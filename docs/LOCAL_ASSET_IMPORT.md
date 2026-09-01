# Local asset import

This workflow is reproducible without placing proprietary binaries in Git. It operates only on owner-supplied files copied into the repository's ignored `assets/dev_local/` tree.

## Source integrity

- Primary source: `/Users/joe/Downloads/assets`
- Repository-local immutable copy: `assets/dev_local/source/`
- Full owner source verification: 109 files, 148,819,122 bytes
- SHA-256 of the sorted per-file SHA-256 listing: `9b3fb47e202b13071805e635ab8e62113b788a67007ad11adf8448f7e29284e9`
- Supplemental Cats archive: `/Users/joe/Downloads/Nintendo Switch - Animal Crossing_ New Horizons - Villagers - Cats.zip`
- Supplemental copy: `assets/dev_local/source/_supplemental_characters/`
- Cats archive SHA-256: `38baa327c9e4a8e52ddc2d7d21b75dbecebc35428707c2934951b7ae73a2c1dc`

The Downloads source was read and hashed but not modified. All extraction and conversion used the repository-local copy.

## Rebuild procedure

1. Copy the supplied archives into `assets/dev_local/source/` and add `.gdignore` inside source, conversion, and diagnostic directories.
2. Extract archives into `assets/dev_local/converted/extracted/` without overwriting the immutable archive copies.
3. Run `python3 tools/local_assets/audit_library.py` to regenerate `assets/local_asset_manifest.json` and `docs/ASSET_AUDIT.md`.
4. Inspect candidate FBX files with `tools/local_assets/blender_inspect.py` under Blender 5.x.
5. Convert Bob, Rosie, and Raymond with `tools/local_assets/blender_cat_pipeline.py`. The hierarchy-aware filter retains every `Body__*` component (including the ear-cap regression fix), required accessories, and the neutral top; it normalizes height to 2.70 world units and generates nine skeletal actions.
6. Convert selected FBX props with `tools/local_assets/blender_prop_pipeline.py`; keep output under `assets/dev_local/props/` or `assets/dev_local/environment/`.
7. Open the project once in Godot to import the local runtime derivatives, then run the logic/runtime tests and visual-review modes.
8. Generate genuinely missing original props with `tools/local_assets/blender_furniture_kit.py`. Nineteen local kit assets support the rich development build; the public Garden grass tuft is generated selectively and committed with its editable Blender source.

## Runtime layout

- `assets/dev_local/characters/` — Bob, Rosie, and Raymond GLBs plus diagnostic JSON
- `assets/dev_local/props/` — selected furniture and small props
- `assets/dev_local/environment/` — selected trees, plants, rocks, weeds, and tent
- `assets/dev_local/blender_generated/` — original local furniture-kit runtime GLBs and editable sources
- `assets/dev_local/source/` — immutable supplied archives
- `assets/dev_local/converted/` — ignored extraction/intermediate workspace

`assets/local_asset_manifest.json` is the only committed registry. `CharacterLoader` and `StudyTownAssetLoader` resolve resource paths from it and use public fallbacks when files are missing.

## Known source limitations

- The cat source armature contains 51 bones and no embedded actions; all nine runtime actions are generated locally.
- The Gaming Chair source is Collada-only. Godot 4.7 rejected that DAE and the installed Blender 5.2 build has no Collada importer, so it remains audited but unused. The source copy is retained.
- Froggy Chair is also Collada-only, but Godot imports this particular DAE successfully; its registry scale is 14.
- The initially converted oak derivative rendered incorrectly. The active local oak uses a previously validated derivative rebuilt from the same owner-supplied source.
- Cedar sapling/tree and two alpha-card weed variants rendered as dark rectangular cards in Compatibility. They remain audited but are intentionally not selected; the Garden uses the validated supplied weeds plus the original public Blender tuft.

## Public repository safety

Never force-add `assets/dev_local/`, generated screenshots, or web output. Before pushing, verify `git status --ignored`, `git ls-files assets/dev_local`, and a clean-clone fallback test. A public build must be exported from a checkout without the local proprietary files.
