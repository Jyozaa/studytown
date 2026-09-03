#!/usr/bin/env python3
"""
StudyTown Garden hedge cleanup + real FenceIkegaki leaf extraction.

This script works on the CURRENT runtime hedge:
    assets/dev_local/blender_generated/runtime/garden_hedge.glb

It does two things:

1. Removes the remaining low rectangular base geometry from the original
   FenceIkegaki foliage mesh. It does NOT regenerate or recolour the foliage.

2. Extracts a real leaf card directly from FenceIkegaki and exports it as:
       garden_falling_leaf.glb

The extracted leaf keeps the same FenceIkegaki texture/material and is used by
the Godot whole-map falling/static leaf atmosphere.

The script preserves alpha cutout on both output GLBs:
    alphaMode   = MASK
    alphaCutoff = 0.50
    doubleSided = true

Run from the StudyTown project root:

/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/local_assets/fix_hedge_base_extract_leaf.py -- \
  --input "assets/dev_local/blender_generated/runtime/garden_hedge.glb" \
  --leaf-output "assets/dev_local/blender_generated/runtime/garden_falling_leaf.glb"

If the base is unusually thick, --base-band can be adjusted. Default is 0.14.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import statistics
import struct
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


FOLIAGE_HINTS = (
    "mFenceIkegaki",
    "FenceIkegaki",
)

CORE_PREFIXES = (
    "StudyTownHedgeOpaqueCore",
    "StudyTownHedgeRoundedCore",
)


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        type=Path,
        default=Path(
            "assets/dev_local/blender_generated/runtime/garden_hedge.glb"
        ),
    )
    parser.add_argument(
        "--leaf-output",
        type=Path,
        default=Path(
            "assets/dev_local/blender_generated/runtime/garden_falling_leaf.glb"
        ),
    )
    parser.add_argument(
        "--base-band",
        type=float,
        default=0.14,
        help="Bottom fraction of foliage height inspected for base geometry.",
    )
    parser.add_argument(
        "--alpha-cutoff",
        type=float,
        default=0.50,
    )
    parser.add_argument(
        "--leaf-size",
        type=float,
        default=0.26,
        help="Longest dimension of exported leaf in metres.",
    )
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_glb(path: Path) -> list[bpy.types.Object]:
    before = set(bpy.context.scene.objects)

    result = bpy.ops.import_scene.gltf(
        filepath=str(path)
    )

    if "FINISHED" not in result:
        raise RuntimeError(
            f"glTF import failed: {path}"
        )

    return [
        obj
        for obj in bpy.context.scene.objects
        if obj not in before
    ]


def remove_any_studytown_core(
    objects: list[bpy.types.Object],
) -> list[bpy.types.Object]:
    kept: list[bpy.types.Object] = []

    for obj in objects:
        if (
            obj.type == "MESH"
            and any(
                obj.name.startswith(prefix)
                for prefix in CORE_PREFIXES
            )
        ):
            print(
                "REMOVE CORE",
                obj.name,
            )
            bpy.data.objects.remove(
                obj,
                do_unlink=True,
            )
            continue

        kept.append(obj)

    return kept


def find_foliage(
    objects: list[bpy.types.Object],
) -> bpy.types.Object:
    candidates = [
        obj
        for obj in objects
        if obj.type == "MESH"
    ]

    hinted = [
        obj
        for obj in candidates
        if any(
            hint.lower() in obj.name.lower()
            for hint in FOLIAGE_HINTS
        )
    ]

    if hinted:
        return max(
            hinted,
            key=lambda obj: len(obj.data.polygons),
        )

    if not candidates:
        raise RuntimeError(
            "No mesh object found in garden_hedge.glb."
        )

    return max(
        candidates,
        key=lambda obj: len(obj.data.polygons),
    )


def polygon_area(
    mesh: bpy.types.Mesh,
    polygon: bpy.types.MeshPolygon,
) -> float:
    return polygon.area


def longest_polygon_edge(
    mesh: bpy.types.Mesh,
    polygon: bpy.types.MeshPolygon,
) -> float:
    coords = [
        mesh.vertices[index].co
        for index in polygon.vertices
    ]

    longest = 0.0

    for index in range(len(coords)):
        a = coords[index]
        b = coords[(index + 1) % len(coords)]
        longest = max(
            longest,
            (a - b).length,
        )

    return longest


def mesh_bounds(
    mesh: bpy.types.Mesh,
) -> tuple[Vector, Vector]:
    if not mesh.vertices:
        raise RuntimeError(
            "Foliage mesh has no vertices."
        )

    coords = [
        vertex.co
        for vertex in mesh.vertices
    ]

    minimum = Vector((
        min(v.x for v in coords),
        min(v.y for v in coords),
        min(v.z for v in coords),
    ))

    maximum = Vector((
        max(v.x for v in coords),
        max(v.y for v in coords),
        max(v.z for v in coords),
    ))

    return minimum, maximum


def identify_base_polygon_indices(
    mesh: bpy.types.Mesh,
    base_band: float,
) -> list[int]:
    minimum, maximum = mesh_bounds(
        mesh
    )

    extent = maximum - minimum
    cutoff_z = minimum.z + extent.z * base_band

    areas = [
        max(
            polygon_area(mesh, polygon),
            1e-9,
        )
        for polygon in mesh.polygons
    ]

    median_area = statistics.median(
        areas
    )

    base_indices: list[int] = []

    for polygon in mesh.polygons:
        coords = [
            mesh.vertices[index].co
            for index in polygon.vertices
        ]

        max_z = max(
            point.z
            for point in coords
        )

        if max_z > cutoff_z:
            continue

        area = max(
            polygon.area,
            1e-9,
        )

        longest_edge = longest_polygon_edge(
            mesh,
            polygon,
        )

        large_low_face = (
            area >= median_area * 1.75
            or longest_edge >= extent.x * 0.14
            or longest_edge >= extent.y * 0.20
        )

        if large_low_face:
            base_indices.append(
                polygon.index
            )

    print(
        "BASE DETECTION "
        f"min_z={minimum.z:.5f} "
        f"max_z={maximum.z:.5f} "
        f"cutoff_z={cutoff_z:.5f} "
        f"median_area={median_area:.6f} "
        f"faces={len(base_indices)}"
    )

    return base_indices


def face_coordinate_keys(
    mesh: bpy.types.Mesh,
    polygon: bpy.types.MeshPolygon,
    precision: int = 4,
) -> set[tuple[float, float, float]]:
    return {
        (
            round(
                mesh.vertices[index].co.x,
                precision,
            ),
            round(
                mesh.vertices[index].co.y,
                precision,
            ),
            round(
                mesh.vertices[index].co.z,
                precision,
            ),
        )
        for index in polygon.vertices
    }


def choose_leaf_faces(
    mesh: bpy.types.Mesh,
    excluded: set[int],
) -> list[int]:
    minimum, maximum = mesh_bounds(
        mesh
    )
    extent = maximum - minimum

    candidates = []

    for polygon in mesh.polygons:
        if polygon.index in excluded:
            continue

        centre = polygon.center

        # Prefer a readable leaf from the upper-middle shell, away from the
        # base strip.
        normalized_z = (
            (centre.z - minimum.z)
            / max(
                extent.z,
                1e-6,
            )
        )

        if not 0.35 <= normalized_z <= 0.88:
            continue

        candidates.append(
            polygon
        )

    if not candidates:
        candidates = [
            polygon
            for polygon in mesh.polygons
            if polygon.index not in excluded
        ]

    if not candidates:
        raise RuntimeError(
            "No foliage polygon remained for leaf extraction."
        )

    candidate_areas = [
        polygon.area
        for polygon in candidates
    ]

    median_area = statistics.median(
        candidate_areas
    )

    candidates.sort(
        key=lambda polygon: abs(
            polygon.area - median_area
        )
    )

    # Many extracted Nintendo cards have split/duplicated vertices, so the two
    # triangles of one card may be disconnected topologically. Pair them by
    # approximate shared coordinates instead.
    search_pool = candidates[:180]

    for first in search_pool:
        first_keys = face_coordinate_keys(
            mesh,
            first,
        )

        for second in search_pool:
            if second.index == first.index:
                continue

            if first.normal.dot(
                second.normal
            ) < 0.88:
                continue

            second_keys = face_coordinate_keys(
                mesh,
                second,
            )

            shared = first_keys.intersection(
                second_keys
            )

            union = first_keys.union(
                second_keys
            )

            if (
                len(shared) >= 2
                and len(union) <= 4
            ):
                print(
                    "LEAF CARD "
                    f"faces={first.index},{second.index} "
                    f"areas={first.area:.6f},{second.area:.6f}"
                )
                return [
                    first.index,
                    second.index,
                ]

    # Safe fallback: one actual FenceIkegaki foliage triangle is still a real
    # piece of the source foliage and works as a stylized falling leaf.
    chosen = candidates[0]

    print(
        "LEAF TRIANGLE FALLBACK "
        f"face={chosen.index} "
        f"area={chosen.area:.6f}"
    )

    return [
        chosen.index
    ]


def extract_leaf_object(
    foliage: bpy.types.Object,
    face_indices: list[int],
    target_size: float,
) -> bpy.types.Object:
    mesh = foliage.data

    uv_layer = (
        mesh.uv_layers.active.data
        if mesh.uv_layers.active is not None
        else None
    )

    vertices_out: list[
        tuple[float, float, float]
    ] = []

    faces_out: list[
        tuple[int, int, int]
    ] = []

    uv_faces: list[
        list[tuple[float, float]]
    ] = []

    material_indices: list[int] = []

    all_coords: list[Vector] = []

    selected_polygons = [
        mesh.polygons[index]
        for index in face_indices
    ]

    for polygon in selected_polygons:
        face_vertex_indices = []

        face_uvs: list[
            tuple[float, float]
        ] = []

        for loop_index in polygon.loop_indices:
            vertex_index = mesh.loops[
                loop_index
            ].vertex_index

            coord = mesh.vertices[
                vertex_index
            ].co.copy()

            all_coords.append(
                coord
            )

            new_index = len(
                vertices_out
            )

            vertices_out.append(
                (
                    coord.x,
                    coord.y,
                    coord.z,
                )
            )

            face_vertex_indices.append(
                new_index
            )

            if uv_layer is not None:
                uv = uv_layer[
                    loop_index
                ].uv

                face_uvs.append(
                    (
                        float(uv.x),
                        float(uv.y),
                    )
                )

        if len(face_vertex_indices) != 3:
            continue

        faces_out.append(
            tuple(
                face_vertex_indices
            )
        )

        uv_faces.append(
            face_uvs
        )

        material_indices.append(
            polygon.material_index
        )

    if not faces_out:
        raise RuntimeError(
            "Selected leaf faces did not produce a triangle."
        )

    centre = Vector((
        sum(v.x for v in all_coords) / len(all_coords),
        sum(v.y for v in all_coords) / len(all_coords),
        sum(v.z for v in all_coords) / len(all_coords),
    ))

    centred = [
        Vector(vertex) - centre
        for vertex in vertices_out
    ]

    min_v = Vector((
        min(v.x for v in centred),
        min(v.y for v in centred),
        min(v.z for v in centred),
    ))

    max_v = Vector((
        max(v.x for v in centred),
        max(v.y for v in centred),
        max(v.z for v in centred),
    ))

    longest = max(
        (
            max_v - min_v
        ).x,
        (
            max_v - min_v
        ).y,
        (
            max_v - min_v
        ).z,
        1e-6,
    )

    scale_value = (
        target_size
        / longest
    )

    scaled_vertices = [
        tuple(
            v * scale_value
        )
        for v in centred
    ]

    leaf_mesh = bpy.data.meshes.new(
        "FenceIkegakiFallingLeafMesh"
    )

    leaf_mesh.from_pydata(
        scaled_vertices,
        [],
        faces_out,
    )
    leaf_mesh.update()

    if uv_layer is not None:
        leaf_uv = leaf_mesh.uv_layers.new(
            name="UVMap"
        )

        for face_index, polygon in enumerate(
            leaf_mesh.polygons
        ):
            if face_index >= len(
                uv_faces
            ):
                break

            source_uvs = uv_faces[
                face_index
            ]

            for local_loop_index, loop_index in enumerate(
                polygon.loop_indices
            ):
                if local_loop_index < len(
                    source_uvs
                ):
                    leaf_uv.data[
                        loop_index
                    ].uv = source_uvs[
                        local_loop_index
                    ]

    # Keep all source material slots so the original material_index remains
    # valid.
    for slot in foliage.material_slots:
        if slot.material is not None:
            leaf_mesh.materials.append(
                slot.material
            )

    for face_index, polygon in enumerate(
        leaf_mesh.polygons
    ):
        if face_index < len(
            material_indices
        ):
            polygon.material_index = min(
                material_indices[face_index],
                max(
                    len(leaf_mesh.materials) - 1,
                    0,
                ),
            )

        polygon.use_smooth = True

    leaf_object = bpy.data.objects.new(
        "FenceIkegakiFallingLeaf",
        leaf_mesh,
    )

    bpy.context.scene.collection.objects.link(
        leaf_object
    )

    return leaf_object


def delete_base_faces(
    foliage: bpy.types.Object,
    indices: list[int],
) -> None:
    if not indices:
        print(
            "WARNING: no base-like faces detected; foliage was not cut."
        )
        return

    mesh = foliage.data

    bm = bmesh.new()
    bm.from_mesh(
        mesh
    )
    bm.faces.ensure_lookup_table()

    to_delete = [
        bm.faces[index]
        for index in indices
        if index < len(
            bm.faces
        )
    ]

    bmesh.ops.delete(
        bm,
        geom=to_delete,
        context="FACES",
    )

    bm.to_mesh(
        mesh
    )
    bm.free()

    mesh.update()

    print(
        "REMOVED BASE FACES",
        len(to_delete),
    )


def export_selected_glb(
    objects: list[bpy.types.Object],
    path: Path,
) -> None:
    path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    bpy.ops.object.select_all(
        action="DESELECT"
    )

    meshes = [
        obj
        for obj in objects
        if obj.type == "MESH"
        and obj.name in bpy.context.scene.objects
    ]

    if not meshes:
        raise RuntimeError(
            f"No mesh objects selected for export: {path}"
        )

    for obj in meshes:
        obj.select_set(
            True
        )

    bpy.context.view_layer.objects.active = meshes[0]

    result = bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_apply=True,
    )

    if "FINISHED" not in result:
        raise RuntimeError(
            f"glTF export failed: {path}"
        )


def read_glb(path: Path):
    data = path.read_bytes()

    magic, version, total_length = struct.unpack_from(
        "<4sII",
        data,
        0,
    )

    if (
        magic != b"glTF"
        or version != 2
        or total_length != len(data)
    ):
        raise RuntimeError(
            f"Invalid GLB header: {path}"
        )

    chunks = []
    offset = 12

    while offset < len(
        data
    ):
        length, chunk_type = struct.unpack_from(
            "<II",
            data,
            offset,
        )
        offset += 8

        chunk = data[
            offset:offset + length
        ]
        offset += length

        chunks.append(
            (
                chunk_type,
                chunk,
            )
        )

    return chunks


def write_glb(
    path: Path,
    chunks,
) -> None:
    body = bytearray()

    for chunk_type, chunk in chunks:
        padding = (
            b" "
            if chunk_type == 0x4E4F534A
            else b"\x00"
        )

        while len(chunk) % 4:
            chunk += padding

        body.extend(
            struct.pack(
                "<II",
                len(chunk),
                chunk_type,
            )
        )

        body.extend(
            chunk
        )

    header = struct.pack(
        "<4sII",
        b"glTF",
        2,
        12 + len(body),
    )

    path.write_bytes(
        header + body
    )


def patch_alpha_mask(
    path: Path,
    alpha_cutoff: float,
) -> list[str]:
    chunks = read_glb(
        path
    )

    json_index = None
    gltf = None

    for index, (
        chunk_type,
        chunk,
    ) in enumerate(chunks):
        if chunk_type == 0x4E4F534A:
            json_index = index
            gltf = json.loads(
                chunk.rstrip(
                    b" \x00"
                ).decode(
                    "utf-8"
                )
            )
            break

    if gltf is None:
        raise RuntimeError(
            f"No JSON chunk in {path}"
        )

    changed = []

    materials = gltf.get(
        "materials",
        [],
    )

    for material in materials:
        name = str(
            material.get(
                "name",
                "",
            )
        )

        if any(
            hint.lower() in name.lower()
            for hint in FOLIAGE_HINTS
        ):
            material["alphaMode"] = "MASK"
            material["alphaCutoff"] = float(
                alpha_cutoff
            )
            material["doubleSided"] = True

            changed.append(
                name
            )

    if not changed and len(materials) == 1:
        material = materials[0]
        material["alphaMode"] = "MASK"
        material["alphaCutoff"] = float(
            alpha_cutoff
        )
        material["doubleSided"] = True

        changed.append(
            str(
                material.get(
                    "name",
                    "<single material>",
                )
            )
        )

    if not changed:
        raise RuntimeError(
            f"Could not identify foliage material in {path}"
        )

    encoded = json.dumps(
        gltf,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode(
        "utf-8"
    )

    chunks[json_index] = (
        chunks[json_index][0],
        encoded,
    )

    write_glb(
        path,
        chunks,
    )

    return changed


def main() -> int:
    args = parse_args()

    if not 0.05 <= args.base_band <= 0.30:
        raise SystemExit(
            "ERROR: --base-band must be between 0.05 and 0.30."
        )

    if not 0.10 <= args.alpha_cutoff <= 0.90:
        raise SystemExit(
            "ERROR: --alpha-cutoff must be between 0.10 and 0.90."
        )

    input_path = args.input.expanduser().resolve()
    leaf_output = args.leaf_output.expanduser().resolve()

    if not input_path.is_file():
        raise SystemExit(
            f"ERROR: hedge GLB not found:\n  {input_path}"
        )

    backup_path = input_path.with_name(
        input_path.stem
        + "_before_base_removal.glb"
    )

    if not backup_path.exists():
        shutil.copy2(
            input_path,
            backup_path,
        )

    reset_scene()

    imported = import_glb(
        input_path
    )

    imported = remove_any_studytown_core(
        imported
    )

    foliage = find_foliage(
        imported
    )

    print("")
    print("# STUDYTOWN — HEDGE BASE CLEANUP + REAL LEAF EXTRACTION")
    print(f"Hedge:       {input_path}")
    print(f"Leaf output: {leaf_output}")
    print(f"Foliage:     {foliage.name}")
    print(f"Backup:      {backup_path}")
    print("")

    base_faces = identify_base_polygon_indices(
        foliage.data,
        args.base_band,
    )

    leaf_faces = choose_leaf_faces(
        foliage.data,
        set(base_faces),
    )

    leaf_object = extract_leaf_object(
        foliage,
        leaf_faces,
        args.leaf_size,
    )

    delete_base_faces(
        foliage,
        base_faces,
    )

    # Hedge export: everything except the temporary leaf object.
    hedge_objects = [
        obj
        for obj in imported
        if obj.type == "MESH"
        and obj != leaf_object
    ]

    hedge_tmp = input_path.with_name(
        input_path.stem
        + "_base_cleanup_tmp.glb"
    )

    export_selected_glb(
        hedge_objects,
        hedge_tmp,
    )

    patch_alpha_mask(
        hedge_tmp,
        args.alpha_cutoff,
    )

    hedge_tmp.replace(
        input_path
    )

    # Leaf export.
    export_selected_glb(
        [
            leaf_object,
        ],
        leaf_output,
    )

    patch_alpha_mask(
        leaf_output,
        args.alpha_cutoff,
    )

    print("")
    print("UPDATED HEDGE:", input_path)
    print("EXPORTED REAL LEAF:", leaf_output)
    print("No StudyTown hedge core remains.")
    print("Original foliage colour/material retained.")
    print("DONE")
    print("")

    return 0


if __name__ == "__main__":
    raise SystemExit(
        main()
    )
