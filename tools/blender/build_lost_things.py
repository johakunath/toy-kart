"""Build the 8 lost things of the "Entdecken" mode as small toy models.

    blender -b --python tools/blender/build_lost_things.py -- --out assets/models/finds
        [--only sock,dino] [--blend tools/blender/lost_things_edit.blend]

Writes <out>/<id>.glb for: sock, remote, crayon, puzzle, brick, dummy, car, dino.
Blocky things are built from boxes and cylinders, the sock from a bent tube, the dino from
metaballs (soft, like a plush). Sizes are game metres (1 m = 5 cm in the room, but the things are
drawn bigger than real so a child sees them), origin at the bottom middle, front toward glTF +Z
(Blender -Y). Strong toy colours, a few shared materials. No AI, no downloads.
"""
import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
ap.add_argument("--only", default="")
ap.add_argument("--blend", default="")
args = ap.parse_args(argv)

COLOURS = {
    "red": (232, 40, 40), "white": (250, 248, 240), "yellow": (255, 205, 20), "dark": (44, 46, 58),
    "grey": (150, 155, 165), "blue": (30, 110, 235), "wood": (240, 200, 140), "green": (40, 190, 80),
    "lime": (150, 220, 60), "purple": (160, 80, 230), "pink": (255, 170, 200), "orange": (255, 130, 20),
    "glass": (150, 215, 255), "black": (25, 25, 30), "belly": (190, 235, 120), "navy": (25, 45, 120),
}
MATS = {}
PARTS = []


def srgb(c):
    return tuple(((x / 255.0 + 0.055) / 1.055) ** 2.4 if x / 255.0 > 0.04045 else x / 255.0 / 12.92 for x in c)


def mat(name):
    if name not in MATS:
        m = bpy.data.materials.new("find_" + name)
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*srgb(COLOURS[name]), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.55 if name in ("white", "wood", "dark") else 0.3
        m.diffuse_color = (*srgb(COLOURS[name]), 1.0)
        MATS[name] = m
    return MATS[name]


def finish(obj, colour, bevel=0.0, segments=2):
    obj.data.materials.clear()
    obj.data.materials.append(mat(colour))
    if bevel:
        b = obj.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = segments
        b.limit_method = "ANGLE"
    PARTS.append(obj)
    return obj


def box(cx, cy, cz, sx, sy, sz, colour, bevel=0.0, segments=3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx, cy, cz))
    o = bpy.context.object
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, colour, bevel, segments)


def cyl(cx, cy, cz, r, depth, colour, axis="z", verts=24, bevel=0.0, r_top=None):
    rot = {"x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0), "z": (0, 0, 0)}[axis]
    if r_top is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=(cx, cy, cz), rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r_top, depth=depth, location=(cx, cy, cz), rotation=rot)
    return finish(bpy.context.object, colour, bevel, 2)


def ball(cx, cy, cz, r, colour, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=r, location=(cx, cy, cz))
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, colour)


def torus(cx, cy, cz, major, minor, colour, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=32, minor_segments=12,
                                     location=(cx, cy, cz), rotation=rot)
    return finish(bpy.context.object, colour)


def colour_faces(obj, rule):
    """Give faces a material by where they are: rule(center) -> colour name or None."""
    me = obj.data
    names = []
    for p in me.polygons:
        c = obj.matrix_world @ p.center
        name = rule(c)
        if name is None:
            continue
        if name not in names:
            names.append(name)
            if mat(name).name not in [m.name for m in me.materials]:
                me.materials.append(mat(name))
        p.material_index = [m.name for m in me.materials].index(mat(name).name)


# --- The things ----------------------------------------------------------------------------

