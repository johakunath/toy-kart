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
var _countdown := COUNTDOWN_SECONDS + 1.0
var _countdown_shown := 99
var _finish_delay := -1.0
var _kid_context := false
var _smoke_time := 0.0
var _resets := 0
var _shot_wait := 0.0
var _perf_frames: Array[float] = []

func _ready() -> void:
	if Game.players.is_empty():
		_use_default_setup()
	_build_world()
	_spawn_racers()
	_build_views()
	_build_overlay()
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
		if cfg.source is AiSource:
			_wire_ai(cfg.source as AiSource, racer, 0.93)
		racer.kart.set_marker_color(racer.color)
		cfg.source.swallow_held()
		humans.append(racer)
		_kid_context = _kid_context or racer.assist.kid
		slot += 1

	var ai_count := Game.ai_count if Game.mode == Game.Mode.RACE else 0
	var ai_drivers := _ai_driver_pool(configs)
	var ai_karts := Game.karts.filter(func(k: KartDef) -> bool: return k.ai_can_use)
	if ai_karts.is_empty():
		ai_karts = Game.karts.duplicate()
	ai_karts.shuffle()
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
		racer.color = Color(0.75, 0.78, 0.85)
		racer.display_name = driver.display_name if driver else "Computer %d" % (i + 1)
		racer.kart.engine_db_offset = -9.0
		slot += 1

func _make_racer(kart_def: KartDef, driver: DriverDef, slot: int) -> Racer:
	var racer := Racer.new()
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
	return racer

func _wire_ai(ai: AiSource, racer: Racer, skill: float) -> void:
	# The AI gets the kart and progress, not the racer itself: no reference cycle.
	ai.kart = racer.kart
	ai.progress = racer.progress
	ai.track = track
	ai.skill = skill
	ai.lane = randf_range(-1.5, 1.5)

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
		viewport.msaa_3d = Viewport.MSAA_2X
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
		hud.setup(racer, Game.mode, racers.size())
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
			racer.kart.use_item()
		if racer.assist.wants_reset:
			_reset_racer(racer)

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

func _check_laps() -> void:
	if Game.mode == Game.Mode.FREE_DRIVE:
		return
	for racer in racers:
		if racer.finished:
			continue
		var laps_done := racer.progress.lap
		if laps_done > racer.lap_times.size():
			racer.note_lap(race_time)
			if laps_done >= Game.LAPS:
				_finish_racer(racer)
			elif racer.is_human and laps_done == Game.LAPS - 1:
				huds[humans.find(racer)].show_message("Letzte Runde!", 1.6, 120, UiKit.SUN)
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
			a.push(-n * dv * 0.5)
			b.push(n * dv * 0.5)
			if closing > 2.5:
				a.bumped.emit(clampf(closing / 10.0, 0.0, 0.6))
				b.bumped.emit(clampf(closing / 10.0, 0.0, 0.6))

func _reset_racer(racer: Racer) -> void:
	var safe := track.half_width - 1.3
	var lateral := clampf(racer.progress.lateral, -safe, safe)
	if absf(racer.progress.lateral) > track.half_width:
		lateral = 0.0
	racer.kart.place(track.transform_at(racer.progress.s(), lateral))
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
	for hud in huds:
		hud.hide_message()
	var record := false
	if Game.mode == Game.Mode.TIME_TRIAL and not humans.is_empty():
		record = Game.submit_time(Game.speed_class, humans[0].finish_time)
	_finish_screen.open(racers, humans, record)

# --- Headless smoke test (tools/check.ps1) -------------------------------------------------

func _smoke_tick(delta: float) -> void:
	_smoke_time += delta
	var limit := float(Game.smoke_args.get("seconds", "240"))
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
			print("TRACE t=%.1f s=%.0f lat=%+.2f head=%+.2f v=%.1f steer=%+.2f" % [_smoke_time, r.progress.s(), r.progress.lateral, r.progress.heading_error, r.kart.speed(), r.kart.intent.steer])
	var done := state == State.FINISHED and not Game.smoke_args.has("shot")
	if Game.mode == Game.Mode.FREE_DRIVE:
		done = _smoke_time >= minf(limit, 25.0)
	if not done and _smoke_time < limit:
		return
	var ok := true
	print("SMOKE track=%s mode=%s speed=%s time=%.1fs resets=%d" % [Game.track.id, Game.MODE_NAMES[Game.mode], Game.SPEED_NAMES[Game.speed_class], _smoke_time, _resets])
	for racer in racers:
		print("SMOKE   %-12s human=%s place=%d laps=%d finished=%s time=%.1f dist=%.0fm wall_hits=%d" % [
			racer.display_name, racer.is_human, racer.place, maxi(racer.progress.lap, 0), racer.finished,
			racer.finish_time, racer.progress.distance(), racer.kart.wall_hits])
		if racer.is_human:
			if Game.mode == Game.Mode.FREE_DRIVE:
				ok = ok and racer.progress.distance() > 60.0
			else:
				ok = ok and racer.finished
	# The kid mode promise: at Kid speed nobody needs a rescue.
	if Game.speed_class == Game.SpeedClass.KID and _resets > 0:
		print("SMOKE   a kart needed a reset at Kid speed")
		ok = false
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
	print("SMOKE RESULT: %s" % ("PASS" if ok else "FAIL"))
	set_physics_process(false)
	Game.quit_clean(0 if ok else 1)
