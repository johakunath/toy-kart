class_name FinishScreen extends Control
## The finish screen celebrates everyone: confetti, applause, every kart on show.
## The placing is there, but small: medals for the first three. In a team race the banner shows
## how the team did. The family brick jar shows what everyone collected together.
## In a cup every card also shows the stars from this race and the stars so far, a row of track
## shapes shows how far the cup is, and after the last race the cards line up by stars and
## every player gets a trophy.

const LOCK_SECONDS := 2.5
const MEDALS: Array[Color] = [Color("ffc81e"), Color("dfe6ee"), Color("e0894a")]

var _again: Button
var _lock := 0.0
var _buttons: HBoxContainer
var _present: Control
var _present_open := false
var _time := 0.0

func _init() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()

func open(racers: Array[Racer], humans: Array[Racer], new_record: bool, bricks := 0, team := false) -> void:
	visible = true
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_add_confetti()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	var extra_rows := int(team) + int(bricks > 0 or Game.family_bricks() > 0) + int(Game.cup) * 2 + 1
	column.add_theme_constant_override("separation", 26 - 6 * extra_rows)
	center.add_child(column)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 24)
	title_row.add_child(UiKit.icon_rect("star", 110, UiKit.SUN))
	var best_place := 99
	for h in humans:
		best_place = mini(best_place, h.place)
	var title := "Super gemacht!"
	if team:
		title = "Team gewinnt!" if best_place == 1 else "Super, Team!"
	var cup_end := Game.cup and Game.is_last_cup_race()
	if cup_end:
		title = "Pokal!"
		title_row.get_child(0).queue_free()
		title_row.add_child(UiKit.icon_rect("trophy", 120, MEDALS[0]))
		title_row.move_child(title_row.get_child(title_row.get_child_count() - 1), 0)
	title_row.add_child(UiKit.label(title, 120, Color.WHITE, 26, UiKit.INK))
	title_row.add_child(UiKit.icon_rect("star", 110, UiKit.SUN))
	column.add_child(title_row)

	var order := racers.duplicate()
	order.sort_custom(func(a: Racer, b: Racer) -> bool: return a.place < b.place)
	if cup_end:
		# Most stars first; on a tie the better place in the last race.
		order.sort_custom(func(a: Racer, b: Racer) -> bool:
			var sa := int(Game.cup_stars.get(a.cup_key(), 0))
			var sb := int(Game.cup_stars.get(b.cup_key(), 0))
			return sa > sb or (sa == sb and a.place < b.place))
	if Game.cup:
		column.add_child(_cup_progress())
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 22)
	column.add_child(cards)
	var card_width := (330.0 if order.size() <= 3 else 290.0) - 30.0 * extra_rows
	for k in order.size():
		var racer: Racer = order[k]
		var card := _make_card(racer, card_width, Game.mode == Game.Mode.RACE and order.size() > 1 and not cup_end)
		if Game.cup:
			(card.get_child(0) as VBoxContainer).add_child(_cup_stars(racer, k, cup_end))
		cards.add_child(card)

	if team:
		column.add_child(_team_row(humans, best_place))
	if bricks > 0 or Game.family_bricks() > 0:
		column.add_child(_jar_row(bricks))

	if Game.mode == Game.Mode.TIME_TRIAL and not humans.is_empty():
		var best := Game.best_time(Game.speed_class)
		var text := "Zeit  %s" % UiKit.format_time(humans[0].finish_time)
		if new_record:
			text += "   Neuer Rekord!"
		elif best > 0.0:
			text += "   Bestzeit  %s" % UiKit.format_time(best)
		var time_row := HBoxContainer.new()
		time_row.alignment = BoxContainer.ALIGNMENT_CENTER
		time_row.add_theme_constant_override("separation", 18)
		time_row.add_child(UiKit.icon_rect("clock", 80, Color.WHITE))
		time_row.add_child(UiKit.label(text, 64, UiKit.SUN if new_record else Color.WHITE, 16, UiKit.INK))
		column.add_child(time_row)

	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 36)
	_buttons.modulate.a = 0.0
	column.add_child(_buttons)
	var button_size := Vector2(300, 230 - 25 * extra_rows)
	if Game.cup and not cup_end:
		_again = UiKit.card_button("play", "Weiter", button_size, 110 - 15 * extra_rows)
		_again.pressed.connect(func() -> void: Game.next_cup_race())
	elif Game.cup:
		_again = UiKit.card_button("restart", "Nochmal", button_size, 110 - 15 * extra_rows)
		_again.pressed.connect(func() -> void: Game.start_cup())
	else:
		_again = UiKit.card_button("restart", "Nochmal", button_size, 110 - 15 * extra_rows)
		_again.pressed.connect(func() -> void: Game.start_race())
	_again.disabled = true
	_buttons.add_child(_again)
	var home := UiKit.card_button("home", "Menü", button_size, 110 - 15 * extra_rows)
	home.pressed.connect(func() -> void: Game.go_to_menu())
	home.disabled = true
	_buttons.add_child(home)
	if Game.mode != Game.Mode.FREE_DRIVE:
		var present_row := _make_present(button_size.y)
		column.add_child(present_row)
		column.move_child(present_row, _buttons.get_index())

	# Buttons wake up after a moment, so button mashing does not skip the party.
	_lock = LOCK_SECONDS
	UiKit.play(self, "applause", -2.0)
	UiKit.play(self, "fanfare", -6.0)

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _present and not _present_open:
		# The wrapped present wobbles until it pops open, just before the buttons wake up.
		_present.rotation = sin(_time * 9.0) * 0.08
		if _time > LOCK_SECONDS - 0.6:
			_open_present()
	if _lock <= 0.0:
		return
	_lock -= delta
	if _lock <= 0.0:
		for button: Button in _buttons.get_children():
			button.disabled = false
		_buttons.modulate.a = 1.0
		_again.grab_focus()

