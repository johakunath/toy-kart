class_name DriverRig extends Node3D
## The driver sitting in a kart: either a 3D character or a "paper" toy (front and back photo on
## a flat card). Drivers are not rigged for driving; the game animates them in code:
## they lean into curves, rock back when accelerating, wobble, and hop when honking.

var def: DriverDef
var _pivot: Node3D
var _lean := 0.0
var _lean_vel := 0.0
var _pitch := 0.0
var _pitch_vel := 0.0
var _hop := 0.0
var _hop_vel := 0.0
var _time := 0.0
var _stiffness := 70.0
var _damping := 7.0
var _lean_amount := 0.25
var _cheering := false

func build(p_def: DriverDef, seat_scale: float) -> void:
	def = p_def
	for child in get_children():
		child.queue_free()
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	if def == null:
		return
	if def.type == DriverDef.Type.PAPER:
		_build_paper(seat_scale)
	else:
		_build_model(seat_scale)

func _build_model(seat_scale: float) -> void:
	_stiffness = 90.0
	_damping = 10.0
	_lean_amount = 0.22
	if def.model_scene == null:
		return
	var model := def.model_scene.instantiate() as Node3D
	model.scale = Vector3.ONE * def.model_scale * seat_scale
	_pivot.add_child(model)
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player and player.has_animation(def.animation):
		player.get_animation(def.animation).loop_mode = Animation.LOOP_LINEAR
		player.play(def.animation)

func _build_paper(seat_scale: float) -> void:
	# A cardboard figure wobbles more than a seated character.
	_stiffness = 55.0
	_damping = 4.5
	_lean_amount = 0.38
	var height := def.card_height * seat_scale
	if def.is_vehicle:
		# The toy is the vehicle: sized by its width, and it leans like a car, not a figure.
		_stiffness = 80.0
		_damping = 8.0
		_lean_amount = 0.16
		if def.front_texture:
			var aspect := float(def.front_texture.get_width()) / maxf(1.0, float(def.front_texture.get_height()))
			height = def.vehicle_width / maxf(aspect, 0.01)
	if def.front_texture:
		_pivot.add_child(_make_card(def.front_texture, height, false))
	var back_tex := def.back_texture if def.back_texture else def.front_texture
	if back_tex:
		_pivot.add_child(_make_card(back_tex, height, true))

func _make_card(tex: Texture2D, height: float, is_back: bool) -> MeshInstance3D:
	var quad := QuadMesh.new()
	var aspect := float(tex.get_width()) / maxf(1.0, float(tex.get_height()))
	quad.size = Vector2(height * aspect, height)
	quad.center_offset = Vector3(0, height * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	# Unshaded: the toy photo stays recognisable from every side, like a sticker.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.96, 0.96, 0.96)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.name = "Back" if is_back else "Front"
	# A quad faces +Z, the kart's forward. The back photo faces the chase camera behind the kart.
	if is_back:
		mi.rotation.y = PI
	return mi

## Called every physics tick by the kart. steer -1..1, speed 0..1+, surge > 0 while speeding up.
func animate(delta: float, steer: float, speed: float, surge: float) -> void:
	if _pivot == null:
		return
	_time += delta
	var target_lean := steer * clampf(speed, 0.0, 1.2) * _lean_amount
	var target_pitch := clampf(-surge * 0.35, -0.3, 0.3)
	_lean_vel += (_stiffness * (target_lean - _lean) - _damping * _lean_vel) * delta
	_lean += _lean_vel * delta
	_pitch_vel += (_stiffness * (target_pitch - _pitch) - _damping * _pitch_vel) * delta
	_pitch += _pitch_vel * delta
	_hop_vel += (-220.0 * _hop - 14.0 * _hop_vel) * delta
	_hop += _hop_vel * delta
	if _cheering:
		_hop = absf(sin(_time * 7.0)) * 0.18
	var rumble := sin(_time * 23.0) * 0.012 * clampf(speed, 0.0, 1.0)
	_pivot.rotation = Vector3(_pitch, 0.0, _lean + rumble)
	_pivot.position.y = maxf(_hop, 0.0)
	var squash := 1.0 + clampf(_hop * 1.5, -0.2, 0.3)
	_pivot.scale = Vector3(1.0 / sqrt(squash), squash, 1.0 / sqrt(squash))

## A little hop, used for the horn and for pickups.
func hop(strength := 1.0) -> void:
	_hop_vel += 2.6 * strength

## Knock the wobble, used when the kart bumps into something.
func knock(strength: float) -> void:
	_lean_vel += strength * (1.0 if randf() > 0.5 else -1.0)

func set_cheering(on: bool) -> void:
	_cheering = on
