"""Build the Duplo girl (Duplo-Mädchen, driver id paper_junge) from simple shapes, after the photos
photos/toys/WhatsApp Image 2026-11-21 at 17.04.08*.jpeg and 17.04.09*.jpeg (front, side, back).

    blender -b --python tools/blender/build_duplo_girl.py -- --out assets/models/toys/junge.glb
        [--height 0.7] [--blend art/models/junge_edit.blend] [--sheet <png>]

She is a Duplo child figure sitting down, the way a Duplo figure sits: the leg piece turned
forward at the hip, feet pointing up. Arms reach forward to the steering wheel.
Building units are about a centimetre of the real figure; the model is then scaled to --height
metres (seated height, like the other toy drivers), the origin is under her bottom (the seat
point), and she faces Blender -Y (glTF +Z, the kart's forward).
Unlike prepare_toy_model.py this does not centre the bounding box: her legs stick out forward,
and the seat point has to stay under her bottom.
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
ap.add_argument("--height", type=float, default=0.7, help="seated height in metres")
ap.add_argument("--blend", default="", help="also save a .blend for hand edits")
ap.add_argument("--sheet", default="", help="render front, side, back and three-quarter views")
args = ap.parse_args(argv)


def srgb(c):
    return tuple(((x / 255.0 + 0.055) / 1.055) ** 2.4 if x / 255.0 > 0.04045 else x / 255.0 / 12.92 for x in c)


# Strong toy colours (the photo's pale blue is pushed toward a clear sky blue).
COLOURS = {
    "hair": (74, 40, 20), "skin": (218, 140, 88), "shirt": (246, 246, 242), "stripe": (0, 165, 215),
    "ink": (28, 36, 60), "legs": (96, 168, 245), "eye_white": (255, 255, 255), "iris": (30, 120, 230),
    "pupil": (12, 12, 16), "mouth": (150, 40, 34), "cheek": (240, 120, 105),
}
MATS = {}


def mat(name):
    if name not in MATS:
        m = bpy.data.materials.new("duplo_" + name)
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*srgb(COLOURS[name]), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.6 if name == "hair" else 0.35
        m.diffuse_color = (*srgb(COLOURS[name]), 1.0)  # viewport and the check sheet
        MATS[name] = m
    return MATS[name]


def finish(obj, colour, bevel=0.0, segments=3):
    obj.data.materials.append(mat(colour))
    if bevel:
        b = obj.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = segments
        b.limit_method = "ANGLE"
    return obj


def mesh_object(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def box(x0, x1, y0, y1, z0, z1, colour, bevel=0.12, top_scale=1.0, segments=3):
    """An axis-aligned block; top_scale < 1 narrows the top in x (a tapered torso)."""
    cx = (x0 + x1) / 2
    hx = (x1 - x0) / 2
    tx = hx * top_scale
    p = [(cx - hx, y0, z0), (cx + hx, y0, z0), (cx + hx, y1, z0), (cx - hx, y1, z0),
         (cx - tx, y0, z1), (cx + tx, y0, z1), (cx + tx, y1, z1), (cx - tx, y1, z1)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return finish(mesh_object("box", p, f), colour, bevel, segments)


def ball(x, y, z, r, colour, scale=(1, 1, 1), rot_z=0.0, seg=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=(x, y, z))
    o = bpy.context.object
    o.scale = scale
    o.rotation_euler = (0, 0, rot_z)
    return finish(o, colour)


def cylinder(x, y, z, r, depth, colour, rot=(0, 0, 0), bevel=0.0, verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=(x, y, z), rotation=rot)
    return finish(bpy.context.object, colour, bevel, 4)


def tube(points, r, colour):
    """A round tube along a polyline (mouth, hands); becomes a mesh when everything is joined."""
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 2
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for pt, co in zip(sp.points, points):
        pt.co = (*co, 1.0)
    o = bpy.data.objects.new("tube", cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat(colour))
    return o


def rod(a, b, r, colour, verts=16):
    """A cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return finish(o, colour)


bpy.ops.wm.read_factory_settings(use_empty=True)

