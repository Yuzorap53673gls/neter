// esp.cpp — boxes, names, health, distance, tracers and skeletons.

#include "esp.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <iterator>

#include "math3d.h"

namespace {

constexpr ImU32 kShadow = IM_COL32(0, 0, 0, 190);
constexpr ImU32 kTextDim = IM_COL32(196, 199, 210, 235);

ImU32 color_from(const float rgba[4]) {
    return ImGui::ColorConvertFloat4ToU32(ImVec4(rgba[0], rgba[1], rgba[2], rgba[3]));
}

struct Projector {
    const Snapshot& snapshot;
    Vec2 viewport;

    bool project(const Vec3& world, Vec2& out, bool allow_offscreen = false) const {
        if (viewport.x <= 1.0f || viewport.y <= 1.0f)
            return false;
        switch (snapshot.projection_mode) {
        case ProjectionMode::RowVector:
        case ProjectionMode::ColumnVector:
            return world_to_screen(snapshot.view_matrix, snapshot.projection_mode, world, viewport, out, allow_offscreen);
        case ProjectionMode::Camera:
            return camera_to_screen(snapshot.camera_position, snapshot.camera_rotation, snapshot.camera_fov, viewport,
                                    world, out, allow_offscreen);
        default:
            return false;
        }
    }
};

void add_line_shadowed(ImDrawList* draw, ImVec2 a, ImVec2 b, ImU32 color, float thickness) {
    draw->AddLine(ImVec2(a.x + 1.0f, a.y + 1.0f), ImVec2(b.x + 1.0f, b.y + 1.0f), kShadow, thickness + 1.0f);
    draw->AddLine(a, b, color, thickness);
}

void add_rect_shadowed(ImDrawList* draw, ImVec2 min, ImVec2 max, ImU32 color, float thickness) {
    draw->AddRect(ImVec2(min.x + 1.0f, min.y + 1.0f), ImVec2(max.x + 1.0f, max.y + 1.0f), kShadow, 0.0f, 0, thickness + 1.0f);
    draw->AddRect(min, max, color, 0.0f, 0, thickness);
}

ImU32 with_alpha(ImU32 color, int alpha) {
    return (color & ~IM_COL32_A_MASK) | (static_cast<ImU32>(alpha) << IM_COL32_A_SHIFT);
}

void add_corner_box(ImDrawList* draw, ImVec2 min, ImVec2 max, ImU32 color, float thickness, bool shadow) {
    const float height = max.y - min.y;
    const float length = std::clamp(height * 0.22f, 4.0f, 20.0f);

    struct Segment {
        ImVec2 a;
        ImVec2 b;
    };
    const Segment segments[8] = {
        {{min.x, min.y}, {min.x + length, min.y}},
        {{min.x, min.y}, {min.x, min.y + length}},
        {{max.x, min.y}, {max.x - length, min.y}},
        {{max.x, min.y}, {max.x, min.y + length}},
        {{min.x, max.y}, {min.x + length, max.y}},
        {{min.x, max.y}, {min.x, max.y - length}},
        {{max.x, max.y}, {max.x - length, max.y}},
        {{max.x, max.y}, {max.x, max.y - length}},
    };
    for (const Segment& s : segments) {
        if (shadow)
            draw->AddLine(ImVec2(s.a.x + 1.0f, s.a.y + 1.0f), ImVec2(s.b.x + 1.0f, s.b.y + 1.0f), kShadow,
                          thickness + 1.0f);
        draw->AddLine(s.a, s.b, color, thickness);
    }
}

void add_text_outline(ImDrawList* draw, ImVec2 pos, ImU32 color, const char* text) {
    ImFont* font = ImGui::GetFont();
    const float size = ImGui::GetFontSize();
    draw->AddText(font, size, ImVec2(pos.x - 1.0f, pos.y - 1.0f), kShadow, text);
    draw->AddText(font, size, ImVec2(pos.x + 1.0f, pos.y - 1.0f), kShadow, text);
    draw->AddText(font, size, ImVec2(pos.x - 1.0f, pos.y + 1.0f), kShadow, text);
    draw->AddText(font, size, ImVec2(pos.x + 1.0f, pos.y + 1.0f), kShadow, text);
    draw->AddText(font, size, pos, color, text);
}

ImU32 health_color(float fraction) {
    if (fraction > 0.55f)
        return IM_COL32(96, 214, 128, 255);
    if (fraction > 0.25f)
        return IM_COL32(238, 202, 88, 255);
    return IM_COL32(233, 86, 92, 255);
}

void draw_skeleton(ImDrawList* draw, const Projector& projector, const PlayerSnapshot& player, ImU32 color) {
    static constexpr int r15_edges[][2] = {
        {0, 1}, {1, 2}, {1, 3}, {3, 4}, {4, 5}, {1, 6}, {6, 7}, {7, 8},
        {2, 9}, {9, 10}, {10, 11}, {2, 12}, {12, 13}, {13, 14},
    };
    static constexpr int r6_edges[][2] = {
        {0, 1}, {1, 3}, {1, 6}, {1, 9}, {1, 12},
    };

    const int (*edges)[2] = player.is_r15 ? r15_edges : r6_edges;
    const size_t count = player.is_r15 ? std::size(r15_edges) : std::size(r6_edges);

    for (size_t i = 0; i < count; ++i) {
        const BonePoint& a = player.bones[static_cast<size_t>(edges[i][0])];
        const BonePoint& b = player.bones[static_cast<size_t>(edges[i][1])];
        if (!a.valid || !b.valid)
            continue;
        Vec2 pa;
        Vec2 pb;
        if (!projector.project(a.position, pa, true) || !projector.project(b.position, pb, true))
            continue;
        add_line_shadowed(draw, ImVec2(pa.x, pa.y), ImVec2(pb.x, pb.y), color, 1.0f);
    }
}

} // namespace

