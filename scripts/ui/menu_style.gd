class_name MenuStyle extends RefCounted
## The console look of the menu pages: bold coloured cards with depth (soft shadow, glossy top,
## darker lip at the bottom), a cartoon title with a double outline, and focus that pops
## (the card grows with a little bounce and glows yellow).

## One strong colour per mode card: Freie Fahrt, Rennen, Team, Pokal, Zeitfahren.
const MODE_COLORS: Array[Color] = [
	Color("2fb54f"), Color("e83a3a"), Color("2f7fee"), Color("f39c12"), Color("8e44ef"),
]
## The "Entdecken" card (second on the mode page).
const EXPLORE_COLOR := Color("14a89b")
const SHADOW := Color(0.04, 0.07, 0.2, 0.4)
const GLOW := Color(1.0, 0.85, 0.2, 0.75)
const FOCUS_SCALE := 1.08

static var _theme: Theme

## A rounded box with a soft drop shadow.
static func card(bg: Color, radius := 34, border := Color.TRANSPARENT, border_width := 0, shadow := 14) -> StyleBoxFlat:
	var style := UiKit.box(bg, radius, border, border_width)
	style.shadow_color = SHADOW
	style.shadow_size = shadow
	style.shadow_offset = Vector2(0, shadow * 0.6)
	return style

## Drawn over a focused button: a thick yellow ring and a warm glow around it.
static func focus_ring(radius := 34) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_corner_radius_all(radius)
	style.set_border_width_all(10)
	style.border_color = UiKit.SUN
	style.shadow_color = GLOW
	style.shadow_size = 26
	style.anti_aliasing = true
	style.set_expand_margin_all(4)
	return style

## The menu theme: UiKit's theme with shadows under the buttons and the glowing focus ring.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := UiKit.theme().duplicate() as Theme
	t.set_stylebox("normal", "Button", card(UiKit.PAPER, 28, Color(UiKit.INK, 0.18), 4, 10))
	t.set_stylebox("hover", "Button", card(Color.WHITE, 28, Color(UiKit.SUN, 0.8), 5, 12))
	t.set_stylebox("pressed", "Button", card(UiKit.SUN, 28, Color(UiKit.INK, 0.8), 5, 8))
	t.set_stylebox("hover_pressed", "Button", card(UiKit.SUN, 28, Color(UiKit.INK, 0.8), 5, 12))
	t.set_stylebox("focus", "Button", focus_ring(28))
	_theme = t
	return t

## A glossy highlight over the top of a card (a pale band with round corners).
static func gloss(radius := 26, height := 0.42, inset := 10.0) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.2)
	style.set_corner_radius_all(radius)
	style.corner_radius_bottom_left = int(radius * 2.5)
	style.corner_radius_bottom_right = int(radius * 2.5)
	style.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_right = 1.0
	panel.anchor_bottom = height
	panel.offset_left = inset
	panel.offset_top = inset
	panel.offset_right = -inset
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

## A darker band along the bottom of a card: the card reads like a thick toy block.
static func lip(color: Color, radius := 34, height := 26.0) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.25)
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -height
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

