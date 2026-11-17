// overlay.cpp — click-through render window + panel-only input proxy.
//
// Design notes that matter:
//  * The render window carries WS_EX_TRANSPARENT and answers HTTRANSPARENT, so
//    no click ever lands on it. It exists only to show DX11 output.
//  * The proxy window is a separate top-level layered window with alpha 1/255.
//    It covers exactly the panel rectangle, receives mouse input, and translates
//    proxy-client coordinates to overlay-client coordinates through screen
//    space, which is what makes DPI scaling correct.
//  * Mouse events are injected into ImGui after the Win32 backend's NewFrame.
//    The overlay is never the foreground window, so the backend's own mouse
//    path stays inactive; injecting avoids needing a focused HWND.

#include "overlay.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <iterator>

#include <dwmapi.h>
#include <dcomp.h>
#include <dxgi1_2.h>
#include <imgui_impl_dx11.h>
#include <imgui_impl_win32.h>

#include "log.h"

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "dcomp.lib")

namespace {

constexpr wchar_t kRenderClass[] = L"RbxEspOverlayRender";
constexpr wchar_t kProxyClass[] = L"RbxEspOverlayInput";
constexpr wchar_t kWindowTitle[] = L"rbx_esp overlay";

} // namespace

LRESULT CALLBACK Overlay::render_proc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    Overlay* self = reinterpret_cast<Overlay*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
        auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
        self = reinterpret_cast<Overlay*>(create->lpCreateParams);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    }
    if (!self)
        return DefWindowProcW(hwnd, message, wparam, lparam);

    switch (message) {
    case WM_NCHITTEST:
        return HTTRANSPARENT;
    case WM_MOUSEACTIVATE:
        return MA_NOACTIVATE;
    case WM_ERASEBKGND:
        return 1;
    case WM_PAINT: {
        PAINTSTRUCT ps{};
        BeginPaint(hwnd, &ps);
        EndPaint(hwnd, &ps);
        return 0;
    }
    case WM_CLOSE:
        return 0;
    default:
        break;
    }
    return DefWindowProcW(hwnd, message, wparam, lparam);
}

LRESULT CALLBACK Overlay::proxy_proc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    Overlay* self = reinterpret_cast<Overlay*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
        auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
        self = reinterpret_cast<Overlay*>(create->lpCreateParams);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    }
    if (!self)
        return DefWindowProcW(hwnd, message, wparam, lparam);

    switch (message) {
    case WM_NCHITTEST:
        return HTCLIENT;
    case WM_MOUSEACTIVATE:
        return MA_NOACTIVATE;
    case WM_MOUSEMOVE:
    case WM_LBUTTONDOWN:
    case WM_LBUTTONUP:
    case WM_RBUTTONDOWN:
    case WM_RBUTTONUP:
    case WM_MBUTTONDOWN:
    case WM_MBUTTONUP:
    case WM_MOUSEWHEEL:
        self->on_proxy_mouse(message, wparam, lparam);
        return 0;
    case WM_MOUSELEAVE:
        self->tracking_mouse_ = false;
        self->clear_input();
        return 0;
    case WM_CAPTURECHANGED:
        if (self->input_.down[0] || self->input_.down[1] || self->input_.down[2]) {
            self->input_.down[0] = false;
            self->input_.down[1] = false;
            self->input_.down[2] = false;
        }
        return 0;
    case WM_ERASEBKGND:
        return 1;
    case WM_PAINT: {
        PAINTSTRUCT ps{};
        BeginPaint(hwnd, &ps);
        EndPaint(hwnd, &ps);
        return 0;
    }
    case WM_CLOSE:
        return 0;
    default:
        break;
    }
    return DefWindowProcW(hwnd, message, wparam, lparam);
}

