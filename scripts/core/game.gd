extends Node
## Autoload "Game": what the next race should look like, the driver/kart catalog,
## saved settings, and scene switching. Menus write to it, the race scene reads it.

enum Mode { FREE_DRIVE, RACE, TIME_TRIAL, EXPLORE }
enum SpeedClass { KID, NORMAL, FAST }
enum ControlMode { KID, FULL }

const SPEED_FACTOR: Array[float] = [0.92, 1.05, 1.5]
const SPEED_NAMES: Array[String] = ["Kind", "Normal", "Schnell"]
const MODE_NAMES: Array[String] = ["Freie Fahrt", "Rennen", "Zeitfahren", "Entdecken"]
const CONTROL_NAMES: Array[String] = ["Kind", "Profi"]
const MAX_AI := 3

const PLAYER_COLORS: Array[Color] = [
	Color("e8483f"), Color("3b8beb"), Color("3fbf5f"), Color("f2b90f"),
	Color("a55de0"), Color("f08a24"),
]
const COLOR_NAMES: Array[String] = ["Rot", "Blau", "Grün", "Gelb", "Lila", "Orange"]

const MENU_SCENE := "res://scenes/menu.tscn"
const RACE_SCENE := "res://scenes/race.tscn"
## The open living room (mode "Entdecken"): no track, no laps.
const EXPLORE_SCENE := "res://scenes/explore.tscn"
const SETTINGS_PATH := "user://settings.cfg"

var mode := Mode.RACE
var speed_class := SpeedClass.KID
var ai_count := MAX_AI
var players: Array[PlayerConfig] = []
var track: TrackDef
var music_on := true
var rumble_on := true
## Team race: all humans are one team against the AI toys (a race, scored by the best human).
var team_race := false

## Cup ("Pokal"): three races in a row, each a lap shorter than usual (about ten minutes in
## all). Every racer gets stars by place in each race; after the last race everyone's stars are
## added up and every player gets a trophy. The computer drivers stay the same for the cup.
const CUP_TRACKS: Array[String] = ["kurvenkurs", "wohnzimmer", "riesenrunde"]
var cup := false
var cup_round := 0
## Stars per racer (Racer.cup_key()): total so far and the last race's.
var cup_stars := {}
var cup_last := {}
## The computer drivers and karts of the first race, kept for the whole cup.
var cup_ai_drivers: Array[DriverDef] = []
var cup_ai_karts: Array[KartDef] = []

var drivers: Array[DriverDef] = []
var karts: Array[KartDef] = []
var tracks: Array[TrackDef] = []

## Set by "-- --smoke" on the command line: the race runs itself and quits (used by tools/check.ps1).
var smoke := false
var smoke_args := {}

## Tests switch this off so they never touch the family's saved colours and best times.
var save_enabled := true

## The mouse pointer shows only while the mouse is in use: on the projector, with pads and
## keys, it would sit on a menu card (and light it up) or in the middle of the race.
var mouse_active := false
## The menu's mode page opens on the Pokal card after a cup.
var came_from_cup := false

var _settings := ConfigFile.new()
var _track_before_cup: TrackDef

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN  # until the mouse moves (see mouse_active)
	_settings.load(SETTINGS_PATH)
	_parse_cmdline()
	if smoke or not smoke_args.is_empty():
		save_enabled = false  # test and screenshot runs
	if smoke_args.has("stickers"):
		_stickers_in_memory = clampi(int(smoke_args["stickers"]), 0, STICKERS.size())  # screenshots
	speed_class = clampi(_settings.get_value("options", "speed_class", SpeedClass.KID), 0, 2) as SpeedClass
	ai_count = clampi(_settings.get_value("options", "ai_count", MAX_AI), 0, MAX_AI)
	music_on = _settings.get_value("options", "music", true)
	rumble_on = _settings.get_value("options", "rumble", true)
	_load_catalog()
	track = track_by_id(smoke_args.get("track", _settings.get_value("options", "track", "")))
	if not OS.has_feature("editor") and not smoke and not OS.get_cmdline_user_args().has("--windowed"):
		# Exclusive fullscreen: lowest input lag and smooth 144 Hz on the monitor.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length_squared() > 4.0:
		_set_mouse_active(true)
	elif event is InputEventMouseButton:
		_set_mouse_active(true)
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		_set_mouse_active(false)

func _set_mouse_active(on: bool) -> void:
	if on == mouse_active:
		return
	mouse_active = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_HIDDEN
	if not on and DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN:
		# Out of the way too: a hidden pointer resting on a button would still light it up.
		get_viewport().warp_mouse(Vector2.ZERO)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

# --- Catalog -------------------------------------------------------------------------------

