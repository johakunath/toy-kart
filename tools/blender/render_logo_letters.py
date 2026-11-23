"""Render the "Toy Racer" lettering as glossy plastic 3D letters on a transparent background.
blender -b --python tools/blender/render_logo_letters.py -- C:/Windows/Fonts/seguibl.ttf <letters.png> 1500 128
(env TEXT="TR" PICK="03" for the app icon letters). Then tools/make_logo.py and tools/make_app_icon.py.
"""
import bpy, bmesh, sys, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
FONT, OUT, W, SAMPLES = args[0], args[1], int(args[2]), int(args[3])
TEXT = __import__("os").environ.get("TEXT", "Toy Racer")
# strong toy-brick colours, one per letter, left to right
COLOURS = [
    (0.80, 0.01, 0.01),  # T red
    (1.00, 0.42, 0.00),  # o orange
    (1.00, 0.78, 0.00),  # y yellow
    (0.00, 0.20, 0.85),  # R blue
    (0.80, 0.01, 0.01),  # a red
    (0.00, 0.50, 0.06),  # c green
    (1.00, 0.42, 0.00),  # e orange
    (1.00, 0.78, 0.00),  # r yellow
]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
font = bpy.data.fonts.load(FONT)


def plastic(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = 0.3
    b.inputs["Coat Weight"].default_value = 0.5
    b.inputs["Coat Roughness"].default_value = 0.08
    return m


cu = bpy.data.curves.new("logo", "FONT")
cu.body = TEXT
cu.font = font
cu.extrude = 0.14
cu.bevel_depth = 0.04
cu.bevel_resolution = 4
cu.shear = float(__import__("os").environ.get("SHEAR", "0.12"))
cu.space_character = 1.04
cu.align_x = "CENTER"
txt = bpy.data.objects.new("logo", cu)
scene.collection.objects.link(txt)
bpy.context.view_layer.objects.active = txt
txt.select_set(True)
bpy.ops.object.convert(target="MESH")
bpy.ops.mesh.separate(type="LOOSE")
pieces = [o for o in scene.objects if o.type == "MESH"]


def box(o):
    xs = [v.co.x for v in o.data.vertices]
    ys = [v.co.y for v in o.data.vertices]
    return min(xs), min(ys), max(xs), max(ys)


# caps, sides and counters of one glyph are separate loose pieces: group them by bounding-box containment
pieces.sort(key=lambda o: -(box(o)[2] - box(o)[0]) * (box(o)[3] - box(o)[1]))
groups = []
for o in pieces:
    x0, y0, x1, y1 = box(o)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    for g in groups:
        gx0, gy0, gx1, gy1 = box(g[0])
        if gx0 - 0.01 <= cx <= gx1 + 0.01 and gy0 - 0.01 <= cy <= gy1 + 0.01:
            g.append(o)
            break
    else:
        groups.append([o])
parts = []
for g in groups:
    bpy.ops.object.select_all(action="DESELECT")
    for o in g:
        o.select_set(True)
    bpy.context.view_layer.objects.active = g[0]
    if len(g) > 1:
        bpy.ops.object.join()
    parts.append(g[0])
parts.sort(key=lambda o: (box(o)[0] + box(o)[2]) / 2)
COLOURS = [COLOURS[int(c)] for c in __import__("os").environ.get("PICK", "01234567")]
assert len(parts) == len(COLOURS), "expected %d letters, got %d" % (len(COLOURS), len(parts))
for i, o in enumerate(parts):
    o.data.materials.clear()
    o.data.materials.append(plastic("m%d" % i, COLOURS[i]))
    bpy.context.view_layer.objects.active = o
    for p in parts:
        p.select_set(p == o)
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    # playful bounce: each letter hops and tilts a little
    o.location.y += 0.06 * math.sin(i * 1.9 + 0.3)
    o.rotation_euler = (math.radians(90), math.radians(5 * math.sin(i * 2.4 + 1.0)), 0)
    o.location = (o.location.x, 0, o.location.y)

bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
for o in parts:
    o.select_set(True)
bpy.context.view_layer.update()

lo = Vector((1e9,) * 3)
hi = Vector((-1e9,) * 3)
for o in parts:
    for v in o.data.vertices:
        w = o.matrix_world @ v.co
        lo = Vector(map(min, lo, w))
        hi = Vector(map(max, hi, w))
mid = (lo + hi) / 2
size = hi - lo

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = size.x * 1.06
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
cam.location = mid + Vector((0.5, -10, -1.6))
cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam


def area(name, energy, size_, loc):
    l = bpy.data.lights.new(name, "AREA")
    l.energy = energy
    l.size = size_
    ob = bpy.data.objects.new(name, l)
    ob.location = loc
    ob.rotation_euler = (mid - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(ob)


area("key", 330, 5, (-3, -6, 5))
area("fill", 70, 6, (4, -7, -1))
area("rim", 250, 3, (4, 4, 4))
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.9, 0.95, 1.0, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.35
scene.world = world

scene.render.engine = "CYCLES"
prefs = bpy.context.preferences.addons["cycles"].preferences
for dev_type in ("OPTIX", "CUDA"):
    try:
        prefs.compute_device_type = dev_type
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        scene.cycles.device = "GPU"
        break
    except Exception:
        continue
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = W
scene.render.resolution_y = int(W * (size.z * 1.35) / (size.x * 1.06))
scene.view_settings.view_transform = "Standard"
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("RENDERED", OUT)
