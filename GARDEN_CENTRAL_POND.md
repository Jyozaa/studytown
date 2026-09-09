# Garden — Central Pond redesign

Implemented from Concept A and the written Garden-only brief. The concept is a
composition reference, not a source of copied art. This replaces the old Garden;
it is not a pond layered over its fountain, market, pool or forest-village layout.

## Layout and interaction

- Approximately 52 × 38 playable units; south entrance at `(0, 0.65, 15.6)`.
- Organic central pond with 16 authored shoreline controls, smoothed into 80
  shoreline segments. Muted animated water reuses `garden_water.gdshader`
  through a new material; the existing shader is unchanged.
- Tree island, two log bridges, and a roughly 2.5-unit-wide winding ring path.
- North green gazebo, west open-air café, east fireside nook, southeast study
  lawn, southwest quiet grove, and a party-light entrance arch.
- Six flowering oaks, layered perimeter trees and low planting, irregular rock
  clusters, six park benches, eight path lamps and four unshadowed local lights.
- **18 StudySpots:** island 2, gazebo 4, café 4, campfire 2, lawn 4, grove 2.
- **6 background students**, leaving 12 player-available seats.
- Existing E → reservation → approach/sit → camera pan → setup → focus flow is
  retained. Bench/log availability effects use Garden-specific cushion heights.

The island benches were moved inward after reachability testing. The gazebo
was widened, rotated and moved slightly north to retain column clearance and
keep the north ring path open. Bridge approaches are actual slopes: floor snap
alone does not let a Godot CharacterBody step up a raised bridge end.
The island tree uses a measured footprint and model-accurate trunk collision;
its root silhouette clears the cross-route. The raised island has its own floor.

## Files created

- `scripts/rooms/garden_builder.gd` — dedicated layout, local-asset lookup,
  public procedural fallback, collision, study anchors, students and lighting.
- `shaders/garden_meadow.gdshader` — low-contrast treatment of the existing
  owner-supplied lawn texture; no bitmap is rewritten.
- `tools/editor/rebuild_garden_central_pond.gd` — Garden-only replacement tool;
  requires `--replace-garden` and refuses to overwrite if backup fails.
- `tools/editor/inspect_pond_assets.gd` — repeatable actual runtime-mesh bounds.
- `tools/local_assets/blender_central_pond_assets.py` — targeted conversion
  using the existing static COLLADA/material pipeline.
- `tests/test_central_pond.gd` — floor, route, bridge, seat, camera and public
  fallback checks, including a half-unit collision-clearance reachability graph.
- `tests/review_central_pond.gd` — screenshot tour and actual E-key seat tests.
- `tests/measure_central_pond.gd` — warmed native performance sample.
- This report and Godot-generated `.uid` sidecars.

## Files modified

- `assets/dev_local/room_layouts/garden.tscn` — complete editable replacement,
  with organized destination groups and retained shared GLB PackedScenes.
- `scripts/core/editable_main.gd` — Garden-only current-layout fallback when the
  local scene is absent; visible procedural NPC fallback without local GLBs.
- `scripts/rooms/room_definitions.gd` — **Garden only:** south spawn and elevated
  follow offset `(2.2, 11.8, 16.8)`. Other room definitions are unchanged.
- `scripts/ui/room_preview.gd` — **Garden only:** pond overview and its own
  lighting, avoiding the preview's extra lights washing out this room.
- `scripts/study/seat_availability_glow.gd` — optional Garden cushion-height
  metadata; existing rooms retain their original values.
- `assets/local_asset_manifest.json` — metadata for the new/reused Garden props.

`main.gd`, shared character/animation code, Library/Train/Japanese scenes and
their manual furniture, StudySpots and cameras were not edited in this task.
Pre-existing unrelated working-tree changes were preserved. No whole-project
room bake, Git commit, or push was performed.

## Owner-local assets

Source directories below are under `asset_library/Model/`. New binaries are
under ignored `assets/dev_local/blender_generated/runtime/` and are **not CC0,
not redistributable, and must not be committed**, including extracted textures.

