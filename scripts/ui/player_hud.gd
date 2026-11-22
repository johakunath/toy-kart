class_name PlayerHud extends Control
## One player's HUD, drawn over that player's half of the screen: a frame in the player's colour,
## place, lap, time, the held star, and big centre messages (countdown, last lap, finish).
## Readable without reading: the place digit has a medal colour, a column of faces shows the
## race order (his own face big), and in kid mode the laps are dots instead of numbers.

const MEDALS: Array[Color] = [Color("ffc81e"), Color("dfe6ee"), Color("e0894a")]
const FACE_SIZE := 62.0
const OWN_FACE_SIZE := 92.0
const FACE_GAP := 12.0
const FACES_TOP := 160.0

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
var _all: Array[Racer] = []
var _faces := {}           ## Racer -> Control in the face column
var _lap_dots: Array[Panel] = []

func setup(p_racer: Racer, mode: int, total_racers: int, all_racers: Array[Racer] = []) -> void:
	racer = p_racer
	_all = all_racers
	_mode = mode as Game.Mode
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.theme()

	# Streaks while boosting, under everything else.
	var lines := SpeedLines.new()
	lines.kart = racer.kart
	add_child(lines)

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
	_lap = UiKit.label("1/%d" % Game.track.laps, 64, Color.WHITE, 16, UiKit.INK)
	_lap_box.add_child(_lap)
	if racer.control_mode == Game.ControlMode.KID:
		# Dots instead of numbers: one dot per lap, filled when he is on it or past it.
		_lap.visible = false
		for i in Game.track.laps:
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(44, 44)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_lap_box.add_child(dot)
			_lap_dots.append(dot)
	UiKit.pin(_lap_box, Control.PRESET_TOP_RIGHT, Vector2(-260.0 if _lap_dots.is_empty() else -(110.0 + 54.0 * _lap_dots.size()), 36))
	_lap_box.visible = mode != Game.Mode.FREE_DRIVE
	add_child(_lap_box)

	# Time, top centre. Kid mode never shows a clock.
	_time = UiKit.label("0:00.0", 56, Color.WHITE, 14, UiKit.INK)
	UiKit.pin(_time, Control.PRESET_CENTER_TOP, Vector2(-130, 40), Vector2(260, 0))
	_time.visible = mode == Game.Mode.TIME_TRIAL or (mode == Game.Mode.RACE and racer.control_mode == Game.ControlMode.FULL)
	add_child(_time)

	# Race order as a column of faces, left edge under the place.
	if mode == Game.Mode.RACE and _all.size() > 1:
		for other in _all:
			var face := _make_face(other, other == racer)
			add_child(face)
			_faces[other] = face

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
		var medal := MEDALS[racer.place - 1] if racer.place <= MEDALS.size() else Color.WHITE
		_place.add_theme_color_override("font_color", medal)
	for i in _lap_dots.size():
		var on := i < racer.display_lap()
		_lap_dots[i].add_theme_stylebox_override("panel", UiKit.box(UiKit.SUN if on else Color(1, 1, 1, 0.35), 22, UiKit.INK, 4))
	_place_faces(delta)
	_lap.text = "%d/%d" % [racer.display_lap(), Game.track.laps]
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

func _make_face(other: Racer, own: bool) -> Control:
	var size := OWN_FACE_SIZE if own else FACE_SIZE
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(size, size)
	var ring_color := other.color if other.is_human else Color(UiKit.INK, 0.7)
	ring.add_theme_stylebox_override("panel", UiKit.box(ring_color, int(size / 2.0)))
	var inner := size - (10.0 if own else 6.0)
	var pic := UiKit.rounded_picture(inner, int(inner / 2.0))
	pic.position = Vector2.ONE * (size - inner) / 2.0
	pic.size = Vector2(inner, inner)
	var portrait: Texture2D = other.driver.portrait if other.driver else null
	if portrait:
		(pic.get_child(0) as TextureRect).texture = portrait
	else:
		pic.add_theme_stylebox_override("panel", UiKit.box(Color(0.9, 0.92, 0.96), int(inner / 2.0)))
		var letter := UiKit.label(other.display_name.left(1), int(inner * 0.55), UiKit.INK)
		letter.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.add_child(letter)
	ring.add_child(pic)
	ring.position = Vector2(34, FACES_TOP + (other.place - 1) * (FACE_SIZE + FACE_GAP))
	return ring

## Faces slide to their place; his own face sits a little to the right so it stands out.
func _place_faces(delta: float) -> void:
	for other: Racer in _faces:
		var face: Control = _faces[other]
		var y := FACES_TOP
		for r in _all:
			if r.place < other.place:
				y += (OWN_FACE_SIZE if r == racer else FACE_SIZE) + FACE_GAP
		var x := 34.0 + (12.0 if other == racer else 0.0)
		face.position = face.position.lerp(Vector2(x, y), minf(1.0, delta * 8.0))
		face.z_index = 1 if other == racer else 0

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
