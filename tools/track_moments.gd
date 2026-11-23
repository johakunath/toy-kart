class_name TrackMoments extends RefCounted
## Signature moments for the round tracks (tools/build_round_track.gd): the one thing a child
## talks about after the race. Built from the road slices the round-track builder computes.
##
##   {"kind": "train", "at": s, "left": m, "right": m, "clearance": m}
##       A toy train bridge across the road at s metres: a straight rail from a mountain on the
##       left to a mountain on the right (portals `left` / `right` metres from the road centre),
##       `clearance` metres above the road. scripts/track/toy_train.gd runs the train.
##   {"kind": "tunnel", "from": s, "to": s}
##       A rainbow caterpillar the road runs through, mouth first. scripts/track/tunnel.gd adds
##       the engine echo, the twinkling lights and the eyes that watch the karts.
##   {"kind": "pillows", "at": s, "teddy": [metres after s, metres sideways]}
##       The pillow fort round the sofa-cushion jump whose lip is at s: two towers of fat
##       cushions with a flag garland high over the road, gold tassels on the cushion's
##       corners, and a giant teddy beside the landing. scripts/track/pillow_fort.gd makes the
##       teddy cheer when a kart flies and puffs feathers where karts land.
##   {"kind": "owl", "at": s}
##       A tree gate in the forest: two giant trees, a thick branch high across the road with
##       an owl on it. scripts/track/forest_friends.gd turns the owl's head after the karts and
##       sends a parade of forest animals over the branch when a player comes.
##
## Nothing here has collision: the invisible walls keep every kart on the road, so a moment can
## never stop, block or reset anyone.

const C_RED := Color("e3241b")
const C_ORANGE := Color("ff8a1e")
const C_YELLOW := Color("ffc81e")
const C_GREEN := Color("3fb44a")
const C_BLUE := Color("2f7fe8")
const C_PURPLE := Color("9b4de0")
const C_PINK := Color("ff5c8a")
const C_WHITE := Color("f4f6fb")
const C_BLACK := Color("1c1d24")
const C_WOOD := Color("e7b86a")
const C_SLEEPER := Color("8b5a2b")
const C_RAIL := Color("c9ced8")
const C_STONE := Color("a3a8b6")
const C_STONE_DARK := Color("7d8392")
const C_HILL := Color("2f9e3c")
const C_HILL_LIGHT := Color("4cc456")
const C_ROCK := Color("8f8478")
const C_BARK := Color("8b4f24")
const C_BARK_LIGHT := Color("b06a32")
const C_LEAF := Color("2fa83c")
const C_LEAF_LIGHT := Color("5fd04a")
const PILLOW_COLORS: Array[Color] = [C_YELLOW, C_BLUE, C_GREEN, C_PURPLE, C_ORANGE, C_PINK]
const RAINBOW: Array[Color] = [C_RED, C_ORANGE, C_YELLOW, C_GREEN, C_BLUE, C_PURPLE]
const BULBS: Array[Color] = [Color("ffd23a"), Color("ff5c8a"), Color("3ee0ff"), Color("7dff5a"), Color("ff8a1e")]

## Train: deck thickness and the rail's height above the deck top.
const DECK := 0.7
const RAIL_TOP := 0.15
const MOUNTAIN_BACK := 9.0   ## portal to mountain centre (metres along the rail)
const MOUNTAIN_RADIUS := 11.0
const PORTAL_DEPTH := 3.5

## Caterpillar cross-section: walls at +-WALL up to WALL_TOP, then a round roof ROOF higher.
## Wide and high, so the chase camera always stays inside (it hangs at most ~3.4 m over the kart
## and swings ~1.3 m sideways in a drift).
const WALL := 5.4
const WALL_TOP := 3.4
const ROOF := 3.6
const SKIN := 0.3
const SEGMENT := 4           ## slices per body segment (3 m)
const BULGE := 0.45
const HEAD_BULGE := 1.1

## Pillow fort: towers this far before the lip and out from the centre line; the garland's
## lowest point this high over the lip (the chase camera flies at most ~6 m over it).
const PILLOW_TOWER_BEFORE := 3.0
const PILLOW_TOWER_OUT := 9.0
const PILLOW_LAYERS := 6
const GARLAND_CLEAR := 9.5
const GARLAND_SAG := 1.0

## Owl tree gate: trunks this far from the centre line, branch this high over the road.
const OWL_TRUNK_OUT := 6.6
const OWL_BRANCH_HEIGHT := 7.2
const OWL_BRANCH_R := 0.7

var _pos: PackedVector3Array
var _right: PackedVector3Array
var _bank: PackedFloat32Array
var _curv: PackedFloat32Array
var _count := 0
var _step := 0.75
var _road_y := -0.15
var _half_width := 3.6

var _st: SurfaceTool
var _glow: Array[SurfaceTool] = []

func _init(pos: PackedVector3Array, right: PackedVector3Array, bank: PackedFloat32Array, curv: PackedFloat32Array,
		step: float, road_y: float, half_width: float) -> void:
	_pos = pos
	_right = right
	_bank = bank
	_curv = curv
	_count = pos.size()
	_step = step
	_road_y = road_y
	_half_width = half_width

func build(root: Node3D, cfg: Dictionary) -> void:
	var moment: Dictionary = cfg["moment"]
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_glow.clear()
	var node: Node3D
	match moment.get("kind", ""):
		"train":
			node = _build_train(root, moment)
		"tunnel":
			node = _build_tunnel(root, moment)
		"pillows":
			node = _build_pillows(root, moment)
		"owl":
			node = _build_owl(root, moment)
		_:
			push_error("Unknown moment: %s" % moment)
			return
	_save_mesh(root, node, cfg["id"])

# --- Toy train bridge ------------------------------------------------------------------------

