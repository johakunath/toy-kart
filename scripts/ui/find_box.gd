class_name FindBox extends Control
## The "Fundkiste": one wooden box for the whole family, across the top of the screen, with
## 8 dark silhouettes of the lost things. A found thing pops in with its colours.

const SLOT := 96
const ICON := 80

const _SILHOUETTE := "shader_type canvas_item;
uniform bool lit = false;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = lit ? c : vec4(0.27, 0.15, 0.07, c.a * 0.85);
}"

var _icons: Array[TextureRect] = []
var _slots: Array[Panel] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var panel := PanelContainer.new()
	var wood := UiKit.box(Color("9a5a2c"), 26, Color("6e3c18"), 6)
	wood.content_margin_left = 16
	wood.content_margin_right = 16
	wood.content_margin_top = 12
	wood.content_margin_bottom = 12
	wood.shadow_color = Color(0, 0, 0, 0.3)
	wood.shadow_size = 10
	panel.add_theme_stylebox_override("panel", wood)
	panel.add_child(row)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 14
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var shader := Shader.new()
	shader.code = _SILHOUETTE
	for thing_id in LostThing.IDS:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(SLOT, SLOT)
		slot.add_theme_stylebox_override("panel", UiKit.box(Color("fff3dc"), 18))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = load(LostThing.icon_path(thing_id)) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(ICON, ICON)
		icon.position = Vector2((SLOT - ICON) * 0.5, (SLOT - ICON) * 0.5)
		icon.pivot_offset = Vector2(ICON, ICON) * 0.5
		var mat := ShaderMaterial.new()
		mat.shader = shader
		icon.material = mat
		slot.add_child(icon)
		row.add_child(slot)
		_icons.append(icon)
		_slots.append(slot)

## A thing is found: its picture lights up with a bounce.
func fill(thing_id: String) -> void:
	var i := LostThing.IDS.find(thing_id)
	if i < 0:
		return
	(_icons[i].material as ShaderMaterial).set_shader_parameter("lit", true)
	_slots[i].add_theme_stylebox_override("panel", UiKit.box(Color("fff8c8"), 18, Color("ffd23f"), 5))
	var tween := create_tween()
	_icons[i].scale = Vector2.ONE * 0.3
	tween.tween_property(_icons[i], "scale", Vector2.ONE * 1.35, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_icons[i], "scale", Vector2.ONE, 0.25)

## A friend's thing is on its way: its slot wobbles in the carrier's colour.
func carrying(thing_id: String, color: Color) -> void:
	var i := LostThing.IDS.find(thing_id)
	if i < 0:
		return
	_slots[i].add_theme_stylebox_override("panel", UiKit.box(Color("fff3dc"), 18, color, 6))
	var tween := create_tween().set_loops(3)
	tween.tween_property(_icons[i], "rotation", 0.25, 0.12)
	tween.tween_property(_icons[i], "rotation", -0.25, 0.12)
	tween.tween_property(_icons[i], "rotation", 0.0, 0.12)

func is_lit(thing_id: String) -> bool:
	var i := LostThing.IDS.find(thing_id)
	return i >= 0 and bool((_icons[i].material as ShaderMaterial).get_shader_parameter("lit"))
