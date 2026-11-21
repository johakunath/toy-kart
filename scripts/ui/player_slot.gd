class_name PlayerSlot extends PanelContainer
## One player's panel on the selection screen. Each panel is driven only by its own device:
## up/down picks a row, left/right changes it, A = ready, B = back.
## Rows: driver, kart, control mode (Kind / Profi), colour.

enum SlotState { EMPTY, JOINED, READY }

const ROW_COUNT := 4
const ROW_ICONS: Array[String] = ["kid", "wheel", "gamepad", "star"]

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
var _device_label: Label
var _device_icon: TextureRect
var _header: PanelContainer
var _preview: KartPreview
var _row_panels: Array[PanelContainer] = []
var _row_labels: Array[Label] = []
var _mode_icon: TextureRect
var _swatch: Panel
var _ready_banner: PanelContainer
var _ready_label: Label
var _ready_icon: TextureRect
var _time := 0.0
var _hint := "Knopf drücken"

func _init(hint := "Knopf drücken") -> void:
	_hint = hint
	custom_minimum_size = Vector2(640, 820)
	_build()
	_refresh()

# --- Building ------------------------------------------------------------------------------

func _build() -> void:
	_empty_view = VBoxContainer.new()
	(_empty_view as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(_empty_view as VBoxContainer).add_theme_constant_override("separation", 30)
	_join_icon = UiKit.icon_rect("gamepad", 240, Color(UiKit.INK, 0.55))
	_join_icon.pivot_offset = Vector2(120, 120)
	_join_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_empty_view.add_child(_join_icon)
	_empty_view.add_child(UiKit.label(_hint, 52, Color(UiKit.INK, 0.7)))
	add_child(_empty_view)

	_joined_view = VBoxContainer.new()
	(_joined_view as VBoxContainer).add_theme_constant_override("separation", 8)
	add_child(_joined_view)

	_header = PanelContainer.new()
	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_theme_constant_override("separation", 14)
	_device_icon = UiKit.icon_rect("gamepad", 48, Color.WHITE)
	header_row.add_child(_device_icon)
	_device_label = UiKit.label("", 38, Color.WHITE)
	header_row.add_child(_device_label)
	_header.add_child(header_row)
	_joined_view.add_child(_header)

	_preview = KartPreview.new()
	_preview.custom_minimum_size = Vector2(580, 250)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_joined_view.add_child(_preview)

	for i in ROW_COUNT:
		var panel := PanelContainer.new()
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.add_child(UiKit.icon_rect("arrow_left", 40, UiKit.INK))
		var middle := HBoxContainer.new()
		middle.alignment = BoxContainer.ALIGNMENT_CENTER
		middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		middle.add_theme_constant_override("separation", 14)
		if i == 2:
			_mode_icon = UiKit.icon_rect("kid", 52, UiKit.INK)
			middle.add_child(_mode_icon)
		elif i == 3:
			_swatch = Panel.new()
			_swatch.custom_minimum_size = Vector2(52, 52)
			_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			middle.add_child(_swatch)
		else:
			middle.add_child(UiKit.icon_rect(ROW_ICONS[i], 46, Color(UiKit.INK, 0.5)))
		var text := UiKit.label("", 38)
		middle.add_child(text)
		line.add_child(middle)
		line.add_child(UiKit.icon_rect("arrow_right", 40, UiKit.INK))
		panel.add_child(line)
		_joined_view.add_child(panel)
		_row_panels.append(panel)
		_row_labels.append(text)

	_ready_banner = PanelContainer.new()
	var ready_row := HBoxContainer.new()
	ready_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ready_row.add_theme_constant_override("separation", 14)
	_ready_icon = UiKit.icon_rect("check", 50, Color.WHITE)
	ready_row.add_child(_ready_icon)
	_ready_label = UiKit.label("", 44, Color.WHITE)
	ready_row.add_child(_ready_label)
	_ready_banner.add_child(ready_row)
	_joined_view.add_child(_ready_banner)

# --- Joining and leaving -------------------------------------------------------------------

func join(p_source: InputSource, slot_number: int) -> void:
	source = p_source
	state = SlotState.JOINED
	row = 0
	var prefs := Game.device_prefs(source.id)
	driver_index = _index_of_driver(prefs.get("driver", ""), slot_number)
	kart_index = _index_of_kart(prefs.get("kart", ""), slot_number)
	control_mode = clampi(prefs.get("control", Game.ControlMode.KID), 0, 1) as Game.ControlMode
	color_index = clampi(prefs.get("color", slot_number), 0, Game.PLAYER_COLORS.size() - 1)
	if _colors_taken().has(color_index):
		_step_color(1)
	UiKit.play(self, "select")
	_refresh()

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
			row = posmod(row - 1, ROW_COUNT)
			UiKit.play(self, "click")
		elif poll.get("down", false):
			row = posmod(row + 1, ROW_COUNT)
			UiKit.play(self, "click")
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

func _refresh() -> void:
	_empty_view.visible = state == SlotState.EMPTY
	_joined_view.visible = state != SlotState.EMPTY
	if state == SlotState.EMPTY:
		add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.PAPER, 0.55), 36, Color(UiKit.INK, 0.25), 6))
		return
	var color := Game.PLAYER_COLORS[color_index]
	add_theme_stylebox_override("panel", UiKit.box(UiKit.PAPER, 36, color, 14))
	_header.add_theme_stylebox_override("panel", UiKit.box(color, 22))
	_device_label.text = source.label
	_device_icon.texture = UiKit.icon(source.icon)

	var driver := Game.drivers[driver_index]
	var kart := Game.karts[kart_index]
	if _preview.shown_kart != kart or _preview.shown_driver != driver:
		_preview.show_kart(kart, driver)
	_row_labels[0].text = driver.display_name
	_row_labels[1].text = kart.display_name
	_row_labels[2].text = Game.CONTROL_NAMES[control_mode]
	_row_labels[3].text = Game.COLOR_NAMES[color_index]
	_mode_icon.texture = UiKit.icon("kid" if control_mode == Game.ControlMode.KID else "pro")
	_swatch.add_theme_stylebox_override("panel", UiKit.box(color, 26))

	var is_ready := state == SlotState.READY
	for i in ROW_COUNT:
		var selected := i == row and not is_ready
		_row_panels[i].add_theme_stylebox_override("panel", UiKit.box(UiKit.SUN if selected else Color(UiKit.INK, 0.06), 20))
		_row_panels[i].modulate.a = 0.45 if is_ready else 1.0
	_ready_banner.add_theme_stylebox_override("panel", UiKit.box(UiKit.GRASS if is_ready else Color(UiKit.INK, 0.35), 22))
	_ready_label.text = "Bereit!" if is_ready else "%s = Bereit" % source.accept_hint
	_ready_icon.visible = is_ready
