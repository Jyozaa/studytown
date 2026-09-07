"""Convert the verified StudyTown Library asset candidates into runtime GLBs.

This converter reads directly from the permanent raw asset library:

    asset_library/Model

It intentionally does NOT copy candidate folders into StudyTown again.

The heavy lifting (Blender-5-compatible static COLLADA parsing, material
reconstruction, texture lookup, grounding, normalization, and GLB export) is
shared with the already-tested Garden archive converter.

Typical use from the StudyTown repo root:

/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/local_assets/blender_library_archive_assets.py -- --source "asset_library/Model" --output "assets/dev_local/blender_generated/runtime"

Optional:

/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/local_assets/blender_library_archive_assets.py -- --source "asset_library/Model" --output "assets/dev_local/blender_generated/runtime" --only bookshelf,study_desk,study_chair

/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/local_assets/blender_library_archive_assets.py -- --list

The resulting GLBs are local runtime derivatives under assets/dev_local and
should remain gitignored unless the project deliberately changes its asset
licensing/distribution policy.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from blender_garden_archive_assets import AssetSpec, convert_asset  # noqa: E402


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        default="asset_library/Model",
        help="Permanent StudyTown raw Model library.",
    )
    parser.add_argument(
        "--output",
        default="assets/dev_local/blender_generated/runtime",
        help="Gitignored StudyTown runtime GLB directory.",
    )
    parser.add_argument(
        "--only",
        default="",
        help="Comma-separated conversion target names.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List conversion targets and exit.",
    )
    return parser.parse_args(argv)


# The target sizes below are authored for StudyTown's existing character scale:
# imported cats are roughly 2.7 world units tall.  They deliberately do not use
# the source archive's raw 1:1 units.
ASSETS: list[AssetSpec] = [
    AssetSpec(
        name="bookshelf",
        folder="FtrBookshelf.Nin_NX_NVN",
        dae="FtrBookshelf.dae",
        output="library_bookshelf.glb",
        target_height=4.20,
        variant_folders={
            "mReBody": "FtrBookshelfReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="bookstand",
        folder="FtrBookstand.Nin_NX_NVN",
        dae="FtrBookstand.dae",
        output="library_bookstand.glb",
        target_height=0.90,
        variant_folders={
            "mReBody": "FtrBookstandReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="study_desk",
        folder="FtrStudyDesk.Nin_NX_NVN",
        dae="FtrStudyDesk.dae",
        output="library_study_desk.glb",
        target_height=1.75,
        variant_folders={
            "mReBody": "FtrStudyDeskReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="antique_bureau",
        folder="FtrAntiqueBureau.Nin_NX_NVN",
        dae="FtrAntiqueBureau.dae",
        output="library_antique_bureau.glb",
        target_height=1.80,
        variant_folders={
            "mReBody": "FtrAntiqueBureauReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="antique_table",
        folder="FtrAntiqueTableL.Nin_NX_NVN",
        dae="FtrAntiqueTableL.dae",
        output="library_antique_table.glb",
        target_height=1.05,
        variant_folders={
            "mReBody": "FtrAntiqueTableLReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="serving_cart",
        folder="FtrIronwoodServingcart.Nin_NX_NVN",
        dae="FtrIronwoodServingcart.dae",
        output="library_serving_cart.glb",
        target_height=1.20,
        variant_folders={
            "mReBody": "FtrIronwoodServingcartReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="study_chair",
        folder="FtrStudyChair.Nin_NX_NVN",
        dae="FtrStudyChair.dae",
        output="library_study_chair.glb",
        target_height=1.45,
        variant_folders={
            "mReBody": "FtrStudyChairReBody0.Nin_NX_NVN",
            "mReFabric": "FtrStudyChairReFabric0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="antique_chair",
        folder="FtrAntiqueChairS.Nin_NX_NVN",
        dae="FtrAntiqueChairS.dae",
        output="library_antique_chair.glb",
        target_height=1.70,
        variant_folders={
            "mReBody": "FtrAntiqueChairSReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="elegant_sofa",
        folder="FtrElegantSofaL.Nin_NX_NVN",
        dae="FtrElegantSofaL.dae",
        output="library_elegant_sofa.glb",
        target_height=1.70,
        variant_folders={
            "mReBody": "FtrElegantSofaLReBody0.Nin_NX_NVN",
            "mReFabric": "FtrElegantSofaLReFabric0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="fireplace",
        folder="FtrFireplace.Nin_NX_NVN",
        dae="FtrFireplace.dae",
        output="library_fireplace.glb",
        target_height=2.60,
        variant_folders={
            "mReBody": "FtrFireplaceReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="bankers_lamp",
        folder="FtrLampBankers.Nin_NX_NVN",
        dae="FtrLampBankers.dae",
        output="library_bankers_lamp.glb",
        target_height=0.75,
        variant_folders={
            "mReBody": "FtrLampBankersReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="globe",
        folder="FtrGlobeAntique.Nin_NX_NVN",
        dae="FtrGlobeAntique.dae",
        output="library_globe.glb",
        target_height=1.65,
    ),
    AssetSpec(
        name="antique_clock",
        folder="FtrAntiqueClock.Nin_NX_NVN",
        dae="FtrAntiqueClock.dae",
        output="library_antique_clock.glb",
        target_height=3.60,
        variant_folders={
            "mReBody": "FtrAntiqueClockReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="books",
        folder="FtrBooks.Nin_NX_NVN",
        dae="FtrBooks.dae",
        output="library_books.glb",
        target_height=0.60,
        variant_folders={
            "mReBody": "FtrBooksReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="book_opened",
        folder="FtrBookOpened.Nin_NX_NVN",
        dae="FtrBookOpened.dae",
        output="library_book_opened.glb",
        target_height=0.08,
        variant_folders={
            "mReBody": "FtrBookOpenedReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="magazine_rack",
        folder="FtrMagazinerackL.Nin_NX_NVN",
        dae="FtrMagazinerackL.dae",
        output="library_magazine_rack.glb",
        target_height=1.55,
        variant_folders={
            "mReBody": "FtrMagazinerackLReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="typewriter",
        folder="FtrTypewriter.Nin_NX_NVN",
        dae="FtrTypewriter.dae",
        output="library_typewriter.glb",
        target_height=0.42,
        variant_folders={
            "mReBody": "FtrTypewriterReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="corkboard",
        folder="FtrCorkboard.Nin_NX_NVN",
        dae="FtrCorkboard.dae",
        output="library_corkboard.glb",
        target_height=1.80,
        variant_folders={
            "mReBody": "FtrCorkboardReBody0.Nin_NX_NVN",
            "mReFabric": "FtrCorkboardReFabric0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="study_set",
        folder="FtrStudySet.Nin_NX_NVN",
        dae="FtrStudySet.dae",
        output="library_study_set.glb",
        target_height=0.12,
    ),
]


def main() -> None:
    args = parse_args()

    source_root = Path(args.source).expanduser().resolve()
    output_dir = Path(args.output).expanduser().resolve()

    if args.list:
        for spec in ASSETS:
            print(f"{spec.name:18s} -> {spec.output}")
        return

    if not source_root.is_dir():
        raise FileNotFoundError(
            "StudyTown master Model directory does not exist: "
            f"{source_root}"
        )

    requested = {
        item.strip()
        for item in args.only.split(",")
        if item.strip()
    }

    known = {spec.name for spec in ASSETS}
    unknown = requested - known
    if unknown:
        raise ValueError(
            "Unknown --only target(s): "
            + ", ".join(sorted(unknown))
        )

    selected = [
        spec
        for spec in ASSETS
        if not requested or spec.name in requested
    ]

    output_dir.mkdir(parents=True, exist_ok=True)

    failures: list[tuple[str, str]] = []

    print("")
    print("STUDYTOWN LIBRARY ARCHIVE CONVERSION")
    print("====================================")
    print(f"source: {source_root}")
    print(f"output: {output_dir}")
    print(f"assets: {len(selected)}")
    print("")

    for spec in selected:
        try:
            convert_asset(source_root, output_dir, spec)
        except Exception as exc:
            failures.append((spec.name, str(exc)))
            print(
                "STUDYTOWN_LIBRARY_IMPORT_FAILED "
                f"name={spec.name} error={exc}"
            )

    print("")
    print(
        "STUDYTOWN_LIBRARY_IMPORT_SUMMARY "
        f"requested={len(selected)} "
        f"succeeded={len(selected) - len(failures)} "
        f"failed={len(failures)}"
    )

    if failures:
        print("")
        for name, error in failures:
            print(f"FAILED {name}: {error}")
        raise RuntimeError(
            f"{len(failures)} Library asset conversion(s) failed."
        )


if __name__ == "__main__":
    main()
