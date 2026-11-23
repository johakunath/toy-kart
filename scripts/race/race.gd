extends Node
## The race scene. Reads the setup from the Game autoload and builds everything at runtime:
## the track, the karts (humans and AI), one camera + HUD per player (split screen for two),
## the countdown, laps and places, catch-up, soft kart bumps, pause and the finish screen.

enum State { COUNTDOWN, RACING, FINISHED }

const KART_SCENE := preload("res://scenes/kart.tscn")
const COUNTDOWN_SECONDS := 3.0
const BUMP_DISTANCE := 1.25
const AI_SKILLS: Array[float] = [0.95, 0.9, 0.86]
## With a kid in the race, each AI kart aims for its own spot around the slowest human:
## two a little ahead, one behind (metres). They wait when far ahead but only speed up a
## little to hold their spot, so a kid who drives well (gas, good line, stars) can pass them,
## and a kid who does nothing ends up behind.
const AI_KID_GAPS: Array[float] = [12.0, 4.0, -14.0]
const AI_KID_MAX_PACE := 1.0
## Bumping into each other is fun: both karts get a small boost (at most every few seconds).
const BUMP_BOOST_SECONDS := 0.4
const BUMP_BOOST_STRENGTH := 0.12
const BUMP_BOOST_COOLDOWN := 2.5
const KID_RUMBLE := 0.7          ## kid pads vibrate a little softer
const TICKLE_RANGE := 45.0       ## metres ahead a tickle bubble looks for a kart
const TICKLE_FLIGHT := 0.55      ## seconds the bubble flies
const BRICK_ROWS := 7            ## rows of bricks per lap
const BRICK_CLEAR := 7.0         ## metres kept free around stars, turbo pads and the start

var track: Track
var racers: Array[Racer] = []
var humans: Array[Racer] = []
var huds: Array[PlayerHud] = []
var state := State.COUNTDOWN
var race_time := 0.0

var _world: Node3D
var _karts: Node3D
var _overlay: CanvasLayer
var _pause_menu: PauseMenu
var _finish_screen: FinishScreen
var _playground: Playground
var _countdown := COUNTDOWN_SECONDS + 1.0
var _countdown_shown := 99
var _finish_delay := -1.0
var _kid_context := false
var _smoke_time := 0.0
var _resets := 0
var _shot_wait := 0.0
var _perf_frames: Array[float] = []
var _bump_ready_at := {}         ## Kart -> race time when it can get the next bump boost
var _ai_item_wait := {}          ## Racer -> seconds until the AI uses its item
var _bubbles: Array[Dictionary] = []  ## tickle bubbles in flight
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if Game.players.is_empty():
		_use_default_setup()
	_build_world()
	_spawn_racers()
	_place_bricks()
	_world.add_child(Roadside.new(track, racers))  # toy buildings and watching toys at the start
	_build_views()
	add_child(CoopHelp.new(track, humans, huds))  # magic rope and gifts between humans
	_build_overlay()
	if Game.mode == Game.Mode.FREE_DRIVE:
		# Rings, the brick jar and "catch Papa": things to do when nobody races.
		_playground = Playground.new()
		_playground.name = "Playground"
		_playground.setup(track, humans, huds)
		_world.add_child(_playground)
	if humans.size() > 1:
		_split_screen_shadows()
	Music.stop(0.6)  # quiet for the countdown; the race tune starts with "Los!"
	if humans.size() > 1:
		# Split screen: each player's own engine plays on their side (left half = left speaker),
		# instead of as a 3D sound that both cameras would hear.
		for racer in humans:
			racer.kart.engine_db_offset = -2.0
			racer.kart.use_own_engine(_player_bus(humans.find(racer), humans.size()))
	_update_places()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

# --- Setup ---------------------------------------------------------------------------------

