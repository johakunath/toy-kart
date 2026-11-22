# Toy Racer: Nintendo-quality visuals and tech in Godot 4.7 (research notes)

Date: 2026-11-22. Target: Godot 4.7.2, Forward+, Jolt, physics interpolation on, 2-player split screen
(two SubViewports side by side) at 1080p/60 on a projector, single player 1440p/144 Hz, RTX 4070.

Legend: [doc] = from official Godot docs/release pages; [comm] = community source; [inf] = my inference /
engine knowledge, verify in-engine before relying on it.

---

## 0. What changed in Godot 4.5 - 4.7 that matters here

| Version | Feature | Relevance |
| --- | --- | --- |
| 4.5 | Stencil buffer; StandardMaterial3D `stencil_mode` Outline / X-Ray presets (experimental) [doc/comm] | Cheap per-object outlines on karts/drivers; X-ray silhouette of a kart hidden behind a hill |
| 4.5 | SMAA 1x (`screen_space_aa = SMAA`) [doc] | Sharper than FXAA, low cost, combine with MSAA |
| 4.5 | Shader baker (export option) [doc] | Pre-compiles shaders at export; removes first-time hitches (biggest win on D3D12/Metal, "20x" load time in TPS demo) |
| 4.5 | Specular occlusion from ambient light, bent normal maps [doc] | Small quality win, almost free |
| 4.5 | SDL3 gamepad driver [doc] | Better mappings, hotplug, basis for LED/motion/haptics |
| 4.5 | 3D physics interpolation moved to SceneTree [doc] | Same API, more robust |
| 4.6 | Glow now blended *before* tonemapping, default blend mode Screen [doc] | Re-tune glow; bloom now respects AgX |
| 4.6 | AgX exposes `tonemap_agx_contrast` (default 1.25) and `tonemap_agx_white` (default 16.29) [doc] | Key knob for saturated, punchy colours |
| 4.6 | SSR rewrite (full/half res), octahedral reflection probes (cheaper) [doc] | Wet/plastic reflections affordable |
| 4.6 | Jolt default, D3D12 default for *new* Windows projects [doc] | Check `rendering_device/driver.windows`; Vulkan and D3D12 both fine on RTX 4070, measure both |
| 4.6 | Gamepad LED colours; groundwork for motion/haptics [doc] | LED = player colour |
| 4.6 | Tracy/Perfetto profiling of GDScript [doc] | Real frame profiling |
| 4.7 | HDR output (Windows) [doc] | Optional; projector likely SDR, skip |
| 4.7 | Clearcoat now energy conserving + uses sky/probe reflections [doc] | Toy plastic / car paint finally looks right with clearcoat |
| 4.7 | AreaLight3D (rect lights, soft shadows; reported expensive) [doc/comm] | Menu / garage scene only, not in race |
| 4.7 | Joypad motion sensors (gyro/accel) [doc] | Optional "tilt to steer" for kid |
| 4.7 | Per-pass environment uniform buffers (removes bottleneck) [doc] | Free perf |
| 4.7 | Haptics/force feedback PR still draft; no adaptive triggers [comm] | Only classic rumble (`start_joy_vibration`) |

Sources: https://godotengine.org/releases/4.5/ , https://godotengine.org/releases/4.6/ ,
https://godotengine.org/releases/4.7/ , https://github.com/godotengine/godot/pull/114642 ,
https://github.com/godotengine/godot/pull/111707

---

## 1. What makes the "Nintendo look" (Mario Kart 8 / World, Astro Bot, Splatoon)

Findings (mostly secondary sources; no official Nintendo rendering talk exists):
- MK8 Deluxe: soft halo from "basic distance fog and a lot of bloom"; looks more physically based than
  older Nintendo titles (fresnel, metals, reflections) but kept bright and readable [comm].
  https://nintendoeverything.com/mario-kart-world-tech-analysis-including-frame-rate-and-resolution/
