class_name KartVisual extends Node3D
## Puts a kart model and a driver together. Used by the kart in a race and by menu previews.
## Kart models follow the Kenney naming: "body", "wheel-front-left", ... (or "wheel-front" for bikes).

var kart_def: KartDef
var driver_def: DriverDef

var model: Node3D
var body: Node3D
var body_rest := Vector3.ZERO
var wheels: Array[Node3D] = []
var front_wheels: Array[Node3D] = []
var fork: Node3D          ## bikes only
var lean_node: Node3D     ## bikes only: the whole bike leans
var driver: DriverRig
var wheel_spin_sign := 1.0  ## -1 for models that are turned round to face forward
## Flip-up roof (the Krankenwagen): a "roof" node in the model, closed at rest, hinged about its
## own X axis. Purely visual. Open in menus; in a race closed at the start, springs open on "go".
var roof: Node3D
var _roof_rest := Vector3.ZERO
var _roof_angle := 0.0       ## radians open
var _roof_speed := 0.0
var _roof_pop := 0.0         ## seconds left of a honk "pop shut"
var _roof_sound: AudioStreamPlayer3D
const ROOF_SPRING := 160.0   ## stiff with little damping: a springy flip in about 0.6 s
const ROOF_DAMPING := 11.0

func build(p_kart: KartDef, p_driver: DriverDef) -> void:
	kart_def = p_kart
	driver_def = p_driver
	for child in get_children():
		remove_child(child)
		child.queue_free()
	wheels.clear()
	front_wheels.clear()
	body = null
	roof = null
	_roof_sound = null
	fork = null
	lean_node = null
	driver = null
	if driver_def and driver_def.is_vehicle:
		_build_toy_vehicle()
		return
	if kart_def == null or kart_def.model_scene == null:
		return
	model = kart_def.model_scene.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	model.scale = Vector3.ONE * kart_def.model_scale
	model.rotation.y = deg_to_rad(kart_def.model_yaw_degrees)
	wheel_spin_sign = -1.0 if absf(kart_def.model_yaw_degrees) > 90.0 else 1.0
	for node_name in kart_def.hide_nodes:
		var hidden := model.find_child(node_name, true, false) as Node3D
		if hidden:
			hidden.visible = false
	fork = model.find_child("fork", true, false) as Node3D
	lean_node = model.find_child("motorcycle", true, false) as Node3D
	for node in model.find_children("wheel-*", "Node3D", true, false):
		wheels.append(node)
		var wheel_name := String(node.name)
		if wheel_name.contains("front") or wheel_name.ends_with("-fl") or wheel_name.ends_with("-fr"):
			front_wheels.append(node)
	body = model.find_child("body", true, false) as Node3D
	roof = model.find_child("roof", true, false) as Node3D
	if roof:
		_roof_rest = roof.rotation
		set_roof_open(1.0)
		_roof_sound = AudioStreamPlayer3D.new()
		_roof_sound.stream = load("res://assets/sfx/pop.wav")
		_roof_sound.bus = &"Effects"
		_roof_sound.volume_db = -6.0
		add_child(_roof_sound)
	if body == null and not wheels.is_empty():
		# Some packs hang the wheels on the body mesh. Use that mesh as the body and move the
		# wheels next to it, so the body can lean and bounce without taking the wheels along.
		var wheel_parent := wheels[0].get_parent() as Node3D
		if wheel_parent != model and wheel_parent is MeshInstance3D:
			body = wheel_parent
			for wheel in wheels:
				var local := body.transform * wheel.transform
				wheel.get_parent().remove_child(wheel)
				body.get_parent().add_child(wheel)
				wheel.transform = local
	var seat_parent: Node3D = body if body else model
	body_rest = body.position if body else Vector3.ZERO
	driver = DriverRig.new()
	driver.name = "Driver"
	seat_parent.add_child(driver)
	# The seat is given in kart space (metres, +Z forward); convert it into the seat parent's space.
	var seat_in_model := model.transform.affine_inverse() * kart_def.seat_position
	driver.position = seat_in_model - (body_rest if body else Vector3.ZERO)
	driver.rotation.y = -model.rotation.y
	driver.scale = Vector3.ONE / kart_def.model_scale
	driver.build(driver_def, kart_def.seat_scale)
	ToyLook.apply(model, ToyLook.Kind.KART)
	ToyLook.apply(driver, ToyLook.Kind.DRIVER)

## A toy vehicle stands in for the whole kart: no kart model, the toy sits on the ground.
func _build_toy_vehicle() -> void:
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	driver = DriverRig.new()
	driver.name = "Driver"
	model.add_child(driver)
	# The model's lowest point (its wheels) touches the road: the visual's origin is the road.
	driver.position = Vector3(0, driver_def.vehicle_hover, 0)
	driver.build(driver_def, 1.0)
	ToyLook.apply(driver, ToyLook.Kind.KART)
	# The toy itself pitches, leans and slides like a kart body.
	body = model
	body_rest = Vector3.ZERO

