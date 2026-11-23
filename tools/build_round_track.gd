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
## Hills: [metres where the hill starts, where it ends, height in metres] (smooth, at most ~8 %).
## Jump: metres after the start line where the ramp's lip is (a striped ramp, then a long
## downhill landing that catches every kart at every speed). Corners bank by themselves.
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
		"hills": [[112.0, 182.0, 2.2]],
		"jump": 24.0,
		"grass": true, "water": [[Vector2(13, -16), 7.0]],  # tools/track_nature.gd
		"moment": {"kind": "train", "at": 68.0, "left": 18.0, "right": 20.0, "clearance": 5.0},
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
		"hills": [[150.0, 230.0, 2.6], [330.0, 400.0, 1.8]],
		"jump": 46.0,
		"grass": true, "water": [[Vector2(-3, -93), 13.0]],  # tools/track_nature.gd
		"moment": {"kind": "tunnel", "from": 404.0, "to": 440.0},
	},
	{
		# Indoors: a toy road through the living room, his toys as giants. Three zones (wooden
		# floor by the red sofa, the round rug under the coffee table, the play corner), a jump
		# over a fallen sofa cushion, and a side lane round an island of giant bricks.
		"id": "wohnzimmer", "name": "Wohnzimmer", "sort": 15, "laps": 3, "look": Atmosphere.Look.LIVING_ROOM,
		"world": "living_room",
		"points": [
			Vector2(0, 0), Vector2(24, 0), Vector2(44, -3), Vector2(58, -14), Vector2(62, -30),
			Vector2(56, -45), Vector2(42, -52), Vector2(28, -50), Vector2(14, -56), Vector2(0, -64),
			Vector2(-18, -66), Vector2(-38, -64), Vector2(-56, -56), Vector2(-68, -42), Vector2(-72, -26),
			Vector2(-66, -12), Vector2(-52, -3), Vector2(-28, 1),
		],
		"stars": [[56.0, [-1.8, 0.0, 1.8]], [140.0, [-1.4]], [180.0, [-1.8, 0.0, 1.8]], [268.0, [-10.0]],
			[300.0, [1.6]]],
		"pads": [[14.0, [-1.4, 1.4]], [128.0, [0.0]], [246.0, [-10.0]], [312.0, [-1.2]]],
		"hills": [[66.0, 108.0, 2.0]],
		"jump": 36.0, "jump_height": 1.7, "jump_style": "cushion",
		"zones": [[0.0, "holz"], [116.0, "teppich"], [196.0, "spielecke"], [300.0, "holz"]],
		"arch": 192.0,
		"fork": {"from": 204.0, "to": 292.0, "side": -1.0, "offset": 10.0, "lane": 2.6, "ease": 22.0},
		"moment": {"kind": "pillows", "at": 36.0, "teddy": [8.0, 10.0]},
	},
]

## Looks of the road per zone ("zones": [[metres from the start, style], ...]; default "rennbahn").
const STYLES := {
	"rennbahn": {"road": Color("4a4c5a"), "line": Color("e9ecf5"), "kerb_a": Color("e3241b"), "kerb_b": Color("f3f4f8"),
		"barrier": Color("2f7fe8"), "skirt": Color("3fb44a")},
	# Living room: a blue toy road on the wooden floor ...
	"holz": {"road": Color("2a6ae0"), "line": Color("f3f4f8"), "kerb_a": Color("ffc81e"), "kerb_b": Color("f3f4f8"),
		"barrier": Color("e3241b"), "skirt": Color("c9874a")},
	# ... a printed play-rug road ...
	"teppich": {"road": Color("4a4c5a"), "line": Color("f3f4f8"), "kerb_a": Color("e3241b"), "kerb_b": Color("f3f4f8"),
		"barrier": Color("2f7fe8"), "skirt": Color("e8483f")},
	# ... and an orange toy track in the play corner.
	"spielecke": {"road": Color("ff7412"), "line": Color("fff3c4"), "kerb_a": Color("8e44d8"), "kerb_b": Color("f3f4f8"),
		"barrier": Color("2fb84a"), "skirt": Color("3b8beb")},
}
const C_CUSHION := Color("e0245e")
const C_PIPING := Color("ffd2e2")
const C_ISLAND := Color("2fb84a")

