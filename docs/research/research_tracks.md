# Kart track design research: what makes MK / CTR / DKR / Sonic tracks great, and how to do it procedurally for a 4-year-old

Date: 2026-11-22. Web research (WebSearch + WebFetch). Items marked **[src]** are backed by the linked source; items marked **[judgement]** are my synthesis / engineering advice for this project (Godot 4.7, Path3D-based generated tracks, ~285 m, 2-3 laps, 2-player split screen, kid assist).

Honest gap: Nintendo has never published a formal "course design rules" document. Iwata Asks (MK Wii, MK7), Yabuki interviews (MK8) and Ask the Developer Vol. 18 (MK World) give scattered principles; the rest comes from designer write-ups (SuperTuxKart guidelines, Game Developer articles, Milestone, Naughty Dog) and community analyses. No GDC talk dedicated to kart-track rhythm was found.

---

## 1. Primary-source principles

### Nintendo
- **Every course needs one surprise / hook, not just better graphics.** MK8's team explored many ideas and picked changing gravity direction because they wanted "an element of surprise". Courses mix sections of different kinds (ground, underwater, flying, anti-grav). **[src]** Nintendo Life Yabuki interview: https://www.nintendolife.com/news/2014/05/interview_mario_kart_8_director_kosuke_yabuki_on_key_features_of_the_wii_us_blockbuster_release ; anti-gravity / F-Zero: https://nintendoeverything.com/konno-and-yabuki-on-how-f-zero-led-to-mario-kart-struggling-with-anti-gravity-in-mk8-sunshine-airport-came-from-previous-entrys-development
- **Split screen limits scale.** F-Zero-scale tracks with long straights were not possible with MK8's multiplayer design; split screen had to be factored into level design. **[src]** (IGN interview summarised in the search results above; same nintendoeverything link). -> For us: compact tracks, landmarks visible in a half-height viewport.
- **Adding verticality to flat tracks** was the main way to refresh old flat GBA tracks in the Booster Course Pass. **[src]** https://nintendoeverything.com/mario-kart-8-deluxe-booster-course-pass-interview-kosuke-yabuki-future/
- **Balance through thousands of tests**; tuning one element alone breaks the whole. **[src]** same Yabuki coverage.
- **MK World (Ask the Developer Vol. 18):** courses placed by climate/compass; a big landmark (snowy mountain) anchors a region; connecting roads must not feel barren or "divided into chunks"; trees key to natural look; day/night and weather cycles, transitions shortened so they never get dull; straights made interesting with rail rides and wall rides ("I'm gonna drive up that wall"); too many bends makes players lose their sense of direction; water you can drive on, visible floor through clear water, NPC animals (Cow, Cheep Cheep) as racers; everyday-life scenery (people eating, drive-thrus). Smart Steering was improved so "even small children" reach the finish. **[src]** Ch.2 https://www.nintendo.com/en-gb/News/2025/May/Ask-the-Developer-Vol-18-Mario-Kart-World-Chapter-2-2832717.html ; Ch.3 https://www.nintendo.com/en-gb/News/2025/May/Ask-the-Developer-Vol-18-Mario-Kart-World-Chapter-3-2832747.html ; Ch.4 https://www.nintendo.com/en-gb/News/2025/May/Ask-the-Developer-Vol-18-Mario-Kart-World-Chapter-4-2832777.html ; Ch.1 https://www.nintendo.com/en-gb/News/2025/May/Ask-the-Developer-Vol-18-Mario-Kart-World-Chapter-1-2832687.html
- **MK7 (Iwata Asks, Retro Studios):** courses "full of variation"; atmosphere particles (sparks, cherry blossoms in the air, marine snow underwater) give depth and presence; gliding and underwater were the new section types. **[src]** https://iwataasks.nintendo.com/interviews/3ds/mario-kart-7/0/3 and https://iwataasks.nintendo.com/interviews/3ds/mario-kart-7/0/0
- **MK Wii (Iwata Asks):** whole-family design; ~30 wheel prototypes; button moved so a child's fingers reach it; playtests where people struggled drove more user-friendliness. **[src]** https://iwataasks.nintendo.com/interviews/wii/mariokart/0/2
- **Smart Steering / Auto-Accelerate (MK8DX)** keep new drivers on the track and off walls. **[src]** https://www.mariowiki.com/Smart_Steering , https://play.nintendo.com/news-tips/tips-tricks/mario-kart-8-deluxe-tips-tricks
- Anti-gravity: gravity and camera always normal to the road surface; Mobius-strip track in MK8; idea came from MK7 Rainbow Road moon section. **[src]** https://www.mariowiki.com/Anti_gravity

