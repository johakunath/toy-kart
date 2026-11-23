"""Build a Duplo vehicle as a kart model (drivers sit in it), after the 23 Nov photos.

    blender -b --python tools/blender/build_duplo_vehicle.py -- --vehicle krankenwagen
        --out assets/models/toys/krankenwagen.glb [--length 1.5] [--sheet <png>] [--blend <file>]

Vehicles:
  krankenwagen  Duplo ambulance/van: white body, orange-red base, red-white stripes and a grille
                at the front, black tyres with white hubs. The flip-up roof shell is shown flipped
                open behind the seats (hinged at the back), so the driver is seen sitting inside. Photos 2026-11-23 11.59.28 (11), 11.59.29*.
  zug           Duplo train car: tall lime green body with a round roof edge round
                an open top, open front above the round nose, a notch in the back, navy base,
                railway logo and four lamps at the front. Photos 2026-11-23 11.59.26*, 11.59.27, (1).

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
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--vehicle", required=True, choices=["krankenwagen", "zug"])
ap.add_argument("--out", required=True)
ap.add_argument("--length", type=float, default=1.5, help="nose to tail in metres")
ap.add_argument("--blend", default="")
ap.add_argument("--sheet", default="")
ap.add_argument("--sheet-roof", type=float, default=100.0, help="degrees the roof is open in the sheet")
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

ROOF = []     # parts of a flip-up roof: joined into their own node "roof"
HINGE = None  # Blender point on the roof's hinge axis (along X)


def roof_parts(parts, u, z):
    """Make parts (built closed) the flip-up roof, hinged about a cross axis at (u, z). The game
    swings it open (KartVisual: front end up and over toward the back)."""
    global HINGE
    HINGE = W(u, 0, z)
    for o in parts:
        BODY.remove(o)
        ROOF.append(o)


if args.vehicle == "krankenwagen":
    L = 8.5
    HW = 2.0                    # half width of the body
    FLOOR = 1.15                # top of the red floor (the seat)
    SILL = 2.45                 # top of the white tub, where the roof shell sits when closed
    RT = 4.75                   # top of the roof shell, closed (side photo 11.59.29 (5))
    # base: orange-red chassis, wider at the bumpers
    box(0.0, L, -HW, HW, 0.45, 1.25, "base", bevel=0.3, segments=3)
    box(-0.1, 0.6, -HW + 0.1, HW - 0.1, 0.45, 1.1, "base", bevel=0.25)          # front bumper
    box(L - 0.6, L + 0.15, -HW + 0.1, HW - 0.1, 0.45, 1.1, "base", bevel=0.25)  # back bumper
    box(L - 0.1, L + 0.45, -0.3, 0.3, 0.55, 0.95, "base", bevel=0.1)            # tow hitch
    # white tub: a van, no bonnet. Round nose, walls round an open seat well.
    box(0.0, 1.7, -HW, HW, 1.2, SILL, "white", bevel=0.55, segments=4)          # nose and dashboard
    box(1.2, L, -HW, -HW + 0.35, 1.2, SILL, "white", bevel=0.15)                # right wall
    box(1.2, L, HW - 0.35, HW, 1.2, SILL, "white", bevel=0.15)                  # left wall
    box(L - 0.45, L, -HW, HW, 1.2, SILL, "white", bevel=0.25, segments=3)       # back wall
    box(1.7, L - 0.45, -HW + 0.35, HW - 0.35, FLOOR - 0.2, FLOOR, "seat", bevel=0.0)  # red floor
    studs(5.6, -1.0, FLOOR, 2, 2, "seat")                                       # studs behind the seat
    # front face: red-white stripes with the blue emblem, grille, round lamps
    for k in range(7):
        v = -1.7 + k * 0.52
        box(-0.06, 0.25, v, v + 0.26, 1.95, 2.25, "red", bevel=0.0)
    box(-0.06, 0.25, -0.9, 0.9, 1.35, 1.75, "dark", bevel=0.1)                  # grille
    for v in (-1.35, 1.35):
        disc(-0.04, v, 1.55, 0.27, 0.2, "lamp", axis="u")
    disc(-0.05, 0.0, 2.1, 0.24, 0.2, "blue", axis="u")
    # red-white side stripe and a red cross on each side of the tub
    for side in (-1, 1):
        v0 = side * HW - (0.02 if side > 0 else -0.02)
        for k in range(10):
            u = 2.0 + k * 0.62
            box(u, u + 0.31, v0 - 0.03, v0 + 0.03, 2.0, 2.25, "red", bevel=0.0)
        box(5.0, 6.2, v0 - 0.03, v0 + 0.03, 1.4, 1.8, "red", bevel=0.0)        # red cross bar
        box(5.4, 5.8, v0 - 0.03, v0 + 0.03, 1.25, 1.95, "red", bevel=0.0)
    # The roof shell (the van's upper half with its window frames and four studs), built closed as
    # its own node "roof" with the origin on the hinge at the back of the tub. The game flips it
    # open like the toy (photos 11.59.29, (1), (2), (3)); --sheet-roof shows it open in the sheet.
    first = len(BODY)
    box(0.35, L, -HW, HW, RT - 0.42, RT, "white", bevel=0.4, segments=4)        # roof
    studs(L / 2 - 1.0, -1.0, RT, 2, 2, "white")                                 # four studs on top
    box(0.35, 0.85, -HW, HW, SILL, SILL + 0.3, "white", bevel=0.1)              # windscreen sill
    for side in (-1, 1):
        v0, v1 = (HW - 0.32, HW) if side > 0 else (-HW, -HW + 0.32)
        box(0.35, L, v0, v1, SILL, SILL + 0.32, "white", bevel=0.1)             # window sill
        for (u0, u1) in ((0.35, 0.95), (4.0, 4.45), (L - 0.7, L)):              # pillars
            box(u0, u1, v0, v1, SILL, RT - 0.2, "white", bevel=0.14)
        box(L - 0.4, L, v0 - side * 0.35, v1 - side * 0.35, SILL, RT - 0.2, "white", bevel=0.1)
    box(L - 0.4, L, -HW, HW, SILL, SILL + 0.55, "white", bevel=0.12)            # back: low band
    box(L - 0.4, L, -HW, HW, RT - 1.0, RT - 0.2, "white", bevel=0.12)           # back: high band
    roof_parts(BODY[first:], L - 0.1, SILL)
    for (name, u, v) in (("wheel-front-left", 1.9, 1.95), ("wheel-front-right", 1.9, -1.95),
                         ("wheel-back-left", 6.6, 1.95), ("wheel-back-right", 6.6, -1.95)):
        wheel(name, u, v, 0.9, 0.7, "tyre", "hub", 0.58)
    SEAT = (4.0, FLOOR)         # (u, z) of the driver's bottom
else:
    L = 8.0
    HW = 2.0
    FLOOR = 1.4
    RT = 5.0                    # roof top (side photo 11.59.26 (3): a tall car with a round roof)
    WIN = 2.9                   # lower edge of the windows
    # navy base with four round lamps at the front, small grey train wheels, a coupling
    box(0.1, L - 0.1, -HW + 0.1, HW - 0.1, 0.3, 1.5, "navy", bevel=0.3, segments=3)
    for v in (-1.4, -0.6, 0.6, 1.4):
        disc(0.06, v, 0.9, 0.24, 0.2, "lamp", axis="u")
    box(L - 0.2, L + 0.35, -0.25, 0.25, 0.45, 0.9, "navy", bevel=0.1)           # coupling
    # lime body. The nose is round and low (two studs on it); above it the front is open
    # between two rounded corner posts, the roof is a rounded rim round an open top, and the
    # back has a wide notch, so the driver shows from every side (photos 11.59.26 (1), (2), 11.59.27).
    box(0.0, 1.9, -HW, HW, 1.45, 3.4, "lime", bevel=0.85, segments=5)           # round nose
    studs(0.4, -1.0, 3.4, 1, 2, "lime")
    for side in (-1, 1):
        v0, v1 = (HW - 0.32, HW) if side > 0 else (-HW, -HW + 0.32)
        box(1.2, L, v0, v1, 1.45, WIN, "lime", bevel=0.15)                      # lower side wall
        for (u0, u1) in ((4.5, 4.85), (L - 1.3, L)):                            # window pillars
            box(u0, u1, v0, v1, WIN - 0.2, RT - 0.3, "lime", bevel=0.12)
        r0, r1 = (HW - 0.95, HW) if side > 0 else (-HW, -HW + 0.95)
        box(0.25, L, r0, r1, RT - 0.8, RT, "lime", bevel=0.42, segments=5)      # round roof edge
        box(0.15, 1.9, r0, r1, 2.6, RT, "lime", bevel=0.6, segments=5)          # front corner post
    for side in (-1, 1):                                                        # back: wide notch
        box(L - 0.45, L, side * 1.05, side * HW, 1.45, RT, "lime", bevel=0.3, segments=3)
        studs(L - 0.73, side * 1.52 - 0.5, RT, 1, 1, "lime")
    box(L - 0.45, L, -HW, HW, 1.45, 3.1, "lime", bevel=0.25, segments=3)
    box(1.9, L - 0.45, -HW + 0.32, HW - 0.32, FLOOR - 0.2, FLOOR, "navy", bevel=0.0)  # navy studded floor
    studs(5.4, -1.0, FLOOR, 2, 2, "navy")
    # front face: the railway logo (arrows and a ring) and two smiling eye arcs
    disc(-0.04, 0.0, 2.25, 0.32, 0.12, "logo", axis="u", verts=24)
    disc(-0.07, 0.0, 2.25, 0.2, 0.12, "lime", axis="u", verts=20)
    for side in (-1, 1):
        box(-0.07, 0.1, side * 0.42, side * 0.9, 2.18, 2.32, "logo", bevel=0.0)
        box(0.05, 0.2, side * 1.2, side * 1.6, 1.8, 1.92, "logo", bevel=0.0)
    # side print: music notes and stars in navy
    for side in (-1, 1):
        v0 = side * (HW + 0.02)
        for k in range(5):
            u = 2.2 + k * 1.0
            disc(u, v0, 2.0, 0.14, 0.06, "logo", axis="v", verts=12)
            box(u + 0.1, u + 0.16, v0 - 0.03, v0 + 0.03, 2.0, 2.4, "logo", bevel=0.0)
    for (name, u, v) in (("wheel-front-left", 1.6, 1.6), ("wheel-front-right", 1.6, -1.6),
                         ("wheel-back-left", 6.4, 1.6), ("wheel-back-right", 6.4, -1.6)):
        wheel(name, u, v, 0.55, 0.45, "grey", "grey", 0.35)
    SEAT = (4.1, FLOOR)

pts = [o.matrix_world @ v.co for o in BODY for v in o.data.vertices]
length = max(p.y for p in pts) - min(p.y for p in pts)

# The flip-up roof: one node, origin on the hinge axis.
roof = None
if ROOF:
    bpy.ops.object.select_all(action="DESELECT")
    for o in ROOF:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ROOF[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    roof = bpy.context.view_layer.objects.active
    roof.name = "roof"
    roof.data.name = "roof"
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.scene.cursor.location = HINGE
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

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
k = args.length / length
PARTS = [body] + WHEELS + ([roof] if roof else [])
for o in PARTS:
    o.location = o.location * k
    o.scale = (k, k, k)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
for o in WHEELS:
    o.rotation_mode = "XYZ"
if roof:
    roof.rotation_mode = "XYZ"
    roof.parent = body          # it leans and bounces with the body
    roof.location = roof.location - body.location
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in PARTS)
seat = W(SEAT[0], 0, SEAT[1]) * k
everything = [o.matrix_world @ v.co for o in PARTS for v in o.data.vertices]
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
    if roof:
        roof.rotation_euler.x = math.radians(-args.sheet_roof)
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
