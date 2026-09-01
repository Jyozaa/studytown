# Local ACNH development import

These tools operate only on files supplied by the project owner or downloaded directly from the cited Models Resource pages. Output belongs in `assets/dev_only_acnh/`, which is ignored by Git.

Example:

```bash
"/Applications/Blender.app/Contents/MacOS/Blender" --background --factory-startup \
  --python tools/acnh_import/blender_character_pipeline.py -- \
  --source-fbx "/path/to/Alligator.FBX" \
  --texture-dir "/path/to/00 - Alfonso" \
  --output "$PWD/assets/dev_only_acnh/characters/alfonso.glb" \
  --character-id alfonso
```

The source FBX has a 48-bone rig but no animation actions. The pipeline adds prototype Idle, Walk, Sit, StudyLaptop, StudyBook, Wave, and Stretch actions locally and emits a diagnostic JSON beside the ignored GLB.

`blender_prop_pipeline.py` normalizes owner-supplied FBX props to a requested world-space height. Blender 5.2 no longer bundles a working Collada importer, so DAE-only chair candidates need a trusted Collada-capable conversion step before this pipeline; the current local build uses the FBX books, mug, oak tree, and flower sources.
