# Cat character diagnostics

## Selected variants

| Character | Source model | Meshes kept | Distinctive material content |
|---|---|---:|---|
| Bob | `Cat.fbx` | 5 | body, ear-cap, eye, mouth, and floral top maps |
| Rosie | `Cat.fbx` | 5 | body, ear-cap, eye, mouth, and top maps |
| Raymond | `Cat.fbx` | 5 | body, ear-cap, eye, mouth, and neutral top maps |

All three use the 51-bone `Armature`. The source contains no actions. The local converter normalizes relevant visible geometry from an approximately 0.37749-unit source height to 2.70 world units (scale factor 7.15246) and embeds the chosen texture maps in each ignored GLB. `Body__mCapVis` is explicitly retained; dropping that hierarchy member caused the earlier missing-ear regression.

## Generated action policy

- Looping: Idle, Walk, SeatedIdle, StudyLaptop, StudyBook
- One-shot: Sit, Wave, Stretch, Cheer
- `CharacterAnimationController` explicitly applies Godot loop modes and returns one-shots to the prior study/locomotion state.
- Study arm rotations are solved against the imported armature's actual wrist endpoints. Left/right bones are not treated as naive Euler mirrors.
- Walk uses opposing 1.16/−0.96 radian hip keys, bent trailing knees, a 1.48-radian arm-swing range, 0.105-unit root bounce, and three-bone tail follow-through. These keys are deliberately readable from the gameplay camera and loop in 25 frames.
- The seated base uses deeper hip/knee flexion plus ankle correction; per-seat offsets then place that pose on desk chairs, armchairs, café chairs, train booths, or floor cushions.
- `CharacterProfile` supplies the 180-degree VisualRoot correction so the mesh's source +Z face direction becomes canonical gameplay -Z without changing movement math.

## Runtime profile

- nominal dimensions: 1.55 × 2.70 × 1.52
- capsule radius: 0.52
- capsule height: 2.20
- standing visual offset: (0, 0, 0)
- sitting visual offset: (0, -0.14, 0.12)
- label height: 2.98

The public fallback character remains intentionally available and is verified by the clean-clone test.
