# Garden seating and camera audit

Garden: **32 / 32 slots validated**, each with Rosie and Bangle (64 complete interaction runs). Library and Train are also complete; see `INTERIOR_SEATING_AUDIT.md`.

## Furniture manifest

23 physical seating objects; 32 independent StudySpots; zero intentionally non-interactive reachable seating objects.

| Zone | Objects | Slots | Furniture |
|---|---:|---:|---|
| Island | 2 | 4 | Two two-person benches |
| Gazebo | 4 | 4 | Four chairs |
| Café | 6 | 6 | Six chairs, including the third table |
| Campfire | 3 | 6 | Three two-person logs |
| Study lawn | 4 | 4 | Four chairs |
| Quiet grove | 2 | 4 | Two two-person benches |
| North shore | 2 | 4 | Two two-person benches |

Bench instances are 3.02 m wide and logs 2.94 m wide, with 1.56 m slot spacing. Only instance width was adjusted; source meshes were not modified. The island bank was widened and its benches separated to preserve a central walking passage. The two shoreline benches moved 1.2 m away from the ring path to clear their wider backs. No furniture was rotated for camera convenience.

Measured cushion/contact surfaces, rather than total model heights, were used to correct bench/log hip contact. Availability glows sit just above those surfaces.

## Per-slot results

Every PASS below covers both character sizes. Alignment was inspected in isolated side views. Setup, primary and secondary views were inspected with nearby Bangle mock occupants visible.

| Slot ID | Alignment | Setup | Primary | Secondary | Occlusion | E / exit / completion |
|---|---|---|---|---|---|---|
| garden_cafe_08_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_cafe_09_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_cafe_10_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_cafe_11_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_cafe_12_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_cafe_13_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_campfire_14_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_campfire_14_B | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_campfire_16_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_campfire_16_B | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_campfire_18_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_campfire_18_B | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_gazebo_04_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_gazebo_05_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_gazebo_06_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_gazebo_07_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_grove_24_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_grove_24_B | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_grove_26_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_grove_26_B | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_island_00_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_island_00_B | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_island_02_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_island_02_B | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_lawn_20_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_lawn_21_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_lawn_22_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_lawn_23_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_shore_28_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_shore_28_B | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_shore_30_A | PASS | PASS | PASS | PASS | PASS | PASS |
| garden_shore_30_B | PASS | PASS | PASS | PASS | PASS | PASS |

## Validation and implementation

- Every slot: visible E prompt, real E input, correct seated position/yaw, independent reservation, setup framing, two active shots, completion retaining the slot for break setup, release and reachable standing return.
- Setup FOV 40; secondary FOV 44. Character head projection is about 74.6–74.9% across the viewport.
- Five rays cover head, chest, torso and both sides of the head. Camera-only triangle geometry includes foliage, columns, tables, chair backs and other visible Garden props. Canopy volumes reject lenses inside leaf cards.
- Occupied-neighbour envelopes participate in visibility and swept-lens transition checks. Direct transitions, opening waypoints and revalidated reverse entry routes avoid cutting through geometry.
- The hidden follow rig resolves its final standing pose before the return dolly; movement resumes after the camera tween finishes.
- Accepted coordinates are stored in `resources/cameras/garden_seats.json`, applied to exported StudySpot overrides and revalidated at runtime. The solver is a fallback, not the only source of authored coordinates.
- 649 Garden/navigation checks, 289 application-flow checks and 13 logic checks passed. The furniture/availability audit also passes for all 32 slots.
- Desktop Compatibility screenshots and machine results are local-only: `/tmp/studytown-garden-seats/`. No owner-supplied meshes, textures or screenshots are included in this report or committed.
- Godot reports four GL texture teardown warnings when the screenshot runner exits; no GDScript/runtime interaction failures remain in the recorded Garden runs. Browser performance has not been benchmarked by this seat audit.

## Developer review

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --review=garden-seats
```

Left/right selects a seat using its real E interaction. 1 = setup, 2 = primary, 3 = secondary, 4 = isolated alignment diagnostic, N = occupied-neighbour toggle, C = small/wide character, R = re-solve. No debug overlay appears during normal play. The alignment diagnostic is not an accepted session shot.

Automated repeat:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/audit_garden_seats.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/review_every_garden_seat.gd
```

The visual runner supports `-- --seat=7 --character=2 --output=/tmp/seat-check`; `--seats=0,1,2 --merge` rechecks affected seats while retaining unchanged rows and images.

Original pre-seat-overhaul Garden backup: `assets/dev_local/backups/garden_central_pond_redesign/2026-09-10T09-11-30/garden.tscn`. Subsequent rebuilds also create dated backups. Library, Train and Japanese room files were not rebuilt or changed during this Garden work.
