class_name PillowFort extends Node3D
## Wohnzimmer's signature moment: the sofa-cushion jump as a pillow fort. Cushion towers and a
## flag garland come from tools/track_moments.gd; this script adds the giant teddy who sits by
## the landing, turns his head after the nearest player and throws both arms up while a kart
## flies, and the feathers that puff out of the cushion where a kart lands.
## Nothing here has collision: it can never touch, stop or block a kart.

@export var teddy_spot := Vector3.ZERO      ## floor point under the teddy
@export var teddy_facing := Vector3.FORWARD ## flat direction the teddy looks (toward the road)
@export var lip_point := Vector3.ZERO       ## road centre at the jump's lip

const C_FUR := Color("e07a1f")
const C_CREAM := Color("ffe0a6")
const C_PINK := Color("ff6f9c")
const C_RED := Color("e3241b")
const C_BLACK := Color("1c1d24")
const C_WHITE := Color("f4f6fb")
const FEATHER_COLORS: Array[Color] = [Color("f4f6fb"), Color("ffd2e2"), Color("ff8fb8"), Color("8fd4ff")]

const REACH := 48.0          ## a kart flying closer than this to the lip makes the teddy cheer
const FEATHERS := 36
const FEATHERS_PER_LANDING := 9
const FEATHER_LIFE := 2.4
const HEAD_TURN := 1.1       ## radians the head turns at most to each side

var _head: Node3D
var _arms: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _cheer := 0.0
var _blink_in := 3.0
var _time := 0.0
var _look_yaw := 0.0

## Karts as plain nodes: this script is built into the track by a tool script, which cannot
## compile the Kart class (it uses the Game autoload).
var _karts: Array[Node3D] = []
var _was_air := {}           ## kart -> it was flying off the ramp last frame
var _cams: Array[Camera3D] = []
var _scan_wait := 0.0

var _feathers: Array[MeshInstance3D] = []
var _f_vel: Array[Vector3] = []
var _f_age := PackedFloat32Array()
var _f_spin: Array[Vector3] = []
var _f_next := 0
var _pop: AudioStreamPlayer3D

func _ready() -> void:
	_build_teddy()
	var feather_mesh := SphereMesh.new()
	feather_mesh.radius = 0.5
	feather_mesh.height = 1.0
	feather_mesh.radial_segments = 8
	feather_mesh.rings = 4
	for k in FEATHERS:
		var feather := MeshInstance3D.new()
		feather.mesh = feather_mesh
		var color := FEATHER_COLORS[k % FEATHER_COLORS.size()]
		var mat := ToyParts.material(color, 0.9).duplicate() as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.25
		feather.material_override = mat
		feather.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		feather.top_level = true
		feather.visible = false
		add_child(feather)
		_feathers.append(feather)
		_f_vel.append(Vector3.ZERO)
		_f_spin.append(Vector3.ZERO)
		_f_age.append(FEATHER_LIFE)
	_pop = AudioStreamPlayer3D.new()
	_pop.stream = load("res://assets/sfx/pop.wav")
	_pop.bus = &"Effects"
	_pop.volume_db = -6.0
	_pop.unit_size = 12.0
	_pop.max_distance = 90.0
	_pop.top_level = true
	add_child(_pop)

func _process(delta: float) -> void:
	_time += delta
	_scan(delta)
	var flying := false
	for kart in _karts.duplicate():
		if not is_instance_valid(kart):
			_karts.erase(kart)
			continue
		var air: bool = kart.call("in_ramp_air")
		var at: Vector3 = (kart.get("sphere") as Node3D).global_position
		var near := at.distance_to(lip_point) < REACH
		if air and near:
			flying = true
		if _was_air.get(kart, false) and not air and near:
			_burst(at)
		_was_air[kart] = air
	_cheer = move_toward(_cheer, 1.0 if flying else 0.0, delta * (4.0 if flying else 1.2))
	_pose(delta)
	_update_feathers(delta)

