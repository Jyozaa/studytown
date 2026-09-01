"""Inspect an owner-supplied ACNH villager FBX and export a local Godot GLB.

Run with Blender, not system Python. Output belongs under assets/dev_only_acnh/.
No Nintendo mesh or texture is copied into Git by this tool.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-fbx", required=True)
    parser.add_argument("--texture-dir", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--character-id", required=True)
    parser.add_argument("--mesh-prefix", default="Alligator")
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.actions, bpy.data.materials, bpy.data.images):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def choose_meshes(prefix: str) -> None:
    keep_exact = {prefix, f"{prefix}_Mouth", "AlligatorShirt_TshirtsN"}
    for obj in list(bpy.data.objects):
        if obj.type in {"CAMERA", "LIGHT"} or obj.name == "Cube":
            bpy.data.objects.remove(obj, do_unlink=True)
        elif obj.type == "MESH" and obj.name not in keep_exact:
            bpy.data.objects.remove(obj, do_unlink=True)


def set_texture(material_name: str, filename: str, texture_dir: Path) -> None:
    material = bpy.data.materials.get(material_name)
    path = texture_dir / filename
    if material is None or not path.exists():
        return
    material.use_nodes = True
    image = bpy.data.images.load(str(path), check_existing=False)
    texture_nodes = [node for node in material.node_tree.nodes if node.type == "TEX_IMAGE"]
    if texture_nodes:
        texture_nodes[0].image = image


def remap_textures(texture_dir: Path) -> None:
    set_texture("Beak", "mBeak_Alb.png", texture_dir)
    set_texture("Body", "mBody_Alb.png", texture_dir)
    set_texture("Cloth", "mTops_Alb.png", texture_dir)
    set_texture("Eye", "mEye_Alb_00.png", texture_dir)


def reset_pose(armature: bpy.types.Object) -> None:
    for bone in armature.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.location = (0.0, 0.0, 0.0)
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.scale = (1.0, 1.0, 1.0)


def key_bones(armature: bpy.types.Object, frame: int, rotations: dict[str, tuple[float, float, float]]) -> None:
    bpy.context.scene.frame_set(frame)
    for name, rotation in rotations.items():
        bone = armature.pose.bones.get(name)
        if bone is None:
            continue
        bone.rotation_euler = rotation
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=name)


def create_action(armature: bpy.types.Object, name: str, frames: list[tuple[int, dict[str, tuple[float, float, float]]]], length: int) -> None:
    reset_pose(armature)
    action = bpy.data.actions.new(name)
    armature.animation_data_create()
    armature.animation_data.action = action
    for frame, rotations in frames:
        key_bones(armature, frame, rotations)
    action.frame_start = 1
    action.frame_end = length
    armature.animation_data.action = None


def create_actions(armature: bpy.types.Object) -> None:
    create_action(armature, "Idle", [
        (1, {"Spine_2": (0.0, 0.0, -0.025), "Arm_1_L": (0.0, 0.0, 0.03), "Arm_1_R": (0.0, 0.0, -0.03)}),
        (24, {"Spine_2": (0.0, 0.0, 0.025), "Arm_1_L": (0.0, 0.0, -0.03), "Arm_1_R": (0.0, 0.0, 0.03)}),
        (48, {"Spine_2": (0.0, 0.0, -0.025), "Arm_1_L": (0.0, 0.0, 0.03), "Arm_1_R": (0.0, 0.0, -0.03)}),
    ], 48)
    create_action(armature, "Walk", [
        (1, {"Leg_1_L": (0.48, 0.0, 0.0), "Leg_1_R": (-0.48, 0.0, 0.0), "Arm_1_L": (-0.40, 0.0, 0.0), "Arm_1_R": (0.40, 0.0, 0.0)}),
        (8, {"Leg_1_L": (-0.48, 0.0, 0.0), "Leg_1_R": (0.48, 0.0, 0.0), "Arm_1_L": (0.40, 0.0, 0.0), "Arm_1_R": (-0.40, 0.0, 0.0)}),
        (16, {"Leg_1_L": (0.48, 0.0, 0.0), "Leg_1_R": (-0.48, 0.0, 0.0), "Arm_1_L": (-0.40, 0.0, 0.0), "Arm_1_R": (0.40, 0.0, 0.0)}),
    ], 16)
    sit = {"Leg_1_L": (-1.18, 0.0, 0.0), "Leg_2_L": (1.35, 0.0, 0.0), "Leg_1_R": (-1.18, 0.0, 0.0), "Leg_2_R": (1.35, 0.0, 0.0), "Arm_1_L": (-0.46, 0.0, 0.10), "Arm_1_R": (-0.46, 0.0, -0.10)}
    create_action(armature, "Sit", [(1, sit), (24, sit)], 24)
    laptop_a = dict(sit, **{"Arm_1_L": (-0.82, 0.0, 0.18), "Arm_2_L": (-0.42, 0.0, 0.0), "Arm_1_R": (-0.82, 0.0, -0.18), "Arm_2_R": (-0.42, 0.0, 0.0)})
    laptop_b = dict(laptop_a, **{"Wrist_L": (0.0, 0.0, 0.12), "Wrist_R": (0.0, 0.0, -0.12)})
    create_action(armature, "StudyLaptop", [(1, laptop_a), (12, laptop_b), (24, laptop_a)], 24)
    book = dict(sit, **{"Arm_1_L": (-0.68, 0.0, 0.32), "Arm_2_L": (-0.72, 0.0, 0.0), "Arm_1_R": (-0.68, 0.0, -0.32), "Arm_2_R": (-0.72, 0.0, 0.0)})
    create_action(armature, "StudyBook", [(1, book), (32, dict(book, **{"Head": (0.0, 0.08, 0.0)})), (64, book)], 64)
    create_action(armature, "Wave", [
        (1, {"Arm_1_R": (0.0, 0.0, -1.45), "Arm_2_R": (0.0, 0.0, -0.55)}),
        (8, {"Arm_1_R": (0.0, 0.0, -1.45), "Arm_2_R": (0.0, 0.0, 0.45)}),
        (16, {"Arm_1_R": (0.0, 0.0, -1.45), "Arm_2_R": (0.0, 0.0, -0.55)}),
        (24, {"Arm_1_R": (0.0, 0.0, -1.45), "Arm_2_R": (0.0, 0.0, 0.45)}),
    ], 24)
    create_action(armature, "Stretch", [
        (1, {"Arm_1_L": (0.0, 0.0, 0.0), "Arm_1_R": (0.0, 0.0, 0.0)}),
        (18, {"Arm_1_L": (0.0, 0.0, 2.2), "Arm_1_R": (0.0, 0.0, -2.2), "Spine_2": (0.12, 0.0, 0.0)}),
        (36, {"Arm_1_L": (0.0, 0.0, 0.0), "Arm_1_R": (0.0, 0.0, 0.0)}),
    ], 36)


def main() -> None:
    args = arguments()
    source = Path(args.source_fbx)
    texture_dir = Path(args.texture_dir)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    reset_scene()
    bpy.ops.import_scene.fbx(filepath=str(source))
    choose_meshes(args.mesh_prefix)
    remap_textures(texture_dir)
    armatures = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"Expected one armature, found {len(armatures)}")
    armature = armatures[0]
    create_actions(armature)
    bpy.context.scene.render.fps = 24
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    report = {
        "character_id": args.character_id,
        "source_fbx": str(source),
        "texture_dir": str(texture_dir),
        "mesh_objects": [obj.name for obj in meshes],
        "mesh_count": len(meshes),
        "armature": armature.name,
        "bone_count": len(armature.data.bones),
        "source_actions": [],
        "generated_actions": [action.name for action in bpy.data.actions],
        "forward_axis": "+Z source; VisualRoot rotates 180 degrees to canonical -Z",
        "output": str(output),
    }
    output.with_suffix(".diagnostic.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("STUDYTOWN_ACNH_DIAGNOSTIC", json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
