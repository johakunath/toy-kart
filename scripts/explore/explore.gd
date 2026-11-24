extends Node
## The "Entdecken" mode: drive freely through our living room at toy scale and find 8 lost
## things. Calm and finite: no timer, no score, no racing line. Toy friends ask for their
## things with picture bubbles; carry those to them. When all 8 are in the Fundkiste the room
## gets dark, the toys fall asleep, the karts park in a row, "Gute Nacht", back to the menu.
##
## The world is scenes/worlds/wohnzimmer_offen.tscn (tools/build_open_room.gd). The input
## chain is the same as in a race: InputSource -> Intent -> OpenAssist -> Kart.

enum State { PLAYING, ENDING, NIGHT }

const WORLD := "res://scenes/worlds/wohnzimmer_offen.tscn"
const KART_SCENE := preload("res://scenes/kart.tscn")
const PICK_RADIUS := 3.4         ## metres from a thing (flat) to pick it up
const GIVE_RADIUS := 5.0         ## metres from a friend's edge to hand over its thing
const EXCITED_RADIUS := 30.0     ## a friend's bubble bounces when its thing comes this close
const BUMP_DISTANCE := 1.25
const KID_RUMBLE := 0.7
## Bedtime, seconds after the last find: lights dim, toys sleep, karts park, "Gute Nacht".
const DIM_AT := 1.6
const PARK_AT := 3.2
const NIGHT_AT := 6.0

var world: Node3D
var map := OpenMap.new()
var explorers: Array[Explorer] = []
var things: Array[LostThing] = []
var friends := {}                ## id -> ToyFriend
var state := State.PLAYING
var found := 0

var _views: Array[ChaseCamera] = []
var _box: FindBox
var _night: GoodNight
var _pause: PauseMenu
var _fields := {}                ## LostThing or ToyFriend -> PackedInt32Array
var _end_time := -1.0
var _time := 0.0
var _resets := 0
var _night_time := 0.0
var _shot_done := false
var _perf_frames: Array[float] = []

func _ready() -> void:
	Game.mode = Game.Mode.EXPLORE
	if Game.players.is_empty():
		_use_default_setup()
	world = (load(WORLD) as PackedScene).instantiate() as Node3D
	add_child(world)
	_spawn_things()
	_spawn_explorers()
	_build_views()
	_build_overlay()
	if Game.smoke and Game.smoke_args.get("top", "0") == "1":
		_top_view()
	if explorers.size() > 1:
		var sun := world.find_child("Sun", true, false) as DirectionalLight3D
		if sun:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 70.0
		for e in explorers:
			e.kart.engine_db_offset = -2.0
			e.kart.use_own_engine(_player_bus(e.player_index, explorers.size()))
	Music.play("menu")
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

# --- Setup ---------------------------------------------------------------------------------

## Started directly (editor F6 or the headless checks): players from the command line.
##   --players=1|2  --control=kid|full|mixed  --input=none|left|right|gas|random|skilled
func _use_default_setup() -> void:
	var args := Game.smoke_args
	var count := int(args.get("players", "2"))
	Game.speed_class = clampi(int(args.get("speed", "0")), 0, 2) as Game.SpeedClass
	var control: String = args.get("control", "kid")
	for i in count:
		var is_full := control == "full" or (control == "mixed" and i == 1)
		var source: InputSource
		if is_full or args.get("input", "none") == "skilled":
			source = ExploreBot.new(i)
		elif Game.smoke or args.has("input"):
			source = TestSource.new(args.get("input", "none"), i)
		else:
			source = KeyboardSource.new(i)
		var driver_index := int(args.get("driver", "0")) + i * 2 if args.has("driver") else i * 2
		Game.players.append(Game.make_player(source, Game.ControlMode.FULL if is_full else Game.ControlMode.KID, i, driver_index, i))

