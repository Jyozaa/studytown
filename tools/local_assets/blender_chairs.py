"""Generate StudyTown's original library and Garden Cafe chair assets.

The assets are intentionally small, rounded, low-poly furniture that matches the
existing StudyTown Blender furniture kit. Outputs should stay under the local,
gitignored ``assets/dev_local/blender_generated`` tree.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy


PALETTE = {
    "cream": "F8E6BA",
    "cocoa": "5A3326",
    "wood": "8A4B2B",
    "honey": "E6A737",
}


def arguments() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, help="Runtime output directory for GLB files")
    parser.add_argument(
        "--only",
        choices=("library_chair", "cafe_chair"),
        default=None,
        help="Generate only one chair. Omit to generate both.",
    )
    return parser.parse_args(argv)


def color(hex_value: str) -> tuple[float, float, float, float]:
    return tuple(int(hex_value[index : index + 2], 16) / 255.0 for index in (0, 2, 4)) + (1.0,)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def material(name: str):
    existing = bpy.data.materials.get(name)
    if existing is not None:
        return existing

    mat = bpy.data.materials.new(name)
    base = color(PALETTE[name])
    mat.diffuse_color = base
    mat.roughness = 0.72
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = base
        principled.inputs["Roughness"].default_value = 0.72
    return mat


def finish(obj, name: str, material_name: str, bevel: float = 0.04):
    obj.name = name
    obj.data.name = name + "Mesh"
    obj.data.materials.append(material(material_name))
    if bevel > 0.0:
        modifier = obj.modifiers.new("StudyTownSoftBevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
    return obj


def box(name: str, location, dimensions, material_name: str, bevel: float = 0.04):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, material_name, min(bevel, min(dimensions) * 0.22))


def cylinder(
    name: str,
    location,
    radius: float,
    depth: float,
    material_name: str,
    vertices: int = 18,
    bevel: float = 0.025,
):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
    )
    return finish(bpy.context.object, name, material_name, bevel)


def library_chair() -> None:
    """Warm traditional reading-room chair with a modest upholstered seat."""
    reset_scene()

    # Seat surface: top is approximately Z=0.82 m.
    box("LibrarySeatFrame", (0.0, 0.0, 0.70), (1.06, 0.98, 0.18), "cocoa", 0.055)
    box("LibrarySeatCushion", (0.0, -0.02, 0.815), (0.88, 0.78, 0.08), "cream", 0.035)

    # Four sturdy but not bulky legs.
    for x in (-0.41, 0.41):
        for y in (-0.35, 0.35):
            cylinder("LibraryLeg", (x, y, 0.34), 0.072, 0.68, "cocoa")

    # Classic open back. Positive Y is the rear of the chair in this asset.
    for x in (-0.43, 0.43):
        cylinder("LibraryBackPost", (x, 0.39, 1.18), 0.078, 0.98, "cocoa")

    box("LibraryTopRail", (0.0, 0.39, 1.64), (1.02, 0.14, 0.15), "honey", 0.045)
    for z in (1.12, 1.34, 1.52):
        box("LibraryBackSlat", (0.0, 0.39, z), (0.76, 0.10, 0.10), "wood", 0.03)

    # Subtle front apron keeps the silhouette substantial next to library desks.
    box("LibraryFrontApron", (0.0, -0.43, 0.61), (0.86, 0.10, 0.15), "wood", 0.03)


def cafe_chair() -> None:
    """Lighter open-air bistro chair with a slim, airy back."""
    reset_scene()

    # Keep the seat height close to the library chair so the existing seated
    # character offsets remain compatible.
    box("CafeSeatFrame", (0.0, 0.0, 0.69), (0.98, 0.92, 0.14), "wood", 0.05)
    box("CafeSeatInset", (0.0, -0.015, 0.785), (0.82, 0.74, 0.07), "cream", 0.03)

    # Slim legs for a lighter outdoor silhouette.
    for x in (-0.38, 0.38):
        for y in (-0.33, 0.33):
            cylinder("CafeLeg", (x, y, 0.335), 0.055, 0.67, "wood", 16, 0.018)

    # Tall narrow back posts and widely spaced rails make it read as a cafe
    # chair rather than the heavier library version.
    for x in (-0.39, 0.39):
        cylinder("CafeBackPost", (x, 0.35, 1.15), 0.058, 1.06, "wood", 16, 0.018)

    for z, width in ((1.10, 0.72), (1.31, 0.76), (1.50, 0.82)):
        box("CafeBackRail", (0.0, 0.35, z), (width, 0.085, 0.085), "honey", 0.026)

    box("CafeTopRail", (0.0, 0.35, 1.66), (0.90, 0.10, 0.12), "wood", 0.035)


def export_asset(output_dir: Path, name: str) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    source_dir = output_dir.parent / "source"
    source_dir.mkdir(parents=True, exist_ok=True)

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No meshes generated for {name}")

    # Apply bevels before joining so every component keeps its intended radius.
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

    # Give every generated chair a predictable world-origin pivot. Godot still
    # performs visual-AABB grounding, but this also makes Blender inspection easy.
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

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
    print(f"STUDYTOWN_CHAIR_ASSET {name}.glb")


def main() -> None:
    parsed = arguments()
    output_dir = Path(parsed.output).resolve()

    builders = {
        "library_chair": library_chair,
        "cafe_chair": cafe_chair,
    }

    selected = (
        [(parsed.only, builders[parsed.only])]
        if parsed.only is not None
        else list(builders.items())
    )

    for name, builder in selected:
        builder()
        export_asset(output_dir, name)


if __name__ == "__main__":
    main()
