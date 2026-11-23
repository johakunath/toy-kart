class_name InputSource extends RefCounted
## Base class for anything that produces intents: keyboard, gamepad, AI, test bots.
## Subclasses fill in _read_raw(). This class adds edge detection for use/horn and menu moves.

var id := ""     ## stable id, used to remember colour and picks per device
var label := ""  ## short German label for the UI
var icon := "gamepad"
var accept_hint := "A"  ## name of this device's "yes" button, for the UI
var back_hint := "B"
var move_hint := "Stick"  ## what moves through menus (up/down picks a row, left/right changes it)
## The "give my item to the kid" button, for the HUD hint: an icon name, or a short key name.
var gift_icon := ""
var gift_key := ""

var _intent := Intent.new()
var _prev_use := false
var _prev_horn := false
var _prev_gift := false
var _menu_prev := {}

## Raw state right now. control_mode is Game.ControlMode.
## Returns a Dictionary: steer, accelerate, brake, drift, use, horn, gift (use/horn/gift as held booleans).
func _read_raw(_control_mode: int) -> Dictionary:
	return {}

## Raw menu state: left, right, up, down, accept, back (held booleans).
func _read_menu_raw() -> Dictionary:
	return {}

func is_connected_now() -> bool:
	return true

## Called once per physics tick by the racer.
func read(control_mode: int) -> Intent:
	var raw := _read_raw(control_mode)
	_intent.steer = clampf(raw.get("steer", 0.0), -1.0, 1.0)
	_intent.accelerate = clampf(raw.get("accelerate", 0.0), 0.0, 1.0)
	_intent.brake = clampf(raw.get("brake", 0.0), 0.0, 1.0)
	_intent.drift = raw.get("drift", false)
	var use_now: bool = raw.get("use", false)
	var horn_now: bool = raw.get("horn", false)
	_intent.use = use_now and not _prev_use
	_intent.horn = horn_now and not _prev_horn
	_prev_use = use_now
	_prev_horn = horn_now
	var gift_now: bool = raw.get("gift", false)
	_intent.gift = gift_now and not _prev_gift
	_prev_gift = gift_now
	return _intent

## Called once per frame by menus. Returns which menu buttons were pressed this frame.
func menu_poll() -> Dictionary:
	var raw := _read_menu_raw()
	var out := {}
	for key in ["left", "right", "up", "down", "accept", "back"]:
		var now: bool = raw.get(key, false)
		out[key] = now and not _menu_prev.get(key, false)
		_menu_prev[key] = now
	return out

## True while any button of this device is held (used for "press a button to join").
func any_button() -> bool:
	var raw := _read_menu_raw()
	return raw.get("accept", false)

## Forget held buttons, so a button held while switching screens does not fire again.
func swallow_held() -> void:
	var raw := _read_menu_raw()
	for key in raw:
		_menu_prev[key] = raw[key]
	_prev_use = true
	_prev_horn = true
	_prev_gift = true

## Short key help for driving, shown in the player panel and at the start of a race.
func drive_help(_control_mode: int) -> String:
	return ""
