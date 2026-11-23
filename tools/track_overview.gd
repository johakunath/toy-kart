extends SceneTree
## Saves a picture of a whole track from straight above (for checking a layout).
##
##   godot --path . --script res://tools/track_overview.gd -- --track=wohnzimmer --shot=C:/tmp/top.png
##
## Optional: --size=<metres shown>, --center=x,z, --tilt (a slanted bird's-eye view instead).

var _frames := 0
var _shot := ""

func _initialize() -> void:
	var id := "kurvenkurs"
	var size := 0.0
	var center := Vector2.INF
	var tilt := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			id = arg.substr(8)
		elif arg.begins_with("--shot="):
			_shot = arg.substr(7)
		elif arg.begins_with("--size="):
			size = float(arg.substr(7))
		elif arg.begins_with("--center="):
			var parts := arg.substr(9).split(",")
			center = Vector2(float(parts[0]), float(parts[1]))
		elif arg == "--tilt":
			tilt = true
	root.size = Vector2i(1600, 1200)
	var track := (load("res://scenes/tracks/%s.tscn" % id) as PackedScene).instantiate() as Node3D
	root.add_child(track)
	var path := track.get_node("RacingLine") as Path3D
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in path.curve.get_baked_points():
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	if center == Vector2.INF:
		center = (lo + hi) * 0.5
	if size <= 0.0:
		size = maxf(hi.x - lo.x, (hi.y - lo.y) * 4.0 / 3.0) + 40.0
	var camera := Camera3D.new()
	camera.far = 2000.0
	if tilt:
		camera.fov = 50.0
		camera.position = Vector3(center.x, size * 0.55, center.y + size * 0.75)
		root.add_child(camera)
		camera.look_at(Vector3(center.x, 0, center.y))
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = size * 0.75
		camera.position = Vector3(center.x, 300.0, center.y)
		camera.rotation_degrees = Vector3(-90, 0, 0)
		root.add_child(camera)
	camera.current = true

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		var image := root.get_texture().get_image()
		image.save_png(_shot)
		print("overview saved: ", _shot)
		return true
	return false
