"""Convert owner-local Garden archive assets into StudyTown-ready GLBs.

This pipeline is deliberately local-only. It expects the curated archive folder
created by the StudyTown Garden separator scripts:

    ~/Downloads/StudyTown Garden Candidates

It converts only the assets that improve the Garden while preserving generated
StudyTown support assets such as:
- garden_cafe_back_wall.glb
- garden_cafe_rug.glb
- garden_tree_rug.glb
- garden_water_droplet.glb
- garden_log_seat.glb
- garden_pool.glb

The archive's FtrPool asset is intentionally NOT used by default because, after
inspection, its basin is kidney-shaped and does not match StudyTown's desired
rectangular tiled pool. The existing generated rectangular pool remains in use,
while the real FtrPoolsidebed asset replaces the generated loungers.

Typical use:

/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/local_assets/blender_garden_archive_assets.py -- \
  --source "$HOME/Downloads/StudyTown Garden Candidates" \
  --output "assets/dev_local/blender_generated/runtime"

Optional:
  --only big_tree,hedge,fountain
  --list

The exported GLBs and copied/generated textures belong under StudyTown's
gitignored local asset directories. Do not commit or redistribute extracted
game assets unless you have the rights to do so.
"""

from __future__ import annotations

import argparse
import math
import random
import shutil
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

import bpy
from mathutils import Matrix, Vector


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        default="~/Downloads/StudyTown Garden Candidates",
        help="Curated Garden candidate root.",
    )
    parser.add_argument(
        "--output",
        default="assets/dev_local/blender_generated/runtime",
        help="StudyTown local runtime output directory.",
    )
    parser.add_argument(
        "--only",
        default="",
        help="Comma-separated target names to convert.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="Print available conversion targets and exit.",
    )
    return parser.parse_args(argv)


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------


@dataclass
class AssetSpec:
    name: str
    folder: str
    dae: str
    output: str
    target_height: float | None = None
    target_longest_xy: float | None = None
    target_dims: tuple[float, float, float] | None = None
    drop_materials: tuple[str, ...] = ()
    drop_objects: tuple[str, ...] = ()
    variant_folders: dict[str, str] = field(default_factory=dict)
    material_source_folders: dict[str, str] = field(default_factory=dict)
    gradient_files: dict[str, str] = field(default_factory=dict)
    tint_overrides: dict[str, tuple[float, float, float, float]] = field(default_factory=dict)
    alpha_overrides: dict[str, float] = field(default_factory=dict)
    default: bool = True


