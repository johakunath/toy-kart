class_name TrackBuildCommon extends RefCounted
## Helpers shared by the track builders (tools/build_track.gd, tools/build_round_track.gd).

## Adds boost stars along the racing line. `rows` holds [metres from the start, [sideways offsets]].
static func add_stars(root: Node3D, curve: Curve3D, rows: Array) -> int:
	var stars := Node3D.new()
	stars.name = "Stars"
	root.add_child(stars)
	stars.owner = root
	var star_scene: PackedScene = load("res://scenes/boost_star.tscn")
	var number := 1
	for row in rows:
		var s: float = row[0]
		var here := curve.sample_baked(s, true)
		var ahead := curve.sample_baked(s + 0.5, true)
		var dir := (ahead - here)
		dir.y = 0.0
		dir = dir.normalized()
		var right := dir.cross(Vector3.UP)
		for lateral: float in row[1]:
			var star := star_scene.instantiate() as Node3D
			star.name = "Star%d" % number
			number += 1
			star.position = Vector3(here.x, here.y, here.z) + right * lateral
			stars.add_child(star)
			star.owner = root
	return number - 1

## Adds turbo arrows on the road. `rows` holds [metres from the start, [sideways offsets]].
## `bank_at` (optional) gives tan(bank) at a distance, so the arrows lie flat on banked road.
static func add_pads(root: Node3D, curve: Curve3D, rows: Array, road_y: float, bank_at := Callable()) -> int:
	var pads := Node3D.new()
	pads.name = "BoostPads"
	root.add_child(pads)
	pads.owner = root
	var number := 1
	for row in rows:
		var s: float = row[0]
		var here := curve.sample_baked(s, true)
		var ahead := curve.sample_baked(s + 0.5, true)
		var dir := (ahead - here)
		dir.y = 0.0
		dir = dir.normalized()
		var right := dir.cross(Vector3.UP)
		for lateral: float in row[1]:
			var pad := BoostPad.new()
			pad.name = "Pad%d" % number
			number += 1
			var bank: float = bank_at.call(s) if bank_at.is_valid() else 0.0
			var slope := (ahead - here)
			var forward := slope.normalized() if slope.length() > 0.001 else dir
			var origin := Vector3(here.x, here.y + road_y + 0.15 - lateral * bank, here.z) + right * lateral
			var up := (forward.cross(right) * -1.0).normalized()
			up = (up + right * bank).normalized()
			var side := up.cross(forward).normalized()
			pad.transform = Transform3D(Basis(side, up, up.cross(side) * -1.0).orthonormalized(), origin)
			pads.add_child(pad)
			pad.owner = root
	return number - 1

## Adds the node that sets up light, sky and weather when the track runs.
static func add_atmosphere(root: Node3D, look: int, center: Vector3, size: Vector3) -> void:
	var atmosphere := Atmosphere.new()
	atmosphere.name = "Atmosphere"
	atmosphere.look = look as Atmosphere.Look
	atmosphere.area_center = center
	atmosphere.area_size = size
	root.add_child(atmosphere)
	atmosphere.owner = root

## The floor the karts roll on: one big flat collider with its top at height 0.
static func add_ground_collider(root: Node3D) -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.position = Vector3(0, -0.5, 0)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(800, 1, 800)
	shape.shape = box
	ground.add_child(shape)
	root.add_child(ground)
	ground.owner = root
	shape.owner = root

## Writes data/tracks/<id>.tres: name, scene and the outline shown on the menu button.
static func write_track_def(id: String, display_name: String, sort_order: int, curve: Curve3D, laps := 3) -> Error:
	var points := PackedVector2Array()
	var length := curve.get_baked_length()
	var count := 72
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in count:
		var p := curve.sample_baked(length * i / count, true)
		var q := Vector2(p.x, p.z)
		points.append(q)
		lo = lo.min(q)
		hi = hi.max(q)
	var mid := (lo + hi) * 0.5
	var half := maxf(hi.x - lo.x, hi.y - lo.y) * 0.5
	for i in count:
		points[i] = (points[i] - mid) / half
	var def := TrackDef.new()
	def.id = id
	def.display_name = display_name
	def.sort_order = sort_order
	def.scene_path = "res://scenes/tracks/%s.tscn" % id
	def.outline = points
	def.laps = laps
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/tracks"))
	return ResourceSaver.save(def, "res://data/tracks/%s.tres" % id)

static func save_scene(root: Node3D, id: String) -> Error:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/tracks"))
	return ResourceSaver.save(packed, "res://scenes/tracks/%s.tscn" % id)
