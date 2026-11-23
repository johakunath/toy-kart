"""Render a game model as a reference picture for FLUX (menu portraits of toy vehicles).

    blender -b --python tools/blender/render_model_ref.py -- --in assets/models/toys/<id>.glb
        --out <png> [--turn -35] [--tilt 18] [--size 768]

A three-quarter view from the front left and a little above, on white, lit like a toy photo
(Eevee, soft studio light, Standard view transform so the colours stay strong). A photo shows a
built Duplo toy only from one side and FLUX then turns the front view into a brick pile; the
model render shows wings, tail and wheels at once.
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
ap.add_argument("--turn", type=float, default=-35.0, help="degrees the toy turns; 0 = nose to camera")
ap.add_argument("--tilt", type=float, default=18.0, help="camera height in degrees above the horizon")
ap.add_argument("--size", type=int, default=768)
args = ap.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.src))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
root = bpy.data.objects.new("Turn", None)
bpy.context.scene.collection.objects.link(root)
for o in bpy.context.scene.objects:
    if o.parent is None and o is not root:
        o.parent = root
root.rotation_mode = "XYZ"
root.rotation_euler = (0, 0, math.radians(args.turn))
bpy.context.view_layer.update()

# Frame the visible vertices, not the bounding box: a turned plane is a cross, its box is far wider.
pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
t = math.radians(args.tilt)
look = Vector((0, math.cos(t), -math.sin(t)))           # from -Y, a little above
right = Vector((1, 0, 0))
up = right.cross(look)
xs, ys = [p.dot(right) for p in pts], [p.dot(up) for p in pts]
mid = right * (min(xs) + max(xs)) / 2 + up * (min(ys) + max(ys)) / 2
depth = sum(p.dot(look) for p in pts) / len(pts)

scene = bpy.context.scene
cam_data = bpy.data.cameras.new("RefCam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.12
cam_data.clip_end = 1000
cam = bpy.data.objects.new("RefCam", cam_data)
scene.collection.objects.link(cam)
cam.location = mid + look * (depth - 50)
cam.rotation_mode = "QUATERNION"
cam.rotation_quaternion = look.to_track_quat("-Z", "Y")
scene.camera = cam

for name, energy, rot in (("Key", 2.6, (50, 0, -35)), ("Fill", 0.8, (60, 0, 140))):
    light = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
    light.data.energy = energy
    light.data.angle = math.radians(20)
    light.rotation_euler = [math.radians(a) for a in rot]
    scene.collection.objects.link(light)
world = bpy.data.worlds.new("RefWorld")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45
scene.world = world
scene.render.engine = "BLENDER_EEVEE"
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x = scene.render.resolution_y = args.size
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = os.path.abspath(args.out)
bpy.ops.render.render(write_still=True)
print("MODEL REF:", scene.render.filepath)
