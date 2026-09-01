"""Search cat arm rotations for a centered, forward study pose in Blender."""

from __future__ import annotations

import itertools
import sys

import bpy
from mathutils import Vector


def main() -> None:
    source = sys.argv[sys.argv.index("--") + 1]
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.fbx(filepath=source, use_anim=False)
    armature = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    bpy.context.view_layer.objects.active = armature
    values = (-1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5)
    for side, target in (("L", Vector((1.0, 3.5, 0.0))), ("R", Vector((-1.0, 3.5, 0.0)))):
        upper = armature.pose.bones[f"Arm_1_{side}"]
        wrist = armature.pose.bones[f"Wrist_{side}"]
        down_results = []
        for rotation in itertools.product(values, repeat=3):
            for bone in armature.pose.bones:
                bone.rotation_mode = "XYZ"
                bone.rotation_euler = (0.0, 0.0, 0.0)
            upper.rotation_euler = rotation
            bpy.context.view_layer.update()
            end = wrist.tail.copy()
            down_results.append(((end - target).length, rotation, end))
        for score, rotation, end in sorted(down_results, key=lambda item: item[0])[:5]:
            print("DOWN", side, round(score, 3), rotation, tuple(round(value, 3) for value in end))
    up_values = (-3.0, -2.5, -2.0, -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0)
    for side, target in (("L", Vector((2.2, 7.3, 0.0))), ("R", Vector((-2.2, 7.3, 0.0)))):
        upper = armature.pose.bones[f"Arm_1_{side}"]
        wrist = armature.pose.bones[f"Wrist_{side}"]
        up_results = []
        for rotation in itertools.product(up_values, repeat=3):
            for bone in armature.pose.bones:
                bone.rotation_mode = "XYZ"
                bone.rotation_euler = (0.0, 0.0, 0.0)
            upper.rotation_euler = rotation
            bpy.context.view_layer.update()
            end = wrist.tail.copy()
            up_results.append(((end - target).length, rotation, end))
        for score, rotation, end in sorted(up_results, key=lambda item: item[0])[:5]:
            print("UP", side, round(score, 3), rotation, tuple(round(value, 3) for value in end))
    for side, target in (("L", Vector((1.2, 4.3, 1.5))), ("R", Vector((-1.2, 4.3, 1.5)))):
        upper = armature.pose.bones[f"Arm_1_{side}"]
        lower = armature.pose.bones[f"Arm_2_{side}"]
        wrist = armature.pose.bones[f"Wrist_{side}"]
        results = []
        upper_z = -1.34 if side == "L" else 1.34
        for upper_x, upper_y, lower_y, lower_z in itertools.product(values, repeat=4):
            upper.rotation_mode = "XYZ"
            lower.rotation_mode = "XYZ"
            upper.rotation_euler = (upper_x, upper_y, upper_z)
            lower.rotation_euler = (0.0, lower_y, lower_z)
            bpy.context.view_layer.update()
            end = wrist.tail.copy()
            results.append(((end - target).length, upper_x, upper_y, lower_y, lower_z, end))
        for result in sorted(results, key=lambda item: item[0])[:8]:
            score, upper_x, upper_y, lower_y, lower_z, end = result
            print(
                "POSE",
                side,
                round(score, 3),
                "upper",
                (upper_x, upper_y, upper_z),
                "lower",
                (0.0, lower_y, lower_z),
                "end",
                tuple(round(value, 3) for value in end),
            )


if __name__ == "__main__":
    main()
