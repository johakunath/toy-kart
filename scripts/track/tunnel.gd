class_name Tunnel extends Node3D
## Riesenrunde's signature moment: the road runs through a giant rainbow caterpillar, in at its
## mouth. Inside it is dim, with twinkling fairy lights, and your own engine echoes. Its eyes
## follow the karts and blink; its antennae wobble. The body comes from tools/track_moments.gd.
##
## The echo is per player: each camera that is inside switches on a light reverb on the bus its
## own kart's engine plays on ("Engines" with one player, "Player1"/"Player2" in split screen),
## so one player in the tunnel never makes the other half echo.

@export var entry_point := Vector3.ZERO  ## road centre at the mouth
@export var exit_point := Vector3.ZERO   ## road centre where it comes out

const ECHO_WET := 0.3
const ECHO_FADE := 5.0       ## 1/s
const DIM := 0.4             ## ambient light inside, as a share of outside
const EYE_REACH := 0.62      ## how far a pupil moves inside its eye

var _track: Track
var _s_in := 0.0
var _s_out := 0.0
var _cams: Array[Camera3D] = []
var _cam_index := {}         ## Camera3D -> sample index on the racing line
var _cam_dim := {}           ## Camera3D -> 0 (outside) .. 1 (deep inside)
var _cam_env := {}           ## Camera3D -> its own darker copy of the world environment
var _scan_wait := 0.0
var _echo := {}              ## bus name -> AudioEffectReverb this tunnel added
var _bulbs: Array[StandardMaterial3D] = []
var _eyes: Array[Node3D] = []
var _antennae: Array[Node3D] = []
var _antenna_rest: Array[Basis] = []
var _blink_in := 2.5
var _time := 0.0

func _ready() -> void:
	var body := get_node_or_null("Body") as MeshInstance3D
	if body and body.mesh:
		for k in range(1, body.mesh.get_surface_count()):
			var mat := body.mesh.surface_get_material(k) as StandardMaterial3D
			if mat:
				_bulbs.append(mat)
	for eye_name: String in ["EyeL", "EyeR"]:
		var eye := get_node_or_null(eye_name) as Node3D
		if eye:
			_eyes.append(eye)
	for antenna_name: String in ["AntennaL", "AntennaR"]:
		var antenna := get_node_or_null(antenna_name) as Node3D
		if antenna:
			_antennae.append(antenna)
			_antenna_rest.append(antenna.basis)

func _exit_tree() -> void:
	# Buses outlive the race: take the echo off again.
	for bus: StringName in _echo:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		for k in range(AudioServer.get_bus_effect_count(index) - 1, -1, -1):
			if AudioServer.get_bus_effect(index, k) == _echo[bus]:
				AudioServer.remove_bus_effect(index, k)
	_echo.clear()

func _process(delta: float) -> void:
	_time += delta
	_twinkle()
	_wobble()
	if _track == null:
		_track = get_parent() as Track
		if _track == null or _track.count == 0:
			_track = null
			return
		_s_in = _track.s_at(_track.closest_index(entry_point))
		_s_out = _track.s_at(_track.closest_index(exit_point))
	_scan_wait -= delta
	if _cams.is_empty() and _scan_wait <= 0.0:
		_scan_wait = 1.0
		for node in get_tree().root.find_children("*", "Camera3D", true, false):
			_cams.append(node as Camera3D)
	var wet := {}
	for cam in _cams.duplicate():
		if not is_instance_valid(cam):
			_cams.erase(cam)
			continue
		var index := _track.closest_index(cam.global_position, _cam_index.get(cam, -1))
		_cam_index[cam] = index
		var depth := _depth(_track.s_at(index))
		var bus := _engine_bus(cam)
		wet[bus] = maxf(wet.get(bus, 0.0), 1.0 if depth > 0.0 else 0.0)
		_dim_camera(cam, depth, delta)
	for bus: StringName in wet:
		_set_echo(bus, wet[bus], delta)
	_look_at_karts()

