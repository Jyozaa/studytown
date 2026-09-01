# Architecture

StudyTown is a Godot 4.7 GDScript project using the Compatibility renderer for macOS and desktop web.

## Runtime

- `scenes/main/main.tscn` is the entry scene. `scripts/core/main.gd` keeps room composition and flow orchestration while extracted scripts own focused systems.
- `GameState` centralizes product name, room list, selected character, coins, minutes, sessions, and JSON persistence.
- `FocusManager` owns timestamp-based session timing and emits tick/completion/cancellation signals. Rendering stalls and background tabs do not create timer drift.
- `scripts/player/player_controller.gd` owns acceleration, deceleration, grounded gravity, floor snapping, -Z facing, locomotion state, and below-world recovery to a validated spawn.
- `scripts/player/character_profile.gd` and `scripts/assets/character_loader.gd` read `assets/local_asset_manifest.json`, select owner-local cat GLBs when present, and otherwise instantiate the committed fallback.
- `scripts/characters/character_animation_controller.gd` centralizes state-to-clip mapping, looping states, and one-shot return behaviour for player and NPC cats.
- `scripts/camera/follow_camera.gd` follows X/Z with damping, fixed authored orientation, subtle velocity look-ahead, and a world-collision ray. `focus_camera_director.gd` blends to and from authored B-roll.
- `scripts/world/room_floor.gd` creates the reusable `StaticBody3D` structural floor. World, Player, NPC, and Interaction are physics layers 1–4.
- `scripts/rooms/room_definitions.gd` centralizes footprint, spawn, bounds, camera offset, look height, FOV, and damping.
- `StudySpot` nodes contain explicit standing/sitting transforms, yaw, activity, camera position, camera target, and debug visuals. Furniture origins never determine seating.

## State flow

`Menu → Room → Focus Setup → Focus → Completion → Room/Menu`

## Web constraints

The project uses GDScript, Compatibility rendering, non-threaded web export, and browser-safe timestamps. Local web QA may include owner-local runtime derivatives; public/distributable builds must be produced from a clean clone or with those proprietary files removed.

## Extension points

Keep additional rooms as authored builders until their visual language stabilizes. Extract to dedicated scenes only when independent editing or streaming is materially useful. A WebSocket multiplayer client/server can sit beside the current NPC fallback without changing local focus timing.
