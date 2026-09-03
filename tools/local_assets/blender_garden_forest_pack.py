"""Convert the approved StudyTown Garden forest-source pack to runtime GLBs.

Expected source:
    assets/dev_local/source_assets/garden_forest_selected

Expected output:
    assets/dev_local/blender_generated/runtime

The external installer stages the selected remake/recolour textures beside the
DAE files, so this converter can build stable GLBs without knowing the original
Downloads/Model directory.

Blender 5.2 compatible.

This version does NOT depend on Blender's COLLADA extension. It directly parses
the static triangle geometry from these Nintendo DAE files, which avoids broken
controller/material references in several extracted assets.

"""

from __future__ import annotations

import argparse
import math
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import bpy
from mathutils import Vector


ASSETS = [
    {
        "id": "forest_trailer",
        "folder": "structures/forest_trailer",
        "dae": ["CommuneObjTrailerGarden.dae"],
        "output": "garden_forest_trailer.glb",
        "target_height": 4.3,
        "emission_strength": 1.45,
    },
    {
        "id": "campsite_tent",
        "folder": "structures/campsite_tent",
        "dae": [
            "StrcCampsiteTentA00.dae",
            "StrcCampsiteTentA00Door0.dae",
        ],
        "output": "garden_campsite_tent.glb",
        "target_height": 4.5,
        "emission_strength": 1.35,
    },
    {
        "id": "campsite_base",
        "folder": "structures_optional/campsite_base",
        "dae": ["StrcCampsiteA00.dae"],
        "output": "garden_campsite_base.glb",
        "target_height": 4.2,
        "emission_strength": 1.0,
    },
    {
        "id": "western_gazebo",
        "folder": "structures_optional/western_gazebo",
        "dae": ["FtrWesternGazebo.dae"],
        "output": "garden_western_gazebo.glb",
        "target_height": 4.7,
        "emission_strength": 0.4,
    },
    {
        "id": "garden_lamp",
        "folder": "lighting/garden_lamp",
        "dae": ["FtrLampGarden.dae"],
        "output": "garden_forest_lamp.glb",
        "target_height": 1.65,
        "emission_strength": 2.6,
    },
    {
        "id": "streetlamp_curve",
        "folder": "lighting/streetlamp_curve",
        "dae": ["FtrStreetlampCurve.dae"],
        "output": "garden_forest_streetlamp.glb",
        "target_height": 3.45,
        "emission_strength": 2.8,
    },
    {
        "id": "party_light_arch",
        "folder": "lighting/party_light_arch",
        "dae": ["FtrPartylightArch.dae"],
        "output": "garden_party_light_arch.glb",
        "target_height": 3.25,
        "emission_strength": 3.0,
    },
    {
        "id": "forest_lantern",
        "folder": "lighting/forest_lantern",
        "dae": ["FtrLantern.dae"],
        "output": "garden_forest_lantern.glb",
        "target_height": 0.52,
        "emission_strength": 2.1,
    },
    {
        "id": "forest_firepit",
        "folder": "lighting/forest_firepit",
        "dae": ["FtrFirepit.dae"],
        "output": "garden_forest_firepit.glb",
        "target_height": 0.62,
        "emission_strength": 3.2,
    },
    {
        "id": "park_bench",
        "folder": "props_optional/park_bench",
        "dae": ["FtrParkbenche.dae"],
        "output": "garden_forest_bench.glb",
        "target_height": 1.05,
        "emission_strength": 0.0,
    },
]


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        default="assets/dev_local/source_assets/garden_forest_selected",
    )
    parser.add_argument(
        "--output",
        default="assets/dev_local/blender_generated/runtime",
    )
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _collada_namespace(root: ET.Element) -> str:
    if root.tag.startswith("{"):
        return root.tag[1:].split("}", 1)[0]
    return ""


def _q(namespace: str, tag: str) -> str:
    return f"{{{namespace}}}{tag}" if namespace else tag


