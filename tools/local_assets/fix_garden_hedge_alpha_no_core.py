#!/usr/bin/env python3
"""
StudyTown FenceIkegaki final foliage fix.

What this does:
1. Imports the EXISTING runtime garden_hedge.glb.
2. Removes every StudyTown-added hedge core completely:
   - StudyTownHedgeOpaqueCore
   - StudyTownHedgeRoundedCore
3. Leaves the original FenceIkegaki foliage geometry untouched.
4. Exports the hedge again.
5. Patches the resulting GLB material to use hard alpha cutout:
      alphaMode   = "MASK"
      alphaCutoff = 0.50
      doubleSided = true

This prevents the leaf cards from looking semi-transparent while preserving the
transparent spaces around each actual leaf.

It does NOT regenerate the hedge from the DAE and does NOT add a replacement
core.

Run from the StudyTown project root:

/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/local_assets/fix_garden_hedge_alpha_no_core.py -- \
  --input "assets/dev_local/blender_generated/runtime/garden_hedge.glb"

Optional:
  --alpha-cutoff 0.45

Recommended range:
  0.40 - 0.55

A backup is written before replacement.
"""

from __future__ import annotations

import argparse
import json
import shutil
import struct
import sys
from pathlib import Path

import bpy


CORE_PREFIXES = (
    "StudyTownHedgeOpaqueCore",
    "StudyTownHedgeRoundedCore",
)

