class_name TrackNature extends RefCounted
## Grass, flowers, reeds and ponds for the round tracks, called by tools/build_round_track.gd.
## A track entry opts in with  "grass": true  and  "water": [[Vector2(x, z) of the middle, radius], ...].
## Only positions are stored (GrassField, Pond); the game makes the meshes when the track loads.
## Grass grows thick along the barriers, on the embankments of raised road and in clumps and
## flower patches on the lawn near the road, never on the road. Ponds must lie on flat lawn
## clear of the road and its embankments; otherwise the builder reports an error and leaves them out.

const CELL := 8.0             # grid size of the nearest-slice lookup
const SEEN := 40.0            # grass further than this from the road is never seen up close
const EDGE_BAND := 4.0        # thick strip along the road: metres of lawn beyond the barrier
const EDGE_PER_SLICE := 3     # plants per road slice (0.75 m) and side in that strip
const CLUMPS_PER_SLICE := 0.7 # clumps and flower patches on the lawn per road slice
const BLOCKED := -1000.0

var _b: Object
var _id := ""
var _pos := PackedVector3Array()
var _right := PackedVector3Array()
var _count := 0
var _edge := 0.0      # centre line to the outer side of the barrier
var _slope := 1.5     # embankment: metres outward per metre of height
var _ground_y := 0.0  # height of the lawn
var _grid := {}       # Vector2i cell -> PackedInt32Array of slices
var _near_d2 := 0.0
var _ponds: Array[Vector3] = []  # x, z, radius
var _pond_seeds := PackedInt32Array()
var _spots := PackedVector4Array()
var _kinds := PackedByteArray()

static func add(root: Node3D, builder: Object, cfg: Dictionary) -> void:
	var water: Array = cfg.get("water", [])
	var grass: bool = cfg.get("grass", false)
	if not grass and water.is_empty():
		return
	var nature := TrackNature.new()
	nature._setup(builder, cfg)
	nature._add_ponds(root, water)
	if grass:
		nature._add_plants(root)
	return

func _setup(builder: Object, cfg: Dictionary) -> void:
	_b = builder
	_id = cfg["id"]
	_pos = builder.get("_pos")
	_right = builder.get("_right")
	_count = builder.get("_count")
	var consts := (builder.get_script() as Script).get_script_constant_map()
	var barrier: Array = consts["BARRIER"]
	_edge = float(consts["HALF_WIDTH"]) + (barrier[barrier.size() - 1] as Vector2).x
	_slope = consts["SKIRT_SLOPE"]
	_ground_y = float(consts["ROAD_Y"]) - 0.03
	for i in _count:
		var key := _cell(_pos[i].x, _pos[i].z)
		var ids: PackedInt32Array = _grid.get(key, PackedInt32Array())
		ids.append(i)
		_grid[key] = ids

static func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL), floori(z / CELL))

## The road slice nearest to (x, z), or -1 when none is within about 60 m. Sets _near_d2.
func _nearest(x: float, z: float) -> int:
	var c := _cell(x, z)
	var best := -1
	_near_d2 = INF
	for ring in 9:
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var ids: PackedInt32Array = _grid.get(c + Vector2i(dx, dz), PackedInt32Array())
				for k in ids:
					var d2 := Vector2(x - _pos[k].x, z - _pos[k].z).length_squared()
					if d2 < _near_d2:
						_near_d2 = d2
						best = k
		# Cells further out are at least ring * CELL away.
		if best >= 0 and _near_d2 <= (ring * CELL) * (ring * CELL):
			break
	return best

## Height of the ground at (x, z): the lawn, or the embankment of raised road; BLOCKED on the
## road and its barriers.
func _ground(x: float, z: float) -> float:
	var k := _nearest(x, z)
	if k < 0:
		return _ground_y
	var d := Vector2(x - _pos[k].x, z - _pos[k].z).dot(Vector2(_right[k].x, _right[k].z))
	var side := 1.0 if d >= 0.0 else -1.0
	var ad := absf(d)
	if ad < _edge + 0.12:
		return BLOCKED
	# A side lane (fork) on this side: keep off it and its island too.
	var fork: Dictionary = _b.get("_fork")
	if not fork.is_empty() and side == float(_b.get("_fork_side")):
		if ad < float(_b.call("_lane_outer", k)) + (_edge - float(_b.get_script().get_script_constant_map()["HALF_WIDTH"])) + 0.12:
			return BLOCKED
	# Same embankment as build_round_track.gd _add_skirts.
	var top: Vector3 = _b.call("_at", k, side * _edge, -0.1)
	var rise := top.y - _ground_y
	if rise < 0.05 or ad >= _edge + rise * _slope:
		return _ground_y
	return top.y - (ad - _edge) / _slope - 0.04

func _in_pond(x: float, z: float, margin: float) -> bool:
	for j in _ponds.size():
		var p := _ponds[j]
		var off := Vector2(x - p.x, z - p.y)
		if off.length() < Pond.shore_radius(off.angle(), p.z, _pond_seeds[j]) + Pond.SHORE + margin:
			return true
	return false

func _plant(x: float, z: float, size: float, kind: int) -> bool:
	var y := _ground(x, z)
	if y <= BLOCKED or _in_pond(x, z, 0.05):
		return false
	_put(x, y, z, size, kind)
	return true

func _put(x: float, y: float, z: float, size: float, kind: int) -> void:
	_spots.append(Vector4(snappedf(x, 0.01), snappedf(y, 0.01), snappedf(z, 0.01), snappedf(size, 0.01)))
	_kinds.append(kind)

# --- Ponds -------------------------------------------------------------------------------------

