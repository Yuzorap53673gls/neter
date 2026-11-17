// game.cpp — resolves the Roblox world from the profile offsets and rebuilds
// the player list on every cycle. Read-only; no pointer from the target is
// trusted without a range check and a real read.

#include "game.h"

#include "log.h"
#include "offsets.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <unordered_map>

namespace {

const char* kR15Names[static_cast<int>(SkeletonNode::Count)] = {
    "Head", "UpperTorso", "LowerTorso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
};

const char* kR6Names[static_cast<int>(SkeletonNode::Count)] = {
    "Head", "Torso", nullptr,
    "Left Arm", nullptr, nullptr,
    "Right Arm", nullptr, nullptr,
    "Left Leg", nullptr, nullptr,
    "Right Leg", nullptr, nullptr,
};

int r15_index(const std::string& name) {
    for (int i = 0; i < kSkeletonNodeCount; ++i)
        if (kR15Names[i] && name == kR15Names[i])
            return i;
    return -1;
}

int r6_index(const std::string& name) {
    for (int i = 0; i < kSkeletonNodeCount; ++i)
        if (kR6Names[i] && name == kR6Names[i])
            return i;
    return -1;
}

bool finite_vec(const Vec3& v) {
    return std::isfinite(v.x) && std::isfinite(v.y) && std::isfinite(v.z);
}

} // namespace

bool Game::attach(uint32_t pid) {
    projection_mode_ = ProjectionMode::None;
    world_ = World{};
    return memory_.attach(pid);
}

void Game::detach() {
    clear_world_cache("detach");
    memory_.detach();
}

bool Game::resolve_root(Snapshot& snapshot) {
    const uint64_t base = memory_.module_base();
    if (base == 0)
        return false;

    uint64_t visual_engine = memory_.read_ptr(base + off::VisualEngine_Pointer);
    uint64_t fake_data_model = 0;
    uint64_t data_model = 0;

    if (Memory::plausible(visual_engine))
        fake_data_model = memory_.read_ptr(visual_engine + off::VisualEngine_FakeDataModel);

    if (Memory::plausible(fake_data_model))
        data_model = memory_.read_ptr(fake_data_model + off::FakeDataModel_RealDataModel);

    if (!Memory::plausible(data_model)) {
        // Fallback: the standalone FakeDataModel global.
        const uint64_t fallback = memory_.read_ptr(base + off::FakeDataModel_Pointer);
        if (Memory::plausible(fallback)) {
            fake_data_model = fallback;
            data_model = memory_.read_ptr(fallback + off::FakeDataModel_RealDataModel);
        }
    }

    if (!Memory::plausible(data_model)) {
        snapshot.visual_engine = visual_engine;
        snapshot.fake_data_model = fake_data_model;
        snapshot.data_model = 0;
        return false;
    }

    const bool changed = world_.data_model != 0 &&
                         (world_.data_model != data_model || world_.visual_engine != visual_engine);
    if (changed) {
        const uint64_t old_dm = world_.data_model;
        const uint64_t old_ve = world_.visual_engine;
        Log::get().info("world switch detected: DataModel 0x%llX -> 0x%llX, VisualEngine 0x%llX -> 0x%llX",
                        static_cast<unsigned long long>(old_dm), static_cast<unsigned long long>(data_model),
                        static_cast<unsigned long long>(old_ve), static_cast<unsigned long long>(visual_engine));
        clear_world_cache("world switch");
    }

    world_.visual_engine = visual_engine;
    world_.fake_data_model = fake_data_model;
    world_.data_model = data_model;
    if (world_.generation == 0)
        world_.generation = 1;

    snapshot.visual_engine = visual_engine;
    snapshot.fake_data_model = fake_data_model;
    snapshot.data_model = data_model;
    snapshot.world_generation = world_.generation;
    return true;
}

