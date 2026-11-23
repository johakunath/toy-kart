# 3D toys

How a toy becomes a 3D driver. Milestone 3. Done: Koba (from a video); Bobo, plane, fox, motorbike,
police car (from Codex turnaround views); the Duplo plane and the Duplo girl (built in Blender).
All 8 toys are 3D now; the paper cards stay in the `.tres` files. Blocky Duplo toys are built by Claude from simple shapes in Blender instead.
The 23 Nov toys are all 3D, built in Blender: Duplo-Junge and Bauarbeiterin (drivers,
`build_duplo_figure.py`), Krankenwagen and Zug (karts, `build_duplo_vehicle.py`), Traktor and
Jumbo (toy vehicles, `build_toy_vehicle.py`). Close-ups in the game: `docs/img/new-toys-2026-11-23.png`.
24 Nov: Sanitäter, Polizei and Koba come from Codex views + Pixal3D, the Traktor from local
FLUX views of the photos + Pixal3D; Krankenwagen (with an animated roof), Zug, Duplo-Mädchen and
Bauarbeiterin stay Blender builds. Which and why: "Local views from real photos" below.

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
width (`--length 1.3` for cars and bikes: nose to tail like a kart), and prints one line per step. Then look at one picture, `art/models/<id>_sheet.png`, and
take one race screenshot. `--skip-generate` redoes only the Blender step.

The Blender step matches the colours to the front drawing (`--match`): Pixal3D textures come
out darker, so brightness and colour strength are scaled to the drawing's (hue unchanged).
Bobo took 8 minutes, the plane 5.

## Local pictures: FLUX.2 [klein] 4B

