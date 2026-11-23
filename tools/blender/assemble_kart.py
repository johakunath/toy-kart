"""Turn a one-piece toy model (Pixal3D, prepared) into a kart model the game can animate: the toy
becomes the mesh "body", and four separate wheels "wheel-front-left" ... (origin at the wheel
centre, they spin and the front ones steer) are added where the toy's own wheels are.

    blender -b --python tools/blender/assemble_kart.py -- --in art/models/zug_local_fix.glb
        --out assets/models/toys/zug.glb --wheels 0.2,0.8 --radius 0.1 --track 0.3 --width 0.08
        [--colour 150,155,165] [--hub 246,246,240] [--seat 0.5]

--wheels  front and back axle, as fractions of the length from the nose
--track   half the distance between left and right wheel centres (metres)
--seat    where the driver sits, as a fraction of the length from the nose; the floor height
          there is found by casting a ray down inside the toy
Prints "SEAT: seat_position = Vector3(...)" for the kart .tres (Godot: +Y up, +Z forward).
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
ap.add_argument("--wheels", default="0.2,0.8")
ap.add_argument("--radius", type=float, default=0.1)
ap.add_argument("--track", type=float, default=0.3)
ap.add_argument("--width", type=float, default=0.08)
ap.add_argument("--colour", default="150,155,165")
ap.add_argument("--hub", default="246,246,240")
ap.add_argument("--seat", type=float, default=0.5)
args = ap.parse_args(argv)


def srgb(c):
    return tuple(((x / 255.0 + 0.055) / 1.055) ** 2.4 if x / 255.0 > 0.04045 else x / 255.0 / 12.92 for x in c)


def material(name, rgb):
    m = bpy.data.materials.new(name)
    col = (*srgb([int(x) for x in rgb.split(",")]), 1.0)
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = col
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.4
    m.diffuse_color = col
    return m


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.src))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
for o in list(bpy.context.scene.objects):
    if o.type == "EMPTY":
        bpy.data.objects.remove(o)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
body.name = "body"
body.data.name = "body"
pts = [body.matrix_world @ v.co for v in body.data.vertices]
ymin, ymax = min(p.y for p in pts), max(p.y for p in pts)
length = ymax - ymin

tyre = material("wheel", args.colour)
hub = material("hub", args.hub)
fu, bu = (float(x) for x in args.wheels.split(","))
wheels = []
for name, frac, side in (("wheel-front-left", fu, 1), ("wheel-front-right", fu, -1),
                         ("wheel-back-left", bu, 1), ("wheel-back-right", bu, -1)):
    y = ymin + frac * length           # the nose is at -Y
    centre = Vector((side * args.track, y, args.radius))
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=args.radius, depth=args.width, location=centre,
                                        rotation=(0, math.pi / 2, 0))
    t = bpy.context.object
    t.data.materials.append(tyre)
    bev = t.modifiers.new("Bevel", "BEVEL")
    bev.width = args.radius * 0.18
    bev.segments = 3
    bev.limit_method = "ANGLE"
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=args.radius * 0.6, depth=args.width * 0.3,
                                        location=centre + Vector((side * args.width * 0.4, 0, 0)),
                                        rotation=(0, math.pi / 2, 0))
    h = bpy.context.object
    h.data.materials.append(hub)
    bpy.ops.object.select_all(action="DESELECT")
    t.select_set(True)
    h.select_set(True)
    bpy.context.view_layer.objects.active = t
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    w = bpy.context.view_layer.objects.active
    w.name = name
    w.data.name = name
    bpy.context.scene.cursor.location = centre
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    w.rotation_mode = "XYZ"
    wheels.append(w)

# Floor under the seat: cast a ray down from just under the top, in the middle of the toy.
depsgraph = bpy.context.evaluated_depsgraph_get()
seat_y = ymin + args.seat * length
top = max(p.z for p in pts)
floor = 0.0
origin = Vector((0, seat_y, top - 0.02))
for _ in range(6):
    hit, loc, normal, *_rest = body.ray_cast(origin, Vector((0, 0, -1)), depsgraph=depsgraph)
    if not hit:
        break
    if normal.z > 0.5:
        floor = loc.z
        break
    origin = loc - Vector((0, 0, 0.005))   # went through a roof edge or a wall: keep going down

out = os.path.abspath(args.out)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=True,
                          export_animations=False)
print("ASSEMBLE OK: %s, length %.2f m" % (out, length))
print("SEAT: seat_position = Vector3(0, %.2f, %.2f)" % (floor, -seat_y))
