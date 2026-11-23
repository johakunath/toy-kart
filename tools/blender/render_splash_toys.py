"""Render all toys in one group picture on a transparent background (with contact shadows).
blender -b --python tools/blender/render_splash_toys.py -- assets/models/toys <toys.png> 1920 1080 160
Then: tools/make_splash.py <toys.png> assets/ui/logo.png assets/ui/splash.png 1320
"""
import bpy, os, sys, math
from mathutils import Vector, Euler

args = sys.argv[sys.argv.index("--") + 1:]
ROOT, OUT = args[0], args[1]
W, H, SAMPLES = int(args[2]), int(args[3]), int(args[4])

# name, x, y, z, yaw deg (0 = faces camera), scale, roll deg, pitch deg
LAYOUT = [
    # flying planes beside the logo
    ("jumbo",        -4.0, 2.5, 3.45, -62, 1.3, -16, 8),
    ("flieger",       4.1, 2.5, 3.5,  58, 1.15, 16, 8),
    ("duploflieger",  0.0, 2.6, 1.9, -50, 1.3, -10, 6),
    # racing vehicles, back row, in the gaps between the figures
    ("motorrad",     -2.5, 1.5, 0.0, -22, 1.3, 0, 0),
    ("polizei",      -1.25, 1.75, 0.0, -14, 1.2, 0, 0),
    ("traktor",       0.0, 1.9, 0.0,   0, 1.2, 0, 0),
    ("krankenwagen",  1.25, 1.75, 0.0, 14, 1.2, 0, 0),
    ("zug",           2.5, 1.5, 0.0,  22, 1.25, 0, 0),
    # figures, front row
    ("baer",         -3.1, -0.3, 0.0, -20, 1.6, 0, 0),
    ("loewe",        -1.86, -0.6, 0.0, -12, 1.6, 0, 0),
    ("katze",        -0.62, -0.75, 0.0, -4, 1.6, 0, 0),
    ("junge",         0.62, -0.75, 0.0,  4, 1.6, 0, 0),
    ("duplojunge",    1.86, -0.6, 0.0, 12, 1.6, 0, 0),
    ("bauarbeiterin", 3.1, -0.3, 0.0, 20, 1.6, 0, 0),
]
only = os.environ.get("ONLY")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

for name, x, y, z, yaw, s, roll, pitch in LAYOUT:
    if only and name not in only.split(","):
        continue
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, name + ".glb"))
    new = [o for o in bpy.data.objects if o not in before]
    tops = [o for o in new if o.parent is None]
    pivot = bpy.data.objects.new("pivot_" + name, None)
    scene.collection.objects.link(pivot)
    for o in tops:
        o.parent = pivot
    if z > 0.5:  # flying: no shadow blob far away on the ground
        for o in new:
            o.visible_shadow = False
    pivot.rotation_mode = "XYZ"
    pivot.location = (x, y, z)
    pivot.rotation_euler = Euler((math.radians(pitch), math.radians(roll), math.radians(yaw)), "XYZ")
    pivot.scale = (s, s, s)
    for o in new:
        if o.type == "MESH":
            for m in o.data.materials:
                if m and m.node_tree:
                    for n in m.node_tree.nodes:
                        if n.type == "BSDF_PRINCIPLED":
                            n.inputs["Roughness"].default_value = min(n.inputs["Roughness"].default_value, 0.45)
                            n.inputs["Metallic"].default_value = 0.0

# shadow catcher ground
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
ground = bpy.context.active_object
ground.is_shadow_catcher = True

# camera
cam_data = bpy.data.cameras.new("cam")
cam_data.lens = 40
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (0, -10.4, 4.6)
target = Vector((0, 0.5, 2.0))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
cam_data.shift_y = 0.0
scene.camera = cam

# lights
sun = bpy.data.lights.new("sun", "SUN")
sun.energy = 3.2
sun.angle = math.radians(12)
so = bpy.data.objects.new("sun", sun)
so.rotation_euler = (math.radians(40), math.radians(-18), math.radians(-25))
scene.collection.objects.link(so)
world = bpy.data.worlds.new("w")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.85, 0.92, 1.0, 1)
bg.inputs[1].default_value = 1.1
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
scene.render.resolution_y = H
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("RENDERED", OUT)
