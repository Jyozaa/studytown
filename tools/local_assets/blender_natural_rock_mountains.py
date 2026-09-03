"""Build StudyTown natural rock mountain variants from existing local assets.

v1.1 fixes the noisy/fragile mesh duplication path from v1:
- single-mesh GLBs are no longer passed through bpy.ops.object.join()
- source rock meshes are prepared once as visible templates
- every duplicate is explicitly unhidden, detached from source parents, and selectable
- multi-mesh GLBs are joined only when there are actually 2+ meshes
- export diagnostics report rock count / vertices / polygons for every variant

Uses:
  - scenic_mountain.glb as the underlying macro silhouette
  - garden_rock_a.glb / garden_rock_b.glb / garden_rock_c.glb as the visible rock shell

Outputs:
  natural_rock_mountain_a.glb
  natural_rock_mountain_b.glb
  natural_rock_mountain_c.glb
"""

from __future__ import annotations

import argparse
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        default="assets/dev_local/blender_generated/runtime",
    )
    parser.add_argument(
        "--output",
        default="assets/dev_local/blender_generated/runtime",
    )
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    # Keep cleanup conservative. Imported data from the previous variant is
    # unlinked by object deletion and Blender can garbage-collect it on exit.
    for collection in list(bpy.data.collections):
        if collection.name != "Collection" and collection.users == 0:
            bpy.data.collections.remove(collection)


def import_glb(path: Path) -> list[bpy.types.Object]:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [obj for obj in bpy.context.scene.objects if obj not in before]


def mesh_objects(objects: list[bpy.types.Object]) -> list[bpy.types.Object]:
    return [obj for obj in objects if obj.type == "MESH"]


def make_visible(obj: bpy.types.Object) -> None:
    obj.hide_viewport = False
    obj.hide_render = False
    obj.hide_select = False
    try:
        obj.hide_set(False)
    except RuntimeError:
        pass


def detach_preserving_world(obj: bpy.types.Object) -> None:
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world


def join_meshes_if_needed(
    objects: list[bpy.types.Object],
    name: str,
) -> bpy.types.Object:
    meshes = [obj for obj in objects if obj.type == "MESH"]

    if not meshes:
        raise RuntimeError(f"No mesh objects available for {name}")

    for obj in meshes:
        make_visible(obj)
        detach_preserving_world(obj)

    # Important: do NOT call join for a one-mesh GLB. Blender 5.2 prints
    # "Warning: No mesh data to join" even though nothing is actually wrong.
    if len(meshes) == 1:
        result = meshes[0]
        result.name = name
        return result

    bpy.ops.object.select_all(action="DESELECT")

    for obj in meshes:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()

    result = bpy.context.object
    if result is None or result.type != "MESH":
        raise RuntimeError(f"Could not join mesh group for {name}")

    result.name = name
    return result


def prepare_template(
    path: Path,
    name: str,
) -> bpy.types.Object:
    imported = import_glb(path)
    template = join_meshes_if_needed(
        mesh_objects(imported),
        name,
    )

    # Template is intentionally hidden; only its duplicates are exported.
    template.hide_render = True
    template.hide_viewport = True
    try:
        template.hide_set(True)
    except RuntimeError:
        pass

    return template


def duplicate_template(
    template: bpy.types.Object,
    name: str,
) -> bpy.types.Object:
    dup = template.copy()
    dup.data = template.data.copy()

    # Link to the active scene collection directly.
    bpy.context.scene.collection.objects.link(dup)

    dup.name = name
    dup.parent = None
    dup.matrix_parent_inverse.identity()

    # Explicitly undo every hidden state inherited from the template.
    make_visible(dup)

    return dup


def make_stone_material() -> bpy.types.Material:
    mat = bpy.data.materials.new("NaturalMountainStone")

    # These material-level properties are sufficient for the GLB exporter and
    # avoid the Blender 5.2 use_nodes deprecation warning.
    mat.diffuse_color = (0.28, 0.30, 0.27, 1.0)
    mat.roughness = 0.92
    mat.metallic = 0.0

    return mat


def apply_material(
    obj: bpy.types.Object,
    material: bpy.types.Material,
) -> None:
    if obj.type != "MESH":
        return

    obj.data.materials.clear()
    obj.data.materials.append(material)


