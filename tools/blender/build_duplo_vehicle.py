"""Build a Duplo vehicle as a kart model (drivers sit in it), after the 23 Nov photos.

    blender -b --python tools/blender/build_duplo_vehicle.py -- --vehicle krankenwagen
        --out assets/models/toys/krankenwagen.glb [--length 1.5] [--sheet <png>] [--blend <file>]

Vehicles:
  krankenwagen  Duplo ambulance/van: white body, orange-red base, red-white stripes and a grille
                at the front, black tyres with white hubs. The flip-up roof is left off (open top),
                so the driver is seen sitting inside. Photos 2026-11-23 11.59.28 (11), 11.59.29*.
  zug           Duplo train car: lime green body with window frames and an open roof, navy base,
                railway logo and lamps at the front. Photos 2026-11-23 11.59.26*, 11.59.27, (1).

Built in Duplo units (one stud = 1, a brick layer = 1.2), then scaled to --length metres nose to
tail. Kenney-style node names so the game animates it: one mesh "body" (bounces and leans) and
four wheels "wheel-front-left" ... (spin about X, front ones steer), each with its origin at the
wheel centre. Faces Blender -Y (glTF +Z, the kart's forward); origin under the middle at the
ground. Prints the seat point for the kart .tres (Godot kart space: +Y up, +Z forward).
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--vehicle", required=True, choices=["krankenwagen", "zug"])
ap.add_argument("--out", required=True)
ap.add_argument("--length", type=float, default=1.5, help="nose to tail in metres")
ap.add_argument("--blend", default="")
ap.add_argument("--sheet", default="")
args = ap.parse_args(argv)

STUD_R, STUD_H = 0.3, 0.18
COLOURS = {
    "white": (246, 246, 240), "base": (236, 72, 20), "red": (220, 30, 30), "tyre": (30, 30, 34),
    "hub": (246, 246, 240), "dark": (40, 44, 56), "lamp": (255, 250, 210), "glass": (150, 210, 245),
    "blue": (30, 110, 230), "seat": (220, 40, 30),
    "lime": (160, 222, 40), "navy": (22, 34, 92), "grey": (150, 155, 165), "logo": (24, 30, 60),
    "yellow": (255, 210, 0),
}
MATS = {}


def srgb(c):
    return tuple(((x / 255.0 + 0.055) / 1.055) ** 2.4 if x / 255.0 > 0.04045 else x / 255.0 / 12.92 for x in c)


def mat(name):
    if name not in MATS:
        m = bpy.data.materials.new("duplo_" + name)
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*srgb(COLOURS[name]), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.6 if name == "tyre" else 0.3
        m.diffuse_color = (*srgb(COLOURS[name]), 1.0)
        MATS[name] = m
    return MATS[name]


BODY = []     # parts joined into "body"
L = 8.5       # set per vehicle before building


def W(u, v, z):
    """Vehicle coordinates (u from the nose back, v across, z up) to Blender (front = -Y)."""
    return Vector((v, u - L / 2, z))


def finish(obj, colour, bevel=0.0, segments=2):
    obj.data.materials.append(mat(colour))
    if bevel:
        b = obj.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = segments
        b.limit_method = "ANGLE"
    BODY.append(obj)
    return obj


def box(u0, u1, v0, v1, z0, z1, colour, bevel=0.12, segments=2):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = (abs(v1 - v0), abs(u1 - u0), abs(z1 - z0))
    o.location = W((u0 + u1) / 2, (v0 + v1) / 2, (z0 + z1) / 2)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, colour, bevel, segments)


def disc(u, v, z, r, depth, colour, axis="v", verts=20, bevel=0.0):
    rot = {"v": (0, math.pi / 2, 0), "u": (math.pi / 2, 0, 0), "z": (0, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=W(u, v, z), rotation=rot)
    return finish(bpy.context.object, colour, bevel)


def studs(u0, v0, z, nu, nv, colour):
    for i in range(nu):
        for j in range(nv):
            disc(u0 + i + 0.5, v0 + j + 0.5, z + STUD_H / 2, STUD_R, STUD_H, colour, axis="z", verts=12)


WHEELS = []


def wheel(name, u, v, r, width, tyre, hub, hub_r):
    """A wheel as its own object, origin at its centre (the game spins it about X)."""
    side = 1 if v > 0 else -1
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=r, depth=width, location=W(u, v, r),
                                        rotation=(0, math.pi / 2, 0))
    t = bpy.context.object
    t.data.materials.append(mat(tyre))
    b = t.modifiers.new("Bevel", "BEVEL")
    b.width = r * 0.18
    b.segments = 3
    b.limit_method = "ANGLE"
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=hub_r, depth=width * 0.3,
                                        location=W(u, v + side * width * 0.4, r), rotation=(0, math.pi / 2, 0))
    h = bpy.context.object
    h.data.materials.append(mat(hub))
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=hub_r * 0.35, depth=width * 0.3,
                                        location=W(u, v + side * width * 0.5, r), rotation=(0, math.pi / 2, 0))
    c = bpy.context.object
    c.data.materials.append(mat(tyre if hub != tyre else "grey"))
    bpy.ops.object.select_all(action="DESELECT")
    for o in (t, h, c):
        o.select_set(True)
    bpy.context.view_layer.objects.active = t
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.name = name
    # origin to the wheel centre
    centre = W(u, v, r)
    bpy.context.scene.cursor.location = centre
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    WHEELS.append(o)
    return o


bpy.ops.wm.read_factory_settings(use_empty=True)

if args.vehicle == "krankenwagen":
    L = 8.5
    HW = 2.0                    # half width of the body
    FLOOR = 1.15                # top of the red floor (the seat)
    SILL = 2.75                 # top of the white walls (roof left off)
    # base: orange-red chassis, wider at the bumpers
    box(0.0, L, -HW, HW, 0.45, 1.25, "base", bevel=0.3, segments=3)
    box(-0.1, 0.6, -HW + 0.1, HW - 0.1, 0.45, 1.1, "base", bevel=0.25)          # front bumper
    box(L - 0.6, L + 0.15, -HW + 0.1, HW - 0.1, 0.45, 1.1, "base", bevel=0.25)  # back bumper
    box(L - 0.1, L + 0.45, -0.3, 0.3, 0.55, 0.95, "base", bevel=0.1)            # tow hitch
    # white lower body: bonnet at the front, walls round an open seat well
    box(0.0, 2.4, -HW, HW, 1.2, 2.45, "white", bevel=0.45, segments=4)          # bonnet, round nose
    box(2.2, L, -HW, -HW + 0.35, 1.2, SILL, "white", bevel=0.15)                # right wall
    box(2.2, L, HW - 0.35, HW, 1.2, SILL, "white", bevel=0.15)                  # left wall
    box(L - 0.4, L, -HW, HW, 1.2, SILL, "white", bevel=0.2)                     # back wall
    box(2.2, 2.6, -HW, HW, 1.2, SILL, "white", bevel=0.12)                      # dashboard wall
    box(2.6, L - 0.4, -HW + 0.35, HW - 0.35, FLOOR - 0.2, FLOOR, "seat", bevel=0.0)  # red floor
    studs(5.4, -1.0, FLOOR, 2, 2, "seat")                                       # studs behind the seat
    # low windscreen on the dashboard, a blue light on top
    box(2.25, 2.45, -HW + 0.3, HW - 0.3, SILL, SILL + 0.75, "glass", bevel=0.08)
    box(2.2, 2.5, -HW + 0.15, HW - 0.15, SILL + 0.75, SILL + 0.95, "white", bevel=0.08)
    box(2.2, 2.5, -0.55, 0.55, SILL + 0.95, SILL + 1.3, "blue", bevel=0.12)
    # front face: red-white stripes over the grille, headlights, the emblem
    for k in range(7):
        v = -1.7 + k * 0.52
        box(-0.06, 0.25, v, v + 0.26, 1.95, 2.25, "red", bevel=0.0)
    box(-0.06, 0.25, -0.9, 0.9, 1.35, 1.75, "dark", bevel=0.1)                  # grille
    for v in (-1.35, 1.35):
        disc(-0.04, v, 1.55, 0.27, 0.2, "lamp", axis="u")
    disc(-0.05, 0.0, 2.1, 0.24, 0.2, "blue", axis="u")
    # red-white side stripe and side windows' lower edge
    for side in (-1, 1):
        v0 = side * HW - (0.02 if side > 0 else -0.02)
        for k in range(9):
            u = 2.7 + k * 0.62
            box(u, u + 0.31, v0 - 0.03, v0 + 0.03, 2.25, 2.5, "red", bevel=0.0)
        box(5.0, 6.2, v0 - 0.03, v0 + 0.03, 1.5, 2.0, "red", bevel=0.0)        # red cross bar
        box(5.35, 5.85, v0 - 0.03, v0 + 0.03, 1.3, 2.2, "red", bevel=0.0)
    for (name, u, v) in (("wheel-front-left", 1.9, 1.95), ("wheel-front-right", 1.9, -1.95),
                         ("wheel-back-left", 6.6, 1.95), ("wheel-back-right", 6.6, -1.95)):
        wheel(name, u, v, 0.85, 0.7, "tyre", "hub", 0.55)
    SEAT = (4.6, FLOOR)         # (u, z) of the driver's bottom
else:
    L = 8.0
    HW = 2.0
    FLOOR = 1.3
    TOP = 3.9                   # top of the window frames (no roof)
    # navy base with small grey train wheels and buffers
    box(0.1, L - 0.1, -HW + 0.15, HW - 0.15, 0.35, 1.35, "navy", bevel=0.25, segments=3)
    for v in (-1.0, 1.0):
        disc(-0.05, v, 0.85, 0.28, 0.3, "grey", axis="u")                       # buffers / lamps
    box(L - 0.2, L + 0.35, -0.25, 0.25, 0.45, 0.9, "navy", bevel=0.1)           # coupling
    # lime body: low walls round the seat well, a rounded nose with studs, window frames
    box(0.0, 2.0, -HW, HW, 1.3, 2.7, "lime", bevel=0.55, segments=4)            # nose
    studs(0.5, -1.0, 2.7, 1, 2, "lime")
    for side in (-1, 1):
        v0, v1 = (HW - 0.3, HW) if side > 0 else (-HW, -HW + 0.3)
        box(1.8, L, v0, v1, 1.3, 2.5, "lime", bevel=0.15)                       # lower side wall
        for (u0, u1) in ((1.8, 2.4), (4.6, 5.0), (L - 0.6, L)):                 # window pillars
            box(u0, u1, v0, v1, 2.4, TOP, "lime", bevel=0.12)
        box(1.8, L, v0, v1, TOP - 0.35, TOP, "lime", bevel=0.12)                # top rail
    box(1.8, 2.3, -HW, HW, 1.3, 3.0, "lime", bevel=0.15)                        # front wall
    box(1.85, 2.0, -HW + 0.3, HW - 0.3, 3.0, TOP - 0.35, "glass", bevel=0.04)   # windscreen
    box(1.8, 2.3, -HW, HW, TOP - 0.35, TOP, "lime", bevel=0.12)                 # front rail
    box(L - 0.4, L, -HW, -0.8, 1.3, 2.5, "lime", bevel=0.12)                    # back: open U
    box(L - 0.4, L, 0.8, HW, 1.3, 2.5, "lime", bevel=0.12)
    box(L - 0.4, L, -HW, HW, 1.3, 1.9, "lime", bevel=0.12)
    box(2.3, L - 0.4, -HW + 0.3, HW - 0.3, FLOOR - 0.2, FLOOR, "navy", bevel=0.0)  # navy studded floor
    studs(5.2, -1.0, FLOOR, 2, 2, "navy")
    # front face: the railway logo (arrows and a ring), two lamps, a smile line
    disc(-0.04, 0.0, 2.05, 0.32, 0.12, "logo", axis="u", verts=24)
    disc(-0.07, 0.0, 2.05, 0.2, 0.12, "lime", axis="u", verts=20)
    for side in (-1, 1):
        box(-0.07, 0.1, side * 0.42, side * 0.9, 1.98, 2.12, "logo", bevel=0.0)
        disc(-0.04, side * 1.35, 1.6, 0.25, 0.12, "lamp", axis="u")
    # side print: music notes and stars in navy
    for side in (-1, 1):
        v0 = side * (HW + 0.02)
        for k in range(5):
            u = 2.8 + k * 1.0
            disc(u, v0, 1.9, 0.14, 0.06, "logo", axis="v", verts=12)
            box(u + 0.1, u + 0.16, v0 - 0.03, v0 + 0.03, 1.9, 2.3, "logo", bevel=0.0)
    for (name, u, v) in (("wheel-front-left", 1.6, 1.6), ("wheel-front-right", 1.6, -1.6),
                         ("wheel-back-left", 6.4, 1.6), ("wheel-back-right", 6.4, -1.6)):
        wheel(name, u, v, 0.55, 0.45, "grey", "grey", 0.35)
    SEAT = (4.1, FLOOR)

# Join the body.
bpy.ops.object.select_all(action="DESELECT")
for o in BODY:
    o.select_set(True)
bpy.context.view_layer.objects.active = BODY[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = "body"
body.data.name = "body"
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

# Scale to the length in metres (wheel origins stay at their centres).
pts = [body.matrix_world @ v.co for v in body.data.vertices]
length = max(p.y for p in pts) - min(p.y for p in pts)
k = args.length / length
for o in [body] + WHEELS:
    o.location = o.location * k
    o.scale = (k, k, k)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
for o in WHEELS:
    o.rotation_mode = "XYZ"
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in [body] + WHEELS)
seat = W(SEAT[0], 0, SEAT[1]) * k
everything = [o.matrix_world @ v.co for o in [body] + WHEELS for v in o.data.vertices]
lo = Vector((min(p.x for p in everything), min(p.y for p in everything), min(p.z for p in everything)))
hi = Vector((max(p.x for p in everything), max(p.y for p in everything), max(p.z for p in everything)))
size = hi - lo

out = os.path.abspath(args.out)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=True,
                          export_animations=False)
if args.blend:
    os.makedirs(os.path.dirname(os.path.abspath(args.blend)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.blend), compress=True)
print("DUPLO VEHICLE OK: %s, %d triangles, %.2f x %.2f x %.2f m (w x l x h)" % (out, tris, size.x, size.y, size.z))
print("SEAT: seat_position = Vector3(0, %.2f, %.2f)" % (seat.z, -seat.y))

if args.sheet:
    scene = bpy.context.scene
    step = max(size.x, size.y, size.z) * 1.25
    turns = [0, -90, 180, -35]
    group = [body] + WHEELS
    for i, deg in enumerate(turns):
        empty = bpy.data.objects.new("turn%d" % i, None)
        scene.collection.objects.link(empty)
        empty.location = (i * step, 0, 0)
        empty.rotation_euler = (0, 0, math.radians(deg))
        for o in group:
            c = o if i == 0 else o.copy()
            if i:
                scene.collection.objects.link(c)
            c.parent = empty
    cam_data = bpy.data.cameras.new("SheetCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = step * len(turns)
    cam = bpy.data.objects.new("SheetCam", cam_data)
    scene.collection.objects.link(cam)
    # Looking a little down (into the open seat), aimed at the middle of the vehicles.
    cam.location = (step * (len(turns) - 1) / 2, -20, size.z / 2 + 20 * math.tan(math.radians(12)))
    cam.rotation_euler = (math.radians(78), 0, 0)
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
    print("DUPLO VEHICLE SHEET:", scene.render.filepath)