# --- Leg piece, turned forward at the hip (seated) --------------------------------------------
HIP_TOP = 1.0
box(-1.0, 1.0, -0.55, 0.62, 0.0, HIP_TOP, "legs", bevel=0.28)          # hip block, round at the back
for side in (-1, 1):
    x0, x1 = (0.06, 1.0) if side > 0 else (-1.0, -0.06)
    box(x0, x1, -2.05, -0.2, 0.0, 0.92, "legs", bevel=0.18)             # thigh + shin, pointing forward
    box(x0 + 0.02, x1 - 0.02, -2.05, -1.35, 0.6, 1.42, "legs", bevel=0.3, segments=4)  # shoe, toes up
    cylinder(side * 1.0, 0.05, 0.5, 0.13, 0.06, "ink", rot=(0, math.pi / 2, 0), verts=12)  # hip pin hole

# --- Torso: white shirt, striped print on the front, short white sleeves ----------------------
T0, T1 = 0.92, 2.1
TY0, TY1 = -0.55, 0.55
box(-0.98, 0.98, TY0, TY1, T0, T1, "shirt", bevel=0.14, top_scale=0.86)
FRONT = TY0 - 0.012
for k in range(5):                                                      # teal stripes
    z = 1.08 + k * 0.2
    half = 0.88 - (z - T0) / (T1 - T0) * 0.98 * 0.14 - 0.06
    box(-half, half, FRONT - 0.03, FRONT + 0.02, z, z + 0.1, "stripe", bevel=0.0)
box(0.22, 0.66, FRONT - 0.06, FRONT + 0.02, 1.12, 1.52, "ink", bevel=0.0)      # pocket outline
box(0.27, 0.61, FRONT - 0.075, FRONT + 0.02, 1.17, 1.47, "shirt", bevel=0.0)   # pocket
tube([(x, FRONT - 0.02, 2.02 - 0.12 * math.cos(x / 0.4 * math.pi / 2)) for x in
      [-0.4 + 0.1 * i for i in range(9)]], 0.035, "ink")                 # neckline

# --- Arms: forward to the steering wheel, C-shaped Duplo hands ----------------------------------
for side in (-1, 1):
    shoulder = Vector((side * 0.92, 0.0, 1.82))
    elbow = Vector((side * 1.08, -0.75, 1.45))
    ball(*shoulder, 0.33, "shirt", seg=14, rings=8)
    rod(shoulder, elbow, 0.3, "shirt")
    ball(*elbow, 0.3, "shirt", seg=12, rings=7)
    wrist = elbow + Vector((side * 0.0, -0.32, -0.02))
    rod(elbow, wrist, 0.17, "skin", verts=12)
    # the C hand: an open ring in the x-z plane... opening facing inward
    c = wrist + Vector((0, -0.18, 0))
    pts = []
    for i in range(11):
        a = math.radians(40 + i * 28)  # 280 degrees of ring, open toward the middle
        pts.append((c.x - side * 0.2 * math.cos(a), c.y - 0.04, c.z + 0.2 * math.sin(a)))
    tube(pts, 0.12, "skin")

# --- Neck and head --------------------------------------------------------------------------
cylinder(0, 0, 2.18, 0.42, 0.2, "skin", verts=20)
HC = 2.98       # head centre
HR = 0.88       # head radius
cylinder(0, 0, HC, HR, 1.5, "skin", bevel=0.34, verts=32)


def on_head(x, z, out=0.0):
    """A point on the front of the head cylinder at height z, pushed `out` along the normal."""
    y = -math.sqrt(max(HR * HR - x * x, 0.0))
    n = Vector((x, y, 0)).normalized()
    return Vector((x, y, z)) + n * out, math.atan2(x, -y)


EYE_Z = 2.98
for side in (-1, 1):
    x = side * 0.34
    p, rz = on_head(x, EYE_Z, -0.02)
    ball(p.x, p.y, p.z, 0.2, "eye_white", scale=(0.78, 0.32, 1.0), rot_z=rz)
    p, rz = on_head(x, EYE_Z - 0.02, 0.02)
    ball(p.x, p.y, p.z, 0.15, "iris", scale=(0.85, 0.3, 1.0), rot_z=rz)
    p, rz = on_head(x, EYE_Z - 0.03, 0.05)
    ball(p.x, p.y, p.z, 0.08, "pupil", scale=(0.9, 0.3, 1.0), rot_z=rz, seg=10, rings=6)
    p, rz = on_head(x + side * 0.05, EYE_Z + 0.06, 0.08)
    ball(p.x, p.y, p.z, 0.038, "eye_white", scale=(1, 0.4, 1), rot_z=rz, seg=8, rings=5)
    p, rz = on_head(side * 0.56, 2.68, -0.03)
    ball(p.x, p.y, p.z, 0.13, "cheek", scale=(1.0, 0.25, 0.7), rot_z=rz, seg=10, rings=6)