def _parse_float_source(
    mesh_element: ET.Element,
    namespace: str,
    source_id: str,
) -> tuple[list[float], int]:
    source_id = source_id.lstrip("#")

    source = None
    for candidate in mesh_element.findall(_q(namespace, "source")):
        if candidate.get("id") == source_id:
            source = candidate
            break

    if source is None:
        raise RuntimeError(
            f"DAE source not found: {source_id}"
        )

    float_array = source.find(_q(namespace, "float_array"))
    if float_array is None or not (float_array.text or "").strip():
        raise RuntimeError(
            f"DAE source has no float_array: {source_id}"
        )

    values = [
        float(value)
        for value in float_array.text.split()
    ]

    accessor = source.find(
        f".//{_q(namespace, 'accessor')}"
    )

    stride = 1
    if accessor is not None:
        stride = int(accessor.get("stride", "1"))

    return values, stride


def _source_tuple(
    values: list[float],
    stride: int,
    index: int,
) -> tuple[float, ...]:
    start = index * stride
    end = start + stride

    if start < 0 or end > len(values):
        raise RuntimeError(
            f"DAE source index out of range: "
            f"index={index} stride={stride}"
        )

    return tuple(values[start:end])


def _y_up_to_blender_xyz(
    value: tuple[float, ...],
) -> tuple[float, float, float]:
    # COLLADA defaults to Y_UP when <up_axis> is absent. These Nintendo
    # extracts omit <asset><up_axis>, so convert Y-up -> Blender Z-up.
    x = float(value[0])
    y = float(value[1])
    z = float(value[2])

    return (
        x,
        -z,
        y,
    )


def _make_basic_material(
    name: str,
    folder: Path,
    emission_strength: float,
) -> bpy.types.Material:
    material = bpy.data.materials.get(name)

    if material is None:
        material = bpy.data.materials.new(name)

    set_principled_texture_material(
        material,
        folder,
        emission_strength,
    )

    return material