bool Overlay::init(HINSTANCE instance) {
    instance_ = instance;

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = nullptr; // panel position lives in settings, not imgui.ini
    io.LogFilename = nullptr;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

    if (!create_windows(instance_))
        return false;
    if (!create_device())
        return false;

    load_fonts();
    ImGui_ImplWin32_Init(render_hwnd_);
    ImGui_ImplDX11_Init(device_, context_);
    imgui_ready_ = true;

    ShowWindow(render_hwnd_, SW_SHOWNOACTIVATE);
    render_shown_ = true;
    Log::get().info("overlay created render_hwnd=0x%llX proxy_hwnd=0x%llX %ux%u",
                    static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(render_hwnd_)),
                    static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(proxy_hwnd_)),
                    static_cast<unsigned>(width_), static_cast<unsigned>(height_));
    return true;
}

bool Overlay::create_windows(HINSTANCE instance) {
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.style = CS_NOCLOSE;
    wc.lpfnWndProc = render_proc;
    wc.hInstance = instance;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = nullptr;
    wc.lpszClassName = kRenderClass;
    if (!RegisterClassExW(&wc)) {
        Log::get().error("RegisterClassExW(render) failed win32=%lu", GetLastError());
        return false;
    }

    wc.lpfnWndProc = proxy_proc;
    wc.lpszClassName = kProxyClass;
    if (!RegisterClassExW(&wc)) {
        Log::get().error("RegisterClassExW(proxy) failed win32=%lu", GetLastError());
        return false;
    }

    const int screen_w = GetSystemMetrics(SM_CXSCREEN);
    const int screen_h = GetSystemMetrics(SM_CYSCREEN);

    // The render window has no redirection bitmap: its pixels come from a
    // composition swapchain through DirectComposition, which is what gives the
    // overlay real per-pixel alpha. A layered window with LWA_ALPHA makes the
    // whole swapchain opaque, which covers the desktop in black.
    const DWORD render_ex = WS_EX_TOPMOST | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TRANSPARENT |
                            WS_EX_NOREDIRECTIONBITMAP;
    render_hwnd_ = CreateWindowExW(render_ex, kRenderClass, kWindowTitle, WS_POPUP, 0, 0, screen_w, screen_h, nullptr,
                                   nullptr, instance, this);
    if (!render_hwnd_) {
        Log::get().error("CreateWindowExW(render) failed win32=%lu", GetLastError());
        return false;
    }

    const DWORD proxy_ex = WS_EX_TOPMOST | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_LAYERED;
    proxy_hwnd_ = CreateWindowExW(proxy_ex, kProxyClass, L"rbx_esp input", WS_POPUP, 0, 0, 8, 8, nullptr, nullptr,
                                  instance, this);
    if (!proxy_hwnd_) {
        Log::get().error("CreateWindowExW(proxy) failed win32=%lu", GetLastError());
        return false;
    }
    // Alpha 1/255 is deliberately not zero: a fully transparent layered window
    // may be skipped by hit testing on some compositions.
    SetLayeredWindowAttributes(proxy_hwnd_, 0, 1, LWA_ALPHA);
    ShowWindow(proxy_hwnd_, SW_HIDE);

    window_rect_ = RECT{0, 0, screen_w, screen_h};
    width_ = static_cast<uint32_t>(screen_w);
    height_ = static_cast<uint32_t>(screen_h);
    return true;
}

