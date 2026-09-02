"""Import the owner-local ACNH Big Tree (Museum) asset into StudyTown.

The source archive is expected to have been extracted locally.  This script:
- imports the supplied FBX,
- rebuilds the three materials from the supplied texture maps,
- applies leaf opacity,
- normalizes the complete tree to a predictable height,
- grounds and centres it,
- exports one self-contained GLB to StudyTown's gitignored runtime folder.

This is intentionally a local-development pipeline.  Do not commit the
generated GLB or the source textures/models unless you have redistribution
rights for them.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Vector


TRUNK = "mTreeHugeTrunk"
LEAF = "mTreeHugeLeaf"
LEAF_BACK = "mIdrTreeOakLeafBack"


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        required=True,
        help='Extracted "Big tree (Museum)" directory.',
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Destination GLB path.",
    )
    parser.add_argument(
        "--target-height",
        type=float,
        default=9.6,
        help="Tree height in Blender metres before StudyTown runtime scaling.",
    )
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.images,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for block in list(datablocks):
            try:
                datablocks.remove(block)
            except RuntimeError:
                pass


def find_source_fbx(source_dir: Path) -> Path:
    preferred = source_dir / "IdrObjTreeHuge00.fbx"
    if preferred.exists():
        return preferred

    candidates = sorted(source_dir.glob("*.fbx"))
    if not candidates:
        raise FileNotFoundError(
            f"No FBX found in {source_dir}. Expected IdrObjTreeHuge00.fbx"
        )
    return candidates[0]


def load_image(path: Path, non_color: bool = False) -> bpy.types.Image:
    if not path.exists():
        raise FileNotFoundError(f"Missing texture: {path}")

    image = bpy.data.images.load(str(path), check_existing=True)
    if non_color:
        try:
            image.colorspace_settings.name = "Non-Color"
        except TypeError:
            pass
    return image


def set_transparency(material: bpy.types.Material) -> None:
    """Enable alpha rendering across recent Blender versions."""
    if hasattr(material, "surface_render_method"):
        try:
            material.surface_render_method = "DITHERED"
        except (TypeError, ValueError):
            try:
                material.surface_render_method = "BLENDED"
            except (TypeError, ValueError):
                pass

    if hasattr(material, "use_transparency_overlap"):
        material.use_transparency_overlap = False

    # Older Blender fallback.
    if hasattr(material, "blend_method"):
        try:
            material.blend_method = "HASHED"
        except (TypeError, ValueError):
            try:
                material.blend_method = "BLEND"
            except (TypeError, ValueError):
                pass

    if hasattr(material, "show_transparent_back"):
        material.show_transparent_back = True


def build_material(
    name: str,
    texture_dir: Path,
    *,
    opacity: bool,
    use_ao: bool = True,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name=f"{name}_StudyTown")
    material.use_nodes = True
    material.diffuse_color = (1.0, 1.0, 1.0, 1.0)
    material.roughness = 0.75
    material.use_backface_culling = False

    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (720, 0)

    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.location = (430, 0)
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])

    albedo_path = texture_dir / f"{name}_Alb.png"
    normal_path = texture_dir / f"{name}_Nrm.png"
    roughness_path = texture_dir / f"{name}_Rgh.png"
    ao_path = texture_dir / f"{name}_Ocl.png"
    opacity_path = texture_dir / f"{name}_OP.png"

    albedo_node = nodes.new("ShaderNodeTexImage")
    albedo_node.name = f"{name}_Albedo"
    albedo_node.label = "Albedo"
    albedo_node.location = (-820, 180)
    albedo_node.image = load_image(albedo_path)

    if use_ao and ao_path.exists():
        ao_node = nodes.new("ShaderNodeTexImage")
        ao_node.name = f"{name}_AO"
        ao_node.label = "Ambient Occlusion"
        ao_node.location = (-820, -30)
        ao_node.image = load_image(ao_path, non_color=True)

        multiply = nodes.new("ShaderNodeMixRGB")
        multiply.blend_type = "MULTIPLY"
        multiply.inputs[0].default_value = 1.0
        multiply.location = (-350, 170)

        links.new(albedo_node.outputs["Color"], multiply.inputs[1])
        links.new(ao_node.outputs["Color"], multiply.inputs[2])
        links.new(multiply.outputs["Color"], principled.inputs["Base Color"])
    else:
        links.new(albedo_node.outputs["Color"], principled.inputs["Base Color"])

    if roughness_path.exists():
        roughness_node = nodes.new("ShaderNodeTexImage")
        roughness_node.name = f"{name}_Roughness"
        roughness_node.label = "Roughness"
        roughness_node.location = (-350, -110)
        roughness_node.image = load_image(roughness_path, non_color=True)
        links.new(roughness_node.outputs["Color"], principled.inputs["Roughness"])

    if normal_path.exists():
        normal_texture = nodes.new("ShaderNodeTexImage")
        normal_texture.name = f"{name}_NormalTexture"
        normal_texture.label = "Normal"
        normal_texture.location = (-820, -330)
        normal_texture.image = load_image(normal_path, non_color=True)

        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.location = (-350, -330)
        normal_map.inputs["Strength"].default_value = 1.0

        links.new(normal_texture.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])

    if opacity and opacity_path.exists():
        opacity_node = nodes.new("ShaderNodeTexImage")
        opacity_node.name = f"{name}_Opacity"
        opacity_node.label = "Opacity"
        opacity_node.location = (-350, -540)
        opacity_node.image = load_image(opacity_path, non_color=True)

        links.new(opacity_node.outputs["Color"], principled.inputs["Alpha"])
        set_transparency(material)

    # These are stylized non-metallic tree materials.
    if "Metallic" in principled.inputs:
        principled.inputs["Metallic"].default_value = 0.0

    return material


def imported_meshes() -> list[bpy.types.Object]:
    return [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "MESH"
    ]


def material_kind(name: str) -> str | None:
    lowered = name.lower()
    if TRUNK.lower() in lowered or "trunk" in lowered:
        return TRUNK
    if LEAF_BACK.lower() in lowered or "leafback" in lowered:
        return LEAF_BACK
    if LEAF.lower() in lowered or "hugeleaf" in lowered or "ivy010" in lowered:
        return LEAF
    return None


def assign_materials(
    meshes: list[bpy.types.Object],
    materials: dict[str, bpy.types.Material],
) -> None:
    for obj in meshes:
        if not obj.data.materials:
            # Fallback based on source mesh naming.
            kind = material_kind(obj.name)
            if kind is not None:
                obj.data.materials.append(materials[kind])
            continue

        for index, old_material in enumerate(list(obj.data.materials)):
            old_name = old_material.name if old_material else obj.name
            kind = material_kind(old_name) or material_kind(obj.name)
            if kind is not None:
                obj.data.materials[index] = materials[kind]


def world_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    minimum = Vector((float("inf"), float("inf"), float("inf")))
    maximum = Vector((float("-inf"), float("-inf"), float("-inf")))

    for obj in objects:
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            minimum.x = min(minimum.x, point.x)
            minimum.y = min(minimum.y, point.y)
            minimum.z = min(minimum.z, point.z)
            maximum.x = max(maximum.x, point.x)
            maximum.y = max(maximum.y, point.y)
            maximum.z = max(maximum.z, point.z)

    return minimum, maximum


def normalize_tree(
    meshes: list[bpy.types.Object],
    target_height: float,
) -> bpy.types.Object:
    if not meshes:
        raise RuntimeError("FBX imported no mesh objects.")

    minimum, maximum = world_bounds(meshes)
    source_height = maximum.z - minimum.z

    if source_height <= 0.00001:
        raise RuntimeError("Imported tree has invalid zero height.")

    scale_factor = target_height / source_height
    centre_x = (minimum.x + maximum.x) * 0.5
    centre_y = (minimum.y + maximum.y) * 0.5

    root = bpy.data.objects.new("GardenBigTreeMuseum", None)
    bpy.context.collection.objects.link(root)

    # FBX meshes are normally root-level.  Parenting them to one empty lets us
    # normalize the complete model without changing relative mesh placement.
    for obj in meshes:
        world_matrix = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = world_matrix

    root.scale = (scale_factor, scale_factor, scale_factor)
    root.location = Vector(
        (
            -centre_x * scale_factor,
            -centre_y * scale_factor,
            -minimum.z * scale_factor,
        )
    )

    bpy.context.view_layer.update()
    return root


def clean_scene(meshes: list[bpy.types.Object]) -> None:
    keep = set(meshes)

    for obj in list(bpy.context.scene.objects):
        if obj in keep:
            continue
        if obj.type in {"CAMERA", "LIGHT", "ARMATURE"}:
            bpy.data.objects.remove(obj, do_unlink=True)

    for obj in meshes:
        obj.hide_render = False
        obj.hide_viewport = False

        # ACNH foliage relies heavily on normal/opacity textures.  Preserve
        # geometry and UVs; only smooth actual mesh shading where appropriate.
        for polygon in obj.data.polygons:
            polygon.use_smooth = True


def export_glb(
    output_path: Path,
    root: bpy.types.Object,
    meshes: list[bpy.types.Object],
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in meshes:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = root

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


def save_blend(output_path: Path) -> None:
    source_dir = output_path.parent.parent / "source"
    source_dir.mkdir(parents=True, exist_ok=True)
    blend_path = source_dir / "garden_big_tree_museum.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))


def main() -> None:
    parsed = parse_args()

    source_dir = Path(parsed.source).expanduser().resolve()
    output_path = Path(parsed.output).expanduser().resolve()

    if not source_dir.exists():
        raise FileNotFoundError(f"Source folder does not exist: {source_dir}")

    source_fbx = find_source_fbx(source_dir)

    print(f"STUDYTOWN_BIG_TREE_SOURCE {source_fbx}")
    print(f"STUDYTOWN_BIG_TREE_OUTPUT {output_path}")

    reset_scene()

    bpy.ops.import_scene.fbx(
        filepath=str(source_fbx),
        use_anim=False,
    )

    meshes = imported_meshes()
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {source_fbx}")

    materials = {
        TRUNK: build_material(TRUNK, source_dir, opacity=False),
        LEAF: build_material(LEAF, source_dir, opacity=True),
        LEAF_BACK: build_material(LEAF_BACK, source_dir, opacity=True),
    }

    assign_materials(meshes, materials)
    clean_scene(meshes)

    root = normalize_tree(meshes, parsed.target_height)

    minimum, maximum = world_bounds(meshes)
    print(
        "STUDYTOWN_BIG_TREE_IMPORTED "
        f"meshes={len(meshes)} "
        f"bounds_min={tuple(round(v, 3) for v in minimum)} "
        f"bounds_max={tuple(round(v, 3) for v in maximum)}"
    )

    export_glb(output_path, root, meshes)
    save_blend(output_path)

    print(f"STUDYTOWN_BIG_TREE_DONE {output_path}")


if __name__ == "__main__":
    main()
