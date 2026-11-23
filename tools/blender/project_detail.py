"""Paint a detail from a front drawing onto a Pixal3D model's texture (a smeared face, a lost mouth).

    blender -b --python tools/blender/project_detail.py -- --in assets/models/toys/loewe.glb
        --out assets/models/toys/loewe.glb --image art/toys/turnaround/loewe-front.png
        --region 0.33,0.67,0.17,0.37 [--feather 0.25] [--shift 0,0]

The drawing (transparent PNG, the toy facing the viewer) is laid over the model's front view:
both are fitted to their outlines (the drawing's alpha box, the model's box seen from the front).
--region is the part to copy, as x0,x1,y0,y1 in shares of the drawing's toy box (y from the top);
it is blended in with a soft oval edge (--feather, share of the region). Only faces that look
forward get paint. --shift moves the drawing on the model (shares of the box) if it lands a bit off.
The texture's other texels stay as they are.
"""
import argparse
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--in", dest="src", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--image", required=True)
ap.add_argument("--region", required=True)
ap.add_argument("--feather", type=float, default=0.25)
ap.add_argument("--shift", default="0,0")
ap.add_argument("--hue-shift", type=float, default=0.0, help="degrees, like recolor_model.py on the model")
ap.add_argument("--sat", type=float, default=1.0, help="saturation factor for the drawing's colours")
args = ap.parse_args(argv)
rx0, rx1, ry0, ry1 = (float(x) for x in args.region.split(","))
sx, sy = (float(x) for x in args.shift.split(","))

# The drawing, cut to its toy box.
drawing = bpy.data.images.load(os.path.abspath(args.image))
dw, dh = drawing.size
d = np.array(drawing.pixels[:], dtype=np.float32).reshape(dh, dw, 4)[::-1]   # rows from the top
ys, xs = np.where(d[..., 3] > 0.1)
bx0, bx1, by0, by1 = xs.min(), xs.max(), ys.min(), ys.max()


def sample(nx, ny):
    """Drawing colour at shares (nx, ny) of its toy box (ny from the top), nearest texel."""
    px = np.clip((bx0 + nx * (bx1 - bx0)).astype(int), 0, dw - 1)
    py = np.clip((by0 + ny * (by1 - by0)).astype(int), 0, dh - 1)
    return d[py, px]


def mask(nx, ny):
    """Soft oval over the region: 1 inside, 0 outside, a smooth edge of --feather."""
    cx, cy = (rx0 + rx1) / 2, (ry0 + ry1) / 2
    r = np.sqrt(((nx - cx) / ((rx1 - rx0) / 2)) ** 2 + ((ny - cy) / ((ry1 - ry0) / 2)) ** 2)
    return np.clip((1.0 - r) / max(args.feather, 1e-3), 0.0, 1.0)


def recolour(rgb):
    """The same hue shift and saturation as the model got (recolor_model.py), so the patch matches."""
    mx, mn = rgb.max(1), rgb.min(1)
    dlt = mx - mn
    h = np.zeros_like(mx)
    m = dlt > 1e-6
    r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    rm = m & (mx == r)
    gm = m & (mx == g) & ~rm
    bm = m & ~rm & ~gm
    h[rm] = ((g - b)[rm] / dlt[rm]) % 6
    h[gm] = (b - r)[gm] / dlt[gm] + 2
    h[bm] = (r - g)[bm] / dlt[bm] + 4
    h = h * 60.0
    s0 = np.where(mx > 1e-6, dlt / np.maximum(mx, 1e-6), 0)
    fur = (h >= 25) & (h <= 80) & (s0 > 0.2)          # only the fur colours, not a brown nose or dark lines
    h = np.where(fur, (h + args.hue_shift) % 360.0, h)
    s_ = np.where(fur, np.clip(s0 * args.sat, 0, 1), s0)
    c = mx * s_
    hp = h / 60.0
    x = c * (1 - np.abs(hp % 2 - 1))
    z = np.zeros_like(h)
    conds = [hp < 1, hp < 2, hp < 3, hp < 4, hp < 5, hp >= 5]
    out = np.stack([np.select(conds, [c, x, z, z, x, c]), np.select(conds, [x, c, c, x, z, z]),
                    np.select(conds, [z, z, x, c, c, x])], -1)
    return out + (mx - c)[:, None]


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.src))
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
me = obj.data
mw = obj.matrix_world
verts = np.array([tuple(mw @ v.co) for v in me.vertices])
xmin, xmax = verts[:, 0].min(), verts[:, 0].max()
zmin, zmax = verts[:, 2].min(), verts[:, 2].max()

mat = obj.material_slots[0].material
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
img = bsdf.inputs["Base Color"].links[0].from_node.image
W_, H_ = img.size
tex = np.array(img.pixels[:], dtype=np.float32).reshape(H_, W_, 4)
uv = me.uv_layers.active.data
me.calc_loop_triangles()
painted = 0
for tri in me.loop_triangles:
    n = mw.to_3x3() @ Vector(tri.normal)
    if n.y > -0.35:                      # only faces that look forward (the front is -Y)
        continue
    p = verts[list(tri.vertices)]
    nx = (p[:, 0] - xmin) / (xmax - xmin) - sx
    ny = (zmax - p[:, 2]) / (zmax - zmin) - sy
    if nx.max() < rx0 or nx.min() > rx1 or ny.max() < ry0 or ny.min() > ry1:
        continue
    t = np.array([tuple(uv[i].uv) for i in tri.loops]) * [W_, H_]
    x0, x1 = int(np.floor(t[:, 0].min())) - 1, int(np.ceil(t[:, 0].max())) + 1
    y0, y1 = int(np.floor(t[:, 1].min())) - 1, int(np.ceil(t[:, 1].max())) + 1
    gx, gy = np.meshgrid(np.arange(max(x0, 0), min(x1, W_)), np.arange(max(y0, 0), min(y1, H_)))
    if gx.size == 0:
        continue
    px, py = gx.ravel() + 0.5, gy.ravel() + 0.5
    (ax, ay), (bx, by), (cx, cy) = t
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-9:
        continue
    l1 = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / den
    l2 = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / den
    l3 = 1 - l1 - l2
    inside = (l1 > -0.08) & (l2 > -0.08) & (l3 > -0.08)    # a little over the edge: no seams
    if not inside.any():
        continue
    l1, l2, l3 = l1[inside], l2[inside], l3[inside]
    qx = l1 * nx[0] + l2 * nx[1] + l3 * nx[2]
    qy = l1 * ny[0] + l2 * ny[1] + l3 * ny[2]
    m = mask(qx, qy)
    col = sample(qx, qy).copy()
    if args.hue_shift or args.sat != 1.0:
        col[:, :3] = recolour(col[:, :3])
    m = m * col[:, 3]
    if not (m > 0).any():
        continue
    ix, iy = gx.ravel()[inside], gy.ravel()[inside]
    tex[iy, ix, :3] = tex[iy, ix, :3] * (1 - m[:, None]) + col[:, :3] * m[:, None]
    painted += int((m > 0).sum())
img.pixels[:] = tex.ravel()
img.update()
img.pack()   # packs the edited buffer
bpy.ops.export_scene.gltf(filepath=os.path.abspath(args.out), export_format="GLB", export_yup=True,
                          export_apply=True, export_animations=False)
print("PROJECT OK: %d texels painted, %s" % (painted, os.path.abspath(args.out)))
