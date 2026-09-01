# Cat character diagnostics

## Selected variants

| Character | Source model | Meshes kept | Distinctive material content |
|---|---|---:|---|
| Bob | `Cat.fbx` | 4 | Bob body, eye, mouth, and floral top maps |
| Rosie | `Cat.fbx` | 4 | Rosie body, eye, mouth, and top maps |
| Raymond | `CatRaymond.fbx` | 6 | Raymond maps plus glasses and alpha-glass meshes |

All three use the 51-bone `Armature`. The source contains no actions. The local converter normalizes relevant visible geometry from an approximately 0.30192-unit source height to 2.70 world units (scale factor 8.94289) and embeds the chosen texture maps in each ignored GLB.

## Generated action policy

- Looping: Idle, Walk, StudyLaptop, StudyBook
- One-shot: Sit, Wave, Stretch
- `CharacterAnimationController` explicitly applies Godot loop modes and returns one-shots to the prior study/locomotion state.
- Study arm rotations are solved against the imported armature's actual wrist endpoints. Left/right bones are not treated as naive Euler mirrors.
- `CharacterProfile` supplies the 180-degree VisualRoot correction so the mesh's source +Z face direction becomes canonical gameplay -Z without changing movement math.

## Runtime profile

- nominal dimensions: 1.55 × 2.70 × 1.52
- capsule radius: 0.52
- capsule height: 2.20
- standing visual offset: (0, 0, 0)
- sitting visual offset: (0, -0.14, 0.12)
- label height: 2.98

The public fallback character remains intentionally available and is verified by the clean-clone test.
