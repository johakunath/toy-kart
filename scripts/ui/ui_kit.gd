class_name UiKit extends RefCounted
## Small helpers so every screen looks the same: big, round, colourful, icons first.

const INK := Color("1d2b53")
const SKY := Color("8fd0ff")
const SKY_DEEP := Color("4aa3ea")
const PAPER := Color("fffdf5")
const SUN := Color("ffd23f")
const GRASS := Color("5fc46a")

static var _theme: Theme
static var _bold: Font

static func icon(icon_name: String) -> Texture2D:
	return load("res://assets/icons/%s.svg" % icon_name) as Texture2D

static func bold_font() -> Font:
	if _bold == null:
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.variation_embolden = 0.9
		_bold = variation
	return _bold

static func box(bg: Color, radius := 28, border := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border_width)
	style.border_color = border
	style.set_content_margin_all(14)
	style.anti_aliasing = true
	return style

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = bold_font()
	t.default_font_size = 38
	t.set_color("font_color", "Label", INK)
	# Buttons: white cards, yellow when focused.
	t.set_stylebox("normal", "Button", box(PAPER, 28, Color(INK, 0.25), 4))
	t.set_stylebox("hover", "Button", box(Color.WHITE, 28, SUN, 6))
	t.set_stylebox("pressed", "Button", box(SUN, 28, INK, 6))
	t.set_stylebox("focus", "Button", box(Color(SUN, 0.35), 28, SUN, 10))
	t.set_stylebox("disabled", "Button", box(Color(PAPER, 0.5), 28))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", INK)
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		t.set_color(state, "Button", INK)
	t.set_constant("h_separation", "Button", 14)
	t.set_constant("icon_max_width", "Button", 0)
	t.set_stylebox("panel", "PanelContainer", box(Color(PAPER, 0.95), 32))
	_theme = t
	return t

static func label(text: String, size: int, color := INK, outline := 0, outline_color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func icon_rect(icon_name: String, size: float, color := INK) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(icon_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## A square picture with round corners (a driver's face). Its child TextureRect shows the picture.
static func rounded_picture(size: float, radius := 24) -> Panel:
	var mask := Panel.new()
	mask.custom_minimum_size = Vector2(size, size)
	mask.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.add_theme_stylebox_override("panel", box(Color.WHITE, radius))
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(pic)
	return mask

## A big card button: icon on top, short label below.
static func card_button(icon_name: String, text: String, size: Vector2, icon_size := 150) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.text = text
	b.icon = icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", icon_size)
	b.add_theme_font_size_override("font_size", 44)
	return b

## A smaller button with icon and text side by side.
static func pill_button(icon_name: String, text: String, min_size := Vector2(260, 96)) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.text = text
	if icon_name != "":
		b.icon = icon(icon_name)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 56)
	return b

static func background(top := SKY, bottom := SKY_DEEP) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

static func format_time(seconds: float) -> String:
	var whole := int(seconds)
	@warning_ignore("integer_division")
	var minutes := whole / 60
	return "%d:%02d.%d" % [minutes, whole % 60, int((seconds - whole) * 10.0)]

## Anchors a control to a corner/edge preset and offsets it from there.
static func pin(c: Control, preset: Control.LayoutPreset, offset: Vector2, size := Vector2.ZERO) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y

## Plays a short UI sound without needing a node set up in advance.
static func play(parent: Node, sound: String, volume_db := 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load("res://assets/sfx/%s.wav" % sound)
	player.volume_db = volume_db
	player.bus = &"Effects"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
