"""Build a toy vehicle that is a driver itself (like the police car) from simple shapes.

    blender -b --python tools/blender/build_toy_vehicle.py -- --vehicle jumbo
        --out assets/models/toys/jumbo.glb [--sheet <png>] [--blend <file>]

Vehicles (after the 23 Nov photos, see photos/toys/INVENTORY-2026-11-23.md):
  traktor  blue farm tractor with a dark grey front loader, black tyres with white rims.
           Sized to --length metres nose (bucket) to tail, default 1.5.
  jumbo    white four-engine airliner, blue tail fin and wing tips. Sized to --width metres
           wing tip to wing tip, default 1.7 (it flies: vehicle_hover in the driver .tres).

Pixal3D from the real photos gave a tractor without front wheels and a plane without a tail
(photos are perspective shots of thin, shiny parts), so these two are built like the Duplo
toys: simple shapes, strong toy colours. One mesh, origin at the bottom middle, faces Blender -Y
(glTF +Z, the kart's forward), as the toy-vehicle drivers expect (DriverRig, is_vehicle).
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--vehicle", required=True, choices=["traktor", "jumbo"])
ap.add_argument("--out", required=True)
ap.add_argument("--length", type=float, default=1.5)
ap.add_argument("--width", type=float, default=1.7)
ap.add_argument("--blend", default="")
ap.add_argument("--sheet", default="")
args = ap.parse_args(argv)

COLOURS = {
    "blue": (18, 72, 205), "dark": (52, 54, 60), "black": (24, 24, 28), "rim": (246, 246, 240),
    "glass": (40, 60, 90), "lamp": (255, 250, 215), "grey": (130, 135, 145), "red": (215, 35, 30),
    "white": (248, 248, 246), "engine": (215, 218, 224), "tail": (20, 60, 190), "window": (22, 48, 150),
    "door": (170, 192, 225),
    "orange": (245, 140, 20),
}
MATS = {}


def srgb(c):
    return tuple(((x / 255.0 + 0.055) / 1.055) ** 2.4 if x / 255.0 > 0.04045 else x / 255.0 / 12.92 for x in c)


def mat(name):
    if name not in MATS:
        m = bpy.data.materials.new("toy_" + name)
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*srgb(COLOURS[name]), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.7 if name in ("black", "dark") else 0.35
        m.diffuse_color = (*srgb(COLOURS[name]), 1.0)
        MATS[name] = m
    return MATS[name]


PARTS = []


def W(u, v, z):
    """u from the nose back, v across (positive = the toy's left), z up -> Blender (front = -Y)."""
    return Vector((v, u, z))


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


def box(u0, u1, v0, v1, z0, z1, colour, bevel=0.1, segments=2):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = (abs(v1 - v0), abs(u1 - u0), abs(z1 - z0))
    o.location = W((u0 + u1) / 2, (v0 + v1) / 2, (z0 + z1) / 2)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, colour, bevel, segments)