## Used when the race scene is started directly (F6 in the editor, or the headless smoke test).
func _use_default_setup() -> void:
	if Game.smoke:
		var args := Game.smoke_args
		var count := int(args.get("players", "2"))
		Game.mode = {"free": Game.Mode.FREE_DRIVE, "trial": Game.Mode.TIME_TRIAL}.get(args.get("mode", "race"), Game.Mode.RACE)
		Game.speed_class = clampi(int(args.get("speed", "0")), 0, 2) as Game.SpeedClass
		Game.ai_count = clampi(int(args.get("ai", "3")), 0, Game.MAX_AI)
		Game.team_race = args.get("team", "0") == "1"
		# --cup=1 plays all cup races one after another (--cup_round=N starts at race N, from 0).
		if args.get("cup", "0") == "1" and not Game.cup:
			Game.cup = true
			Game.cup_round = clampi(int(args.get("cup_round", "0")), 0, Game.cup_tracks().size() - 1)
			Game.track = Game.cup_tracks()[Game.cup_round]
		# --control=kid|full|mixed   --input=none|left|right|random (what the kid "does")
		var control: String = args.get("control", "kid")
		for i in count:
			var is_full := control == "full" or (control == "mixed" and i == 1)
			# Full-mode test players are driven by the AI; kid test players by a fake child.
			var source: InputSource
			# "skilled" stands in for a kid who steers well and holds the gas: the AI line driver
			# at the controls, still going through the kid assist.
			if is_full or args.get("input", "none") == "skilled":
				source = AiSource.new()
				source.id = "bot%d" % i
				source.label = "Test %d" % (i + 1)
				(source as AiSource).skill = 1.0
			else:
				source = TestSource.new(args.get("input", "none"), i)
			var driver_index := int(args.get("driver", str(i * 2))) + i * 2 if args.has("driver") else i * 2
			Game.players.append(Game.make_player(source, Game.ControlMode.FULL if is_full else Game.ControlMode.KID, i, driver_index, i))
	else:
		Game.mode = Game.Mode.RACE
		Game.players.append(Game.make_player(KeyboardSource.new(0), Game.ControlMode.FULL, 0, 0, 0))

func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	track = (load(Game.track.scene_path) as PackedScene).instantiate() as Track
	_world.add_child(track)
	_karts = Node3D.new()
	_karts.name = "Karts"
	_world.add_child(_karts)

func _spawn_racers() -> void:
	var configs: Array[PlayerConfig] = Game.players.duplicate()
	# The kid sits on the left: with one kid-mode and one full-mode player, the kid gets the left half.
	if configs.size() == 2 and configs[0].control_mode == Game.ControlMode.FULL and configs[1].control_mode == Game.ControlMode.KID:
		configs.reverse()
	var slot := 0
	for i in configs.size():
		var cfg := configs[i]
		var racer := _make_racer(cfg.kart, cfg.driver, slot)
		racer.is_human = true
		racer.player_index = i
		racer.source = cfg.source
		racer.control_mode = cfg.control_mode as Game.ControlMode
		racer.color = cfg.color()
		racer.display_name = cfg.driver.display_name if cfg.driver else "Spieler %d" % (i + 1)
		racer.assist.kid = cfg.control_mode == Game.ControlMode.KID
		if racer.assist.kid:
			racer.kart.max_spark_tier = 2
			racer.kart.free_start_boost = true
			racer.kart.auto_trick = true
		_wire_rumble(racer)
		if cfg.source is AiSource:
			_wire_ai(cfg.source as AiSource, racer, 0.93)
		racer.kart.set_marker_color(racer.color)
		racer.kart.visual.add_stickers(Game.sticker_ids())
		cfg.source.swallow_held()
		humans.append(racer)
		_kid_context = _kid_context or racer.assist.kid
		slot += 1

	var ai_count := Game.ai_count if Game.mode == Game.Mode.RACE else 0
	if Game.mode == Game.Mode.RACE and Game.team_race:
		ai_count = maxi(ai_count, 1)  # "us against the toys" needs toys
	var ai_drivers := _ai_driver_pool(configs)
	var ai_karts := Game.karts.filter(func(k: KartDef) -> bool: return k.ai_can_use)
	if ai_karts.is_empty():
		ai_karts = Game.karts.duplicate()
	ai_karts.shuffle()
	if Game.cup:
		# The same toys race the whole cup, so their stars add up.
		if Game.cup_ai_drivers.is_empty():
			Game.cup_ai_drivers.assign(ai_drivers)
			Game.cup_ai_karts.assign(ai_karts)
		ai_drivers = Game.cup_ai_drivers
		ai_karts = Game.cup_ai_karts
	var skills := AI_SKILLS.duplicate()
	skills.shuffle()
	for i in ai_count:
		var driver: DriverDef = ai_drivers[i % ai_drivers.size()] if not ai_drivers.is_empty() else null
		var kart_def: KartDef = ai_karts[i % ai_karts.size()] if not ai_karts.is_empty() else null
		var racer := _make_racer(kart_def, driver, slot)
		var ai := AiSource.new()
		_wire_ai(ai, racer, 1.0 if _kid_context else skills[i % skills.size()])
		racer.ai_number = i
		racer.source = ai
		racer.assist.is_ai = true
		racer.kart.auto_trick = true
		racer.kart.brick_bonus = not _kid_context
		racer.color = Color(0.75, 0.78, 0.85)
		racer.display_name = driver.display_name if driver else "Computer %d" % (i + 1)
		racer.kart.engine_db_offset = -9.0
		racer.kart.use_doppler()
		slot += 1
	_wire_personalities()

