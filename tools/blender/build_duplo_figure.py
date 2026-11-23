"""Build a seated Duplo figure from simple shapes, with a preset per toy (after the 23 Nov photos).

    blender -b --python tools/blender/build_duplo_figure.py -- --figure duplojunge
        --out assets/models/toys/duplojunge.glb [--height 0.7] [--blend <file>] [--sheet <png>]

Presets:
  duplojunge     Duplo boy: yellow overalls (bib and legs), light blue sleeves, short dark hair
                 swept up in front. Photos 2026-11-23 11.59.19*, 11.59.20 (front, sides, back).
  bauarbeiterin  Duplo builder woman: white hard hat, brown curls to the neck, light blue shirt,
                 yellow vest, navy trousers, light grey gloves. Photos 2026-11-23 11.59.20 (1..5).

Same body as tools/blender/build_duplo_girl.py (the Duplo girl, kept as it is): the leg piece
turned forward at the hip, feet up, arms forward with C-hands. Building units are about a
centimetre of the real figure; the model is scaled to --height metres (seated height), the origin
is under the bottom (the seat point), and it faces Blender -Y (glTF +Z, the kart's forward).
Colours are pushed to strong toy colours (the photos are dim).
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--figure", required=True, choices=["duplojunge", "bauarbeiterin"])
ap.add_argument("--out", required=True)
ap.add_argument("--height", type=float, default=0.7, help="seated height in metres")
ap.add_argument("--blend", default="", help="also save a .blend for hand edits")
ap.add_argument("--sheet", default="", help="render front, side, back and three-quarter views")
args = ap.parse_args(argv)

PRESETS = {
    "duplojunge": {
        "hair": (58, 32, 20), "skin": (156, 92, 58), "shirt": (70, 170, 240), "torso": (252, 204, 18),
        "torso_back": (252, 204, 18), "legs": (252, 204, 18), "hand": (156, 92, 58),
        "ink": (28, 36, 60), "eye_white": (255, 255, 255), "iris": (90, 50, 25), "pupil": (12, 12, 16),
        "mouth": (120, 30, 30), "cheek": (190, 100, 75), "badge": (240, 240, 235), "badge_ink": (30, 120, 220),
        "helmet": None, "hair_style": "short",
    },
    "bauarbeiterin": {
        "hair": (120, 62, 30), "skin": (236, 172, 128), "shirt": (80, 180, 238), "torso": (80, 180, 238),
        "torso_back": (252, 208, 20), "legs": (26, 42, 112), "hand": (200, 206, 212),
        "ink": (28, 36, 60), "eye_white": (255, 255, 255), "iris": (40, 150, 110), "pupil": (12, 12, 16),
        "mouth": (170, 50, 45), "cheek": (240, 130, 110), "badge": (240, 240, 235), "badge_ink": (40, 40, 50),
        "vest": (252, 208, 20), "helmet": (246, 246, 240), "hair_style": "curls",
    },
}
P = PRESETS[args.figure]


def srgb(c):
    return tuple(((x / 255.0 + 0.055) / 1.055) ** 2.4 if x / 255.0 > 0.04045 else x / 255.0 / 12.92 for x in c)


MATS = {}


def mat(name):
    if name not in MATS:
        m = bpy.data.materials.new("duplo_" + name)
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*srgb(P[name]), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.6 if name == "hair" else 0.35
        m.diffuse_color = (*srgb(P[name]), 1.0)
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
# Toes 1.55 in front of the hip pin: a real seated Duplo leg piece is short and stubby (side photos:
# back of the hip to the toes is about 2.1 units, the torso is 1.1 deep). 2.05 looked too long.
LEG_TIP = 1.55
box(-1.0, 1.0, -0.55, 0.62, 0.0, HIP_TOP, "legs", bevel=0.28)
for side in (-1, 1):
    x0, x1 = (0.06, 1.0) if side > 0 else (-1.0, -0.06)
    box(x0, x1, -LEG_TIP, -0.2, 0.0, 0.92, "legs", bevel=0.18)
    box(x0 + 0.02, x1 - 0.02, -LEG_TIP, -LEG_TIP + 0.62, 0.6, 1.36, "legs", bevel=0.28, segments=4)
    cylinder(side * 1.0, 0.05, 0.5, 0.13, 0.06, "ink", rot=(0, math.pi / 2, 0), verts=12)

# --- Torso ------------------------------------------------------------------------------------
T0, T1 = 0.92, 2.1
TY0, TY1 = -0.55, 0.55
box(-0.98, 0.98, TY0, TY1, T0, T1, "torso", bevel=0.14, top_scale=0.86)
FRONT = TY0 - 0.012
BACK = TY1 + 0.012


def half_width(z):
    return 0.98 - (z - T0) / (T1 - T0) * 0.98 * 0.14


# The back panel (overall back, or the vest seen from behind).
if P["torso_back"] != P["torso"]:
    box(-half_width(1.0) + 0.02, half_width(1.0) - 0.02, BACK - 0.02, BACK + 0.03, 0.95, 2.02, "torso_back",
        bevel=0.0, top_scale=0.86)

if args.figure == "duplojunge":
    # Overall bib: shirt-blue shoulders above it, two buttons, a round badge and a phone in the pocket.
    for side in (-1, 1):
        box(side * 0.55 - 0.32, side * 0.55 + 0.32, FRONT - 0.03, FRONT + 0.02, 1.86, 2.08, "shirt", bevel=0.0)
        box(side * 0.55 - 0.32, side * 0.55 + 0.32, BACK - 0.02, BACK + 0.03, 1.86, 2.08, "shirt", bevel=0.0)
        cylinder(side * 0.5, FRONT - 0.04, 1.72, 0.07, 0.05, "ink", rot=(math.pi / 2, 0, 0), verts=12)
    cylinder(-0.45, FRONT - 0.04, 1.38, 0.24, 0.04, "badge", rot=(math.pi / 2, 0, 0), verts=20)
    cylinder(-0.45, FRONT - 0.06, 1.38, 0.15, 0.04, "badge_ink", rot=(math.pi / 2, 0, 0), verts=16)
    box(0.25, 0.62, FRONT - 0.05, FRONT + 0.02, 1.1, 1.55, "ink", bevel=0.0)      # walkie-talkie
    box(0.3, 0.57, FRONT - 0.065, FRONT + 0.02, 1.15, 1.5, "badge", bevel=0.0)
    tube([(x, FRONT - 0.02, 1.2) for x in (-0.75, 0.75)], 0.03, "ink")           # belt line
else:
    # Shirt in the middle, yellow vest panels left and right, a name badge.
    for side in (-1, 1):
        box(side * 0.62 - 0.33, side * 0.62 + 0.33, FRONT - 0.03, FRONT + 0.02, 0.96, 1.95, "vest",
            bevel=0.0, top_scale=0.9)
        box(side * 0.98 - side * 0.04 - 0.03, side * 0.98 - side * 0.04 + 0.03, -0.5, 0.5, 0.96, 1.9, "vest",
            bevel=0.0)
    box(0.04, 0.26, FRONT - 0.05, FRONT + 0.02, 1.35, 1.62, "badge", bevel=0.0)
    box(-0.26, -0.04, FRONT - 0.05, FRONT + 0.02, 1.35, 1.62, "badge_ink", bevel=0.0)
    tube([(x, FRONT - 0.02, 2.0 - 0.18 * math.cos(x / 0.35 * math.pi / 2)) for x in
          [-0.35 + 0.0875 * i for i in range(9)]], 0.035, "ink")                  # collar

# --- Arms: forward to the steering wheel, C-shaped Duplo hands ----------------------------------
for side in (-1, 1):
    shoulder = Vector((side * 0.92, 0.0, 1.82))
    elbow = Vector((side * 1.08, -0.75, 1.52))
    ball(*shoulder, 0.33, "shirt", seg=14, rings=8)
    rod(shoulder, elbow, 0.3, "shirt")
    ball(*elbow, 0.3, "shirt", seg=12, rings=7)
    wrist = elbow + Vector((0.0, -0.32, -0.02))
    rod(elbow, wrist, 0.17, "hand", verts=12)
    c = wrist + Vector((0, -0.18, 0))
    pts = []
    for i in range(11):
        a = math.radians(40 + i * 28)
        pts.append((c.x - side * 0.2 * math.cos(a), c.y - 0.04, c.z + 0.2 * math.sin(a)))
    tube(pts, 0.12, "hand")

# --- Neck and head --------------------------------------------------------------------------
cylinder(0, 0, 2.18, 0.42, 0.2, "skin", verts=20)
HC = 2.98
HR = 0.88
cylinder(0, 0, HC, HR, 1.5, "skin", bevel=0.34, verts=32)


def on_head(x, z, out=0.0):
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
    # eyebrows
    brow = []
    for k in range(5):
        bx = x - 0.16 + k * 0.08
        bp, _ = on_head(bx, EYE_Z + 0.3 + 0.03 * math.sin(k / 4 * math.pi), 0.02)
        brow.append(tuple(bp))
    tube(brow, 0.03, "hair")
mouth = []
for i in range(9):
    x = -0.26 + i * 0.065
    p, _ = on_head(x, 2.6 - 0.11 * math.cos(x / 0.26 * math.pi / 2), 0.01)
    mouth.append(tuple(p))
tube(mouth, 0.045, "mouth")


def fib_balls(c, r, n, inset, keep, rad):
    """Small balls half sunk into an ellipsoid, evenly spread (Fibonacci points)."""
    out = []
    for i in range(n):
        zz = 1 - 2 * (i + 0.5) / n
        rr = math.sqrt(1 - zz * zz)
        a = i * math.pi * (3 - math.sqrt(5))
        u = Vector((rr * math.cos(a), rr * math.sin(a), zz))
        p = Vector((c[0] + r[0] * u.x, c[1] + r[1] * u.y, c[2] + r[2] * u.z))
        nrm = Vector((u.x / r[0], u.y / r[1], u.z / r[2])).normalized()
        p -= nrm * inset
        if keep(p):
            out.append((p.x, p.y, p.z, rad))
    return out


if P["hair_style"] == "short":
    # Short dark hair: a smooth cap, swept up into a wave over the forehead, short at the neck.
    ball(0, 0.12, 3.4, 1.0, "hair", scale=(0.98, 0.98, 0.62), seg=24, rings=14)
    ball(0, 0.32, 3.05, 1.0, "hair", scale=(0.93, 0.62, 0.62), seg=24, rings=14)
    for (x, y, z, r, sx) in ((-0.42, -0.62, 3.62, 0.36, 1.3), (0.18, -0.66, 3.7, 0.4, 1.4),
                             (0.62, -0.5, 3.6, 0.3, 1.1)):
        ball(x, y, z, r, "hair", scale=(sx, 0.9, 0.75), seg=14, rings=8)
    for side in (-1, 1):
        ball(side * 0.86, -0.25, 3.18, 0.22, "hair", scale=(0.7, 1.0, 1.4), seg=10, rings=6)   # sideburns
else:
    # Brown curls around the head down to the neck, a white hard hat with a brim on top.
    def keep(p):
        face = p.y < -0.3 and abs(p.x) < 0.8
        return not face and 2.25 < p.z < 3.5
    curls = fib_balls((0, 0.2, 2.95), (1.05, 0.85, 0.9), 70, 0.1, keep, 0.3)
    for side in (-1, 1):
        curls += [(side * 0.92, -0.38, 3.2, 0.26), (side * 0.98, -0.22, 2.9, 0.27), (side * 0.95, -0.1, 2.6, 0.28),
                  (side * 0.8, 0.2, 2.35, 0.28)]
    for (x, y, z, r) in curls:
        ball(x, y, z, r, "hair", seg=10, rings=6)
    ball(0, 0.08, 3.5, 1.0, "helmet", scale=(1.04, 1.04, 0.72), seg=28, rings=14)              # dome
    cylinder(0, 0.08, 3.48, 1.12, 0.1, "helmet", bevel=0.03, verts=32)                          # brim band
    ball(0, -0.9, 3.5, 0.5, "helmet", scale=(0.9, 0.5, 0.12), seg=16, rings=6)                 # front peak

# --- Join, scale to the seated height, export -------------------------------------------------
for o in bpy.context.scene.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = bpy.context.scene.objects[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
obj.name = args.figure
obj.data.name = args.figure
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
print("DUPLO FIGURE OK: %s, %d triangles, %.2f x %.2f x %.2f m (w x d x h)" % (
    out, tris, size.x, size.y, size.z))

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
    print("DUPLO FIGURE SHEET:", scene.render.filepath)
