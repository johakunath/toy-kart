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
ap.add_argument("--width", type=float, default=0.0, help="size by width instead (toy vehicles)")
ap.add_argument("--length", type=float, default=0.0, help="size by length, nose to tail (cars, bikes)")
ap.add_argument("--tris", type=int, default=12000)
ap.add_argument("--tex", type=int, default=1024)
ap.add_argument("--turn", type=float, default=0.0)
ap.add_argument("--sheet", default="")
ap.add_argument("--matte", action="store_true", help="plush look: no shadow map, not metallic, soft")
ap.add_argument("--even", type=float, default=0.0,
                help="0..1: lift darker patches of the main colour toward it (nose and eyes stay)")
ap.add_argument("--match", default="", help="a drawing of the toy: scale the texture colours to match it")
ap.add_argument("--blend", default="", help="also save a .blend of the finished model, for hand edits")
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


if args.src.lower().endswith(".blend"):
    # A model Johannes edited by hand: take it as it is (it was prepared before).
    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(args.src))
    for o in list(bpy.context.scene.objects):
        if o.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(o, do_unlink=True)
else:
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
factor = (args.length / max(size.y, 1e-6) if args.length > 0 else
          args.width / max(size.x, 1e-6) if args.width > 0 else args.height / max(size.z, 1e-6))
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

def repack(img, tag):
    path = os.path.join(tmp, "%s.png" % tag)
    img.save(filepath=path)
    fresh = bpy.data.images.load(path)
    fresh.pack()
    img.user_remap(fresh)
    fresh.name = img.name
    return fresh


def principled_nodes():
    for mat in bpy.data.materials:
        if mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == "BSDF_PRINCIPLED":
                    yield mat, node


if args.matte:
    for mat, bsdf in principled_nodes():
        tree = mat.node_tree
        for link in list(tree.links):
            if link.to_node == bsdf and link.to_socket.name in ("Metallic", "Roughness"):
                tree.links.remove(link)
            elif link.to_socket.name == "Occlusion":
                tree.links.remove(link)
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.85

if args.even > 0.0:
    import numpy as np
    for mat, bsdf in principled_nodes():
        links = bsdf.inputs["Base Color"].links
        if not links or links[0].from_node.type != "TEX_IMAGE":
            continue
        img = links[0].from_node.image
        w, h = img.size
        px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
        rgb = px[:, :3]
        hi_c, lo_c = rgb.max(axis=1), rgb.min(axis=1)
        sat = (hi_c - lo_c) / np.maximum(hi_c, 1e-4)
        lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
        # The main colour: the bright, saturated majority. Features (nose, eyes) are much darker.
        body = (sat > 0.25) & (lum > 0.3)
        target = float(np.percentile(lum[body], 70)) if body.any() else 0.0
        hue_ref = np.median(rgb[body] / np.maximum(lum[body, None], 1e-4), axis=0) if body.any() else None
        lift = body & (lum < target) & (lum > 0.3)
        if lift.any():
            new_lum = lum[lift] + (target - lum[lift]) * args.even
            k = (new_lum / np.maximum(lum[lift], 1e-4))[:, None]
            # Also pull the hue a little toward the main colour (removes olive and brown blotches).
            towards = hue_ref[None, :] * new_lum[:, None]
            rgb[lift] = (rgb[lift] * k) * (1 - 0.5 * args.even) + towards * (0.5 * args.even)
        px[:, :3] = np.clip(rgb, 0.0, 1.0)
        img.pixels.foreach_set(px.ravel())
        img.update()
        repack(img, "even_%s" % mat.name)
        print("PREPARE EVEN: %s main brightness %.2f, %d %% of pixels lifted" % (
            mat.name, target, 100.0 * lift.mean()))

if args.match:
    # Pixal3D textures come out darker than the drawings. Compare the saturated (coloured) pixels
    # of the drawing and the texture, and scale each channel so their medians match.
    import numpy as np
    ref = bpy.data.images.load(os.path.abspath(args.match))
    rp = np.array(ref.pixels[:], dtype=np.float32).reshape(-1, 4)
    rp = rp[rp[:, 3] > 0.5][:, :3]
    def coloured(rgb):
        hi_c, lo_c = rgb.max(axis=1), rgb.min(axis=1)
        return rgb[((hi_c - lo_c) / np.maximum(hi_c, 1e-4) > 0.3) & (hi_c > 0.25)]
    W = np.array([0.299, 0.587, 0.114], dtype=np.float32)
    def stats(rgb):
        c = coloured(rgb)
        lum = c @ W
        sat = (c.max(axis=1) - c.min(axis=1)) / np.maximum(c.max(axis=1), 1e-4)
        return float(np.median(lum)), float(np.median(sat))
    ref_lum, ref_sat = stats(rp)
    for mat, bsdf in principled_nodes():
        links = bsdf.inputs["Base Color"].links
        if not links or links[0].from_node.type != "TEX_IMAGE":
            continue
        img = links[0].from_node.image
        px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
        tex_lum, tex_sat = stats(px[:, :3])
        gain = float(np.clip(ref_lum / max(tex_lum, 1e-3), 1.0, 1.6))  # Pixal3D textures are darker: only brighten
        satk = float(np.clip(ref_sat / max(tex_sat, 1e-3), 0.8, 1.4))
        rgb = px[:, :3] * gain
        lum = (rgb @ W)[:, None]
        px[:, :3] = np.clip(lum + (rgb - lum) * satk, 0.0, 1.0)
        img.pixels.foreach_set(px.ravel())
        img.update()
        repack(img, "match_%s" % mat.name)
        print("PREPARE MATCH: brightness x%.2f, colour strength x%.2f" % (gain, satk))

out = os.path.abspath(args.out)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=out, export_format="GLB", use_selection=True, export_yup=True,
    export_apply=True, export_animations=False, export_image_format="AUTO",
)
lo, hi = world_bounds(obj)
size = hi - lo
if args.blend:
    os.makedirs(os.path.dirname(os.path.abspath(args.blend)), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.blend), compress=True)
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