- MK World: baked light maps for direct/indirect light plus real-time cube maps for water/reflections,
  volumetric haze for depth, strong sun bloom, locked 60 fps, 1080p handheld / 1440p docked, no AA
  handheld; split screen with no performance concerns found [comm].
  https://www.nintendolife.com/news/2025/06/digital-foundry-delivers-its-mario-kart-world-tech-review-nintendos-artistry-stands-out-the-most-here
  https://www.nintendolife.com/news/2025/04/digital-foundry-digs-deep-into-mario-kart-worlds-tech-and-specs
- Nintendo Mario titles use heavy rim lighting (since Galaxy), masked by a rim texture [comm].
  https://gamedev.net/forums/topic/638937-how-to-make-a-shiny-effect/5034754/
- Valve TF2 "illustrative rendering" is the classic reference: artist-tuned fresnel + separate rim term
  with a mask, silhouettes from rim light rather than black outlines.
  https://cdn.fastly.steamstatic.com/apps/valve/2008/GDC2008_StylizationWithAPurpose_TF2.pdf
- Astro Bot: material choice per level makes the world "tangible"; proprietary engine; GDC talk
  "Taming Technologies Behind ASTRO BOT" (rendering optimisations for constant frame rate).
  https://blog.playstation.com/2019/01/24/astro-bot-rescue-mission-inside-the-art-and-animation-of-japan-studios-ps-vr-hit/
  https://gdcvault.com/play/1026072/Taming-Technologies-Behind-ASTRO-BOT

Synthesis of the recipe [inf, based on above]:
1. PBR-lite, not hard cel: smooth lighting with a slightly wrapped diffuse, soft shadows, strong
   ambient (sky) fill so shadows are coloured, never black.
2. Rim/fresnel light on characters and karts (pops them off the track; that is what reads "Nintendo").
3. Generous bloom on highlights, sun, boost effects; distance haze (aerial perspective) for depth.
4. Saturated albedo but controlled value range: bright, clean colours, sky-tinted shadows.
5. Rock-solid 60 fps, clean image (no ghosting), crisp edges.
6. Juice: speed lines, FOV kick on boost, camera shake, particles, squash and stretch.
7. Outlines are NOT used in MK8/World (Splatoon also mostly not). Outlines are optional, for drivers only.

---

## 2. Environment / colour pipeline (concrete settings)

Order of operations in Godot: DOF -> auto exposure -> glow -> tonemap -> adjustments (BCS, LUT) [doc].
https://docs.godotengine.org/en/4.6/classes/class_environment.html
https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html

Tonemapper:
- ACES "desaturates bright values for a more realistic appearance" -> wrong for saturated toys [doc].
- Filmic: decent contrast but shifts hues of bright saturated colours.
- AgX: best hue preservation as colours brighten; `tonemap_agx_contrast` adds contrast at no cost
  (better than `adjustment_contrast`); slowest but negligible on RTX 4070 [doc].
- AgX inherently desaturates highlights toward white (by design). To keep Lego colours:
  keep albedo saturated but not near-white value, keep sun energy moderate (~1.0-1.5 with exposure 1.0)
  so lit surfaces do not hit the highlight shoulder, then `tonemap_agx_contrast` 1.3-1.5,
  `adjustment_enabled = true`, `adjustment_saturation` 1.15-1.3 (post-tonemap). Lower
  `tonemap_agx_white` (e.g. 6-10) brightens mid-tones if the image looks dim [doc + inf].
- Alternative if AgX still looks pastel: Filmic or Linear+custom LUT for the "candy" look; compare
  screenshots per track. A 3D LUT (`adjustment_color_correction`, Texture3D import, 33 slices) gives
  full per-track grading control (evening = warm LUT) [doc].

Glow (bloom):
- 4.6+: glow before tonemap, default blend Screen [doc]. Suggested starting point:
  `glow_enabled`, levels 2-5 on (1 off), `glow_intensity` 0.6-0.9, `glow_bloom` 0.05-0.1,
  `glow_hdr_threshold` 1.0-1.2, blend Screen (Additive for dreamy menu) [inf].
- Emissive boost pads, stars and exhaust flames with energy 2-4 so they bloom while the rest does not.

