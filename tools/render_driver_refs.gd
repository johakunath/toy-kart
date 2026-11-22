extends SceneTree
## Renders a front picture of every 3D driver model that has no drawing (the Kenney characters),
## as the reference for its FLUX portrait (tools/make_portraits.py). Needs a window (rendering):
##
##   godot --path . --script res://tools/render_driver_refs.gd -- --out=<folder>
##
## Writes <folder>/<driver id>.png (768 x 768, white background).

const SIZE := 768

var _frame := 0
var _queue: Array[String] = []
var _out := ""
var _viewport: SubViewport
var _holder: Node3D
var _camera: Camera3D
var _current := ""

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--out="):
				_out = arg.substr(6)
		for file in DirAccess.get_files_at("res://data/drivers"):
			if file.begins_with("model_") and file.ends_with(".tres"):
				_queue.append("res://data/drivers/" + file)
		_build_stage()
		return false
	if _current != "":
		if _frame % 6 != 0:
			return false
		var image := _viewport.get_texture().get_image()
		image.save_png(_out.path_join(_current + ".png"))
		print("REF ", _current)
		_current = ""
	if _queue.is_empty():
		print("REFS OK")
		return true
	_show(_queue.pop_front())
	return false

func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_8X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 20, 0)
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 25.0
	_viewport.add_child(_camera)
	_holder = Node3D.new()
	_viewport.add_child(_holder)

func _show(path: String) -> void:
	for child in _holder.get_children():
		child.queue_free()
	var def: Resource = load(path)
	var model: Node3D = (def.get("model_scene") as PackedScene).instantiate()
	_holder.add_child(model)
	var box := _bounds(model)
	# Head and shoulders: the upper 70 % of the figure, seen straight from the front (+Z).
	var top := box.end.y
	var height := box.size.y * 0.72
	var center := Vector3(box.get_center().x, top - height * 0.5, box.get_center().z)
	var distance := height * 0.75 / tan(deg_to_rad(_camera.fov * 0.5))
	_camera.look_at_from_position(center + Vector3(0, 0, distance), center, Vector3.UP)
	_camera.current = true
	_current = str(def.get("id"))

func _bounds(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var b := mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