const HALF_WIDTH := 3.6      # centre line to the wall face (what the karts can use)
const ASPHALT := 3.0         # centre line to where the kerb starts
const ROAD_Y := -0.15        # kart models sit 0.15 m below the physics floor (Kenney kit)
const STEP := 0.75           # one slice of road every 0.75 m
const TREE_CLEARANCE := 10.5 # trees keep this far from the centre line, so cameras see past them
const BANK_PER_CURVATURE := 2.6  # bank angle (rad) per 1/m of smoothed curvature: tight corners bank ~8°
const MAX_BANK := 0.16           # radians (~9°)
const BANK_SMOOTH := 10          # slices averaged on each side, so banking eases in and out
const JUMP_RISE := 12.0          # metres of ramp up to the lip
const JUMP_HEIGHT := 1.3         # metres
const JUMP_FALL := 18.0          # metres of downhill landing after the lip
const SKIRT_SLOPE := 1.5         # embankment: metres outward per metre of height
const CHEVRON_CURVATURE := 1.0 / 24.0  # corners tighter than this get arrow boards

const C_ASPHALT := Color("4a4c5a")
const C_LINE := Color("e9ecf5")
const C_KERB_RED := Color("e3241b")
const C_KERB_WHITE := Color("f3f4f8")
const C_BARRIER := Color("2f7fe8")
const C_GRASS := Color("3fb44a")
const C_BLACK := Color("2a2b33")
const C_RAMP := Color("ffc81e")

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
var _h := PackedFloat32Array()     # height of the centre line per slice (physics floor)
var _bank := PackedFloat32Array()  # tan(bank angle) per slice: + = left side higher
var _curv := PackedFloat32Array()  # smoothed signed curvature per slice, + = bends right
var _ramp_from := -1               # slices of the jump ramp (striped)
var _ramp_to := -1
var _land_to := -1                 # last slice of the landing slope
var _jump_style := "stripes"       # or "cushion": the whole jump is a sofa cushion
var _style_of := PackedInt32Array()  # zone style per slice, index into _styles
var _styles: Array[Dictionary] = []
var _fork := {}                    # the side lane, if the track has one (see Track.forks)
var _fork_side := 0.0
var _lane_w := 0.0
var _fork_c := PackedFloat32Array()  # lane centre offset from the line per slice (0 = no lane)
var _barrier_normals: Array[Vector2] = []

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

	_zones(cfg, length)
	_setup_fork(cfg, length)
	_profile(cfg, length)

	var root := Track.new()
	root.name = "Track"
	root.half_width = HALF_WIDTH
	if not _fork.is_empty():
		root.forks = [_fork]

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
	if cfg.get("world", "") == "living_room":
		LivingRoom.build(root, ROAD_Y - 0.03, _is_clear)
		_add_world_marks(root, cfg, length)
	else:
		_add_grass(root, center, size)
		TrackNature.add(root, self, cfg)
		_add_trees(root, lo, hi)
		_add_life(root, center, size)
	_add_gate(root)
	_add_moment(root, cfg)

	# The racing line follows the hills: one point every 3 m on the floor's centre line.
	var line := Curve3D.new()
	line.bake_interval = 0.2
	# Smooth handles (like the original line), so curvature has no spikes at the points.
	var picks: Array[int] = []
	for i in range(0, _count, 4):
		picks.append(i)
	var m := picks.size()
	for j in m + 1:
		var p := _pos[picks[j % m]]
		var handle := (_pos[picks[(j + 1) % m]] - _pos[picks[(j - 1 + m) % m]]) / 6.0
		line.add_point(p, -handle, handle)
	curve = line
	_add_floor(root)

	var path := Path3D.new()
	path.name = "RacingLine"
	path.curve = curve
	root.add_child(path)
	path.owner = root
	var star_count := TrackBuildCommon.add_stars(root, curve, cfg["stars"])
	var pad_count := TrackBuildCommon.add_pads(root, curve, cfg["pads"], ROAD_Y, _bank_at_s)

	var err := TrackBuildCommon.save_scene(root, _id)
	if err == OK:
		err = TrackBuildCommon.write_track_def(_id, cfg["name"], cfg["sort"], curve, cfg["laps"])
	print("track written: res://scenes/tracks/%s.tscn  stars=%d  pads=%d  err=%d" % [_id, star_count, pad_count, err])
	root.free()
	return err

