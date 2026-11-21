# Handover

Updated 21 Nov 2026, fourth round: milestone 1 passed on your test drive, milestone 2 started.

## Where it stands

Milestone 1 is built. All local checks pass and the Windows game is exported to
`builds/ToyKart.exe`. **Not yet done: a real race on the projector with two real controllers.**
No gamepad was plugged in during the build, so pads were tested with simulated button presses only.
The couch test below is the gate for milestone 1.

![Kurvenkurs, split screen](img/race-split-screen.jpg)
![Waldkurs in evening light](img/race-waldkurs-evening.jpg)

## New in the fourth round (milestone 2 starts)

- **Who sits where:** the empty panels are now "Linke Seite" and "Rechte Seite". Press left on
  your stick or keys to sit left, right to sit right (the join button still takes the first free
  seat). The panel header says "Links" or "Rechts". If the Kind player sits right and the Profi
  left, the panels swap at once, so you see the real seats before the race.
- **Boosts you feel and see:** stars and turbo arrows push the kart forward (+40 % for 1.6 s,
  arrows +30 % for 1 s) instead of the old barely noticeable change. While boosting: an orange
  flame trail, white speed streaks on the screen, and a wider camera view (also in kid mode,
  a little calmer). Tested: hands-off kid still 4th, good driving still wins.
- **Music:** a calm menu tune and an upbeat race tune that starts with "Los!" and speeds up on the
  last lap. Generated on this PC (`tools/make_music.py`), no licences. "Musik an / aus" on the
  options page.
- **Sound:** separate channels for music, effects and engines (music a bit quieter, engines a bit
  quieter than effects; quieter again in split screen). A rumble when you drive on the kerb,
  a zip on the turbo arrows, and every driver honks a little differently.
- **Drawn toys, prepared for Codex:** put drawings in `art/toys/` and the game uses them instead
  of the photos. The brief is `docs/ART_BRIEF.md`, the prompt to paste into Codex is
  `docs/CODEX_TOY_ART.md`.
- **Plan:** milestone 1 passed on your test drive. Your test drives are the gates until he is
  ready; the second controller and his couch test are milestone 5.

## New in the third round (after your first test drive)

- **Kid mode is no longer automatic.** In the middle of the road the stick really steers. A
  helper only takes over near the edge, and the edge strip slows the kart. Without gas the kart
  cruises at 85 %; **A or RT (W / arrow up on a keyboard) = full speed.** B, X, Y honk.
  In tests: hands off = 3rd to 5th place, only gas = 3rd, steering well with gas = 1st.
  Still no wall hits and no resets.
- **AI with a kid:** two AI karts stay a little ahead, one behind, but never drive faster than
  normal to keep their spot, so a kid who drives well passes them.
- **Profi:** a leading AI eases off from 8 m ahead; whoever is behind the leading AI gets up to
  12 % extra top speed. **Schnell is faster** (1.5 instead of 1.3), Normal slightly (1.05),
  Kind slightly (0.78) to make up for the cruise speed.
- **Player menu:** an empty panel shows how to join (Controller: A, W A S D: Leertaste,
  Pfeile: Enter). A joined panel shows what Kind / Profi means, the driving keys for that
  device, and how to move and leave. The keys also show at the bottom of the screen for the
  first seconds of a race.
- **Toy vehicles:** Motorrad, Polizei and Flieger are now the vehicle themselves (the plane
  flies a bit above the road). The vehicle row then says "fährt selbst". The Duplo-Flieger still
  sits in a kart; say if it should be a vehicle too (one line in its file).
- **Names:** Katze is now **Fuchs**, Löwe is **Koba**, Junge is **Duplo-Mädchen**, Bär is **Bobo**.
- **New long track "Riesenrunde":** 716 m with an S, a wide hairpin and a long home straight,
  2 laps (about 3 minutes at Kind speed).