func _spawn_things() -> void:
	var holder := Node3D.new()
	holder.name = "Things"
	world.add_child(holder)
	for marker in world.get_node("Finds").get_children():
		var m := marker as Marker3D
		var thing := LostThing.new()
		thing.setup(m.name, str(m.get_meta("for", "")))
		thing.position = m.position
		holder.add_child(thing)
		things.append(thing)
	for marker in world.get_node("Friends").get_children():
		var m := marker as Marker3D
		var wants := ""
		for thing in things:
			if thing.for_friend == String(m.name):
				wants = thing.id
		var friend := ToyFriend.new()
		friend.setup(m.name, str(m.get_meta("model")), float(m.get_meta("height")), wants)
		friend.transform = m.transform
		holder.add_child(friend)
		friends[String(m.name)] = friend

func _spawn_explorers() -> void:
	var karts := Node3D.new()
	karts.name = "Karts"
	world.add_child(karts)
	for i in Game.players.size():
		var cfg := Game.players[i]
		var e := Explorer.new()
		var kart := KART_SCENE.instantiate() as Kart
		karts.add_child(kart)
		kart.setup(cfg.kart, cfg.driver)
		kart.class_factor = Game.SPEED_FACTOR[Game.speed_class]
		var start := world.get_node_or_null("Spots/Start%d" % i) as Marker3D
		var xform := start.global_transform if start else Transform3D(Basis(Vector3.UP, PI), Vector3(i * 6.0, 0, 40.0))
		kart.place(xform)
		kart.frozen = false  # no countdown: he never has to wait
		e.kart = kart
		e.source = cfg.source
		e.control_mode = cfg.control_mode
		e.player_index = i
		e.color = cfg.color()
		e.display_name = cfg.driver.display_name if cfg.driver else "Spieler %d" % (i + 1)
		e.assist.kid = cfg.control_mode == Game.ControlMode.KID
		e.assist.map = map
		if e.assist.kid:
			kart.max_spark_tier = 2
			kart.auto_trick = true
		var bot := e.source as ExploreBot
		if bot:
			bot.kart = kart
		kart.set_marker_color(e.color)
		kart.visual.add_stickers(Game.sticker_ids())
		if not (Game.smoke and Game.smoke_args.get("xray", "1") == "0"):
			XRay.apply(kart.visual, i, e.color)  # see his kart under the sofa
		_wire_rumble(e)
		cfg.source.swallow_held()
		explorers.append(e)

func _wire_rumble(e: Explorer) -> void:
	var pad := e.source as PadSource
	if pad == null:
		return
	var device := pad.device
	var scale := KID_RUMBLE if e.assist.kid else 1.0
	e.kart.rumble_requested.connect(func(weak: float, strong: float, seconds: float) -> void:
		if Game.rumble_on and state == State.PLAYING:
			Input.start_joy_vibration(device, clampf(weak * scale, 0.0, 1.0), clampf(strong * scale, 0.0, 1.0), seconds))

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

func _build_views() -> void:
	var screens := HBoxContainer.new()
	screens.name = "Screens"
	screens.set_anchors_preset(Control.PRESET_FULL_RECT)
	screens.add_theme_constant_override("separation", 0)
	add_child(screens)
	var split := explorers.size() > 1
	for e in explorers:
		var view := Control.new()
		view.name = "View%d" % (e.player_index + 1)
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
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
		viewport.audio_listener_enable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		var camera := ChaseCamera.new()
		camera.calm = e.assist.kid
		if split:
			camera.use_split_screen_setup()
		viewport.add_child(camera)
		camera.attach(e.kart)
		camera.cull_mask &= ~XRay.others_mask(e.player_index)
		camera.current = true
		var atmosphere := world.get_node_or_null("Atmosphere") as Atmosphere
		if atmosphere:
			camera.add_child(atmosphere.make_camera_weather())
		_views.append(camera)

## Dev helper "--top=1": the first player's screen looks straight down on the whole room
## (windows on the left, hall door on the right), for checking the layout.
func _top_view() -> void:
	var viewport := _views[0].get_parent() as SubViewport
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 96.0
	camera.far = 1000.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0, 300, 0), Vector3.ZERO, Vector3(1, 0, 0))
	camera.current = true

func _build_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	_box = FindBox.new()
	overlay.add_child(_box)
	_night = GoodNight.new()
	overlay.add_child(_night)
	_pause = PauseMenu.new()
	overlay.add_child(_pause)