# --- Height, banking ------------------------------------------------------------------------

## Fills the heights (hills, jump) and banking of every slice and lifts the centre line.
func _profile(cfg: Dictionary, length: float) -> void:
	_h.resize(_count)
	_bank.resize(_count)
	_curv.resize(_count)
	var raw := PackedFloat32Array()
	raw.resize(_count)
	for i in _count:
		var d0 := _pos[i] - _pos[(i - 3 + _count) % _count]
		var d1 := _pos[(i + 3) % _count] - _pos[i]
		d0.y = 0.0
		d1.y = 0.0
		raw[i] = d0.normalized().signed_angle_to(d1.normalized(), Vector3.DOWN) / (3.0 * STEP)
	for i in _count:
		var sum := 0.0
		for k in range(-BANK_SMOOTH, BANK_SMOOTH + 1):
			sum += raw[(i + k + _count) % _count]
		_curv[i] = sum / (2 * BANK_SMOOTH + 1)
	var lip: float = cfg.get("jump", -1000.0)
	var jump_h: float = cfg.get("jump_height", JUMP_HEIGHT)
	var jump_fall := JUMP_FALL * maxf(1.0, jump_h / JUMP_HEIGHT)  # a higher jump lands on a longer slope
	_jump_style = cfg.get("jump_style", "stripes")
	_ramp_from = -1
	_ramp_to = -1
	_land_to = -1
	for i in _count:
		var s := length * i / _count
		var h := 0.0
		for hill: Array in cfg.get("hills", []):
			var s0: float = hill[0]
			var s1: float = hill[1]
			if s >= s0 and s <= s1:
				h += float(hill[2]) * 0.5 * (1.0 - cos(TAU * (s - s0) / (s1 - s0)))
		if s >= lip - JUMP_RISE and s <= lip:
			var u := (s - (lip - JUMP_RISE)) / JUMP_RISE
			h += jump_h * u * u
			if _ramp_from < 0:
				_ramp_from = i
			_ramp_to = i
		elif s > lip and s <= lip + jump_fall:
			var u := (s - lip) / jump_fall
			h += jump_h * (1.0 - u) * (1.0 - u)
			_land_to = i
		if h > 0.0 and _fork_c.size() > 0 and _fork_c[i] > 0.0:
			push_error("A hill or jump runs into the side lane (keep the fork on flat road).")
		# No banking on the start straight (grid, gate), on the jump and around a fork.
		var calm := s < 12.0 or s > length - 32.0 or (s > lip - JUMP_RISE - 8.0 and s < lip + jump_fall + 4.0)
		if not _fork.is_empty() and s > float(_fork["from"]) - 12.0 and s < float(_fork["to"]) + 12.0:
			calm = true
		var angle := 0.0 if calm else clampf(_curv[i] * BANK_PER_CURVATURE, -MAX_BANK, MAX_BANK)
		_bank[i] = tan(angle)
		_h[i] = h
	# Ease the bank in and out once more, then lift the road so its low edge never dips
	# under the flat ground.
	var eased := PackedFloat32Array()
	eased.resize(_count)
	for i in _count:
		var sum := 0.0
		for k in range(-BANK_SMOOTH, BANK_SMOOTH + 1):
			sum += _bank[(i + k + _count) % _count]
		eased[i] = sum / (2 * BANK_SMOOTH + 1)
	_bank = eased
	var top := 0.0
	for i in _count:
		_h[i] += (HALF_WIDTH + 0.6) * absf(_bank[i])
		_pos[i].y = _h[i]
		top = maxf(top, _h[i])
	print("%s profile: highest point %.1f m, steepest bank %.1f°" % [_id, top, rad_to_deg(atan(_max_abs(_bank)))])

static func _max_abs(values: PackedFloat32Array) -> float:
	var m := 0.0
	for v in values:
		m = maxf(m, absf(v))
	return m

# --- Zones and the side lane ---------------------------------------------------------------

## Which road style every slice gets ("zones" in the track's config).
func _zones(cfg: Dictionary, length: float) -> void:
	var zones: Array = cfg.get("zones", [[0.0, "rennbahn"]])
	_styles.clear()
	var index_of := {}
	for zone: Array in zones:
		if not index_of.has(zone[1]):
			index_of[zone[1]] = _styles.size()
			_styles.append(STYLES[zone[1]])
	_style_of.resize(_count)
	for i in _count:
		var s := length * i / _count
		var pick := 0
		for zone: Array in zones:
			if s >= float(zone[0]):
				pick = index_of[zone[1]]
		_style_of[i] = pick

