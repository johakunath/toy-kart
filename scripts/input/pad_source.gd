class_name PadSource extends InputSource
## Any XInput / SDL gamepad as a player device. Reads the device directly, so two pads never mix.
## Kid mode: either stick, D-pad or LB/RB steer; A or RT = full gas; B, X, Y honk.
## Full mode: left stick or D-pad steer, RT or A gas, LT or B brake, RB drift, X or LB use, Y horn,
## D-pad up or down gives the held item to the kid.

const DEADZONE := 0.25

var device := 0

func _init(p_device: int, ordinal: int) -> void:
	device = p_device
	var guid := Input.get_joy_guid(p_device) if Input.get_connected_joypads().has(p_device) else "none"
	id = "pad:%s:%d" % [guid, ordinal]
	label = "Controller %d" % (ordinal + 1)
	icon = "gamepad"
	gift_icon = "dpad_up"

func is_connected_now() -> bool:
	return Input.get_connected_joypads().has(device)

func _b(button: JoyButton) -> bool:
	return Input.is_joy_button_pressed(device, button)

func _axis(axis: JoyAxis) -> float:
	var v := Input.get_joy_axis(device, axis)
	if absf(v) < DEADZONE:
		return 0.0
	# Rescale so the stick starts at 0 right after the deadzone.
	return signf(v) * (absf(v) - DEADZONE) / (1.0 - DEADZONE)

func _digital_steer(with_shoulders: bool) -> float:
	var left := _b(JOY_BUTTON_DPAD_LEFT)
	var right := _b(JOY_BUTTON_DPAD_RIGHT)
	if with_shoulders:
		left = left or _b(JOY_BUTTON_LEFT_SHOULDER)
		right = right or _b(JOY_BUTTON_RIGHT_SHOULDER)
	return (1.0 if right else 0.0) - (1.0 if left else 0.0)

func _face_any() -> bool:
	return _b(JOY_BUTTON_A) or _b(JOY_BUTTON_B) or _b(JOY_BUTTON_X) or _b(JOY_BUTTON_Y)

func _read_raw(control_mode: int) -> Dictionary:
	var stick := _axis(JOY_AXIS_LEFT_X)
	if control_mode == Game.ControlMode.KID:
		var stick_r := _axis(JOY_AXIS_RIGHT_X)
		if absf(stick_r) > absf(stick):
			stick = stick_r
		# A stick that is pushed wins: a small hand resting on LB must not lock the steering.
		var digital := _digital_steer(true)
		return {
			"steer": stick if stick != 0.0 else digital,
			"accelerate": maxf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT), 1.0 if _b(JOY_BUTTON_A) else 0.0),
			"horn": _b(JOY_BUTTON_B) or _b(JOY_BUTTON_X) or _b(JOY_BUTTON_Y),
		}
	var digital_full := _digital_steer(false)
	return {
		"steer": digital_full if digital_full != 0.0 else stick,
		"accelerate": maxf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT), 1.0 if _b(JOY_BUTTON_A) else 0.0),
		"brake": maxf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT), 1.0 if _b(JOY_BUTTON_B) else 0.0),
		"drift": _b(JOY_BUTTON_RIGHT_SHOULDER),
		"use": _b(JOY_BUTTON_X) or _b(JOY_BUTTON_LEFT_SHOULDER),
		"horn": _b(JOY_BUTTON_Y),
		"gift": _b(JOY_BUTTON_DPAD_UP) or _b(JOY_BUTTON_DPAD_DOWN),
	}

func _read_menu_raw() -> Dictionary:
	var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var y := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	return {
		"left": x < -0.6 or _b(JOY_BUTTON_DPAD_LEFT) or _b(JOY_BUTTON_LEFT_SHOULDER),
		"right": x > 0.6 or _b(JOY_BUTTON_DPAD_RIGHT) or _b(JOY_BUTTON_RIGHT_SHOULDER),
		"up": y < -0.6 or _b(JOY_BUTTON_DPAD_UP),
		"down": y > 0.6 or _b(JOY_BUTTON_DPAD_DOWN),
		"accept": _b(JOY_BUTTON_A) or _b(JOY_BUTTON_X) or _b(JOY_BUTTON_Y),
		"back": _b(JOY_BUTTON_B),
	}

func any_button() -> bool:
	return _face_any() or _b(JOY_BUTTON_START)

func drive_help(control_mode: int) -> String:
	if control_mode == Game.ControlMode.KID:
		return "Stick lenken   A Turbo   B X Y Hupe"
	return "Stick lenken   RT Gas   LT Bremse   RB Drift   X Stern   Y Hupe   Kreuz hoch Geschenk"
