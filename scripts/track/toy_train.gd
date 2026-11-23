class_name ToyTrain extends Node3D
## Kurvenkurs' signature moment: a big toy train that chugs over a bridge high above the road,
## from one mountain tunnel to the other. It waits inside a mountain and sets off when a player
## is about to drive under the bridge, so every player sees it cross, puffing and whistling.
## The bridge, mountains and rail come from tools/track_moments.gd. Nothing here has collision:
## the train can never touch, stop or block a kart.

@export var rail_origin := Vector3.ZERO  ## rail top straight above the road centre
@export var rail_dir := Vector3.RIGHT    ## horizontal, along the rail (+ = toward portal_b)
@export var portal_a := -20.0            ## metres along the rail to the left mountain's portal
@export var portal_b := 20.0             ## ... and to the right one
@export var road_point := Vector3.ZERO   ## the road centre under the bridge

const SPEED := 8.0             ## m/s along the rail
const CAR_LENGTHS: Array[float] = [3.8, 2.8, 2.8, 2.8]
const CAR_GAP := 0.45
const CAMERA_LAG := 6.0        ## the chase camera hangs about this far behind its kart
const KART_BEFORE := 6.0       ## the train is over the road when the kart is this far before it
const LOOK_AHEAD := 130.0      ## a player further away than this does not start the train
const PUFF_EVERY := 0.17
const PUFF_LIFE := 1.5

var _cars: Array[Node3D] = []
var _axles: Array[Node3D] = []
var _length := 0.0
var _running := false
var _front := 0.0              ## where the train's nose is along the rail
var _dir := 1.0
var _crossed := false
var _rest := 0.0

var _track: Track
var _s_bridge := -1.0
var _cams: Array[Camera3D] = []
var _cam_index := {}           ## Camera3D -> sample index on the racing line
var _cam_speed := {}           ## Camera3D -> metres per second along the line
var _scan_wait := 0.0

var _whistle: AudioStreamPlayer3D
var _chug: AudioStreamPlayer3D
var _puffs: Array[MeshInstance3D] = []
var _puff_age := PackedFloat32Array()
var _puff_next := 0
var _puff_timer := 0.0
var _time := 0.0
var _materials := {}
var _loco: Node3D

func _ready() -> void:
	for k in CAR_LENGTHS.size():
		var car := _make_loco() if k == 0 else _make_wagon(k)
		car.name = "Loco" if k == 0 else "Wagon%d" % k
		add_child(car)
		_cars.append(car)
		_length += CAR_LENGTHS[k] + (CAR_GAP if k > 0 else 0.0)
		car.visible = false
	_whistle = _sound("res://assets/sfx/train_whistle.wav", 2.0, false)
	_chug = _sound("res://assets/sfx/train_chug.wav", -3.0, true)
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 0.45
	puff_mesh.height = 0.9
	puff_mesh.radial_segments = 10
	puff_mesh.rings = 6
	var puff_mat := StandardMaterial3D.new()
	puff_mat.albedo_color = Color(1, 1, 1)
	puff_mat.roughness = 1.0
	puff_mat.emission_enabled = true
	puff_mat.emission = Color(0.85, 0.9, 1.0)
	puff_mat.emission_energy_multiplier = 0.35
	puff_mesh.material = puff_mat
	for k in 14:
		var puff := MeshInstance3D.new()
		puff.mesh = puff_mesh
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.top_level = true
		puff.visible = false
		add_child(puff)
		_puffs.append(puff)
		_puff_age.append(PUFF_LIFE)

func _process(delta: float) -> void:
	_time += delta
	_watch_players(delta)
	if _running:
		_drive(delta)
	else:
		_rest += delta
	_update_puffs(delta)

# --- When to go --------------------------------------------------------------------------------

## Follows every player camera along the racing line and starts the train in time for the first
## one coming up to the bridge.
func _watch_players(delta: float) -> void:
	if _track == null:
		_track = get_parent() as Track
		if _track == null or _track.count == 0:
			_track = null
			return
		_s_bridge = _track.s_at(_track.closest_index(road_point))
	_scan_wait -= delta
	if _cams.is_empty() and _scan_wait <= 0.0:
		_scan_wait = 1.0
		for node in get_tree().root.find_children("*", "Camera3D", true, false):
			_cams.append(node as Camera3D)
	var lead := (absf(portal_a if _dir < 0.0 else portal_b) + _length * 0.5) / SPEED  # seconds until the middle is over the road
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
		if _running or _rest < 0.5:
			continue
		var ahead := fposmod(_s_bridge - _track.s_at(index), _track.length)
		var gap := ahead - CAMERA_LAG - KART_BEFORE
		if ahead < LOOK_AHEAD and gap > -4.0 and gap / maxf(speed, 2.5) <= lead:
			_start()

func _start() -> void:
	_dir = -_dir  # every crossing goes the other way, the engine always in front
	_front = portal_a if _dir > 0.0 else portal_b
	_running = true
	_crossed = false
	for car in _cars:
		car.visible = true
	_whistle.play()
	_chug.play()