def build_sock():
    """A red sock lying on the floor: the leg toward the back, the foot bending to the side.
    White cuff, yellow stripes round the leg, a yellow toe."""
    curve = bpy.data.curves.new("sock", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 0.8
    curve.bevel_resolution = 6
    curve.resolution_u = 64
    spline = curve.splines.new("BEZIER")
    pts = [(0.0, 2.2, 0.0), (0.0, 0.0, 0.0), (1.6, -1.2, 0.0)]
    spline.bezier_points.add(len(pts) - 1)
    for bp, p in zip(spline.bezier_points, pts):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    spline.use_endpoint_u = True
    curve.use_fill_caps = True
    obj = bpy.data.objects.new("sock", curve)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    obj.scale = (1.0, 1.0, 0.55)     # a sock lies flat
    obj.location.z = 0.45
    bpy.ops.object.transform_apply(location=True, scale=True)
    obj.data.materials.append(mat("red"))
    PARTS.append(obj)

    def rule(c):
        if c.y > 1.75:
            return "white"           # cuff
        if 0.55 < c.y < 1.65 and int((c.y - 0.55) / 0.22) % 2 == 0:
            return "yellow"          # stripes round the leg
        if c.x > 1.15:
            return "yellow"          # toe
        return None
    colour_faces(obj, rule)
    b = obj.modifiers.new("Smooth", "SUBSURF")
    b.levels = 1


def build_remote():
    """The TV remote: a dark rounded bar with a red power button, a grey cross and coloured
    buttons, white number keys."""
    box(0, 0, 0.35, 1.7, 4.6, 0.7, "dark", bevel=0.3, segments=4)
    cyl(0, -1.75, 0.75, 0.28, 0.16, "red")
    box(0, -0.95, 0.74, 0.9, 0.3, 0.14, "grey", bevel=0.05)
    box(0, -0.95, 0.74, 0.3, 0.9, 0.14, "grey", bevel=0.05)
    for k, c in enumerate(["red", "green", "yellow", "blue"]):
        cyl(-0.54 + k * 0.36, -0.1, 0.74, 0.14, 0.12, c)
    for row in range(4):
        for col in range(3):
            box(-0.45 + col * 0.45, 0.45 + row * 0.42, 0.73, 0.3, 0.26, 0.12, "white", bevel=0.04)


def build_crayon():
    """A blue wax crayon lying on its side: hexagonal, with a white paper wrapper and stripes."""
    cyl(0, 0.0, 0.5, 0.5, 3.4, "blue", axis="y", verts=6, bevel=0.06)
    cyl(0, 0.3, 0.5, 0.53, 2.2, "white", axis="y", verts=6)
    for y in (-0.6, 1.2):
        cyl(0, y, 0.5, 0.545, 0.22, "navy", axis="y", verts=6)
    cyl(0, 0.3, 0.5, 0.545, 0.7, "blue", axis="y", verts=6)
    cyl(0, -2.05, 0.5, 0.5, 0.7, "blue", axis="y", verts=6, r_top=0.12)
    bpy.context.object.rotation_euler = (math.pi / 2, 0, 0)
    cyl(0, -2.45, 0.5, 0.12, 0.12, "blue", axis="y", verts=12)


def build_puzzle():
    """A foam puzzle-mat piece: a green square with two round tabs, two notches, and a yellow
    shape set into the top (the mats have coloured animal inlays)."""
    s = 2.4
    r = 0.65
    outline = []

    def edge(p0, p1, tab):
        n = 24
        for k in range(n):
            t = k / n
            x = p0[0] + (p1[0] - p0[0]) * t
            y = p0[1] + (p1[1] - p0[1]) * t
            mid = abs(t - 0.5) * 2 * s
            if mid < r:
                # a round tab (out) or notch (in) in the middle of the side
                nx, ny = (p1[1] - p0[1]) / (2 * s), -(p1[0] - p0[0]) / (2 * s)
                depth = math.sqrt(max(r * r - mid * mid, 0.0)) + 0.25
                x += nx * depth * tab
                y += ny * depth * tab
            outline.append((x, y))

    corners = [(-s, -s), (s, -s), (s, s), (-s, s)]
    tabs = [1, 1, -1, -1]
    for i in range(4):
        edge(corners[i], corners[(i + 1) % 4], tabs[i])
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, 0.0)) for x, y in outline]
    face = bm.faces.new(verts)
    bmesh.ops.reverse_faces(bm, faces=[face]) if face.normal.z < 0 else None
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z = 0.6
    me = bpy.data.meshes.new("puzzle")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("puzzle", me)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    finish(obj, "green", bevel=0.08, segments=2)
    # The inlay: a yellow round-eared face shape set into the top.
    cyl(0.0, -0.2, 0.61, 1.1, 0.06, "yellow", verts=32)
    cyl(-0.85, 0.75, 0.61, 0.45, 0.06, "yellow", verts=24)
    cyl(0.85, 0.75, 0.61, 0.45, 0.06, "yellow", verts=24)
    cyl(-0.35, -0.05, 0.645, 0.14, 0.04, "dark", verts=16)
    cyl(0.35, -0.05, 0.645, 0.14, 0.04, "dark", verts=16)


