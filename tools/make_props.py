"""Turn toy photos of buildings into roadside prop cards.

Same cut-out as the paper drivers (tools/make_paper_drivers.py: rembg, trim, white sticker
outline), but bigger, and written to
  assets/props/<id>_front.png, assets/props/<id>_back.png
scripts/track/roadside.gd stands them beside the tracks as two-sided cards, but only when there
is no 3D model (tools/blender/build_duplo_buildings.py); the tower card is no longer used (it was
the station seen end-on).

Run: tools\\.venv\\Scripts\\python.exe tools\\make_props.py [--only=id,id]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_paper_drivers as paper  # noqa: E402

ROOT = paper.ROOT
PHOTOS = paper.PHOTOS
OUT = os.path.join(ROOT, "assets", "props")

# Photo names from photos/toys/INVENTORY-2026-11-23.md. crop = [left, top, right, bottom].
PROPS = [
    {"id": "polizeiwache", "front": "WhatsApp Image 2026-11-23 at 11.59.27 (11).jpeg",
     "back": "WhatsApp Image 2026-11-23 at 11.59.27 (9).jpeg"},
    {"id": "duplo_laden", "front": "WhatsApp Image 2026-11-23 at 11.59.29 (10).jpeg",
     "back": "WhatsApp Image 2026-11-23 at 11.59.29 (12).jpeg"},
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="isnet-general-use")
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    os.environ.setdefault("U2NET_HOME", os.path.join(ROOT, "tools", ".cache", "rembg"))
    from rembg import new_session
    session = new_session(args.model)
    paper.TARGET = 768
    os.makedirs(OUT, exist_ok=True)
    only = {s for s in args.only.split(",") if s}
    for prop in PROPS:
        if only and prop["id"] not in only:
            continue
        for side in ("front", "back"):
            img = paper.cut_out(os.path.join(PHOTOS, prop[side]), session, prop.get("crop_" + side))
            # Window holes come out pure black after the hole fill: make them a toy-like dark blue.
            arr = np.array(img)
            dark = (arr[:, :, :3].max(axis=2) < 24) & (arr[:, :, 3] > 200)
            arr[dark, :3] = (38, 52, 92)
            img = Image.fromarray(arr, "RGBA")
            img.save(os.path.join(OUT, "%s_%s.png" % (prop["id"], side)), optimize=True)
            print("ok  %-18s %-5s %s" % (prop["id"], side, img.size))
    print("done")


if __name__ == "__main__":
    sys.exit(main())
