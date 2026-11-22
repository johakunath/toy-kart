"""Build the Duplo plane (Duplo-Flieger) from bricks, after photos/toys/duploflieger-*.jpg.

    blender -b --python tools/blender/build_duplo_plane.py -- --out art/models/duploflieger_blender.glb

Bricks are laid out in Duplo units: one stud = 1 unit, one brick layer = 1.2 units.
Plane coordinates while building: u runs along the body from the nose (0) to the tail (22),
v across the wings (negative = the plane's right side), layer = brick layer from the ground.
The finished model faces Blender -Y (glTF +Z, the kart's forward). prepare_toy_model.py then
scales it (--width) and exports the game model.
"""
import argparse
import math
import os
import sys

import bmesh
import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
args = ap.parse_args(argv)

LAYER = 1.2
STUD_R, STUD_H = 0.3, 0.18
LENGTH = 22.0


def srgb(c):
    return tuple(((x / 255.0 + 0.055) / 1.055) ** 2.4 if x / 255.0 > 0.04045 else x / 255.0 / 12.92 for x in c)


COLOURS = {
    "red": (196, 30, 26), "orange": (232, 88, 34), "yellow": (250, 200, 50), "cream": (248, 226, 140),
    "green": (20, 120, 60), "lime": (140, 190, 50), "blue": (40, 140, 215), "white": (242, 242, 236),
    "salmon": (240, 120, 105), "mint": (175, 225, 215), "wood": (222, 190, 140), "grey": (150, 155, 160),
    "leaf": (90, 175, 70), "tyre": (245, 245, 245), "hub": (60, 60, 60),
}
MATS = {}


def mat(name):
    if name not in MATS:
        m = bpy.data.materials.new("duplo_" + name)
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*srgb(COLOURS[name]), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.35
        MATS[name] = m
    return MATS[name]


def to_world(u, v, z):
    return (v, u - LENGTH / 2, z)


def finish(obj, colour, bevel=0.06):
    obj.data.materials.append(mat(colour))
    if bevel:
        b = obj.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
    return obj


def mesh_object(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def studs(u0, v0, layer_top, su, sv, colour):
    for i in range(int(su)):
        for j in range(int(sv)):
            x, y, z = to_world(u0 + i + 0.5, v0 + j + 0.5, layer_top * LAYER + STUD_H / 2)
            bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=STUD_R, depth=STUD_H, location=(x, y, z))
            finish(bpy.context.object, colour, 0)


def brick(u0, v0, layer, su, sv, colour, layers=1.0, top_studs=True):
    """A plain brick: su studs long, sv studs wide, `layers` high, studs on top."""
    x0, y0, z0 = to_world(u0, v0, layer * LAYER)
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = (sv, su, layers * LAYER)
    o.location = (x0 + sv / 2, y0 + su / 2, z0 + layers * LAYER / 2)
    bpy.ops.object.transform_apply(scale=True)
    finish(o, colour)
    if top_studs:
        studs(u0, v0, layer + layers, su, sv, colour)


def slope(u0, v0, layer, su, sv, colour, layers=1.0, low="front", low_height=0.25, top_studs=0):
    """A wedge: full height at one end, `low_height` layers at the `low` end (front = nose side).
    `top_studs` rows of studs stay on the high end."""
    u1, v1 = u0 + su, v0 + sv
    z0, z1, zl = layer * LAYER, (layer + layers) * LAYER, (layer + low_height) * LAYER
    zf, zb = (zl, z1) if low == "front" else (z1, zl)
    p = [to_world(u0, v0, z0), to_world(u0, v1, z0), to_world(u1, v1, z0), to_world(u1, v0, z0),
         to_world(u0, v0, zf), to_world(u0, v1, zf), to_world(u1, v1, zb), to_world(u1, v0, zb)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    finish(mesh_object("slope", p, f), colour)
    if top_studs:
        start = u1 - top_studs if low == "front" else u0
        studs(start, v0, layer + layers, top_studs, sv, colour)


def curve(u0, v0, layer, su, sv, colour, layers=1.0, low="front", top_studs=0):
    """A curved brick: a quarter-round falling toward the `low` end."""
    steps = 8
    z0 = layer * LAYER
    h = layers * LAYER
    prof = []  # (u, z) along the top, from the front end to the back end
    for k in range(steps + 1):
        t = k / steps
        if low == "front":
            prof.append((u0 + su * t, z0 + h * math.sin(t * math.pi / 2) ** 0.8))
        else:
            prof.append((u0 + su * t, z0 + h * math.cos(t * math.pi / 2) ** 0.8))
    verts, faces = [], []
    for (u, z) in prof:
        verts += [to_world(u, v0, z0), to_world(u, v0, max(z, z0 + 0.05)),
                  to_world(u, v0 + sv, max(z, z0 + 0.05)), to_world(u, v0 + sv, z0)]
    for k in range(steps):
        a, b = 4 * k, 4 * (k + 1)
        faces += [(a + 1, b + 1, b + 2, a + 2), (a + 0, a + 1, b + 1, b + 0), (a + 2, b + 2, b + 3, a + 3),
                  (a + 3, b + 3, b + 0, a + 0)]
    n = 4 * steps
    faces += [(0, 3, 2, 1), (n, n + 1, n + 2, n + 3)]
    finish(mesh_object("curve", verts, faces), colour, 0.04)
    if top_studs:
        start = u0 + su - top_studs if low == "front" else u0
        studs(start, v0, layer + layers, top_studs, sv, colour)


def wheel(u, v, side):
    x, y, z = to_world(u, v, 0.55)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.62, depth=0.55, location=(x, y, z),
                                        rotation=(0, math.pi / 2, 0))
    finish(bpy.context.object, "tyre", 0.05)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.25, depth=0.58, location=(x + side * 0.02, y, z),
                                        rotation=(0, math.pi / 2, 0))
    finish(bpy.context.object, "hub", 0)


