# Arcade kart driving feel: research notes (2026-11-22)

Target: Toy Racer (Godot 4.7, Kenney rolling-ball kart, dad + 4-year-old, 2P split screen, 1080p projector, Xbox pads).
Confidence markers: [S] = taken from a cited source, [K] = well-known/community knowledge that I could not verify with a fetched source this session.

---

## 1. Drift and mini-turbo (the core loop of every top kart racer)

### Mario Kart (numbers from Mario Wiki datamines)
- Charge is a hidden counter that starts at 0 when the drift begins. It charges faster when steering at least halfway *into* the turn: Wii/MK8 = 5 units/frame inside, 2 units/frame otherwise. MK8 autodrift: 2 / 0.8 units/frame. [S]
- MK8 (Wii U) thresholds: blue sparks appear at 135, mini-turbo at 270, super mini-turbo at 570. At 60 fps with a full inside steer: blue at ~0.45 s, MT at ~0.9 s, SMT at ~1.9 s. With neutral steer: MT ~2.25 s. [S, arithmetic mine]
- Mario Kart Wii: blue sparks 148, MT 270, orange sparks 448, SMT 570. MK7: MT 220, SMT 460, charge 2-6/frame interpolated by stick. [S]
- Note the "sparks appear before the boost is ready" trick: visual cue appears ~half way, so the player sees progress. [S]
- MK8DX boost durations (in-game statistics page): Mini-Turbo 21-40 frames (0.35-0.67 s), Super 72-110 frames (1.2-1.8 s), Ultra 123-180 frames (2.05-3.0 s), depending on the MT stat. Nintendo tutorial values: MT 0.621 s, SMT 1.674 s, UMT 2.633 s. Boost speed factor for MT 1.055-1.15 of top speed. Charge threshold for MT: 280 units (low stat) to 200 (high stat). [S]
- Mario Kart World: same 3 tiers (blue, orange, rainbow "ultra"), thresholds identical for all karts, autodrift removed; Charge Jump reuses the boost counter. [S]
- Drift requires >55% of top speed to start, is kept while >50% (MK8DX). [S]
- Smart Steering blocks the Ultra tier (MK8DX) / the top tier (World). [S]
- Super Mini-Turbo in Wii lasted 3x a Mini-Turbo. [S]
- Hop: pressing drift does a small visual hop (~0.2-0.3 s), the drift direction is locked by the stick at landing. [K]. SuperTuxKart (open source, same genre) uses graphical-jump-time 0.4 s with physical jump 0. [S]

### SuperTuxKart (open-source reference numbers, kart_characteristics.xml) [S]
- Skid: time-till-bonus 1.0 s and 3.0 s (two tiers), bonus-speed +4.5 / +6.5 m/s (on max 25 m/s, i.e. +18% / +26%), bonus-time 3.0 / 4.0 s, bonus-force 250 / 350, visual skid angle factor 1.25, visual-time 0.7 s, graphical jump 0.4 s.
- Steering: time-full-steer 0.17 s at low speed, 0.28 s above half speed; time-reset-steer 0.1 s. Turn radius grows with speed: 2.0 m at 0, 7.5 m at 10 m/s, 15 m at 25, 30 m at 45 (light kart); heavy karts 30% wider.
- Startup boost: press within 0.3 s / 0.5 s of "go" for +8 / +4 m/s.
- Slipstream: zone 8 m long, 4 m wide, collect 2.5 s min (up to 8 s), max speed +3 m/s, fades over 2 s.
- Nitro: +5 m/s max speed, 1 s per unit, fade 2.4 s. Zipper (boost pad): +4.5 m/s instant gain, max +15 m/s, 3.5 s, fade 1.0 s.
- Rescue (fell off): 1.2 s. Explosion: 1.5 s, then 7 s invulnerability.
- Classes: light 0.8 power / 0.95 top speed, medium 0.875 / 1.0, heavy 1.0 / 1.05. Easy difficulty: x0.7 power, x0.6 speed.
- Key lesson: boosts "fade out" over 1-2.4 s instead of cutting off. Abrupt cut-offs feel like braking.

### Crash Team Racing Nitro-Fueled [S]
- Hop on R1 to start the slide; tap the other shoulder button when the turbo gauge is nearly full (exhaust goes black, tyres glow) to boost. Up to 3 boosts per slide. Too late = backfire, no boost.
- Reserves: every boost adds hidden reserve time that keeps you at boost speed; chained slides stack. Lost on wall hits, getting hit, braking on ground. Kept when braking in air.
- Fire tiers (colour = state): none -> red (single boost, start, jump) -> orange (chained, reserves) -> yellow "Sacred Fire" (turbo pads) -> blue (super pads). Colour of exhaust flame communicates current speed tier at a glance.
- Hang-time turbo: hop off a ramp; longer airtime = bigger boost on landing.
- Start boost: rev to fill the gauge exactly at green.
- CTR is known for a "skill-heavy" drift that is too hard for small kids [K]; its value here is the *readable colour states* and *reserve stacking*, not the timing.

