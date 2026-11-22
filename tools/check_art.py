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
    # Turnaround sets for 3D (docs/CODEX_TURNAROUND.md): four views that must match each other.
    turn_dir = os.path.join(ART, "turnaround")
    for toy in toys:
        paths = {v: os.path.join(turn_dir, "%s-%s.png" % (toy["id"], v)) for v in ("front", "left", "back", "right")}
        present = [v for v, p in paths.items() if os.path.exists(p)]
        if not present:
            continue
        problems = []
        if len(present) < 4:
            problems.append("missing " + ", ".join(v for v in paths if v not in present))
        boxes = {}
        for v in present:
            img = Image.open(paths[v])
            own, size = check(paths[v])
            problems += ["%s: %s" % (v, p) for p in own]
            if img.size[0] != img.size[1]:
                problems.append("%s: not square %s" % (v, img.size))
            if img.mode == "RGBA":
                a = np.array(img.getchannel("A"))
                ys, xs = np.where(a > 128)
                if len(ys):
                    boxes[v] = (ys.max() - ys.min(), ys.max() / a.shape[0], img.size)
        if len({b[2] for b in boxes.values()}) > 1:
            problems.append("views have different canvas sizes")
        if boxes:
            hs = [b[0] for b in boxes.values()]
            if max(hs) > 1.08 * min(hs):
                problems.append("toy height differs between views by %.0f %% (same scale needed)"
                                % (100 * (max(hs) / min(hs) - 1)))
            grounds = [b[1] for b in boxes.values()]
            if max(grounds) - min(grounds) > 0.03:
                problems.append("the toy stands on a different ground line in different views")
        found += 1
        if problems:
            failed += 1
            print("  FAIL     turnaround %s: %s" % (toy["id"], "; ".join(problems)))
        else:
            print("  ok       turnaround %s (4 views)" % toy["id"])
    print("ART CHECK: %s (%d drawings and sets, %d with problems)" % ("FAIL" if failed else "PASS", found, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
