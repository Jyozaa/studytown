"""Convert StudyTown Train + Japanese Study candidate assets into runtime GLBs.

Reads directly from the permanent master asset library:

    asset_library/Model

No candidate-copy step is required.

The script reuses the tested Blender 5.x COLLADA/material pipeline from
blender_garden_archive_assets.py, so the same static DAE fallback importer,
material reconstruction, grounding and GLB export behavior is used here.

Typical use from the StudyTown repo root:

/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/local_assets/blender_train_japanese_archive_assets.py -- --source "asset_library/Model" --output "assets/dev_local/blender_generated/runtime"

Optional:
  --rooms train
  --rooms japanese
  --rooms train,japanese
  --only train_table,train_table_antique,train_table_vintage,train_table_elegant
  --list
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from blender_garden_archive_assets import AssetSpec, convert_asset, find_folder  # noqa: E402


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
        help="Gitignored runtime GLB/texture output directory.",
    )
    parser.add_argument(
        "--rooms",
        default="train,japanese",
        help="Comma-separated rooms: train,japanese",
    )
    parser.add_argument(
        "--only",
        default="",
        help="Comma-separated individual conversion target names.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List conversion targets and exit.",
    )
    return parser.parse_args(argv)


TRAIN_ASSETS: list[AssetSpec] = [
    AssetSpec(
        name="train_seat",
        folder="FtrSeatTransport.Nin_NX_NVN",
        dae="FtrSeatTransport.dae",
        output="train_seat_transport.glb",
        target_height=1.40,
        variant_folders={
            "mReBody": "FtrSeatTransportReBody0.Nin_NX_NVN",
            "mReFabric": "FtrSeatTransportReFabric0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="train_long_seat",
        folder="FtrSeatLong.Nin_NX_NVN",
        dae="FtrSeatLong.dae",
        output="train_seat_long.glb",
        target_height=1.34,
        variant_folders={
            "mReBody": "FtrSeatLongReBody0.Nin_NX_NVN",
            "mReFabric": "FtrSeatLongReFabric0.Nin_NX_NVN",
        },
    ),
    # Main Train compartment table.
    # Actual candidate choice after inspecting the supplied archive:
    # FtrWoodenTableMini + dark brown ReBody3.
    AssetSpec(
        name="train_table",
        folder="FtrWoodenTableMini.Nin_NX_NVN",
        dae="FtrWoodenTableMini.dae",
        output="train_table_wooden_mini.glb",
        target_height=0.72,
        variant_folders={
            "mReBody": "FtrWoodenTableMiniReBody3.Nin_NX_NVN",
            # Neutral/dark cloth accent if the mesh exposes mReFabric.
            "mReFabric": "FtrWoodenTableMiniReFabric0.Nin_NX_NVN",
        },
    ),

    # Decorative tables used around the old-world carriage.
    AssetSpec(
        name="train_table_antique",
        folder="FtrAntiqueTableS.Nin_NX_NVN",
        dae="FtrAntiqueTableS.dae",
        output="train_table_antique_small.glb",
        target_height=0.66,
        variant_folders={
            "mReBody": "FtrAntiqueTableSReBody2.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="train_table_vintage",
        folder="FtrVintageTableM.Nin_NX_NVN",
        dae="FtrVintageTableM.dae",
        output="train_table_vintage_medium.glb",
        target_height=0.74,
        variant_folders={
            "mReBody": "FtrVintageTableMReBody1.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="train_table_elegant",
        folder="FtrElegantTableM.Nin_NX_NVN",
        dae="FtrElegantTableM.dae",
        output="train_table_elegant_medium.glb",
        target_height=0.72,
        variant_folders={
            "mReBody": "FtrElegantTableMReBody2.Nin_NX_NVN",
            # Deep burgundy fabric suits the carriage palette.
            "mReFabric": "FtrElegantTableMReFabric4.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="train_handrail",
        folder="FtrHandrail.Nin_NX_NVN",
        dae="FtrHandrail.dae",
        output="train_handrail.glb",
        target_height=3.20,
        tint_overrides={
            "mReBody": (0.68, 0.70, 0.72, 1.0),
        },
    ),
    AssetSpec(
        name="train_partition_pole",
        folder="FtrPartitionpole.Nin_NX_NVN",
        dae="FtrPartitionpole.dae",
        output="train_partition_pole.glb",
        target_height=3.35,
        tint_overrides={
            "mReBody": (0.70, 0.72, 0.74, 1.0),
        },
    ),
    AssetSpec(
        name="train_window",
        folder="RoomMdlWindowSquareSteel00.Nin_NX_NVN",
        dae="RoomMdlWindowSquareSteel00.dae",
        output="train_window_steel.glb",
        target_dims=(3.70, 0.18, 2.25),
        tint_overrides={
            "mFrame": (0.50, 0.53, 0.56, 1.0),
            "mGlass": (0.55, 0.68, 0.78, 0.34),
        },
        alpha_overrides={
            "mGlass": 0.34,
        },
    ),
    AssetSpec(
        name="train_blind",
        folder="RoomMdlCurtainBlind.Nin_NX_NVN",
        dae="RoomMdlCurtainBlind.dae",
        output="train_window_blind.glb",
        target_dims=(3.60, 0.16, 0.72),
    ),
    AssetSpec(
        name="train_fan",
        folder="FtrFanRetroWall.Nin_NX_NVN",
        dae="FtrFanRetroWall.dae",
        output="train_wall_fan.glb",
        target_height=0.78,
        tint_overrides={
            "mReBody": (0.55, 0.58, 0.60, 1.0),
        },
    ),
    AssetSpec(
        name="train_clock",
        folder="FtrClockWall.Nin_NX_NVN",
        dae="FtrClockWall.dae",
        output="train_wall_clock.glb",
        target_height=0.72,
    ),
    AssetSpec(
        name="train_corkboard",
        folder="FtrCorkboard.Nin_NX_NVN",
        dae="FtrCorkboard.dae",
        output="train_corkboard.glb",
        target_height=1.15,
    ),
    AssetSpec(
        name="train_books",
        folder="FtrBooks.Nin_NX_NVN",
        dae="FtrBooks.dae",
        output="train_books.glb",
        target_height=0.48,
    ),
    AssetSpec(
        name="train_open_book",
        folder="FtrBookOpened.Nin_NX_NVN",
        dae="FtrBookOpened.dae",
        output="train_open_book.glb",
        target_height=0.07,
    ),
    AssetSpec(
        name="train_coffee",
        folder="FtrCoffeecup.Nin_NX_NVN",
        dae="FtrCoffeecup.dae",
        output="train_coffee_cup.glb",
        target_height=0.32,
    ),
    AssetSpec(
        name="train_mug",
        folder="FtrMug.Nin_NX_NVN",
        dae="FtrMug.dae",
        output="train_mug.glb",
        target_height=0.34,
    ),
    AssetSpec(
        name="train_case",
        folder="FtrDuralumincase.Nin_NX_NVN",
        dae="FtrDuralumincase.dae",
        output="train_duralumin_case.glb",
        target_longest_xy=1.05,
        tint_overrides={
            "mReBody": (0.48, 0.50, 0.52, 1.0),
        },
    ),
    AssetSpec(
        name="train_backpack",
        folder="BagBackpackTote0.Nin_NX_NVN",
        dae="BagBackpackTote0.dae",
        output="train_backpack.glb",
        target_height=0.78,
    ),
    AssetSpec(
        name="train_travel_bag",
        folder="BagShoulderTravel0.Nin_NX_NVN",
        dae="BagShoulderTravel0.dae",
        output="train_travel_bag.glb",
        target_height=0.70,
    ),
    AssetSpec(
        name="train_shopping_bag",
        folder="FtrShoppingbag.Nin_NX_NVN",
        dae="FtrShoppingbag.dae",
        output="train_shopping_bag.glb",
        target_height=0.62,
    ),
]


JAPANESE_ASSETS: list[AssetSpec] = [
    AssetSpec(
        name="japanese_low_table",
        folder="FtrLowtableJapan.Nin_NX_NVN",
        dae="FtrLowtableJapan.dae",
        output="japanese_low_table_archive.glb",
        target_height=0.72,
        tint_overrides={
            "mReBody": (0.40, 0.25, 0.14, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_dining_table",
        folder="FtrDiningtableJapan.Nin_NX_NVN",
        dae="FtrDiningtableJapan.dae",
        output="japanese_dining_table.glb",
        target_height=0.96,
        tint_overrides={
            "mReBody": (0.42, 0.27, 0.16, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_lowboard",
        folder="FtrLowboardJapan.Nin_NX_NVN",
        dae="FtrLowboardJapan.dae",
        output="japanese_lowboard.glb",
        target_height=0.95,
        tint_overrides={
            "mReBody": (0.36, 0.23, 0.14, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_chest",
        folder="FtrChestJapan.Nin_NX_NVN",
        dae="FtrChestJapan.dae",
        output="japanese_chest.glb",
        target_height=1.65,
        tint_overrides={
            "mReBody": (0.34, 0.21, 0.13, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_kotatsu",
        folder="FtrKotatsu.Nin_NX_NVN",
        dae="FtrKotatsu.dae",
        output="japanese_kotatsu.glb",
        target_height=0.82,
        tint_overrides={
            "mBody": (0.40, 0.25, 0.15, 1.0),
            "mReFabric": (0.37, 0.25, 0.20, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_cushion",
        folder="FtrCushionJapan.Nin_NX_NVN",
        dae="FtrCushionJapan.dae",
        output="japanese_floor_cushion_archive.glb",
        target_height=0.23,
        tint_overrides={
            "mReFabric": (0.66, 0.31, 0.16, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_cushion_pile",
        folder="FtrCushionJapanPile.Nin_NX_NVN",
        dae="FtrCushionJapanPile.dae",
        output="japanese_cushion_pile.glb",
        target_height=0.58,
        tint_overrides={
            "mReFabric": (0.57, 0.30, 0.18, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_shoji_window",
        folder="RoomMdlWindowSquareShojiWood00.Nin_NX_NVN",
        dae="RoomMdlWindowSquareShojiWood00.dae",
        output="japanese_shoji_window.glb",
        target_dims=(4.35, 0.18, 3.05),
        tint_overrides={
            "mFrame": (0.35, 0.24, 0.16, 1.0),
            "mGlass": (0.94, 0.87, 0.71, 0.72),
        },
        alpha_overrides={
            "mGlass": 0.72,
        },
    ),
    AssetSpec(
        name="japanese_round_shoji",
        folder="RoomMdlWindowCircleShojiWood00.Nin_NX_NVN",
        dae="RoomMdlWindowCircleShojiWood00.dae",
        output="japanese_round_shoji_window.glb",
        target_dims=(3.35, 0.18, 3.35),
        tint_overrides={
            "mFrame": (0.35, 0.24, 0.16, 1.0),
            "mGlass": (0.94, 0.87, 0.71, 0.72),
        },
        alpha_overrides={
            "mGlass": 0.72,
        },
    ),
    AssetSpec(
        name="japanese_screen",
        folder="FtrScreenJapan.Nin_NX_NVN",
        dae="FtrScreenJapan.dae",
        output="japanese_screen.glb",
        target_height=2.65,
        tint_overrides={
            "mReBody": (0.36, 0.24, 0.15, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_screen_low",
        folder="FtrScreenJapanLow.Nin_NX_NVN",
        dae="FtrScreenJapanLow.dae",
        output="japanese_screen_low.glb",
        target_height=1.72,
        tint_overrides={
            "mReFabric": (0.72, 0.57, 0.39, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_byoubu",
        folder="FtrScreenByoubu.Nin_NX_NVN",
        dae="FtrScreenByoubu.dae",
        output="japanese_byoubu.glb",
        target_height=2.50,
        tint_overrides={
            "mReBody": (0.33, 0.22, 0.14, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_lamp",
        folder="FtrLampJapan.Nin_NX_NVN",
        dae="FtrLampJapan.dae",
        output="japanese_floor_lamp.glb",
        target_height=1.30,
        tint_overrides={
            "mReBody": (0.30, 0.20, 0.13, 1.0),
            "mReFabric": (1.0, 0.80, 0.51, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_ceiling_lamp",
        folder="FtrJapanCeiling.Nin_NX_NVN",
        dae="FtrJapanCeiling.dae",
        output="japanese_ceiling_lamp.glb",
        target_height=0.72,
        tint_overrides={
            "mReBody": (0.35, 0.23, 0.14, 1.0),
            "mReFabric": (1.0, 0.82, 0.55, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_bamboo_lamp",
        folder="FtrBambooLamp.Nin_NX_NVN",
        dae="FtrBambooLamp.dae",
        output="japanese_bamboo_lamp.glb",
        target_height=1.12,
        tint_overrides={
            "mReBody": (0.50, 0.34, 0.20, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_kettle",
        folder="FtrKettleJapan.Nin_NX_NVN",
        dae="FtrKettleJapan.dae",
        output="japanese_kettle.glb",
        target_height=0.34,
    ),
    AssetSpec(
        name="japanese_teacup",
        folder="FtrTeacupJapan.Nin_NX_NVN",
        dae="FtrTeacupJapan.dae",
        output="japanese_teacup.glb",
        target_height=0.19,
        tint_overrides={
            "mReBody": (0.72, 0.64, 0.49, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_bonsai_pine",
        folder="FtrBonsaiPine.Nin_NX_NVN",
        dae="FtrBonsaiPine.dae",
        output="japanese_bonsai_pine.glb",
        target_height=1.05,
    ),
    AssetSpec(
        name="japanese_bonsai_kokedama",
        folder="FtrBonsaiKokedama.Nin_NX_NVN",
        dae="FtrBonsaiKokedama.dae",
        output="japanese_bonsai_kokedama.glb",
        target_height=0.82,
    ),
    AssetSpec(
        name="japanese_bamboo_shelf",
        folder="FtrBambooShelf.Nin_NX_NVN",
        dae="FtrBambooShelf.dae",
        output="japanese_bamboo_shelf.glb",
        target_height=1.78,
        tint_overrides={
            "mReBody": (0.43, 0.30, 0.18, 1.0),
        },
    ),
    AssetSpec(
        name="japanese_scroll",
        folder="FtrHangingscroll.Nin_NX_NVN",
        dae="FtrHangingscroll.dae",
        output="japanese_hanging_scroll.glb",
        target_height=2.10,
        tint_overrides={
            "mReFabric": (0.81, 0.72, 0.57, 1.0),
        },
    ),
]


ALL_ASSETS: list[AssetSpec] = TRAIN_ASSETS + JAPANESE_ASSETS


def copy_japanese_tatami(source_root: Path, output_dir: Path) -> None:
    folder = find_folder(
        source_root,
        "RoomTexFloorTatami00.Nin_NX_NVN",
    )

    copies = {
        "RoomTexFloorTatami00_Alb.png": "japanese_tatami_albedo.png",
        "RoomTexFloorTatami00_Nrm.png": "japanese_tatami_normal.png",
        "RoomTexFloorTatami00_Mix.png": "japanese_tatami_mix.png",
    }

    output_dir.mkdir(parents=True, exist_ok=True)

    for source_name, destination_name in copies.items():
        source = folder / source_name
        if not source.exists():
            raise FileNotFoundError(f"Missing tatami texture: {source}")
        shutil.copy2(source, output_dir / destination_name)

    print("STUDYTOWN_JAPANESE_TATAMI_TEXTURES_DONE")


def main() -> None:
    args = parse_args()

    source_root = Path(args.source).expanduser().resolve()
    output_dir = Path(args.output).expanduser().resolve()

    if args.list:
        for spec in ALL_ASSETS:
            room = (
                "train"
                if spec in TRAIN_ASSETS
                else "japanese"
            )
            print(f"{room:9s} {spec.name:26s} -> {spec.output}")
        return

    if not source_root.is_dir():
        raise FileNotFoundError(
            "StudyTown master Model directory does not exist: "
            f"{source_root}"
        )

    requested_rooms = {
        item.strip().lower()
        for item in args.rooms.split(",")
        if item.strip()
    }

    unknown_rooms = requested_rooms - {"train", "japanese"}
    if unknown_rooms:
        raise ValueError(
            "Unknown --rooms value(s): "
            + ", ".join(sorted(unknown_rooms))
        )

    selected: list[AssetSpec] = []
    if "train" in requested_rooms:
        selected.extend(TRAIN_ASSETS)
    if "japanese" in requested_rooms:
        selected.extend(JAPANESE_ASSETS)

    requested_only = {
        item.strip()
        for item in args.only.split(",")
        if item.strip()
    }

    known = {spec.name for spec in ALL_ASSETS}
    unknown = requested_only - known
    if unknown:
        raise ValueError(
            "Unknown --only target(s): "
            + ", ".join(sorted(unknown))
        )

    if requested_only:
        selected = [
            spec
            for spec in selected
            if spec.name in requested_only
        ]

    output_dir.mkdir(parents=True, exist_ok=True)

    if "japanese" in requested_rooms and (
        not requested_only
        or any(
            name.startswith("japanese_")
            for name in requested_only
        )
    ):
        copy_japanese_tatami(
            source_root,
            output_dir,
        )

    failures: list[tuple[str, str]] = []

    print("")
    print("STUDYTOWN TRAIN + JAPANESE ARCHIVE CONVERSION")
    print("=============================================")
    print(f"source: {source_root}")
    print(f"output: {output_dir}")
    print(f"assets: {len(selected)}")
    print("")

    for spec in selected:
        try:
            convert_asset(
                source_root,
                output_dir,
                spec,
            )
        except Exception as exc:
            failures.append(
                (
                    spec.name,
                    str(exc),
                )
            )
            print(
                "STUDYTOWN_ROOM_IMPORT_FAILED "
                f"name={spec.name} error={exc}"
            )

    print("")
    print(
        "STUDYTOWN_ROOM_IMPORT_SUMMARY "
        f"requested={len(selected)} "
        f"succeeded={len(selected) - len(failures)} "
        f"failed={len(failures)}"
    )

    if failures:
        print("")
        for name, error in failures:
            print(f"FAILED {name}: {error}")
        raise RuntimeError(
            f"{len(failures)} room asset conversion(s) failed."
        )


if __name__ == "__main__":
    main()