def build_brick():
    """A yellow Duplo brick, 2 x 4 studs."""
    box(0, 0, 0.95, 1.6, 3.2, 1.9, "yellow", bevel=0.08)
    for i in range(2):
        for j in range(4):
            cyl(-0.4 + i * 0.8, -1.2 + j * 0.8, 2.07, 0.3, 0.36, "yellow", verts=24, bevel=0.04)


def build_dummy():
    """A purple dummy standing up: the shield, a pink teat at the front, a ring at the back."""
    cyl(0, 0, 1.7, 1.45, 0.42, "purple", axis="y", verts=40, bevel=0.12)
    bpy.context.object.scale = (1.3, 1.0, 1.0)
    ball(0, -0.85, 1.7, 0.62, "pink", scale=(1.0, 1.3, 1.0))
    cyl(0, -0.3, 1.7, 0.35, 0.5, "pink", axis="y", verts=20)
    torus(0, 0.55, 1.7, 0.7, 0.18, "purple", rot=(math.pi / 2, 0, 0))
    cyl(0, 0.3, 1.7, 0.4, 0.3, "white", axis="y", verts=20)
    for x in (-1.15, 1.15):
        cyl(x, 0, 1.7, 0.28, 0.46, "white", axis="y", verts=16)   # air holes


def build_car():
    """A little orange toy car: rounded body, blue windows, black wheels with grey hubs,
    yellow headlights."""
    box(0, 0, 0.95, 2.0, 3.8, 0.8, "orange", bevel=0.3, segments=4)
    # The cabin: narrower at the top.
    bm = bmesh.new()
    lo = [(-0.85, -0.7), (0.85, -0.7), (0.85, 1.0), (-0.85, 1.0)]
    hi = [(-0.7, -0.35), (0.7, -0.35), (0.7, 0.8), (-0.7, 0.8)]
    vl = [bm.verts.new((x, y, 1.3)) for x, y in lo]
    vh = [bm.verts.new((x, y, 2.05)) for x, y in hi]
    bm.faces.new(vl[::-1])
    bm.faces.new(vh)
    for k in range(4):
        bm.faces.new((vl[k], vl[(k + 1) % 4], vh[(k + 1) % 4], vh[k]))
    me = bpy.data.meshes.new("cabin")
    bm.to_mesh(me)
    bm.free()
    cabin = bpy.data.objects.new("cabin", me)
    bpy.context.scene.collection.objects.link(cabin)
    finish(cabin, "glass", bevel=0.12)
    box(0, 0.22, 2.08, 1.45, 1.2, 0.12, "orange", bevel=0.05)
    for x in (-1.05, 1.05):
        for y in (-1.2, 1.2):
            cyl(x, y, 0.55, 0.55, 0.45, "black", axis="x", verts=24, bevel=0.08)
            cyl(x * 1.12, y, 0.55, 0.26, 0.1, "grey", axis="x", verts=16)
    for x in (-0.6, 0.6):
        cyl(x, -1.92, 1.05, 0.2, 0.1, "yellow", axis="y", verts=16)
        cyl(x, 1.92, 1.05, 0.18, 0.1, "red", axis="y", verts=16)


