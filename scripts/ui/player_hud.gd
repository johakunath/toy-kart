class_name PlayerHud extends Control
## One player's HUD, drawn over that player's half of the screen: a frame in the player's colour,
## place, lap, time, the held star, and big centre messages (countdown, last lap, finish).

var racer: Racer
var _mode := Game.Mode.RACE
var _place: Label
var _lap_box: Control
var _lap: Label
var _time: Label
var _item: TextureRect
var _message: Label
var _message_left := 0.0
var _item_pulse := 0.0
var _keys: PanelContainer
var _keys_left := 9.0  ## the key help shows during the countdown and a few seconds after

func setup(p_racer: Racer, mode: int, total_racers: int) -> void:
	racer = p_racer
	_mode = mode as Game.Mode
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.theme()

	# Frame in the player's colour.
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = racer.color
	style.set_border_width_all(12)
	style.set_corner_radius_all(26)
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)

	# Place, top left. Shown small-ish on purpose: the race is about driving, not ranking.
	_place = UiKit.label("", 110, Color.WHITE, 22, UiKit.INK)
	UiKit.pin(_place, Control.PRESET_TOP_LEFT, Vector2(40, 22))
	_place.visible = mode == Game.Mode.RACE and total_racers > 1
	add_child(_place)

	# Lap counter, top right.
	_lap_box = HBoxContainer.new()
	_lap_box.add_theme_constant_override("separation", 10)
	_lap_box.add_child(UiKit.icon_rect("flag", 72, Color.WHITE))
	_lap = UiKit.label("1/%d" % Game.LAPS, 64, Color.WHITE, 16, UiKit.INK)
	_lap_box.add_child(_lap)
	UiKit.pin(_lap_box, Control.PRESET_TOP_RIGHT, Vector2(-260, 36))
	_lap_box.visible = mode != Game.Mode.FREE_DRIVE
	add_child(_lap_box)

	# Time, top centre. Kid mode never shows a clock.
	_time = UiKit.label("0:00.0", 56, Color.WHITE, 14, UiKit.INK)
	UiKit.pin(_time, Control.PRESET_CENTER_TOP, Vector2(-130, 40), Vector2(260, 0))
	_time.visible = mode == Game.Mode.TIME_TRIAL or (mode == Game.Mode.RACE and racer.control_mode == Game.ControlMode.FULL)
	add_child(_time)

	# Held star, bottom centre.
	_item = UiKit.icon_rect("star", 130, UiKit.SUN)
	UiKit.pin(_item, Control.PRESET_CENTER_BOTTOM, Vector2(-65, -175), Vector2(130, 130))
	_item.pivot_offset = Vector2(65, 65)
	_item.visible = false
	add_child(_item)

	# Name tag, bottom left.
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UiKit.box(racer.color, 20))
	tag.add_child(UiKit.label(racer.display_name, 34, Color.WHITE))
	UiKit.pin(tag, Control.PRESET_BOTTOM_LEFT, Vector2(34, -108))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tag)

	# Big centre message.
	_message = UiKit.label("", 230, Color.WHITE, 40, UiKit.INK)
	_message.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message.visible = false
	add_child(_message)

	# Key help for this player's device, bottom centre, at the start of the race.
	var help := racer.source.drive_help(racer.control_mode) if racer.source else ""
	var keys_row := CenterContainer.new()
	UiKit.pin(keys_row, Control.PRESET_BOTTOM_WIDE, Vector2(0, -150))
	keys_row.offset_bottom = -90
	keys_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(keys_row)
	_keys = PanelContainer.new()
	_keys.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.6), 18))
	_keys.add_child(UiKit.label(help, 24, Color.WHITE))
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.visible = help != ""
	keys_row.add_child(_keys)

	racer.kart.item_changed.connect(_on_item_changed)

func refresh(race_time: float, delta: float) -> void:
	if _place.visible:
		_place.text = "%d." % racer.place
	_lap.text = "%d/%d" % [racer.display_lap(), Game.LAPS]
	if _time.visible:
		_time.text = UiKit.format_time(racer.finish_time if racer.finished else race_time)
	if _item.visible:
		_item_pulse += delta * 8.0
		_item.scale = Vector2.ONE * (1.0 + sin(_item_pulse) * 0.08)
	if _keys.visible:
		_keys_left -= delta
		_keys.modulate.a = clampf(_keys_left, 0.0, 1.0)
		if _keys_left <= 0.0:
			_keys.visible = false
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.visible = false

## seconds <= 0 keeps the message until the next one.
func show_message(text: String, seconds: float, size := 230, color := Color.WHITE) -> void:
	_message.text = text
	_message.add_theme_font_size_override("font_size", size)
	_message.add_theme_color_override("font_color", color)
	_message.visible = true
	_message_left = seconds
	_message.pivot_offset = _message.size / 2.0
	_message.scale = Vector2.ONE * 1.5
	var tween := create_tween()
	tween.tween_property(_message, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_message() -> void:
	_message.visible = false
	_message_left = 0.0

func _on_item_changed(has_item: bool) -> void:
	# In kid mode the star fires by itself; show it only when the player has to press the button.
	_item.visible = has_item and racer.control_mode == Game.ControlMode.FULL and racer.source is not AiSource