func _st(i: int) -> Dictionary:
	return _styles[_style_of[posmod(i, _count)]]

func _setup_fork(cfg: Dictionary, length: float) -> void:
	_fork = {}
	_fork_c = PackedFloat32Array()
	if not cfg.has("fork"):
		return
	var f: Dictionary = cfg["fork"]
	_fork = {"from": float(f["from"]), "to": float(f["to"]), "side": float(f["side"]),
		"offset": float(f["offset"]), "lane": float(f["lane"]), "ease": float(f["ease"])}
	_fork_side = _fork["side"]
	_lane_w = _fork["lane"]
	_fork_c.resize(_count)
	var tightest := INF
	for i in _count:
		_fork_c[i] = Track.fork_offset(_fork, length * i / _count)
	# The lane is on the inside or outside of the corners it runs along: check its radius.
	for i in _count:
		if _fork_c[i] <= 0.0:
			continue
		var a := _lane_point(i - 3)
		var b := _lane_point(i)
		var c := _lane_point(i + 3)
		var turn := absf((b - a).signed_angle_to(c - b, Vector3.UP))
		if turn > 0.0001:
			tightest = minf(tightest, (b - a).length() / turn * 2.0)
	print("%s side lane: %.0f-%.0f m, %.1f m out, tightest radius %.1f m" % [_id, _fork["from"], _fork["to"], _fork["offset"], tightest])
	if tightest < _lane_w + 1.5:
		push_error("The side lane bends tighter than it is wide.")

func _lane_c(i: int) -> float:
	return _fork_c[posmod(i, _count)] if not _fork_c.is_empty() else 0.0

## The side lane's outer wall (fork side, metres from the line; HALF_WIDTH where there is none).
func _lane_outer(i: int) -> float:
	return maxf(HALF_WIDTH, _lane_c(i) + _lane_w)

func _has_island(i: int) -> bool:
	return _lane_c(i) - _lane_w > HALF_WIDTH + Track.ISLAND_GAP

func _fork_open(i: int) -> bool:
	return _lane_c(i) + _lane_w > HALF_WIDTH + 0.001

func _lane_point(i: int) -> Vector3:
	var k := posmod(i, _count)
	return _pos[k] + _right[k] * (_fork_side * _lane_c(k))

## True if a thing of radius r at p stays clear of the road, the side lane and the barriers.
func _is_clear(p: Vector3, r: float) -> bool:
	if _distance_to_line(p) < HALF_WIDTH + 1.2 + r:
		return false
	for i in range(0, _count, 2):
		if _lane_c(i) > 0.0:
			var q := _lane_point(i)
			if Vector2(p.x - q.x, p.z - q.z).length() < _lane_w + 1.2 + r:
				return false
	return true

## Living-room landmarks that hang on the road: a brick arch where the play corner starts and
## brick towers on the side lane's island.
func _add_world_marks(root: Node3D, cfg: Dictionary, length: float) -> void:
	if cfg.has("arch"):
		var i := posmod(int(round(float(cfg["arch"]) / length * _count)), _count)
		LivingRoom.brick_arch(root, _pos[i] + Vector3(0, ROAD_Y - 0.03, 0), _right[i], HALF_WIDTH + 1.6)
	if _fork.is_empty():
		return
	var first := -1
	var last := -1
	for i in _count:
		if _has_island(i) and _lane_c(i) - _lane_w - HALF_WIDTH > 2.9:
			if first < 0:
				first = i
			last = i
	if first < 0:
		return
	var towers := 3
	for t in towers:
		var i := first + int((last - first) * (t + 0.5) / towers)
		var mid := _fork_side * (HALF_WIDTH + _lane_c(i) - _lane_w) * 0.5
		var tangent := (_pos[(i + 1) % _count] - _pos[(i - 1 + _count) % _count])
		tangent.y = 0.0
		LivingRoom.brick_tower(root, _pos[i] + _right[i] * mid + Vector3(0, ROAD_Y + 0.27, 0), tangent.normalized(), 3 + t % 2 * 2, t)