## 0 outside; inside it rises to 1 over the first few metres and falls again before the way out.
func _depth(s: float) -> float:
	var span := fposmod(_s_out - _s_in, _track.length)
	var into := fposmod(s - _s_in, _track.length)
	if into > span:
		return 0.0
	return clampf(minf(into, span - into) / 4.0, 0.0, 1.0)

## The bus this camera's own kart engine plays on.
static func _engine_bus(cam: Camera3D) -> StringName:
	var kart := cam.get("target") as Node
	if kart and kart.has_method("engine_bus"):
		return kart.call("engine_bus")
	return &"Engines"

func _set_echo(bus: StringName, target: float, delta: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var reverb := _echo.get(bus) as AudioEffectReverb
	if reverb == null:
		if target <= 0.0:
			return
		reverb = AudioEffectReverb.new()
		reverb.room_size = 0.5
		reverb.damping = 0.3
		reverb.spread = 0.7
		reverb.hipass = 0.2
		reverb.predelay_msec = 55.0
		reverb.predelay_feedback = 0.3
		reverb.dry = 1.0
		reverb.wet = 0.0
		AudioServer.add_bus_effect(index, reverb)
		_echo[bus] = reverb
	reverb.wet = lerpf(reverb.wet, target * ECHO_WET, 1.0 - exp(-ECHO_FADE * delta))
	for k in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, k) == reverb:
			AudioServer.set_bus_effect_enabled(index, k, reverb.wet > 0.005)

## Inside, the camera gets its own copy of the sky light turned down, so the tunnel is dim and
## the fairy lights shine; coming out, the daylight comes back.
func _dim_camera(cam: Camera3D, depth: float, delta: float) -> void:
	var dim: float = _cam_dim.get(cam, 0.0)
	dim = lerpf(dim, depth, 1.0 - exp(-4.0 * delta))
	_cam_dim[cam] = dim
	if dim < 0.01:
		if cam.environment != null and _cam_env.has(cam):
			cam.environment = null
		return
	var world := cam.get_world_3d()
	if world == null or world.environment == null:
		return
	var env := _cam_env.get(cam) as Environment
	if env == null:
		env = world.environment.duplicate() as Environment
		_cam_env[cam] = env
	var outside := world.environment
	env.ambient_light_energy = outside.ambient_light_energy * lerpf(1.0, DIM, dim)
	env.tonemap_exposure = outside.tonemap_exposure * lerpf(1.0, 0.85, dim)
	cam.environment = env

func _twinkle() -> void:
	for k in _bulbs.size():
		_bulbs[k].emission_energy_multiplier = 2.2 + 1.6 * sin(_time * 3.0 + k * 1.7)

func _wobble() -> void:
	for k in _antennae.size():
		var swing := 0.12 * sin(_time * 2.6 + k * 1.9)
		_antennae[k].basis = _antenna_rest[k] * Basis(Vector3.FORWARD, swing) * Basis(Vector3.RIGHT, 0.06 * sin(_time * 3.4 + k))
	# Blink now and then: the eyes squash flat for a moment.
	_blink_in -= get_process_delta_time()
	var squash := 1.0
	if _blink_in < 0.0:
		squash = 0.12
		if _blink_in < -0.13:
			_blink_in = randf_range(2.0, 4.5)
	for eye in _eyes:
		eye.scale = Vector3(1.0, squash, 1.0)

## The pupils look at the nearest player camera.
func _look_at_karts() -> void:
	var best := Vector3.INF
	var best_d := INF
	for cam in _cams:
		if not is_instance_valid(cam):
			continue
		var d := cam.global_position.distance_squared_to(global_position + entry_point)
		if d < best_d:
			best_d = d
			best = cam.global_position
	if best == Vector3.INF:
		return
	for eye in _eyes:
		var pupil := eye.get_node_or_null("Pupil") as Node3D
		if pupil:
			var to := eye.to_local(best)
			if to.length() > 0.01:
				pupil.position = pupil.position.lerp(to.normalized() * EYE_REACH, 0.15)
