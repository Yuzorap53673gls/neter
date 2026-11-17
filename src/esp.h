// esp.h — projection and world-space ESP rendering.

#pragma once

#include <imgui.h>

#include "settings.h"

namespace esp {

// Draws every player that survives filters/projection and fills the rejection
// counters in the snapshot. Returns the number of players actually drawn.
int draw(ImDrawList* draw, const Settings& settings, Snapshot& snapshot, Vec2 display);

} // namespace esp
