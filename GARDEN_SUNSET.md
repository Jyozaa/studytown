# Garden sunset environment

Garden-only follow-up to the central-pond layout. The 52 × 38 playable bounds,
18 StudySpots, six NPCs, bridge ramps and seating transforms are preserved.
Library, Train and Japanese room files retain their previous SHA-1 hashes.

## Implemented

- Deep muted grass shared across the clearing and surroundings, darker soil
  and stone paths, a 29-degree peach sun, cool ambient fill and eight amber lights.
- A procedural blue/violet-to-peach sky, distance haze beginning at 40 units,
  and a rounded 480 × 400 landscape with gradual hills and a distant ridge.
- Irregular near-tree clusters, instanced existing oaks in the middle distance,
  and lightweight far-forest silhouettes. Forest batches occupy 48-unit cells
  so off-screen areas can be culled. Scenery trees have no collision or emitters.
- A separate dark blue-green pond shader with animated normals, depth-colour
  variation and one update-once reflection probe for static tree/gazebo scenery.
- Six cherry emitters × 20 petals, 18 oak emitters × five leaves, and 14 island
  leaves: maximum 224 live particles, all GPUParticles3D. Two shared GPU motion
  materials provide consistent northeast drift, randomized phase, tumble,
  gentle flutter and finite lifetimes. No CPU leaf update loop or accumulating
  ground scatter. Imported tree meshes are not deformed.

## Verification

- Garden suite: 607 checks, zero failures, including real grounded bridge
  crossings, the complete ring route, every standing anchor, public fallback,
  particle budget and persisted forest instance data.
- Application flow: 261 checks, zero failures. Logic: 13 passed.
- Compatibility-renderer screenshots cover entrance, pond, gazebo, café,
  campfire, six seated categories, active focus, and paired petal-motion frames.
- Four cardinal map edges use the actual fixed follow camera, plus broader
  outward 10- and 65-degree downward stress views. Exploration has no user
  pitch/orbit range; its controls and camera restrictions were not changed.
- Screenshots remain outside Git at `/tmp/studytown-garden-sunset/` because
  they contain owner-supplied reference assets.

The first measured forest implementation submitted 1,633,430 primitives in the
entrance view. Spatial batching reduced this to 1,000,747 (about 39% fewer), with
2,183 draw calls. Desktop warm runs measured 33.1–34.5 FPS on this M2 Pro; this is
not a 60-FPS claim or a browser/WebGL benchmark. Further web-device profiling
is still needed. The far ridge is deliberately simplified, not a high-detail
mountain asset. Pond reflections are a static cubemap, not live planar mirrors.

## Files and recovery

Environment construction: `scripts/rooms/garden_sunset.gd`.
Headless-safe instance restoration: `scripts/world/garden_forest_instances.gd`.
Garden-specific shaders: `garden_meadow`, `garden_sunset_sky`,
`garden_sunset_water`, `garden_leaf_motion`, and `garden_drifting_leaf`.

The exact pre-sunset Garden is backed up at:
`assets/dev_local/backups/garden_central_pond_redesign/2026-09-09T18-02-52/garden.tscn`.
Every subsequent bake also retains a timestamped backup. No supplied asset
meshes or textures were edited, removed or committed during this pass.

Rebuild only the Garden (with backup):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/editor/rebuild_garden_central_pond.gd -- --replace-garden
```

Visual review:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/review_central_pond.gd -- --review=ui_test
```

The GPU motion implementation uses Godot's documented particle `start()` and
`process()` stages: https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/particle_shader.html