### Crash Team Racing (Naughty Dog)
- Each course treated like a platformer level: main paths plus secrets everywhere; core question "where are the big jumps, where are the shortcuts?". Boost pads often sit at shortcut entrances; ramps with turbo pads launch onto raised platforms. Shortcut density varies (Tiny Arena none). **[src]** https://www.gamesradar.com/the-making-of-crash-team-racing , https://strategywiki.org/wiki/Crash_Team_Racing/Tracks , https://gamingbolt.com/crash-team-racing-nitro-fueled-guide-all-track-shortcuts

### SuperTuxKart track guidelines (best explicit numbers found)
- Clean lap **40-70 s, sweet spot ~60 s**; very short tracks force more laps and repetition. **[src]** https://supertuxkart.net/Making_Tracks:_Gameplay_Fundamentals
- Avoid narrow tracks, especially at the start. Alternative paths: slower path should be easier, time difference ideally **< 1 s, never > 2 s**.
- Jumps need landing space; mandatory jumps must be completable at beginner speed.
- Balance hard curves with easy sections where boosts are safe; boost pads sparingly with several sections without them.
- Keep insides of curves free of obstacles. Avoid concave crests that hide what follows; use slight convex curvature to *show* a hard corner coming.
- The more surprising an obstacle, the clearer it must be; dynamic obstacles visible early, avoidable, cost little time.
- Road/off-road colour contrast is the most important readability cue; no look-alike dead ends; no invisible walls; mark the lap line with arch + checkers.

### Game Developer articles
- Wider road = easier corners (more obtuse clipping angle, more forgiveness). Guideline: lane = 1.6 car widths; shoulder 50-75 % of a car width. **[src]** https://gamedeveloper.com/design/feature-the-fundamentals-of-arcade-style-racing-track-design , https://gamedeveloper.com/design/a-rational-approach-to-racing-game-track-design
- Super Mario Kart: narrow hairpins created the challenge; veterans feel later MKs are so wide that staying on the road is rarely a challenge (i.e., width is the main difficulty dial). **[src]** https://gamedeveloper.com/design/-i-super-mario-kart-i-at-25-dissecting-a-revolutionary-game-design

### Rhythm / sections
- Magnopus: vary shape, angle and placement of turns for rhythm; escalate intensity gradually and space key moments; splits give choices and reduce crowding; time set pieces to music beats loosely (geysers, pulsing lights); split turns >90 deg into evenly spaced control points with smooth tangents to avoid mesh/collision artefacts. **[src]** https://www.magnopus.com/blog/the-art-of-designing-a-memorable-race-track
- MK8 case study (Bone-Dry Dunes): track = 3 sections separated by a ramp + environment change; drift flow is what makes a section good; difficulty spikes come from rapid back-to-back decisions. **[src]** https://zoe-pilgrim.itch.io/kokiri-forest-mario-kart-8-level-design/devlog/339569/mario-kart-8-case-study
- SRB2Kart circuit level design wiki (community): https://www.wiki.srb2.org/wiki/Level_Design_101/Circuit

### Lap time norms
- MK8 3-lap world records ~1:35 (Animal Crossing); casual races ~2:00-2:30 for 3 laps, i.e. ~40-50 s/lap. **[src]** https://www.guinnessworldrecords.com/world-records/424247-fastest-lap-time-for-animal-crossing-mario-kart-8 ; STK 40-70 s per lap.
- **[judgement]** For a 4-year-old: total race 60-120 s. With ~285 m and 3 laps, aim for 25-40 s per lap at kid speed; don't make tracks longer, make them denser (more events per lap).