Ambient and GI (split-screen-aware):
- LightmapGI: best quality/cost but needs baking in the editor and UV2 -> not viable for runtime
  generated tracks, but our tracks are generated by tool scripts in the editor, so baking per track
  *is* possible in principle (bake step after `build_round_track.gd`). Cost at runtime: lowest [doc].
  https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/introduction_to_global_illumination.html
- SDFGI: least setup, works with generated geometry, but costs per viewport (two cascaded updates in
  split screen) [doc + inf]. Fine for single-player 144 Hz on a 4070 at low settings; risky for 2P.
- VoxelGI: needs bake, leaks; not worth it here.
- SSIL: screen-space only, complement, half-res; per-viewport cost [doc].
- Recommendation: sky ambient (`ambient_light_source = Sky`, `ambient_light_sky_contribution` 1.0,
  energy 1.0-1.5) + SSAO (half size, radius 1-2, intensity 1.0-1.5, light_affect 0) + optional
  baked LightmapGI later. Sky-coloured ambient is what makes shadows blue-ish and toy-like.

SSAO: conservative intensity; project setting `rendering/environment/ssao/half_size = true` for a large
speed gain [doc]. Adds the "contact shadow under the kart and between bricks" look cheaply.

Fog: depth fog + `fog_aerial_perspective` 0.3-0.6 (fog takes sky colour, MK-style haze); `fog_sun_scatter`
for evening glow. Volumetric fog only for menu or one special track; it is per viewport and costly [doc + inf].

Depth of field: menu/garage/podium only via CameraAttributesPractical (far blur), tilt-shift style
(near+far) on the finish podium looks "toy miniature" [doc]. Never in race.

Debanding: `use_debanding = true` (project setting) to avoid sky gradient banding on projector [doc].

---

## 3. Stylised shading techniques

Toon / cel:
- Pure cel shading (hard steps) fights the Kenney/MK aesthetic; use "soft toon": wrap diffuse +
  2-3 smoothstep bands with wide transitions only on characters. Custom `light()` replaces the
  built-in BRDF, and is evaluated per light; with one directional light the cost is small [comm].
  https://hexaquo.at/pages/understanding-godot-light-shaders-and-light-calculations-by-implementing-a-toon-light-shader/
  https://godotshaders.com/shader/complete-toon-shader/ , https://github.com/EXPWorlds/Godot-Cel-Shader
- Caveat: custom `light()` loses some built-in features (e.g. you must handle specular yourself).

Rim light (highest value per cost):
- StandardMaterial3D has built-in `rim_enabled`, `rim` (amount), `rim_tint` (0 = white, 1 = albedo
  colour). It is designed as a fabric/scatter rim -> ideal for plush/felt toys [doc/inf].
- For a Nintendo-style rim: in a shader, `float r = pow(1.0 - dot(NORMAL, VIEW), 3.0);` multiplied
  by a light-direction mask, added to EMISSION or in `light()` [comm].

Outlines:
- Inverted hull (next_pass, `cull_front`, grow along normal): cost = drawing the mesh twice per
  viewport; fine for 2-8 karts/drivers, too expensive for the whole world. Needs smooth normals.
- 4.5 stencil Outline preset in StandardMaterial3D: same "grow" idea but stencil-masked so the outline
  never covers the object itself; experimental; needs shared vertices/smooth normals; overlapping
  duplicates need unique stencil reference values [comm].
  https://github.com/godotengine/godot-docs/pull/11373/files
  https://80.lv/articles/mind-bending-power-of-godot-4-5-s-stencil-support
- Post-process (depth/normal Sobel) outlines: full-screen pass per viewport, constant cost, outlines
  everything; conflicts with the MK look, noisy on Kenney tiles. Not recommended.
- X-Ray preset: show a coloured silhouette of a player's kart when hidden behind terrain - useful for
  a kid to always find his kart.

Toy materials (StandardMaterial3D):
- Plastic/Lego: roughness 0.25-0.4, metallic 0, specular 0.5, clearcoat 0.3-0.6, clearcoat_roughness
  0.1-0.2 (4.7 clearcoat is now energy-conserving and reflects sky/probes) [doc 4.7].