def build_dino():
    """A soft green toy dino: overlapping round shapes melted into one smooth body (voxel
    remesh), like a plush. Round body, neck, big head, tail, four stubby legs, a lighter belly,
    yellow spikes, big eyes."""
    shapes = [
        # (x, y, z, radius, scale)
        (0, 0, 1.75, 1.35, (0.95, 1.35, 0.9)),      # body
        (0, -1.35, 2.5, 0.75, (0.85, 0.9, 1.1)),    # neck
        (0, -1.85, 3.25, 0.68, (0.85, 0.85, 1.0)),  # upper neck
        (0, -2.4, 3.85, 0.95, (0.95, 1.1, 0.85)),   # head
        (0, -3.05, 3.65, 0.6, (0.9, 0.9, 0.7)),     # snout
    ]
    for k in range(6):                              # tail, getting thinner, curling down
        shapes.append((0, 1.35 + k * 0.55, 1.55 - k * 0.2, 0.78 - k * 0.11, (1, 1, 1)))
    for x in (-0.75, 0.75):
        for y in (-0.75, 0.85):
            shapes.append((x, y, 0.62, 0.55, (0.9, 0.9, 1.15)))   # legs
    parts = []
    for x, y, z, r, sc in shapes:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=r, location=(x, y, z))
        o = bpy.context.object
        o.scale = sc
        parts.append(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = "dino"
    rm = body.modifiers.new("Melt", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = 0.07
    sm = body.modifiers.new("Soft", "SMOOTH")
    sm.factor = 0.8
    sm.iterations = 8
    bpy.ops.object.modifier_apply(modifier="Melt")
    bpy.ops.object.modifier_apply(modifier="Soft")
    dec = body.modifiers.new("Light", "DECIMATE")
    dec.ratio = 0.25
    bpy.ops.object.modifier_apply(modifier="Light")
    body.data.materials.clear()
    body.data.materials.append(mat("green"))
    PARTS.append(body)
    colour_faces(body, lambda c: "belly" if c.z < 1.35 and abs(c.x) < 0.7 and -1.1 < c.y < 1.3 and c.z > 0.9 else None)
    for k in range(5):                              # spikes along the back
        y = -0.9 + k * 0.62
        z = 2.95 - abs(y - 0.2) * 0.22
        cyl(0, y, z, 0.34, 0.65, "yellow", verts=4, r_top=0.0, bevel=0.03)
    for x in (-0.45, 0.45):
        ball(x, -2.95, 4.2, 0.27, "white")
        ball(x * 1.08, -3.17, 4.22, 0.13, "black")
    for x in (-0.18, 0.18):
        ball(x, -3.62, 3.75, 0.07, "dark")          # nostrils


BUILDERS = {
    "sock": build_sock, "remote": build_remote, "crayon": build_crayon, "puzzle": build_puzzle,
    "brick": build_brick, "dummy": build_dummy, "car": build_car, "dino": build_dino,
}

only = [s for s in args.only.split(",") if s] or list(BUILDERS)
out_dir = os.path.abspath(args.out)
os.makedirs(out_dir, exist_ok=True)
for thing in only:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()
    PARTS.clear()
    BUILDERS[thing]()
    bpy.ops.object.select_all(action="DESELECT")
    for o in PARTS:
        o.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = thing
    obj.data.name = thing
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Origin at the bottom middle.
    pts = [v.co.copy() for v in obj.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in obj.data.vertices:
        v.co -= shift
    obj.data.update()
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    size = hi - lo
    path = os.path.join(out_dir, thing + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True,
                              export_animations=False)
    print("THING OK: %s, %d triangles, %.1f x %.1f x %.1f m" % (thing, tris, size.x, size.y, size.z))
    if args.blend:
        base, ext = os.path.splitext(os.path.abspath(args.blend))
        bpy.ops.wm.save_as_mainfile(filepath="%s_%s%s" % (base, thing, ext), compress=True)
