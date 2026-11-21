class_name Kart extends Node3D
## Arcade kart, based on the Kenney Starter Kit Racing vehicle: a rolling physics ball does the
## driving, the visible kart follows it. The kart never reads devices; it only sees an Intent
## that already went through the assist layer.

signal bumped(strength: float)
signal boost_started
signal honked
signal item_changed(has_item: bool)

const BASE_DRIVE := 100.0        ## kit value: ball spin-up per unit of throttle
const BASE_TOP_SPEED := 12.5     ## m/s reached at speed multiplier 1.0
const STEER_RATE := 4.0          ## rad/s at full steer
const SPHERE_OFFSET := 0.65      ## visible kart sits this far below the ball centre
const DRIFT_STEER := 1.45
const DRIFT_BOOST_AFTER := 1.0   ## seconds of drifting that earn a mini boost

@onready var sphere: RigidBody3D = $Sphere
@onready var raycast: RayCast3D = $Ground
@onready var container: Node3D = $Container
@onready var visual: KartVisual = $Container/Visual
@onready var trail_left: GPUParticles3D = $Container/TrailLeft
@onready var trail_right: GPUParticles3D = $Container/TrailRight
@onready var sparkles: GPUParticles3D = $Container/Sparkles
@onready var screech_sound: AudioStreamPlayer3D = $Container/ScreechSound
@onready var engine_sound: AudioStreamPlayer3D = $Container/EngineSound
@onready var impact_sound: AudioStreamPlayer3D = $Container/ImpactSound
@onready var horn_sound: AudioStreamPlayer3D = $Container/HornSound
@onready var boost_sound: AudioStreamPlayer3D = $Container/BoostSound
@onready var marker: MeshInstance3D = $Container/Marker

## Set every physics tick by the racer.
var intent := Intent.new()

var frozen := true               ## true until the countdown ends
var class_factor := 1.0          ## speed class: Kid 0.7, Normal 1.0, Fast 1.3
var pace := 1.0                  ## AI pacing
var catchup := 0.0               ## 0..0.3 extra top speed for a kid who is behind
var engine_db_offset := 0.0      ## AI karts are quieter
var has_item := false

var kart_def: KartDef
var driver_def: DriverDef

# Driving state (names follow the Kenney kit)
var input := Vector3.ZERO        ## x = steer, z = throttle
var linear_speed := 0.0          ## smoothed throttle, about -0.5..1
var angular_speed := 0.0
var acceleration := 0.0
var colliding := false
var linear_velocity := Vector3.ZERO
var calculated_lean := 0.0
var drifting := false

var _boost_left := 0.0
var _boost_strength := 0.0
var _drift_time := 0.0
var _prev_position := Vector3.ZERO
var _normal := Vector3.UP
var _marker_time := 0.0
var _placed := false

func _ready() -> void:
	sphere.body_entered.connect(_on_sphere_body_entered)
	sparkles.emitting = false
	marker.visible = false

# --- Setup ---------------------------------------------------------------------------------

func setup(p_kart: KartDef, p_driver: DriverDef) -> void:
	kart_def = p_kart
	driver_def = p_driver
	visual.build(kart_def, driver_def)
	if kart_def and kart_def.engine_sound:
		engine_sound.stream = kart_def.engine_sound
		engine_sound.play()
	if kart_def:
		horn_sound.pitch_scale = kart_def.horn_pitch

