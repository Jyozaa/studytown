# Asset pipeline

1. Find the creator's original asset page, not a rehost.
2. Verify an explicit CC0/public-domain dedication in the page or bundled license. “Free” and “royalty-free” are not enough.
3. Record creator, URL, verification source, access date, files, modifications, and usage in `ASSET_LICENSES.md` immediately.
4. Retain the original archive contents under `assets/source_external/<pack>/` with `.gdignore` so Godot does not import source formats.
5. Copy only chosen game-ready files to `assets/external/<pack>/`.
6. In Blender, normalize scale (one metre = one world unit), apply transforms, repair normals, set a useful origin, simplify hidden geometry, soften intentional edges, and reshape silhouettes where required.
7. Replace or consolidate materials into the StudyTown palette. Preserve material differences among wood, fabric, paper, ceramic, glass, foliage, metal, stone, and carpet.
8. Export GLB with embedded materials. Import in Godot, inspect from the authored camera, then add only necessary collision.
9. Prefer shared meshes/materials and MultiMesh for dense repeats. Keep hero visual quality before optimization.
10. Capture an in-game review image. If the asset reads as a foreign pack, normalize it again or remove it.

## Character pipeline

Character 01 establishes proportions, forward axis, part hierarchy, seating dimensions, face construction, clothing volumes, shoes, and animation pivots. Review it front/three-quarter/side/back and in gameplay/seated compositions before deriving variants. Variants keep the same hierarchy and movement/seating math.