| Actual source mesh | New runtime GLB | Choice |
| --- | --- | --- |
| `BridgeLog.Nin_NX_NVN/BridgeLog03.dae` | `garden_pond_log_bridge.glb` | Log cross-route; removed winter-snow mesh during conversion |
| `FtrCafeParasoltable.Nin_NX_NVN/FtrCafeParasoltable.dae` | `garden_pond_parasol.glb` | Body 0 / fabric 1 texture variants |
| `FtrGardenrockLow.Nin_NX_NVN/FtrGardenrockLow.dae` | `garden_pond_low_rock.glb` | Low shoreline clusters |
| `PltTreeOakSakura.Nin_NX_NVN/PltTreeOak4Sakura.dae` | `garden_pond_blossom.glb` | Six authentic flowering trees |
| `FtrWesternGazebo.Nin_NX_NVN/FtrWesternGazebo.dae` | `garden_pond_gazebo.glb` | Green body 2 variant; original golden runtime gazebo is untouched |

Reused runtime GLBs: `garden_big_tree`, `garden_oak_tree`, `garden_forest_bench`,
`cafe_chair`, `garden_cafe_table`, `garden_party_light_arch`, `garden_log_seat`,
`garden_cafe_counter`, `garden_cafe_coffee_mill`, `garden_cafe_siphon`,
`garden_cafe_milk_pitcher`, `garden_cafe_coffee_cup`, `garden_cafe_saucer`,
`garden_forest_firepit`, `garden_shrub`, `garden_flower_patch`,
`garden_weed_clump`, `garden_rock_a`, `garden_rock_b`, `garden_hedge`, and
`garden_forest_lamp`. Existing `tile.png` and `garden_grass.jpeg` are reused.

Not selected: BridgeWood/Stone/Japanese/Suspension (one consistent log-bridge
family), Japanese gazebo/pergola (avoid competing landmarks), palms (temperate
garden), the old golden gazebo variant (green better complements the pond),
old pool/fountain/market/trailer/tent/mountains (superseded composition). No
shared runtime GLBs were overwritten.

## Backup and preservation

The exact original Garden is preserved at:

`assets/dev_local/backups/garden_central_pond_redesign/20260909-121834/garden.tscn`

Its SHA-1 is `b1f3c6f0947dc5f012b10150745cca4b60559407`.
Every later Garden-only rebuild also makes its own timestamped backup. A
`.gdignore` keeps backup scripts out of Godot's global-class registry.

Unchanged authored scene SHA-1 values:

- Library: `b4a61f0f3f3560d138728105eaa6e4b86b5fbe65`
- Train: `b1ff29a2873a5913b4cffdec2587a099ec8f6d9e`
- Japanese: `a7d832ad1df0e6e170d6dfb54fc90c466be9f4fe`

## Validation

Commands run from the repository (Godot executable abbreviated below):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_logic.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_application_flow.gd -- --review=ui_test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_central_pond.gd -- --review=ui_test
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/review_central_pond.gd -- --review=ui_test
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/measure_central_pond.gd -- --review=ui_test
/Applications/Godot.app/Contents/MacOS/Godot --path . --write-movie /tmp/studytown-central-pond/full-game.png --fixed-fps 10 --quit-after 30
```

Results: 13 logic checks, 261 application-flow checks and 147 Garden checks.
Garden checks cover all four room loads/grounded spawns, every ring segment,
both actual grounded bridge traversals, pond/rail rejection, all standing
anchors and their reachability, available-seat camera clearance, and public
fallback geometry/anchors. Screenshot testing presses E for all six categories.

The short warmed M2 Pro native sample recorded 57–145 FPS, averaging 76 FPS
(eight one-second samples after warmup). This is not a web-export benchmark or
a guarantee at every display size; the foliage remains a substantial part of
the render workload.

Screenshots and logs stay outside Git in `/tmp/studytown-central-pond/` because
they contain owner-local art. The review covers entrance, elevated overview,
pond/island, gazebo, café, campfire, gazebo-to-pond view, each seat category and
active focus. These are temporary review artifacts, not public assets.

## Remaining visual limitations

- The supplied models give this a brighter, stylized console-game appearance
  rather than the concept's painterly evening rendering. The Western gazebo
  has a domed roof, not the concept's faceted roof.
- Tree/flower silhouettes retain the source models' cutout foliage and can
  show flat layers up close. Public fallbacks deliberately use simpler art.
- Water uses animated shading/specular in Compatibility, not planar scene
  reflections. Background students are the existing local simulation, not
  networked players. No new licensed music or ambient recordings are included.

To regenerate only this Garden deliberately:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/editor/rebuild_garden_central_pond.gd -- --replace-garden
```
