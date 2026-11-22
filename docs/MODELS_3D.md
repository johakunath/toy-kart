# 3D toys

How a toy becomes a 3D driver. Milestone 3. Koba (the lion) is done; Bobo and the fox are next.
Blocky Duplo toys are built by Claude from simple shapes in Blender instead.

Everything runs on this PC; nothing is uploaded and no account is needed. Johannes does nothing
in a terminal: Claude runs every step.

## The pipeline

| Step | Tool | Result |
| --- | --- | --- |
| 1. Four views of the toy: front, left, back, right | Codex drawings (`art/toys/`, `art/toys/turnaround/`) or frames from a turntable video | square PNGs |
| 2. Raw 3D model | Pixal3D in local ComfyUI: `tools/comfy/run_pixal3d.py` | `art/models/<id>_pixal3d.glb` (~700k triangles, 45 MB; not in git) |
| 3. Game model | Blender 5.3: `tools/blender/prepare_toy_model.py` | `assets/models/toys/<id>.glb` (12k triangles, 0.7 m tall, faces forward) |
| 4. In the game | `data/drivers/paper_<id>.tres`: `type = 0`, `model_scene`, `model_scale = 1.0`, `animation = ""` | the toy drives as 3D |

The driver needs no rig and no animation file: `DriverRig` leans, bobs and hops it in code, like
the cards. Keep the paper textures in the `.tres` (portraits use them later).

## Step 1: the views

Pixal3D wants four square pictures on black: `<name>_front.png`, `_left.png`, `_back.png`,
`_right.png`. "left" is the toy's own left side (it faces left in the picture). Same scale in
every view, the toy filling about 1/1.1 of the frame at its widest. Straight side and back views
matter most: the chase camera sees the back all race long.

Koba's views came from Johannes' screen recording of Tripo's preview (Tripo's free plan has no
downloads): `tools/comfy/views_from_turntable.py` records how. Results:
`art/toys/turnaround/loewe-pixal3d-*.png`. For the next toys, drawn turnaround views from Codex
are cleaner (brief: `docs/ART_BRIEF.md`, optional views).

## Step 2: Pixal3D in ComfyUI

Installed outside the repo: `C:\Users\Johannes\AI projects Local\ComfyUI` (git checkout of
ComfyUI master, `.venv` with PyTorch 2.11 + CUDA 12.8). Models in `ComfyUI\models\`, about 9 GB:
`diffusion_models\pixal3d_multiview_int8_convrot.safetensors`, `vae\trellis_2_shape_vae_bf16`,
`vae\trellis_2_texture_vae_bf16`, `clip_vision\dino_v3_L_naf_fp32`,
`background_removal\birefnet` (all from huggingface.co/Comfy-Org).

```
# start the server (keep it running)
"C:\Users\Johannes\AI projects Local\ComfyUI\.venv\Scripts\python.exe" main.py --listen 127.0.0.1 --port 8188 --disable-auto-launch
# then, from the project folder
tools\.venv\Scripts\python.exe tools\comfy\run_pixal3d.py --views <dir> --name <name> --out art/models/<id>_pixal3d.glb
```

The script takes ComfyUI's official "Pixal3D multi-views" template, puts the four pictures in
place of the turnaround sheet, and queues it. Koba took 9 minutes on the RTX 4070 at the
template's settings. `--resolution 1024` lowers the upsample stage if memory runs out.
Licence: Pixal3D is MIT (TencentARC).

## Step 3: Blender

```
"C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" -b --python tools/blender/prepare_toy_model.py --
    --in art/models/<id>_pixal3d.glb --out assets/models/toys/<id>.glb --height 0.7 --tris 12000 --tex 1024
    --sheet <scratchpad>/<id>_sheet.png
```

Look at the sheet (front, left side, back, three-quarter). If the first view shows the back,
run again with `--turn 180`. `--height` is the seated height in metres; paper cards are about 0.7.

## Step 4: in the game

Edit the driver `.tres`, `godot --headless --import`, a race screenshot with that driver
(`--driver=N`), then `tools\check.ps1`.

## Faster: one command per toy

`tools\.venv\Scripts\python.exe tools\make_3d_toy.py --id <id> --apply` does steps 2 to 4 from
Codex's turnaround drawings (`art/toys/turnaround/<id>-front|left|back|right.png`, transparent,
see `docs/CODEX_TURNAROUND.md`). It starts and stops ComfyUI by itself, sizes toy vehicles by
width, and prints one line per step. Then look at one picture, `art/models/<id>_sheet.png`, and
take one race screenshot. `--skip-generate` redoes only the Blender step.

## Duplo toys: built in Blender, no AI

`tools/blender/build_duplo_plane.py` builds the Duplo plane brick by brick (Duplo units: a stud
is 1, a layer 1.2) after the photos, then `prepare_toy_model.py --width 1.3`. The plane is a toy
vehicle (it has the red Duplo car base with wheels), so it replaces the kart.

## Using ComfyUI yourself (Johannes)

Desktop shortcut **ComfyUI (3D-Modelle)**: a black window starts, then the browser opens ComfyUI.
Closing the black window stops it (do that before playing: it holds the graphics card).
In ComfyUI: **Templates** (left) -> search "Pixal3D" -> "Pixal3D Multi-views to 3D", then
**Run**: it builds the example character (about 10 minutes), and you can turn the result in the
3D preview. Results are saved in `ComfyUI\outputd`.
For your own toys, let Claude run it: the template cuts its input sheet at fixed positions made
for its example picture, so another picture needs the four crop boxes changed.
`tools/make_3d_toy.py` feeds the four views in directly instead.

## Changing proportions by hand (Johannes, in Blender)

Each prepared toy is also saved as `art/models/<id>_edit.blend` (Koba: `loewe_edit.blend`).

1. Double-click the file; Blender opens with the toy.
2. Click the toy. Top left, switch **Object Mode** to **Sculpt Mode**.
3. Press **G** for the Grab brush. **F** and moving the mouse sets the brush size (big = gentle,
   whole-area changes). Drag on the model to pull or push. Symmetry left/right is on by default.
   Hold **Shift** while dragging to smooth. **Ctrl+Z** undoes.
4. Middle mouse button turns the view, mouse wheel zooms.
5. **Ctrl+S** saves. Tell Claude; Claude runs `prepare_toy_model.py --in art/models/<id>_edit.blend
   --even 0 ...` and the change is in the game.
