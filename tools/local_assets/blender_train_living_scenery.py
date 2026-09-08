"""Convert the selected StudyTown Train living-scenery assets to runtime GLBs.

Reads directly from:
    asset_library/Model

Writes to:
    assets/dev_local/blender_generated/runtime

This converter intentionally does not touch the Train interior assets or scene.
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
        help="Gitignored runtime GLB output directory.",
    )
    parser.add_argument(
        "--only",
        default="",
        help="Comma-separated conversion target names.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List targets and exit.",
    )
    return parser.parse_args(argv)


ASSETS: list[AssetSpec] = [
    AssetSpec(
        name="living_boat",
        folder="StrcWherearenBoatA00.Nin_NX_NVN",
        dae="StrcWherearenBoatA00.dae",
        output="train_scenery_boat.glb",
        target_longest_xy=4.25,
    ),
    AssetSpec(
        name="living_fish_ayu",
        folder="FishAyu.Nin_NX_NVN",
        dae="FishAyu.dae",
        output="train_scenery_fish_ayu.glb",
        target_longest_xy=0.72,
    ),
    AssetSpec(
        name="living_fish_koi",
        folder="FishNishikigoi.Nin_NX_NVN",
        dae="FishNishikigoi.dae",
        output="train_scenery_fish_nishikigoi.glb",
        target_longest_xy=0.82,
    ),
    AssetSpec(
        name="living_bird",
        folder="BbsBirdDay.Nin_NX_NVN",
        dae="BbsBirdDay.dae",
        output="train_scenery_bird_day.glb",
        target_longest_xy=0.58,
    ),
    AssetSpec(
        name="living_lighthouse",
        folder="FtrLighthouse.Nin_NX_NVN",
        dae="FtrLighthouse.dae",
        output="train_scenery_lighthouse.glb",
        target_height=6.20,
        variant_folders={
            "mReBody": "FtrLighthouseReBody5.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="living_windmill",
        folder="CommuneObjWindmill01.Nin_NX_NVN",
        dae="CommuneObjWindmill01.dae",
        output="train_scenery_windmill.glb",
        target_height=4.90,
    ),
    AssetSpec(
        name="living_tractor",
        folder="FtrTractor.Nin_NX_NVN",
        dae="FtrTractor.dae",
        output="train_scenery_tractor.glb",
        target_longest_xy=2.55,
        variant_folders={
            "mReBody": "FtrTractorReBody2.Nin_NX_NVN",
        },
    ),
]


def main() -> None:
    args = parse_args()
    source_root = Path(args.source).expanduser().resolve()
    output_dir = Path(args.output).expanduser().resolve()

    if not source_root.is_dir():
        raise FileNotFoundError(
            f"StudyTown Model library not found: {source_root}"
        )

    if args.list:
        for spec in ASSETS:
            print(f"{spec.name:22s} -> {spec.output}")
        return

    requested_only = {
        item.strip()
        for item in args.only.split(",")
        if item.strip()
    }

    known = {spec.name for spec in ASSETS}
    unknown = requested_only - known
    if unknown:
        raise ValueError(
            "Unknown --only target(s): "
            + ", ".join(sorted(unknown))
        )

    selected = [
        spec
        for spec in ASSETS
        if not requested_only or spec.name in requested_only
    ]

    output_dir.mkdir(parents=True, exist_ok=True)

    failures: list[tuple[str, str]] = []

    print("")
    print("STUDYTOWN TRAIN LIVING SCENERY CONVERSION")
    print("=========================================")
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
            failures.append((spec.name, str(exc)))
            print(
                "STUDYTOWN_TRAIN_LIVING_IMPORT_FAILED "
                f"name={spec.name} error={exc}"
            )

    print("")
    print(
        "STUDYTOWN_TRAIN_LIVING_IMPORT_SUMMARY "
        f"requested={len(selected)} "
        f"succeeded={len(selected) - len(failures)} "
        f"failed={len(failures)}"
    )

    if failures:
        print("")
        for name, error in failures:
            print(f"FAILED {name}: {error}")
        raise RuntimeError(
            f"{len(failures)} living-scenery conversion(s) failed."
        )


if __name__ == "__main__":
    main()