func _drive(delta: float) -> void:
	_front += _dir * SPEED * delta
	var forward := rail_dir * _dir
	var x := Vector3.UP.cross(forward).normalized()
	var at := _front
	for k in _cars.size():
		var half := CAR_LENGTHS[k] * 0.5
		at -= _dir * half
		var bob := 0.035 * absf(sin(_time * 9.0 + k * 1.3))
		var sway := 0.02 * sin(_time * 5.0 + k)
		var basis := Basis(x, Vector3.UP, forward) * Basis(Vector3.FORWARD, sway)
		_cars[k].transform = Transform3D(basis, rail_origin + rail_dir * at + Vector3.UP * bob)
		at -= _dir * (half + CAR_GAP)
	var spin := SPEED * delta / 0.34
	for axle in _axles:
		axle.rotate_object_local(Vector3.RIGHT, spin)
	# A second whistle right over the road.
	if not _crossed and _front * _dir > 0.0:
		_crossed = true
		_whistle.play()
	# Puffs from the chimney.
	_puff_timer -= delta
	if _puff_timer <= 0.0:
		_puff_timer = PUFF_EVERY
		var chimney := _front - _dir * 0.65
		if chimney > portal_a + 0.8 and chimney < portal_b - 0.8:
			_emit_puff(_cars[0].to_global(Vector3(0, 2.55, 1.25)))
	# Gone into the other mountain: hide and wait for the next player.
	var tail := _front - _dir * _length
	var exit := portal_b if _dir > 0.0 else portal_a
	if (tail - exit) * _dir > 0.6:
		_running = false
		_rest = 0.0
		for car in _cars:
			car.visible = false
		_chug.stop()

func _emit_puff(at: Vector3) -> void:
	var puff := _puffs[_puff_next]
	_puff_age[_puff_next] = 0.0
	_puff_next = (_puff_next + 1) % _puffs.size()
	puff.global_position = at
	puff.visible = true

func _update_puffs(delta: float) -> void:
	for k in _puffs.size():
		if _puff_age[k] >= PUFF_LIFE:
			continue
		_puff_age[k] += delta
		var t := _puff_age[k] / PUFF_LIFE
		var puff := _puffs[k]
		if t >= 1.0:
			puff.visible = false
			continue
		puff.global_position += Vector3(0.0, 1.8 * (1.0 - t), 0.0) * delta
		# Grows quickly into a round cotton ball, then shrinks away.
		var size := 0.6 + 1.2 * sqrt(t) if t < 0.7 else (0.6 + 1.2 * sqrt(0.7)) * (1.0 - t) / 0.3
		puff.scale = Vector3.ONE * maxf(size, 0.01)

# --- The train, built from toy shapes ---------------------------------------------------------

## Car local space: +Z is the front, the rail top is at y = 0.
func _make_loco() -> Node3D:
	var parts := {}
	var red := Color("e3241b")
	var blue := Color("2f7fe8")
	var yellow := Color("ffc81e")
	var black := Color("1c1d24")
	var white := Color("f4f6fb")
	_part(parts, red, _box_mesh(Vector3(1.7, 0.3, 3.7)), Vector3(0, 0.6, 0))
	_part(parts, black, _box_mesh(Vector3(1.5, 0.22, 0.14)), Vector3(0, 0.55, 1.9))
	_part(parts, black, _box_mesh(Vector3(1.5, 0.22, 0.14)), Vector3(0, 0.55, -1.9))
	# Boiler with yellow bands, a smiley face at the front.
	_part(parts, blue, _cylinder_mesh(0.58, 0.58, 2.3), Vector3(0, 1.3, 0.62), Basis(Vector3.RIGHT, PI * 0.5))
	for z: float in [-0.25, 0.55, 1.35]:
		_part(parts, yellow, _cylinder_mesh(0.62, 0.62, 0.12), Vector3(0, 1.3, z), Basis(Vector3.RIGHT, PI * 0.5))
	_part(parts, Color("dfe3ea"), _cylinder_mesh(0.54, 0.54, 0.08), Vector3(0, 1.3, 1.78), Basis(Vector3.RIGHT, PI * 0.5))
	for side: float in [-1.0, 1.0]:
		_part(parts, white, _sphere_mesh(0.14), Vector3(side * 0.2, 1.45, 1.82))
		_part(parts, black, _sphere_mesh(0.075), Vector3(side * 0.2, 1.45, 1.93))
		_part(parts, Color("ff7a9a"), _sphere_mesh(0.09), Vector3(side * 0.36, 1.2, 1.8))
	for k in 5:
		var a := lerpf(-0.9, 0.9, k / 4.0)
		_part(parts, black, _box_mesh(Vector3(0.09, 0.06, 0.06)), Vector3(sin(a) * 0.2, 1.17 - cos(a) * 0.08 + 0.08, 1.83))
	# Chimney (puffs come out at the top), dome, cab with windows and a yellow roof.
	_part(parts, black, _cylinder_mesh(0.3, 0.18, 0.75), Vector3(0, 2.2, 1.25))
	_part(parts, yellow, _sphere_mesh(0.28), Vector3(0, 1.85, 0.45))
	_part(parts, red, _box_mesh(Vector3(1.7, 1.35, 1.3)), Vector3(0, 1.4, -1.15))
	_part(parts, yellow, _box_mesh(Vector3(2.0, 0.16, 1.6)), Vector3(0, 2.15, -1.15))
	for side: float in [-1.0, 1.0]:
		_part(parts, Color("33415e"), _box_mesh(Vector3(0.04, 0.5, 0.75)), Vector3(side * 0.86, 1.62, -1.15))
	var car := _car(parts)
	for z: float in [-1.2, 0.0, 1.2]:
		_add_axle(car, z, 0.36, yellow, red)
	_loco = car
	return car