### Toy-scale worlds
- Re-Volt: RC cars in toy shop, supermarket, museum, giant playroom ("Toy World"); scenery oversized vs. car. Included a track editor. **[src]** https://revolt.fandom.com/wiki/Category:Tracks , https://www.topgear.com/car-news/gaming/absolutely-nailed-it-1999-videogame-perfected-rc-racing-formula
- Micro Machines: kitchen tables, desktops, bathtubs, worktops at true scale; everyday items are obstacles; falling off the table is the hazard. **[src]** https://en.wikipedia.com/wiki/Micro_Machines_(video_game) , https://www.topgear.com/car-news/gaming/remembering-classic-games-micro-machines-2-1994
- Hot Wheels Unleashed: garage, kitchen, bedroom; HWU2 Backyard track starts in the garden and enters the living room through the window. Environments designed *first*, with "gameplay hooks" (cabinets, treehouse planks) to anchor track sections, and measured clearances. **[src]** https://news.xbox.com/en-us/2023/10/20/hot-wheels-unleashed-2-turbocharged-creating-the-backyard , https://www.gamedeveloper.com/design/a-closer-look-at-hot-wheels-unleashed-2---turbocharged-track-builder , https://en.wikipedia.org/wiki/Hot_Wheels_Unleashed

### Track editors
- **Hot Wheels Unleashed builder:** priorities "usability and simplicity"; 5 steps (environment -> start -> body -> finish -> validate); auto-closure reconnects edited sections; max segment length; validation = actually drive a full lap through all checkpoints; test mode always available; all official tracks made with the same tool. **[src]** gamedeveloper link above; https://www.pcgamer.com/heres-how-the-hot-wheels-unleashed-track-editor-works
- **ModNation Racers:** you *drive* a paintbrush kart and the road is laid behind you; one-click surface repaint; auto-scenery. Took ~18-20 months to get the first track done. **[src]** https://en.wikipedia.org/wiki/ModNation_Racers , https://blog.playstation.com/2009/12/23/modnation-racers-track-studio-walkthrough-with-track-designer-mark-riddell/comment-page-2 , https://gamedeveloper.com/game-platforms/interview-making-user-generated-content-friendly-but-deep-with-i-modnation-racers-i-
- **Trackmania:** powerful block editor with Simple and Advanced modes; Common Sense rates 10+ (DS version 6+). **[src]** https://www.commonsensemedia.org/game-reviews/trackmania
- **[judgement]** For a 4-year-old: ModNation's "drive to draw" is the most natural (he already can drive); HWU's auto-close + drive-to-validate solves broken tracks. Avoid free 3D placement.

### Godot tech
- **TheDuckCow Road Generator** (MIT, Godot 4.4+, v0.9.x, GDScript): RoadPoints with per-point lanes/width/shoulders interpolated, auto AI lane paths, runtime procedural functions, custom meshes + colliders, glTF export; not feature-complete, no banking mentioned, intersections limited. Highway/street oriented, not kart-track oriented. **[src]** https://github.com/TheDuckCow/godot-road-generator , https://godotengine.org/asset-library/asset/3379
- **CSGPolygon3D MODE_PATH** extrudes a profile along Path3D, `path_joined` for loops, `use_collision`; rotation via path-follow; Curve3D per-point tilt = bank. Users report tilt/up-vector quirks and CSG performance issues; recommendation is to build an ArrayMesh in script. **[src]** https://docs.godotengine.org/de/4.x/classes/class_csgpolygon3d.html , https://forum.godotengine.org/t/tilt-variable-for-path3d-not-functioning-as-expected/126442 , https://forum.godotengine.org/t/how-to-make-mesh-follow-path3d-without-using-csg/134760
- **[judgement] Recommended for this project (already generating ArrayMesh from points):**
  - Keep own generator. Add per-point `width`, `bank_deg`, `height` channels interpolated along the line (same idea as RoadPoints). Sample `Curve3D.sample_baked_with_rotation()` (respects tilt when `up_vector_enabled`), or compute frames yourself with a parallel-transport frame + explicit bank angle to avoid flips.
  - Bank automatically from curvature: `bank = clamp(k * curvature * speed^2, 0, 12 deg)`; ramp it in/out over ~10 m. Small banks (5-12 deg) make corners feel catching and forgiving.
  - Hills: add a smooth height profile (sum of 1-3 low-frequency sines or authored per-point heights), keep grade < ~8-10 % for kid karts, never put a concave crest right before a corner.
  - Collision: ConcavePolygonShape3D trimesh from the same road mesh (Jolt is fine with it); keep triangles roughly square (segment length ~ road width/4) so the rolling ball doesn't hit seams; enable backface collision on thin road decks, put a thicker collider under jumps/landings.
  - Anti-grav / loops / wall ride: for a ball-physics kart, set own gravity each physics tick = -road normal from the nearest racing-line sample (or ray-cast down to surface normal), only inside flagged sections; outside, normal gravity. Alternatively Area3D with gravity override (point/direction) per section. Camera up follows the same normal with smoothing. Keep this for later; it's L effort and risk for "never lose control".
  - Jumps: mark segments as ramp (raise + lip), guarantee landing zone 2x jump length, and in kid mode steer airborne karts toward the racing line (air-assist) so landing is always on road.