func _make_racer(kart_def: KartDef, driver: DriverDef, slot: int) -> Racer:
	var racer := Racer.new()
	racer.laps = Game.race_laps()
	var kart := KART_SCENE.instantiate() as Kart
	_karts.add_child(kart)
	kart.setup(kart_def, driver)
	kart.class_factor = Game.SPEED_FACTOR[Game.speed_class]
	kart.place(track.grid_transform(slot))
	racer.kart = kart
	racer.driver = driver
	racer.kart_def = kart_def
	racer.progress = TrackProgress.new(track)
	racer.progress.snap_to(kart.ground_position())
	racer.progress.lap = -1
	racers.append(racer)
	kart.item_picker = _pick_item.bind(racer)
	kart.tickle_thrown.connect(_throw_tickle.bind(racer))
	return racer

# --- Items -------------------------------------------------------------------------------

## The item a racer gets from a star: kids always get good ones, a grown-up ahead of a kid gets
## small ones, everyone else by place (the further back, the better).
func _pick_item(racer: Racer) -> int:
	var ahead_of_kid := false
	if not racer.assist.kid:
		for other in humans:
			if other.assist.kid and other.progress.distance() < racer.progress.distance():
				ahead_of_kid = true
	var behind := float(racer.place - 1) / maxf(racers.size() - 1, 1.0)
	return Items.pick(_rng, racer.assist.kid, ahead_of_kid, behind)

## Teammates in a team race (humans with humans).
func _same_team(a: Racer, b: Racer) -> bool:
	return Game.team_race and a.is_human and b.is_human

## A tickle bubble flies to the nearest kart ahead. Kid-mode players are never a target.
func _throw_tickle(thrower: Racer) -> void:
	var target: Racer = null
	var best := TICKLE_RANGE
	for other in racers:
		if other == thrower or other.finished or other.assist.kid or _same_team(thrower, other):
			continue
		var gap := other.progress.distance() - thrower.progress.distance()
		if gap > 0.5 and gap < best:
			best = gap
			target = other
	var bubble := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.56, 0.78, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.7)
	mat.emission_energy_multiplier = 1.5
	mat.rim_enabled = true
	mat.rim = 1.0
	mesh.material = mat
	bubble.mesh = mesh
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(bubble)
	var start := thrower.kart.ground_position() + Vector3(0, 1.2, 0)
	bubble.global_position = start
	_bubbles.append({"node": bubble, "from": start, "target": target, "t": 0.0,
		"forward": thrower.kart.forward()})
	UiKit.play(self, "pop", -4.0)

func _fly_bubbles(delta: float) -> void:
	for i in range(_bubbles.size() - 1, -1, -1):
		var b: Dictionary = _bubbles[i]
		b["t"] = float(b["t"]) + delta / TICKLE_FLIGHT
		var t: float = b["t"]
		var node: MeshInstance3D = b["node"]
		var target: Racer = b["target"]
		var to: Vector3
		if target:
			to = target.kart.ground_position() + Vector3(0, 0.8, 0)
		else:
			to = (b["from"] as Vector3) + (b["forward"] as Vector3) * 20.0
		var pos := (b["from"] as Vector3).lerp(to, minf(t, 1.0))
		pos.y += sin(minf(t, 1.0) * PI) * 1.5
		node.global_position = pos
		node.scale = Vector3.ONE * (1.0 + 0.15 * sin(t * 25.0))
		if t >= 1.0:
			if target and not target.finished:
				target.kart.wobble()
			node.queue_free()
			_bubbles.remove_at(i)

# --- Bricks ------------------------------------------------------------------------------

