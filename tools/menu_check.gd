extends SceneTree
## Plays through the menu like two people at the keyboard would, without a window:
## pick Rennen, go on, both join, change a few things, both ready, race starts, pause, resume.
##
##   godot --headless --path . --fixed-fps 60 --script res://tools/menu_check.gd
##
## Exit code 0 = the whole flow works. Used by tools/check.ps1.

# This script must not name classes that use the Game autoload (PlayerSlot, Racer ...):
# it is compiled before autoloads exist. It talks to them through get() instead.
const JOINED := 1
const READY := 2

var _frame := 0
var _step := 0
var _wait := 0
var _fails: Array[String] = []
var _checks := 0
var _game: Node
var _driver_before := 0

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_game = get_root().get_node("Game")
		_game.save_enabled = false
		# Start from a fresh install: the family's saved picks (a keyboard remembered in
		# Profi mode, 0 AI karts) must not change what this check expects.
		_game.set("_settings", ConfigFile.new())
		_game.set("ai_count", 3)
		_game.set("speed_class", 0)
		_game.players.clear()
		change_scene_to_file("res://scenes/menu.tscn")
		return false
	if _wait > 0:
		_wait -= 1
		return false
	_wait = 4
	_step += 1
	var menu := current_scene
	match _step:
		1:
			_expect("menu scene is running", menu != null and menu.name == "Menu")
			_expect("drivers and karts are in the catalog", _game.drivers.size() >= 8 and _game.karts.size() >= 4)
			_action("ui_accept")                     # Rennen has the focus
		2:
			_expect("mode page leads to options", menu.get("_page") == 1 and _game.mode == 1)
			_action("ui_accept")                     # Weiter has the focus
		3:
			_expect("options page leads to player selection", menu.get("_page") == 2)
			_expect("a race offers two seats", (menu.get("_slots") as Array).size() == 2)
			_key(KEY_SPACE)                          # keyboard 1 joins
		4:
			_expect("keyboard 1 took the first seat", _slot(0).state == JOINED)
			_expect("new players start in kid mode", _slot(0).control_mode == 0)
			_key(KEY_ENTER)                          # keyboard 2 joins
		5:
			_expect("keyboard 2 took the second seat", _slot(1).state == JOINED)
			_expect("the two players have different colours", _slot(0).color_index != _slot(1).color_index)
			_driver_before = _slot(0).driver_index    # remembered picks from earlier games
			_key(KEY_D)                              # keyboard 1: next driver
		6:
			_expect("left/right changes the driver", _slot(0).driver_index == (_driver_before + 1) % _driver_count())
			_key(KEY_DOWN)                           # keyboard 2: down to the vehicle row
		7:
			_key(KEY_DOWN)                           # keyboard 2: down to the control row
		8:
			_key(KEY_RIGHT)                          # keyboard 2: Kind -> Profi
		9:
			_expect("the second player switched to full mode", _slot(1).control_mode == 1)
			_key(KEY_SPACE)                          # keyboard 1 ready
		10:
			_expect("keyboard 1 is ready", _slot(0).state == READY)
			_key(KEY_Q)                              # keyboard 1 changes their mind
		11:
			_expect("back makes a ready player un-ready", _slot(0).state == JOINED)
			_key(KEY_SPACE)
		12:
			_key(KEY_ENTER)                          # keyboard 2 ready
			_wait = 110                              # start delay, then the race scene loads
		13:
			_expect("the race scene started", menu != null and menu.name == "Race")
			_expect("two players were handed to the race", _game.players.size() == 2)
			if menu != null and menu.name == "Race":
				var humans: Array = menu.get("humans")
				_expect("the kid-mode player sits on the left", humans.size() == 2 and humans[0].control_mode == 0)
				_expect("three AI karts joined", (menu.get("racers") as Array).size() == 5)
				_expect("each player has a HUD", (menu.get("huds") as Array).size() == 2)
			_wait = 300                              # countdown, then some driving
		14:
			_expect("the race is running after the countdown", menu.get("state") == 1)
			var first: Object = (menu.get("humans") as Array)[0]
			_expect("the kid's kart drives by itself", first.get("kart").speed() > 2.0)
			_key(KEY_ESCAPE)
		15:
			_expect("Esc pauses the race", paused)
			_action("ui_accept")                     # Weiter
		16:
			_expect("Weiter resumes the race", not paused)
			return _finish()
	return false

func _finish() -> bool:
	if _fails.is_empty():
		print("MENU CHECK: PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			print("MENU CHECK: wrong: ", f)
		print("MENU CHECK: FAIL (%d of %d)" % [_fails.size(), _checks])
	_game.quit_clean(0 if _fails.is_empty() else 1)
	_wait = 100000
	return false

func _driver_count() -> int:
	return (_game.get("drivers") as Array).size()

func _slot(i: int) -> Object:
	return (current_scene.get("_slots") as Array)[i]

func _expect(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)

## Press and release an input action (as any pad or key bound to it would).
func _action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

## Tap a key: down now, up two frames later.
func _key(code: Key) -> void:
	_send_key(code, true)
	create_timer(0.034).timeout.connect(_send_key.bind(code, false))

func _send_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