bool Overlay::create_device() {
    const D3D_FEATURE_LEVEL levels[] = {D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0};
    const UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
    HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, flags, levels,
                                   static_cast<UINT>(std::size(levels)), D3D11_SDK_VERSION, &device_, nullptr, &context_);
    if (FAILED(hr)) {
        Log::get().warn("D3D11 hardware device failed hr=0x%08lX; trying WARP", static_cast<unsigned long>(hr));
        device_ = nullptr;
        context_ = nullptr;
        hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_WARP, nullptr, flags, levels,
                               static_cast<UINT>(std::size(levels)), D3D11_SDK_VERSION, &device_, nullptr, &context_);
    }
    if (FAILED(hr) || !device_ || !context_) {
        Log::get().error("D3D11CreateDevice failed hr=0x%08lX", static_cast<unsigned long>(hr));
        destroy_device();
        return false;
    }

    IDXGIDevice* dxgi_device = nullptr;
    IDXGIAdapter* adapter = nullptr;
    IDXGIFactory2* factory = nullptr;

    auto release_locals = [&]() {
        if (factory)
            factory->Release();
        if (adapter)
            adapter->Release();
        if (dxgi_device)
            dxgi_device->Release();
    };

    hr = device_->QueryInterface(__uuidof(IDXGIDevice), reinterpret_cast<void**>(&dxgi_device));
    if (FAILED(hr) || !dxgi_device) {
        Log::get().error("QueryInterface(IDXGIDevice) failed hr=0x%08lX", static_cast<unsigned long>(hr));
        release_locals();
        destroy_device();
        return false;
    }

    hr = dxgi_device->GetAdapter(&adapter);
    if (FAILED(hr) || !adapter) {
        Log::get().error("IDXGIDevice::GetAdapter failed hr=0x%08lX", static_cast<unsigned long>(hr));
        release_locals();
        destroy_device();
        return false;
    }

    hr = adapter->GetParent(__uuidof(IDXGIFactory2), reinterpret_cast<void**>(&factory));
    if (FAILED(hr) || !factory) {
        Log::get().error("IDXGIAdapter::GetParent(IDXGIFactory2) failed hr=0x%08lX", static_cast<unsigned long>(hr));
        release_locals();
        destroy_device();
        return false;
    }

    // Composition swapchain: premultiplied alpha, flipped model, and no HWND
    // binding. The visual is attached to the window through DirectComposition.
    DXGI_SWAP_CHAIN_DESC1 desc{};
    desc.Width = width_;
    desc.Height = height_;
    desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    desc.Stereo = FALSE;
    desc.SampleDesc.Count = 1;
    desc.SampleDesc.Quality = 0;
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.BufferCount = 2;
    desc.Scaling = DXGI_SCALING_STRETCH;
    desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    desc.AlphaMode = DXGI_ALPHA_MODE_PREMULTIPLIED;

    IDXGISwapChain1* swapchain = nullptr;
    hr = factory->CreateSwapChainForComposition(device_, &desc, nullptr, &swapchain);
    if (FAILED(hr) || !swapchain) {
        Log::get().error("CreateSwapChainForComposition failed hr=0x%08lX", static_cast<unsigned long>(hr));
        release_locals();
        destroy_device();
        return false;
    }
    swapchain_ = swapchain; // ownership moves to the member

    ID3D11Texture2D* back_buffer = nullptr;
    if (FAILED(swapchain_->GetBuffer(0, __uuidof(ID3D11Texture2D), reinterpret_cast<void**>(&back_buffer))) ||
        !back_buffer) {
        Log::get().error("composition swapchain GetBuffer failed");
        release_locals();
        destroy_device();
        return false;
    }
    hr = device_->CreateRenderTargetView(back_buffer, nullptr, &render_target_);
    back_buffer->Release();
    if (FAILED(hr)) {
        Log::get().error("CreateRenderTargetView failed hr=0x%08lX", static_cast<unsigned long>(hr));
        release_locals();
        destroy_device();
        return false;
    }

    hr = DCompositionCreateDevice(dxgi_device, __uuidof(IDCompositionDevice),
                                  reinterpret_cast<void**>(&dcomp_device_));
    if (FAILED(hr) || !dcomp_device_) {
        Log::get().error("DCompositionCreateDevice failed hr=0x%08lX", static_cast<unsigned long>(hr));
        release_locals();
        destroy_device();
        return false;
    }

    hr = dcomp_device_->CreateTargetForHwnd(render_hwnd_, TRUE, &dcomp_target_);
    if (FAILED(hr) || !dcomp_target_) {
        Log::get().error("IDCompositionDevice::CreateTargetForHwnd failed hr=0x%08lX",
                         static_cast<unsigned long>(hr));
        release_locals();
        destroy_device();
        return false;
    }

    hr = dcomp_device_->CreateVisual(&dcomp_visual_);
    if (FAILED(hr) || !dcomp_visual_) {
        Log::get().error("IDCompositionDevice::CreateVisual failed hr=0x%08lX", static_cast<unsigned long>(hr));
        release_locals();
        destroy_device();
        return false;
    }

    hr = dcomp_visual_->SetContent(swapchain_);
    if (SUCCEEDED(hr))
        hr = dcomp_target_->SetRoot(dcomp_visual_);
    if (SUCCEEDED(hr))
        hr = dcomp_device_->Commit();
    if (FAILED(hr)) {
        Log::get().error("DirectComposition setup failed hr=0x%08lX", static_cast<unsigned long>(hr));
        release_locals();
        destroy_device();
        return false;
    }

    release_locals();
    Log::get().info("DirectComposition swapchain ready (%ux%u, premultiplied alpha)", width_, height_);
    return true;
}

