"""Build StudyTown's original, reusable stylized furniture kit in Blender.

These assets fill genuine gaps in the owner-supplied library.  They are built
as beveled Blender meshes and exported to the gitignored local runtime folder;
Godot primitives remain reserved for structure, collision, and debugging.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy


PALETTE = {
    "cream": "F8E6BA",
    "cocoa": "5A3326",
    "wood": "8A4B2B",
    "honey": "E6A737",
    "green": "4F9A68",
    "teal": "38A89D",
    "gold": "F3C34E",
    "coral": "E96B58",
    "red": "B9483E",
    "blue": "4F76A8",
    "purple": "7F559F",
    "paper": "FFF8E8",
    "ink": "211A18",
    "stone": "B9AA94",
    "leaf": "123E24",
    "leaf_light": "216B38",
}


def args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--only", default="", help="Build one named asset instead of the complete kit")
    return parser.parse_args(argv)


def color(hex_value: str) -> tuple[float, float, float, float]:
    return tuple(int(hex_value[i : i + 2], 16) / 255 for i in (0, 2, 4)) + (1.0,)


def reset() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        for block in list(datablocks):
            datablocks.remove(block)


def material(name: str):
    found = bpy.data.materials.get(name)
    if found:
        return found
    mat = bpy.data.materials.new(name)
    base_color = color(PALETTE[name])
    mat.diffuse_color = base_color
    mat.roughness = 0.72
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    if principled:
        principled.inputs["Base Color"].default_value = base_color
        principled.inputs["Roughness"].default_value = 0.72
    return mat


def finish(obj, name: str, mat_name: str, bevel: float = 0.05):
    obj.name = name
    obj.data.name = name + "Mesh"
    obj.data.materials.append(material(mat_name))
    if bevel > 0:
        mod = obj.modifiers.new("Soft toy bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    return obj


def box(name, location, dimensions, mat_name, bevel=0.05, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat_name, min(bevel, min(dimensions) * 0.22))


def cylinder(name, location, radius, depth, mat_name, vertices=24, rotation=(0, 0, 0), bevel=0.04):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    return finish(bpy.context.object, name, mat_name, bevel)


def sphere(name, location, scale, mat_name, segments=24, rings=14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(obj, name, mat_name, 0)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def grass_blade(name: str, location, width: float, height: float, lean: float, angle: float, mat_name: str):
    """Create one tapered, slightly leaning low-poly blade with real thickness."""
    half_width = width * 0.5
    half_depth = 0.022
    tip_width = width * 0.10
    vertices = [
        (-half_width, -half_depth, 0), (half_width, -half_depth, 0),
        (-half_width, half_depth, 0), (half_width, half_depth, 0),
        (lean - tip_width, -half_depth * 0.45, height), (lean + tip_width, -half_depth * 0.45, height),
        (lean - tip_width, half_depth * 0.45, height), (lean + tip_width, half_depth * 0.45, height),
    ]
    faces = [
        (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2),
        (1, 3, 7, 5), (4, 5, 7, 6), (0, 2, 3, 1),
    ]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler.z = angle
    return finish(obj, name, mat_name, 0.012)


def grass_tuft() -> None:
    reset()
    blade_data = [
        (0.00, 0.00, 0.18, 0.62, 0.12, 0.00),
        (0.08, 0.02, 0.16, 0.48, 0.16, 0.75),
        (-0.07, 0.03, 0.15, 0.52, -0.14, 1.55),
        (0.02, -0.08, 0.14, 0.42, 0.13, 2.35),
        (-0.10, -0.04, 0.13, 0.38, -0.11, 3.05),
        (0.11, -0.05, 0.13, 0.35, 0.10, 3.85),
        (-0.02, 0.10, 0.12, 0.34, -0.10, 4.70),
    ]
    for index, (x, y, width, height, lean, angle) in enumerate(blade_data):
        grass_blade(
            f"GrassBlade{index + 1}", (x, y, 0), width, height, lean, angle,
            "leaf_light" if index in {1, 3, 6} else "leaf",
        )


def export(output_dir: Path, name: str) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    meshes[0].name = name
    meshes[0].data.name = name + "Mesh"
    bpy.ops.export_scene.gltf(
        filepath=str(output_dir / f"{name}.glb"),
        export_format="GLB",
        export_animations=False,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_apply=True,
    )
    bpy.ops.wm.save_as_mainfile(filepath=str(output_dir.parent / "source" / f"{name}.blend"))
    print(f"STUDYTOWN_BLENDER_ASSET {name}.glb")


def shelf_unit(front_sign: float, y_offset: float, width: float, height: float, depth: float, seed: int) -> None:
    back_y = y_offset - front_sign * depth * 0.40
    box("ShelfBack", (0, back_y, height / 2), (width, 0.14, height), "cocoa", 0.025)
    for side in (-1, 1):
        box("ShelfSide", (side * (width / 2 + 0.06), y_offset, height / 2), (0.24, depth, height + 0.12), "wood", 0.045)
    for row in range(6):
        z = 0.12 + row * (height - 0.2) / 5
        box("ShelfRail", (0, y_offset, z), (width + 0.26, depth + 0.12, 0.17), "honey" if row == 5 else "wood", 0.035)
        if row == 5:
            continue
        x = -width / 2 + 0.19
        index = 0
        while x < width / 2 - 0.14:
            bw = 0.13 + ((seed + row * 7 + index * 5) % 5) * 0.025
            bh = 0.43 + ((seed + row * 11 + index * 3) % 6) * 0.045
            palette = ("red", "blue", "green", "gold", "purple", "cream", "coral")
            y = y_offset + front_sign * (depth / 2 + 0.02)
            box("Book", (x, y, z + 0.09 + bh / 2), (bw, 0.24, bh), palette[(seed + row + index) % len(palette)], 0.018)
            x += bw + 0.055
            index += 1


def bookshelf(single: bool) -> None:
    reset()
    if single:
        shelf_unit(-1, 0, 3.8, 4.45, 0.68, 19)
    else:
        shelf_unit(-1, -0.39, 5.8, 3.8, 0.70, 31)
        shelf_unit(1, 0.39, 5.8, 3.8, 0.70, 47)


def study_table() -> None:
    reset()
    box("TableTop", (0, 0, 1.08), (3.7, 1.55, 0.25), "honey", 0.09)
    box("TableApron", (0, 0, 0.90), (3.42, 1.30, 0.20), "wood", 0.04)
    for x in (-1.48, 1.48):
        for y in (-0.53, 0.53):
            cylinder("TaperedLeg", (x, y, 0.48), 0.12, 0.96, "cocoa", 20, bevel=0.025)


def armchair(fabric: str) -> None:
    reset()
    box("Seat", (0, 0, 0.62), (1.42, 1.32, 0.34), fabric, 0.16)
    box("Back", (0, 0.47, 1.26), (1.48, 0.34, 1.18), fabric, 0.15, rotation=(math.radians(-7), 0, 0))
    for x in (-0.77, 0.77):
        box("Arm", (x, 0, 0.85), (0.30, 1.25, 0.46), fabric, 0.14)
    for x in (-0.54, 0.54):
        for y in (-0.38, 0.38):
            cylinder("Foot", (x, y, 0.18), 0.10, 0.36, "cocoa", 16, bevel=0.02)


def fireplace() -> None:
    reset()
    box("Hearth", (0, 0, 0.20), (3.20, 0.92, 0.40), "stone", 0.08)
    for x in (-1.24, 1.24):
        box("Pillar", (x, 0.12, 1.95), (0.58, 0.72, 3.50), "stone", 0.08)
    box("Mantel", (0, 0.05, 3.62), (3.28, 0.90, 0.36), "honey", 0.08)
    box("Firebox", (0, -0.03, 1.48), (2.02, 0.46, 2.40), "ink", 0.10)
    box("FireboxInset", (0, -0.30, 1.30), (1.62, 0.10, 1.76), "cocoa", 0.04)
    for index, x in enumerate((-0.48, -0.16, 0.16, 0.48)):
        cylinder("Log", (x, -0.45, 0.65), 0.13, 1.08, "wood", 16, rotation=(0, math.pi / 2, 0), bevel=0.02)
    for index, x in enumerate((-0.38, 0, 0.38)):
        sphere("Flame", (x, -0.50, 1.04 + abs(x) * 0.4), (0.20, 0.14, 0.48 + abs(x) * 0.16), "gold", 18, 10)


def globe() -> None:
    reset()
    cylinder("Base", (0, 0, 0.10), 0.48, 0.20, "cocoa", 28)
    cylinder("Stem", (0, 0, 0.78), 0.08, 1.38, "gold", 18)
    sphere("Globe", (0, 0, 1.52), (0.70, 0.70, 0.70), "blue", 32, 18)
    cylinder("Meridian", (0, 0, 1.52), 0.76, 0.055, "gold", 40, rotation=(math.pi / 2, 0, 0), bevel=0.01)
    for x, y, z, sx, sy in ((-0.22, -0.66, 1.62, .26, .11), (.28, -.65, 1.43, .20, .10), (.05, -.68, 1.78, .16, .08)):
        sphere("Land", (x, y, z), (sx, sy, 0.09), "green", 16, 8)


def cafe_table() -> None:
    reset()
    cylinder("CafeTop", (0, 0, 1.04), 1.16, 0.20, "honey", 40)
    cylinder("Pedestal", (0, 0, 0.52), 0.18, 0.96, "cocoa", 24)
    cylinder("Foot", (0, 0, 0.08), 0.58, 0.14, "cocoa", 32)
    cylinder("UmbrellaPole", (0, 0, 2.35), 0.08, 3.25, "wood", 20)
    cylinder("Canopy", (0, 0, 3.76), 2.05, 0.20, "coral", 12, bevel=0.08)
    sphere("CanopyCrown", (0, 0, 3.88), (.50, .50, .18), "gold", 20, 10)


def train_bench() -> None:
    reset()
    box("BenchSeat", (0, 0, .72), (2.75, 1.10, .24), "teal", .11)
    box("BenchBack", (0, .46, 1.35), (2.78, .28, 1.10), "teal", .13, rotation=(math.radians(-5), 0, 0))
    box("BenchBase", (0, .10, .35), (2.48, .82, .58), "cocoa", .09)
    box("SeatSeam", (0, -.56, .78), (.055, .04, .18), "cream", .01)


def train_table() -> None:
    reset()
    box("TrainTableTop", (0, 0, 1.02), (2.7, 1.0, .18), "honey", .08)
    cylinder("TrainTableLeg", (0, 0, .50), .12, 1.0, "cocoa", 20)
    box("TrainTableFoot", (0, 0, .08), (1.25, .55, .15), "cocoa", .05)


def low_table() -> None:
    reset()
    box("LowTableTop", (0, 0, .72), (2.82, 1.22, .20), "wood", .08)
    box("LowTableInset", (0, 0, .83), (2.54, .96, .055), "honey", .025)
    for x in (-1.05, 1.05):
        box("LowLeg", (x, 0, .35), (.20, .82, .70), "cocoa", .05)


def cushion() -> None:
    reset()
    cylinder("FloorCushion", (0, 0, .15), .66, .30, "coral", 32, bevel=.10)
    cylinder("CushionButton", (0, 0, .32), .08, .025, "gold", 20, bevel=.008)


def path_tile() -> None:
    reset()
    cylinder("GardenPathStone", (0, 0, .07), 1.0, .14, "stone", 14, bevel=.07)


def fountain_basin() -> None:
    reset()
    cylinder("OuterBasin", (0, 0, .25), 3.1, .50, "stone", 40, bevel=.10)
    cylinder("InnerBasin", (0, 0, .51), 2.55, .10, "ink", 40, bevel=.04)
    cylinder("FountainColumn", (0, 0, 1.12), .25, 1.7, "stone", 28, bevel=.06)
    cylinder("FountainBowl", (0, 0, 1.75), 1.15, .18, "stone", 36, bevel=.07)
    sphere("Finial", (0, 0, 2.03), (.30, .30, .38), "gold", 20, 12)


def water_surface() -> None:
    reset()
    segments = 64
    vertices = [(0.0, 0.0, 0.03)] + [
        (math.cos(index * math.tau / segments) * 2.52, math.sin(index * math.tau / segments) * 2.52, 0.03)
        for index in range(segments)
    ]
    faces = [(0, index + 1, (index + 1) % segments + 1) for index in range(segments)]
    mesh = bpy.data.meshes.new("WaterSurfaceMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material("blue"))
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            uv_layer.data[loop_index].uv = (vertex.x / 5.04 + 0.5, vertex.y / 5.04 + 0.5)
    obj = bpy.data.objects.new("WaterSurface", mesh)
    bpy.context.collection.objects.link(obj)


def wall_lamp() -> None:
    reset()
    box("LampMount", (0, .10, 0), (.34, .20, .62), "cocoa", .08)
    cylinder("LampArm", (0, -.18, .05), .065, .58, "gold", 18, rotation=(math.pi / 2, 0, 0), bevel=.02)
    sphere("LampShade", (0, -.50, -.02), (.48, .40, .58), "paper", 24, 14)
    cylinder("LampRim", (0, -.52, -.33), .46, .07, "gold", 24, bevel=.02)


def scenic_mountain() -> None:
    reset()
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=3.6, radius2=.45, depth=4.3, location=(0, 0, 2.15))
    finish(bpy.context.object, "Mountain", "blue", .18)
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=1.06, radius2=.36, depth=1.25, location=(0, 0, 3.90))
    finish(bpy.context.object, "SnowCap", "cream", .11)


def village_house() -> None:
    reset()
    box("House", (0, 0, .72), (1.8, 1.6, 1.44), "cream", .10)
    box("Door", (0, -.83, .52), (.46, .08, .90), "wood", .035)
    for x in (-.52, .52):
        box("Window", (x, -.84, .83), (.38, .06, .42), "blue", .035)
    box("Roof", (0, 0, 1.70), (2.16, 2.02, .42), "red", .10, rotation=(0, math.radians(9), 0))
    cylinder("Chimney", (.58, .30, 2.05), .15, .72, "cocoa", 16, bevel=.025)


def main() -> None:
    parsed = args()
    output = Path(parsed.output)
    (output.parent / "source").mkdir(parents=True, exist_ok=True)
    builders = {
        "bookshelf_single": lambda: bookshelf(True),
        "bookshelf_double": lambda: bookshelf(False),
        "study_table": study_table,
        "armchair_green": lambda: armchair("green"),
        "armchair_teal": lambda: armchair("teal"),
        "armchair_gold": lambda: armchair("gold"),
        "fireplace": fireplace,
        "globe": globe,
        "cafe_table": cafe_table,
        "train_bench": train_bench,
        "train_table": train_table,
        "japanese_low_table": low_table,
        "floor_cushion": cushion,
        "garden_path_tile": path_tile,
        "fountain_basin": fountain_basin,
        "water_surface": water_surface,
        "wall_lamp": wall_lamp,
        "scenic_mountain": scenic_mountain,
        "village_house": village_house,
        "grass_tuft": grass_tuft,
    }
    selected = builders.items() if not parsed.only else [(parsed.only, builders[parsed.only])]
    for name, builder in selected:
        builder()
        export(output, name)


if __name__ == "__main__":
    main()