### Sonic Racing CrossWorlds / Transformed [S, partly K]
- Three boost levels from drifting and from air tricks; gadget can add a 4th. Drift handling was tuned by Sega's arcade team (Sega Rally / OutRun / Initial D DNA). No rubber banding; catch-up comes from items. Items that were "too stressful or let players win all the time" were removed.
- Transformed (Sumo): drift charges 3 levels (blue/yellow/red sparks), trick boosts in air via stick flicks, boost after transformations. [K]

---

## 2. Acceleration, top speed vs turning
- MK8DX: acceleration is relative (speed fraction rises by 0.55-1.6% of remaining per frame, i.e. exponential approach), capped per frame (0.035-0.13 units). Top speed only varies 7.525-8.0 units/frame between worst and best builds (~6%). So: karts differ a lot in *acceleration and handling*, very little in top speed. [S]
- Ground handling rate 0.0065-0.014 (2x range), drift tightness 0.0145-0.022. Drift turns ~1.6-2.2x tighter than normal steering. [S]
- Game Developer "Implementing racing games": steering angle should shrink with speed (illustrative 10 deg low speed -> 2 deg high speed); acceleration strong off the line, weaker near top speed; prefer "position on circle" grip (100% traction) over force-based steering, which always feels like sliding. [S]
- SuperTuxKart: turn radius grows ~linearly with speed (see above). [S]
- Lesson for Toy Racer: an exponential "approach top speed" curve (fast 0-60%, slow last 20%) is what makes karts feel punchy without being twitchy. Recovery after a bump depends on acceleration, so high acceleration = forgiving.

## 3. Steering response and input smoothing
- STK: 0.17 s from centre to full lock at low speed, 0.28 s at high speed; return to centre 0.1 s (faster return than build-up). [S]
- MK8DX: the fastest drift charge requires a fairly horizontal stick, i.e. the stick is read as analogue with a threshold. [S]
- General: return-to-centre faster than steer-in; speed-dependent steering ramp; stick deadzone ~0.15-0.2 for kids' sloppy thumbs. [K]

## 4. Rocket start [S]
- MK8DX / World: hold accelerate right after "2" appears. Too early = rev too long = backfire + stall for a few seconds. Holding after "1" = normal start, no penalty.
- Since MK DS, boost length depends on when you started revving: 0.5 to 3 s.
- STK: press within 0.3 s after go for +8 m/s, within 0.5 s for +4 m/s (forgiving, no stall).
- CTR: tap to fill gauge, perfect at green = red fire.
- Kid lesson: give a start boost for simply holding gas at any time in the last ~1 s, never a stall.

## 5. Tricks / jump boost [S]
- MK8/8DX: press R as you leave a ramp -> trick animation + jump boost on landing. Too late = smaller boost; too early = none. Same as MK7.
- MK World: multiple tricks per jump, trick while gliding (barrel roll), trick off other racers; Charge Jump (hold, release) gives height and a boost. Wall ride after a charge jump.
- CTR: hang-time turbo grows with air time.
- Single Joy-Con: *shaking* the controller on a ramp triggers the trick boost (motion-friendly). Good idea for kid: any button in air = trick.

## 6. Slipstream [S]
- In every MK since 64 except Super Circuit/DD. Stay directly behind an opponent "a few seconds"; wind lines around kart grow; then a mini-turbo-like boost; used to ram/pass.
- STK numbers: 8 m x 4 m zone, 2.5 s to collect, +3 m/s, fades 2 s.
- For a 2-player family game: slipstream is a natural catch-up for the kid behind dad, visible with wind lines.

## 7. Off-road [S]
- MK8DX: off-road max-speed fraction 0.7 (light), 0.5 (medium), 0.3 (heavy off-road) regardless of stats. Sand/ice 0.97-1.0 with more slip. Boosts (mushroom) cancel off-road slowdown [K].
- Lesson: off-road should slow but never stop. For kid: 0.8-0.85, and boost ignores it.

## 8. Walls [S/K]
- MK DS datamine: wall contact applies a speed multiplier; moving near-parallel to the wall minimises speed loss. So glancing hits keep speed, head-on hits lose a lot. [S]
- Burnout lets you grind walls with little speed penalty. [S]
- Standard arcade practice: remove the velocity component into the wall, keep (most of) the tangential component, small bounce-away impulse, rotate the kart nose slightly toward the wall tangent; never flip, never stop dead on glancing hits. [K]
- MK World wall ride: charge jump into a wall to ride it briefly. [S]

