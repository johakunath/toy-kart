extends SceneTree
## Builds a track with round, flowing curves. Unlike the tile track, nothing here is a grid:
## the road is drawn along one smooth line through a track's points, and the same line is
## the racing line. Road, kerbs, barriers, walls, trees and the menu outline all come from it.
##
##   godot --headless --path . --script res://tools/build_round_track.gd
##
##   godot --headless --path . --script res://tools/build_round_track.gd -- --track=riesenrunde
##
## Writes scenes/tracks/<id>.tscn (+ _road.res) and data/tracks/<id>.tres for each track in TRACKS.
## To change a track: move, add or remove points, run again, run the checks.

## Each track: points of the road's centre in metres (x to the east, y to the south), in
## driving order. The first point is the start/finish line; the line runs smoothly through all.
## Stars and turbo arrows: [metres after the start line, [sideways offsets in metres]].
const TRACKS := [
	{
		"id": "kurvenkurs", "name": "Kurvenkurs", "sort": 10, "laps": 3, "look": Atmosphere.Look.SUNNY_DAY,
		"points": [
			Vector2(0, 0), Vector2(26, 0), Vector2(44, -5), Vector2(55, -19), Vector2(53, -36),
			Vector2(40, -47), Vector2(24, -46), Vector2(12, -37), Vector2(0, -33), Vector2(-12, -40),
			Vector2(-22, -52), Vector2(-38, -54), Vector2(-50, -44), Vector2(-53, -28), Vector2(-45, -14),
			Vector2(-32, -6), Vector2(-18, -1),
		],
		"stars": [[58.0, [-1.8, 0.0, 1.8]], [124.0, [-1.4]], [186.0, [-1.8, 0.0, 1.8]], [240.0, [1.6]]],
		"pads": [[12.0, [-1.4, 1.4]], [106.0, [0.0]], [200.0, [1.2]]],
	},
	{
		# The long one: a big loop with an S, a wide hairpin and a long home straight. Two laps.
		"id": "riesenrunde", "name": "Riesenrunde", "sort": 30, "laps": 2, "look": Atmosphere.Look.SUNNY_DAY,
		"points": [
			Vector2(0, 0), Vector2(30, 0), Vector2(60, 0), Vector2(85, -4), Vector2(100, -18),
			Vector2(102, -38), Vector2(92, -52), Vector2(75, -56), Vector2(60, -50), Vector2(45, -58),
			Vector2(30, -70), Vector2(22, -88), Vector2(30, -104), Vector2(48, -112), Vector2(66, -110),
			Vector2(80, -120), Vector2(84, -138), Vector2(72, -152), Vector2(52, -156), Vector2(30, -150),
			Vector2(10, -140), Vector2(-8, -128), Vector2(-24, -120), Vector2(-42, -124), Vector2(-58, -134),
			Vector2(-74, -130), Vector2(-84, -114), Vector2(-82, -94), Vector2(-70, -80), Vector2(-54, -74),
			Vector2(-44, -60), Vector2(-48, -42), Vector2(-60, -28), Vector2(-58, -12), Vector2(-44, -2),
			Vector2(-24, 1),
		],
		"stars": [[40.0, [-1.8, 0.0, 1.8]], [140.0, [-1.4]], [205.0, [-1.8, 0.0, 1.8]], [300.0, [1.6]],
			[395.0, [-1.4]], [480.0, [-1.8, 0.0, 1.8]]],
		"pads": [[16.0, [-1.4, 1.4]], [120.0, [1.2]], [235.0, [0.0]], [325.0, [0.0]], [420.0, [-1.2]],
			[505.0, [-1.4, 1.4]]],
	},
]

const HALF_WIDTH := 3.6      # centre line to the wall face (what the karts can use)
const ASPHALT := 3.0         # centre line to where the kerb starts
const ROAD_Y := -0.15        # kart models sit 0.15 m below the physics floor (Kenney kit)
const STEP := 0.75           # one slice of road every 0.75 m
const TREE_CLEARANCE := 10.5 # trees keep this far from the centre line, so cameras see past them

