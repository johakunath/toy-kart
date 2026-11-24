class_name ToyFriend extends Node3D
## One of his toys standing in the room, asking for help: a picture bubble above its head
## shows what it lost (no text). Bring the thing close and it jumps and spins for joy.
## At bedtime it leans over and sleeps.

enum State { WAITING, HAPPY, ASLEEP }

const TOY := "res://assets/models/toys/%s.glb"

var id := ""
var wants := ""          ## the LostThing id it asks for
var height := 10.0
var state := State.WAITING
## Someone is bringing the thing: the bubble bounces.
var excited := false

var _holder: Node3D
var _bubble: Node3D
var _time := 0.0
var _zzz: Label3D
var _radius := 2.0

func setup(p_id: String, model_id: String, p_height: float, p_wants: String) -> void:
	id = p_id
	wants = p_wants
	height = p_height
	name = "Friend_%s" % id
	_holder = Node3D.new()
	_holder.name = "Holder"
	add_child(_holder)
	var scene := load(TOY % model_id) as PackedScene
	if scene:
		var model := scene.instantiate() as Node3D
		model.name = "Model"
		model.scale = Vector3.ONE * (height / 0.7)  # the prepared toy models are 0.7 m tall
		_holder.add_child(model)
		ToyLook.apply(_holder, ToyLook.Kind.DRIVER)
		_radius = _footprint(model)
	# Karts bump into the friend, not through it.
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius()
	cylinder.height = height
	shape.shape = cylinder
	shape.position.y = height * 0.5
	body.add_child(shape)
	add_child(body)
	_build_bubble()

## How far the friend reaches out from its middle (metres): the model's footprint.
func radius() -> float:
	return _radius

## Half the width of the model seen from above (a little less: plush is soft).
func _footprint(model: Node3D) -> float:
	var reach := 0.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xform := mi.transform
		var p := mi.get_parent()
		while p != null and p != _holder:
			xform = (p as Node3D).transform * xform
			p = p.get_parent()
		var box := xform * mi.mesh.get_aabb()
		for corner in 8:
			var c := box.get_endpoint(corner)
			reach = maxf(reach, Vector2(c.x, c.z).length())
	return clampf(reach * 0.8, 2.0, height * 0.5)

## Where a given thing goes: in front of the friend, at chest height.
func hand_spot() -> Vector3:
	return global_position + global_basis.z * (radius() + 0.6) + Vector3(0, height * 0.35, 0)

func _build_bubble() -> void:
	_bubble = Node3D.new()
	_bubble.name = "Bubble"
	_bubble.position.y = height + 3.6
	add_child(_bubble)
	var back := MeshInstance3D.new()
	var disc := QuadMesh.new()
	disc.size = Vector2(5.6, 5.6)
	back.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = load("res://assets/icons/bubble.svg") as Texture2D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	back.material_override = mat
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.add_child(back)
	var picture := Sprite3D.new()
	picture.texture = load(LostThing.icon_path(wants)) as Texture2D
	picture.pixel_size = 3.4 / 128.0
	picture.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	picture.shaded = false
	picture.render_priority = 1
	picture.position.y = 0.35
	picture.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_bubble.add_child(picture)

func _process(delta: float) -> void:
	_time += delta
	if state == State.WAITING:
		var bounce := 0.6 if excited else 0.25
		_bubble.position.y = height + 3.6 + absf(sin(_time * (5.0 if excited else 2.0))) * bounce
		var s := 1.0 + (0.12 * sin(_time * 8.0) if excited else 0.0)
		_bubble.scale = Vector3.ONE * s
		_holder.rotation.z = sin(_time * 1.3) * 0.04
	elif state == State.ASLEEP and _zzz:
		_zzz.position.y = height + 1.0 + fposmod(_time * 0.8, 3.0)
		_zzz.modulate.a = 1.0 - fposmod(_time * 0.8, 3.0) / 3.0

## The thing arrived: the bubble pops, three jumps and a spin.
func be_happy() -> void:
	state = State.HAPPY
	var pop := create_tween()
	pop.tween_property(_bubble, "scale", Vector3.ONE * 1.4, 0.12)
	pop.tween_property(_bubble, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var hop := create_tween()
	for k in 3:
		hop.tween_property(_holder, "position:y", height * 0.25, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		hop.tween_property(_holder, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	hop.parallel().tween_property(_holder, "rotation:y", TAU, 1.3)
	hop.tween_callback(func() -> void: _holder.rotation.y = 0.0)

## Bedtime: lean over a little, close down, "z z z" floats up.
func fall_asleep() -> void:
	state = State.ASLEEP
	_bubble.visible = false
	var tween := create_tween()
	tween.tween_property(_holder, "rotation:z", 0.22, 1.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_holder, "scale", Vector3(1.04, 0.94, 1.04), 1.5)
	_zzz = Label3D.new()
	_zzz.text = "z z Z"
	_zzz.font_size = 160
	_zzz.outline_size = 30
	_zzz.modulate = Color(0.75, 0.85, 1.0)
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.no_depth_test = true
	_zzz.pixel_size = 0.012
	_zzz.position = Vector3(1.5, height + 1.0, 0)
	add_child(_zzz)
