# StudyTown

StudyTown is a cozy 3D social study game built in Godot. Choose a character and a room, walk into a populated study space, claim a seat, name the task you are working on, and begin a timestamp-accurate focus session with calm authored cinematic views.

## Included vertical slice

- Three local-development ACNH villager profiles (Alfonso, Gayle, and Drago) with a runnable public fallback
- 44×32 Grand Library, 52×38 Garden Café, 11×42 Scenic Train, and 38×30 Japanese Study Room, each split into distinct activity zones
- Smooth fixed-orientation elevated follow camera for exploration and authored cinematic cameras for focus sessions
- Collision-backed structural floors, walls, boundaries, and major furniture; grounded gravity and validated per-room spawn points
- Calm NPC populations of 3/2/2/2 with explicit seated anchors
- CharacterBody3D WASD movement, smooth acceleration/deceleration, canonical -Z facing, wave response, and compact labels
- Task entry, 25/50/90/120-minute presets, 10-second developer session, timestamp-based countdown, completion reward, and local persistence
- Focus Coins, total minutes, completed sessions, and recent-session save data
- Compatibility-renderer desktop web export preset

## Requirements

- Godot 4.7.1 stable or a compatible Godot 4.x stable editor
- Blender 5.x only when generating local development character/prop GLBs
- macOS for the documented local paths; other desktop platforms work with their normal Godot executable
- Python 3 only for the convenience web server

## Run

Open `project.godot` in Godot and press F6/F5, or on this Mac:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/joe/Desktop/studytown
```

## Controls

- `WASD` — move
- `E` — interact / study
- `F` — wave
- `Escape` — return to places / leave focus
- `F3` — StudySpot anchor debugger
- `F4` — structural collision debugger
- `F5` — open a 10-second developer focus setup
- `F6` — performance/grounding overlay

## Web export

Install matching Godot export templates, then:

```bash
./web/export_web.sh
python3 -m http.server 8060 --directory web/build
```

Open `http://localhost:8060`. The export is non-threaded and uses the Compatibility renderer, so it does not require cross-origin isolation headers.

## Art reviews

Runtime captures are under `art_reviews/character_01`, `art_reviews/library`, `art_reviews/final`, and `art_reviews/overhaul`. They are generated from the real Godot scene with Movie Maker mode, not composited mockups.

## Assets

The intended local development build can load owner-supplied Animal Crossing: New Horizons character and prop references from `assets/dev_only_acnh/`. That directory is ignored by Git; those files are not CC0 and are not distributable StudyTown assets. A clean clone automatically uses the procedural character and CC0 Kenney prop fallbacks. See `ASSET_LICENSES.md`, `ASSET_PIPELINE.md`, and `assets/acnh_manifest.example.json`.

## Project map

- `autoload/` — persistent game state and focus timing
- `scenes/main/` — project entry scene
- `scripts/core/main.gd` — room composition, UI, and orchestration
- `scripts/player/`, `scripts/camera/`, `scripts/study/`, `scripts/npc/`, `scripts/assets/` — extracted runtime systems
- `scripts/rooms/room_definitions.gd` — footprints, validated spawns, walkable bounds, and per-room camera tuning
- `tools/acnh_import/` — local-only Blender inspection/normalization pipelines
- `assets/external/` — selected game-ready CC0 support assets
- `assets/source_external/` — retained original pack source and license; ignored by Godot import
- `art_reviews/` — screenshot-driven visual QA
- `web/` — export and local serving scripts

## Current multiplayer status

The delivered vertical slice uses authored NPC population and local persistence. Multiplayer remains intentionally out of scope for this overhaul.
