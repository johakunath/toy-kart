# Research: what would make Toy Racer as good as Mario Kart

22 Nov 2026. Five research passes: driving feel, gameplay and kid design, Godot tech and graphics,
track design, and an audit of the current code. The full notes, with sources, are in `docs/research/`:
[feel](research/research_feel.md), [gameplay](research/research_gameplay.md),
[tech](research/research_tech.md), [tracks](research/research_tracks.md).
This page is the ranked summary. Nothing here is decided until it lands in PLAN.md or DECISIONS.md.

## The short answer

Mario Kart's magic for a parent and a child is three layers working together:
1. **Every second feels good.** Drift sparks that change colour, boosts that surge and fade,
   rumble, sound and camera kicks. Cheap to build and present all the time.
2. **The child always has fun, and the adult still has a real race.** Assists he can see, kid-safe
   items, catch-up that stays hidden, and a podium and present for everyone.
3. **Tracks with moments.** Hills, banked corners, one jump, one surprise per track, landmarks.

Toy Racer already has the hardest part: his own toys as drivers, a kid mode that never loses
control, and a clean input -> assist -> kart chain. The gaps are mostly in layer 1 (cheap) and
layer 3 (medium).

## What the game has today (code audit)

| Area | Today | Gap vs. Mario Kart 8 |
| --- | --- | --- |
| Drift | One level: 1 s gives a 0.8 s +25 % boost | No hop, no spark colours, no tiers |
| Boosts | Kick + push, hard stop at the end | No fade-out |
| Start | 3 s countdown | No start boost |
| Walls | Default physics bounce | No glance-off, can feel sticky |
| Kart bumps | Soft push apart | No fun in it; no boost or wobble |
| Camera | Yaw lag, boost FOV kick +14, shake (off for kid) | No drift swing, no look-behind |
| Juice | Smoke, flames, speed lines, confetti | No skid marks, wall sparks, **no controller rumble at all** |
| Audio | One engine sample with pitch; 2 music tracks | No RPM layers, no doppler, no music layers |
| AI | Follows the line, rubber-band around the kid | Never drifts, never overtakes on purpose, no personality |
| Items | Boost star only | No item set, no odds per player |
| HUD | Place, lap, timer, item icon | No face strip or minimap; place is a digit |
| Finish | Message, confetti cards | No podium scene, no present |
| Respawn | Instant teleport | No rescue animation |
| Tracks | Flat, fixed width | No hills, banking, jumps, forks, set pieces |
| Rendering | MSAA 2x, AgX, SSAO, SSIL, glow, 4 shadow splits | No rim light, no toy materials, glow not re-tuned for 4.6, no SMAA |

## Ranked list

Score = what it adds for a dad and a 4-year-old on the projector, divided by effort in this codebase.
Impact: H / M / L. Effort: S (one session) / M (2-3 sessions) / L (a milestone).

### Tier 1: biggest win per hour (do first)

| # | Item | Area | Impact | Effort | Why |
| --- | --- | --- | --- | --- | --- |
| 1 | **Drift tiers with spark colours** (blue 0.5 s, orange 1.0 s, purple 2.0 s; bigger boost each tier); kid reaches tiers 1-2 automatically | Feel | H | S | The heartbeat of Mario Kart; ours has one invisible step |
| 2 | **Boosts fade out** over about 1 s instead of cutting off | Feel | H | S | A hard cut feels like braking |
| 3 | **Controller rumble**: boost, drift tick, wall, bump; soft for kid, off switch | Feel | H | S | Not present at all; huge for a child holding a pad |
| 4 | **Start boost that never stalls**: any gas in the last second = boost | Feel | H | S | A thing to do at the start, always rewarded |
| 5 | **Walls glance off**: remove only the speed into the wall, turn the nose along it | Feel | H | S | Stops dead stops; keeps the kid promise |
| 6 | **Colour and glow re-tune for Godot 4.6+**, rim light on karts and drivers, emissive pads and stars | Look | H | S | The Nintendo look is soft shading + rim + bloom, not outlines |
| 7 | **Toy materials**: plastic with clearcoat, plush rough with rim | Look | H | S | His toys should look like toys; 4.7 clearcoat suits it |
| 8 | **Kid-readable HUD**: his toy's face with a medal colour for the place, lap flags as dots, a strip of sliding faces instead of a minimap | UI | H | S | He can't read digits |
| 9 | **Bumping is fun**: dad and kid touching gives both a small boost and a wobble; never knocks him off his line | Feel | H | S | Turns contact into play |
| 10 | **Anti-aliasing and shadow budget**: MSAA 4x + SMAA, 2 shadow splits in split screen | Tech | M | S | Cleaner edges on the projector, frame-time headroom |

