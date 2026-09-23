"""Bake glowing bulbs into lamp lantern cages (one-off, then normal convert).

Finds glass-cage-sized islands in the upper half of each lamp, drops a small
emissive sphere at each center, then runs the standard CraftPix conversion.
Re-run the normal converter afterwards for these files is NOT needed: this
script converts fully (materials, grounding, GLB export).
"""
from __future__ import annotations

import sys
from pathlib import Path

import bpy
from mathutils import Vector


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
    for node in list(nodes):
        if node.type == "NORMAL_MAP":
            for link in list(material.node_tree.links):
                if link.from_node == node or link.to_node == node:
                    material.node_tree.links.remove(link)
            nodes.remove(node)
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    material.node_tree.links.new(tex.outputs["Color"], principled.inputs["Base Color"])


LAMPS = ["Lamp_1.fbx", "Lamp_3.fbx", "Lamp_4.fbx"]


def main() -> None:
    root = Path("assets/dev_local/source/craftpix")
    out = Path("assets/dev_local/blender_generated/runtime")
    tex = root / "environment/Texture/Texture.png"
    for fname in LAMPS:
        reset_scene()
        bpy.ops.import_scene.fbx(filepath=str(root / "environment/FBX" / fname))
        for obj in list(bpy.data.objects):
            if obj.type in {"CAMERA", "LIGHT", "ARMATURE"}:
                bpy.data.objects.remove(obj, do_unlink=True)
        meshes = [o for o in bpy.data.objects if o.type == "MESH"]
        if not meshes:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in meshes:
            o.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        # Split into islands to find lantern cages.
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.separate(type="LOOSE")
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.select_all(action="DESELECT")
        parts = [o for o in bpy.data.objects if o.type == "MESH"]
        # NOTE: bound_box is stale right after import; measure vertices.
        def part_box(o):
            pts = [o.matrix_world @ v.co for v in o.data.vertices]
            xs = [p.x for p in pts]
            ys = [p.y for p in pts]
            zs = [p.z for p in pts]
            return (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs),
                    (sum(xs) / len(xs), sum(ys) / len(ys), sum(zs) / len(zs)))
        top = max(part_box(o)[2] + 0.0 for o in parts)
        # Recompute true top from vertex data.
        allpts = [o.matrix_world @ v.co for o in parts for v in o.data.vertices]
        top = max(p.z for p in allpts)
        scored = []
        for o in parts:
            ex, ey, ez, c = part_box(o)
            vol = ex * ey * ez
            # Cage-sized chunks floating in the upper half (posts/bases are
            # big, finials are tiny).
            if 0.015 < vol < 0.8 and c[2] > top * 0.45:
                scored.append((vol, o, c))
        scored.sort(key=lambda t: t[0], reverse=True)
        cages = [t[1] for t in scored[:4]]
        print(f"BULBS {fname} cages={len(cages)}")
        bulb_mat = bpy.data.materials.new(name="CraftPixLampBulb")
        bulb_mat.use_nodes = True
        for node in bulb_mat.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                node.inputs["Base Color"].default_value = (1.0, 0.72, 0.42, 1.0)
                emission_input = node.inputs.get("Emission Color", node.inputs.get("Emission"))
                if emission_input is not None:
                    emission_input.default_value = (1.0, 0.55, 0.22, 1.0)
                strength = node.inputs.get("Emission Strength")
                if strength is not None:
                    strength.default_value = 2.5
        for _vol, _cage, center in [(t[0], t[1], Vector(t[2])) for t in scored[:4]]:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.075, segments=8, ring_count=4, location=center)
            bulb = bpy.context.object
            bulb.name = "LampBulb"
            if len(bulb.data.materials) == 0:
                bulb.data.materials.append(bulb_mat)
            else:
                bulb.data.materials[0] = bulb_mat
        for mat in bpy.data.materials:
            if mat != bulb_mat:
                link_texture(mat, tex)
        # Ground + center like the standard converter.
        tops = [o for o in bpy.context.scene.objects if o.parent is None]
        pts = []
        for o in tops:
            if o.type == "MESH":
                pts.extend(o.matrix_world @ v.co for v in o.data.vertices)
            else:
                pts.append(o.matrix_world.translation)
        mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        for o in tops:
            o.location -= Vector(((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mn.z))
        bpy.context.view_layer.update()
        out_path = out / f"craftpix_{Path(fname).stem.lower()}.glb"
        bpy.ops.export_scene.gltf(
            filepath=str(out_path),
            export_format="GLB",
            use_selection=False,
            export_animations=False,
            export_materials="EXPORT",
            export_cameras=False,
            export_lights=False,
            export_apply=True,
        )
        print(f"CRAFTPIX_DONE {fname} -> {out_path.name}")


if __name__ == "__main__":
    main()
