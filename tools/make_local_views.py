"""Four clean views of a real toy from its photos with local FLUX.2 [klein] (no Codex), for Pixal3D.

    tools\\.venv\\Scripts\\python.exe tools\\make_local_views.py --id traktor [--count 3]
    tools\\.venv\\Scripts\\python.exe tools\\make_local_views.py --id traktor --pick front=2,left=1,back=3,right=1

Step 1 (no --pick): each photo in PHOTOS is cut out (rembg), put on white, and used as image 1 of
a FLUX edit: "a clean product render of this toy, seen straight from <side>, orthographic, on
black". --count variants per view (seeds 1..N) go to art/toys/local_views/variants/ plus a contact
sheet <id>-sheet.png to choose from (not in git).
Step 2 (--pick): the chosen variants are cut out (rembg) and saved as transparent
art/toys/local_views/<id>-front|left|back|right.png. Then:
    tools\\make_3d_toy.py --id <id> --views art/toys/local_views --model-out art/models/<id>_local.glb
"left" is the toy's own left side: its nose points left in the picture.
Starts ComfyUI if needed and stops it again (one GPU job at a time).
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "comfy"))
import comfy_api as api  # noqa: E402
from run_flux_klein import build  # noqa: E402

OUT = os.path.join(ROOT, "art", "toys", "local_views")
VAR = os.path.join(OUT, "variants")
VIEWS = ["front", "left", "back", "right"]
P = "WhatsApp Image 2026-11-23 at %s.jpeg"
# Photos per view (photos/toys/INVENTORY-2026-11-23.md) and what the toy is, for the prompt.
PHOTOS = {
    "traktor": ({"front": "11.59.28 (7)", "left": "11.59.28 (8)", "back": "11.59.28 (9)", "right": "11.59.28 (10)"},
                "a blue toy farm tractor with a grey front loader and a bucket, white wheel rims, black tyres, "
                "a cab with large windows"),
    "krankenwagen": ({"front": "11.59.29 (2)", "left": "11.59.29 (1)", "back": "11.59.29", "right": "11.59.29 (3)"},
                     "a white Duplo toy ambulance van with an orange-red base, black wheels with white hubs, its "
                     "roof shell flipped open upward at the back"),
    "zug": ({"front": "11.59.26 (2)", "left": "11.59.26 (3)", "back": "11.59.27", "right": "11.59.27 (1)"},
            "a lime green Duplo toy train carriage with a navy blue base, rounded roof edges, window openings, "
            "navy music-note prints on the sides"),
    "duplojunge": ({"front": "11.59.20", "left": "11.59.19 (3)", "back": "11.59.19 (2)", "right": "11.59.19 (1)"},
                   "a seated Duplo toy figure of a boy with short dark hair, yellow overalls and light blue sleeves"),
}
SIDE = {
    "front": "straight from the front, looking directly at its face",
    "left": "exactly from its left side, a pure side elevation with the front pointing to the left of the picture",
    "back": "straight from behind, looking directly at its back",
    "right": "exactly from its right side, a pure side elevation with the front pointing to the right of the picture",
}


def session():
    cache = os.path.join(ROOT, "tools", ".cache", "rembg")
    if not os.path.isdir(cache):  # git worktree: the model cache lives in the main checkout
        cache = os.path.join(ROOT.split(os.sep + ".claude" + os.sep)[0], "tools", ".cache", "rembg")
    os.environ.setdefault("U2NET_HOME", cache)
    from rembg import new_session
    return new_session("isnet-general-use")


def cut(img, sess):
    from rembg import remove
    rgba = np.array(remove(img.convert("RGB"), session=sess, post_process_mask=True))
    a = rgba[..., 3]
    ys, xs = np.where(a > 40)
    return Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")


def on_white(cut_img, size=1024):
    k = (size * 0.8) / max(cut_img.size)
    c = cut_img.resize((max(1, round(cut_img.width * k)), max(1, round(cut_img.height * k))), Image.LANCZOS)
    can = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    can.alpha_composite(c, ((size - c.width) // 2, (size - c.height) // 2))
    return can.convert("RGB")


def generate(toy, count):
    photos, what = PHOTOS[toy]
    sess = session()
    os.makedirs(VAR, exist_ok=True)
    refs = {}
    for v in VIEWS:
        img = ImageOps.exif_transpose(Image.open(os.path.join(ROOT, "photos", "toys", P % photos[v])))
        img.thumbnail((1600, 1600), Image.LANCZOS)
        path = os.path.join(VAR, "%s-%s-ref.png" % (toy, v))
        on_white(cut(img, sess)).save(path)
        refs[v] = path
    log = os.path.join(VAR, "comfy_server.log")
    with api.comfy_server(log):
        names = {v: api.upload(p) for v, p in refs.items()}
        for v in VIEWS:
            prompt = ("A clean studio product render of the exact toy in image 1: %s. Seen %s. Orthographic "
                      "view, no perspective, the whole toy centred and filling most of the frame, on a plain pure "
                      "black background. Keep the toy identical to image 1: same shape, same proportions, same "
                      "parts, same colours and prints. Bright even lighting, strong saturated colours, no shadow "
                      "on the ground, no text." % (what, SIDE[v]))
            for k in range(count):
                out = os.path.join(VAR, "%s-%s-%d.png" % (toy, v, k + 1))
                entry = api.run(build(prompt, [names[v]], 1024, 1024, 1 + k, 4, "local_views"))
                api.copy_images(entry, [out])
                print("view %s %d done" % (v, k + 1), flush=True)
    sheet(toy, count)


def sheet(toy, count):
    cell = 256
    S = Image.new("RGB", (cell * (count + 1), (cell + 16) * 4), "white")
    d = ImageDraw.Draw(S)
    for r, v in enumerate(VIEWS):
        files = ["%s-%s-ref.png" % (toy, v)] + ["%s-%s-%d.png" % (toy, v, k + 1) for k in range(count)]
        for c, f in enumerate(files):
            p = os.path.join(VAR, f)
            if os.path.exists(p):
                im = Image.open(p).convert("RGB")
                im.thumbnail((cell, cell))
                S.paste(im, (c * cell, r * (cell + 16) + 16))
            d.text((c * cell + 4, r * (cell + 16) + 2), "%s %s" % (v, "photo" if c == 0 else c), fill="black")
    path = os.path.join(VAR, "%s-sheet.png" % toy)
    S.save(path)
    print("SHEET:", path)


def pick(toy, picks):
    """picks: view=N (variant N), view=photo (the photo cut-out itself), view=flip-<other>-N (variant
    N of the other side, mirrored: for a side FLUX got wrong on a symmetric toy). All four views
    are brought to one common height (the toy is equally tall from every side), then to one scale."""
    sess = session()
    crops = {}
    for item in picks.split(","):
        v, n = item.split("=")
        mirror = n.startswith("flip-")
        if mirror:
            _, other, n = n.split("-")
        else:
            other = v
        name = "%s-%s-ref.png" % (toy, other) if n == "photo" else "%s-%s-%s.png" % (toy, other, n)
        c = cut(Image.open(os.path.join(VAR, name)), sess)
        crops[v] = ImageOps.mirror(c) if mirror else c
    for v, c in crops.items():
        crops[v] = c.resize((max(1, round(c.width * 600 / c.height)), 600), Image.LANCZOS)
    k = min(1.0, 930 / max(max(c.size) for c in crops.values()))
    for v, c in crops.items():
        c = c.resize((max(1, round(c.width * k)), max(1, round(c.height * k))), Image.LANCZOS)
        can = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        can.alpha_composite(c, ((1024 - c.width) // 2, (1024 - c.height) // 2))
        dst = os.path.join(OUT, "%s-%s.png" % (toy, v))
        can.save(dst)
        print("picked", os.path.relpath(dst, ROOT))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True, choices=sorted(PHOTOS))
    ap.add_argument("--count", type=int, default=3)
    ap.add_argument("--pick", default="")
    args = ap.parse_args()
    if args.pick:
        pick(args.id, args.pick)
    else:
        generate(args.id, args.count)


if __name__ == "__main__":
    main()
