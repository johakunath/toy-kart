class_name ForestFriends extends Node3D
## Waldkurs' signature moment: a tree gate with a big friendly owl on a branch high over the
## road. The owl turns its head after the nearest player (all the way round, like real owls),
## blinks and flaps its wings when a kart comes close. When a player is about to drive under the
## branch, a parade of forest animals (hedgehog, bunny, squirrel) hops out of a knothole, over
## the branch and into the other tree, so every player sees them cross; the next parade goes the
## other way. Trees and branch come from tools/track_moments.gd. Nothing here has collision.

@export var hole_a := Vector3.ZERO      ## branch top at the left tree's knothole
@export var hole_b := Vector3.ZERO      ## ... and at the right one
@export var owl_spot := Vector3.ZERO    ## branch top in the middle, where the owl sits
@export var facing := Vector3.FORWARD   ## flat, toward the karts coming up to the branch
@export var road_point := Vector3.ZERO  ## the road centre under the branch

const C_OWL := Color("c8641e")
const C_OWL_DARK := Color("8a3f12")
const C_CREAM := Color("ffe3a3")
const C_FACE := Color("fff1d2")
const C_YELLOW := Color("ffc81e")
const C_ORANGE := Color("ff8a1e")
const C_BLACK := Color("1c1d24")
const C_WHITE := Color("f4f6fb")
const C_PINK := Color("ff6f9c")

const WALK_SPEED := 3.4          ## m/s along the branch
const SPACING := 2.1             ## metres between two animals
const HOP := 0.45
const ARCH := 0.35               ## the branch is this much higher in the middle
const CAMERA_LAG := 6.0          ## the chase camera hangs about this far behind its kart
const KART_BEFORE := 10.0        ## the parade is mid-branch when the kart is this far before it
const LOOK_AHEAD := 120.0
const FLAP_NEAR := 26.0          ## the owl flaps when a camera is this close
const ANIMAL_SCALE := 1.5

var _owl: Node3D
var _owl_head: Node3D
var _owl_eyes: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _head_yaw := 0.0
var _head_pitch := 0.0
var _flap := 0.0
var _blink_in := 2.0
var _time := 0.0

var _animals: Array[Node3D] = []
var _running := false
var _front := 0.0                ## distance of the first animal from its start hole
var _dir := -1.0                 ## +1: from hole_a to hole_b
var _rest := 1.0

var _track: Track
var _s_branch := -1.0
var _cams: Array[Camera3D] = []
var _cam_index := {}
var _cam_speed := {}
var _scan_wait := 0.0
var _hop: AudioStreamPlayer3D
var _hop_count := 0

func _ready() -> void:
	_build_owl()
	_animals = [_hedgehog(), _bunny(), _squirrel()]
	for animal in _animals:
		animal.top_level = true
		animal.visible = false
		add_child(animal)
	_hop = AudioStreamPlayer3D.new()
	_hop.stream = load("res://assets/sfx/pop.wav")
	_hop.bus = &"Effects"
	_hop.volume_db = -12.0
	_hop.unit_size = 10.0
	_hop.max_distance = 80.0
	_hop.top_level = true
	add_child(_hop)

func _process(delta: float) -> void:
	_time += delta
	var near := _watch_players(delta)
	if _running:
		_walk(delta)
	else:
		_rest += delta
	_flap = move_toward(_flap, 1.0 if near or _running else 0.0, delta * 2.0)
	_pose_owl(delta)

# --- When to go --------------------------------------------------------------------------------

