class_name OpenMap extends RefCounted
## A coarse floor map of an open world without a racing line: which 2 m cells a kart fits in,
## and "which way to" fields toward a spot (breadth-first, round furniture). The explore mode
## uses them for the kid's gentle pull toward the next lost thing, for the test bot, and to
## put a stuck kart back on free floor.

const CELL := 2.0
const PROBE_RADIUS := 1.3   ## a cell is free if a ball this big fits at kart height
const PROBE_HEIGHT := 1.5

var origin := Vector2.ZERO   ## x, z of the corner of cell 0
var nx := 0
var nz := 0
var blocked := PackedByteArray()

## Probes every cell against layer 1 (furniture, walls). Call from _physics_process.
func build(space: PhysicsDirectSpaceState3D, lo: Vector2, hi: Vector2) -> void:
	origin = lo
	nx = ceili((hi.x - lo.x) / CELL)
	nz = ceili((hi.y - lo.y) / CELL)
	blocked.resize(nx * nz)
	var shape := SphereShape3D.new()
	shape.radius = PROBE_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	for i in nx * nz:
		query.transform = Transform3D(Basis.IDENTITY, center(i) + Vector3(0, PROBE_HEIGHT, 0))
		blocked[i] = 1 if not space.intersect_shape(query, 1).is_empty() else 0

func is_ready() -> bool:
	return nx > 0

func free_count() -> int:
	var n := 0
	for b in blocked:
		n += 1 - b
	return n

func cell_at(p: Vector3) -> int:
	var cx := int(floor((p.x - origin.x) / CELL))
	var cz := int(floor((p.z - origin.y) / CELL))
	if cx < 0 or cz < 0 or cx >= nx or cz >= nz:
		return -1
	return cz * nx + cx

func center(i: int) -> Vector3:
	@warning_ignore("integer_division")
	var cz := i / nx
	var cx := i % nx
	return Vector3(origin.x + (cx + 0.5) * CELL, 0.0, origin.y + (cz + 0.5) * CELL)

func is_free(i: int) -> bool:
	return i >= 0 and i < blocked.size() and blocked[i] == 0

## Steps (cells) from every cell to `target`; -1 where it cannot be reached.
func field_to(target: Vector3) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(nx * nz)
	dist.fill(-1)
	var start := nearest_free_cell(target, 5)
	if start < 0:
		return dist
	var queue: Array[int] = [start]
	dist[start] = 0
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		for j in _neighbours(i):
			if dist[j] < 0:
				dist[j] = dist[i] + 1
				queue.append(j)
	return dist

## Free neighbours of a cell (8 ways; diagonals only past two free sides).
func _neighbours(i: int) -> Array[int]:
	var out: Array[int] = []
	@warning_ignore("integer_division")
	var cz := i / nx
	var cx := i % nx
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var x: int = cx + dx
			var z: int = cz + dz
			if x < 0 or z < 0 or x >= nx or z >= nz or blocked[z * nx + x] == 1:
				continue
			if dx != 0 and dz != 0 and (blocked[cz * nx + x] == 1 or blocked[z * nx + cx] == 1):
				continue
			out.append(z * nx + x)
	return out

## Steps from `p` along a field (large when unknown).
func steps(field: PackedInt32Array, p: Vector3) -> int:
	var i := nearest_free_cell(p, 2)
	if i < 0 or field.is_empty() or field[i] < 0:
		return 100000
	return field[i]

## Flat direction to drive from `p` to follow a field: a few cells down the hill, so the
## line is smooth. Zero when there is no way.
func direction(field: PackedInt32Array, p: Vector3, look := 3) -> Vector3:
	if field.is_empty():
		return Vector3.ZERO
	var i := cell_at(p)
	if not is_free(i) or field[i] < 0:
		i = nearest_free_cell(p, 3, field)
		if i < 0:
			return Vector3.ZERO
		var to := center(i) - p
		to.y = 0.0
		return to.normalized() if to.length() > 0.1 else Vector3.ZERO
	var here := i
	for _step in look:
		var best := here
		for j in _neighbours(here):
			if field[j] >= 0 and field[j] < field[best]:
				best = j
		if best == here:
			break
		here = best
	var d := center(here) - p
	d.y = 0.0
	return d.normalized() if d.length() > 0.2 else Vector3.ZERO

## The free cell closest to `p` within `radius` cells (-1 if none). With a field, only cells
## that can reach its target count.
func nearest_free_cell(p: Vector3, radius: int, field := PackedInt32Array()) -> int:
	var cx := int(floor((p.x - origin.x) / CELL))
	var cz := int(floor((p.z - origin.y) / CELL))
	var best := -1
	var best_d := INF
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := cx + dx
			var z := cz + dz
			if x < 0 or z < 0 or x >= nx or z >= nz:
				continue
			var i := z * nx + x
			if blocked[i] == 1 or (not field.is_empty() and field[i] < 0):
				continue
			var d := center(i).distance_squared_to(Vector3(p.x, 0, p.z))
			if d < best_d:
				best_d = d
				best = i
	return best

## A spot with room all around (for putting a stuck kart back), near `p`.
func open_spot(p: Vector3) -> Vector3:
	for radius in range(1, 12):
		var best := -1
		var best_d := INF
		var cx := int(floor((p.x - origin.x) / CELL))
		var cz := int(floor((p.z - origin.y) / CELL))
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var x := cx + dx
				var z := cz + dz
				if x < 1 or z < 1 or x >= nx - 1 or z >= nz - 1:
					continue
				var i := z * nx + x
				if blocked[i] == 1 or _neighbours(i).size() < 8:
					continue
				var d := center(i).distance_squared_to(Vector3(p.x, 0, p.z))
				if d < best_d:
					best_d = d
					best = i
		if best >= 0:
			return center(best)
	return Vector3(p.x, 0, p.z)