## 9. Kart-to-kart bumping and weight [S]
- MK8DX weight: mass interpolated by speed (standstill 6-40, top speed 10-80); while boosting a separate boost-mass 30-80 applies, i.e. a boosting kart is heavy and shoves others. [S]
- MK8 anti-gravity: bumping another racer gives *both* a small speed boost ("spin boost"); contact rewarded, not punished. [S]
- Rocket League GDC 2018 (Jared Cone): fixed 120 Hz physics tick for consistency; one simple box collider per car; Game Developer article notes precise collisions would make games feel random. [S]
- Lesson: in a dad+kid game, make bumps playful (both get a tiny boost, or the lighter/slower kart gets pushed forward not sideways). The kid should never lose to a bump.

## 10. Weight classes [S]
- MK8DX top speed range across builds ~6%; real differences in accel, handling, weight, MT. STK: light 0.8 power / 0.95 speed; heavy 1.0 / 1.05 with 30% wider turn radius.
- For a 4-year-old: classes are cosmetic flavour at most; never give him a slower kart.

## 11. Anti-gravity / gliders [S/K]
- MK8: anti-gravity sections turn bumps into boosts; glider sections have their own speed (air speed stat 7.645-8.5) and roll/turn handling; gliders appear automatically from blue ramps — no input needed (kid-friendly spectacle). [S/K]

## 12. Camera [S/K]
- "Math for Game Programmers: Juicing Your Cameras With Math" (Squirrel Eiserloh, GDC 2016, free on GDC YouTube): trauma value 0-1, shake = trauma^2 (or ^3) times max offset/angle, driven by Perlin noise (not random), trauma decays linearly; also smoothed motion and dynamic split screen. [S for trauma 0-1 + Perlin, K for squared]
- Criterion "Vehicle Feel Masterclass" (GDC 2018, Matthew Harris): 16 years of handling; emphasises camera movement and handling assists as the under-discussed half of vehicle feel. [S: session abstract]
- Spring camera: lags on acceleration, catches up at constant speed, overshoots on braking; damp position and velocity separately; camera should move less than the kart over bumps so the jolt reads. [S: forum sources]
- FOV with speed: subtle widening at high speed, more during boosts; SuperTuxKart uses a smaller FOV boost for nitro and larger for zipper pads, lerped per frame. Too much wide-angle at high speed distorts. [S]
- Feeling of speed (critpoints): close camera + objects of the player's size rushing past matter more than actual speed; far, sparse views feel slow; drift sparks / dust / speed lines show contact and motion. [S]
- Common numbers [K]: base FOV ~70-75 deg vertical, +5-10 deg on boost with ~0.15 s ease-in and ~0.5 s ease-out; camera 4-6 m behind, 1.5-2.5 m up, looking at a point ahead of the kart; yaw lag ~0.1-0.25 s; during drift the camera swings slightly to the outside so you see into the corner. Look-behind on a button (MK: X / R-stick press).
- Split screen 2P side-by-side (each view ~960x1080, tall): use vertical FOV carefully; a tall viewport shows more sky/ground, so lower the camera pitch or raise the look-at point. [K]

## 13. Juice [S/K]
- Spark colour ladder communicates drift level (MK: blue -> orange -> purple/rainbow; CTR: flame red -> orange -> yellow -> blue). [S]
- Motorstorm boost: camera pull-back, rising pitch that indicates gauge progress, screen shake that grows during boost. [S]
- Engine sound: pitch/volume follow speed; extra "whoosh" layer at speed. [S]
- Screen shake: small amount goes a long way; consider shaking the kart instead of the camera. [S]
- Rumble [K]: short strong pulse on boost release (~100-150 ms), low continuous rumble while drifting rising with tier, sharp pulse on wall hit, tiny tick on tier change. Godot: Input.start_joy_vibration(device, weak, strong, duration).
- Squash and stretch of the kart on landing, lean into turns, wheels lifted on one side during drift (indie fruit-kart devlog). [S]
- Visual suspension: lean and bounce the kart model based on acceleration (Game Developer). [S]
- Feedback on every success: sound + colour + particles + rumble together.

## 14. Kid assists (Nintendo) [S]
- Smart Steering (MK8DX 2017, MK World 2025): steers the kart back onto the road; antenna on the kart glows yellow and bends to show when it acts. Can turn sharper than normal steering, works in air. World version acts mainly near edges/walls. Drifting and charge jumps still work.
- Cost: blocks the top drift tier; corrections can ruin drifts, off-road shortcuts and rail rides.
- Auto-Accelerate: holds the gas; cannot brake or reverse well.
- Criticism: on by default in some menus (annoys veterans), hidden trade-offs not explained, seen as "cheating" by some. Praise: lets a father play with his physically impaired daughter; young kids can race with adults. Not an autopilot — kids still feel they drive.
- Lesson: the *visible antenna* is a nice design: the assist is honest and visible, kid sees "my helper". Keep a reward ladder for the kid that is reachable with the assist (e.g. allow tier 1 and 2), and reserve the top tier for dad.