## Rows of toy bricks along the racing line, kept clear of stars, turbo pads and the start.
func _place_bricks() -> void:
	if Game.mode == Game.Mode.TIME_TRIAL:
		return
	var taken: Array[float] = [0.0, track.length]
	for group_name in ["Stars", "BoostPads"]:
		var group := track.get_node_or_null(group_name)
		if group == null:
			continue
		for child in group.get_children():
			taken.append(track.s_at(track.closest_index((child as Node3D).global_position)))
	var holder := Node3D.new()
	holder.name = "Bricks"
	_world.add_child(holder)
	var patterns := [[-1.6, 0.0, 1.6], [-1.2, -0.4, 0.4, 1.2], [0.8, 1.6], [-1.6, -0.8]]
	var number := 0
	for row in BRICK_ROWS:
		var s := (row + 0.5) * track.length / BRICK_ROWS
		var clear := true
		for t in taken:
			if absf(s - t) < BRICK_CLEAR:
				clear = false
		if not clear:
			s += BRICK_CLEAR * 1.5
			for t in taken:
				if absf(s - t) < BRICK_CLEAR:
					clear = false
			if not clear:
				continue
			clear = true
		for lateral: float in patterns[row % patterns.size()]:
			var brick := Brick.new()
			brick.name = "Brick%d" % number
			number += 1
			holder.add_child(brick)
			brick.global_transform = track.transform_at(s, lateral)

## An audio bus per player half, panned to that side, feeding the Engines bus.
func _player_bus(index: int, count: int) -> StringName:
	var bus_name := StringName("Player%d" % (index + 1))
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, bus_name)
		AudioServer.set_bus_send(bus, &"Engines")
		AudioServer.add_bus_effect(bus, AudioEffectPanner.new())
	var panner := AudioServer.get_bus_effect(bus, 0) as AudioEffectPanner
	panner.pan = 0.0 if count < 2 else lerpf(-0.6, 0.6, float(index) / (count - 1))
	return bus_name

## Split screen draws the world twice: the sun's shadows get 2 splits and a shorter reach,
## which costs much less and is hard to tell apart on a half screen.
func _split_screen_shadows() -> void:
	var sun := _world.find_child("Sun", true, false) as DirectionalLight3D
	if sun:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 70.0

## Controller vibration for a human on a gamepad (off switch on the options page).
func _wire_rumble(racer: Racer) -> void:
	var pad := racer.source as PadSource
	if pad == null:
		return
	var device := pad.device
	var scale := KID_RUMBLE if racer.assist.kid else 1.0
	racer.kart.rumble_requested.connect(func(weak: float, strong: float, seconds: float) -> void:
		if Game.rumble_on and state != State.FINISHED:
			Input.start_joy_vibration(device, clampf(weak * scale, 0.0, 1.0), clampf(strong * scale, 0.0, 1.0), seconds))

func _wire_ai(ai: AiSource, racer: Racer, skill: float) -> void:
	# The AI gets the kart and progress, not the racer itself: no reference cycle.
	ai.kart = racer.kart
	ai.progress = racer.progress
	ai.track = track
	ai.skill = skill
	ai.lane = randf_range(-1.5, 1.5)

## AI karts drive with their toy's personality (DriverDef "AI personality"). They watch the
## kids (friendly honks, giving way, cheers) and the others (show-offs after an overtake).
func _wire_personalities() -> void:
	for racer in racers:
		var ai := racer.source as AiSource
		if racer.is_human or ai == null:
			continue
		var kids: Array[TrackProgress] = []
		var rivals: Array[TrackProgress] = []
		for other in racers:
			if other != racer:
				if other.is_human and other.assist.kid:
					kids.append(other.progress)
				else:
					rivals.append(other.progress)
		ai.set_personality(racer.driver, kids, rivals, racer.laps)

## AI karts get 3D characters the humans did not pick; the toys stay with the players.
func _ai_driver_pool(configs: Array[PlayerConfig]) -> Array[DriverDef]:
	var taken := {}
	for cfg in configs:
		if cfg.driver:
			taken[cfg.driver.id] = true
	var pool: Array[DriverDef] = []
	for d in Game.drivers:
		if d.type == DriverDef.Type.MODEL and not taken.has(d.id):
			pool.append(d)
	if pool.is_empty():
		pool = Game.drivers.duplicate()
	pool.shuffle()
	return pool