func _build_train(root: Node3D, m: Dictionary) -> Node3D:
	var i := _slice(m["at"])
	var across := _right[i]
	var along := Vector3.UP.cross(across).normalized()  # the road's direction under the bridge
	var flat := Vector3(_pos[i].x, 0.0, _pos[i].z)
	var left: float = m["left"]
	var right: float = m["right"]
	# The deck clears the highest point of the road under it (banking lifts one edge).
	var road_top := -INF
	for k in range(i - 6, i + 7):
		for d: float in [-_half_width - 0.6, _half_width + 0.6]:
			road_top = maxf(road_top, _at(k, d, 0.0).y)
	var deck_bottom := road_top + float(m.get("clearance", 5.0))
	var deck_top := deck_bottom + DECK
	var ground := _road_y - 0.05
	var rail := func(u: float, y: float) -> Vector3: return flat + across * u + Vector3.UP * y

	# Deck from portal to portal (it runs on into both mountains), sleepers and rails on top.
	var u0 := -left - PORTAL_DEPTH
	var u1 := right + PORTAL_DEPTH
	var mid := (u0 + u1) * 0.5
	var half := (u1 - u0) * 0.5
	_box(rail.call(mid, deck_bottom + DECK * 0.5 - 0.03), across * half, Vector3.UP * (DECK * 0.5 - 0.03), along * 1.3, C_RED)
	_box(rail.call(mid, deck_top - 0.03), across * half, Vector3.UP * 0.03, along * 1.18, C_WOOD)
	var u := u0 + 0.35
	while u < u1:
		_box(rail.call(u, deck_top + 0.04), across * 0.13, Vector3.UP * 0.04, along * 0.95, C_SLEEPER)
		u += 0.7
	for side: float in [-0.55, 0.55]:
		_box(rail.call(mid, deck_top + 0.1) + along * side, across * half, Vector3.UP * 0.05, along * 0.06, C_RAIL)

	# Over the road: a yellow bow on each side, with hangers.
	var span := _half_width + 2.9
	for side: float in [-1.0, 1.0]:
		var off := along * side * 1.42
		var bow := func(t: float) -> Vector3:
			var x := lerpf(-span, span, t)
			return rail.call(x, deck_top + 0.12 + 3.0 * (1.0 - (x / span) * (x / span))) + off
		var steps := 14
		for k in steps:
			_beam(bow.call(float(k) / steps), bow.call(float(k + 1) / steps), along, 0.2, C_YELLOW)
		for t: float in [0.2, 0.35, 0.5, 0.65, 0.8]:
			var top: Vector3 = bow.call(t)
			var foot := Vector3(top.x, deck_top + 0.02, top.z)
			_beam(foot, top, along, 0.07, C_YELLOW)
		# A red-white stripe along the deck edge over the road, so the bridge reads from afar.
		var stripes := 10
		for k in stripes:
			var a := lerpf(-span, span, float(k) / stripes)
			var b := lerpf(-span, span, float(k + 1) / stripes)
			var color := C_WHITE if k % 2 == 0 else C_RED
			_box(rail.call((a + b) * 0.5, deck_bottom + DECK * 0.5) + along * side * 1.31,
				across * (b - a) * 0.5, Vector3.UP * (DECK * 0.5 - 0.06), along * 0.02, color)

	# Piers of stacked toy blocks: two strong ones beside the road, thinner ones out to the hills.
	var piers: Array = [[-span, 0.75], [span, 0.75]]
	var p := span + 5.0
	while p < left - 1.5:
		piers.append([-p, 0.55])
		p += 5.0
	p = span + 5.0
	while p < right - 1.5:
		piers.append([p, 0.55])
		p += 5.0
	var colors: Array[Color] = [C_YELLOW, C_BLUE, C_RED, C_GREEN]
	for n in piers.size():
		var at: float = piers[n][0]
		var w: float = piers[n][1]
		var height := deck_bottom - ground
		var blocks := maxi(2, int(round(height / 1.3)))
		var bh := height / blocks
		for b in blocks:
			var color := colors[(b + n) % colors.size()]
			var y := ground + bh * (b + 0.5)
			_box(rail.call(at, y), across * w, Vector3.UP * bh * 0.5, along * w, color)
			# Studs on top of each block, like a real toy brick.
			for sx: float in [-0.5, 0.5]:
				for sz: float in [-0.5, 0.5]:
					_box(rail.call(at + sx * w, y + bh * 0.5 + 0.06) + along * sz * w, across * 0.12, Vector3.UP * 0.06, along * 0.12, color)

	# A mountain with a tunnel portal at each end.
	var hill_top := deck_top + 8.0 - ground
	for side: float in [-1.0, 1.0]:
		var portal := -left if side < 0.0 else right
		var center: Vector3 = rail.call(portal + side * MOUNTAIN_BACK, ground)
		_mountain(center, MOUNTAIN_RADIUS, hill_top, int(side * 7.0 + 11.0))
		_portal(rail, portal, side, across, along, ground, deck_bottom, deck_top)
		_clear_trees(root, center, MOUNTAIN_RADIUS + 2.5)
	_clear_trees_along(root, rail.call(-left, 0.0), rail.call(right, 0.0), 3.5)

	var train := ToyTrain.new()
	train.name = "ToyTrain"
	train.rail_origin = rail.call(0.0, deck_top + RAIL_TOP)
	train.rail_dir = across
	train.portal_a = -left
	train.portal_b = right
	train.road_point = _pos[i]
	root.add_child(train)
	train.owner = root
	print("toy train: bridge at s=%.0f, deck %.1f m over the road, rail %.0f m" % [float(m["at"]), deck_bottom - road_top, left + right])
	return train