## Shows a floating arrow in the player's colour above the kart.
func set_marker_color(color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	marker.material_override = mat
	marker.visible = true

## Put the kart on the ground at a transform (+Z = forward) and stop it.
func place(xform: Transform3D) -> void:
	global_transform = Transform3D.IDENTITY
	sphere.linear_velocity = Vector3.ZERO
	sphere.angular_velocity = Vector3.ZERO
	sphere.global_position = xform.origin + Vector3(0, 0.5, 0)
	container.global_basis = xform.basis.orthonormalized()
	container.position = sphere.position - Vector3(0, SPHERE_OFFSET, 0)
	raycast.position = sphere.position
	_prev_position = container.position
	linear_speed = 0.0
	angular_speed = 0.0
	acceleration = 0.0
	linear_velocity = Vector3.ZERO
	input = Vector3.ZERO
	_placed = true
	reset_physics_interpolation()

# --- Queries -------------------------------------------------------------------------------

func ground_position() -> Vector3:
	return container.global_position

func forward() -> Vector3:
	return container.global_basis.z

## Actual speed over ground in m/s.
func speed() -> float:
	var v := sphere.linear_velocity
	return Vector2(v.x, v.z).length()

func speed_multiplier() -> float:
	var stat := kart_def.top_speed if kart_def else 1.0
	var boost := _boost_strength if _boost_left > 0.0 else 0.0
	return class_factor * stat * pace * (1.0 + catchup) * (1.0 + boost)

## Top speed in m/s without boost or catch-up.
func top_speed() -> float:
	return BASE_TOP_SPEED * class_factor * (kart_def.top_speed if kart_def else 1.0)

func is_boosting() -> bool:
	return _boost_left > 0.0

# --- Actions -------------------------------------------------------------------------------

func boost(duration := 1.6, strength := 0.5) -> void:
	_boost_left = maxf(_boost_left, duration)
	_boost_strength = maxf(strength, _boost_strength if _boost_left > 0.0 else 0.0)
	linear_speed = maxf(linear_speed, 1.0)
	sparkles.emitting = true
	boost_sound.play()
	if visual.driver:
		visual.driver.hop(0.8)
	boost_started.emit()

func give_item() -> void:
	if not has_item:
		has_item = true
		item_changed.emit(true)

func use_item() -> void:
	if has_item:
		has_item = false
		item_changed.emit(false)
		boost()

func honk() -> void:
	horn_sound.play()
	if visual.driver:
		visual.driver.hop()
	honked.emit()

## Sideways shove in m/s, used for soft kart-to-kart bumps.
func push(velocity_change: Vector3) -> void:
	sphere.apply_central_impulse(velocity_change * sphere.mass)

## Gentle steady push in m/s², used for the kid-mode soft walls.
func nudge(accel: Vector3) -> void:
	sphere.apply_central_force(accel * sphere.mass)

# --- Physics -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _placed:
		return
	_handle_intent(delta)

	var direction := signf(linear_speed)
	if direction == 0.0:
		direction = signf(input.z) if absf(input.z) > 0.1 else 1.0

	var handling := kart_def.handling if kart_def else 1.0
	var steering_grip := clampf(absf(linear_speed), 0.2, 1.0)
	var steer_rate := STEER_RATE * handling * (DRIFT_STEER if drifting else 1.0)
	var target_angular := -input.x * steering_grip * steer_rate * direction
	angular_speed = lerpf(angular_speed, target_angular, delta * 4.0)
	container.rotate_y(angular_speed * delta)

	# Ground alignment
	if raycast.is_colliding():
		if not colliding:
			if visual.body:
				visual.body.position = visual.body_rest - Vector3(0, 0.1, 0)  # landing bounce
			input.z = 0.0
		_normal = raycast.get_collision_normal()
		if _normal.dot(container.global_basis.y) > 0.5:
			var xform := _align_with_y(container.global_transform, _normal)
			container.global_transform = container.global_transform.interpolate_with(xform, 0.2).orthonormalized()
	colliding = raycast.is_colliding()

	var accel_stat := kart_def.acceleration if kart_def else 1.0
	var target_speed := input.z
	if target_speed < 0.0 and linear_speed > 0.01:
		linear_speed = lerpf(linear_speed, 0.0, delta * 8.0)
	elif target_speed < 0.0:
		linear_speed = lerpf(linear_speed, target_speed / 2.0, delta * 2.0)
	else:
		linear_speed = lerpf(linear_speed, target_speed, delta * 6.0 * accel_stat)
	if _boost_left > 0.0:
		linear_speed = maxf(linear_speed, 1.0)

	acceleration = lerpf(acceleration, linear_speed + (absf(sphere.angular_velocity.length() * linear_speed) / 100.0), delta)

	# The ball drives; the kart model follows it.
	sphere.angular_velocity += container.global_basis.x * (linear_speed * BASE_DRIVE * speed_multiplier()) * delta
	container.position = sphere.position - Vector3(0, SPHERE_OFFSET, 0)
	raycast.position = sphere.position

	linear_velocity = (container.position - _prev_position) / delta
	_prev_position = container.position

	if _boost_left > 0.0:
		_boost_left -= delta
		if _boost_left <= 0.0:
			_boost_strength = 0.0
			sparkles.emitting = false

	_effect_engine(delta)
	_effect_body(delta)
	_effect_wheels(delta)
	_effect_trails(delta)
	_effect_marker(delta)

func _handle_intent(delta: float) -> void:
	if frozen:
		input = Vector3(intent.steer, 0.0, 0.0)
		drifting = false
		if intent.horn:
			honk()
		return
	if raycast.is_colliding():
		input.x = intent.steer
		input.z = intent.accelerate - intent.brake
	if intent.horn:
		honk()
	if intent.use:
		use_item()
	var want_drift := intent.drift and colliding and absf(input.x) > 0.25 and linear_speed > 0.4
	if want_drift:
		_drift_time += delta
	else:
		if drifting and _drift_time >= DRIFT_BOOST_AFTER:
			boost(0.7, 0.3)
		_drift_time = 0.0
	drifting = want_drift

# --- Effects (from the Kenney kit, extended) -----------------------------------------------

func _effect_body(delta: float) -> void:
	calculated_lean = lerp_angle(calculated_lean, -input.x / 5.0 * linear_speed, delta * 5.0)
	var body := visual.body
	if body:
		body.rotation.x = lerp_angle(body.rotation.x, -(linear_speed - acceleration) / 6.0, delta * 10.0)
		if visual.lean_node:
			# Bikes lean into the curve as a whole.
			visual.lean_node.rotation.z = lerp_angle(visual.lean_node.rotation.z, input.x * linear_speed * 0.6, delta * 3.0)
		else:
			body.rotation.z = calculated_lean
		var slide := -input.x * 0.35 if drifting else 0.0
		body.rotation.y = lerp_angle(body.rotation.y, slide, delta * 6.0)
		body.position = body.position.lerp(visual.body_rest, delta * 5.0)
	if visual.driver:
		visual.driver.animate(delta, input.x, absf(linear_speed), linear_speed - acceleration)

func _effect_wheels(delta: float) -> void:
	for wheel in visual.wheels:
		wheel.rotation.x += acceleration
	for wheel in visual.front_wheels:
		wheel.rotation.y = lerp_angle(wheel.rotation.y, -input.x / 1.5, delta * 10.0)
	if visual.fork:
		visual.fork.rotation.y = lerp_angle(visual.fork.rotation.y, -input.x / 1.5, delta * 5.0)

func _effect_engine(delta: float) -> void:
	var speed_factor := clampf(absf(linear_speed), 0.0, 1.0)
	var throttle_factor := clampf(absf(input.z), 0.0, 1.0)
	var target_volume := remap(speed_factor + (throttle_factor * 0.5), 0.0, 1.5, -15.0, -5.0) + engine_db_offset
	engine_sound.volume_db = lerpf(engine_sound.volume_db, target_volume, delta * 5.0)
	var target_pitch := remap(speed_factor, 0.0, 1.0, 0.5, 3.0) * lerpf(0.85, 1.15, clampf(class_factor - 0.5, 0.0, 1.0))
	if throttle_factor > 0.1:
		target_pitch += 0.2
	if _boost_left > 0.0:
		target_pitch += 0.5
	engine_sound.pitch_scale = lerpf(engine_sound.pitch_scale, target_pitch, delta * 2.0)

func _effect_trails(delta: float) -> void:
	var drift_intensity := absf(linear_speed - acceleration) + (absf(calculated_lean) * 2.0)
	if drifting:
		drift_intensity += 0.6
	var should_emit := drift_intensity > 0.25 and colliding
	trail_left.emitting = should_emit
	trail_right.emitting = should_emit
	var target_volume := -80.0
	if should_emit:
		target_volume = remap(clampf(drift_intensity, 0.25, 2.0), 0.25, 2.0, -14.0, -4.0) + engine_db_offset
	screech_sound.pitch_scale = lerpf(screech_sound.pitch_scale, clampf(absf(linear_speed), 1.0, 3.0), 0.1)
	screech_sound.volume_db = lerpf(screech_sound.volume_db, target_volume, 10.0 * delta)

func _effect_marker(delta: float) -> void:
	if not marker.visible:
		return
	_marker_time += delta
	marker.position.y = 1.75 + sin(_marker_time * 3.0) * 0.08
	marker.rotation.y += delta * 2.0

func _align_with_y(xform: Transform3D, new_y: Vector3) -> Transform3D:
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform

func _on_sphere_body_entered(_body: Node) -> void:
	var impact := absf(linear_velocity.dot(container.global_basis.z))
	if impact < 1.0:
		return
	if not impact_sound.playing:
		impact_sound.volume_db = clampf(remap(impact, 0.0, 6.0, -20.0, 0.0), -20.0, 0.0) + engine_db_offset
		impact_sound.play()
	if visual.driver:
		visual.driver.knock(clampf(impact * 0.4, 0.5, 3.0))
	bumped.emit(clampf(impact / 8.0, 0.0, 1.0))
