"""Check the drawn toy art in art/toys/ against docs/ART_BRIEF.md.

    tools\\.venv\\Scripts\\python.exe tools\\check_art.py

For every toy in photos/toys/pairs.json: is there a front and a back drawing, is it a PNG with a
transparent background, big enough, the toy filling the frame and not cut off at the edges?
Prints one line per file and "ART CHECK: PASS" or "ART CHECK: FAIL". Missing drawings are only
listed (the game falls back to the photo), not counted as failures.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art", "toys")
MIN_SIDE = 1024


def check(path):
    problems = []
    img = Image.open(path)
    if img.format != "PNG":
        problems.append("not a PNG")
    if img.mode != "RGBA":
        problems.append("no alpha channel (needs a transparent background)")
        return problems, img.size
    a = np.array(img.getchannel("A"))
    if max(img.size) < MIN_SIDE:
        problems.append("too small: longest side %d px, needs %d" % (max(img.size), MIN_SIDE))
    if (a < 16).mean() < 0.05:
        problems.append("background is not transparent")
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    if (edge > 128).mean() > 0.02:
        problems.append("toy touches the image edge (leave a margin)")
    ys, xs = np.where(a > 128)
    if len(xs):
        fill = max((xs.max() - xs.min()) / a.shape[1], (ys.max() - ys.min()) / a.shape[0])
        if fill < 0.6:
            problems.append("toy is small in the frame (%.0f %%), crop closer" % (fill * 100))
    # Stray specks: semi-transparent haze or bits far from the toy.
    haze = ((a > 8) & (a < 120)).mean()
    if haze > 0.08:
        problems.append("a lot of half-transparent haze (%.0f %%)" % (haze * 100))
    return problems, img.size


def main():
    with open(os.path.join(ROOT, "photos", "toys", "pairs.json"), encoding="utf-8") as f:
        toys = json.load(f)["toys"]
    failed = 0
    found = 0
    for toy in toys:
        for side in ("front", "back"):
            path = os.path.join(ART, "%s-%s.png" % (toy["id"], side))
            if not os.path.exists(path):
                print("  missing  %s-%s.png  (%s; the photo is used)" % (toy["id"], side, toy["name"]))
                continue
            found += 1
            problems, size = check(path)
            if problems:
                failed += 1
                print("  FAIL     %s-%s.png %s: %s" % (toy["id"], side, size, "; ".join(problems)))
            else:
                print("  ok       %s-%s.png %s" % (toy["id"], side, size))
    print("ART CHECK: %s (%d drawings, %d with problems)" % ("FAIL" if failed else "PASS", found, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