- Car paint: metallic 0.3-0.6, roughness 0.3, clearcoat 1.0.
- Felt/plush: roughness 0.9-1.0, specular 0.2, rim_enabled (rim 0.6-1.0, rim_tint 0.5-0.8),
  optional backlight / subsurface for thin parts; detail noise normal map for fibres. No built-in
  sheen; rim is the cheap sheen substitute [inf + comm].
  https://godotshaders.com/shader/performant-sss-sub-surface-scattering-approximation/
- Wood toy: roughness 0.6, warm albedo, subtle grain detail texture.

Sky: ProceduralSkyMaterial is fine; for clouds use a custom sky shader with 2D noise layers scrolled by
TIME and a sun disc; `process_mode = Quality/Incremental/RealTime` matters: keep the sky static or use
Incremental for radiance updates (real-time radiance per frame is expensive) [inf]. Reflection probes
are now octahedral and cheaper (4.6) [doc].

Water: depth-based foam + scrolling normals; check reverse-Z (Godot 4.3+) when porting older shaders,
foam formulas break otherwise [comm].
https://godotshaders.com/shader/stylized-water-for-godot-4-x , https://godotengine.org/article/introducing-reverse-z/

Grass/foliage: MultiMeshInstance3D + vertex-shader wind (noise texture, tip weighted by UV.y or
COLOR), `cast_shadow = off` (shadows are the main cost), chunk multimeshes so frustum culling works,
visibility range end ~40-60 m with dither fade [comm/doc].
https://github.com/2Retr0/GodotGrass , https://godotshaders.com/shader/stylized-multimesh-grass-shader/ ,
https://hexaquo.at/pages/grass-rendering-series-part-2-full-geometry-grass-in-godot/
Wind on trees: same vertex sway, global `wind_strength` uniform per track (Atmosphere sets it).

Speed feel:
- Radial speed lines as a CanvasLayer/ColorRect shader per SubViewport, alpha driven by speed and
  boost; noise in polar coordinates [comm].
  https://godotshaders.com/shader/speed-lines-shader-for-godot-4/
- Radial/zoom blur on boost only (screen texture, 6-8 samples, strength 0.02-0.05).
  https://godotshaders.com/shader/radical-blur-shader/
- Camera-velocity motion blur (Bauxitedev port) is optional; risk of nausea for a 4-year-old and of
  smearing kid-readable visuals. https://github.com/Bauxitedev/godot-motion-blur
- Cheapest and strongest: FOV kick (+8-12 degrees on boost, tweened), small camera shake, wind
  particles, drift sparks.

---

## 4. Performance in split screen

Basics:
- Two SubViewports = the world is culled and drawn twice, including directional shadow cascades,
  SSAO, glow, SSR, fog per viewport [comm + inf].
  https://uhiyama-lab.com/en/notes/godot/split-screen-multiplayer/
- But each half is 960x1080 (2P side-by-side) = same pixel count as one 1080p frame; so the extra cost
  is mostly vertex/draw-call/shadow-map work, not pixel shading.
- Shadows are the most expensive part [doc]. https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html

Concrete settings:
- DirectionalLight3D: `directional_shadow_mode = PARALLEL_2_SPLITS` in split screen (4 splits draw
  large objects up to 5 times), `directional_shadow_max_distance` 50-80 m (tight = sharper + faster),
  `directional_shadow_fade_start` 0.8, `shadow_normal_bias` up instead of `shadow_bias`,
  `light_angular_distance` 0 (no PCSS) or small, project `soft_shadow_filter_quality` Soft Low/Medium [doc].
- Project `rendering/lights_and_shadows/directional_shadow/size` 4096 (2P) / 8192 not needed.
- Per SubViewport: `positional_shadow_atlas_size = 0` if no omni/spot shadows (saves CPU and GPU) [doc].
  https://docs.godotengine.org/en/4.7/classes/class_viewport.html
- Small props (cones, bricks, trees far away): `cast_shadow = off` or visibility range end.
- Visibility ranges: `visibility_range_end` on scatter/trees/props (e.g. 80-150 m), fade mode
  Disabled (cheapest, hysteresis) or dither via material distance fade; HLOD: far groups -> one
  MultiMesh/merged mesh [doc]. https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html
