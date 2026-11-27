extends Control
## The menu: three pages, all usable without reading.
##   1. Mode:    Freie Fahrt / Rennen / Team (a race: all players against the toys) / Pokal
##               (three races in a row, Game.cup) / Zeitfahren
##   2. Options: Tempo (Kind / Normal / Schnell) and, for races, the number of AI karts
##   3. Players: press a button to join; each player picks driver, kart, control mode and colour
## Pages 1 and 2 use normal button focus (any pad or keyboard). Page 3 is per device.

enum Page { MODE, OPTIONS, PLAYERS }

const START_DELAY := 1.2
## A player just left his seat (B is also a kid's horn button): the others do not start
## without him for this long, so he can sit down again.
const LEFT_GRACE := 4.0
## A seat kept from the last race gives way after this long when its device stays silent
## while everybody else is ready (dad's keyboard must not block a kid who drives alone).
const IDLE_SEAT := 5.0
const QUIT_CONFIRM := 3.0  ## "Ende" needs a second press within this time

var _page := Page.MODE
var _pages := {}
var _mode_buttons := {}  ## Game.Mode -> its card
var _team_button: Button
var _cup_button: Button
var _track_block: Control
var _options_title: Label
var _options_icon: TextureRect
var _speed_buttons: Array[Button] = []
var _track_buttons: Array[Button] = []
var _ai_row: Control
var _ai_buttons: Array[Button] = []
var _next_button: Button
var _slot_row: HBoxContainer
var _slots: Array[PlayerSlot] = []
var _sources: Array[InputSource] = []
var _start_timer := -1.0
var _grace := 0.0
var _idle_wait := 0.0
var _seated_before: Array[InputSource] = []  ## who sat where when the players page was left
var _quit_armed := 0.0
var _quit_button: Button
var _start_label: Label
var _swap_button: Button
var _music_button: Button
var _rumble_button: Button

func _ready() -> void:
	if Game.smoke:
		# The exported game cannot be started on another scene; "-- --smoke" jumps to the race.
		Game.start_race.call_deferred()
		return
	theme = MenuStyle.theme()
	add_child(UiKit.background())
	if MenuBackdrop.wanted():
		add_child(MenuBackdrop.new())  # a slow flight over the tracks behind the cards
	Music.play("menu")
	_build_mode_page()
	_build_options_page()
	_build_players_page()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _refresh_sources())
	_refresh_sources()
	_show(Page.MODE)
	if Game.smoke_args.has("shot"):
		_dev_shot()
	elif Game.smoke_args.has("perf"):
		_dev_perf()

# --- Page 1: mode --------------------------------------------------------------------------

func _build_mode_page() -> void:
	var page := _new_page(Page.MODE)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 50)
	page.add_child(column)
	# The logo (or the cartoon title) gently bobs; the holder keeps the layout still.
	var logo := MenuStyle.logo(220)
	var logo_holder := MenuStyle.holder(logo)
	logo_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(logo_holder)
	MenuStyle.bob(logo)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	column.add_child(row)
	# Big coloured cards, one colour per mode: [icon, label, colour, mode, team, cup].
	var cards := [
		["wheel", Game.MODE_NAMES[Game.Mode.FREE_DRIVE], MenuStyle.MODE_COLORS[0], Game.Mode.FREE_DRIVE, false, false],
		["search", Game.MODE_NAMES[Game.Mode.EXPLORE], MenuStyle.EXPLORE_COLOR, Game.Mode.EXPLORE, false, false],
		["flag", Game.MODE_NAMES[Game.Mode.RACE], MenuStyle.MODE_COLORS[1], Game.Mode.RACE, false, false],
		["team", "Team", MenuStyle.MODE_COLORS[2], Game.Mode.RACE, true, false],
		["trophy", "Pokal", MenuStyle.MODE_COLORS[3], Game.Mode.RACE, false, true],
		["clock", Game.MODE_NAMES[Game.Mode.TIME_TRIAL], MenuStyle.MODE_COLORS[4], Game.Mode.TIME_TRIAL, false, false],
	]
	var card_size := Vector2(282, 400)
	for spec: Array in cards:
		var button := MenuStyle.mode_card(spec[0], spec[1], spec[2], card_size)
		button.pressed.connect(_on_mode_picked.bind(spec[3], spec[4], spec[5]))
		row.add_child(MenuStyle.holder(button))
		MenuStyle.pop_on_focus(button)
		if spec[4]:
			_team_button = button
		elif spec[5]:
			_cup_button = button
		else:
			_mode_buttons[spec[3]] = button
	var quit_row := HBoxContainer.new()
	quit_row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(quit_row)
	# Two presses close the game: one stray press (down, then A) must not end the evening.
	var quit := UiKit.pill_button("exit", "Ende", Vector2(220, 84))
	_quit_button = quit
	quit.pressed.connect(_on_quit_pressed)
	quit.focus_exited.connect(_disarm_quit)
	quit_row.add_child(quit)
	MenuStyle.pop_on_focus(quit, 1.05)