bool Game::resolve_world(Snapshot& snapshot) {
    if (!resolve_root(snapshot))
        return false;

    // Revalidate the cached workspace/camera each cycle; the DataModel can be
    // alive while a server transition tears down the services underneath it.
    uint64_t workspace = memory_.read_ptr(snapshot.data_model + off::DataModel_Workspace);
    std::string workspace_name = Memory::plausible(workspace) ? memory_.read_name(workspace) : std::string();
    if (workspace_name != "Workspace") {
        const uint64_t fresh = memory_.find_child(snapshot.data_model, "Workspace");
        if (fresh) {
            workspace = fresh;
            workspace_name = memory_.read_name(fresh);
        }
    }
    if (!Memory::plausible(workspace) || workspace_name != "Workspace") {
        snapshot.status = "Workspace not resolved";
        return false;
    }

    const int32_t loaded = memory_.read_i32(snapshot.data_model + off::DataModel_GameLoaded);
    snapshot.game_loaded = loaded;

    uint64_t camera = memory_.read_ptr(workspace + off::Workspace_CurrentCamera);
    if (!Memory::plausible(camera)) {
        snapshot.status = "CurrentCamera not resolved";
        return false;
    }

    world_.workspace = workspace;
    world_.camera = camera;
    snapshot.workspace = workspace;
    snapshot.camera = camera;

    snapshot.place_id = static_cast<uint64_t>(memory_.read_i32(snapshot.data_model + off::DataModel_PlaceId));
    snapshot.game_id = static_cast<uint64_t>(memory_.read_i32(snapshot.data_model + off::DataModel_GameId));

    if (loaded == 0) {
        snapshot.status = "DataModel present, GameLoaded=0 (loading)";
        return true; // world is resolving; no ESP yet
    }

    if (world_.players == 0) {
        const uint64_t players = memory_.find_child(snapshot.data_model, "Players");
        if (Memory::plausible(players)) {
            world_.players = players;
            Log::get().info("Players service 0x%llX", static_cast<unsigned long long>(players));
        }
    }

    if (world_.players != 0) {
        if (!memory_.child_vector_sane(world_.players)) {
            Log::get().throttled("players-vector", 2000, "Players child vector went invalid; resolving again");
            world_.players = 0;
        }
    }
    snapshot.players_service = world_.players;

    const uint64_t local = world_.players ? memory_.read_ptr(world_.players + off::Player_LocalPlayer) : 0;
    world_.local_player = Memory::plausible(local) ? local : 0;
    snapshot.local_player = world_.local_player;
    return true;
}

void Game::clear_world_cache(const char* reason) {
    Log::get().info("clear_world_cache: %s (was ve=0x%llX dm=0x%llX ws=0x%llX cam=0x%llX players=0x%llX local=0x%llX)", reason,
                    static_cast<unsigned long long>(world_.visual_engine),
                    static_cast<unsigned long long>(world_.data_model),
                    static_cast<unsigned long long>(world_.workspace),
                    static_cast<unsigned long long>(world_.camera),
                    static_cast<unsigned long long>(world_.players),
                    static_cast<unsigned long long>(world_.local_player));
    const uint64_t generation = world_.generation + 1;
    world_ = World{};
    world_.generation = generation;
    projection_mode_ = ProjectionMode::None;
    team_color_mode_ = 0;
    team_color_distinct_ = 0;
}

