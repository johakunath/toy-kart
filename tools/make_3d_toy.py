"""One command from four drawn views to a 3D toy in the game (docs/MODELS_3D.md).

    tools\\.venv\\Scripts\\python.exe tools\\make_3d_toy.py --id baer [--apply]
        [--height 0.7] [--even 0.7] [--turn 0] [--resolution 0] [--skip-generate]

Reads art/toys/turnaround/<id>-front.png, -left.png, -back.png, -right.png (transparent PNGs from
Codex, see docs/CODEX_TURNAROUND.md; or photo cut-outs with --views art/toys/photo_views, made by
tools/make_photo_views.py) and:
1. frames them for Pixal3D: square, black, one common scale, toy at 1/1.1 of the frame
   -> art/models/<id>_rig/
2. runs Pixal3D in the local ComfyUI (starts the server if needed, stops it again afterwards)
   -> art/models/<id>_pixal3d.glb (about 10 minutes)
3. cleans it in Blender: 12k triangles, matte, evened colour, 0.7 m tall, facing forward
   -> assets/models/toys/<id>.glb, art/models/<id>_sheet.png (look at this), art/models/<id>_edit.blend
4. with --apply: switches data/drivers/paper_<id>.tres to the 3D model (keeps the paper pictures)

Prints one line per step and "3D TOY: OK" or "3D TOY: FAIL".
"""
import argparse
import os
import re
import subprocess
import sys
import time
import urllib.request

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# ComfyUI sits next to the project folder (also when this runs from a git worktree).
COMFY = os.environ.get("COMFYUI_DIR", r"C:\Users\Johannes\AI projects Local\ComfyUI")
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.3\blender.exe"
SERVER = "http://127.0.0.1:8188"
VIEWS = ["front", "left", "back", "right"]


def fail(msg):
    print("3D TOY: FAIL (%s)" % msg)
    sys.exit(1)