## A big mode card: strong colour, white icon, white word, gloss and lip. Its focus pops.
## Put it in a container through holder(), so the focus pop is not undone by the container.
static func mode_card(icon_name: String, text: String, color: Color, card_size: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = card_size
	var radius := 40
	button.add_theme_stylebox_override("normal", card(color, radius, color.darkened(0.35), 6, 16))
	button.add_theme_stylebox_override("hover", card(color.lightened(0.08), radius, Color.WHITE, 6, 18))
	button.add_theme_stylebox_override("pressed", card(color.darkened(0.12), radius, Color.WHITE, 6, 8))
	button.add_theme_stylebox_override("hover_pressed", card(color.darkened(0.12), radius, Color.WHITE, 6, 8))
	button.add_theme_stylebox_override("focus", focus_ring(radius))
	button.add_child(lip(color, radius))
	button.add_child(gloss(radius - 10))
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 26
	column.offset_bottom = -40
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := UiKit.icon_rect(icon_name, 190, Color.WHITE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var label := UiKit.label(text, 46, Color.WHITE, 14, color.darkened(0.55))
	column.add_child(label)
	button.add_child(column)
	return button

## Puts `c` in a plain holder of the same size, so it can grow and tilt without its container
## snapping it back (containers reset the scale of their direct children).
static func holder(c: Control) -> Control:
	var box := Control.new()
	box.custom_minimum_size = c.custom_minimum_size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(c)
	return box

## The control grows with a small bounce while focused (or hovered) and settles back after.
static func pop_on_focus(c: Control, grow := FOCUS_SCALE) -> void:
	var update := func() -> void:
		c.pivot_offset = c.size * 0.5
		var on := c.has_focus() or c.get_global_rect().has_point(c.get_global_mouse_position())
		c.z_index = 1 if on else 0
		var tween := c.create_tween()
		tween.tween_property(c, "scale", Vector2.ONE * (grow if on else 1.0), 0.28 if on else 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.focus_entered.connect(update)
	c.focus_exited.connect(update)
	c.mouse_entered.connect(update)
	c.mouse_exited.connect(update)
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)

## A cartoon title: coloured letters, a dark outline, a wide white outline behind it and a soft
## shadow. The holder keeps the size; the two labels sit on top of each other.
static func title(text: String, size: int, fill := Color.WHITE) -> Control:
	var back := UiKit.label(text, size, Color.WHITE, int(size * 0.34), Color.WHITE)
	back.add_theme_color_override("font_shadow_color", Color(UiKit.INK, 0.45))
	back.add_theme_constant_override("shadow_offset_x", 0)
	back.add_theme_constant_override("shadow_offset_y", int(size * 0.08))
	back.add_theme_constant_override("shadow_outline_size", int(size * 0.34))
	var front := UiKit.label(text, size, fill, int(size * 0.17), UiKit.INK)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Measured from the font: labels outside the tree do not know their size yet.
	var width := UiKit.bold_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	box.custom_minimum_size = Vector2(width + size * 0.6, size * 1.5)
	for l: Label in [back, front]:
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.add_child(l)
	return box

## The game logo when its picture exists (assets/ui/logo.png), else the cartoon text title.
static func logo(height: float) -> Control:
	var path := "res://assets/ui/logo.png"
	if ResourceLoader.exists(path):
		var picture := TextureRect.new()
		picture.texture = load(path) as Texture2D
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var aspect := 2.6
		if picture.texture != null and picture.texture.get_height() > 0:
			aspect = float(picture.texture.get_width()) / picture.texture.get_height()
		picture.custom_minimum_size = Vector2(height * aspect, height)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return picture
	return title("Toy Racer", int(height * 0.78), UiKit.SUN)

## A slow, gentle bob and tilt, for the title.
static func bob(c: Control, degrees := 2.5) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	c.rotation_degrees = -degrees
	var tween := c.create_tween().set_loops()
	tween.tween_property(c, "rotation_degrees", degrees, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(c, "scale", Vector2.ONE * 1.04, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(c, "rotation_degrees", -degrees, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(c, "scale", Vector2.ONE, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## A page arrives: fades in and grows from slightly smaller, with a soft overshoot.
static func page_in(page: Control) -> void:
	page.pivot_offset = page.size * 0.5
	page.modulate.a = 0.0
	page.scale = Vector2.ONE * 0.94
	var tween := page.create_tween().set_parallel()
	tween.tween_property(page, "modulate:a", 1.0, 0.22)
	tween.tween_property(page, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A small bounce, e.g. when a player joins or gets ready.
static func bounce(c: Control, from := 0.92) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * from
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A soft drop shadow under a label's letters (titles over the moving background).
static func shadowed(l: Label) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(UiKit.INK, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(3, int(l.get_theme_font_size("font_size") * 0.07)))
	l.add_theme_constant_override("shadow_outline_size", l.get_theme_constant("outline_size") + 4)
	return l

## A raised bar: a darker lip along the bottom edge, and a glow around it when it matters
## (the chosen row, the ready banner).
static func bevel(color: Color, radius := 22, glow := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := UiKit.box(color, radius)
	style.border_width_bottom = 6 if color.a > 0.5 else 0
	style.border_color = color.darkened(0.25)
	style.border_blend = false
	if glow.a > 0.0:
		style.shadow_color = glow
		style.shadow_size = 16
	elif color.a > 0.5:
		style.shadow_color = Color(SHADOW, 0.25)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 3)
	return style

## The one button that moves on ("Weiter"): green with white letters, like a console's main button.
static func primary(b: Button) -> void:
	var green := UiKit.GRASS
	b.add_theme_stylebox_override("normal", card(green, 28, green.darkened(0.35), 5, 12))
	b.add_theme_stylebox_override("hover", card(green.lightened(0.1), 28, Color.WHITE, 5, 14))
	b.add_theme_stylebox_override("pressed", card(green.darkened(0.15), 28, Color.WHITE, 5, 8))
	b.add_theme_stylebox_override("hover_pressed", card(green.darkened(0.15), 28, Color.WHITE, 5, 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	b.add_theme_constant_override("outline_size", 10)
	b.add_theme_color_override("font_outline_color", green.darkened(0.5))
