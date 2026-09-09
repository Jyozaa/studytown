"""Garden-only additions. Owner-local inputs/outputs, never distributable assets.

Uses the existing static COLLADA/material pipeline; does not reconvert shared
runtime props or touch any authored room. Run Blender --background --python
tools/local_assets/blender_central_pond_assets.py from the project root.
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_garden_archive_assets import AssetSpec, convert_asset

SOURCE = Path("asset_library/Model").resolve()
OUTPUT = Path("assets/dev_local/blender_generated/runtime").resolve()
SPECS = [
    AssetSpec(
        name="central_pond_gazebo",
        folder="FtrWesternGazebo.Nin_NX_NVN",
        dae="FtrWesternGazebo.dae",
        output="garden_pond_gazebo.glb",
        target_height=4.7,
        variant_folders={"mReBody": "FtrWesternGazeboReBody2.Nin_NX_NVN"},
    ),
    AssetSpec(
        name="central_pond_blossom",
        folder="PltTreeOakSakura.Nin_NX_NVN",
        dae="PltTreeOak4Sakura.dae",
        output="garden_pond_blossom.glb",
        target_height=5.8,
        drop_materials=("mShadow", "mShadowShake"),
    ),
    AssetSpec(
        name="central_pond_bridge",
        folder="BridgeLog.Nin_NX_NVN",
        dae="BridgeLog03.dae",
        output="garden_pond_log_bridge.glb",
        target_longest_xy=7.8,
        drop_materials=("mWinterSnow", "mShadow"),
    ),
    AssetSpec(
        name="central_pond_parasol",
        folder="FtrCafeParasoltable.Nin_NX_NVN",
        dae="FtrCafeParasoltable.dae",
        output="garden_pond_parasol.glb",
        target_height=3.7,
        variant_folders={
            "mReBody": "FtrCafeParasoltableReBody0.Nin_NX_NVN",
            "mReFabric": "FtrCafeParasoltableReFabric1.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="central_pond_low_rock",
        folder="FtrGardenrockLow.Nin_NX_NVN",
        dae="FtrGardenrockLow.dae",
        output="garden_pond_low_rock.glb",
        target_longest_xy=1.7,
    ),
]

requested = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for spec in SPECS:
    if not requested or spec.name in requested:
        convert_asset(SOURCE, OUTPUT, spec)
