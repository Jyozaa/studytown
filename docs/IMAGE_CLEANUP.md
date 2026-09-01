# Image cleanup

The repository-wide audit classified every tracked PNG by dependency and purpose.

## Result

- Tracked PNGs before cleanup: 722
- Runtime-referenced tracked PNGs: 0
- Obsolete review captures removed: 20
- Redundant Kenney source preview renders removed: 702
- Tracked PNGs after cleanup: 0

The 20 review images described the pre-overhaul character and rooms and were superseded by the local before/after review set. The 702 Kenney `Isometric`, `Side`, `Preview`, and `Sample` renders were presentation previews; the game loads selected GLBs from `assets/external/kenney_furniture_kit/` and never references those PNGs. The pack license and model sources remain retained.

Current screenshots and their Movie Maker frame/audio sidecars are ignored under `art_reviews/baseline/` and `art_reviews/current/`. No proprietary texture, render, screenshot, archive, or derivative is committed.

For the September 1 polish pass, the obsolete ignored alligator backup and intermediate Movie Maker frame sets were moved recoverably to macOS Trash as `studytown_legacy_alligator_backup_20260901`, `studytown_art_reviews_current_pre_final_20260901`, and `studytown_art_reviews_current_pre_targeted_20260901`. `art_reviews/current/` now retains only the 21 compact named QA captures. `git ls-files` still reports zero tracked PNG/JPG review images.
