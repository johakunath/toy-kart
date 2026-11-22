# Toy Racer: gameplay research (kart racers, family games, preschool design)

Date: 2026-11-22. Web research for a 2-player split-screen (dad + 4-year-old) kart racer with 0-3 AI karts.
Items marked **[sourced]** come from the linked pages; **[known]** marks widely documented mechanics I did not re-verify this session; **[inference]** is my design reading.

---

## 1. Items and item distribution

### What the big games do
- **MK8 / MK8 Deluxe: distance-based item tables.** In Grand Prix the distribution depends on the distance to the frontrunner when the box is opened; players and CPUs use separate tables; Versus has themed sets (Mushrooms only, Shells only, Bananas only, Bob-ombs only, Frantic). Battle tables depend on minutes and balloons left. [sourced] https://www.mariowiki.com/Mario_Kart_8_item_probability_distributions
- **Mario Kart World: position-based** like Mario Kart Wii (community analysis), with generally stronger items; some items are withheld in the first 20-30 s of a race. [sourced, community inference] https://nintendosoup.com/in-depth-analysis-reveals-how-mario-kart-worlds-item-system-works/amp/
- Deluxe community analysis describes 5 placement groups (1st, 2nd, 3-5, 6-8, 9-12). [sourced, community] Mario Wiki notes the Deluxe tables have not been ripped. https://www.mariowiki.com/Talk:Mario_Kart_8_item_probability_distributions
- Typical shape [known]: leader gets defensive/low items (banana, green shell, coin); back of pack gets speed items (triple mushroom, star, bullet bill). Strong items have cooldowns and caps on how many can exist at once.

### The blue shell debate
- Hideki Konno (director SMK, MK64): introduced to keep everyone bunched and "in it until the end". [sourced] https://kotaku.com/the-maker-of-mario-kart-justifies-the-blue-shell-5780082
- Kosuke Yabuki (MK7/MK8): Nintendo tested removing it, the game felt like "something's missing", so it stayed. [sourced via Wikipedia] https://en.wikipedia.org/wiki/Blue_shell
- [inference] For a 4-year-old the blue shell is the worst possible item: it punishes him exactly when he is winning (the moment he is happiest) with an unavoidable hit he cannot understand. Rubber-banding already does the bunching job.

### Coins as a soft system
- MK8/8DX: coins raise top speed up to 10 (World: 20), give a tiny burst on pickup, are lost when hit. Gains are small (one test: ~1.4 % at 10 coins) with diminishing returns. [sourced] https://nintendoeverything.com/mario-kart-world-how-coins-work/ , https://win.gg/news/what-do-coins-do-in-mario-kart-8-deluxe-heres-what-to-know/
- Design reading (Tom Kail, Game Developer blog): evenly placed coins are constant micro-goals, they mark the racing line and curve entries, pacing builds over a race, and novices "don't need to know what coins do" - they only need to see coins are good. [sourced] https://www.gamedeveloper.com/design/mario-kart-8-players-don-t-need-to-know-what-the-coins-do-
- CTR Nitro-Fueled: 10 Wumpa fruit = "juiced" (stronger power-ups, slightly faster); lost on hits/falls. Hidden boost reserves fill when you chain boosts. [sourced] https://support.activision.com/content/atvi/support/web/en/crash-team-racing/articles/crash-team-racing-nitro-fueled-gameplay-tips.html , https://www.powerpyx.com/crash-team-racing-nitro-fueled-boost-mechanics-explained/

### How to apply here
- **Kid-friendly item set** (no attacks on a person, only "fun" effects): mushroom/turbo, golden/rainbow invincibility star (run through things, music changes), bubble shield, magnet that pulls you to the next kart, "bounce spring" jump, confetti cannon/horn that makes nearby karts wobble harmlessly (no spin-out for the kid), banana-like "soap bubbles" that only slow AI and dad. Always an icon, never text.
- **Asymmetric hit rules:** items can hit AI and dad; nothing ever spins out the kid's kart for more than a wobble (keeps the kid promise). If items hit him, make it a 0.5 s bounce with laughter, not a stop.
- **Distribution by player, not by position:** kid gets "good" items always (boost, star); dad gets weaker/defensive items when ahead of the kid; AI gets the MK-style position table. No blue shell, or a "rainbow shell" that only targets the leading AI/dad, never the kid.
- **Fixed one-button use:** item auto-fires for the kid after ~1 s if he does not press (no hoarding concept needed), or fires on any face button.
- **Coins / toy bricks** along the racing line: pick-up sound, tiny speed bump, counter on HUD as filled dots, not digits. Also a natural steering teacher (follow the coins). Total coins feed unlocks (section 7).