## The stone front of a tunnel into the mountain, with a dark hole and a ring of coloured stones.
func _portal(rail: Callable, portal: float, side: float, across: Vector3, along: Vector3, ground: float, deck_bottom: float, deck_top: float) -> void:
	var top := deck_top + 3.9
	var depth := PORTAL_DEPTH
	_box(rail.call(portal + side * depth * 0.5, (ground + top) * 0.5), across * depth * 0.5, Vector3.UP * (top - ground) * 0.5, along * 2.6, C_STONE)
	# Battlements on top.
	for k in 5:
		var z := lerpf(-2.2, 2.2, k / 4.0)
		_box(rail.call(portal + side * 0.4, top + 0.25) + along * z, across * 0.4, Vector3.UP * 0.25, along * 0.3, C_STONE_DARK)
	var face := portal - side * 0.03
	var n := -across * side
	var hole_r := 1.5
	var spring := deck_top + 1.7  # where the round top starts
	var pt := func(w: float, y: float, lift: float) -> Vector3: return rail.call(face - side * lift, y) + along * w
	# The dark hole: a rectangle and a half circle.
	_face([pt.call(-hole_r, deck_bottom - 0.05, 0.0), pt.call(hole_r, deck_bottom - 0.05, 0.0), pt.call(hole_r, spring, 0.0), pt.call(-hole_r, spring, 0.0)], n, C_BLACK)
	var arc := 10
	for k in arc:
		var a0 := PI * k / arc
		var a1 := PI * (k + 1) / arc
		_face([pt.call(0.0, spring, 0.0), pt.call(cos(a0) * hole_r, spring + sin(a0) * hole_r, 0.0), pt.call(cos(a1) * hole_r, spring + sin(a1) * hole_r, 0.0)], n, C_BLACK)
		# Ring stones around the arch, red and yellow.
		var r0 := hole_r
		var r1 := hole_r + 0.6
		var color := C_RED if k % 2 == 0 else C_YELLOW
		_face([pt.call(cos(a0) * r0, spring + sin(a0) * r0, 0.02), pt.call(cos(a0) * r1, spring + sin(a0) * r1, 0.02),
			pt.call(cos(a1) * r1, spring + sin(a1) * r1, 0.02), pt.call(cos(a1) * r0, spring + sin(a1) * r0, 0.02)], n, color)
	# Straight sides of the ring down to the deck.
	for w: float in [-1.0, 1.0]:
		var rows := 3
		for k in rows:
			var y0 := lerpf(deck_bottom - 0.05, spring, float(k) / rows)
			var y1 := lerpf(deck_bottom - 0.05, spring, float(k + 1) / rows)
			var color := C_YELLOW if (k % 2 == 0) == (w > 0.0) else C_RED
			_face([pt.call(w * hole_r, y0, 0.02), pt.call(w * (hole_r + 0.6), y0, 0.02), pt.call(w * (hole_r + 0.6), y1, 0.02), pt.call(w * hole_r, y1, 0.02)], n, color)

## A round toy mountain: green felt with darker patches, rock higher up and a snow cap.
func _mountain(center: Vector3, radius: float, height: float, seed_value: int) -> void:
	var rings := 12
	var segs := 36
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var phase := rng.randf() * TAU
	var grid: Array[PackedVector3Array] = []
	for r in rings + 1:
		var row := PackedVector3Array()
		var f := float(r) / rings  # 0 at the foot, 1 at the top
		for s in segs:
			var a := TAU * s / segs
			var wobble := 1.0 + 0.09 * sin(3.0 * a + phase) + 0.05 * sin(7.0 * a + phase * 2.0)
			var rho := radius * (1.0 - f) * wobble
			var h := height * pow(1.0 - (1.0 - f) * (1.0 - f), 0.8)
			if r > 0 and r < rings:
				h += rng.randf_range(-0.25, 0.25) * height * 0.04
			row.append(center + Vector3(cos(a) * rho, h, sin(a) * rho))
		grid.append(row)
	for r in rings:
		for s in segs:
			var a := grid[r][s]
			var b := grid[r][(s + 1) % segs]
			var c := grid[r + 1][(s + 1) % segs]
			var d := grid[r + 1][s]
			for tri: Array in [[a, b, c], [a, c, d]]:
				var v: Array[Vector3] = [tri[0], tri[1], tri[2]]
				var n := (v[1] - v[0]).cross(v[2] - v[0]).normalized()
				if n.y < 0.0:
					n = -n
				var y := (v[0].y + v[1].y + v[2].y) / 3.0 - center.y
				var f := y / height + rng.randf_range(-0.06, 0.06)
				var color := C_HILL if (r + s) % 3 != 0 else C_HILL_LIGHT
				if f > 0.8:
					color = C_WHITE
				elif f > 0.6:
					color = C_ROCK if rng.randf() < 0.7 else C_HILL
				_face(v, n, color)

# --- Caterpillar tunnel ----------------------------------------------------------------------