# --- Main loop -----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not map.is_ready():
		_build_map()
	_time += delta
	if state == State.PLAYING:
		for e in explorers:
			var guide := _guide(e)
			e.assist.guide = guide
			var bot := e.source as ExploreBot
			if bot:
				bot.guide = guide
			e.tick(delta)
			if e.assist.wants_reset:
				_rescue(e)
		_check_pickups()
		_check_gifts()
		_soft_bumps()
	else:
		_tick_ending(delta)
	if Game.smoke:
		_smoke_tick(delta)

func _process(delta: float) -> void:
	if Game.smoke and Game.smoke_args.has("perf") and state == State.PLAYING:
		_perf_frames.append(delta)

func _build_map() -> void:
	var lo: Vector2 = world.get_meta("room_lo", Vector2(-50, -80))
	var hi: Vector2 = world.get_meta("room_hi", Vector2(50, 80))
	map.build(world.get_world_3d().direct_space_state, lo, hi)
	for thing in things:
		_fields[thing] = map.field_to(thing.global_position)
	for id: String in friends:
		var friend: ToyFriend = friends[id]
		_fields[friend] = map.field_to(friend.global_position + friend.global_basis.z * (friend.radius() + 2.0))

## Which way to the next thing for this player: the friend while carrying, otherwise the
## nearest thing nobody has found or picked up yet (by the way round the furniture).
func _guide(e: Explorer) -> Vector3:
	if not map.is_ready():
		return Vector3.ZERO
	var pos := e.kart.ground_position()
	var target: Object = null
	if e.carrying:
		target = friends.get(e.carrying.for_friend)
	else:
		var best := 100000
		for thing in things:
			if thing.found or thing.carrier != null:
				continue
			var steps := map.steps(_fields[thing], pos)
			if steps < best:
				best = steps
				target = thing
	if target == null:
		return Vector3.ZERO
	return map.direction(_fields[target], pos)

func _check_pickups() -> void:
	for e in explorers:
		var pos := e.kart.ground_position()
		for thing in things:
			if thing.found or thing.carrier != null:
				continue
			var d := Vector2(thing.global_position.x - pos.x, thing.global_position.z - pos.z).length()
			if d > PICK_RADIUS:
				continue
			if thing.for_friend == "":
				_found(thing, e)
				thing.celebrate()
			elif e.carrying == null:
				e.carrying = thing
				thing.ride_on(e.kart)
				_box.carrying(thing.id, e.color)
				UiKit.play(self, "gift", -2.0)
				_hop(e)

func _check_gifts() -> void:
	for id: String in friends:
		(friends[id] as ToyFriend).excited = false
	for e in explorers:
		if e.carrying == null:
			continue
		var friend: ToyFriend = friends.get(e.carrying.for_friend)
		if friend == null:
			continue
		var pos := e.kart.ground_position()
		var d := Vector2(friend.global_position.x - pos.x, friend.global_position.z - pos.z).length() - friend.radius()
		friend.excited = d < EXCITED_RADIUS
		if d <= GIVE_RADIUS:
			var thing := e.carrying
			e.carrying = null
			thing.fly_to(friend.hand_spot())
			friend.be_happy()
			UiKit.play(self, "friend_happy", -2.0)
			_found(thing, e)

func _found(thing: LostThing, e: Explorer) -> void:
	thing.found = true
	found += 1
	e.found += 1
	_box.fill(thing.id)
	UiKit.play(self, "found")
	_hop(e)
	e.kart.rumble_requested.emit(0.4, 0.2, 0.2)
	if found >= things.size():
		_begin_ending()

func _hop(e: Explorer) -> void:
	if e.kart.visual.driver:
		e.kart.visual.driver.hop(1.5)

