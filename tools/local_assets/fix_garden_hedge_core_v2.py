#!/usr/bin/env python3
"""
Fix StudyTown's existing ACNH FenceIkegaki hedge by shrinking ONLY the
StudyTownHedgeOpaqueCore object already embedded in garden_hedge.glb.

The foliage mesh is left completely untouched.

Why v2 exists:
The opaque core is a separate cube object whose six faces are stored as six
disconnected face islands after glTF import. A connected-component detector
therefore sees six 2-triangle components instead of one box. The object itself
is already explicitly named StudyTownHedgeOpaqueCore, so this version targets
that exact object directly.

Run from the StudyTown project root:

/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/local_assets/fix_garden_hedge_core_v2.py -- \
  --input "assets/dev_local/blender_generated/runtime/garden_hedge.glb"

Defaults shrink the core around its centre:
  X: 0.82
  Y: 0.74
  Z: 0.66

This hides the bottom/side rectangular protrusion while preserving enough core
to fill gaps behind the foliage.
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import bpy


CORE_NAME = "StudyTownHedgeOpaqueCore"


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
    parser.add_argument("--x-scale", type=float, default=0.82)
    parser.add_argument("--y-scale", type=float, default=0.74)
    parser.add_argument("--z-scale", type=float, default=0.66)
    parser.add_argument("--dry-run", action="store_true")
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


def find_core(objects: list[bpy.types.Object]) -> bpy.types.Object:
    exact = [
        obj
        for obj in objects
        if obj.type == "MESH"
        and obj.name == CORE_NAME
    ]

    if len(exact) == 1:
        return exact[0]

    # Blender can append .001 if a datablock with the same name survives.
    prefixed = [
        obj
        for obj in objects
        if obj.type == "MESH"
        and obj.name.startswith(CORE_NAME)
    ]

    if len(prefixed) == 1:
        return prefixed[0]

    raise RuntimeError(
        f"Expected exactly one {CORE_NAME} mesh, "
        f"found {len(exact) or len(prefixed)}."
    )


def mesh_local_bounds(obj: bpy.types.Object):
    mesh = obj.data

    if mesh is None or len(mesh.vertices) == 0:
        raise RuntimeError(f"Core mesh is empty: {obj.name}")

    xs = [vertex.co.x for vertex in mesh.vertices]
    ys = [vertex.co.y for vertex in mesh.vertices]
    zs = [vertex.co.z for vertex in mesh.vertices]

    return (
        min(xs), max(xs),
        min(ys), max(ys),
        min(zs), max(zs),
    )


def shrink_core_geometry(
    obj: bpy.types.Object,
    x_scale: float,
    y_scale: float,
    z_scale: float,
) -> None:
    min_x, max_x, min_y, max_y, min_z, max_z = mesh_local_bounds(obj)

    cx = (min_x + max_x) * 0.5
    cy = (min_y + max_y) * 0.5
    cz = (min_z + max_z) * 0.5

    for vertex in obj.data.vertices:
        vertex.co.x = cx + (vertex.co.x - cx) * x_scale
        vertex.co.y = cy + (vertex.co.y - cy) * y_scale
        vertex.co.z = cz + (vertex.co.z - cz) * z_scale

    obj.data.update()


def export_glb(
    objects: list[bpy.types.Object],
    output_path: Path,
) -> None:
    bpy.ops.object.select_all(action="DESELECT")

    mesh_objects = [
        obj
        for obj in objects
        if obj.type == "MESH"
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

    for label, value in (
        ("x", args.x_scale),
        ("y", args.y_scale),
        ("z", args.z_scale),
    ):
        if not 0.40 <= value <= 0.98:
            raise SystemExit(
                f"ERROR: --{label}-scale must be between 0.40 and 0.98"
            )

    reset_scene()
    imported = import_glb(input_path)
    core = find_core(imported)

    foliage_objects = [
        obj
        for obj in imported
        if obj.type == "MESH"
        and obj != core
    ]

    before_bounds = mesh_local_bounds(core)

    print("")
    print("# STUDYTOWN — FIX FENCEIKEGAKI OPAQUE CORE v2")
    print(f"Input:   {input_path}")
    print(f"Core:    {core.name}")
    print(
        "Core local bounds before: "
        f"x=({before_bounds[0]:.4f},{before_bounds[1]:.4f}) "
        f"y=({before_bounds[2]:.4f},{before_bounds[3]:.4f}) "
        f"z=({before_bounds[4]:.4f},{before_bounds[5]:.4f})"
    )
    print(
        f"Core object scale: "
        f"({core.scale.x:.4f}, {core.scale.y:.4f}, {core.scale.z:.4f})"
    )
    print(f"Foliage/other mesh objects left untouched: {len(foliage_objects)}")
    print("")

    if args.dry_run:
        print("DRY RUN — no files changed.")
        return 0

    backup_path = input_path.with_name(
        input_path.stem + "_before_core_fix_v2.glb"
    )

    if not backup_path.exists():
        shutil.copy2(input_path, backup_path)
        print(f"Backup: {backup_path}")
    else:
        print(f"Backup already exists: {backup_path}")

    shrink_core_geometry(
        core,
        args.x_scale,
        args.y_scale,
        args.z_scale,
    )

    after_bounds = mesh_local_bounds(core)

    print(
        "Core local bounds after:  "
        f"x=({after_bounds[0]:.4f},{after_bounds[1]:.4f}) "
        f"y=({after_bounds[2]:.4f},{after_bounds[3]:.4f}) "
        f"z=({after_bounds[4]:.4f},{after_bounds[5]:.4f})"
    )

    temp_path = input_path.with_name(
        input_path.stem + "_core_fix_v2_tmp.glb"
    )

    export_glb(imported, temp_path)
    temp_path.replace(input_path)

    print("")
    print(
        "FIXED "
        f"x_scale={args.x_scale:.3f} "
        f"y_scale={args.y_scale:.3f} "
        f"z_scale={args.z_scale:.3f}"
    )
    print(f"Updated: {input_path}")
    print("Original FenceIkegaki foliage was not modified.")
    print("DONE")
    print("")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