FOLIAGE_NAME_HINTS = (
    "mFenceIkegaki",
    "FenceIkegaki",
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
        "--alpha-cutoff",
        type=float,
        default=0.50,
        help="Hard cutout threshold. Recommended 0.40-0.55.",
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


def remove_studytown_cores(
    objects: list[bpy.types.Object],
) -> tuple[list[bpy.types.Object], list[str]]:
    kept: list[bpy.types.Object] = []
    removed: list[str] = []

    for obj in objects:
        if (
            obj.type == "MESH"
            and any(
                obj.name.startswith(prefix)
                for prefix in CORE_PREFIXES
            )
        ):
            removed.append(obj.name)
            bpy.data.objects.remove(
                obj,
                do_unlink=True,
            )
            continue

        kept.append(obj)

    return kept, removed


def prepare_foliage_materials(
    objects: list[bpy.types.Object],
) -> list[str]:
    """Make Blender-side intent match the final GLB patch where possible."""
    touched: list[str] = []

    seen: set[int] = set()

    for obj in objects:
        if obj.type != "MESH":
            continue

        for slot in obj.material_slots:
            material = slot.material

            if material is None:
                continue

            pointer = material.as_pointer()
            if pointer in seen:
                continue
            seen.add(pointer)

            name = material.name

            if not any(
                hint.lower() in name.lower()
                for hint in FOLIAGE_NAME_HINTS
            ):
                continue

            # Preserve the imported texture/node graph. We only alter render
            # behaviour, not the foliage colour or texture.
            material.use_nodes = True

            # Blender 4.2+/5.x setting. DITHERED is only a Blender-side
            # approximation; the GLB is explicitly patched to MASK afterward.
            if hasattr(material, "surface_render_method"):
                try:
                    material.surface_render_method = "DITHERED"
                except Exception:
                    pass

            # Older Blender fallback.
            if hasattr(material, "blend_method"):
                try:
                    material.blend_method = "CLIP"
                except Exception:
                    pass

            if hasattr(material, "alpha_threshold"):
                try:
                    material.alpha_threshold = 0.50
                except Exception:
                    pass

            if hasattr(material, "use_transparency_overlap"):
                try:
                    material.use_transparency_overlap = False
                except Exception:
                    pass

            # Show both sides of the leaf cards.
            material.use_backface_culling = False

            touched.append(name)

    return touched


def export_glb(
    objects: list[bpy.types.Object],
    output_path: Path,
) -> None:
    bpy.ops.object.select_all(action="DESELECT")

    mesh_objects = [
        obj
        for obj in objects
        if obj.type == "MESH"
        and obj.name in bpy.context.scene.objects
    ]

    if not mesh_objects:
        raise RuntimeError(
            "No hedge mesh remains after removing StudyTown core objects."
        )

    for obj in mesh_objects:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = mesh_objects[0]

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


def read_glb(path: Path):
    data = path.read_bytes()

    if len(data) < 12:
        raise RuntimeError("Invalid GLB: file too small.")

    magic, version, total_length = struct.unpack_from(
        "<4sII",
        data,
        0,
    )

    if magic != b"glTF" or version != 2:
        raise RuntimeError(
            f"Unsupported GLB header: magic={magic!r}, version={version}"
        )

    if total_length != len(data):
        raise RuntimeError(
            f"GLB length mismatch: header={total_length}, actual={len(data)}"
        )

    chunks: list[tuple[int, bytes]] = []
    offset = 12

    while offset < len(data):
        if offset + 8 > len(data):
            raise RuntimeError("Malformed GLB chunk header.")

        chunk_length, chunk_type = struct.unpack_from(
            "<II",
            data,
            offset,
        )
        offset += 8

        chunk_data = data[
            offset:offset + chunk_length
        ]
        offset += chunk_length

        if len(chunk_data) != chunk_length:
            raise RuntimeError("Malformed GLB chunk payload.")

        chunks.append(
            (
                chunk_type,
                chunk_data,
            )
        )

    return chunks


def write_glb(
    path: Path,
    chunks: list[tuple[int, bytes]],
) -> None:
    body = bytearray()

    for chunk_type, chunk_data in chunks:
        padded = chunk_data

        # JSON chunks are space-padded. BIN chunks are zero-padded.
        pad_byte = b" " if chunk_type == 0x4E4F534A else b"\x00"

        while len(padded) % 4:
            padded += pad_byte

        body += struct.pack(
            "<II",
            len(padded),
            chunk_type,
        )
        body += padded

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
    chunks = read_glb(path)

    json_index = None
    gltf = None

    for index, (chunk_type, chunk_data) in enumerate(chunks):
        if chunk_type == 0x4E4F534A:
            json_index = index
            gltf = json.loads(
                chunk_data.rstrip(b" \x00").decode("utf-8")
            )
            break

    if gltf is None or json_index is None:
        raise RuntimeError("GLB contains no JSON chunk.")

    materials = gltf.get("materials", [])
    changed: list[str] = []

    for material in materials:
        name = str(material.get("name", ""))

        if not any(
            hint.lower() in name.lower()
            for hint in FOLIAGE_NAME_HINTS
        ):
            continue

        material["alphaMode"] = "MASK"
        material["alphaCutoff"] = float(alpha_cutoff)
        material["doubleSided"] = True

        changed.append(
            name or "<unnamed foliage material>"
        )

    # There should normally be only the foliage material after deleting cores.
    # If Blender renamed it unexpectedly, safely fall back ONLY when exactly one
    # material remains.
    if not changed and len(materials) == 1:
        material = materials[0]
        material["alphaMode"] = "MASK"
        material["alphaCutoff"] = float(alpha_cutoff)
        material["doubleSided"] = True

        changed.append(
            str(material.get("name", "<single material>"))
        )

    if not changed:
        raise RuntimeError(
            "Could not identify FenceIkegaki foliage material in exported GLB."
        )

    encoded_json = json.dumps(
        gltf,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")

    json_type = chunks[json_index][0]
    chunks[json_index] = (
        json_type,
        encoded_json,
    )

    write_glb(
        path,
        chunks,
    )

    return changed


def main() -> int:
    args = parse_args()

    if not 0.10 <= args.alpha_cutoff <= 0.90:
        raise SystemExit(
            "ERROR: --alpha-cutoff must be between 0.10 and 0.90."
        )

    input_path = args.input.expanduser().resolve()

    if not input_path.is_file():
        raise SystemExit(
            f"ERROR: hedge GLB does not exist:\n  {input_path}"
        )

    backup_path = input_path.with_name(
        input_path.stem
        + "_before_alpha_no_core.glb"
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

    kept, removed = remove_studytown_cores(
        imported
    )

    blender_materials = prepare_foliage_materials(
        kept
    )

    print("")
    print("# STUDYTOWN — FENCEIKEGAKI FINAL ALPHA FIX")
    print(f"Input: {input_path}")
    print(f"Backup: {backup_path}")
    print("")
    print(
        "Removed StudyTown cores: "
        + (
            ", ".join(removed)
            if removed
            else "none found"
        )
    )
    print(
        "Foliage materials prepared in Blender: "
        + (
            ", ".join(blender_materials)
            if blender_materials
            else "material name will be resolved in GLB"
        )
    )
    print(f"Alpha cutoff: {args.alpha_cutoff:.3f}")
    print("Double-sided leaf cards: yes")
    print("")

    temp_path = input_path.with_name(
        input_path.stem
        + "_alpha_no_core_tmp.glb"
    )

    export_glb(
        kept,
        temp_path,
    )

    patched_materials = patch_alpha_mask(
        temp_path,
        args.alpha_cutoff,
    )

    temp_path.replace(
        input_path
    )

    print(
        "GLB MASK materials: "
        + ", ".join(patched_materials)
    )
    print("")
    print("UPDATED:", input_path)
    print("No opaque/rounded core remains.")
    print("Original FenceIkegaki foliage geometry was not regenerated.")
    print("Leaf transparency now uses hard alpha cutout.")
    print("DONE")
    print("")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
