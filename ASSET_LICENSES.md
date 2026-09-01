# External asset register

## Development-only proprietary reference assets

Local prototypes may use models and textures originating from **Animal Crossing: New Horizons** and obtained from the project-owner-supplied archive or the [Animal Crossing: New Horizons section of The Models Resource](https://models.spriters-resource.com/nintendo_switch/animalcrossingnewhorizons/).

- These files are Nintendo-origin proprietary reference assets. They are **not CC0**, public domain, or original StudyTown assets.
- They are used locally for development/testing only and are not part of StudyTown's distributable asset licence.
- Meshes, textures, archives, extracted sources, and local optimized derivatives live under gitignored `assets/dev_only_acnh/`.
- The repository commits integration code, example metadata, diagnostics, import tools, and public fallback assets only.
- All such references must be removed, replaced with original work, or properly licensed before any public/commercial distribution.
- Current local character candidates: Alfonso, Gayle, and Drago. Current local prop references: hardcover books, coffee mug, oak tree, and potted spring flowers; example manifest entries also describe chair candidates.

This section is intentionally separate from the CC0 register below.

## Kenney Furniture Kit 2.0

- **Asset/Pack:** Furniture Kit 2.0
- **Creator:** Kenney
- **Source:** Kenney official asset library
- **Original URL:** https://kenney.nl/assets/furniture-kit
- **License:** Creative Commons Zero (CC0 1.0)
- **License verification source:** Official asset page and the retained `assets/source_external/kenney_furniture_kit/License.txt`
- **Date accessed:** 2026-09-01
- **Original format:** GLB, FBX, DAE, OBJ, STL, PNG previews
- **Files used:** `laptop.glb`, `lampRoundTable.glb`, `plantSmall1.glb`; additional selected GLBs are retained for later normalization
- **Modifications:** Godot-side scale, rotation, placement, material context, and composition; used beside original StudyTown furniture rather than as a complete room kit
- **Where used:** Desks in all four rooms and selected Library supporting props

## Researched but not imported

Quaternius Furniture Pack was verified as CC0 on its official pack page (https://quaternius.com/packs/furniture.html). It was not imported because its shape language overlapped the selected supporting pack and mixing both would reduce cohesion.

OpenGameArt's 3D Interior Home Assets by mabaci was verified as CC0 on its asset page (https://opengameart.org/content/3d-interior-home-assets). It was not imported because the master Library already had original hero furniture and a smaller support set was preferable.

All other visible character, architecture, bookshelf, book, table, chair, fireplace, rug, tree, foliage, café pavilion, train, scenery, Japanese-room, UI, and material work in this repository is original project code/geometry.