func _add_ponds(root: Node3D, water: Array) -> void:
	for entry: Array in water:
		var mid: Vector2 = entry[0]
		var r: float = entry[1]
		var reach := r * 1.16 + Pond.SHORE
		var clear: float = _b.call("_distance_to_line", Vector3(mid.x, 0, mid.y)) - reach - _edge
		var flat := true
		for s in 36:
			var a := TAU * s / 36.0
			if _ground(mid.x + cos(a) * (reach + 0.5), mid.y + sin(a) * (reach + 0.5)) != _ground_y:
				flat = false
		if clear < 1.0 or not flat:
			push_error("%s: the pond at %s is too close to the road (%.1f m of lawn) or on an embankment (%s); left out." % [
				_id, mid, clear, not flat])
			continue
		var seed_value := _ponds.size() + 1
		var pond := Pond.new()
		pond.name = "Pond" if _ponds.is_empty() else "Pond%d" % seed_value
		pond.radius = r
		pond.shape_seed = seed_value
		pond.ducks = 3 if r >= 10.0 else 2
		pond.lily_pads = int(r * 0.9)
		pond.position = Vector3(mid.x, _ground_y, mid.y)
		pond.add_to_group(Scatter.KEEP_OUT_GROUP, true)
		root.add_child(pond)
		pond.owner = root
		_ponds.append(Vector3(mid.x, mid.y, r))
		_pond_seeds.append(seed_value)
		print("%s: pond at %s, radius %.1f m, %.1f m of lawn to the road" % [_id, mid, r, clear])

# --- Grass, flowers, reeds ---------------------------------------------------------------------

func _add_plants(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_id + "/grass")
	var flowers := GrassField.FLOWER_COLORS.size()
	# 1. A thick strip along both sides of the road, thickest at the barrier, over the
	#    embankment wherever the road is raised.
	for i in _count:
		var forward := Vector3(-_right[i].z, 0.0, _right[i].x)
		for side: float in [-1.0, 1.0]:
			var top: Vector3 = _b.call("_at", i, side * _edge, -0.1)
			var slope_width := maxf(top.y - _ground_y, 0.0) * _slope
			var on_slope := int(round(EDGE_PER_SLICE * slope_width / EDGE_BAND))
			for n in EDGE_PER_SLICE + on_slope:
				var u := rng.randf()
				# Spread evenly over the embankment, then thickest at its foot (or the barrier).
				var d := _edge + 0.2 + u * slope_width if n < on_slope else _edge + 0.2 + slope_width + u * u * EDGE_BAND
				var p := _pos[i] + _right[i] * side * d + forward * rng.randf_range(-0.4, 0.4)
				var kind := GrassField.GRASS
				if rng.randf() < 0.1:
					kind = GrassField.FLOWER + rng.randi() % flowers
				_plant(p.x, p.z, rng.randf_range(0.8, 1.35), kind)
	var strip := _spots.size()
	# 2. Clumps of grass and patches of flowers on the lawn, where the camera comes near.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in _pos:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi() % 10000
	noise.frequency = 0.04
	var want := int(_count * CLUMPS_PER_SLICE)
	var made := 0
	for attempt in want * 10:
		if made >= want:
			break
		var c := Vector2(rng.randf_range(lo.x - SEEN, hi.x + SEEN), rng.randf_range(lo.y - SEEN, hi.y + SEEN))
		if _nearest(c.x, c.y) < 0 or _near_d2 > SEEN * SEEN:
			continue
		# Meadows and short lawn: clumps gather where the noise is high.
		if noise.get_noise_2d(c.x, c.y) < 0.0 and rng.randf() < 0.8:
			continue
		made += 1
		var patch := rng.randf() < 0.3
		var color := rng.randi() % flowers
		var spread := rng.randf_range(0.7, 1.7)
		for j in rng.randi_range(5, 13):
			var q := c + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * spread
			var kind := GrassField.GRASS
			if patch and rng.randf() < 0.7:
				kind = GrassField.FLOWER + (color if rng.randf() < 0.8 else rng.randi() % flowers)
			_plant(q.x, q.y, rng.randf_range(0.75, 1.3), kind)
	var lawn := _spots.size() - strip
	# 3. Reeds in groups at the water's edge, grass and flowers round the sandy rim.
	for j in _ponds.size():
		var pond := _ponds[j]
		var steps := int(TAU * pond.z * 2.0)
		for s in steps:
			var a := TAU * (s + rng.randf()) / steps
			var edge := Pond.shore_radius(a, pond.z, _pond_seeds[j])
			var dir := Vector2.from_angle(a)
			if sin(a * 3.0 + _pond_seeds[j] * 1.3) > 0.15 and rng.randf() < 0.8:
				var q := Vector2(pond.x, pond.y) + dir * (edge + rng.randf_range(0.0, 0.35))
				_put(q.x, _ground_y + 0.1, q.y, rng.randf_range(0.85, 1.25), GrassField.REEDS)
			for k in 2:
				var q := Vector2(pond.x, pond.y) + dir * (edge + Pond.SHORE + 0.1 + rng.randf() * rng.randf() * 2.5)
				var kind := GrassField.FLOWER + rng.randi() % flowers if rng.randf() < 0.2 else GrassField.GRASS
				_plant(q.x, q.y, rng.randf_range(0.8, 1.3), kind)
	var field := GrassField.new()
	field.name = "GrassField"
	field.spots = _spots
	field.kinds = _kinds
	root.add_child(field)
	field.owner = root
	print("%s grass: %d plants (%d along the road, %d on the lawn, %d by the water)" % [
		_id, _spots.size(), strip, lawn, _spots.size() - strip - lawn])