func _on_quit_pressed() -> void:
	if _quit_armed > 0.0:
		Game.quit_clean()
		return
	_quit_armed = QUIT_CONFIRM
	_quit_button.text = "Ende?"
	_quit_button.add_theme_stylebox_override("normal", MenuStyle.card(UiKit.SUN, 28, UiKit.INK, 5, 10))
	MenuStyle.bounce(_quit_button, 0.9)
	UiKit.play(self, "click")

func _disarm_quit() -> void:
	_quit_armed = 0.0
	_quit_button.text = "Ende"
	_quit_button.remove_theme_stylebox_override("normal")

func _on_mode_picked(mode: int, team := false, cup := false) -> void:
	Game.mode = mode as Game.Mode
	Game.team_race = team
	Game.cup = cup
	UiKit.play(self, "select")
	_show(Page.OPTIONS)

# --- Page 2: options -----------------------------------------------------------------------

func _build_options_page() -> void:
	var page := _new_page(Page.OPTIONS)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	page.add_child(column)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 24)
	_options_icon = UiKit.icon_rect("flag", 90, Color.WHITE)
	title_row.add_child(_options_icon)
	_options_title = MenuStyle.shadowed(UiKit.label("", 84, Color.WHITE, 22, UiKit.INK))
	title_row.add_child(_options_title)
	column.add_child(title_row)

	# Strecke: each button shows the shape of its track.
	var track_group := ButtonGroup.new()
	var track_row := _option_row(column, "Strecke")
	_track_block = track_row.get_parent() as Control
	# Four or more tracks share the row: narrower buttons, smaller outlines.
	var track_width := minf(500.0, (1820.0 - 24.0 * (Game.tracks.size() - 1)) / maxf(1.0, Game.tracks.size()))
	var outline_size := 140.0 if track_width >= 480.0 else 104.0
	for i in Game.tracks.size():
		var def := Game.tracks[i]
		var button := _option_button([], def.display_name, track_group, Vector2(track_width, 170))
		var content := button.get_child(0) as BoxContainer
		if track_width < 480.0:
			# Long names ("Wohnzimmer", "Riesenrunde") must stay inside the narrower button.
			(content.get_child(0) as Label).add_theme_font_size_override("font_size", 36)
		var icon := TrackIcon.new(def.outline)
		icon.custom_minimum_size = Vector2(outline_size, outline_size)
		content.add_child(icon)
		content.move_child(icon, 0)
		content.add_theme_constant_override("separation", 18)
		button.pressed.connect(func() -> void: Game.track = def)
		track_row.add_child(button)
		_track_buttons.append(button)

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
		var button := _option_button(icons, str(i), ai_group, Vector2(250, 120))
		button.pressed.connect(func() -> void: Game.ai_count = i)
		ai_buttons_row.add_child(button)
		_ai_buttons.append(button)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 40)
	column.add_child(nav)
	# Back, music and rumble are icons only; "Weiter" is the one big button with a word.
	var back := UiKit.pill_button("arrow_left", "", Vector2(160, 100))
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.pressed.connect(func() -> void: _show(Page.MODE))
	nav.add_child(back)
	_music_button = UiKit.pill_button("music", "", Vector2(160, 100))
	_music_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_music_button.pressed.connect(func() -> void:
		Game.music_on = not Game.music_on
		Game.save_options()
		_refresh_music_button()
		Music.refresh("menu"))
	nav.add_child(_music_button)
	_refresh_music_button()
	_rumble_button = UiKit.pill_button("gamepad", "", Vector2(160, 100))
	_rumble_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rumble_button.pressed.connect(func() -> void:
		Game.rumble_on = not Game.rumble_on
		Game.save_options()
		_refresh_rumble_button()
		if Game.rumble_on:
			for pad in Input.get_connected_joypads():
				Input.start_joy_vibration(pad, 0.4, 0.6, 0.25))
	nav.add_child(_rumble_button)
	_refresh_rumble_button()
	_next_button = UiKit.pill_button("arrow_right", "Weiter", Vector2(420, 112))
	_next_button.add_theme_font_size_override("font_size", 56)
	MenuStyle.primary(_next_button)
	_next_button.pressed.connect(func() -> void:
		Game.save_options()
		UiKit.play(self, "select")
		_show(Page.PLAYERS))
	nav.add_child(_next_button)
	for nav_button in nav.get_children():
		MenuStyle.pop_on_focus(nav_button as Control, 1.06)

