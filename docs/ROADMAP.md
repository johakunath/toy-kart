# Roadmap to Mario Kart quality

22 Nov 2026. Built from the ranked research in [RESEARCH.md](RESEARCH.md) (numbers `#n` point to its
list) and Johannes' answers. PLAN.md milestones still apply; this page orders the work inside them.

## Goals (agreed 22 Nov 2026)

- **His delight first, a real race for dad close second.** Two layers: deep for the adult, assisted
  and flashy for the child. Public release stays parked.
- **No playtest gate.** Johannes develops on and plays with him whenever there is time.
- **Order of pillars:** driving feel and juice, then tracks and worlds, then gameplay variety, then
  graphics extras.
- **Items are friendly:** boosts, shield bubble, silly hits that cost no real time. Classic items
  only between adults later, if ever.
- **Build for 2 players, never block 4:** HUD and camera code stay viewport-agnostic.
- **Free and local by default.** Exception: CC0 or cheap recorded sound effects, each purchase
  approved by Johannes.
- **Both screens:** the 1080p projector (steady 60 fps in split screen, readable) and the
  1440p 144 Hz monitor.

### What he showed in his first 2 minutes (22 Nov 2026)

He played the two-button kid mode. The autopilot was too strong, so he felt no feedback from the
car, and the car was very slow. He loves looking at his toys, but it was not bright or flashy
enough. He loves playing together, even on the keyboard. So: faster kid mode, a lighter hand,
much more feedback (sparks, rumble, sounds), brighter and shinier.

## Phase A: quick wins (done 22 Nov 2026, eleventh round)

Open from A: feel the rumble on a real pad and judge the look on the projector. Small add-on for
later: a helper icon that lights up when the kid assist steers (Nintendo's glowing antenna).

| Item | Research |
| --- | --- |
| Kid mode faster, lighter autopilot, more feedback when he steers | his test |
| Drift levels with spark colours, bigger boost per level; kid gets levels 1-2 by himself | #1 |
| Boosts fade out | #2 |
| Controller rumble (soft for kid, off switch) | #3 |
| Start boost that never stalls | #4 |
| Walls glance off | #5 |
| Bumping is fun: small boost for both | #9 |
| Glow and colour re-tune, rim light, shiny pads and stars | #6 |
| Toy materials: plastic with clearcoat, plush | #7 |
| Kid-readable HUD: face + medal colour, lap dots, face strip | #8 |
| MSAA 4x + SMAA, shadow budget in split screen, 144 Hz frame pacing | #10 |

## Phase B: tracks with moments (mostly done 23 Nov 2026, twelfth round)

| Item | Research | Status |
| --- | --- | --- |
| Hills (road floor collider from the road data, embankments, hill assist) | #14 | Done on both round tracks |
| One jump per track, trick boost, guaranteed landing for the kid | #15 | Done on both round tracks |
| Corner arrow boards | research tracks #8 | Done |
| Automatic banking (up to ~9°, from the curvature) | #14 | Done on both round tracks |
| Width per point and corner rhythm in the generator | #21 | Open: needs `Track.half_width` per point through assist, AI and resets |
| One signature moment per track (cushion jump, toy train, tunnel) | #17 | Open: best together with the living-room world (phase E) |
| Hills and a jump on Waldkurs | | Open: Kenney tiles have no slope collision |

## Phase C: playing together (next)

| Item | Research |
| --- | --- |
| Team mode "us vs. the toys" | #11 |
| Kid-safe items: boost, star, bubble shield, magnet, spring | #12 |
| Item odds per player, no blue shell | #13 |
| Coins / bricks on the racing line, dot counter | #18 |
| Podium for everyone, a present after every race, family progress | #16 |
| Toy rescuer respawn | #20 |
| Hidden rubber-band: AI mistakes and wide lines, close last lap | #19 |

## Phase D: sound and camera

| Item | Research |
| --- | --- |
| Engine from 3 RPM loops; adaptive music with a final-lap layer | #22 |
| Split-screen audio: own engine per half, panned | #23 |
| Spring chase camera with drift swing | #24 |
| Recorded sound effects where generated ones feel cheap (ask before buying) | goals |

## Phase E: worlds

| Item | Research |
| --- | --- |
| Living-room toy world, his toys as giant landmarks | #25 |
| Three zones per lap, each with its own look | #26 |
| Background life: waving toys, animals, plush crowd | #33 |
| One safe fork per track | #32 |
| MultiMesh grass with wind, toon water | #35 |

## Phase F: more to play

| Item | Research |
| --- | --- |
| Mini-cup of 3 races with a trophy | #27 |
| AI personalities in the driver `.tres` | #28 |
| Tow rope / slipstream behind dad, item gifting | #29 |
| Kid battle modes: sparkle jar, catch Papa | #30 |
| Free-drive missions | #31 |

## Phase G: later

120 Hz physics (#34), baked lightmaps (#37), X-ray silhouette (#38), gyro steering (#39),
"drive to draw" track editor (#36), 3-4 players, his little brother joining in about two years.