func _build_tunnel(root: Node3D, m: Dictionary) -> Node3D:
	var i0 := _slice(m["from"])
	var segments := maxi(3, int(round((float(m["to"]) - float(m["from"])) / (_step * SEGMENT))))
	var i1 := i0 + segments * SEGMENT

	# Body: one bulging ring per segment, head first. Outside in rainbow colours, inside darker.
	for j in range(i0, i1):
		var seg := (j - i0) / SEGMENT
		var color := C_GREEN.lightened(0.1) if seg == 0 else RAINBOW[(seg - 1) % RAINBOW.size()]
		var inner_color := color.darkened(0.3)
		var big := HEAD_BULGE if seg == 0 else BULGE
		var t0 := float(j - i0 - seg * SEGMENT) / SEGMENT
		var t1 := t0 + 1.0 / SEGMENT
		var b0 := big * sin(PI * t0)
		var b1 := big * sin(PI * t1)
		var slope0 := big * PI * cos(PI * t0) / (SEGMENT * _step)
		var slope1 := big * PI * cos(PI * t1) / (SEGMENT * _step)
		var count := _profile_count()
		for k in count - 1:
			var v: Array[Vector3] = [_ring(j, k, b0, 0.0), _ring(j, k + 1, b0, 0.0), _ring(j + 1, k + 1, b1, 0.0), _ring(j + 1, k, b1, 0.0)]
			var normals: Array[Vector3] = [_ring_normal(j, k, slope0), _ring_normal(j, k + 1, slope0), _ring_normal(j + 1, k + 1, slope1), _ring_normal(j + 1, k, slope1)]
			_poly(v, normals, color)
			var w: Array[Vector3] = [_ring(j, k, 0.0, SKIN), _ring(j, k + 1, 0.0, SKIN), _ring(j + 1, k + 1, 0.0, SKIN), _ring(j + 1, k, 0.0, SKIN)]
			var inward: Array[Vector3] = [-_ring_normal(j, k, 0.0), -_ring_normal(j, k + 1, 0.0), -_ring_normal(j + 1, k + 1, 0.0), -_ring_normal(j + 1, k, 0.0)]
			_poly(w, inward, inner_color)

	# The mouth: thick pink lips round the opening. The way out: a plain rim.
	_lip(i0, -1.0, C_PINK, 0.75)
	_lip(i1, 1.0, RAINBOW[(segments - 2) % RAINBOW.size()], 0.15)

	# Cheeks, little feet on every segment, a pom-pom tail.
	var fwd0 := _forward(i0)
	for side: float in [-1.0, 1.0]:
		_ball(_at(i0 + 1, side * (WALL + 0.9), 2.2) - fwd0 * 0.3, Vector3(0.7, 0.55, 0.35), C_PINK)
	for seg in range(1, segments):
		var j := i0 + seg * SEGMENT + SEGMENT / 2
		var color := RAINBOW[(seg - 1) % RAINBOW.size()].darkened(0.25)
		for side: float in [-1.0, 1.0]:
			_ball(_at(j, side * (WALL + BULGE + 0.35), 0.25), Vector3(0.55, 0.45, 0.8), color)
	var tail := _at(i1, 0.0, WALL_TOP + ROOF + 0.2)
	var fwd1 := _forward(i1)
	var tail_colors: Array[Color] = [C_PURPLE, C_PINK, C_YELLOW]
	for k in 3:
		_ball(tail + fwd1 * (0.6 + k * 0.85) + Vector3.UP * (0.3 + k * 0.7), Vector3.ONE * (0.75 - k * 0.15), tail_colors[k])

	# Fairy lights along the ceiling.
	_glow.clear()
	for c in BULBS.size():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_glow.append(st)
	var bulb := 0
	for j in range(i0 + 3, i1 - 1, 2):
		for d: float in [-2.6, 0.0, 2.6]:
			var y := WALL_TOP + (ROOF - SKIN) * sqrt(maxf(0.0, 1.0 - pow(d / (WALL - SKIN), 2.0))) - 0.3
			_ball(_at(j, d, y), Vector3.ONE * 0.17, BULBS[bulb % BULBS.size()], _glow[bulb % BULBS.size()], 3, 6)
			bulb += 1

	var tunnel := Tunnel.new()
	tunnel.name = "Tunnel"
	tunnel.entry_point = _pos[posmod(i0, _count)]
	tunnel.exit_point = _pos[posmod(i1, _count)]
	root.add_child(tunnel)
	tunnel.owner = root

	# Warm lamps inside (no shadows: cheap).
	var lamps := 4
	for k in lamps:
		var j := i0 + int((k + 0.5) * (i1 - i0) / lamps)
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp%d" % (k + 1)
		lamp.position = _at(j, 0.0, 4.4)
		lamp.light_color = Color("ffd89a") if k % 2 == 0 else Color("ffb3d0")
		lamp.light_energy = 2.2
		lamp.omni_range = 10.0
		lamp.shadow_enabled = false
		tunnel.add_child(lamp)
		lamp.owner = root

	_add_face(root, tunnel, i0)
	_clear_trees_along(root, _pos[posmod(i0, _count)], _pos[posmod(i1, _count)], WALL + 3.0)
	print("caterpillar tunnel: %d segments, %.0f m, bulbs=%d" % [segments, segments * SEGMENT * _step, bulb])
	return tunnel

## Eyes (white balls with pupils that follow the karts) and two antennae, as nodes so
## scripts/track/tunnel.gd can move them.
func _add_face(root: Node3D, tunnel: Node3D, i0: int) -> void:
	var fwd := _forward(i0)
	var white := _material(C_WHITE, 0.3)
	var black := _material(C_BLACK, 0.2)
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 1.05
	eye_mesh.height = 2.1
	eye_mesh.material = white
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.5
	pupil_mesh.height = 1.0
	pupil_mesh.material = black
	var shine_mesh := SphereMesh.new()
	shine_mesh.radius = 0.14
	shine_mesh.height = 0.28
	shine_mesh.material = white
	var top := WALL_TOP + ROOF + HEAD_BULGE
	for side: float in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.name = "EyeL" if side < 0.0 else "EyeR"
		eye.position = _at(i0 + 1, side * 2.0, top - 0.25) - fwd * 0.4
		tunnel.add_child(eye)
		eye.owner = root
		var ball := MeshInstance3D.new()
		ball.name = "Ball"
		ball.mesh = eye_mesh
		eye.add_child(ball)
		ball.owner = root
		var pupil := MeshInstance3D.new()
		pupil.name = "Pupil"
		pupil.mesh = pupil_mesh
		pupil.position = -fwd * 0.7
		eye.add_child(pupil)
		pupil.owner = root
		var shine := MeshInstance3D.new()
		shine.name = "Shine"
		shine.mesh = shine_mesh
		shine.position = Vector3(0.15, 0.2, 0.0) - fwd * 0.4
		pupil.add_child(shine)
		shine.owner = root

		var antenna := Node3D.new()
		antenna.name = "AntennaL" if side < 0.0 else "AntennaR"
		antenna.position = _at(i0 + 2, side * 1.1, top - 0.2)
		# Leans forward and outward.
		var lean := (Vector3.UP * 1.0 - fwd * 0.45 + _right[posmod(i0, _count)] * side * 0.35).normalized()
		antenna.basis = Basis(Quaternion(Vector3.UP, lean))
		tunnel.add_child(antenna)
		antenna.owner = root
		var stalk_mesh := CylinderMesh.new()
		stalk_mesh.top_radius = 0.09
		stalk_mesh.bottom_radius = 0.13
		stalk_mesh.height = 2.4
		stalk_mesh.radial_segments = 8
		stalk_mesh.rings = 1
		stalk_mesh.material = black
		var stalk := MeshInstance3D.new()
		stalk.name = "Stalk"
		stalk.mesh = stalk_mesh
		stalk.position = Vector3(0, 1.2, 0)
		antenna.add_child(stalk)
		stalk.owner = root
		var knob_mesh := SphereMesh.new()
		knob_mesh.radius = 0.42
		knob_mesh.height = 0.84
		knob_mesh.radial_segments = 12
		knob_mesh.rings = 6
		knob_mesh.material = _material(C_YELLOW, 0.3)
		var knob := MeshInstance3D.new()
		knob.name = "Knob"
		knob.mesh = knob_mesh
		knob.position = Vector3(0, 2.5, 0)
		antenna.add_child(knob)
		knob.owner = root

