# StudyTown UI Overhaul — Summary

Reference: lofi.town walkthrough (`UI_reference.mp4`; frames in
`assets/dev_local/ui_reference/`). Direction: dark tactile UI, StudyTown
identity (no copied artwork/text/branding).

## What changed
- **Design system** (`scripts/ui/study_theme.gd`, global `StudyTheme`):
  dark tokens, tactile buttons (hover brighten / press-down depth /
  disabled), chips, drawers, modals, sliders, toggles, HUD pills, keycaps,
  toasts, type scale. All new UI builds from it; `warm_ui.gd` facade removed
  and its callers repointed (session/social/music/nameplates/flow).
- **HUD**: compact room card, top-right pill (coins/launcher/music/members),
  bottom-left music card + expander, keycap E prompt. Same node contracts.
- **Dashboard**: kept + wired (sidebar incl. World Map entry, stats,
  featured, 3 room cards → bar-sweep travel).
- **Map** (`map_screen.gd` + `destination_registry.gd`): drawn stylized isle
  + 3 data-driven destination cards + HERE badge + back behavior.
- **Transitions** (`transition_fx.gd`): 6 black bars sweep L→R staggered,
  cover, swap, sweep-reveal. Used room→map and map→room.
- **Exits**: Area3D thresholds inside library/café/train doors; movement
  locks, map opens, exteriors stay unreachable (baker strips triggers).
- **Auth** (`auth_screens.gd` + `services/auth_service.gd`): dark welcome /
  login / signup, email+password only, masked, friendly errors, loading
  guard. Dev-only salted-hash local store, explicitly labelled — NO
  production backend exists (no Firebase/Supabase/Auth0/Clerk).
- **Onboarding**: 4 short steps (clamped indexing keeps old flows green).
- **Launcher + settings** (`app_launcher.gd`): drawer with Map/Friends/
  Focus/Settings; persistent Seat Availability View toggle (default ON).
- **Seat highlights**: single state machine in driver (setting ON + standing
  + not suspended); extended to train benches (no more floor discs anywhere);
  seated/setup/focus/map all suppress; interaction logic untouched.
- **Boot routing**: fresh → splash → welcome → auth → onboarding → map;
  returning → splash → map. `home()` semantics preserved for tests/reviews.

## QA (all visually inspected, `art_reviews/ui/`)
welcome/signup/login/onboarding×2/map/map-from-exit/sweep-mid/covered/
travel-sweep/rooms×3/launcher/settings/music×2/seat-prompt/setup/focus/
dashboard. Glow matrix per room (on/seated/off/on-again). Full seat reviews
re-ran: café 39/39, library 27/27, train 24/24. Walk routes re-ran.
1440×900 spot-check clean. `test_application_flow.gd`: 343/343.

## Known limitations
- Map isle + brand mark are drawn primitives (see MISSING_UI_ASSETS.md).
- Legacy overlays (chat/members/profile/focus editor) keep older dark
  styling (consistent family, not yet tactile components).
- Fresh-windowed first builds are slow (shader compile); harness waits are
  state-polled to compensate.
