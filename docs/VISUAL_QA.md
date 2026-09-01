# Visual QA

All captures come from the real Godot scene using Movie Maker mode at 1280×720. Proprietary-reference captures stay in ignored `art_reviews/current/`.

## Review matrix

| Area | Review modes/captures | Verified outcome |
|---|---|---|
| Menu | `menu` | three distinct cat choices and a readable preview |
| Character | `cat_idle`, `cat_walk`, `cat_sit`, `cat_study_laptop`, `cat_study_book`, `cat_wave`, `cat_stretch` | textured cat deformation, correct grounding, explicit loop/one-shot states |
| Library | `library`, `library_hall`, `library_fireplace`, `focus` | dense bookshelves/tables, 6 NPCs, close study view without NPC overlap |
| Garden | `garden`, `garden_focus` | planted paths and destinations, 5 NPCs, free player study seat |
| Train | `train`, `train_focus`, `train_scenery` | furnished carriage, 4 NPCs, moving multi-speed exterior scenery |
| Japanese room | `japanese`, `japanese_focus` | tatami hall, tea/reading clusters, 5 NPCs, floor-study framing |

Exploration follows a damped camera rig; focus uses room-authored cameras with a minimum readable subject distance. Player rotation does not rotate the exploration camera. Focus completion/cancellation restores the standing offset and follow camera.

The final validation pass checked the menu, wide room composition, first-personal focus shot for every room, all seven cat actions, and the debug collision/grounding overlay. Automated focus validation also enters a 10-second session, verifies personal plus B-roll cameras, cancels, and confirms room/follow-camera restoration.
