class_name PlayerSlot extends PanelContainer
## One player's panel on the selection screen. Each panel is driven only by its own device:
## up/down picks a row, left/right changes it, A = ready, B = back.
## Rows: driver, kart, control mode (Kind / Profi), colour.
## Keys and buttons are shown as pictures of the real keys (KeyHints), not as words.

enum SlotState { EMPTY, JOINED, READY }

const ROW_COUNT := 4
const ROW_ICONS: Array[String] = ["kid", "wheel", "gamepad", "star"]
const KEY_SIZE := 50.0

var state := SlotState.EMPTY
var source: InputSource
var driver_index := 0
var kart_index := 0
var control_mode := Game.ControlMode.KID
var color_index := 0
var row := 0

## Set by the menu: returns the colour indices used by the other panels.
var taken_colors: Callable

var _empty_view: Control
var _joined_view: Control
var _join_icon: TextureRect
var _side_label: Label
var _ways: VBoxContainer
var _ways_side := -2
var _device_keys: HBoxContainer
var _device_number: Label
var _device_icon: TextureRect
var _header: PanelContainer
var _header_source: InputSource
var _preview: KartPreview
var _row_panels: Array[PanelContainer] = []
var _row_labels: Array[Label] = []
var _row_arrows: Array[TextureRect] = []  ## two per row: left, right
var _mode_icon: TextureRect
## Driver faces in the first row: before, chosen, after.
var _faces: Array[Panel] = []
var _swatch: Panel
var _drive_flow: HFlowContainer
var _drive_shown := ""
var _ready_banner: PanelContainer
var _ready_key: TextureRect
var _ready_label: Label
var _ready_icon: TextureRect
var _back_key: TextureRect
var _back_icon: TextureRect
var _time := 0.0
var _side_icon: TextureRect
## 0 = left half of the screen, 1 = right half, -1 = the only seat (one player).
var side := 0

func _init(p_side := 0) -> void:
	side = p_side
	custom_minimum_size = Vector2(640, 780)
	_build()
	_refresh()

# --- Building ------------------------------------------------------------------------------