func _build_views() -> void:
	var screens := HBoxContainer.new()
	screens.name = "Screens"
	screens.set_anchors_preset(Control.PRESET_FULL_RECT)
	screens.add_theme_constant_override("separation", 0)
	add_child(screens)
	var split := humans.size() > 1
	for racer in humans:
		var view := Control.new()
		view.name = "View%d" % (racer.player_index + 1)
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		view.clip_contents = true
		screens.add_child(view)

		var container := SubViewportContainer.new()
		container.stretch = true
		container.set_anchors_preset(Control.PRESET_FULL_RECT)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(container)
		var viewport := SubViewport.new()
		# MSAA for edges plus SMAA for thin lines; no TAA (it smears moving karts).
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
		viewport.audio_listener_enable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)

		var camera := ChaseCamera.new()
		camera.calm = racer.control_mode == Game.ControlMode.KID
		if split:
			camera.use_split_screen_setup()
		viewport.add_child(camera)
		camera.attach(racer.kart)
		camera.current = true
		var atmosphere := track.get_node_or_null("Atmosphere") as Atmosphere
		if atmosphere:
			camera.add_child(atmosphere.make_camera_weather())

		var hud := PlayerHud.new()
		view.add_child(hud)
		hud.setup(racer, Game.mode, racers.size(), racers)
		huds.append(hud)

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 10
	add_child(_overlay)
	_pause_menu = PauseMenu.new()
	_overlay.add_child(_pause_menu)
	_finish_screen = FinishScreen.new()
	_overlay.add_child(_finish_screen)

# --- Main loop -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.COUNTDOWN:
		_tick_countdown(delta)
	elif state == State.RACING:
		race_time += delta

	var racing := state != State.COUNTDOWN
	for racer in racers:
		racer.tick(track, racing, delta)
		if racer.source is AiSource and racer.kart.has_item:
			# The AI waits a moment like a person would, then uses its item.
			if not _ai_item_wait.has(racer):
				_ai_item_wait[racer] = _rng.randf_range(0.6, 2.5)
			_ai_item_wait[racer] -= delta
			if _ai_item_wait[racer] <= 0.0:
				_ai_item_wait.erase(racer)
				racer.kart.use_item()
		if racer.assist.wants_reset:
			_reset_racer(racer)
		if not track.forks.is_empty():
			var in_lane := absf(racer.progress.lateral) > track.half_width + 1.5
			if in_lane and not racer._in_side_lane:
				racer.side_lanes += 1
			racer._in_side_lane = in_lane

	if racing:
		_check_laps()
		_update_places()
		_update_pacing(delta)
		_soft_bumps()

	if _finish_delay > 0.0:
		_finish_delay -= delta
		if _finish_delay <= 0.0:
			_show_finish_screen()

	if Game.smoke:
		_smoke_tick(delta)

func _process(delta: float) -> void:
	_fly_bubbles(delta)
	for hud in huds:
		hud.refresh(race_time, delta)
	if Game.smoke and Game.smoke_args.has("perf") and state == State.RACING:
		_perf_frames.append(delta)

func _tick_countdown(delta: float) -> void:
	_countdown -= delta
	var shown := int(ceil(_countdown))
	if shown != _countdown_shown and shown <= int(COUNTDOWN_SECONDS):
		_countdown_shown = shown
		if shown > 0:
			for hud in huds:
				hud.show_message(str(shown), 0.9)
			UiKit.play(self, "beep_low")
	if _countdown <= 0.0:
		state = State.RACING
		for racer in racers:
			racer.kart.frozen = false
			racer.assist.clear_timers(racer)
		for hud in huds:
			hud.show_message("Los!", 1.0, 230, UiKit.SUN)
		UiKit.play(self, "beep_high")
		Music.play("race")

func _check_laps() -> void:
	if Game.mode == Game.Mode.FREE_DRIVE:
		return
	for racer in racers:
		if racer.finished:
			continue
		var laps_done := racer.progress.lap
		if laps_done > racer.lap_times.size():
			racer.note_lap(race_time)
			if laps_done >= Game.race_laps():
				_finish_racer(racer)
			elif racer.is_human and laps_done == Game.race_laps() - 1:
				huds[humans.find(racer)].show_message("Letzte Runde!", 1.6, 120, UiKit.SUN)
				Music.hurry()
				UiKit.play(self, "select")