func _make_card(racer: Racer, width: float, show_place: bool) -> Control:
	var card := PanelContainer.new()
	var border := racer.color if racer.is_human else Color(UiKit.INK, 0.2)
	card.add_theme_stylebox_override("panel", UiKit.box(UiKit.PAPER, 30, border, 12 if racer.is_human else 4))
	card.custom_minimum_size = Vector2(width, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)

	var preview := KartPreview.new()
	preview.cheering = true
	preview.spin_speed = 1.0
	preview.custom_minimum_size = Vector2(width - 40, width - 60)
	if racer.is_human:
		preview.stickers = Game.sticker_ids()
	column.add_child(preview)
	preview.show_kart(racer.kart_def, racer.driver)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 10)
	if not racer.is_human:
		name_row.add_child(UiKit.icon_rect("robot", 40, Color(UiKit.INK, 0.6)))
	name_row.add_child(UiKit.label(racer.display_name, 40))
	column.add_child(name_row)
	if show_place:
		if racer.place <= MEDALS.size():
			var medal := PanelContainer.new()
			medal.add_theme_stylebox_override("panel", UiKit.box(MEDALS[racer.place - 1], 30, UiKit.INK, 4))
			medal.custom_minimum_size = Vector2(64, 64)
			medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			medal.add_child(UiKit.label("%d" % racer.place, 34, UiKit.INK))
			column.add_child(medal)
		else:
			column.add_child(UiKit.label("%d." % racer.place, 30, Color(UiKit.INK, 0.6)))
	return card

## A wrapped present (red box, yellow ribbon) with this race's new sticker inside.
func _make_present(height: float) -> Control:
	var holder := CenterContainer.new()
	var side := clampf(height * 0.7, 110.0, 150.0)
	holder.custom_minimum_size = Vector2(0, side + 10.0)
	var box := Control.new()
	box.custom_minimum_size = Vector2(side, side)
	box.pivot_offset = Vector2(side, side) * 0.5
	holder.add_child(box)
	var wrap := Panel.new()
	wrap.name = "Wrap"
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_theme_stylebox_override("panel", UiKit.box(Color("e8243c"), 14, Color.WHITE, 5))
	box.add_child(wrap)
	for vertical: bool in [true, false]:
		var ribbon := ColorRect.new()
		ribbon.color = UiKit.SUN
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if vertical:
			ribbon.anchor_left = 0.42
			ribbon.anchor_right = 0.58
			ribbon.anchor_bottom = 1.0
		else:
			ribbon.anchor_top = 0.42
			ribbon.anchor_bottom = 0.58
			ribbon.anchor_right = 1.0
		wrap.add_child(ribbon)
	var bow := UiKit.icon_rect("star", side * 0.45, UiKit.SUN)
	bow.position = Vector2(side * 0.275, -side * 0.3)
	wrap.add_child(bow)
	var inside := TextureRect.new()
	inside.name = "Inside"
	inside.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inside.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inside.set_anchors_preset(Control.PRESET_FULL_RECT)
	inside.visible = false
	inside.texture = Game.sticker_texture(Game.last_sticker) if Game.last_sticker != "" else UiKit.icon("item_superstar")
	box.add_child(inside)
	_present = box
	return holder