void Overlay::load_fonts() {
    ImGuiIO& io = ImGui::GetIO();

    // Logical sizes in the menu are 12 px at 100% scaling. The overlay works in
    // physical pixels, so the font and the panel scale together with the
    // monitor DPI instead of becoming unreadable on a 150% display.
    UINT dpi = 0;
    if (render_hwnd_)
        dpi = GetDpiForWindow(render_hwnd_);
    if (dpi == 0) {
        HDC screen = GetDC(nullptr);
        dpi = static_cast<UINT>(GetDeviceCaps(screen, LOGPIXELSX));
        ReleaseDC(nullptr, screen);
    }
    ui_scale_ = dpi > 0 ? static_cast<float>(dpi) / 96.0f : 1.0f;
    ui_scale_ = std::clamp(ui_scale_, 1.0f, 2.0f);

    // Segoe UI ships with Windows and is the clean sans-serif closest to the
    // Inter look requested for the menu. Fall back to the built-in bitmap font
    // when the file cannot be opened.
    const char* candidates[] = {
        "C:\\Windows\\Fonts\\segoeui.ttf",
        "C:\\Windows\\Fonts\\arial.ttf",
    };
    ImFont* font = nullptr;
    for (const char* path : candidates) {
        if (GetFileAttributesA(path) == INVALID_FILE_ATTRIBUTES)
            continue;
        font = io.Fonts->AddFontFromFileTTF(path, 12.0f * ui_scale_);
        if (font) {
            Log::get().info("menu font %s at %.1f px (dpi scale %.2f)", path, 12.0f * ui_scale_, ui_scale_);
            break;
        }
    }
    if (!font) {
        io.Fonts->AddFontDefault();
        Log::get().warn("menu font fallback to ImGui default; scale %.2f", ui_scale_);
    }
}

void Overlay::destroy_device() {
    if (dcomp_visual_) {
        dcomp_visual_->Release();
        dcomp_visual_ = nullptr;
    }
    if (dcomp_target_) {
        dcomp_target_->Release();
        dcomp_target_ = nullptr;
    }
    if (dcomp_device_) {
        dcomp_device_->Release();
        dcomp_device_ = nullptr;
    }
    if (render_target_) {
        render_target_->Release();
        render_target_ = nullptr;
    }
    if (swapchain_) {
        swapchain_->Release();
        swapchain_ = nullptr;
    }
    if (context_) {
        context_->Release();
        context_ = nullptr;
    }
    if (device_) {
        device_->Release();
        device_ = nullptr;
    }
}

void Overlay::destroy_windows() {
    if (proxy_hwnd_) {
        DestroyWindow(proxy_hwnd_);
        proxy_hwnd_ = nullptr;
    }
    if (render_hwnd_) {
        DestroyWindow(render_hwnd_);
        render_hwnd_ = nullptr;
    }
    UnregisterClassW(kRenderClass, instance_);
    UnregisterClassW(kProxyClass, instance_);
}