void Game::read_camera(Snapshot& snapshot) {
    snapshot.camera_position = {};
    snapshot.camera_rotation_valid = false;
    snapshot.view_matrix_valid = false;

    if (world_.camera == 0)
        return;

    const Vec3 position = memory_.read_vec3(world_.camera + off::Camera_Position);
    if (finite_vec(position) && std::fabs(position.x) < 1.0e6f && std::fabs(position.y) < 1.0e6f &&
        std::fabs(position.z) < 1.0e6f) {
        snapshot.camera_position = position;
    }

    float rotation[9] = {};
    if (memory_.read_floats(world_.camera + off::Camera_Rotation, rotation, 9) && rotate_plausible(rotation)) {
        std::memcpy(snapshot.camera_rotation, rotation, sizeof(rotation));
        snapshot.camera_rotation_valid = true;
    }

    float viewport[2] = {};
    if (memory_.read_floats(world_.camera + off::Camera_ViewportSize, viewport, 2)) {
        if (viewport[0] >= 16.0f && viewport[1] >= 16.0f && viewport[0] <= 16384.0f && viewport[1] <= 16384.0f)
            snapshot.viewport = Vec2(viewport[0], viewport[1]);
    }

    const float fov = memory_.read_f32(world_.camera + off::Camera_FieldOfView);
    if (std::isfinite(fov) && fov > 10.0f && fov < 170.0f)
        snapshot.camera_fov = fov;

    if (snapshot.viewport.x <= 0.0f && Memory::plausible(snapshot.visual_engine)) {
        float dimensions[2] = {};
        if (memory_.read_floats(snapshot.visual_engine + off::VisualEngine_Dimensions, dimensions, 2)) {
            if (dimensions[0] >= 16.0f && dimensions[1] >= 16.0f)
                snapshot.viewport = Vec2(dimensions[0], dimensions[1]);
        }
    }

    float matrix[16] = {};
    if (Memory::plausible(snapshot.visual_engine) &&
        memory_.read_floats(snapshot.visual_engine + off::VisualEngine_ViewMatrix, matrix, 16)) {
        bool finite = true;
        bool nonzero = false;
        for (float value : matrix) {
            if (!std::isfinite(value) || std::fabs(value) > 1.0e7f) {
                finite = false;
                break;
            }
            if (std::fabs(value) > 1.0e-6f)
                nonzero = true;
        }
        if (finite && nonzero) {
            std::memcpy(snapshot.view_matrix.m, matrix, sizeof(matrix));
            snapshot.view_matrix_valid = true;
        }
    }
}

bool Game::rotate_plausible(const float rot[9]) {
    float lengths[3] = {};
    for (int row = 0; row < 3; ++row) {
        const float x = rot[row * 3 + 0];
        const float y = rot[row * 3 + 1];
        const float z = rot[row * 3 + 2];
        if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(z))
            return false;
        lengths[row] = std::sqrt(x * x + y * y + z * z);
    }
    for (float len : lengths)
        if (len < 0.5f || len > 1.5f)
            return false;
    return true;
}

void Game::update_projection(Snapshot& snapshot) {
    ProjectionMode selected = ProjectionMode::None;

    if (snapshot.view_matrix_valid && snapshot.camera_rotation_valid) {
        const CameraBasis basis = make_basis(snapshot.camera_rotation);
        const Vec3 probe = snapshot.camera_position + basis.forward * 10.0f;
        Vec2 viewport = snapshot.viewport;
        if (viewport.x <= 0.0f || viewport.y <= 0.0f)
            viewport = Vec2(1920.0f, 1080.0f);

        ClipResult row = clip_row_vector(snapshot.view_matrix, probe);
        ClipResult col = clip_column_vector(snapshot.view_matrix, probe);

        auto score = [&](const ClipResult& clip, float& out) -> bool {
            if (!std::isfinite(clip.w) || clip.w <= 0.01f)
                return false;
            const float ndc_x = clip.x / clip.w;
            const float ndc_y = clip.y / clip.w;
            if (!std::isfinite(ndc_x) || !std::isfinite(ndc_y))
                return false;
            if (std::fabs(ndc_x) > 1.5f || std::fabs(ndc_y) > 1.5f)
                return false;
            Vec2 screen;
            if (!clip_to_screen(clip, viewport, screen, false))
                return false;
            out = std::fabs(ndc_x) + std::fabs(ndc_y);
            return true;
        };

        float row_score = 0.0f;
        float col_score = 0.0f;
        const bool row_ok = score(row, row_score);
        const bool col_ok = score(col, col_score);

        if (row_ok && col_ok) {
            if (std::fabs(row_score - col_score) < 0.05f) {
                selected = (projection_mode_ == ProjectionMode::RowVector || projection_mode_ == ProjectionMode::ColumnVector)
                               ? projection_mode_
                               : ProjectionMode::RowVector;
            } else {
                selected = row_score < col_score ? ProjectionMode::RowVector : ProjectionMode::ColumnVector;
            }
        } else if (row_ok) {
            selected = ProjectionMode::RowVector;
        } else if (col_ok) {
            selected = ProjectionMode::ColumnVector;
        }
    }

    if (selected == ProjectionMode::None)
        selected = snapshot.camera_rotation_valid ? ProjectionMode::Camera : ProjectionMode::None;

    if (projection_mode_ != selected) {
        if (selected != ProjectionMode::None)
            Log::get().info("projection mode: %s", projection_mode_name(selected));
        projection_mode_ = selected;
    }
    snapshot.projection_mode = projection_mode_;
}

