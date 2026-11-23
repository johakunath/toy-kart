# Handover prompt for Codex: turnaround views of the Duplo toys and the tractor

Copy everything below the line into Codex, started in this project folder. When Codex is done,
tell Claude "Codex views are done": Claude builds the 3D models locally with Pixal3D.

---

You are working in the Toy Racer repository, a Godot kart game I am making for my 4-year-old son.
His real toys become 3D models: a local tool (Pixal3D) builds each model from four drawn views.
The first models, built from simple shapes, came out wrong. Your job: draw clean, matching
turnaround views of seven toys from the real photos.

Read first: `AGENTS.md`, `docs/ART_BRIEF.md`, and **every rule in `docs/CODEX_TURNAROUND.md`**
(four views front/left/back/right, same square canvas, same scale and ground line, straight
orthographic views, transparent background, flat even light, colours exactly like the toy).
The photos are in `photos/toys/`; `photos/toys/INVENTORY-2026-11-23.md` says which photo shows
which toy and side; `photos/toys/pairs.json` and the `duploflieger-*.jpg` files cover the older
toys. Look at ALL photos of a toy before drawing it.

Make `art/toys/turnaround/<id>-front.png`, `-left.png`, `-back.png`, `-right.png` for each toy.
Do one toy, show me the four views, and wait for my OK before the next.

| Order | id | Toy | What matters most |
| --- | --- | --- | --- |
| 1 | `krankenwagen` | Duplo ambulance/van: white body, orange base, red-white stripes, flip-up roof | Draw it with the **roof flipped open** (hinged at the back, standing up like in the photos), so the seats inside are visible. Wheels, stripes, grille and the round emblem exactly as on the toy |
| 2 | `zug` | Duplo train car: lime green, navy base, railway logo, music notes | **With its roof**: the roof is clearly **rounded** (a smooth arch from side to side), window openings in the sides as on the toy |
| 3 | `duplojunge` | Duplo paramedic (Sanitäter): dark hair, yellow overalls with badge, light blue sleeves | **Seated** pose, like sitting in a car. Real Duplo proportions: **short, stubby legs**, big head, the body and legs as one blocky unit |
| 4 | `bauarbeiterin` | Duplo builder woman: white helmet, brown curls, light blue shirt, yellow vest, navy trousers, grey hands | Seated, short stubby Duplo legs, as above |
| 5 | `junge` | Duplo girl (the id says "junge", but she is a girl): see `pairs.json` entry `junge` | Seated, short stubby Duplo legs, as above |
| 6 | `traktor` | Blue toy tractor with a black front loader | Real proportions from the side photo: big rear wheels, small front wheels, bonnet with grille and lights, the cab with its roof. Loader arms from the cab sides to a wide bucket **lowered to the ground**, so the bonnet stays visible from the front |
| 7 | `duploflieger` | Plane built from Duplo bricks (`photos/toys/duploflieger-*.jpg`) | **Both wings fully visible**, same span in front and back views; the tail fin; the brick studs |

Figures (3-5): every view shows the same seated figure; the side views are true profiles with the
legs pointing forward. Vehicles (1, 2, 6): all wheels touch the same ground line.

Check and hand over as in `docs/CODEX_TURNAROUND.md`: run `tools\.venv\Scripts\python.exe tools\check_art.py`
until it prints `ART CHECK: PASS`, change only files in `art/toys/turnaround/` (do not delete
anything; if an old file has the same name, overwrite it), commit ("Turnaround views: <toy>"),
`git pull --rebase`, `git push origin main`, then tell me in two sentences what is done.

I am not a programmer. Run all commands yourself; never ask me to use a terminal.