## Number of points in the caterpillar's cross-section (right foot, up the wall, over the roof,
## down the left wall).
func _profile_count() -> int:
	return 18

## Cross-section point k: (sideways, up) with the segment's bulge `b`, pulled in by `inset`.
func _profile(k: int, b: float, inset: float) -> Vector2:
	var w := WALL + b - inset
	var roof := ROOF + b * 0.8 - inset
	if k == 0:
		return Vector2(w, -0.35)
	if k == 17:
		return Vector2(-w, -0.35)
	var a := PI * float(k - 1) / 15.0
	return Vector2(w * cos(a), WALL_TOP + roof * sin(a))

func _ring(j: int, k: int, b: float, inset: float) -> Vector3:
	var p := _profile(k, b, inset)
	return _at(j, p.x, p.y)

## Outward normal at cross-section point k; `slope` tilts it along the road to show the bulge.
func _ring_normal(j: int, k: int, slope: float) -> Vector3:
	var r := _right[posmod(j, _count)]
	var side := Vector2(1.0, 0.0)
	if k == 0:
		side = Vector2(1.0, 0.0)
	elif k == 17:
		side = Vector2(-1.0, 0.0)
	else:
		var a := PI * float(k - 1) / 15.0
		side = Vector2(cos(a) / WALL, sin(a) / ROOF).normalized()
	return (r * side.x + Vector3.UP * side.y - _forward(j) * slope).normalized()

## A flat ring across the opening at slice j, from the inner skin out to `width` past the outside.
## `facing` -1 faces karts coming in, +1 faces the way out.
func _lip(j: int, facing: float, color: Color, width: float) -> void:
	var fwd := _forward(j)
	var n := fwd * facing
	var push := fwd * facing * (0.25 if width > 0.3 else 0.05)
	var count := _profile_count()
	for k in count - 1:
		var a0 := _ring(j, k, 0.0, SKIN)
		var a1 := _ring(j, k + 1, 0.0, SKIN)
		var b0 := _ring(j, k, width, 0.0) + push
		var b1 := _ring(j, k + 1, width, 0.0) + push
		_face([a0, a1, b1, b0], n, color)
		# Round the lip back onto the body.
		var c0 := _ring(j, k, 0.0, 0.0)
		var c1 := _ring(j, k + 1, 0.0, 0.0)
		_face([b0, b1, c1, c0], (_ring_normal(j, k, 0.0) + n).normalized(), color)

# --- Pillow fort (living room) ---------------------------------------------------------------