## Follows every player camera along the racing line, starts the parade in time for the first
## one coming up to the branch, and returns true if a camera is close to the owl.
func _watch_players(delta: float) -> bool:
	if _track == null:
		_track = get_parent() as Track
		if _track == null or _track.count == 0:
			_track = null
			return false
		_s_branch = _track.s_at(_track.closest_index(road_point))
	_scan_wait -= delta
	if _cams.is_empty() and _scan_wait <= 0.0:
		_scan_wait = 1.0
		for node in get_tree().root.find_children("*", "Camera3D", true, false):
			_cams.append(node as Camera3D)
	var near := false
	var lead := (hole_a.distance_to(hole_b) * 0.5 + SPACING) / WALK_SPEED
	for cam in _cams.duplicate():
		if not is_instance_valid(cam):
			_cams.erase(cam)
			continue
		var hint: int = _cam_index.get(cam, -1)
		var index := _track.closest_index(cam.global_position, hint)
		var speed: float = _cam_speed.get(cam, 0.0)
		if hint >= 0 and delta > 0.0:
			var moved := _track.s_at(index) - _track.s_at(hint)
			if moved < -_track.length * 0.5:
				moved += _track.length
			if absf(moved) > 3.0:
				speed = 0.0  # the camera jumped (first frames, a reset): no real speed
			else:
				speed = lerpf(speed, maxf(moved / delta, 0.0), 1.0 - exp(-3.0 * delta))
		_cam_index[cam] = index
		_cam_speed[cam] = speed
		if cam.global_position.distance_to(owl_spot) < FLAP_NEAR:
			near = true
		if _running or _rest < 0.5:
			continue
		var ahead := fposmod(_s_branch - _track.s_at(index), _track.length)
		var gap := ahead - CAMERA_LAG - KART_BEFORE
		if ahead < LOOK_AHEAD and gap > -4.0 and gap / maxf(speed, 2.5) <= lead:
			_start()
	return near

func _start() -> void:
	_dir = -_dir
	_front = 0.0
	_running = true
	_hop_count = 0

func _walk(delta: float) -> void:
	_front += WALK_SPEED * delta
	var from := hole_a if _dir > 0.0 else hole_b
	var to := hole_b if _dir > 0.0 else hole_a
	var span := from.distance_to(to)
	var forward := (to - from)
	forward.y = 0.0
	forward = forward.normalized()
	var x := Vector3.UP.cross(forward).normalized()
	var back := -facing * 0.35  # walk behind the owl, on the far half of the branch
	var all_in := true
	for k in _animals.size():
		var d := _front - k * SPACING
		var animal := _animals[k]
		if d < 0.0 or d > span:
			animal.visible = false
			all_in = all_in and d > span
			continue
		all_in = false
		animal.visible = true
		var t := d / span
		var phase := d / 1.1 * PI + k
		var hop := HOP * absf(sin(phase)) * (1.3 if k == 1 else 1.0)  # the bunny hops highest
		var pos := from.lerp(to, t) + Vector3.UP * (ARCH * 4.0 * t * (1.0 - t) + hop) + back
		var tilt := 0.18 * cos(phase)
		animal.global_transform = Transform3D(Basis(x, Vector3.UP, forward) * Basis(Vector3.RIGHT, -tilt).scaled(Vector3.ONE * ANIMAL_SCALE), pos)
		if k == 0 and int(phase / PI) != _hop_count:
			_hop_count = int(phase / PI)
			if _hop_count % 2 == 0:
				_hop.global_position = pos
				_hop.pitch_scale = randf_range(1.4, 1.8)
				_hop.play()
	if all_in:
		_running = false
		_rest = 0.0

# --- The owl -----------------------------------------------------------------------------------

