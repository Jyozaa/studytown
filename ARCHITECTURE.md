# Architecture

StudyTown is a Godot 4.7 GDScript project using the Compatibility renderer for macOS and desktop web.

## Runtime

- `scenes/main/main.tscn` is the entry scene. `scripts/core/main.gd` keeps room composition and flow orchestration while extracted scripts own focused systems.
- `GameState` centralizes product name, room list, selected character, coins, minutes, sessions, and JSON persistence.
- `FocusManager` owns timestamp-based session timing and emits tick/completion/cancellation signals. Rendering stalls and background tabs do not create timer drift.
- `scripts/player/player_controller.gd` owns acceleration, deceleration, grounded gravity, floor snapping, -Z facing, locomotion state, and below-world recovery to a validated spawn.
- `scripts/player/character_profile.gd` and `scripts/assets/character_loader.gd` read `assets/local_asset_manifest.json`, select owner-local cat GLBs when present, and otherwise instantiate the committed fallback.
- `scripts/characters/character_animation_controller.gd` centralizes state-to-clip mapping, looping states, and one-shot return behaviour for player and NPC cats.
- `scripts/camera/follow_camera.gd` follows X/Z with damping, a fixed near-frontal authored orientation, subtle velocity look-ahead, and a world-collision ray. `focus_camera_director.gd` blends between focus shots and back to exploration.
- `scripts/world/room_floor.gd` creates the reusable `StaticBody3D` structural floor. World, Player, NPC, and Interaction are physics layers 1–4.
- `scripts/rooms/room_definitions.gd` centralizes footprint, spawn, bounds, camera offset, look height, FOV, and damping.
- `StudySpot` nodes contain explicit standing/sitting transforms, yaw, activity, seat type, seat height, seat-specific visual offset, camera data, occupancy, and debug visuals. Furniture origins never determine seating. `CharacterLoader` combines the seat offset with the selected `CharacterProfile` offset for both players and NPCs.
- Focus mode discards the exploration B-roll pool and generates a curated set of seat-relative front/side angles. Shoulder and head rays must both be clear before a camera is admitted; the same validation runs again whenever shots cycle, so newly blocked views are skipped.

## State flow

Legacy production path (explicit UI review modes and legacy tests only):

`Menu → Room → Focus Setup → Focus → Completion → Room/Menu`

### Development runtime (normal `Godot --path .` startup)

No UI controller is instantiated. Gameplay stands alone:

`BOOT → ROOM → SEATED → FOCUS → SEATED/ROOM`

- `scripts/core/gameplay_flow.gd` (child of main, always present) owns
  seating mechanics (`take_seat`/`stand_up`, result-coded, no UI) and focus
  mechanics (`start_focus`/`cancel_focus`/natural completion with rewards).
  Seated is `active_study_spot != null`; no invisible SESSION_SETUP page is
  required to start focus.
- `scripts/ui/application_flow.gd` is NOT instantiated during dev boot. It
  remains for explicit legacy UI review modes (`--review=…`, which create it
  via `ensure_legacy_flow()`) and consumes the gameplay API for its
  take/leave/start paths instead of owning mechanics.
- Input: E → `gameplay.try_interact()`; F wave unchanged; Escape toggles the
  dev panel (never opens legacy menus).
- `scripts/dev/dev_panel.gd` + controls hint are the only UI, calling the
  gameplay API directly.

## Web constraints

The project uses GDScript, Compatibility rendering, non-threaded web export, and browser-safe timestamps. Local web QA may include owner-local runtime derivatives; public/distributable builds must be produced from a clean clone or with those proprietary files removed.

## Extension points

Keep additional rooms as authored builders until their visual language stabilizes. Extract to dedicated scenes only when independent editing or streaming is materially useful. A WebSocket multiplayer client/server can sit beside the current NPC fallback without changing local focus timing.