ASSETS: list[AssetSpec] = [
    AssetSpec(
        name="big_tree",
        folder="IdrObjTreeHuge00.Nin_NX_NVN",
        dae="IdrObjTreeHuge00.dae",
        output="garden_big_tree.glb",
        target_height=9.6,
        drop_materials=("mShadow", "mShadowShake"),
    ),
    AssetSpec(
        name="oak_tree",
        folder="PltTreeOak.Nin_NX_NVN",
        dae="PltTreeOak4.dae",
        output="garden_oak_tree.glb",
        target_height=5.1,
        drop_materials=("mShadow", "mShadowShake"),
        gradient_files={
            "mPltTreeOakTrunk": "mPltTreeOakTrunkColor_Grd.png",
            "mTreeOakLeaf": "mPltTreeOakLeafColor_Grd.png",
            "mTreeOakLeafBack": "mPltTreeOakLeafColor_Grd.png",
        },
    ),
    AssetSpec(
        name="shrub",
        folder="PltBushAzalea.Nin_NX_NVN",
        dae="PltBushAzalea4.dae",
        output="garden_shrub.glb",
        target_height=1.20,
        gradient_files={
            "mPltBushAzaleaLeaf": "mPltBushAzaleaLeafColor_Grd.png",
        },
        tint_overrides={
            "mPltBushAzaleaLeaf": (0.34, 0.72, 0.27, 1.0),
        },
    ),
    AssetSpec(
        name="flower_bush",
        folder="PltBushHydrangea.Nin_NX_NVN",
        dae="PltBushHydrangea3.dae",
        output="garden_flower_patch.glb",
        target_height=1.16,
        gradient_files={
            "mPltHydrangeaLeaf": "mPltHydrangeaLeafColor_Grd.png",
            "mPltHydrangeaPetal": "mPltHydrangeaFlowColor_Grd.png",
        },
        tint_overrides={
            "mPltHydrangeaLeaf": (0.32, 0.69, 0.27, 1.0),
            "mPltHydrangeaPetal": (0.55, 0.76, 0.98, 1.0),
        },
    ),
    AssetSpec(
        name="weed",
        folder="PltWeedSmr.Nin_NX_NVN",
        dae="PltWeedSmr2A.dae",
        output="garden_weed_clump.glb",
        target_height=0.50,
    ),
    AssetSpec(
        name="hedge",
        folder="FenceIkegaki.Nin_NX_NVN",
        dae="FenceIkegaki_A.dae",
        output="garden_hedge.glb",
        target_dims=(3.0, 1.0, 1.25),
        gradient_files={
            "mFenceIkegaki": "mFenceIkegaki_Grd.png",
        },
        tint_overrides={
            "mFenceIkegaki": (0.31, 0.68, 0.25, 1.0),
        },
    ),
    AssetSpec(
        name="fountain",
        folder="FtrFountain.Nin_NX_NVN",
        dae="FtrFountain.dae",
        output="garden_fountain.glb",
        target_longest_xy=6.55,
        drop_materials=("mWater",),
        variant_folders={
            "mReBody": "FtrFountainReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="cafe_table",
        folder="FtrGardenTableNatural.Nin_NX_NVN",
        dae="FtrGardenTableNatural.dae",
        output="garden_cafe_table.glb",
        target_longest_xy=2.10,
        variant_folders={
            "mReBody": "FtrGardenTableNaturalReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="cafe_chair",
        folder="FtrGardenChairNatural.Nin_NX_NVN",
        dae="FtrGardenChairNatural.dae",
        output="cafe_chair.glb",
        target_height=1.44,
        variant_folders={
            "mReBody": "FtrGardenChairNaturalReBody0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="cafe_counter",
        folder="FtrCounter.Nin_NX_NVN",
        dae="FtrCounter.dae",
        output="garden_cafe_counter.glb",
        target_longest_xy=7.35,
        variant_folders={
            "mReBody": "FtrCounterReBody0.Nin_NX_NVN",
        },
        tint_overrides={
            "mGlassR": (0.65, 0.78, 0.82, 0.42),
        },
        alpha_overrides={
            "mGlassR": 0.42,
        },
        # Test-only: this archive counter becomes a huge display block in the
        # open-air café. StudyTown's generated counter has the right silhouette.
        default=False,
    ),
    AssetSpec(
        name="pool_lounger",
        folder="FtrPoolsidebed.Nin_NX_NVN",
        dae="FtrPoolsidebed.dae",
        output="garden_tanning_bed.glb",
        target_longest_xy=2.60,
        variant_folders={
            "mReBody": "FtrPoolsidebedReBody0.Nin_NX_NVN",
            "mReFabric": "FtrPoolsidebedReFabric0.Nin_NX_NVN",
        },
    ),
    AssetSpec(
        name="campfire",
        folder="FtrCampfire.Nin_NX_NVN",
        dae="FtrCampfire.dae",
        output="garden_campfire.glb",
        target_longest_xy=2.25,
    ),
    AssetSpec(
        name="firewood",
        folder="FtrFirewood.Nin_NX_NVN",
        dae="FtrFirewood.dae",
        output="garden_firewood.glb",
        target_longest_xy=1.55,
    ),
    AssetSpec(
        name="rock_a",
        folder="FtrGardenrock.Nin_NX_NVN",
        dae="FtrGardenrock.dae",
        output="garden_rock_a.glb",
        target_longest_xy=1.55,
    ),
    AssetSpec(
        name="rock_b",
        folder="FtrGardenrockMoss.Nin_NX_NVN",
        dae="FtrGardenrockMoss.dae",
        output="garden_rock_b.glb",
        target_longest_xy=1.65,
    ),
    AssetSpec(
        name="rock_c",
        folder="FtrGardenrockTall.Nin_NX_NVN",
        dae="FtrGardenrockTall.dae",
        output="garden_rock_c.glb",
        target_longest_xy=1.70,
    ),
    AssetSpec(
        name="road_stone",
        folder="FldUnitRoadStone.Nin_NX_NVN",
        dae="RoadStone0A_0.dae",
        output="garden_flagstone_path_tile.glb",
        target_dims=(2.55, 2.55, 0.10),
        material_source_folders={
            "mRoadStone": "FldUnit.Nin_NX_NVN",
            "mGrassXlu": "FldUnit.Nin_NX_NVN",
        },
        gradient_files={
            "mGrassXlu": "mGrass_Grd.png",
        },
        default=False,
    ),
    AssetSpec(
        name="road_dark_soil",
        folder="FldUnitRoadDarkSoil.Nin_NX_NVN",
        dae="RoadDarkSoil0A_0.dae",
        output="garden_dirt_path_tile.glb",
        target_dims=(2.55, 2.55, 0.08),
        material_source_folders={
            "mRoadDarkSoil": "FldUnit.Nin_NX_NVN",
            "mGrassXlu": "FldUnit.Nin_NX_NVN",
        },
        gradient_files={
            "mRoadDarkSoil": "mRoadDarkSoil_Grd.png",
            "mGrassXlu": "mGrass_Grd.png",
        },
        default=False,
    ),
    AssetSpec(
        name="cafe_coffee_cup",
        folder="IdrObjMuseumCafeCoffeeCup.Nin_NX_NVN",
        dae="IdrObjMuseumCafeCoffeeCup.dae",
        output="garden_cafe_coffee_cup.glb",
        target_height=0.28,
        tint_overrides={
            "mCoffee": (0.14, 0.07, 0.035, 1.0),
        },
    ),
    AssetSpec(
        name="cafe_saucer",
        folder="IdrObjMuseumCafeCoffeeSaucer.Nin_NX_NVN",
        dae="IdrObjMuseumCafeCoffeeSaucer.dae",
        output="garden_cafe_saucer.glb",
        target_longest_xy=0.32,
    ),
    AssetSpec(
        name="cafe_coffee_mill",
        folder="IdrObjMuseumCafeCoffeeMill.Nin_NX_NVN",
        dae="IdrObjMuseumCafeCoffeeMill.dae",
        output="garden_cafe_coffee_mill.glb",
        target_height=0.56,
        tint_overrides={
            "mGlassR": (0.68, 0.79, 0.82, 0.42),
        },
        alpha_overrides={
            "mGlassR": 0.42,
        },
    ),
    AssetSpec(
        name="cafe_milk_pitcher",
        folder="IdrObjMuseumCafeMilkPtcher.Nin_NX_NVN",
        dae="IdrObjMuseumCafeMilkPtcher.dae",
        output="garden_cafe_milk_pitcher.glb",
        target_height=0.35,
    ),
    AssetSpec(
        name="cafe_siphon",
        folder="IdrObjMuseumCafeSiphon.Nin_NX_NVN",
        dae="IdrObjMuseumCafeSiphon.dae",
        output="garden_cafe_siphon.glb",
        target_height=0.63,
        tint_overrides={
            "mGlassR": (0.68, 0.79, 0.82, 0.40),
        },
        alpha_overrides={
            "mGlassR": 0.40,
        },
    ),
    AssetSpec(
        name="cafe_water_cup",
        folder="IdrObjMuseumCafeWaterCup.Nin_NX_NVN",
        dae="IdrObjMuseumCafeWaterCup.dae",
        output="garden_cafe_water_cup.glb",
        target_height=0.28,
        tint_overrides={
            "mGlassR": (0.68, 0.80, 0.84, 0.38),
        },
        alpha_overrides={
            "mGlassR": 0.38,
        },
    ),
    # Test-only. This asset has a kidney-shaped basin and intentionally does
    # not overwrite StudyTown's rectangular garden_pool.glb.
    AssetSpec(
        name="pool_archive_test",
        folder="FtrPool.Nin_NX_NVN",
        dae="FtrPool.dae",
        output="garden_pool_archive_test.glb",
        target_longest_xy=10.2,
        drop_materials=("mWater",),
        variant_folders={
            "mReBody": "FtrPoolReBody0.Nin_NX_NVN",
        },
        default=False,
    ),
]


# ---------------------------------------------------------------------------
# Scene / file lookup
# ---------------------------------------------------------------------------


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.images,
        bpy.data.cameras,
        bpy.data.lights,
        bpy.data.armatures,
    ):
        for block in list(datablocks):
            try:
                datablocks.remove(block)
            except RuntimeError:
                pass


def find_folder(source_root: Path, folder_name: str) -> Path:
    direct = source_root / folder_name
    if direct.is_dir():
        return direct

    matches = [p for p in source_root.rglob(folder_name) if p.is_dir()]
    if not matches:
        raise FileNotFoundError(f"Missing candidate folder: {folder_name}")

    # Prefer the shallowest path so duplicated nested copies do not win.
    matches.sort(key=lambda p: (len(p.parts), str(p)))
    return matches[0]


def find_texture(directory: Path, stem: str) -> Path | None:
    path = directory / stem
    return path if path.exists() else None


COLLADA_NS = "http://www.collada.org/2005/11/COLLADASchema"
COLLADA = {"c": COLLADA_NS}


def _collada_tag(name: str) -> str:
    return f"{{{COLLADA_NS}}}{name}"


def _collada_source_data(
    mesh_element: ET.Element,
) -> dict[str, list[tuple[float, ...]]]:
    """Read numeric COLLADA sources using their accessor stride/count."""
    sources: dict[str, list[tuple[float, ...]]] = {}

    for source in mesh_element.findall("c:source", COLLADA):
        source_id = source.get("id")
        if not source_id:
            continue

        float_array = source.find("c:float_array", COLLADA)
        if float_array is None or not float_array.text:
            continue

        values = [float(value) for value in float_array.text.split()]
        accessor = source.find("c:technique_common/c:accessor", COLLADA)

        stride = 1
        offset = 0
        count = len(values)

        if accessor is not None:
            stride = max(1, int(accessor.get("stride", "1")))
            offset = max(0, int(accessor.get("offset", "0")))
            count = int(
                accessor.get(
                    "count",
                    str(max(0, (len(values) - offset) // stride)),
                )
            )
        else:
            count = max(0, len(values) // stride)

        rows: list[tuple[float, ...]] = []
        for index in range(count):
            start = offset + index * stride
            end = start + stride
            if end > len(values):
                break
            rows.append(tuple(values[start:end]))

        sources[source_id] = rows

    return sources


def _collada_vertices_map(
    mesh_element: ET.Element,
) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}

    for vertices in mesh_element.findall("c:vertices", COLLADA):
        vertices_id = vertices.get("id")
        if not vertices_id:
            continue

        semantics: dict[str, str] = {}
        for input_element in vertices.findall("c:input", COLLADA):
            semantic = input_element.get("semantic")
            source = input_element.get("source", "").lstrip("#")
            if semantic and source:
                semantics[semantic] = source

        result[vertices_id] = semantics

    return result


def _collada_to_blender_vector(
    value: tuple[float, ...] | None,
) -> tuple[float, float, float]:
    """COLLADA defaults to Y-up. Convert to Blender's Z-up convention."""
    if value is None or len(value) < 3:
        return (0.0, 0.0, 0.0)

    x, y, z = float(value[0]), float(value[1]), float(value[2])
    return (x, -z, y)


def _collada_make_mesh_object(
    geometry_name: str,
    material_key: str,
    corners: list[
        tuple[
            tuple[float, ...],
            tuple[float, ...] | None,
            tuple[float, ...] | None,
        ]
    ],
    part_index: int,
) -> bpy.types.Object:
    """Create one Blender object for one COLLADA triangle/material group.

    Vertices are deliberately duplicated per triangle corner. That keeps UVs
    and split normals faithful without needing Blender's removed Collada add-on.
    These StudyTown archive assets are static, so this is a robust local import
    path and the resulting GLB is what Godot ultimately consumes.
    """
    if not corners or len(corners) % 3 != 0:
        raise RuntimeError(
            f"Invalid COLLADA triangle data for {geometry_name}: "
            f"{len(corners)} corners"
        )

    vertices: list[tuple[float, float, float]] = []
    normals: list[tuple[float, float, float]] = []
    uvs: list[tuple[float, float]] = []
    have_normals = True
    have_uvs = True

    for position, normal, texcoord in corners:
        vertices.append(_collada_to_blender_vector(position))

        if normal is not None and len(normal) >= 3:
            nx, ny, nz = _collada_to_blender_vector(normal)
            length = math.sqrt(nx * nx + ny * ny + nz * nz)
            if length > 0.0000001:
                normals.append((nx / length, ny / length, nz / length))
            else:
                normals.append((0.0, 0.0, 1.0))
        else:
            have_normals = False
            normals.append((0.0, 0.0, 1.0))

        if texcoord is not None and len(texcoord) >= 2:
            # COLLADA and Blender both store UV coordinates in normalized UV
            # space. Do not flip V here; the archive textures line up directly.
            uvs.append((float(texcoord[0]), float(texcoord[1])))
        else:
            have_uvs = False
            uvs.append((0.0, 0.0))

    faces = [
        (index, index + 1, index + 2)
        for index in range(0, len(vertices), 3)
    ]

    object_name = geometry_name
    if material_key and f"__{material_key}" not in object_name:
        object_name = f"{object_name}__{material_key}"
    if part_index > 0:
        object_name = f"{object_name}_{part_index:02d}"

    mesh = bpy.data.meshes.new(f"{object_name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()

    if have_uvs:
        uv_layer = mesh.uv_layers.new(name="UVMap")
        for loop in mesh.loops:
            uv_layer.data[loop.index].uv = uvs[loop.vertex_index]

    # Blender has changed its custom-normal API several times. Use it when
    # present, otherwise smooth shading + the archive normal maps still produce
    # the intended result.
    if have_normals and hasattr(mesh, "normals_split_custom_set"):
        try:
            mesh.normals_split_custom_set(
                [normals[loop.vertex_index] for loop in mesh.loops]
            )
        except (AttributeError, RuntimeError, TypeError, ValueError):
            pass

    for polygon in mesh.polygons:
        polygon.use_smooth = True

    if material_key:
        placeholder = bpy.data.materials.get(material_key)
        if placeholder is None:
            placeholder = bpy.data.materials.new(name=material_key)
        mesh.materials.append(placeholder)

    obj = bpy.data.objects.new(object_name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _import_collada_static(path: Path) -> None:
    """Minimal static COLLADA importer for Blender 5.x.

    Blender 5.2 no longer ships the old bpy.ops.wm.collada_import operator.
    The curated StudyTown archive DAEs only use triangle primitives for the
    selected Garden assets, and their skin controllers are bind-pose/static.
    Parsing the geometry directly avoids requiring any external Blender add-on.
    """
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as exc:
        raise RuntimeError(f"Could not parse COLLADA XML: {path}") from exc

    geometries = root.findall(
        "c:library_geometries/c:geometry",
        COLLADA,
    )
    if not geometries:
        raise RuntimeError(f"No COLLADA geometries found in {path}")

    created = 0

    for geometry in geometries:
        geometry_name = (
            geometry.get("name")
            or geometry.get("id")
            or f"Geometry_{created:03d}"
        )

        mesh_element = geometry.find("c:mesh", COLLADA)
        if mesh_element is None:
            continue

        sources = _collada_source_data(mesh_element)
        vertices_maps = _collada_vertices_map(mesh_element)

        triangle_groups = mesh_element.findall("c:triangles", COLLADA)

        # The curated archive was inspected before building this importer and
        # uses triangles for the Garden candidates. Fail loudly if a future
        # source introduces a primitive we do not yet support.
        unsupported = []
        for child in list(mesh_element):
            local_name = child.tag.rsplit("}", 1)[-1]
            if local_name in {
                "polylist",
                "polygons",
                "trifans",
                "tristrips",
                "lines",
                "linestrips",
            }:
                unsupported.append(local_name)
        if unsupported:
            raise RuntimeError(
                f"{path.name}: unsupported COLLADA primitive(s) "
                f"{sorted(set(unsupported))}"
            )

        for part_index, triangles in enumerate(triangle_groups):
            inputs = []
            for input_element in triangles.findall("c:input", COLLADA):
                semantic = input_element.get("semantic", "")
                source = input_element.get("source", "").lstrip("#")
                offset = int(input_element.get("offset", "0"))
                set_index = int(input_element.get("set", "0"))
                inputs.append((semantic, source, offset, set_index))

            if not inputs:
                continue

            tuple_stride = max(item[2] for item in inputs) + 1
            p_element = triangles.find("c:p", COLLADA)
            if p_element is None or not p_element.text:
                continue

            indices = [int(value) for value in p_element.text.split()]
            if len(indices) % tuple_stride != 0:
                raise RuntimeError(
                    f"{path.name}: malformed index stream for {geometry_name}"
                )

            corners = []

            for start in range(0, len(indices), tuple_stride):
                record = indices[start : start + tuple_stride]

                position = None
                normal = None
                texcoord = None

                for semantic, source_id, offset, set_index in inputs:
                    source_index = record[offset]

                    if semantic == "VERTEX":
                        vertex_semantics = vertices_maps.get(source_id, {})
                        position_source = vertex_semantics.get("POSITION")
                        if (
                            position_source is not None
                            and position_source in sources
                        ):
                            position = sources[position_source][source_index]

                    elif semantic == "POSITION":
                        if source_id in sources:
                            position = sources[source_id][source_index]

                    elif semantic == "NORMAL":
                        if source_id in sources:
                            normal = sources[source_id][source_index]

                    elif semantic == "TEXCOORD" and set_index == 0:
                        if source_id in sources:
                            texcoord = sources[source_id][source_index]

                if position is None:
                    raise RuntimeError(
                        f"{path.name}: triangle corner has no POSITION "
                        f"in {geometry_name}"
                    )

                corners.append((position, normal, texcoord))

            expected_triangles = int(triangles.get("count", "0"))
            if expected_triangles and len(corners) != expected_triangles * 3:
                raise RuntimeError(
                    f"{path.name}: expected {expected_triangles * 3} corners "
                    f"for {geometry_name}, got {len(corners)}"
                )

            material_key = triangles.get("material", "")
            _collada_make_mesh_object(
                geometry_name,
                material_key,
                corners,
                part_index,
            )
            created += 1

    if created == 0:
        raise RuntimeError(f"No mesh objects were created from {path}")

    print(
        f"STUDYTOWN_COLLADA_STATIC_IMPORT "
        f"file={path.name} objects={created}"
    )


def import_collada(path: Path) -> None:
    """Import DAE with native operators when available, otherwise self-parse."""
    native_errors: list[str] = []

    # Older Blender versions exposed the operator here. Blender's operator
    # proxy can make hasattr() misleading, so actually call it and catch the
    # "operator could not be found" RuntimeError.
    try:
        bpy.ops.wm.collada_import(filepath=str(path))
        print(f"STUDYTOWN_COLLADA_NATIVE_IMPORT file={path.name}")
        return
    except (AttributeError, RuntimeError) as exc:
        native_errors.append(str(exc))

    try:
        bpy.ops.import_scene.dae(filepath=str(path))
        print(f"STUDYTOWN_COLLADA_NATIVE_IMPORT file={path.name}")
        return
    except (AttributeError, RuntimeError) as exc:
        native_errors.append(str(exc))

    print(
        f"STUDYTOWN_COLLADA_FALLBACK file={path.name} "
        f"reason=Blender_has_no_native_DAE_importer"
    )
    _import_collada_static(path)


def imported_meshes() -> list[bpy.types.Object]:
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


# ---------------------------------------------------------------------------
# Material reconstruction
# ---------------------------------------------------------------------------


def set_non_color(image: bpy.types.Image) -> None:
    try:
        image.colorspace_settings.name = "Non-Color"
    except (TypeError, ValueError):
        pass


def load_image(path: Path, non_color: bool = False) -> bpy.types.Image:
    image = bpy.data.images.load(str(path), check_existing=True)
    if non_color:
        set_non_color(image)
    return image


def average_image_color(path: Path) -> tuple[float, float, float, float]:
    image = load_image(path)
    pixels = image.pixels[:]

    # Sample rather than sum every pixel in large source maps.
    stride_pixels = max(1, (image.size[0] * image.size[1]) // 4096)
    stride = stride_pixels * 4

    sr = sg = sb = sa = 0.0
    count = 0
    for index in range(0, len(pixels), stride):
        if index + 3 >= len(pixels):
            break
        alpha = float(pixels[index + 3])
        if alpha <= 0.08:
            continue
        sr += float(pixels[index])
        sg += float(pixels[index + 1])
        sb += float(pixels[index + 2])
        sa += alpha
        count += 1

    if count == 0:
        return (1.0, 1.0, 1.0, 1.0)

    return (sr / count, sg / count, sb / count, sa / count)


def enable_alpha(material: bpy.types.Material) -> None:

    if hasattr(material, "surface_render_method"):
        for value in ("DITHERED", "BLENDED"):
            try:
                material.surface_render_method = value
                break
            except (TypeError, ValueError):
                pass

    if hasattr(material, "blend_method"):
        for value in ("HASHED", "BLEND"):
            try:
                material.blend_method = value
                break
            except (TypeError, ValueError):
                pass

    if hasattr(material, "use_transparency_overlap"):
        material.use_transparency_overlap = False

    if hasattr(material, "show_transparent_back"):
        material.show_transparent_back = False


def choose_texture_dir(
    source_root: Path,
    asset_folder: Path,
    spec: AssetSpec,
    material_key: str,
) -> Path:
    if material_key in spec.variant_folders:
        return find_folder(source_root, spec.variant_folders[material_key])
    if material_key in spec.material_source_folders:
        return find_folder(source_root, spec.material_source_folders[material_key])
    return asset_folder


def material_default_tint(material_key: str) -> tuple[float, float, float, float]:
    token = material_key.lower()

    if "coffee" in token:
        return (0.13, 0.065, 0.03, 1.0)
    if "water" in token:
        return (0.25, 0.68, 0.80, 0.72)
    if "glass" in token:
        return (0.72, 0.84, 0.87, 0.40)
    if "trunk" in token or "wood" in token:
        return (0.53, 0.30, 0.14, 1.0)
    if "soil" in token:
        return (0.34, 0.23, 0.14, 1.0)
    if "petal" in token or "flower" in token:
        return (0.72, 0.72, 0.92, 1.0)
    if (
        "leaf" in token
        or "grass" in token
        or "weed" in token
        or "dokudami" in token
        or "hahakogusa" in token
        or "enokorogusa" in token
        or "fenceikegaki" in token
    ):
        return (0.31, 0.62, 0.24, 1.0)

    return (1.0, 1.0, 1.0, 1.0)


def material_texture_paths(
    source_root: Path,
    asset_folder: Path,
    spec: AssetSpec,
    material_key: str,
) -> dict[str, Path | None]:
    directory = choose_texture_dir(source_root, asset_folder, spec, material_key)

    def first(*names: str) -> Path | None:
        for name in names:
            path = find_texture(directory, name)
            if path is not None:
                return path
        return None

    gradient_name = spec.gradient_files.get(material_key)
    gradient = first(gradient_name) if gradient_name else first(f"{material_key}_Grd.png")

    return {
        "albedo": first(f"{material_key}_Alb.png"),
        "albedo_gray": first(f"{material_key}_AlbGry.png"),
        "normal": first(f"{material_key}_Nrm.png"),
        "opacity": first(f"{material_key}_OP.png"),
        "emission": first(f"{material_key}_Emi.png"),
        "specular": first(f"{material_key}_Spc.png"),
        "mix": first(f"{material_key}_Mix.png"),
        "gradient": gradient,
    }



def baked_base_color_image(
    albedo_path: Path,
    opacity_path: Path | None,
    tint: tuple[float, float, float, float],
    image_name: str,
    *,
    colorize: bool,
) -> bpy.types.Image:
    """Create an export-safe RGBA base-colour image.

    Nintendo's foliage commonly stores grayscale albedo + a separate colour
    gradient lookup. Blender's glTF exporter does not preserve our previous
    arbitrary MixRGB node chain consistently, so the tint and alpha mask are
    baked directly into a temporary packed image.

    Opacity is intentionally converted to a hard-ish leaf cutout. That avoids
    semi-transparent grey/black foliage and the hollow-looking hedge problem.
    """
    source = load_image(albedo_path)
    source_pixels = source.pixels[:]

    opacity_pixels = None
    opacity_size = None
    if opacity_path is not None:
        opacity_image = load_image(opacity_path, non_color=True)
        opacity_pixels = opacity_image.pixels[:]
        opacity_size = (opacity_image.size[0], opacity_image.size[1])

    width, height = source.size[0], source.size[1]
    image = bpy.data.images.get(image_name)
    if image is not None:
        bpy.data.images.remove(image)

    image = bpy.data.images.new(
        image_name,
        width=width,
        height=height,
        alpha=True,
    )

    result = [0.0] * (width * height * 4)
    tr, tg, tb, _ = tint

    def opacity_at(x: int, y: int) -> float:
        if opacity_pixels is None or opacity_size is None:
            return 1.0
        ow, oh = opacity_size
        ox = min(ow - 1, int(x * ow / max(1, width)))
        oy = min(oh - 1, int(y * oh / max(1, height)))
        oi = (oy * ow + ox) * 4
        return float(opacity_pixels[oi])

    for y in range(height):
        for x in range(width):
            i = (y * width + x) * 4

            r = float(source_pixels[i])
            g = float(source_pixels[i + 1])
            b = float(source_pixels[i + 2])

            if colorize:
                # AlbGry is a luminance/detail mask. Preserve its contrast while
                # shifting it into a saturated AC-like vegetation colour.
                luminance = (r + g + b) / 3.0
                detail = 0.42 + luminance * 0.92
                r = min(1.0, tr * detail)
                g = min(1.0, tg * detail)
                b = min(1.0, tb * detail)
            else:
                r *= tr
                g *= tg
                b *= tb

            alpha = opacity_at(x, y)
            # Hard cutout with a narrow antialiasing band.
            if alpha < 0.40:
                alpha = 0.0
            elif alpha > 0.58:
                alpha = 1.0
            else:
                alpha = (alpha - 0.40) / 0.18

            result[i : i + 4] = [r, g, b, alpha]

    image.pixels = result
    # Packing makes this generated image self-contained in the GLB export.
    try:
        image.pack()
    except RuntimeError:
        pass
    return image


def build_material(
    source_root: Path,
    asset_folder: Path,
    spec: AssetSpec,
    material_key: str,
) -> bpy.types.Material:
    paths = material_texture_paths(source_root, asset_folder, spec, material_key)

    material = bpy.data.materials.new(f"{spec.name}_{material_key}")
    material.use_nodes = True
    material.use_backface_culling = spec.name in {"shrub", "flower_bush"}

    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (760, 0)

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (480, 0)
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    # Conservative roughness works better than guessing Nintendo's packed Mix
    # channel layout. Normal/albedo/opacity maps remain exact.
    bsdf.inputs["Roughness"].default_value = 0.72
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0

    tint = spec.tint_overrides.get(material_key)
    if tint is None and paths["gradient"] is not None:
        tint = average_image_color(paths["gradient"])
    if tint is None:
        tint = material_default_tint(material_key)

    albedo_path = paths["albedo"] or paths["albedo_gray"]
    opacity_path = paths["opacity"]

    if albedo_path is not None:
        # Bake all foliage/recolouring into an export-safe RGBA image instead
        # of depending on unsupported arbitrary shader-node multiplication.
        needs_bake = (
            paths["albedo_gray"] is not None
            or opacity_path is not None
            or tint != (1.0, 1.0, 1.0, 1.0)
        )

        tex = nodes.new("ShaderNodeTexImage")
        tex.name = f"{material_key}_Albedo"
        tex.label = "Albedo"
        tex.location = (-760, 180)

        if needs_bake:
            tex.image = baked_base_color_image(
                albedo_path,
                opacity_path,
                tint,
                f"{spec.name}_{material_key}_BakedRGBA",
                colorize=paths["albedo_gray"] is not None,
            )
        else:
            tex.image = load_image(albedo_path)

        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

        if opacity_path is not None:
            links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            enable_alpha(material)
    else:
        bsdf.inputs["Base Color"].default_value = tint

    if paths["normal"] is not None:
        normal_tex = nodes.new("ShaderNodeTexImage")
        normal_tex.name = f"{material_key}_Normal"
        normal_tex.label = "Normal"
        normal_tex.location = (-760, -220)
        normal_tex.image = load_image(paths["normal"], non_color=True)

        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.location = (-250, -220)
        normal_map.inputs["Strength"].default_value = 0.80

        links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])

    alpha_override = spec.alpha_overrides.get(material_key)
    if opacity_path is None and (alpha_override is not None or tint[3] < 0.999):
        bsdf.inputs["Alpha"].default_value = (
            alpha_override if alpha_override is not None else tint[3]
        )
        enable_alpha(material)

    if paths["emission"] is not None:
        emission_tex = nodes.new("ShaderNodeTexImage")
        emission_tex.name = f"{material_key}_Emission"
        emission_tex.label = "Emission"
        emission_tex.location = (-760, -700)
        emission_tex.image = load_image(paths["emission"])

        emission_input = None
        for candidate in ("Emission Color", "Emission"):
            if candidate in bsdf.inputs:
                emission_input = bsdf.inputs[candidate]
                break
        if emission_input is not None:
            links.new(emission_tex.outputs["Color"], emission_input)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = 0.50

    return material


def material_key_for_object(
    obj: bpy.types.Object,
    known_keys: Iterable[str],
) -> str | None:
    object_name = obj.name.lower()

    # Extractor names frequently end with __mMaterialName.
    for key in known_keys:
        if f"__{key.lower()}" in object_name:
            return key

    for slot in obj.material_slots:
        if slot.material is None:
            continue
        slot_name = slot.material.name.lower()
        for key in known_keys:
            if key.lower() in slot_name:
                return key

    return None


def source_material_keys(obj: bpy.types.Object) -> set[str]:
    keys: set[str] = set()

    if "__" in obj.name:
        suffix = obj.name.rsplit("__", 1)[1]
        suffix = suffix.split(".", 1)[0]
        if suffix.startswith("m"):
            keys.add(suffix)

    for slot in obj.material_slots:
        if slot.material is None:
            continue
        name = slot.material.name.split(".", 1)[0]
        for suffix in ("-material", "_material"):
            if name.endswith(suffix):
                name = name[: -len(suffix)]
        if name.startswith("m"):
            keys.add(name)

    return keys


def assign_materials(
    source_root: Path,
    asset_folder: Path,
    spec: AssetSpec,
    meshes: list[bpy.types.Object],
) -> None:
    all_keys: set[str] = set()
    for obj in meshes:
        all_keys.update(source_material_keys(obj))

    # Configured material names may not survive the Collada import slot naming,
    # so include every explicit config key too.
    all_keys.update(spec.variant_folders.keys())
    all_keys.update(spec.material_source_folders.keys())
    all_keys.update(spec.gradient_files.keys())
    all_keys.update(spec.tint_overrides.keys())
    all_keys.update(spec.alpha_overrides.keys())

    material_cache: dict[str, bpy.types.Material] = {}

    for obj in meshes:
        key = material_key_for_object(obj, all_keys)

        if key is None:
            # Leave imported material in place if there is no reliable mapping.
            continue

        if key not in material_cache:
            material_cache[key] = build_material(
                source_root,
                asset_folder,
                spec,
                key,
            )

        obj.data.materials.clear()
        obj.data.materials.append(material_cache[key])


# ---------------------------------------------------------------------------
# Geometry cleanup / normalization
# ---------------------------------------------------------------------------


def object_should_drop(obj: bpy.types.Object, spec: AssetSpec) -> bool:
    token = obj.name.lower()

    for material in spec.drop_materials:
        if material.lower() in token:
            return True

    for part in spec.drop_objects:
        if part.lower() in token:
            return True

    # If every material on the object belongs to a dropped material family,
    # discard the object even if the exporter changed its object name.
    slot_names = [
        slot.material.name.lower()
        for slot in obj.material_slots
        if slot.material is not None
    ]
    if slot_names and spec.drop_materials:
        if all(
            any(drop.lower() in slot_name for drop in spec.drop_materials)
            for slot_name in slot_names
        ):
            return True

    return False


def clean_import(spec: AssetSpec) -> list[bpy.types.Object]:
    meshes = imported_meshes()

    for obj in list(meshes):
        if object_should_drop(obj, spec):
            bpy.data.objects.remove(obj, do_unlink=True)

    meshes = imported_meshes()
    if not meshes:
        raise RuntimeError(f"{spec.name}: no mesh objects remain after cleanup.")

    # Detach static meshes from source armatures while preserving their bind
    # pose/world transform.
    for obj in meshes:
        matrix_world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = matrix_world

        for modifier in list(obj.modifiers):
            if modifier.type == "ARMATURE":
                obj.modifiers.remove(modifier)

        for polygon in obj.data.polygons:
            polygon.use_smooth = True

    # Remove armatures, lights, cameras and source helper empties.
    mesh_set = set(meshes)
    for obj in list(bpy.context.scene.objects):
        if obj in mesh_set:
            continue
        bpy.data.objects.remove(obj, do_unlink=True)

    return meshes


def world_bounds(
    objects: list[bpy.types.Object],
) -> tuple[Vector, Vector]:
    minimum = Vector((float("inf"), float("inf"), float("inf")))
    maximum = Vector((float("-inf"), float("-inf"), float("-inf")))

    for obj in objects:
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            minimum.x = min(minimum.x, point.x)
            minimum.y = min(minimum.y, point.y)
            minimum.z = min(minimum.z, point.z)
            maximum.x = max(maximum.x, point.x)
            maximum.y = max(maximum.y, point.y)
            maximum.z = max(maximum.z, point.z)

    return minimum, maximum


def normalize_asset(
    spec: AssetSpec,
    meshes: list[bpy.types.Object],
) -> bpy.types.Object:
    minimum, maximum = world_bounds(meshes)
    extent = maximum - minimum

    if min(extent.x, extent.y, extent.z) < 0.000001:
        # Flat road geometry can legitimately have almost no vertical extent.
        if extent.x < 0.000001 or extent.y < 0.000001:
            raise RuntimeError(f"{spec.name}: invalid imported bounds {extent}")

    root = bpy.data.objects.new(f"StudyTown_{spec.name}", None)
    bpy.context.collection.objects.link(root)

    for obj in meshes:
        matrix_world = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = matrix_world

    if spec.target_dims is not None:
        tx, ty, tz = spec.target_dims
        sx = tx / max(extent.x, 0.000001)
        sy = ty / max(extent.y, 0.000001)
        sz = tz / max(extent.z, 0.000001)
        root.scale = (sx, sy, sz)
    elif spec.target_height is not None:
        scale = spec.target_height / max(extent.z, 0.000001)
        root.scale = (scale, scale, scale)
    elif spec.target_longest_xy is not None:
        horizontal = max(extent.x, extent.y, 0.000001)
        scale = spec.target_longest_xy / horizontal
        root.scale = (scale, scale, scale)
    else:
        root.scale = (1.0, 1.0, 1.0)

    centre_x = (minimum.x + maximum.x) * 0.5
    centre_y = (minimum.y + maximum.y) * 0.5

    root.location = Vector(
        (
            -centre_x * root.scale.x,
            -centre_y * root.scale.y,
            -minimum.z * root.scale.z,
        )
    )

    bpy.context.view_layer.update()
    return root


def export_glb(
    output_path: Path,
    root: bpy.types.Object,
    meshes: list[bpy.types.Object],
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)

    for obj in meshes:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = root

    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_apply=True,
    )


# ---------------------------------------------------------------------------
# Archive grass texture
# ---------------------------------------------------------------------------


def find_field_unit_folder(source_root: Path) -> Path:
    return find_folder(source_root, "FldUnit.Nin_NX_NVN")


def palette_samples(path: Path) -> list[tuple[float, float, float]]:
    image = load_image(path)
    pixels = image.pixels[:]

    samples: list[tuple[float, float, float]] = []
    stride = max(4, (len(pixels) // 4) // 128) * 4

    for index in range(0, len(pixels), stride):
        if index + 3 >= len(pixels):
            break
        if pixels[index + 3] <= 0.08:
            continue
        samples.append(
            (
                float(pixels[index]),
                float(pixels[index + 1]),
                float(pixels[index + 2]),
            )
        )

    if not samples:
        samples.append((0.33, 0.62, 0.28))

    return samples


def write_archive_grass_maps(source_root: Path, output_dir: Path) -> None:
    """Keep StudyTown's subtle generated grass albedo; only add archive normal.

    mGrass_Grd is a shader gradient/LUT, not a lawn colour texture. Sampling it
    as an albedo created the high-contrast green/white maze pattern seen in the
    Garden screenshots.
    """
    field_folder = find_field_unit_folder(source_root)
    normal_path = field_folder / "mGrass_Nrm.png"

    if not normal_path.exists():
        raise FileNotFoundError(f"Missing grass normal: {normal_path}")

    output_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(normal_path, output_dir / "garden_grass_normal.png")

    grass_tile = output_dir / "garden_grass_tile.png"
    if grass_tile.exists():
        print("STUDYTOWN_GRASS_ALBEDO_PRESERVED")
    else:
        # Safe fallback only when blender_garden.py has not been run yet.
        width = height = 256
        image = bpy.data.images.new(
            "StudyTownGardenGrassFallback",
            width=width,
            height=height,
            alpha=True,
        )
        rng = random.Random(1207)
        base = (0.30, 0.70, 0.29)
        pixels = [0.0] * (width * height * 4)
        for y in range(height):
            for x in range(width):
                i = (y * width + x) * 4
                noise = (rng.random() - 0.5) * 0.025
                pixels[i : i + 4] = [
                    max(0.0, min(1.0, base[0] + noise)),
                    max(0.0, min(1.0, base[1] + noise)),
                    max(0.0, min(1.0, base[2] + noise)),
                    1.0,
                ]
        image.pixels = pixels
        image.filepath_raw = str(grass_tile)
        image.file_format = "PNG"
        image.save()
        print("STUDYTOWN_GRASS_ALBEDO_FALLBACK_WRITTEN")

    print("STUDYTOWN_GRASS_NORMAL_DONE")


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------


def convert_asset(
    source_root: Path,
    output_dir: Path,
    spec: AssetSpec,
) -> None:
    reset_scene()

    folder = find_folder(source_root, spec.folder)
    dae_path = folder / spec.dae

    if not dae_path.exists():
        raise FileNotFoundError(
            f"{spec.name}: missing DAE {dae_path}"
        )

    print(
        f"STUDYTOWN_ARCHIVE_IMPORT_BEGIN "
        f"name={spec.name} source={dae_path}"
    )

    import_collada(dae_path)

    meshes = clean_import(spec)
    assign_materials(source_root, folder, spec, meshes)

    root = normalize_asset(spec, meshes)

    # The round archive bushes are open foliage shells. A second exact copy
    # caused alpha-sorting/z-fighting because many leaf cards became coplanar.
    # Build a rear shell that is rotated 180 degrees, slightly inset, and
    # shifted toward the rear instead. The opaque core below fills any tiny
    # seam between the two shells.
    if spec.name in {"shrub", "flower_bush"}:
        shell_min, shell_max = world_bounds(meshes)
        shell_centre = (shell_min + shell_max) * 0.5
        shell_extent = shell_max - shell_min

        rear_scale = 0.93
        rear_shift = Vector((0.0, shell_extent.y * 0.055, 0.0))

        rear_transform = (
            Matrix.Translation(shell_centre + rear_shift)
            @ Matrix.Rotation(math.pi, 4, "Z")
            @ Matrix.Scale(rear_scale, 4)
            @ Matrix.Translation(-shell_centre)
        )

        original_shell_meshes = list(meshes)
        rear_shell_meshes: list[bpy.types.Object] = []

        for original in original_shell_meshes:
            duplicate = original.copy()
            duplicate.data = original.data.copy()
            bpy.context.collection.objects.link(duplicate)
            duplicate.name = f"{original.name}_RearInset"

            rear_world = rear_transform @ original.matrix_world

            duplicate.parent = root
            duplicate.matrix_world = rear_world
            rear_shell_meshes.append(duplicate)

        meshes.extend(rear_shell_meshes)
        bpy.context.view_layer.update()

    if spec.name in {"shrub", "flower_bush", "hedge"}:
        final_min, final_max = world_bounds(meshes)
        final_extent = final_max - final_min
        centre = (final_min + final_max) * 0.5

        core_mat = bpy.data.materials.new(f"{spec.name}_OpaqueFoliageCore")
        core_mat.diffuse_color = (
            (0.12, 0.39, 0.10, 1.0)
            if spec.name == "hedge"
            else (0.13, 0.42, 0.11, 1.0)
        )
        core_mat.use_nodes = True
        core_bsdf = core_mat.node_tree.nodes.get("Principled BSDF")
        if core_bsdf is not None:
            core_bsdf.inputs["Base Color"].default_value = core_mat.diffuse_color
            core_bsdf.inputs["Roughness"].default_value = 0.92

        if spec.name == "hedge":
            bpy.ops.mesh.primitive_cube_add(location=centre)
            core = bpy.context.object
            core.name = "StudyTownHedgeOpaqueCore"
            core.dimensions = Vector(
                (
                    final_extent.x * 0.76,
                    final_extent.y * 0.68,
                    final_extent.z * 0.72,
                )
            )
        else:
            bpy.ops.mesh.primitive_uv_sphere_add(
                segments=20,
                ring_count=12,
                location=centre + Vector((0.0, 0.0, -final_extent.z * 0.04)),
            )
            core = bpy.context.object
            core.name = f"StudyTown{spec.name.title()}OpaqueCore"
            core.scale = Vector(
                (
                    final_extent.x * 0.37,
                    final_extent.y * 0.37,
                    final_extent.z * 0.34,
                )
            )

        core.data.materials.append(core_mat)
        bpy.context.view_layer.update()

        # Parent while preserving the final world transform so the existing
        # normalized root scale does not distort our final-size core.
        core_world = core.matrix_world.copy()
        core.parent = root
        core.matrix_world = core_world
        meshes.append(core)

    minimum, maximum = world_bounds(meshes)
    print(
        f"STUDYTOWN_ARCHIVE_BOUNDS name={spec.name} "
        f"min={tuple(round(v, 4) for v in minimum)} "
        f"max={tuple(round(v, 4) for v in maximum)} "
        f"meshes={len(meshes)}"
    )

    output_path = output_dir / spec.output
    export_glb(output_path, root, meshes)

    print(
        f"STUDYTOWN_ARCHIVE_IMPORT_DONE "
        f"name={spec.name} output={output_path}"
    )


def main() -> None:
    args = parse_args()

    source_root = Path(args.source).expanduser().resolve()
    output_dir = Path(args.output).expanduser().resolve()

    if args.list:
        for spec in ASSETS:
            suffix = "" if spec.default else " [test-only]"
            print(f"{spec.name:22s} -> {spec.output}{suffix}")
        return

    if not source_root.exists():
        raise FileNotFoundError(
            f"Garden candidate root does not exist: {source_root}"
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
        if (
            spec.name in requested
            if requested
            else spec.default
        )
    ]

    output_dir.mkdir(parents=True, exist_ok=True)

    # The grass maps are used by main.gd regardless of which individual
    # vegetation/road GLBs are selected.
    write_archive_grass_maps(source_root, output_dir)

    failures: list[tuple[str, str]] = []

    for spec in selected:
        try:
            convert_asset(source_root, output_dir, spec)
        except Exception as exc:
            failures.append((spec.name, str(exc)))
            print(
                f"STUDYTOWN_ARCHIVE_IMPORT_FAILED "
                f"name={spec.name} error={exc}"
            )

    print()
    print(
        f"STUDYTOWN_ARCHIVE_SUMMARY "
        f"requested={len(selected)} "
        f"succeeded={len(selected) - len(failures)} "
        f"failed={len(failures)}"
    )

    if failures:
        for name, message in failures:
            print(f"  FAILED {name}: {message}")
        raise RuntimeError(
            f"{len(failures)} Garden archive conversion(s) failed."
        )


if __name__ == "__main__":
    main()
