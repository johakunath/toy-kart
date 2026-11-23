# Decisions

Claude builds from this file. Change a row only with Johannes' OK, and change it here first.

## Product decisions (from PLAN.md, 21 Nov 2026)

| Area | Decision | Why |
| --- | --- | --- |
| Name | Game: **Toy Racer**. Repo: `toy-kart`. Exe: `builds/ToyKart.exe` | Name decided 21 Nov 2026; repo and exe names kept from the kickoff prompt |
| Engine | Godot 4.7, standard build with GDScript, no C# | All project files are text; free; Kenney template exists |
| Base | Kenney Starter Kit Racing, MIT code and CC0 assets | Arcade kart physics and tile tracks ready |
| Platform | Windows PC first, played on the 1080p projector | Steam Deck and tablet later |
| Screen | Side-by-side split for 2 players; the left player panel drives the left half | Each of you looks at the half on your side of the couch |
| Modes | Free drive, race with 0 to 3 AI karts, time trial | Taking turns first, then racing |
| Kid mode | Auto-accelerate, steering with a helper near the edge, one gas button for full speed, soft walls, catch-up | The same assists as Mario Kart; changed 21 Nov 2026 at Johannes' request: the first version won by itself |
| Language | Icons plus short German labels | Readable for adults; the kid always plays with you |
| Drivers | Ready-made CC0 characters plus toy photo cut-outs; 3D toys in milestone 3 | Fast now, clear upgrade path |
| Toy photos | Front and back per toy in `photos/toys`; left and right for later 3D | Paper drivers now, Pixal3D multiview (front, left, back, right) for 3D |
| Karts | Open go-karts the drivers sit inside (Kenney Car Kit); the kit's trucks stay selectable | Asked for by Johannes on 21 Nov 2026: Mario Kart-style karts, not pickups with the toy on top |
| Look | Stronger light and shadow, a sky that lights the shade, haze, clouds, things floating in the air; a different mood per track | Asked for by Johannes on 21 Nov 2026: the first version looked flat |
| Controllers | Wireless Xbox pad for you, smaller pad for him | The keyboard doesn't reach the couch |
| 3D generation | Pixal3D in a local ComfyUI on the RTX 4070 (MIT, free, nothing uploaded); see docs/MODELS_3D.md | Changed 22 Nov 2026 on Johannes' request: Tripo's free plan does not allow downloads. Pixal3D (built on TRELLIS.2) runs in 12 GB with its 8-bit model |
| Models | Fable 5.2 for milestone 1, Opus 5.5 after, Sonnet for small tweaks | Spend the Max budget on the foundation |
| Repo | CLAUDE.md is the index, AGENTS.md points to it, GitHub, no Actions | One file to maintain, token-efficient |
| Family | Only the 4-year-old plays; the 1-year-old gets no screen time | Your call |
| Scope | 3 tracks (Kurvenkurs, Waldkurs, Riesenrunde with 2 laps); boost stars and turbo arrows | Johannes asked for longer tracks with more to do on 21 Nov 2026 (second round) |
| Goal | His delight first, a real race for dad close second; public release parked. Roadmap in `docs/ROADMAP.md` | Johannes, 22 Nov 2026, after the research in `docs/RESEARCH.md` |
| Playtests | No gate: development goes on, he plays whenever there is time | Johannes, 22 Nov 2026 |
| Items | Friendly only: boosts, shield bubble, silly hits that cost no real time; no blue shell | Johannes, 22 Nov 2026 |
| Players | Build for 2, never block 4 (HUD and camera code viewport-agnostic) | Johannes, 22 Nov 2026 |
| Assets | Free and local by default; CC0 or cheap recorded sound effects allowed, each purchase approved by Johannes | Johannes, 22 Nov 2026 |
| Screens | Both: 1080p projector (steady 60 fps in split screen) and 1440p 144 Hz monitor | Johannes, 22 Nov 2026 |

## Build decisions made in milestone 1 (by Claude; tell me if you want any changed)