const C_ASPHALT := Color("4a4c5a")
const C_LINE := Color("e9ecf5")
const C_KERB_RED := Color("e5544a")
const C_KERB_WHITE := Color("f3f4f8")
const C_BARRIER := Color("c7d1ee")
const C_GRASS := Color("5fbf86")
const C_BLACK := Color("2a2b33")

## Barrier cross-section: [metres outward from the wall face, metres above the road].
const BARRIER: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.0, 0.32), Vector2(0.07, 0.43), Vector2(0.19, 0.47),
	Vector2(0.37, 0.47), Vector2(0.49, 0.43), Vector2(0.56, 0.32), Vector2(0.56, -0.1),
]

var _id := ""
var _points: Array = []
var _pos := PackedVector3Array()
var _right := PackedVector3Array()
var _count := 0

func _process(_delta: float) -> bool:
	# "-- --track=<id>" builds one track; without it, all of them.
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			only = arg.substr(8)
	var err := OK
	for cfg: Dictionary in TRACKS:
		if only == "" or only == cfg["id"]:
			var e := _build(cfg)
			if e != OK:
				err = e
	quit(0 if err == OK else 1)
	return true

func _build(cfg: Dictionary) -> Error:
	_id = cfg["id"]
	_points = cfg["points"]
	_pos = PackedVector3Array()
	_right = PackedVector3Array()
	# --- The line ---
	var curve := Curve3D.new()
	curve.bake_interval = 0.2
	var n := _points.size()
	for i in n + 1:
		var p: Vector2 = _points[i % n]
		var prev: Vector2 = _points[(i - 1 + n) % n]
		var next: Vector2 = _points[(i + 1) % n]
		var handle := (next - prev) / 6.0
		curve.add_point(Vector3(p.x, 0, p.y), Vector3(-handle.x, 0, -handle.y), Vector3(handle.x, 0, handle.y))
	var length := curve.get_baked_length()
	_count = int(round(length / STEP))
	_pos.resize(_count)
	_right.resize(_count)
	for i in _count:
		_pos[i] = curve.sample_baked(length * i / _count, true)
	var min_radius := INF
	for i in _count:
		var a := _pos[(i - 1 + _count) % _count]
		var b := _pos[(i + 1) % _count]
		var dir := (b - a).normalized()
		_right[i] = dir.cross(Vector3.UP).normalized()
	for i in _count:
		var d0 := (_pos[i] - _pos[(i - 3 + _count) % _count]).normalized()
		var d1 := (_pos[(i + 3) % _count] - _pos[i]).normalized()
		var turn := absf(d0.signed_angle_to(d1, Vector3.UP))
		if turn > 0.0001:
			min_radius = minf(min_radius, 3.0 * STEP / turn)
	var min_gap := INF
	var far := int(30.0 / STEP)
	for i in _count:
		for j in range(i + far, _count):
			if _count - (j - i) < far:
				continue
			min_gap = minf(min_gap, _pos[i].distance_to(_pos[j]))
	print("%s line: length=%.1f m  slices=%d  tightest radius=%.1f m  closest pass=%.1f m" % [_id, length, _count, min_radius, min_gap])
	if min_gap < 2.0 * (HALF_WIDTH + 0.6) + 3.0:
		push_error("Two parts of the track are too close together.")
		return ERR_INVALID_DATA
	if min_radius < HALF_WIDTH + 1.5:
		push_error("A corner is tighter than the road is wide.")
		return ERR_INVALID_DATA

	var root := Track.new()
	root.name = "Track"
	root.half_width = HALF_WIDTH

	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for p in _pos:
		lo = Vector3(minf(lo.x, p.x), 0, minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), 0, maxf(hi.z, p.z))
	var center := (lo + hi) * 0.5
	var size := hi - lo

	TrackBuildCommon.add_atmosphere(root, cfg["look"], center, size)
	TrackBuildCommon.add_ground_collider(root)
	_add_walls(root)
	_add_road(root)
	_add_grass(root, center, size)
	_add_trees(root, lo, hi)
	_add_gate(root)

	var path := Path3D.new()
	path.name = "RacingLine"
	path.curve = curve
	root.add_child(path)
	path.owner = root
	var star_count := TrackBuildCommon.add_stars(root, curve, cfg["stars"])
	var pad_count := TrackBuildCommon.add_pads(root, curve, cfg["pads"], ROAD_Y)

	var err := TrackBuildCommon.save_scene(root, _id)
	if err == OK:
		err = TrackBuildCommon.write_track_def(_id, cfg["name"], cfg["sort"], curve, cfg["laps"])
	print("track written: res://scenes/tracks/%s.tscn  stars=%d  pads=%d  err=%d" % [_id, star_count, pad_count, err])
	root.free()
	return err