mouth = []
for i in range(9):
    x = -0.24 + i * 0.06
    p, _ = on_head(x, 2.62 - 0.09 * math.cos(x / 0.24 * math.pi / 2), 0.01)
    mouth.append(tuple(p))
tube(mouth, 0.04, "mouth")

# --- Hair: a dark curly cap, framing the face ------------------------------------------------
CAPS = [((0, 0.16, 3.36), (1.0, 1.0, 0.7)),     # top of the head
        ((0, 0.36, 2.95), (0.95, 0.66, 0.8))]   # back of the head, down to the neck
for c, r in CAPS:
    ball(*c, 1.0, "hair", scale=r, seg=24, rings=14)


def is_face(x, y, z):
    return y < -0.3 and abs(x) < 0.8 and z < 3.42


def inside(p, cap, margin):
    c, r = cap
    return sum(((p[i] - c[i]) / r[i]) ** 2 for i in range(3)) < margin


# Wavy curls: small balls half sunk into the cap, evenly spread (Fibonacci points).
curls = []
for ci, (c, r) in enumerate(CAPS):
    n = 46
    for i in range(n):
        zz = 1 - 2 * (i + 0.5) / n
        rr = math.sqrt(1 - zz * zz)
        a = i * math.pi * (3 - math.sqrt(5))
        u = Vector((rr * math.cos(a), rr * math.sin(a), zz))
        p = Vector((c[0] + r[0] * u.x, c[1] + r[1] * u.y, c[2] + r[2] * u.z))
        nrm = Vector((u.x / r[0], u.y / r[1], u.z / r[2])).normalized()
        p -= nrm * 0.14
        if is_face(p.x, p.y, p.z) or p.z < 2.35:
            continue
        if any(inside(p, other, 0.8) for oi, other in enumerate(CAPS) if oi != ci):
            continue
        curls.append((p.x, p.y, p.z, 0.31))
# fringe over the forehead and locks beside the cheeks
for x in (-0.6, -0.3, 0.0, 0.3, 0.6):
    curls.append((x, -0.74 + 0.15 * abs(x), 3.55 - 0.1 * abs(x) / 0.6, 0.25))
for side in (-1, 1):
    curls.append((side * 0.88, -0.36, 3.25, 0.25))
    curls.append((side * 0.92, -0.22, 2.95, 0.24))
for (x, y, z, r) in curls:
    ball(x, y, z, r, "hair", seg=10, rings=6)

# --- Join, scale to the seated height, export -------------------------------------------------
for o in bpy.context.scene.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = bpy.context.scene.objects[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
obj.name = "junge"
obj.data.name = "junge"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")
top = max((obj.matrix_world @ v.co).z for v in obj.data.vertices)
k = args.height / top
obj.scale = (k, k, k)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
size = hi - lo

out = os.path.abspath(args.out)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=True,
                          export_animations=False)
if args.blend:
    os.makedirs(os.path.dirname(os.path.abspath(args.blend)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.blend), compress=True)
print("DUPLO GIRL OK: %s, %d triangles, %.2f x %.2f x %.2f m (w x d x h), forward reach %.2f m" % (
    out, tris, size.x, size.y, size.z, -lo.y))

if args.sheet:
    scene = bpy.context.scene
    step = max(size.x, size.y, size.z) * 1.3
    turns = [0, -90, 180, -35]
    for i, deg in enumerate(turns):
        o = obj if i == 0 else obj.copy()
        if i:
            scene.collection.objects.link(o)
        o.location = (i * step, 0, 0)
        o.rotation_mode = "XYZ"
        o.rotation_euler = (0, 0, math.radians(deg))
    cam_data = bpy.data.cameras.new("SheetCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = step * len(turns)
    cam = bpy.data.objects.new("SheetCam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (step * (len(turns) - 1) / 2, -20, size.z / 2)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 400 * len(turns)
    scene.render.resolution_y = 400
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("SheetWorld")
    scene.render.filepath = os.path.abspath(args.sheet)
    bpy.ops.render.render(write_still=True)
    print("DUPLO GIRL SHEET:", scene.render.filepath)