## Outdoors: a stand of cheering fans just before the start line (on whichever side has
## room) and the Duplo plane circling the track high up.
func _add_life(root: Node3D, center: Vector3, size: Vector3) -> void:
	var i := posmod(_count - int(14.0 / STEP), _count)
	for side: float in [1.0, -1.0]:
		var spot := _pos[i] + _right[i] * side * (HALF_WIDTH + 4.6)
		spot.y = ROAD_Y - 0.03
		if not _is_clear(spot, 1.6):
			continue
		var tangent := _pos[(i + 1) % _count] - _pos[i]
		# The stand's long side runs along the road; its fans face the road.
		var yaw := atan2(-side * tangent.z, side * tangent.x)
		LivingRoom.outdoor_life(root, spot, yaw, Vector3(center.x, 0, center.z), maxf(size.x, size.z) * 0.4)
		return
	push_warning("No room for the fans at the start of %s." % _id)

## Bank (as tan) at a distance along the line, for placing turbo arrows flat on the road.
func _bank_at_s(s: float) -> float:
	var length := _count * STEP
	return _bank[posmod(int(round(s / length * _count)), _count)]

# --- Geometry helpers ----------------------------------------------------------------------

## A point of road slice i: `d` metres to the right of the centre line, `h` metres above the road.
## Follows the slice's height and bank.
func _at(i: int, d: float, h: float) -> Vector3:
	var k := posmod(i, _count)
	return _pos[k] + _right[k] * d + Vector3(0, ROAD_Y + h - d * _bank[k], 0)

## A surface normal of slice i from a cross-section normal (sideways part, upward part).
func _normal(i: int, sideways: float, up: float) -> Vector3:
	var k := posmod(i, _count)
	return (_right[k] * (sideways + up * _bank[k]) + Vector3.UP * up).normalized()

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
	_ribbon_v(st, func(_i: int) -> float: return d0, h0, n0, func(_i: int) -> float: return d1, h1, n1, color_at)

## The same with sideways offsets that change along the track: `d0`/`d1` give the offset at slice i.
func _ribbon_v(st: SurfaceTool, d0: Callable, h0: float, n0: Vector2, d1: Callable, h1: float, n1: Vector2, color_at: Callable) -> void:
	for i in _count:
		var color: Color = color_at.call(i)
		if color.a < 0.5:
			continue
		var a0: float = d0.call(i)
		var a1: float = d1.call(i)
		var b0: float = d0.call(i + 1)
		var b1: float = d1.call(i + 1)
		var v: Array[Vector3] = [_at(i, a0, h0), _at(i, a1, h1), _at(i + 1, b1, h1), _at(i + 1, b0, h0)]
		var normals: Array[Vector3] = [_normal(i, n0.x, n0.y), _normal(i, n1.x, n1.y), _normal(i + 1, n1.x, n1.y), _normal(i + 1, n0.x, n0.y)]
		_quad(st, v, normals, color)

## A rounded barrier on one side: its wall face is `base` metres (at slice i) from the line.
func _barrier(st: SurfaceTool, side: float, base: Callable, color_at: Callable) -> void:
	for k in BARRIER.size() - 1:
		var p0 := BARRIER[k]
		var p1 := BARRIER[k + 1]
		_ribbon_v(st, func(i: int) -> float: return side * (float(base.call(i)) + p0.x), p0.y,
			Vector2(side * _barrier_normals[k].x, _barrier_normals[k].y),
			func(i: int) -> float: return side * (float(base.call(i)) + p1.x), p1.y,
			Vector2(side * _barrier_normals[k + 1].x, _barrier_normals[k + 1].y), color_at)

# --- Road, kerbs, barriers -----------------------------------------------------------------

func _on_cushion(i: int) -> bool:
	return _jump_style == "cushion" and _ramp_from >= 0 and i >= _ramp_from and i <= _land_to

func _road_color(i: int) -> Color:
	if _on_cushion(i):
		return C_CUSHION if (i >> 2) % 3 != 0 else C_CUSHION.darkened(0.14)  # quilted
	if _jump_style != "cushion" and _ramp_from >= 0 and i >= _ramp_from and i <= _ramp_to:
		return C_RAMP if (i >> 1) % 2 == 0 else C_BLACK
	return _st(i)["road"]