# --- Geometry helpers ----------------------------------------------------------------------

## A point of road slice i: `d` metres to the right of the centre line, `h` metres above the road.
func _at(i: int, d: float, h: float) -> Vector3:
	var k := posmod(i, _count)
	return _pos[k] + _right[k] * d + Vector3(0, ROAD_Y + h, 0)

## A surface normal of slice i from a cross-section normal (sideways part, upward part).
func _normal(i: int, sideways: float, up: float) -> Vector3:
	return (_right[posmod(i, _count)] * sideways + Vector3.UP * up).normalized()

func _quad(st: SurfaceTool, v: Array[Vector3], normals: Array[Vector3], color: Color) -> void:
	# Godot shows the side where the corners run clockwise. Flip the order if the face would
	# otherwise point away from its normals.
	var facing := (v[2] - v[0]).cross(v[1] - v[0])
	var order := [0, 1, 2, 0, 2, 3]
	if facing.dot(normals[0] + normals[1] + normals[2]) < 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for k: int in order:
		st.set_color(color)
		st.set_normal(normals[k])
		st.add_vertex(v[k])

## One ribbon along the whole track between two cross-section points.
## `color_at` picks the colour for slice i; returning a transparent colour skips the slice.
func _ribbon(st: SurfaceTool, d0: float, h0: float, n0: Vector2, d1: float, h1: float, n1: Vector2, color_at: Callable) -> void:
	for i in _count:
		var color: Color = color_at.call(i)
		if color.a < 0.5:
			continue
		var v: Array[Vector3] = [_at(i, d0, h0), _at(i, d1, h1), _at(i + 1, d1, h1), _at(i + 1, d0, h0)]
		var normals: Array[Vector3] = [_normal(i, n0.x, n0.y), _normal(i, n1.x, n1.y), _normal(i + 1, n1.x, n1.y), _normal(i + 1, n0.x, n0.y)]
		_quad(st, v, normals, color)

# --- Road, kerbs, barriers -----------------------------------------------------------------

