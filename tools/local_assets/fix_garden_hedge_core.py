#!/usr/bin/env python3
"""
Fix the protruding solid core inside StudyTown's existing ACNH FenceIkegaki hedge.

This script DOES NOT regenerate or replace the foliage.

It imports the already-correct runtime asset:
    assets/dev_local/blender_generated/runtime/garden_hedge.glb

Then it:
- finds disconnected mesh components,
- identifies the large, simple box-like component inside the hedge,
- shrinks that component inward while keeping its bottom at the same height,
- leaves all foliage geometry, UVs, textures and materials untouched,
- writes a backup beside the GLB before replacing it.

Run from the StudyTown project root:

/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/local_assets/fix_garden_hedge_core.py -- \
  --input "assets/dev_local/blender_generated/runtime/garden_hedge.glb"

Optional:
  --dry-run
  --xy-scale 0.84
  --z-scale 0.68
"""

from __future__ import annotations

import argparse
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

import bpy
from mathutils import Vector


@dataclass
class Component:
    vertices: set[int]
    polygons: list[int]
    min_v: Vector
    max_v: Vector

    @property
    def dims(self) -> Vector:
        return self.max_v - self.min_v

    @property
    def center(self) -> Vector:
        return (self.min_v + self.max_v) * 0.5


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        type=Path,
        default=Path("assets/dev_local/blender_generated/runtime/garden_hedge.glb"),
    )
    parser.add_argument(
        "--xy-scale",
        type=float,
        default=0.84,
        help="Horizontal scale applied only to the detected solid core.",
    )
    parser.add_argument(
        "--z-scale",
        type=float,
        default=0.68,
        help="Vertical scale applied only to the detected solid core, anchored at its bottom.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print detected components but do not change the GLB.",
    )
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_glb(path: Path) -> list[bpy.types.Object]:
    before = set(bpy.context.scene.objects)

    result = bpy.ops.import_scene.gltf(filepath=str(path))
    if "FINISHED" not in result:
        raise RuntimeError(f"glTF import failed: {path}")

    return [
        obj
        for obj in bpy.context.scene.objects
        if obj not in before
    ]


def connected_components(mesh: bpy.types.Mesh) -> list[Component]:
    adjacency: dict[int, set[int]] = {
        index: set()
        for index in range(len(mesh.vertices))
    }

    for edge in mesh.edges:
        a, b = edge.vertices
        adjacency[a].add(b)
        adjacency[b].add(a)

    remaining = set(adjacency.keys())
    vertex_components: list[set[int]] = []

    while remaining:
        start = remaining.pop()
        stack = [start]
        component = {start}

        while stack:
            current = stack.pop()
            for neighbour in adjacency[current]:
                if neighbour in remaining:
                    remaining.remove(neighbour)
                    component.add(neighbour)
                    stack.append(neighbour)

        vertex_components.append(component)

    polygon_lookup: dict[int, list[int]] = {}
    for polygon in mesh.polygons:
        if not polygon.vertices:
            continue
        polygon_lookup.setdefault(polygon.vertices[0], []).append(polygon.index)

    components: list[Component] = []

    for vertices in vertex_components:
        poly_indices: list[int] = []

        # A polygon belongs to this component if its first vertex belongs to it.
        for polygon in mesh.polygons:
            if polygon.vertices and polygon.vertices[0] in vertices:
                poly_indices.append(polygon.index)

        coords = [
            mesh.vertices[index].co.copy()
            for index in vertices
        ]

        min_v = Vector((
            min(v.x for v in coords),
            min(v.y for v in coords),
            min(v.z for v in coords),
        ))
        max_v = Vector((
            max(v.x for v in coords),
            max(v.y for v in coords),
            max(v.z for v in coords),
        ))

        components.append(
            Component(
                vertices=vertices,
                polygons=poly_indices,
                min_v=min_v,
                max_v=max_v,
            )
        )

    return components


def overall_bounds(mesh: bpy.types.Mesh) -> tuple[Vector, Vector]:
    coords = [vertex.co for vertex in mesh.vertices]

    return (
        Vector((
            min(v.x for v in coords),
            min(v.y for v in coords),
            min(v.z for v in coords),
        )),
        Vector((
            max(v.x for v in coords),
            max(v.y for v in coords),
            max(v.z for v in coords),
        )),
    )


def score_core_candidate(
    component: Component,
    overall_dims: Vector,
) -> float:
    dims = component.dims

    if (
        dims.x <= 0.0001
        or dims.y <= 0.0001
        or dims.z <= 0.0001
    ):
        return -1.0

    x_ratio = dims.x / overall_dims.x
    y_ratio = dims.y / overall_dims.y
    z_ratio = dims.z / overall_dims.z

    vertex_count = len(component.vertices)
    polygon_count = len(component.polygons)

    # The foliage consists of many disconnected leaf/surface pieces.
    # The offending inner body is expected to be:
    # - one comparatively simple connected solid,
    # - nearly as long as the hedge,
    # - substantial in depth and height,
    # - much lower topology than the foliage shell.
    if x_ratio < 0.72:
        return -1.0
    if y_ratio < 0.38:
        return -1.0
    if z_ratio < 0.38:
        return -1.0
    if polygon_count > 300:
        return -1.0
    if vertex_count > 300:
        return -1.0

    topology_bonus = max(
        0.0,
        1.0 - polygon_count / 300.0,
    )

    return (
        x_ratio * 4.0
        + y_ratio * 2.0
        + z_ratio * 2.0
        + topology_bonus * 3.0
    )


