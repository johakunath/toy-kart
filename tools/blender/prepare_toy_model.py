"""Turn a downloaded AI model (Tripo, Meshy: .glb) into a game-ready toy driver.

    blender -b --python tools/blender/prepare_toy_model.py -- --in <download.glb>
        --out assets/models/toys/<id>.glb [--height 0.7] [--tris 12000] [--tex 1024]
        [--turn 0] [--sheet <png>]

What it does, in order:
- loads the model into an empty scene and keeps only the meshes (no lights, cameras, rigs)
- joins everything into one object, turns it by --turn degrees around the up axis
- reduces it to about --tris triangles (AI models are often 100k+)
- scales it to --height metres tall, centres it, stands it on the ground (origin = bottom middle)
- shrinks textures to --tex pixels and exports a .glb that Godot imports as is
- with --sheet: renders front, side, back and three-quarter views into one PNG to check by eye

Facing: the toy must look along glTF +Z (the kart's forward). In Blender's front view (-Y) you
see its face. If the sheet's first picture shows the back, run again with --turn 180.
"""
import argparse
import math
import os
import sys
import tempfile

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--in", dest="src", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--height", type=float, default=0.7)
ap.add_argument("--tris", type=int, default=12000)
ap.add_argument("--tex", type=int, default=1024)
ap.add_argument("--turn", type=float, default=0.0)
ap.add_argument("--sheet", default="")
args = ap.parse_args(argv)


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def world_bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.src))

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    print("PREPARE FAIL: no mesh in", args.src)
    sys.exit(1)
for o in meshes:
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
    for m in list(o.modifiers):
        o.modifiers.remove(m)
    if o.data.shape_keys:
        select_only(o)
        bpy.ops.object.shape_key_remove(all=True)
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)

bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
name = os.path.splitext(os.path.basename(args.out))[0]
obj.name = name
obj.data.name = name
obj.rotation_mode = "XYZ"  # the glTF importer leaves quaternions, which ignore rotation_euler
obj.rotation_euler[2] += math.radians(args.turn)
select_only(obj)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

tris_before = triangles(obj)
# glTF splits vertices along texture seams; weld them first or decimation tears parts apart.
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.00001 * max(obj.dimensions))
bpy.ops.object.mode_set(mode="OBJECT")
if triangles(obj) > args.tris:
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = args.tris / triangles(obj)
    bpy.ops.object.modifier_apply(modifier=dec.name)

lo, hi = world_bounds(obj)
size = hi - lo
factor = args.height / max(size.z, 1e-6)
obj.scale = (factor, factor, factor)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
lo, hi = world_bounds(obj)
obj.location -= Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
bpy.ops.object.shade_smooth_by_angle() if hasattr(bpy.ops.object, "shade_smooth_by_angle") else None

# Shrink big textures. A scaled packed image must be written out and loaded again, or the
# exporter ships the original bytes under the wrong type.
tmp = tempfile.mkdtemp(prefix="toyprep_")
for i, img in enumerate(list(bpy.data.images)):
    w, h = img.size
    if max(w, h) > args.tex:
        k = args.tex / max(w, h)
        img.scale(max(1, int(w * k)), max(1, int(h * k)))
        path = os.path.join(tmp, "tex%d.png" % i)
        img.save(filepath=path)
        small = bpy.data.images.load(path)
        small.pack()
        img.user_remap(small)
        small.name = img.name

out = os.path.abspath(args.out)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=out, export_format="GLB", use_selection=True, export_yup=True,
    export_apply=True, export_animations=False, export_image_format="AUTO",
)
lo, hi = world_bounds(obj)
size = hi - lo
print("PREPARE OK: %s  triangles %d -> %d  size %.2f x %.2f x %.2f m (w x d x h)" % (
    out, tris_before, triangles(obj), size.x, size.y, size.z))

if args.sheet:
    # Four copies side by side: front, left side, back, three-quarter. One orthographic shot.
    scene = bpy.context.scene
    step = max(size.x, size.y, size.z) * 1.35
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
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 400 * len(turns)
    scene.render.resolution_y = int(400 * max(0.6, size.z * 1.15 / step))
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("SheetWorld")
    scene.render.filepath = os.path.abspath(args.sheet)
    bpy.ops.render.render(write_still=True)
    print("PREPARE SHEET:", scene.render.filepath)