- **Turbo arrows:** blue pads with yellow arrows on all three tracks; drive over them for a
  short turbo, no button needed. More stars on Waldkurs.

## New in the second round (your four requests)

- **Duplo plane:** in the game as the driver "Duplo-Flieger". All five photos are kept in
  `photos/toys/` (front, back, left, right, top) for a 3D model later.
- **Track with round curves:** "Kurvenkurs", a flowing loop with wide bends, no 90 degree corners.
  It is now the first track. The tile track stays as "Waldkurs". Pick the track on the options
  page; each button shows the track's shape.
- **Karts the toys sit inside:** five little open go-karts, a racing car and an oldtimer. The
  trucks and the motorcycle are still at the end of the list.
- **Light and weather:** warm sun with soft shadows, a sky that lights the shade, haze in the
  distance, bloom, clouds that drift and cast moving shadows, dust glinting in the air.
  Kurvenkurs is a sunny day with petals; Waldkurs is a warm evening with long shadows, light
  shafts between the trees and autumn leaves.

## How you start it

| You want to | Do this |
| --- | --- |
| Play | Double-click **Toy Racer spielen** on the desktop |
| Open the project in Godot | Double-click **Toy Racer in Godot** on the desktop, then press F5 to play |
| Leave a race | Start button on a pad, or Esc: Pause, then **Menü** |
| Leave the game | **Ende** on the first menu page |
| Window instead of full screen | F11 |
| Game opened on the monitor, not the projector | Win + Shift + arrow key moves it to the other screen |

## Controls

| | Kind (kid mode) | Profi (full mode) |
| --- | --- | --- |
| Steer | Either stick, D-pad, or LB / RB | Left stick or D-pad |
| Gas | Cruises by itself; A or RT = full speed | RT or A |
| Brake, reverse | Not needed | LT or B |
| Drift | No | Hold RB in a curve; after 1 s you get a small boost when you let go |
| Star (boost) | Fires by itself | X or LB |
| Horn | B, X or Y | Y |
| Keyboard 1 | A / D steer, W full speed, other keys honk | W gas, S brake, A / D steer, Space drift, E star, Q horn |
| Keyboard 2 | Left / right steer, up full speed | Arrows, `.` drift, Enter star, `,` horn |

In kid mode he steers himself. A helper catches the kart near the edge and steers it back, the
edge strip slows it a little, and it cannot hit the walls hard or turn around.

## What works

- Menu without reading: mode (Freie Fahrt, Rennen, Zeitfahren), Tempo (Kind, Normal, Schnell),
  Gegner (0 to 3), then "press a button to join". Options and picks are remembered.
- Player selection: each player picks driver, vehicle, Kind or Profi, and colour with their own
  controller, with a live 3D preview. A controller keeps its colour.
- 16 drivers: your 8 toys as paper cut-outs (Junge, Katze, Löwe, Bär, Polizei, Motorrad, Flieger,
  Duplo-Flieger) and 8 animated Kenney characters. 12 vehicles: 5 karts, racing car, oldtimer,
  4 trucks, motorcycle.
- Two tracks, each about 285 m and 3 laps (about 1:45 at Kid speed): Kurvenkurs (round curves,
  sunny) and Waldkurs (Kenney tiles, evening).
- Race with 1 or 2 players and 0 to 3 AI karts; split screen side by side with a coloured frame
  per player; the Kind player gets the left half.
- Kid mode: auto-accelerate, lane steering, soft walls, pickups fire alone, catch-up boost when
  behind the other human, reset when stuck or off course, calm camera, no clock.
- AI karts stay close to the slowest human when a kid is racing.
- Boost stars with sound and sparkles; horn; countdown; "Letzte Runde!"; pause menu.
- Finish screen with confetti and applause for everyone, places shown small, Nochmal / Menü.
- Time trial with best time per speed.
- Frame rate at 1080p split screen with 5 karts on the RTX 4070 (target 60): about 450 fps on
  Kurvenkurs and 350 fps on Waldkurs, worst 1 % above 175 fps.

