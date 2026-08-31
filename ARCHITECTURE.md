# Architecture

`StudyTown.tsx` owns the presentation and play loop. Zustand persists only the selected character and local focus progression. React Three Fiber renders the scene; Rapier supplies the kinematic player and scene boundaries. No backend is used.

`SceneDefinition` in `types.ts` is the expansion seam. Every destination declares a fixed exploration camera, player spawn, boundaries, explicit `StudySpot` standing/sitting anchors, and authored `CinematicShot` compositions. Adding a cafe, beach, rooftop, rainy room, or airport should begin with one new definition and a matching environment kit.

The timer stores an absolute end timestamp, so background tabs and frame drops do not drift. Character and NPC motion share the +Z orientation convention. Seated actors are never placed at arbitrary furniture origins; the study spot is the authoritative transform.
