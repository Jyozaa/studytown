import bpy

def toon_material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.roughness = 0.82
    return mat