## Stuck for a long time: the toy helicopter puts the kart on free floor nearby.
func _rescue(e: Explorer) -> void:
	if Game.smoke:
		print("SMOKE   rescue %s at %s" % [e.display_name, e.kart.ground_position().snapped(Vector3.ONE * 0.1)])
	var at := map.open_spot(e.kart.ground_position()) if map.is_ready() else Vector3(0, 0, 40)
	var facing := e.assist.guide if e.assist.guide != Vector3.ZERO else (Vector3(0, 0, 0) - at).normalized()
	facing.y = 0.0
	if facing.length() < 0.1:
		facing = Vector3.FORWARD
	e.kart.place(Transform3D(Basis.looking_at(-facing.normalized(), Vector3.UP), at))
	var heli := RescueHeli.new()
	heli.name = "RescueHeli"
	world.add_child(heli)
	heli.carry(e.kart)
	e.assist.clear()
	e.reset_tracking()
	_resets += 1

## Karts push each other apart gently instead of colliding hard.
func _soft_bumps() -> void:
	for i in explorers.size():
		for j in range(i + 1, explorers.size()):
			var a := explorers[i].kart
			var b := explorers[j].kart
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

# --- Bedtime -------------------------------------------------------------------------------

func _begin_ending() -> void:
	state = State.ENDING
	_end_time = 0.0
	UiKit.play(self, "fanfare", -4.0)
	for e in explorers:
		if e.kart.visual.driver:
			e.kart.visual.driver.set_cheering(true)

func _tick_ending(delta: float) -> void:
	var before := _end_time
	_end_time += delta
	# The karts roll out gently.
	for e in explorers:
		if not e.kart.frozen:
			e.kart.intent.clear()
			e.kart.intent.brake = 0.3
	if before < DIM_AT and _end_time >= DIM_AT:
		_dim_lights()
		for id: String in friends:
			(friends[id] as ToyFriend).fall_asleep()
		for node in world.find_children("*", "ToyMotion", true, false):
			if node.name != "RobotVacuum":
				node.set_process(false)
		Music.stop(2.0)
		UiKit.play(self, "sleepy", -3.0)
	if before < PARK_AT and _end_time >= PARK_AT:
		for e in explorers:
			var spot := world.get_node_or_null("Spots/Park%d" % e.player_index) as Marker3D
			if spot:
				e.kart.place(spot.global_transform)
				e.kart.frozen = true
				e.kart.intent.clear()
				e.kart.drop_in(3.0, 0.6)
				if e.kart.visual.driver:
					e.kart.visual.driver.set_cheering(false)
			if e.carrying:
				e.carrying.hide()
				e.carrying = null
	if before < NIGHT_AT and _end_time >= NIGHT_AT:
		state = State.NIGHT
		_night.open()
		Music.play("lullaby", 1.5)

## Evening in the room: the window light fades, the floor lamp and the bulb come on.
func _dim_lights() -> void:
	var tween := create_tween().set_parallel(true)
	for node in world.find_children("*", "DirectionalLight3D", true, false):
		var light := node as DirectionalLight3D
		tween.tween_property(light, "light_energy", light.light_energy * 0.12, 3.0)
	var env_node := world.find_child("Environment", true, false) as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment
		tween.tween_property(env, "ambient_light_energy", env.ambient_light_energy * 0.3, 3.0)
		tween.tween_property(env, "background_energy_multiplier", env.background_energy_multiplier * 0.25, 3.0)
	for light_name in ["LampLight", "BulbLight"]:
		var lamp := world.find_child(light_name, true, false) as OmniLight3D
		if lamp:
			tween.tween_property(lamp, "light_energy", 2.4, 2.5)

# --- Pause ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var pause_pressed := false
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		pause_pressed = true
	var button := event as InputEventJoypadButton
	if button and button.pressed and button.button_index == JOY_BUTTON_START:
		pause_pressed = true
	if pause_pressed and state == State.PLAYING and not _pause.visible:
		_pause.open()
		get_viewport().set_input_as_handled()

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected or state != State.PLAYING or _pause.visible:
		return
	for e in explorers:
		var pad := e.source as PadSource
		if pad and pad.device == device:
			_pause.open()
			return

# --- Headless checks (tools/check.ps1) -----------------------------------------------------