### Tier 2: the next layer (milestone-sized)

| # | Item | Area | Impact | Effort | Why |
| --- | --- | --- | --- | --- | --- |
| 11 | **Team mode "us vs. the toys"**: one team score, dad's skill goes into helping | Mode | H | M | Nintendo's parent-helps-child design (Galaxy co-star); losing hurts less |
| 12 | **Kid-safe item set**: boost, star, bubble shield, magnet, spring; hits on him are only a 0.5 s happy wobble | Gameplay | H | M | Variety without tears |
| 13 | **Item odds per player**: kid always gets good items, dad weaker when ahead; no blue shell | Gameplay | H | S (with 12) | Keeps him happy at his best moment |
| 14 | **Hills and automatic banking** in the track generator | Tracks | H | M | The biggest step from "flat test track" to Mario Kart |
| 15 | **One jump per track with a trick boost** and guaranteed landing (kid mode steers in the air) | Tracks / Feel | H | M | Air time is joy |
| 16 | **Podium for everyone + a present after every race** (sticker, horn, colour), progress shared by the family | Meta | H | M | Reward effort, not just winning |
| 17 | **One signature moment per track** (sofa-cushion jump, toy train crossing, tunnel) | Tracks | H | M | What he will talk about |
| 18 | **Coins / bricks along the racing line**, counter as dots | Gameplay | H | S | Small goals that teach steering |
| 19 | **Hidden rubber-band**: AI loses ground through wide lines and small mistakes, close pack in the last lap | AI | H | M | Feels fair, not slowed down |
| 20 | **Toy rescuer respawn** (toy helicopter or hand, under 1.5 s, funny sound) | Feel | M | S | Turns a failure into a joke |
| 21 | **Width per point and corner rhythm** (sweeper, S-bend, hairpin; never two hard corners in a row) | Tracks | H | S-M | Width is the difficulty knob for a kid |
| 22 | **Engine sound from 3 RPM loops + adaptive music** (final-lap layer) | Audio | M | M | The weakest link after rumble |
| 23 | **Split-screen audio**: own engine non-positional per half, panned left/right | Audio | M | M | Each player hears their own kart |
| 24 | **Spring chase camera** with drift swing; taller look-at in the tall half-screens | Feel | M | S | Weight and speed |

### Tier 3: bigger bets (later milestones)

| # | Item | Area | Impact | Effort |
| --- | --- | --- | --- | --- |
| 25 | **Living-room toy world**: road between furniture, his real toys as giant landmarks | Tracks | H | L |
| 26 | Three zones per lap with their own look; landmarks per zone | Tracks | H | M |
| 27 | Mini-cup of 3 races with a trophy (about 10 min) | Mode | M | S |
| 28 | AI personalities in the driver `.tres` (line, mistakes, honks, cheers when he passes) | AI | M | M |
| 29 | Tow rope / slipstream behind dad; dad can give his item to the kid | Co-op | M | M |
| 30 | Kid battle modes: collect sparkles into a jar, "catch Papa" | Mode | M | M |
| 31 | Free-drive missions: rings, hidden toys, visible rewards | Mode | M | M |
| 32 | One safe fork per track (wide easy path, short boosted path) | Tracks | M | M |
| 33 | Background life: waving toys, animals, stuffed-animal crowd | Tracks | M | M |
| 34 | 120 Hz physics with an interpolated camera (retune and recheck kid races) | Tech | M | M |
| 35 | MultiMesh grass with wind, toon water | Look | M | M-L |
| 36 | "Drive to draw" track editor for him | Kids | M (huge later) | L |
| 37 | Baked lightmaps per track | Look | M | L |
| 38 | X-ray silhouette of his kart behind hills | UI | L-M | S |
| 39 | Gyro steering (Godot 4.7 motion sensors) | Input | L | M |

### Not worth it now

SDFGI or VoxelGI in split screen (cost doubles), post-process outlines, TAA or FSR2 (ghost trails
behind karts), camera motion blur (comfort for a small child), HDR output on the projector,
anti-gravity / wall riding (needs a new kart controller), a blue shell.

## Rules that came out of every pass

- **One stick and one button is the limit at four.** Drift and brake are dad's. Kid tiers come by
  themselves.
- **Four-year-olds expect to win and find losing hard.** Short races (60-120 s), team play,
  praise for effort, a present for everyone.
- **Every input answers at once and loudly.** Sound, rumble, sparks.
- **Help he can see:** a glowing antenna or helper icon when the assist steers (Nintendo does this).
- **Width and landing space, not narrow roads, set the difficulty.**
- **Split screen costs shadows and draw calls, not pixels.** Keep both halves at a steady 60 fps.
