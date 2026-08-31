import bpy, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.dirname(__file__))
from common.geometry import rounded_cube, sphere, cylinder
from common.materials import toon_material
from common.palette import PALETTE
from common.export import export_collection

OUT = os.path.join(ROOT, 'public', 'assets', 'generated')

def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.materials: bpy.data.materials.remove(block)

def mats(): return {k: toon_material(k, v) for k,v in PALETTE.items()}

def save(name):
    export_collection(os.path.join(OUT, name + '.glb'))
    clear()

def character(idx):
    m=mats(); skin=toon_material('skin', [(0.67,.34,.18,1),(.88,.55,.36,1),(.32,.13,.07,1)][idx])
    hair=toon_material('hair', [(.045,.02,.015,1),(.55,.10,.035,1),(.025,.012,.035,1)][idx])
    shirt=[m['yellow'],m['blue'],m['red']][idx]
    sphere('head',(0,0,1.45),(.64,.58,.62),skin)
    for x in (-.34,-.1,.14,.38): sphere('hair_clump',(x,0,1.75),(.22,.2,.22),hair)
    for x in (-.22,.22):
        sphere('eye_white',(x,-.55,1.48),(.12,.05,.16),m['cream'])
        sphere('pupil',(x,-.60,1.48),(.055,.025,.08),m['charcoal'])
    rounded_cube('torso',(0,0,.82),(.68,.42,.62),shirt,.16)
    for x in (-.2,.2):
        cylinder('leg',(x,0,.3),.11,.5,m['blue']); rounded_cube('shoe',(x,-.08,.07),(.32,.48,.17),m['cream'],.07)
    for x in (-.43,.43): cylinder('arm',(x,0,.83),.1,.55,shirt)
    save(f'character_0{idx+1}')

def chair():
    m=mats(); rounded_cube('seat',(0,0,.48),(.9,.84,.2),m['orangeWood'],.1); rounded_cube('back',(0,.34,1.0),(.9,.18,1.05),m['orangeWood'],.1)
    for x in (-.35,.35):
        for y in (-.3,.3): cylinder('leg',(x,y,.23),.065,.46,m['warmWood'])
    save('reading_chair')

def desk():
    m=mats(); rounded_cube('top',(0,0,.9),(2.8,1.05,.18),m['warmWood'],.08)
    for x in (-1.1,1.1):
        for y in (-.38,.38): cylinder('leg',(x,y,.45),.08,.9,m['charcoal'])
    rounded_cube('laptop_base',(.35,-.05,1.03),(.75,.5,.06),m['charcoal'],.03)
    rounded_cube('laptop_screen',(.35,.2,1.32),(.75,.06,.55),m['blue'],.03)
    save('study_desk')

def bookcase():
    m=mats(); rounded_cube('back',(0,.16,1.55),(2.4,.3,3.1),m['warmWood'],.08)
    for z in (.15,1.02,1.89,2.76): rounded_cube('shelf',(0,-.04,z),(2.25,.62,.12),m['orangeWood'],.03)
    colors=[m['red'],m['blue'],m['yellow'],m['leaf']]
    for row,z in enumerate((.48,1.35,2.22)):
        for i in range(10): rounded_cube('book',(-.93+i*.205,-.38,z),(.15,.24,.55+(i%3)*.07),colors[(i+row)%4],.02)
    save('bookshelf_tall')

def tree():
    m=mats(); cylinder('trunk',(0,0,1),.28,2,m['warmWood'])
    for x,y,z in ((0,0,2.45),(-.65,0,2.2),(.65,0,2.2),(0,.5,2.1),(0,-.5,2.1)):
        sphere('canopy',(x,y,z),(1.0,.9,.85),m['leaf' if x>=0 else 'deepLeaf'])
    save('tree_large')

def train_seat():
    m=mats()
    for x in (-.75,.75):
        rounded_cube('seat',(x,0,.5),(1.15,.9,.22),m['red'],.12)
        rounded_cube('back',(x,.36,1.1),(1.15,.2,1.25),m['red'],.13)
        cylinder('leg',(x,0,.24),.08,.48,m['charcoal'])
    save('seat_pair')

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for i in range(3): character(i)
    chair(); desk(); bookcase(); tree(); train_seat()
    print('StudyTown assets exported to', OUT)
