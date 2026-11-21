"""Turn toy photo pairs into paper drivers.

Reads photos/toys/pairs.json (plus any <id>-front.* / <id>-back.* files), removes the background
locally with rembg (free, runs on this PC), trims, adds a white sticker outline, and writes
  assets/paper/<id>_front.png, assets/paper/<id>_back.png, data/drivers/paper_<id>.tres

Run via tools/make_paper_drivers.ps1. Existing .tres files are kept unless --force is given,
so hand-tuned values (name, card height) survive a re-run.
"""
import argparse
import json
import os
import re
import sys

import numpy as np
from PIL import Image, ImageFilter, ImageOps
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHOTOS = os.path.join(ROOT, "photos", "toys")
OUT_IMG = os.path.join(ROOT, "assets", "paper")
OUT_RES = os.path.join(ROOT, "data", "drivers")
TARGET = 512      # longest side of the finished cut-out in pixels
OUTLINE = 7       # white sticker border in pixels (at TARGET size)
PAD = OUTLINE + 3


def load_pairs():
    toys = []
    manifest = os.path.join(PHOTOS, "pairs.json")
    if os.path.exists(manifest):
        with open(manifest, encoding="utf-8") as f:
            toys = json.load(f).get("toys", [])
    known = {t["id"] for t in toys}
    fronts = {}
    for name in sorted(os.listdir(PHOTOS)):
        m = re.match(r"^(.+)-(front|back)\.(jpe?g|png|webp)$", name, re.I)
        if m:
            fronts.setdefault(m.group(1).lower(), {})[m.group(2).lower()] = name
    for toy_id, sides in fronts.items():
        if toy_id not in known and "front" in sides:
            toys.append({"id": re.sub(r"[^a-z0-9_]", "_", toy_id), "name": toy_id.capitalize(),
                         "front": sides["front"], "back": sides.get("back", sides["front"])})
    return toys


def cut_out(path, session, crop=None):
    from rembg import remove
    img = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    if crop:
        w, h = img.size
        img = img.crop((int(crop[0] * w), int(crop[1] * h), int(crop[2] * w), int(crop[3] * h)))
    # Work at a moderate size: plenty for a 512 px card, and faster.
    img.thumbnail((1400, 1400), Image.LANCZOS)
    rgba = remove(img, session=session, post_process_mask=True)
    arr = np.array(rgba)
    alpha = arr[:, :, 3]
    # Keep the biggest blob plus anything nearly as big; drops stray background specks.
    labels, n = ndimage.label(alpha > 100)
    if n > 1:
        sizes = ndimage.sum(alpha > 100, labels, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= 0.12 * sizes.max()]
        alpha = np.where(np.isin(labels, keep), alpha, 0).astype(np.uint8)
    # Fill holes fully enclosed by the toy (rembg sometimes punches through light areas).
    solid = ndimage.binary_fill_holes(alpha > 100)
    alpha = np.where(solid & (alpha < 200), 255, alpha).astype(np.uint8)
    arr[:, :, 3] = alpha
    ys, xs = np.where(alpha > 40)
    if len(xs) == 0:
        raise RuntimeError("nothing left after background removal: " + path)
    arr = arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    cut = Image.fromarray(arr, "RGBA")
    scale = (TARGET - 2 * PAD) / max(cut.size)
    cut = cut.resize((max(1, round(cut.width * scale)), max(1, round(cut.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (cut.width + 2 * PAD, cut.height + 2 * PAD), (255, 255, 255, 0))
    canvas.paste(cut, (PAD, PAD), cut)
    # White sticker outline: grow the alpha, put white underneath.
    a = canvas.getchannel("A")
    grown = a.filter(ImageFilter.MaxFilter(2 * OUTLINE + 1)).filter(ImageFilter.GaussianBlur(1.2))
    grown = grown.point(lambda v: 255 if v > 110 else 0).filter(ImageFilter.GaussianBlur(0.8))
    sticker = Image.new("RGBA", canvas.size, (255, 255, 255, 0))
    sticker.putalpha(grown)
    sticker.alpha_composite(canvas)
    return sticker


TRES = """[gd_resource type="Resource" script_class="DriverDef" format=3]

[ext_resource type="Script" path="res://scripts/core/driver_def.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/paper/{id}_front.png" id="2"]
[ext_resource type="Texture2D" path="res://assets/paper/{id}_back.png" id="3"]

[resource]
script = ExtResource("1")
id = "paper_{id}"
display_name = "{name}"
type = 1
sort_order = {order}
front_texture = ExtResource("2")
back_texture = ExtResource("3")
card_height = {height:.2f}
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="isnet-general-use")
    ap.add_argument("--force", action="store_true", help="overwrite existing .tres files")
    ap.add_argument("--only", default="", help="comma separated toy ids")
    args = ap.parse_args()
    os.environ.setdefault("U2NET_HOME", os.path.join(ROOT, "tools", ".cache", "rembg"))
    from rembg import new_session
    session = new_session(args.model)
    os.makedirs(OUT_IMG, exist_ok=True)
    os.makedirs(OUT_RES, exist_ok=True)
    only = {s for s in args.only.split(",") if s}
    toys = load_pairs()
    for order, toy in enumerate(toys):
        if only and toy["id"] not in only:
            continue
        sizes = {}
        for side in ("front", "back"):
            src = os.path.join(PHOTOS, toy[side])
            img = cut_out(src, session, toy.get("crop_" + side))
            img.save(os.path.join(OUT_IMG, "%s_%s.png" % (toy["id"], side)), optimize=True)
            sizes[side] = img.size
        aspect = max(sizes["front"][0] / sizes["front"][1], sizes["back"][0] / sizes["back"][1])
        height = 0.85 if aspect <= 1.0 else max(0.45, 0.85 / aspect)
        tres = os.path.join(OUT_RES, "paper_%s.tres" % toy["id"])
        if args.force or not os.path.exists(tres):
            with open(tres, "w", encoding="utf-8", newline="\n") as f:
                f.write(TRES.format(id=toy["id"], name=toy["name"], order=10 + order, height=height))
        print("ok  %-10s front %s  back %s  card %.2f m" % (toy["id"], sizes["front"], sizes["back"], height))
    print("done: %d toys" % len(toys))


if __name__ == "__main__":
    sys.exit(main())
