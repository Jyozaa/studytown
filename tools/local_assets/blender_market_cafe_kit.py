#!/usr/bin/env python3
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    # Kept for command compatibility with v20. v21 no longer needs donor
    # geometry from IdrMarket01, so --source is accepted but not required.
    parser.add_argument("--source", default="")
    parser.add_argument("--output", required=True)

    argv = (
        sys.argv[sys.argv.index("--") + 1:]
        if "--" in sys.argv
        else []
    )
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
    ):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float = 0.68,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True

    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness

    return mat


def bevel_object(
    obj: bpy.types.Object,
    width: float,
    segments: int = 3,
) -> None:
    modifier = obj.modifiers.new(
        name="StudyTownSoftEdges",
        type="BEVEL",
    )
    modifier.width = width
    modifier.segments = segments

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def cube(
    name: str,
    dimensions: tuple[float, float, float],
    location: tuple[float, float, float],
    mat: bpy.types.Material,
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions

    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(
        location=False,
        rotation=False,
        scale=True,
    )

    if bevel > 0.0:
        bevel_object(obj, bevel)

    obj.data.materials.append(mat)
    return obj


def cylinder(
    name: str,
    radius: float,
    depth: float,
    location: tuple[float, float, float],
    mat: bpy.types.Material,
    vertices: int = 24,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def add_front_panel(
    objects: list[bpy.types.Object],
    *,
    x: float,
    width: float,
    body_y: float,
    body_z: float,
    wood: bpy.types.Material,
    cream: bpy.types.Material,
    accent: bpy.types.Material,
) -> None:
    # Raised wooden frame.
    objects.append(
        cube(
            f"PanelFrame_{x:+.2f}",
            (width, 0.055, 0.58),
            (x, body_y - 0.391, body_z),
            wood,
            0.035,
        )
    )
    # Cream inset.
    objects.append(
        cube(
            f"PanelInset_{x:+.2f}",
            (width - 0.16, 0.025, 0.42),
            (x, body_y - 0.425, body_z),
            cream,
            0.025,
        )
    )
    # Small stylized tea/coffee emblem: cup body + steam block.
    objects.append(
        cube(
            f"PanelCup_{x:+.2f}",
            (0.22, 0.018, 0.13),
            (x, body_y - 0.443, body_z - 0.025),
            accent,
            0.020,
        )
    )
    objects.append(
        cube(
            f"PanelSteam_{x:+.2f}",
            (0.055, 0.018, 0.13),
            (x + 0.055, body_y - 0.444, body_z + 0.115),
            accent,
            0.018,
        )
    )


def build_market_stall(output_dir: Path) -> None:
    reset_scene()

    wood = material(
        "StallWarmWood",
        (0.67, 0.38, 0.18, 1.0),
        0.64,
    )
    light_wood = material(
        "StallLightWood",
        (0.90, 0.66, 0.36, 1.0),
        0.66,
    )
    cream = material(
        "StallCream",
        (0.97, 0.86, 0.64, 1.0),
        0.72,
    )
    coral = material(
        "StallCoral",
        (0.92, 0.47, 0.39, 1.0),
        0.70,
    )
    mint = material(
        "StallMint",
        (0.42, 0.69, 0.50, 1.0),
        0.70,
    )
    gold = material(
        "StallGold",
        (0.91, 0.67, 0.27, 1.0),
        0.68,
    )

    objects: list[bpy.types.Object] = []

    # ------------------------------------------------------------------
    # Overall dimensions:
    # width 4.9 m
    # depth 2.65 m
    # total height ~3.2 m
    #
    # Front of the stall is -Y in Blender.
    # ------------------------------------------------------------------

    # Floor/platform.
    objects.append(
        cube(
            "StallPlatform",
            (4.90, 2.65, 0.10),
            (0.0, 0.0, 0.05),
            light_wood,
            0.045,
        )
    )

    # Four thin posts, intentionally much lighter than the v20 enclosing
    # market-building walls.
    for x in (-2.20, 2.20):
        for y in (-1.04, 1.04):
            objects.append(
                cube(
                    f"StallPost_{x:+.2f}_{y:+.2f}",
                    (0.16, 0.16, 2.94),
                    (x, y, 1.51),
                    wood,
                    0.035,
                )
            )

    # Serving counter: shallow, low and clearly stall-scale.
    counter_y = -0.73
    objects.append(
        cube(
            "CounterBody",
            (4.38, 0.68, 0.90),
            (0.0, counter_y, 0.53),
            wood,
            0.075,
        )
    )
    objects.append(
        cube(
            "CounterFrontFace",
            (4.18, 0.06, 0.72),
            (0.0, counter_y - 0.365, 0.54),
            light_wood,
            0.035,
        )
    )
    objects.append(
        cube(
            "CounterTop",
            (4.64, 0.92, 0.13),
            (0.0, counter_y, 1.04),
            cream,
            0.065,
        )
    )

    # Three decorative panels like the reference stall.
    for x in (-1.38, 0.0, 1.38):
        add_front_panel(
            objects,
            x=x,
            width=1.08,
            body_y=counter_y,
            body_z=0.54,
            wood=wood,
            cream=cream,
            accent=coral,
        )

    # Rear work shelf only, rather than a giant full market interior.
    objects.append(
        cube(
            "RearShelfLower",
            (3.80, 0.42, 0.10),
            (0.0, 0.93, 1.20),
            light_wood,
            0.035,
        )
    )
    objects.append(
        cube(
            "RearShelfUpper",
            (3.80, 0.42, 0.10),
            (0.0, 0.93, 1.76),
            light_wood,
            0.035,
        )
    )

    # Small cups/tins on shelves to stop the stall looking empty.
    shelf_colors = [cream, mint, coral, gold]
    for row_z in (1.31, 1.87):
        for index, x in enumerate((-1.35, -0.45, 0.45, 1.35)):
            objects.append(
                cylinder(
                    f"ShelfCup_{row_z}_{index}",
                    0.105,
                    0.22,
                    (x, 0.87, row_z),
                    shelf_colors[index % len(shelf_colors)],
                    20,
                )
            )

    # Canopy base. Solid cream prevents any transparency/glitching.
    objects.append(
        cube(
            "CanopyBase",
            (5.16, 2.88, 0.16),
            (0.0, 0.0, 3.02),
            cream,
            0.065,
        )
    )

    # Geometric stripes rather than stretching an archive image over a box.
    # These sit very slightly above the canopy surface, with enough separation
    # to avoid z-fighting.
    stripe_mats = [coral, mint, gold, coral, mint]
    stripe_width = 0.34
    y_values = (-0.98, -0.49, 0.0, 0.49, 0.98)
    for index, y in enumerate(y_values):
        objects.append(
            cube(
                f"CanopyStripe_{index}",
                (4.94, stripe_width, 0.026),
                (0.0, y, 3.114),
                stripe_mats[index],
                0.010,
            )
        )

    # Front fascia with matching stripe accents.
    objects.append(
        cube(
            "FrontFascia",
            (5.16, 0.14, 0.46),
            (0.0, -1.42, 2.82),
            cream,
            0.035,
        )
    )

    for index, z in enumerate((2.68, 2.80, 2.92)):
        objects.append(
            cube(
                f"FrontFasciaStripe_{index}",
                (4.90, 0.026, 0.055),
                (0.0, -1.502, z),
                (coral, mint, gold)[index],
                0.012,
            )
        )

    # Simple top-frame rails to tie the posts into the canopy.
    objects.append(
        cube(
            "TopFrontRail",
            (4.70, 0.13, 0.15),
            (0.0, -1.04, 2.52),
            wood,
            0.030,
        )
    )
    objects.append(
        cube(
            "TopRearRail",
            (4.70, 0.13, 0.15),
            (0.0, 1.04, 2.52),
            wood,
            0.030,
        )
    )

    root = bpy.data.objects.new(
        "StudyTown_garden_market_stall",
        None,
    )
    bpy.context.collection.objects.link(root)

    for obj in objects:
        obj.parent = root

    output_path = (
        output_dir
        / "garden_market_stall.glb"
    )
    output_dir.mkdir(parents=True, exist_ok=True)

    # Select only this asset.
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in objects:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = root

    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )

    print(
        "STUDYTOWN_MARKET_STALL_DONE "
        f"objects={len(objects)} "
        f"output={output_path}"
    )


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output).expanduser().resolve()
    build_market_stall(output_dir)


if __name__ == "__main__":
    main()