## Checked automatically (all passing)

`tools\check.ps1`: no Godot 3 names; every script, scene and resource loads; simulated gamepad
mapping (30 checks); a scripted walk through the menu with two keyboard players into a race, pause
and resume (22 checks); 9 headless runs of the race scene on both tracks, including two kid karts with nobody
touching the controls, with the stick held to one side, and with random button mashing. At Kid
speed no kart needs a rescue. `tools\export.ps1`: the exe runs a full 2-player kid race with 3 AI
karts and opens its window.

## Not verified, or known weak spots

- Real controllers, the projector, and how the driving feels in your hands. I can read numbers
  and screenshots, not feel.
- Sound levels: all sounds are generated and were never listened to. Expect to want changes.
- Bobo's front picture lost its hair (book page with a busy background). A photo on a plain
  background fixes it: name it `bobo-front.jpg`, or replace the bear photos listed in
  `photos/toys/pairs.json`.
- Kid mode feel: tuned with simulated kids only. Watch whether he finds the gas button and
  whether the edge strip feels like a fair "oops" or like a punishment.
- Toy vehicles are flat photo cards: from the side they look thin. A 3D model fixes that later.
- The new look was judged from still pictures only. Moving clouds, leaves and light shafts may
  feel different in motion; say what is too much.
- The Duplo plane's front photo is a little blurred; a sharper one would look better.
- Player selection works with pads and keyboard only, not the mouse.
- Full mode drift and the Fast speed were tuned by the AI driver only.

## The 5-minute couch test

Plug in both controllers first. Sit so that he is on the left.

1. **Minute 1, free drive, him alone.** Freie Fahrt, Weiter. He presses any button on his pad,
   leave "Kind", press A. Say nothing and watch: does he use the stick or the buttons? Does he find
   the horn? Does he drive into a star?
2. **Minute 2 to 4, one race.** Pause (Start), Menü, Rennen, Tempo "Kind", Gegner 3, Weiter. Both
   press a button. You switch your panel to "Profi", both press A.
   Watch: does he look at his own half? What does he do when a kart passes him? Does he notice
   that he cannot crash?
3. **Minute 5, the finish.** Let him press the button on the finish screen himself.
   Does he pick Nochmal?

Write down, right after:

| Question | Answer |
| --- | --- |
| Stick or buttons? | |
| Did he look at his half? | |
| Did he ask for another race? | |
| What made him laugh? | |
| Where did he give up or get bored? | |
| What felt wrong for you in Profi mode? | |
| Too loud, too quiet, annoying sounds? | |

Tell Claude the answers by voice; they become the tuning list.

## What is next

1. You: one race with sound on, on the projector. Too loud, too quiet, annoying? Do the boosts
   feel right now? Is the seat choice clear?
2. Codex: drawn toy pictures (`docs/CODEX_TOY_ART.md`).
3. Rest of milestone 2: driver portraits, graphics presets for projector and monitor, scenery.
2. Milestone 2 per PLAN.md: more of your toys (retake the bear), music and sound, graphics presets.
   The Duplo plane has all four side photos, so it is the first candidate for a 3D model.
3. Two small open decisions from PLAN.md: which small pad, and the first cast for 3D toys.

## Notes for the next Claude session

- Read CLAUDE.md first. The Godot MCP server is configured in `.mcp.json` and loads at session
  start; this session used the Godot command line instead.
- Tuning knobs are listed in CLAUDE.md under "Common jobs".
- Screenshots need a visible window: a covered or minimised window returns a stale picture.
- Leak notices when Godot quits (`resources still in use at exit`) come from sounds still
  playing; they are not script errors and the checks ignore them.
- `tools/.venv` and `tools/.cache` (1.1 GB of cut-out models) are not in git. Recreate with
  `python -m uv venv tools/.venv --python 3.12` and `uv pip install "rembg[cpu]" pillow numpy`.