def frame_views(toy_id, out_dir, src_dir):
    crops = {}
    for view in VIEWS:
        path = os.path.join(src_dir, "%s-%s.png" % (toy_id, view))
        if not os.path.exists(path):
            fail("missing %s" % os.path.relpath(path, ROOT))
        im = Image.open(path).convert("RGBA")
        a = np.array(im)[..., 3]
        ys, xs = np.where(a > 20)
        if len(xs) == 0:
            fail("%s is empty" % path)
        crops[view] = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    heights = [c.height for c in crops.values()]
    if max(heights) > 1.12 * min(heights):
        print("  warning: views differ in height by %.0f %% (should be the same scale)"
              % (100 * (max(heights) / min(heights) - 1)))
    biggest = max(max(c.size) for c in crops.values())
    k = (1024 / 1.1) / biggest
    os.makedirs(out_dir, exist_ok=True)
    for view, c in crops.items():
        c = c.resize((max(1, round(c.width * k)), max(1, round(c.height * k))), Image.LANCZOS)
        can = Image.new("RGBA", (1024, 1024), (0, 0, 0, 255))
        can.alpha_composite(c, ((1024 - c.width) // 2, (1024 - c.height) // 2))
        can.convert("RGB").save(os.path.join(out_dir, "%s_%s.png" % (toy_id, view)))
    print("1 views framed: %s" % os.path.relpath(out_dir, ROOT))


def server_up():
    try:
        urllib.request.urlopen(SERVER + "/system_stats", timeout=3)
        return True
    except Exception:
        return False


def generate(toy_id, rig_dir, raw_glb, resolution):
    started = None
    if not server_up():
        log = open(os.path.join(ROOT, "art", "models", "comfy_server.log"), "w")
        started = subprocess.Popen([os.path.join(COMFY, ".venv", "Scripts", "python.exe"), "main.py",
                                    "--listen", "127.0.0.1", "--port", "8188", "--disable-auto-launch"],
                                   cwd=COMFY, stdout=log, stderr=subprocess.STDOUT)
        for _ in range(180):
            if server_up():
                break
            if started.poll() is not None:
                fail("ComfyUI did not start, see art/models/comfy_server.log")
            time.sleep(2)
        else:
            fail("ComfyUI did not answer in 6 minutes")
    try:
        cmd = [sys.executable, os.path.join(ROOT, "tools", "comfy", "run_pixal3d.py"), "--views", rig_dir,
               "--name", toy_id, "--out", raw_glb, "--comfy", COMFY]
        if resolution:
            cmd += ["--resolution", str(resolution)]
        res = subprocess.run(cmd, capture_output=True, text=True)
        line = [l for l in res.stdout.splitlines() if l.startswith("PIXAL3D")]
        if res.returncode != 0:
            fail(line[-1] if line else res.stderr[-500:])
        print("2 " + (line[-1] if line else "generated"))
    finally:
        if started is not None:
            started.terminate()


def prepare(toy_id, raw_glb, args):
    sheet = os.path.join(ROOT, "art", "models", "%s%s_sheet.png" % (toy_id, args.tag))
    model = os.path.abspath(args.model_out) if args.model_out else \
        os.path.join(ROOT, "assets", "models", "toys", "%s.glb" % toy_id)
    size = ["--height", str(args.height)]
    tres = os.path.join(ROOT, "data", "drivers", "paper_%s.tres" % toy_id)
    if os.path.exists(tres):
        s = open(tres, encoding="utf-8").read()
        width = re.search(r"^vehicle_width = ([\d.]+)", s, re.M)
        if re.search(r"^is_vehicle = true", s, re.M):
            size = ["--width", width.group(1) if width else "1.0"]  # a toy vehicle: as wide as its card
    if args.length > 0:
        size = ["--length", str(args.length)]
    cmd = [BLENDER, "-b", "--python", os.path.join(ROOT, "tools", "blender", "prepare_toy_model.py"), "--",
           "--in", raw_glb, "--out", model,
           *size, "--matte", "--even", str(args.even), "--turn", str(args.turn),
           "--blend", os.path.join(ROOT, "art", "models", "%s%s_edit.blend" % (toy_id, args.tag)), "--sheet", sheet]
    if args.mirror:
        cmd.append("--mirror")
    drawing = os.path.join(args.views, "%s-front.png" % toy_id)
    if os.path.exists(drawing):
        cmd += ["--match", drawing]
    res = subprocess.run(cmd, capture_output=True, text=True)
    ok = [l for l in res.stdout.splitlines() if l.startswith("PREPARE OK")]
    for l in res.stdout.splitlines():
        if l.startswith("PREPARE MATCH"):
            print("  " + l)
    if not ok:
        fail("Blender: " + (res.stdout + res.stderr)[-800:])
    print("3 " + ok[0].split(":  ", 1)[-1] + "; look at " + os.path.relpath(sheet, ROOT))


def apply(toy_id):
    path = os.path.join(ROOT, "data", "drivers", "paper_%s.tres" % toy_id)
    s = open(path, encoding="utf-8").read()
    glb = "res://assets/models/toys/%s.glb" % toy_id
    if glb not in s:
        ids = [int(x) for x in re.findall(r'id="(\d+)"', s)]
        new_id = str(max(ids) + 1 if ids else 9)
        head, rest = s.split("\n[resource]", 1)
        head += '[ext_resource type="PackedScene" path="%s" id="%s"]\n' % (glb, new_id)
        rest = re.sub(r"\ntype = \d+", "\ntype = 0", rest)
        rest = rest.replace('\nscript = ExtResource("1")',
                            '\nscript = ExtResource("1")\nmodel_scene = ExtResource("%s")\nanimation = ""\nmodel_scale = 1.0'
                            % new_id, 1)
        s = head + "\n[resource]" + rest
        open(path, "w", encoding="utf-8").write(s)
    print("4 driver switched to 3D: %s" % os.path.relpath(path, ROOT))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True, help="toy id as in pairs.json: baer, flieger, polizei ...")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--height", type=float, default=0.7)
    ap.add_argument("--even", type=float, default=0.7)
    ap.add_argument("--turn", type=float, default=0.0)
    ap.add_argument("--length", type=float, default=0.0, help="size by length (cars, bikes); kart is about 1.3")
    ap.add_argument("--resolution", type=int, default=0)
    ap.add_argument("--views", default=os.path.join(ROOT, "art", "toys", "turnaround"),
                    help="folder with <id>-front|left|back|right.png (art/toys/photo_views for photo cut-outs)")
    ap.add_argument("--skip-generate", action="store_true", help="reuse art/models/<id>_pixal3d.glb")
    ap.add_argument("--mirror", action="store_true",
                    help="flip left and right in Blender (Pixal3D gave a mirror image: lettering reads backwards)")
    ap.add_argument("--tag", default="", help="suffix for the work files (art/models/<id><tag>_*), e.g. _local")
    ap.add_argument("--model-out", default="", help="game model path instead of assets/models/toys/<id>.glb "
                                                     "(a trial model that must not replace the game's)")
    args = ap.parse_args()
    os.makedirs(os.path.join(ROOT, "art", "models"), exist_ok=True)
    rig = os.path.join(ROOT, "art", "models", "%s%s_rig" % (args.id, args.tag))
    raw = os.path.join(ROOT, "art", "models", "%s%s_pixal3d.glb" % (args.id, args.tag))
    if not args.skip_generate:
        frame_views(args.id, rig, os.path.abspath(args.views))
        generate(args.id, rig, raw, args.resolution)
    prepare(args.id, raw, args)
    if args.apply:
        apply(args.id)
    print("3D TOY: OK")


if __name__ == "__main__":
    main()