func _build_pillows(root: Node3D, m: Dictionary) -> Node3D:
	var lip := _slice(m["at"])
	var ground := _road_y - 0.03
	var rng := RandomNumberGenerator.new()
	rng.seed = 3601
	var road_top := _at(lip, 0.0, 0.0).y

	# Two towers of fat cushions just before the lip, one on each side of the road.
	var tower := lip - int(round(PILLOW_TOWER_BEFORE / _step))
	var fwd := _forward(tower)
	var tops: Array[Vector3] = []
	for side: float in [-1.0, 1.0]:
		var base := _flat(tower, side * PILLOW_TOWER_OUT, 0.0)
		var y := ground
		var top := Vector3.ZERO
		for k in PILLOW_LAYERS:
			var half := Vector3(2.7 - k * 0.16, 0.95, 2.5 - k * 0.12)
			var yaw := rng.randf_range(-0.4, 0.4) + atan2(fwd.x, fwd.z)
			var color := PILLOW_COLORS[(k * 2 + (0 if side < 0.0 else 3)) % PILLOW_COLORS.size()]
			var c := base + Vector3(rng.randf_range(-0.3, 0.3), y + half.y * 0.82, rng.randf_range(-0.3, 0.3))
			_pillow(c, Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, rng.randf_range(-0.05, 0.05)), half, color)
			y += half.y * 1.6
			top = c + Vector3.UP * half.y * 0.8
		tops.append(top)

	# A candy-striped pole on each tower and a garland of flags between them, high over the road.
	var pole_top := road_top + GARLAND_CLEAR + GARLAND_SAG
	var ends: Array[Vector3] = []
	for top in tops:
		var height := maxf(1.5, pole_top - top.y)
		var stripes := int(ceil(height / 0.6))
		for k in stripes:
			var y0 := top.y + height * k / stripes
			var y1 := top.y + height * (k + 1) / stripes
			_tube(Vector3(top.x, y0, top.z), Vector3(top.x, y1, top.z), 0.16, 0.16, C_RED if k % 2 == 0 else C_WHITE, 8)
		var knob := Vector3(top.x, top.y + height, top.z)
		_ball(knob + Vector3.UP * 0.2, Vector3.ONE * 0.38, C_YELLOW)
		ends.append(knob)
	var a := ends[0]
	var b := ends[1]
	var sag := func(t: float) -> Vector3: return a.lerp(b, t) - Vector3.UP * GARLAND_SAG * 4.0 * t * (1.0 - t)
	var steps := 24
	for k in steps:
		_beam(sag.call(float(k) / steps), sag.call(float(k + 1) / steps), fwd, 0.05, C_WHITE)
	var span := a.distance_to(b)
	var flags := int(span / 1.05)
	var across := (b - a).normalized()
	for k in flags:
		var t0 := (k + 0.18) / flags
		var t1 := (k + 0.82) / flags
		var p0: Vector3 = sag.call(t0)
		var p1: Vector3 = sag.call(t1)
		var tip := (p0 + p1) * 0.5 + Vector3.DOWN * 1.15
		var n := across.cross(Vector3.DOWN).normalized()
		var color := RAINBOW[k % RAINBOW.size()]
		_face([p0, p1, tip], n, color)
		_face([p0, p1, tip], -n, color)

	# Gold tassels on the four corners of the cushion the road runs over.
	var from_i: int = m.get("from_slice", lip - int(12.0 / _step))
	var to_i: int = m.get("to_slice", lip + int(24.0 / _step))
	for i: int in [from_i, to_i]:
		for side: float in [-1.0, 1.0]:
			var corner := _at(i, side * (_half_width + 0.75), 0.25)
			_ball(corner, Vector3(0.42, 0.42, 0.42), C_YELLOW)
			_tube(corner - Vector3.UP * 0.2, corner - Vector3.UP * 1.0, 0.18, 0.42, C_ORANGE, 10)

	var fort := PillowFort.new()
	fort.name = "PillowFort"
	var teddy: Array = m.get("teddy", [8.0, 10.0])
	var ti := lip + int(round(float(teddy[0]) / _step))
	var d: float = teddy[1]
	fort.teddy_spot = _flat(ti, d, ground)
	fort.teddy_facing = (-_right[posmod(ti, _count)] * signf(d) - _forward(ti) * 0.55).normalized()
	fort.lip_point = _at(lip, 0.0, 0.0)
	root.add_child(fort)
	fort.owner = root
	print("pillow fort: lip at s=%.0f, garland %.1f m over the lip, %d flags" % [float(m["at"]), a.y - GARLAND_SAG - road_top, flags])
	return fort

## A fat cushion: square seen from above with round corners, thick in the middle and thin at
## the edges, with a gold tassel on each corner.
func _pillow(c: Vector3, basis: Basis, half: Vector3, color: Color) -> void:
	var rings := 8
	var segs := 24
	var shape := func(eta: float, om: float) -> Vector3:
		var ce := _spow(cos(eta), 0.9)
		return Vector3(half.x * ce * _spow(cos(om), 0.28), half.y * _spow(sin(eta), 0.9), half.z * ce * _spow(sin(om), 0.28))
	var normal := func(eta: float, om: float) -> Vector3:
		if absf(eta) > PI * 0.5 - 0.001:
			return Vector3.UP * signf(eta)
		var h := 0.004
		var n: Vector3 = ((shape.call(eta, om + h) - shape.call(eta, om - h)) as Vector3).cross(shape.call(eta + h, om) - shape.call(eta - h, om))
		var q: Vector3 = shape.call(eta, om)
		if n.dot(q) < 0.0:
			n = -n
		return n.normalized()
	for r in rings:
		var e0 := PI * r / rings - PI * 0.5
		var e1 := PI * (r + 1) / rings - PI * 0.5
		for s in segs:
			var o0 := TAU * s / segs
			var o1 := TAU * (s + 1) / segs
			var v: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for p: Vector2 in [Vector2(e0, o0), Vector2(e0, o1), Vector2(e1, o1), Vector2(e1, o0)]:
				v.append(c + basis * (shape.call(p.x, p.y) as Vector3))
				normals.append(basis * (normal.call(p.x, p.y) as Vector3))
			if r == 0:
				_poly([v[0], v[2], v[3]], [normals[0], normals[2], normals[3]], color)
			elif r == rings - 1:
				_poly([v[0], v[1], v[2]], [normals[0], normals[1], normals[2]], color)
			else:
				_poly(v, normals, color)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_ball(c + basis * Vector3(sx * half.x * 0.97, 0.0, sz * half.z * 0.97), Vector3.ONE * 0.24, C_YELLOW, null, 4, 8)
	# A button in the middle of the top.
	_ball(c + basis * Vector3(0.0, half.y * 0.97, 0.0), Vector3(0.3, 0.1, 0.3), color.darkened(0.25), null, 3, 8)

static func _spow(v: float, e: float) -> float:
	return signf(v) * pow(absf(v), e)

# --- Owl tree gate (forest) ------------------------------------------------------------------

