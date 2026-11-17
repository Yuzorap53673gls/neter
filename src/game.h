// game.h — world resolution, DataModel change detection and player collection.

#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "math3d.h"
#include "memory.h"
#include "settings.h"

class Game {
public:
    bool attach(uint32_t pid);
    void detach();
    bool attached() const { return memory_.attached(); }
    const Memory& memory() const { return memory_; }

    // One collection cycle. Never blocks on the render thread.
    void collect(Snapshot& out);

private:
    struct World {
        uint64_t visual_engine = 0;
        uint64_t fake_data_model = 0;
        uint64_t data_model = 0;
        uint64_t workspace = 0;
        uint64_t camera = 0;
        uint64_t players = 0;
        uint64_t local_player = 0;
        uint64_t generation = 0;
    };

    bool resolve_root(Snapshot& snapshot);
    bool resolve_world(Snapshot& snapshot);
    void clear_world_cache(const char* reason);
    void read_camera(Snapshot& snapshot);
    void update_projection(Snapshot& snapshot);
    void collect_players(Snapshot& snapshot);
    bool read_player(uint64_t player_instance, Snapshot& snapshot, PlayerSnapshot& out);
    bool read_property_string(uint64_t address, std::string& out) const;

    static bool rotate_plausible(const float rot[9]);
    static bool same_team_color(const float a[3], const float b[3]);

    Memory memory_;
    World world_;
    ProjectionMode projection_mode_ = ProjectionMode::None;
    int team_color_mode_ = 0;
    int team_color_distinct_ = 0;
    uint64_t last_log_tick_ = 0;
};
