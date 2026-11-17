// main.cpp — lifecycle, hotkeys, threads and the version gate.
//
// Read-only by construction: the only process handle is opened with
// PROCESS_VM_READ | PROCESS_QUERY_INFORMATION and no write API is imported.

#include <windows.h>

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <cwchar>
#include <iterator>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include <shellapi.h>
#include <tlhelp32.h>

#include "esp.h"
#include "game.h"
#include "log.h"
#include "offsets.h"
#include "overlay.h"
#include "panel.h"
#include "settings.h"

// ---- shared state -------------------------------------------------------
std::mutex g_settings_mutex;
Settings g_settings;
std::mutex g_snapshot_mutex;
Snapshot g_snapshot;
std::mutex g_runtime_mutex;
RuntimeFields g_runtime;

namespace {

std::atomic<bool> g_offsets_trusted{false};

struct Options {
    uint32_t pid = 0;
    bool trust_profile = false;
};

std::atomic<bool> g_running{true};
std::atomic<uint32_t> g_attached_pid{0};

struct ClientInfo {
    uint32_t pid = 0;
    std::wstring image;
};

std::wstring executable_directory() {
    wchar_t path[MAX_PATH * 2] = {};
    const DWORD length = GetModuleFileNameW(nullptr, path, static_cast<DWORD>(std::size(path)));
    if (length == 0)
        return L".";
    std::wstring full(path, length);
    const size_t slash = full.find_last_of(L"\\/");
    return slash == std::wstring::npos ? L"." : full.substr(0, slash);
}

std::wstring base_name(const std::wstring& path) {
    const size_t slash = path.find_last_of(L"\\/");
    return slash == std::wstring::npos ? path : path.substr(slash + 1);
}

bool ends_with_icase(const std::wstring& value, const wchar_t* suffix) {
    const size_t n = std::wcslen(suffix);
    if (value.size() < n)
        return false;
    return _wcsicmp(value.c_str() + value.size() - n, suffix) == 0;
}

// The installed client identifies its build by the version-* folder. GDK and
// WindowsApps installs have no such folder, which is itself a mismatch.
std::wstring version_token_from_path(const std::wstring& image) {
    const std::wstring marker = L"\\version-";
    const size_t at = image.find(marker);
    if (at == std::wstring::npos)
        return {};
    const size_t start = at + 1; // skip the leading backslash
    const size_t end = image.find(L'\\', start);
    if (end == std::wstring::npos)
        return image.substr(start);
    return image.substr(start, end - start);
}

std::wstring image_for_pid(uint32_t pid) {
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!process)
        return {};
    wchar_t buffer[MAX_PATH * 4] = {};
    DWORD size = static_cast<DWORD>(std::size(buffer));
    std::wstring image;
    if (QueryFullProcessImageNameW(process, 0, buffer, &size))
        image.assign(buffer, size);
    CloseHandle(process);
    return image;
}

bool query_client(uint32_t pid, ClientInfo& out) {
    if (pid == 0)
        return false;
    out.pid = pid;
    out.image = image_for_pid(pid);
    return !out.image.empty();
}

bool find_roblox_process(ClientInfo& out) {
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE)
        return false;

    PROCESSENTRY32W entry{};
    entry.dwSize = sizeof(entry);
    bool found = false;
    if (Process32FirstW(snapshot, &entry)) {
        do {
            if (_wcsicmp(entry.szExeFile, L"RobloxPlayerBeta.exe") != 0)
                continue;
            const std::wstring image = image_for_pid(entry.th32ProcessID);
            if (image.empty())
                continue;
            if (_wcsicmp(base_name(image).c_str(), L"RobloxPlayerBeta.exe") != 0)
                continue;
            out.pid = entry.th32ProcessID;
            out.image = image;
            found = true;
            break;
        } while (Process32NextW(snapshot, &entry));
    }
    CloseHandle(snapshot);
    return found;
}