func _add_road(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector2(0, 1)
	_ribbon(st, -ASPHALT, 0.0, up, ASPHALT, 0.0, up, func(_i: int) -> Color: return C_ASPHALT)
	# Edge lines and a dashed centre line.
	for side: float in [-1.0, 1.0]:
		_ribbon(st, side * (ASPHALT - 0.3), 0.012, up, side * (ASPHALT - 0.14), 0.012, up, func(_i: int) -> Color: return C_LINE)
	_ribbon(st, -0.07, 0.012, up, 0.07, 0.012, up,
		func(i: int) -> Color: return C_LINE if (i >> 2) % 2 == 0 else Color.TRANSPARENT)
	# Red and white kerbs, slightly raised toward the barrier.
	for side: float in [-1.0, 1.0]:
		_ribbon(st, side * ASPHALT, 0.01, up, side * HALF_WIDTH, 0.05, up,
			func(i: int) -> Color: return C_KERB_RED if (i >> 1) % 2 == 0 else C_KERB_WHITE)
	# Chequered start line: two rows of squares across the asphalt.
	var squares := int(round(2.0 * ASPHALT / STEP))
	for row in 2:
		for col in squares:
			var d0 := -ASPHALT + col * STEP
			var color := C_KERB_WHITE if (row + col) % 2 == 0 else C_BLACK
			var v: Array[Vector3] = [_at(row - 1, d0, 0.016), _at(row - 1, d0 + STEP, 0.016), _at(row, d0 + STEP, 0.016), _at(row, d0, 0.016)]
			var normals: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
			_quad(st, v, normals, color)
	# Rounded barriers on both sides.
	var seg_normals: Array[Vector2] = []
	for k in BARRIER.size() - 1:
		var d := BARRIER[k + 1] - BARRIER[k]
		seg_normals.append(Vector2(-d.y, d.x).normalized())
	var point_normals: Array[Vector2] = []
	for k in BARRIER.size():
		var a := seg_normals[maxi(k - 1, 0)]
		var b := seg_normals[mini(k, seg_normals.size() - 1)]
		point_normals.append((a + b).normalized())
	for side: float in [-1.0, 1.0]:
		for k in BARRIER.size() - 1:
			var p0 := BARRIER[k]
			var p1 := BARRIER[k + 1]
			_ribbon(st, side * (HALF_WIDTH + p0.x), p0.y, Vector2(side * point_normals[k].x, point_normals[k].y),
				side * (HALF_WIDTH + p1.x), p1.y, Vector2(side * point_normals[k + 1].x, point_normals[k + 1].y),
				func(_i: int) -> Color: return C_BARRIER)
	st.index()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.85
	st.set_material(material)
	var mesh := st.commit()
	var mesh_path := "res://scenes/tracks/%s_road.res" % _id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/tracks"))
	ResourceSaver.save(mesh, mesh_path)
	var road := MeshInstance3D.new()
	road.name = "Road"
	road.mesh = load(mesh_path)
	root.add_child(road)
	road.owner = root
	print("road mesh: %d vertices" % mesh.surface_get_array_len(0))

## Invisible walls the karts bounce off, at the wall face on both sides.
func _add_walls(root: Node3D) -> void:
	var faces := PackedVector3Array()
	for side: float in [-1.0, 1.0]:
		for i in _count:
			var a_low := _at(i, side * HALF_WIDTH, -0.4)
			var a_high := _at(i, side * HALF_WIDTH, 3.2)
			var b_low := _at(i + 1, side * HALF_WIDTH, -0.4)
			var b_high := _at(i + 1, side * HALF_WIDTH, 3.2)
			faces.append_array([a_low, a_high, b_high, a_low, b_high, b_low])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "Walls"
	var material := PhysicsMaterial.new()
	material.friction = 0.0
	material.bounce = 0.1
	body.physics_material_override = material
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	body.owner = root
	collision.owner = root

# --- Scenery -------------------------------------------------------------------------------

func _distance_to_line(p: Vector3) -> float:
	var best := INF
	for q in _pos:
		best = minf(best, Vector2(p.x - q.x, p.z - q.z).length_squared())
	return sqrt(best)

func _add_grass(root: Node3D, center: Vector3, size: Vector3) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000.0, 4000.0)  # reaches past the haze, so no edge is ever visible
	var material := StandardMaterial3D.new()
	material.albedo_color = C_GRASS
	material.roughness = 0.95
	plane.material = material
	var grass := MeshInstance3D.new()
	grass.name = "Grass"
	grass.mesh = plane
	grass.position = Vector3(center.x, ROAD_Y - 0.03, center.z)
	root.add_child(grass)
	grass.owner = root

	# Lighter and darker patches break up the lawn and make speed visible.
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 14
	disc.rings = 1
	var patch_material := StandardMaterial3D.new()
	patch_material.vertex_color_use_as_albedo = true
	patch_material.roughness = 0.95
	disc.material = patch_material
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for attempt in 900:
		var p := Vector3(rng.randf_range(center.x - size.x * 0.5 - 60.0, center.x + size.x * 0.5 + 60.0), 0,
			rng.randf_range(center.z - size.z * 0.5 - 60.0, center.z + size.z * 0.5 + 60.0))
		var radius := rng.randf_range(1.6, 5.0)
		if _distance_to_line(p) < HALF_WIDTH + 0.7 + radius * 1.3:
			continue
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(radius * rng.randf_range(0.8, 1.3), 1.0, radius))
		transforms.append(Transform3D(basis, Vector3(p.x, ROAD_Y - 0.02, p.z)))
		colors.append(C_GRASS.lightened(0.09) if rng.randf() < 0.5 else C_GRASS.darkened(0.08))
		if transforms.size() >= 170:
			break
	var patches := Scatter.new()
	patches.name = "GrassPatches"
	patches.source_mesh = disc
	patches.placements = transforms
	patches.tints = PackedColorArray(colors)
	patches.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(patches)
	patches.owner = root

