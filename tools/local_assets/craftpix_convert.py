"""Convert CraftPix FBX packs into StudyTown runtime GLBs (local-only).

Fixes up imported materials (links the pack texture atlas), grounds and
centers geometry, joins multi-mesh houses sharing one material, and exports
GLB with embedded textures. Natural authorial size is kept; placement code
scales to measured bounds at runtime.

Typical use from the StudyTown repo root:

/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/local_assets/craftpix_convert.py -- --only trees

 Targets: trees, bushes, grass, houses, environment, all.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="all")
    return parser.parse_args(argv)


CRAFTPIX_ROOT = Path("assets/dev_local/blender_generated/../source/craftpix")
OUTPUT_DIR = Path("assets/dev_local/blender_generated/runtime")


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images,
                 bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for block in list(coll):
            try:
                coll.remove(block)
            except RuntimeError:
                pass


def link_texture(material: bpy.types.Material, image_path: Path) -> None:
    if not image_path.exists():
        print(f"CRAFTPIX_NO_TEXTURE {image_path.name}")
        return
    material.use_nodes = True
    nodes = material.node_tree.nodes
    principled = None
    for node in nodes:
        if node.type == "BSDF_PRINCIPLED":
            principled = node
            break
    if principled is None:
        return
    # Keep materials that already resolve their own image (e.g. house atlas
    # references carried by the FBX); only wire the pack atlas where no
    # image node feeds the shader graph yet.
    for node in nodes:
        if node.type == "TEX_IMAGE" and node.image is not None:
            return
    image = bpy.data.images.load(str(image_path), check_existing=True)
    try:
        image.colorspace_settings.name = "sRGB"
    except (TypeError, ValueError):
        pass
    material.use_nodes = True
    nodes = material.node_tree.nodes
    principled = None
    for node in nodes:
        if node.type == "BSDF_PRINCIPLED":
            principled = node
            break
    if principled is None:
        return
    # Drop dangling normal-map links (no source image shipped for them).
    for node in list(nodes):
        if node.type == "NORMAL_MAP":
            for link in list(material.node_tree.links):
                if link.from_node == node or link.to_node == node:
                    material.node_tree.links.remove(link)
            nodes.remove(node)
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    material.node_tree.links.new(tex.outputs["Color"], principled.inputs["Base Color"])


def mesh_world_points(obj) -> list:
    # NOTE: object.bound_box is stale right after FBX import (garbage from
    # the bind pose); vertices are the truth. Always use these.
    mesh = obj.data
    return [obj.matrix_world @ v.co for v in mesh.vertices]


def orient_upright() -> None:
    # Pack FBX files disagree on up-axis. Stand the longest axis up (+Z),
    # wide end (canopy) up, then ground_and_center() finishes the job.
    import math
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        return
    pts = []
    for o in meshes:
        pts.extend(mesh_world_points(o))
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    ext = mx - mn
    longest = max(range(3), key=lambda i: ext[i])
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    if meshes:
        bpy.context.view_layer.objects.active = meshes[0]
    if longest == 0:
        bpy.ops.transform.rotate(value=math.radians(90.0), orient_axis="Y")
    elif longest == 1:
        bpy.ops.transform.rotate(value=math.radians(-90.0), orient_axis="X")
    bpy.ops.object.select_all(action="DESELECT")
    # Wide end up: compare perpendicular spread of bottom vs top third.
    pts = []
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            pts.extend(mesh_world_points(o))
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    lo = [p for p in pts if p.z < mn.z + (mx.z - mn.z) * 0.34]
    hi = [p for p in pts if p.z > mn.z + (mx.z - mn.z) * 0.66]
    spread = lambda ps: (max(p.x for p in ps) - min(p.x for p in ps)) + (max(p.y for p in ps) - min(p.y for p in ps)) if ps else 0.0
    if spread(lo) > spread(hi):
        for o in meshes:
            o.select_set(True)
        if meshes:
            bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.transform.rotate(value=math.radians(180.0), orient_axis="X")
        bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.update()


def ground_and_center() -> None:
    # Translate top-level objects so the combined bounds sit centered at the
    # origin with base at y=0. Edits locations directly: the earlier wrapper
    # Empty approach preserved world transforms and grounded nothing.
    tops = [o for o in bpy.context.scene.objects if o.parent is None]
    pts = []
    for o in tops:
        if o.type == "MESH":
            pts.extend(mesh_world_points(o))
        else:
            pts.append(o.matrix_world.translation)
    if not pts:
        return
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    shift = Vector(((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mn.z))
    for o in tops:
        o.location -= shift
    bpy.context.view_layer.update()


def join_meshes() -> None:
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if len(meshes) < 2:
        return
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = "JoinedCraftPixMesh"


SPECS: dict = {
    # name -> (fbx dir, texture, join, outputs)
    "trees": None,  # expanded below: every tree FBX
    "bushes": None,
    "houses": None,
    "environment": None,
}


def normalize_units() -> None:
    # Some pack files model in centimeters: Blender compensates with a scene
    # unit scale the glTF exporter ignores, producing 100x giants. Fold the
    # unit scale into the top-level nodes so exports come out in meters.
    # Meter-authored files already sit at 1.0 and are untouched.
    unit_scale: float = bpy.context.scene.unit_settings.scale_length
    if abs(unit_scale - 1.0) > 0.0001:
        for o in bpy.context.scene.objects:
            if o.parent is None:
                o.scale *= unit_scale
        bpy.context.scene.unit_settings.scale_length = 1.0
        bpy.context.view_layer.update()
        print(f"CRAFTPIX_UNIT_FIX scale was {unit_scale}")
    # Some files model in centimeters with no unit compensation anywhere
    # (measured in raw vertex units here); fold them to meters.
    pts = []
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            pts.extend(mesh_world_points(o))
    if pts:
        extent = max(
            max(p.x for p in pts) - min(p.x for p in pts),
            max(p.y for p in pts) - min(p.y for p in pts),
            max(p.z for p in pts) - min(p.z for p in pts),
        )
        if extent > 30.0:
            for o in bpy.context.scene.objects:
                if o.parent is None:
                    o.scale *= 0.01
            bpy.context.view_layer.update()
            print(f"CRAFTPIX_UNIT_FIX extent was {extent:.1f}")


def flat_wood_material() -> None:
    # Gates ship broken texture references; use a clean flat wood instead of
    # atlas roulette (single material per gate, matches garden wood tones).
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        for node in mat.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                node.inputs["Base Color"].default_value = (0.5, 0.36, 0.24, 1.0)
                for link in list(mat.node_tree.links):
                    if link.to_node == node and link.to_socket.name == "Base Color":
                        mat.node_tree.links.remove(link)


def flatten_hierarchy() -> None:
    # Some pack files hide a 0.01 unit scale on a parent Empty that the glTF
    # exporter drops without baking (100x giants like the gates). Fold every
    # ancestor transform into the meshes and remove the empties, so exports
    # match the Blender viewport exactly.
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.parent is not None:
            world = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = world
    for o in list(bpy.data.objects):
        if o.type not in {"MESH", "LIGHT", "CAMERA"}:
            try:
                bpy.data.objects.remove(o, do_unlink=True)
            except RuntimeError:
                pass
    bpy.context.view_layer.update()


def convert_one(fbx: Path, texture: Path | None, output: Path, join: bool = False, orient: bool = True, flat_wood: bool = False) -> None:
    reset_scene()
    bpy.ops.import_scene.fbx(filepath=str(fbx))
    for obj in list(bpy.data.objects):
        if obj.type in {"CAMERA", "LIGHT", "ARMATURE"}:
            bpy.data.objects.remove(obj, do_unlink=True)
    normalize_units()
    flatten_hierarchy()
    if join:
        join_meshes()
    if flat_wood:
        flat_wood_material()
    elif texture is not None:
        for mat in bpy.data.materials:
            link_texture(mat, texture)
    normalize_units()
    # Trees ship with mixed up-axes and need standing up; authored props,
    # houses, and bush clumps are already upright and must keep their pose
    # (orienting a house by longest-axis once stood one on its side).
    if orient:
        orient_upright()
    ground_and_center()
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=False,
        export_animations=False,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_apply=True,
    )
    print(f"CRAFTPIX_DONE {fbx.name} -> {output.name}")


def main() -> None:
    args = parse_args()
    only = {s.strip() for s in args.only.split(",") if s.strip()}
    root = Path("assets/dev_local/source/craftpix")
    out = Path("assets/dev_local/blender_generated/runtime")
    jobs = []
    if only == {"all"} or "trees" in only:
        tex = root / "trees/Textures/T_Trees_temp_climate.png"
        for fbx in sorted((root / "trees/Fbx").glob("*.FBX")):
            jobs.append((fbx, tex, out / f"craftpix_{fbx.stem.lower()}.glb", False, True, False))
    if only == {"all"} or "bushes" in only:
        tex = root / "bushes/Bush_temp_climate/Textures/T_Bush_temp_climate.png"
        for fbx in sorted((root / "bushes/Bush_temp_climate/Fbx").glob("*.fbx")):
            jobs.append((fbx, tex, out / f"craftpix_{fbx.stem.lower()}.glb", False, False, False))
    if only == {"all"} or "houses" in only:
        tex = root / "houses/Texture/House_texture_atlas1.png"
        for name in ["House_04_full.fbx", "House_02_full.fbx"]:
            fbx = root / "houses/fbx/House_Full_ordinar" / name
            if fbx.exists():
                jobs.append((fbx, tex, out / f"craftpix_{name[:-4].lower()}.glb", True, False, False))
    if only == {"all"} or "environment" in only:
        tex = root / "environment/Texture/Texture.png"
        for name in ["Road_stone_1.fbx", "Road_stone_2.fbx", "Road_stone_3.fbx", "Road_stone_4.fbx", "Road_wood_1.fbx", "Lamp_1.fbx", "Lamp_2.fbx", "Lamp_3.fbx", "Lamp_4.fbx", "bench.fbx", "Fense_1.fbx", "Fense_2.fbx", "Fense_3.fbx", "Fense_4.fbx", "Fense_5.fbx", "Fense_6.fbx", "Bag_1.fbx", "bag_2.fbx"]:
            fbx = root / "environment/FBX" / name
            if fbx.exists():
                jobs.append((fbx, tex if (root / "environment/Texture/Texture.png").exists() else None,
                             out / f"craftpix_{name[:-4].lower()}.glb", False, False, False))
        for name in ["gate_1.fbx", "gate_2.fbx", "gate_3.fbx"]:
            fbx = root / "environment/FBX" / name
            if fbx.exists():
                jobs.append((fbx, None, out / f"craftpix_{name[:-4].lower()}.glb", False, False, True))
    print(f"CRAFTPIX_JOBS {len(jobs)}")
    failures = []
    for fbx, tex, output, join, orient, flat_wood in jobs:
        try:
            convert_one(fbx, tex, output, join, orient, flat_wood)
        except Exception as exc:  # noqa: BLE001
            failures.append((fbx.name, str(exc)))
            print(f"CRAFTPIX_FAILED {fbx.name}: {exc}")
    print(f"CRAFTPIX_SUMMARY ok={len(jobs) - len(failures)} failed={len(failures)}")
    if failures:
        raise RuntimeError(failures)


if __name__ == "__main__":
    main()