| Area | Decision | Why |
| --- | --- | --- |
| Kid steering | In the middle of the road the stick steers for real, with a light helping hand (15 %, was 30 % until 22 Nov 2026: the autopilot felt too strong to him). Near the edge the helper takes over and steers back; it looks 0.6 s ahead so a kart pointed at the wall is caught early. The edge strip slows the kart | Changed 21 Nov 2026 at Johannes' request: lane steering drove the whole track by itself, so the kid felt nothing and won by doing nothing. Tests: hands off = 3rd to 5th, holding gas = 3rd, steering well with gas = 1st; no wall hits, no resets |
| Kid speed | Changed 22 Nov 2026 after his first try (too slow): cruises at 90 % of top speed; gas (A or RT, W or arrow up) gives 100 %. Eases off before tight corners by itself | A button that does something he can feel |
| Kid side | Panels never move by themselves. Both on the keyboard: grown-up (Profi, W A S D) left, kid (Kind, arrow keys) right. One big swap button (or Tab / a pad's View button) switches sides; the race keeps the panel order | Owner's playtest 23 Nov 2026: the old auto-swap (kid always left, 21 Nov) moved panels while clicking |
| Seat choice | Empty panels are "Linke Seite" / "Rechte Seite": left or right on a device takes that seat, the join button the first free one | Johannes: it was unclear who presses what first (21 Nov 2026) |
| Kart feel | Added grip to the Kenney ball physics: the motion follows the kart's nose | The kit's free-rolling ball slid wide in every corner of a walled track |
| Full mode buttons | RT or A gas, LT or B brake, RB drift (mini boost after 1 s), X or LB use, Y horn | Close to Mario Kart on an Xbox pad |
| AI with a kid in the race | Each AI kart holds a spot near the slowest human (+12 m, +4 m, -14 m); it waits when far ahead but never drives faster than normal to hold its spot | Changed 21 Nov 2026: a kid who drives well can win, one who does nothing comes 3rd or 4th, never far behind |
| AI without a kid | Fixed skill (86 to 95 % of top speed). A leading AI eases off from 8 m ahead (down to 80 % at 48 m); anyone behind the leading AI gets up to 12 % extra top speed | Changed 21 Nov 2026: Johannes could not win as Profi on Fast |
| AI personalities | Each driver `.tres` has an "AI personality" (lane: any / middle / inside / outside; weave, horn, show-off, friendly and brave from 0 to 1; police has a siren). A computer toy weaves harmlessly on clear straights, honks, shows off with a hop and spin of its picture, moves over for a kid close behind, gives a happy honk and a jump when a kid passes it, and cheers when it finishes behind a kid. Brave toys take side lanes more often. Style only: the pacing above still sets the speed, and nothing touches human karts or the kid assist | Added 23 Nov 2026 (research #28): toys should feel alive; personality matters more than skill for a 4-year-old |
| Speeds | Kid 0.92 (was 0.78 until 22 Nov 2026: too slow for him), Normal 1.05, Fast 1.5 of 12.5 m/s | Changed 21 Nov 2026: Fast felt slow |
| Tracks | Kurvenkurs: road, kerbs, barriers and walls generated along a smooth line through 17 points (286 m, tightest radius 9 m). Waldkurs: Kenney tiles from a list of moves (40 tiles, 284 m) | Road and racing line come from the same data and can never disagree; the Kenney tiles only have tight 90 degree corners |
| Track moods | Kurvenkurs: sunny day, clouds with moving shadows, petals. Waldkurs: warm evening, long shadows, light shafts, autumn leaves | Different lighting per track; both kept bright enough for a small child to read |
| Track choice | A "Strecke" row on the options page; each button shows the track's shape | Pick a track without reading |
| Vehicles | Only vehicles a toy can sit in: 5 open go-karts, a racing car and an oldtimer (AI drivers use only these), plus the motorcycle last in the list. The kit's pickup, truck, bus and jeep are gone (their models stay in `assets/`) | Replaces "the kit's trucks stay selectable": only seatable karts, owner's request 23 Nov 2026 (toys floated on the truck roofs) |
| Driver seat | In the karts the driver sits inside, enlarged 1.4 times (toy cards about 1 m), like the big-headed figures the karts shipped with | The toy must be visible from the chase camera |
| Paper cards | Unshaded with a white sticker outline | Recognisable from every angle |
| Toy vehicles | Motorrad, Polizei and Flieger replace the kart (front photo ahead, back photo toward the camera); the plane flies 35 cm above the road. The vehicle row shows "fährt selbst" and is skipped; speed and sound come from the vehicle picked before | Asked for by Johannes, 21 Nov 2026 |
| Hills and jumps | Round tracks get hills (at most ~10 % slope) and one jump on the home straight with a long downhill landing; an arcade hill assist cancels 80 % of slope gravity. At the ramp's lip (found on the racing line) every kart is thrown up (6 m/s, floatier gravity in the air): about 1.3 s in the air at Kid speed, ~1.5 m above the lip, a barrel roll of the kart picture (never the physics ball) and a landing boost for everyone. In the air the flight bends gently along the road ahead, so a jump before a bend lands on the road | Roadmap phase B, 23 Nov 2026. Changed 23 Nov 2026 at Johannes' request (playtest: the ramps barely lifted the kart). Kid races stay at zero resets |
| Banking | Corners bank by themselves from the curvature, up to about 9° (outside high); none on the start straight and the jump | 23 Nov 2026 |
| Items | Stars give one of six friendly items (turbo, triple turbo, superstar, shield bubble, spring, tickle bubble). Every kart has its own star: a kart taking it pops it for 0.5 s, the others can still take it; the same kart again after 6 s. Pick-up radius 0.7 m (was 1.0 m: the front karts swept whole rows). Odds by place and gap (Mario Kart style): leader bubble/tickle/turbo, middle mostly turbo, last or 60 m behind the leader mostly triple turbo and superstar; a kid always gets good ones (triple turbo and superstar when behind); a grown-up ahead of a kid: small items. Turbo and triple turbo are kept until the use button (one turbo per press); in kid mode a boost item fires by itself on the next straight bit of road. A tickle only makes a kart spin with a honk and costs 10 % speed and one brick; it never targets a kid-mode player or a teammate | Roadmap phase C, 23 Nov 2026. Changed 23 Nov 2026 at Johannes' request (playtest: the front karts took all stars, 3rd and 4th got nothing) |
| Bricks | Rows of toy bricks on every track; each held brick +1 % top speed, max 10; AI bricks give no speed in a race with a kid; all humans' bricks go into one family jar | 23 Nov 2026 |
| Team race | A "Team" card: all humans one team against the AI (at least one AI kart); the team's place is its best human's | 23 Nov 2026 |
| Magic rope | When another human drives 1.2 to 10 m ahead of a kid-mode player (lets go beyond 13 m), less than 4.5 m to the side, both on the road, a glowing candy-striped rope ties the karts together (fades in 0.45 s, chime on connect) and the kid gets up to 12 % extra top speed, easing off right behind dad. No sideways force: the kid assist keeps steering. Humans only; AI karts get no slipstream | Roadmap phase F (#29), 23 Nov 2026: following dad is worth it, which teaches following |
| Gift button | Full mode: D-pad up or down on the pad, R (WASD keys) or M (arrow keys) sends the held item as a flying present to the kid-mode player; only when he holds no item (it flies back if his hands are full on arrival). His auto-use fires it. Dad's HUD shows a present with the button above the item slot while a gift is possible | Roadmap phase F (#29), 23 Nov 2026: D-pad up/down were free in full mode |
| Turbo arrows | Blue pads with yellow arrows on the road: drive over = turbo (+45 % for 1 s), no button | More to do on the track; steering onto them is a reason to steer. 23 Nov 2026: they never fired before (the pads looked for collision layer 1, the karts are on layer 8) |
| Boosts | Push the kart directly to top speed: turbo item + 35 %, superstar + 45 %, + 45 % 1 s (arrows, 23 Nov 2026), drift by spark colour (blue +18 % 0.5 s, orange +26 % 0.9 s, purple +34 % 1.4 s; kid gets blue and orange by steering hard), start boost +30 % 1 s; never stacking, fading out over 0.8 s (22 Nov 2026). Kid mode: with a bend just ahead a boost pushes only to normal top speed (23 Nov 2026, keeps kid races off the walls). Flame trail, speed streaks, wider camera | Johannes: boosts had almost no effect and could not be seen (21 Nov 2026) |
| Music and sound | Generated on this PC like the effects (`tools/make_music.py`, `tools/make_sfx.py`); buses Music (-7 dB), Effects, Engines (-4 dB); music on/off on the options page | No licences, no downloads; easy to regenerate |
| Toy pictures | Drawn by Codex into `art/toys/`, used instead of the photos when present | Cleaner cards; photos stay as fallback |
| Colours | A controller gets the next free colour the first time it joins; remembered per device | "His pad, his colour" without setup |
| Kart bumps | Karts push each other apart softly instead of colliding | No pile-ups, no spinning out |
| Sounds | All effects synthesised by `tools/make_sfx.py` | No licence questions, no downloads |
| Checks | `tools/check.ps1`: Godot 3 name scan, parse of every file, simulated pad test, 7 headless races | A broken build never reaches Play |
| Settings file | `user://settings.cfg` (colours, picks per device, last options, best times) | Survives updates of the exe |
| Cup | "Pokal" card on the mode page: Kurvenkurs, Wohnzimmer, Riesenrunde in a row, each one lap shorter (about 10 minutes). Stars by place (last 1, each place ahead one more), shown as little stars and a total; the same computer toys race the whole cup; after the last race every player gets a trophy (gold, silver, bronze, or one in their colour) | Roadmap phase F, 23 Nov 2026 |
| Free drive | Has things to do now: a glowing ring per player ahead on the road (wide and centred for a kid; boost and chime, a party every 5th), one brick jar for everybody (party at 25), and with a kid plus a grown-up "catch Papa": a star over dad's kart (not shown on dad's own half); the kid catches him by getting close, dad spins, the kid gets a boost | Roadmap phase F, 23 Nov 2026 |
| Presents | After every race and time trial the finish screen shows a wrapped present that pops open: the family's next sticker (10, fixed order: star, heart, lightning, flower, rainbow, ladybug, rocket, moon, paw, sun). Always a reward, never tied to winning. Collected stickers sit on every player's kart (back, sides, bonnet; the newest six); with all ten, the present holds a star | Research gameplay #16 (sticker book), 23 Nov 2026 |
| Physics rate | 120 physics steps per second (was 60), with physics interpolation: less input delay on the 144 Hz monitor, smoother contact at speed. Race times, jumps and the kid races are unchanged; costs about 10 % frame rate in split screen (still far above 60 fps) | Research #34, 23 Nov 2026 |
