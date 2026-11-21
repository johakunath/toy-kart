# Toy Racer

Mario Kart-style racing for Johannes and his 4-year-old son. Windows PC, played on a 1080p projector.
The owner is not a programmer: never ask him to use a terminal. Do installs, git, config, builds and
checks yourself. Give him steps only in the Godot editor or on websites.

## Stack
- Godot 4.7.2 stable, standard build, GDScript 2.0, no C#. Forward+, Jolt physics, physics interpolation on.
- Godot exe: `%LOCALAPPDATA%\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe` (export templates installed).
- Base: Kenney Starter Kit Racing (MIT code, CC0 assets) + Kenney Mini Characters (CC0). Licences in `licenses/`.
- Repo: github.com/johakunath/toy-kart (private). No GitHub Actions; all checks run locally.
- `tools/.venv` (Python 3.12: rembg, Pillow) only for photo cut-outs and sound generation.
- Godot MCP server (Coding-Solo/godot-mcp) is configured in `.mcp.json`.

## Folder map
| Path | What |
| --- | --- |
| `scripts/core/` | `game.gd` (autoload `Game`: mode, speed, players, catalog, settings), `DriverDef`, `KartDef` |
| `scripts/input/` | `Intent`, `InputSource` (keyboard, pad, AI, test), `Assist` (kid/full), `LineFollow` |
| `scripts/kart/` | `Kart` (rolling-ball arcade physics), `KartVisual`, `DriverRig` (3D model or paper card) |
| `scripts/track/` | `Track` (racing line lookups), `TrackProgress` (laps), `BoostStar` |
| `scripts/race/` | `race.gd` (builds the race at runtime), `Racer`, `ChaseCamera` |
| `scripts/ui/` | `menu.gd`, `PlayerSlot`, `PlayerHud`, `FinishScreen`, `PauseMenu`, `KartPreview`, `UiKit` |
| `scenes/` | `menu.tscn` (main), `race.tscn`, `kart.tscn`, `boost_star.tscn`, `tracks/track_01.tscn` |
| `data/drivers/`, `data/karts/` | one `.tres` per driver / kart; the game lists these folders at start |
| `assets/` | `kenney_racing/`, `characters/`, `paper/` (toy cut-outs), `sfx/`, `fx/`, `icons/` |
| `photos/toys/` | toy photos + `pairs.json` (which photo is front/back). Not imported by Godot |
| `tools/` | check, export, track builder, cut-out and sound generators |
| `docs/` | PLAN, DECISIONS, BACKLOG, HANDOVER |
| `builds/` | exported game (not in git) |

## The one architecture rule
Devices never talk to karts. `InputSource` (device or AI) -> `Intent` (steer, accelerate, brake,
drift, use, horn) -> `Assist` (per player: kid or full) -> `Kart`. New controllers, AI and assists
plug into that chain. The racing line (`Path3D` "RacingLine" in the track scene) drives smart
steering, AI, laps, places, reset and the start grid.

## Checks (run before every handover)
```
powershell -ExecutionPolicy Bypass -File tools\check.ps1        # names, parse, pad mapping, 7 headless races
powershell -ExecutionPolicy Bypass -File tools\check.ps1 -Quick # parse + one race
powershell -ExecutionPolicy Bypass -File tools\export.ps1       # builds\ToyKart.exe + start tests
```
- Headless race by hand: `godot --headless --path . --fixed-fps 60 res://scenes/race.tscn -- --smoke`
  Options after `--smoke`: `--players=1|2 --control=kid|full|mixed --input=none|left|right|random
  --mode=race|free|trial --speed=0|1|2 --ai=0..3 --seconds=N --trace=T`. Prints `SMOKE RESULT: PASS|FAIL`.
- Look at the game: same command without `--headless`, plus `--windowed --shot=<png> --shot_at=<s|finish>`
  (race) or `res://scenes/menu.tscn -- --windowed --shot=<png> --page=mode|options|players` (menu).
  Read only the saved PNG, never asset files.
- Frame rate: windowed with `--disable-vsync` and `-- --smoke --perf=1 --seconds=25` prints a `PERF` line.

## Rules
1. Godot 4.7 APIs only. No Godot 3 names (`KinematicBody`, `yield`, `export var`, `.instance()` ...);
   `tools/check.ps1` scans for them. Typed GDScript.
2. Every change passes the headless script parse and a headless run of the race scene before
   handover. A change is not done until `tools\check.ps1` prints ALL CHECKS PASSED.
3. Never read asset files into context (`assets/`, `photos/`, `*.glb`, `*.png`, `mesh-library.tres`).
   Use the tools and look at screenshots or contact sheets instead.
4. Ask the owner before deleting files, using paid tools, or changing a decision in `docs/DECISIONS.md`.
5. Kid mode promise: he never loses control, never gets stuck, never has to wait. Any change to
   steering, physics or the track must keep the kid races in `check.ps1` at zero resets.
6. UI: icons plus short German labels; playable without reading. Code, comments and docs in English.
7. Commit after each working step, push to `origin main`. Update `docs/HANDOVER.md` at session end.
8. New driver = one `.tres` in `data/drivers/`; new kart = one `.tres` in `data/karts/`. No code change.
9. Tracks are generated: edit `TRACK` in `tools/build_track.gd`, run it, commit the `.tscn`.
10. Keep this file under 100 lines; details go in `docs/`.

## Common jobs
- New toy photos: put `<name>-front.jpg` / `<name>-back.jpg` in `photos/toys/` (or add to `pairs.json`),
  run `tools\.venv\Scripts\python.exe tools\make_paper_drivers.py`, then import and check.
- Rebuild track: `godot --headless --path . --script res://tools/build_track.gd`.
- Regenerate sounds: `tools\.venv\Scripts\python.exe tools\make_sfx.py`.
- Tuning knobs: speeds in `game.gd` (`SPEED_FACTOR`), kart feel in `kart.gd` (constants at the top),
  kid assist in `assist.gd`, AI and catch-up in `race.gd` (`_update_pacing`), cameras in `chase_camera.gd`.

## Docs
- [docs/PLAN.md](docs/PLAN.md): the plan and milestones (source of truth for scope).
- [docs/DECISIONS.md](docs/DECISIONS.md): decisions; change only with the owner's OK.
- [docs/BACKLOG.md](docs/BACKLOG.md): everything that waits.
- [docs/HANDOVER.md](docs/HANDOVER.md): what works, what is next, the couch test.