bool Game::read_property_string(uint64_t address, std::string& out) const {
    out.clear();
    const int32_t length = memory_.read_i32(address + off::String_Length);
    if (length <= 0 || length > 200)
        return false;
    uint64_t data = 0;
    if (length <= 15)
        data = address;
    else {
        data = memory_.read_ptr(address);
        if (!Memory::plausible(data))
            return false;
    }
    char buffer[201] = {};
    if (!memory_.read(data, buffer, static_cast<size_t>(length)))
        return false;
    if (std::memchr(buffer, '\0', static_cast<size_t>(length)) != nullptr)
        return false;
    out.assign(buffer, static_cast<size_t>(length));
    return true;
}

bool Game::read_player(uint64_t player_instance, Snapshot& snapshot, PlayerSnapshot& out) {
    out = PlayerSnapshot{};
    out.instance = player_instance;
    out.local = (player_instance == snapshot.local_player);

    out.name = memory_.read_name(player_instance);
    if (out.name.empty())
        return false;

    out.user_id = static_cast<int64_t>(memory_.read_i32(player_instance + off::Player_UserId));

    // Team pointer: the only reliable ally signal.
    out.team = memory_.read_ptr(player_instance + off::Player_Team);
    if (!Memory::plausible(out.team))
        out.team = 0;

    float color[3] = {};
    if (memory_.read_floats(player_instance + off::Player_TeamColor, color, 3)) {
        if (std::isfinite(color[0]) && std::isfinite(color[1]) && std::isfinite(color[2]) && color[0] >= -0.01f &&
            color[0] <= 1.01f && color[1] >= -0.01f && color[1] <= 1.01f && color[2] >= -0.01f && color[2] <= 1.01f) {
            std::memcpy(out.team_color, color, sizeof(color));
            out.team_color_valid = true;
        }
    }

    const uint64_t model = memory_.read_ptr(player_instance + off::Player_ModelInstance);
    if (!Memory::plausible(model)) {
        ++snapshot.rejected_model;
        return false;
    }

    const std::vector<uint64_t> children = memory_.read_children(model);
    if (children.empty()) {
        ++snapshot.rejected_model;
        return false;
    }

    uint64_t humanoid = 0;
    uint64_t head = 0;
    uint64_t humanoid_root = 0;
    std::unordered_map<std::string, uint64_t> parts;
    parts.reserve(children.size());

    for (uint64_t child : children) {
        const std::string name = memory_.read_name(child);
        if (name.empty())
            continue;
        parts.emplace(name, child);
        if (name == "Humanoid")
            humanoid = child;
        else if (name == "Head")
            head = child;
        else if (name == "HumanoidRootPart")
            humanoid_root = child;
    }

    if (!Memory::plausible(humanoid)) {
        ++snapshot.rejected_humanoid;
        return false;
    }
    out.has_humanoid = true;

    const float health = memory_.read_f32(humanoid + off::Humanoid_Health);
    const float max_health = memory_.read_f32(humanoid + off::Humanoid_MaxHealth);
    if (std::isfinite(health) && std::isfinite(max_health)) {
        out.health = std::max(0.0f, health);
        out.max_health = max_health > 0.0f ? max_health : 100.0f;
    } else {
        out.health = 0.0f;
        out.max_health = 100.0f;
    }
    out.alive = out.health > 0.0f;

    std::string display;
    if (read_property_string(humanoid + off::Humanoid_DisplayName, display) && !display.empty())
        out.display_name = display;
    else
        out.display_name = out.name;

    // Rig detection: R15 characters expose UpperTorso/LowerTorso.
    out.is_r15 = parts.count("UpperTorso") != 0 || parts.count("LowerTorso") != 0;

    uint64_t root_part = Memory::plausible(humanoid_root) ? humanoid_root : 0;
    if (root_part == 0)
        root_part = memory_.read_ptr(humanoid + off::Humanoid_HumanoidRootPart);
    if (!Memory::plausible(root_part))
        root_part = memory_.read_ptr(model + off::Model_PrimaryPart);
    if (!Memory::plausible(root_part))
        root_part = head;
    if (!Memory::plausible(root_part)) {
        ++snapshot.rejected_root;
        return false;
    }

    auto read_part_position = [&](uint64_t part, Vec3& position, float& height) -> bool {
        if (!Memory::plausible(part))
            return false;
        const uint64_t primitive = memory_.read_ptr(part + off::BasePart_Primitive);
        if (!Memory::plausible(primitive))
            return false;
        const Vec3 pos = memory_.read_vec3(primitive + off::Primitive_Position);
        if (!finite_vec(pos) || std::fabs(pos.x) > 1.0e6f || std::fabs(pos.y) > 1.0e6f || std::fabs(pos.z) > 1.0e6f)
            return false;
        const Vec3 size = memory_.read_vec3(primitive + off::Primitive_Size);
        position = pos;
        height = (std::isfinite(size.y) && size.y > 0.1f && size.y < 100.0f) ? size.y : 0.0f;
        return true;
    };

    float root_height = 0.0f;
    if (!read_part_position(root_part, out.root, root_height)) {
        ++snapshot.rejected_root;
        return false;
    }
    out.root_height = root_height > 0.0f ? root_height : 2.0f;

    float head_height = 0.0f;
    Vec3 head_pos{};
    if (read_part_position(head, head_pos, head_height)) {
        out.head = head_pos;
        out.head_size = head_height > 0.0f ? head_height : 1.0f;
    } else {
        out.head = out.root + Vec3(0.0f, out.root_height * 0.5f + 0.5f, 0.0f);
        out.head_size = 1.0f;
    }

    if (snapshot.camera != 0 && finite_vec(snapshot.camera_position))
        out.distance = distance(out.root, snapshot.camera_position);

    // Skeleton: use real part centers; only nodes present in this rig light up.
    for (const auto& [name, part] : parts) {
        int index = -1;
        if (out.is_r15)
            index = r15_index(name);
        if (index < 0)
            index = r6_index(name);
        if (index < 0)
            continue;
        Vec3 position{};
        float height = 0.0f;
        if (read_part_position(part, position, height)) {
            out.bones[static_cast<size_t>(index)].position = position;
            out.bones[static_cast<size_t>(index)].valid = true;
        }
    }

    return true;
}