func _build() -> void:
	_empty_view = VBoxContainer.new()
	(_empty_view as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(_empty_view as VBoxContainer).add_theme_constant_override("separation", 30)
	# A big arrow pointing to this panel's side: press that direction to sit here.
	_join_icon = UiKit.icon_rect("arrow_left", 200, Color(UiKit.INK, 0.55))
	_join_icon.pivot_offset = Vector2(100, 100)
	_join_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_empty_view.add_child(_join_icon)
	_side_label = UiKit.label("", 60, UiKit.INK)
	_empty_view.add_child(_side_label)
	# How each device takes this seat: pictures of the keys, filled in by _refresh.
	_ways = VBoxContainer.new()
	_ways.add_theme_constant_override("separation", 14)
	_empty_view.add_child(_ways)
	add_child(_empty_view)

	_joined_view = VBoxContainer.new()
	(_joined_view as VBoxContainer).add_theme_constant_override("separation", 8)
	add_child(_joined_view)

	_header = PanelContainer.new()
	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_theme_constant_override("separation", 14)
	_side_icon = UiKit.icon_rect("arrow_left", 44, Color.WHITE)
	header_row.add_child(_side_icon)
	_device_icon = UiKit.icon_rect("gamepad", 52, Color.WHITE)
	header_row.add_child(_device_icon)
	_device_keys = HBoxContainer.new()
	_device_keys.add_theme_constant_override("separation", 2)
	header_row.add_child(_device_keys)
	_device_number = UiKit.label("", 44, Color.WHITE)
	header_row.add_child(_device_number)
	_header.add_child(header_row)
	_joined_view.add_child(_header)

	_preview = KartPreview.new()
	_preview.stickers = Game.sticker_ids()
	_preview.custom_minimum_size = Vector2(580, 150)
	_preview.set_view_angle(22.0, 0.55)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_joined_view.add_child(_preview)

	for i in ROW_COUNT:
		var panel := PanelContainer.new()
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var left_arrow := UiKit.icon_rect("arrow_left", 40, UiKit.INK)
		line.add_child(left_arrow)
		var middle := HBoxContainer.new()
		middle.alignment = BoxContainer.ALIGNMENT_CENTER
		middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		middle.add_theme_constant_override("separation", 14)
		if i == 0:
			# Faces: the chosen driver big, the ones before and after small, so a child picks by face.
			for size: float in [50.0, 88.0]:
				var face := UiKit.rounded_picture(size, int(size * 0.22))
				middle.add_child(face)
				_faces.append(face)
		elif i == 2:
			_mode_icon = UiKit.icon_rect("kid", 52, UiKit.INK)
			middle.add_child(_mode_icon)
		elif i == 3:
			_swatch = Panel.new()
			_swatch.custom_minimum_size = Vector2(120, 52)
			_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			middle.add_child(_swatch)
		else:
			middle.add_child(UiKit.icon_rect(ROW_ICONS[i], 46, Color(UiKit.INK, 0.5)))
		var text := UiKit.label("", 38)
		middle.add_child(text)
		if i == 0:
			var next_face := UiKit.rounded_picture(50.0, 11)
			middle.add_child(next_face)
			_faces.append(next_face)
		line.add_child(middle)
		var right_arrow := UiKit.icon_rect("arrow_right", 40, UiKit.INK)
		line.add_child(right_arrow)
		panel.add_child(line)
		_joined_view.add_child(panel)
		_row_panels.append(panel)
		_row_labels.append(text)
		_row_arrows.append(left_arrow)
		_row_arrows.append(right_arrow)

	# How to drive: key pictures, each followed by what it does.
	_drive_flow = HFlowContainer.new()
	_drive_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	_drive_flow.add_theme_constant_override("h_separation", 22)
	_drive_flow.add_theme_constant_override("v_separation", 8)
	_drive_flow.custom_minimum_size = Vector2(580, 0)
	_drive_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joined_view.add_child(_drive_flow)

	# Ready: [accept key] + tick. Below: [back key] + leave.
	_ready_banner = PanelContainer.new()
	var ready_row := HBoxContainer.new()
	ready_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ready_row.add_theme_constant_override("separation", 14)
	_ready_key = KeyHints.key("key_space", 56)
	ready_row.add_child(_ready_key)
	_ready_icon = UiKit.icon_rect("check", 56, Color.WHITE)
	ready_row.add_child(_ready_icon)
	_ready_label = UiKit.label("", 44, Color.WHITE)
	ready_row.add_child(_ready_label)
	_ready_banner.add_child(ready_row)
	_joined_view.add_child(_ready_banner)

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.add_theme_constant_override("separation", 10)
	_back_key = KeyHints.key("key_q", 40)
	back_row.add_child(_back_key)
	_back_icon = UiKit.icon_rect("exit", 40, Color(UiKit.INK, 0.6))
	back_row.add_child(_back_icon)
	_joined_view.add_child(back_row)

# --- Joining and leaving -------------------------------------------------------------------

func join(p_source: InputSource, slot_number: int) -> void:
	source = p_source
	state = SlotState.JOINED
	row = 0
	var prefs := Game.device_prefs(source.id)
	driver_index = _index_of_driver(prefs.get("driver", ""), slot_number)
	kart_index = _index_of_kart(prefs.get("kart", ""), slot_number)
	control_mode = clampi(prefs.get("control", _default_control()), 0, 1) as Game.ControlMode
	color_index = clampi(prefs.get("color", slot_number), 0, Game.PLAYER_COLORS.size() - 1)
	if _colors_taken().has(color_index):
		_step_color(1)
	UiKit.play(self, "select")
	_refresh()

## A device seen for the first time: in a two-seat race the W A S D keys belong to the
## grown-up (Profi, left), the arrow keys to the kid. Everything else starts in kid mode.
func _default_control() -> Game.ControlMode:
	if side >= 0 and source is KeyboardSource and (source as KeyboardSource).layout == 0:
		return Game.ControlMode.FULL
	return Game.ControlMode.KID

func leave() -> void:
	source = null
	state = SlotState.EMPTY
	_refresh()

func config() -> PlayerConfig:
	var cfg := PlayerConfig.new()
	cfg.source = source
	cfg.control_mode = control_mode
	cfg.color_index = color_index
	cfg.driver = Game.drivers[driver_index]
	cfg.kart = Game.karts[kart_index]
	return cfg

func save_prefs() -> void:
	Game.save_device_prefs(source.id, {
		"driver": Game.drivers[driver_index].id,
		"kart": Game.karts[kart_index].id,
		"control": control_mode,
		"color": color_index,
	})

# --- Input from this panel's device --------------------------------------------------------

func handle(poll: Dictionary) -> void:
	if state == SlotState.JOINED:
		if poll.get("up", false):
			_step_row(-1)
		elif poll.get("down", false):
			_step_row(1)
		elif poll.get("left", false):
			_change(-1)
		elif poll.get("right", false):
			_change(1)
		elif poll.get("accept", false):
			state = SlotState.READY
			save_prefs()
			UiKit.play(self, "select")
		elif poll.get("back", false):
			leave()
			return
		_refresh()
	elif state == SlotState.READY:
		if poll.get("back", false):
			state = SlotState.JOINED
			UiKit.play(self, "click")
			_refresh()

func _step_row(step: int) -> void:
	row = posmod(row + step, ROW_COUNT)
	if row == 1 and _is_toy_vehicle():
		row = posmod(row + step, ROW_COUNT)
	UiKit.play(self, "click")

## A toy that is a vehicle itself brings its own vehicle: the vehicle row is not used.
func _is_toy_vehicle() -> bool:
	return Game.drivers[driver_index].is_vehicle

func _change(step: int) -> void:
	UiKit.play(self, "click")
	match row:
		0:
			driver_index = posmod(driver_index + step, Game.drivers.size())
		1:
			kart_index = posmod(kart_index + step, Game.karts.size())
		2:
			control_mode = (Game.ControlMode.FULL if control_mode == Game.ControlMode.KID else Game.ControlMode.KID)
		3:
			_step_color(step)

func _step_color(step: int) -> void:
	var taken := _colors_taken()
	for i in Game.PLAYER_COLORS.size():
		color_index = posmod(color_index + step, Game.PLAYER_COLORS.size())
		if not taken.has(color_index):
			return

func _colors_taken() -> Array:
	return taken_colors.call(self) if taken_colors.is_valid() else []

func _index_of_driver(id: String, fallback: int) -> int:
	for i in Game.drivers.size():
		if Game.drivers[i].id == id:
			return i
	return fallback % maxi(1, Game.drivers.size())

func _index_of_kart(id: String, fallback: int) -> int:
	for i in Game.karts.size():
		if Game.karts[i].id == id:
			return i
	return fallback % maxi(1, Game.karts.size())

# --- Drawing -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if state == SlotState.EMPTY:
		_join_icon.scale = Vector2.ONE * (1.0 + sin(_time * 4.0) * 0.07)

## The side this panel stands for. Set by the menu (the swap button moves panels).
func set_side(p_side: int) -> void:
	side = p_side
	_refresh()

## One line of the empty panel: a device icon, then the key pictures that take this seat.
func _way_line(device_icon: String, keys: Array[String], arrow := "") -> HBoxContainer:
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 12)
	line.add_child(UiKit.icon_rect(device_icon, 52, Color(UiKit.INK, 0.6)))
	for k in keys:
		line.add_child(KeyHints.key(k, 58))
	if arrow != "":
		line.add_child(UiKit.icon_rect(arrow, 40, UiKit.INK))
	return line