func _finish_racer(racer: Racer) -> void:
	racer.finished = true
	racer.finish_time = race_time
	_update_places()
	if racer.is_human:
		var hud := huds[humans.find(racer)]
		hud.show_message("Ziel!", 0.0, 230, UiKit.SUN)
		UiKit.play(self, "fanfare", -4.0)
		# The kart keeps rolling on autopilot while the other player finishes.
		var auto := AiSource.new()
		_wire_ai(auto, racer, 0.6)
		racer.source = auto
		racer.assist.kid = false
		racer.assist.is_ai = true
		racer.kart.auto_trick = true
		racer.kart.catchup = 0.0
		if racer.kart.visual.driver:
			racer.kart.visual.driver.set_cheering(true)
		var all_done := true
		for h in humans:
			all_done = all_done and h.finished
		if all_done:
			_finish_delay = 2.0
	else:
		racer.kart.pace = 0.6

func _update_places() -> void:
	var order := racers.duplicate()
	order.sort_custom(func(a: Racer, b: Racer) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_time < b.finish_time
		return a.progress.distance() > b.progress.distance())
	for i in order.size():
		(order[i] as Racer).place = i + 1

## Keeps the field together: a kid who is behind the other human gets a quiet boost,
## and AI karts wait a little when they are far ahead of the slowest human.
func _update_pacing(delta: float) -> void:
	for racer in humans:
		if racer.finished:
			continue
		var target := 0.0
		# Anyone behind the leading AI gets a little extra top speed to catch up.
		var ai_lead := -INF
		for other in racers:
			if not other.is_human:
				ai_lead = maxf(ai_lead, other.progress.distance())
		if ai_lead > -INF:
			target = clampf((ai_lead - racer.progress.distance() - 8.0) / 40.0, 0.0, 1.0) * 0.12
		if racer.assist.kid and humans.size() > 1:
			for other in humans:
				if other == racer:
					continue
				var gap := 60.0 if other.finished else other.progress.distance() - racer.progress.distance()
				target = maxf(target, clampf((gap - 6.0) / 35.0, 0.0, 1.0) * 0.3)
		racer.kart.catchup = lerpf(racer.kart.catchup, target, delta * 1.5)

	var slowest := INF
	var fastest := -INF
	for racer in humans:
		if not racer.finished:
			slowest = minf(slowest, racer.progress.distance())
			fastest = maxf(fastest, racer.progress.distance())
	for racer in racers:
		if racer.is_human or racer.finished:
			continue
		var pace := 1.0
		if slowest != INF:
			var lead := racer.progress.distance() - slowest
			var behind := fastest - racer.progress.distance()
			if _kid_context:
				var target_gap := AI_KID_GAPS[racer.ai_number % AI_KID_GAPS.size()]
				pace = clampf(1.0 + (target_gap - lead) / 40.0, 0.6, AI_KID_MAX_PACE)
			else:
				# Against grown-ups: a leading AI eases off early, a trailing one pushes a little.
				if lead > 8.0:
					pace = lerpf(1.0, 0.8, clampf((lead - 8.0) / 40.0, 0.0, 1.0))
				elif behind > 30.0:
					pace = lerpf(1.0, 1.06, clampf((behind - 30.0) / 60.0, 0.0, 1.0))
		racer.kart.pace = lerpf(racer.kart.pace, pace, delta * 1.5)
		var ai := racer.source as AiSource
		if ai:
			ai.slow = 1.0 - racer.kart.pace

## Karts push each other apart gently instead of colliding hard.
func _soft_bumps() -> void:
	for i in racers.size():
		for j in range(i + 1, racers.size()):
			var a := racers[i].kart
			var b := racers[j].kart
			var d := b.sphere.global_position - a.sphere.global_position
			d.y = 0.0
			var dist := d.length()
			if dist >= BUMP_DISTANCE or dist < 0.001:
				continue
			var n := d / dist
			var closing := -(b.sphere.linear_velocity - a.sphere.linear_velocity).dot(n)
			var dv := (BUMP_DISTANCE - dist) * 6.0 + maxf(closing, 0.0) * 0.5
			# A kid's kart is hardly moved: the other kart takes most of the push.
			var share_a := 0.5
			if racers[i].assist.kid != racers[j].assist.kid:
				share_a = 0.2 if racers[i].assist.kid else 0.8
			a.push(-n * dv * share_a)
			b.push(n * dv * (1.0 - share_a))
			if closing > 1.5:
				a.bumped.emit(clampf(closing / 10.0, 0.0, 0.6))
				b.bumped.emit(clampf(closing / 10.0, 0.0, 0.6))
				if racers[i].is_human or racers[j].is_human:
					_bump_boost(a)
					_bump_boost(b)

