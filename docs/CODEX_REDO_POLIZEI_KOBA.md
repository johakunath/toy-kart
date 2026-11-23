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

---

## New toys (23 Nov photos): tractor and airliner (optional)

Not needed right now: Claude built both in Blender from simple shapes
(`tools/blender/build_toy_vehicle.py`), and they are in the game as 3D. Pixal3D from the real
photos failed (the tractor lost its front wheels, the plane its tail fin and half its body),
because photos are perspective shots of thin parts. Use this prompt only if Johannes wants the
more detailed, photo-like look; then Claude runs `tools/make_3d_toy.py --id <id> --apply`.

Copy everything below the line into Codex, started in this project folder.

---

You are working in the Toy Racer repository, a Godot kart game I am making for my 4-year-old son.
Two new toys need turnaround views for 3D models. Follow every rule in
`docs/CODEX_TURNAROUND.md` (four views, same canvas, same ground line, straight views,
transparent background, flat light). Read `AGENTS.md` and `docs/ART_BRIEF.md` first. Reference
photos: `photos/toys/INVENTORY-2026-11-23.md` lists which photo shows which side
(`WhatsApp Image 2026-11-23 at <time>.jpeg`). Photo cut-outs at one scale are in
`art/toys/photo_views/<id>-front|left|back|right.png`.

Do one toy, show me the four views, and wait for my OK before the next.

1. **`traktor` (the blue farm tractor).** Make `art/toys/turnaround/traktor-{front,left,back,right}.png`.
   - Blue body and cab roof, dark tinted cab windows, black tyres with white rims; big rear
     wheels, small front wheels. All four wheels visible and touching the ground line in the
     side views.
   - The dark grey front loader: two arms from the cab down to a wide bucket in front, the bucket
     resting on the ground. In the front view the bucket must not hide the whole tractor: draw
     it lowered so the bonnet and cab show above it.
2. **`jumbo` (the white four-engine airliner).** Make `art/toys/turnaround/jumbo-{front,left,back,right}.png`.
   - White body, four engines under the wings, small wheels under the middle and the nose.
   - Blue tail fin with its swirl, blue wing tips turned up, blue tips on the tail wings.
   - Side views: the full body from nose to tail with the tall tail fin, clearly longer than
     high, wings seen edge-on. Front and back: wings spread fully, the same span in both.
   - No airline name or logo.

Check and hand over as in `docs/CODEX_TURNAROUND.md`: run `tools\.venv\Scripts\python.exe tools\check_art.py`
until it prints `ART CHECK: PASS`, change only files in `art/toys/turnaround/`, commit
("Turnaround views: tractor and airliner"), `git pull --rebase`, `git push origin main`,
then tell me in two sentences what is done.

I am not a programmer. Run all commands yourself; never ask me to use a terminal.
