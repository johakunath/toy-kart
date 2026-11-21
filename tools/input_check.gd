extends SceneTree
## Checks the gamepad and keyboard mapping without real hardware: it feeds fake button and
## stick events into Godot and looks at the intents that come out.
##
##   godot --headless --path . --script res://tools/input_check.gd
##
## Exit code 0 = all mappings as designed. Used by tools/check.ps1.

const DEVICE := 3   # any device number; no real pad needed

var _fails: Array[String] = []
var _checks := 0

func _process(_delta: float) -> bool:
	var pad := PadSource.new(DEVICE, 0)
	var kid := Game.ControlMode.KID
	var full := Game.ControlMode.FULL

	# --- Kid mode: stick, D-pad or LB/RB steer; any face button honks; nothing else matters ---
	_axis(JOY_AXIS_LEFT_X, -1.0)
	_expect("kid: left stick left steers left", pad.read(kid).steer < -0.9)
	_axis(JOY_AXIS_LEFT_X, 0.1)
	_expect("kid: tiny stick movement is ignored (deadzone)", is_zero_approx(pad.read(kid).steer))
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	_expect("kid: right stick steers too", pad.read(kid).steer > 0.9)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_button(JOY_BUTTON_DPAD_LEFT, true)
	_expect("kid: D-pad left steers left", pad.read(kid).steer == -1.0)
	_button(JOY_BUTTON_DPAD_LEFT, false)
	_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	_expect("kid: RB steers right", pad.read(kid).steer == 1.0)
	_expect("kid: RB does not drift", not pad.read(kid).drift)
	_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	_button(JOY_BUTTON_LEFT_SHOULDER, true)
	_expect("kid: LB steers left", pad.read(kid).steer == -1.0)
	_button(JOY_BUTTON_LEFT_SHOULDER, false)
	_button(JOY_BUTTON_A, true)
	_expect("kid: A is full gas", pad.read(kid).accelerate == 1.0)
	_expect("kid: A does not honk", not pad.read(kid).horn)
	_button(JOY_BUTTON_A, false)
	for face: JoyButton in [JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]:
		pad.read(kid)
		_button(face, true)
		var first := pad.read(kid)
		var honked := first.horn
		var again := pad.read(kid).horn
		_expect("kid: face button %d honks once per press" % face, honked and not again)
		_expect("kid: face button %d does not use items or brake" % face, not first.use and first.brake == 0.0)
		_button(face, false)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_expect("kid: RT is full gas", pad.read(kid).accelerate == 1.0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)

	# --- Full mode: RT/A gas, LT/B brake, RB drift, X/LB use, Y horn ---
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.8)
	_expect("full: RT accelerates (analog)", absf(pad.read(full).accelerate - 0.8) < 0.01)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_button(JOY_BUTTON_A, true)
	_expect("full: A accelerates", pad.read(full).accelerate == 1.0)
	_expect("full: A does not honk", not pad.read(full).horn)
	_button(JOY_BUTTON_A, false)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_expect("full: LT brakes", pad.read(full).brake == 1.0)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_button(JOY_BUTTON_B, true)
	_expect("full: B brakes", pad.read(full).brake == 1.0)
	_button(JOY_BUTTON_B, false)
	_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	var drift_intent := pad.read(full)
	_expect("full: RB drifts and does not steer", drift_intent.drift and drift_intent.steer == 0.0)
	_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	pad.read(full)
	_button(JOY_BUTTON_X, true)
	_expect("full: X uses the item, once per press", pad.read(full).use and not pad.read(full).use)
	_button(JOY_BUTTON_X, false)
	pad.read(full)
	_button(JOY_BUTTON_Y, true)
	_expect("full: Y honks", pad.read(full).horn)
	_button(JOY_BUTTON_Y, false)
	_button(JOY_BUTTON_DPAD_RIGHT, true)
	_expect("full: D-pad right steers right", pad.read(full).steer == 1.0)
	_button(JOY_BUTTON_DPAD_RIGHT, false)

	# --- Two pads never mix ---
	var other := PadSource.new(DEVICE + 1, 1)
	_button(JOY_BUTTON_DPAD_LEFT, true)
	_expect("a second pad does not see the first pad's buttons", other.read(kid).steer == 0.0)
	_button(JOY_BUTTON_DPAD_LEFT, false)
	_expect("each pad has its own id", pad.id != other.id)

	# --- Menu moves ---
	pad.menu_poll()
	_button(JOY_BUTTON_A, true)
	var poll := pad.menu_poll()
	_expect("menu: A accepts once", poll["accept"] and not pad.menu_poll()["accept"])
	_button(JOY_BUTTON_A, false)
	_button(JOY_BUTTON_B, true)
	_expect("menu: B goes back", pad.menu_poll()["back"])
	_button(JOY_BUTTON_B, false)

	# --- The kid assist turns "nothing pressed" into driving ---
	var assist := Assist.new()
	_expect("assist: kid flag is off by default (full mode passes through)", not assist.kid)

	if _fails.is_empty():
		print("INPUT CHECK: PASS (%d checks)" % _checks)
		quit(0)
	else:
		for f in _fails:
			print("INPUT CHECK: wrong: ", f)
		print("INPUT CHECK: FAIL (%d of %d)" % [_fails.size(), _checks])
		quit(1)
	return true

func _expect(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)

func _button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