---

## 2. Catch-up and rubber-banding

- Black Rock (Pure, GDC Europe): rubber-banding criticised because it is obvious when AI is superhumanly fast or brain-dead slow; they used race scripting instead. [sourced] https://www.mcvuk.com/development-news/black-rock-studio-blasts-arubber-bandinga/ , https://gamedeveloper.com/design/the-pure-advantage-advanced-racing-game-ai
- "Rubber banding as a design requirement" (Game Developer). [sourced] https://gamedeveloper.com/design/rubber-banding-as-a-design-requirement
- Academic: rubber-banding is the standard DDA in racing games; improved system (ARBS) proposed in ICGA Journal. [sourced] https://content.iospress.com/articles/icga-journal/icg220207
- Done badly: player feels cheated when the same car is visibly faster. [sourced] https://www.taylorfrancis.com/books/9780429100277/chapters/10.1201/b16725-48

### How to apply here
- Keep rubber-banding but **hide it**: AI slows by taking wider lines, small "mistakes", hesitating at boost pads, missing coins, rather than by visibly lower top speed. Speed it up via drafting/turbo pads that look earned.
- **Script the drama** (Pure approach): aim for the kid to be in a pack in the last lap and to pass someone near the finish. Target finish places by a "story" chosen at race start (kid finishes 1st most races, sometimes a close 2nd behind dad's friendly rival so winning stays meaningful).
- Dad gets **reverse catch-up** (handicap): slightly lower top speed when ahead of the kid, or a "dad lane" of fewer boost pads. Optional toggle in options.

---

## 3. AI drivers that feel human

- Forza Drivatar: learned from real players, "honest mistakes" (braking late, running wide), deliberately reduced aggression, analog throttle/brake modulation, multiple lines for overtakes. Players complain when AI is too clean. [sourced] https://gamedeveloper.com/design/how-forza-s-drivatar-actually-works , https://forza.net/news/forza-motorsport-drivatar-changes
- [inference] For toys-as-drivers, personality matters more than skill: each toy gets a style (careful, wobbly, fast-but-crashy, show-off who honks).

### How to apply here
- Per-driver `.tres` personality: line offset, mistake rate, horn frequency, reaction to the kid (friendly honk, little jump when passed).
- AI never rams the kid; AI gives way if overlapping the kid's kart.
- Visible emotions: driver bounce/cheer when using a boost, "oops" wobble when hitting a wall. These read for a pre-reader.

---

## 4. Cooperative and parent-as-helper modes

- Super Mario Galaxy Co-Star: Miyamoto imagined a parent sitting next to a child helping them; second player stops boulders and enemies with the pointer; meant to fix the "getting in each other's way" problem. [sourced] https://www.nintendo.co.uk/Iwata-Asks-Super-Mario-Galaxy/Volume-4-Shigeru-Miyamoto/1-The-Old-Issue-of-Two-Player-Play/1-The-Old-Issue-of-Two-Player-Play-220647.html , https://www.engadget.com/2007-11-08-miyamoto-talks-super-mario-galaxy-co-op.html
- Galaxy "from 5 to 95" aim; skilled players teach non-gamers via Co-Star. [sourced] https://nintendo.co.uk/Iwata-Asks/Iwata-Asks-Super-Mario-Galaxy/Volume-1-The-Producer-and-Director/4-From-5-to-95/4-From-5-to-95-230131.html
- Super Mario Odyssey: player 2 controls Cappy, invincible by design, protects Mario by moving around him, controls the camera. [sourced] https://www.gamespot.com/articles/nintendo-e3-207-super-mario-odyssey-local-co-op-co/1100-6450983/ , https://gameinformer.com/b/news/archive/2017/06/15/see-how-local-co-op-works-in-super-mario-odyssey.aspx
- Sonic Racing CrossWorlds / Team Sonic Racing: team racing with shared team score and joint actions (ring sharing, slipstream). [sourced] https://www.techradar.com/gaming/sonic-racing-crossworlds-review
- Mario Kart team races: team score from individual points (15/12/10/9...). [sourced] https://help.playvs.com/en/articles/5872507-mario-kart-8-deluxe-rulebook ; friendly-fire rules not verified.
- Lego 2K Drive: whole campaign playable in 2-player split screen; criticism that only one player's save/progress counts. [sourced] https://stevivor.com/reviews/lego-2k-drive-review/ , https://gamesradar.com/lego-2k-drive-review

### How to apply here
- **Team mode "Wir gegen die Spielzeuge" (us vs. the toys):** dad + kid are one team; team score = best of the two places. Dad's job becomes blocking AI and towing the kid. This turns dad's skill into help instead of competition.
- **Tow / slipstream link:** when dad drives just ahead, the kid's kart gets a visible "magic rope" or slipstream boost. Teaches following.
- **Hand-over items:** dad can press a button to give his item to the kid (gift animation). Galaxy/Odyssey logic: the helper is invincible-ish and his actions make the child look good.
- **Shared progress:** unlocks are family-wide, never per player (avoid Lego 2K Drive's issue).

---

## 5. Battle and alternative modes for kids

- MK8DX battle: Balloon Battle, Renegade Roundup (cops and robbers, free jailed teammates), Bob-omb Blast, Coin Runners, Shine Thief. [sourced] https://www.siliconera.com/mario-kart-8-deluxe-brings-back-double-dashs-bob-omb-blast-shine-thief/ , https://inverse.com/article/30964-renegade-roundup-is-the-best-battle-mode-in-mario-kart-8-deluxe
- Kirby Air Ride/Riders: Sakurai's one-button concept; City Trial (roam a city collecting power-ups, then a random mini-event) is called the standout mode. [sourced] https://goombastomp.com/kirby-air-ride-and-sakurais-one-button-game-vision/ , https://npr.org/2025/11/19/nx-s1-5611480/kirby-air-riders-racing-game-review
- Mario Kart World free roam + P-Switch missions: liked by younger players for relaxed driving and collecting; criticised for weak rewards (only stickers). [sourced] https://gamesradar.com/games/racing/mario-kart-world-review , https://www.pockettactics.com/mario-kart-world/review

### How to apply here
- **Coin/brick collecting** (Coin Runners without stealing): arena or free-drive map, 90 s, collect as many sparkles as possible as a team; counter fills a big jar.
- **Balloon pop "Ballons"** with only AI targets carrying balloons, or kid chases dad (dad = "catch me" game). Tag/chase is the classic 4-year-old game.
- **Free drive missions (City Trial-lite):** "drive through 5 rings", "find the hidden toy", "push the big ball into the goal". Reward with a visible thing in the world (sticker on kart, new hat), not just a number.
- Avoid elimination modes (Shine Thief, Knockout) for the kid.

---

## 6. Cups, Grand Prix and session length

- MK structure [known]: cups of 4 races, points 15/12/10/... (12 racers), trophy + podium per cup. Diddy Kong Racing: hub (Timber's Island), balloons unlock worlds, bosses raced twice, trophy races, silver-coin challenge, mirrored "Adventure 2". [sourced] https://en.wikipedia.org/wiki/Diddy_Kong_Racing , https://www.mariowiki.com/Diddy_Kong_Racing
- Screen time: AAP guideline ~1 hour/day high-quality content for ages 2-5, with co-viewing/co-play. [sourced] https://www.pbs.org/newshour/health/pediatricians-relax-guidelines-screen-time , https://health.choc.org/updated-aap-recommendations-for-screen-time/
- Losing hurts less after 5 minutes than after 30: choose quick games. [sourced] https://www.todaysparent.com/kids/school-age/6-ways-to-help-a-sore-loser/ (via summary)

### How to apply here
- **Mini-cup of 3 races** on 3 tracks, each race 2-3 minutes (2 laps), whole cup ~10 minutes, then a trophy. A full session = 2 cups + a free-drive or collecting round, well under 30 minutes.
- Cup points: everyone gets points; team score for team mode. Show points as stacked stars, not numbers.
- Never more than ~3 minutes between "celebration moments" (lap, item, finish).

---

## 7. Unlocks and progression for young kids

- DKR: balloons as tangible collectibles opening new areas. [sourced] above.
- MK8: unlocks tied to total coins feel earned because they reflect active play. [sourced] Kail article above.
- Toca Boca / Sago Mini: no scores, timers, levels or artificial incentives; open-ended play, kids invent their own rules. [sourced] https://tocaboca.helpshift.com/hc/en/16-other-toca-boca-apps/faq/28-a-digital-toy-or-a-game---what-is-the-difference , https://joanganzcooneycenter.org/2014/11/14/qa-with-sago-sagos-jason-krogh/ , https://sagomini.com/article/message-from-the-ceo/

### How to apply here
- **Sticker book / toy shelf**: after each race or cup, one new sticker (kart decal, hat, horn sound, kart colour, confetti type) is "opened" with a present animation. Always a reward, never gated by winning: placement only changes which present wobbles bigger.
- Unlocks are cosmetic or new playful things (new horn, trail, track mirror), never power. Nothing to grind.
- The kid's own toys are the main progression: "add a new toy" as a family ritual (already supported by photo pipeline) is the strongest unlock there is.

---

## 8. Celebration and feedback

- Dweck: praise effort/process, not talent; person praise led to more helplessness after failure. [sourced] https://news.stanford.edu/2015/04/29/dweck-kids-potential-042915/ , https://www.reed.edu/psychology/motivation/assets/downloads/Corpus_Lepper_2007.pdf
- Pre-MEGa framework: quick, clear response to input, no stagnation, let kids succeed accidentally in the first 30 seconds. [sourced] https://www.slideshare.net/lailashoukry/premega-a-proposed-framework-for-the-design-and-evaluation-of-preschoolers-mobile-educational-games

### How to apply here
- **Podium for everyone**: all karts on a podium/stage; kid's toy always does a happy dance; first place gets fireworks, but 2nd/3rd still get confetti and a medal. Voice line praises effort ("Super gefahren!", "Toll gekurvt!") rather than "Du bist der Beste".
- Finish cutscene: camera orbits the kid's toy driver, his toy jumps, music fanfare. Cap at ~8 s, skippable by any button.
- In-race juice: every coin, boost, overtake has a sound + particle; overtake gives a "+1" star burst and a short cheer from his toy.

---

## 9. Failure handling

- MK: Lakitu is referee (start lights, lap counter, flag, reverse sign) and fishes you back after falling off. [sourced roles] https://www.mariowiki.com/Lakitu ; respawn ~2-3 s, lose some coins [known].
- MK8DX Smart Steering prevents driving off edges; Auto-Accelerate; together let a 4-year-old race with the family. [sourced] https://www.nintendolife.com/news/2017/05/mario_kart_8_deluxes_smart_steering_means_father_can_play_with_his_physically_impaired_daughter , https://mobilesyrup.com/2017/05/02/mario-kart-8-deluxes-smart-steering-option-help-child/
- MK World Smart Steering only nudges near edges and leaves drift/jump available. [sourced] https://www.gamesradar.com/games/racing/mario-kart-world-smart-steering
- NN/g: harsh outcomes (a mis-tap that throws you out, a vanished item) make kids quit. [sourced] https://www.nngroup.com/articles/children-ux-physical-development/

### How to apply here
- A **toy rescuer character** (e.g. a toy helicopter or hand from above) who picks the kart up and puts it back on the line in under 1.5 s with a funny sound, no coin loss for the kid. Makes the reset a little show instead of a failure.
- Wrong-way: big arrow + helper character pointing, then auto-turn for the kid after 2 s.
- Stuck detection already exists; keep it fast and invisible.

---

## 10. Split-screen UX for pre-readers

- Split/Second kept only lap, position and one meter near the car; no speedometer. [sourced] https://kotaku.com/things-we-dont-need-to-see-such-as-our-speed-5458994
- SRB2Kart uses large HUD variants in 2-player split screen. [sourced] https://mail.wiki.srb2.org/wiki/SRB2Kart/HUD
- Children 3-5: symbolic interface elements need specific design support; under 3 they are inaccessible. [sourced] https://faculty.washington.edu/alexisr/HiddenSymbols.pdf
- Sago Mini: zero words for 4-year-olds; testing with 100+ kids showed a joystick didn't work, so they switched to tap. [sourced] https://developer.apple.com/news/?id=3t6o5jec , https://gori.me/en/apps/ipad-app-news/167337/

### How to apply here
- Each half shows: **face of your toy + place as a big medal colour** (gold/silver/bronze/ribbon) rather than "2nd"; **laps as filled flags** (2 lap dots); **item slot** big in the top corner. No timer, no speed.
- A **race strip** (horizontal bar with toy faces sliding along it) instead of a minimap: pre-readers understand "who is in front" spatially. Optionally shared in the centre seam.
- Distinct colour frame per player half (his half in his favourite colour), so he always knows which half is his on the projector.
- Big arrow/ghost of dad's kart at screen edge when dad is near, so he can find "Papa".

---

## 11. Child development notes (age 4)

- Fine motor: draws a square, uses scissors; skills vary widely. [sourced] https://www.healthlinkbc.ca/healthwise/milestones-4-year-olds , https://medlineplus.gov/ency/article/002013.htm
- 3-5 year-olds: very limited fine motor and coordination; avoid two-handed coordination and quick reactions; prefer one-input actions; big targets. Lego Junior one-big-button game was easy for 5-year-olds; Roblox two-stick play failed. [sourced] https://www.nngroup.com/articles/children-ux-physical-development/
- Attention is "elastic" and varies through the day. [sourced] https://blog.cincinnatichildrens.org/learning-and-growing/activities-that-will-keep-your-4-year-olds-attention/
- Losing: preschoolers see only their own perspective and expect to win, so losing feels catastrophic; it is a stage, not a flaw. Use short games, team up with them, cooperative games, model gracious losing; don't make winning the main point. [sourced] https://www.janetlansbury.com/2018/02/4-reasons-let-kids-sore-losers/ , https://pathways.org/talking-child-winning-losing , https://www.todaysparent.com/family/parenting/when-winning-is-everything/
- Pre-MEGa: short, interruptible routines; mix exploratory non-goal play with goal-oriented games; include collaboration. [sourced] slideshare link above.
- Nintendo Labo: when something seemed too hard for a child, the team redesigned it; Play and Discover matter as much as Make. [sourced] https://www.nintendo.com/au/news-and-articles/nintendo-labo-developer-interview-part-1-the-concept/ , https://gonintendo.com/stories/307407-nintendo-labo-dev-interview-part-2-a-nose-picking-prototype-d

### Implications
- One stick + one button is the ceiling. Drift, brake, item-use timing are dad-only depths.
- Dad modeling: dad's toy should visibly "lose happily" (cheering animation when the kid passes him).
- Pause anywhere, instant resume; a race interrupted for a snack must not be lost.

---

## 12. Other notable systems

- **CTR**: power-sliding with boost chains, Adventure hub, boss races, Time Trial ghosts (Oxide). Adapt: dad-only drift boost; kid gets auto-boost on long curves.
- **Sonic CrossWorlds Travel Rings**: leader picks a different world for lap 2; Gadgets loadouts. [sourced] https://blog.playstation.com/?p=401254 . Adapt: a "magic portal" mid-race that drops everyone into a surprise themed section (snow, candy) - big wow moment for a kid.
- **Hot Wheels Unleashed**: toy-scale environments, track builder (but hard with controller). [sourced] https://mp1st.com/reviews/hot-wheels-unleashed-review-the-unicorn-of-toy-car-racers-xbox . Adapt: tracks in rooms of the house (living room floor, kitchen table), matching the real-toy concept.
- **Lego 2K Drive**: open-world family racing, vehicle transforms on road/off-road/water. [sourced] https://news.xbox.com/en-us/2023/05/19/lego-2k-drive-how-visual-concepts-built-the-ultimate-driving-experience-out-of-lego/
- **Horn**: already in Intent; make it a toy-specific sound and let AI answer it. 4-year-olds love cause-and-effect buttons.

---

## Top 15 ranked (impact for this family, effort for this codebase)

| # | Idea | Impact | Effort |
|---|---|---|---|
| 1 | Team mode "us vs. the toys" (shared score, dad as helper) | High | M |
| 2 | Kid-safe asymmetric items (only boosts/stars/bubbles; nothing stops the kid) | High | M |
| 3 | Per-player item tables (kid always good items, dad handicapped, no blue shell) | High | S (after items) |
| 4 | Podium for everyone + effort praise + skippable fanfare | High | M |
| 5 | Sticker/present after every race, family-wide, cosmetic | High | M |
| 6 | Coins/bricks on the racing line (micro-goals, steering teacher) | High | S |
| 7 | Hidden rubber-band (AI mistakes, scripted close finish) | High | M |
| 8 | Toy rescuer reset animation (<1.5 s, no loss) | Med | S |
| 9 | Pre-reader HUD: medal colours, flag dots, face race strip | Med | S |
| 10 | 3-race mini-cup with trophy, ~10 min | Med | S |
| 11 | AI personalities per driver .tres, friendly reactions | Med | M |
| 12 | Tow/slipstream rope from dad + item gifting | Med | M |
| 13 | Kid battle: collect-together jar, chase-dad tag | Med | M |
| 14 | Free-drive missions with visible world rewards | Med | M |
| 15 | Surprise portal/section mid-race (Travel Ring lite) | Low-Med | L |
