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


LOOP_ACTIONS = {
    "Idle",
    "Walk",
    "SeatedIdle",
    "StudyLaptop",
    "StudyBook",
    "ArmchairSeatedIdle",
    "ArmchairStudyLaptop",
    "ArmchairStudyBook",
    "FloorStudy",
    "TrainStudy",
}


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

    # -------------------------------------------------------------------------
    # Animal-Crossing-style walk cycle
    # -------------------------------------------------------------------------
    #
    # - short, cute stride
    # - bent passing knee
    # - subtle vertical bounce
    # - strong opposite arm swing
    # - elbows bent naturally FORWARD rather than folding backward
    #
    # RIG AXES:
    #
    # Legs:
    #   LOCAL Z = main forward/back hip and knee flexion.
    #
    # Arms:
    #   Arm_1 LOCAL Z = shoulder forward/back swing.
    #   Arm_2 LOCAL Z = elbow flexion.
    #
    # The previous version used Arm_2 LOCAL Y for elbow bending. On this rig
    # that bends the forearm in the wrong plane and makes it look like the
    # elbows are folding backward.
    #
    # Cycle:
    #
    #   1   LEFT CONTACT
    #   4   LEFT DOWN
    #   7   RIGHT PASSING
    #  10   RIGHT UP
    #  13   RIGHT CONTACT
    #  16   RIGHT DOWN
    #  19   LEFT PASSING
    #  22   LEFT UP
    #  25   LEFT CONTACT

    walk_left_contact = {
        "rotation": {
            # --------------------------------------------------------------
            # LEGS
            # --------------------------------------------------------------

            # LEFT LEG - forward/contact
            "Leg_1_L": (0.0, 0.0, 0.42),
            "Leg_1_L_Sub": (0.0, 0.0, 0.03),

            "Leg_2_L": (0.0, 0.0, -0.12),
            "Leg_2_L_Sub": (0.0, 0.0, -0.01),

            "Ankle_L": (0.0, 0.0, 0.04),

            # RIGHT LEG - trailing
            "Leg_1_R": (0.0, 0.0, -0.32),
            "Leg_1_R_Sub": (0.0, 0.0, -0.02),

            "Leg_2_R": (0.0, 0.0, -0.50),
            "Leg_2_R_Sub": (0.0, 0.0, -0.04),

            "Ankle_R": (0.0, 0.0, 0.14),

            # --------------------------------------------------------------
            # ARMS
            #
            # Left leg forward -> RIGHT arm forward.
            # --------------------------------------------------------------

            # LEFT arm backward
            "Arm_1_L": (1.42, -1.34, -0.52),
            "Arm_1_L_Sub": (0.0, 0.0, -0.03),

            # Elbow bent forward
            "Arm_2_L": (0.0, 0.0, -0.46),

            # RIGHT arm forward
            "Arm_1_R": (-1.42, -1.34, 0.52),
            "Arm_1_R_Sub": (0.0, 0.0, 0.03),

            # Elbow bent forward
            "Arm_2_R": (0.0, 0.0, 0.46),

            # --------------------------------------------------------------
            # BODY
            # --------------------------------------------------------------

            "Spine_2": (0.020, 0.0, 0.055),
            "Spine_3": (0.0, 0.0, 0.025),

            "Head": (-0.015, -0.025, -0.035),

            "Ear_1_L": (0.0, 0.0, -0.014),
            "Ear_1_R": (0.0, 0.0, 0.014),

            "S_Tail_1": (0.0, 0.04, -0.12),
            "S_Tail_2": (0.0, 0.05, -0.08),
            "S_Tail_3": (0.0, 0.03, -0.04),
        },

        "location": {
            "Trans_Root": (0.0, 0.0, 0.025),
        },
    }

    walk_left_down = {
        "rotation": {
            # --------------------------------------------------------------
            # LEGS
            # --------------------------------------------------------------

            "Leg_1_L": (0.0, 0.0, 0.30),
            "Leg_1_L_Sub": (0.0, 0.0, 0.02),

            "Leg_2_L": (0.0, 0.0, -0.28),
            "Leg_2_L_Sub": (0.0, 0.0, -0.02),

            "Ankle_L": (0.0, 0.0, 0.06),

            "Leg_1_R": (0.0, 0.0, -0.20),
            "Leg_1_R_Sub": (0.0, 0.0, -0.02),

            "Leg_2_R": (0.0, 0.0, -0.62),
            "Leg_2_R_Sub": (0.0, 0.0, -0.05),

            "Ankle_R": (0.0, 0.0, 0.18),

            # --------------------------------------------------------------
            # ARMS
            # --------------------------------------------------------------

            "Arm_1_L": (1.42, -1.34, -0.44),
            "Arm_1_L_Sub": (0.0, 0.0, -0.025),
            "Arm_2_L": (0.0, 0.0, -0.50),

            "Arm_1_R": (-1.42, -1.34, 0.44),
            "Arm_1_R_Sub": (0.0, 0.0, 0.025),
            "Arm_2_R": (0.0, 0.0, 0.50),

            # --------------------------------------------------------------
            # BODY
            # --------------------------------------------------------------

            "Spine_2": (0.025, 0.0, 0.065),
            "Spine_3": (0.0, 0.0, 0.030),

            "Head": (-0.020, -0.020, -0.040),

            "S_Tail_1": (0.0, 0.035, -0.10),
            "S_Tail_2": (0.0, 0.045, -0.07),
        },

        "location": {
            "Trans_Root": (0.0, 0.0, 0.0),
        },
    }

    walk_right_passing = {
        "rotation": {
            # --------------------------------------------------------------
            # LEGS
            # --------------------------------------------------------------

            # LEFT leg planted
            "Leg_1_L": (0.0, 0.0, -0.08),
            "Leg_1_L_Sub": (0.0, 0.0, -0.01),

            "Leg_2_L": (0.0, 0.0, -0.12),
            "Leg_2_L_Sub": (0.0, 0.0, -0.01),

            "Ankle_L": (0.0, 0.0, 0.03),

            # RIGHT passing leg
            "Leg_1_R": (0.0, 0.0, 0.02),
            "Leg_1_R_Sub": (0.0, 0.0, 0.0),

            "Leg_2_R": (0.0, 0.0, -0.72),
            "Leg_2_R_Sub": (0.0, 0.0, -0.06),

            "Ankle_R": (0.0, 0.0, 0.22),

            # --------------------------------------------------------------
            # ARMS
            #
            # Shoulders pass near neutral.
            # Elbows stay visibly bent.
            # --------------------------------------------------------------

            "Arm_1_L": (1.42, -1.34, -0.08),
            "Arm_1_L_Sub": (0.0, 0.0, -0.005),
            "Arm_2_L": (0.0, 0.0, -0.40),

            "Arm_1_R": (-1.42, -1.34, 0.08),
            "Arm_1_R_Sub": (0.0, 0.0, 0.005),
            "Arm_2_R": (0.0, 0.0, 0.40),

            # --------------------------------------------------------------
            # BODY
            # --------------------------------------------------------------

            "Spine_2": (0.0, 0.0, 0.025),
            "Spine_3": (0.0, 0.0, 0.012),

            "Head": (0.0, 0.0, -0.015),

            "S_Tail_1": (0.0, 0.0, -0.035),
            "S_Tail_2": (0.0, 0.0, -0.025),
        },

        "location": {
            "Trans_Root": (0.0, 0.0, 0.080),
        },
    }

    walk_right_up = {
        "rotation": {
            # --------------------------------------------------------------
            # LEGS
            # --------------------------------------------------------------

            "Leg_1_L": (0.0, 0.0, -0.26),
            "Leg_1_L_Sub": (0.0, 0.0, -0.02),

            "Leg_2_L": (0.0, 0.0, -0.24),
            "Leg_2_L_Sub": (0.0, 0.0, -0.02),

            "Ankle_L": (0.0, 0.0, 0.10),

            "Leg_1_R": (0.0, 0.0, 0.28),
            "Leg_1_R_Sub": (0.0, 0.0, 0.02),

            "Leg_2_R": (0.0, 0.0, -0.38),
            "Leg_2_R_Sub": (0.0, 0.0, -0.03),

            "Ankle_R": (0.0, 0.0, 0.12),

            # --------------------------------------------------------------
            # ARMS
            # --------------------------------------------------------------

            "Arm_1_L": (1.42, -1.34, 0.34),
            "Arm_1_L_Sub": (0.0, 0.0, 0.02),
            "Arm_2_L": (0.0, 0.0, -0.44),

            "Arm_1_R": (-1.42, -1.34, -0.34),
            "Arm_1_R_Sub": (0.0, 0.0, -0.02),
            "Arm_2_R": (0.0, 0.0, 0.44),

            # --------------------------------------------------------------
            # BODY
            # --------------------------------------------------------------

            "Spine_2": (-0.012, 0.0, -0.030),
            "Spine_3": (0.0, 0.0, -0.015),

            "Head": (0.010, 0.018, 0.020),

            "S_Tail_1": (0.0, -0.025, 0.065),
            "S_Tail_2": (0.0, -0.035, 0.045),
        },

        "location": {
            "Trans_Root": (0.0, 0.0, 0.110),
        },
    }

    walk_right_contact = {
        "rotation": {
            # --------------------------------------------------------------
            # LEGS
            # --------------------------------------------------------------

            # LEFT trailing
            "Leg_1_L": (0.0, 0.0, -0.32),
            "Leg_1_L_Sub": (0.0, 0.0, -0.02),

            "Leg_2_L": (0.0, 0.0, -0.50),
            "Leg_2_L_Sub": (0.0, 0.0, -0.04),

            "Ankle_L": (0.0, 0.0, 0.14),

            # RIGHT contact
            "Leg_1_R": (0.0, 0.0, 0.42),
            "Leg_1_R_Sub": (0.0, 0.0, 0.03),

            "Leg_2_R": (0.0, 0.0, -0.12),
            "Leg_2_R_Sub": (0.0, 0.0, -0.01),

            "Ankle_R": (0.0, 0.0, 0.04),

            # --------------------------------------------------------------
            # ARMS
            #
            # Right leg forward -> LEFT arm forward.
            # --------------------------------------------------------------

            "Arm_1_L": (1.42, -1.34, 0.52),
            "Arm_1_L_Sub": (0.0, 0.0, 0.03),
            "Arm_2_L": (0.0, 0.0, -0.46),

            "Arm_1_R": (-1.42, -1.34, -0.52),
            "Arm_1_R_Sub": (0.0, 0.0, -0.03),
            "Arm_2_R": (0.0, 0.0, 0.46),

            # --------------------------------------------------------------
            # BODY
            # --------------------------------------------------------------

            "Spine_2": (0.020, 0.0, -0.055),
            "Spine_3": (0.0, 0.0, -0.025),

            "Head": (-0.015, 0.025, 0.035),

            "Ear_1_L": (0.0, 0.0, 0.014),
            "Ear_1_R": (0.0, 0.0, -0.014),

            "S_Tail_1": (0.0, -0.04, 0.12),
            "S_Tail_2": (0.0, -0.05, 0.08),
            "S_Tail_3": (0.0, -0.03, 0.04),
        },

        "location": {
            "Trans_Root": (0.0, 0.0, 0.025),
        },
    }

    walk_right_down = {
        "rotation": {
            # --------------------------------------------------------------
            # LEGS
            # --------------------------------------------------------------

            "Leg_1_L": (0.0, 0.0, -0.20),
            "Leg_1_L_Sub": (0.0, 0.0, -0.02),

            "Leg_2_L": (0.0, 0.0, -0.62),
            "Leg_2_L_Sub": (0.0, 0.0, -0.05),

            "Ankle_L": (0.0, 0.0, 0.18),

            "Leg_1_R": (0.0, 0.0, 0.30),
            "Leg_1_R_Sub": (0.0, 0.0, 0.02),

            "Leg_2_R": (0.0, 0.0, -0.28),
            "Leg_2_R_Sub": (0.0, 0.0, -0.02),

            "Ankle_R": (0.0, 0.0, 0.06),

            # --------------------------------------------------------------
            # ARMS
            # --------------------------------------------------------------

            "Arm_1_L": (1.42, -1.34, 0.44),
            "Arm_1_L_Sub": (0.0, 0.0, 0.025),
            "Arm_2_L": (0.0, 0.0, -0.50),

            "Arm_1_R": (-1.42, -1.34, -0.44),
            "Arm_1_R_Sub": (0.0, 0.0, -0.025),
            "Arm_2_R": (0.0, 0.0, 0.50),

            # --------------------------------------------------------------
            # BODY
            # --------------------------------------------------------------

            "Spine_2": (0.025, 0.0, -0.065),
            "Spine_3": (0.0, 0.0, -0.030),

            "Head": (-0.020, 0.020, 0.040),

            "S_Tail_1": (0.0, -0.035, 0.10),
            "S_Tail_2": (0.0, -0.045, 0.07),
        },

        "location": {
            "Trans_Root": (0.0, 0.0, 0.0),
        },
    }

    walk_left_passing = {
        "rotation": {
            # --------------------------------------------------------------
            # LEGS
            # --------------------------------------------------------------

            # LEFT passing
            "Leg_1_L": (0.0, 0.0, 0.02),
            "Leg_1_L_Sub": (0.0, 0.0, 0.0),

            "Leg_2_L": (0.0, 0.0, -0.72),
            "Leg_2_L_Sub": (0.0, 0.0, -0.06),

            "Ankle_L": (0.0, 0.0, 0.22),

            # RIGHT planted
            "Leg_1_R": (0.0, 0.0, -0.08),
            "Leg_1_R_Sub": (0.0, 0.0, -0.01),

            "Leg_2_R": (0.0, 0.0, -0.12),
            "Leg_2_R_Sub": (0.0, 0.0, -0.01),

            "Ankle_R": (0.0, 0.0, 0.03),

            # --------------------------------------------------------------
            # ARMS
            # --------------------------------------------------------------

            "Arm_1_L": (1.42, -1.34, 0.08),
            "Arm_1_L_Sub": (0.0, 0.0, 0.005),
            "Arm_2_L": (0.0, 0.0, -0.40),

            "Arm_1_R": (-1.42, -1.34, -0.08),
            "Arm_1_R_Sub": (0.0, 0.0, -0.005),
            "Arm_2_R": (0.0, 0.0, 0.40),

            # --------------------------------------------------------------
            # BODY
            # --------------------------------------------------------------

            "Spine_2": (0.0, 0.0, -0.025),
            "Spine_3": (0.0, 0.0, -0.012),

            "Head": (0.0, 0.0, 0.015),

            "S_Tail_1": (0.0, 0.0, 0.035),
            "S_Tail_2": (0.0, 0.0, 0.025),
        },

        "location": {
            "Trans_Root": (0.0, 0.0, 0.080),
        },
    }

    walk_left_up = {
        "rotation": {
            # --------------------------------------------------------------
            # LEGS
            # --------------------------------------------------------------

            "Leg_1_L": (0.0, 0.0, 0.28),
            "Leg_1_L_Sub": (0.0, 0.0, 0.02),

            "Leg_2_L": (0.0, 0.0, -0.38),
            "Leg_2_L_Sub": (0.0, 0.0, -0.03),

            "Ankle_L": (0.0, 0.0, 0.12),

            "Leg_1_R": (0.0, 0.0, -0.26),
            "Leg_1_R_Sub": (0.0, 0.0, -0.02),

            "Leg_2_R": (0.0, 0.0, -0.24),
            "Leg_2_R_Sub": (0.0, 0.0, -0.02),

            "Ankle_R": (0.0, 0.0, 0.10),

            # --------------------------------------------------------------
            # ARMS
            # --------------------------------------------------------------

            "Arm_1_L": (1.42, -1.34, -0.34),
            "Arm_1_L_Sub": (0.0, 0.0, -0.02),
            "Arm_2_L": (0.0, 0.0, -0.44),

            "Arm_1_R": (-1.42, -1.34, 0.34),
            "Arm_1_R_Sub": (0.0, 0.0, 0.02),
            "Arm_2_R": (0.0, 0.0, 0.44),

            # --------------------------------------------------------------
            # BODY
            # --------------------------------------------------------------

            "Spine_2": (-0.012, 0.0, 0.030),
            "Spine_3": (0.0, 0.0, 0.015),

            "Head": (0.010, -0.018, -0.020),

            "S_Tail_1": (0.0, 0.025, -0.065),
            "S_Tail_2": (0.0, 0.035, -0.045),
        },

        "location": {
            "Trans_Root": (0.0, 0.0, 0.110),
        },
    }

    create_action(
        armature,
        "Walk",
        [
            (1, walk_left_contact),
            (4, walk_left_down),
            (7, walk_right_passing),
            (10, walk_right_up),

            (13, walk_right_contact),
            (16, walk_right_down),
            (19, walk_left_passing),
            (22, walk_left_up),

            # Same as frame 1 for a seamless loop.
            (25, walk_left_contact),
        ],
        25,
    )

    # Generic chair sitting pose.
    #
    # The cat rig bends anatomically around the leg bones' LOCAL Z axis.
    # This is the same proven leg configuration used by TrainStudy:
    #
    #   hip -> thigh forward
    #              \
    #               knee
    #                |
    #                | shin down
    #                |
    #
    # Library, garden and standard Japanese-room chairs all inherit this pose
    # through SeatedIdle / StudyLaptop / StudyBook.
    chair_sit = {
        "rotation": {
            # LEFT LEG
            "Leg_1_L": (0.0, 0.0, 1.42),
            "Leg_1_L_Sub": (0.0, 0.0, 0.10),

            "Leg_2_L": (0.0, 0.0, -1.38),
            "Leg_2_L_Sub": (0.0, 0.0, -0.08),

            "Ankle_L": (0.0, 0.0, 0.18),

            # RIGHT LEG
            "Leg_1_R": (0.0, 0.0, 1.42),
            "Leg_1_R_Sub": (0.0, 0.0, 0.10),

            "Leg_2_R": (0.0, 0.0, -1.38),
            "Leg_2_R_Sub": (0.0, 0.0, -0.08),

            "Ankle_R": (0.0, 0.0, 0.18),

            # ARMS
            "Arm_1_L": (0.0, -1.50, -1.34),
            "Arm_2_L": (0.0, -1.50, 1.0),

            "Arm_1_R": (0.50, -1.50, 1.34),
            "Arm_2_R": (0.0, 1.50, -0.50),

            # Slight seated torso lean.
            "Spine_2": (0.10, 0.0, 0.0),
        }
    }

    # Armchair-specific seated pose.
    #
    # The thighs are held almost exactly 90 degrees forward from the upright
    # body, while the shins counter-rotate by 90 degrees and fall straight
    # down. Secondary deform bones are neutral so each leg segment stays
    # visually straight rather than curving through the upholstered seat.
    armchair_sit = merged(
        chair_sit,
        {
            "rotation": {
                # LEFT LEG — 90-degree hip and knee bend.
                "Leg_1_L": (0.0, 0.0, 1.5708),
                "Leg_1_L_Sub": (0.0, 0.0, 0.0),
                "Leg_2_L": (0.0, 0.0, -1.5708),
                "Leg_2_L_Sub": (0.0, 0.0, 0.0),
                "Ankle_L": (0.0, 0.0, 0.0),

                # RIGHT LEG — mirrored placement, same anatomical bend.
                "Leg_1_R": (0.0, 0.0, 1.5708),
                "Leg_1_R_Sub": (0.0, 0.0, 0.0),
                "Leg_2_R": (0.0, 0.0, -1.5708),
                "Leg_2_R_Sub": (0.0, 0.0, 0.0),
                "Ankle_R": (0.0, 0.0, 0.0),

                # Keep the torso more upright in the armchair.
                "Spine_2": (0.06, 0.0, 0.0),
            }
        },
    )

    create_action(
        armature,
        "Sit",
        [
            (1, arms_down),
            (9, scaled_pose(chair_sit, 0.52)),
            (18, chair_sit),
            (24, chair_sit),
        ],
        24,
    )

    seated_idle_a = merged(
        chair_sit,
        {
            "rotation": {
                "Head": (0.08, -0.025, 0.018),
                "S_Tail_2": (0.0, 0.08, -0.06),
            }
        },
    )

    seated_idle_b = merged(
        chair_sit,
        {
            "rotation": {
                "Head": (0.11, 0.025, -0.018),
                "S_Tail_2": (0.0, -0.08, 0.06),
            }
        },
    )

    create_action(
        armature,
        "SeatedIdle",
        [
            (1, seated_idle_a),
            (32, seated_idle_b),
            (64, seated_idle_a),
        ],
        64,
    )

    armchair_idle_a = merged(
        armchair_sit,
        {
            "rotation": {
                "Head": (0.08, -0.025, 0.018),
                "S_Tail_2": (0.0, 0.08, -0.06),
            }
        },
    )

    armchair_idle_b = merged(
        armchair_sit,
        {
            "rotation": {
                "Head": (0.11, 0.025, -0.018),
                "S_Tail_2": (0.0, -0.08, 0.06),
            }
        },
    )

    create_action(
        armature,
        "ArmchairSeatedIdle",
        [
            (1, armchair_idle_a),
            (32, armchair_idle_b),
            (64, armchair_idle_a),
        ],
        64,
    )

    laptop_a = merged(
        chair_sit,
        {
            "rotation": {
                "Spine_2": (0.22, 0.0, 0.0),
                "Head": (0.16, -0.02, 0.0),

                "Arm_1_L": (0.0, -1.50, -1.34),
                "Arm_2_L": (0.0, -1.36, 1.08),

                "Arm_1_R": (0.50, -1.50, 1.34),
                "Arm_2_R": (0.0, 1.36, -0.58),

                "Wrist_L": (0.0, 0.0, 0.28),
                "Wrist_R": (0.0, 0.0, -0.24),

                "Hand_L": (0.0, 0.10, 0.0),
                "Hand_R": (0.0, -0.10, 0.0),
            }
        },
    )

    laptop_b = merged(
        laptop_a,
        {
            "rotation": {
                "Head": (0.19, 0.025, 0.018),

                "Arm_2_L": (0.08, -1.46, 0.94),
                "Arm_2_R": (-0.08, 1.46, -0.44),

                "Wrist_L": (0.0, 0.0, -0.28),
                "Wrist_R": (0.0, 0.0, 0.24),

                "Hand_L": (0.0, -0.12, 0.0),
                "Hand_R": (0.0, 0.12, 0.0),
            }
        },
    )

    create_action(
        armature,
        "StudyLaptop",
        [
            (1, laptop_a),
            (8, laptop_b),
            (16, laptop_a),
            (24, laptop_b),
            (32, laptop_a),
        ],
        32,
    )

    armchair_laptop_a = merged(
        armchair_sit,
        {
            "rotation": {
                "Spine_2": (0.18, 0.0, 0.0),
                "Head": (0.16, -0.02, 0.0),

                "Arm_1_L": (0.0, -1.50, -1.34),
                "Arm_2_L": (0.0, -1.36, 1.08),
                "Arm_1_R": (0.50, -1.50, 1.34),
                "Arm_2_R": (0.0, 1.36, -0.58),

                "Wrist_L": (0.0, 0.0, 0.28),
                "Wrist_R": (0.0, 0.0, -0.24),
                "Hand_L": (0.0, 0.10, 0.0),
                "Hand_R": (0.0, -0.10, 0.0),
            }
        },
    )

    armchair_laptop_b = merged(
        armchair_laptop_a,
        {
            "rotation": {
                "Head": (0.19, 0.025, 0.018),
                "Arm_2_L": (0.08, -1.46, 0.94),
                "Arm_2_R": (-0.08, 1.46, -0.44),
                "Wrist_L": (0.0, 0.0, -0.28),
                "Wrist_R": (0.0, 0.0, 0.24),
                "Hand_L": (0.0, -0.12, 0.0),
                "Hand_R": (0.0, 0.12, 0.0),
            }
        },
    )

    create_action(
        armature,
        "ArmchairStudyLaptop",
        [
            (1, armchair_laptop_a),
            (8, armchair_laptop_b),
            (16, armchair_laptop_a),
            (24, armchair_laptop_b),
            (32, armchair_laptop_a),
        ],
        32,
    )

    book_a = merged(
        chair_sit,
        {
            "rotation": {
                "Spine_2": (0.12, 0.0, 0.0),
                "Head": (0.22, -0.02, 0.0),

                "Arm_1_L": (0.0, -1.50, -1.34),
                "Arm_2_L": (0.0, -1.50, 1.0),

                "Arm_1_R": (0.50, -1.50, 1.34),
                "Arm_2_R": (0.0, 1.50, -0.50),
            }
        },
    )

    book_b = merged(
        book_a,
        {
            "rotation": {
                "Head": (0.27, 0.06, 0.025),
                "Arm_2_R": (0.12, 1.36, -0.36),
                "Wrist_R": (0.0, 0.0, 0.32),
                "Hand_R": (0.0, 0.18, 0.0),
            }
        },
    )

    create_action(
        armature,
        "StudyBook",
        [
            (1, book_a),
            (28, book_a),
            (42, book_b),
            (56, book_a),
            (72, book_a),
        ],
        72,
    )

    armchair_book_a = merged(
        armchair_sit,
        {
            "rotation": {
                "Spine_2": (0.10, 0.0, 0.0),
                "Head": (0.22, -0.02, 0.0),
                "Arm_1_L": (0.0, -1.50, -1.34),
                "Arm_2_L": (0.0, -1.50, 1.0),
                "Arm_1_R": (0.50, -1.50, 1.34),
                "Arm_2_R": (0.0, 1.50, -0.50),
            }
        },
    )

    armchair_book_b = merged(
        armchair_book_a,
        {
            "rotation": {
                "Head": (0.27, 0.06, 0.025),
                "Arm_2_R": (0.12, 1.36, -0.36),
                "Wrist_R": (0.0, 0.0, 0.32),
                "Hand_R": (0.0, 0.18, 0.0),
            }
        },
    )

    create_action(
        armature,
        "ArmchairStudyBook",
        [
            (1, armchair_book_a),
            (28, armchair_book_a),
            (42, armchair_book_b),
            (56, armchair_book_a),
            (72, armchair_book_a),
        ],
        72,
    )

        # Train booth seated pose.
    #
    # IMPORTANT:
    # This rig's anatomical forward/back leg flexion is primarily around each
    # leg bone's LOCAL Z axis, not local X.
    #
    # Positive Z on Leg_1 swings the thigh forward.
    # Negative Z on Leg_2 bends the lower leg back downward at the knee.
    train_a = merged(
        chair_sit,
        {
            "rotation": {
                # LEFT LEG
                # Hip flexion: thigh projects forward from the body.
                "Leg_1_L": (0.0, 0.0, 1.42),

                # Keep the secondary thigh deform bone aligned with the upper
                # leg instead of allowing its weighted vertices to remain
                # close to the standing silhouette.
                "Leg_1_L_Sub": (0.0, 0.0, 0.10),

                # Knee flexion: counter-rotate so the shin drops downward.
                "Leg_2_L": (0.0, 0.0, -1.38),
                "Leg_2_L_Sub": (0.0, 0.0, -0.08),

                # Small foot correction.
                "Ankle_L": (0.0, 0.0, 0.18),

                # RIGHT LEG
                "Leg_1_R": (0.0, 0.0, 1.42),
                "Leg_1_R_Sub": (0.0, 0.0, 0.10),

                "Leg_2_R": (0.0, 0.0, -1.38),
                "Leg_2_R_Sub": (0.0, 0.0, -0.08),

                "Ankle_R": (0.0, 0.0, 0.18),

                # Upper body
                "Spine_2": (0.12, 0.0, 0.0),
                "Head": (0.12, -0.02, 0.0),

                "Arm_1_L": (0.0, -1.50, -1.34),
                "Arm_2_L": (0.0, -1.50, 1.0),

                "Arm_1_R": (0.50, -1.50, 1.34),
                "Arm_2_R": (0.0, 1.50, -0.50),
            }
        },
    )

    train_b = merged(
        train_a,
        {
            "rotation": {
                "Head": (0.15, 0.025, 0.015),
                "Wrist_R": (0.0, 0.0, 0.12),
                "S_Tail_2": (0.0, 0.06, -0.05),
            }
        },
    )

    create_action(
        armature,
        "TrainStudy",
        [
            (1, train_a),
            (32, train_b),
            (64, train_a),
        ],
        64,
    )

    # Floor cushions should read as a cross-legged seated pose, similar to
    # sitting on the floor with an upright torso.
    #
    # IMPORTANT:
    # As with the corrected chair/train pose, the cat rig's meaningful leg
    # forward/back bending is primarily around LOCAL Z, while slight outward
    # opening of the knees is introduced with mirrored LOCAL Y offsets.
    #
    # This pose is intentionally built as:
    # - thighs forward and slightly opened outward
    # - lower legs folded inward/downward into a cross-legged silhouette
    # - ankles rotated so the feet tuck in closer to the body
    # - torso upright rather than hunched
    floor_base = {
        "rotation": {
            # LEFT LEG
            "Leg_1_L": (0.08, 0.34, 1.06),
            "Leg_1_L_Sub": (0.0, 0.0, 0.08),

            "Leg_2_L": (0.0, -0.18, -1.02),
            "Leg_2_L_Sub": (0.0, 0.0, -0.08),

            "Ankle_L": (0.22, 0.12, 0.36),
            "Toe_L": (0.0, 0.0, 0.18),

            # RIGHT LEG
            "Leg_1_R": (0.08, -0.34, 1.06),
            "Leg_1_R_Sub": (0.0, 0.0, 0.08),

            "Leg_2_R": (0.0, 0.18, -1.02),
            "Leg_2_R_Sub": (0.0, 0.0, -0.08),

            "Ankle_R": (0.22, -0.12, -0.36),
            "Toe_R": (0.0, 0.0, -0.18),

            # UPRIGHT TORSO
            "Spine_2": (0.02, 0.0, 0.0),

            # Keep the arms relaxed and readable for a study pose.
            # We are only solving the floor-sitting body silhouette here.
            "Arm_1_L": (0.10, -1.50, -1.18),
            "Arm_2_L": (0.0, -1.42, 0.92),

            "Arm_1_R": (0.32, -1.50, 1.18),
            "Arm_2_R": (0.0, 1.42, -0.92),
        },
        "location": {
            # Small root correction so the hips sit closer to the cushion/floor.
            "Trans_Root": (0.0, -0.03, -0.10),
        },
    }

    floor_a = merged(
        floor_base,
        {
            "rotation": {
                "Head": (0.07, -0.02, 0.01),
                "S_Tail_1": (0.0, 0.08, -0.12),
                "S_Tail_2": (0.0, 0.08, -0.08),
            }
        },
    )

    floor_b = merged(
        floor_base,
        {
            "rotation": {
                "Head": (0.10, 0.02, -0.01),
                "S_Tail_1": (0.0, -0.08, 0.12),
                "S_Tail_2": (0.0, -0.08, 0.08),
                "Wrist_R": (0.0, 0.0, 0.12),
            }
        },
    )

    create_action(
        armature,
        "FloorStudy",
        [
            (1, floor_a),
            (36, floor_b),
            (72, floor_a),
        ],
        72,
    )

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
