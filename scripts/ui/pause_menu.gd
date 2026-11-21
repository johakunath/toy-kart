class_name PauseMenu extends Control
## Pause overlay: three big buttons. Opens with Esc or the Start button of any gamepad.

var _first: Button
var _opened_frame := -1

func _init() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()

	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 36)
	center.add_child(column)
	column.add_child(UiKit.label("Pause", 120, Color.WHITE, 24, UiKit.INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	column.add_child(row)

	_first = UiKit.card_button("play", "Weiter", Vector2(320, 320))
	_first.pressed.connect(close)
	row.add_child(_first)
	var again := UiKit.card_button("restart", "Neustart", Vector2(320, 320))
	again.pressed.connect(func() -> void: Game.start_race())
	row.add_child(again)
	var home := UiKit.card_button("home", "Menü", Vector2(320, 320))
	home.pressed.connect(func() -> void: Game.go_to_menu())
	row.add_child(home)

func open() -> void:
	visible = true
	get_tree().paused = true
	_opened_frame = Engine.get_process_frames()
	_first.grab_focus()
	UiKit.play(self, "select")

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() == _opened_frame:
		return
	var close_pressed := event.is_action_pressed("ui_cancel")
	var button := event as InputEventJoypadButton
	if button and button.pressed and button.button_index == JOY_BUTTON_START:
		close_pressed = true
	if close_pressed:
		get_viewport().set_input_as_handled()
		close()
