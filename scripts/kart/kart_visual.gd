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

func build(p_kart: KartDef, p_driver: DriverDef) -> void:
	kart_def = p_kart
	driver_def = p_driver
	for child in get_children():
		remove_child(child)
		child.queue_free()
	wheels.clear()
	front_wheels.clear()
	body = null
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
	driver.position = Vector3(0, 0.02 + driver_def.vehicle_hover, 0)
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
		if not mesh.visible or String(mesh.name).begins_with("wheel") or (driver and driver.is_ancestor_of(mesh)):
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
