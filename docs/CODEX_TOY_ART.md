# Handover prompt for Codex: drawn toy art

Copy everything below the line into Codex, started in this project folder.

---

You are working in the Toy Racer repository, a small Godot 4.7 kart game I am making for my
4-year-old son. His real toys are in the game as flat picture cards, cut out of phone photos.
The cut-outs look rough. Your job: draw clean, friendly pictures of the same toys and bring them
into the game.

Read first: `AGENTS.md` (points to `CLAUDE.md`, the project rules), then `docs/ART_BRIEF.md`.
The brief lists the eight toys, the files to make and the rules every picture must follow.
The reference photos are in `photos/toys/`; `photos/toys/pairs.json` says which photo is the front
and which the back of each toy. Look at all photos of a toy before drawing it.

What to do:

1. For each of the eight toys, generate a front and a back picture as described in the brief:
   transparent PNG, at least 1024 px, straight-on view, faithful to the real toy, one consistent
   friendly style for all toys. Save them as `art/toys/<id>-front.png` and `art/toys/<id>-back.png`.
   Start with one toy (`polizei`), show me front and back, and wait for my OK on the style before
   doing the other seven.
2. Run `tools\.venv\Scripts\python.exe tools\check_art.py` and fix every problem until it prints
   `ART CHECK: PASS`.
3. Run `tools\.venv\Scripts\python.exe tools\make_paper_drivers.py`, then
   `powershell -ExecutionPolicy Bypass -File tools\check.ps1` until it prints `ALL CHECKS PASSED`.
4. Take the two screenshots listed at the end of the brief and look at them: is every toy
   recognisable, the right size, nothing cut off?
5. Optional, only if steps 1 to 4 are done and I agree: the turnaround views and portraits from
   the brief.

Rules:

- I am not a programmer. Do all commands yourself; never ask me to use a terminal.
- Change only `art/`, `assets/paper/` and, if a toy looks too big or small in the game,
  `card_height` / `vehicle_width` in its `data/drivers/paper_<id>.tres`. Do not change game code,
  names, or any other file. If something else seems to need a change, ask me first.
- Never read the large generated files the project rules list (`*.glb`, `mesh-library.tres`,
  `scenes/tracks/*`). Images you made or need as reference are fine.
- Commit when the checks pass, with a short message, then `git pull --rebase` and
  `git push origin main`.
- At the end, tell me in a few sentences what you made, which toys still use photos, and
  anything that did not work.
