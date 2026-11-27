class_name GoodNight extends Control
## The end of the explore mode: the screen goes night blue, a moon and "Gute Nacht".
## Any button after a moment, or a quiet wait, goes back to the menu. No "play again".

const HOLD := 6.0        ## seconds before a button press counts (he is still tapping gas)
const AUTO_MENU := 20.0  ## seconds until it goes back to the menu by itself

var _time := -1.0
var _moon: TextureRect

func _init() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()  # the same round, bold letters as everywhere else
	modulate.a = 0.0
	var night := ColorRect.new()
	night.color = Color(0.06, 0.08, 0.24, 0.9)
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(night)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 40:
		var star := ColorRect.new()
		var s := rng.randf_range(4.0, 9.0)
		star.size = Vector2(s, s)
		star.color = Color(1.0, 0.95, 0.7, rng.randf_range(0.5, 1.0))
		star.position = Vector2(rng.randf_range(0.0, 1920.0), rng.randf_range(0.0, 1080.0))
		star.rotation = PI * 0.25
		add_child(star)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 30)
	center.add_child(column)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(300, 300)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(holder)
	_moon = UiKit.icon_rect("good_night", 300, Color.WHITE)
	_moon.pivot_offset = Vector2(150, 150)
	holder.add_child(_moon)
	var label := UiKit.label("Gute Nacht", 140, Color.WHITE, 26, Color(0.06, 0.08, 0.24))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)

func open() -> void:
	visible = true
	_time = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 2.0)

func is_open() -> bool:
	return _time >= 0.0

func _process(delta: float) -> void:
	if _time < 0.0:
		return
	_time += delta
	_moon.rotation = sin(_time * 0.8) * 0.12
	if _time >= AUTO_MENU and not Game.smoke:
		_time = -100.0
		Game.go_to_menu()

func _input(event: InputEvent) -> void:
	if _time < HOLD or Game.smoke:
		return
	# Any pad button, or a "yes" / "back" key. Other keys (F11 ...) do not end the screen.
	var press := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
	var button := event as InputEventJoypadButton
	if button and button.pressed:
		press = true
	if press:
		_time = -100.0
		get_viewport().set_input_as_handled()
		Game.go_to_menu()
