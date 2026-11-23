class_name ChaseCamera extends Camera3D
## Follows one kart from behind and above. One camera per player, each inside its own SubViewport.
## Split screen uses a higher, wider setup. Kid mode gets a calm camera: no shake, a smaller
## widening while boosting, a gentler swing.
##
## The camera hangs on a spring: it falls back a little when the kart speeds up and catches up
## when it slows down, swings out to show the kart's side in a drift, and follows hills and
## jumps a moment late, so landings feel soft instead of jerky.

const SPRING := 28.0             ## how hard the distance spring pulls (1/s²)
const SPRING_DAMPING := 0.75     ## below 1: a small overshoot when the kart brakes
const SPEED_PULL_BACK := 0.9     ## metres further back at top speed
const DRIFT_SWING := 0.22        ## radians the camera swings out in a drift
const HEIGHT_FOLLOW := 7.0       ## how fast the camera follows the kart up and down (1/s)

var target: Kart
var calm := false

var height := 2.7
var distance := 5.6
var look_ahead := 2.5
var base_fov := 62.0
var focus_height := 0.9

var _yaw := 0.0
var _shake := 0.0
var _fov_kick := 0.0
var _started := false
var _dist := 0.0
var _dist_vel := 0.0
var _swing := 0.0
var _focus_y := 0.0

func _ready() -> void:
	# The camera moves every rendered frame, following the kart's interpolated position.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	doppler_tracking = Camera3D.DOPPLER_TRACKING_IDLE_STEP
	fov = base_fov
	near = 0.2
	far = 1500.0

func use_split_screen_setup() -> void:
	height = 3.4
	distance = 5.8
	look_ahead = 2.2
	base_fov = 72.0
	focus_height = 1.1  # the halves are tall: aim a little higher so the road ahead shows
	fov = base_fov

func attach(kart: Kart) -> void:
	target = kart
	if not calm:
		kart.bumped.connect(func(strength: float) -> void: _shake = maxf(_shake, strength * 0.25))
		kart.boost_started.connect(func() -> void: _fov_kick = 14.0)
	_started = false

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	delta = minf(delta, 0.05)
	var xform := target.container.get_global_transform_interpolated()
	var fwd := xform.basis.z
	var target_yaw := atan2(fwd.x, fwd.z)
	if not _started:
		_yaw = target_yaw
		_dist = distance
		_dist_vel = 0.0
		_focus_y = xform.origin.y
		_started = true
	var follow := 3.0 if calm else 5.0
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-follow * delta))

	# Swing out in a drift: the camera moves toward the outside, showing the kart's side.
	var swing_target := 0.0
	if target.drifting or target.spark_tier > 0:
		swing_target = -target.input.x * DRIFT_SWING * (0.5 if calm else 1.0)
	_swing = lerpf(_swing, swing_target, 1.0 - exp(-3.0 * delta))

	# Distance on a spring: further back at speed, a little overshoot when braking.
	var top := maxf(target.top_speed() * 1.3, 0.1)
	var want_dist := distance + clampf(target.speed() / top, 0.0, 1.2) * SPEED_PULL_BACK
	var accel := (want_dist - _dist) * SPRING - _dist_vel * 2.0 * sqrt(SPRING) * SPRING_DAMPING
	_dist_vel += accel * delta
	_dist += _dist_vel * delta

	_focus_y = lerpf(_focus_y, xform.origin.y, 1.0 - exp(-HEIGHT_FOLLOW * delta))
	var yaw := _yaw + _swing
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	var focus := Vector3(xform.origin.x, _focus_y, xform.origin.z) + Vector3(0, focus_height, 0)
	var eye := focus - back * _dist + Vector3(0, height - focus_height, 0)
	if _shake > 0.001:
		eye += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-8.0 * delta))
	var ahead := Vector3(sin(_yaw), 0.0, cos(_yaw))
	look_at_from_position(eye, focus + ahead * look_ahead, Vector3.UP)
	# While boosting the view stays wide (the world rushes past), then eases back.
	var hold := (9.0 if calm else 12.0) if target.is_boosting() else 0.0
	var rate := 6.0 if _fov_kick < hold else 2.5
	_fov_kick = lerpf(_fov_kick, hold, 1.0 - exp(-rate * delta)) if absf(_fov_kick - hold) > 0.01 else hold
	fov = base_fov + _fov_kick
