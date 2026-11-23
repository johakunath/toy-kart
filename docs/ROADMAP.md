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

## Phase C: playing together (done 23 Nov 2026, thirteenth round)

| Item | Research | Status |
| --- | --- | --- |
| Team mode "us vs. the toys" | #11 | Done: "Team" card, team place, team finish banner |
| Kid-safe items: turbo, superstar, shield bubble, spring, tickle bubble | #12 | Done (magnet left out: too close to turbo) |
| Item odds per player, no blue shell | #13 | Done |
| Bricks on the racing line, dot counter | #18 | Done |
| Podium medals, family brick jar | #16 | Done. Open: a present after every race (sticker, horn, colour) needs things to unlock first |
| Toy rescuer respawn | #20 | Done as a bounce drop; a toy helicopter model would be nicer |
| Hidden rubber-band: wide lines | #19 | Done; a close pack in the last lap is open |

## Phase D: sound and camera (done 23 Nov 2026, fourteenth round)

| Item | Research | Status |
| --- | --- | --- |
| Engine layers | #22 | Done: recorded engine + generated high whine layer. A full 3-loop RPM engine is open |
| Adaptive music with a final-lap version | #22 | Done: cross-fade into a faster tune |
| Split-screen audio: own engine per half, panned | #23 | Done |
| Spring chase camera with drift swing | #24 | Done |
| Recorded sound effects where generated ones feel cheap (ask before buying) | goals | Waits for Johannes' ears |

## Phase E: worlds (done 23 Nov 2026, fifteenth round)

| Item | Research | Status |
| --- | --- | --- |
| Living-room toy world, his toys as giant landmarks | #25 | Done: track "Wohnzimmer" (sofa with Bobo, coffee table bridge, Koba in the infield, fox by the window, police car on the table, two planes circling) |
| Three zones per lap, each with its own look | #26 | Done: "zones" in the generator (road, kerb, barrier colours); Wohnzimmer has wooden floor, rug, play corner with a brick arch |
| Background life: waving toys, animals, plush crowd | #33 | Done: `ToyMotion` (bob, rock, nod, hop, orbit, blink); fans by the start line and a plane on every round track |
| One safe fork per track | #32 | Done on Wohnzimmer: side lane round a brick island (`Track.forks`); kid assist keeps the main road, some AI take the lane. Other tracks: add a "fork" entry |
| MultiMesh grass with wind, toon water | #35 | Done: grass, flowers, reeds; pond on Kurvenkurs, lake on Riesenrunde |

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