std::wstring profile_version_w() {
    const char* text = off::kProfileVersion;
    return std::wstring(text, text + std::strlen(text));
}

bool profile_trusted(const ClientInfo& client, const Options& options) {
    if (client.image.empty())
        return false;
    const std::wstring token = version_token_from_path(client.image);
    const std::wstring expected = profile_version_w();
    if (token == expected)
        return true;

    if (options.trust_profile) {
        Log::get().warn("FORCED profile trust (--trust-profile): installed token '%s' != profile '%s'; "
                        "offsets are only valid for the profile build",
                        token.empty() ? "<none>" : Log::utf8(token).c_str(), Log::utf8(expected).c_str());
        return true;
    }

    Log::get().warn("offset profile mismatch: client version token '%s' but offsets.h declares '%s'",
                    token.empty() ? "<none>" : Log::utf8(token).c_str(), Log::utf8(expected).c_str());
    return false;
}

bool key_pressed_once(int vk, bool& previous) {
    const bool down = (GetAsyncKeyState(vk) & 0x8000) != 0;
    const bool edge = down && !previous;
    previous = down;
    return edge;
}

void fill_idle_snapshot(Snapshot& snapshot) {
    snapshot.attached = false;
    snapshot.offsets_trusted = offsets_trusted();
    snapshot.status = "waiting for RobloxPlayerBeta.exe";
}

void collector_main(Options options) {
    Game game;
    uint32_t attached_pid = 0;
    uint64_t next_scan = 0;
    uint64_t tick = 0;
    uint64_t last_count_log = 0;

    while (g_running.load(std::memory_order_relaxed)) {
        const uint64_t now = GetTickCount64();
        if (!game.attached() || now >= next_scan) {
            next_scan = now + 1000;
            ClientInfo client;
            const bool found = options.pid != 0 ? query_client(options.pid, client) : find_roblox_process(client);

            if (found && (client.pid != attached_pid || !game.attached())) {
                if (game.attached())
                    game.detach();
                const bool trusted = profile_trusted(client, options);
                set_offsets_trusted(trusted);
                Log::get().info("client pid=%u image=%s trusted=%d", client.pid, Log::utf8(client.image).c_str(),
                                trusted ? 1 : 0);
                if (game.attach(client.pid)) {
                    attached_pid = client.pid;
                    g_attached_pid.store(client.pid);
                    const uint64_t base = game.memory().module_base();
                    if (!game.memory().module_contains(base + off::VisualEngine_Pointer))
                        Log::get().warn("VisualEngine slot base+0x%llX is outside the module image; "
                                        "only valid for the diagnostic mock target",
                                        static_cast<unsigned long long>(off::VisualEngine_Pointer));
                } else {
                    attached_pid = 0;
                    g_attached_pid.store(0);
                }
            } else if (!found && game.attached()) {
                Log::get().info("Roblox process no longer present; detaching");
                game.detach();
                attached_pid = 0;
                g_attached_pid.store(0);
                set_offsets_trusted(false);
            }
        }

        Snapshot snapshot;
        if (game.attached()) {
            game.collect(snapshot);
        } else {
            snapshot.tick = ++tick;
            fill_idle_snapshot(snapshot);
        }

        RuntimeFields runtime;
        runtime.projection_mode = static_cast<int>(snapshot.projection_mode);
        runtime.team_color_mode = snapshot.team_color_mode;
        runtime.team_color_distinct = snapshot.team_color_distinct;
        runtime.world_generation = snapshot.world_generation;

        {
            std::lock_guard<std::mutex> lock(g_snapshot_mutex);
            snapshot.players_drawn = g_snapshot.players_drawn;
            g_snapshot = std::move(snapshot);
        }

        {
            std::lock_guard<std::mutex> lock(g_runtime_mutex);
            g_runtime = runtime;
        }

        Snapshot counts;
        {
            std::lock_guard<std::mutex> lock(g_snapshot_mutex);
            counts = g_snapshot;
        }
        if (counts.world_valid && now - last_count_log > 3000) {
            last_count_log = now;
            Log::get().info("counts players=%d characters=%d drawn=%d rejected(model=%d humanoid=%d root=%d dead=%d "
                            "distance=%d team=%d) gen=%llu",
                            counts.players_found, counts.characters_valid, counts.players_drawn, counts.rejected_model,
                            counts.rejected_humanoid, counts.rejected_root, counts.rejected_dead,
                            counts.rejected_distance, counts.rejected_team,
                            static_cast<unsigned long long>(counts.world_generation));
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(40));
    }

    game.detach();
}

