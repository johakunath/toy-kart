# Art brief: drawn toys

The toys in the game are flat "paper" cards: one picture facing forward, one facing the chase
camera behind the kart. Today these are cut-out photos. This brief is for replacing them with
drawn pictures of the same toys, so they look clean and consistent on the 1080p projector.

The game picks drawings up by themselves: a file in `art/toys/` wins over the photo of the same
toy. Nothing in the game code needs to change.

## The toys

| id (file name) | Name in the game | What it is | Shown as | Reference photos |
| --- | --- | --- | --- | --- |
| `junge` | Duplo-Mädchen | Duplo girl figure | Driver, sits in a kart | see `photos/toys/pairs.json` |
| `katze` | Fuchs | Toy fox | Driver | " |
| `loewe` | Koba | Toy lion called Koba | Driver | " |
| `baer` | Bobo | Bobo, a character from a picture book (photo of a book page) | Driver | " |
| `polizei` | Polizei | Toy police car | The vehicle itself | " |
| `motorrad` | Motorrad | Toy police motorbike | The vehicle itself | " |
| `flieger` | Flieger | Toy propeller plane | The vehicle itself (flies a bit above the road) | " |
| `duploflieger` | Duplo-Flieger | Duplo plane built from bricks | Driver, sits in a kart | " (plus left, right, top photos) |

The ids are old names kept for file compatibility (`junge` is the Duplo girl, `katze` the fox,
`loewe` Koba, `baer` Bobo). Use the ids for file names.

`pairs.json` lists, for every toy, which photo is the front and which is the back. Other photos
in `photos/toys/` show more angles of the same toys and are fine to use as extra reference.

## Files to make

Required, for every toy:

- `art/toys/<id>-front.png`: the toy seen straight from the front.
- `art/toys/<id>-back.png`: the same toy seen straight from behind.

Optional, for the 3D models later (milestone 3):

- `art/toys/turnaround/<id>-left.png`, `-right.png`, `-top.png`: same style, same scale.
- `art/toys/portraits/<id>.png`: a square head-and-shoulders portrait (512 x 512) for the
  driver selection screen.

## Rules for every picture

| Rule | Why |
| --- | --- |
| PNG with a **transparent background** (RGBA), no ground, no shadow, no scenery | The game cuts nothing; whatever is in the picture is on the card |
| Longest side at least **1024 px**; the toy fills 80 to 95 % of the frame with a small empty margin | Shown at about 300 px tall on the projector; the margin keeps the white sticker outline whole |
| **Straight-on view**, no perspective tilt, toy upright and centred | The card stands upright; a tilted drawing looks like it leans |
| Front and back drawings at the **same scale and the same outline** (a mirror-like silhouette) | The game shows one or the other as the kart turns; a size jump is visible |
| **Faithful to the real toy**: same shapes, colours, markings, proportions. He must recognise *his* toy at once | The whole point of the cards |
| Clean, friendly, slightly stylised: flat colours with soft shading, crisp dark outline, no texture noise or photo grain | Reads well small and on a projector; matches the bright low-poly world |
| No text, no logos added. Leave markings that are on the real toy ("POLIZEI" is fine) | Kid-readable, no new branding |
| Vehicles: wheels/propeller visible, nothing cropped. The plane with wings spread fully | The vehicle card is as wide as the vehicle |
| Same style for all eight toys | They race side by side |

A white sticker outline is added by the game's tool afterwards; do not draw one.

## How to check and bring them in

1. `tools\.venv\Scripts\python.exe tools\check_art.py` checks every drawing against the rules
   above. It must print `ART CHECK: PASS`.
2. `tools\.venv\Scripts\python.exe tools\make_paper_drivers.py` turns the drawings into the cards
   in `assets/paper/` (it prints `(art)` or `(photo)` per side). Existing `.tres` files keep their
   names and sizes.
3. `powershell -ExecutionPolicy Bypass -File tools\check.ps1` must print `ALL CHECKS PASSED`.
4. A screenshot to look at the result:
   `godot --path . res://scenes/menu.tscn -- --windowed --shot=<png> --page=players`, and a race
   with the toy vehicles: `godot --path . --fixed-fps 60 res://scenes/race.tscn -- --smoke --windowed --shot=<png> --shot_at=8 --driver=4`.

## Note for later

Bobo is a picture-book character and the Duplo figures are a brand. Fine for the family; they
must be replaced before the game is ever shared publicly (see BACKLOG.md, "Legal").
