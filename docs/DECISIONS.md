# Decisions

Claude builds from this file. Change a row only with Johannes' OK, and change it here first.

## Product decisions (from PLAN.md, 21 Nov 2026)

| Area | Decision | Why |
| --- | --- | --- |
| Name | Game: **Toy Racer**. Repo: `toy-kart`. Exe: `builds/ToyKart.exe` | Name decided 21 Nov 2026; repo and exe names kept from the kickoff prompt |
| Engine | Godot 4.7, standard build with GDScript, no C# | All project files are text; free; Kenney template exists |
| Base | Kenney Starter Kit Racing, MIT code and CC0 assets | Arcade kart physics and tile tracks ready |
| Platform | Windows PC first, played on the 1080p projector | Steam Deck and tablet later |
| Screen | Side-by-side split for 2 players; the left half is the kid's | Each of you looks at the half on your side of the couch |
| Modes | Free drive, race with 0 to 3 AI karts, time trial | Taking turns first, then racing |
| Kid mode | Auto-accelerate, smart steering, left and right only, catch-up, soft walls | The same assists as Mario Kart |
| Language | Icons plus short German labels | Readable for adults; the kid always plays with you |
| Drivers | Ready-made CC0 characters plus toy photo cut-outs; 3D toys in milestone 3 | Fast now, clear upgrade path |
| Toy photos | Front and back per toy in `photos/toys`; left and right for later 3D | Paper drivers now, Tripo multiview later |
| Karts | Open go-karts the drivers sit inside (Kenney Car Kit); the kit's trucks stay selectable | Asked for by Johannes on 21 Nov 2026: Mario Kart-style karts, not pickups with the toy on top |
| Look | Stronger light and shadow, a sky that lights the shade, haze, clouds, things floating in the air; a different mood per track | Asked for by Johannes on 21 Nov 2026: the first version looked flat |
| Controllers | Wireless Xbox pad for you, smaller pad for him | The keyboard doesn't reach the couch |
| 3D generation | Tripo or Meshy in the cloud | Local tools need 24 GB or exclude the EU |
| Models | Fable 5.2 for milestone 1, Opus 5.5 after, Sonnet for small tweaks | Spend the Max budget on the foundation |
| Repo | CLAUDE.md is the index, AGENTS.md points to it, GitHub, no Actions | One file to maintain, token-efficient |
| Family | Only the 4-year-old plays; the 1-year-old gets no screen time | Your call |
| Scope | 2 tracks (Kurvenkurs with round curves, Waldkurs from tiles), 3 laps, about 2 minutes per race; boost pickups only | Second track asked for by Johannes on 21 Nov 2026; everything else waits until he asks for a third race |

## Build decisions made in milestone 1 (by Claude; tell me if you want any changed)

| Area | Decision | Why |
| --- | --- | --- |
| Kid steering | The stick picks a **lane** on the road; the assist steers along it. Hands off = the kart keeps its lane round the whole track | Free steering plus a correction made the kart weave and bump walls in tests. Lane steering keeps "left goes left" and cannot leave the road |
| Kid speed in corners | Auto-accelerate eases off by itself before tight corners | No wall hits at any speed class |
| Kid side | With one Kind and one Profi player, the Kind player always gets the left half | Matches "the left half is his" without an extra menu step |
| Kart feel | Added grip to the Kenney ball physics: the motion follows the kart's nose | The kit's free-rolling ball slid wide in every corner of a walled track |
| Full mode buttons | RT or A gas, LT or B brake, RB drift (mini boost after 1 s), X or LB use, Y horn | Close to Mario Kart on an Xbox pad |
| AI with a kid in the race | Each AI kart holds a spot near the slowest human (+10 m, -6 m, -22 m) and the leader eases off on the home stretch | Close races; the kid is never left alone at the back or the front |
| AI without a kid | Fixed skill (86 to 95 % of top speed), mild rubber band | A real opponent for full mode |
| Speeds | Kid 0.7, Normal 1.0, Fast 1.3 of 12.5 m/s | Kid speed gives about 1:45 for 3 laps |
| Tracks | Kurvenkurs: road, kerbs, barriers and walls generated along a smooth line through 17 points (286 m, tightest radius 9 m). Waldkurs: Kenney tiles from a list of moves (40 tiles, 284 m) | Road and racing line come from the same data and can never disagree; the Kenney tiles only have tight 90 degree corners |
| Track moods | Kurvenkurs: sunny day, clouds with moving shadows, petals. Waldkurs: warm evening, long shadows, light shafts, autumn leaves | Different lighting per track; both kept bright enough for a small child to read |
| Track choice | A "Strecke" row on the options page; each button shows the track's shape | Pick a track without reading |
| Vehicles | 5 go-karts, a racing car and an oldtimer first; AI drivers use only these. The trucks and the motorcycle come last in the list | Players can still pick a truck |
| Driver seat | In the karts the driver sits inside, enlarged 1.4 times (toy cards about 1 m), like the big-headed figures the karts shipped with. On trucks they sit on top | The toy must be visible from the chase camera |
| Paper cards | Unshaded with a white sticker outline | Recognisable from every angle |
| Colours | A controller gets the next free colour the first time it joins; remembered per device | "His pad, his colour" without setup |
| Kart bumps | Karts push each other apart softly instead of colliding | No pile-ups, no spinning out |
| Sounds | All effects synthesised by `tools/make_sfx.py` | No licence questions, no downloads |
| Checks | `tools/check.ps1`: Godot 3 name scan, parse of every file, simulated pad test, 7 headless races | A broken build never reaches Play |
| Settings file | `user://settings.cfg` (colours, picks per device, last options, best times) | Survives updates of the exe |