func _scan(delta: float) -> void:
	_scan_wait -= delta
	if (_karts.is_empty() or _cams.is_empty()) and _scan_wait <= 0.0:
		_scan_wait = 1.0
		_karts.clear()
		for node in get_tree().root.find_children("*", "Kart", true, false):
			_karts.append(node as Node3D)
		_cams.clear()
		for node in get_tree().root.find_children("*", "Camera3D", true, false):
			_cams.append(node as Camera3D)

# --- The teddy ---------------------------------------------------------------------------------

## Teddy local space: +Z looks at the road, the floor is y = 0. About 10 m tall sitting.
func _build_teddy() -> void:
	var teddy := Node3D.new()
	teddy.name = "Teddy"
	teddy.top_level = true
	var x := Vector3.UP.cross(teddy_facing).normalized()
	teddy.transform = Transform3D(Basis(x, Vector3.UP, teddy_facing), teddy_spot)
	add_child(teddy)

	var body := ToyParts.new(0.95)
	body.ball(Vector3(0, 2.9, 0), Vector3(2.4, 2.9, 2.1), C_FUR)
	body.ball(Vector3(0, 2.6, 0.9), Vector3(1.7, 2.0, 1.35), C_CREAM)
	for side: float in [-1.0, 1.0]:
		# Legs stretched out in front, soles toward the road.
		body.ball(Vector3(side * 1.35, 1.0, 1.7), Vector3(1.0, 0.95, 1.7), C_FUR)
		body.ball(Vector3(side * 1.35, 1.05, 3.3), Vector3(0.82, 0.82, 0.22), C_CREAM)
		body.ball(Vector3(side * 1.35, 0.9, 3.45), Vector3(0.36, 0.3, 0.08), C_PINK)
	# A red bow tie under the chin.
	for side: float in [-1.0, 1.0]:
		body.ball(Vector3(side * 0.55, 5.05, 1.75), Vector3(0.6, 0.42, 0.22), C_RED, Basis(Vector3.FORWARD, side * 0.25))
	body.ball(Vector3(0, 5.05, 1.9), Vector3(0.25, 0.25, 0.2), C_RED.darkened(0.15))
	teddy.add_child(body.build())

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 6.5, 0.2)
	teddy.add_child(_head)
	var head := ToyParts.new(0.95)
	head.ball(Vector3.ZERO, Vector3(2.05, 1.85, 1.9), C_FUR)
	head.ball(Vector3(0, -0.55, 1.5), Vector3(1.0, 0.72, 0.72), C_CREAM)
	head.ball(Vector3(0, -0.2, 2.15), Vector3(0.36, 0.28, 0.22), C_BLACK)
	for side: float in [-1.0, 1.0]:
		head.ball(Vector3(side * 1.45, 1.45, -0.1), Vector3(0.8, 0.8, 0.45), C_FUR)
		head.ball(Vector3(side * 1.45, 1.45, 0.25), Vector3(0.5, 0.5, 0.15), C_PINK)
		head.ball(Vector3(side * 1.25, -0.55, 1.3), Vector3(0.38, 0.26, 0.12), C_PINK)
		# A smile: little dark beads in a curve under the nose.
		for k in 3:
			var a := (k + 1) * 0.28
			head.ball(Vector3(side * sin(a) * 0.45, -0.85 - (1.0 - cos(a)) * 0.6 + 0.1, 2.0 - k * 0.07), Vector3.ONE * 0.08, C_BLACK)
	_head.add_child(head.build())
	for side: float in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side * 0.72, 0.4, 1.62)
		_head.add_child(eye)
		var parts := ToyParts.new(0.2, 0.6)
		parts.ball(Vector3.ZERO, Vector3(0.34, 0.4, 0.22), C_BLACK)
		parts.ball(Vector3(0.1, 0.14, 0.18), Vector3.ONE * 0.1, C_WHITE)
		eye.add_child(parts.build(false))
		_eyes.append(eye)

	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0.0 else "ArmR"
		arm.position = Vector3(side * 2.05, 4.4, 0.3)
		teddy.add_child(arm)
		var parts := ToyParts.new(0.95)
		parts.ball(Vector3(0, -1.5, 0), Vector3(0.85, 1.75, 0.85), C_FUR)
		parts.ball(Vector3(0, -2.9, 0.35), Vector3(0.6, 0.45, 0.55), C_CREAM)
		arm.add_child(parts.build())
		_arms.append(arm)

