# 3D toys

How a toy becomes a 3D driver. Milestone 3; Koba (the lion) is the first.

## Who does what

| Step | Who | Where |
| --- | --- | --- |
| 1. Make the raw model from a picture | Johannes, on the Tripo website | tripo3d.ai |
| 2. Clean, shrink, size and face it | Claude | `tools/blender/prepare_toy_model.py` (Blender 5.3, command line) |
| 3. Put it in the game | Claude | the toy's `data/drivers/paper_<id>.tres` switches to a 3D model |
| 4. Look at it, tune size and wobble | Claude, then Johannes on the projector | screenshots, a race |

Blocky Duplo toys skip step 1: Claude builds them from simple shapes in Blender.

## Step 1 on the Tripo website (Johannes)

1. Open tripo3d.ai and sign in (a free account is enough).
2. Choose **Image to 3D** and upload the drawing `art/toys/<id>-front.png`
   (for Koba: `art/toys/loewe-front.png`). Clean drawings on a transparent background work better
   than phone photos.
3. Generate. If it offers several results, take the one that looks most like the toy from the side
   and back too. Turn it around in the preview before you pick.
4. Download as **GLB**. Leave the file in your Downloads folder and tell Claude its name.

If the back or the side comes out wrong, try again with a three-quarter photo of the real toy on a
plain background.

Free Tripo models are public on Tripo and come under CC BY 4.0: upload toys only, never the kids.
The credit goes into `licenses/`.

## Step 2 and 3 (Claude)

```
"C:\Program Files\Blender Foundation\Blender 5.3\blender.exe" -b --python tools/blender/prepare_toy_model.py --
    --in <download.glb> --out assets/models/toys/<id>.glb --height 0.7 --tris 12000 --tex 1024
    --sheet <scratchpad>/<id>_sheet.png
```

- Keep the raw download in `art/models/` (ignored by Godot and by git: too big).
- Look at the sheet: front, left side, back, three-quarter. If the first view shows the back,
  run again with `--turn 180`.
- `--height` is the seated height in metres; paper cards are about 0.7. Use the same, so the toy
  fits the seat.
- In `data/drivers/paper_<id>.tres`: `type = 0`, `model_scene` = the new `.glb`, `model_scale = 1.0`,
  `animation = ""`. Keep the id and the paper textures (portraits use them later).
- `godot --headless --import`, then a race screenshot with that driver, then `tools\check.ps1`.

The driver needs no rig and no animation file: `DriverRig` leans, bobs and hops it in code, like
the cards. A model with a rig is only needed for toys that should wave or move their legs.

## Tested

The script was tested end to end with a stand-in model (two spheres and a nose):
36k triangles reduced to 6k, textures shrunk, right size in the kart, facing forward
(the chase camera sees its back).
