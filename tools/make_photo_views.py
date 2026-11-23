"""Four views of a toy from real photos, for Pixal3D (instead of Codex drawings).

    tools\\.venv\\Scripts\\python.exe tools\\make_photo_views.py --id traktor
        --front "<photo>" --left "<photo>" --back "<photo>" --right "<photo>" [--fit height|width]

Cuts each photo out with rembg (local), trims it and brings the four views to one common scale:
--fit height (default) gives every view the same height (tractors, cars, figures);
--fit width gives front and back the same width as the side views' length (planes: wingspan is
about the body length). Writes transparent PNGs art/toys/photo_views/<id>-front|left|back|right.png
plus <id>-sheet.png to look at. "left" is the toy's own left side: it faces left in the picture.
Then: tools\\make_3d_toy.py --id <id> --views art/toys/photo_views
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageOps
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHOTOS = os.path.join(ROOT, "photos", "toys")
OUT = os.path.join(ROOT, "art", "toys", "photo_views")
VIEWS = ["front", "left", "back", "right"]
SIZE = 1024


def cut(path, session):
    from rembg import remove
    img = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    img.thumbnail((1600, 1600), Image.LANCZOS)
    rgba = np.array(remove(img, session=session, post_process_mask=True))
    a = rgba[..., 3]
    labels, n = ndimage.label(a > 100)
    if n > 1:
        sizes = ndimage.sum(a > 100, labels, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= 0.05 * sizes.max()]
        a = np.where(np.isin(labels, keep), a, 0).astype(np.uint8)
    solid = ndimage.binary_fill_holes(a > 100)
    a = np.where(solid & (a < 200), 255, a).astype(np.uint8)
    a = np.where(a < 30, 0, a).astype(np.uint8)
    rgba[..., 3] = a
    ys, xs = np.where(a > 40)
    return Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True)
    for v in VIEWS:
        ap.add_argument("--" + v, required=True, help="photo file name in photos/toys/")
    ap.add_argument("--fit", choices=["height", "width"], default="height")
    args = ap.parse_args()
    os.environ.setdefault("U2NET_HOME", os.path.join(ROOT, "tools", ".cache", "rembg"))
    from rembg import new_session
    session = new_session("isnet-general-use")
    crops = {v: cut(os.path.join(PHOTOS, getattr(args, v)), session) for v in VIEWS}
    if args.fit == "height":
        target = {v: ("h", 700) for v in VIEWS}
    else:
        target = {v: ("w", 900) for v in VIEWS}
    os.makedirs(OUT, exist_ok=True)
    scaled = {}
    for v, c in crops.items():
        kind, px = target[v]
        k = px / (c.height if kind == "h" else c.width)
        scaled[v] = c.resize((max(1, round(c.width * k)), max(1, round(c.height * k))), Image.LANCZOS)
    biggest = max(max(c.size) for c in scaled.values())
    k = min(1.0, (SIZE / 1.1) / biggest)
    sheet = Image.new("RGBA", (SIZE * 2, SIZE // 2), (60, 60, 60, 255))
    for i, (v, c) in enumerate(scaled.items()):
        c = c.resize((max(1, round(c.width * k)), max(1, round(c.height * k))), Image.LANCZOS)
        can = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        # Common ground line: every view stands on the same bottom edge.
        ground = (SIZE + round(700 * k if args.fit == "height" else c.height)) // 2
        can.alpha_composite(c, ((SIZE - c.width) // 2, min(SIZE - c.height, ground - c.height)))
        can.save(os.path.join(OUT, "%s-%s.png" % (args.id, v)))
        sheet.alpha_composite(can.resize((SIZE // 2, SIZE // 2)), (i * SIZE // 2, 0))
        print("view %-5s %s -> %dx%d" % (v, getattr(args, v), c.width, c.height))
    sheet.convert("RGB").save(os.path.join(OUT, "%s-sheet.png" % args.id))
    print("PHOTO VIEWS OK: %s" % os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    sys.exit(main())