`tools\.venv\Scripts\python.exe tools\comfy\run_flux_klein.py --prompt "..." --out <png> [--ref <png>] [--count 2]`
makes a picture from text, or edits from reference pictures ("the character in image 1 as a
portrait"). Apache 2.0, about 16 GB of model files in ComfyUI, a few seconds per picture.
First test (22 Nov 2026): driver portraits of Bobo were very good;
a ruin brick texture was good and tiled almost seamlessly; a side view of the police car was
well drawn but not exactly the same car as the drawings. A four-view turnaround sheet of Bobo on
one wide canvas failed: the "side" views came out as three-quarter back views and the clothes
changed. So turnaround views stay with Codex.
What FLUX does well here: small edits of one view. Bobo's smile is a FLUX edit of Codex's front
view (Codex's original: `art/toys/turnaround/originals/`), cut out and fitted to the exact size
and position of the original, then the 3D model was made again.
All generated pictures also stay in `ComfyUI\output`.

**Driver portraits** (the faces in the selection menu): `tools\.venv\Scripts\python.exe
tools\make_portraits.py` draws two variants per driver from its drawing, photo cut-out or (Kenney
characters) a front render made by `tools/render_driver_refs.gd`, each on its own strong
background colour, and saves a sheet to choose from (`art/toys/portraits/variants/sheet.png`,
not in git). `--pick paper_baer=2,...` installs the chosen ones (`assets/portraits/`, 256 px,
and `portrait` in the driver `.tres`). A new driver without a portrait simply shows no face.
Toys built in Blender (Duplo-Flieger, Jumbo: `MODEL_REFS` in the script) use a three-quarter
render of their game model as the reference instead (`tools/blender/render_model_ref.py`, run by
the script). The front photo of the Duplo plane made FLUX draw a generic brick pile; the model
render shows wings, tail and wheels at once, so the portrait looks like the real toy. Rebuild the
portrait after changing such a model (`--ids paper_jumbo --count 4`, then `--pick`).

## Duplo toys: built in Blender, no AI

`tools/blender/build_duplo_plane.py` builds the Duplo plane brick by brick (Duplo units: a stud
is 1, a layer 1.2) after the photos, then `prepare_toy_model.py --width 1.3`. The plane is a toy
vehicle (it has the red Duplo car base with wheels), so it replaces the kart.

`tools/blender/build_duplo_girl.py` builds the Duplo girl (`paper_junge`) after the photos
`17.04.08*` / `17.04.09*` (front, side, back): a Duplo child figure seated the Duplo way (leg
piece turned forward at the hip, shoes pointing up), arms forward with C-hands, curly hair from
small balls sunk into a cap, printed face and striped shirt as thin shapes. Colours are pushed to
strong toy colours (sky-blue legs instead of the photo's pale blue). She is a driver, not a
vehicle: the script scales her to 0.7 m seated height itself and puts the origin under her
bottom (the seat point), so it does not use `prepare_toy_model.py` (that centres the bounding
box, which would shift her back by half her legs). One command does model, edit file and sheet:

```
blender -b --python tools/blender/build_duplo_girl.py -- --out assets/models/toys/junge.glb
    --blend art/models/junge_edit.blend --sheet <scratchpad>/junge_sheet.png
```

### More Duplo figures and Duplo vehicles (23 Nov toys)

`tools/blender/build_duplo_figure.py --figure duplojunge|bauarbeiterin` builds the other seated
Duplo figures on the girl's body (same seat point, height and pose) with a preset per toy:
colours, the torso print (overall bib with badge; vest over the shirt), hair (short swept cap;
curls under a white hard hat), hand colour (the builder wears light grey gloves). The girl's own
script stays as it is. Add a figure = add a preset.

```
blender -b --python tools/blender/build_duplo_figure.py -- --figure duplojunge
    --out assets/models/toys/duplojunge.glb --blend art/models/duplojunge_edit.blend --sheet <png>
```

Legs (24 Nov, owner: "too long"): the seated leg piece now reaches 1.55 units in front of the hip
instead of 2.05 (`LEG_TIP` in both scripts), with a lower shoe. Measured on the side photos
(`11.59.19 (1)`, `11.59.20 (2)`): back of the hip to the toes is about twice the torso depth.

`tools/blender/build_duplo_vehicle.py --vehicle krankenwagen|zug` builds a Duplo vehicle as a
**kart** (`data/karts/`), not a driver: drivers sit in it. The ambulance is a van without a
bonnet (a white tub with the round nose, stripes, grille and lamps); its roof shell (the upper
half with the window frames and four studs) is built closed as its own node `roof`, a child of
`body`, with its origin on the hinge axis at the back of the tub (`roof_parts()`).
**Animated roof** (any kart model with a `roof` node; `KartVisual.animate_roof`): open in the
menus; in a race shut while waiting at the start, it springs open on "go" with a pop
(`assets/sfx/pop.wav`, about 0.6 s, a little overshoot), snaps shut and open again when the
driver honks, and leans further back with speed. `KartDef.roof_open_degrees` (100, like the toy)
standing still, `roof_open_fast_degrees` (135) at full speed: at 100 degrees the roof stands
behind the driver like a wall and the chase camera would see only the roof. Purely visual.
`render_model_sheet.py --roof 100` shows it open in a sheet.
The roof shell is one rounded hollow piece like the closed toy (24 Nov, owner: "a flat box lid"):
`rounded_block()` bevels each edge by its own weight (a big round over the front, smaller ones
over the sides and back, plan corners matching the tub's nose), cuts it flat at the sill so it
sits flush on the tub walls, then a solidify gives the wall and boolean cuts make the windscreen,
side windows and back slot. The tub's nose is flat on top for the same reason. Before and after,
closed and open next to the photo: `docs/img/toy-fixes-2026-11-24c.png`. The train car is tall with a round nose
(two studs), a rounded roof edge round an open top, an open front between round corner posts
(the U cut of the real front) and a wide notch in the back, so the driver shows from every side. The model has Kenney-style nodes, so the game animates it like a Kenney kart: one
mesh `body` and four wheels `wheel-front-left` ... with their origin at the wheel centre (they
spin and the front ones steer). `--length 1.5` (metres, nose to tail). The script prints the
`seat_position` for the kart `.tres` (top of the floor, middle of the seat well); `seat_scale
0.95` makes a 0.7 m figure the right size for the toy.

## Toys from real photos (no Codex): tractor and airliner

`tools/make_photo_views.py --id <id> --front <photo> --left <photo> --back <photo> --right <photo>
[--fit height|width]` cuts four photos out with rembg and brings them to one scale
(`art/toys/photo_views/`). Then `tools/make_3d_toy.py --id <id> --views art/toys/photo_views`.
Photos are perspective shots, not straight views, so Pixal3D gets less to work with than from
Codex drawings; look at the sheet before using the model. First try (23 Nov): the tractor came
out without its front wheels and dark, the airliner without its tail fin and with half a body.
Both were rejected (kept in `art/models/pixal3d_rejected/`, not in git).

Instead `tools/blender/build_toy_vehicle.py --vehicle traktor|jumbo` builds them from simple
shapes (boxes, cylinders, a lofted plane body, flat wing plates) as toy-vehicle drivers: one
mesh, origin at the bottom middle. Tractor `--length 1.5`, airliner `--width 1.7` (wing span;
`vehicle_hover = 0.4` in its `.tres` makes it fly). Fixes after the owner's look (24 Nov): the
jumbo's windows are painted into the body faces (`loft(..., paint=...)`: one row of dark-blue
passenger windows per side, a two-pane cockpit window, two pale doors per side) because the
owner wants windows even though the real toy's wore off; stuck-on window boxes were too small to
see. The tractor front follows the photos: sloping bonnet with grille bars and round headlights,
front axle with smaller lugged wheels, loader towers behind the front wheels, arms over the
wheels and past the nose, bucket lowered to the ground so the bonnet stays visible. Before and
after: `docs/img/toy-fixes-2026-11-24.png`. Second pass (24 Nov, owner: "still not quite
right"), measured on the side photo `11.59.28 (10)` in rear wheel radii R: front wheel 0.7 R,
wheelbase 2.6 R, a tall bonnet whose top (2.3 R) is above the rear wheels, the glass cab over
the rear axle (not behind it), roof at 3.8 R, big white dished rims, thin blue mudguard arcs,
grey (not black) loader with the arms level with the bonnet top, exhaust up past the roof. Clean and recognisable in the race; an
optional Codex prompt for a more detailed look is at the end of `docs/CODEX_REDO_POLIZEI_KOBA.md`.

## Local views from real photos: FLUX.2 klein + Pixal3D (24 Nov)

The owner asked whether the PC can make the four views itself, without Codex.
`tools/make_local_views.py --id <id>` cuts each of four photos out (rembg), puts it on white and
asks FLUX.2 klein for "a clean studio product render of the exact toy in image 1 ... seen
exactly from its left side ... orthographic, plain black background, keep the toy identical",
3 seeds per view, and saves a contact sheet (`art/toys/local_views/variants/`, not in git).
`--pick front=2,left=1,back=photo,right=1` cuts the chosen ones out and brings all four to one
common height (`art/toys/local_views/<id>-*.png`); `photo` takes the photo cut-out itself,
`flip-right-2` mirrors the other side's pick (symmetric toys). Then
`make_3d_toy.py --id <id> --views art/toys/local_views --tag _local --model-out art/models/<id>_local.glb`
(trial models never replace the game's). About 2 minutes of FLUX and 8 to 9 minutes of
Pixal3D per toy.

What came out (sheets in `docs/img/toy-models-2026-11-24b.png`):

| Toy | FLUX views | Pixal3D model |
| --- | --- | --- |
| Traktor | all four clean and faithful (the photos already show each side) | very close to the real toy: wheels, cab, loader, bucket. Blue came out light cyan and the loader light grey: fixed with `recolor_model.py` |
| Zug | front and sides very good; the back got an invented window | round roof, windows and front right; pale lime (recoloured), prints smeared |
| Krankenwagen | front and right good; left and back invented a closed van (used the mirrored right view and the back photo) | lumpy: the photos show the roof at different angles, so the views do not fit together |
| Sanitäter | good, but arms hang down (photo pose) | right shape and short legs; face and prints smeared, print copied onto the back |

Codex views arrived later for polizei, loewe, krankenwagen, zug, traktor and duplojunge (Codex is
done now; junge and bauarbeiterin stay local). All were run through Pixal3D too
(`--tag _codex --model-out art/models/<id>_codex.glb`). **Kept in the game** (green frames in
`docs/img/toy-models-2026-11-24b.png`):

| Toy | Kept | Why |
| --- | --- | --- |
| Traktor | local FLUX views + Pixal3D, recoloured (`--hue 170-215:224 --sat 1.35 --val 0.8 --grey 0.55`), `model_scale 1.15` | closest to the real toy; the Codex-view model was as good in shape but cyan with a messy bucket |
| Krankenwagen | Blender | the only one with a separate roof that can open and close, and spinning wheels; both Pixal3D versions are lumpy and have the roof fixed open |
| Zug | Blender | both Pixal3D trains look more like the toy but hide the driver from the chase camera (round roof, tall back): only the top of the head showed |
| Sanitäter | Codex views + Pixal3D, `--seat-back 0.3` | clean face and print, short legs; the local-view model had a smeared face |
| Polizei | Codex views + Pixal3D, `--length 1.5`, POLIZEI added with `add_lettering.py` | Pixal3D wrote the lettering scrambled and mirrored on one side |
| Koba | Codex views + Pixal3D, warmer colour (`recolor_model.py --hue 20-80:-14 --sat 1.35`), nose and mouth painted from the Codex front view (`project_detail.py`, below) | friendlier, rounder face |
| Mädchen, Bauarbeiterin | Blender (shorter legs) | no Codex views; the local-view figure test (Sanitäter) smeared the face |

Koba's mouth (owner: "not quite right"): Pixal3D left a pale small nose and a thin wide line.
`tools/blender/project_detail.py` lays the Codex front view over the model's front (both fitted
to their outlines) and paints a soft-edged oval region into the texture, only on faces that look
forward, with the same colour shift as the model so the muzzle matches the fur:

```
blender -b --python tools/blender/project_detail.py -- --in assets/models/toys/loewe.glb
    --out assets/models/toys/loewe.glb --image art/toys/turnaround/loewe-front.png
    --region 0.32,0.68,0.15,0.38 --feather 0.45 --hue-shift -14 --sat 1.35
```

Run it once on a freshly prepared and recoloured model (it paints on top of what is there).

A Pixal3D run at the default upsample resolution hung for 15 minutes in the texture bake when
the GPU memory was full (Codex tractor: 11.7 of 12 GB); `--resolution 1024` finished it.

So: local FLUX + Pixal3D is good enough for hard toys whose photos show each side cleanly
(tractor, train), not for toys with a moving part photographed in different poses (ambulance
roof) or with a printed face (figures). Codex views, where they exist, are cleaner still.

Helpers: `tools/blender/recolor_model.py` (hue range to a hue or a shift, saturation, mid greys;
fixes Pixal3D colour drift), `tools/blender/assemble_kart.py` (a one-piece model becomes a kart:
`body` plus four wheel nodes, seat floor found by a ray cast), `tools/blender/add_lettering.py`
(clean raised lettering on both sides: Pixal3D scrambled POLIZEI), `prepare_toy_model.py --mirror`
(a mirror-image model), `tools/blender/render_model_sheet.py` (four views in one row, same
scale, `--roof 100` opens a flip-up roof).

## Roadside buildings: police station and Duplo shop

`tools/blender/build_duplo_buildings.py --building polizeiwache|duplo_laden` builds the two toy
buildings beside the start from simple shapes, after the photos in the inventory:

- **Polizeiwache**: blue walls on the white two-step base plate, measured on the front photo
  (window, white door, badge, balcony railing over the garage, garage annex with the beacon),
  open at the back like the toy, darker groove lines for the bricks. The inventory's "tower"
  photos are this station seen end-on, so there is no separate tower.
- **Duplo-Laden**: in Duplo units (6 x 4 studs): two layers of 2x2 bricks and curved 2x4 bricks,
  a core of two tall bricks with a window at each end, tall 2x2 bricks on top, studs, the number
  prints 5 and 2 as raised strokes. The photo's pale Duplo tones are pushed to strong colours.

One mesh, a few colour materials, 4.6k / 9.4k triangles, faces Blender -Y (the side that looks
at the road), origin at the bottom middle.

```
blender -b --python tools/blender/build_duplo_buildings.py -- --building polizeiwache
    --out assets/models/props/polizeiwache.glb --height 6.0
    --blend art/models/polizeiwache_edit.blend --sheet <scratchpad>/station_sheet.png
blender -b --python tools/blender/build_duplo_buildings.py -- --building duplo_laden
    --out assets/models/props/duplo_laden.glb --height 5.5
    --blend art/models/duplo_laden_edit.blend --sheet <scratchpad>/shop_sheet.png
```

`scripts/track/roadside.gd` loads `assets/models/props/<id>.glb`, scales it to the height in its
`PROPS` list (7 m and 6.5 m; 1.5 times that in the living room) and clears trees in front of it.
Without a model it falls back to the photo card from `tools/make_props.py`.

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
