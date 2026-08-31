# StudyTown

StudyTown is a cozy 3D social study game built in Godot. Choose a character and a room, walk into a populated study space, claim a seat, name the task you are working on, and begin a timestamp-accurate focus session with calm authored cinematic views.

## Included vertical slice

- Three original character variants sharing one anatomy, movement, seating, and animation hierarchy
- Grand Library benchmark room with full shelves, fireplace, desks, reading nook, six NPC students, and six cinematic shots
- Garden Café, Scenic Train, and Japanese Study Room, each playable with authored study spots and focus B-roll
- Fixed three-quarter exploration cameras, CharacterBody3D WASD movement, smooth -Z facing, collisions, wave response, and compact labels
- Task entry, 25/50/90/120-minute presets, 10-second developer session, timestamp-based countdown, completion reward, and local persistence
- Focus Coins, total minutes, completed sessions, and recent-session save data
- Compatibility-renderer desktop web export preset

## Requirements

- Godot 4.7.1 stable or a compatible Godot 4.x stable editor
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
- `F5` — open a 10-second developer focus setup
- `F6` — debug overlay

## Web export

Install matching Godot export templates, then:

```bash
./web/export_web.sh
python3 -m http.server 8060 --directory web/build
```

Open `http://localhost:8060`. The export is non-threaded and uses the Compatibility renderer, so it does not require cross-origin isolation headers.

## Art reviews

Runtime captures are under `art_reviews/character_01`, `art_reviews/library`, and `art_reviews/final`. They are generated from the real Godot scene with Movie Maker mode, not composited mockups.

## Assets

Characters and hero environments are original. Selected Kenney Furniture Kit supporting props are CC0 and retained with their original license. See `ASSET_LICENSES.md` and `ASSET_PIPELINE.md`.

## Project map

- `autoload/` — persistent game state and focus timing
- `scenes/main/` — project entry scene
- `scripts/core/main.gd` — room construction, character system, movement, interaction, UI, and cinematic flow
- `assets/external/` — selected game-ready CC0 support assets
- `assets/source_external/` — retained original pack source and license; ignored by Godot import
- `art_reviews/` — screenshot-driven visual QA
- `web/` — export and local serving scripts

## Current multiplayer status

The delivered vertical slice uses authored NPC population and local persistence. A browser-compatible authoritative WebSocket multiplayer layer is the next engineering milestone; it is intentionally not represented as production-ready in this build.