- Auto mesh LOD on imported GLB (Pixal3D models are dense!): keep LOD generation on import;
  `mesh_lod_threshold` per viewport 1.0-2.0 in 2P [doc].
- Occlusion culling: adds CPU cost, helps only with big blocking geometry; open tracks rarely benefit [doc].
- MultiMesh for trees, cones, fences, grass (one draw call per chunk).
- Pixal3D toy models: decimate to 5-20k tris per kart/driver in Blender; 4 karts x 2 viewports.
- Shader compile hitches: enable shader baker at export [doc 4.5]; also warm up by showing all
  materials once in the loading screen [inf].

Anti-aliasing [doc]: https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html
- Stylised + fast-moving -> MSAA is recommended (no blur, no ghosting). TAA/FSR2 ghost behind moving
  objects (karts!) and blur in motion.
- Recommended: `msaa_3d = 4x` + `screen_space_aa = SMAA` (or FXAA) per SubViewport; screen-space
  roughness limiter stays on. 1440p single: MSAA 4x, optionally SMAA.
- TAA off. FSR2 only as a fallback.

Resolution scaling [doc]: https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html
- RTX 4070 does not need upscaling at 1080p/1440p. Keep `scaling_3d_scale = 1.0`.
- If 144 Hz cannot be held: FSR1 at 0.77-0.85 + MSAA (FSR1 benefits from MSAA), or FSR2 at 0.67-0.77
  (built-in TAA, ghosting risk). These are per Viewport, so each SubViewport can be set individually.
- Note: SubViewport sizing - set SubViewport `size` to the real pixel size of its half (stretch on
  SubViewportContainer) so UI/text and MSAA are crisp.

Frame pacing / latency [doc]: https://docs.godotengine.org/en/4.7/tutorials/rendering/jitter_stutter.html
- VRR monitor: V-Sync on + `Engine.max_fps` cap = 138 at 144 Hz (formula refresh - refresh^2/3600).
- Projector at 60 Hz (likely no VRR): V-Sync on, consider swapchain image count 2 for lower latency
  only if 60 is always sustained.
- Exclusive fullscreen (`WINDOW_MODE_EXCLUSIVE_FULLSCREEN`) for less jitter and lag on Windows.
- NVIDIA Control Panel Low Latency Ultra helps.

---

## 5. Feel tech (physics, camera, input)

- Physics interpolation adds 1-2 ticks of visual delay; fix by raising tick rate [doc].
  https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html
- Recommended: `physics/common/physics_ticks_per_second = 120` (Jolt handles it easily for 4 balls),
  interpolation on. That gives good 144 Hz and 60 Hz output, halves latency, reduces tunnelling.
  Re-check kid-mode zero-reset tests because tuning is tick-rate dependent (forces per tick!) [doc + inf].
  `max_physics_steps_per_frame` keep default 8.
- Cameras: move them in `_process`, `top_level = true` (or separate branch), disable their automatic
  interpolation (`physics_interpolation_mode = OFF`), follow the target's
  `get_global_transform_interpolated()`, smooth with frame-rate independent damping
  `lerp(a, b, 1.0 - exp(-k * delta))` [doc].
  https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html
- Call `reset_physics_interpolation()` on the kart (and snap the camera) after teleports/resets/start
  grid placement, otherwise you see a smear [inf, API exists on Node].
- Input: read input in `_physics_process` for physics, `Input.set_use_accumulated_input(false)` only
  matters for mouse. Determinism: fixed timestep + same inputs is roughly repeatable in Jolt but not
  guaranteed bit-exact across machines; fine for headless checks with `--fixed-fps 60` [doc + inf].

---

## 6. Audio tech

Engine sound:
- Practical approach (used in most arcade racers): 2-4 looped samples (idle, low, mid, high RPM),
  crossfade volumes by RPM bands and map `pitch_scale` within each band (e.g. 0.8-1.6) [inf].
- AudioStreamGenerator in GDScript is CPU heavy; docs recommend C#/GDExtension or low mix rate
  (11025-22050 Hz) [doc]. https://docs.godotengine.org/en/latest/classes/class_audiostreamgenerator.html
