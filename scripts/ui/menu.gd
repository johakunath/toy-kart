extends Control
## The menu: three pages, all usable without reading.
##   1. Mode:    Freie Fahrt / Rennen / Zeitfahren
##   2. Options: Tempo (Kind / Normal / Schnell) and, for races, the number of AI karts
##   3. Players: press a button to join; each player picks driver, kart, control mode and colour
## Pages 1 and 2 use normal button focus (any pad or keyboard). Page 3 is per device.

enum Page { MODE, OPTIONS, PLAYERS }

const START_DELAY := 1.2

var _page := Page.MODE
var _pages := {}
var _mode_buttons: Array[Button] = []
var _options_title: Label
var _options_icon: TextureRect
var _speed_buttons: Array[Button] = []
var _ai_row: Control
var _ai_buttons: Array[Button] = []
var _next_button: Button
var _slot_row: HBoxContainer
var _slots: Array[PlayerSlot] = []
var _sources: Array[InputSource] = []
var _start_timer := -1.0
var _start_label: Label

func _ready() -> void:
	if Game.smoke:
		# The exported game cannot be started on another scene; "-- --smoke" jumps to the race.
		Game.start_race.call_deferred()
		return
	theme = UiKit.theme()
	add_child(UiKit.background())
	_build_mode_page()
	_build_options_page()
	_build_players_page()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _refresh_sources())
	_refresh_sources()
	_show(Page.MODE)
	if Game.smoke_args.has("shot"):
		_dev_shot()

# --- Page 1: mode --------------------------------------------------------------------------

func _build_mode_page() -> void:
	var page := _new_page(Page.MODE)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 50)
	page.add_child(column)
	column.add_child(UiKit.label("Toy Racer", 170, Color.WHITE, 36, UiKit.INK))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 44)
	column.add_child(row)
	var icons := ["wheel", "flag", "clock"]
	for i in 3:
		var button := UiKit.card_button(icons[i], Game.MODE_NAMES[i], Vector2(450, 450), 250)
		button.pressed.connect(_on_mode_picked.bind(i))
		row.add_child(button)
		_mode_buttons.append(button)
	var quit_row := HBoxContainer.new()
	quit_row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(quit_row)
	var quit := UiKit.pill_button("exit", "Ende", Vector2(220, 84))
	quit.pressed.connect(func() -> void: Game.quit_clean())
	quit_row.add_child(quit)

func _on_mode_picked(mode: int) -> void:
	Game.mode = mode as Game.Mode
	UiKit.play(self, "select")
	_show(Page.OPTIONS)

# --- Page 2: options -----------------------------------------------------------------------

func _build_options_page() -> void:
	var page := _new_page(Page.OPTIONS)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 36)
	page.add_child(column)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 24)
	_options_icon = UiKit.icon_rect("flag", 120, Color.WHITE)
	title_row.add_child(_options_icon)
	_options_title = UiKit.label("", 110, Color.WHITE, 26, UiKit.INK)
	title_row.add_child(_options_title)
	column.add_child(title_row)

	# Tempo: one, two or three arrows.
	var speed_group := ButtonGroup.new()
	var speed_row := _option_row(column, "Tempo")
	for i in 3:
		var icons: Array[String] = []
		for k in i + 1:
			icons.append("chevron")
		var button := _option_button(icons, Game.SPEED_NAMES[i], speed_group)
		button.pressed.connect(func() -> void: Game.speed_class = i as Game.SpeedClass)
		speed_row.add_child(button)
		_speed_buttons.append(button)

	# Gegner: zero to three robots.
	var ai_group := ButtonGroup.new()
	var ai_buttons_row := _option_row(column, "Gegner")
	_ai_row = ai_buttons_row.get_parent()
	for i in Game.MAX_AI + 1:
		var icons: Array[String] = []
		for k in i:
			icons.append("robot")
		var button := _option_button(icons, str(i), ai_group, Vector2(250, 150))
		button.pressed.connect(func() -> void: Game.ai_count = i)
		ai_buttons_row.add_child(button)
		_ai_buttons.append(button)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 40)
	column.add_child(nav)
	var back := UiKit.pill_button("arrow_left", "Zurück", Vector2(300, 110))
	back.pressed.connect(func() -> void: _show(Page.MODE))
	nav.add_child(back)
	_next_button = UiKit.pill_button("arrow_right", "Weiter", Vector2(420, 130))
	_next_button.add_theme_font_size_override("font_size", 56)
	_next_button.pressed.connect(func() -> void:
		Game.save_options()
		UiKit.play(self, "select")
		_show(Page.PLAYERS))
	nav.add_child(_next_button)

func _option_row(parent: Control, title: String) -> HBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 10)
	parent.add_child(block)
	block.add_child(UiKit.label(title, 46, Color.WHITE, 12, UiKit.INK))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	block.add_child(row)
	return row

func _option_button(icons: Array[String], text: String, group: ButtonGroup, min_size := Vector2(380, 150)) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = min_size
	var content := HBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for icon_name in icons:
		content.add_child(UiKit.icon_rect(icon_name, 54 if icon_name == "robot" else 44, UiKit.INK))
	var text_label := UiKit.label(text, 44)
	content.add_child(text_label)
	if not icons.is_empty():
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(10, 0)
		content.add_child(gap)
		content.move_child(gap, content.get_child_count() - 2)
	button.add_child(content)
	return button

# --- Page 3: players -----------------------------------------------------------------------