## Owl local space: +Z looks at the coming karts, the branch top is y = 0. About 3.4 m tall.
func _build_owl() -> void:
	_owl = Node3D.new()
	_owl.name = "Owl"
	_owl.top_level = true
	var x := Vector3.UP.cross(facing).normalized()
	_owl.transform = Transform3D(Basis(x, Vector3.UP, facing), owl_spot + facing * 0.3)
	add_child(_owl)
	var body := ToyParts.new(0.7)
	body.ball(Vector3(0, 1.25, 0), Vector3(1.15, 1.35, 1.0), C_OWL)
	body.ball(Vector3(0, 1.05, 0.45), Vector3(0.85, 1.0, 0.65), C_CREAM)
	# Little orange chevrons on the belly.
	for row in 3:
		for k in 3 - row % 2:
			var off := (k - (2 - row % 2) * 0.5) * 0.42
			body.ball(Vector3(off, 1.45 - row * 0.38, 1.02 - absf(off) * 0.25 - row * 0.02), Vector3(0.14, 0.07, 0.06), C_ORANGE)
	# Tail and feet gripping the branch.
	body.ball(Vector3(0, 0.25, -0.75), Vector3(0.5, 0.35, 0.5), C_OWL_DARK, Basis(Vector3.RIGHT, 0.5))
	for side: float in [-1.0, 1.0]:
		for k in 3:
			body.ball(Vector3(side * 0.42 + (k - 1) * 0.16, 0.05, 0.55), Vector3(0.1, 0.1, 0.2), C_ORANGE)
	_owl.add_child(body.build())

	_owl_head = Node3D.new()
	_owl_head.name = "Head"
	_owl_head.position = Vector3(0, 2.6, 0.05)
	_owl.add_child(_owl_head)
	var head := ToyParts.new(0.7)
	head.ball(Vector3.ZERO, Vector3(1.1, 0.95, 1.0), C_OWL)
	for side: float in [-1.0, 1.0]:
		head.ball(Vector3(side * 0.45, 0.05, 0.72), Vector3(0.5, 0.5, 0.3), C_FACE)
		# Ear tufts.
		head.cylinder(Vector3(side * 0.72, 0.95, -0.05), 0.0, 0.3, 0.75, C_OWL_DARK, Basis(Vector3.FORWARD, -side * 0.35))
	head.cylinder(Vector3(0, -0.28, 1.0), 0.0, 0.17, 0.5, C_ORANGE, Basis(Vector3.RIGHT, PI * 0.5 + 0.5))
	_owl_head.add_child(head.build())
	for side: float in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.45, 0.08, 0.96)
		_owl_head.add_child(eye)
		var parts := ToyParts.new(0.25, 0.6)
		parts.ball(Vector3.ZERO, Vector3(0.34, 0.34, 0.1), C_YELLOW)
		parts.ball(Vector3(0, 0, 0.06), Vector3(0.2, 0.2, 0.08), C_BLACK)
		parts.ball(Vector3(0.07, 0.08, 0.12), Vector3.ONE * 0.06, C_WHITE)
		eye.add_child(parts.build(false))
		_owl_eyes.append(eye)

	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 1.0, 1.85, -0.05)
		_owl.add_child(wing)
		var parts := ToyParts.new(0.7)
		parts.ball(Vector3(side * 0.12, -0.75, 0), Vector3(0.28, 0.95, 0.75), C_OWL_DARK)
		wing.add_child(parts.build())
		_wings.append(wing)

func _pose_owl(delta: float) -> void:
	# Head: turns after the nearest camera, all the way round if needed, and looks down at it.
	var target := Vector3.INF
	var best := INF
	for cam in _cams:
		if is_instance_valid(cam):
			var d := cam.global_position.distance_squared_to(owl_spot)
			if d < best:
				best = d
				target = cam.global_position
	var yaw := 0.0
	var pitch := 0.0
	if target != Vector3.INF:
		var local := _owl.to_local(target) - _owl_head.position
		yaw = atan2(local.x, local.z)
		pitch = clampf(atan2(-local.y, Vector2(local.x, local.z).length()), -0.2, 0.7)
	# Owls turn far, but not through the back: keep the turn short and smooth.
	yaw = clampf(yaw, -2.7, 2.7)
	_head_yaw = lerpf(_head_yaw, yaw, 1.0 - exp(-4.0 * delta))
	_head_pitch = lerpf(_head_pitch, pitch, 1.0 - exp(-4.0 * delta))
	_owl_head.rotation = Vector3(_head_pitch, _head_yaw, 0.0)
	# Wings: folded, flapping and waving when someone comes.
	for k in _wings.size():
		var side := -1.0 if k == 0 else 1.0
		var open := _flap * (0.55 + 0.5 * sin(_time * 12.0))
		_wings[k].rotation = Vector3(0.0, 0.0, side * open)
	# A little hop on the branch while flapping, and blinking now and then.
	_owl.position = owl_spot + facing * 0.3 + Vector3.UP * 0.12 * _flap * absf(sin(_time * 6.0))
	_blink_in -= delta
	var squash := 1.0
	if _blink_in < 0.0:
		squash = 0.12
		if _blink_in < -0.15:
			_blink_in = randf_range(1.8, 4.0)
	for eye in _owl_eyes:
		eye.scale = Vector3(1.0, squash, 1.0)

# --- The parade animals (local +Z forward, feet at y = 0, about 1 m tall) ----------------------

