class_name KeyboardSource extends InputSource
## Keyboard as a player device. Two layouts so two people can test at the desk.
## Layout 0: A/D steer, W gas, S brake, Space drift, E use, Q horn.
## Layout 1: arrows steer/gas/brake, "." or "-" drift, Enter use, "," horn.

var layout := 0

func _init(p_layout: int) -> void:
	layout = p_layout
	id = "kb%d" % (p_layout + 1)
	label = "Tasten %s" % ("WASD" if p_layout == 0 else "Pfeile")
	icon = "keyboard"
	accept_hint = "Leertaste" if p_layout == 0 else "Enter"

func _k(code: Key) -> bool:
	return Input.is_physical_key_pressed(code)

func _read_raw(control_mode: int) -> Dictionary:
	var left: bool
	var right: bool
	var up: bool
	var down: bool
	var drift: bool
	var use: bool
	var horn: bool
	if layout == 0:
		left = _k(KEY_A)
		right = _k(KEY_D)
		up = _k(KEY_W)
		down = _k(KEY_S)
		drift = _k(KEY_SPACE)
		use = _k(KEY_E)
		horn = _k(KEY_Q)
	else:
		left = _k(KEY_LEFT)
		right = _k(KEY_RIGHT)
		up = _k(KEY_UP)
		down = _k(KEY_DOWN)
		drift = _k(KEY_PERIOD) or _k(KEY_SLASH)
		use = _k(KEY_ENTER) or _k(KEY_KP_ENTER)
		horn = _k(KEY_COMMA)
	var steer := (1.0 if right else 0.0) - (1.0 if left else 0.0)
	if control_mode == Game.ControlMode.KID:
		# Kid mode: left and right steer, every other key of the layout honks.
		return {"steer": steer, "horn": up or down or drift or use or horn}
	return {
		"steer": steer,
		"accelerate": 1.0 if up else 0.0,
		"brake": 1.0 if down else 0.0,
		"drift": drift,
		"use": use,
		"horn": horn,
	}

func _read_menu_raw() -> Dictionary:
	if layout == 0:
		return {
			"left": _k(KEY_A), "right": _k(KEY_D), "up": _k(KEY_W), "down": _k(KEY_S),
			"accept": _k(KEY_SPACE) or _k(KEY_E), "back": _k(KEY_Q),
		}
	return {
		"left": _k(KEY_LEFT), "right": _k(KEY_RIGHT), "up": _k(KEY_UP), "down": _k(KEY_DOWN),
		"accept": _k(KEY_ENTER) or _k(KEY_KP_ENTER), "back": _k(KEY_BACKSPACE),
	}
