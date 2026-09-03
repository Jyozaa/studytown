"""Generate StudyTown's stylized Garden Café assets in Blender.

The kit keeps StudyTown's warm, rounded low-poly language while adding a more
lush Animal-Crossing-inspired garden atmosphere: a substantial café back wall
and service shelving, a larger sculpted tree, rectangular patterned study
rugs, a tiered fountain, tiled pool surround, continuous flagstone paving,
a dirt stepping-stone path for the campfire, and denser planting assets.

Runtime GLBs and editable .blend sources are written beneath the owner-local
generated asset directory. No proprietary source content is embedded here.
"""

from __future__ import annotations

import argparse
import math
import random
import sys
from pathlib import Path

import bpy


PALETTE = {
    "cream": "F7E8C5",
    "paper": "FFF7E5",
    "cocoa": "4B2E24",
    "wood": "825033",
    "wood_light": "B27748",
    "honey": "D8A55A",
    "green": "4F9362",
    "leaf": "2E6F42",
    "leaf_dark": "235635",
    "leaf_light": "4A9B58",
    "teal": "4F9B91",
    "blue": "5BA7B3",
    "pool_blue": "69C9C5",
    "gold": "EDB84C",
    "coral": "C96D58",
    "red": "A84E42",
    "purple": "81658D",
    "ink": "241C19",
    "stone": "A99E8E",
    "stone_mid": "BDB4A5",
    "stone_light": "DED6C8",
    "tile": "EFE2C6",
    "tile_accent": "6E9B86",
    "soil": "5B4030",
    "soil_light": "765742",
    "bark": "4A2918",
    "bark_light": "C99458",
    "flower_white": "F8F4DF",
    "flower_yellow": "E7B844",
    "grass_base": "4CB94F",
    "grass_light": "66C95E",
    "grass_dark": "3D9F47",
    "leaf_bright": "59B956",
    "bark_gold": "C98245",
    "coffee": "5A3528",
    "mug_cream": "F6E8C9",
    "mug_blue": "6FA8B0",
    "mug_red": "C76A59",
}


SOURCE_TEXTURE_DIR = Path.home() / "Downloads"


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--only", default="")
    parser.add_argument(
        "--source-textures",
        default=str(Path.home() / "Downloads"),
        help="Folder containing grass.jpeg, carpet.png and tile.png.",
    )
    return parser.parse_args(argv)


def rgba(hex_value: str) -> tuple[float, float, float, float]:
    return tuple(int(hex_value[i : i + 2], 16) / 255.0 for i in (0, 2, 4)) + (1.0,)


def reset() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        for block in list(datablocks):
            datablocks.remove(block)


def material(name: str):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    mat = bpy.data.materials.new(name)
    base = rgba(PALETTE[name])
    mat.diffuse_color = base
    mat.roughness = 0.76 if name not in {"gold", "pool_blue"} else 0.56
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    if principled:
        principled.inputs["Base Color"].default_value = base
        principled.inputs["Roughness"].default_value = mat.roughness
    return mat


def resolve_external_texture(*names: str) -> Path | None:
    """Find a user-local Garden texture without hard-coding one machine."""
    search_roots = [
        SOURCE_TEXTURE_DIR,
        Path.home() / "Downloads",
        Path.cwd() / "assets/dev_local/environment",
    ]
    for root in search_roots:
        for name in names:
            candidate = root / name
            if candidate.exists():
                return candidate.resolve()
    return None


def image_material(
    name: str,
    image_path: Path,
    *,
    roughness: float = 0.82,
) -> bpy.types.Material:
    existing = bpy.data.materials.get(name)
    if existing:
        return existing

    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.roughness = roughness

    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (420, 0)

    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.location = (160, 0)
    principled.inputs["Roughness"].default_value = roughness

    tex = nodes.new("ShaderNodeTexImage")
    tex.location = (-220, 0)
    tex.image = bpy.data.images.load(str(image_path), check_existing=True)
    tex.extension = "REPEAT"

    links.new(tex.outputs["Color"], principled.inputs["Base Color"])
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    return mat