##   --seconds=N   stop after N seconds (default 90)
##   --finish=1    must find all 8 and reach "Gute Nacht"
##   --shot=<png> --shot_at=<s|found|carry|dim|night>   save a picture and quit
##   --found=N     dev helper: the first N things are found at once (ending pictures)
func _smoke_tick(delta: float) -> void:
	var args := Game.smoke_args
	if args.has("found") and _time - delta < 0.5 and _time >= 0.5:
		var n := clampi(int(args["found"]), 0, things.size())
		for k in n:
			var thing := things[k]
			if thing.found or thing.carrier != null:
				continue
			var friend: ToyFriend = friends.get(thing.for_friend)
			if friend:
				# A friend's thing goes to the friend, as if it had been carried there.
				thing.fly_to(friend.hand_spot())
				friend.be_happy()
			else:
				thing.celebrate()
			_found(thing, explorers[0])
	if state == State.NIGHT:
		_night_time += delta
	if args.has("shot") and not _shot_done:
		var at: String = args.get("shot_at", "8")
		var now := false
		if at == "night":
			now = _night_time > 2.6
		elif at == "dim":
			now = state != State.PLAYING and _end_time > PARK_AT + 1.2
		elif at == "carry":
			_carry_wait = _carry_wait + delta if explorers.any(func(e: Explorer) -> bool: return e.carrying != null) else 0.0
			now = _carry_wait > 1.2
		elif at == "found":
			now = _found_shot_wait(delta)
		else:
			now = _time >= float(at)
		if now:
			_shot_done = true
			get_viewport().get_texture().get_image().save_png(args["shot"])
			set_physics_process(false)
			Game.quit_clean(0)
			return
	var limit := float(args.get("seconds", "90"))
	var done := state == State.NIGHT and _night_time > 1.0 and not args.has("shot")
	if not done and _time < limit:
		return
	var ok := true
	print("SMOKE mode=Entdecken speed=%s time=%.1fs found=%d/%d resets=%d state=%s map_free=%d" % [
		Game.SPEED_NAMES[Game.speed_class], _time, found, things.size(), _resets, State.keys()[state], map.free_count()])
	for id: String in friends:
		print("SMOKE   friend %s radius=%.1fm" % [id, (friends[id] as ToyFriend).radius()])
	for e in explorers:
		print("SMOKE   %-12s kid=%s dist=%.0fm found=%d backups=%d escapes=%d wall_hits=%d boosts=%d" % [
			e.display_name, e.assist.kid, e.distance, e.found, e.assist.backups, e.assist.escapes, e.kart.wall_hits, e.kart.pad_boosts])
		ok = ok and e.distance > 40.0
	if Game.speed_class == Game.SpeedClass.KID and _resets > 0:
		print("SMOKE   a kart needed the helicopter at Kid speed")
		ok = false
	if args.get("finish", "0") == "1" and state != State.NIGHT:
		print("SMOKE   not everything was found")
		ok = false
	if map.free_count() < 1000:
		print("SMOKE   the floor map is too small")
		ok = false
	if not _perf_frames.is_empty():
		_perf_frames.sort()
		var total := 0.0
		for f in _perf_frames:
			total += f
		var worst := _perf_frames[int(_perf_frames.size() * 0.99)]
		var size := get_window().size
		print("PERF %s  %dx%d  players=%d  avg=%.0f fps  1%%-low=%.0f fps  frames=%d" % [
			RenderingServer.get_video_adapter_name(), size.x, size.y, explorers.size(),
			_perf_frames.size() / total, 1.0 / worst, _perf_frames.size()])
	print("SMOKE RESULT: %s" % ("PASS" if ok else "FAIL"))
	set_physics_process(false)
	Game.quit_clean(0 if ok else 1)

var _carry_wait := 0.0
var _found_wait := 0.0
var _found_seen := 0

## "--shot_at=found": a moment after the first find (the celebration).
func _found_shot_wait(delta: float) -> bool:
	if found > _found_seen:
		_found_seen = found
		_found_wait = 0.0
	if _found_seen > 0:
		_found_wait += delta
	return _found_seen > 0 and _found_wait > 0.45