func _build_owl(root: Node3D, m: Dictionary) -> Node3D:
	var i := _slice(m["at"])
	var across := _right[i]
	var along := _forward(i)
	var ground := _road_y - 0.05
	var branch_y := _road_y + OWL_BRANCH_HEIGHT
	var rng := RandomNumberGenerator.new()
	rng.seed = 7007
	var holes: Array[Vector3] = []
	for side: float in [-1.0, 1.0]:
		var foot := _flat(i, side * OWL_TRUNK_OUT, ground - 0.4)
		var top := foot + Vector3.UP * (OWL_BRANCH_HEIGHT + 5.0)
		_tube(foot, top, 1.35, 0.85, C_BARK, 14)
		# Roots spreading out at the foot.
		for k in 5:
			var a := TAU * k / 5.0 + 0.4
			var out := (across * cos(a) + along * sin(a))
			if out.dot(across * side) < -0.3:
				continue  # no roots across the road
			_tube(foot + Vector3.UP * 1.6 + out * 0.6, foot + out * 2.6 + Vector3.UP * 0.25, 0.55, 0.2, C_BARK, 8)
		# A knothole facing the road just above the branch: the animals come out of it.
		var face := -across * side
		var hole_c := _flat(i, side * (OWL_TRUNK_OUT - 1.08), branch_y + 1.05)
		_ball(hole_c - face * 0.12, Vector3(0.62, 0.8, 0.62), C_BARK.darkened(0.25), null, 4, 10)
		_ball(hole_c + face * 0.06, Vector3(0.45, 0.62, 0.45), C_BLACK, null, 4, 10)
		holes.append(_flat(i, side * (OWL_TRUNK_OUT - 1.0), branch_y + OWL_BRANCH_R))
		# The crown: big round leaf balls in two greens, with red apples.
		for k in 7:
			var a := TAU * k / 7.0 + rng.randf() * 0.5
			var r := rng.randf_range(2.4, 3.3)
			var c := top + (across * cos(a) + along * sin(a)) * rng.randf_range(1.8, 2.8) + Vector3.UP * rng.randf_range(-0.6, 1.6)
			_ball(c, Vector3(r, r * 0.9, r), C_LEAF if k % 2 == 0 else C_LEAF_LIGHT, null, 6, 12)
		_ball(top + Vector3.UP * 2.8, Vector3(3.0, 2.6, 3.0), C_LEAF_LIGHT, null, 6, 12)
		for k in 9:
			var a := TAU * k / 9.0 + rng.randf() * 0.4
			var c := top + (across * cos(a) + along * sin(a)) * 4.3 + Vector3.UP * rng.randf_range(-0.8, 2.2)
			_ball(c, Vector3.ONE * 0.42, C_RED, null, 4, 8)
		# Toadstools round the foot.
		for k in 3:
			var a := TAU * (k + 0.3) / 3.0 + rng.randf() * 0.6
			var at := foot + (across * cos(a) + along * sin(a)) * rng.randf_range(2.6, 3.4)
			if (at - _flat(i, 0.0, at.y)).dot(across * side) < OWL_TRUNK_OUT - 0.5:
				continue  # keep off the road side
			at.y = ground
			var h := rng.randf_range(0.9, 1.5)
			_tube(at, at + Vector3.UP * h, 0.28, 0.34, C_WHITE, 8)
			var cap := at + Vector3.UP * h
			_ball(cap, Vector3(0.95, 0.6, 0.95) * (h / 1.2), C_RED, null, 5, 12)
			for dot in 5:
				var da := TAU * dot / 5.0
				_ball(cap + Vector3(cos(da) * 0.55, 0.38, sin(da) * 0.55) * (h / 1.2), Vector3(0.16, 0.08, 0.16), C_WHITE, null, 3, 6)
	# The branch from tree to tree, a little arched, with leafy tufts at both ends.
	var p0 := _flat(i, -OWL_TRUNK_OUT + 0.6, branch_y)
	var p1 := _flat(i, OWL_TRUNK_OUT - 0.6, branch_y)
	var mid := (p0 + p1) * 0.5 + Vector3.UP * 0.35
	_tube(p0, mid, OWL_BRANCH_R * 1.15, OWL_BRANCH_R, C_BARK_LIGHT, 12)
	_tube(mid, p1, OWL_BRANCH_R, OWL_BRANCH_R * 1.15, C_BARK_LIGHT, 12)
	_ball(mid, Vector3.ONE * OWL_BRANCH_R, C_BARK_LIGHT, null, 5, 12)
	for side: float in [-1.0, 1.0]:
		var at := _flat(i, side * (OWL_TRUNK_OUT - 2.6), branch_y - 0.2) + along * 0.3
		_tube(at, at + Vector3.DOWN * 1.1 + along * 0.4, 0.12, 0.08, C_BARK, 6)
		_ball(at + Vector3.DOWN * 1.4 + along * 0.5, Vector3(0.7, 0.55, 0.7), C_LEAF_LIGHT, null, 4, 10)

	var friends := ForestFriends.new()
	friends.name = "ForestFriends"
	friends.hole_a = holes[0]
	friends.hole_b = holes[1]
	friends.owl_spot = mid + Vector3.UP * (OWL_BRANCH_R - 0.05)
	friends.facing = -along
	friends.road_point = _pos[i]
	root.add_child(friends)
	friends.owner = root
	print("owl tree gate: s=%.0f, branch %.1f m over the road, trunks %.1f m out" % [float(m["at"]), OWL_BRANCH_HEIGHT, OWL_TRUNK_OUT])
	return friends

# --- Shared helpers --------------------------------------------------------------------------

## A point `d` metres to the right of slice i's centre line, at height y (not following the bank).
func _flat(i: int, d: float, y: float) -> Vector3:
	var k := posmod(i, _count)
	return Vector3(_pos[k].x, y, _pos[k].z) + _right[k] * d

## A round tube from p0 (radius r0) to p1 (radius r1), closed at p1.
func _tube(p0: Vector3, p1: Vector3, r0: float, r1: float, color: Color, segs := 12) -> void:
	var axis := (p1 - p0).normalized()
	var ref := Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var u := axis.cross(ref).normalized()
	var w := axis.cross(u)
	var slope := (r0 - r1) / maxf(p0.distance_to(p1), 0.001)
	for k in segs:
		var a0 := TAU * k / segs
		var a1 := TAU * (k + 1) / segs
		var d0 := u * cos(a0) + w * sin(a0)
		var d1 := u * cos(a1) + w * sin(a1)
		var n0 := (d0 + axis * slope).normalized()
		var n1 := (d1 + axis * slope).normalized()
		_poly([p0 + d0 * r0, p0 + d1 * r0, p1 + d1 * r1, p1 + d0 * r1], [n0, n1, n1, n0], color)
		_poly([p1, p1 + d0 * r1, p1 + d1 * r1], [axis, axis, axis], color)