def import_static_collada(
    path: Path,
    folder: Path,
    emission_strength: float,
) -> list[bpy.types.Object]:
    """Import the static geometry directly from a Nintendo DAE.

    Blender 5 removed its native COLLADA importer, and the extension-based
    importer can abort these extracted assets when their controller/material
    references are imperfect (for example CommuneObjTrailerGarden's unused
    mWinterSnow material).

    StudyTown does not need armatures for these environment props, so this
    function reads the DAE's geometry/triangle data directly with Python's XML
    parser and creates ordinary Blender meshes. This deliberately ignores:
      - armatures
      - controllers / skin weights
      - animations
      - unused/broken winter-snow geometry

    All approved Garden forest assets are static props, so this is the more
    reliable path for this pipeline.
    """
    if not path.is_file():
        raise FileNotFoundError(path)

    root = ET.parse(path).getroot()
    namespace = _collada_namespace(root)

    created: list[bpy.types.Object] = []

    library_geometries = root.find(
        _q(namespace, "library_geometries")
    )

    if library_geometries is None:
        raise RuntimeError(
            f"DAE contains no library_geometries: {path}"
        )

    for geometry in library_geometries.findall(
        _q(namespace, "geometry")
    ):
        geometry_name = (
            geometry.get("name")
            or geometry.get("id")
            or "Geometry"
        )

        mesh_element = geometry.find(
            _q(namespace, "mesh")
        )

        if mesh_element is None:
            continue

        vertices_sources: dict[str, str] = {}

        for vertices in mesh_element.findall(
            _q(namespace, "vertices")
        ):
            vertices_id = vertices.get("id", "")

            for input_element in vertices.findall(
                _q(namespace, "input")
            ):
                if input_element.get("semantic") == "POSITION":
                    vertices_sources[vertices_id] = (
                        input_element.get("source", "")
                    )

        triangle_sets = mesh_element.findall(
            _q(namespace, "triangles")
        )

        for primitive_index, triangles in enumerate(
            triangle_sets
        ):
            material_name = triangles.get(
                "material",
                "DefaultMaterial",
            )

            # The camper extract includes a winter-snow controller/material
            # whose image reference is absent from the candidate archive.
            # It is seasonal decoration and should not exist in the cozy
            # sunset Garden anyway.
            material_lower = material_name.lower()
            geometry_lower = geometry_name.lower()

            if (
                "wintersnow" in material_lower
                or "winter_snow" in material_lower
                or "wintersnow" in geometry_lower
                or "snowparts" in geometry_lower
            ):
                print(
                    "STUDYTOWN_DAE_SKIP "
                    f"file={path.name} "
                    f"geometry={geometry_name} "
                    f"material={material_name}"
                )
                continue

            inputs = []
            max_offset = 0

            for input_element in triangles.findall(
                _q(namespace, "input")
            ):
                semantic = input_element.get(
                    "semantic",
                    "",
                )
                source_ref = input_element.get(
                    "source",
                    "",
                )
                offset = int(
                    input_element.get(
                        "offset",
                        "0",
                    )
                )
                set_index = int(
                    input_element.get(
                        "set",
                        "0",
                    )
                )

                max_offset = max(
                    max_offset,
                    offset,
                )

                inputs.append(
                    {
                        "semantic": semantic,
                        "source": source_ref,
                        "offset": offset,
                        "set": set_index,
                    }
                )

            stride = max_offset + 1

            position_input = None
            normal_input = None
            uv_input = None

            for input_info in inputs:
                semantic = input_info["semantic"]

                if semantic == "VERTEX":
                    vertices_id = (
                        input_info["source"]
                        .lstrip("#")
                    )

                    position_source = (
                        vertices_sources.get(
                            vertices_id
                        )
                    )

                    if position_source:
                        position_input = {
                            **input_info,
                            "source": position_source,
                        }

                elif semantic == "POSITION":
                    position_input = input_info

                elif semantic == "NORMAL":
                    normal_input = input_info

                elif (
                    semantic == "TEXCOORD"
                    and (
                        uv_input is None
                        or input_info["set"] == 0
                    )
                ):
                    uv_input = input_info

            if position_input is None:
                raise RuntimeError(
                    f"No POSITION/VERTEX input in "
                    f"{path.name}:{geometry_name}"
                )

            position_values, position_stride = (
                _parse_float_source(
                    mesh_element,
                    namespace,
                    position_input["source"],
                )
            )

            normal_values = None
            normal_stride = 0

            if normal_input is not None:
                (
                    normal_values,
                    normal_stride,
                ) = _parse_float_source(
                    mesh_element,
                    namespace,
                    normal_input["source"],
                )

            uv_values = None
            uv_stride = 0

            if uv_input is not None:
                (
                    uv_values,
                    uv_stride,
                ) = _parse_float_source(
                    mesh_element,
                    namespace,
                    uv_input["source"],
                )

            p_element = triangles.find(
                _q(namespace, "p")
            )

            if (
                p_element is None
                or not (p_element.text or "").strip()
            ):
                continue

            raw_indices = [
                int(value)
                for value in p_element.text.split()
            ]

            if len(raw_indices) % stride != 0:
                raise RuntimeError(
                    f"Malformed triangle index stream in "
                    f"{path.name}:{geometry_name}"
                )

            corner_count = (
                len(raw_indices)
                // stride
            )

            if corner_count % 3 != 0:
                raise RuntimeError(
                    f"Triangle corner count is not divisible by 3 in "
                    f"{path.name}:{geometry_name}"
                )

            vertices_out: list[
                tuple[float, float, float]
            ] = []

            normals_out: list[
                tuple[float, float, float]
            ] = []

            uvs_out: list[
                tuple[float, float]
            ] = []

            for corner_index in range(
                corner_count
            ):
                base = corner_index * stride

                position_index = raw_indices[
                    base
                    + int(
                        position_input["offset"]
                    )
                ]

                position_tuple = _source_tuple(
                    position_values,
                    position_stride,
                    position_index,
                )

                vertices_out.append(
                    _y_up_to_blender_xyz(
                        position_tuple
                    )
                )

                if (
                    normal_input is not None
                    and normal_values is not None
                ):
                    normal_index = raw_indices[
                        base
                        + int(
                            normal_input["offset"]
                        )
                    ]

                    normal_tuple = _source_tuple(
                        normal_values,
                        normal_stride,
                        normal_index,
                    )

                    normals_out.append(
                        _y_up_to_blender_xyz(
                            normal_tuple
                        )
                    )

                if (
                    uv_input is not None
                    and uv_values is not None
                ):
                    uv_index = raw_indices[
                        base
                        + int(
                            uv_input["offset"]
                        )
                    ]

                    uv_tuple = _source_tuple(
                        uv_values,
                        uv_stride,
                        uv_index,
                    )

                    u = float(uv_tuple[0])
                    v = float(uv_tuple[1])

                    # Blender image UV convention is vertically opposite to
                    # these extracted COLLADA coordinates.
                    uvs_out.append(
                        (
                            u,
                            1.0 - v,
                        )
                    )

            faces = [
                (
                    face_start,
                    face_start + 1,
                    face_start + 2,
                )
                for face_start in range(
                    0,
                    corner_count,
                    3,
                )
            ]

            mesh_name = (
                f"{geometry_name}_"
                f"{primitive_index:02d}_Mesh"
            )

            mesh = bpy.data.meshes.new(
                mesh_name
            )

            mesh.from_pydata(
                vertices_out,
                [],
                faces,
            )

            mesh.update()

            if uvs_out:
                uv_layer = mesh.uv_layers.new(
                    name="UVMap"
                )

                # Every DAE corner became its own Blender vertex, so the loop's
                # vertex index maps directly to the stored corner UV.
                for loop in mesh.loops:
                    uv_layer.data[
                        loop.index
                    ].uv = uvs_out[
                        loop.vertex_index
                    ]

            if (
                normals_out
                and len(normals_out)
                == len(vertices_out)
            ):
                # Blender 5's custom-normal API can vary between builds.
                # Apply it when available; otherwise smooth shading below is
                # a safe visual fallback.
                try:
                    mesh.normals_split_custom_set_from_vertices(
                        normals_out
                    )
                except Exception:
                    pass

            object_name = (
                f"{geometry_name}_"
                f"{primitive_index:02d}"
            )

            obj = bpy.data.objects.new(
                object_name,
                mesh,
            )

            bpy.context.scene.collection.objects.link(
                obj
            )

            material = _make_basic_material(
                material_name,
                folder,
                emission_strength,
            )

            mesh.materials.append(
                material
            )

            for polygon in mesh.polygons:
                polygon.use_smooth = True

            created.append(
                obj
            )

    if not created:
        raise RuntimeError(
            f"Static DAE parser created no geometry from: {path}"
        )

    print(
        "STUDYTOWN_STATIC_DAE "
        f"file={path.name} "
        f"objects={len(created)}"
    )

    return created


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


