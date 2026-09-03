#!/usr/bin/env python3
"""
Replace StudyTown's rectangular FenceIkegaki opaque core with a recessed,
rounded dark-green foliage filler.

This edits ONLY the already-converted runtime hedge:
    assets/dev_local/blender_generated/runtime/garden_hedge.glb

It preserves the original ACNH FenceIkegaki foliage mesh and its materials.
Only StudyTownHedgeOpaqueCore is removed/replaced.

The replacement is an elongated UV-sphere/ellipsoid:
- no flat rectangular bottom strip
- no vertical slab ends
- recessed well inside the foliage
- darker green so it reads as deep foliage/shadow rather than bright plastic

Run from the StudyTown project root:

/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/local_assets/fix_garden_hedge_rounded_core.py -- \
  --input "assets/dev_local/blender_generated/runtime/garden_hedge.glb"

Optional:
  --x-ratio 0.68
  --y-ratio 0.46
  --z-ratio 0.48
  --z-offset 0.015
  --color 123817
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import bpy
from mathutils import Vector


CORE_NAME = "StudyTownHedgeOpaqueCore"
NEW_CORE_NAME = "StudyTownHedgeRoundedCore"


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        type=Path,
        default=Path(
            "assets/dev_local/blender_generated/runtime/garden_hedge.glb"
        ),
    )
    parser.add_argument(
        "--x-ratio",
        type=float,
        default=0.68,
        help="Rounded core length as a fraction of foliage world-space X extent.",
    )
    parser.add_argument(
        "--y-ratio",
        type=float,
        default=0.46,
        help="Rounded core depth as a fraction of foliage world-space Y extent.",
    )
    parser.add_argument(
        "--z-ratio",
        type=float,
        default=0.48,
        help="Rounded core height as a fraction of foliage world-space Z extent.",
    )
    parser.add_argument(
        "--z-offset",
        type=float,
        default=0.015,
        help="Upward offset as a fraction of foliage Z extent.",
    )
    parser.add_argument(
        "--color",
        default="0C2710",
        help="Dark core RGB hex without #. Default: 0C2710.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
    )
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_glb(path: Path) -> list[bpy.types.Object]:
    before = set(bpy.context.scene.objects)
    result = bpy.ops.import_scene.gltf(filepath=str(path))

    if "FINISHED" not in result:
        raise RuntimeError(f"glTF import failed: {path}")

    return [
        obj
        for obj in bpy.context.scene.objects
        if obj not in before
    ]


def world_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points: list[Vector] = []

    for obj in objects:
        if obj.type != "MESH":
            continue

        for corner in obj.bound_box:
            points.append(
                obj.matrix_world @ Vector(tuple(corner))
            )

    if not points:
        raise RuntimeError("No mesh bounds available.")

    minimum = Vector((
        min(p.x for p in points),
        min(p.y for p in points),
        min(p.z for p in points),
    ))

    maximum = Vector((
        max(p.x for p in points),
        max(p.y for p in points),
        max(p.z for p in points),
    ))

    return minimum, maximum


def rgba_from_hex(value: str) -> tuple[float, float, float, float]:
    value = value.strip().lstrip("#")

    if len(value) != 6:
        raise ValueError(
            "--color must contain exactly 6 hexadecimal characters."
        )

    try:
        rgb = tuple(
            int(value[index:index + 2], 16) / 255.0
            for index in (0, 2, 4)
        )
    except ValueError as exc:
        raise ValueError("--color contains invalid hexadecimal characters.") from exc

    return (*rgb, 1.0)


def create_dark_material(color: tuple[float, float, float, float]) -> bpy.types.Material:
    material = bpy.data.materials.new(
        "StudyTownHedgeDeepFoliage"
    )
    material.diffuse_color = color

    # Explicit nodes for stable glTF export.
    material.use_nodes = True

    bsdf = material.node_tree.nodes.get(
        "Principled BSDF"
    )

    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.96
        bsdf.inputs["Metallic"].default_value = 0.0

        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.18

    return material


def delete_old_core(objects: list[bpy.types.Object]) -> list[bpy.types.Object]:
    kept: list[bpy.types.Object] = []

    for obj in objects:
        if (
            obj.type == "MESH"
            and (
                obj.name.startswith(CORE_NAME)
                or obj.name.startswith(NEW_CORE_NAME)
            )
        ):
            bpy.data.objects.remove(
                obj,
                do_unlink=True,
            )
            continue

        kept.append(obj)

    return kept


def add_rounded_core(
    foliage_objects: list[bpy.types.Object],
    x_ratio: float,
    y_ratio: float,
    z_ratio: float,
    z_offset_ratio: float,
    color: tuple[float, float, float, float],
) -> bpy.types.Object:
    minimum, maximum = world_bounds(
        foliage_objects
    )

    extent = maximum - minimum
    centre = (minimum + maximum) * 0.5

    centre.z += extent.z * z_offset_ratio

    target_dimensions = Vector((
        extent.x * x_ratio,
        extent.y * y_ratio,
        extent.z * z_ratio,
    ))

    # A sphere becomes a soft, capsule-like inner foliage mass once stretched.
    # Because it has no flat faces, it cannot form a visible rectangular frame.
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=32,
        ring_count=18,
        radius=1.0,
        location=centre,
    )

    core = bpy.context.object
    core.name = NEW_CORE_NAME

    # Unit UV sphere has diameter 2.
    core.scale = target_dimensions * 0.5

    bpy.context.view_layer.objects.active = core
    core.select_set(True)

    bpy.ops.object.transform_apply(
        location=False,
        rotation=False,
        scale=True,
    )

    for polygon in core.data.polygons:
        polygon.use_smooth = True

    material = create_dark_material(
        color
    )
    core.data.materials.append(
        material
    )

    print(
        "ROUNDED CORE "
        f"dims=({target_dimensions.x:.4f}, "
        f"{target_dimensions.y:.4f}, "
        f"{target_dimensions.z:.4f}) "
        f"centre=({centre.x:.4f}, {centre.y:.4f}, {centre.z:.4f})"
    )

    return core


def export_glb(
    objects: list[bpy.types.Object],
    output_path: Path,
) -> None:
    bpy.ops.object.select_all(action="DESELECT")

    mesh_objects = [
        obj
        for obj in objects
        if obj.type == "MESH"
        and obj.name in bpy.context.scene.objects
    ]

    if not mesh_objects:
        raise RuntimeError("No mesh objects available for export.")

    for obj in mesh_objects:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = mesh_objects[0]

    result = bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_apply=True,
    )

    if "FINISHED" not in result:
        raise RuntimeError("glTF export failed.")


def main() -> int:
    args = parse_args()
    input_path = args.input.expanduser().resolve()

    if not input_path.is_file():
        raise SystemExit(
            f"ERROR: hedge GLB does not exist:\n  {input_path}"
        )

    for name, value in (
        ("x-ratio", args.x_ratio),
        ("y-ratio", args.y_ratio),
        ("z-ratio", args.z_ratio),
    ):
        if not 0.20 <= value <= 0.90:
            raise SystemExit(
                f"ERROR: --{name} must be between 0.20 and 0.90"
            )

    try:
        color = rgba_from_hex(
            args.color
        )
    except ValueError as exc:
        raise SystemExit(f"ERROR: {exc}")

    reset_scene()
    imported = import_glb(
        input_path
    )

    original_core_names = [
        obj.name
        for obj in imported
        if obj.type == "MESH"
        and (
            obj.name.startswith(CORE_NAME)
            or obj.name.startswith(NEW_CORE_NAME)
        )
    ]

    if not original_core_names:
        raise SystemExit(
            "ERROR: No StudyTown hedge core object was found. "
            "Nothing was changed."
        )

    kept = delete_old_core(
        imported
    )

    foliage = [
        obj
        for obj in kept
        if obj.type == "MESH"
    ]

    if not foliage:
        raise SystemExit(
            "ERROR: No FenceIkegaki foliage mesh remained after removing the core."
        )

    minimum, maximum = world_bounds(
        foliage
    )
    extent = maximum - minimum

    print("")
    print("# STUDYTOWN — FENCEIKEGAKI ROUNDED DARK CORE")
    print(f"Input: {input_path}")
    print(f"Removed old core(s): {', '.join(original_core_names)}")
    print(
        "Foliage world extent: "
        f"({extent.x:.4f}, {extent.y:.4f}, {extent.z:.4f})"
    )
    print(
        "Dark core colour: "
        f"#{args.color.strip().lstrip('#').upper()}"
    )
    print("")

    if args.dry_run:
        print("DRY RUN — no file changed.")
        return 0

    backup_path = input_path.with_name(
        input_path.stem
        + "_before_rounded_core.glb"
    )

    if not backup_path.exists():
        shutil.copy2(
            input_path,
            backup_path,
        )
        print(f"Backup: {backup_path}")
    else:
        print(f"Backup already exists: {backup_path}")

    rounded_core = add_rounded_core(
        foliage,
        args.x_ratio,
        args.y_ratio,
        args.z_ratio,
        args.z_offset,
        color,
    )

    export_objects = kept + [
        rounded_core
    ]

    temp_path = input_path.with_name(
        input_path.stem
        + "_rounded_core_tmp.glb"
    )

    export_glb(
        export_objects,
        temp_path,
    )

    temp_path.replace(
        input_path
    )

    print("")
    print("UPDATED:", input_path)
    print("FenceIkegaki foliage mesh/materials were left untouched.")
    print("Rectangular core was replaced by a recessed rounded dark-green filler.")
    print("DONE")
    print("")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