func _refresh_ways() -> void:
	if _ways_side == side:
		return
	_ways_side = side
	for child in _ways.get_children():
		child.queue_free()
	match side:
		0:
			_ways.add_child(_way_line("gamepad", ["pad_stick"], "arrow_left"))
			_ways.add_child(_way_line("keyboard", ["key_space", "key_a"]))
			_ways.add_child(_way_line("keyboard", ["key_left"]))
		1:
			_ways.add_child(_way_line("gamepad", ["pad_stick"], "arrow_right"))
			_ways.add_child(_way_line("keyboard", ["key_enter", "key_right"]))
			_ways.add_child(_way_line("keyboard", ["key_d"]))
		_:
			_ways.add_child(_way_line("gamepad", ["pad_a"]))
			_ways.add_child(_way_line("keyboard", ["key_space"]))
			_ways.add_child(_way_line("keyboard", ["key_enter"]))

func _refresh_header() -> void:
	if _header_source == source:
		return
	_header_source = source
	for child in _device_keys.get_children():
		child.queue_free()
	for k in KeyHints.device_keys(source):
		_device_keys.add_child(KeyHints.key(k, 44))
	_device_icon.texture = UiKit.icon(source.icon)
	# Pads show their number (1, 2 ...) so two pads are told apart.
	_device_number.text = source.label.get_slice(" ", 1) if source is PadSource else ""