func _add_trees(root: Node3D, lo: Vector3, hi: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122
	var noise := FastNoiseLite.new()
	noise.seed = 99
	noise.frequency = 0.035
	var spots: Array[Vector3] = []
	for attempt in 12000:
		var p := Vector3(rng.randf_range(lo.x - 55.0, hi.x + 55.0), 0, rng.randf_range(lo.z - 55.0, hi.z + 55.0))
		var dist := _distance_to_line(p)
		if dist < TREE_CLEARANCE:
			continue
		# Woods in clumps, with clearings in between; thicker far from the road.
		var wooded := noise.get_noise_2d(p.x, p.z) * 0.5 + 0.5
		if rng.randf() > wooded * (0.35 + minf(dist / 60.0, 0.65)):
			continue
		var crowded := false
		for q in spots:
			if p.distance_squared_to(q) < 3.4 * 3.4:
				crowded = true
				break
		if crowded:
			continue
		spots.append(p)
		if spots.size() >= clampi(int(_count * STEP * 1.05), 300, 650):
			break
	var kinds := [
		{"name": "Trees", "path": "res://assets/kenney_toy_car_kit/tree.glb", "min": 5.0, "max": 7.5},
		{"name": "Pines", "path": "res://assets/kenney_toy_car_kit/tree-pine.glb", "min": 6.0, "max": 9.5},
	]
	for k in kinds.size():
		var kind: Dictionary = kinds[k]
		var mine: Array[Transform3D] = []
		for i in spots.size():
			if (noise.get_noise_2d(spots[i].z * 2.0, spots[i].x * 2.0) > 0.0) == (k == 0):
				var s := rng.randf_range(kind["min"], kind["max"])
				mine.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)),
					Vector3(spots[i].x, ROAD_Y - 0.02, spots[i].z)))
		var node := Scatter.new()
		node.name = kind["name"]
		node.source_scene = load(kind["path"])
		node.placements = mine
		root.add_child(node)
		node.owner = root
		print("%s: %d" % [kind["name"], mine.size()])

func _add_gate(root: Node3D) -> void:
	var gate := (load("res://assets/kenney_toy_car_kit/gate-finish.glb") as PackedScene).instantiate() as Node3D
	gate.name = "Gate"
	# The gate spans the road and both barriers; its front faces the karts coming up to the line.
	var forward := (_pos[1] - _pos[_count - 1]).normalized()
	var yaw := atan2(-forward.x, -forward.z)
	gate.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 6.6), Vector3(_pos[0].x, ROAD_Y, _pos[0].z))
	root.add_child(gate)
	gate.owner = root
