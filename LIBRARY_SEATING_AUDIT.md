# Library seating audit (revision pass)

- Total StudySpots: **33** on **30 meshes**. Zero duplicates.
- Shared meshes (intentional multi-seat): NW `couch_pillows` hosts L19-21;
  SW `couch_pillows` hosts L24-26 (whole-couch subtle highlight +
  nearest-slot emphasis; white-on-cream is inherently subtle, E prompt
  disambiguates).
- All other meshes bind exactly one seat.
- Seat IDs `library-L01..L33`; glow path: physical-mesh `material_overlay`
  (shared dim/bright materials, ~2.1 s sine). Zero floor discs/disc meshes.
- Occupied at build (6 NPCs, all verified seated at sitdist 0.0):
  L03 Theo (communal A), L12 Mina (communal B), L14 Hana (window bar),
  L22 Nora (NW lounge armchair), L29 Ren (W nook), L32 Yuki (snack).
- 27 free seats: full E -> sit -> setup/primary/secondary cameras ->
  completion -> exit review passes (`art_reviews/library/seats/`,
  validation.json 27/27 passed). NPC seats correctly refuse E
  (reserve fails, nearest skips to adjacent free seat).
- All 33 solve under realistic occupancy (NPC reservations as built).
- All 33 stand anchors verified outside every blocker AABB; full 33-leg
  physics walk of the final layout reaches every zone with zero stuck legs.
- Study-camera review notes:
  - `review_every_garden_seat` worst-case mode (all neighbours mocked) can
    starve middle seats (continuous 1.4 m neighbour columns at 1.1 m chair
    spacing leave no 3.2 m+ sightline). Batch QA ran with realistic
    occupancy (`neighbour_mode=false`, restored to true afterwards).
  - NPC-occupied seats are skipped by the batch (their freed-then-tested
    state cannot occur in play); refusal path tested separately.

## Manifest (from live `SeatHighlightDriver` report)

| ID | Zone | Furniture mesh | Sitting | Standing | NPC |
|----|------|----------------|---------|----------|-----|
| L01 | communal | chair_A_wood | (-4.3, 0.3, 0.8) | (-4.3, 0, -0.8) | - |
| L02 | communal | chair_B_wood | (-4.3, 0.3, 3.2) | (-4.3, 0, 4.8) | - |
| L03 | communal | chair_A_wood | (-3.2, 0.3, 0.8) | (-3.2, 0, -0.8) | Theo |
| L04 | communal | chair_B_wood | (-3.2, 0.3, 3.2) | (-3.2, 0, 4.8) | - |
| L05 | communal | chair_A_wood | (-2.1, 0.3, 0.8) | (-2.1, 0, -0.8) | - |
| L06 | communal | chair_B_wood | (-2.1, 0.3, 3.2) | (-2.1, 0, 4.8) | - |
| L07 | communal | chair_A_wood | (2.1, 0.3, 0.8) | (2.1, 0, -0.8) | - |
| L08 | communal | chair_B_wood | (2.1, 0.3, 3.2) | (2.1, 0, 4.8) | - |
| L09 | communal | chair_A_wood | (3.2, 0.3, 0.8) | (3.2, 0, -0.8) | - |
| L10 | communal | chair_B_wood | (3.2, 0.3, 3.2) | (3.2, 0, 4.8) | - |
| L11 | communal | chair_A_wood | (4.3, 0.3, 0.8) | (4.3, 0, -0.8) | - |
| L12 | communal | chair_B_wood | (4.3, 0.3, 3.2) | (4.3, 0, 4.8) | Mina |
| L13 | window-bar | chair_stool_wood | (-7.1, 0.35, 9.35) | (-7.1, 0, 7.75) | - |
| L14 | window-bar | chair_stool_wood | (-6.0, 0.35, 9.35) | (-6.0, 0, 7.75) | Hana |
| L15 | window-bar | chair_stool_wood | (-4.9, 0.35, 9.35) | (-4.9, 0, 7.75) | - |
| L16 | window-bar | chair_stool_wood | (4.9, 0.35, 9.35) | (4.9, 0, 7.75) | - |
| L17 | window-bar | chair_stool_wood | (6.0, 0.35, 9.35) | (6.0, 0, 7.75) | - |
| L18 | window-bar | chair_stool_wood | (7.1, 0.35, 9.35) | (7.1, 0, 7.75) | - |
| L19 | lounge-nw | couch_pillows | (-11.35, 0.1, -7.5) | (-13.4, 0, -7.5) | - |
| L20 | lounge-nw | couch_pillows | (-11.35, 0.1, -6.5) | (-13.4, 0, -6.5) | - |
| L21 | lounge-nw | couch_pillows | (-11.35, 0.1, -5.5) | (-13.4, 0, -5.5) | - |
| L22 | lounge-nw | armchair_pillows | (-10.32, 0.1, -8.04) | (-9.38, 0, -9.68) | Nora |
| L23 | lounge-nw | armchair_pillows | (-10.32, 0.1, -4.96) | (-9.38, 0, -3.32) | - |
| L24 | lounge-sw | couch_pillows | (-11.85, 0.1, 6.5) | (-13.9, 0, 6.5) | - |
| L25 | lounge-sw | couch_pillows | (-11.85, 0.1, 7.5) | (-13.9, 0, 7.5) | - |
| L26 | lounge-sw | couch_pillows | (-11.85, 0.1, 8.5) | (-13.9, 0, 8.5) | - |
| L27 | lounge-sw | armchair_pillows | (-10.71, 0.1, 8.99) | (-9.30, 0, 10.75) | - |
| L28 | reading-nook-e | armchair_pillows | (11.86, 0.1, 5.63) | (13.73, 0, 5.25) | - |
| L29 | reading-nook-w | armchair_pillows | (-13.97, 0.1, 2.66) | (-15.81, 0, 2.20) | Ren |
| L30 | reading-nook-w | armchair_pillows | (-14.02, 0.1, 4.31) | (-15.72, 0, 5.16) | - |
| L31 | reception | chair_B_wood | (11.15, 0.3, 9.5) | (12.75, 0, 9.5) | - |
| L32 | refreshment | chair_stool_wood | (10.5, 0.35, -9.35) | (10.5, 0, -7.9) | Yuki |
| L33 | refreshment | chair_stool_wood | (12.5, 0.35, -9.35) | (12.5, 0, -7.9) | - |

Fixes applied after screenshot/review QA: window-bar stools moved north of
bars facing the windows (stand anchors were inside the south wall);
reception moved SE clear of the east bar; lounge lamp moved clear of couch
exit anchors; Nora moved from couch middle slot to lounge armchair so every
slot solves under real occupancy.

## Revision pass (taller glass hall + blue hour + denser forest)

- Walls unified at 6.0 with full-height glass (sill 0-1, glass 1.0-5.2,
  header beam) on all four sides; corner piers; doorway blocker keeps
  players inside (escape-tested N/E/S/W/door).
- Central mid rows reoriented back-to-back (books outward to both aisles,
  verified in aisle screenshots) and shortened to 2 units each, opening the
  study zone; perimeter runs nudged off the glass.
- Added SW cozy corner (couch L24-26 + armchair L27) and E reading nook
  (armchair L28); real rug meshes under communal tables; aisle/window/
  snack lamps; warm pool count 8 -> 11.
- Blue-hour sky (cool #344B6A zenith, faint warm remnant), dimmer sun and
  ambient, brighter warm interior pools for the glow-through-glass effect.
- Forest: 30 near clusters, 55-tree mid ring, 70-tree far ring, grounded
  BlockBits terrace columns (W/E/N/S), 7 streetlights, 2 benches.