def shrink_component(
    mesh: bpy.types.Mesh,
    component: Component,
    xy_scale: float,
    z_scale: float,
) -> None:
    center = component.center
    bottom_z = component.min_v.z

    for vertex_index in component.vertices:
        vertex = mesh.vertices[vertex_index]
        co = vertex.co.copy()

        co.x = center.x + (co.x - center.x) * xy_scale
        co.y = center.y + (co.y - center.y) * xy_scale

        # Preserve the bottom plane so the hedge still reaches the ground,
        # while lowering the top and side faces beneath the foliage shell.
        co.z = bottom_z + (co.z - bottom_z) * z_scale

        vertex.co = co

    mesh.update()


def export_glb(objects: list[bpy.types.Object], output_path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")

    selected = 0
    for obj in objects:
        if obj.type == "MESH":
            obj.select_set(True)
            selected += 1

    if selected == 0:
        raise RuntimeError("No mesh objects available for export.")

    bpy.context.view_layer.objects.active = next(
        obj
        for obj in objects
        if obj.type == "MESH"
    )

    result = bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_apply=True,
    )

    if "FINISHED" not in result:
        raise RuntimeError("glTF export failed.")


def main() -> int:
    args = parse_args()

    input_path = args.input.expanduser().resolve()

    if not input_path.is_file():
        raise SystemExit(
            f"ERROR: hedge GLB does not exist:\n  {input_path}"
        )

    if not (0.50 <= args.xy_scale <= 0.98):
        raise SystemExit("--xy-scale must be between 0.50 and 0.98")

    if not (0.40 <= args.z_scale <= 0.98):
        raise SystemExit("--z-scale must be between 0.40 and 0.98")

    reset_scene()
    imported = import_glb(input_path)

    mesh_objects = [
        obj
        for obj in imported
        if obj.type == "MESH"
    ]

    if not mesh_objects:
        raise SystemExit("ERROR: imported hedge contains no mesh objects.")

    print("")
    print("# STUDYTOWN — FIX ACTUAL FENCEIKEGAKI HEDGE CORE")
    print(f"Input: {input_path}")
    print("")

    ranked: list[tuple[float, bpy.types.Object, Component]] = []

    for obj in mesh_objects:
        mesh = obj.data
        min_v, max_v = overall_bounds(mesh)
        overall_dims = max_v - min_v

        components = connected_components(mesh)

        print(
            f"OBJECT {obj.name}: "
            f"verts={len(mesh.vertices)} "
            f"polys={len(mesh.polygons)} "
            f"components={len(components)} "
            f"dims=({overall_dims.x:.4f}, {overall_dims.y:.4f}, {overall_dims.z:.4f})"
        )

        ordered = sorted(
            enumerate(components),
            key=lambda item: len(item[1].polygons),
            reverse=True,
        )

        for index, component in ordered[:12]:
            score = score_core_candidate(
                component,
                overall_dims,
            )

            dims = component.dims

            print(
                "  COMPONENT "
                f"{index:03d} "
                f"verts={len(component.vertices):4d} "
                f"polys={len(component.polygons):4d} "
                f"dims=({dims.x:.4f}, {dims.y:.4f}, {dims.z:.4f}) "
                f"score={score:.3f}"
            )

            if score >= 0.0:
                ranked.append(
                    (
                        score,
                        obj,
                        component,
                    )
                )

    if not ranked:
        raise SystemExit(
            "\nERROR: No safe box-like core candidate was detected. "
            "Nothing was changed."
        )

    ranked.sort(
        key=lambda item: item[0],
        reverse=True,
    )

    best_score, best_obj, best_component = ranked[0]

    # Require a reasonably convincing match rather than touching arbitrary
    # foliage if the asset layout ever changes.
    if best_score < 6.0:
        raise SystemExit(
            f"\nERROR: Best candidate score was only {best_score:.3f}. "
            "Refusing to modify the hedge."
        )

    print("")
    print(
        "SELECTED CORE "
        f"object={best_obj.name} "
        f"verts={len(best_component.vertices)} "
        f"polys={len(best_component.polygons)} "
        f"dims=({best_component.dims.x:.4f}, "
        f"{best_component.dims.y:.4f}, "
        f"{best_component.dims.z:.4f}) "
        f"score={best_score:.3f}"
    )

    if args.dry_run:
        print("")
        print("DRY RUN — no files changed.")
        return 0

    backup_path = input_path.with_name(
        input_path.stem
        + "_before_core_fix.glb"
    )

    if not backup_path.exists():
        shutil.copy2(
            input_path,
            backup_path,
        )
        print(f"Backup: {backup_path}")
    else:
        print(
            "Backup already exists; leaving it untouched:"
            f" {backup_path}"
        )

    shrink_component(
        best_obj.data,
        best_component,
        args.xy_scale,
        args.z_scale,
    )

    temp_output = input_path.with_name(
        input_path.stem
        + "_core_fix_tmp.glb"
    )

    export_glb(
        imported,
        temp_output,
    )

    temp_output.replace(
        input_path
    )

    print("")
    print(
        "FIXED CORE "
        f"xy_scale={args.xy_scale:.3f} "
        f"z_scale={args.z_scale:.3f}"
    )
    print(f"Updated: {input_path}")
    print("")
    print("The original FenceIkegaki foliage was not regenerated or rescaled.")
    print("DONE")
    print("")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