bool Overlay::resize_swapchain(uint32_t width, uint32_t height) {
    if (!swapchain_ || !context_ || !device_ || width == 0 || height == 0)
        return false;

    if (render_target_) {
        render_target_->Release();
        render_target_ = nullptr;
    }
    context_->OMSetRenderTargets(0, nullptr, nullptr);
    context_->Flush();

    HRESULT hr = swapchain_->ResizeBuffers(0, width, height, DXGI_FORMAT_UNKNOWN, 0);
    if (FAILED(hr)) {
        Log::get().error("ResizeBuffers(%ux%u) failed hr=0x%08lX", width, height, static_cast<unsigned long>(hr));
        return false;
    }

    ID3D11Texture2D* back_buffer = nullptr;
    if (FAILED(swapchain_->GetBuffer(0, __uuidof(ID3D11Texture2D), reinterpret_cast<void**>(&back_buffer))) ||
        !back_buffer) {
        Log::get().error("swapchain GetBuffer after resize failed");
        return false;
    }
    hr = device_->CreateRenderTargetView(back_buffer, nullptr, &render_target_);
    back_buffer->Release();
    if (FAILED(hr)) {
        Log::get().error("CreateRenderTargetView after resize failed hr=0x%08lX", static_cast<unsigned long>(hr));
        return false;
    }
    return true;
}

void Overlay::shutdown() {
    hide_proxy();
    if (imgui_ready_) {
        ImGui_ImplDX11_Shutdown();
        ImGui_ImplWin32_Shutdown();
        ImGui::DestroyContext();
        imgui_ready_ = false;
    }
    destroy_device();
    destroy_windows();
    Log::get().info("overlay resources released");
}

bool Overlay::pump() {
    MSG msg{};
    while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
        if (msg.message == WM_QUIT)
            return false;
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    return true;
}

HWND Overlay::find_target_window(uint32_t pid) const {
    if (pid == 0)
        return nullptr;

    struct Search {
        DWORD pid;
        HWND best;
        uint64_t best_area;
    } search{pid, nullptr, 0};

    EnumWindows(
        [](HWND hwnd, LPARAM param) -> BOOL {
            auto* state = reinterpret_cast<Search*>(param);
            DWORD window_pid = 0;
            GetWindowThreadProcessId(hwnd, &window_pid);
            if (window_pid != state->pid)
                return TRUE;
            if (!IsWindowVisible(hwnd) || IsIconic(hwnd))
                return TRUE;
            if (GetAncestor(hwnd, GA_ROOT) != hwnd)
                return TRUE;
            const LONG ex_style = GetWindowLongW(hwnd, GWL_EXSTYLE);
            if (ex_style & WS_EX_TOOLWINDOW)
                return TRUE;

            DWORD cloaked = 0;
            if (SUCCEEDED(DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked))) && cloaked != 0)
                return TRUE;

            RECT client{};
            if (!GetClientRect(hwnd, &client))
                return TRUE;
            const int w = client.right - client.left;
            const int h = client.bottom - client.top;
            if (w < 200 || h < 150)
                return TRUE;

            const uint64_t area = static_cast<uint64_t>(w) * static_cast<uint64_t>(h);
            if (area > state->best_area) {
                state->best_area = area;
                state->best = hwnd;
            }
            return TRUE;
        },
        reinterpret_cast<LPARAM>(&search));

    return search.best;
}

void Overlay::follow(uint32_t pid) {
    const uint64_t now = GetTickCount64();
    if (pid != tracked_pid_) {
        tracked_pid_ = pid;
        target_hwnd_ = find_target_window(pid);
        next_window_scan_ = now + 1000;
        if (target_hwnd_)
            Log::get().info("target window 0x%llX for pid %u",
                            static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(target_hwnd_)), pid);
        else
            Log::get().info("pid %u has no usable window; overlay uses primary monitor", pid);
    } else if (now >= next_window_scan_) {
        next_window_scan_ = now + 1000;
        HWND fresh = find_target_window(pid);
        if (fresh != target_hwnd_) {
            target_hwnd_ = fresh;
            if (fresh)
                Log::get().info("target window changed to 0x%llX",
                                static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(fresh)));
        }
    }
    update_window_rect();
}

