# Handover prompt for Codex: redraw the police car and Koba

Copy everything below the line into Codex, started in this project folder. After Codex is done,
tell Claude "Codex is done": Claude builds the 3D models locally with Pixal3D (no Codex needed).

---

You are working in the Toy Racer repository, a Godot kart game I am making for my 4-year-old son.
Two toys need new turnaround views, because their 3D models came out wrong. Follow every rule in
`docs/CODEX_TURNAROUND.md` (four views, same canvas, same ground line, straight views, transparent
background, flat light). Read `AGENTS.md` and `docs/ART_BRIEF.md` first.

Do one toy, show me the four views, and wait for my OK before the next.

1. **`polizei` (the toy police car).** Replace `art/toys/turnaround/polizei-{front,left,back,right}.png`.
   - The car was too short: draw it with the real toy's length. Compare length to height with the
     reference photos in `photos/toys/` (`pairs.json` says which ones show the police car); in the
     side views the car should be clearly longer than it is tall, like the real toy.
   - The lettering on the sides was scrambled. Write **POLIZEI** in clean, correctly spelled
     block letters, exactly as on the real toy, in the same place on both sides. Letters must read
     correctly in both side views (not mirrored). No other text.
   - All four wheels touch the same ground line; wheels fully visible in the side views.
2. **`loewe` (Koba, the toy lion).** Replace `art/toys/turnaround/loewe-{front,left,back,right}.png`
   (keep the old `loewe-pixal3d-*` files; do not delete anything).
   - The face of the old model looked bulky and strange. Draw a friendly, clear face: two eyes,
     nose and mouth placed like on the real toy, soft rounded mane, nothing lumpy.
   - Same seated pose and colours as `art/toys/loewe-front.png` and the photos.

Check and hand over as in `docs/CODEX_TURNAROUND.md`: run `tools\.venv\Scripts\python.exe tools\check_art.py`
until it prints `ART CHECK: PASS`, change only files in `art/toys/turnaround/`, commit
("Turnaround views: police car and Koba, redone"), `git pull --rebase`, `git push origin main`,
then tell me in two sentences what is done.

I am not a programmer. Run all commands yourself; never ask me to use a terminal.
