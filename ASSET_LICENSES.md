# External asset register

## Development-only proprietary reference assets

Local prototypes may use models and textures originating from **Animal Crossing: New Horizons** and obtained from the project-owner-supplied archive or the [Animal Crossing: New Horizons section of The Models Resource](https://models.spriters-resource.com/nintendo_switch/animalcrossingnewhorizons/).

- These files are Nintendo-origin proprietary reference assets. They are **not CC0**, public domain, or original StudyTown assets.
- They are used locally for development/testing only and are not part of StudyTown's distributable asset licence.
- Meshes, textures, archives, extracted sources, and local optimized derivatives live under gitignored `assets/dev_local/`.
- The repository commits integration code, metadata-only inventory/diagnostics, import tools, and public fallback assets only.
- All such references must be removed, replaced with original work, or properly licensed before any public/commercial distribution.
- Current local character selections are Bob, Rosie, and Raymond from the owner-supplied Cats archive. Selected local props and environment models are enumerated in `docs/ROOM_ASSET_USAGE.md`; all 106 supplied primary archives and 23 cat variants are accounted for in `docs/ASSET_AUDIT.md`.

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

## CraftPix low-poly packs (development-only, non-CC0)

- **Packs:** Free Tree 3D Low Poly Pack, Free Bush 3D Low Poly Models, Free Medieval Houses 3D Low Poly Pack, Free Environment Props 3D Low Poly Models
- **Creator:** CraftPix (https://craftpix.net)
- **License:** CraftPix Freebie license (https://craftpix.net/file-licenses/): free for personal and commercial game projects including derivatives; redistributing/selling the source art itself is forbidden. **Not CC0.**
- **Files used:** 21 temperate tree FBX + atlas, 13 bush FBX + atlas, `House_02_full`/`House_04_full` + atlas, selected environment props (stone/wood road tiles, lamp, bench, fence) + atlas; local `License.txt`/`readme.txt` retained beside the sources.
- **Handling:** sources live under gitignored `assets/dev_local/source/craftpix/`; Blender-generated runtime GLBs under gitignored `assets/dev_local/blender_generated/runtime/craftpix_*`; the committed manifest holds metadata only (`craftpix_*` entries). Same clean-room treatment as the proprietary reference assets above: remove/replace/re-license before any public/commercial distribution that cannot carry this license.
- **Where used:** Garden vegetation/scenery dressing via runtime swaps with procedural/public fallbacks.

## KayKit City Builder Bits 1.0

- **Asset/Pack:** City Builder Bits (1.0)
- **Creator:** Kay Lousberg (https://kaylousberg.com, https://kaykit.co)
- **Source:** Owner-supplied KayKit pack, copied from `~/Downloads/city/` into `assets/source/cafe_packs/city/` (GLTF + BIN + `citybits_texture.png`); original Downloads folder left untouched
- **License:** Creative Commons Zero (CC0 1.0) — verified in the pack's retained `License.txt` (`assets/source/cafe_packs/city/` is untracked working data; keep the `License.txt` text with any redistribution)
- **Date accessed:** 2026-09-20
- **Original format:** GLTF (+ BIN, PNG texture)
- **Files used:** `building_A`–`building_H` (with/without base), `road_straight`, `road_straight_crossing`, `road_tsplit`, `base`, `streetlight`, `trafficlight_A/B`, `bench`, `bush`, `box_A/B`, `dumpster`, `firehydrant`, `trash_A/B`, `car_sedan`, `car_hatchback`, `car_stationwagon`, `car_taxi`, `watertower`; supplied KayKit palette kept as-is (muted red/orange/green/blue-grey buildings, grey roads, yellow/white markings)
- **Modifications:** Godot-side uniform 5x scale (toy-scale bits matched to true-scale Nature trees), rotation/placement for the StudyTown city district; shared `citybits_texture` material untouched
- **Where used:** Study Café surrounding city district only (`scripts/rooms/cafe_builder.gd`); no other room references these assets

## KayKit Block Bits 1.0

- **Asset/Pack:** Block Bits (1.0)
- **Creator:** Kay Lousberg (https://kaylousberg.com, https://kaykit.co)
- **Source:** Owner-supplied KayKit pack, copied from `~/Downloads/blocks/Assets/gltf/` + `~/Downloads/blocks/Textures/` into `assets/source/cafe_packs/blocks/` (GLTF + BIN + `block_bits_texture.png` + `License.txt`); original Downloads folder left untouched
- **License:** Creative Commons Zero (CC0 1.0) — verified in the pack's retained `License.txt`
- **Date accessed:** 2026-09-20
- **Original format:** GLTF (+ BIN, PNG texture)
- **Files used:** `grass`, `dirt_with_grass`, `gravel_with_grass`, `stone`, `stone_dark`, `bricks_A`, `bricks_B` (terrain shelves + retaining edges); other block types available but unused
- **Modifications:** Godot-side non-uniform scale for wide flat shelves (e.g. 40×3×14 m terrain platforms with tops at +1.5/+3.0); shared `block_bits_texture` material untouched; used subtly as terrain backbone, not voxel styling
- **Where used:** Study Café outer districts only (`scripts/rooms/cafe_builder.gd`); no other room references these assets

## Researched but not imported

Quaternius Furniture Pack was verified as CC0 on its official pack page (https://quaternius.com/packs/furniture.html). It was not imported because its shape language overlapped the selected supporting pack and mixing both would reduce cohesion.

OpenGameArt's 3D Interior Home Assets by mabaci was verified as CC0 on its asset page (https://opengameart.org/content/3d-interior-home-assets). It was not imported because the master Library already had original hero furniture and a smaller support set was preferable.

All other visible character, architecture, bookshelf, book, table, chair, fireplace, rug, tree, foliage, café pavilion, train, scenery, Japanese-room, UI, and material work in this repository is original project code/geometry. The committed Garden grass tuft and its Blender source are original StudyTown work generated by `tools/local_assets/blender_furniture_kit.py`.