void Overlay::update_window_rect() {
    RECT rect{};
    bool have_target = false;

    if (target_hwnd_ && IsWindow(target_hwnd_) && !IsIconic(target_hwnd_)) {
        RECT client{};
        if (GetClientRect(target_hwnd_, &client) && client.right > 1 && client.bottom > 1) {
            POINT top_left{0, 0};
            if (ClientToScreen(target_hwnd_, &top_left)) {
                rect.left = top_left.x;
                rect.top = top_left.y;
                rect.right = top_left.x + client.right;
                rect.bottom = top_left.y + client.bottom;
                have_target = true;
            }
        }
    }

    if (!have_target) {
        // Keep the panel reachable on the primary monitor while Roblox has no
        // usable window (not started, loading, or minimized).
        rect.left = 0;
        rect.top = 0;
        rect.right = GetSystemMetrics(SM_CXSCREEN);
        rect.bottom = GetSystemMetrics(SM_CYSCREEN);
    }

    const int x = static_cast<int>(rect.left);
    const int y = static_cast<int>(rect.top);
    const int w = static_cast<int>(rect.right - rect.left);
    const int h = static_cast<int>(rect.bottom - rect.top);
    if (w <= 1 || h <= 1)
        return;

    const bool moved = x != window_rect_.left || y != window_rect_.top;
    const bool resized = static_cast<uint32_t>(w) != width_ || static_cast<uint32_t>(h) != height_;
    if (!moved && !resized)
        return;

    window_rect_ = RECT{x, y, x + w, y + h};
    SetWindowPos(render_hwnd_, HWND_TOPMOST, x, y, w, h, SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_SHOWWINDOW);
    render_shown_ = true;

    if (resized) {
        width_ = static_cast<uint32_t>(w);
        height_ = static_cast<uint32_t>(h);
        if (!resize_swapchain(width_, height_))
            Log::get().throttled("swapchain-resize", 2000, "swapchain resize failed; keeping previous frame");
        Log::get().info("overlay window %dx%d at %d,%d", w, h, x, y);
    }
}

ImVec2 Overlay::display_size() const {
    return ImVec2(static_cast<float>(width_), static_cast<float>(height_));
}

ImVec2 Overlay::client_origin_screen() const {
    POINT origin{0, 0};
    if (render_hwnd_)
        ClientToScreen(render_hwnd_, &origin);
    return ImVec2(static_cast<float>(origin.x), static_cast<float>(origin.y));
}

