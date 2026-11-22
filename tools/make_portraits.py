"""Driver portraits for the selection menu, drawn by FLUX.2 [klein] 4B in the local ComfyUI.

    tools\\.venv\\Scripts\\python.exe tools\\make_portraits.py [--ids a,b] [--count 2] [--refs <dir>]
        makes <count> variants per driver: art/toys/portraits/variants/<id>_<n>.png, plus
        art/toys/portraits/variants/sheet.png to choose from.
    tools\\.venv\\Scripts\\python.exe tools\\make_portraits.py --pick paper_baer=2,model_ben=1 ...
        copies the chosen variants to art/toys/portraits/<id>.png and installs them in the game:
        assets/portraits/<id>.png (256 px) and `portrait` in data/drivers/<id>.tres.

The reference picture of each toy is its drawing or photo cut-out (see REFS). The Kenney
characters have no drawing: tools/render_driver_refs.gd renders them first (--refs <dir>).
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import time

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "comfy"))
import comfy_api as api  # noqa: E402
import run_flux_klein as flux  # noqa: E402

VARIANTS = os.path.join(ROOT, "art", "toys", "portraits", "variants")
GODOT = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Godot", "Godot_v4.7.2-stable_win64_console.exe")

# Driver id -> reference picture (relative to the project), or None = rendered Kenney character.
REFS = {
    "paper_junge": "assets/paper/junge_front.png",
    "paper_katze": "art/toys/turnaround/katze-front.png",
    "paper_loewe": "art/toys/loewe-front.png",
    "paper_baer": "art/toys/turnaround/baer-front.png",
    "paper_polizei": "art/toys/turnaround/polizei-front.png",
    "paper_motorrad": "art/toys/turnaround/motorrad-front.png",
    "paper_flieger": "art/toys/turnaround/flieger-front.png",
    "paper_duploflieger": "assets/paper/duploflieger_front.png",
}
# What the toy is, where FLUX guesses wrong from the picture alone.
HINTS = {
    "paper_junge": "a chunky plastic toy figure of a little girl",
}
# Strong toy-brick colours, one per driver, so neighbours in the menu look different.
BACKGROUNDS = ["bright red", "bright blue", "sunny yellow", "bright green", "orange", "purple",
               "turquoise", "pink", "bright blue", "bright red", "bright green", "sunny yellow",
               "purple", "orange", "pink", "turquoise"]
PERSON = ("A square portrait icon of the character in image 1: head and shoulders, centered, facing "
          "the viewer, big happy smile, exactly the same design and colours as in image 1, clean "
          "illustrated toy style with bold strong saturated colours and soft shading, on a plain "
          "solid %s background. No text.")
VEHICLE = ("A square icon of the toy in image 1: the whole toy, centered, seen from the front and "
           "slightly from the side, exactly the same design and colours as in image 1, clean "
           "illustrated toy style with bold strong saturated colours and soft shading, on a plain "
           "solid %s background. No text.")


def drivers():
    """(id, is_vehicle) of every driver, in menu order."""
    out = []
    folder = os.path.join(ROOT, "data", "drivers")
    for name in os.listdir(folder):
        if name.endswith(".tres"):
            text = open(os.path.join(folder, name), encoding="utf-8").read()
            order = int(re.search(r"sort_order = (\d+)", text).group(1))
            out.append((order, name[:-5], "is_vehicle = true" in text))
    return [(i, v) for _, i, v in sorted(out)]


def on_white(src, dst):
    """Reference on white: transparent pixels would read as black."""
    img = Image.open(src).convert("RGBA")
    bg = Image.new("RGBA", img.size, "white")
    bg.alpha_composite(img)
    bg.convert("RGB").save(dst)
    return dst


def generate(ids, count, refs_dir):
    os.makedirs(VARIANTS, exist_ok=True)
    work = os.path.join(VARIANTS, "refs")
    os.makedirs(work, exist_ok=True)
    if any(i not in REFS for i in ids):
        if not refs_dir:
            refs_dir = work
            subprocess.run([GODOT, "--path", ROOT, "--windowed", "--resolution", "400x300", "--script",
                            "res://tools/render_driver_refs.gd", "--", "--out=" + refs_dir], check=True,
                           stdout=subprocess.DEVNULL)
    all_ids = [i for i, _ in drivers()]
    vehicle = dict(drivers())
    started = time.time()
    with api.comfy_server(os.path.join(VARIANTS, "comfy_server.log")):
        for i in ids:
            src = os.path.join(ROOT, REFS[i]) if i in REFS else os.path.join(refs_dir, i + ".png")
            ref = api.upload(on_white(src, os.path.join(work, i + "_ref.png")))
            prompt = (VEHICLE if vehicle[i] else PERSON) % BACKGROUNDS[all_ids.index(i) % len(BACKGROUNDS)]
            if i in HINTS:
                prompt = prompt.replace("in image 1", "in image 1 (%s)" % HINTS[i], 1)
            for k in range(count):
                entry = api.run(flux.build(prompt, [ref], 768, 768, 7 + k, 4, "portrait"))
                api.copy_images(entry, [os.path.join(VARIANTS, "%s_%d.png" % (i, k + 1))])
            print("PORTRAIT", i)
    sheet(ids, count)
    print("PORTRAITS OK: %d drivers (%.0f s); look at %s" % (len(ids), time.time() - started,
                                                             os.path.join(VARIANTS, "sheet.png")))


def sheet(ids, count):
    w = 192
    img = Image.new("RGB", (w * count * 2, w * ((len(ids) + 1) // 2) + 0), "grey")
    draw = ImageDraw.Draw(img)
    for n, i in enumerate(ids):
        for k in range(count):
            x, y = ((n % 2) * count + k) * w, (n // 2) * w
            img.paste(Image.open(os.path.join(VARIANTS, "%s_%d.png" % (i, k + 1))).convert("RGB").resize((w, w)), (x, y))
            draw.rectangle([x, y, x + 120, y + 16], fill="white")
            draw.text((x + 3, y + 2), "%s %d" % (i.split("_", 1)[1], k + 1), fill="black")
    img.save(os.path.join(VARIANTS, "sheet.png"))


def install(picks):
    out_dir = os.path.join(ROOT, "assets", "portraits")
    os.makedirs(out_dir, exist_ok=True)
    for pick in picks.split(","):
        i, k = pick.split("=")
        chosen = os.path.join(ROOT, "art", "toys", "portraits", i + ".png")
        shutil.copy(os.path.join(VARIANTS, "%s_%s.png" % (i, k)), chosen)
        Image.open(chosen).convert("RGB").resize((256, 256), Image.LANCZOS).save(os.path.join(out_dir, i + ".png"))
        tres = os.path.join(ROOT, "data", "drivers", i + ".tres")
        text = open(tres, encoding="utf-8").read()
        res_path = "res://assets/portraits/%s.png" % i
        if res_path not in text:
            ids = [int(n) for n in re.findall(r'id="(\d+)"', text)]
            new_id = str(max(ids) + 1)
            line = '[ext_resource type="Texture2D" path="%s" id="%s"]\n' % (res_path, new_id)
            text = text.replace("\n[resource]", line + "\n[resource]", 1)
            text = re.sub(r"\nportrait = .*", "", text)
            text = text.rstrip("\n") + '\nportrait = ExtResource("%s")\n' % new_id
            open(tres, "w", encoding="utf-8", newline="\n").write(text)
        print("INSTALLED", i)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", default="")
    ap.add_argument("--count", type=int, default=2)
    ap.add_argument("--refs", default="")
    ap.add_argument("--pick", default="")
    args = ap.parse_args()
    if args.pick:
        install(args.pick)
        return
    ids = args.ids.split(",") if args.ids else [i for i, _ in drivers()]
    generate(ids, args.count, args.refs)


if __name__ == "__main__":
    main()