func _bump_boost(kart: Kart) -> void:
	if race_time < float(_bump_ready_at.get(kart, 0.0)):
		return
	_bump_ready_at[kart] = race_time + BUMP_BOOST_COOLDOWN
	kart.rumble_requested.emit(0.4, 0.3, 0.1)
	if not kart.is_boosting():
		kart.boost(BUMP_BOOST_SECONDS, BUMP_BOOST_STRENGTH)

func _reset_racer(racer: Racer) -> void:
	var safe := track.half_width - 1.3
	var lateral := clampf(racer.progress.lateral, -safe, safe)
	if absf(racer.progress.lateral) > track.half_width:
		lateral = 0.0
	racer.kart.place(track.transform_at(racer.progress.s(), lateral))
	# The toy helicopter lowers the kart onto the road and flies off.
	var heli := RescueHeli.new()
	heli.name = "RescueHeli"
	_world.add_child(heli)
	heli.carry(racer.kart)
	racer.assist.clear_timers(racer)
	if racer.kart.visual.driver:
		racer.kart.visual.driver.hop(1.5)
	if racer.is_human:
		UiKit.play(self, "pop")
	_resets += 1

# --- Pause and finish ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var pause_pressed := false
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		pause_pressed = true
	var button := event as InputEventJoypadButton
	if button and button.pressed and button.button_index == JOY_BUTTON_START:
		pause_pressed = true
	if pause_pressed and state != State.FINISHED and not _pause_menu.visible:
		_pause_menu.open()
		get_viewport().set_input_as_handled()

## A player's controller went away (battery, cable): pause so nobody loses the race over it.
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected or state == State.FINISHED or _pause_menu.visible:
		return
	for racer in humans:
		var pad := racer.source as PadSource
		if pad and pad.device == device:
			_pause_menu.open()
			return

func _show_finish_screen() -> void:
	state = State.FINISHED
	Music.stop(0.8)
	for hud in huds:
		hud.hide_message()
	var record := false
	if Game.mode == Game.Mode.TIME_TRIAL and not humans.is_empty():
		record = Game.submit_time(Game.speed_class, humans[0].finish_time)
	var picked := 0
	for racer in humans:
		picked += racer.kart.bricks_picked
	if picked > 0:
		Game.add_family_bricks(picked)
	Game.unlock_sticker()  # a present after every race (the finish screen opens it)
	if Game.cup:
		var order: Array[Racer] = racers.duplicate()
		order.sort_custom(func(a: Racer, b: Racer) -> bool: return a.place < b.place)
		Game.award_cup_stars(order)
	_finish_screen.open(racers, humans, record, picked, Game.team_race and Game.mode == Game.Mode.RACE)

# --- Headless smoke test (tools/check.ps1) -------------------------------------------------