void Overlay::on_proxy_mouse(uint32_t message, WPARAM wparam, LPARAM lparam) {
    if (!render_hwnd_ || !proxy_hwnd_)
        return;

    last_input_ms_.store(GetTickCount64(), std::memory_order_relaxed);

    POINT point{static_cast<short>(LOWORD(lparam)), static_cast<short>(HIWORD(lparam))};
    if (message == WM_MOUSEWHEEL) {
        // Wheel messages already carry screen coordinates.
        if (!ScreenToClient(render_hwnd_, &point))
            return;
        input_.wheel += GET_WHEEL_DELTA_WPARAM(wparam) / WHEEL_DELTA;
    } else {
        if (!ClientToScreen(proxy_hwnd_, &point))
            return;
        if (!ScreenToClient(render_hwnd_, &point))
            return;
    }
    input_.mouse_x = static_cast<float>(point.x);
    input_.mouse_y = static_cast<float>(point.y);

    auto set_button = [&](int index, bool down) {
        if (index < 0 || index > 2)
            return;
        input_.down[index] = down;
    };

    switch (message) {
    case WM_MOUSEMOVE:
        if (!tracking_mouse_) {
            TRACKMOUSEEVENT track{};
            track.cbSize = sizeof(track);
            track.dwFlags = TME_LEAVE;
            track.hwndTrack = proxy_hwnd_;
            tracking_mouse_ = TrackMouseEvent(&track) != FALSE;
        }
        break;
    case WM_LBUTTONDOWN:
        set_button(0, true);
        SetCapture(proxy_hwnd_);
        break;
    case WM_LBUTTONUP:
        set_button(0, false);
        if (!input_.down[0] && !input_.down[1] && !input_.down[2] && GetCapture() == proxy_hwnd_)
            ReleaseCapture();
        break;
    case WM_RBUTTONDOWN:
        set_button(1, true);
        SetCapture(proxy_hwnd_);
        break;
    case WM_RBUTTONUP:
        set_button(1, false);
        if (!input_.down[0] && !input_.down[1] && !input_.down[2] && GetCapture() == proxy_hwnd_)
            ReleaseCapture();
        break;
    case WM_MBUTTONDOWN:
        set_button(2, true);
        SetCapture(proxy_hwnd_);
        break;
    case WM_MBUTTONUP:
        set_button(2, false);
        if (!input_.down[0] && !input_.down[1] && !input_.down[2] && GetCapture() == proxy_hwnd_)
            ReleaseCapture();
        break;
    default:
        break;
    }
}

void Overlay::clear_input() {
    input_.mouse_x = -FLT_MAX;
    input_.mouse_y = -FLT_MAX;
    input_.down[0] = false;
    input_.down[1] = false;
    input_.down[2] = false;
    input_.wheel = 0;
    if (!imgui_ready_)
        return;
    ImGuiIO& io = ImGui::GetIO();
    io.AddMousePosEvent(-FLT_MAX, -FLT_MAX);
    for (int i = 0; i < 3; ++i)
        io.AddMouseButtonEvent(i, false);
    sent_mouse_valid_ = false;
    sent_down_[0] = sent_down_[1] = sent_down_[2] = false;
    sent_mouse_x_ = sent_mouse_y_ = -FLT_MAX;
}

void Overlay::push_input() {
    ImGuiIO& io = ImGui::GetIO();
    bool has_position = input_.mouse_x > -1.0e6f && input_.mouse_y > -1.0e6f;

    if (has_position) {
        if (!sent_mouse_valid_ || input_.mouse_x != sent_mouse_x_ || input_.mouse_y != sent_mouse_y_) {
            io.AddMousePosEvent(input_.mouse_x, input_.mouse_y);
            sent_mouse_x_ = input_.mouse_x;
            sent_mouse_y_ = input_.mouse_y;
            sent_mouse_valid_ = true;
        }
    } else if (sent_mouse_valid_) {
        io.AddMousePosEvent(-FLT_MAX, -FLT_MAX);
        sent_mouse_valid_ = false;
        sent_mouse_x_ = sent_mouse_y_ = -FLT_MAX;
    }

    for (int i = 0; i < 3; ++i) {
        if (input_.down[i] != sent_down_[i]) {
            io.AddMouseButtonEvent(i, input_.down[i]);
            sent_down_[i] = input_.down[i];
        }
    }

    if (input_.wheel != 0) {
        io.AddMouseWheelEvent(0.0f, static_cast<float>(input_.wheel));
        input_.wheel = 0;
    }
}

bool Overlay::begin_frame() {
    if (!imgui_ready_ || !render_hwnd_ || !render_target_ || width_ == 0 || height_ == 0)
        return false;

    ImGui_ImplDX11_NewFrame();
    ImGui_ImplWin32_NewFrame();
    push_input();
    ImGui::NewFrame();
    in_frame_ = true;
    return true;
}