func _build_players_page() -> void:
	var page := _new_page(Page.PLAYERS)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	page.add_child(column)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 20)
	title_row.add_child(UiKit.icon_rect("gamepad", 70, Color.WHITE))
	title_row.add_child(UiKit.label("Wer fährt mit?", 66, Color.WHITE, 18, UiKit.INK))
	column.add_child(title_row)
	_slot_row = HBoxContainer.new()
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_row.add_theme_constant_override("separation", 50)
	column.add_child(_slot_row)
	_start_label = UiKit.label("", 54, UiKit.SUN, 16, UiKit.INK)
	_start_label.custom_minimum_size = Vector2(0, 66)
	column.add_child(_start_label)

func _enter_players_page() -> void:
	for slot in _slots:
		slot.queue_free()
	_slots.clear()
	var slot_count := 2 if Game.mode == Game.Mode.RACE else 1
	for i in slot_count:
		var slot := PlayerSlot.new("Knopf drücken" if i == 0 else "2. Spieler:\nKnopf drücken")
		slot.taken_colors = _colors_taken_by_others
		_slot_row.add_child(slot)
		_slots.append(slot)
	# Players from the last race are already in their seats.
	var seat := 0
	for cfg in Game.players:
		if seat < slot_count and cfg.source != null and cfg.source.is_connected_now() and _find_source(cfg.source.id) != null:
			_slots[seat].join(_find_source(cfg.source.id), seat)
			seat += 1
	for source in _sources:
		source.swallow_held()
	_start_timer = -1.0
	_start_label.text = ""

func _colors_taken_by_others(asking: PlayerSlot) -> Array:
	var taken := []
	for slot in _slots:
		if slot != asking and slot.state != PlayerSlot.SlotState.EMPTY:
			taken.append(slot.color_index)
	return taken

func _refresh_sources() -> void:
	var fresh := Game.list_sources()
	var merged: Array[InputSource] = []
	for source in fresh:
		var known := _find_source(source.id)
		if known == null:
			for cfg in Game.players:
				if cfg.source != null and cfg.source.id == source.id:
					known = cfg.source
		if known is PadSource and source is PadSource:
			(known as PadSource).device = (source as PadSource).device
			known.label = source.label
		merged.append(known if known != null else source)
	_sources = merged
	for slot in _slots:
		if slot.state != PlayerSlot.SlotState.EMPTY and _find_source(slot.source.id) == null:
			slot.leave()

func _find_source(id: String) -> InputSource:
	for source in _sources:
		if source.id == id:
			return source
	return null

func _slot_of(source: InputSource) -> PlayerSlot:
	for slot in _slots:
		if slot.state != PlayerSlot.SlotState.EMPTY and slot.source == source:
			return slot
	return null

func _process(delta: float) -> void:
	if _page != Page.PLAYERS:
		return
	var joined := 0
	for source in _sources:
		var poll := source.menu_poll()
		var slot := _slot_of(source)
		if slot != null:
			slot.handle(poll)
		elif poll.get("accept", false):
			for free_slot in _slots:
				if free_slot.state == PlayerSlot.SlotState.EMPTY:
					free_slot.join(source, _slots.find(free_slot))
					break
	var all_ready := true
	for slot in _slots:
		if slot.state != PlayerSlot.SlotState.EMPTY:
			joined += 1
			all_ready = all_ready and slot.state == PlayerSlot.SlotState.READY
	if joined > 0 and all_ready:
		if _start_timer < 0.0:
			_start_timer = START_DELAY
			_start_label.text = "Los geht's!"
		_start_timer -= delta
		if _start_timer <= 0.0:
			_start_race()
	else:
		_start_timer = -1.0
		_start_label.text = ""

func _start_race() -> void:
	Game.players.clear()
	for slot in _slots:
		if slot.state == PlayerSlot.SlotState.READY:
			Game.players.append(slot.config())
	set_process(false)
	Game.start_race()

# --- Page switching ------------------------------------------------------------------------

func _new_page(page: Page) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_pages[page] = center
	return center

func _show(page: Page) -> void:
	_page = page
	for key: Page in _pages:
		(_pages[key] as Control).visible = key == page
	match page:
		Page.MODE:
			_mode_buttons[Game.mode].grab_focus()
		Page.OPTIONS:
			_options_title.text = Game.MODE_NAMES[Game.mode]
			_options_icon.texture = UiKit.icon(["wheel", "flag", "clock"][Game.mode])
			_ai_row.visible = Game.mode == Game.Mode.RACE
			_speed_buttons[Game.speed_class].button_pressed = true
			_ai_buttons[Game.ai_count].button_pressed = true
			_next_button.grab_focus()
		Page.PLAYERS:
			_enter_players_page()

func _unhandled_input(event: InputEvent) -> void:
	if _page == Page.OPTIONS and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show(Page.MODE)
	elif _page == Page.PLAYERS:
		# Esc always goes back. A pad's B button goes back only when nobody has joined yet,
		# because inside a panel B means "leave my seat".
		var key := event as InputEventKey
		var button := event as InputEventJoypadButton
		var anyone := false
		for slot in _slots:
			anyone = anyone or slot.state != PlayerSlot.SlotState.EMPTY
		if (key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE) \
				or (button and button.pressed and button.button_index == JOY_BUTTON_B and not anyone):
			get_viewport().set_input_as_handled()
			_show(Page.OPTIONS)

# --- Dev helper: "-- --shot=<png> --page=mode|options|players" saves a picture of a page ---

func _dev_shot() -> void:
	var page_name: String = Game.smoke_args.get("page", "mode")
	if page_name != "mode":
		Game.mode = Game.Mode.RACE
		_show(Page.OPTIONS)
	if page_name == "players":
		_show(Page.PLAYERS)
		_slots[0].join(_sources[0], 0)
		_slots[1].join(_sources[1], 1)
		_slots[1].control_mode = Game.ControlMode.FULL
		_slots[1].handle({"accept": true})
		_slots[0].handle({"down": true})
		set_process(false)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(Game.smoke_args["shot"])
	Game.quit_clean()
