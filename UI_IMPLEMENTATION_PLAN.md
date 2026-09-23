# StudyTown UI Overhaul — Implementation Plan

Reference: `UI_reference.mp4` (frames in `assets/dev_local/ui_reference/`).
Target: lofi.town interaction language, StudyTown identity, DARK tactile UI.

## Keep (working systems, do not rebuild)
- 3 rooms: geometry, furniture, StudySpots, cameras, NPCs, environments.
- Seat flow core: E → reserve → sit → setup camera → session → exit.
- FocusManager, rewards (`projected_reward`), music controller logic.
- `dark_ui.gd` helper pattern (extended, not replaced).
- New backend pieces (already built, kept): `AuthService` (dev adapter),
  destination registry, seat-highlight state machine (driver gate + train
  extension + `seat_availability_view` pref), exit triggers + baker strip,
  `GameState.auth_email`, flow AUTH/MAP states + boot routing.

## Refactor (visual system, same architecture)
- `study_theme.gd` → DARK tokens + tactile buttons (hover/press/depress),
  chips, drawers, modals, sliders, toggles, HUD pills, keycaps.
- HUD (`session_panels.hud`): compact dark top bar, room card, music pill,
  keycap seat prompt. Same node contracts (`prompt_label`, `timer_label`).
- Session setup/active/complete/music/members/drawers → dark tactile,
  same node names + sync behavior (`DurationInput`, `DurationSlider`).
- Dashboard → sidebar + stats + 3 room cards (mock numbers).
- Onboarding 12 → 4 steps (clamped indexing keeps old tests green).

## Replace/add
- Map: dark stylized world panel (drawn landmass + markers + preview cards),
  NOT flat buttons. Bar-sweep transition (black bars L→R, cover, swap,
  reveal) for room↔map. Exit triggers already installed (library/café/train
  doors); verify in QA.
- Auth: dark welcome/login/signup (email+password only) → onboarding → map.
- Launcher + settings drawer (seat toggle, persisted, default ON).
- `MISSING_UI_ASSETS.md` for anything not drawable with theme primitives.

## Test contracts to preserve
- `test_application_flow.gd`: home→HOME, 12-step render loop (clamp),
  DurationInput/Slider sync, overlays during session, end_early→HOME.
- Seat reviews, walk tests, radii probes: untouched room systems.

## QA (screenshots, every phase)
ui_first_launch/welcome/signup/login/onboarding/map/transition frames/
room×3/seat_prompt/session_setup/focus_active/launcher/settings/music×2,
seat-glow on/off/seated behavior per room, 3 resolutions spot-checks.
