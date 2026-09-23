# Library and Train seating audit

Garden: 32/32 validated; see `GARDEN_SEATING_AUDIT.md`.
Library: 18/18 validated with Rosie and Bangle (36 complete interaction runs).
Train: 24/24 validated with Rosie and Bangle (48 complete interaction runs).

## Furniture coverage

Library has 17 physical seating objects and 18 independent positions: twelve desk chairs, four armchairs (including the two formerly decorative right-alcove chairs), and a two-position sofa.

Train has twelve reachable physical benches and 24 independent positions. Four inner benches now have a second slot, matching the outer benches. Left bench slot pitch is 1.4 m within the existing 2.01 m cushions; right bench pitch is 1.56 m within the existing 3.28 m cushions. Eight benches on moving exterior scenery tiles are not reachable and are intentionally excluded.

Runtime inventory metadata maps each StudySpot to its actual furniture instance and detects furniture without an interaction. Library/Train saved scenes and all source assets are unchanged. Only seat anchors, interactions, camera configuration and review tooling are modified.

## Camera and interaction changes

- Library's two alcove armchairs have explicit approach, sitting and facing transforms.
- Train's left bench approaches use open bench ends: the aisle is narrower than the walking capsule. Right compartment approaches are offset clear of the bench collider.
- Facing-sensitive selection disambiguates opposite seats sharing an approach position.
- Precise visible mesh triangles validate interior camera lenses and head/chest/lower-torso sightlines. Oversized walking colliders remain unchanged, but do not falsely occlude seated characters in camera tests.
- Nearby occupied seats are tested with wide-character envelopes and visible Bangle occupants.
- Train session cameras stay inside the carriage's X/Z bounds, at FOV 40/42. Its exploration camera endpoint is horizontally bounded so entry/exit paths do not cross outside the shell.
- Existing global room B-roll cameras remain in the scenes. The audit checks their sightlines per seat; personal sessions use the two validated per-seat shots instead of unrelated global compositions.
- Setup, focus-to-focus, completion and exit transitions use swept lens-clearance checks.

## Library per-seat results

Every PASS covers both character sizes: E prompt, sit/yaw alignment, setup/right-third framing, primary, secondary, clearance, completion, release and stand-up/exit.

| Seat | Result |
|---|---|
| library-communal-0-n-0 | PASS |
| library-communal-0-s-0 | PASS |
| library-communal-0-n-1 | PASS |
| library-communal-0-s-1 | PASS |
| library-communal-1-n-0 | PASS |
| library-communal-1-s-0 | PASS |
| library-communal-1-n-1 | PASS |
| library-communal-1-s-1 | PASS |
| library-lounge-sofa-left | PASS |
| library-lounge-sofa-right | PASS |
| library-lounge-chair-left | PASS |
| library-lounge-chair-right | PASS |
| library-alcove-armchair-left | PASS |
| library-alcove-armchair-right | PASS |
| library-window-desk-0 | PASS |
| library-window-desk-1 | PASS |
| library-window-desk-2 | PASS |
| library-window-desk-3 | PASS |

## Train per-seat results

Every PASS covers both character sizes and the same interaction/camera checks listed for Library. All final setup, primary, secondary and isolated alignment screenshots were inspected.

| Seat | Result |
|---|---|
| train-left-outer-00-a | PASS |
| train-left-outer-00-b | PASS |
| train-left-inner-00 | PASS |
| train-left-outer-01-a | PASS |
| train-left-outer-01-b | PASS |
| train-left-inner-01 | PASS |
| train-left-outer-02-a | PASS |
| train-left-outer-02-b | PASS |
| train-left-inner-02 | PASS |
| train-left-outer-03-a | PASS |
| train-left-outer-03-b | PASS |
| train-left-inner-03 | PASS |
| train-right-00-north-a | PASS |
| train-right-00-north-b | PASS |
| train-right-00-south-a | PASS |
| train-right-00-south-b | PASS |
| train-right-01-north-a | PASS |
| train-right-01-north-b | PASS |
| train-right-01-south-a | PASS |
| train-right-01-south-b | PASS |
| train-left-inner-00-b | PASS |
| train-left-inner-01-b | PASS |
| train-left-inner-02-b | PASS |
| train-left-inner-03-b | PASS |

## Verification

- Garden: 32/32 positions, 64 full interaction runs.
- Library: 18/18 positions, 36 full interaction runs.
- Train: 24/24 positions, 48 full interaction runs.
- Interior inventory, all-available prompt selection, independent occupancy/glows, standing-capsule clearance, candidate cameras and transition checks: zero failures.
- Application flow: 301 checks, zero failures.
- Central pond/grounding/reachability regression: 649 checks, zero failures.
- Logic: 13 passed.
- Library, Train and Japanese saved-scene SHA-1 hashes match their pre-audit values.

## Review commands

From the repository root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --review=garden-seats
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --review=library-seats
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --review=train-seats
```

Labels use G01–G32, L01–L18 and T01–T24. Left/right select seats; 1/2/3 show setup/primary/secondary; 4 isolates seated alignment; N toggles neighbouring occupants; C switches small/wide character; R re-solves.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/audit_interior_cameras.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/review_every_garden_seat.gd -- --room=library --output=/tmp/studytown-library-seats
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/review_every_garden_seat.gd -- --room=train --output=/tmp/studytown-train-seats
```

The historical test filename supports all three rooms. Screenshots and raw run results stay under `/tmp`, outside Git, because they show owner-local assets. OpenGL emits texture-teardown warnings at test shutdown; these are not interaction or script failures. Web performance has not been benchmarked in this audit.
