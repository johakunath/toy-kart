# Handover prompt for Codex: turnaround views for 3D toys

Copy everything below the line into Codex, started in this project folder. Order: Bobo (`baer`),
then the plane (`flieger`), then the police car (`polizei`). One toy per run is fine.

---

You are working in the Toy Racer repository, a Godot kart game I am making for my 4-year-old son.
His toys are becoming 3D models. A local tool (Pixal3D) builds each model from four drawn views of
the toy: front, left, back, right. Your job: draw those four views, so they match each other
exactly. The 3D model can only be as good as these pictures.

Read first: `AGENTS.md` (points to `CLAUDE.md`, the project rules), then `docs/ART_BRIEF.md`.
The toy's existing drawings are `art/toys/<id>-front.png` and `art/toys/<id>-back.png`: they set
the style, the colours and the pose. The reference photos are in `photos/toys/`
(`pairs.json` says which photo shows which toy).

Toys, in this order: `baer` (Bobo, seated, as in his front/back drawings), `flieger` (the toy
propeller plane), `polizei` (the toy police car). Do one toy, show me the four views, and wait
for my OK before the next.

For each toy, make four PNGs in `art/toys/turnaround/`:

| File | View |
| --- | --- |
| `<id>-front.png` | straight from the front (the side that faces forward when driving) |
| `<id>-left.png` | straight from the toy's own LEFT side: the toy faces LEFT in the picture |
| `<id>-back.png` | straight from behind |
| `<id>-right.png` | straight from the toy's own RIGHT side: the toy faces RIGHT in the picture |

Rules (the 3D tool fails or makes a lumpy model when one is broken):

1. **The same toy in the same pose in all four.** Same proportions, colours, markings. For Bobo:
   the same seated pose as `art/toys/baer-front.png`.
2. **The same scale and ground line.** All four on the same square canvas (1024 x 1024 or
   larger, all the same size). The toy stands on the same bottom line in every view, and its
   height is the same in every view. The widest view fills about 85 % of the canvas width.
3. **Straight views, no perspective.** Like an orthographic technical drawing: no three-quarter
   angle, no camera tilt, no foreshortening. The side views are true profiles.
4. **Transparent background** (RGBA). No ground, no shadow, no scenery, no outline sticker.
5. **Flat, even light.** Soft shading is fine, but no strong shadows, no dark patches, no
   reflections or highlights painted into the colours: the colours become the model's texture.
6. **Nothing hidden.** Vehicles: all wheels visible in the side views, the propeller and full
   wings visible from the front and back. Plane wings spread fully, same span in front and back.
7. No text, no logos added (markings that are on the real toy, like "POLIZEI", are fine).

Check and hand over:

1. Run `tools\.venv\Scripts\python.exe tools\check_art.py`. It checks the turnaround sets
   (all four views, same canvas, same height, same ground line). Fix every problem until it
   prints `ART CHECK: PASS`.
2. Change only files in `art/toys/turnaround/`. Do not touch game code, `assets/`, `data/` or
   other drawings. Never read the large generated files the project rules list.
3. Commit with a short message (for example "Turnaround views: Bobo"), then
   `git pull --rebase` and `git push origin main`.
4. Tell me in two sentences which toys are done and anything that did not work.

I am not a programmer. Run all commands yourself; never ask me to use a terminal.