def cyl(u, v, z, r, depth, colour, axis="v", verts=24, bevel=0.0):
    rot = {"v": (0, math.pi / 2, 0), "u": (math.pi / 2, 0, 0), "z": (0, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=W(u, v, z), rotation=rot)
    return finish(bpy.context.object, colour, bevel, 3)


def rod(a, b, r, colour, verts=12):
    a, b = W(*a), W(*b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return finish(o, colour)


def beam(a, b, w, h, colour):
    """A square bar from a to b (loader arms)."""
    a, b = W(*a), W(*b)
    d = b - a
    bpy.ops.mesh.primitive_cube_add(size=1, location=(a + b) / 2)
    o = bpy.context.object
    o.scale = (w, h, d.length)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return finish(o, colour, 0.04)


def loft(rings, colour, verts=24, paint=None):
    """A closed tube through rings (u, half width, half height, z centre); r = 0 closes an end.
    paint(u0, u1, k) may return another colour name for the face between rings u0..u1 and
    around-steps k..k+1 (k = 0 is the toy's left side at mid height, counting upwards): windows
    painted flush into the body instead of boxes stuck on it."""
    pts, faces, paints = [], [], []
    for (u, rx, rz, zc) in rings:
        for k in range(verts):
            a = 2 * math.pi * k / verts
            pts.append(tuple(W(u, rx * math.cos(a), zc + rz * math.sin(a))))
    for i in range(len(rings) - 1):
        for k in range(verts):
            a, b = i * verts + k, i * verts + (k + 1) % verts
            faces.append((a, b, b + verts, a + verts))
            paints.append(paint(rings[i][0], rings[i + 1][0], k) if paint else None)
    faces.append(tuple(range(verts))[::-1])
    faces.append(tuple(range((len(rings) - 1) * verts, len(rings) * verts)))
    paints += [None, None]
    o = mesh_object("loft", pts, faces)
    finish(o, colour)
    slots = [colour]
    for f, p in zip(o.data.polygons, paints):
        if p:
            if p not in slots:
                slots.append(p)
                o.data.materials.append(mat(p))
            f.material_index = slots.index(p)
    return o


def rings_with(rings, extra):
    """Insert rings at the u values in extra, linearly between the given rings."""
    out = list(rings)
    for u in extra:
        for (a, b) in zip(rings, rings[1:]):
            if a[0] < u < b[0]:
                t = (u - a[0]) / (b[0] - a[0])
                out.append(tuple(a[j] + (b[j] - a[j]) * t for j in range(4)))
    return sorted(out)


def slab(outline, z0, z1, colour, bevel=0.05):
    """A flat plate: outline is a list of (u, v) points (convex, any winding), z0..z1 thick."""
    n = len(outline)
    pts = [tuple(W(u, v, z0)) for u, v in outline] + [tuple(W(u, v, z1)) for u, v in outline]
    faces = [tuple(range(n)), tuple(range(n, 2 * n))]
    for k in range(n):
        faces.append((k, (k + 1) % n, n + (k + 1) % n, n + k))
    o = mesh_object("slab", pts, faces)
    return finish(o, colour, bevel)


def fin(outline, v0, v1, colour, bevel=0.05):
    """A vertical plate: outline is (u, z) points, v0..v1 thick."""
    n = len(outline)
    pts = [tuple(W(u, v0, z)) for u, z in outline] + [tuple(W(u, v1, z)) for u, z in outline]
    faces = [tuple(range(n)), tuple(range(n, 2 * n))]
    for k in range(n):
        faces.append((k, (k + 1) % n, n + (k + 1) % n, n + k))
    o = mesh_object("fin", pts, faces)
    return finish(o, colour, bevel)


bpy.ops.wm.read_factory_settings(use_empty=True)

if args.vehicle == "traktor":
    # Units: about a centimetre of the real toy. Loader bucket at the front (u ~ 0).
    FU = 6.0                                                             # front axle
    for side in (-1, 1):
        # big rear wheels, small front wheels: black tyres, white rims, a dark hub
        cyl(14.5, side * 3.6, 3.3, 3.3, 2.0, "black", bevel=0.5)
        cyl(14.5, side * 4.55, 3.3, 2.0, 0.2, "rim", verts=20)
        cyl(14.5, side * 4.65, 3.3, 0.7, 0.2, "grey", verts=12)
        for k in range(12):                                             # tread lugs
            a = k * 2 * math.pi / 12
            box(14.5 + 3.3 * math.cos(a) - 0.25, 14.5 + 3.3 * math.cos(a) + 0.25, side * 2.7, side * 4.5,
                3.3 + 3.3 * math.sin(a) - 0.25, 3.3 + 3.3 * math.sin(a) + 0.25, "black", bevel=0.08)
        # small front wheels on the front axle, with tread lugs too
        cyl(FU, side * 3.0, 2.2, 2.2, 1.5, "black", bevel=0.4)
        cyl(FU, side * 3.8, 2.2, 1.35, 0.2, "rim", verts=20)
        cyl(FU, side * 3.88, 2.2, 0.5, 0.2, "grey", verts=12)
        for k in range(10):
            a = k * 2 * math.pi / 10
            box(FU + 2.2 * math.cos(a) - 0.2, FU + 2.2 * math.cos(a) + 0.2, side * 2.35, side * 3.65,
                2.2 + 2.2 * math.sin(a) - 0.2, 2.2 + 2.2 * math.sin(a) + 0.2, "black", bevel=0.06)
        # blue mudguards over the rear wheels
        box(11.8, 17.2, side * 2.4, side * 4.7, 6.4, 6.9, "blue", bevel=0.2)
        box(11.6, 12.2, side * 2.4, side * 4.7, 4.6, 6.9, "blue", bevel=0.2)
    box(4.0, 17.0, -1.2, 1.2, 1.6, 3.4, "dark", bevel=0.2)               # chassis
    box(FU - 0.3, FU + 0.3, -2.4, 2.4, 1.9, 2.5, "dark", bevel=0.1)       # front axle
    box(2.6, 3.4, -1.3, 1.3, 1.3, 2.7, "dark", bevel=0.15)               # front frame / weight
    # bonnet: long, a little lower at the nose, rounded edges
    fin([(3.2, 2.6), (3.2, 5.2), (3.9, 5.8), (11.8, 6.2), (11.8, 2.6)], -1.65, 1.65, "blue", bevel=0.35)
    box(3.0, 3.3, -1.25, 1.25, 2.8, 4.6, "black", bevel=0.08)            # grille
    for z in (3.15, 3.6, 4.05):                                          # grille bars
        box(2.95, 3.05, -1.15, 1.15, z, z + 0.18, "grey", bevel=0.0)
    for side in (-1, 1):
        cyl(3.15, side * 0.95, 5.0, 0.42, 0.2, "black", axis="u", verts=16)  # headlight rims
        cyl(3.05, side * 0.95, 5.0, 0.32, 0.2, "lamp", axis="u", verts=16)   # headlights
        box(5.0, 10.6, side * 1.64, side * 1.7, 4.0, 5.1, "dark", bevel=0.0)  # side vents
    cyl(10.8, 1.2, 7.4, 0.25, 3.2, "black", axis="z", verts=10)          # exhaust
    # cab: dark posts, tinted glass, blue roof
    box(11.8, 17.0, -2.4, 2.4, 6.0, 6.6, "blue", bevel=0.15)             # cab floor
    for u in (12.0, 16.6):
        for side in (-1, 1):
            box(u - 0.25, u + 0.25, side * 2.1, side * 2.4, 6.5, 10.4, "black", bevel=0.05)
    box(12.0, 16.6, -2.15, 2.15, 6.6, 10.2, "glass", bevel=0.05)
    box(13.4, 15.4, -0.9, 0.9, 6.6, 8.8, "dark", bevel=0.3)              # seat seen through glass
    box(11.5, 17.2, -2.6, 2.6, 10.2, 11.0, "blue", bevel=0.3, segments=3)  # roof
    box(11.6, 12.0, -1.6, 1.6, 9.7, 10.1, "lamp", bevel=0.05)            # roof lamps
    box(16.6, 17.6, -0.6, 0.6, 1.8, 3.0, "dark", bevel=0.1)              # hitch
    # front loader after the photos: a tower on each side behind the front wheels, arms up over
    # the front wheels and forward past the nose, then down to a wide bucket lowered to the ground
    # (so the bonnet, grille and lights stay visible from the front)
    for side in (-1, 1):
        v = side * 2.15
        box(8.3, 9.7, side * 1.6, side * 2.5, 2.6, 6.4, "dark", bevel=0.15)       # tower
        beam((9.0, v, 6.0), (2.4, v, 7.0), 0.55, 0.8, "dark")
        beam((2.4, v, 7.0), (-0.3, v, 2.2), 0.55, 0.8, "dark")
        rod((8.8, v, 3.4), (4.2, v, 6.7), 0.22, "grey")                  # lift ram
        rod((2.6, side * 2.5, 6.6), (0.0, side * 2.5, 2.9), 0.16, "grey")  # bucket ram
        box(-0.3, 0.3, side * 1.85, side * 2.45, 1.0, 2.9, "dark", bevel=0.08)  # bucket bracket
    beam((0.15, -2.15, 2.6), (0.15, 2.15, 2.6), 0.5, 0.5, "dark")        # cross tube
    box(-2.9, 0.0, -3.6, 3.6, 0.2, 0.5, "dark", bevel=0.08)              # bucket floor
    box(-0.4, 0.0, -3.6, 3.6, 0.2, 2.8, "dark", bevel=0.08)              # bucket back
    box(-3.0, -2.6, -3.55, 3.55, 0.2, 0.42, "grey", bevel=0.04)          # cutting edge
    for side in (-1, 1):
        fin([(-2.9, 0.2), (0.0, 0.2), (0.0, 2.8), (-0.6, 2.8), (-2.9, 0.75)],
            side * 3.35, side * 3.6, "dark")                             # bucket sides
    for k in range(5):                                                   # ribs on the back
        v = -2.8 + k * 1.4
        box(0.0, 0.25, v - 0.15, v + 0.15, 0.4, 2.6, "grey", bevel=0.04)
else:
    # Units: about a centimetre of the real toy. Nose at u = 0.
    L = 22.0
    rings = [(0.0, 0.0, 0.0, 1.55), (0.3, 0.75, 0.7, 1.55), (0.9, 1.15, 1.1, 1.6), (1.8, 1.4, 1.38, 1.65),
             (3.2, 1.5, 1.5, 1.7), (16.0, 1.5, 1.5, 1.7), (18.0, 1.2, 1.15, 1.95), (20.0, 0.75, 0.7, 2.3),
             (21.6, 0.3, 0.3, 2.6), (22.0, 0.0, 0.0, 2.65)]
    # The real toy's windows wore off; the owner wants them back. They are painted into the body
    # faces (28 steps around): one row of passenger windows per side (step 1 on the left, 12 on
    # the right, 13 to 26 degrees above the middle), a two-pane cockpit window over the nose, and two doors
    # per side as pale panels with a window. Rings are added at every window edge.
    WIN0, WIN_PITCH, WIN_LEN, WIN_N = 3.75, 0.8, 0.45, 14
    windows = [(WIN0 + n * WIN_PITCH, WIN0 + n * WIN_PITCH + WIN_LEN) for n in range(WIN_N)]
    doors = [(2.45, 3.1), (15.0, 15.6)]
    cockpit = (0.95, 1.8)
    cuts = [u for w in windows + doors + [cockpit] for u in w]
    cuts += [d0 + 0.12 for d0, _ in doors] + [d1 - 0.12 for _, d1 in doors]
    rings = rings_with(rings, cuts)

    def paint(u0, u1, k):
        um = (u0 + u1) / 2
        if cockpit[0] < um < cockpit[1] and (2 <= k <= 5 or 8 <= k <= 11):   # two panes, a post between
            return "window"
        for d0, d1 in doors:
            if d0 < um < d1:
                if k in (1, 12) and d0 + 0.12 < um < d1 - 0.12:
                    return "window"
                if k in (27, 0, 1, 12, 13, 14):
                    return "door"
        if k in (1, 12) and any(w0 < um < w1 for w0, w1 in windows):
            return "window"
        return None

    loft(rings, "white", verts=28, paint=paint)
    for side in (-1, 1):                                                 # blue swirl near the tail
        box(15.0, 19.5, side * 1.3, side * 1.52, 1.0, 1.4, "tail", bevel=0.1)
    # wings: low, swept back, tips turned up, blue tips
    for side in (-1, 1):
        root_f, root_b, tip_f, tip_b, span = 7.0, 12.5, 13.6, 15.4, 10.5
        slab([(root_f, side * 1.2), (tip_f, side * span), (tip_b, side * span), (root_b, side * 1.2)],
             0.85, 1.25, "white")
        slab([(tip_f - 0.4, side * (span - 1.5)), (tip_f + 0.15, side * span), (tip_b, side * span),
              (tip_b - 0.3, side * (span - 1.5))], 1.27, 1.32, "tail", bevel=0.0)
        fin([(tip_f + 0.2, 1.1), (tip_b, 1.1), (tip_b + 0.6, 2.6), (tip_b - 0.3, 2.6)],
            side * span - 0.08, side * span + 0.08, "tail")            # winglet
        for e, (s, f) in enumerate(((3.6, 7.3), (6.9, 10.0))):          # two engines per wing
            cyl(f + 1.3, side * s, 0.35, 0.62, 2.8, "engine", axis="u", verts=18, bevel=0.15)
            cyl(f - 0.04, side * s, 0.35, 0.45, 0.1, "dark", axis="u", verts=16)
            box(f + 0.6, f + 2.6, side * s - 0.12, side * s + 0.12, 0.6, 1.0, "white", bevel=0.05)  # pylon
    # tail: blue fin and stabilisers
    fin([(17.2, 3.0), (21.8, 2.9), (22.6, 6.6), (20.6, 6.6)], -0.18, 0.18, "tail")
    for side in (-1, 1):
        slab([(18.6, side * 0.4), (21.2, side * 4.2), (22.2, side * 4.2), (21.8, side * 0.4)], 2.45, 2.65, "white")
        slab([(20.8, side * 3.3), (21.25, side * 4.2), (22.2, side * 4.2), (22.05, side * 3.3)], 2.67, 2.71,
             "tail", bevel=0.0)
    # landing gear: the toy has small wheels under the middle and the nose
    for side in (-1, 1):
        rod((11.5, side * 0.9, 0.9), (11.5, side * 0.9, 0.4), 0.12, "grey")
        cyl(11.5, side * 0.9, 0.42, 0.42, 0.35, "black", verts=14)
    rod((2.6, 0, 0.6), (2.6, 0, 0.3), 0.1, "grey")
    cyl(2.6, 0, 0.3, 0.3, 0.3, "black", verts=12)

# Join, size, origin at the bottom middle, export.
bpy.ops.object.select_all(action="DESELECT")
for o in PARTS:
    o.select_set(True)
bpy.context.view_layer.objects.active = PARTS[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
obj.name = args.vehicle
obj.data.name = args.vehicle
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")
pts = [v.co.copy() for v in obj.data.vertices]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
k = args.length / (hi.y - lo.y) if args.vehicle == "traktor" else args.width / (hi.x - lo.x)
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
print("TOY VEHICLE OK: %s, %d triangles, %.2f x %.2f x %.2f m (w x l x h)" % (out, tris, size.x, size.y, size.z))

if args.sheet:
    scene = bpy.context.scene
    step = max(size.x, size.y) * 1.15
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
    cam.location = (step * (len(turns) - 1) / 2, -20, size.z / 2 + 20 * math.tan(math.radians(10)))
    cam.rotation_euler = (math.radians(80), 0, 0)
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
    print("TOY VEHICLE SHEET:", scene.render.filepath)
