// panel.h — compact ImGui panel (fixed 300 px, draggable header, custom toggles).

#pragma once

#include <imgui.h>

#include "settings.h"

namespace panel {

struct Outcome {
    bool settings_changed = false;
    bool hide_requested = false;
    bool reset_position = false;
};

void apply_style(float ui_scale);

// Draws the panel. `origin_screen` is the screen position of the overlay's
// client origin; it is used only so automated click tests can address controls.
Outcome draw(Settings& settings, PanelState& state, const Snapshot& snapshot, ImVec2 display, ImVec2 origin_screen);

} // namespace panel