void Overlay::end_frame(const PanelState& panel_state, bool panel_visible) {
    if (!in_frame_)
        return;
    in_frame_ = false;

    ImGui::Render();

    if (!device_ || !context_ || !swapchain_ || !render_target_)
        return;

    const float clear_color[4] = {0.0f, 0.0f, 0.0f, 0.0f};
    const D3D11_VIEWPORT viewport{0.0f, 0.0f, static_cast<float>(width_), static_cast<float>(height_), 0.0f, 1.0f};
    context_->OMSetRenderTargets(1, &render_target_, nullptr);
    context_->RSSetViewports(1, &viewport);
    context_->ClearRenderTargetView(render_target_, clear_color);
    ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());

    const HRESULT hr = swapchain_->Present(0, 0);
    if (SUCCEEDED(hr)) {
        if (!present_logged_) {
            present_logged_ = true;
            Log::get().info("Present: first frame ok (%ux%u)", static_cast<unsigned>(width_),
                            static_cast<unsigned>(height_));
        }
    } else {
        ++present_failures_;
        const uint64_t now = GetTickCount64();
        if (now - last_present_fail_log_ > 2000) {
            last_present_fail_log_ = now;
            Log::get().warn("Present failed hr=0x%08lX (count=%d)", static_cast<unsigned long>(hr), present_failures_);
        }
        if (hr == DXGI_ERROR_DEVICE_REMOVED || hr == DXGI_ERROR_DEVICE_RESET) {
            Log::get().warn("D3D11 device lost; recreating device");
            ImGui_ImplDX11_Shutdown();
            destroy_device();
            if (create_device())
                ImGui_ImplDX11_Init(device_, context_);
            else
                Log::get().error("D3D11 device recreation failed");
        }
    }

    place_proxy(panel_state, panel_visible);
}

void Overlay::place_proxy(const PanelState& panel_state, bool panel_visible) {
    if (!proxy_hwnd_ || !render_hwnd_)
        return;

    if (!panel_visible || !panel_state.bounds_valid) {
        hide_proxy();
        return;
    }

    const float width = panel_state.bounds_max_x - panel_state.bounds_min_x;
    const float height = panel_state.bounds_max_y - panel_state.bounds_min_y;
    if (width < 8.0f || height < 8.0f) {
        hide_proxy();
        return;
    }

    POINT top_left{static_cast<LONG>(std::floor(panel_state.bounds_min_x)),
                   static_cast<LONG>(std::floor(panel_state.bounds_min_y))};
    POINT bottom_right{static_cast<LONG>(std::ceil(panel_state.bounds_max_x)),
                       static_cast<LONG>(std::ceil(panel_state.bounds_max_y))};
    if (!ClientToScreen(render_hwnd_, &top_left) || !ClientToScreen(render_hwnd_, &bottom_right)) {
        hide_proxy();
        return;
    }

    const int w = std::max(8, static_cast<int>(bottom_right.x - top_left.x));
    const int h = std::max(8, static_cast<int>(bottom_right.y - top_left.y));

    if (!proxy_visible_) {
        ShowWindow(proxy_hwnd_, SW_SHOWNOACTIVATE);
        proxy_visible_ = true;
    }
    if (top_left.x != proxy_rect_.left || top_left.y != proxy_rect_.top || w != proxy_rect_.right ||
        h != proxy_rect_.bottom) {
        SetWindowPos(proxy_hwnd_, HWND_TOPMOST, top_left.x, top_left.y, w, h,
                     SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_SHOWWINDOW);
        proxy_rect_ = RECT{top_left.x, top_left.y, w, h};
    }
}

void Overlay::hide_proxy() {
    const bool was_visible = proxy_visible_;
    if (proxy_hwnd_ && proxy_visible_) {
        if (GetCapture() == proxy_hwnd_)
            ReleaseCapture();
        ShowWindow(proxy_hwnd_, SW_HIDE);
        proxy_visible_ = false;
    }
    tracking_mouse_ = false;
    if (was_visible || sent_mouse_valid_ || input_.down[0] || input_.down[1] || input_.down[2])
        clear_input();
}

void Overlay::set_panel_visible(bool visible) {
    panel_visible_ = visible;
    if (!visible)
        hide_proxy();
}
