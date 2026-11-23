"""Render a game model as one row of four views (front, left side, back, three-quarter) for
before/after comparison pictures.

    blender -b --python tools/blender/render_model_sheet.py -- --in assets/models/toys/<id>.glb
        --out <png> [--size 400] [--tilt 15] [--bg 0.2]

All four views use the same scale, so models can be compared row by row. Eevee, soft studio
light, Standard view transform (strong colours), on a flat dark grey background. The toy faces
glTF +Z (the kart's forward); "front" looks at its nose.
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--in", dest="src", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--size", type=int, default=400)
ap.add_argument("--tilt", type=float, default=15.0, help="camera height in degrees above the horizon")
ap.add_argument("--bg", type=float, default=0.2, help="background grey (0..1)")
args = ap.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.src))
scene = bpy.context.scene
tops = [o for o in scene.objects if o.parent is None]
meshes = [o for o in scene.objects if o.type == "MESH"]
bpy.context.view_layer.update()
pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
centre = (lo + hi) / 2
radius = max((p - centre).length for p in pts)
step = radius * 2.3

# glTF +Z forward becomes Blender -Y: the nose looks at a camera placed at -Y.
turns = [0, -90, 180, -35]   # front, left side (nose to the left of the picture), back, three-quarter
for i, deg in enumerate(turns):
    pivot = bpy.data.objects.new("turn%d" % i, None)
    scene.collection.objects.link(pivot)
    pivot.location = (i * step, 0, 0)
    pivot.rotation_mode = "XYZ"
    pivot.rotation_euler = (0, 0, math.radians(deg))
    for o in tops:
        if i == 0:
            c = o
        else:
            c = o.copy()
            scene.collection.objects.link(c)
            for ch in o.children_recursive:
                cc = ch.copy()
                scene.collection.objects.link(cc)
                cc.parent = c
        c.location = c.location - Vector((centre.x, centre.y, 0))
        c.parent = pivot

t = math.radians(args.tilt)
cam_data = bpy.data.cameras.new("SheetCam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = step * len(turns)
cam_data.clip_end = 1000
cam = bpy.data.objects.new("SheetCam", cam_data)
scene.collection.objects.link(cam)
look = Vector((0, math.cos(t), -math.sin(t)))
mid = Vector((step * (len(turns) - 1) / 2, 0, (hi.z - lo.z) / 2 + lo.z))
cam.location = mid - look * 50
cam.rotation_mode = "QUATERNION"
cam.rotation_quaternion = look.to_track_quat("-Z", "Y")
scene.camera = cam

for name, energy, rot in (("Key", 2.6, (50, 0, -35)), ("Fill", 0.9, (60, 0, 140)), ("Back", 0.6, (40, 0, 180))):
    light = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
    light.data.energy = energy
    light.data.angle = math.radians(20)
    light.rotation_euler = [math.radians(a) for a in rot]
    scene.collection.objects.link(light)
world = bpy.data.worlds.new("SheetWorld")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45
scene.world = world
scene.render.engine = "BLENDER_EEVEE"
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x = args.size * len(turns)
scene.render.resolution_y = args.size
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
tmp = os.path.abspath(args.out) + ".rgba.png"
scene.render.filepath = tmp
bpy.ops.render.render(write_still=True)

# Flatten onto the grey background.
img = bpy.data.images.load(tmp)
px = list(img.pixels)
g = args.bg
for i in range(0, len(px), 4):
    a = px[i + 3]
    px[i] = px[i] * a + g * (1 - a)
    px[i + 1] = px[i + 1] * a + g * (1 - a)
    px[i + 2] = px[i + 2] * a + g * (1 - a)
    px[i + 3] = 1.0
img.pixels = px
img.filepath_raw = os.path.abspath(args.out)
img.file_format = "PNG"
img.save()
os.remove(tmp)
print("MODEL SHEET:", os.path.abspath(args.out))