namespace esp {

int draw(ImDrawList* draw, const Settings& settings, Snapshot& snapshot, Vec2 display) {
    snapshot.rejected_dead = 0;
    snapshot.rejected_distance = 0;
    snapshot.rejected_team = 0;
    if (!draw || !settings.esp_enabled || !snapshot.offsets_trusted || !snapshot.world_valid)
        return 0;
    if (snapshot.players.empty())
        return 0;

    Projector projector{snapshot, snapshot.viewport.x > 1.0f ? snapshot.viewport : display};
    const Vec2 viewport = projector.viewport;
    const ImVec2 screen_center(viewport.x * 0.5f, viewport.y * 0.5f);

    draw->PushClipRect(ImVec2(0.0f, 0.0f), ImVec2(display.x, display.y), true);

    int drawn = 0;
    const float font_size = ImGui::GetFontSize();

    for (const PlayerSnapshot& player : snapshot.players) {
        if (settings.ignore_local && player.local)
            continue;
        if (settings.ignore_dead && !player.alive) {
            ++snapshot.rejected_dead;
            continue;
        }
        if (settings.hide_allies && player.relation == TeamRelation::Ally) {
            ++snapshot.rejected_team;
            continue;
        }
        if (settings.hide_unknown_team && player.relation == TeamRelation::Unknown) {
            ++snapshot.rejected_team;
            continue;
        }
        if (player.distance > settings.max_distance) {
            ++snapshot.rejected_distance;
            continue;
        }

        Vec2 head_screen;
        Vec2 feet_screen;
        const Vec3 head_top = player.head + Vec3(0.0f, player.head_size * 0.45f, 0.0f);
        const Vec3 feet = player.root - Vec3(0.0f, player.root_height * 0.5f, 0.0f);

        if (!projector.project(head_top, head_screen, true) || !projector.project(feet, feet_screen, true))
            continue;

        const float height = std::fabs(feet_screen.y - head_screen.y);
        if (height < 6.0f || height > 4000.0f)
            continue;
        float width = height * 0.55f;
        width = std::clamp(width, 3.0f, 900.0f);

        const float center_x = (head_screen.x + feet_screen.x) * 0.5f;
        ImVec2 box_min(center_x - width * 0.5f, std::min(head_screen.y, feet_screen.y));
        ImVec2 box_max(center_x + width * 0.5f, std::max(head_screen.y, feet_screen.y));

        if (box_max.x < -50.0f || box_min.x > display.x + 50.0f || box_max.y < -50.0f || box_min.y > display.y + 50.0f)
            continue;

        if (settings.fov_limit) {
            const float dx = (box_min.x + box_max.x) * 0.5f - screen_center.x;
            const float dy = (box_min.y + box_max.y) * 0.5f - screen_center.y;
            if (std::sqrt(dx * dx + dy * dy) > settings.fov_radius)
                continue;
        }

        const ImU32 color = color_from(player.relation == TeamRelation::Ally ? settings.color_ally : settings.color_enemy);

        if (settings.tracers) {
            draw->AddLine(ImVec2(screen_center.x, display.y), ImVec2(center_x, box_max.y), kShadow, 2.0f);
            draw->AddLine(ImVec2(screen_center.x, display.y), ImVec2(center_x, box_max.y), color, 1.0f);
        }

        if (settings.box) {
            if (settings.box_fill)
                draw->AddRectFilled(box_min, box_max, with_alpha(color, 34), 0.0f);
            if (settings.box_corners)
                add_corner_box(draw, box_min, box_max, color, 1.2f, true);
            else
                add_rect_shadowed(draw, box_min, box_max, color, 1.2f);
        }

        if (settings.health_bar && player.max_health > 0.0f) {
            const float fraction = std::clamp(player.health / player.max_health, 0.0f, 1.0f);
            const float bar_x = box_min.x - 5.0f;
            draw->AddRectFilled(ImVec2(bar_x - 1.0f, box_min.y - 1.0f), ImVec2(bar_x + 4.0f, box_max.y + 1.0f), kShadow);
            draw->AddRectFilled(ImVec2(bar_x, box_min.y), ImVec2(bar_x + 3.0f, box_max.y), IM_COL32(28, 30, 36, 220));
            const float fill_top = box_max.y - (box_max.y - box_min.y) * fraction;
            draw->AddRectFilled(ImVec2(bar_x, fill_top), ImVec2(bar_x + 3.0f, box_max.y), health_color(fraction));
        }

        if (settings.show_name) {
            const char* label = player.display_name.c_str();
            const ImVec2 text_size = ImGui::CalcTextSize(label);
            const ImVec2 text_pos(box_min.x + (box_max.x - box_min.x - text_size.x) * 0.5f, box_min.y - font_size - 3.0f);
            if (settings.text_outline)
                add_text_outline(draw, text_pos, IM_COL32(240, 242, 248, 255), label);
            else
                draw->AddText(text_pos, IM_COL32(240, 242, 248, 255), label);
        }

        if (settings.show_distance) {
            char buffer[32];
            std::snprintf(buffer, sizeof(buffer), "%.0f m", player.distance);
            const ImVec2 text_size = ImGui::CalcTextSize(buffer);
            const ImVec2 text_pos(box_min.x + (box_max.x - box_min.x - text_size.x) * 0.5f, box_max.y + 2.0f);
            if (settings.text_outline)
                add_text_outline(draw, text_pos, kTextDim, buffer);
            else
                draw->AddText(text_pos, kTextDim, buffer);
        }

        if (settings.skeleton)
            draw_skeleton(draw, projector, player, color);

        ++drawn;
    }

    draw->PopClipRect();
    return drawn;
}

} // namespace esp