func _hedgehog() -> Node3D:
	var p := ToyParts.new(0.8)
	var brown := Color("7a4a1e")
	p.ball(Vector3(0, 0.42, -0.05), Vector3(0.48, 0.4, 0.62), brown)
	# Spikes: dark cones all over the back.
	for row in 4:
		for k in 5:
			var a := lerpf(-1.1, 1.1, k / 4.0)
			var b := lerpf(0.35, -0.75, row / 3.0)
			var n := Vector3(sin(a) * 0.9, cos(a), b).normalized()
			var base := Vector3(0, 0.42, -0.05) + n * Vector3(0.45, 0.37, 0.58)
			p.cylinder(base + n * 0.12, 0.0, 0.11, 0.32, Color("4a2a10"), Basis(Quaternion(Vector3.UP, n)))
	p.ball(Vector3(0, 0.36, 0.52), Vector3(0.3, 0.26, 0.32), Color("f2c98a"))
	p.ball(Vector3(0, 0.36, 0.85), Vector3(0.08, 0.08, 0.08), C_BLACK)
	for side: float in [-1.0, 1.0]:
		p.ball(Vector3(side * 0.15, 0.48, 0.72), Vector3.ONE * 0.06, C_BLACK)
		p.ball(Vector3(side * 0.22, 0.08, 0.25), Vector3(0.1, 0.08, 0.14), Color("f2c98a"))
	return _animal("Hedgehog", p)

func _bunny() -> Node3D:
	var p := ToyParts.new(0.8)
	p.ball(Vector3(0, 0.45, -0.05), Vector3(0.38, 0.42, 0.5), C_WHITE)
	p.ball(Vector3(0, 0.88, 0.3), Vector3(0.3, 0.28, 0.3), C_WHITE)
	for side: float in [-1.0, 1.0]:
		var ear := Basis(Vector3.FORWARD, side * 0.2) * Basis(Vector3.RIGHT, -0.25)
		p.ball(Vector3(side * 0.13, 1.35, 0.22), Vector3(0.09, 0.4, 0.06), C_WHITE, ear)
		p.ball(Vector3(side * 0.13, 1.35, 0.27), Vector3(0.05, 0.3, 0.03), C_PINK, ear)
		p.ball(Vector3(side * 0.13, 0.95, 0.56), Vector3.ONE * 0.05, C_BLACK)
		p.ball(Vector3(side * 0.18, 0.1, 0.2), Vector3(0.12, 0.08, 0.22), C_WHITE)
	p.ball(Vector3(0, 0.84, 0.6), Vector3(0.06, 0.05, 0.04), C_PINK)
	p.ball(Vector3(0, 0.45, -0.55), Vector3.ONE * 0.14, Color("ffd2e2"))
	return _animal("Bunny", p)

func _squirrel() -> Node3D:
	var p := ToyParts.new(0.8)
	var fur := Color("e8541b")
	p.ball(Vector3(0, 0.42, 0), Vector3(0.3, 0.38, 0.42), fur)
	p.ball(Vector3(0, 0.38, 0.18), Vector3(0.2, 0.26, 0.24), C_CREAM)
	p.ball(Vector3(0, 0.82, 0.28), Vector3(0.26, 0.24, 0.26), fur)
	p.ball(Vector3(0, 0.76, 0.5), Vector3(0.12, 0.1, 0.08), C_CREAM)
	for side: float in [-1.0, 1.0]:
		p.cylinder(Vector3(side * 0.13, 1.08, 0.24), 0.0, 0.08, 0.2, fur)
		p.ball(Vector3(side * 0.11, 0.88, 0.5), Vector3.ONE * 0.05, C_BLACK)
	# The big bushy tail curling up behind.
	for k in 4:
		var a := k * 0.55
		p.ball(Vector3(0, 0.35 + sin(a) * 0.75, -0.45 - cos(a) * 0.3 + k * 0.05), Vector3.ONE * (0.3 - k * 0.02), fur.lightened(0.08 * (k % 2)))
	return _animal("Squirrel", p)

static func _animal(animal_name: String, parts: ToyParts) -> Node3D:
	var node := Node3D.new()
	node.name = animal_name
	node.add_child(parts.build())
	return node