func _slice(s: float) -> int:
	return posmod(int(round(s / _step)), _count)

func _at(i: int, d: float, h: float) -> Vector3:
	var k := posmod(i, _count)
	return _pos[k] + _right[k] * d + Vector3(0, _road_y + h - d * _bank[k], 0)

func _forward(i: int) -> Vector3:
	var d := _pos[posmod(i + 1, _count)] - _pos[posmod(i - 1, _count)]
	d.y = 0.0
	return d.normalized()

## One flat polygon (3 or 4 corners) facing `n`.
func _face(v: Array[Vector3], n: Vector3, color: Color, st: SurfaceTool = null) -> void:
	var normals: Array[Vector3] = []
	for k in v.size():
		normals.append(n)
	_poly(v, normals, color, st)

## A polygon (3 or 4 corners) with a normal per corner. Godot shows the side where the corners
## run clockwise, so the order flips when the face would point away from its normals.
func _poly(v: Array[Vector3], normals: Array[Vector3], color: Color, st: SurfaceTool = null) -> void:
	if st == null:
		st = _st
	var facing := (v[2] - v[0]).cross(v[1] - v[0])
	var order: Array = [0, 1, 2] if v.size() == 3 else [0, 1, 2, 0, 2, 3]
	var sum := normals[0] + normals[1] + normals[2]
	if facing.dot(sum) < 0.0:
		order = [0, 2, 1] if v.size() == 3 else [0, 2, 1, 0, 3, 2]
	for k: int in order:
		st.set_color(color)
		st.set_normal(normals[k])
		st.add_vertex(v[k])

## A box from its centre and three half-size vectors (at right angles to each other).
func _box(c: Vector3, ax: Vector3, ay: Vector3, az: Vector3, color: Color, st: SurfaceTool = null) -> void:
	for axes: Array in [[ax, ay, az], [ay, az, ax], [az, ax, ay]]:
		var a: Vector3 = axes[0]
		var b: Vector3 = axes[1]
		var d: Vector3 = axes[2]
		for sgn: float in [-1.0, 1.0]:
			var f := c + a * sgn
			_face([f - b - d, f + b - d, f + b + d, f - b + d], a.normalized() * sgn, color, st)

## A square beam from p0 to p1; `side` is a direction across the beam.
func _beam(p0: Vector3, p1: Vector3, side: Vector3, half: float, color: Color) -> void:
	var axis := (p1 - p0) * 0.5
	var across := side.normalized() * half
	var up := axis.cross(across).normalized() * half
	_box((p0 + p1) * 0.5, axis, up, across, color)

## A smooth ball (or egg, with three radii).
func _ball(c: Vector3, r: Vector3, color: Color, st: SurfaceTool = null, rings := 6, segs := 12) -> void:
	var point := func(lat: float, lon: float) -> Vector3:
		return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
	for ri in rings:
		var l0 := PI * ri / rings - PI * 0.5
		var l1 := PI * (ri + 1) / rings - PI * 0.5
		for si in segs:
			var o0 := TAU * si / segs
			var o1 := TAU * (si + 1) / segs
			var u: Array[Vector3] = [point.call(l0, o0), point.call(l0, o1), point.call(l1, o1), point.call(l1, o0)]
			var v: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for q in u:
				v.append(c + q * r)
				normals.append((q / r).normalized())
			if ri == 0:
				_poly([v[0], v[2], v[3]], [normals[0], normals[2], normals[3]], color, st)
			elif ri == rings - 1:
				_poly([v[0], v[1], v[2]], [normals[0], normals[1], normals[2]], color, st)
			else:
				_poly(v, normals, color, st)

static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.rim_tint = 0.85
	return mat

## Removes trees and pines inside a circle (so nothing grows through a mountain).
func _clear_trees(root: Node3D, center: Vector3, radius: float) -> void:
	_filter_trees(root, func(p: Vector3) -> bool: return Vector2(p.x - center.x, p.z - center.z).length() > radius)

## Removes trees closer than `width` to the straight line from a to b.
func _clear_trees_along(root: Node3D, a: Vector3, b: Vector3, width: float) -> void:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	_filter_trees(root, func(p: Vector3) -> bool:
		return Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a2, b2).distance_to(Vector2(p.x, p.z)) > width)

func _filter_trees(root: Node3D, keep: Callable) -> void:
	for scatter_name: String in ["Trees", "Pines"]:
		var scatter := root.get_node_or_null(scatter_name) as Scatter
		if scatter == null:
			continue
		var kept: Array[Transform3D] = []
		for xform in scatter.placements:
			if keep.call(xform.origin):
				kept.append(xform)
		scatter.placements = kept

func _save_mesh(root: Node3D, node: Node3D, id: String) -> void:
	_st.index()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.5
	material.rim_enabled = true
	material.rim = 0.2
	material.rim_tint = 0.85
	_st.set_material(material)
	var mesh := _st.commit()
	for c in _glow.size():
		_glow[c].index()
		_glow[c].commit(mesh)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = BULBS[c]
		glow.emission_enabled = true
		glow.emission = BULBS[c]
		glow.emission_energy_multiplier = 2.5
		mesh.surface_set_material(mesh.get_surface_count() - 1, glow)
	var path := "res://scenes/tracks/%s_moment.res" % id
	ResourceSaver.save(mesh, path)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = load(path)
	node.add_child(body)
	body.owner = root
	print("moment mesh: %d vertices, %d surfaces" % [mesh.surface_get_array_len(0), mesh.get_surface_count()])
