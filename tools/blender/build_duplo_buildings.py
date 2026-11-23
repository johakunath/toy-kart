"""Build the roadside toy buildings from simple shapes, after the 23 Nov photos.

    blender -b --python tools/blender/build_duplo_buildings.py -- --building polizeiwache
        --out assets/models/props/polizeiwache.glb [--height 6.0] [--blend <file>] [--sheet <png>]

Buildings (photos: photos/toys/INVENTORY-2026-11-23.md):
  polizeiwache  the blue police station on its white base plate: a two-storey block (window,
                white door, badge; balcony with railing over the garage), a one-storey garage
                annex with a beacon on its roof. Open at the back like the toy (a dollhouse).
                The "tower" photos (11.59.27 (8)/(10)) are this station seen end-on, so the
                tower is part of this model and not a building of its own.
  duplo_laden   the Duplo brick house: a 6 x 4 stud footprint, two layers of 2x2 bricks and
                curved 2x4 bricks, a 4 x 4 core of two tall bricks with a window at each end,
                and a top row of tall 2x2 bricks. Number prints 5 and 2 as raised segments.
                Colours pushed from the photo's pale Duplo tones to strong toy colours.

Units while building: the station in about millimetres / 10 of the photo, the shop in Duplo
units (one stud = 1, one layer = 1.2). The model faces Blender -Y (glTF +Z: the side that looks
at the road), one mesh with a few shared colour materials, origin at the bottom middle, scaled
to --height metres (roadside.gd rescales to its own height anyway).
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--building", required=True, choices=["polizeiwache", "duplo_laden"])
ap.add_argument("--out", required=True)
ap.add_argument("--height", type=float, default=0.0)
ap.add_argument("--blend", default="")
ap.add_argument("--sheet", default="")
args = ap.parse_args(argv)

COLOURS = {
    # station
    "blue": (22, 78, 220), "groove": (12, 46, 150), "white": (248, 248, 246), "pane": (34, 50, 105),
    "black": (24, 24, 28), "lamp": (240, 246, 255),
    # Duplo bricks: strong toy colours
    "orange": (250, 120, 15), "coral": (250, 80, 70), "lime": (140, 210, 25), "green": (10, 150, 60),
    "azure": (20, 150, 230), "purple": (140, 80, 225), "red": (215, 20, 30), "yellow": (255, 210, 40),
    "sand": (255, 165, 30), "print_green": (0, 95, 40), "print_red": (120, 0, 45),
}
MATS = {}
PARTS = []


def srgb(c):
    return tuple(((x / 255.0 + 0.055) / 1.055) ** 2.4 if x / 255.0 > 0.04045 else x / 255.0 / 12.92 for x in c)


def mat(name):
    if name not in MATS:
        m = bpy.data.materials.new("toy_" + name)
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*srgb(COLOURS[name]), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.6 if name in ("black", "groove", "pane") else 0.35
        m.diffuse_color = (*srgb(COLOURS[name]), 1.0)
        MATS[name] = m
    return MATS[name]


def finish(obj, colour, bevel=0.0, segments=2):
    obj.data.materials.append(mat(colour))
    if bevel:
        b = obj.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = segments
        b.limit_method = "ANGLE"
    PARTS.append(obj)
    return obj


def mesh_object(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def box(x0, x1, y0, y1, z0, z1, colour, bevel=0.0, segments=2):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0))
    o.location = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, colour, bevel, segments)


def cyl(x, y, z, r, depth, colour, axis="z", verts=16, bevel=0.0):
    rot = {"x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0), "z": (0, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=(x, y, z), rotation=rot)
    return finish(bpy.context.object, colour, bevel, 2)


def dome(x, y, z, r, colour):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=r, location=(x, y, z))
    o = bpy.context.object
    o.scale.z = 1.1
    return finish(o, colour)


def prism_x(profile, x0, x1, colour, bevel=0.0):
    """A shape extruded along x: profile is a convex list of (y, z) points."""
    n = len(profile)
    pts = [(x0, y, z) for y, z in profile] + [(x1, y, z) for y, z in profile]
    faces = [tuple(range(n)), tuple(range(n, 2 * n))]
    for k in range(n):
        faces.append((k, (k + 1) % n, n + (k + 1) % n, n + k))
    return finish(mesh_object("prism", pts, faces), colour, bevel)


def stadium(x0, x1, y0, y1, z0, z1, colour, bevel=0.06):
    """A 2 x 4 brick with round ends along y (the curved Duplo bricks)."""
    r = (x1 - x0) / 2
    cx = (x0 + x1) / 2
    pts2 = []
    for k in range(9):                                   # front end, round
        a = math.pi + math.pi * k / 8
        pts2.append((cx + r * math.cos(a), y0 + r + r * math.sin(a)))
    for k in range(9):                                   # back end, round
        a = math.pi * k / 8
        pts2.append((cx + r * math.cos(a), y1 - r + r * math.sin(a)))
    n = len(pts2)
    pts = [(x, y, z0) for x, y in pts2] + [(x, y, z1) for x, y in pts2]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for k in range(n):
        faces.append((k, (k + 1) % n, n + (k + 1) % n, n + k))
    return finish(mesh_object("stadium", pts, faces), colour, bevel)


def window_frame(face, a0, a1, b0, b1, depth0, depth1, border, colour, pane_colour, bars=True):
    """A window on a wall: face 'front' (a = x, depth = y) or 'xpos' / 'xneg' (a = y, depth = x).
    a0..a1 across, b0..b1 up (z), depth0..depth1 how far it stands out of the wall."""
    def put(p0, p1, q0, q1, d0, d1, c, bev=0.03):
        if face == "front":
            box(p0, p1, d0, d1, q0, q1, c, bev)
        else:
            box(d0, d1, p0, p1, q0, q1, c, bev)
    put(a0, a1, b0, b0 + border, depth0, depth1, colour)
    put(a0, a1, b1 - border, b1, depth0, depth1, colour)
    put(a0, a0 + border, b0, b1, depth0, depth1, colour)
    put(a1 - border, a1, b0, b1, depth0, depth1, colour)
    if bars:
        am, bm, t = (a0 + a1) / 2, (b0 + b1) / 2, border * 0.45
        put(am - t, am + t, b0, b1, depth0, depth1, colour)
        put(a0, a1, bm - t, bm + t, depth0, depth1, colour)
    # the dark pane sits behind the frame, against the wall
    th = (depth1 - depth0) * 0.3
    p0, p1 = (depth0, depth0 + th) if face == "xpos" else (depth1 - th, depth1)
    put(a0 + border * 0.5, a1 - border * 0.5, b0 + border * 0.5, b1 - border * 0.5, p0, p1, pane_colour, 0.0)


SEGMENTS = {"2": "abged", "5": "afgcd"}


def digit(face, ch, a_mid, b_mid, h, d0, d1, colour):
    """A printed number as raised seven-segment strokes (reads at any distance)."""
    w, t = h * 0.55, h * 0.16
    top, mid, bot = b_mid + h / 2, b_mid, b_mid - h / 2
    left, right = a_mid - w / 2, a_mid + w / 2
    seg = {
        "a": (left, right, top - t, top), "g": (left, right, mid - t / 2, mid + t / 2), "d": (left, right, bot, bot + t),
        "f": (left, left + t, mid, top), "b": (right - t, right, mid, top),
        "e": (left, left + t, bot, mid), "c": (right - t, right, bot, mid),
    }
    for s in SEGMENTS[ch]:
        p0, p1, q0, q1 = seg[s]
        if face == "front":
            box(p0, p1, d0, d1, q0, q1, colour, 0.02)
        else:
            box(d0, d1, p0, p1, q0, q1, colour, 0.02)


def build_station():
    # Measured on the front photo (11.59.27 (11)): 1 unit = 100 px; x from the left, z up from
    # the table, y from the front wall backwards (front faces -y). Depth from the end view.
    # White base plate, two steps
    box(2.55, 15.6, -1.0, 3.5, 0.0, 0.4, "white", 0.08)
    box(2.8, 15.35, -0.8, 3.3, 0.4, 0.75, "white", 0.06)
    Z0, ZT, D, T = 0.75, 9.4, 2.6, 0.3          # floor, wall top, depth, wall thickness
    # --- main block: left room (window, door, badge) ---
    box(3.7, 7.6, 0.0, T, Z0, ZT, "blue", 0.04)                     # front wall left part
    box(3.7, 4.0, 0.0, D, Z0, ZT, "blue", 0.04)                     # left end wall
    box(7.4, 7.6, 0.0, D, Z0, ZT, "blue", 0.03)                     # inner wall
    box(11.5, 11.9, 0.0, D, Z0, ZT, "blue", 0.04)                   # wall between block and annex
    box(4.0, 7.4, 0.0, D, 5.0, 5.3, "blue", 0.03)                   # upper floor, left room
    box(7.6, 11.5, 0.15, D, 5.0, 5.3, "blue", 0.03)                 # balcony floor
    # brick grooves: darker lines across the outer walls (the "tower" look from the side)
    z = Z0 + 0.55
    while z < ZT - 0.2:
        box(3.62, 3.7, 0.05, D - 0.05, z, z + 0.08, "groove")       # left end
        if z < 6.15 or z > 8.75:                                    # front, around the window
            box(3.75, 7.55, -0.08, 0.0, z, z + 0.08, "groove")
        z += 0.55
    window_frame("front", 4.0, 7.15, 6.3, 8.6, -0.2, 0.0, 0.28, "white", "pane")
    box(3.95, 7.25, -0.38, 0.0, 6.15, 6.35, "white", 0.04)          # window sill
    box(4.45, 5.55, -0.1, 0.05, Z0, 4.35, "white", 0.04)            # door
    box(5.25, 5.35, -0.2, -0.1, 2.0, 3.0, "white", 0.02)            # door handle
    box(4.1, 6.9, -0.22, 0.0, 4.35, 4.65, "blue", 0.04)             # door lintel
    cyl(5.55, -0.06, 5.75, 0.45, 0.14, "white", axis="y", verts=20)  # badge
    cyl(5.55, -0.14, 5.75, 0.3, 0.04, "black", axis="y", verts=16)
    # --- middle bay: garage below, balcony with railing above ---
    for x0, x1 in ((7.4, 7.75), (11.15, 11.5)):
        box(x0, x1, -0.2, T, Z0, 5.0, "blue", 0.04)                 # garage posts
    box(7.4, 11.9, -0.2, T, 5.0, 5.55, "blue", 0.04)                # garage lintel
    box(11.5, 11.9, -0.15, T, Z0, ZT, "blue", 0.04)                 # front pillar
    cyl(9.55, 0.05, 7.4, 0.14, 4.1, "blue", axis="x", verts=10)      # railing top rail
    for x in (8.35, 9.5, 10.65):
        box(x - 0.1, x + 0.1, -0.05, 0.15, 5.55, 7.4, "blue", 0.03)
    for x0, x1 in ((3.7, 7.6), (7.6, 11.9)):
        box(x0, x1, D - T, D, Z0, Z0 + 0.25, "blue", 0.03)            # low back sill
    # main roof: flat at the back, sloping down to an overhang at the front
    prism_x([(-0.75, 9.3), (2.95, 9.3), (2.95, 10.65), (2.0, 10.65), (-0.75, 9.75)], 3.05, 12.55, "blue", 0.05)
    # --- annex: garage with a beacon on the roof ---
    AD = 1.9
    box(15.55, 16.15, 0.0, AD, Z0, 5.3, "blue", 0.04)               # right end wall
    z = Z0 + 0.55
    while z < 5.1:
        box(16.15, 16.23, 0.05, AD - 0.05, z, z + 0.08, "groove")
        z += 0.55
    for x0, x1 in ((11.9, 12.2), (15.25, 15.55)):
        box(x0, x1, -0.15, T, Z0, 4.95, "blue", 0.04)               # garage posts
    box(11.9, 16.15, -0.15, T, 4.95, 5.3, "blue", 0.04)             # lintel
    prism_x([(-0.6, 5.25), (AD + 0.2, 5.25), (AD + 0.2, 6.3), (1.3, 6.3), (-0.6, 5.6)], 11.9, 16.75, "blue", 0.05)
    cyl(13.7, 0.85, 6.4, 0.42, 0.25, "white", verts=16, bevel=0.03)  # beacon
    cyl(13.7, 0.85, 6.7, 0.36, 0.4, "lamp", verts=16)
    dome(13.7, 0.85, 6.9, 0.36, "lamp")


def build_shop():
    # Duplo units, x across the long (6 stud) face, y depth (4 studs), front = -y.
    L, G = 1.2, 0.025                     # layer height, gap between bricks
    BEV = 0.07

    def brick(x0, x1, y0, y1, z0, z1, colour):
        box(x0 + G, x1 - G, y0 + G, y1 - G, z0 + G * 0.4, z1 - G * 0.4, colour, BEV, 2)

    def studs(x0, x1, y0, y1, z, colour):
        x = x0 + 0.5
        while x < x1:
            y = y0 + 0.5
            while y < y1:
                cyl(x, y, z + 0.14, 0.3, 0.28, colour, verts=14, bevel=0.04)
                y += 1.0
            x += 1.0

    # bottom: two layers of 2x2 bricks at the ends, curved 2x4 bricks in the middle
    cells = [((-3, -1, -2, 0), ("green", "purple")), ((-3, -1, 0, 2), ("red", "lime")),
             ((1, 3, -2, 0), ("orange", "sand")), ((1, 3, 0, 2), ("coral", "purple"))]
    for (x0, x1, y0, y1), cols in cells:
        for k, c in enumerate(cols):
            brick(x0, x1, y0, y1, k * L, (k + 1) * L, c)
        # only the outer stud row is not under the core (x -3..-2 and 2..3)
        studs(x0, x0 + 1 if x0 < 0 else x1 - 1, y0, y1, 2 * L, cols[1])
    for k, c in enumerate(("lime", "green")):
        stadium(-1 + G, 1 - G, -2 + G, 2 - G, k * L + G * 0.4, (k + 1) * L - G * 0.4, c)
    digit("xpos", "2", 1.0, 0.6, 0.8, 3.0 - G, 3.06, "print_red")
    # core: two tall bricks (white, yellow), 2.5 layers, a window at each end
    zc0, zc1 = 2 * L, 2 * L + 3.0
    brick(-2, 0, -2, 2, zc0, zc1, "white")
    brick(0, 2, -2, 2, zc0, zc1, "yellow")
    window_frame("xneg", -1.6, 1.6, zc0 + 0.25, zc1 - 0.25, -2.12, -2.0 + G, 0.3, "white", "pane")
    window_frame("xpos", -1.6, 1.6, zc0 + 0.25, zc1 - 0.25, 2.0 - G, 2.12, 0.3, "white", "pane")
    # top: tall 2x2 bricks at the ends, two curved bricks in the middle
    z0 = zc1
    tops = [((-3, -1, -2, 0), "orange"), ((-3, -1, 0, 2), "coral"), ((1, 3, -2, 0), "lime"), ((1, 3, 0, 2), "azure")]
    for (x0, x1, y0, y1), c in tops:
        brick(x0, x1, y0, y1, z0, z0 + 2 * L, c)
        studs(x0, x1, y0, y1, z0 + 2 * L, c)
    for k, c in enumerate(("lime", "green")):
        stadium(-1 + G, 1 - G, -2 + G, 2 - G, z0 + k * L + G * 0.4, z0 + (k + 1) * L - G * 0.4, c)
    studs(-1, 1, -1, 1, z0 + 2 * L, "green")
    digit("front", "5", 2.0, z0 + L, 1.5, -2.0 - 0.06, -2.0 + G, "print_green")


bpy.ops.wm.read_factory_settings(use_empty=True)
if args.building == "polizeiwache":
    build_station()
else:
    build_shop()

# Join, size, origin at the bottom middle, export.
bpy.ops.object.select_all(action="DESELECT")
for o in PARTS:
    o.select_set(True)
bpy.context.view_layer.objects.active = PARTS[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
obj.name = args.building
obj.data.name = args.building
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
pts = [v.co.copy() for v in obj.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
k = args.height / (hi.z - lo.z) if args.height > 0 else 1.0
shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for v in obj.data.vertices:
    v.co = (v.co - shift) * k
obj.data.update()
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
size = (hi - lo) * k
out = os.path.abspath(args.out)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=True,
                          export_animations=False)
if args.blend:
    os.makedirs(os.path.dirname(os.path.abspath(args.blend)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.blend), compress=True)
print("BUILDING OK: %s, %d triangles, %d materials, %.2f x %.2f x %.2f m (w x d x h)"
      % (out, tris, len(MATS), size.x, size.y, size.z))

if args.sheet:
    scene = bpy.context.scene
    step = max(max(size.x, size.y) * 1.15, size.z * 1.2)
    turns = [0, -35, -90, 180]
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
    cam.location = (step * (len(turns) - 1) / 2, -40, size.z / 2 + 40 * math.tan(math.radians(12)))
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
    print("BUILDING SHEET:", scene.render.filepath)
