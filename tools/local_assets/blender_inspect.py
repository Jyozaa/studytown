"""Inspect local owner-supplied models without modifying source files.

Run with Blender in background mode. JSON output belongs under the gitignored
``assets/dev_local/diagnostics`` directory.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("models", nargs="+")
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.actions, bpy.data.materials, bpy.data.images):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def import_model(path: Path) -> None:
    if path.suffix.lower() == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path), use_anim=True)
    elif path.suffix.lower() in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    else:
        raise RuntimeError(f"Unsupported inspection format: {path.suffix}")


def inspect(path: Path) -> dict:
    reset_scene()
    import_model(path)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    dimensions = [0.0, 0.0, 0.0]
    bounds = None
    if points:
        minimum = Vector(tuple(min(point[i] for point in points) for i in range(3)))
        maximum = Vector(tuple(max(point[i] for point in points) for i in range(3)))
        dimensions = [round(float(maximum[i] - minimum[i]), 5) for i in range(3)]
        bounds = {
            "minimum": [round(float(value), 5) for value in minimum],
            "maximum": [round(float(value), 5) for value in maximum],
        }
    return {
        "path": str(path),
        "mesh_names": [obj.name for obj in meshes],
        "meshes": [mesh_report(obj) for obj in meshes],
        "mesh_count": len(meshes),
        "vertex_count": sum(len(obj.data.vertices) for obj in meshes),
        "material_names": sorted({slot.material.name for obj in meshes for slot in obj.material_slots if slot.material}),
        "dimensions_xyz": dimensions,
        "bounds": bounds,
        "armatures": [
            {
                "name": armature.name,
                "bone_count": len(armature.data.bones),
                "bone_names": [bone.name for bone in armature.data.bones],
                "bones": [
                    {
                        "name": bone.name,
                        "parent": bone.parent.name if bone.parent else "",
                        "head": [round(float(value), 6) for value in bone.head_local],
                        "tail": [round(float(value), 6) for value in bone.tail_local],
                    }
                    for bone in armature.data.bones
                ],
            }
            for armature in armatures
        ],
        "actions": [
            {
                "name": action.name,
                "frame_range": [float(value) for value in action.frame_range],
                "fcurves": len(getattr(action, "fcurves", [])),
            }
            for action in bpy.data.actions
        ],
    }


def mesh_report(obj: bpy.types.Object) -> dict:
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    minimum = Vector(tuple(min(point[i] for point in points) for i in range(3)))
    maximum = Vector(tuple(max(point[i] for point in points) for i in range(3)))
    return {
        "name": obj.name,
        "vertices": len(obj.data.vertices),
        "materials": [slot.material.name for slot in obj.material_slots if slot.material],
        "vertex_groups": [group.name for group in obj.vertex_groups],
        "modifiers": [
            {
                "name": modifier.name,
                "type": modifier.type,
                "object": modifier.object.name if hasattr(modifier, "object") and modifier.object else "",
            }
            for modifier in obj.modifiers
        ],
        "visible_viewport": not obj.hide_viewport,
        "visible_render": not obj.hide_render,
        "bounds": {
            "minimum": [round(float(value), 6) for value in minimum],
            "maximum": [round(float(value), 6) for value in maximum],
            "dimensions": [round(float(maximum[i] - minimum[i]), 6) for i in range(3)],
        },
    }


def main() -> None:
    args = arguments()
    reports = []
    for value in args.models:
        path = Path(value).resolve()
        try:
            reports.append(inspect(path))
        except Exception as error:  # Keep a complete batch diagnostic.
            reports.append({"path": str(path), "error": str(error)})
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(reports, indent=2), encoding="utf-8")
    print("STUDYTOWN_LOCAL_ASSET_INSPECTION", json.dumps(reports, sort_keys=True))


if __name__ == "__main__":
    main()
