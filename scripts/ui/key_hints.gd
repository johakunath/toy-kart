class_name KeyHints extends RefCounted
## Pictures of the real keys and pad buttons, so nobody has to read a key name.
## Pictures come from tools/make_key_icons.py (assets/icons/key_*.svg, pad_*.svg).

## A key or button picture, `height` pixels tall, as wide as the picture needs.
static func key(icon_name: String, height: float) -> TextureRect:
	var r := UiKit.icon_rect(icon_name, height, Color.WHITE)
	var tex := r.texture
	if tex != null and tex.get_height() > 0:
		r.custom_minimum_size = Vector2(height * tex.get_width() / tex.get_height(), height)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r

## Short German words for the action icons, shown next to the pictures on the selection screen.
const ACTION_WORDS := {
	"chevron": "Gas", "brake": "Bremse", "wheel": "Lenken", "drift": "Drift",
	"star": "Item", "horn": "Hupe", "gift": "Geschenk",
}
## Most controls one device has in one mode (keyboard or pad, Profi): the grid keeps room for them.
const MAX_CONTROLS := 7

## A row of key pictures, then the icon of what they do: "[W] gas".
static func group(keys: Array[String], action_icon: String, height: float) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in keys:
		box.add_child(key(k, height))
	if action_icon != "":
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(4, 0)
		box.add_child(spacer)
		box.add_child(UiKit.icon_rect(action_icon, height * 0.9, UiKit.INK))
	return box

static func _layout(source: InputSource) -> int:
	if source is KeyboardSource:
		return (source as KeyboardSource).layout
	if source is PadSource:
		return 2
	return -1

## The keys that move left / right in menus (what changes a row in the player panel).
static func left_right(source: InputSource) -> Array[String]:
	match _layout(source):
		0: return ["key_a", "key_d"]
		1: return ["key_left", "key_right"]
	return []

static func accept_key(source: InputSource) -> String:
	return ["key_space", "key_enter", "pad_a"][_layout(source)] if _layout(source) >= 0 else ""

static func back_key(source: InputSource) -> String:
	return ["key_q", "key_backspace", "pad_b"][_layout(source)] if _layout(source) >= 0 else ""

## The "give my item to the kid" key (co-op).
static func gift_key(source: InputSource) -> String:
	return ["key_r", "key_m", "pad_dpad"][_layout(source)] if _layout(source) >= 0 else ""

## The small keys shown in a player's header: W A S D, the arrows, or the stick.
static func device_keys(source: InputSource) -> Array[String]:
	match _layout(source):
		0: return ["key_w", "key_a", "key_s", "key_d"]
		1: return ["key_left", "key_up", "key_down", "key_right"]
		2: return ["pad_stick"]
	return []

## How this device drives in this control mode: a list of [keys, action icon] pairs.
static func driving(source: InputSource, control_mode: int) -> Array:
	var kid := control_mode == Game.ControlMode.KID
	match _layout(source):
		0:
			if kid:
				return [[["key_a", "key_d"], "wheel"], [["key_w"], "chevron"], [["key_q"], "horn"]]
			return [[["key_w"], "chevron"], [["key_s"], "brake"], [["key_a", "key_d"], "wheel"],
				[["key_space"], "drift"], [["key_e"], "star"], [["key_q"], "horn"], [["key_r"], "gift"]]
		1:
			if kid:
				return [[["key_left", "key_right"], "wheel"], [["key_up"], "chevron"], [["key_comma"], "horn"]]
			return [[["key_up"], "chevron"], [["key_down"], "brake"], [["key_left", "key_right"], "wheel"],
				[["key_period"], "drift"], [["key_enter"], "star"], [["key_comma"], "horn"], [["key_m"], "gift"]]
		2:
			if kid:
				return [[["pad_stick"], "wheel"], [["pad_a"], "chevron"], [["pad_b", "pad_x", "pad_y"], "horn"]]
			return [[["pad_rt"], "chevron"], [["pad_lt"], "brake"], [["pad_stick"], "wheel"], [["pad_rb"], "drift"],
				[["pad_x"], "star"], [["pad_y"], "horn"], [["pad_dpad"], "gift"]]
	return []

## Fills `flow` with the driving pictures for this device and mode.
static func fill_driving(flow: Container, source: InputSource, control_mode: int, height: float) -> void:
	for child in flow.get_children():
		child.queue_free()
	for pair: Array in driving(source, control_mode):
		var keys: Array[String] = []
		keys.assign(pair[0])
		flow.add_child(group(keys, pair[1], height))

## Fills `grid` with the driving controls as a tidy table: key pictures (right-aligned), the
## action icon, a short word. Up to four controls stand in one column, more in two.
static func fill_driving_grid(grid: GridContainer, source: InputSource, control_mode: int, height: float, font_size: int) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var pairs := driving(source, control_mode)
	var two := pairs.size() > 4
	@warning_ignore("integer_division")
	var per_column := (pairs.size() + 1) / 2 if two else pairs.size()
	grid.columns = 7 if two else 3
	# Row-major grid, column-major reading: the first column is the first half of the list.
	for r in per_column:
		for c in (2 if two else 1):
			var i := r + c * per_column
			if c == 1:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(26, 0)
				grid.add_child(gap)
			if i < pairs.size():
				_add_control_cells(grid, pairs[i], height, font_size)
			else:
				for k in 3:
					grid.add_child(Control.new())

static func _add_control_cells(grid: GridContainer, pair: Array, height: float, font_size: int) -> void:
	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_END
	keys.add_theme_constant_override("separation", 3)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k: String in pair[0]:
		keys.add_child(key(k, height))
	grid.add_child(keys)
	var action: String = pair[1]
	var icon := UiKit.icon_rect(action, height * 0.8, UiKit.INK)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(icon)
	var word := UiKit.label(ACTION_WORDS.get(action, ""), font_size)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	grid.add_child(word)
