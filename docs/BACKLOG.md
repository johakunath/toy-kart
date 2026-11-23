# Backlog

The ordered plan is [ROADMAP.md](ROADMAP.md) (from the research in RESEARCH.md); this page keeps the loose items.

Milestone 1 passed on your test drive (21 Nov 2026); the couch test with him waits until he is
ready (PLAN.md, milestone 5). Pick by what you want to play.

## Playtest with him, 23 Nov 2026 (10 minutes, build before f45d859)

He had fun and likes it. Being fixed now unless marked "waits".

| Area | Item | Status |
| --- | --- | --- |
| Boost | Driving over a boost pad gives no boost | Fixing |
| Jumps | Jump ramps barely lift the kart: jump much higher, with a fun trick animation | Fixing |
| Balance | The front one or two karts take all item boxes (pick-up range too big); 3rd and 4th get nothing and fall further behind | Fixing |
| Items | A boost you collect and fire whenever you want | Fixing |
| Vehicles | Remove pickups, trucks, buses, jeeps: keep only our own toys and open karts/cabrios/race cars a toy can sit in (changes the karts decision) | Fixing |
| Police car | Too short and a bit small; looks like it floats (shadow/ground contact) | Size and ground: fixing. Lettering and length of the drawing: Codex, `docs/CODEX_REDO_POLIZEI_KOBA.md`, then local 3D |
| Koba | Face looks bulky and odd: new Codex views, then rebuild the 3D model locally | Waits for Codex |
| Menu | Two players: the panels swap sides when clicking. Both on keyboard: grown-up left with WASD, kid right with arrow keys; easy to switch | Fixing |
| Menu | Pictures of the real keys and pad buttons instead of written key names; less text overall | Fixing |
| Track | New photos: blue police station and the Duplo shop become props beside the track, not vehicles | Done: photo cards beside the start straight (`scripts/track/roadside.gd`, `tools/make_props.py`, `docs/img/roadside-2026-11-23.png`). Waits: local 3D models of the station, tower and shop (Pixal3D, `local-game-assets`) to replace the cards; trees can still poke through a card outdoors |
| Track | Toys that are not racing stand at the roadside and watch | Done: two rows beside the start grid, no colliders; they sway, hop when a human kart passes and cheer at a human finish |

## Found while building milestone 1

| Area | Item | When |
| --- | --- | --- |
| Test | Play with his small pad (only your Xbox pad and simulated pads so far) | Milestone 5 |
| Tuning | Kid mode after watching him: how strongly the stick answers, edge strip, AI gaps, Kid speed | Milestone 5 |
| Art | Police car: the "POLICE" lettering on the 3D model is scrambled (AI texture). Fix by painting the lettering into its texture in Blender, or new views | When it bothers him |
| Art | Vehicle proportions in FLUX pictures are off (police car, motorbike); fine for portraits, not for new views | If new vehicle views are needed |
| Art | Portraits also on the HUD and the finish podium (the menu has them since round ten) | Milestone 2 |
| Sound | Listen and tune: volume of music vs. effects, rumble, turbo sound. Real recorded sounds if the generated ones feel cheap | Milestone 2 |
| Sound | Volume slider instead of only music on/off | If needed |
| UI | Mouse support on the player selection page | If needed |
| UI | 3D podium on the finish screen | Later |
| Karts | More vehicles already in `assets/` and not wired up yet: future racer, speedster, two racers, drag racer | When he wants more |
| Look | More weather: rain with a wet road, snow, night with headlights | Later |
| Look | A weather or time-of-day choice per track instead of one fixed mood | Later |
| Tracks | Hills and banked curves on the generated track (needs a sloped floor collider) | Later |
| Tracks | Scenery on Kurvenkurs: tents, signs (fans at the start exist since round 15) | Milestone 2 |
| Tracks | Side lanes on the other round tracks (one `"fork"` entry each, on flat road) | When he likes the Wohnzimmer one |
| Tracks | Toy train on Kurvenkurs looks small from far away (bigger train needs bigger portals) | If he does not notice it |
| Tech | Wohnzimmer draws many separate furniture pieces (~200 fps vs 300+ outdoors): merge into fewer meshes if the projector PC struggles | If needed |
| Tech | Driving on the Kenney ramp and bump tiles (the kit's tile library has no collision for them) | With new tracks |

## From PLAN.md

| Area | Item | When |
| --- | --- | --- |
| Gameplay | Aimed items and weapons | After kid mode works |
| Gameplay | Battle mode, cups of 3 races | Milestone 4 |
| Gameplay | More tracks: living-room miniature, fantasy and comic worlds | Milestone 3 onward |
| Gameplay | Loopings and wall rides (a new kart controller with gravity along the track) | Later |
| Gameplay | 3 to 4 players | When needed |
| Gameplay | Unlocks, outfits, levelling; a few per session, no streaks | Later |
| Vehicles | More vehicle types, for example a space shuttle | Later |
| Vehicles | Toys only in fitting karts, so a figure never floats above a pickup: a "fits these karts" list per driver (or per kart: which seat style). For paper cards, a Codex picture of toy + kart together is an option; 3D toys mostly solve it. Johannes' idea, 22 Nov 2026 | Milestone 3, after more 3D toys |
| Kids | Simple track editor or track colouring for him | Later |
| Input | Learner mode: stick steering plus a pickup button, lighter smart steering | When kid mode gets boring |
| Input | Tilt steering with a motion-sensor pad | Later |
| Input | DIY big-button box | Optional |
| Platforms | Steam Deck via Godot's Linux export | After milestone 2 |
| Platforms | Android tablet: touch zones left and right; split screen with one player per side | Later |
| Platforms | itch.io page, installer | Before sharing |
| Art | Art pass: toon shading, outlines (strong colours done in round ten; tune with `tools/make_strong_colors.py --strength`) | Milestone 3 |
| Art | New toys: photos, Codex turnaround views, `make_3d_toy.py`, `make_portraits.py` (see `docs/MODELS_3D.md`); living-room photo textures made with FLUX | When he brings a new toy |
| Art | Blender basics for you: move, scale and recolour a model | Optional backup |
| Tech | Graphics presets for projector and 1440p 144 Hz | Milestone 2 |
| UI | The player panel is at its height limit at 1080p: a new row needs space taken elsewhere | With the next menu change |
| Tech | Save file for unlocks | With unlocks |
| Tech | Git LFS once model and texture files grow | When the repo grows |
| Legal | Replace branded toys (Lego, licensed plush, picture-book characters) before a public release | Before sharing |
