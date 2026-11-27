# Toy Kart Racer: Plan & Prototype

Nov 21, 2026 · @Johannes

## Decisions at a glance

Build it in Godot 4.7 on top of Kenney's free racing template, start with photo cut-outs of the real toys, and give the 4-year-old a two-button mode with auto-accelerate and smart steering.

| Topic | Decision | Main reason |
| --- | --- | --- |
| Engine | Godot 4.7 (free, open source) | Scenes, scripts and settings are plain text, so Claude builds whole scenes, not just scripts |
| Foundation | Kenney Starter Kit Racing (MIT code, CC0 assets) | Arcade kart controls and tile-based tracks already work in Godot |
| First drivers | Ready-made animated 3D characters or your own toys as photo cut-outs, picked per race | Toys are recognisable at once with zero modelling; 3D versions of the toys come in milestone 3 |
| Kid controls | 2 buttons (left, right), auto-accelerate, smart steering | The same assists Nintendo built into Mario Kart for beginners and kids |
| Controllers | Your wireless Xbox pad for you, one smaller pad for him, bought now | The keyboard doesn't reach the couch; his own pad gets his own colour |
| Screen | 2-player split screen, side by side: the left half is his | Each of you looks at the half on your side of the couch |
| Scope | 1 track; free drive, race with up to 3 AI karts, time trial; boost pickups | Everything else waits until he asks for a third race |
| Models | Fable for the foundation sprint, Opus 5.5 for features, Sonnet for tuning | Spend the Max budget where early mistakes cost the most |
| Delivery | Windows .exe from Godot's export | Sharing via itch.io later |

## Scope check

Your list holds about 15 features; the first prototype needs 7. The test for every feature: does it help answer "does my son want to play a third race?"

| In the prototype | Later, after the fun test |
| --- | --- |
| 1 track, 3 laps, about 2 minutes per race | More tracks: living-room miniature, fantasy and comic worlds |
| 1 or 2 players side by side, up to 3 AI karts, plus free drive for taking turns | 3 to 4 players, up to 4 AI karts |
| Race and time trial | Battle mode, cups |
| Boost pickups you drive through | Weapons and aimed items |
| Driver and kart picked separately: ready-made characters, toy cut-outs, template karts | Levelling up, outfits, unlocks |
| Kid mode and full mode | Loopings and wall rides (they need different physics) |
| Windows .exe | Installer, itch.io page, sharing |

