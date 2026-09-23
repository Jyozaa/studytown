# StudyTown application flow

The app uses a dark dashboard and local onboarding, with the existing authored
Godot rooms underneath a separate UI controller. No payment, premium, OAuth or
external media service is connected.

## Files in this pass

Added UI scripts under `scripts/ui/`: `application_flow.gd`, `dark_ui.gd`,
`tactile_button.gd`, `onboarding.gd`, `dashboard.gd`, `session_panels.gd`,
`social_panels.gd`, `room_nameplates.gd`, `country_flag.gd`, `seat_prompt.gd`,
and `music_controller.gd`.

Added checks: `tests/test_application_flow.gd`, `tests/capture_ui_flow.gd`.
Added documentation: this file. Godot also generates UID sidecars.

Modified: `autoload/game_state.gd`, `scripts/core/main.gd`,
`scripts/camera/follow_camera.gd`, `scripts/study/seat_availability_glow.gd`,
`scripts/ui/room_preview.gd`, and `scripts/ui/retro_character_preview.gd`.
Other pre-existing worktree changes were preserved.

## Ownership

- `scripts/ui/application_flow.gd` owns navigation, exclusive overlays, seat
  reservations, session/break handoff, early-exit rewards and review entry points.
- `onboarding.gd` and `dashboard.gd` build local account setup and app navigation.
- `session_panels.gd` builds setup, focus editing, settings, timer, completion,
  early-exit and break views.
- `social_panels.gd`, `room_nameplates.gd` and `country_flag.gd` provide local
  member/profile/chat views and vector presence badges.
- `dark_ui.gd` and `tactile_button.gd` supply shared sizes, colors, type and controls.
- `music_controller.gd` owns local audio players and mixing. `room_preview.gd`
  renders previews from the existing room scenes. The existing character-preview
  helper uses CharacterLoader, including the game's public fallback factory.
- `main.gd` retains world construction, animation, authored anchor integration
  and camera selection, with thin UI entry points. Old scrapbook/retro panel
  builders have been removed from the active main script.
- `GameState` persists the local profile, onboarding, preferences, custom tags,
  current focus and results. Its reward function is the single source of truth.
  `FocusManager` retains the existing pauseable timestamp countdown.

The controller has one base state and at most one overlay state. Opening an
overlay never restarts the timer. Closing an editor without Save discards its
focus/duration draft. Tag creation, renaming and deletion save locally immediately.

## Session behavior

Home → room exploration → E near an available seat → animated seating → setup
→ active focus → completion → break setup → break or another focus session.

The seat remains reserved through setup, focus, completion and breaks. Finish
releases it and uses its original standing anchor. Early Leave credits only whole
elapsed focus minutes; cancelled sessions do not increment completed-session
counts. Breaks earn no points. Rewards are one point/minute, plus five at 25+
minutes. F5 sets up a ten-second developer session with no fabricated full reward.

Setup cameras search front/quarter angles with world and NPC silhouette checks;
shorter front offsets serve tight window seats. The initial focus shot is kept
for 25 seconds. End/completion return smoothly to the seat composition. Invisible
named walking boundaries no longer collapse the Library exploration camera.

## Deliberately local / mocked

- Dashboard population figures, friend listings, NPC profile statistics and
  social presence are illustrative. Member lists reflect the loaded room's NPCs.
- Chat is local. Copy Room Code copies an identifying demo code, not an online
  joining link. There is no backend authentication or notification permission.
- The audio picker and mixer are wired, but this checkout contains no audio
  tracks. Missing tracks are labelled and Play is disabled. Licensed local OGGs
  can be connected at `assets/audio/radio/<station>.ogg` and
  `assets/audio/ambience/<sound>.ogg` using snake_case names. No assets were added
  or modified for this UI pass.
- Deep focus is a saved local preference. Friend boost awards nothing.

## Checks and visual review