func _refresh() -> void:
	var arrow := "arrow_right" if side == 1 else "arrow_left"
	_join_icon.texture = UiKit.icon(arrow)
	_join_icon.visible = side >= 0
	_side_icon.texture = UiKit.icon(arrow)
	_side_icon.visible = side >= 0
	_side_label.text = ["Links", "Rechts"][side] if side >= 0 else "Mitfahren"
	_refresh_ways()
	_empty_view.visible = state == SlotState.EMPTY
	_joined_view.visible = state != SlotState.EMPTY
	if state == SlotState.EMPTY:
		add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PAPER, 0.55), 36, Color(UiKit.INK, 0.25), 6))
		return
	var color := Game.PLAYER_COLORS[color_index]
	add_theme_stylebox_override("panel", UiKit.box(UiKit.PAPER, 36, color, 14))
	_header.add_theme_stylebox_override("panel", UiKit.box(color, 22))
	_refresh_header()

	var driver := Game.drivers[driver_index]
	var kart := Game.karts[kart_index]
	if _preview.shown_kart != kart or _preview.shown_driver != driver:
		_preview.show_kart(kart, driver)
	_row_labels[0].text = driver.display_name
	var count := Game.drivers.size()
	for k in _faces.size():
		var shown := Game.drivers[posmod(driver_index + [-1, 0, 1][k], count)]
		_faces[k].visible = shown.portrait != null
		(_faces[k].get_child(0) as TextureRect).texture = shown.portrait
		_faces[k].modulate.a = 1.0 if k == 1 else 0.55
	var toy_vehicle := driver.is_vehicle
	_row_labels[1].text = "" if toy_vehicle else kart.display_name
	_row_labels[2].text = Game.CONTROL_NAMES[control_mode]
	_row_labels[3].text = ""
	_mode_icon.texture = UiKit.icon("kid" if control_mode == Game.ControlMode.KID else "pro")
	_swatch.add_theme_stylebox_override("panel", UiKit.box(color, 26))

	var is_ready := state == SlotState.READY
	var move_keys := KeyHints.left_right(source)
	for i in ROW_COUNT:
		var selected := i == row and not is_ready
		var row_box := UiKit.box(UiKit.SUN if selected else Color(UiKit.INK, 0.06), 20)
		if i == 0:
			row_box.content_margin_top = 5
			row_box.content_margin_bottom = 5
		_row_panels[i].add_theme_stylebox_override("panel", row_box)
		_row_panels[i].modulate.a = 0.45 if is_ready or (i == 1 and toy_vehicle) else 1.0
		# The chosen row shows the real keys that change it (A / D or the arrow keys).
		for k in 2:
			var arrow_rect := _row_arrows[i * 2 + k]
			var as_key := selected and not move_keys.is_empty()
			arrow_rect.texture = UiKit.icon(move_keys[k] if as_key else ["arrow_left", "arrow_right"][k])
			arrow_rect.modulate = Color.WHITE if as_key else UiKit.INK
			arrow_rect.custom_minimum_size = Vector2.ONE * (50.0 if as_key else 40.0)

	var drive_key := "%s:%d" % [source.id, control_mode]
	if drive_key != _drive_shown:
		_drive_shown = drive_key
		KeyHints.fill_driving(_drive_flow, source, control_mode, KEY_SIZE)

	_ready_banner.add_theme_stylebox_override("panel", UiKit.box(UiKit.GRASS if is_ready else Color(UiKit.INK, 0.35), 22))
	var accept := KeyHints.accept_key(source)
	_ready_key.texture = UiKit.icon(accept) if accept != "" else null
	_ready_key.visible = not is_ready and accept != ""
	_fit_key(_ready_key, 56)
	_ready_label.text = "Bereit!" if is_ready else ""
	_ready_label.visible = is_ready
	var back := KeyHints.back_key(source)
	_back_key.texture = UiKit.icon(back) if back != "" else null
	_back_key.visible = back != ""
	_fit_key(_back_key, 40)
	# Not ready: the back key leaves the seat. Ready: it takes "ready" back.
	_back_icon.texture = UiKit.icon("arrow_left" if is_ready else "exit")

func _fit_key(rect: TextureRect, height: float) -> void:
	if rect.texture != null and rect.texture.get_height() > 0:
		rect.custom_minimum_size = Vector2(height * rect.texture.get_width() / rect.texture.get_height(), height)