## Icon only: a faded pad means "no rumble".
func _refresh_rumble_button() -> void:
	_rumble_button.modulate = Color.WHITE if Game.rumble_on else Color(1, 1, 1, 0.4)

func _refresh_music_button() -> void:
	_music_button.icon = UiKit.icon("music" if Game.music_on else "music_off")

func _option_row(parent: Control, title: String) -> HBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	parent.add_child(block)
	block.add_child(MenuStyle.shadowed(UiKit.label(title, 40, Color.WHITE, 12, UiKit.INK)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	block.add_child(row)
	return row

func _option_button(icons: Array[String], text: String, group: ButtonGroup, min_size := Vector2(380, 120)) -> Button:
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
	MenuStyle.pop_on_focus(button, 1.05)
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
	title_row.add_child(MenuStyle.title("Wer fährt mit?", 62, UiKit.SUN))
	column.add_child(title_row)
	_slot_row = HBoxContainer.new()
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_row.add_theme_constant_override("separation", 30)
	column.add_child(_slot_row)
	# Between the two panels: one big button that swaps the sides (also Tab or a pad's View button).
	_swap_button = Button.new()
	_swap_button.icon = UiKit.icon("swap")
	_swap_button.expand_icon = true
	_swap_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_swap_button.custom_minimum_size = Vector2(150, 150)
	_swap_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_swap_button.add_theme_constant_override("icon_max_width", 96)
	# Never takes focus: Space or Enter must not press it by accident.
	_swap_button.focus_mode = Control.FOCUS_NONE
	_swap_button.pressed.connect(_swap_sides)
	_slot_row.add_child(_swap_button)
	_start_label = UiKit.label("", 54, UiKit.SUN, 16, UiKit.INK)
	_start_label.custom_minimum_size = Vector2(0, 66)
	column.add_child(_start_label)

func _enter_players_page() -> void:
	for slot in _slots:
		slot.queue_free()
	_slots.clear()
	# Only the time trial is for one driver. Free drive has two seats too ("catch Papa" needs a
	# kid and a grown-up); one player alone just leaves the other seat empty.
	var slot_count := 1 if Game.mode == Game.Mode.TIME_TRIAL else 2
	for i in slot_count:
		var slot := PlayerSlot.new(i if slot_count > 1 else -1)
		slot.taken_colors = _colors_taken_by_others
		_slot_row.add_child(slot)
		_slots.append(slot)
	_place_swap_button()
	# Players from the last race (or from before going back a page) are already in their
	# seats. Such a seat is "kept": see IDLE_SEAT.
	var returning: Array[InputSource] = _seated_before.duplicate()
	var same_sides := not returning.is_empty()
	if returning.is_empty():
		for cfg in Game.players:
			returning.append(cfg.source)
	var seat := 0
	for i in returning.size():
		var source := returning[i]
		if source == null or not source.is_connected_now() or _find_source(source.id) == null:
			continue
		# The same side as before where that seat exists and is free, else the next free seat.
		var want := i if same_sides and i < slot_count and _slots[i].state == PlayerSlot.SlotState.EMPTY else -1
		while want < 0 and seat < slot_count:
			if _slots[seat].state == PlayerSlot.SlotState.EMPTY:
				want = seat
			seat += 1
		if want < 0:
			break
		_slots[want].join(_find_source(source.id), want)
		_slots[want].kept = true
	_seated_before.clear()
	_grace = 0.0
	_idle_wait = 0.0
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
	var old: Array[InputSource] = _sources.duplicate()
	for cfg in Game.players:
		if cfg.source != null and not old.has(cfg.source):
			old.append(cfg.source)
	var connected := Input.get_connected_joypads()
	for source in fresh:
		var known: InputSource = null
		var pad := source as PadSource
		if pad:
			# The pad we know on this device number is this pad. Two pads of one model share
			# their id scheme (model + order switched on), and the order shifts when one of
			# them drops out: matching by id would hand dad's seat to the kid's pad.
			for o in old:
				if o is PadSource and (o as PadSource).device == pad.device and not merged.has(o):
					known = o
		if known == null:
			for o in old:
				var taken := o is PadSource and connected.has((o as PadSource).device)
				if o.id == source.id and not merged.has(o) and not (pad and taken):
					known = o
			# A pad that came back on another device number.
			if known is PadSource and pad:
				(known as PadSource).device = pad.device
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
	if _quit_armed > 0.0:
		_quit_armed -= delta
		if _quit_armed <= 0.0:
			_disarm_quit()
	if _page != Page.PLAYERS:
		return
	var joined := 0
	for source in _sources:
		var poll := source.menu_poll()
		var slot := _slot_of(source)
		if slot != null:
			slot.handle(poll)
			if slot.state == PlayerSlot.SlotState.EMPTY:
				_grace = LEFT_GRACE  # he left his seat: give him time to come back
		else:
			# Left or right takes the seat on that side. The join button takes the device's home
			# seat (W A S D left, arrow keys right), else the first free one.
			var want := -1
			if _slots.size() > 1 and poll.get("left", false):
				want = 0
			elif _slots.size() > 1 and poll.get("right", false):
				want = 1
			elif poll.get("accept", false):
				var home := _home_seat(source)
				if home >= 0 and _slots[home].state == PlayerSlot.SlotState.EMPTY:
					want = home
				else:
					for k in _slots.size():
						if _slots[k].state == PlayerSlot.SlotState.EMPTY:
							want = k
							break
			# Pushing toward a seat somebody has already taken: the free seat instead.
			if want >= 0 and _slots[want].state != PlayerSlot.SlotState.EMPTY:
				want = 1 - want if _slots.size() > 1 and _slots[1 - want].state == PlayerSlot.SlotState.EMPTY else -1
			if want >= 0 and _slots[want].state == PlayerSlot.SlotState.EMPTY:
				_slots[want].join(source, want)
				source.swallow_held()
	var all_ready := true
	var idle: Array[PlayerSlot] = []
	for slot in _slots:
		slot.modulate.a = 1.0
		if slot.state == PlayerSlot.SlotState.JOINED and slot.kept:
			idle.append(slot)  # kept from the last race, nothing pressed yet
		elif slot.state != PlayerSlot.SlotState.EMPTY:
			joined += 1
			all_ready = all_ready and slot.state == PlayerSlot.SlotState.READY
	_grace = maxf(_grace - delta, 0.0)
	if joined > 0 and all_ready and not idle.is_empty():
		# Everybody who is here is ready: a silent kept seat fades and then gives way.
		_idle_wait += delta
		for slot in idle:
			slot.modulate.a = lerpf(1.0, 0.35, _idle_wait / IDLE_SEAT)
			if _idle_wait >= IDLE_SEAT:
				slot.leave()
		all_ready = false
	else:
		_idle_wait = 0.0
		all_ready = all_ready and idle.is_empty() and _grace <= 0.0
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

## Two keyboard players: W A S D sits left, the arrow keys sit right (DECISIONS.md).
func _home_seat(source: InputSource) -> int:
	if _slots.size() > 1 and source is KeyboardSource:
		return clampi((source as KeyboardSource).layout, 0, 1)
	return -1

## Panels stay where they are; only this swaps them (button, Tab, or a pad's View button).
## The panel order is the screen order of the race: left panel = left half.
func _swap_sides() -> void:
	if _slots.size() < 2:
		return
	var a := _slots[0]
	_slots[0] = _slots[1]
	_slots[1] = a
	_slots[0].set_side(0)
	_slots[1].set_side(1)
	_place_swap_button()
	_start_timer = -1.0
	_grace = 0.0
	UiKit.play(self, "pop")

## Order in the row: left panel, swap button, right panel. The button shows only with two seats.
func _place_swap_button() -> void:
	if _slots.size() > 1:
		_slot_row.move_child(_slots[0], 0)
		_slot_row.move_child(_swap_button, 1)
		_slot_row.move_child(_slots[1], 2)
	_swap_button.visible = _slots.size() > 1

func _start_race() -> void:
	Game.players.clear()
	for slot in _slots:
		if slot.state == PlayerSlot.SlotState.READY:
			Game.players.append(slot.config())
	set_process(false)
	if Game.cup:
		Game.start_cup()
	else:
		Game.start_race()

# --- Page switching ------------------------------------------------------------------------

func _new_page(page: Page) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_pages[page] = center
	return center

func _show(page: Page) -> void:
	if _page == Page.PLAYERS and page != Page.PLAYERS:
		# Going back keeps the seats and the picks for the way forward again.
		_seated_before.clear()
		for slot in _slots:
			_seated_before.append(slot.source if slot.state != PlayerSlot.SlotState.EMPTY else null)
			if slot.state != PlayerSlot.SlotState.EMPTY:
				slot.save_prefs()
	_page = page
	for key: Page in _pages:
		(_pages[key] as Control).visible = key == page
	MenuStyle.page_in(_pages[page] as Control)
	match page:
		Page.MODE:
			(_cup_button if Game.cup or Game.came_from_cup else _team_button if Game.team_race else _mode_buttons[Game.mode] as Button).grab_focus()
			Game.came_from_cup = false
		Page.OPTIONS:
			_options_title.text = "Pokal" if Game.cup else "Team-Rennen" if Game.team_race else Game.MODE_NAMES[Game.mode]
			_options_icon.texture = UiKit.icon("trophy" if Game.cup else "team" if Game.team_race else ["wheel", "flag", "clock", "search"][Game.mode])
			# A cup always drives its three tracks; Entdecken is always the open living room.
			_track_block.visible = not Game.cup and Game.mode != Game.Mode.EXPLORE
			_ai_row.visible = Game.mode == Game.Mode.RACE
			_speed_buttons[Game.speed_class].button_pressed = true
			var track_index := Game.tracks.find(Game.track)
			if track_index >= 0:
				_track_buttons[track_index].button_pressed = true
			# Team is "us against the toys": there is always at least one toy (the race adds it).
			_ai_buttons[0].visible = not Game.team_race
			_ai_buttons[maxi(Game.ai_count, 1) if Game.team_race else Game.ai_count].button_pressed = true
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

## Tab (or a pad's View button) swaps the sides. Read before the GUI, so focus moves never eat it.
func _input(event: InputEvent) -> void:
	if _page == Page.PLAYERS and _is_swap_press(event):
		get_viewport().set_input_as_handled()
		_swap_sides()

func _is_swap_press(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_TAB:
		return true
	var button := event as InputEventJoypadButton
	return button != null and button.pressed and button.button_index == JOY_BUTTON_BACK

# --- Dev helper: "-- --shot=<png> --page=mode|options|players" saves a picture of a page ---

func _dev_shot() -> void:
	var page_name: String = Game.smoke_args.get("page", "mode")
	if page_name != "mode":
		# "--mode=free|explore|trial|team|cup": the pages as that mode shows them.
		var mode_name: String = Game.smoke_args.get("mode", "race")
		Game.mode = {"free": Game.Mode.FREE_DRIVE, "trial": Game.Mode.TIME_TRIAL, "explore": Game.Mode.EXPLORE}.get(mode_name, Game.Mode.RACE)
		Game.team_race = mode_name == "team"
		Game.cup = mode_name == "cup"
		_show(Page.OPTIONS)
	if page_name == "join":
		_show(Page.PLAYERS)
		set_process(false)
	if page_name == "players":
		_show(Page.PLAYERS)
		# Both on the keyboard, as a new family would see it: W A S D (Profi) left,
		# arrow keys (Kind) right and ready. "--swap=1" presses the swap button.
		Game.set("_settings", ConfigFile.new())
		# "--pad=1": two (pretend) pads instead of the two keyboard halves, left Profi.
		var pads: bool = Game.smoke_args.get("pad", "0") == "1"
		_slots[0].join(PadSource.new(0, 0) if pads else _sources[0], 0)
		_slots[1].join(PadSource.new(1, 1) if pads else _sources[1], 1)
		if pads:
			_slots[0].control_mode = Game.ControlMode.FULL
		_slots[1].handle({"accept": true})
		_slots[0].handle({"down": true})
		if Game.smoke_args.get("swap", "0") == "1":
			_swap_sides()
		set_process(false)
	await get_tree().create_timer(float(Game.smoke_args.get("shot_at", "1.0"))).timeout
	get_viewport().get_texture().get_image().save_png(Game.smoke_args["shot"])
	Game.quit_clean()

## "-- --perf=<page> [--seconds=N]": average frame rate of a menu page (run with --disable-vsync).
func _dev_perf() -> void:
	var page_name: String = Game.smoke_args.get("perf", "mode")
	if page_name == "players":
		Game.mode = Game.Mode.RACE
		_show(Page.PLAYERS)
		Game.set("_settings", ConfigFile.new())
		_slots[0].join(_sources[0], 0)
		_slots[1].join(_sources[1], 1)
		set_process(false)
	await get_tree().create_timer(2.0).timeout
	var seconds := float(Game.smoke_args.get("seconds", "10"))
	var frames := Engine.get_frames_drawn()
	var start := Time.get_ticks_usec()
	var last := start
	var worst := 0
	while Time.get_ticks_usec() - start < seconds * 1000000.0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
	var fps := (Engine.get_frames_drawn() - frames) / ((Time.get_ticks_usec() - start) / 1000000.0)
	print("MENU PERF page=%s backdrop=%s fps=%.1f worst_frame_ms=%.1f" % [page_name,
		Game.smoke_args.get("backdrop", "1"), fps, worst / 1000.0])
	Game.quit_clean()