bool Game::same_team_color(const float a[3], const float b[3]) {
    constexpr float kEpsilon = 0.02f;
    return std::fabs(a[0] - b[0]) < kEpsilon && std::fabs(a[1] - b[1]) < kEpsilon && std::fabs(a[2] - b[2]) < kEpsilon;
}

void Game::collect_players(Snapshot& snapshot) {
    snapshot.players_found = 0;
    snapshot.characters_valid = 0;
    snapshot.players.clear();

    if (world_.players == 0)
        return;

    const std::vector<uint64_t> players = memory_.read_children(world_.players);
    snapshot.players_found = static_cast<int>(players.size());
    snapshot.players.reserve(players.size());

    for (uint64_t instance : players) {
        PlayerSnapshot player;
        if (read_player(instance, snapshot, player)) {
            ++snapshot.characters_valid;
            snapshot.players.push_back(std::move(player));
        }
    }

    // Team resolution. Team pointer first; colour only as a guarded fallback.
    uint64_t local_team = 0;
    float local_color[3] = {};
    bool local_color_valid = false;
    for (const PlayerSnapshot& p : snapshot.players) {
        if (!p.local)
            continue;
        local_team = p.team;
        std::memcpy(local_color, p.team_color, sizeof(local_color));
        local_color_valid = p.team_color_valid;
        break;
    }

    // Distinct colours across the population, quantised to 1/100.
    std::vector<std::array<int, 3>> quantised;
    for (const PlayerSnapshot& p : snapshot.players) {
        if (!p.team_color_valid)
            continue;
        std::array<int, 3> key{static_cast<int>(p.team_color[0] * 100.0f + 0.5f),
                               static_cast<int>(p.team_color[1] * 100.0f + 0.5f),
                               static_cast<int>(p.team_color[2] * 100.0f + 0.5f)};
        if (std::find(quantised.begin(), quantised.end(), key) == quantised.end())
            quantised.push_back(key);
    }
    team_color_distinct_ = static_cast<int>(quantised.size());

    const bool color_mode = local_color_valid && team_color_distinct_ > 1;
    team_color_mode_ = color_mode ? 2 : 0;

    for (PlayerSnapshot& p : snapshot.players) {
        if (p.local) {
            p.relation = TeamRelation::Ally;
            continue;
        }
        if (local_team != 0 && p.team != 0) {
            p.relation = (p.team == local_team) ? TeamRelation::Ally : TeamRelation::Enemy;
            team_color_mode_ = 1;
            continue;
        }
        if (color_mode && p.team_color_valid) {
            p.relation = same_team_color(p.team_color, local_color) ? TeamRelation::Ally : TeamRelation::Enemy;
            continue;
        }
        p.relation = TeamRelation::Unknown;
    }

    snapshot.team_color_mode = team_color_mode_;
    snapshot.team_color_distinct = team_color_distinct_;
}

