class_name XRay extends RefCounted
## X-ray silhouette: where a player's own kart is hidden from his camera (tunnel wall, sofa,
## caterpillar, tree), it shows through as a bright shape in his colour, so he never loses it.
##
## How: the kart's own meshes write a per-player stencil value where they are really seen.
## Each mesh gets a "ghost" child: the same mesh with an unshaded, see-through material that
## ignores depth and only draws where that stencil value is NOT set, i.e. exactly on the hidden
## parts (its own wheel behind its body stays plain). The ghost writes that value too, so its
## overlapping parts draw only once: one even shape instead of stacked layers. The ghosts sit on a render layer per player;
## each split-screen camera hides the other players' layers, so every half shows only its own kart.
## Works for 3D models (skinned too: the ghost uses the same skeleton) and paper cards (the ghost
## cuts the card's picture out by its alpha, so no rectangle shows).

const FIRST_LAYER_BIT := 12        ## player 0 -> render layer 13, player 1 -> layer 14
const MAX_PLAYERS := 4
const STENCIL_BASE := 64           ## stencil value of player 0's kart; player n uses 64 + n
const ALPHA := 0.85

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
stencil_mode read, write, compare_not_equal, %d;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D mask : source_color, hint_default_white, filter_linear_mipmap;
uniform bool use_mask = false;
void fragment() {
	if (use_mask && texture(mask, UV).a < 0.5) {
		discard;
	}
	// A lighter edge makes the shape read as a body, not a flat blob.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(tint.rgb, vec3(1.0), 0.08 + rim * 0.5);
	ALPHA = tint.a;
}
"""

static var _shaders := {}          ## player index -> Shader
static var _write_cache := {}      ## "material id:stencil value" -> stencil-writing copy
static var _ghost_cache := {}      ## "player:mask texture id" -> ghost material

## Render-layer bit of a player's silhouette.
static func layer(player_index: int) -> int:
	return 1 << (FIRST_LAYER_BIT + player_index)

## Every player's silhouette layer except this one's: take these out of his camera's cull mask.
static func others_mask(player_index: int) -> int:
	var mask := 0
	for i in MAX_PLAYERS:
		if i != player_index:
			mask |= layer(i)
	return mask

## Gives the kart visual (kart model and driver) its silhouette in the player's colour.
static func apply(root: Node3D, player_index: int, color: Color) -> void:
	if player_index < 0 or player_index >= MAX_PLAYERS:
		return
	var reference := STENCIL_BASE + player_index
	var tint := Color(color.r, color.g, color.b, ALPHA)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		# The contact shadow under toy vehicles (material_override) is not part of the toy.
		if mi.mesh == null or mi.material_override != null or mi.has_meta("xray"):
			continue
		mi.set_meta("xray", true)
		var ghost := MeshInstance3D.new()
		ghost.name = "XRayGhost"
		ghost.set_meta("xray", true)
		ghost.mesh = mi.mesh
		ghost.layers = layer(player_index)
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if mi.skin:
			ghost.skin = mi.skin
			ghost.skeleton = NodePath("../" + String(mi.skeleton)) if not mi.skeleton.is_absolute() else mi.skeleton
		for i in mi.mesh.get_surface_count():
			var original := mi.get_active_material(i) as BaseMaterial3D
			if original == null:
				continue
			mi.set_surface_override_material(i, _writer(original, reference))
			ghost.set_surface_override_material(i, _ghost_material(original, player_index, tint))
		mi.add_child(ghost)

## A copy of the kart's material that marks the pixels where it is really seen.
static func _writer(original: BaseMaterial3D, reference: int) -> BaseMaterial3D:
	var key := "%d:%d" % [original.get_instance_id(), reference]
	if _write_cache.has(key):
		return _write_cache[key]
	var mat := original.duplicate() as BaseMaterial3D
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	mat.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	mat.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	mat.stencil_reference = reference
	_write_cache[key] = mat
	return mat

static func _ghost_material(original: BaseMaterial3D, player_index: int, tint: Color) -> ShaderMaterial:
	var cut_out := original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and original.albedo_texture != null
	var key := "%d:%d:%s" % [player_index, original.albedo_texture.get_instance_id() if cut_out else 0, tint.to_html()]
	if _ghost_cache.has(key):
		return _ghost_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = _shader(player_index)
	mat.set_shader_parameter("tint", tint)
	# Cut-out cards (paper drivers, photo toys): follow the picture's outline.
	if cut_out:
		mat.set_shader_parameter("mask", original.albedo_texture)
		mat.set_shader_parameter("use_mask", true)
	_ghost_cache[key] = mat
	return mat

static func _shader(player_index: int) -> Shader:
	if not _shaders.has(player_index):
		var shader := Shader.new()
		shader.code = SHADER % (STENCIL_BASE + player_index)
		_shaders[player_index] = shader
	return _shaders[player_index]
