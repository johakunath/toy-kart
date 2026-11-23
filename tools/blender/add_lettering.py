"""Put clean lettering on both sides of a prepared toy model (Pixal3D scrambles or mirrors text).

    blender -b --python tools/blender/add_lettering.py -- --in assets/models/toys/polizei.glb
        --out assets/models/toys/polizei.glb --text POLIZEI --at 0.5 --z 0.23 --width 0.56
        [--panel 20,20,24] [--colour 250,250,250] [--sheet <png>]

The model faces glTF +Z (Blender -Y), origin at the bottom middle, sizes in metres.
--at is the text centre as a fraction of the length from the nose, --z its height. On each side
a thin backing panel (covering the scrambled text in the texture) and raised letters are placed
just outside the body (found with ray casts), reading left to right from either side.
"""
import argparse
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--in", dest="src", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--text", required=True)
ap.add_argument("--at", type=float, default=0.5)
ap.add_argument("--z", type=float, required=True)
ap.add_argument("--width", type=float, required=True, help="text width in metres")
ap.add_argument("--panel", default="20,20,24", help="backing colour, or '' for none")
ap.add_argument("--colour", default="250,250,250")
ap.add_argument("--font", default=r"C:\Windows\Fonts\arialbd.ttf")
args = ap.parse_args(argv)


def srgb(c):
    return tuple(((x / 255.0 + 0.055) / 1.055) ** 2.4 if x / 255.0 > 0.04045 else x / 255.0 / 12.92 for x in c)


def material(name, rgb):
    m = bpy.data.materials.new(name)
    col = (*srgb([int(x) for x in rgb.split(",")]), 1.0)
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.5
    m.diffuse_color = col
    return m


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.src))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
body = meshes[0]
pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
ymin, ymax = min(p.y for p in pts), max(p.y for p in pts)
xmax = max(abs(p.x) for p in pts)
y_mid = ymin + args.at * (ymax - ymin)
depsgraph = bpy.context.evaluated_depsgraph_get()

ink = material("letters", args.colour)
back = material("letter_panel", args.panel) if args.panel else None
font = bpy.data.fonts.load(args.font) if os.path.exists(args.font) else None

for side in (1, -1):
    # The body surface on this side: the outermost hit over the text area.
    surface = 0.0
    for dy in (-0.5, -0.25, 0.0, 0.25, 0.5):
        for dz in (-0.04, 0.0, 0.04):
            origin = Vector((side * (xmax + 1.0), y_mid + dy * args.width, args.z + dz))
            for o in meshes:
                inv = o.matrix_world.inverted()
                hit, loc, _n, _i = o.ray_cast(inv @ origin, inv.to_3x3() @ Vector((-side, 0, 0)), depsgraph=depsgraph)
                if hit:
                    surface = max(surface, abs((o.matrix_world @ loc).x))
    # Text: reads along +Y on the left (+X) side and along -Y on the right side, faces outward.
    basis = Matrix(((0, 0, side), (side, 0, 0), (0, 1, 0))).to_4x4()   # columns: x->(0,s,0), y->(0,0,1), z->(s,0,0)
    cu = bpy.data.curves.new("lettering", "FONT")
    cu.body = args.text
    if font:
        cu.font = font
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = 0.004
    txt = bpy.data.objects.new("lettering", cu)
    bpy.context.scene.collection.objects.link(txt)
    txt.data.materials.append(ink)
    bpy.context.view_layer.update()
    w = txt.dimensions.x
    k = args.width / max(w, 1e-6)
    txt.matrix_world = Matrix.Translation((side * (surface + 0.012), y_mid, args.z)) @ basis @ Matrix.Scale(k, 4)
    bpy.context.view_layer.update()
    height = txt.dimensions.y      # already scaled by k
    if back:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(side * (surface + 0.003), y_mid, args.z))
        p = bpy.context.object
        p.scale = (0.008, args.width + 0.05, height + 0.04)
        p.data.materials.append(back)
        bev = p.modifiers.new("Bevel", "BEVEL")
        bev.width = 0.01
        bev.segments = 2
    print("LETTERING side %+d: surface x %.3f m, text %.2f x %.2f m" % (side, surface, args.width, height))

# Letters and panels become meshes next to the model; export everything.
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.context.scene.objects:
    if o.type == "FONT":
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
if bpy.context.view_layer.objects.active:
    bpy.ops.object.convert(target="MESH")
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.out), export_format="GLB", export_yup=True,
                          export_apply=True, export_animations=False)
print("LETTERING OK:", os.path.abspath(args.out))
