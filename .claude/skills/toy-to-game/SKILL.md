---
name: toy-to-game
description: Turn one of Johannes' real toys into a Toy Racer driver (photo card, drawn views, 3D model, menu portrait), or make other pictures and textures locally with FLUX. Use when he brings new toy photos, Codex drawings or turnaround views, asks for a 3D toy, a portrait, a texture, or a fix to how a toy looks in the game.
---

# Toy to game

Everything runs on this PC (ComfyUI at `C:\Users\Johannes\AI projects Local\ComfyUI`, Blender 5.3,
Godot). Johannes never uses a terminal: run every command yourself. Details: `docs/MODELS_3D.md`.
Never read `photos/`, `assets/` or `*.png` directly: make a contact sheet in the scratchpad and
look at that.

## Steps for a new toy `<id>`

1. **Card (minutes):** photos `photos/toys/<id>-front.jpg`/`-back.jpg` (or `pairs.json`), then
   `tools\.venv\Scripts\python.exe tools\make_paper_drivers.py`. One `.tres` in `data/drivers/`.
2. **Views:** ask Johannes for Codex turnaround views with the prompt in
   `docs/CODEX_TURNAROUND.md` -> `art/toys/turnaround/<id>-front|left|back|right.png`.
   `tools/check_art.py` checks them. (FLUX cannot make matching views.)
3. **3D (5 to 10 min):** `tools\.venv\Scripts\python.exe tools\make_3d_toy.py --id <id> --apply`
   (`--length 1.3` for cars and bikes; `--skip-generate` redoes only Blender). Look at
   `art/models/<id>_sheet.png`, then one race screenshot with `--driver=N`.
   Blocky Duplo toys: build in Blender from shapes instead (`tools/blender/build_duplo_plane.py`).
4. **Portrait (1 to 2 min):** `tools\.venv\Scripts\python.exe tools\make_portraits.py --ids <driver id>`,
   look at `art/toys/portraits/variants/sheet.png`, then `--pick <driver id>=<n>`.
   If FLUX gets the kind of toy wrong, add a hint in `HINTS`.
5. `godot --headless --import`, `tools\check.ps1` until ALL CHECKS PASSED, `tools\export.ps1`,
   update `docs/HANDOVER.md`, commit, push.

## Other local pictures

`tools\comfy\run_flux_klein.py --prompt "..." --out <png> [--ref <png>] [--count 2]`: textures,
backgrounds, small edits of one view (Bobo's smile). About 40 s per picture. Licence: Apache 2.0;
add a row to `licenses/README.md` for anything that goes into the game.

## Pitfalls

- Run FLUX and Pixal3D one after another, never together (12 GB of VRAM).
- A ComfyUI window Johannes has open is reused; if he closes it the run dies: rerun the
  missing items.
- Transparent references go on white first (`make_portraits.py` does this).
- Colours of Kenney models: `tools/make_strong_colors.py --strength <0..1.5>` (0 = Kenney's own).
- Ask before deleting files or using paid tools (Tripo, Meshy: not needed).