- Synthetic engine via GDExtension: https://github.com/bend-n/enginesound (Rust; GDExtension, not GDScript).
- For toy karts: cartoony "brrr" via pitch-shifted sample + slight random LFO on pitch sounds more
  Nintendo than realistic engines.

Doppler: enable `doppler_tracking = PHYSICS_STEP` on both AudioStreamPlayer3D and the Camera3D
(or AudioListener3D); karts move in physics [doc].
https://docs.godotengine.org/en/latest/classes/class_audiostreamplayer3d.html

Split-screen listeners:
- Each Viewport with `audio_listener_enable_3d = true` processes 3D audio with its own camera/listener;
  only one AudioListener3D is "current" per viewport [doc].
  https://docs.godotengine.org/en/4.7/classes/class_viewport.html
  https://forum.godotengine.org/t/audiolistener3d-does-not-override-cameras-listener-when-camera-is-placed-inside-a-subviewport/122575
- [inf, from engine source behaviour] AudioStreamPlayer3D mixes for every listening viewport in the
  same World3D, so a sound near both players plays twice (louder, double doppler). Mitigations:
  (a) own kart engine/horn/boost as non-positional AudioStreamPlayer on a per-player bus with
  AudioEffectPanner (P1 left -0.5, P2 right +0.5); (b) other karts' engines 3D with
  `max_distance` 20-30 m and lower volume; (c) or only one SubViewport listens (enable for P1 only)
  and the rest is 2D.
- Bus effects: Engines bus with Compressor + light Reverb on tunnels (Area3D switch bus),
  Limiter on Master to keep the projector speakers clean.

Adaptive music (Godot 4.3+ resources):
- AudioStreamSynchronized: stems in sync, per-stem volume (`set_sync_stream_volume`): add drums/lead
  layer as the race progresses or when the kid is in front [comm/doc].
- AudioStreamInteractive: clips + transition table (cross-fade, at beat/bar); final-lap clip.
  https://uhiyama-lab.com/en/notes/godot/adaptive-music-system/
  https://forum.godotengine.org/t/creating-layered-music-like-in-mario-kart-wii/124374
- Final-lap tempo: MK speeds up the track; with `pitch_scale` 1.06-1.1 on the music player plus an
  AudioEffectPitchShift of 1/1.08 on the Music bus you get a tempo increase without the chipmunk pitch
  (pitch shift effect costs some CPU and adds artefacts; alternatively author a faster stem) [inf].
  Since our music is generated by `make_music.py`, generating a "final lap" variant at +8% BPM and
  crossfading via AudioStreamInteractive is cleaner.

---

## 7. Controller tech

- `Input.start_joy_vibration(device, weak_magnitude, strong_magnitude, duration)`; magnitudes 0..1,
  duration in seconds (0 = until stopped); `stop_joy_vibration(device)` [doc].
  https://docs.godotengine.org/en/4.7/classes/class_input.html
  Ideas: short strong pulse on bump/wall (0.3 s), weak continuous rumble on boost and off-road,
  tiny tick on item pickup. Kid: keep it soft and short. Also allow off in options.
- Hotplug: `Input.joy_connection_changed(device, connected)`; also scan `Input.get_connected_joypads()`
  at start (already connected pads do not fire the signal); do not assume ids start at 0 [doc/comm].
- SDL3 driver since 4.5 (better mappings); LED colours 4.6 (`Input.set_joy_light(device, color)` -
  verify name in 4.7 class ref); motion sensors 4.7 (gyro steer option); real haptics/adaptive
  triggers not merged [doc/comm].
- 4.7 project setting to ignore joypads when the window is unfocused [doc].

---

## 8. Projects and references to learn from

- Kenney Starter Kit Racing (our base; single RigidBody3D sphere) https://store.godotengine.org/asset/kenney/starter-kit-racing/
- KidsCanCode arcade sphere car recipe https://kidscancode.org/godot_recipes/4.x/3d/3d_sphere_car
- Retro Karting League kart controller devlog https://sporktank.itch.io/retro-karting-league/devlog/373320/kart-controller
- Photon Fusion Godot racing sample (Starter Kit + gamepad) https://doc.photonengine.com/fusion-godot/current/game-samples/racing-starter-kit
- GDQuest split screen coop (Godot 4) https://gdquest.com/library/split_screen_coop
- SuperTuxKart: PBR + custom shaders, render resolution scaling for weak GPUs, up to 8-player split
  screen with vertical viewports https://blog.supertuxkart.net/2018/04/everything-is-shiny.html ,
  https://github.com/supertuxkart/stk-code/blob/master/CHANGELOG.md