func _pose(delta: float) -> void:
	# Arms: resting on the belly, up in the air (with a happy wiggle) while a kart flies.
	var breathe := 0.04 * sin(_time * 1.6)
	for k in _arms.size():
		var side := -1.0 if k == 0 else 1.0
		var rest := Vector3(-0.35, 0.0, side * 0.35)
		var up := Vector3(0.15, 0.0, side * (PI - 0.45 + 0.18 * sin(_time * 11.0 + k * PI)))
		var r := rest.lerp(up, _ease(_cheer))
		_arms[k].rotation = r + Vector3(breathe, 0.0, 0.0)
	# Head: turns after the nearest player camera, tilts happily when cheering.
	var target := _nearest_cam()
	var yaw := 0.0
	if target != Vector3.INF:
		var local := _head.get_parent_node_3d().to_local(target) - _head.position
		yaw = clampf(atan2(local.x, local.z), -HEAD_TURN, HEAD_TURN)
	_look_yaw = lerpf(_look_yaw, yaw, 1.0 - exp(-3.0 * delta))
	_head.rotation = Vector3(-0.08 * _cheer, _look_yaw, 0.12 * _cheer * sin(_time * 7.0))
	# Blink now and then.
	_blink_in -= delta
	var squash := 1.0
	if _blink_in < 0.0:
		squash = 0.15
		if _blink_in < -0.14:
			_blink_in = randf_range(2.0, 4.5)
	for eye in _eyes:
		eye.scale = Vector3(1.0, squash, 1.0)

static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func _nearest_cam() -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for cam in _cams:
		if not is_instance_valid(cam):
			continue
		var d := cam.global_position.distance_squared_to(teddy_spot)
		if d < best_d:
			best_d = d
			best = cam.global_position
	return best

# --- Feathers ----------------------------------------------------------------------------------

func _burst(at: Vector3) -> void:
	for k in FEATHERS_PER_LANDING:
		var i := _f_next
		_f_next = (_f_next + 1) % FEATHERS
		var a := randf() * TAU
		_f_vel[i] = Vector3(cos(a) * randf_range(1.5, 3.5), randf_range(4.0, 7.0), sin(a) * randf_range(1.5, 3.5))
		_f_spin[i] = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
		_f_age[i] = 0.0
		_feathers[i].global_position = at + Vector3(randf_range(-0.6, 0.6), 0.3, randf_range(-0.6, 0.6))
		_feathers[i].visible = true
	_pop.global_position = at
	_pop.pitch_scale = randf_range(0.8, 1.0)
	_pop.play()

func _update_feathers(delta: float) -> void:
	for i in FEATHERS:
		if _f_age[i] >= FEATHER_LIFE:
			continue
		_f_age[i] += delta
		var t := _f_age[i] / FEATHER_LIFE
		var feather := _feathers[i]
		if t >= 1.0:
			feather.visible = false
			continue
		# Shoot up, then float down slowly, swaying like a real feather.
		var v := _f_vel[i]
		v.y = maxf(v.y - 9.0 * delta, -1.2)
		v.x *= exp(-1.5 * delta)
		v.z *= exp(-1.5 * delta)
		_f_vel[i] = v
		var sway := Vector3(cos(_time * 4.0 + i), 0.0, sin(_time * 3.3 + i * 1.7)) * 0.9 * t
		feather.global_position += (v + sway) * delta
		var spin := _f_spin[i] * t
		var size := 1.0 if t < 0.8 else (1.0 - t) / 0.2
		feather.global_basis = Basis.from_euler(spin + Vector3(0.0, _time * 2.0 + i, 0.0)).scaled(Vector3(0.55, 0.08, 0.22) * maxf(size, 0.01))
