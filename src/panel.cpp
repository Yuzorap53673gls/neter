// panel.cpp — "Reaper Aim" menu shell.
//
// The layout is deliberately self-contained: a 410x340 floating window at
// 100% DPI with a fixed title bar, a 125 px sidebar and a scrolling content
// column. Only the Visuals controls touch real Settings; the Aimbot and FPS
// tabs are navigation previews and never feed the memory reader.

#include "panel.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <iterator>
#include <string>
#include <unordered_map>

#include <windows.h>

#include "log.h"

namespace panel {
namespace {

constexpr float kWidth = 410.0f;
constexpr float kHeight = 340.0f;
constexpr float kTitleHeight = 28.0f;
constexpr float kSidebarWidth = 125.0f;
constexpr float kRowHeight = 28.0f;
constexpr float kSwitchAnimationSeconds = 0.15f;

constexpr ImU32 kWindowBg = IM_COL32(26, 15, 18, 248);
constexpr ImU32 kTitleBg = IM_COL32(33, 18, 23, 255);
constexpr ImU32 kSidebarBg = IM_COL32(21, 11, 14, 255);
constexpr ImU32 kTabActive = IM_COL32(45, 25, 31, 255);
constexpr ImU32 kTabHover = IM_COL32(255, 255, 255, 10);
constexpr ImU32 kAccent = IM_COL32(190, 64, 84, 255);
constexpr ImU32 kText = IM_COL32(242, 236, 238, 255);
constexpr ImU32 kTextMuted = IM_COL32(168, 154, 160, 255);
constexpr ImU32 kSection = IM_COL32(139, 122, 130, 255);
constexpr ImU32 kSwitchOff = IM_COL32(58, 50, 54, 255);
constexpr ImU32 kSwitchOn = IM_COL32(34, 197, 94, 255);
constexpr ImU32 kKnob = IM_COL32(246, 243, 244, 255);
constexpr ImU32 kDivider = IM_COL32(255, 255, 255, 14);
constexpr ImU32 kDanger = IM_COL32(240, 96, 112, 255);

const char* kTabs[] = {"Home", "Visuals", "Aimbot", "FPS", "Character", "Config", "Creditos"};

std::unordered_map<ImGuiID, ToggleAnimation> g_animations;

int lerp_int(int a, int b, float t) {
    return static_cast<int>(a + (b - a) * t + 0.5f);
}

float clampf(float value, float low, float high) {
    return value < low ? low : (value > high ? high : value);
}

void log_control_rect(const char* name, const ImVec2& min, const ImVec2& max, const ImVec2& origin_screen) {
    static std::unordered_map<std::string, ImVec4> last_rect;
    static std::unordered_map<std::string, uint64_t> last_log_ms;
    const uint64_t now = GetTickCount64();

    ImVec4& previous = last_rect[name];
    const bool changed = std::fabs(previous.x - min.x) > 0.5f || std::fabs(previous.y - min.y) > 0.5f ||
                         std::fabs(previous.z - max.x) > 0.5f || std::fabs(previous.w - max.y) > 0.5f;
    auto it = last_log_ms.find(name);
    const bool first = it == last_log_ms.end();
    if (!changed && !first)
        return;
    if (!first && now - it->second < 300)
        return;

    previous = ImVec4(min.x, min.y, max.x, max.y);
    last_log_ms[name] = now;
    Log::get().info("panel control %s rect=%.0f,%.0f,%.0f,%.0f screen=%.0f,%.0f", name, min.x, min.y, max.x, max.y,
                    origin_screen.x + min.x, origin_screen.y + min.y);
}

// ---- small vector icons (no icon font, no external assets) -----------------

void draw_icon(ImDrawList* draw, int kind, const ImVec2& center, float s, ImU32 color) {
    const float thickness = 1.4f * s;
    const ImVec2 c = center;
    switch (kind) {
    case 0: // home
        draw->AddTriangleFilled(ImVec2(c.x - 5.0f * s, c.y), ImVec2(c.x, c.y - 5.0f * s),
                                ImVec2(c.x + 5.0f * s, c.y), color);
        draw->AddRect(ImVec2(c.x - 3.5f * s, c.y), ImVec2(c.x + 3.5f * s, c.y + 4.5f * s), color, 1.0f * s, 0,
                      thickness);
        break;
    case 1: // visuals / eye
        draw->AddCircle(c, 4.4f * s, color, 18, thickness);
        draw->AddCircleFilled(c, 1.6f * s, color, 12);
        break;
    case 2: // aimbot / crosshair
        draw->AddCircle(c, 4.4f * s, color, 18, thickness);
        draw->AddLine(ImVec2(c.x - 6.5f * s, c.y), ImVec2(c.x - 3.0f * s, c.y), color, thickness);
        draw->AddLine(ImVec2(c.x + 3.0f * s, c.y), ImVec2(c.x + 6.5f * s, c.y), color, thickness);
        draw->AddLine(ImVec2(c.x, c.y - 6.5f * s), ImVec2(c.x, c.y - 3.0f * s), color, thickness);
        draw->AddLine(ImVec2(c.x, c.y + 3.0f * s), ImVec2(c.x, c.y + 6.5f * s), color, thickness);
        break;
    case 3: // fps / bars
        draw->AddRectFilled(ImVec2(c.x - 4.8f * s, c.y + 0.4f * s), ImVec2(c.x - 2.6f * s, c.y + 4.6f * s), color);
        draw->AddRectFilled(ImVec2(c.x - 1.1f * s, c.y - 2.2f * s), ImVec2(c.x + 1.1f * s, c.y + 4.6f * s), color);
        draw->AddRectFilled(ImVec2(c.x + 2.6f * s, c.y - 4.8f * s), ImVec2(c.x + 4.8f * s, c.y + 4.6f * s), color);
        break;
    case 4: // character
        draw->AddCircleFilled(ImVec2(c.x, c.y - 2.6f * s), 2.3f * s, color, 12);
        draw->PathArcTo(ImVec2(c.x, c.y + 5.8f * s), 4.8f * s, 3.14159f, 6.28318f, 12);
        draw->PathStroke(color, 0, thickness);
        break;
    case 5: // config / gear
        draw->AddCircle(c, 3.6f * s, color, 18, thickness);
        draw->AddLine(ImVec2(c.x - 5.6f * s, c.y), ImVec2(c.x - 3.3f * s, c.y), color, thickness);
        draw->AddLine(ImVec2(c.x + 3.3f * s, c.y), ImVec2(c.x + 5.6f * s, c.y), color, thickness);
        draw->AddLine(ImVec2(c.x, c.y - 5.6f * s), ImVec2(c.x, c.y - 3.3f * s), color, thickness);
        draw->AddLine(ImVec2(c.x, c.y + 3.3f * s), ImVec2(c.x, c.y + 5.6f * s), color, thickness);
        draw->AddCircleFilled(c, 1.0f * s, color, 8);
        break;
    default: // creditos / info
        draw->AddCircle(c, 5.0f * s, color, 20, thickness);
        draw->AddCircleFilled(ImVec2(c.x, c.y - 2.7f * s), 1.0f * s, color, 8);
        draw->AddLine(ImVec2(c.x, c.y - 0.6f * s), ImVec2(c.x, c.y + 3.0f * s), color, thickness);
        break;
    }
}

void draw_reaper_mark(ImDrawList* draw, const ImVec2& c, float s) {
    draw->AddCircleFilled(c, 5.0f * s, kAccent, 18);
    draw->AddCircleFilled(ImVec2(c.x - 1.8f * s, c.y - 0.7f * s), 1.1f * s, kTitleBg, 10);
    draw->AddCircleFilled(ImVec2(c.x + 1.8f * s, c.y - 0.7f * s), 1.1f * s, kTitleBg, 10);
    draw->AddRectFilled(ImVec2(c.x - 2.1f * s, c.y + 3.2f * s), ImVec2(c.x + 2.1f * s, c.y + 5.3f * s), kAccent,
                        1.0f * s);
}

// ---- content building blocks ----------------------------------------------

void section_title(const char* text, float s) {
    ImGui::Dummy(ImVec2(0.0f, 8.0f * s));
    const ImVec2 pos = ImGui::GetCursorScreenPos();
    ImGui::GetWindowDrawList()->AddText(ImGui::GetFont(), 10.5f * s, pos, kSection, text);
    ImGui::Dummy(ImVec2(0.0f, 17.0f * s));
}

void body_text(const char* text, float s, ImU32 color = kTextMuted) {
    ImGui::PushStyleColor(ImGuiCol_Text, ImGui::ColorConvertU32ToFloat4(color));
    ImGui::PushTextWrapPos(ImGui::GetCursorPosX() + ImGui::GetContentRegionAvail().x);
    ImGui::TextWrapped("%s", text);
    ImGui::PopTextWrapPos();
    ImGui::PopStyleColor();
    ImGui::Dummy(ImVec2(0.0f, 4.0f * s));
}

void text_line(const char* label, const char* value, float s, ImU32 value_color = kTextMuted) {
    const ImVec2 pos = ImGui::GetCursorScreenPos();
    const float width = ImGui::GetContentRegionAvail().x;
    ImDrawList* draw = ImGui::GetWindowDrawList();
    draw->AddText(pos, kTextMuted, label);
    const float value_width = ImGui::CalcTextSize(value).x;
    draw->AddText(ImVec2(pos.x + width - value_width, pos.y), value_color, value);
    ImGui::Dummy(ImVec2(0.0f, 17.0f * s));
}

bool switch_row(const char* id, const char* label, bool& value, float s, const ImVec2& origin,
                const char* log_name) {
    const ImGuiID animation_id = ImGui::GetID(id);
    ImGui::PushID(id);
    const ImVec2 row_min = ImGui::GetCursorScreenPos();
    const float width = ImGui::GetContentRegionAvail().x;
    const float height = kRowHeight * s;
    ImGui::InvisibleButton("##switch", ImVec2(width, height));
    const bool hovered = ImGui::IsItemHovered();
    const bool clicked = ImGui::IsItemClicked(ImGuiMouseButton_Left);
    ImGui::PopID();

    bool changed = false;
    if (clicked) {
        value = !value;
        changed = true;
        Log::get().info("panel switch %s = %d (%s)", log_name, value ? 1 : 0, label);
    }

    ImDrawList* draw = ImGui::GetWindowDrawList();
    if (hovered)
        draw->AddRectFilled(row_min, ImVec2(row_min.x + width, row_min.y + height), IM_COL32(255, 255, 255, 7),
                            5.0f * s);
    const float font_size = ImGui::GetFontSize();
    draw->AddText(ImVec2(row_min.x, row_min.y + (height - font_size) * 0.5f), kText, label);

    ToggleAnimation& animation = g_animations[animation_id];
    const float target = value ? 1.0f : 0.0f;
    const float step = ImGui::GetIO().DeltaTime / kSwitchAnimationSeconds;
    animation.value += clampf(target - animation.value, -step, step);
    animation.value = clampf(animation.value, 0.0f, 1.0f);

    const float track_width = 30.0f * s;
    const float track_height = 16.0f * s;
    const ImVec2 track_min(row_min.x + width - track_width - 2.0f * s, row_min.y + (height - track_height) * 0.5f);
    const ImVec2 track_max(track_min.x + track_width, track_min.y + track_height);
    const ImU32 track_color = IM_COL32(lerp_int(58, 34, animation.value), lerp_int(50, 197, animation.value),
                                       lerp_int(54, 94, animation.value), 255);
    draw->AddRectFilled(track_min, track_max, track_color, track_height * 0.5f);

    const float eased = animation.value * animation.value * (3.0f - 2.0f * animation.value);
    const float knob_radius = 6.0f * s;
    const float knob_x =
        track_min.x + 2.0f * s + knob_radius + eased * (track_width - 4.0f * s - knob_radius * 2.0f);
    draw->AddCircleFilled(ImVec2(knob_x, track_min.y + track_height * 0.5f), knob_radius, kKnob, 20);

    log_control_rect(log_name, row_min, ImVec2(row_min.x + width, row_min.y + height), origin);
    return changed;
}

bool slider_row(const char* id, const char* label, float& value, float min_value, float max_value, const char* format,
                float s, const ImVec2& origin, const char* log_name) {
    ImGui::PushID(id);
    const ImVec2 row_min = ImGui::GetCursorScreenPos();
    const float width = ImGui::GetContentRegionAvail().x;
    const float height = kRowHeight * s;
    const float font_size = ImGui::GetFontSize();
    ImDrawList* draw = ImGui::GetWindowDrawList();

    draw->AddText(ImVec2(row_min.x, row_min.y + (height - font_size) * 0.5f), kText, label);

    const float value_width = 48.0f * s;
    const float track_width = 90.0f * s;
    const float track_x = row_min.x + width - value_width - track_width - 6.0f * s;
    const float track_y = row_min.y + height * 0.5f;

    ImGui::SetCursorScreenPos(ImVec2(track_x - 6.0f * s, row_min.y));
    ImGui::InvisibleButton("##slider", ImVec2(track_width + 12.0f * s + value_width, height));
    const bool active = ImGui::IsItemActive();
    const bool hovered = ImGui::IsItemHovered();

    bool changed = false;
    if (active) {
        const float t = clampf((ImGui::GetIO().MousePos.x - track_x) / track_width, 0.0f, 1.0f);
        const float next = min_value + t * (max_value - min_value);
        if (std::fabs(next - value) > 0.0001f) {
            value = next;
            changed = true;
        }
    }
    if (ImGui::IsItemDeactivated())
        Log::get().info("panel slider %s = %.2f (%s)", log_name, value, label);

    const float t = clampf((value - min_value) / (max_value - min_value), 0.0f, 1.0f);
    draw->AddRectFilled(ImVec2(track_x, track_y - 1.0f * s), ImVec2(track_x + track_width, track_y + 1.0f * s),
                        kSwitchOff, 1.0f * s);
    draw->AddRectFilled(ImVec2(track_x, track_y - 1.0f * s), ImVec2(track_x + track_width * t, track_y + 1.0f * s),
                        kAccent, 1.0f * s);
    draw->AddCircleFilled(ImVec2(track_x + track_width * t, track_y), 4.5f * s, kKnob, 16);

    char buffer[64];
    std::snprintf(buffer, sizeof(buffer), format, value);
    const float text_width = ImGui::CalcTextSize(buffer).x;
    draw->AddText(ImVec2(row_min.x + width - text_width, row_min.y + (height - font_size) * 0.5f),
                  active || hovered ? kText : kTextMuted, buffer);

    log_control_rect(log_name, row_min, ImVec2(row_min.x + width, row_min.y + height), origin);
    ImGui::PopID();
    return changed;
}

bool button_row(const char* id, const char* label, float s, const ImVec2& origin, const char* log_name) {
    ImGui::PushID(id);
    const ImVec2 row_min = ImGui::GetCursorScreenPos();
    const float width = ImGui::GetContentRegionAvail().x;
    const float height = kRowHeight * s;
    ImGui::InvisibleButton("##button", ImVec2(width, height));
    const bool hovered = ImGui::IsItemHovered();
    const bool clicked = ImGui::IsItemClicked(ImGuiMouseButton_Left);
    ImGui::PopID();

    ImDrawList* draw = ImGui::GetWindowDrawList();
    const ImU32 fill = hovered ? IM_COL32(58, 32, 40, 255) : IM_COL32(43, 25, 31, 255);
    draw->AddRectFilled(row_min, ImVec2(row_min.x + width, row_min.y + height), fill, 6.0f * s);
    draw->AddRect(row_min, ImVec2(row_min.x + width, row_min.y + height), IM_COL32(255, 255, 255, 12), 6.0f * s,
                  0, 1.0f * s);

    const ImVec2 text_size = ImGui::CalcTextSize(label);
    draw->AddText(ImVec2(row_min.x + (width - text_size.x) * 0.5f, row_min.y + (height - text_size.y) * 0.5f),
                  hovered ? kText : kTextMuted, label);

    log_control_rect(log_name, row_min, ImVec2(row_min.x + width, row_min.y + height), origin);
    return clicked;
}

bool choice_row(const char* id, const char* label, int& mode, int value, float s, const ImVec2& origin,
                const char* log_name) {
    ImGui::PushID(id);
    const ImVec2 row_min = ImGui::GetCursorScreenPos();
    const float width = ImGui::GetContentRegionAvail().x;
    const float height = kRowHeight * s;
    ImGui::InvisibleButton("##choice", ImVec2(width, height));
    const bool hovered = ImGui::IsItemHovered();
    const bool clicked = ImGui::IsItemClicked(ImGuiMouseButton_Left);
    ImGui::PopID();

    bool changed = false;
    if (clicked) {
        mode = value;
        changed = true;
        Log::get().info("panel choice %s selected (%s)", log_name, label);
    }

    ImDrawList* draw = ImGui::GetWindowDrawList();
    if (hovered)
        draw->AddRectFilled(row_min, ImVec2(row_min.x + width, row_min.y + height), IM_COL32(255, 255, 255, 7),
                            5.0f * s);
    const float font_size = ImGui::GetFontSize();
    draw->AddText(ImVec2(row_min.x, row_min.y + (height - font_size) * 0.5f), kText, label);

    const ImVec2 center(row_min.x + width - 9.0f * s, row_min.y + height * 0.5f);
    const bool selected = mode == value;
    draw->AddCircle(center, 5.0f * s, selected ? kAccent : IM_COL32(120, 108, 114, 255), 18, 1.4f * s);
    if (selected)
        draw->AddCircleFilled(center, 2.5f * s, kAccent, 12);

    log_control_rect(log_name, row_min, ImVec2(row_min.x + width, row_min.y + height), origin);
    return changed;
}

// ---- tabs -----------------------------------------------------------------

void draw_home(const Snapshot& snapshot, float s) {
    section_title("REAPER AIM", s);
    body_text("Interface preview for the external read-only ESP. Nothing on this page writes to the game.", s);
    body_text("Use the sidebar to navigate. F1 hides or shows the menu, F2 exits.", s);

    section_title("STATUS", s);
    text_line("Client", snapshot.attached ? "attached" : "not attached", s,
              snapshot.attached ? kSwitchOn : kTextMuted);
    text_line("Offset profile", snapshot.offsets_trusted ? "verified" : "mismatch", s,
              snapshot.offsets_trusted ? kSwitchOn : kDanger);
    text_line("World", snapshot.world_valid ? "resolved" : "waiting", s,
              snapshot.world_valid ? kSwitchOn : kTextMuted);

    char buffer[96];
    std::snprintf(buffer, sizeof(buffer), "%d / %d", snapshot.players_drawn, snapshot.players_found);
    text_line("Drawn / players", buffer, s);

    std::snprintf(buffer, sizeof(buffer), "gen %llu", static_cast<unsigned long long>(snapshot.world_generation));
    text_line("World generation", buffer, s);
    text_line("Projection", projection_mode_name(snapshot.projection_mode), s);

    if (!snapshot.status.empty())
        body_text(snapshot.status.c_str(), s, snapshot.offsets_trusted ? kTextMuted : kDanger);

    section_title("NOTICE", s);
    body_text("The Aimbot and FPS tabs are visual previews. They do not move the camera, change graphics or write "
              "to Roblox.",
              s);
}

void draw_visuals(Settings& settings, bool& changed, float s, const ImVec2& origin) {
    section_title("MASTER", s);
    changed |= switch_row("visuals_enable", "Enable ESP", settings.esp_enabled, s, origin, "visuals_enable");
    changed |= switch_row("visuals_team", "Team Check", settings.hide_allies, s, origin, "visuals_team_check");

    section_title("ELEMENTOS", s);
    changed |= switch_row("visuals_boxes", "Boxes", settings.box, s, origin, "visuals_boxes");
    changed |= switch_row("visuals_skeleton", "Skeleton", settings.skeleton, s, origin, "visuals_skeleton");
    changed |= switch_row("visuals_names", "Names", settings.show_name, s, origin, "visuals_names");
    changed |= switch_row("visuals_health", "Health Bar", settings.health_bar, s, origin, "visuals_health");
    changed |= switch_row("visuals_distance", "Distance", settings.show_distance, s, origin, "visuals_distance");
    changed |= switch_row("visuals_tracers", "Tracers", settings.tracers, s, origin, "visuals_tracers");
    changed |= switch_row("visuals_fill", "Box Fill", settings.box_fill, s, origin, "visuals_box_fill");

    section_title("CONFIGURACOES", s);
    changed |= slider_row("visuals_maxdist", "Max Distance", settings.max_distance, 20.0f, 2000.0f, "%.0f m", s,
                          origin, "visuals_max_distance");
}

void draw_aimbot(PanelState& state, bool& changed, float s, const ImVec2& origin) {
    UiState& ui = state.ui;
    section_title("CONTROLE", s);
    changed |= switch_row("aim_enable", "Enable Aimbot", ui.aim_enable, s, origin, "aim_enable");
    changed |= switch_row("aim_toggle", "Toggle Mode (Mobile Friendly)", ui.aim_toggle_mode, s, origin, "aim_toggle_mode");
    changed |= switch_row("aim_team", "Team Check", ui.aim_team_check, s, origin, "aim_team_check");
    changed |= switch_row("aim_visible", "Visible Check (Wall Check)", ui.aim_visible_check, s, origin,
                          "aim_visible_check");
    changed |= switch_row("aim_prediction", "Prediction", ui.aim_prediction, s, origin, "aim_prediction");

    section_title("MODO", s);
    changed |= choice_row("aim_mode_camera", "Camera", ui.aim_mode, 0, s, origin, "aim_mode_camera");
    changed |= choice_row("aim_mode_mouse", "Mouse", ui.aim_mode, 1, s, origin, "aim_mode_mouse");
    changed |= choice_row("aim_mode_silent", "Silent", ui.aim_mode, 2, s, origin, "aim_mode_silent");

    section_title("NOTES", s);
    body_text("These controls are visual only in this read-only build. No camera movement, no input injection and "
              "no memory writes are performed.",
              s);
    body_text("Scroll the content area for the rest of the preview content.", s);
    ImGui::Dummy(ImVec2(0.0f, 18.0f * s));
}

void draw_fps(PanelState& state, bool& changed, float s, const ImVec2& origin) {
    UiState& ui = state.ui;
    section_title("VISUALS", s);
    changed |= switch_row("fps_fullbright", "Fullbright", ui.fps_fullbright, s, origin, "fps_fullbright");
    changed |= switch_row("fps_nofog", "No Fog", ui.fps_no_fog, s, origin, "fps_no_fog");
    changed |= switch_row("fps_low", "Low Graphics (max. FPS)", ui.fps_low_graphics, s, origin, "fps_low_graphics");

    section_title("CAMERA", s);
    changed |= switch_row("fps_customfov", "Custom FOV", ui.fps_custom_fov, s, origin, "fps_custom_fov");
    changed |= slider_row("fps_fov", "FOV Value", ui.fps_fov, 50.0f, 120.0f, "%.0f deg", s, origin, "fps_fov_value");
    if (button_row("fps_resetfov", "Reset Camera FOV", s, origin, "fps_reset_fov")) {
        ui.fps_fov = 70.0f;
        changed = true;
        Log::get().info("panel button fps_reset_fov -> 70");
    }

    section_title("CROSSHAIR", s);
    changed |= switch_row("fps_crosshair", "Enable Crosshair", ui.fps_crosshair, s, origin, "fps_crosshair");
    changed |= slider_row("fps_crosssize", "Tamanho", ui.crosshair_size, 4.0f, 40.0f, "%.0f px", s, origin,
                          "fps_crosshair_size");
}

void draw_character(const Snapshot& snapshot, float s) {
    section_title("CHARACTER", s);
    body_text("Read-only preview. This build never modifies WalkSpeed, JumpPower or Humanoid state.", s);

    const PlayerSnapshot* local = nullptr;
    for (const PlayerSnapshot& player : snapshot.players) {
        if (player.local) {
            local = &player;
            break;
        }
    }

    section_title("LOCAL PLAYER", s);
    if (!local) {
        body_text("No local character detected.", s);
        return;
    }
    text_line("Name", local->display_name.empty() ? local->name.c_str() : local->display_name.c_str(), s);
    char buffer[64];
    std::snprintf(buffer, sizeof(buffer), "%.0f / %.0f", local->health, local->max_health);
    text_line("Health", buffer, s);
    std::snprintf(buffer, sizeof(buffer), "%.1f m", local->distance);
    text_line("Distance", buffer, s);
    text_line("Team", local->relation == TeamRelation::Ally ? "ally" : "unknown", s);
}

void draw_config(bool& reset_position, const Snapshot& snapshot, float s, const ImVec2& origin) {
    section_title("WINDOW", s);
    if (button_row("config_resetpos", "Reset Window Position", s, origin, "config_reset_position")) {
        reset_position = true;
        Log::get().info("panel button config_reset_position");
    }
    text_line("UI scale", "auto (DPI)", s);

    section_title("BUILD", s);
    char buffer[96];
    std::snprintf(buffer, sizeof(buffer), "0x%llX", static_cast<unsigned long long>(snapshot.module_base));
    text_line("Module base", buffer, s);
    std::snprintf(buffer, sizeof(buffer), "0x%llX", static_cast<unsigned long long>(snapshot.data_model));
    text_line("DataModel", buffer, s);
    text_line("Profile", "version-11f155f3450f4c8e", s);

    section_title("EXAMPLE", s);
    body_text("Config example content. Extra persistence and input options can be added here later.", s);
    body_text("The menu position is saved with the runtime settings.", s);
}

void draw_credits(float s) {
    section_title("REAPER AIM", s);
    body_text("External read-only ESP interface.", s, kText);
    section_title("CREDITS", s);
    body_text("Menu and ESP: rbx_esp 1.0.0", s);
    body_text("Rendering: Dear ImGui 1.91.8 + DirectX 11", s);
    body_text("Offsets: RbxDumperV2 profile 2026-10-15 (verified builds only)", s);
    section_title("PRINCIPLES", s);
    body_text("No DLL injection. No WriteProcessMemory. No kernel driver.", s);
}

} // namespace

void apply_style(float ui_scale) {
    const float s = ui_scale > 0.0f ? ui_scale : 1.0f;
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowPadding = ImVec2(0.0f, 0.0f);
    style.WindowRounding = 8.0f * s;
    style.ChildRounding = 6.0f * s;
    style.FrameRounding = 6.0f * s;
    style.PopupRounding = 6.0f * s;
    style.GrabRounding = 4.0f * s;
    style.ScrollbarRounding = 3.0f * s;
    style.ScrollbarSize = 6.0f * s;
    style.WindowBorderSize = 1.0f * s;
    style.FrameBorderSize = 0.0f;
    style.ItemSpacing = ImVec2(8.0f * s, 3.0f * s);
    style.ItemInnerSpacing = ImVec2(6.0f * s, 4.0f * s);

    ImVec4* colors = style.Colors;
    colors[ImGuiCol_WindowBg] = ImVec4(0.102f, 0.059f, 0.071f, 0.97f);
    colors[ImGuiCol_ChildBg] = ImVec4(0.0f, 0.0f, 0.0f, 0.0f);
    colors[ImGuiCol_PopupBg] = ImVec4(0.086f, 0.047f, 0.055f, 0.98f);
    colors[ImGuiCol_Border] = ImVec4(0.42f, 0.30f, 0.34f, 0.55f);
    colors[ImGuiCol_Text] = ImVec4(0.949f, 0.925f, 0.933f, 1.0f);
    colors[ImGuiCol_TextDisabled] = ImVec4(0.55f, 0.50f, 0.53f, 1.0f);
    colors[ImGuiCol_FrameBg] = ImVec4(0.16f, 0.11f, 0.13f, 1.0f);
    colors[ImGuiCol_ScrollbarBg] = ImVec4(0.0f, 0.0f, 0.0f, 0.0f);
    colors[ImGuiCol_ScrollbarGrab] = ImVec4(0.36f, 0.26f, 0.30f, 1.0f);
    colors[ImGuiCol_ScrollbarGrabHovered] = ImVec4(0.46f, 0.33f, 0.38f, 1.0f);
    colors[ImGuiCol_ScrollbarGrabActive] = ImVec4(0.58f, 0.38f, 0.45f, 1.0f);
    colors[ImGuiCol_Button] = ImVec4(0.16f, 0.10f, 0.12f, 1.0f);
    colors[ImGuiCol_ButtonHovered] = ImVec4(0.23f, 0.13f, 0.16f, 1.0f);
    colors[ImGuiCol_ButtonActive] = ImVec4(0.29f, 0.15f, 0.19f, 1.0f);
    colors[ImGuiCol_Separator] = ImVec4(1.0f, 1.0f, 1.0f, 0.06f);
}

Outcome draw(Settings& settings, PanelState& state, const Snapshot& snapshot, ImVec2 display, ImVec2 origin_screen) {
    Outcome outcome;
    const float s = state.ui_scale > 0.0f ? state.ui_scale : 1.0f;
    const float width = kWidth * s;
    const float title_height = kTitleHeight * s;

    const float normal_height = std::min(kHeight * s, std::max(220.0f * s, display.y - 32.0f * s));
    const float expanded_height = std::min(display.y - 32.0f * s, 700.0f * s);
    float height = state.ui.minimized ? title_height : (state.ui.maximized ? expanded_height : normal_height);
    height = clampf(height, title_height, std::max(title_height, display.y - 16.0f * s));

    if (state.x < 0.0f)
        state.x = display.x - width - 24.0f * s;
    if (state.y < 0.0f)
        state.y = (display.y - height) * 0.5f - 30.0f * s;

    state.x = clampf(state.x, -width + 80.0f * s, std::max(-width + 80.0f * s, display.x - 80.0f * s));
    state.y = clampf(state.y, 0.0f, std::max(0.0f, display.y - title_height));

    // Dragging is applied before the window position is submitted. One frame of
    // latency is invisible and keeps the proxy and the drawing in sync.
    if (state.dragging) {
        if (ImGui::IsMouseDown(ImGuiMouseButton_Left)) {
            const ImVec2 delta = ImGui::GetIO().MouseDelta;
            state.x += delta.x;
            state.y += delta.y;
        } else {
            state.dragging = false;
            Log::get().info("panel drag end at %.0f,%.0f", state.x, state.y);
        }
    }
    state.x = clampf(state.x, -width + 80.0f * s, std::max(-width + 80.0f * s, display.x - 80.0f * s));
    state.y = clampf(state.y, 0.0f, std::max(0.0f, display.y - height));

    // Soft shadow behind the floating window.
    {
        ImDrawList* background = ImGui::GetBackgroundDrawList();
        const ImVec2 p0(state.x, state.y);
        const ImVec2 p1(state.x + width, state.y + height);
        for (int layer = 6; layer >= 1; --layer) {
            const float grow = layer * 1.5f * s;
            const int alpha = 10 - layer;
            background->AddRectFilled(ImVec2(p0.x - grow, p0.y - grow), ImVec2(p1.x + grow, p1.y + grow),
                                      IM_COL32(0, 0, 0, alpha), 8.0f * s + grow);
        }
    }

    ImGui::SetNextWindowSize(ImVec2(width, height), ImGuiCond_Always);
    ImGui::SetNextWindowPos(ImVec2(state.x, state.y), ImGuiCond_Always);
    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(0.0f, 0.0f));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 8.0f * s);
    ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.0f * s);
    ImGui::PushStyleColor(ImGuiCol_WindowBg, ImGui::ColorConvertU32ToFloat4(kWindowBg));
    ImGui::PushStyleColor(ImGuiCol_Border, ImVec4(0.42f, 0.30f, 0.34f, 0.55f));

    const ImGuiWindowFlags flags = ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize |
                                   ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoSavedSettings |
                                   ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoNav |
                                   ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_NoScrollWithMouse;

    ImGui::Begin("##reaper_aim", nullptr, flags);
    const ImVec2 window_pos = ImGui::GetWindowPos();
    ImDrawList* draw = ImGui::GetWindowDrawList();

    // ---- title bar --------------------------------------------------------
    draw->AddRectFilled(window_pos, ImVec2(window_pos.x + width, window_pos.y + title_height), kTitleBg,
                        8.0f * s, ImDrawFlags_RoundCornersTop);
    draw->AddLine(ImVec2(window_pos.x, window_pos.y + title_height),
                  ImVec2(window_pos.x + width, window_pos.y + title_height), kDivider, 1.0f * s);

    const float button_size = 20.0f * s;
    const float button_gap = 4.0f * s;
    const float buttons_width = button_size * 3.0f + button_gap * 2.0f;
    const float drag_width = std::max(20.0f * s, width - buttons_width - 24.0f * s);

    ImGui::SetCursorScreenPos(ImVec2(window_pos.x + 4.0f * s, window_pos.y + 4.0f * s));
    ImGui::InvisibleButton("##title_drag", ImVec2(drag_width, title_height - 8.0f * s));
    const bool title_hovered = ImGui::IsItemHovered();
    if (ImGui::IsItemActive() && !state.dragging) {
        state.dragging = true;
        Log::get().info("panel drag start at %.0f,%.0f", state.x, state.y);
    }
    if (title_hovered)
        ImGui::SetMouseCursor(ImGuiMouseCursor_ResizeAll);

    draw_reaper_mark(draw, ImVec2(window_pos.x + 16.0f * s, window_pos.y + title_height * 0.5f), s);
    draw->AddText(ImGui::GetFont(), 12.0f * s,
                  ImVec2(window_pos.x + 27.0f * s, window_pos.y + (title_height - 12.0f * s) * 0.5f), kText,
                  "Reaper Aim");

    const float buttons_x = window_pos.x + width - 10.0f * s - buttons_width;
    const float buttons_y = window_pos.y + (title_height - button_size) * 0.5f;
    const ImU32 button_color = IM_COL32(196, 182, 187, 255);

    ImGui::SetCursorScreenPos(ImVec2(buttons_x, buttons_y));
    ImGui::InvisibleButton("##win_min", ImVec2(button_size, button_size));
    const bool min_hovered = ImGui::IsItemHovered();
    const bool min_clicked = ImGui::IsItemClicked(ImGuiMouseButton_Left);
    log_control_rect("window_min", ImVec2(buttons_x, buttons_y),
                     ImVec2(buttons_x + button_size, buttons_y + button_size), origin_screen);

    ImGui::SetCursorScreenPos(ImVec2(buttons_x + button_size + button_gap, buttons_y));
    ImGui::InvisibleButton("##win_max", ImVec2(button_size, button_size));
    const bool max_hovered = ImGui::IsItemHovered();
    const bool max_clicked = ImGui::IsItemClicked(ImGuiMouseButton_Left);
    log_control_rect("window_max", ImVec2(buttons_x + button_size + button_gap, buttons_y),
                     ImVec2(buttons_x + button_size * 2.0f + button_gap, buttons_y + button_size), origin_screen);

    ImGui::SetCursorScreenPos(ImVec2(buttons_x + (button_size + button_gap) * 2.0f, buttons_y));
    ImGui::InvisibleButton("##win_close", ImVec2(button_size, button_size));
    const bool close_hovered = ImGui::IsItemHovered();
    const bool close_clicked = ImGui::IsItemClicked(ImGuiMouseButton_Left);
    log_control_rect("window_close", ImVec2(buttons_x + (button_size + button_gap) * 2.0f, buttons_y),
                     ImVec2(buttons_x + (button_size + button_gap) * 2.0f + button_size, buttons_y + button_size),
                     origin_screen);

    auto draw_button_hover = [&](bool hovered, float x, bool danger) {
        if (!hovered)
            return;
        draw->AddRectFilled(ImVec2(x, buttons_y), ImVec2(x + button_size, buttons_y + button_size),
                            danger ? IM_COL32(150, 42, 56, 200) : IM_COL32(255, 255, 255, 16), 4.0f * s);
    };
    draw_button_hover(min_hovered, buttons_x, false);
    draw_button_hover(max_hovered, buttons_x + button_size + button_gap, false);
    draw_button_hover(close_hovered, buttons_x + (button_size + button_gap) * 2.0f, true);

    const ImVec2 min_center(buttons_x + button_size * 0.5f, buttons_y + button_size * 0.5f);
    draw->AddLine(ImVec2(min_center.x - 4.0f * s, min_center.y), ImVec2(min_center.x + 4.0f * s, min_center.y),
                  button_color, 1.4f * s);

    const ImVec2 max_center(buttons_x + button_size + button_gap + button_size * 0.5f,
                            buttons_y + button_size * 0.5f);
    if (state.ui.maximized && !state.ui.minimized) {
        draw->AddRect(ImVec2(max_center.x - 5.0f * s, max_center.y - 4.0f * s),
                      ImVec2(max_center.x + 3.0f * s, max_center.y + 4.0f * s), button_color, 1.0f * s, 0,
                      1.2f * s);
        draw->AddRect(ImVec2(max_center.x - 3.0f * s, max_center.y - 2.0f * s),
                      ImVec2(max_center.x + 5.0f * s, max_center.y + 6.0f * s), button_color, 1.0f * s, 0,
                      1.2f * s);
    } else {
        draw->AddRect(ImVec2(max_center.x - 4.0f * s, max_center.y - 4.0f * s),
                      ImVec2(max_center.x + 4.0f * s, max_center.y + 4.0f * s), button_color, 1.0f * s, 0,
                      1.3f * s);
    }

    const ImVec2 close_center(buttons_x + (button_size + button_gap) * 2.0f + button_size * 0.5f,
                              buttons_y + button_size * 0.5f);
    draw->AddLine(ImVec2(close_center.x - 3.8f * s, close_center.y - 3.8f * s),
                  ImVec2(close_center.x + 3.8f * s, close_center.y + 3.8f * s), button_color, 1.4f * s);
    draw->AddLine(ImVec2(close_center.x - 3.8f * s, close_center.y + 3.8f * s),
                  ImVec2(close_center.x + 3.8f * s, close_center.y - 3.8f * s), button_color, 1.4f * s);

    if (min_clicked) {
        state.ui.minimized = !state.ui.minimized;
        if (!state.ui.minimized)
            state.ui.maximized = false;
        Log::get().info("window %s", state.ui.minimized ? "minimized" : "restored");
    }
    if (max_clicked) {
        state.ui.maximized = !state.ui.maximized;
        state.ui.minimized = false;
        Log::get().info("window %s", state.ui.maximized ? "maximized" : "restored");
    }
    if (close_clicked) {
        outcome.hide_requested = true;
        Log::get().info("window hidden by close button");
    }

    if (!state.ui.minimized) {
        // ---- sidebar ------------------------------------------------------
        draw->AddRectFilled(ImVec2(window_pos.x, window_pos.y + title_height),
                            ImVec2(window_pos.x + kSidebarWidth * s, window_pos.y + height), kSidebarBg, 8.0f * s,
                            ImDrawFlags_RoundCornersBottomLeft);
        draw->AddLine(ImVec2(window_pos.x + kSidebarWidth * s, window_pos.y + title_height),
                      ImVec2(window_pos.x + kSidebarWidth * s, window_pos.y + height), kDivider, 1.0f * s);

        const float tab_x = window_pos.x + 8.0f * s;
        const float tab_width = (kSidebarWidth - 16.0f) * s;
        float tab_y = window_pos.y + title_height + 10.0f * s;
        for (int i = 0; i < static_cast<int>(std::size(kTabs)); ++i) {
            const float tab_height = 26.0f * s;
            ImGui::SetCursorScreenPos(ImVec2(tab_x, tab_y));

            char id[32];
            std::snprintf(id, sizeof(id), "##tab_%d", i);
            ImGui::InvisibleButton(id, ImVec2(tab_width, tab_height));
            const bool hovered = ImGui::IsItemHovered();
            const bool clicked = ImGui::IsItemClicked(ImGuiMouseButton_Left);
            const bool active = state.ui.tab == i;

            if (hovered && !active)
                draw->AddRectFilled(ImVec2(tab_x, tab_y), ImVec2(tab_x + tab_width, tab_y + tab_height), kTabHover,
                                    6.0f * s);
            if (active) {
                draw->AddRectFilled(ImVec2(tab_x, tab_y), ImVec2(tab_x + tab_width, tab_y + tab_height), kTabActive,
                                    6.0f * s);
                draw->AddRectFilled(ImVec2(tab_x, tab_y + 5.0f * s), ImVec2(tab_x + 2.0f * s, tab_y + tab_height - 5.0f * s),
                                    kAccent, 1.0f * s);
            }

            const ImU32 icon_color = active ? kAccent : (hovered ? kText : kTextMuted);
            draw_icon(draw, i, ImVec2(tab_x + 17.0f * s, tab_y + tab_height * 0.5f), s, icon_color);
            const float font_size = ImGui::GetFontSize();
            draw->AddText(ImVec2(tab_x + 31.0f * s, tab_y + (tab_height - font_size) * 0.5f),
                          active || hovered ? kText : kTextMuted, kTabs[i]);

            char log_name[32];
            std::snprintf(log_name, sizeof(log_name), "tab_%s", kTabs[i]);
            log_control_rect(log_name, ImVec2(tab_x, tab_y), ImVec2(tab_x + tab_width, tab_y + tab_height),
                             origin_screen);

            if (clicked && !active) {
                state.ui.tab = i;
                state.ui.scroll_to_top = true;
                Log::get().info("panel tab %s", kTabs[i]);
            }
            tab_y += tab_height;
        }

        // ---- avatar -------------------------------------------------------
        const float avatar_center_y = window_pos.y + height - 22.0f * s;
        const ImVec2 avatar_center(window_pos.x + 20.0f * s, avatar_center_y);
        draw->AddCircleFilled(avatar_center, 9.0f * s, IM_COL32(58, 34, 41, 255), 20);
        draw->AddCircle(avatar_center, 9.0f * s, kAccent, 20, 1.2f * s);
        draw->AddText(ImGui::GetFont(), 10.0f * s, ImVec2(avatar_center.x - 3.0f * s, avatar_center.y - 5.0f * s),
                      kText, "R");
        const float avatar_font = ImGui::GetFontSize();
        draw->AddText(ImVec2(window_pos.x + 35.0f * s, avatar_center_y - avatar_font * 0.5f), kText, "Rafael");

        // ---- content ------------------------------------------------------
        const float content_x = window_pos.x + (kSidebarWidth + 12.0f) * s;
        const float content_y = window_pos.y + title_height + 8.0f * s;
        const float content_width = width - (kSidebarWidth + 24.0f) * s;
        const float content_height = height - title_height - 16.0f * s;

        ImGui::SetCursorScreenPos(ImVec2(content_x, content_y));
        ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(12.0f * s, 0.0f));
        ImGui::PushStyleColor(ImGuiCol_ChildBg, ImVec4(0.0f, 0.0f, 0.0f, 0.0f));
        ImGui::BeginChild("##content", ImVec2(content_width, content_height), ImGuiChildFlags_None,
                          ImGuiWindowFlags_NoBackground);
        if (state.ui.scroll_to_top) {
            ImGui::SetScrollY(0.0f);
            state.ui.scroll_to_top = false;
        }

        bool changed = false;
        switch (state.ui.tab) {
        case 0: draw_home(snapshot, s); break;
        case 1: draw_visuals(settings, changed, s, origin_screen); break;
        case 2: draw_aimbot(state, changed, s, origin_screen); break;
        case 3: draw_fps(state, changed, s, origin_screen); break;
        case 4: draw_character(snapshot, s); break;
        case 5: draw_config(outcome.reset_position, snapshot, s, origin_screen); break;
        default: draw_credits(s); break;
        }
        outcome.settings_changed |= changed;

        ImGui::EndChild();
        ImGui::PopStyleColor();
        ImGui::PopStyleVar();
    }

    const ImVec2 window_size = ImGui::GetWindowSize();
    ImGui::End();
    ImGui::PopStyleColor(2);
    ImGui::PopStyleVar(3);

    state.bounds_min_x = window_pos.x;
    state.bounds_min_y = window_pos.y;
    state.bounds_max_x = window_pos.x + window_size.x;
    state.bounds_max_y = window_pos.y + window_size.y;
    state.bounds_valid = true;

    if (window_size.y <= display.y - 8.0f * s) {
        state.y = clampf(state.y, 0.0f, display.y - window_size.y - 8.0f * s);
    } else {
        state.y = 0.0f;
    }
    state.x = clampf(state.x, -width + 80.0f * s, std::max(-width + 80.0f * s, display.x - 80.0f * s));

    static float last_min_x = -1.0f;
    static float last_min_y = -1.0f;
    static float last_max_x = -1.0f;
    static float last_max_y = -1.0f;
    static uint64_t last_bounds_log = 0;
    const uint64_t now = GetTickCount64();
    const bool moved = std::fabs(last_min_x - state.bounds_min_x) > 0.5f ||
                       std::fabs(last_min_y - state.bounds_min_y) > 0.5f ||
                       std::fabs(last_max_x - state.bounds_max_x) > 0.5f ||
                       std::fabs(last_max_y - state.bounds_max_y) > 0.5f;
    if (moved && now - last_bounds_log > 400) {
        last_bounds_log = now;
        last_min_x = state.bounds_min_x;
        last_min_y = state.bounds_min_y;
        last_max_x = state.bounds_max_x;
        last_max_y = state.bounds_max_y;
        Log::get().info("panel bounds %.0f,%.0f,%.0f,%.0f", state.bounds_min_x, state.bounds_min_y,
                        state.bounds_max_x, state.bounds_max_y);
    }

    if (outcome.reset_position)
        state.ui.minimized = false;

    return outcome;
}

} // namespace panel
