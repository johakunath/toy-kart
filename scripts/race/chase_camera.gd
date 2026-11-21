class_name ChaseCamera extends Camera3D
## Follows one kart from behind and above. One camera per player, each inside its own SubViewport.
## Split screen uses a higher, wider setup. Kid mode gets a calm camera: no shake, no zoom kick.

var target: Kart
var calm := false

var height := 2.7
var distance := 5.6
var look_ahead := 2.5
var base_fov := 62.0

var _yaw := 0.0
var _shake := 0.0
var _fov_kick := 0.0
var _started := false

func _ready() -> void:
	# The camera moves every rendered frame, following the kart's interpolated position.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = base_fov
	near = 0.2
	far = 400.0

func use_split_screen_setup() -> void:
	height = 3.4
	distance = 5.8
	look_ahead = 2.2
	base_fov = 72.0
	fov = base_fov

func attach(kart: Kart) -> void:
	target = kart
	if not calm:
		kart.bumped.connect(func(strength: float) -> void: _shake = maxf(_shake, strength * 0.25))
		kart.boost_started.connect(func() -> void: _fov_kick = 9.0)
	_started = false

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var xform := target.container.get_global_transform_interpolated()
	var fwd := xform.basis.z
	var target_yaw := atan2(fwd.x, fwd.z)
	if not _started:
		_yaw = target_yaw
		_started = true
	var follow := 3.0 if calm else 5.0
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-follow * delta))
	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var focus := xform.origin + Vector3(0, 0.9, 0)
	var eye := focus - back * distance + Vector3(0, height - 0.9, 0)
	if _shake > 0.001:
		eye += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-8.0 * delta))
	look_at_from_position(eye, focus + back * look_ahead, Vector3.UP)
	_fov_kick = lerpf(_fov_kick, 0.0, 1.0 - exp(-2.5 * delta))
	fov = base_fov + _fov_kick