**Optional step 0: SuperTuxKart.** Skip it if you like; free drive in milestone 1 does the same job with kid assists. SuperTuxKart is a free, open-source kart racer with local split screen for [up to 8 players](https://www.omgubuntu.co.uk/2018/08/supertuxkart-devs-detail-several-upcoming-improvements) and a [Beginner difficulty](<https://www.linux-magazine.com/Issues/2022/261/SuperTuxKart/(offset)/3>). If you try it, play 2 or 3 races and watch three things:

1. Can he steer at all, and with which buttons?
2. Does he look at his own half of the screen?
3. Does he ask for another race?

I found no auto-accelerate option in SuperTuxKart, so he has to hold a button while steering. If that fails, it confirms the kid mode below. SuperTuxKart also accepts [custom karts made in Blender](https://github.com/supertuxkart/stk-blender), but since you want to learn building games, it stays a 30-minute test, not the foundation.

## Engine: Godot, not Unity

Your hunch that Unity is easier for AI is half right. Language models have seen more C# than GDScript, and Unity has more tutorials. For a non-programmer working through Claude, two other facts weigh more:

- **Godot is all text.** Scenes (.tscn), scripts (.gd), resources (.tres) and the project config are [human-readable files](https://dev.to/ziva/vibe-coding-works-for-web-apps-it-breaks-on-game-engines-heres-why-446g). Claude can create and wire up a whole scene, so you rarely have to click around the editor.
- **Unity leans on the editor.** Unity 6 [stores scenes as text by default](https://ziva.sh/blogs/unity-vs-godot-2026-ai), but much of the wiring happens by dragging references in the Inspector. The [official Unity MCP server](https://unity.com/blog/unity-ai-mcp-how-to-get-started), which lets Claude drive the editor, needs a Unity AI trial or subscription. Free community MCP servers exist.

|  | Godot 4.7 | Unity 6 | Unreal 5 |
| --- | --- | --- | --- |
| Cost for you | Free, MIT licence, no account | [Free under $200K revenue](https://unity.com/products/pricing-updates), splash screen optional | Free for hobby use |
| What Claude can edit directly | Scripts, scenes, resources | Scripts; scenes as YAML; editor work via MCP | C++; Blueprints are binary graphs |
| Editor bridge for Claude | [Free community MCP servers](https://mcpservers.org/servers/Coding-Solo/godot-mcp) | Official MCP needs Unity AI subscription | Limited |
| Kart starting point | [Kenney Starter Kit Racing](https://store.godotengine.org/asset/kenney/starter-kit-racing/), free | Asset Store templates | Marketplace templates |
| Graphics | Strong for stylised looks; [HDR output in 4.7](https://godotengine.org/releases/4.7/) | Higher ceiling, more post-processing | Highest, built for realism |
| Weight | Small download, opens in seconds | Medium | Very large install |

**Risk with Godot:** GDScript has [less training data](https://vegcale.com/2026/03/20/what-is-godot-claude-code/), and models sometimes mix Godot 3 and Godot 4 syntax. Mitigation: the project's CLAUDE.md pins "Godot 4.7, GDScript 2.0", and Claude runs a headless check of every change before you press Play.

**Physics bonus:** since 4.6, [Jolt is the default 3D physics engine](https://digitalproduction.com/2026/01/28/godot-4-6-arrives-with-major-cg-friendly-updates/), a more stable base for fast karts than the old default.

**Detail has room to grow.** Godot 4.7's Forward+ renderer handles PBR materials, real-time global illumination, volumetric fog, reflections and automatic level of detail for meshes. That is enough for a detailed Mario Kart-style look on an RTX 4070, also in split screen. The bottleneck is producing detailed models; the engine shows them fine. Models go in as standard glTF files, so everything you make stays usable in Unity or Unreal if you ever switch. Unreal-level photorealism is out of reach, and your target is the Mario Kart look anyway.

## Controllers and input

You keep your wireless Xbox pad, he gets his own smaller pad now, and his mode needs only left and right. The control mode is set per player, so you can race in full mode while he plays in kid mode.

| Mode | Who | Controls | Assists |
| --- | --- | --- | --- |
| Kid | Your son now | Stick, D-pad or shoulder buttons: left steers left, right steers right; any face button honks | Auto-accelerate, smart steering, pickups fire on their own, can't fall off |
| Learner | When kid mode gets boring | Stick or D-pad to steer, 1 button for pickups | Auto-accelerate, lighter smart steering |
| Full | You, later the kids | Accelerate, brake, drift, pickups | None |

These are the assists Nintendo ships in Mario Kart: [Smart Steering keeps the kart on the course and Auto-Accelerate removes holding the gas button](https://nintendosoup.com/?p=273231). One father described how Smart Steering [opened up the game for his four-year-old](https://www.cinemablend.com/games/1653260/little-girls-gets-to-play-mario-kart-for-the-first-time-thanks-to-new-feature) so she could race with the family.

| Option | Buy? | Notes |
| --- | --- | --- |
| Your wireless Xbox controller | Have it | Yours |
| Smaller pad for him | Yes, now | Wireless: [8BitDo Ultimate 2C Wireless](https://siemens-mobile.com/best-kid-sized-gaming-controllers-for-small-hands/), 2.4 GHz dongle or USB-C, said to have a narrower grip, made for Windows. Wired: [8BitDo Ultimate Mini](https://www.target.com/p/product/-/A-1001587158) (20% smaller than the Ultimate C) or [HyperX Clutch Tanto Mini](https://www.hp.com/us-en/shop/pdp/hyperx-clutch-tanto-mini-wd-gaming-controller) (about 3 m cable) |
| Keyboard | No | Fine for tests at the desk; doesn't reach the couch |
| DIY big-button box | Optional | 2 large arcade buttons in a shoebox, wired to a [zero-delay USB encoder](https://www.newegg.com/p/2Z6-0541-000H7) that Windows reads as a gamepad without drivers. A craft weekend together |
| Tilt steering (wheel) | Later | Needs a pad with motion sensors; [Xbox controllers have none](https://docs.godotengine.org/en/4.7/tutorials/inputs/controller_features.html). Godot 4.7 reads gyroscopes from PlayStation and Nintendo pads |
| Touch on a tablet | Later | See backlog |

I can't judge which pad fits his hands best: buy where returns are easy. A wired pad needs the cable to reach the couch; a USB extension cable helps. If tilt steering matters later, check the product page for motion sensors, or plan a separate PlayStation or Nintendo pad for it. Each controller gets a colour, and his kart, name tag and screen frame use the same colour.

## Kid-friendly game design

The rule for kid mode: he never loses control, never gets stuck and never has to wait.

- **No falling off:** soft walls, gentle bounces, and an automatic reset onto the track after 2 seconds off course.
- **Close races:** if he falls behind you, his kart gets a quiet speed boost; the AI karts drive slower in kid mode.
- **Pickups without aiming:** drive through a star to get a boost, with a sound and a sparkle every time.
- **A horn button:** does nothing except honk. Instant feedback for a button press is worth testing with a 4-year-old.
- **No reading needed:** icons, colours and sounds instead of text. The finish screen celebrates everyone; the placing is shown small.
- **Calm camera:** high, stable and wide, with no camera shake in his view.
- **Three speeds:** Kid, Normal, Fast. Kid speed works like Mario Kart's slowest class.
- **Split screen:** side by side. He sits left and gets the left half, framed in the colour of his controller.

**Free drive for taking turns.** One player, full screen, no timer and no opponents. You drive a lap, hand him the pad, he tries; then you race.

**Can a 4-year-old steer this?** There is no fixed age. Nintendo Life recommends Mario Kart 8 Deluxe from [about 3 to 4](https://nintendolife.com/guides/best-nintendo-switch-games-for-kids), and parent guides call [ages 4 to 6 the training-wheels stage with Smart Steering and Auto-Accelerate](https://screenwiseapp.com/guides/is-mario-kart-8-deluxe-safe-for-young-kids). The hard part at 4 is doing two things at once, gas and steering, and kid mode removes the gas. Kid mode accepts both stick and buttons, so free drive shows within minutes which suits him.

**Built to end, not to hook.** The American Academy of Pediatrics suggests [about one hour a day of quality media for ages 2 to 5, ideally used together with a parent](https://pulse.seattlechildrens.org/?p=10334). The game fits that:

- A "race day" is a cup of 3 races, about 10 minutes, then a clear end screen.
- No daily rewards, streaks, loot boxes or timers that pull him back.
- Unlocks (outfits, karts) come later, a few per session, earned by playing together.
- The building part stays real-world: he picks which toy gets photographed next, and later he colours a track or places obstacles in a simple editor.

## From toys to game characters

The driver menu offers both from day 1: ready-made animated 3D characters from a free CC0 pack, and your toys as photo cut-outs. Once the game is fun, the 2 or 3 favourite toys become real 3D models.

1. **Prototype: paper drivers.** Two photos per toy, front and back, in good light on a plain background. Claude removes the background, and the two photos go on the two sides of a flat card that stands in the kart seat like a cardboard figure. It wobbles and leans into curves; from the side you can see it's flat. Your son sees his own toy, not a lookalike. Mario Kart 64 drew its drivers as flat pre-rendered images too.
2. **Milestone 3: 3D drivers.** Four photos (front, left, back, right) go into Tripo's multiview mode, which builds one model from 2 to 4 views; or one stylised image made in ChatGPT goes into single-image mode. Codex can't build 3D models itself. Then Blender cleanup, then Godot as a glTF file. No rigging needed: drivers sit in karts, so the game animates them in code (bounce, lean, squash on landing).
3. **Karts:** photograph the toy cars and Duplo cars the same way, or start from Kenney's kart models and recolour them.

| Tool | Free tier | Verdict |
| --- | --- | --- |
| [Tripo](https://www.tripo3d.ai/help/billing/which-tripo-ai-plan-is-right-for-me) | 200 credits a month, up to 13 models; free models are [public under CC BY 4.0, non-commercial](https://costbench.com/software/ai-3d-generation/tripo-ai/free-plan/) | First try |
| [Meshy](https://www.tripo3d.ai/blog/free-ai-3d-model-generators-for-beginners) | 100 credits a month, CC BY 4.0 | Backup |
| [TRELLIS.2](https://huggingface.co/microsoft/TRELLIS.2-4B/blob/main/README.md) (Microsoft) | Free, MIT licence, runs locally | Not for you: needs 24 GB, your RTX 4070 has 12 GB; also [tested on Linux only](https://huggingface.co/henrybit/TRELLIS.2-4B) |
| [Hunyuan3D](https://huggingface.co/tencent/Hunyuan3D-2/blob/main/LICENSE) (Tencent) | Free model weights | Skip: the licence excludes the EU, so it does not cover you in Berlin |
| Blender | Free | Cleanup: reduce polygons, fix scale and pivot. Claude can script most of it |

Free Tripo and Meshy models are public, so upload photos of toys only, never of the kids.

**World and placeholders.** Kenney's [Toy Car Kit](https://kenney.nl/assets/toy-car-kit) (100 files of toy cars and track pieces) and [Car Kit](https://kenney.nl/assets/car-kit) (kart racers added in January 2026) are CC0, free for any use. Both are low-poly. If that look feels flat to you, milestone 3 adds an art pass: soft toon shading, outlines, rounded shapes, a bright palette. For the living-room track, photos of your rug, floor and sofa fabric become textures under giant furniture.

**Before sharing publicly:** your own toys are fine at home, but Lego, Duplo and licensed plush characters are other companies' brands. Swap them for your own designs before a public release.

## Technical architecture

Controllers never talk to karts directly: every input becomes an intent, passes a per-player assist layer, and only then moves the kart. That one rule makes kid mode, AI drivers and new controllers cheap to add later.

&#91;embedded content: game architecture · input to kart, racing line feeds assists, AI and laps\]

The racing line does triple duty: it pulls kid-mode karts back to the track, steers the AI, and counts laps and places.

| Area | Decision | Why |
| --- | --- | --- |
| Kart physics | Sphere-based arcade controller from the Kenney kit: a rolling ball does the physics, the visible kart follows it | Feels like [arcade kart racing without a full suspension model](https://doc.photonengine.com/fusion-godot/v3-shared-authority/game-samples/racing-starter-kit) |
| Loopings | Not in the prototype. They need a different controller with gravity along the track surface | The kart controller sits behind one interface, so it can be swapped |
| Input | Device to intents (steer, accelerate, use pickup, horn), then assists, then kart | Keyboard, pads, the button box and tilt all plug into the same slot |
| Track | Kenney tile track plus one racing line along its centre | The line drives smart steering, AI, lap counting and reset after leaving the track |
| AI karts | Follow the racing line with an offset and a speed profile | Simple to tune; slower in kid mode |
| Split screen | One 3D world, one camera and one HUD per player | Scales to 4 players without rework |
| Content | Each driver and kart is a small resource file with stats, image or model, and colour | Separate selection from day 1; adding a toy means adding one file |
| Checks | Claude runs Godot headless to parse scripts and run the race scene before handing over | You only press Play on builds that start |
| Export | Windows export preset stored in the project | One click to a .exe |

## How we build it, with no terminal for you

Claude Code runs on your gaming PC and does all installs, code and git; you keep the Godot editor open and press F5 to play.

- **Setup (Claude does it):** Godot 4.7, Git, Node.js and the [Godot MCP server](https://mcpservers.org/servers/Coding-Solo/godot-mcp), which lets Claude launch the game, read its errors and inspect scenes. Project folder on your PC, private GitHub repo for history.
- **Your part:** open the project in Godot once, press F5 after each change, play, and tell Claude by voice what felt wrong.
- **Rhythm:** one milestone per session, PLAN.md as the single source of truth, HANDOVER.md at the end of each session.
- **Playtest loop:** you race with your son, note what made him laugh or give up, and that becomes the next tuning list.

| Work | Model | Why |
| --- | --- | --- |
| Milestone 1: setup, kart feel, input and assists, modes, AI, split screen | Fable 5.2 | Architecture mistakes here are the most expensive later |
| Milestones 2 and 3: your toys, sound, art pass, 3D toys | Opus 5.5, high effort | Multi-system features |
| Tuning, new toys, small fixes | Opus 5.5 low or medium, or Sonnet 5.5 | Cheap iterations once the structure stands |
| Drawn toy pictures for the cards | Codex (image generation), brief in `docs/ART_BRIEF.md`, prompt in `docs/CODEX_TOY_ART.md` | Claude does not generate images |
| 3D models: blocky toys (Duplo) | Claude in Blender (scripted, from the photos) | Bricks are simple shapes; no outside tool needed |
| 3D models: plush and the book character | Pixal3D in local ComfyUI, from front/left/back/right views | Organic shapes need an image-to-3D tool; Tripo's free plan has no downloads |

Front-load the Fable sprint while you are on Max, and check your remaining usage before each long session. Once you are back on Pro, the foundation is done and new toys or tracks are small, cheap changes.

## Milestones

Each milestone ends with a gate. If a gate fails, we fix that before building anything new.

**Changed 21 Nov 2026:** your son is not ready for the game yet. Until he is, the gates are
**your own test drives**; the couch test with him moves to the point where you say he is ready.
The second controller is bought then, not now. Until then, two players means pad + keyboard or
two keyboard halves.

| # | Milestone | Content | Gate | Status |
| --- | --- | --- | --- | --- |
| 1 | Foundation | Kart feel, input and assists, modes, AI, split screen, Windows export | Your test drive: it drives well, kid mode is neither automatic nor frustrating | **Passed** 21 Nov 2026 (your test drive). Kid couch test postponed |
| 2 | Your toys and polish | Toys in the game (done), toy vehicles (done), more tracks and turbo arrows (done), sound and music (done), drawn toy pictures (all but the Duplo girl), driver portraits (done), graphics presets, scenery | You enjoy a race on the projector with sound on, and the toys look like *his* toys | **In progress** |
| 3 | 3D toys and art pass | Toys as 3D models (Duplo toys built in Blender by Claude; plush and the book character via Pixal3D, run locally), toon look, a themed track (living room) | The 3D toys are recognisable and feel alive | **Started**: Koba is in the game as a 3D model ([MODELS_3D.md](MODELS_3D.md)) |
| 4 | More game | Battle mode, cups of three races, aimed items | You want to play it yourself | Not started |
| 5 | His turn | Second controller, the 5-minute couch test with him, tuning from what he does | He asks for a third race | When you say he is ready |

There are no dates: I expect one or two sessions per milestone, and the gate decides when to move on.
Since 22 Nov 2026 the order of work inside the milestones is [ROADMAP.md](ROADMAP.md).

## Open decisions for you

Two small choices are still open; neither blocks milestone 1.

- [x] Engine: Godot 4.7.
- [x] Hardware: Intel i7, RTX 4070 with 12 GB, 32 GB RAM, 1440p 144 Hz monitor, 1080p projector.
- [x] Younger child (1 year): no screen time.
- [x] Split-screen layout: side by side.
- [x] Words in the game: icons plus short German labels, readable for adults and the kid.
- [x] Controllers: one smaller pad for him, bought now.
- [ ] Which pad: wireless 8BitDo Ultimate 2C or a wired mini. Decide at milestone 5.
- [ ] First cast: which 3 to 4 toys get photographed, front and back. Needed for milestone 2.

## Decision log

Decided on 21 Nov 2026. When a decision changes, change its row here, so Claude Code always builds from the current one.

| Area | Decision | Why |
| --- | --- | --- |
| Engine | Godot 4.7, standard build with GDScript | All project files are text; free; Kenney template exists |
| Base | Kenney Starter Kit Racing, MIT code and CC0 assets | Arcade kart physics and tile tracks ready |
| Platform | Windows PC first, played on the 1080p projector | Steam Deck and tablet later |
| Screen | Side-by-side split for 2 players | Each of you looks at the half on your side of the couch |
| Modes | Free drive, race with 0 to 3 AI karts, time trial | Taking turns first, then racing |
| Kid mode | Auto-accelerate, smart steering, left and right only, catch-up, soft walls | The same assists as Mario Kart |
| Language | Icons plus short German labels | Readable for adults; the kid always plays with you |
| Drivers | Ready-made CC0 characters plus toy photo cut-outs; 3D toys in milestone 3 | Fast now, clear upgrade path |
| Toy photos | Front and back per toy in photos/toys; left and right for later 3D | Paper drivers now, Pixal3D multiview (front, left, back, right) for 3D |
| Karts | Template karts for the prototype | Your toy cars come later |
| Controllers | Wireless Xbox pad for you, smaller pad for him | The keyboard doesn't reach the couch |
| 3D generation | Pixal3D in a local ComfyUI on the RTX 4070 (MIT, free, nothing uploaded); see docs/MODELS_3D.md | Changed 22 Nov 2026 on Johannes' request: Tripo's free plan does not allow downloads. Pixal3D (built on TRELLIS.2) runs in 12 GB with its 8-bit model |
| Models | Fable 5.2 for milestone 1, Opus 5.5 after, Sonnet for small tweaks | Spend the Max budget on the foundation |
| Repo | CLAUDE.md is the index, AGENTS.md points to it, GitHub | One file to maintain, token-efficient |
| Family | Only the 4-year-old plays; the 1-year-old gets no screen time | Your call |

## Your setup and shopping list

No purchase now: the smaller pad for him waits until he is ready (milestone 5).

| Item | Status | Note |
| --- | --- | --- |
| Gaming PC: Intel i7, RTX 4070 with 12 GB, 32 GB RAM | Have | Runs Claude Code, Godot and the game |
| Monitor, 1440p at 144 Hz | Have | Building and testing |
| Projector, 1080p via HDMI | Have | Target: 60 fps at 1080p in split screen |
| Wireless Xbox controller | Have | Yours |
| Smaller pad for him | Later (milestone 5) | See Controllers and input |
| USB extension cable | Only with a wired pad | If the cable doesn't reach the couch |
| Claude Code on the gaming PC | Install if missing | Claude then installs Godot, Git, Node.js and the Godot MCP server itself |
| GitHub account | Have | Claude creates the private repo |
| ComfyUI + Pixal3D (local, installed) | Milestone 3 | Multiview 3D models from toy views; no account |
| ChatGPT Plus | Have | Stylised reference images |
| Blender | Milestone 3, optional | Claude installs and scripts it |

## Backlog

Everything here waits until milestone 2 is fun; pick by what the kids ask for.

| Area | Item | When |
| --- | --- | --- |
| Gameplay | Aimed items and weapons | After kid mode works |
| Gameplay | Battle mode, cups of 3 races | Milestone 4 |
| Gameplay | More tracks: living-room miniature, fantasy and comic worlds | Milestone 3 onward |
| Gameplay | Loopings and wall rides (a new kart controller with gravity along the track) | Later |
| Gameplay | 3 to 4 players | When needed |
| Gameplay | Unlocks, outfits, levelling; a few per session, no streaks | Later |
| Vehicles | More vehicle types, for example a space shuttle | Later |
| Kids | Simple track editor or track colouring for him | Later |
| Input | Learner mode: stick steering plus a pickup button | When kid mode gets boring |
| Input | Tilt steering with a motion-sensor pad | Later |
| Input | DIY big-button box | Optional |
| Platforms | Steam Deck via Godot's Linux export | After milestone 2 |
| Platforms | Android tablet: touch zones left and right; split screen with one player per side | Later |
| Platforms | itch.io page, installer | Before sharing |
| Art | Art pass: toon shading, outlines, bright palette | Milestone 3 |
| Art | More 3D toys via Pixal3D: Bobo, then the plane, then the police car (Codex turnaround views first); living-room photo textures | Milestone 3 |
| Art | Blender basics for you: move, scale and recolour a model | Optional backup |
| Tech | Graphics presets for projector and 1440p 144 Hz | Milestone 2 |
| Tech | Save file for unlocks | With unlocks |
| Tech | Git LFS once model and texture files grow | When the repo grows |
| Legal | Replace branded toys (Lego, licensed plush) before a public release | Before sharing |

## Handover to Claude Code

Five steps on your PC, then Claude Code builds milestone 1 and stops with a couch test script for you.

1. Create an empty folder, for example Documents\\ToyKart.
2. Save this doc as Markdown into that folder as PLAN.md.
3. Put toy photos into a subfolder photos\\toys: front and back of each toy, plain background, even light, the toy filling most of the frame. One file per side, named like bear-front.jpg and bear-back.jpg. Add left and right shots for toys you may want in 3D later.
4. Open Claude Code on the PC in that folder and pick Fable 5.2.
5. Paste the prompt below.

**Repo conventions:**

- CLAUDE.md is the one index file, under 100 lines: goal, stack, folder map, how to run checks, rules, links to the docs.
- AGENTS.md holds one line that points to CLAUDE.md.
- docs/PLAN.md (this doc), docs/DECISIONS.md, docs/BACKLOG.md, and docs/HANDOVER.md, updated at the end of every session.
- No GitHub Actions: all checks run locally.
- Asset folders are never read into context.

**Kickoff prompt:**

```text
Project: Toy Kart, a Mario Kart-style racing game for me and my 4-year-old son. Windows PC, Godot 4.7 standard build, GDScript 2.0, no C#.

I am not a programmer. Never ask me to use a terminal. Do all installs, git, config and builds yourself. Give me steps only in the Godot editor or on websites.

Read PLAN.md in this folder first and move it to docs/PLAN.md. Build milestone 1 only.

1. Setup
- Install if missing: Git, Godot 4.7.x stable (standard) with Windows export templates, Node.js.
- Create a private GitHub repo named toy-kart and commit after each working step. No GitHub Actions; run all checks locally.
- Add the Godot MCP server (Coding-Solo/godot-mcp) so you can run the game and read its errors.
- Docs, token-efficient: CLAUDE.md is the single index, under 100 lines (goal, stack, folder map, check commands, rules, links). AGENTS.md is one line pointing to CLAUDE.md. Create docs/DECISIONS.md and docs/BACKLOG.md from PLAN.md, and docs/HANDOVER.md. Never read asset files into context.
- Rules for CLAUDE.md: Godot 4.7 APIs only, no Godot 3 names. Every change passes a headless script parse and a headless run of the race scene before you hand over.

2. Base
- Start from Kenney Starter Kit Racing (github.com/KenneyNL/Starter-Kit-Racing, MIT code, CC0 assets). Keep its licence files. Use its karts and track tiles as placeholders.
- Add one free CC0 pack of animated 3D characters (Kenney or Quaternius) as ready-made drivers. Verify the licence before importing.

3. Milestone 1 features
- Input: device to intents (steer, accelerate, brake, use, horn) to a per-player assist layer to the kart. Keyboard plus any XInput pad. Each controller gets a colour.
- Player modes. Kid: stick, D-pad or LB/RB steer left and right, any face button honks, auto-accelerate, smart steering toward the racing line, soft walls, reset onto the track after 2 s off course, catch-up boost when behind the other human, pickups fire by themselves. Full: accelerate, brake, drift, use.
- Track: one track from Kenney tiles, 3 laps, with a Path3D racing line used for smart steering, AI, lap counting, places and reset.
- Game modes: Free drive (1 or 2 players since 27 Nov 2026, no timer, no AI), Race (1 or 2 players, 0 to 3 AI karts, default 3), Time trial.
- Split screen side by side for 2 players: one shared world, one camera and HUD per player, a coloured frame per player. Cameras higher and wider than full screen. No camera shake in kid mode.
- Speeds: Kid, Normal, Fast.
- Driver and kart are separate resources (.tres), picked separately on a simple selection screen. Driver types: 3D model, or paper (front and back photo on a flat card that wobbles and leans in curves). Turn every toy photo pair in photos/toys/ into a paper driver (remove the background locally, free tools only).
- Boost stars to drive through, with a sound and a sparkle. A finish screen that celebrates everyone. UI: icons plus short German labels; playable without reading.
- Windows export preset, built to builds/ToyKart.exe.
- Target: 60 fps at 1080p in split screen on an RTX 4070.

4. Done when
- Headless checks pass, the exe starts, and a 2-player kid-mode race against 3 AI karts runs on the projector.
- docs/HANDOVER.md lists what works, what is next, and a 5-minute couch test for me and my son.

Ask me before deleting files, using paid tools, or changing a decision in docs/DECISIONS.md.
```

## Sources

- [Godot 4.7 release](https://godotengine.org/releases/4.7/) and [controller features docs](https://docs.godotengine.org/en/4.7/tutorials/inputs/controller_features.html)
- [Kenney Starter Kit Racing](https://store.godotengine.org/asset/kenney/starter-kit-racing/), [Toy Car Kit](https://kenney.nl/assets/toy-car-kit), [Car Kit](https://kenney.nl/assets/car-kit)
- [Unity MCP getting started](https://unity.com/blog/unity-ai-mcp-how-to-get-started), [Unity plans and pricing](https://unity.com/products/pricing-updates)
- [Godot MCP server](https://mcpservers.org/servers/Coding-Solo/godot-mcp)
- [Mario Kart World support features](https://nintendosoup.com/?p=273231)
- [AAP media guidance for young children](https://pulse.seattlechildrens.org/?p=10334)
- [Hunyuan3D 2.0 licence](https://huggingface.co/tencent/Hunyuan3D-2/blob/main/LICENSE), [TRELLIS.2 model card](https://huggingface.co/microsoft/TRELLIS.2-4B/blob/main/README.md), [Tripo plans](https://www.tripo3d.ai/help/billing/which-tripo-ai-plan-is-right-for-me)