void Game::collect(Snapshot& out) {
    Snapshot snapshot;
    snapshot.attached = memory_.attached();
    snapshot.offsets_trusted = offsets_trusted();
    snapshot.module_base = memory_.module_base();
    snapshot.module_size = memory_.module_size();
    snapshot.pid = memory_.pid();
    snapshot.tick = last_log_tick_ + 1;
    last_log_tick_ = snapshot.tick;

    if (!snapshot.attached) {
        snapshot.status = "RobloxPlayerBeta.exe not attached";
        out = std::move(snapshot);
        return;
    }

    if (!snapshot.offsets_trusted) {
        snapshot.status = "offset profile does not match installed client";
        out = std::move(snapshot);
        return;
    }

    if (!resolve_world(snapshot)) {
        if (world_.data_model != 0 && !Memory::plausible(snapshot.data_model)) {
            Log::get().throttled("world-lost", 2000, "world chain disappeared; clearing caches and waiting for the new DataModel");
            clear_world_cache("root chain disappeared");
        }
        out = std::move(snapshot);
        return;
    }

    snapshot.world_valid = true;
    snapshot.world_generation = world_.generation;
    read_camera(snapshot);
    update_projection(snapshot);

    if (snapshot.game_loaded != 0)
        collect_players(snapshot);

    if (snapshot.status.empty()) {
        if (snapshot.game_loaded == 0)
            snapshot.status = "waiting for game";
        else if (world_.players == 0)
            snapshot.status = "waiting for Players service";
        else
            snapshot.status = "live";
    }

    out = std::move(snapshot);
}