## 15. Catch-up / pacing
- CrossWorlds: no rubber banding; catch-up through items. [S]
- MK: item distribution by position (Bullet Bill, mushrooms for last place); slipstream. [K]

---

## Sources
- Mario Wiki, Mini-Turbo: https://www.mariowiki.com/Mini-Turbo
- Mario Wiki, MK8DX in-game statistics: https://mariowiki.com/Mario_Kart_8_Deluxe_in-game_statistics
- Mario Wiki, Smart Steering: https://www.mariowiki.com/Smart_Steering
- Mario Wiki, Rocket Start: https://www.mariowiki.com/Rocket_Start
- Mario Wiki, Jump Boost: https://www.mariowiki.com/Jump_Boost
- Mario Wiki, Slipstream: https://mariowiki.com/Slipstream
- Kotaku, drifting in Mario Kart: https://kotaku.com/everything-you-didn-t-know-about-drifting-in-mario-kart-1819196173
- Kotaku, MK World Smart Steering / Auto-Accelerate: https://kotaku.com/mario-kart-world-smart-steering-auto-acceleration-work-1851784842
- Nintendo Life, MK8DX smart steering & daughter: https://www.nintendolife.com/news/2017/05/mario_kart_8_deluxes_smart_steering_means_father_can_play_with_his_physically_impaired_daughter
- Nintendo Life, MK8DX controls: https://www.nintendolife.com/guides/mario-kart-8-deluxe-controls-all-control-options-and-assists-explained
- Mic, Smart steering cheating?: https://www.mic.com/articles/176553/mario-kart-8-deluxe-smart-steering-is-it-cheating-or-a-genius-addition
- GamesAtlas, CTR NF advanced turbo guide: https://gamesatlas.com/crash-team-racing/features/advanced-turbo-and-boosting-guide-for-crash-team-racing-nitro-fueled
- Push Square CTR boost guide: https://www.pushsquare.com/news/2019/07/guide_ctr_nitro-fueled_-_how_to_boost
- Automaton, CrossWorlds Initial D controls: https://automaton-media.com/en/news/sonic-racing-crossworlds-controls-are-based-on-20-years-of-experience-making-initial-d-arcade-games-devs-say/
- GamesRadar, CrossWorlds items removed: https://www.gamesradar.com/games/sonic-the-hedgehog/veteran-sonic-producer-says-sonic-racing-crossworlds-team-completely-removed-items-from-the-game-if-they-were-too-stressful-or-let-players-win-all-the-time
- SuperTuxKart kart_characteristics.xml: https://raw.githubusercontent.com/supertuxkart/stk-code/master/data/kart_characteristics.xml
- Game Developer, Implementing racing games: https://gamedeveloper.com/design/implementing-racing-games-an-intro-to-different-approaches-and-their-game-design-trade-offs
- GDC Vault, Juicing Your Cameras With Math: https://gdcvault.com/play/1023146/Math-for-Game-Programmers-Juicing
- GDC Vault, Vehicle Feel Masterclass (Criterion): https://gdcvault.com/play/1025383/Vehicle-Feel-Masterclass-Balancing-Arcade
- GDC Vault, It IS Rocket Science (Rocket League): https://www.gdcvault.com/play/1024972/
- Game Developer, Rocket League physics video: https://gamedeveloper.com/design/video-the-rocket-science-behind-i-rocket-league-s-i-physics
- critpoints, Feeling of Speed: https://critpoints.net/2016/11/24/feeling-of-speed/
- TASVideos, Mario Kart DS (wall speed multiplier): https://tasvideos.org/GameResources/DS/MarioKartDS
- Siliconera, MK8 bump boost: https://www.siliconera.com/mario-kart-8-encourages-get-close-personal/
- Unreal, dynamic third person camera: https://www.unrealengine.com/tech-blog/six-ingredients-for-a-dynamic-third-person-camera
- SuperTuxKart forum, FOV/speed lines: https://forum.supertuxkart.net/thread-200.html
- Speed Freeks feature request (Motorstorm boost feel): https://speedfreeks40k.featureupvote.com/suggestions/556551/boosting-with-shift-should-feel-more-impactful-like-motorstorm
- PCGamesN, All-Star Fruit Racing drift feel: https://pcgamesn.com/all-star-fruit-racing/all-star-fruit-racing-unreal-engine-4

Gaps: no verified Diddy Kong Racing numbers, no primary source for gamepad rumble tuning, no exact MK slipstream timing, no official Nintendo statement on wall-bounce design. Items marked [K] are standard practice, not verified this session.