func _make_wagon(k: int) -> Node3D:
	var parts := {}
	var body: Color = [Color("ffc81e"), Color("3fb44a"), Color("9b4de0")][(k - 1) % 3]
	var black := Color("1c1d24")
	_part(parts, black, _box_mesh(Vector3(1.6, 0.25, 2.7)), Vector3(0, 0.55, 0))
	_part(parts, body, _box_mesh(Vector3(1.6, 0.14, 2.6)), Vector3(0, 0.74, 0))
	for side: float in [-1.0, 1.0]:
		_part(parts, body, _box_mesh(Vector3(0.12, 0.7, 2.6)), Vector3(side * 0.74, 1.12, 0))
		_part(parts, body, _box_mesh(Vector3(1.6, 0.7, 0.12)), Vector3(0, 1.12, side * 1.24))
		_part(parts, black, _box_mesh(Vector3(0.3, 0.14, 0.2)), Vector3(0, 0.55, side * 1.42))
	# Cargo: balls, toy blocks, a present.
	match k:
		1:
			var balls: Array[Color] = [Color("e3241b"), Color("2f7fe8"), Color("ff8a1e")]
			for n in 3:
				_part(parts, balls[n], _sphere_mesh(0.46), Vector3(0.1 * (n - 1), 1.4, -0.8 + 0.8 * n))
		2:
			var blocks: Array[Color] = [Color("e3241b"), Color("ffc81e"), Color("2f7fe8"), Color("ff5c8a")]
			for n in 4:
				_part(parts, blocks[n], _box_mesh(Vector3(0.62, 0.62, 0.62)), Vector3(0.0, 1.2 + 0.62 * (n / 2), -0.45 + 0.9 * (n % 2)), Basis(Vector3.UP, 0.3 * n))
		_:
			_part(parts, Color("e3241b"), _box_mesh(Vector3(1.2, 1.0, 1.6)), Vector3(0, 1.4, 0))
			_part(parts, Color("ffc81e"), _box_mesh(Vector3(1.24, 1.04, 0.22)), Vector3(0, 1.4, 0))
			_part(parts, Color("ffc81e"), _box_mesh(Vector3(0.22, 1.04, 1.64)), Vector3(0, 1.4, 0))
			_part(parts, Color("ffc81e"), _sphere_mesh(0.26), Vector3(0, 1.95, 0))
	var car := _car(parts)
	for z: float in [-0.85, 0.85]:
		_add_axle(car, z, 0.32, Color("e3241b"), Color("ffc81e"))
	return car

## Two wheels on one axle, turning together; a coloured pin on each wheel shows them roll.
func _add_axle(car: Node3D, z: float, radius: float, wheel: Color, pin: Color) -> void:
	var parts := {}
	for side: float in [-1.0, 1.0]:
		_part(parts, wheel, _cylinder_mesh(radius, radius, 0.16), Vector3(side * 0.78, 0, 0), Basis(Vector3.FORWARD, PI * 0.5))
		_part(parts, pin, _cylinder_mesh(0.09, 0.09, 0.08), Vector3(side * 0.88, radius * 0.55, 0), Basis(Vector3.FORWARD, PI * 0.5))
	var axle := _car(parts)
	axle.position = Vector3(0, radius, z)
	car.add_child(axle)
	_axles.append(axle)

func _car(parts: Dictionary) -> Node3D:
	var mesh := ArrayMesh.new()
	for color: Color in parts:
		var st := parts[color] as SurfaceTool
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(color))
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return node

func _part(parts: Dictionary, color: Color, mesh: PrimitiveMesh, at: Vector3, basis := Basis.IDENTITY) -> void:
	if not parts.has(color):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		parts[color] = st
	(parts[color] as SurfaceTool).append_from(mesh, 0, Transform3D(basis, at))

func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.35
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.5
	mat.clearcoat_roughness = 0.25
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.rim_tint = 0.85
	_materials[color] = mat
	return mat

static func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func _cylinder_mesh(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return mesh

static func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh

func _sound(path: String, volume: float, loop: bool) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	var stream := load(path) as AudioStreamWAV
	if stream and loop:
		stream = stream.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	player.stream = stream
	player.bus = &"Effects"
	player.volume_db = volume
	player.unit_size = 14.0
	player.max_distance = 140.0
	player.position = Vector3(0, 1.5, 1.0)
	_loco.add_child(player)
	return player