func _kerb_color(i: int) -> Color:
	if _on_cushion(i):
		return C_PIPING if (i >> 1) % 2 == 0 else C_CUSHION.lightened(0.25)
	return _st(i)["kerb_a"] if (i >> 1) % 2 == 0 else _st(i)["kerb_b"]

func _barrier_color(i: int) -> Color:
	return C_PIPING if _on_cushion(i) else _st(i)["barrier"]

func _add_road(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector2(0, 1)
	_ribbon(st, -ASPHALT, 0.0, up, ASPHALT, 0.0, up, _road_color)
	# Edge lines and a dashed centre line.
	for side: float in [-1.0, 1.0]:
		_ribbon(st, side * (ASPHALT - 0.3), 0.012, up, side * (ASPHALT - 0.14), 0.012, up,
			func(i: int) -> Color: return C_PIPING if _on_cushion(i) else _st(i)["line"])
	_ribbon(st, -0.07, 0.012, up, 0.07, 0.012, up,
		func(i: int) -> Color: return _st(i)["line"] if (i >> 2) % 2 == 0 and not _on_cushion(i) else Color.TRANSPARENT)
	# Kerbs, slightly raised toward the barrier.
	for side: float in [-1.0, 1.0]:
		_ribbon(st, side * ASPHALT, 0.01, up, side * HALF_WIDTH, 0.05, up, _kerb_color)
	# Chequered start line: two rows of squares across the asphalt.
	var squares := int(round(2.0 * ASPHALT / STEP))
	for row in 2:
		for col in squares:
			var d0 := -ASPHALT + col * STEP
			var color := C_KERB_WHITE if (row + col) % 2 == 0 else C_BLACK
			var v: Array[Vector3] = [_at(row - 1, d0, 0.016), _at(row - 1, d0 + STEP, 0.016), _at(row, d0 + STEP, 0.016), _at(row, d0, 0.016)]
			var normals: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
			_quad(st, v, normals, color)
	# Rounded barriers on both sides; on a fork's side the barrier runs along the lane's outside.
	var seg_normals: Array[Vector2] = []
	for k in BARRIER.size() - 1:
		var d := BARRIER[k + 1] - BARRIER[k]
		seg_normals.append(Vector2(-d.y, d.x).normalized())
	_barrier_normals.clear()
	for k in BARRIER.size():
		var a := seg_normals[maxi(k - 1, 0)]
		var b := seg_normals[mini(k, seg_normals.size() - 1)]
		_barrier_normals.append((a + b).normalized())
	for side: float in [-1.0, 1.0]:
		if not _fork.is_empty() and side == _fork_side:
			_barrier(st, side, _lane_outer, _barrier_color)
		else:
			_barrier(st, side, func(_i: int) -> float: return HALF_WIDTH, _barrier_color)
	if not _fork.is_empty():
		_add_lane(st)
	_add_skirts(st)
	_add_chevrons(st)
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

## The side lane's road, its kerbs and the island with its two barriers.
func _add_lane(st: SurfaceTool) -> void:
	var sd := _fork_side
	var up := Vector2(0, 1)
	var kerb := HALF_WIDTH - ASPHALT
	var inner := func(i: int) -> float: return sd * (_lane_c(i) - _lane_w + kerb if _has_island(i) else HALF_WIDTH)
	var outer := func(i: int) -> float: return sd * (_lane_c(i) + _lane_w - kerb)
	var open := func(i: int) -> bool: return _lane_c(i) + _lane_w - kerb > HALF_WIDTH + 0.05 and _lane_c(i + 1) + _lane_w - kerb > HALF_WIDTH + 0.05
	_ribbon_v(st, inner, 0.0, up, outer, 0.0, up,
		func(i: int) -> Color: return _road_color(i) if open.call(i) else Color.TRANSPARENT)
	# A dashed middle line, so the lane reads as a road of its own.
	_ribbon_v(st, func(i: int) -> float: return sd * _lane_c(i) - 0.07, 0.012, up,
		func(i: int) -> float: return sd * _lane_c(i) + 0.07, 0.012, up,
		func(i: int) -> Color: return _st(i)["line"] if _has_island(i) and (i >> 2) % 2 == 0 else Color.TRANSPARENT)
	# Kerb on the outside of the lane, and on the island side.
	_ribbon_v(st, outer, 0.01, up, func(i: int) -> float: return sd * (_lane_c(i) + _lane_w), 0.05, up,
		func(i: int) -> Color: return _kerb_color(i) if open.call(i) else Color.TRANSPARENT)
	var island := func(i: int) -> bool: return _has_island(i) and _has_island(i + 1)
	_ribbon_v(st, func(i: int) -> float: return sd * (_lane_c(i) - _lane_w), 0.05, up, inner, 0.01, up,
		func(i: int) -> Color: return _kerb_color(i) if island.call(i) else Color.TRANSPARENT)
	# The island: a barrier facing the road, one facing the lane, a raised lawn between them.
	var island_color := func(i: int) -> Color: return _barrier_color(i) if island.call(i) else Color.TRANSPARENT
	_barrier(st, sd, func(_i: int) -> float: return HALF_WIDTH, island_color)
	_barrier(st, -sd, func(i: int) -> float: return -(_lane_c(i) - _lane_w), island_color)
	var back := BARRIER[BARRIER.size() - 2].x
	_ribbon_v(st, func(_i: int) -> float: return sd * (HALF_WIDTH + back), 0.3, up,
		func(i: int) -> float: return sd * maxf(HALF_WIDTH + back, _lane_c(i) - _lane_w - back), 0.3, up,
		func(i: int) -> Color: return C_ISLAND if island.call(i) else Color.TRANSPARENT)

## Grass embankments from the barriers down to the lawn wherever the road is raised.
func _add_skirts(st: SurfaceTool) -> void:
	var edge := HALF_WIDTH + BARRIER[BARRIER.size() - 1].x
	for side: float in [-1.0, 1.0]:
		for i in _count:
			var a := _at(i, side * edge, -0.1)
			var b := _at(i + 1, side * edge, -0.1)
			var rise_a := a.y - (ROAD_Y - 0.03)
			var rise_b := b.y - (ROAD_Y - 0.03)
			if rise_a < 0.05 and rise_b < 0.05:
				continue
			var ka := posmod(i, _count)
			var kb := posmod(i + 1, _count)
			var a_low := Vector3(_pos[ka].x, ROAD_Y - 0.03, _pos[ka].z) + _right[ka] * side * (edge + maxf(rise_a, 0.0) * SKIRT_SLOPE)
			var b_low := Vector3(_pos[kb].x, ROAD_Y - 0.03, _pos[kb].z) + _right[kb] * side * (edge + maxf(rise_b, 0.0) * SKIRT_SLOPE)
			var n := (_right[ka] * side + Vector3.UP * SKIRT_SLOPE).normalized()
			var v: Array[Vector3] = [a, a_low, b_low, b]
			var normals: Array[Vector3] = [n, n, n, n]
			_quad(st, v, normals, C_CUSHION if _on_cushion(i) else _st(i)["skirt"])

## Red boards with white arrows on the outside of tight corners, pointing the way.
func _add_chevrons(st: SurfaceTool) -> void:
	var last := -100
	var boards := 0
	for i in _count:
		if absf(_curv[i]) < CHEVRON_CURVATURE or i - last < 8:
			continue
		if _fork_open(i) and -signf(_curv[i]) == _fork_side:
			continue
		last = i
		boards += 1
		var out := -signf(_curv[i])  # right bend: the outside is the left side
		var center := _at(i, out * (HALF_WIDTH + 1.1), 1.05)
		var tangent := (_pos[(i + 1) % _count] - _pos[(i - 1 + _count) % _count])
		tangent.y = 0.0
		tangent = tangent.normalized()
		var inward := -_right[i] * out
		var n := (-tangent * 0.8 + inward * 0.6).normalized()  # faces karts coming into the corner
		var across := Vector3.UP.cross(n).normalized()
		if across.dot(inward) < 0.0:
			across = -across  # arrows point toward the inside of the corner
		var normals: Array[Vector3] = [n, n, n, n]
		var corner := func(u: float, v: float, lift: float) -> Vector3:
			return center + across * u + Vector3.UP * v + n * lift
		_quad(st, [corner.call(-0.75, -0.45, 0.0), corner.call(0.75, -0.45, 0.0), corner.call(0.75, 0.45, 0.0), corner.call(-0.75, 0.45, 0.0)], normals, C_KERB_RED)
		for u0: float in [-0.5, -0.05]:
			_quad(st, [corner.call(u0, -0.35, 0.02), corner.call(u0 + 0.16, -0.35, 0.02), corner.call(u0 + 0.46, 0.0, 0.02), corner.call(u0 + 0.3, 0.0, 0.02)], normals, C_KERB_WHITE)
			_quad(st, [corner.call(u0 + 0.3, 0.0, 0.02), corner.call(u0 + 0.46, 0.0, 0.02), corner.call(u0 + 0.16, 0.35, 0.02), corner.call(u0, 0.35, 0.02)], normals, C_KERB_WHITE)
		# Post down to the ground.
		var foot := Vector3(center.x, ROAD_Y - 0.03, center.z)
		_quad(st, [foot - across * 0.06, foot + across * 0.06, center + across * 0.06 - Vector3.UP * 0.45, center - across * 0.06 - Vector3.UP * 0.45], normals, C_BLACK)
	print("arrow boards: %d" % boards)

## The floor the karts drive on along the road: follows hills, jump and banking. The flat
## ground collider stays under everything else.
func _add_floor(root: Node3D) -> void:
	var faces := PackedVector3Array()
	var w := HALF_WIDTH + 0.6
	for i in _count:
		var a := _at(i, -w, -ROAD_Y)
		var b := _at(i, w, -ROAD_Y)
		var c := _at(i + 1, w, -ROAD_Y)
		var d := _at(i + 1, -w, -ROAD_Y)
		# Wound so the top is the front face: the kart's ground ray ignores back faces.
		faces.append_array([a, c, b, a, d, c])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "RoadFloor"
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	body.owner = root
	collision.owner = root

func _wall_quad(faces: PackedVector3Array, i: int, da: float, db: float) -> void:
	var a_low := _at(i, da, -0.4)
	var a_high := _at(i, da, 3.2)
	var b_low := _at(i + 1, db, -0.4)
	var b_high := _at(i + 1, db, 3.2)
	faces.append_array([a_low, a_high, b_high, a_low, b_high, b_low])

## Invisible walls the karts bounce off, at the wall face on both sides.
func _add_walls(root: Node3D) -> void:
	var faces := PackedVector3Array()
	for side: float in [-1.0, 1.0]:
		var on_fork := not _fork.is_empty() and side == _fork_side
		for i in _count:
			var da := _lane_outer(i) if on_fork else HALF_WIDTH
			var db := _lane_outer(i + 1) if on_fork else HALF_WIDTH
			_wall_quad(faces, i, side * da, side * db)
	if not _fork.is_empty():
		# The island: walls on both its sides and across its two ends.
		var sd := _fork_side
		for i in _count:
			if _has_island(i) and _has_island(i + 1):
				_wall_quad(faces, i, sd * HALF_WIDTH, sd * HALF_WIDTH)
				_wall_quad(faces, i, sd * (_lane_c(i) - _lane_w), sd * (_lane_c(i + 1) - _lane_w))
			if _has_island(i) != _has_island(i + 1):
				var k := i + 1 if _has_island(i + 1) else i
				var a := _at(k, sd * HALF_WIDTH, -0.4)
				var b := _at(k, sd * HALF_WIDTH, 3.2)
				var c := _at(k, sd * (_lane_c(k) - _lane_w), 3.2)
				var d := _at(k, sd * (_lane_c(k) - _lane_w), -0.4)
				faces.append_array([a, b, c, a, c, d])
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
	patch_material.vertex_color_is_srgb = true
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

# --- Signature moments ---------------------------------------------------------------------

## The track's one special thing (toy train bridge, caterpillar tunnel, pillow fort): see
## tools/track_moments.gd.
func _add_moment(root: Node3D, cfg: Dictionary) -> void:
	if not cfg.has("moment"):
		return
	var moment: Dictionary = (cfg["moment"] as Dictionary).duplicate()
	if _ramp_from >= 0:
		moment["from_slice"] = _ramp_from  # where the jump (the sofa cushion) starts and ends
		moment["to_slice"] = _land_to
	var with_slices := cfg.duplicate()
	with_slices["moment"] = moment
	TrackMoments.new(_pos, _right, _bank, _curv, STEP, ROAD_Y, HALF_WIDTH).build(root, with_slices)
