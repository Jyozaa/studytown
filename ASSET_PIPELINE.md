# Asset pipeline

The playable build uses a procedural Three.js kit for efficient runtime instancing/composition and a Blender Python factory for reusable source assets. Blender 4.x is expected at `/Applications/Blender.app/Contents/MacOS/Blender`.

Run `npm run assets:generate`. It clears a temporary Blender scene, creates bevelled toon-ready meshes at the documented world scale, applies a central palette, and exports individual GLBs to `public/assets/generated/`.

Generated families include three character bases, a full bookcase, reading chair, study desk, garden tree, and train seat pair. Source helpers live in `tools/blender/common/`. Keep origins at sensible placement points: furniture on the floor, character feet at Y=0, and seated props authored against the 0.52-unit seat convention.

When adding an asset, judge it from an elevated gameplay view. A successful export must have a clear silhouette, cohesive colour, enough secondary forms to avoid primitive-box appearance, predictable scale, and no accidental transforms.
