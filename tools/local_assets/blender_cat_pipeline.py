"""Convert an owner-supplied ACNH cat variant into a local Godot GLB.

The source and output paths must remain under the gitignored ``assets/dev_local``
tree. No proprietary mesh or texture is written to Git by this tool.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


LOOP_ACTIONS = {"Idle", "Walk", "SeatedIdle", "StudyLaptop", "StudyBook"}


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-fbx", required=True)
    parser.add_argument("--texture-dir", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--character-id", required=True)
    parser.add_argument("--target-height", type=float, default=2.70)
    parser.add_argument("--raymond", action="store_true")
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.actions, bpy.data.materials, bpy.data.images):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def classify_character_mesh(obj: bpy.types.Object) -> str:
    """Classify the actual cat hierarchy without an old character whitelist."""
    normalized = "".join(character for character in obj.name.lower() if character.isalnum())
    if normalized.startswith("body"):
        return "required_body_component"
    if normalized.startswith("accessory"):
        return "required_accessory"
    if normalized.startswith("catshirt") and "tshirtsn" in normalized:
        return "selected_clothing"
    if normalized.startswith("catshirt"):
        return "alternate_clothing"
    if any(modifier.type == "ARMATURE" for modifier in obj.modifiers):
        return "required_unknown_skinned_component"
    return "non_character_mesh"


def filter_character_meshes() -> dict[str, str]:
    roles: dict[str, str] = {}
    for obj in list(bpy.data.objects):
        if obj.type in {"CAMERA", "LIGHT"} or obj.name == "Cube":
            bpy.data.objects.remove(obj, do_unlink=True)
        elif obj.type == "MESH":
            role = classify_character_mesh(obj)
            roles[obj.name] = role
            if role in {"alternate_clothing", "non_character_mesh"}:
                bpy.data.objects.remove(obj, do_unlink=True)
    return roles


def texture_for(material_name: str, texture_dir: Path, suffix: str) -> Path | None:
    name = material_name.lower()
    stem = None
    if name.startswith("mbody"):
        stem = "mBody"
    elif name.startswith("mcapvis"):
        # The cat ear-cap mesh has its own Raymond material name but shares the
        # body texture set. Dropping this mesh was the missing-ear regression.
        stem = "mBody"
    elif name.startswith("meye"):
        stem = "mEye"
    elif name.startswith("mmouth"):
        stem = "mMouth"
    elif name.startswith("mtops"):
        stem = "mTops"
    elif name.startswith("mglassalpha"):
        stem = "mGlassAlpha"
    elif name.startswith("mglass"):
        stem = "mGlass"
    if stem is None:
        return None
    variants = [f"{stem}_{suffix}.png"]
    if stem in {"mEye", "mMouth"}:
        variants.insert(0, f"{stem}_{suffix}.0.png")
    for filename in variants:
        candidate = texture_dir / filename
        if candidate.exists():
            return candidate
    return None


def image_node(nodes, path: Path, label: str, non_color: bool = False):
    node = nodes.new("ShaderNodeTexImage")
    node.name = label
    node.label = label
    node.image = bpy.data.images.load(str(path), check_existing=True)
    if non_color:
        node.image.colorspace_settings.name = "Non-Color"
    return node


def rebuild_materials(texture_dir: Path) -> None:
    used = {slot.material for obj in bpy.data.objects if obj.type == "MESH" for slot in obj.material_slots if slot.material}
    for material in used:
        material.use_nodes = True
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        nodes.clear()
        output = nodes.new("ShaderNodeOutputMaterial")
        shader = nodes.new("ShaderNodeBsdfPrincipled")
        shader.inputs["Roughness"].default_value = 0.72
        links.new(shader.outputs["BSDF"], output.inputs["Surface"])
        albedo_path = texture_for(material.name, texture_dir, "Alb")
        if albedo_path:
            albedo = image_node(nodes, albedo_path, "Albedo")
            links.new(albedo.outputs["Color"], shader.inputs["Base Color"])
            if material.name.lower().startswith(("mtops", "mglassalpha")):
                links.new(albedo.outputs["Alpha"], shader.inputs["Alpha"])
        normal_path = texture_for(material.name, texture_dir, "Nrm")
        if normal_path:
            normal = image_node(nodes, normal_path, "Normal", True)
            normal_map = nodes.new("ShaderNodeNormalMap")
            normal_map.inputs["Strength"].default_value = 0.65
            links.new(normal.outputs["Color"], normal_map.inputs["Color"])
            links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])
        roughness_path = texture_for(material.name, texture_dir, "Rgh")
        if roughness_path:
            roughness = image_node(nodes, roughness_path, "Roughness", True)
            links.new(roughness.outputs["Color"], shader.inputs["Roughness"])


def normalize_height(target_height: float) -> float:
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    height = max(point.z for point in points) - min(point.z for point in points)
    factor = target_height / max(height, 0.0001)
    roots = [obj for obj in bpy.context.scene.objects if obj.parent is None]
    for root in roots:
        root.scale *= factor
    return factor


def reset_pose(armature: bpy.types.Object) -> None:
    for bone in armature.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.location = (0.0, 0.0, 0.0)
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.scale = (1.0, 1.0, 1.0)


def key_pose(armature: bpy.types.Object, frame: int, pose: dict) -> None:
    bpy.context.scene.frame_set(frame)
    for name, values in pose.get("rotation", {}).items():
        bone = armature.pose.bones.get(name)
        if bone:
            bone.rotation_euler = values
            bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
    for name, values in pose.get("location", {}).items():
        bone = armature.pose.bones.get(name)
        if bone:
            bone.location = values
            bone.keyframe_insert(data_path="location", frame=frame, group=name)
    for name, values in pose.get("scale", {}).items():
        bone = armature.pose.bones.get(name)
        if bone:
            bone.scale = values
            bone.keyframe_insert(data_path="scale", frame=frame, group=name)


def create_action(armature: bpy.types.Object, name: str, poses: list[tuple[int, dict]], length: int) -> None:
    reset_pose(armature)
    action = bpy.data.actions.new(name)
    armature.animation_data_create()
    armature.animation_data.action = action
    for frame, pose in poses:
        key_pose(armature, frame, pose)
    action.frame_start = 1
    action.frame_end = length
    action.use_fake_user = True
    armature.animation_data.action = None


def merged(*poses: dict) -> dict:
    result = {"rotation": {}, "location": {}, "scale": {}}
    for pose in poses:
        result["rotation"].update(pose.get("rotation", {}))
        result["location"].update(pose.get("location", {}))
        result["scale"].update(pose.get("scale", {}))
    return result


def scaled_pose(pose: dict, amount: float) -> dict:
    result = {"rotation": {}, "location": {}, "scale": {}}
    for name, values in pose.get("rotation", {}).items():
        result["rotation"][name] = tuple(value * amount for value in values)
    for name, values in pose.get("location", {}).items():
        result["location"][name] = tuple(value * amount for value in values)
    for name, values in pose.get("scale", {}).items():
        result["scale"][name] = tuple(1.0 + (value - 1.0) * amount for value in values)
    return result


def create_actions(armature: bpy.types.Object) -> None:
    arms_down = {"rotation": {"Arm_1_L": (1.50, -1.50, 0.0), "Arm_1_R": (-1.50, -1.50, 0.0)}}
    idle_a = merged(arms_down, {"rotation": {"Spine_2": (-0.025, 0.0, -0.035), "Spine_3": (0.0, 0.0, -0.035), "Head": (0.0, -0.045, 0.025), "Ear_1_L": (0.0, 0.0, -0.018), "Ear_1_R": (0.0, 0.0, 0.018), "Arm_1_L": (1.47, -1.50, -0.025), "Arm_1_R": (-1.47, -1.50, 0.025), "S_Tail_1": (0.0, 0.10, -0.14), "S_Tail_2": (0.0, 0.12, -0.10)}, "scale": {"Spine_2": (1.0, 1.018, 1.0)}})
    idle_b = merged(arms_down, {"rotation": {"Spine_2": (0.025, 0.0, 0.035), "Spine_3": (0.0, 0.0, 0.035), "Head": (0.0, 0.045, -0.025), "Ear_1_L": (0.0, 0.0, 0.018), "Ear_1_R": (0.0, 0.0, -0.018), "Arm_1_L": (1.53, -1.50, 0.025), "Arm_1_R": (-1.53, -1.50, -0.025), "S_Tail_1": (0.0, -0.10, 0.14), "S_Tail_2": (0.0, -0.12, 0.10)}, "scale": {"Spine_2": (1.0, 0.988, 1.0)}})
    create_action(armature, "Idle", [(1, idle_a), (36, idle_b), (72, idle_a)], 72)

    # Exaggerated just enough to survive the elevated gameplay camera: clear
    # opposing hips, bent trailing knees, full arm counter-swing, bounce, and
    # tail follow-through. This remains a real skeletal cycle with no visual-root bob.
    walk_a = {"rotation": {"Leg_1_L": (1.16, 0.0, 0.05), "Leg_2_L": (-0.48, 0.0, 0.0), "Leg_1_R": (-0.96, 0.0, -0.05), "Leg_2_R": (0.68, 0.0, 0.0), "Arm_1_L": (0.76, -1.50, -0.18), "Arm_1_R": (-2.24, -1.50, 0.18), "Spine_2": (0.045, 0.0, 0.11), "Head": (-0.025, -0.055, -0.065), "Ear_1_L": (0.0, 0.0, -0.050), "Ear_1_R": (0.0, 0.0, 0.038), "S_Tail_1": (0.0, 0.08, -0.34), "S_Tail_2": (0.0, 0.11, -0.24), "S_Tail_3": (0.0, 0.08, -0.14)}, "location": {"Trans_Root": (0.0, 0.0, 0.015)}}
    walk_mid = {"rotation": {"Leg_1_L": (-0.12, 0.0, 0.0), "Leg_2_L": (0.48, 0.0, 0.0), "Leg_1_R": (0.12, 0.0, 0.0), "Leg_2_R": (0.48, 0.0, 0.0), "Arm_1_L": (1.50, -1.50, 0.0), "Arm_1_R": (-1.50, -1.50, 0.0), "Spine_2": (-0.055, 0.0, 0.0), "Head": (0.055, 0.0, 0.0), "S_Tail_1": (0.0, 0.0, 0.0), "S_Tail_2": (0.0, 0.0, 0.0)}, "location": {"Trans_Root": (0.0, 0.0, 0.105)}}
    walk_b = {"rotation": {"Leg_1_L": (-0.96, 0.0, 0.05), "Leg_2_L": (0.68, 0.0, 0.0), "Leg_1_R": (1.16, 0.0, -0.05), "Leg_2_R": (-0.48, 0.0, 0.0), "Arm_1_L": (2.24, -1.50, 0.18), "Arm_1_R": (-0.76, -1.50, -0.18), "Spine_2": (0.045, 0.0, -0.11), "Head": (-0.025, 0.055, 0.065), "Ear_1_L": (0.0, 0.0, 0.038), "Ear_1_R": (0.0, 0.0, -0.050), "S_Tail_1": (0.0, -0.08, 0.34), "S_Tail_2": (0.0, -0.11, 0.24), "S_Tail_3": (0.0, -0.08, 0.14)}, "location": {"Trans_Root": (0.0, 0.0, 0.015)}}
    create_action(armature, "Walk", [(1, walk_a), (7, walk_mid), (13, walk_b), (19, walk_mid), (25, walk_a)], 25)

    sit = {"rotation": {"Leg_1_L": (-1.38, 0.0, 0.07), "Leg_2_L": (1.62, 0.0, 0.0), "Ankle_L": (-0.18, 0.0, 0.0), "Leg_1_R": (-1.38, 0.0, -0.07), "Leg_2_R": (1.62, 0.0, 0.0), "Ankle_R": (-0.18, 0.0, 0.0), "Arm_1_L": (0.0, -1.50, -1.34), "Arm_2_L": (0.0, -1.50, 1.0), "Arm_1_R": (0.50, -1.50, 1.34), "Arm_2_R": (0.0, 1.50, -0.50), "Spine_2": (0.10, 0.0, 0.0)}}
    create_action(armature, "Sit", [(1, arms_down), (9, scaled_pose(sit, 0.52)), (18, sit), (24, sit)], 24)

    seated_idle_a = merged(sit, {"rotation": {"Head": (0.08, -0.025, 0.018), "S_Tail_2": (0.0, 0.08, -0.06)}})
    seated_idle_b = merged(sit, {"rotation": {"Head": (0.11, 0.025, -0.018), "S_Tail_2": (0.0, -0.08, 0.06)}})
    create_action(armature, "SeatedIdle", [(1, seated_idle_a), (32, seated_idle_b), (64, seated_idle_a)], 64)

    # The source rig's left/right arm bases are not simple Euler mirrors. These
    # rotations were solved against wrist endpoints in armature space so both
    # paws land together, forward of the torso, instead of producing a T-pose.
    laptop_a = merged(sit, {"rotation": {"Spine_2": (0.22, 0.0, 0.0), "Head": (0.16, -0.02, 0.0), "Arm_1_L": (0.0, -1.50, -1.34), "Arm_2_L": (0.0, -1.36, 1.08), "Arm_1_R": (0.50, -1.50, 1.34), "Arm_2_R": (0.0, 1.36, -0.58), "Wrist_L": (0.0, 0.0, 0.28), "Wrist_R": (0.0, 0.0, -0.24), "Hand_L": (0.0, 0.10, 0.0), "Hand_R": (0.0, -0.10, 0.0)}})
    laptop_b = merged(laptop_a, {"rotation": {"Head": (0.19, 0.025, 0.018), "Arm_2_L": (0.08, -1.46, 0.94), "Arm_2_R": (-0.08, 1.46, -0.44), "Wrist_L": (0.0, 0.0, -0.28), "Wrist_R": (0.0, 0.0, 0.24), "Hand_L": (0.0, -0.12, 0.0), "Hand_R": (0.0, 0.12, 0.0)}})
    create_action(armature, "StudyLaptop", [(1, laptop_a), (8, laptop_b), (16, laptop_a), (24, laptop_b), (32, laptop_a)], 32)

    book_a = merged(sit, {"rotation": {"Spine_2": (0.12, 0.0, 0.0), "Head": (0.22, -0.02, 0.0), "Arm_1_L": (0.0, -1.50, -1.34), "Arm_2_L": (0.0, -1.50, 1.0), "Arm_1_R": (0.50, -1.50, 1.34), "Arm_2_R": (0.0, 1.50, -0.50)}})
    book_b = merged(book_a, {"rotation": {"Head": (0.27, 0.06, 0.025), "Arm_2_R": (0.12, 1.36, -0.36), "Wrist_R": (0.0, 0.0, 0.32), "Hand_R": (0.0, 0.18, 0.0)}})
    create_action(armature, "StudyBook", [(1, book_a), (28, book_a), (42, book_b), (56, book_a), (72, book_a)], 72)

    wave_rest = {"rotation": {"Arm_1_L": (1.50, -1.50, 0.0), "Arm_1_R": (0.50, 1.0, 0.50), "Arm_2_R": (0.0, 0.0, -0.25)}}
    wave_out = {"rotation": {"Arm_1_L": (1.50, -1.50, 0.0), "Arm_1_R": (0.50, 1.0, 0.50), "Arm_2_R": (0.0, 0.0, 0.38), "Wrist_R": (0.0, 0.0, 0.25)}}
    create_action(armature, "Wave", [(1, arms_down), (6, wave_rest), (11, wave_out), (16, wave_rest), (21, wave_out), (28, arms_down)], 28)

    stretch = {"rotation": {"Arm_1_L": (-0.50, 1.0, -0.50), "Arm_1_R": (0.50, 1.0, 0.50), "Arm_2_L": (0.0, 0.0, 0.18), "Arm_2_R": (0.0, 0.0, -0.18), "Spine_2": (-0.12, 0.0, 0.0), "Head": (-0.08, 0.0, 0.0)}}
    create_action(armature, "Stretch", [(1, arms_down), (14, stretch), (28, stretch), (40, arms_down)], 40)

    cheer = {"rotation": {"Arm_1_L": (-0.55, 0.92, -0.58), "Arm_1_R": (0.55, 0.92, 0.58), "Arm_2_L": (0.0, 0.0, 0.28), "Arm_2_R": (0.0, 0.0, -0.28), "Spine_2": (-0.10, 0.0, 0.0), "Head": (-0.12, 0.0, 0.0)}, "location": {"Trans_Root": (0.0, 0.0, 0.04)}}
    create_action(armature, "Cheer", [(1, arms_down), (9, cheer), (20, cheer), (30, arms_down)], 30)


def main() -> None:
    args = arguments()
    source = Path(args.source_fbx).resolve()
    texture_dir = Path(args.texture_dir).resolve()
    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    reset_scene()
    bpy.ops.import_scene.fbx(filepath=str(source), use_anim=True)
    source_actions = [action.name for action in bpy.data.actions]
    mesh_roles = filter_character_meshes()
    rebuild_materials(texture_dir)
    armatures = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"Expected one cat armature, found {len(armatures)}")
    armature = armatures[0]
    scale_factor = normalize_height(args.target_height)
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
        "source_relative_path": source.name,
        "texture_variant": texture_dir.name,
        "mesh_objects": [obj.name for obj in meshes],
        "source_mesh_roles": mesh_roles,
        "mesh_count": len(meshes),
        "vertex_count": sum(len(obj.data.vertices) for obj in meshes),
        "armature": armature.name,
        "bone_count": len(armature.data.bones),
        "source_actions": source_actions,
        "generated_actions": [action.name for action in bpy.data.actions],
        "loop_actions": sorted(LOOP_ACTIONS),
        "one_shot_actions": ["Sit", "Wave", "Stretch", "Cheer"],
        "source_height": round(args.target_height / scale_factor, 5),
        "target_height": args.target_height,
        "scale_factor": round(scale_factor, 5),
        "forward_axis": "Source faces +Z; VisualRoot rotates 180 degrees to canonical gameplay -Z",
        "output_relative_path": output.name,
    }
    output.with_suffix(".diagnostic.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("STUDYTOWN_CAT_DIAGNOSTIC", json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
