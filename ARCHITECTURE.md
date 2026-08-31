# Architecture

StudyTown is a Godot 4.7 GDScript project using the Compatibility renderer for macOS and desktop web.

## Runtime

- `scenes/main/main.tscn` is the only entry scene. `scripts/core/main.gd` builds the vertical slice from reusable authored construction functions.
- `GameState` centralizes product name, room list, selected character, coins, minutes, sessions, and JSON persistence.
- `FocusManager` owns timestamp-based session timing and emits tick/completion/cancellation signals. Rendering stalls and background tabs do not create timer drift.
- Rooms share the player controller, facing convention, StudySpot data shape, UI, NPC character hierarchy, focus HUD, and cinematic camera system.
- StudySpot dictionaries contain explicit standing/sitting transforms, yaw, activity, camera position, camera target, and debug nodes. Furniture origins never determine seating.

## State flow

`Menu → Room → Focus Setup → Focus → Completion → Room/Menu`

## Web constraints

The project uses GDScript, Compatibility rendering, non-threaded web export, low texture dependence, shared procedural materials, and browser-safe timestamps. Source asset archives are excluded from export.

## Extension points

Keep additional rooms as authored builders until their visual language stabilizes. Extract to dedicated scenes only when independent editing or streaming is materially useful. A WebSocket multiplayer client/server can sit beside the current NPC fallback without changing local focus timing.

