class_name Track extends Node3D
## A track scene: Kenney tiles in a GridMap plus one racing line (Path3D "RacingLine").
## The racing line does everything: smart steering, AI, lap counting, places, reset, start grid.
## Distances along the line are called "s" (metres from the finish line).

## Half the drivable road width in metres (wall to wall is twice this).
@export var half_width := 3.375
## Spacing of the internal sample table in metres.
@export var sample_step := 0.5
## Side lanes ("forks"): a second, narrower lane that leaves the road on one side and comes
## back, with an island in between. The racing line stays on the main road.
## Each: {"from": s, "to": s, "side": -1 (left) or 1 (right), "offset": lane centre in metres
## from the line, "lane": lane half width, "ease": metres to swing out and back in}.
@export var forks: Array[Dictionary] = []

## Gap between the main road's wall and the lane's wall before the island counts as one.
const ISLAND_GAP := 0.4

var length := 0.0
var count := 0

var _pos := PackedVector3Array()
var _tan := PackedVector3Array()    # flat, normalised direction of travel
var _right := PackedVector3Array()  # flat, normalised, to the right of travel
var _curv := PackedFloat32Array()   # signed curvature in 1/m, positive = bends right

func _ready() -> void:
	_bake()

func _bake() -> void:
	var path := get_node_or_null("RacingLine") as Path3D
	if path == null or path.curve == null:
		push_error("Track needs a Path3D child named RacingLine.")
		return
	var curve := path.curve
	var baked_len := curve.get_baked_length()
	count = maxi(8, int(round(baked_len / sample_step)))
	length = baked_len
	var step := length / count
	_pos.resize(count)
	_tan.resize(count)
	_right.resize(count)
	_curv.resize(count)
	for i in count:
		_pos[i] = path.to_global(curve.sample_baked(i * step, true))
	for i in count:
		var d := _pos[(i + 1) % count] - _pos[(i - 1 + count) % count]
		d.y = 0.0
		_tan[i] = d.normalized()
		_right[i] = _tan[i].cross(Vector3.UP).normalized()
	for i in count:
		var a := _tan[(i - 2 + count) % count]
		var b := _tan[(i + 2) % count]
		# Positive when the direction rotates to the right.
		var turn := a.signed_angle_to(b, Vector3.DOWN)
		_curv[i] = turn / (4.0 * step)

# --- Lookups by sample index ---------------------------------------------------------------

func wrap_index(i: int) -> int:
	return posmod(i, count)

func index_at(s: float) -> int:
	return posmod(int(round(s / length * count)), count)

func s_at(index: int) -> float:
	return float(index) * length / count

func pos_at(s: float) -> Vector3:
	var f := fposmod(s, length) / length * count
	var i := int(f)
	return _pos[i % count].lerp(_pos[(i + 1) % count], f - i)

func tangent_at(s: float) -> Vector3:
	return _tan[index_at(s)]

func right_at(s: float) -> Vector3:
	return _right[index_at(s)]

func curvature_at(s: float) -> float:
	return _curv[index_at(s)]

## Largest absolute curvature between s and s + ahead.
func max_curvature(s: float, ahead: float) -> float:
	var start := index_at(s)
	var n := int(ahead / length * count)
	var m := 0.0
	for k in n:
		m = maxf(m, absf(_curv[(start + k) % count]))
	return m

## A kart transform on the line: +Z looks along the direction of travel.
func transform_at(s: float, lateral := 0.0, height := 0.0) -> Transform3D:
	var i := index_at(s)
	var z := _tan[i]
	var x := Vector3.UP.cross(z).normalized()
	var origin := pos_at(s) + _right[i] * lateral + Vector3.UP * height
	return Transform3D(Basis(x, Vector3.UP, z), origin)

## Start grid slot: slot 0 is closest to the line, two karts per row.
func grid_transform(slot: int) -> Transform3D:
	var row := slot >> 1
	var side := -1.0 if slot % 2 == 0 else 1.0
	var s := length - 5.0 - row * 4.0 - (1.2 if slot % 2 == 1 else 0.0)
	return transform_at(s, side * half_width * 0.45)

# --- Forks ---------------------------------------------------------------------------------

## How far the centre of a fork's lane is from the racing line at s (0 outside the fork).
static func fork_offset(fork: Dictionary, s: float) -> float:
	var s0: float = fork["from"]
	var s1: float = fork["to"]
	if s <= s0 or s >= s1:
		return 0.0
	var ease_len: float = fork["ease"]
	return float(fork["offset"]) * smoothstep(0.0, ease_len, s - s0) * smoothstep(0.0, ease_len, s1 - s)

## The drivable band (x = left edge, y = right edge, as lateral offsets from the line) of the
## lane a kart at `lateral` is in. Normally the road; inside a fork either the road, the side
## lane, or both together where they are not yet split by the island.
func corridor(s: float, lateral: float) -> Vector2:
	var road := Vector2(-half_width, half_width)
	for fork in forks:
		var c := fork_offset(fork, fposmod(s, length))
		if c <= 0.0:
			continue
		var side: float = fork["side"]
		var w: float = fork["lane"]
		var inner := c - w
		var outer := maxf(half_width, c + w)
		var band := Vector2(-half_width, outer)  # in fork-side coordinates: + = toward the lane
		if inner > half_width + ISLAND_GAP:
			band = Vector2(inner, c + w) if lateral * side > (half_width + inner) * 0.5 else road
		return band if side > 0.0 else Vector2(-band.y, -band.x)
	return road

# --- Projection ----------------------------------------------------------------------------

## Index of the closest sample to pos. With hint >= 0 only a window around the hint is searched,
## so a kart can never "jump" to another part of the track that happens to be close.
func closest_index(pos: Vector3, hint := -1, back := 12, ahead := 40) -> int:
	var best := 0
	var best_d := INF
	if hint < 0:
		for i in count:
			var d := _flat_dist2(pos, _pos[i])
			if d < best_d:
				best_d = d
				best = i
		return best
	for k in range(-back, ahead + 1):
		var i := posmod(hint + k, count)
		var d := _flat_dist2(pos, _pos[i])
		if d < best_d:
			best_d = d
			best = i
	return best

## Signed distance from the line at sample index: positive = right of the line.
func lateral_at(pos: Vector3, index: int) -> float:
	return (pos - _pos[index]).dot(_right[index])

func sample_pos(index: int) -> Vector3:
	return _pos[posmod(index, count)]

func sample_tangent(index: int) -> Vector3:
	return _tan[posmod(index, count)]

func sample_right(index: int) -> Vector3:
	return _right[posmod(index, count)]

static func _flat_dist2(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz
