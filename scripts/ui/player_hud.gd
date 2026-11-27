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
var _item_back: Panel
var _roulette := 0.0             ## seconds of item roulette left
var _roulette_tick := 0.0
var _shown_item := Items.NONE
var _brick_dots: Array[Panel] = []
var _message: Label
var _message_left := 0.0
var _item_pulse := 0.0
var _charge_row: HBoxContainer    ## triple turbo: one small turbo per charge left, under the slot
var _charges_shown := -1
var _keys: PanelContainer
var _keys_left := 9.0  ## the key help shows during the countdown and a few seconds after
var _all: Array[Racer] = []
var _faces := {}           ## Racer -> Control in the face column
var _lap_dots: Array[Panel] = []
var _gift_hint: PanelContainer   ## "give your item to the kid" hint (CoopHelp shows it)
var _gift_pulse := 0.0
var _place_shown := -1
var _lap_shown := -1

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
	_lap = UiKit.label("1/%d" % Game.race_laps(), 64, Color.WHITE, 16, UiKit.INK)
	_lap_box.add_child(_lap)
	if racer.control_mode == Game.ControlMode.KID:
		# Dots instead of numbers: one dot per lap, filled when he is on it or past it.
		_lap.visible = false
		for i in Game.race_laps():
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
	# Item slot, bottom centre: a white disc with the item; a short roulette when one arrives.
	_item_back = Panel.new()
	_item_back.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.85), 80, UiKit.INK, 6))
	_item_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.pin(_item_back, Control.PRESET_CENTER_BOTTOM, Vector2(-80, -190), Vector2(160, 160))
	_item_back.pivot_offset = Vector2(80, 80)
	_item_back.visible = false
	add_child(_item_back)
	_item = UiKit.icon_rect("item_turbo", 124, Color.WHITE)
	_item.set_anchors_preset(Control.PRESET_FULL_RECT)
	_item.offset_left = 18
	_item.offset_top = 18
	_item.offset_right = -18
	_item.offset_bottom = -18
	_item_back.add_child(_item)
	_charge_row = HBoxContainer.new()
	_charge_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_charge_row.add_theme_constant_override("separation", 2)
	_charge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.pin(_charge_row, Control.PRESET_CENTER_BOTTOM, Vector2(86, -136), Vector2(156, 52))
	_charge_row.visible = false
	add_child(_charge_row)

	# Bricks: a brick and ten dots that fill up (each brick = a little more speed).
	var brick_row := HBoxContainer.new()
	brick_row.add_theme_constant_override("separation", 6)
	brick_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brick_row.add_child(UiKit.icon_rect("brick", 64, Color.WHITE))
	for i in Kart.MAX_BRICKS:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 18)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		brick_row.add_child(dot)
		_brick_dots.append(dot)
	UiKit.pin(brick_row, Control.PRESET_BOTTOM_LEFT, Vector2(34, -190))
	brick_row.visible = mode != Game.Mode.TIME_TRIAL
	add_child(brick_row)
	_on_bricks_changed(0)

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

	# Key help for this player's device, bottom centre, at the start of the race:
	# pictures of the real keys, each followed by what it does.
	var keys_row := CenterContainer.new()
	UiKit.pin(keys_row, Control.PRESET_BOTTOM_WIDE, Vector2(0, -170))
	keys_row.offset_bottom = -90
	keys_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(keys_row)
	_keys = PanelContainer.new()
	_keys.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PAPER, 0.85), 18))
	var key_pictures := HBoxContainer.new()
	key_pictures.add_theme_constant_override("separation", 20)
	key_pictures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if racer.source:
		# The gift key shows only when there is a kid along to give to.
		var kid_along := false
		for other in _all:
			kid_along = kid_along or (other != racer and other.is_human and other.control_mode == Game.ControlMode.KID)
		KeyHints.fill_driving(key_pictures, racer.source, racer.control_mode, 44.0, kid_along)
	_keys.add_child(key_pictures)
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.visible = key_pictures.get_child_count() > 0
	keys_row.add_child(_keys)

	racer.kart.item_changed.connect(_on_item_changed)
	racer.kart.bricks_changed.connect(_on_bricks_changed)

