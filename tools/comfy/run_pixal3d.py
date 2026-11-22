"""Make a 3D model from four views with Pixal3D in a local ComfyUI (see docs/MODELS_3D.md).

    tools\\.venv\\Scripts\\python.exe tools\\comfy\\run_pixal3d.py --views <dir> --name koba
        [--server http://127.0.0.1:8188] [--comfy "C:\\Users\\Johannes\\AI projects Local\\ComfyUI"]
        [--resolution 1024] [--out <glb>]

<dir> holds <name>_front.png, <name>_left.png, <name>_back.png, <name>_right.png: square, on
black, the same scale in every view, the toy filling about 1/1.1 of the frame. "left" is the
toy's own left side (it faces left in the picture).

Takes ComfyUI's official "Pixal3D multi-views" template, replaces the turnaround-sheet input with
the four pictures, converts it to an API prompt and queues it on a running ComfyUI server. Waits
for the result and copies the newest .glb from ComfyUI's output/3d to --out.
"""
import argparse
import glob
import json
import os
import shutil
import sys
import time
import urllib.error
import urllib.request

VIEWS = ["front", "left", "back", "right"]
# Template nodes that cut the four views out of one sheet; replaced by four LoadImage nodes.
SHEET_NODES = {364, 338, 341, 342, 345, 348, 349, 350, 351, 352, 353, 192, 193, 312, 340, 343, 344, 346}
SKIP_TYPES = {"Note", "MarkdownNote"}  # previews stay: here they pass images on
CONDITIONING_NODE = 324
UPSAMPLE_NODE = 94


def http(server, path, data=None):
    req = urllib.request.Request(server + path, data=json.dumps(data).encode() if data is not None else None,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        try:
            return json.loads(body)
        except ValueError:
            raise SystemExit("PIXAL3D FAIL: %s %s" % (e.code, body[:500]))


def upload(server, path):
    boundary = "----toyracer%d" % time.time_ns()
    name = os.path.basename(path)
    with open(path, "rb") as f:
        body = (("--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"%s\"\r\n"
                 "Content-Type: image/png\r\n\r\n" % (boundary, name)).encode() + f.read() +
                ("\r\n--%s\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--%s--\r\n"
                 % (boundary, boundary)).encode())
    req = urllib.request.Request(server + "/upload/image", data=body,
                                 headers={"Content-Type": "multipart/form-data; boundary=" + boundary})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())["name"]


def ordered_inputs(info):
    """(name, spec, required) in the order the UI shows the widgets."""
    order = info.get("input_order", {})
    out = []
    for group in ("required", "optional"):
        specs = info["input"].get(group, {})
        for name in order.get(group, list(specs.keys())):
            out.append((name, specs[name]))
    return out


def is_widget(spec):
    kind = spec[0]
    if isinstance(kind, list):
        return True  # combo
    return kind in ("INT", "FLOAT", "STRING", "BOOLEAN", "COMBO", "LOAD_3D")


