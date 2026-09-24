# StudyTown Production UI

World-first presentation layer over the validated gameplay core.
Lives in `scripts/ui/production/`. Visual identity: warm cream/parchment
panels, dark ink text, muted green / blue-grey / amber accents, tactile
buttons, modest rounding, restrained shadows.

## Dependency rule

```
GAMEPLAY (gameplay_flow, FocusManager, GameState, rooms, cameras)
  ↑  calls / reads / signals
PRODUCTION UI (this folder)
```

The UI never owns seating, occupancy, player position, StudySpot state,
timing, rewards, cameras, room construction, or NPC state.

## Startup

- Normal `Godot --path .` → splash → welcome/local-account → onboarding
  (first run) → world map → room HUD.
- `Godot --path . -- --dev-strip` → stripped dev boot (hint + dev panel).
- Auth is local-prototype only (`scripts/services/auth_service.gd`).

## Screens and states

| Area | File | Notes |
|---|---|---|
| Theme/tokens | `ui_theme.gd` | Colors, radii, timings, panel/button/chip/toggle/slider/text/drawer/modal/toast/keycap |
| Controller | `production_ui.gd` | Modes, drawers stack, travel, transitions, M/Esc keys, F9 dev panel |
| Room HUD | `world_hud.gd` | Room chip, action cluster, music pill, seat prompt, nameplates, click picking |
| World map | `world_map.gd` + `map_location.gd` | 2×2 vignettes, dotted routes, hover lift/glow, keyboard nav, HERE pin |
| Transition | `pixel_transition.gd` | Stepped diagonal pixel wipe; reduced-motion dip fallback |
| Minimap | `minimap.gd` | Live room outline + seats + player/NPC markers, zoom, close |
| People | `people_drawer.gd` | ROOM/FRIENDS/SEARCH over live presence (player + NPCs) |
| Chat | `local_chat.gd` | LOCAL radius count + in-memory messages; honest empty DM |
| Player card | `player_card.gd` | Occupant name/state, local-only Wave |
| Focus | `focus_ui.gd` | Setup (durations/tags/rewards/Start), active timer, completion |
| Music | `music_ui.gd` | Collapsed pill + drawer; existing audio backend |
| Settings | `settings_ui.gd` | Seat toggle, names, reduced motion, mute; persisted prefs |
| Onboarding | `onboarding_ui.gd` | Welcome/auth + 4 steps + character pick |
| Assets | `ui_asset_registry.gd` | Final-then-placeholder resolution, never crashes |

## Key interactions

- **E**: `gameplay.try_interact()` (nearest valid seat). Prompt shows only
  when standing near an available, in-range seat.
- **M / map button / door thresholds**: map opens over the live room.
- **Travel**: guards (busy, active focus blocked with toast, seated-idle
  stands first) → pixel wipe cover → `build_room` → reveal → HUD restore.
  Selecting the current location just closes the map.
- **Seat highlights**: `seat_highlights_allowed()` (setting ON + standing +
  not suspended). Toggle persists; interaction works while hidden.
- **Focus**: setup panel (left) while seated; Start calls
  `GameplayFlow.start_focus`; active card shows live remaining; completion
  panel offers Another/Take Break (gameplay-owned, no reward)/Stand Up.
- **Chat input**: disables player movement while focused, restores after.

## Performance notes

- Map vignettes are static PNGs rendered from the real rooms (no live
  SubViewports, no duplicated simulations).
- Transition is Control `_draw` rects (Compatibility-safe, no shaders).
- HUD ticks are cheap label updates; presence refreshes on drawer open.
- No per-frame scene-tree searches in production paths.

## Layout gotchas (Godot 4.7)

- `Control.size` clamps up to the Label's unwrapped text minimum width, so
  fixed strings carry their own `\n` breaks and dynamic chat text is
  word-wrapped in code (`LocalChat.wrap_lines`). Setting `autowrap_mode`
  alone does not shrink the minimum.
- Overlays position from `ProductionTheme.vp_size(node)` (viewport with a
  1280×720 fallback), never hardcoded screen coordinates: verified at
  1280×720 and 1440×900.