def add_softening(
    obj: bpy.types.Object,
    width: float,
) -> None:
    if obj.type != "MESH":
        return

    for polygon in obj.data.polygons:
        polygon.use_smooth = True

    bevel = obj.modifiers.new(
        "RockSoftening",
        "BEVEL",
    )
    bevel.width = width
    bevel.segments = 2


def apply_all_modifiers(obj: bpy.types.Object) -> None:
    make_visible(obj)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    for modifier in list(obj.modifiers):
        try:
            bpy.ops.object.modifier_apply(
                modifier=modifier.name
            )
        except RuntimeError as exc:
            print(
                f"WARNING modifier_apply {obj.name} "
                f"{modifier.name}: {exc}"
            )


def build_variant(
    runtime_dir: Path,
    output_dir: Path,
    variant: str,
    seed: int,
) -> None:
    reset_scene()

    rng = random.Random(seed)

    base_path = runtime_dir / "scenic_mountain.glb"
    rock_paths = [
        runtime_dir / "garden_rock_a.glb",
        runtime_dir / "garden_rock_b.glb",
        runtime_dir / "garden_rock_c.glb",
    ]

    missing = [
        str(path)
        for path in [base_path, *rock_paths]
        if not path.exists()
    ]

    if missing:
        raise FileNotFoundError(
            "Missing required mountain source assets: "
            + ", ".join(missing)
        )

    stone = make_stone_material()

    # Prepare the macro/base silhouette. Skip join if it is already one mesh.
    base = join_meshes_if_needed(
        mesh_objects(import_glb(base_path)),
        "HiddenMountainBase",
    )

    variant_scale = {
        "a": Vector((1.55, 1.18, 1.15)),
        "b": Vector((1.82, 1.05, 0.96)),
        "c": Vector((1.42, 1.34, 1.28)),
    }[variant]

    base.scale = variant_scale

    bpy.ops.object.select_all(action="DESELECT")
    base.select_set(True)
    bpy.context.view_layer.objects.active = base
    bpy.ops.object.transform_apply(
        location=False,
        rotation=False,
        scale=True,
    )

    apply_material(base, stone)
    add_softening(base, 0.10)

    # Each source rock GLB is imported once and converted to a template object.
    templates = [
        prepare_template(
            rock_paths[0],
            "RockTemplate_A",
        ),
        prepare_template(
            rock_paths[1],
            "RockTemplate_B",
        ),
        prepare_template(
            rock_paths[2],
            "RockTemplate_C",
        ),
    ]

    created: list[bpy.types.Object] = [base]
    shell_rock_count = 0

    # Larger rocks at the foot, smaller near the top.
    layers = [
        (0.15, 4.70, 22, 1.55, 2.20),
        (0.34, 3.90, 19, 1.35, 1.95),
        (0.53, 3.05, 16, 1.10, 1.65),
        (0.70, 2.15, 12, 0.90, 1.35),
        (0.84, 1.25, 8, 0.70, 1.05),
    ]

    squash_x = {
        "a": 1.00,
        "b": 1.18,
        "c": 0.92,
    }[variant]

    squash_y = {
        "a": 0.92,
        "b": 0.78,
        "c": 1.08,
    }[variant]

    lean_x = {
        "a": 0.0,
        "b": 0.55,
        "c": -0.45,
    }[variant]

    for (
        layer_t,
        radius,
        count,
        min_scale,
        max_scale,
    ) in layers:
        z = 0.30 + layer_t * 4.35

        for index in range(count):
            angle = (
                math.tau
                * float(index)
                / float(count)
                + rng.uniform(-0.16, 0.16)
            )

            radial = radius * rng.uniform(
                0.84,
                1.08,
            )

            x = (
                math.cos(angle)
                * radial
                * squash_x
                + lean_x * layer_t
            )

            y = (
                math.sin(angle)
                * radial
                * squash_y
            )

            template = templates[
                shell_rock_count % len(templates)
            ]

            rock = duplicate_template(
                template,
                f"RockShell_{shell_rock_count:03d}",
            )

            shell_rock_count += 1

            rock.location = (
                x,
                y,
                z + rng.uniform(-0.24, 0.24),
            )

            rock.rotation_euler = (
                rng.uniform(-0.28, 0.28),
                rng.uniform(-0.22, 0.22),
                angle
                + math.pi * 0.5
                + rng.uniform(-0.45, 0.45),
            )

            scale = rng.uniform(
                min_scale,
                max_scale,
            )

            rock.scale = (
                scale * rng.uniform(0.88, 1.18),
                scale * rng.uniform(0.82, 1.14),
                scale * rng.uniform(0.78, 1.12),
            )

            bpy.ops.object.select_all(action="DESELECT")
            rock.select_set(True)
            bpy.context.view_layer.objects.active = rock
            bpy.ops.object.transform_apply(
                location=False,
                rotation=False,
                scale=True,
            )

            apply_material(rock, stone)
            add_softening(rock, 0.07)
            created.append(rock)

    # Irregular summit cap so the original point does not read through.
    for cap_index in range(7):
        template = templates[
            (cap_index + 1) % len(templates)
        ]

        rock = duplicate_template(
            template,
            f"SummitRock_{cap_index:02d}",
        )

        rock.location = (
            lean_x * 0.95
            + rng.uniform(-0.75, 0.75),
            rng.uniform(-0.65, 0.65),
            rng.uniform(4.45, 5.20),
        )

        rock.rotation_euler = (
            rng.uniform(-0.45, 0.45),
            rng.uniform(-0.45, 0.45),
            rng.uniform(-math.pi, math.pi),
        )

        scale = rng.uniform(
            0.72,
            1.05,
        )

        rock.scale = (
            scale * 1.25,
            scale,
            scale * 0.88,
        )

        bpy.ops.object.select_all(action="DESELECT")
        rock.select_set(True)
        bpy.context.view_layer.objects.active = rock
        bpy.ops.object.transform_apply(
            location=False,
            rotation=False,
            scale=True,
        )

        apply_material(rock, stone)
        add_softening(rock, 0.06)
        created.append(rock)

    summit_count = 7
    total_visible_rocks = shell_rock_count + summit_count

    # Apply modifiers while each piece is independent.
    for obj in created:
        apply_all_modifiers(obj)

    # Join the base + all visible rocks once, at the very end.
    bpy.ops.object.select_all(action="DESELECT")

    for obj in created:
        make_visible(obj)
        obj.select_set(True)

    bpy.context.view_layer.objects.active = base

    if len(created) > 1:
        bpy.ops.object.join()

    mountain = bpy.context.object

    if mountain is None or mountain.type != "MESH":
        raise RuntimeError(
            f"Final mountain join failed for variant {variant}"
        )

    mountain.name = (
        f"NaturalRockMountain_{variant.upper()}"
    )
    mountain.data.name = mountain.name + "Mesh"

    apply_material(
        mountain,
        stone,
    )

    for polygon in mountain.data.polygons:
        polygon.use_smooth = True

    # Delete the hidden source templates so they can never be included in export.
    for template in templates:
        if template.name in bpy.context.scene.objects:
            bpy.data.objects.remove(
                template,
                do_unlink=True,
            )

    output_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    output_path = (
        output_dir
        / f"natural_rock_mountain_{variant}.glb"
    )

    bpy.ops.object.select_all(action="DESELECT")
    make_visible(mountain)
    mountain.select_set(True)
    bpy.context.view_layer.objects.active = mountain

    vertex_count = len(mountain.data.vertices)
    polygon_count = len(mountain.data.polygons)

    print(
        "STUDYTOWN_MOUNTAIN_DIAGNOSTIC "
        f"variant={variant} "
        f"rocks={total_visible_rocks} "
        f"verts={vertex_count} "
        f"polys={polygon_count}"
    )

    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_apply=True,
    )

    print(
        "STUDYTOWN_NATURAL_MOUNTAIN "
        f"{output_path}"
    )


def main() -> None:
    parsed = parse_args()

    runtime_dir = Path(
        parsed.input
    ).expanduser().resolve()

    output_dir = Path(
        parsed.output
    ).expanduser().resolve()

    for variant, seed in [
        ("a", 9033101),
        ("b", 9033102),
        ("c", 9033103),
    ]:
        build_variant(
            runtime_dir,
            output_dir,
            variant,
            seed,
        )


if __name__ == "__main__":
    main()
