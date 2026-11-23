"""Fix the colours of a Pixal3D game model's texture after the real toy (hue drift, pale greys).

    blender -b --python tools/blender/recolor_model.py -- --in <glb> --out <glb>
        [--hue 175-215:222] [--sat 1.3] [--val 0.85] [--grey 0.6]

--hue A-B:T   texels whose hue (degrees) is between A and B and that are coloured (saturation
              above 0.2) get hue T (or, with T = +N / -N, their hue shifted by N degrees), saturation x --sat and value x --val. Pixal3D turned the
              tractor's royal blue into a light cyan blue; 175-215:222 brings it back.
--grey K      mid greys (saturation below 0.15, value 0.35..0.88) get value x K: a light grey
              loader becomes the toy's dark grey; white rims and black tyres stay as they are.
Only the base colour texture changes; the mesh is untouched.
"""
import argparse
import os
import sys

import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--in", dest="src", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--hue", default="")
ap.add_argument("--sat", type=float, default=1.0)
ap.add_argument("--val", type=float, default=1.0)
ap.add_argument("--grey", type=float, default=1.0)
args = ap.parse_args(argv)


def rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rm = m & (mx == r)
    gm = m & (mx == g) & ~rm
    bm = m & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = (b - r)[gm] / d[gm] + 2
    h[bm] = (r - g)[bm] / d[bm] + 4
    h = h * 60.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h, s, mx


def hsv_to_rgb(h, s, v):
    c = v * s
    hp = (h / 60.0) % 6
    x = c * (1 - np.abs(hp % 2 - 1))
    z = np.zeros_like(h)
    conds = [(hp < 1), (hp < 2), (hp < 3), (hp < 4), (hp < 5), (hp >= 5)]
    vals = [(c, x, z), (x, c, z), (z, c, x), (z, x, c), (x, z, c), (c, z, x)]
    r = np.select(conds, [v_[0] for v_ in vals])
    g = np.select(conds, [v_[1] for v_ in vals])
    b = np.select(conds, [v_[2] for v_ in vals])
    m = v - c
    return np.stack([r + m, g + m, b + m], -1)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.src))
done = set()
for o in bpy.context.scene.objects:
    if o.type != "MESH":
        continue
    for slot in o.material_slots:
        m = slot.material
        if not m or not m.use_nodes:
            continue
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        link = bsdf and bsdf.inputs["Base Color"].links
        if not link or link[0].from_node.type != "TEX_IMAGE":
            continue
        img = link[0].from_node.image
        if img.name in done:
            continue
        done.add(img.name)
        w, hgt = img.size
        px = np.array(img.pixels[:], dtype=np.float32).reshape(hgt, w, 4)
        h, s, v = rgb_to_hsv(px[..., :3])
        if args.hue:
            rng, target = args.hue.split(":")
            a, b = (float(x) for x in rng.split("-"))
            sel = (h >= a) & (h <= b) & (s > 0.2)
            if target[0] in "+-":   # a relative shift keeps the shades (muzzle, belly, tail tip)
                h = np.where(sel, (h + float(target)) % 360.0, h)
            else:
                h = np.where(sel, float(target), h)
            s = np.where(sel, np.clip(s * args.sat, 0, 1), s)
            v = np.where(sel, np.clip(v * args.val, 0, 1), v)
            print("RECOLOR hue: %.1f %% of texels" % (100 * sel.mean()))
        if args.grey != 1.0:
            sel = (s < 0.15) & (v > 0.35) & (v < 0.88)
            v = np.where(sel, v * args.grey, v)
            print("RECOLOR grey: %.1f %% of texels" % (100 * sel.mean()))
        px[..., :3] = hsv_to_rgb(h, s, v)
        img.pixels[:] = px.ravel()
        img.update()
        img.pack()  # packs the edited buffer (a save + reload would bring back the old packed data)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.out), export_format="GLB", export_yup=True,
                          export_apply=True, export_animations=False)
print("RECOLOR OK:", os.path.abspath(args.out), len(done), "texture(s)")
