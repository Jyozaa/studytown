"""Batch-inspect CraftPix FBX packs: dimensions, tris, materials, textures."""
import sys
import bpy
from mathutils import Vector

target_dir = sys.argv[sys.argv.index("--") + 1]


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images,
                 bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for block in list(coll):
            try:
                coll.remove(block)
            except RuntimeError:
                pass


import os
files = sorted(f for f in os.listdir(target_dir) if f.lower().endswith(".fbx"))
print(f"INSPECT_DIR {target_dir} files={len(files)}")
for fname in files:
    reset()
    path = os.path.join(target_dir, fname)
    try:
        bpy.ops.import_scene.fbx(filepath=path)
    except Exception as exc:  # noqa: BLE001
        print(f"IMPORT_FAIL {fname} {exc}")
        continue
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    tris = 0
    for o in meshes:
        mesh = o.data
        tris += sum(len(p.vertices) - 2 for p in mesh.polygons if len(p.vertices) >= 3)
    pts = []
    for o in meshes:
        pts.extend(o.matrix_world @ v.co for v in o.data.vertices)
    if pts:
        mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        dims = mx - mn
    else:
        dims = Vector((0, 0, 0))
    mats = sorted({m.name for m in bpy.data.materials})
    imgs = sorted({i.name for i in bpy.data.images})
    print(f"ASSET {fname} dims=({dims.x:.2f},{dims.y:.2f},{dims.z:.2f}) meshes={len(meshes)} tris={tris} mats={mats} imgs={imgs}")