Run from the project root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_logic.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_application_flow.gd -- --review=ui_test
```

The flow test disables disk persistence, covers onboarding/navigation, all
available study-seat setup cameras in Library/Garden/Train, duration and reward
rules, pause/overlays, completion/break/repeat, early exit, grounding and unchanged
seat/world identity. It does not alter authored scene files.

Latest validation: 247 application-flow checks and 13 existing logic checks
passed. Headless editor import and the rendered screenshot tour completed without
parse/compiler errors. Library, Garden, Train and Japanese room file hashes were
unchanged from the start of this pass.

For a screenshot tour, create a temporary directory, then run:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/capture_ui_flow.gd -- --review=ui_test --capture-dir=/tmp/your-existing-review-directory
```

The tour captures onboarding, buddy selection, Home, all three room setups,
focus/tag settings, active timers, social/music overlays, ending and breaks.
Screenshots must stay outside Git because local development assets are private.
Quick visual entries also include `--review=ui_home`, `ui_onboarding`,
`ui_setup_library`, `ui_setup_garden`, `ui_setup_train` and `ui_active_library`.

Settings → Replay onboarding resets only the onboarding flag, not earned progress.
No editable room scene, furniture transform, StudySpot anchor, character profile,
local asset, train scenery or Garden effect is rewritten by this implementation.

## UI overhaul: warm paper system, Map, transitions, auth

The gameplay UI now uses one warm-paper design system instead of the dark
dashboard panels.

- `scripts/ui/study_theme.gd` is the single source of truth for colour tokens,
  radii, motion durations and shared primitives (`button`, `icon_button`,
  `chip`, `toggle`, `slider`, `text_field`, `drawer`, `modal`, `keycap`,
  `toast`, `hud_pill`, `wrap`).
- `scripts/ui/warm_ui.gd` exposes the historical `dark_ui` static API while
  delegating every token to `StudyTownTheme`, so older panels (social drawers,
  nameplates, music) became warm without a rewrite.
- HUD: room identity top-left, compact global pill top-right (currency, music,
  members, menu), music bottom-left, contextual `[E] Take seat` bottom-right.
- The old dashboard room picker is no longer part of navigation; `State.HOME`
  and `State.MAP` both build the Map.

### Map and travel

`scripts/ui/destination_registry.gd` holds destination data (id, room index,
name, description, population, accent, map slot). `scripts/ui/map_screen.gd`
renders destinations from that registry over the live world. The Map opens from
the menu launcher (`open_map`) or automatically after walking into a room exit
(`request_exit_to_map`).

Each room has one thin `RoomExitTrigger` box placed just inside its real door
threshold (`main._install_exit_trigger`), clear of the spawn point. `transition_in_progress`
swallowing is handled by a single persistent veil on its own CanvasLayer:
a ~140 ms warm dip in, the room swap behind an opaque veil, then a ~180 ms dip
out — matching the fast cut-with-dip rhythm measured in the reference video
rather than a slow fade. Music is never restarted; `GameState` session, reward,
settings and profile state are preserved across travel.

### Auth, onboarding and seat availability

- First launch: splash → Welcome → email+password Create account / Log in →
  short four-step onboarding (welcome, buddy, choose somewhere, take a seat) →
  Map. Signup collects email and password only, with no social login.
- `scripts/services/auth_service.gd` is a clean `create_account`/`sign_in`/
  `sign_out` abstraction. There is **no production backend**; the bundled
  adapter is an explicitly labelled LOCAL DEV store that keeps a salted SHA-256
  hash in `user://studytown_auth_dev.json` and never stores, logs or prints a
  password.
- Seat Availability View lives in Settings (default ON, persisted in
  `GameState.preferences`) and is enforced by one authoritative predicate,
  `main.seat_highlights_allowed()`: setting ON + not suspended + nobody seated.
  It gates visuals only — `StudySpot` reservation and E-take-seat never depend
  on it.

Run the overhaul QA tour (screenshots stay in the gitignored dev folder):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/capture_ui_overhaul.gd
```

It writes the required `ui_*.png` states plus transition frame sequences to
`assets/dev_local/ui_qa/` and prints a structural layout audit (off-canvas
controls, overlapping sibling panels, clipped labels) for every state.
