# Performance review

Performance is checked in the Godot Compatibility renderer at 1280×720 on the development Mac (Apple M2 Pro), with the local cat/prop derivatives present. `F6` exposes runtime FPS, grounded state, and player height.

Four one-second samples were taken after a three-second warm-up in a normal rendered run:

| Room | Approx average FPS | Minimum sampled FPS |
|---|---:|---:|
| Grand Library | 74 | 73 |
| Garden Café | 108 | 74 |
| Scenic Train | 81 | 65 |
| Japanese Study Room | 91 | 85 |

All rooms remained above 60 FPS in this local pass. The Library is dominated by shelf/book density; Train continuously updates its authored parallax list; Garden now includes 18 lightweight original tuft instances. The implementation avoids per-frame asset loading, shares materials, and limits NPCs to 6/5/4/5.

The local web export completed successfully at approximately 47 MB (38 MB engine WASM and 8.4 MB project PCK) with the owner-local runtime derivatives present.

A second export with the entire `assets/dev_local/` tree temporarily absent also completed successfully at approximately 39 MB, confirming the public fallback build does not depend on ignored files.

Potential follow-up optimizations, if browser profiling requires them, are batching repeated books/foliage with MultiMesh and reducing embedded local texture sizes. These are intentionally deferred until measured because current hero readability takes priority.
