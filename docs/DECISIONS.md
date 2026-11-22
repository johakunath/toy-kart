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

## Build decisions made in milestone 1 (by Claude; tell me if you want any changed)

| Area | Decision | Why |
| --- | --- | --- |
| Kid steering | In the middle of the road the stick steers for real, with a light helping hand (30 %). Near the edge the helper takes over and steers back; it looks 0.6 s ahead so a kart pointed at the wall is caught early. The edge strip slows the kart | Changed 21 Nov 2026 at Johannes' request: lane steering drove the whole track by itself, so the kid felt nothing and won by doing nothing. Tests: hands off = 3rd to 5th, holding gas = 3rd, steering well with gas = 1st; no wall hits, no resets |
| Kid speed | Cruises at 85 % of top speed; gas (A or RT, W or arrow up) gives 100 %. Eases off before tight corners by itself | A button that does something he can feel |
| Kid side | With one Kind and one Profi player, the Kind player always gets the left half. The player panels swap the moment this applies | Matches "the left half is his"; the swap shows it before the race (21 Nov 2026) |
| Seat choice | Empty panels are "Linke Seite" / "Rechte Seite": left or right on a device takes that seat, the join button the first free one | Johannes: it was unclear who presses what first (21 Nov 2026) |
| Kart feel | Added grip to the Kenney ball physics: the motion follows the kart's nose | The kit's free-rolling ball slid wide in every corner of a walled track |
| Full mode buttons | RT or A gas, LT or B brake, RB drift (mini boost after 1 s), X or LB use, Y horn | Close to Mario Kart on an Xbox pad |
| AI with a kid in the race | Each AI kart holds a spot near the slowest human (+12 m, +4 m, -14 m); it waits when far ahead but never drives faster than normal to hold its spot | Changed 21 Nov 2026: a kid who drives well can win, one who does nothing comes 3rd or 4th, never far behind |
| AI without a kid | Fixed skill (86 to 95 % of top speed). A leading AI eases off from 8 m ahead (down to 80 % at 48 m); anyone behind the leading AI gets up to 12 % extra top speed | Changed 21 Nov 2026: Johannes could not win as Profi on Fast |
| Speeds | Kid 0.78, Normal 1.05, Fast 1.5 of 12.5 m/s | Changed 21 Nov 2026: Fast felt slow |
| Tracks | Kurvenkurs: road, kerbs, barriers and walls generated along a smooth line through 17 points (286 m, tightest radius 9 m). Waldkurs: Kenney tiles from a list of moves (40 tiles, 284 m) | Road and racing line come from the same data and can never disagree; the Kenney tiles only have tight 90 degree corners |
| Track moods | Kurvenkurs: sunny day, clouds with moving shadows, petals. Waldkurs: warm evening, long shadows, light shafts, autumn leaves | Different lighting per track; both kept bright enough for a small child to read |
| Track choice | A "Strecke" row on the options page; each button shows the track's shape | Pick a track without reading |
| Vehicles | 5 go-karts, a racing car and an oldtimer first; AI drivers use only these. The trucks and the motorcycle come last in the list | Players can still pick a truck |
| Driver seat | In the karts the driver sits inside, enlarged 1.4 times (toy cards about 1 m), like the big-headed figures the karts shipped with. On trucks they sit on top | The toy must be visible from the chase camera |
| Paper cards | Unshaded with a white sticker outline | Recognisable from every angle |
| Toy vehicles | Motorrad, Polizei and Flieger replace the kart (front photo ahead, back photo toward the camera); the plane flies 35 cm above the road. The vehicle row shows "fährt selbst" and is skipped; speed and sound come from the vehicle picked before | Asked for by Johannes, 21 Nov 2026 |
| Turbo arrows | Blue pads with yellow arrows on the road: drive over = short turbo, no button | More to do on the track; steering onto them is a reason to steer |
| Boosts | Push the kart directly to top speed + 40 % (star, 1.6 s), + 30 % (arrows, 1 s), + 25 % (drift, 0.8 s), never stacking. Flame trail, speed streaks, wider camera | Johannes: boosts had almost no effect and could not be seen (21 Nov 2026) |
| Music and sound | Generated on this PC like the effects (`tools/make_music.py`, `tools/make_sfx.py`); buses Music (-7 dB), Effects, Engines (-4 dB); music on/off on the options page | No licences, no downloads; easy to regenerate |
| Toy pictures | Drawn by Codex into `art/toys/`, used instead of the photos when present | Cleaner cards; photos stay as fallback |
| Colours | A controller gets the next free colour the first time it joins; remembered per device | "His pad, his colour" without setup |
| Kart bumps | Karts push each other apart softly instead of colliding | No pile-ups, no spinning out |
| Sounds | All effects synthesised by `tools/make_sfx.py` | No licence questions, no downloads |
| Checks | `tools/check.ps1`: Godot 3 name scan, parse of every file, simulated pad test, 7 headless races | A broken build never reaches Play |
| Settings file | `user://settings.cfg` (colours, picks per device, last options, best times) | Survives updates of the exe |
