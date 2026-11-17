// settings.h — user settings, runtime panel state and the shared snapshot.

#pragma once

#include <array>
#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

#include "math3d.h"

struct Settings {
    bool esp_enabled = true;

    // Visual
    bool box = true;
    bool box_fill = false;
    bool box_corners = true;
    bool skeleton = true;
    bool tracers = true;
    float color_enemy[4] = {0.96f, 0.33f, 0.42f, 1.0f};
    float color_ally[4] = {0.36f, 0.72f, 1.00f, 1.0f};

    // Elements
    bool show_name = true;
    bool health_bar = true;
    bool show_distance = true;
    bool text_outline = true;

    // Range
    float max_distance = 500.0f;
    bool fov_limit = false;
    float fov_radius = 420.0f;

    // Filters
    bool hide_allies = false;
    bool ignore_dead = true;
    bool ignore_local = true;
    bool hide_unknown_team = false; // off by default

    // Panel
    bool panel_visible = true;
    float panel_x = -1.0f;
    float panel_y = -1.0f;
};

// Fields owned by the collector; the panel must never overwrite them.
struct RuntimeFields {
    int projection_mode = 0;
    int team_color_mode = 0;
    int team_color_distinct = 0;
    uint64_t world_generation = 0;
};

struct ToggleAnimation {
    float value = 0.0f;
};

// UI-only state for the Reaper Aim menu. None of the Aimbot/FPS switches feed
// the memory reader; they exist so the interface can be navigated and reviewed.
struct UiState {
    int tab = 2; // Aimbot opens by default.
    bool minimized = false;
    bool maximized = false;
    bool scroll_to_top = false;

    bool aim_enable = true;
    bool aim_toggle_mode = true;
    bool aim_team_check = false;
    bool aim_visible_check = false;
    bool aim_prediction = false;
    int aim_mode = 0; // 0 camera, 1 mouse, 2 silent (UI only)

    bool fps_fullbright = false;
    bool fps_no_fog = false;
    bool fps_low_graphics = false;
    bool fps_custom_fov = false;
    float fps_fov = 70.0f;
    bool fps_crosshair = false;
    float crosshair_size = 10.0f;
};

struct PanelState {
    float x = -1.0f;
    float y = -1.0f;
    float ui_scale = 1.0f;
    bool dragging = false;
    bool dragging_active = false;
    bool position_initialized = false;
    float bounds_min_x = 0.0f;
    float bounds_min_y = 0.0f;
    float bounds_max_x = 0.0f;
    float bounds_max_y = 0.0f;
    bool bounds_valid = false;
    float drag_origin_x = 0.0f;
    float drag_origin_y = 0.0f;
    bool click_test_logged = false;
    UiState ui;
};

enum class TeamRelation : int {
    Unknown = 0,
    Ally = 1,
    Enemy = 2,
};

enum class SkeletonNode : int {
    Head = 0,
    UpperTorso,
    LowerTorso,
    LeftUpperArm,
    LeftLowerArm,
    LeftHand,
    RightUpperArm,
    RightLowerArm,
    RightHand,
    LeftUpperLeg,
    LeftLowerLeg,
    LeftFoot,
    RightUpperLeg,
    RightLowerLeg,
    RightFoot,
    Count,
};

inline constexpr int kSkeletonNodeCount = static_cast<int>(SkeletonNode::Count);

struct BonePoint {
    Vec3 position{};
    bool valid = false;
};

struct PlayerSnapshot {
    uint64_t instance = 0;
    std::string name;
    std::string display_name;
    int64_t user_id = 0;
    float health = 0.0f;
    float max_health = 100.0f;
    bool alive = false;
    bool local = false;
    TeamRelation relation = TeamRelation::Unknown;
    Vec3 root{};
    Vec3 head{};
    float head_size = 1.0f;
    float root_height = 2.0f;
    float distance = 0.0f;
    bool has_humanoid = false;
    std::array<BonePoint, kSkeletonNodeCount> bones{};
    bool is_r15 = false;
    uint64_t team = 0;
    float team_color[3] = {0.0f, 0.0f, 0.0f};
    bool team_color_valid = false;
};

struct Snapshot {
    bool attached = false;
    bool offsets_trusted = false;
    bool world_valid = false;
    uint32_t pid = 0;
    uint64_t module_base = 0;
    uint64_t module_size = 0;
    uint64_t visual_engine = 0;
    uint64_t fake_data_model = 0;
    uint64_t data_model = 0;
    uint64_t workspace = 0;
    uint64_t camera = 0;
    uint64_t players_service = 0;
    uint64_t local_player = 0;
    uint64_t place_id = 0;
    uint64_t game_id = 0;
    int32_t game_loaded = 0;

    Vec3 camera_position{};
    float camera_rotation[9] = {};
    bool camera_rotation_valid = false;
    float camera_fov = 70.0f;
    Vec2 viewport{};
    Mat4 view_matrix{};
    bool view_matrix_valid = false;
    ProjectionMode projection_mode = ProjectionMode::None;

    int players_found = 0;
    int characters_valid = 0;
    int players_drawn = 0;
    int rejected_model = 0;
    int rejected_humanoid = 0;
    int rejected_root = 0;
    int rejected_dead = 0;
    int rejected_distance = 0;
    int rejected_team = 0;

    int team_color_mode = 0; // 0 none, 1 team pointer, 2 team color
    int team_color_distinct = 0;

    uint64_t world_generation = 0;
    uint64_t tick = 0;
    std::string status;
    std::vector<PlayerSnapshot> players;
};

// Shared state. Settings and Snapshot use separate mutexes so a slow draw can
// never block memory reads or vice versa.
extern std::mutex g_settings_mutex;
extern Settings g_settings;
extern std::mutex g_snapshot_mutex;
extern Snapshot g_snapshot;
extern std::mutex g_runtime_mutex;
extern RuntimeFields g_runtime;

// Set by the collector when the installed client does not match the offset
// profile. The panel displays this; the ESP refuses to draw unverified offsets.
void set_offsets_trusted(bool trusted);
bool offsets_trusted();