def join_meshes(objects: list[bpy.types.Object], name: str) -> bpy.types.Object:
    meshes = [obj for obj in objects if obj.type == "MESH"]

    if not meshes:
        raise RuntimeError(f"No meshes found for {name}")

    for obj in meshes:
        make_visible(obj)
        detach_preserving_world(obj)

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
        raise RuntimeError(f"Could not join meshes for {name}")

    result.name = name
    return result


def material_root_name(name: str) -> str:
    # Blender may append .001, .002, etc. to Collada material names.
    return name.split(".")[0]


def find_texture(folder: Path, material_name: str, suffixes: list[str]) -> Path | None:
    root = material_root_name(material_name)

    for suffix in suffixes:
        exact = folder / f"{root}_{suffix}.png"
        if exact.is_file():
            return exact

    # Some material variants use mBody for an imported material that Blender
    # may call something close but not identical. Keep fallback narrow.
    lower_root = root.lower()
    pngs = list(folder.glob("*.png"))

    for candidate in pngs:
        low = candidate.stem.lower()
        if lower_root in low and any(low.endswith("_" + s.lower()) for s in suffixes):
            return candidate

    return None


def image_node(nodes, image_path: Path, name: str, non_color: bool = False):
    image = bpy.data.images.load(
        str(image_path),
        check_existing=True,
    )

    if non_color:
        try:
            image.colorspace_settings.name = "Non-Color"
        except Exception:
            pass

    node = nodes.new("ShaderNodeTexImage")
    node.name = name
    node.label = name
    node.image = image
    return node