const STICKER_PATH := "res://assets/stickers/%s.svg"

## Puts the family's stickers on the kart: on both sides, the back and the bonnet, newest last.
## Only kart models get stickers (a toy vehicle is the toy itself).
func add_stickers(ids: Array[String]) -> void:
	if model == null or ids.is_empty() or (driver_def and driver_def.is_vehicle):
		return
	var box := _model_box()
	if box.size.length() < 0.01:
		return
	var holder: Node3D = body if body else model
	var to_holder := _chain(holder).affine_inverse()
	var mid_y := box.position.y + box.size.y * 0.45
	var x0 := box.position.x - 0.012
	var x1 := box.end.x + 0.012
	var zf := box.position.z + box.size.z * 0.72
	var zb := box.position.z + box.size.z * 0.3
	# Slot: [position, facing]. Karts face +Z.
	var slots: Array[Array] = [
		[Vector3(x1, mid_y, zb), Vector3.RIGHT], [Vector3(x0, mid_y, zb), Vector3.LEFT],
		[Vector3(0, mid_y, box.position.z - 0.012), Vector3.FORWARD],
		[Vector3(x1, mid_y, zf), Vector3.RIGHT], [Vector3(x0, mid_y, zf), Vector3.LEFT],
		[Vector3(0, box.end.y * 0.92, box.end.z - box.size.z * 0.12), Vector3.UP],
	]
	var size := clampf(box.size.y * 0.6, 0.22, 0.38)
	var shown := ids.slice(maxi(0, ids.size() - slots.size()))
	for i in shown.size():
		var slot: Array = slots[i]
		var sticker := Sprite3D.new()
		sticker.name = "Sticker_%s" % shown[i]
		sticker.texture = load(STICKER_PATH % shown[i]) as Texture2D
		if sticker.texture == null:
			continue
		# The back one is what the chase camera sees all race: a bit bigger.
		var scale_here := 1.5 if i == 2 else 1.0
		sticker.pixel_size = size * scale_here / float(sticker.texture.get_width())
		sticker.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sticker.shaded = true
		sticker.double_sided = false
		var facing: Vector3 = slot[1]
		var up := Vector3.FORWARD if facing == Vector3.UP else Vector3.UP
		var basis := Basis.looking_at(-facing, up)
		var local := Transform3D(basis, slot[0])
		holder.add_child(sticker)
		sticker.transform = to_holder * local

## The model's outline in this node's space (without the driver and the wheels).
func _model_box() -> AABB:
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible or String(mesh.name).begins_with("wheel") or String(mesh.name).begins_with("roof") or (driver and driver.is_ancestor_of(mesh)):
			continue
		var b := _chain(mesh) * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## Transform of a descendant relative to this node, without needing the scene tree.
func _chain(node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

# --- Flip-up roof ----------------------------------------------------------------------------

## Puts the roof at once at a share of its standing-still opening (0 = shut, 1 = open).
func set_roof_open(share: float) -> void:
	if roof == null:
		return
	_roof_angle = deg_to_rad(kart_def.roof_open_degrees) * share
	_roof_speed = 0.0
	roof.rotation = _roof_rest - Vector3(_roof_angle, 0, 0)  # minus: the front end lifts

## Each frame in a race: shut while waiting at the start, springs open on "go" (a pop sound),
## leans further back with speed so the driver stays in view, pops shut for a moment on a honk.
func animate_roof(delta: float, racing: bool, speed_share: float) -> void:
	if roof == null:
		return
	_roof_pop = maxf(0.0, _roof_pop - delta)
	var target := 0.0
	if racing and _roof_pop <= 0.0:
		target = deg_to_rad(lerpf(kart_def.roof_open_degrees, kart_def.roof_open_fast_degrees, clampf(speed_share, 0.0, 1.0)))
	if target > 0.5 and _roof_angle < 0.15 and _roof_speed <= 0.0 and _roof_sound and _roof_sound.is_inside_tree():
		_roof_sound.play()
	_roof_speed += ((target - _roof_angle) * ROOF_SPRING - _roof_speed * ROOF_DAMPING) * delta
	_roof_angle = clampf(_roof_angle + _roof_speed * delta, -0.05, deg_to_rad(170.0))
	roof.rotation = _roof_rest - Vector3(_roof_angle, 0, 0)  # minus: the front end lifts

## Honk: the roof snaps shut and flips open again.
func pop_roof() -> void:
	if roof:
		_roof_pop = 0.22