- Godot docs optimisation: https://docs.godotengine.org/en/4.6/tutorials/performance/optimizing_3d_performance.html
- Toon light shader tutorial: https://hexaquo.at/pages/understanding-godot-light-shaders-and-light-calculations-by-implementing-a-toon-light-shader/
- TF2 illustrative rendering (rim light theory): https://cdn.fastly.steamstatic.com/apps/valve/2008/GDC2008_StylizationWithAPurpose_TF2.pdf

---

## 9. Top 15 (ranked by impact for this project)

| # | Item | How to apply here | Impact | Effort |
| --- | --- | --- | --- | --- |
| 1 | Colour pipeline: AgX contrast + post saturation + sky ambient | Per look in `atmosphere.gd`: AgX, `tonemap_agx_contrast` 1.3-1.5, adjustment saturation 1.15-1.3, ambient = Sky, sun energy moderate; compare screenshots | High | S |
| 2 | Glow re-tune for 4.6 order (before tonemap, Screen) | Levels 2-5, intensity ~0.7, bloom 0.05-0.1, emissive pads/stars energy 2-4 | High | S |
| 3 | Rim light on karts + drivers | StandardMaterial3D `rim_enabled` (rim 0.5-1, tint 0.5) or fresnel in a shared kart shader | High | S |
| 4 | Toy materials incl. 4.7 clearcoat | Plastic roughness 0.3 + clearcoat 0.4; car paint clearcoat 1.0; plush = rough + rim | High | S-M |
| 5 | Speed feel: FOV kick, speed lines, boost zoom blur | ChaseCamera FOV tween on boost; ColorRect radial speed-lines shader per SubViewport | High | S-M |
| 6 | Physics 120 Hz + interpolated camera in `_process` | Ticks 120, camera top_level, follows `get_global_transform_interpolated()`, exp damping; reset interpolation on respawn; re-run kid checks | High | M |
| 7 | AA: MSAA 4x + SMAA, no TAA | Set per SubViewport and root viewport; avoids kart ghosting | High | S |
| 8 | Shadow budget for split screen | 2 PSSM splits, max distance 60-80 m, normal bias, positional atlas 0, props cast_shadow off | High | S |
| 9 | SSAO half-size + distance fog with aerial perspective | Contact shadows and MK haze; evening look adds sun scatter | Med | S |
| 10 | Frame pacing | Exclusive fullscreen, V-Sync + max_fps 138 at 144 Hz, shader baker on export | Med | S |
| 11 | LOD for Pixal3D models + visibility ranges + MultiMesh scatter | Decimate models, import LOD on, `visibility_range_end` on scatter, MultiMesh trees | Med | M |
| 12 | Split-screen audio | Own engine as 2D player per player bus with panner; other karts 3D short range; doppler physics step | Med | M |
| 13 | Engine sound layering + adaptive music | 3 RPM loops crossfaded with pitch; AudioStreamInteractive with final-lap faster variant from `make_music.py` | Med | M |
| 14 | Rumble + LED + hotplug | Soft short rumble on bumps/boost, LED in player colour, `joy_connection_changed` re-assigns slots | Med | S |
| 15 | Grass/flowers with wind, stylised water | MultiMesh chunks, no shadows, vertex wind tied to Atmosphere; depth foam water for a lake track | Med | M-L |

Not recommended now: SDFGI/VoxelGI in 2P (cost doubles per viewport), post-process outlines,
camera motion blur (kid comfort), AreaLight3D in race, HDR output (projector), TAA/FSR2 (ghosting).
Optional later: baked LightmapGI per generated track (best quality/cost, but adds a bake step),
stencil X-ray silhouette so the kid always sees his kart, gyro steering (4.7 motion sensors).