def set_principled_texture_material(
    material: bpy.types.Material,
    folder: Path,
    emission_strength: float,
) -> None:
    root = material_root_name(material.name)

    albedo = find_texture(folder, root, ["Alb", "AlbGry"])
    normal = find_texture(folder, root, ["Nrm"])
    emission = find_texture(folder, root, ["Emi", "Emm", "EmiOry"])
    opacity = find_texture(folder, root, ["OP"])

    # Special case: the portable lantern's body remake is staged as mReBody,
    # while its glass has its own normal/opacity maps.
    if albedo is None and root.lower() == "mrebody":
        albedo = folder / "mReBody_Alb.png"
        if not albedo.is_file():
            albedo = None

    if (
        albedo is None
        and normal is None
        and emission is None
        and opacity is None
    ):
        return

    # Needed for explicit PBR node construction. Blender 5.2 emits a harmless
    # future deprecation warning for use_nodes, but the API remains supported.
    material.use_nodes = True

    nodes = material.node_tree.nodes
    links = material.node_tree.links

    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (720, 0)

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (380, 0)

    links.new(
        bsdf.outputs["BSDF"],
        output.inputs["Surface"],
    )

    # Cozy matte surfaces are a better fit for these stylized ACNH assets.
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = 0.72
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0

    if albedo is not None:
        tex = image_node(
            nodes,
            albedo,
            "Albedo",
            False,
        )
        tex.location = (-560, 180)

        links.new(
            tex.outputs["Color"],
            bsdf.inputs["Base Color"],
        )

    if normal is not None:
        tex = image_node(
            nodes,
            normal,
            "Normal",
            True,
        )
        tex.location = (-560, -120)

        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.location = (-120, -120)
        normal_map.inputs["Strength"].default_value = 0.72

        links.new(
            tex.outputs["Color"],
            normal_map.inputs["Color"],
        )
        links.new(
            normal_map.outputs["Normal"],
            bsdf.inputs["Normal"],
        )

    if emission is not None and emission_strength > 0.0:
        tex = image_node(
            nodes,
            emission,
            "Emission",
            False,
        )
        tex.location = (-560, -360)

        emission_input = None
        if "Emission Color" in bsdf.inputs:
            emission_input = bsdf.inputs["Emission Color"]
        elif "Emission" in bsdf.inputs:
            emission_input = bsdf.inputs["Emission"]

        if emission_input is not None:
            links.new(
                tex.outputs["Color"],
                emission_input,
            )

        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength

    if opacity is not None:
        tex = image_node(
            nodes,
            opacity,
            "Opacity",
            True,
        )
        tex.location = (-560, -560)

        if "Alpha" in bsdf.inputs:
            links.new(
                tex.outputs["Color"],
                bsdf.inputs["Alpha"],
            )

        # Blender 4.2+ / 5.x.
        if hasattr(material, "surface_render_method"):
            try:
                material.surface_render_method = "DITHERED"
            except Exception:
                pass
        # Older Blender fallback.
        elif hasattr(material, "blend_method"):
            try:
                material.blend_method = "CLIP"
            except Exception:
                pass