def textured_quad(
    name: str,
    dimensions: tuple[float, float],
    z: float,
    mat: bpy.types.Material,
    *,
    uv_scale: tuple[float, float] = (1.0, 1.0),
) -> bpy.types.Object:
    width, depth = dimensions
    vertices = [
        (-width / 2.0, -depth / 2.0, z),
        ( width / 2.0, -depth / 2.0, z),
        ( width / 2.0,  depth / 2.0, z),
        (-width / 2.0,  depth / 2.0, z),
    ]
    faces = [(0, 1, 2, 3)]

    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    u, v = uv_scale
    uv_by_vertex = [
        (0.0, 0.0),
        (u, 0.0),
        (u, v),
        (0.0, v),
    ]
    for loop in mesh.loops:
        uv_layer.data[loop.index].uv = uv_by_vertex[loop.vertex_index]

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def finish(obj, name: str, mat_name: str, bevel: float = 0.05):
    obj.name = name
    obj.data.name = name + "Mesh"
    obj.data.materials.append(material(mat_name))
    if bevel > 0:
        mod = obj.modifiers.new("Soft bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    return obj


def box(name: str, location, dimensions, mat_name: str, bevel: float = 0.05, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat_name, min(bevel, min(dimensions) * 0.22))


def cylinder(name: str, location, radius: float, depth: float, mat_name: str, vertices: int = 24, rotation=(0, 0, 0), bevel: float = 0.04):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    return finish(bpy.context.object, name, mat_name, bevel)


def sphere(name: str, location, scale, mat_name: str, segments: int = 24, rings: int = 14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(obj, name, mat_name, 0)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def ico(name: str, location, scale, mat_name: str, subdivision: int = 2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivision, radius=1.0, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat_name, 0.035)


def polygon_prism(name: str, points: list[tuple[float, float]], height: float, mat_name: str, location=(0.0, 0.0, 0.0), rotation: float = 0.0):
    count = len(points)
    vertices = [(x, y, 0.0) for x, y in points] + [(x, y, height) for x, y in points]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler.z = rotation
    return finish(obj, name, mat_name, min(height * 0.32, 0.045))


def irregular_disc(name: str, radii: list[float], height: float, mat_name: str, scale=(1.0, 1.0), location=(0.0, 0.0, 0.0)):
    points = []
    for index, radius in enumerate(radii):
        angle = index * math.tau / len(radii)
        points.append((math.cos(angle) * radius * scale[0], math.sin(angle) * radius * scale[1]))
    return polygon_prism(name, points, height, mat_name, location)


def torus(name: str, location, major_radius: float, minor_radius: float, mat_name: str, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=24,
        minor_segments=10,
        location=location,
        rotation=rotation,
    )
    return finish(bpy.context.object, name, mat_name, 0.015)


def leaf_card(
    name: str,
    location,
    scale,
    mat_name: str,
    rotation=(0.0, 0.0, 0.0),
    thickness: float = 0.035,
):
    """Broad pointed game-leaf used by the tree, hedges and shrubs."""
    points = [
        (-0.58, -0.24),
        (-0.42, 0.18),
        (-0.20, 0.46),
        (0.0, 0.68),
        (0.20, 0.46),
        (0.42, 0.18),
        (0.58, -0.24),
        (0.25, -0.44),
        (0.0, -0.54),
        (-0.25, -0.44),
    ]
    obj = polygon_prism(name, points, thickness, mat_name, location)
    obj.scale = scale
    obj.rotation_euler = rotation
    return obj


def stylized_mug(
    name: str,
    location,
    mat_name: str,
    scale: float = 1.0,
    rotation_z: float = 0.0,
    with_coffee: bool = False,
):
    """Rounded low-poly café mug with a real handle and lip."""
    x, y, z = location
    body = cylinder(
        name + "Body",
        (x, y, z + 0.16 * scale),
        0.16 * scale,
        0.32 * scale,
        mat_name,
        24,
        bevel=0.035 * scale,
    )
    body.rotation_euler.z = rotation_z
    torus(
        name + "Rim",
        (x, y, z + 0.325 * scale),
        0.145 * scale,
        0.018 * scale,
        "mug_cream",
        rotation=(0, 0, rotation_z),
    )
    # Torus handle is oriented vertically in X/Z and offset to the side.
    handle_offset = (
        math.cos(rotation_z) * 0.19 * scale,
        math.sin(rotation_z) * 0.19 * scale,
    )
    torus(
        name + "Handle",
        (x + handle_offset[0], y + handle_offset[1], z + 0.19 * scale),
        0.095 * scale,
        0.024 * scale,
        mat_name,
        rotation=(math.pi / 2, 0, rotation_z),
    )
    if with_coffee:
        cylinder(
            name + "Coffee",
            (x, y, z + 0.326 * scale),
            0.125 * scale,
            0.010 * scale,
            "coffee",
            24,
            bevel=0.004,
        )


def write_garden_grass_texture(output_dir: Path, size: int = 1024) -> None:
    """Build one randomized lawn atlas from many small rotated grass copies.

    The user's source image has large visible colour patches. Mapping it once
    made those patches enormous in-world. This atlas divides the lawn into an
    8x8 mosaic, with each cell using a different crop and a random 0/90/180/270
    degree orientation. main.gd then repeats this atlas twice over the Garden,
    so the source-scale "spots" become much smaller.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    source_path = resolve_external_texture(
        "grass.jpeg",
        "garden_grass.jpeg",
        "garden_grass_source.jpeg",
    )

    if source_path is None:
        # Retain a safe generated fallback.
        rng = random.Random(1207)
        base = rgba(PALETTE["grass_base"])
        pixels = [0.0] * (size * size * 4)
        for py in range(size):
            for px in range(size):
                noise = (rng.random() - 0.5) * 0.025
                idx = (py * size + px) * 4
                pixels[idx + 0] = min(max(base[0] + noise, 0.0), 1.0)
                pixels[idx + 1] = min(max(base[1] + noise, 0.0), 1.0)
                pixels[idx + 2] = min(max(base[2] + noise, 0.0), 1.0)
                pixels[idx + 3] = 1.0
    else:
        source = bpy.data.images.load(str(source_path), check_existing=True)
        sw, sh = int(source.size[0]), int(source.size[1])
        src = source.pixels[:]

        grid = 8
        cell = size // grid
        crop = min(sw, sh)
        max_crop_x = max(0, sw - crop)
        max_crop_y = max(0, sh - crop)

        rng = random.Random(5831)
        tile_settings = []
        for _ in range(grid * grid):
            tile_settings.append((
                rng.randrange(4),
                rng.randrange(max_crop_x + 1) if max_crop_x else 0,
                rng.randrange(max_crop_y + 1) if max_crop_y else 0,
            ))

        pixels = [0.0] * (size * size * 4)

        for py in range(size):
            cell_y = min(grid - 1, py // cell)
            local_y = (py % cell) / float(max(1, cell - 1))

            for px in range(size):
                cell_x = min(grid - 1, px // cell)
                local_x = (px % cell) / float(max(1, cell - 1))

                rotation, crop_x, crop_y = tile_settings[cell_y * grid + cell_x]

                if rotation == 0:
                    u, v = local_x, local_y
                elif rotation == 1:
                    u, v = local_y, 1.0 - local_x
                elif rotation == 2:
                    u, v = 1.0 - local_x, 1.0 - local_y
                else:
                    u, v = 1.0 - local_y, local_x

                sx = crop_x + min(crop - 1, int(u * (crop - 1)))
                sy = crop_y + min(crop - 1, int(v * (crop - 1)))

                source_index = (sy * sw + sx) * 4
                target_index = (py * size + px) * 4

                # Tiny deterministic brightness variance between cells makes
                # repeating the finished atlas harder to notice.
                tone = 0.965 + ((cell_x * 13 + cell_y * 7) % 7) * 0.009
                pixels[target_index + 0] = min(1.0, src[source_index + 0] * tone)
                pixels[target_index + 1] = min(1.0, src[source_index + 1] * tone)
                pixels[target_index + 2] = min(1.0, src[source_index + 2] * tone)
                pixels[target_index + 3] = 1.0

    image = bpy.data.images.get("StudyTownGardenGrassTile")
    if image:
        bpy.data.images.remove(image)
    image = bpy.data.images.new(
        "StudyTownGardenGrassTile",
        width=size,
        height=size,
        alpha=True,
    )
    image.pixels = pixels

    path = output_dir / "garden_grass_tile.png"
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    print(f"STUDYTOWN_GARDEN_TEXTURE {path.name}")


def cafe_counter() -> None:
    reset()
    box("CounterBody", (0, 0, 0.58), (7.4, 1.55, 1.16), "cocoa", 0.13)
    box("CounterInset", (0, -0.79, 0.60), (6.65, 0.06, 0.70), "wood", 0.025)
    box("CounterTop", (0, 0, 1.24), (7.75, 1.82, 0.20), "honey", 0.09)
    for x in (-2.45, 0.0, 2.45):
        box("CounterPanelRail", (x, -0.83, 0.60), (0.10, 0.08, 0.73), "wood_light", 0.02)
    # Small rear preparation ledge on the barista side.
    box("PrepLedge", (0, 0.67, 0.92), (6.35, 0.34, 0.12), "wood_light", 0.04)



def cafe_back_wall() -> None:
    reset()

    # One rear wall, floor-to-top. The bookcases form the LEFT wall in main.gd
    # and meet this wall edge-to-edge, creating a clean open-front L shape.
    box("CafeRearWall", (0, 0.12, 2.25), (12.4, 0.30, 4.50), "cream", 0.08)
    box("CafeRearKick", (0, -0.08, 0.26), (12.4, 0.18, 0.52), "cocoa", 0.04)
    box("CafeTopTrim", (0, -0.08, 4.32), (12.4, 0.20, 0.24), "honey", 0.05)

    # Shallow café display shelves behind the counter. They have no large
    # backing panels, so they read as shelves attached to the wall rather than
    # extra walls stacked in front of it.
    for row, z in enumerate((1.22, 2.16, 3.10)):
        box(
            f"CafeDisplayShelf{row}",
            (0.70, -0.20, z),
            (8.55, 0.40, 0.14),
            "wood_light",
            0.035,
        )

    # A few generated mugs make the wall usable even when archive props are
    # unavailable. Runtime archive coffee props layer onto these shelves.
    for index, (x, z, mat_name) in enumerate([
        (-2.70, 1.43, "mug_cream"),
        (-1.85, 1.43, "mug_blue"),
        (-0.95, 1.43, "mug_red"),
        (0.10, 2.37, "mug_blue"),
        (1.05, 2.37, "mug_cream"),
        (2.00, 3.31, "mug_red"),
        (2.95, 3.31, "mug_blue"),
    ]):
        stylized_mug(
            f"CafeWallMug{index}",
            (x + 0.70, -0.34, z),
            mat_name,
            scale=0.72,
            rotation_z=0.0,
            with_coffee=False,
        )


def cafe_rug() -> None:
    reset()

    # The café floor now extends beneath the entire L-shaped rear/left wall.
    # This removes the exposed grass strip that used to sit behind the counter.
    box("RugBase", (0, -0.22, 0.035), (14.4, 9.15, 0.07), "cream", 0.10)
    box("RugInset", (0, -0.20, 0.073), (13.72, 8.47, 0.026), "soil_light", 0.06)

    for x in (-5.0, -2.5, 0.0, 2.5, 5.0):
        box("RugBand", (x, -0.18, 0.094), (0.12, 7.78, 0.012), "honey", 0.01)
    for y in (-3.35, -0.55, 2.25):
        box("RugBand", (0, y, 0.095), (12.8, 0.11, 0.012), "coral", 0.01)


def cafe_table() -> None:
    reset()
    cylinder("CafeTop", (0, 0, 1.00), 1.05, 0.18, "wood_light", 36, bevel=0.07)
    cylinder("Pedestal", (0, 0, 0.50), 0.15, 0.92, "cocoa", 22, bevel=0.025)
    cylinder("Foot", (0, 0, 0.07), 0.52, 0.14, "cocoa", 30, bevel=0.035)



def big_tree() -> None:
    reset()
    rng = random.Random(4107)

    # Animal-Crossing-inspired mature oak silhouette:
    # one warm tapered trunk with chunky root flares and a three-lobed canopy.
    bpy.ops.mesh.primitive_cone_add(
        vertices=32,
        radius1=1.10,
        radius2=0.72,
        depth=5.80,
        location=(0, 0, 2.90),
    )
    finish(bpy.context.object, "OakTrunk", "bark_gold", 0.11)

    # Root flares are broad and rounded, visibly merging into the trunk.
    for index in range(7):
        angle = index * math.tau / 7.0 + 0.18
        radius = 0.72
        root = ico(
            "RootFlare",
            (math.cos(angle) * radius, math.sin(angle) * radius, 0.40),
            (0.82, 0.48, 0.40),
            "bark_gold" if index % 2 == 0 else "bark_light",
            2,
        )
        root.rotation_euler.z = angle
        root.rotation_euler.y = math.radians(-12)

    # Subtle bark patches/knot forms, still soft and toy-like.
    for index in range(9):
        angle = index * 2.18
        z = 0.95 + (index % 6) * 0.66
        radius = 0.88 - z * 0.035
        patch = sphere(
            "BarkPatch",
            (math.cos(angle) * radius, math.sin(angle) * radius, z),
            (0.16, 0.08, 0.34),
            "bark_light" if index % 3 else "wood_light",
            14,
            8,
        )
        patch.rotation_euler.z = angle

    # Branches support the three major canopy lobes but stay mostly hidden.
    branch_specs = [
        ((-1.15, 0.10, 5.25), 2.15, math.radians(58), math.radians(90)),
        ((1.15, -0.05, 5.25), 2.15, math.radians(-58), math.radians(90)),
        ((0.0, 0.20, 5.55), 1.90, 0.0, 0.0),
    ]
    for idx, (location, depth, rz, rx) in enumerate(branch_specs):
        branch = cylinder("MainBranch", location, 0.28, depth, "bark_gold", 18, rotation=(rx, 0, rz), bevel=0.05)

    # Dark cores stop gaps between individual leaves from appearing hollow.
    canopy_cores = [
        ((0.0, 0.0, 7.45), (2.55, 2.20, 2.25)),
        ((-2.15, 0.10, 6.55), (2.65, 2.20, 2.10)),
        ((2.15, 0.10, 6.55), (2.65, 2.20, 2.10)),
        ((0.0, -0.65, 6.30), (2.55, 1.85, 1.80)),
    ]
    for idx, (loc, scale) in enumerate(canopy_cores):
        sphere("CanopyCore", loc, scale, "leaf_dark" if idx == 3 else "leaf", 28, 18)

    # Layered broad leaves form the recognizable scalloped canopy surface.
    lobes = [
        (0.0, 0.0, 7.55, 2.55, 2.15, 2.15, 33),
        (-2.15, 0.0, 6.55, 2.55, 2.15, 1.95, 31),
        (2.15, 0.0, 6.55, 2.55, 2.15, 1.95, 31),
        (0.0, -0.85, 6.25, 2.35, 1.55, 1.60, 25),
    ]
    for lobe_index, (cx, cy, cz, rx, ry, rz, count) in enumerate(lobes):
        for i in range(count):
            theta = rng.random() * math.tau
            # Bias leaves toward the visible outer hemisphere.
            elevation = rng.uniform(-0.55, 0.85)
            horiz = math.sqrt(max(0.0, 1.0 - elevation * elevation))
            px = cx + math.cos(theta) * horiz * rx
            py = cy + math.sin(theta) * horiz * ry
            pz = cz + elevation * rz
            leaf_scale = rng.uniform(0.62, 0.88)
            mat_name = ("leaf_bright", "leaf_light", "leaf", "leaf_dark")[(i + lobe_index) % 4]
            leaf = leaf_card(
                "OakLeaf",
                (px, py, pz),
                (leaf_scale, leaf_scale * 0.82, 1.0),
                mat_name,
                rotation=(
                    rng.uniform(-0.18, 0.18),
                    rng.uniform(-0.16, 0.16),
                    theta + math.pi / 2.0 + rng.uniform(-0.22, 0.22),
                ),
                thickness=0.045,
            )


def tree_rug() -> None:
    reset()
    carpet_path = resolve_external_texture("carpet.png")

    # A thin rounded backing gives the textured rug a believable edge.
    box("TreeRugBacking", (0, 0, 0.032), (4.45, 2.85, 0.064), "cocoa", 0.08)

    if carpet_path is not None:
        carpet_mat = image_material(
            "TreeRugCarpetTexture",
            carpet_path,
            roughness=0.92,
        )
        textured_quad(
            "TreeRugTexturedTop",
            (4.34, 2.74),
            0.067,
            carpet_mat,
            uv_scale=(2.15, 1.40),
        )
    else:
        box("TreeRugFallback", (0, 0, 0.068), (4.34, 2.74, 0.018), "soil_light", 0.04)


def fountain() -> None:
    reset()
    # Wide circular tiered fountain inspired by classic garden fountains while
    # remaining an original StudyTown model.
    cylinder("FountainPlinth", (0, 0, 0.10), 3.65, 0.20, "stone_mid", 48, bevel=0.10)
    cylinder("OuterBasin", (0, 0, 0.30), 3.45, 0.42, "stone", 48, bevel=0.12)
    cylinder("InnerWaterBed", (0, 0, 0.51), 2.96, 0.08, "pool_blue", 48, bevel=0.035)
    cylinder("CentrePedestal", (0, 0, 1.05), 0.48, 1.20, "stone_mid", 30, bevel=0.08)
    cylinder("LowerBowl", (0, 0, 1.52), 1.42, 0.20, "stone", 42, bevel=0.09)
    cylinder("UpperStem", (0, 0, 2.05), 0.28, 0.90, "stone_mid", 28, bevel=0.06)
    cylinder("UpperBowl", (0, 0, 2.42), 0.92, 0.17, "stone", 38, bevel=0.08)
    sphere("Finial", (0, 0, 2.77), (0.25, 0.25, 0.38), "honey", 20, 12)


def pool() -> None:
    reset()
    # Pale decorative tile border like a small landscaped courtyard pool.
    length = 10.4
    width = 6.6
    water_length = 8.7
    water_width = 4.9
    rail_x = (length - water_length) / 2.0
    rail_y = (width - water_width) / 2.0
    box("PoolNorthTile", (0, width / 2 - rail_y / 2, 0.09), (length, rail_y, 0.18), "tile", 0.06)
    box("PoolSouthTile", (0, -width / 2 + rail_y / 2, 0.09), (length, rail_y, 0.18), "tile", 0.06)
    box("PoolWestTile", (-length / 2 + rail_x / 2, 0, 0.09), (rail_x, water_width, 0.18), "tile", 0.06)
    box("PoolEastTile", (length / 2 - rail_x / 2, 0, 0.09), (rail_x, water_width, 0.18), "tile", 0.06)

    # Green decorative corner motifs and small dots around the coping.
    for x in (-4.75, 4.75):
        for y in (-2.85, 2.85):
            box("CornerAccent", (x, y, 0.19), (0.62, 0.62, 0.025), "tile_accent", 0.04, rotation=(0, 0, math.radians(45)))
    for x in (-3.4, -1.7, 0.0, 1.7, 3.4):
        for y in (-2.92, 2.92):
            cylinder("TileDot", (x, y, 0.20), 0.075, 0.025, "tile_accent", 16, bevel=0.008)

    # Slight inner lip around the water edge.
    box("PoolNorthLip", (0, water_width / 2 + 0.10, 0.20), (water_length + 0.25, 0.20, 0.18), "stone_light", 0.04)
    box("PoolSouthLip", (0, -water_width / 2 - 0.10, 0.20), (water_length + 0.25, 0.20, 0.18), "stone_light", 0.04)
    box("PoolWestLip", (-water_length / 2 - 0.10, 0, 0.20), (0.20, water_width, 0.18), "stone_light", 0.04)
    box("PoolEastLip", (water_length / 2 + 0.10, 0, 0.20), (0.20, water_width, 0.18), "stone_light", 0.04)


def tanning_bed() -> None:
    reset()
    box("LoungerFrame", (0, 0, 0.30), (2.45, 0.92, 0.14), "wood_light", 0.06)
    box("LoungerCushion", (0.42, 0, 0.44), (1.58, 0.84, 0.18), "teal", 0.08)
    box("LoungerBack", (-0.74, 0, 0.72), (0.92, 0.84, 0.18), "teal", 0.08, rotation=(0, math.radians(-28), 0))
    for x in (-0.92, 0.92):
        for y in (-0.33, 0.33):
            cylinder("LoungerFoot", (x, y, 0.13), 0.055, 0.26, "cocoa", 14, bevel=0.015)


def campfire() -> None:
    reset()
    for index in range(10):
        angle = index * math.tau / 10.0
        ico("FireRingStone", (math.cos(angle) * 1.06, math.sin(angle) * 1.06, 0.22), (0.38, 0.32, 0.26), "stone", 1)
    cylinder("LogA", (0, 0, 0.34), 0.16, 1.72, "bark", 16, rotation=(0, math.pi / 2, math.radians(35)), bevel=0.025)
    cylinder("LogB", (0, 0, 0.34), 0.16, 1.72, "bark", 16, rotation=(0, math.pi / 2, math.radians(-35)), bevel=0.025)
    cylinder("CoalBed", (0, 0, 0.16), 0.76, 0.10, "ink", 24, bevel=0.02)


def log_seat() -> None:
    reset()

    # One chunky cut log, matching the supplied reference: rough bark around a
    # slightly irregular cylindrical trunk with clearly exposed pale end grain.
    length = 2.35
    radial = 20
    axial_rings = 7

    rng = random.Random(9217)
    ring_radii = []
    for ring in range(axial_rings):
        t = ring / float(axial_rings - 1)
        ring_radii.append(
            0.34
            + math.sin(t * math.pi * 2.0) * 0.018
            + (rng.random() - 0.5) * 0.018
        )

    vertices = []
    for ring in range(axial_rings):
        x = -length / 2.0 + length * ring / float(axial_rings - 1)
        radius = ring_radii[ring]
        for segment in range(radial):
            angle = segment * math.tau / radial
            # Uneven bark silhouette.
            local_radius = radius * (
                1.0
                + math.sin(angle * 3.0 + ring * 0.55) * 0.030
                + math.sin(angle * 7.0) * 0.012
            )
            y = math.cos(angle) * local_radius
            z = math.sin(angle) * local_radius + 0.39
            vertices.append((x, y, z))

    faces = []
    for ring in range(axial_rings - 1):
        for segment in range(radial):
            nxt = (segment + 1) % radial
            a = ring * radial + segment
            b = ring * radial + nxt
            c = (ring + 1) * radial + nxt
            d = (ring + 1) * radial + segment
            faces.append((a, b, c, d))

    mesh = bpy.data.meshes.new("SeatLogBarkMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    bark_obj = bpy.data.objects.new("SeatLogBark", mesh)
    bpy.context.collection.objects.link(bark_obj)
    bark_obj.data.materials.append(material("bark"))

    # Pale cut ends.
    for side in (-1.0, 1.0):
        x = side * (length / 2.0 + 0.018)
        cylinder(
            "SeatLogCutEnd",
            (x, 0, 0.39),
            0.285,
            0.040,
            "bark_light",
            28,
            rotation=(0, math.pi / 2, 0),
            bevel=0.010,
        )

        # Concentric growth rings visible on both ends.
        for ring_index, radius in enumerate((0.22, 0.145, 0.075)):
            torus(
                f"SeatLogGrowthRing{ring_index}",
                (x + side * 0.024, 0, 0.39),
                radius,
                0.010,
                "wood",
                rotation=(0, math.pi / 2, 0),
            )

    # A few darker bark ridges keep the side from reading as a smooth tube.
    for index in range(5):
        angle = -0.65 + index * 0.34
        ridge = cylinder(
            "SeatLogBarkRidge",
            (0, math.cos(angle) * 0.337, 0.39 + math.sin(angle) * 0.337),
            0.026,
            length * 0.94,
            "ink",
            10,
            rotation=(0, math.pi / 2, 0),
            bevel=0.006,
        )


def path_stone(variant: str) -> None:
    reset()
    shapes = {
        "a": [(-0.82, -0.35), (-0.45, -0.74), (0.28, -0.70), (0.78, -0.28), (0.70, 0.38), (0.16, 0.68), (-0.54, 0.58)],
        "b": [(-0.72, -0.46), (-0.10, -0.77), (0.56, -0.60), (0.82, -0.08), (0.54, 0.56), (-0.06, 0.72), (-0.70, 0.38)],
        "c": [(-0.84, -0.18), (-0.44, -0.69), (0.25, -0.75), (0.76, -0.44), (0.82, 0.18), (0.38, 0.63), (-0.30, 0.70), (-0.75, 0.42)],
    }
    polygon_prism("GardenPathStone", shapes[variant], 0.11, "stone_mid")


def flagstone_path_tile() -> None:
    reset()
    tile_path = resolve_external_texture("tile.png")

    # A low stone slab with the supplied herringbone stone image on top.
    # main.gd butts these tiles edge-to-edge instead of overlapping them, which
    # avoids the z-fighting seen in earlier path versions.
    box("StonePathBase", (0, 0, 0.032), (2.50, 2.50, 0.064), "stone_mid", 0.055)

    if tile_path is not None:
        tile_mat = image_material(
            "GardenStonePathTexture",
            tile_path,
            roughness=0.92,
        )
        textured_quad(
            "StonePathTexturedTop",
            (2.44, 2.44),
            0.066,
            tile_mat,
            uv_scale=(1.18, 1.18),
        )
    else:
        box("StonePathFallback", (0, 0, 0.068), (2.44, 2.44, 0.018), "stone_light", 0.035)


def dirt_path_tile() -> None:
    reset()
    radii = [1.00, .94, 1.06, .92, 1.03, .95, 1.04, .90, 1.02, .96, 1.05, .93]
    irregular_disc("DirtPath", radii, 0.045, "soil", scale=(1.25, 1.45))
    # A few darker embedded patches stop the strip from reading as a flat carpet.
    for index, (x, y, sx, sy) in enumerate([
        (-.48, -.52, .34, .22), (.42, -.12, .30, .20), (-.10, .56, .28, .18)
    ]):
        ico("DirtDetail", (x, y, 0.052), (sx, sy, 0.018), "soil_light", 1)


def rock(variant: str) -> None:
    reset()
    scales = {
        "a": (1.05, 0.82, 0.70),
        "b": (0.88, 1.10, 0.82),
        "c": (1.18, 0.78, 0.88),
    }[variant]
    obj = ico("GardenRock", (0, 0, scales[2] * 0.58), scales, "stone", 2)
    obj.rotation_euler.z = {"a": 0.12, "b": -0.18, "c": 0.27}[variant]



def shrub() -> None:
    reset()
    rng = random.Random(3201)
    # Rounded bush with overlapping, individually readable leaf plates.
    sphere("ShrubCore", (0, 0, 0.58), (0.96, 0.86, 0.72), "leaf_dark", 24, 14)
    for index in range(34):
        theta = rng.random() * math.tau
        elevation = rng.uniform(-0.30, 0.82)
        horiz = math.sqrt(max(0.0, 1.0 - elevation * elevation))
        px = math.cos(theta) * horiz * 0.92
        py = math.sin(theta) * horiz * 0.82
        pz = 0.58 + elevation * 0.70
        scale = rng.uniform(0.27, 0.39)
        leaf_card(
            "ShrubLeaf",
            (px, py, pz),
            (scale, scale * 0.82, 1.0),
            "leaf_bright" if index % 4 == 0 else ("leaf_light" if index % 3 else "leaf"),
            rotation=(rng.uniform(-0.15, 0.15), rng.uniform(-0.12, 0.12), theta + math.pi / 2),
            thickness=0.025,
        )



def hedge() -> None:
    reset()
    rng = random.Random(517)

    # Hidden structural core. Keep it comfortably inside the foliage so the
    # rectangular support can never protrude from the hedge silhouette.
    box(
        "HedgeCore",
        (0, 0, 0.53),
        (2.58, 0.66, 0.78),
        "leaf_dark",
        0.18,
    )

    # ------------------------------------------------------------------
    # TOP
    # ------------------------------------------------------------------
    for row, y in enumerate((-0.30, 0.30)):
        for col in range(10):
            x = -1.34 + col * 0.298
            scale = 0.32 + (col % 3) * 0.018

            leaf_card(
                "HedgeLeaf",
                (
                    x,
                    y,
                    0.92 + rng.uniform(-0.035, 0.035),
                ),
                (
                    scale,
                    scale * 0.82,
                    1.0,
                ),
                (
                    "leaf_bright"
                    if (row + col) % 3 == 0
                    else "leaf_light"
                ),
                rotation=(
                    rng.uniform(-0.09, 0.09),
                    rng.uniform(-0.09, 0.09),
                    rng.uniform(-0.18, 0.18),
                ),
                thickness=0.024,
            )

    # ------------------------------------------------------------------
    # FRONT + BACK
    # ------------------------------------------------------------------
    for side_index, y in enumerate((-0.47, 0.47)):
        tilt = math.radians(
            78 if side_index == 0 else -78
        )

        for row in range(3):
            z = 0.28 + row * 0.29

            for col in range(10):
                x = -1.34 + col * 0.298

                leaf_card(
                    "HedgeLeaf",
                    (
                        x,
                        y,
                        z + rng.uniform(-0.025, 0.025),
                    ),
                    (
                        0.31,
                        0.245,
                        1.0,
                    ),
                    (
                        "leaf_light"
                        if (row + col + side_index) % 2
                        else "leaf_bright"
                    ),
                    rotation=(
                        tilt,
                        0,
                        rng.uniform(-0.16, 0.16),
                    ),
                    thickness=0.024,
                )

    # ------------------------------------------------------------------
    # END CAPS
    # Covers the rectangular left/right ends that were visible previously.
    # ------------------------------------------------------------------
    for side_index, x in enumerate((-1.39, 1.39)):
        tilt = math.radians(
            -78 if side_index == 0 else 78
        )

        for row in range(3):
            z = 0.30 + row * 0.29

            for col, y in enumerate((-0.26, 0.22)):
                leaf_card(
                    "HedgeLeaf",
                    (
                        x,
                        y,
                        z + rng.uniform(-0.025, 0.025),
                    ),
                    (
                        0.30,
                        0.24,
                        1.0,
                    ),
                    (
                        "leaf_bright"
                        if (row + col + side_index) % 2 == 0
                        else "leaf_light"
                    ),
                    rotation=(
                        0,
                        tilt,
                        rng.uniform(-0.14, 0.14),
                    ),
                    thickness=0.024,
                )

    # A few lower leaves hide any remaining glimpse of the core close to the
    # ground while retaining the clipped-hedge silhouette.
    for side_index, y in enumerate((-0.43, 0.43)):
        for col in range(9):
            x = -1.28 + col * 0.32

            leaf_card(
                "HedgeLeaf",
                (
                    x,
                    y,
                    0.20 + rng.uniform(-0.02, 0.02),
                ),
                (
                    0.28,
                    0.22,
                    1.0,
                ),
                "leaf",
                rotation=(
                    math.radians(
                        80 if side_index == 0 else -80
                    ),
                    0,
                    rng.uniform(-0.15, 0.15),
                ),
                thickness=0.024,
            )


def weed_clump() -> None:
    reset()
    # Broad serrated rosette inspired by the supplied clump-of-weeds artwork.
    leaf_points = [
        (-0.10, 0.00),
        (-0.22, 0.18),
        (-0.13, 0.20),
        (-0.28, 0.42),
        (-0.13, 0.39),
        (0.0, 0.72),
        (0.13, 0.39),
        (0.28, 0.42),
        (0.13, 0.20),
        (0.22, 0.18),
        (0.10, 0.00),
    ]
    for index, angle in enumerate((-1.05, -0.50, 0.0, 0.52, 1.02)):
        obj = polygon_prism(
            "WeedLeaf",
            leaf_points,
            0.022,
            "leaf_bright" if index in {1, 3} else "leaf_light",
            location=(0, 0, 0.035),
        )
        obj.scale = (0.68 + (index % 2) * 0.08, 0.82, 1.0)
        obj.rotation_euler = (math.radians(62), 0, angle)
    # Small lower rosette.
    for index, angle in enumerate((0.0, 2.1, 4.2)):
        leaf_card(
            "WeedLowLeaf",
            (math.cos(angle) * 0.16, math.sin(angle) * 0.16, 0.07),
            (0.28, 0.20, 1.0),
            "leaf_light",
            rotation=(math.radians(82), 0, angle),
            thickness=0.016,
        )


def water_droplet() -> None:
    reset()
    # One reusable droplet mesh. Runtime fountain code instantiates this same
    # GLB repeatedly and animates each instance along a ballistic path.
    sphere("DropletBody", (0, 0, 0.06), (0.075, 0.075, 0.105), "pool_blue", 18, 10)
    bpy.ops.mesh.primitive_cone_add(
        vertices=16,
        radius1=0.060,
        radius2=0.0,
        depth=0.12,
        location=(0, 0, 0.165),
    )
    finish(bpy.context.object, "DropletTip", "pool_blue", 0.010)

def flower_patch() -> None:
    reset()
    leaf_positions = [(-.45, -.15), (-.18, .22), (.18, -.22), (.45, .18), (0, .02)]
    for index, (x, y) in enumerate(leaf_positions):
        sphere("FlowerLeaves", (x, y, .18), (.28, .22, .16), "leaf_light" if index % 2 else "leaf", 14, 8)
    bloom_positions = [(-.42, -.12, .42), (-.16, .22, .52), (.17, -.20, .46), (.42, .18, .56), (0, .02, .60)]
    for index, (x, y, z) in enumerate(bloom_positions):
        sphere("FlowerBloom", (x, y, z), (.15, .15, .12), "flower_white" if index % 2 == 0 else "flower_yellow", 14, 8)
        cylinder("FlowerStem", (x, y, z * .56), .025, z * .65, "leaf_dark", 10, bevel=.006)


def export(output_dir: Path, name: str) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    source_dir = output_dir.parent / "source"
    source_dir.mkdir(parents=True, exist_ok=True)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No meshes generated for {name}")
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    joined.data.name = name + "Mesh"
    bpy.ops.export_scene.gltf(
        filepath=str(output_dir / f"{name}.glb"),
        export_format="GLB",
        export_animations=False,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_apply=True,
    )
    bpy.ops.wm.save_as_mainfile(filepath=str(source_dir / f"{name}.blend"))
    print(f"STUDYTOWN_GARDEN_ASSET {name}.glb")


def main() -> None:
    global SOURCE_TEXTURE_DIR

    parsed = arguments()
    output = Path(parsed.output).resolve()
    SOURCE_TEXTURE_DIR = Path(parsed.source_textures).expanduser().resolve()
    write_garden_grass_texture(output)
    builders = {
        "garden_cafe_counter": cafe_counter,
        "garden_cafe_back_wall": cafe_back_wall,
        "garden_cafe_rug": cafe_rug,
        "garden_cafe_table": cafe_table,
        "garden_big_tree": big_tree,
        "garden_tree_rug": tree_rug,
        "garden_fountain": fountain,
        "garden_pool": pool,
        "garden_tanning_bed": tanning_bed,
        "garden_campfire": campfire,
        "garden_log_seat": log_seat,
        "garden_path_stone_a": lambda: path_stone("a"),
        "garden_path_stone_b": lambda: path_stone("b"),
        "garden_path_stone_c": lambda: path_stone("c"),
        "garden_flagstone_path_tile": flagstone_path_tile,
        "garden_dirt_path_tile": dirt_path_tile,
        "garden_rock_a": lambda: rock("a"),
        "garden_rock_b": lambda: rock("b"),
        "garden_rock_c": lambda: rock("c"),
        "garden_shrub": shrub,
        "garden_hedge": hedge,
        "garden_weed_clump": weed_clump,
        "garden_water_droplet": water_droplet,
        "garden_flower_patch": flower_patch,
    }
    if parsed.only:
        if parsed.only not in builders:
            raise KeyError(f"Unknown garden asset: {parsed.only}")
        selected = [(parsed.only, builders[parsed.only])]
    else:
        selected = list(builders.items())
    for name, builder in selected:
        builder()
        export(output, name)


if __name__ == "__main__":
    main()
