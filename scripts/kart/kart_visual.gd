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