func _smoke_tick(delta: float) -> void:
	_smoke_time += delta
	var limit := float(Game.smoke_args.get("seconds", "240"))
	# Dev helper: "--boost_at=S" fires a boost for the first player S seconds in (for screenshots).
	if Game.smoke_args.has("boost_at") and _smoke_time - delta < float(Game.smoke_args["boost_at"]) and _smoke_time >= float(Game.smoke_args["boost_at"]):
		humans[0].kart.boost(1.6, 0.4)
	# Dev helper: "--rescue_at=S" rescues the first player S seconds in (helicopter screenshots).
	if Game.smoke_args.has("rescue_at") and _smoke_time - delta < float(Game.smoke_args["rescue_at"]) and _smoke_time >= float(Game.smoke_args["rescue_at"]):
		_reset_racer(humans[0])
	if Game.smoke_args.has("pause_shot") and _smoke_time > 5.0 and not _pause_menu.visible:
		# Dev helper: open the pause menu and save a picture of it.
		_pause_menu.open()
		await get_tree().create_timer(0.6, true).timeout
		get_viewport().get_texture().get_image().save_png(Game.smoke_args["pause_shot"])
		Game.quit_clean(0)
		return
	var shot_now := false
	if Game.smoke_args.has("shot"):
		if Game.smoke_args.get("shot_at", "8") == "finish":
			_shot_wait = _shot_wait + delta if state == State.FINISHED else 0.0
			shot_now = _shot_wait > 3.2
		else:
			shot_now = _smoke_time >= float(Game.smoke_args.get("shot_at", "8"))
	if shot_now:
		# Dev helper: save a picture of the running race, then quit.
		get_viewport().get_texture().get_image().save_png(Game.smoke_args["shot"])
		set_physics_process(false)
		Game.quit_clean(0)
		return
	if Game.smoke_args.has("trace") and int(_smoke_time * 60.0) % 6 == 0:
		# Dev helper: ten lines per second about the first player, to judge steering smoothness.
		var from := float(Game.smoke_args["trace"])
		if _smoke_time >= from and _smoke_time < from + 6.0:
			var r := humans[0]
			print("TRACE t=%.1f s=%.0f lat=%+.2f head=%+.2f v=%.1f steer=%+.2f y=%.2f ground=%s" % [_smoke_time, r.progress.s(), r.progress.lateral, r.progress.heading_error, r.kart.speed(), r.kart.intent.steer, r.kart.sphere.global_position.y, r.kart.colliding])
	var done := state == State.FINISHED and not Game.smoke_args.has("shot")
	if Game.mode == Game.Mode.FREE_DRIVE:
		done = _smoke_time >= minf(limit, 25.0)
	if not done and _smoke_time < limit:
		return
	var ok := true
	print("SMOKE track=%s mode=%s%s speed=%s time=%.1fs resets=%d" % [Game.track.id, Game.MODE_NAMES[Game.mode], " (Team)" if Game.team_race else "", Game.SPEED_NAMES[Game.speed_class], _smoke_time, _resets])
	for racer in racers:
		print("SMOKE   %-12s human=%s place=%d laps=%d finished=%s time=%.1f dist=%.0fm wall_hits=%d boosted=%.0f%% tricks=%d bricks=%d wobbles=%d lanes=%d" % [
			racer.display_name, racer.is_human, racer.place, maxi(racer.progress.lap, 0), racer.finished,
			racer.finish_time, racer.progress.distance(), racer.kart.wall_hits,
			100.0 * racer.kart.boost_time / maxf(racer.finish_time if racer.finished else _smoke_time, 0.1),
			racer.kart.tricks, racer.kart.bricks_picked, racer.kart.wobbles, racer.side_lanes])
		if not racer.is_human and racer.source is AiSource:
			print("SMOKE     mood: %s" % (racer.source as AiSource).mood_report())
		if racer.is_human:
			if Game.mode == Game.Mode.FREE_DRIVE:
				ok = ok and racer.progress.distance() > 60.0
			else:
				ok = ok and racer.finished
	# The kid mode promise: at Kid speed nobody needs a rescue.
	if Game.speed_class == Game.SpeedClass.KID and _resets > 0:
		print("SMOKE   a kart needed a reset at Kid speed")
		ok = false
	var coop := get_node_or_null("CoopHelp") as CoopHelp
	if coop:
		ok = coop.smoke_report() and ok
	if not _perf_frames.is_empty():
		# Frame rate report for "-- --smoke --perf" (run with a window and --disable-vsync).
		_perf_frames.sort()
		var total := 0.0
		for f in _perf_frames:
			total += f
		var worst := _perf_frames[int(_perf_frames.size() * 0.99)]
		var size := get_window().size
		print("PERF %s  %dx%d  players=%d  avg=%.0f fps  1%%-low=%.0f fps  frames=%d" % [
			RenderingServer.get_video_adapter_name(), size.x, size.y, humans.size(),
			_perf_frames.size() / total, 1.0 / worst, _perf_frames.size()])
	if _playground:
		print("SMOKE   " + _playground.summary())
		if Game.smoke_args.get("input", "") == "skilled":
			ok = ok and _playground.rings_done.values().max() > 0  # a good driver gets rings
	if Game.cup and state == State.FINISHED:
		var stars := []
		for racer in racers:
			stars.append("%s=%d" % [racer.display_name, int(Game.cup_stars.get(racer.cup_key(), 0))])
		print("SMOKE   cup race %d/%d stars: %s" % [Game.cup_round + 1, Game.cup_tracks().size(), ", ".join(stars)])
		if ok and not Game.is_last_cup_race():
			set_physics_process(false)
			Game.next_cup_race()
			return
	print("SMOKE RESULT: %s" % ("PASS" if ok else "FAIL"))
	set_physics_process(false)
	Game.quit_clean(0 if ok else 1)