def to_api(workflow, object_info):
    nodes = {n["id"]: n for n in workflow["nodes"]}
    links = {l[0]: l for l in workflow["links"]}
    prompt = {}
    for nid, n in nodes.items():
        if n["type"] in SKIP_TYPES or n.get("mode", 0) in (2, 4):
            continue
        info = object_info.get(n["type"])
        if info is None:
            raise SystemExit("ComfyUI does not know node type %s (update ComfyUI)" % n["type"])
        linked = {}
        for inp in n.get("inputs", []):
            if inp.get("link") is not None:
                l = links[inp["link"]]
                if nodes[l[1]]["type"] in SKIP_TYPES:
                    continue
                linked[inp["name"]] = [str(l[1]), l[2]]
        values = list(n.get("widgets_values") or [])
        if isinstance(n.get("widgets_values"), dict):
            values = []
        inputs = {}
        vi = 0
        for name, spec in ordered_inputs(info):
            opts = spec[1] if len(spec) > 1 and isinstance(spec[1], dict) else {}
            if spec[0] == "COMFY_DYNAMICCOMBO_V3":
                # A combo whose choice brings its own settings, sent as "<name>.<setting>".
                key = values[vi]
                inputs[name] = key
                vi += 1
                option = next(o for o in opts["options"] if o["key"] == key)
                for group in ("required", "optional"):
                    for sub_name, sub_spec in option["inputs"].get(group, {}).items():
                        if is_widget(sub_spec):
                            inputs["%s.%s" % (name, sub_name)] = values[vi]
                            vi += 1
            elif is_widget(spec) and not opts.get("forceInput"):
                if vi < len(values):
                    inputs[name] = values[vi]
                vi += 1
                if opts.get("control_after_generate"):
                    vi += 1
            if name in linked:
                inputs[name] = linked[name]
        prompt[str(nid)] = {"class_type": n["type"], "inputs": inputs}
    return prompt


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--views", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--server", default="http://127.0.0.1:8188")
    ap.add_argument("--comfy", default=os.path.join(os.path.expanduser("~"), "AI projects Local", "ComfyUI"))
    ap.add_argument("--resolution", type=int, default=0, help="upsample resolution; 1024 for less VRAM")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    template = os.path.join(args.comfy, ".venv", "Lib", "site-packages", "comfyui_workflow_templates_json",
                            "templates", "3d_pixal3d_multi_views.json")
    with open(template, encoding="utf-8") as f:
        wf = json.load(f)
    object_info = http(args.server, "/object_info")

    # Drop the sheet-cutting nodes and wire four LoadImage nodes straight into the conditioning.
    wf["nodes"] = [n for n in wf["nodes"] if n["id"] not in SHEET_NODES]
    wf["links"] = [l for l in wf["links"] if l[1] not in SHEET_NODES and l[3] not in SHEET_NODES]
    cond = next(n for n in wf["nodes"] if n["id"] == CONDITIONING_NODE)
    next_link = max(l[0] for l in wf["links"]) + 1
    for i, view in enumerate(VIEWS):
        name = upload(args.server, os.path.join(args.views, "%s_%s.png" % (args.name, view)))
        nid = 9000 + i
        wf["nodes"].append({"id": nid, "type": "LoadImage", "inputs": [], "widgets_values": [name, "image"]})
        slot = next(k for k, inp in enumerate(cond["inputs"]) if inp["name"] == view)
        cond["inputs"][slot]["link"] = next_link
        wf["links"].append([next_link, nid, 0, CONDITIONING_NODE, slot, "IMAGE"])
        next_link += 1
    if args.resolution:
        up = next(n for n in wf["nodes"] if n["id"] == UPSAMPLE_NODE)
        up["widgets_values"][0] = args.resolution

    prompt = to_api(wf, object_info)
    with open(os.path.join(args.views, "%s_prompt.json" % args.name), "w", encoding="utf-8") as f:
        json.dump(prompt, f, indent=1)
    started = time.time()
    res = http(args.server, "/prompt", {"prompt": prompt, "client_id": "toyracer"})
    if res.get("error") or res.get("node_errors"):
        print("PIXAL3D FAIL:", json.dumps(res.get("error")), json.dumps(res.get("node_errors"))[:3000])
        return 1
    pid = res["prompt_id"]
    print("queued", pid)
    while True:
        time.sleep(5)
        hist = http(args.server, "/history/" + pid)
        if pid in hist:
            status = hist[pid].get("status", {})
            if status.get("status_str") == "error":
                for msg in status.get("messages", []):
                    if msg[0] == "execution_error":
                        print("PIXAL3D FAIL:", msg[1].get("node_type"), msg[1].get("exception_message"))
                return 1
            break
    glbs = [p for p in glob.glob(os.path.join(args.comfy, "output", "3d", "**", "*.glb"), recursive=True)
            if os.path.getmtime(p) >= started]
    if not glbs:
        print("PIXAL3D FAIL: finished but no .glb in output/3d")
        return 1
    newest = max(glbs, key=os.path.getmtime)
    if args.out:
        os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
        shutil.copy(newest, args.out)
    print("PIXAL3D OK: %s (%.0f s, %.1f MB)" % (args.out or newest, time.time() - started,
                                                 os.path.getsize(newest) / 1e6))
    return 0


if __name__ == "__main__":
    sys.exit(main())