def world_bounds(
    obj: bpy.types.Object,
) -> tuple[float, float, float, float, float, float]:
    """Return world-space bounds in Blender 5.x.

    In Blender 5.2, Object.bound_box yields bpy_prop_array values rather than
    mathutils.Vector instances. Matrix multiplication therefore requires an
    explicit Vector conversion.
    """
    if obj.type != "MESH" or obj.data is None:
        raise RuntimeError(
            f"world_bounds expected a mesh object, got: {obj.name}"
        )

    if len(obj.data.vertices) == 0:
        raise RuntimeError(
            f"Cannot calculate bounds for empty mesh: {obj.name}"
        )

    # Use bound_box for speed, but convert every corner explicitly.
    corners = [
        obj.matrix_world @ Vector(tuple(corner))
        for corner in obj.bound_box
    ]

    xs = [point.x for point in corners]
    ys = [point.y for point in corners]
    zs = [point.z for point in corners]

    return (
        min(xs),
        max(xs),
        min(ys),
        max(ys),
        min(zs),
        max(zs),
    )


def normalize_object(obj: bpy.types.Object, target_height: float) -> None:
    min_x, max_x, min_y, max_y, min_z, max_z = world_bounds(obj)

    current_height = max_z - min_z

    if current_height <= 0.00001:
        raise RuntimeError(
            f"{obj.name} has invalid height {current_height}"
        )

    scale_value = target_height / current_height
    obj.scale = obj.scale * scale_value

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    bpy.ops.object.transform_apply(
        location=False,
        rotation=False,
        scale=True,
    )

    min_x, max_x, min_y, max_y, min_z, max_z = world_bounds(obj)

    obj.location.x -= (min_x + max_x) * 0.5
    obj.location.y -= (min_y + max_y) * 0.5
    obj.location.z -= min_z

    bpy.ops.object.transform_apply(
        location=True,
        rotation=False,
        scale=False,
    )


def convert_asset(
    source_root: Path,
    output_root: Path,
    spec: dict,
) -> None:
    reset_scene()

    folder = source_root / spec["folder"]

    if not folder.is_dir():
        raise RuntimeError(
            f"Missing staged source folder: {folder}"
        )

    imported: list[bpy.types.Object] = []

    for dae_name in spec["dae"]:
        imported.extend(
            import_static_collada(
                folder / dae_name,
                folder,
                float(spec["emission_strength"]),
            )
        )

    meshes = mesh_objects(imported)

    if not meshes:
        raise RuntimeError(
            f"No mesh data imported for {spec['id']}"
        )

    # Materials are already reconstructed by import_static_collada() from
    # the staged PNG files. Keep them intact through the final join.

    joined = join_meshes(
        meshes,
        spec["id"],
    )

    pre_bounds = world_bounds(joined)
    print(
        "STUDYTOWN_PRE_NORMALIZE "
        f"id={spec['id']} "
        f"bounds={tuple(round(value, 4) for value in pre_bounds)}"
    )

    normalize_object(
        joined,
        float(spec["target_height"]),
    )

    # Smooth shading keeps the extracted geometry pleasant without changing its
    # actual silhouette.
    for polygon in joined.data.polygons:
        polygon.use_smooth = True

    output_root.mkdir(
        parents=True,
        exist_ok=True,
    )

    output_path = output_root / spec["output"]

    bpy.ops.object.select_all(action="DESELECT")
    joined.select_set(True)
    bpy.context.view_layer.objects.active = joined

    vertex_count = len(joined.data.vertices)
    polygon_count = len(joined.data.polygons)

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
        "STUDYTOWN_FOREST_ASSET "
        f"id={spec['id']} "
        f"height={spec['target_height']} "
        f"verts={vertex_count} "
        f"polys={polygon_count} "
        f"path={output_path}"
    )


def main() -> None:
    args = parse_args()

    source_root = Path(args.source).expanduser().resolve()
    output_root = Path(args.output).expanduser().resolve()

    print("")
    print("# STUDYTOWN — GARDEN FOREST ASSET CONVERSION")
    print(f"Source: {source_root}")
    print(f"Output: {output_root}")
    print("")

    for spec in ASSETS:
        convert_asset(
            source_root,
            output_root,
            spec,
        )

    print("")
    print("DONE")
    print("Runtime forest structures and lighting props were exported.")
    print("")


if __name__ == "__main__":
    main()