def leaf(u, v, layer):
    """The little Duplo plant pieces on top: a stem and four round leaves."""
    x, y, z = to_world(u, v, layer * LAYER)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.12, depth=0.6, location=(x, y, z + 0.3))
    finish(bpy.context.object, "leaf", 0)
    for k in range(5):
        a = k * 2 * math.pi / 5
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.42,
                                             location=(x + 0.5 * math.cos(a), y + 0.5 * math.sin(a), z + 0.62))
        o = bpy.context.object
        o.scale = (1.0, 1.0, 0.25)
        finish(o, "leaf", 0)


bpy.ops.wm.read_factory_settings(use_empty=True)

# --- Layer 0: the red car base with four white wheels under the middle ---------------------
brick(5.0, -1.5, 0.25, 9, 3, "red", layers=0.75, top_studs=False)
for u in (6.6, 12.4):
    wheel(u, -1.85, -1)
    wheel(u, 1.85, 1)

# --- Layer 1: the lower body ------------------------------------------------------------------
curve(0.0, -1, 1, 2, 2, "red", layers=1.0, low="front")                 # red nose
brick(2.0, -1, 1, 4, 2, "blue", top_studs=False)
brick(6.0, -1, 1, 2, 2, "yellow", top_studs=False)
brick(8.0, -1, 1, 2, 2, "green", top_studs=False)
brick(10.0, -1, 1, 4, 2, "lime", layers=1.0, top_studs=False)
brick(14.0, -1, 1, 2, 2, "green", top_studs=False)
brick(16.0, -1, 1, 2, 2, "grey", top_studs=False)
curve(18.0, -1, 1, 3, 2, "green", layers=1.0, low="back")               # tail underside
# side rows along the body
for v, cols in ((-2, ["salmon", "red", "lime", "lime", "green"]), (1, ["blue", "salmon", "mint", "mint", "green"])):
    for k, c in enumerate(cols):
        brick(3.0 + 2 * k, v, 1, 2, 1, c)

# --- Layer 2: the upper body --------------------------------------------------------------------
slope(1.0, -1, 2, 3, 2, "white", layers=1.0, low="front", top_studs=1)  # white nose cone
brick(4.0, -1, 2, 2, 2, "salmon", top_studs=False)
brick(6.0, -1, 2, 4, 2, "mint", top_studs=False)
curve(10.0, -1, 2, 4, 2, "white", layers=1.6, low="front", top_studs=2)  # big white cockpit hump
brick(14.0, -1, 2, 1, 2, "yellow")
slope(15.0, -1, 2, 3, 2, "red", layers=1.5, low="front")               # red block before the fin
curve(18.0, -1, 2, 3, 2, "blue", layers=1.0, low="back", top_studs=1)

# --- Layer 3: cockpit, the yellow-orange spine, the tail fin --------------------------------------
curve(3.5, -1, 3, 2, 2, "white", layers=1.2, low="front", top_studs=1)  # canopy
slope(5.5, -1, 3, 4.5, 2, "yellow", layers=1.2, low="front", low_height=0.3)  # yellow spine
slope(18.0, -0.5, 3, 3.5, 1, "orange", layers=2.2, low="front", low_height=0.2, top_studs=1)  # tail fin

# --- Wings: one layer at layer 2, four studs long, from tip to tip ----------------------------
wing_u = 10.0
right = [(-8.2, 2.2, "orange", "curve"), (-6.0, 1, "white", "brick"), (-5.0, 2, "yellow", "brick"),
         (-3.0, 2, "blue", "brick")]
left = [(1.0, 2, "blue", "brick"), (3.0, 2, "yellow", "brick"), (5.0, 1, "green", "brick"),
        (6.0, 2.2, "white", "curve")]
for v0, width, colour, kind in right + left:
    brick(wing_u, v0, 2, 4, width, colour, layers=0.9 if kind == "curve" else 1.0)
brick(wing_u + 0.5, -1, 3.6, 3, 2, "wood", layers=0.35, top_studs=False)  # the wood-print tile on top
leaf(wing_u + 1.0, -3.2, 3)
leaf(wing_u + 1.5, 2.8, 3)

# --- Tail wings ----------------------------------------------------------------------------------
curve(17.0, -3.2, 2, 2.6, 2.2, "lime", layers=0.9, low="back")
curve(17.0, 1.0, 2, 2.6, 2.2, "blue", layers=0.9, low="back")

# Join everything into one object (materials stay per brick), apply the bevels.
for o in bpy.context.scene.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = bpy.context.scene.objects[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
obj.name = "duploflieger"
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)  # hand-made slopes and curves face outward
bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.out), export_format="GLB", export_yup=True,
                          export_apply=True, export_animations=False)
print("DUPLO OK: %s, %d triangles, %d bricks' worth of materials" % (args.out, tris, len(MATS)))
