# Visual QA

All captures come from the real Godot scene using Movie Maker mode at 1280×720. Proprietary-reference captures stay in ignored `art_reviews/current/`.

## Review matrix

| Area | Review modes/captures | Verified outcome |
|---|---|---|
| Menu | `menu` | three distinct cat choices and a readable preview |
| Character | `player_walk_readable`, `npc_walk_readable`, `library_sitting`, `train_sitting`, `japanese_sitting` | readable opposing limbs/bounce, grounded player/NPC motion, and typed seated offsets |
| Library | `library`, `library_focus_fixed`, `library_shelves`, `wall_bookshelves`, `npc_seating` | near-frontal exploration, unblocked side focus, inward wall units, finished back-to-back stacks, and aligned NPC seating |
| Garden | `garden`, `garden_focus_fixed`, `garden_tufts`, `plant_placement` | straight room read, clear focus subject, original tuft clusters, and intentional edge planters |
| Train | `train`, `train_focus_fixed`, `train_sitting`, `train_npc_seating` | straight carriage axis, booth-back-safe focus, typed booth offsets, and moving scenery |
| Japanese room | `japanese`, `japanese_focus_fixed`, `japanese_sitting`, `wall_bookshelves` | straight tatami read, clear focus framing, cushion seating, and inward-facing side shelves |

Exploration follows a damped camera rig at a 12–20 degree horizontal yaw from the room axis. Player rotation does not rotate it. Focus uses a curated seat-relative pool: candidates outside room bounds or without clear shoulder/head rays are rejected, and every cut is checked again before activation. Completion/cancellation restores the standing offset and follow camera.

Final exploration framing is measured from the look target to the camera:

| Room | Yaw | Pitch | Horizontal distance | Full distance | Height | FOV |
|---|---:|---:|---:|---:|---:|---:|
| Grand Library | 19.18° | 34.94° | 9.74 m | 11.88 m | 6.80 m | 38° |
| Garden Café | 19.65° | 34.68° | 10.41 m | 12.66 m | 7.20 m | 39° |
| Scenic Train | 13.39° | 32.05° | 8.63 m | 10.18 m | 5.40 m | 38° |
| Japanese Study Room | 18.43° | 35.24° | 9.49 m | 11.61 m | 6.70 m | 38° |

The low yaw keeps long shelves, paths, the carriage aisle, and tatami rows visually aligned while preserving the elevated three-quarter view. Train bench backs are oriented toward the windows, with the upholstered cushion and seated characters facing the aisle.

The final named runtime set in `art_reviews/current/` is:

`library_camera_fixed.png`, `garden_camera_fixed.png`, `train_camera_fixed.png`, `japanese_camera_fixed.png`, `library_focus_unblocked.png`, `garden_focus_unblocked.png`, `train_focus_unblocked.png`, `japanese_focus_unblocked.png`, `player_walk_readable.png`, `npc_walk_readable.png`, `player_sitting_library.png`, `player_sitting_train.png`, `player_sitting_japanese.png`, `npc_sitting_library.png`, `npc_sitting_train.png`, `npc_sitting_garden.png`, `bookshelf_wall_orientation_fixed.png`, `bookshelf_back_to_back_fixed.png`, `garden_grass_tufts.png`, `plant_placement_examples.png`, and `prop_grounding_fixed.png`.

Automated QA checks all 70 seats for at least two unobstructed focus candidates, injects an invalid camera to prove dynamic skipping, verifies combined character/seat offsets, validates player and NPC anchors, runs every cat loop for simulated long sessions, and confirms the exploration camera remains independent of character rotation.
