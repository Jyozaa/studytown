# MISSING_UI_ASSETS.md — StudyTown UI illustration wishlist

> Production UI status: the current production UI (`scripts/ui/production/`) needs zero external art — map vignettes are project renders in `assets/ui/map/`, everything else is theme-drawn. See `docs/ui/ADDITIONAL_UI_ASSETS.md`. The wishlist below remains as optional future illustration upgrades.

All current UI is drawn with Godot theme primitives (`study_theme.gd`) and
existing in-game assets, so the app is fully runnable with zero missing art.
The items below are OPTIONAL illustration upgrades a designer could supply
later; each lists placement, file name, size, transparency, and description.

## How to integrate
Drop the finished file at the listed `res://` path, then replace the matching
primitive block noted in “Used instead”. Keep the file name exactly.

---

### 1. MAP_ISLE — illustrated world-map panel art
- **Path:** `res://assets/ui/map_isle.png`
- **Recommended size:** 1320 × 876 px (2× of the 660 × 438 panel)
- **Transparent background:** YES (rounded panel corners + soft edge)
- **Description:** Top-down stylized island group in muted teal/green/sand
  matching the in-game palette, with three vague building clusters where the
  code markers sit and soft noisy shores. No text (labels are drawn by code).
- **Used instead:** `MapCanvas._draw` in `scripts/ui/map_screen.gd`
  (primitive blobs + marker dots + cloud).

### 2. BRAND_MARK — StudyTown logo/wordmark
- **Path:** `res://assets/ui/brand_mark.png`
- **Recommended size:** 480 × 160 px
- **Transparent background:** YES
- **Description:** Cozy rounded wordmark reading “StudyTown” with a small
  open-book-plus-moon glyph, warm cream on transparent, readable at 200 px.
- **Used instead:** text label “◈  StudyTown” in auth + onboarding + launcher.

### 3. ROOM_THUMB_LIBRARY — Grand Library thumbnail
- **Path:** `res://assets/ui/room_thumb_library.png`
- **Recommended size:** 640 × 360 px (16:9)
- **Transparent background:** NO (full-bleed card art)
- **Description:** Warm evening-glass library hall thumbnail: tall windows,
  bookshelves, amber lamps. Used on dashboard cards and a future map card.
- **Used instead:** live `RoomPreview.make_preview("library")` viewports.

### 4. ROOM_THUMB_CAFE — Garden Café thumbnail
- **Path:** `res://assets/ui/room_thumb_cafe.png`
- **Recommended size:** 640 × 360 px (16:9)
- **Transparent background:** NO
- **Description:** Sunset courtyard café thumbnail: round tables, string
  lights, terracotta floor.
- **Used instead:** live `RoomPreview.make_preview("garden")` viewports.

### 5. ROOM_THUMB_TRAIN — Scenic Train thumbnail
- **Path:** `res://assets/ui/room_thumb_train.png`
- **Recommended size:** 640 × 360 px (16:9)
- **Transparent background:** NO
- **Description:** Quiet carriage interior thumbnail: blue booth benches,
  warm lamps, windows with passing hills.
- **Used instead:** live `RoomPreview.make_preview("train")` viewports.

### 6. ONBOARDING_SPOT — onboarding spot illustration
- **Path:** `res://assets/ui/onboarding_spot.png`
- **Recommended size:** 760 × 300 px
- **Transparent background:** YES
- **Description:** Small horizontal vignette of an empty armchair beside a
  glowing floor lamp and books stack, for onboarding steps 3–4.
- **Used instead:** typographic cards only (no illustration at present).

### 7. ICON_SET — launcher/HUD glyphs (optional)
- **Path:** `res://assets/ui/icons/` (one file per glyph, see names)
- **Recommended size:** 96 × 96 px each (`icon_map.png`, `icon_friends.png`,
  `icon_focus.png`, `icon_settings.png`, `icon_music.png`, `icon_members.png`,
  `icon_menu.png`, `icon_close.png`)
- **Transparent background:** YES
- **Description:** Rounded minimal line glyphs in warm cream, 10 px stroke,
  matching the tactile button style.
- **Used instead:** unicode glyphs (◈ ♧ ⏱ ⚙ ♫ ☰ ×) drawn as button text.
