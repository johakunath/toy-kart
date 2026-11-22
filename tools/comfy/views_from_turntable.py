"""How Koba's four Pixal3D views were made from the Tripo turntable screen recording.

Kept as a record and a starting point for the next toy; the frame numbers and the mouse-pointer
box are Koba's. Frames first: ffmpeg -i <video> -vf fps=15 <dir>/f%03d.png
(ffmpeg comes with imageio-ffmpeg in tools/.venv).

    tools\.venv\Scripts\python.exe tools\comfyiews_from_turntable.py <frame dir> <out dir>

Cuts the toy out by colour (a saturated toy on the viewer's grey background), paints out the
pointer, mirrors the side view for the other side, and lines all views up at one scale. The
framing for Pixal3D (square, black, 1/1.1 of the frame) was a second small step; the results are
art/toys/turnaround/loewe-pixal3d-*.png.
"""
import os, sys
import numpy as np, cv2
from PIL import Image
FR, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)

def load(n):
    return cv2.imread("%s/f%03d.png" % (FR, n))[:640]  # drop the viewer toolbar

def cut(bgr):
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV).astype(np.float32)
    sat = hsv[..., 1]
    hard = (sat > 70).astype(np.uint8)
    hard = cv2.morphologyEx(hard, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    n, lab, stats, _ = cv2.connectedComponentsWithStats(hard)
    big = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
    body = (lab == big).astype(np.uint8)
    # fill holes (eyes, mouth): everything not reachable from the border
    flood = body.copy() * 255
    h, w = body.shape
    m = np.zeros((h + 2, w + 2), np.uint8)
    cv2.floodFill(flood, m, (0, 0), 128)
    body = (flood != 128).astype(np.uint8)
    body = cv2.erode(body, np.ones((3, 3), np.uint8))
    alpha = cv2.GaussianBlur(body.astype(np.float32), (5, 5), 0)
    rgba = np.dstack([cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB), (alpha * 255).astype(np.uint8)])
    return rgba

side = load(14)
front = load(75)
views = {"front": front, "right": side, "back": load(34), "left": cv2.flip(side, 1)}
cuts = {}
for k, v in views.items():
    rgba = cut(v)
    if k == "front":
        # The mouse pointer sits on the edge of the right arm. Take it out of the outline,
        # close the notch, and colour the patch only from the toy's own pixels.
        y0, y1, x0, x1 = 375, 458, 475, 548
        hsv = cv2.cvtColor(v, cv2.COLOR_BGR2HSV)
        arrow = np.zeros(v.shape[:2], np.uint8)
        arrow[y0:y1, x0:x1] = (hsv[y0:y1, x0:x1, 1] < 90).astype(np.uint8)
        arrow = cv2.dilate(arrow, np.ones((5, 5), np.uint8))
        a = (rgba[..., 3] > 128).astype(np.uint8)
        a[arrow > 0] = 0
        box = a[y0 - 20:y1 + 20, x0 - 20:x1 + 20]
        box = cv2.morphologyEx(box, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (25, 25)))
        a[y0 - 20:y1 + 20, x0 - 20:x1 + 20] = box
        unknown = ((a == 0) | (arrow > 0)).astype(np.uint8) * 255
        unknown[(rgba[..., 3] > 128) & (arrow == 0)] = 0
        rgb = cv2.inpaint(np.ascontiguousarray(rgba[..., :3]), unknown, 7, cv2.INPAINT_TELEA)
        alpha = cv2.GaussianBlur(cv2.erode(a, np.ones((3, 3), np.uint8)).astype(np.float32), (5, 5), 0)
        rgba = np.dstack([rgb, (alpha * 255).astype(np.uint8)])
    ys, xs = np.where(rgba[..., 3] > 128)
    cuts[k] = (rgba, xs.min(), xs.max(), ys.min(), ys.max())
    print(k, "w=%d h=%d" % (xs.max() - xs.min(), ys.max() - ys.min()))
L = int(max(max(c[2] - c[1], c[4] - c[3]) for c in cuts.values()) * 1.18)
for k, (rgba, xa, xb, ya, yb) in cuts.items():
    img = Image.fromarray(rgba).crop((xa, ya, xb + 1, yb + 1))
    can = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    can.paste(img, ((L - img.width) // 2, L - int(L * 0.07) - img.height), img)
    can.resize((1024, 1024), Image.LANCZOS).save("%s/%s.png" % (OUT, k))
sheet = Image.new("RGBA", (4096, 1024), (255, 255, 255, 255))
for i, k in enumerate(["front", "right", "back", "left"]):
    v = Image.open("%s/%s.png" % (OUT, k)); sheet.paste(v, (i * 1024, 0), v)
sheet.convert("RGB").resize((1600, 400)).save(OUT + "_sheet.png")