void publish_settings(const Settings& settings) {
    std::lock_guard<std::mutex> lock(g_settings_mutex);
    g_settings = settings;
}

} // namespace

void set_offsets_trusted(bool trusted) {
    g_offsets_trusted.store(trusted, std::memory_order_relaxed);
}

bool offsets_trusted() {
    return g_offsets_trusted.load(std::memory_order_relaxed);
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    // DPI awareness must be set before any window exists.
    if (!SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2))
        SetProcessDPIAware();

    // Single instance: exit before touching the log so the running instance
    // keeps its file intact.
    HANDLE instance_mutex = CreateMutexW(nullptr, TRUE, L"Global\\rbx_esp_single_instance");
    if (!instance_mutex)
        return 0;
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        CloseHandle(instance_mutex);
        return 0;
    }

    Options options;
    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (argv) {
        for (int i = 1; i < argc; ++i) {
            if (_wcsicmp(argv[i], L"--pid") == 0 && i + 1 < argc) {
                options.pid = static_cast<uint32_t>(_wtoi(argv[++i]));
            } else if (_wcsicmp(argv[i], L"--trust-profile") == 0) {
                options.trust_profile = true;
            }
        }
        LocalFree(argv);
    }

    const std::wstring log_path = executable_directory() + L"\\rbx_esp.log";
    if (!Log::get().open(log_path.c_str()))
        return 1; // nowhere to report failure; no modal dialog by design

    Log::get().info("==== %s (offsets %s, %s) ====", off::kBuildId, off::kProfileVersion, off::kProfileSource);
    Log::get().info("log path %s", Log::utf8(log_path).c_str());
    Log::get().info("options pid=%u trust_profile=%d", options.pid, options.trust_profile ? 1 : 0);

    ClientInfo initial_client;
    if (options.pid != 0 ? query_client(options.pid, initial_client) : find_roblox_process(initial_client)) {
        const std::wstring token = version_token_from_path(initial_client.image);
        Log::get().info("installed client pid=%u image=%s version-token='%s'", initial_client.pid,
                        Log::utf8(initial_client.image).c_str(),
                        token.empty() ? "<none>" : Log::utf8(token).c_str());
        if (!profile_trusted(initial_client, options))
            Log::get().warn("ESP will stay disabled: offsets.h has no verified dump for this client build");
    } else {
        Log::get().info("installed client: RobloxPlayerBeta.exe not running");
    }

    std::thread collector(collector_main, options);

    Overlay overlay;
    if (!overlay.init(instance)) {
        Log::get().error("overlay init failed");
        g_running.store(false);
        collector.join();
        Log::get().close();
        ReleaseMutex(instance_mutex);
        CloseHandle(instance_mutex);
        return 1;
    }
    panel::apply_style(overlay.ui_scale());

    PanelState panel_state;
    panel_state.ui_scale = overlay.ui_scale();
    {
        std::lock_guard<std::mutex> lock(g_settings_mutex);
        panel_state.x = g_settings.panel_x;
        panel_state.y = g_settings.panel_y;
        overlay.set_panel_visible(g_settings.panel_visible);
    }

    Log::get().info("hotkeys: F1 panel toggle, F2 exit");

    bool f1_down = false;
    bool f2_down = false;
    uint64_t ticks_total = 0;
    uint64_t ticks_open = 0;
    uint64_t ticks_hidden = 0;
    uint64_t last_tick_log = GetTickCount64();
    Settings settings_for_publish;

    while (g_running.load(std::memory_order_relaxed)) {
        const auto frame_start = std::chrono::steady_clock::now();
        if (!overlay.pump())
            break;

        if (key_pressed_once(VK_F1, f1_down)) {
            const bool visible = !overlay.panel_visible();
            overlay.set_panel_visible(visible);
            if (!visible)
                panel_state.bounds_valid = false;
            Log::get().info("panel %s via F1", visible ? "visible" : "hidden");
        }
        if (key_pressed_once(VK_F2, f2_down)) {
            Log::get().info("exit requested via F2");
            break;
        }

        overlay.follow(g_attached_pid.load());

        Settings settings;
        Snapshot snapshot;
        {
            std::lock_guard<std::mutex> lock(g_settings_mutex);
            settings = g_settings;
        }
        {
            std::lock_guard<std::mutex> lock(g_snapshot_mutex);
            snapshot = g_snapshot;
        }

        if (overlay.begin_frame()) {
            const ImVec2 display = overlay.display_size();
            const ImVec2 origin = overlay.client_origin_screen();

            panel::Outcome outcome;
            if (overlay.panel_visible()) {
                outcome = panel::draw(settings, panel_state, snapshot, display, origin);
            } else {
                panel_state.bounds_valid = false;
            }

            snapshot.players_drawn = esp::draw(ImGui::GetBackgroundDrawList(), settings, snapshot,
                                               Vec2(display.x, display.y));

            overlay.end_frame(panel_state, overlay.panel_visible());
            ++ticks_total;
            if (overlay.panel_visible())
                ++ticks_open;
            else
                ++ticks_hidden;

            if (outcome.reset_position) {
                panel_state.x = -1.0f;
                panel_state.y = -1.0f;
                panel_state.bounds_valid = false;
            }

            if (outcome.hide_requested) {
                overlay.set_panel_visible(false);
                panel_state.bounds_valid = false;
            }

            settings.panel_x = panel_state.x;
            settings.panel_y = panel_state.y;
            settings.panel_visible = overlay.panel_visible();
            if (outcome.settings_changed || settings.panel_x != settings_for_publish.panel_x ||
                settings.panel_y != settings_for_publish.panel_y ||
                settings.panel_visible != settings_for_publish.panel_visible) {
                publish_settings(settings);
                settings_for_publish = settings;
            }

            {
                std::lock_guard<std::mutex> lock(g_snapshot_mutex);
                g_snapshot.players_drawn = snapshot.players_drawn;
            }
        } else {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }

        const uint64_t now = GetTickCount64();
        if (now - last_tick_log >= 5000) {
            last_tick_log = now;
            Log::get().info("ticks total=%llu panel_open=%llu panel_hidden=%llu attached_pid=%u",
                            static_cast<unsigned long long>(ticks_total), static_cast<unsigned long long>(ticks_open),
                            static_cast<unsigned long long>(ticks_hidden), g_attached_pid.load());
        }

        // Keep the overlay responsive at ~144 Hz without burning a full core.
        const auto elapsed = std::chrono::steady_clock::now() - frame_start;
        const auto budget = std::chrono::microseconds(6944);
        if (elapsed < budget)
            std::this_thread::sleep_for(budget - elapsed);
    }

    Log::get().info("ticks at shutdown: total=%llu panel_open=%llu panel_hidden=%llu",
                    static_cast<unsigned long long>(ticks_total), static_cast<unsigned long long>(ticks_open),
                    static_cast<unsigned long long>(ticks_hidden));

    g_running.store(false);
    collector.join();
    overlay.shutdown();

    Log::get().info("shutdown complete");
    Log::get().close();
    ReleaseMutex(instance_mutex);
    CloseHandle(instance_mutex);
    return 0;
}
