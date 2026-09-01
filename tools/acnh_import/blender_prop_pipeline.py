"""Normalize one locally supplied ACNH prop into a gitignored Godot GLB."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--target-height", type=float, required=True)
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_model(source: Path) -> None:
    suffix = source.suffix.lower()
    if suffix == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(source))
    elif suffix == ".dae":
        raise RuntimeError("This Blender build has no Collada importer; use an owner-supplied FBX or a trusted Collada-capable conversion step.")
    else:
        raise RuntimeError(f"Unsupported prop format: {suffix}")


def normalize(target_height: float) -> None:
    for obj in list(bpy.data.objects):
        if obj.type in {"CAMERA", "LIGHT"} or obj.name == "Cube":
            bpy.data.objects.remove(obj, do_unlink=True)
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("No mesh objects imported")
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    minimum = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maximum = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    source_height = max(maximum.z - minimum.z, 0.0001)
    factor = target_height / source_height
    root = bpy.data.objects.new("StudyTownPropRoot", None)
    bpy.context.scene.collection.objects.link(root)
    for obj in list(bpy.context.scene.objects):
        if obj != root and obj.parent is None:
            obj.parent = root
    root.scale = (factor, factor, factor)
    root.location = (
        -(minimum.x + maximum.x) * 0.5 * factor,
        -(minimum.y + maximum.y) * 0.5 * factor,
        -minimum.z * factor,
    )


def main() -> None:
    args = arguments()
    source = Path(args.source)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    reset_scene()
    import_model(source)
    normalize(args.target_height)
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_animations=False,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )
    print(f"STUDYTOWN_ACNH_PROP {source.name} -> {output}")


if __name__ == "__main__":
    main()
