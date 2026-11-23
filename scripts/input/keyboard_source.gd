class_name KeyboardSource extends InputSource
## Keyboard as a player device. Two layouts so two people can test at the desk.
## Layout 0: A/D steer, W gas, S brake, Space drift, E use, Q horn, R gift.
## Layout 1: arrows steer/gas/brake, "." or "-" drift, Enter use, "," horn, M gift.

var layout := 0

func _init(p_layout: int) -> void:
	layout = p_layout
	id = "kb%d" % (p_layout + 1)
	label = "Tasten %s" % ("WASD" if p_layout == 0 else "Pfeile")
	icon = "keyboard"
	accept_hint = "Leertaste" if p_layout == 0 else "Enter"
	back_hint = "Q" if p_layout == 0 else "Rücktaste"
	move_hint = "W A S D" if p_layout == 0 else "Pfeile"
	gift_key = "R" if p_layout == 0 else "M"

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
	var gift: bool
	if layout == 0:
		left = _k(KEY_A)
		right = _k(KEY_D)
		up = _k(KEY_W)
		down = _k(KEY_S)
		drift = _k(KEY_SPACE)
		use = _k(KEY_E)
		horn = _k(KEY_Q)
		gift = _k(KEY_R)
	else:
		left = _k(KEY_LEFT)
		right = _k(KEY_RIGHT)
		up = _k(KEY_UP)
		down = _k(KEY_DOWN)
		drift = _k(KEY_PERIOD) or _k(KEY_SLASH)
		use = _k(KEY_ENTER) or _k(KEY_KP_ENTER)
		horn = _k(KEY_COMMA)
		gift = _k(KEY_M)
	var steer := (1.0 if right else 0.0) - (1.0 if left else 0.0)
	if control_mode == Game.ControlMode.KID:
		# Kid mode: left and right steer, up is full gas, every other key of the layout honks.
		return {"steer": steer, "accelerate": 1.0 if up else 0.0, "horn": down or drift or use or horn}
	return {
		"steer": steer,
		"accelerate": 1.0 if up else 0.0,
		"brake": 1.0 if down else 0.0,
		"drift": drift,
		"use": use,
		"horn": horn,
		"gift": gift,
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

func drive_help(control_mode: int) -> String:
	if layout == 0:
		if control_mode == Game.ControlMode.KID:
			return "A D lenken   W Turbo   Q Hupe"
		return "W Gas   S Bremse   A D lenken   Leertaste Drift   E Stern   Q Hupe   R Geschenk"
	if control_mode == Game.ControlMode.KID:
		return "Pfeile lenken   Pfeil hoch Turbo   Komma Hupe"
	return "Hoch Gas   Runter Bremse   Links Rechts lenken   Punkt Drift   Enter Stern   Komma Hupe   M Geschenk"