func _load_catalog() -> void:
	drivers.clear()
	karts.clear()
	tracks.clear()
	for res in _load_dir("res://data/tracks"):
		if res is TrackDef:
			tracks.append(res)
	tracks.sort_custom(func(a: TrackDef, b: TrackDef) -> bool: return a.sort_order < b.sort_order)
	for res in _load_dir("res://data/drivers"):
		if res is DriverDef:
			drivers.append(res)
	for res in _load_dir("res://data/karts"):
		if res is KartDef:
			karts.append(res)
	drivers.sort_custom(func(a: DriverDef, b: DriverDef) -> bool:
		return a.sort_order < b.sort_order or (a.sort_order == b.sort_order and a.id < b.id))
	karts.sort_custom(func(a: KartDef, b: KartDef) -> bool:
		return a.sort_order < b.sort_order or (a.sort_order == b.sort_order and a.id < b.id))

func _load_dir(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Catalog folder missing: " + dir_path)
		return out
	var seen := {}
	for file in dir.get_files():
		# Exported builds list "x.tres.remap" instead of "x.tres".
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres") or seen.has(file_name):
			continue
		seen[file_name] = true
		var res := load(dir_path + "/" + file_name)
		if res:
			out.append(res)
	return out

func driver_by_id(id: String) -> DriverDef:
	for d in drivers:
		if d.id == id:
			return d
	return drivers[0] if not drivers.is_empty() else null

## Unknown or empty id gives the first track.
func track_by_id(id: String) -> TrackDef:
	for t in tracks:
		if t.id == id:
			return t
	return tracks[0] if not tracks.is_empty() else null

func kart_by_id(id: String) -> KartDef:
	for k in karts:
		if k.id == id:
			return k
	return karts[0] if not karts.is_empty() else null

## The kart a driver belongs in (DriverDef.favourite_kart), or null: none set, no such kart,
## or a toy that is a vehicle itself.
func favourite_kart(driver: DriverDef) -> KartDef:
	if driver == null or driver.is_vehicle or driver.favourite_kart == "":
		return null
	for k in karts:
		if k.id == driver.favourite_kart:
			return k
	return null

# --- Saved settings ------------------------------------------------------------------------

func save_options() -> void:
	_settings.set_value("options", "speed_class", speed_class)
	_settings.set_value("options", "ai_count", ai_count)
	_settings.set_value("options", "music", music_on)
	_settings.set_value("options", "rumble", rumble_on)
	_settings.set_value("options", "track", track.id if track else "")
	_save()

## Per-device memory: colour, driver, kart, control mode. Returns {} for a device never seen before.
func device_prefs(device_id: String) -> Dictionary:
	return _settings.get_value("devices", device_id, {})

## Two pads of the same model are told apart only by the order they were switched on, so a
## saved "Profi" could land in the kid's hands. True when this pad has such a twin with a
## different saved control mode: its panel then starts as Kind, the safe one.
func pad_mode_unsure(device_id: String) -> bool:
	var cut := device_id.rfind(":")
	if not device_id.begins_with("pad:") or cut < 0 or not _settings.has_section("devices"):
		return false
	var mine: int = device_prefs(device_id).get("control", -1)
	for other in _settings.get_section_keys("devices"):
		if other != device_id and other.begins_with(device_id.left(cut + 1)):
			if int(device_prefs(other).get("control", -1)) != mine:
				return true
	return false

func save_device_prefs(device_id: String, prefs: Dictionary) -> void:
	_settings.set_value("devices", device_id, prefs)
	_save()

func best_time(speed: int) -> float:
	return _settings.get_value("best_times", "%s_%d" % [track.id, speed], 0.0)

## Stores the time if it beats the old one. Returns true for a new record.
func submit_time(speed: int, seconds: float) -> bool:
	var old := best_time(speed)
	if old > 0.0 and seconds >= old:
		return false
	_settings.set_value("best_times", "%s_%d" % [track.id, speed], seconds)
	_save()
	return true

## Bricks the family has collected in all races together (the jar on the finish screen).
func family_bricks() -> int:
	return _settings.get_value("family", "bricks", 0)

func add_family_bricks(count: int) -> void:
	_settings.set_value("family", "bricks", family_bricks() + count)
	_save()

## Stickers: after every race the family opens a present with the next sticker (in this
## order). Collected stickers show on every player's kart. With all of them collected, the
## present holds a star and confetti.
const STICKERS: Array[String] = ["star", "heart", "lightning", "flower", "rainbow", "ladybug", "rocket", "moon", "paw", "sun"]
## The sticker the last present held ("" = all collected already); the finish screen shows it.
var last_sticker := ""
var _stickers_in_memory := -1  # test runs never save, but still count up within the run

func sticker_count() -> int:
	if _stickers_in_memory < 0:
		_stickers_in_memory = clampi(_settings.get_value("family", "stickers", 0), 0, STICKERS.size())
	return _stickers_in_memory

func sticker_ids() -> Array[String]:
	return STICKERS.slice(0, sticker_count())

func sticker_texture(id: String) -> Texture2D:
	return load(KartVisual.STICKER_PATH % id) as Texture2D

## Opens the next present: returns the new sticker, or "" when all are collected.
func unlock_sticker() -> String:
	var count := sticker_count()
	if count >= STICKERS.size():
		last_sticker = ""
		return ""
	_stickers_in_memory = count + 1
	_settings.set_value("family", "stickers", _stickers_in_memory)
	_save()
	last_sticker = STICKERS[count]
	return last_sticker

func _save() -> void:
	if save_enabled:
		_settings.save(SETTINGS_PATH)

# --- Cup ---------------------------------------------------------------------------------

## Laps of the next race: a cup race is one lap shorter (never less than one).
func race_laps() -> int:
	if track == null:
		return 1
	return maxi(1, track.laps - 1) if cup else track.laps

func cup_tracks() -> Array[TrackDef]:
	var out: Array[TrackDef] = []
	for id in CUP_TRACKS:
		var def := track_by_id(id)
		if def and def.id == id:
			out.append(def)
	if out.is_empty():
		out = tracks.slice(0, 3)
	return out

func is_last_cup_race() -> bool:
	return cup_round >= cup_tracks().size() - 1

## Starts a new cup from its first race (the menu's "Pokal" card, and "Nochmal" after a cup).
func start_cup() -> void:
	if not cup or _track_before_cup == null:
		_track_before_cup = track  # the family's own track pick comes back after the cup
	cup = true
	mode = Mode.RACE
	team_race = false
	cup_round = 0
	cup_stars.clear()
	cup_last.clear()
	cup_ai_drivers.clear()
	cup_ai_karts.clear()
	track = cup_tracks()[0]
	start_race()

func next_cup_race() -> void:
	cup_round = mini(cup_round + 1, cup_tracks().size() - 1)
	track = cup_tracks()[cup_round]
	start_race()

## Hands out this race's stars: last place 1, every place ahead one more.
func award_cup_stars(order: Array[Racer]) -> void:
	cup_last.clear()
	for i in order.size():
		var key := order[i].cup_key()
		var stars := order.size() - i
		cup_last[key] = stars
		cup_stars[key] = int(cup_stars.get(key, 0)) + stars

# --- Scene switching -----------------------------------------------------------------------

func start_race() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(EXPLORE_SCENE if mode == Mode.EXPLORE else RACE_SCENE)

func go_to_menu() -> void:
	came_from_cup = cup
	if _track_before_cup != null:
		track = _track_before_cup
		_track_before_cup = null
	cup = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

## Quit without leaving sounds playing: free the scene first, then exit.
func quit_clean(exit_code := 0) -> void:
	get_tree().paused = false
	var scene := get_tree().current_scene
	if scene:
		scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(exit_code)

# --- Devices -------------------------------------------------------------------------------

## All devices that can join right now: two keyboard layouts plus every connected gamepad.
func list_sources() -> Array[InputSource]:
	var out: Array[InputSource] = [KeyboardSource.new(0), KeyboardSource.new(1)]
	var per_guid := {}
	for device in Input.get_connected_joypads():
		var guid := Input.get_joy_guid(device)
		var ordinal: int = per_guid.get(guid, 0)
		per_guid[guid] = ordinal + 1
		var pad := PadSource.new(device, ordinal)
		pad.label = "Controller %d" % (out.size() - 1)
		out.append(pad)
	return out

## Config for a player who did not go through the selection screen (dev runs, tests).
func make_player(source: InputSource, control_mode: int, color_index: int, driver_index: int, kart_index: int) -> PlayerConfig:
	var p := PlayerConfig.new()
	p.source = source
	p.control_mode = control_mode
	p.color_index = color_index
	p.driver = drivers[driver_index % drivers.size()] if not drivers.is_empty() else null
	p.kart = karts[kart_index % karts.size()] if not karts.is_empty() else null
	# Test runs: --kart=<id> puts the first player in that kart (screenshots of one vehicle).
	# (--kart=N with a number picks by menu order in race.gd instead.)
	if smoke and kart_index == 0 and smoke_args.has("kart") and not str(smoke_args["kart"]).is_valid_int():
		p.kart = kart_by_id(str(smoke_args["kart"]))
	return p

# --- Command line --------------------------------------------------------------------------

func _parse_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke":
			smoke = true
		elif arg.begins_with("--") and arg.contains("="):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			smoke_args[parts[0]] = parts[1]