func _open_present() -> void:
	_present_open = true
	_present.rotation = 0.0
	(_present.get_node("Wrap") as Control).visible = false
	(_present.get_node("Inside") as Control).visible = true
	_present.scale = Vector2.ONE * 0.3
	var tween := create_tween()
	tween.tween_property(_present, "scale", Vector2.ONE * 1.25, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_present, "scale", Vector2.ONE, 0.25)
	UiKit.play(self, "pop")
	UiKit.play(self, "star", -3.0)

## The cup so far: one track shape per race; done races bright, this one ringed, next ones dim.
func _cup_progress() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	var tracks := Game.cup_tracks()
	for i in tracks.size():
		var panel := PanelContainer.new()
		var here := i == Game.cup_round
		var fill := Color(1, 1, 1, 0.9) if i <= Game.cup_round else Color(1, 1, 1, 0.3)
		panel.add_theme_stylebox_override("panel", UiKit.box(fill, 24, UiKit.SUN if here else UiKit.INK, 8 if here else 3))
		var icon := TrackIcon.new(tracks[i].outline)
		icon.custom_minimum_size = Vector2(78, 78)
		panel.add_child(icon)
		row.add_child(panel)
	return row

## A card's cup line: this race's stars as little stars, and the total so far (with a trophy
## after the last race: gold, silver, bronze; every player gets one, in their colour if 4th+).
func _cup_stars(racer: Racer, rank: int, cup_end: bool) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var key := racer.cup_key()
	var won := int(Game.cup_last.get(key, 0))
	var little := HBoxContainer.new()
	little.alignment = BoxContainer.ALIGNMENT_CENTER
	little.add_theme_constant_override("separation", -6)
	for i in won:
		little.add_child(UiKit.icon_rect("star", 30, UiKit.SUN))
	column.add_child(little)
	var total := HBoxContainer.new()
	total.alignment = BoxContainer.ALIGNMENT_CENTER
	total.add_theme_constant_override("separation", 8)
	if cup_end and (rank < MEDALS.size() or racer.is_human):
		var color := MEDALS[rank] if rank < MEDALS.size() else racer.color
		total.add_child(UiKit.icon_rect("trophy", 64, color))
	total.add_child(UiKit.icon_rect("star", 44, UiKit.SUN))
	total.add_child(UiKit.label("%d" % int(Game.cup_stars.get(key, 0)), 44, UiKit.INK))
	column.add_child(total)
	return column

## Team banner: the team icon, every human's face, and the team's place (its best driver's).
func _team_row(humans: Array[Racer], best_place: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.55), 40))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	row.add_child(UiKit.icon_rect("team", 90, Color.WHITE))
	for h in humans:
		var face := UiKit.rounded_picture(90, 45)
		if h.driver and h.driver.portrait:
			(face.get_child(0) as TextureRect).texture = h.driver.portrait
		face.add_theme_stylebox_override("panel", UiKit.box(h.color, 45))
		row.add_child(face)
	var color := MEDALS[best_place - 1] if best_place <= MEDALS.size() else Color.WHITE
	row.add_child(UiKit.icon_rect("trophy", 90, color))
	row.add_child(UiKit.label("%d." % best_place, 80, color, 16, UiKit.INK))
	return panel

## The family jar: bricks from this race plus everything collected before.
func _jar_row(bricks: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(UiKit.icon_rect("brick", 80, Color.WHITE))
	if bricks > 0:
		row.add_child(UiKit.label("+%d" % bricks, 64, UiKit.SUN, 16, UiKit.INK))
	# The jar: everything the family has collected so far.
	var jar := PanelContainer.new()
	jar.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.85), 30, UiKit.INK, 5))
	jar.add_child(UiKit.label("%d" % Game.family_bricks(), 54, UiKit.INK))
	row.add_child(jar)
	return row

func _add_confetti() -> void:
	var confetti := CPUParticles2D.new()
	confetti.position = Vector2(960, -40)
	confetti.amount = 220
	confetti.lifetime = 5.0
	confetti.preprocess = 1.0
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(1100, 10)
	confetti.direction = Vector2(0, 1)
	confetti.spread = 25.0
	confetti.gravity = Vector2(0, 260)
	confetti.initial_velocity_min = 120.0
	confetti.initial_velocity_max = 320.0
	confetti.angular_velocity_min = -260.0
	confetti.angular_velocity_max = 260.0
	confetti.scale_amount_min = 12.0
	confetti.scale_amount_max = 24.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color("e8483f"), Color("f2b90f"), Color("3fbf5f"), Color("3b8beb"), Color("a55de0"), Color("f08a24")])
	confetti.color_initial_ramp = ramp
	add_child(confetti)
