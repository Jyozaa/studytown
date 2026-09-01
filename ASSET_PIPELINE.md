# Asset pipeline

1. Find the creator's original asset page, not a rehost.
2. Verify an explicit CC0/public-domain dedication in the page or bundled license. “Free” and “royalty-free” are not enough.
3. Record creator, URL, verification source, access date, files, modifications, and usage in `ASSET_LICENSES.md` immediately.
4. Retain the original archive contents under `assets/source_external/<pack>/` with `.gdignore` so Godot does not import source formats.
5. Copy only chosen game-ready files to `assets/external/<pack>/`.
6. In Blender, normalize scale (one metre = one world unit), apply transforms, repair normals, set a useful origin, simplify hidden geometry, soften intentional edges, and reshape silhouettes where required.
7. Normalize materials only when needed for cohesion. Preserve meaningful texture colour, alpha, normals, roughness, and material assignment.
8. Export GLB with embedded materials. Import in Godot, inspect from the authored camera, then add only necessary collision.
9. Prefer shared meshes/materials and MultiMesh for dense repeats. Keep hero visual quality before optimization.
10. Capture an in-game review image. If the asset reads as a foreign pack, normalize it again or remove it.

## Development-only ACNH pipeline

1. Obtain only owner-supplied files or direct downloads from the cited Models Resource page. Do not bypass access controls or create a mirror.
2. Keep archives, extracted sources, optimized GLBs, and diagnostic JSON under `assets/dev_only_acnh/` or `tools/acnh_import/work/`; both are ignored by Git.
3. Record expected paths and scale/orientation metadata in `assets/acnh_manifest.example.json`. Never hard-code arbitrary local filesystem paths in gameplay scripts.
4. Inspect mesh, materials, textures, armature, bone hierarchy, actions, orientation, pivot, and dimensions in Blender.
5. The current alligator source has a compatible 48-bone armature and no embedded actions. `tools/acnh_import/blender_character_pipeline.py` creates local prototype Idle, Walk, Sit, StudyLaptop, StudyBook, Wave, and Stretch actions before GLB export.
6. Normalize source +Z to gameplay -Z with `VisualRoot`, then tune collider, label, and per-character sit offsets through `CharacterProfile`.
7. Import in Godot and verify texture/material fidelity, animation deformation, floor contact, facing, collision fit, seat contact, hands/table relationship, and camera framing.
8. Optimize unreasonable web texture/mesh cost locally while preserving original local sources. Never commit the derivative proprietary output.

Whenever furniture or character scale changes, re-author every affected StudySpot's standing anchor, sitting anchor, yaw, activity, and cinematic camera data.
