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
	body = model.find_child("body", true, false) as Node3D
	fork = model.find_child("fork", true, false) as Node3D
	lean_node = model.find_child("motorcycle", true, false) as Node3D
	for node in model.find_children("wheel-*", "Node3D", true, false):
		wheels.append(node)
		if String(node.name).contains("front"):
			front_wheels.append(node)
	var seat_parent: Node3D = body if body else model
	body_rest = body.position if body else Vector3.ZERO
	driver = DriverRig.new()
	driver.name = "Driver"
	seat_parent.add_child(driver)
	# The seat is given in model space; the body node has its own offset.
	driver.position = kart_def.seat_position - (body_rest if body else Vector3.ZERO)
	driver.build(driver_def, kart_def.seat_scale)