func refresh(race_time: float, delta: float) -> void:
	# Styles are set only when the place or the lap changes, not every frame.
	if _place.visible and racer.place != _place_shown:
		_place_shown = racer.place
		_place.text = "%d." % racer.place
		var medal := MEDALS[racer.place - 1] if racer.place <= MEDALS.size() else Color.WHITE
		_place.add_theme_color_override("font_color", medal)
	var lap := racer.display_lap()
	if lap != _lap_shown:
		_lap_shown = lap
		for i in _lap_dots.size():
			_lap_dots[i].add_theme_stylebox_override("panel", UiKit.box(UiKit.SUN if i < lap else Color(1, 1, 1, 0.35), 22, UiKit.INK, 4))
		_lap.text = "%d/%d" % [lap, Game.race_laps()]
	_place_faces(delta)
	if _time.visible:
		_time.text = UiKit.format_time(racer.finish_time if racer.finished else race_time)
	if _item_back.visible:
		if _roulette > 0.0:
			_roulette -= delta
			_roulette_tick -= delta
			if _roulette_tick <= 0.0:
				_roulette_tick = 0.08
				_item.texture = UiKit.icon(Items.icon(Items.ALL[randi() % Items.ALL.size()]))
				UiKit.play(self, "click", -14.0)
			if _roulette <= 0.0:
				_item.texture = UiKit.icon(Items.icon(_shown_item))
				_item_back.scale = Vector2.ONE * 1.4
				UiKit.play(self, "select", -6.0)
		else:
			_item_pulse += delta * 8.0
			_item_back.scale = _item_back.scale.lerp(Vector2.ONE * (1.0 + sin(_item_pulse) * 0.06), minf(1.0, delta * 10.0))
	_show_charges()
	if _keys.visible:
		_keys_left -= delta
		_keys.modulate.a = clampf(_keys_left, 0.0, 1.0)
		if _keys_left <= 0.0:
			_keys.visible = false
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.visible = false

## Co-op: a present and the gift button above the item slot, pointing toward the kid's half,
## while this player could give his item to the kid. Built the first time it is needed.
func show_gift_hint(on: bool, source: InputSource, delta: float) -> void:
	if _gift_hint == null:
		if not on:
			return
		_gift_hint = PanelContainer.new()
		_gift_hint.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.9), 40, UiKit.INK, 5))
		_gift_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The kid sits on the other half: left of the right player, right of the left one.
		row.add_child(UiKit.icon_rect("arrow_right" if racer.player_index == 0 else "arrow_left", 44, Color("e8483f")))
		row.add_child(UiKit.icon_rect("gift", 80, Color.WHITE))
		var gift_key := KeyHints.gift_key(source) if source else ""
		if gift_key != "":
			row.add_child(KeyHints.key(gift_key, 60))
		elif source and source.gift_icon != "":
			row.add_child(UiKit.icon_rect(source.gift_icon, 64, Color.WHITE))
		_gift_hint.add_child(row)
		UiKit.pin(_gift_hint, Control.PRESET_CENTER_BOTTOM, Vector2(-110, -320), Vector2(220, 110))
		_gift_hint.pivot_offset = Vector2(110, 55)
		_gift_hint.modulate.a = 0.0
		add_child(_gift_hint)
	_gift_hint.modulate.a = move_toward(_gift_hint.modulate.a, 1.0 if on else 0.0, delta * 5.0)
	_gift_hint.visible = _gift_hint.modulate.a > 0.01
	_gift_pulse += delta * 6.0
	_gift_hint.scale = Vector2.ONE * (1.0 + 0.05 * sin(_gift_pulse))

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
	# Long words ("Letzte Runde!") shrink to fit a split-screen half.
	if self.size.x > 200.0:
		size = UiKit.fit_font_size(text, self.size.x - 120.0, size, 60)
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

func _on_bricks_changed(count: int) -> void:
	for i in _brick_dots.size():
		var on := i < count
		_brick_dots[i].add_theme_stylebox_override("panel", UiKit.box(Color("e8483f") if on else Color(1, 1, 1, 0.35), 9, UiKit.INK, 3))

## Triple turbo: small turbos under the slot, one per turbo left; using one makes the slot pop.
func _show_charges() -> void:
	var count := racer.kart.turbo_charges if _shown_item == Items.TRIPLE_TURBO and _roulette <= 0.0 else 0
	if count == _charges_shown:
		return
	if count < _charges_shown and count > 0:
		_item_back.scale = Vector2.ONE * 1.3
	_charges_shown = count
	for child in _charge_row.get_children():
		child.queue_free()
	for i in count:
		_charge_row.add_child(UiKit.icon_rect("item_turbo", 48, UiKit.SUN))
	_charge_row.visible = count > 0

func _on_item_changed(item: int) -> void:
	_shown_item = item
	if item == Items.NONE:
		_item_back.visible = false
		return
	_item_back.visible = true
	_roulette = 0.7
	_roulette_tick = 0.0