---

## 2. The 12 most impactful ideas, applied to Toy Racer

| # | Idea | How to apply here | Impact | Effort |
|---|---|---|---|---|
| 1 | One hook/set piece per track (MK8 "surprise") | Each track gets one signature moment: sofa-cushion jump, hoop/loop-de-loop toy track piece, bathtub water section, giant toy train crossing. Build as a flagged segment in the round-track generator. | High | M |
| 2 | Sections + environment changes (3 acts per lap) | Split the lap into 3 zones separated by a gate/ramp/tunnel and a lighting/floor change (carpet -> wooden floor -> rug; forest -> cave -> meadow). Generator param: `zones[]` with surface + scatter set. | High | M |
| 3 | Rhythm: alternate easy sweepers, one tighter corner, a straight with boost | Generate points from a corner "grammar" (sweeper, S-bend, hairpin, straight) instead of random points; never two hard corners back-to-back; kid mode keeps hairpins wide. | High | M |
| 4 | Width as difficulty dial | Per-point width: 12-16 m kid-friendly base, wider at start grid and corners, slightly narrower only on straights. Wider = fewer resets; keep check.ps1 kid races at zero resets. | High | S |
| 5 | Gentle hills and auto-banking | Add height + bank channels to the generator; bank from curvature (5-12 deg), crests convex, max grade ~8 %. Biggest "MK feel" upgrade over a flat road; trimesh collision from same mesh. | High | M |
| 6 | Jumps with guaranteed landings (CTR's core) | 1-2 ramps per track with big landing zones; kid air-assist steers to the line; small boost on landing (trick-feel without a button). | High | M |
| 7 | Toy-scale living room world | Re-Volt/Micro Machines/HWU idea: road is an orange toy track or rug path between giant furniture; his real toys (photo cut-outs) as giant landmarks; "falling off the table" replaced by soft walls. Design the room first, then thread the line through anchor points (HWU). | High | L |
| 8 | Landmarks and readability | One giant visible landmark per zone (teddy bear, block tower, castle), visible in half-screen split view; strong road/off-road colour contrast; checkered arch at finish; arrow signs/chevrons before corners. | High | S |
| 9 | Safe split paths / shortcuts (risk-reward light) | One fork per track: wide easy path vs. short path with boost pads, time gap < 1-2 s (STK rule); AI and kid assist take the easy path; dad gets the fun choice. Racing line stays on main path for laps/progress. | Med | M |
| 10 | Boost pads placed with intent | Pads on corner exits and before jumps/shortcuts, never mid-corner; several sections without any; stars on the racing line so the kid collects them naturally. | Med | S |
| 11 | Background life and gentle moving set pieces | Waving toys, hopping animals, crowd of stuffed animals at the start, a slow toy train crossing (telegraphed, harmless bump, no stop). MK World: life and food stands make the world feel inhabited. | Med | M |
| 12 | Kid "drive to draw" track editor | ModNation-style: kid drives freely in an empty room in a "paint" mode, the path is recorded, smoothed, auto-closed, widened and validated by an AI lap (HWU), then built by the existing round-track generator. Icons only. | Med (huge for him, but later) | L |

Also worth doing cheaply: per-track time of day/weather (already in Atmosphere) with airborne particles (dust motes in living room, leaves in forest, MK7's "depth" particles) - Med/S; music cue changes per zone - Low/S.
