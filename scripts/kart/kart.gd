class_name Kart extends Node3D
## Arcade kart, based on the Kenney Starter Kit Racing vehicle: a rolling physics ball does the
## driving, the visible kart follows it. The kart never reads devices; it only sees an Intent
## that already went through the assist layer.

signal bumped(strength: float)
signal boost_started
signal honked
signal item_changed(item: int)
## The kart used a tickle bubble: the race picks the target and flies the bubble.
signal tickle_thrown
signal bricks_changed(count: int)
signal spark_tier_changed(tier: int)
## A request for controller vibration (only human karts on a pad listen to it).
signal rumble_requested(weak: float, strong: float, seconds: float)

const BASE_DRIVE := 100.0        ## kit value: ball spin-up per unit of throttle
const BASE_TOP_SPEED := 12.5     ## m/s reached at speed multiplier 1.0
const STEER_RATE := 4.0          ## rad/s at full steer
const SPHERE_OFFSET := 0.65      ## visible kart sits this far below the ball centre
const DRIFT_STEER := 1.45
const STEER_RESPONSE := 7.0      ## how fast the steering reaches its target (1/s)
const GRIP := 0.85               ## 1 = drives on rails, 0 = the kit's free-rolling ball
const DRIFT_GRIP := 0.45
## Drift levels: seconds of drifting for blue, orange and purple sparks. Letting go fires a
## boost that grows with the level (Mario Kart style: the sparks show before the boost is ready).
const SPARK_TIERS: Array[float] = [0.5, 1.0, 2.0]
const SPARK_BOOST_SECONDS: Array[float] = [0.5, 0.9, 1.4]
const SPARK_BOOST_STRENGTH: Array[float] = [0.18, 0.26, 0.34]
const SPARK_COLORS: Array[Color] = [Color(0.25, 0.65, 1.0), Color(1.0, 0.55, 0.08), Color(0.85, 0.3, 1.0)]
const BOOST_FADE := 0.8          ## seconds a boost takes to fade back to normal speed
const START_BOOST_SECONDS := 1.0 ## gas held when "Los!" comes: a start boost, never a stall
const START_BOOST_STRENGTH := 0.3
const WALL_BOUNCE := 0.25        ## share of the speed into a wall that bounces back
const WALL_STEER := 0.5          ## how much a glancing wall hit turns the nose along the wall
## Arcade hills: this share of the pull of gravity along a slope is cancelled, so karts climb
## hills without stalling and roll down without running away.
const HILL_ASSIST := 0.8
const TRICK_MIN_AIR := 0.15      ## seconds in the air before a trick earns a landing boost
const TRICK_BOOST_SECONDS := 0.6
const TRICK_BOOST_STRENGTH := 0.2
const BOOST_KICK := 3.5          ## m/s added at once when a boost starts
const TURBO_SECONDS := 1.0
const TURBO_STRENGTH := 0.35
const SUPERSTAR_SECONDS := 2.2   ## long boost, and nothing can wobble the kart meanwhile
const SUPERSTAR_STRENGTH := 0.45
const BUBBLE_SECONDS := 12.0     ## a shield that pops one tickle
const SPRING_JUMP := 5.5         ## m/s straight up
const TRIPLE_TURBO_CHARGES := 3  ## a triple turbo fires three turbos, one per press
## Jump ramps: at the lip the kart is thrown up and floats a little, about 1 s in the air at
## Kid speed, with a barrel roll of the picture (never the physics ball) and a landing boost.
const RAMP_LAUNCH_UP := 6.0      ## m/s straight up at the lip (at RAMP_FULL_SPEED or faster)
const RAMP_FULL_SPEED := 8.0     ## m/s; slower karts get a smaller hop (down to half)
const RAMP_AIR_GRAVITY := 1.0    ## gravity scale in the air after a ramp (the ball's normal: 1.5)
const RAMP_AIR_STEER := 0.7      ## share of the steering that turns the kart in the air
const RAMP_GUIDE_RATE := 1.2     ## rad/s the flight turns toward the road ahead (lands on the road)
const RAMP_TRICK_SECONDS := 0.75 ## the barrel roll
const RAMP_TRICK_LIFT := 0.35    ## metres the picture rises during the roll
const RAMP_TRICK_PIVOT := 0.45   ## height of the roll axis above the wheels
const WOBBLE_SECONDS := 0.7
const MAX_BRICKS := 10           ## bricks held at once; each gives 1 % more top speed
const BRICK_SPEED := 0.01
const BOOST_PUSH := 22.0         ## m/s² pushing the kart up to its boost speed
const BALL_RADIUS := 0.5

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
var class_factor := 1.0          ## speed class: Game.SPEED_FACTOR
var pace := 1.0                  ## AI pacing
var catchup := 0.0               ## 0..0.3 extra top speed for a kid who is behind
var tow := 0.0                   ## 0..0.12 extra top speed from the magic rope behind dad (CoopHelp)
var engine_db_offset := 0.0      ## AI karts are quieter
var item := Items.NONE
var has_item: bool:
	get:
		return item != Items.NONE
## Set by the race: returns the item this kart gets from a star (Items.pick with its odds).
var item_picker := Callable()
var wobbles := 0                 ## how often the kart was tickled (the checks report it)
var bricks := 0                  ## held now (0..MAX_BRICKS)
var bricks_picked := 0           ## picked up this race (for the family jar)
## Off for AI karts in a race with a kid: their pacing around him must not be beaten by bricks.
var brick_bonus := true
var wall_hits := 0              ## how often the kart hit a wall hard (for the checks)
## Kid mode: steering hard (intent.spark) charges sparks too, up to this level.
var max_spark_tier := 3
## Kid mode: a start boost even without gas.
var free_start_boost := false
## Kid mode and AI: a trick in the air happens by itself (others press drift, use or horn).
var auto_trick := false
var tricks := 0                  ## landed tricks (the checks report them)
var ramp_jumps := 0              ## launches off a jump ramp (the checks report them)
var best_air := 0.0              ## longest time in the air, seconds (the checks report it)
var items_got := 0               ## items picked up from stars (the checks report them)
var pad_boosts := 0              ## turbo arrows driven over (the checks report them)
var turbo_charges := 0           ## turbos left in a held triple turbo
## Kid assist: m/s above which a boost stops pushing (set before a bend; 0 = no limit).
var boost_cap := 0.0
var spark_tier := 0

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
var _boost_target := 0.0
var boost_time := 0.0            ## seconds spent boosting (smoke tests report it)
var _flames: GPUParticles3D
var _rumble: AudioStreamPlayer3D
var on_kerb := false             ## set by the assist; plays the kerb rumble         ## m/s the kart is pushed to while boosting
var _drift_time := 0.0
var _fade_left := 0.0
var _start_gas := false
var _was_frozen := true
var _sparks: Array[GPUParticles3D] = []
var _spark_sound: AudioStreamPlayer3D
var _air_time := 0.0
var _trick := false
var _spring_trick := false
var _ramp_air := false           ## launched off a ramp and not landed yet
var _ground_gravity := 1.5
var _ramp_time := 0.0
var _shield_left := 0.0
var _star_left := 0.0
var _shield: MeshInstance3D
var _star_light: OmniLight3D
var _pop_sound: AudioStreamPlayer3D
## Engine sound: the recorded engine plus a high whine layer that fades in at speed.
## In split screen a player's own kart plays both without position on that player's bus
## (panned to their half); otherwise they are 3D sounds in the world.
var _engine_main: Node
var _engine_high: Node
var _prev_position := Vector3.ZERO
var _normal := Vector3.UP
var _marker_time := 0.0
var _placed := false

func _ready() -> void:
	sphere.body_entered.connect(_on_sphere_body_entered)
	_ground_gravity = sphere.gravity_scale
	sparkles.emitting = false
	marker.visible = false
	_build_flames()
	_build_sparks()
	_build_shield()
	var high := AudioStreamPlayer3D.new()
	high.name = "EngineHigh"
	high.stream = _looped(load("res://assets/sfx/engine_high.wav") as AudioStreamWAV)
	high.bus = &"Engines"
	high.volume_db = -60.0
	high.max_distance = 45.0
	container.add_child(high)
	_engine_main = engine_sound
	_engine_high = high
	_pop_sound = AudioStreamPlayer3D.new()
	_pop_sound.name = "PopSound"
	_pop_sound.stream = load("res://assets/sfx/pop.wav")
	_pop_sound.bus = &"Effects"
	_pop_sound.max_distance = 25.0
	container.add_child(_pop_sound)
	_spark_sound = AudioStreamPlayer3D.new()
	_spark_sound.name = "SparkSound"
	_spark_sound.stream = load("res://assets/sfx/select.wav")
	_spark_sound.bus = &"Effects"
	_spark_sound.max_distance = 30.0
	container.add_child(_spark_sound)
	_rumble = AudioStreamPlayer3D.new()
	_rumble.name = "RumbleSound"
	var rumble_stream := load("res://assets/sfx/rumble.wav") as AudioStreamWAV
	rumble_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	rumble_stream.loop_begin = 0
	rumble_stream.loop_end = int(rumble_stream.get_length() * rumble_stream.mix_rate)
	_rumble.stream = rumble_stream
	_rumble.bus = &"Effects"
	_rumble.volume_db = -80.0
	_rumble.max_distance = 30.0
	container.add_child(_rumble)

# --- Setup ---------------------------------------------------------------------------------

func setup(p_kart: KartDef, p_driver: DriverDef) -> void:
	kart_def = p_kart
	driver_def = p_driver
	visual.build(kart_def, driver_def)
	if kart_def and kart_def.engine_sound:
		engine_sound.stream = kart_def.engine_sound
		engine_sound.play()
		(_engine_high as AudioStreamPlayer3D).play()
	if kart_def:
		horn_sound.pitch_scale = kart_def.horn_pitch
		if driver_def:
			# Every driver honks a little differently (same driver, same horn every time).
			horn_sound.pitch_scale *= 0.86 + float(absi(hash(driver_def.id)) % 29) / 100.0

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
	_ramp_air = false
	sphere.gravity_scale = _ground_gravity
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
	var boost := 0.0 if _boost_capped() else _boost_factor()
	return class_factor * stat * pace * (1.0 + catchup + tow) * (1.0 + boost) * (1.0 + (bricks * BRICK_SPEED if brick_bonus else 0.0))

## Turn rate in rad/s at full steer.
func steer_rate() -> float:
	return STEER_RATE * (kart_def.handling if kart_def else 1.0)

## Top speed in m/s without boost or catch-up.
func top_speed() -> float:
	return BASE_TOP_SPEED * class_factor * (kart_def.top_speed if kart_def else 1.0)

func is_boosting() -> bool:
	return _boost_left > 0.0

func _boost_capped() -> bool:
	return boost_cap > 0.0 and speed() > boost_cap

## Extra top speed from a boost; after the boost it fades out instead of stopping hard.
func _boost_factor() -> float:
	if _boost_left > 0.0:
		return _boost_strength
	if _fade_left > 0.0:
		return _boost_strength * (_fade_left / BOOST_FADE)
	return 0.0

# --- Actions -------------------------------------------------------------------------------

func boost(duration := 1.6, strength := 0.5) -> void:
	# The ball alone takes too long to spin up, so a boost pushes the kart directly:
	# a kick at once, then a steady push up to (top speed x (1 + strength)).
	# Measured from the normal top speed, so boosts never stack on top of each other.
	var cruise := top_speed() * pace * (1.0 + catchup)
	_boost_target = maxf(_boost_target if _boost_left > 0.0 else 0.0, cruise * (1.0 + strength))
	_push_forward(clampf(boost_cap - speed(), 0.0, BOOST_KICK) if boost_cap > 0.0 else BOOST_KICK)
	_boost_strength = maxf(strength, _boost_strength if _boost_left > 0.0 else 0.0)
	_boost_left = maxf(_boost_left, duration)
	_fade_left = 0.0
	linear_speed = maxf(linear_speed, 1.0)
	sparkles.emitting = true
	_flames.emitting = true
	boost_sound.play()
	if visual.driver:
		visual.driver.hop(0.8)
	rumble_requested.emit(0.5, 0.7, 0.18)
	boost_started.emit()

## Blue, orange and purple sparks from the back wheels while a drift charges.
func _build_sparks() -> void:
	for side in [-1.0, 1.0]:
		var p := GPUParticles3D.new()
		p.name = "Sparks%s" % ("L" if side < 0.0 else "R")
		p.amount = 24
		p.lifetime = 0.25
		p.fixed_fps = 60
		p.emitting = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.position = Vector3(0.38 * side, 0.12, -0.5)
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0.6 * side, 0.9, -0.6)
		process.spread = 35.0
		process.initial_velocity_min = 2.0
		process.initial_velocity_max = 4.0
		process.gravity = Vector3(0, -9.0, 0)
		process.scale_min = 0.25
		process.scale_max = 0.5
		process.color = SPARK_COLORS[0]
		p.process_material = process
		var quad := QuadMesh.new()
		quad.size = Vector2(0.4, 0.4)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.albedo_texture = load("res://assets/fx/sparkle.png")
		quad.material = mat
		p.draw_pass_1 = quad
		container.add_child(p)
		_sparks.append(p)

func _set_spark_tier(tier: int) -> void:
	if tier == spark_tier:
		return
	spark_tier = tier
	for p in _sparks:
		p.emitting = tier > 0
		if tier > 0:
			(p.process_material as ParticleProcessMaterial).color = SPARK_COLORS[tier - 1] * 2.5
			p.amount_ratio = 0.5 + 0.25 * tier
	if tier > 0:
		_spark_sound.pitch_scale = 0.9 + 0.3 * tier
		_spark_sound.play()
		rumble_requested.emit(0.25 + 0.1 * tier, 0.0, 0.08)
	spark_tier_changed.emit(tier)

## Orange-blue flames out of the back while boosting: the boost must be seen, not only felt.
func _build_flames() -> void:
	_flames = GPUParticles3D.new()
	_flames.name = "BoostFlames"
	_flames.amount = 48
	_flames.lifetime = 0.35
	_flames.fixed_fps = 60
	_flames.emitting = false
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.position = Vector3(0, 0.35, -0.55)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 0.15, -1)
	process.spread = 12.0
	process.initial_velocity_min = 3.0
	process.initial_velocity_max = 5.0
	process.gravity = Vector3.ZERO
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.12
	process.scale_min = 0.6
	process.scale_max = 1.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.15))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	process.scale_curve = shrink_tex
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.2, 1.0))
	ramp.add_point(0.35, Color(1.0, 0.4, 0.05, 0.95))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.3, 0.5, 1.0, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	process.color_ramp = ramp_tex
	_flames.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = load("res://assets/fx/sparkle.png")
	quad.material = mat
	_flames.draw_pass_1 = quad
	container.add_child(_flames)

## Adds speed along the kart's nose and spins the ball to match, so it does not brake it.
func _push_forward(dv: float) -> void:
	var fwd := container.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return
	fwd = fwd.normalized()
	sphere.linear_velocity += fwd * dv
	sphere.angular_velocity += container.global_basis.x * (dv / BALL_RADIUS)

## Gets an item from a star. False when the hands are already full.
func give_item() -> bool:
	if item != Items.NONE:
		return false
	item = item_picker.call() if item_picker.is_valid() else Items.TURBO
	turbo_charges = TRIPLE_TURBO_CHARGES if item == Items.TRIPLE_TURBO else 0
	items_got += 1
	item_changed.emit(item)
	return true

## Turbo arrows on the road (BoostPad).
func pad_boost(duration: float, strength: float) -> void:
	pad_boosts += 1
	boost(duration, strength)

## Thrown up at a jump ramp's lip (the racer calls this as the kart crosses it).
func ramp_launch() -> void:
	if frozen or not colliding or _ramp_air:
		return
	var up := RAMP_LAUNCH_UP * clampf(speed() / RAMP_FULL_SPEED, 0.5, 1.0)
	sphere.linear_velocity.y = maxf(sphere.linear_velocity.y, up)
	sphere.gravity_scale = RAMP_AIR_GRAVITY
	_ramp_air = true
	_ramp_time = 0.0
	ramp_jumps += 1
	rumble_requested.emit(0.3, 0.5, 0.12)

## Hands the held item over (dad gives it to the kid); returns it, or Items.NONE.
func take_item() -> int:
	var held := item
	if held != Items.NONE:
		item = Items.NONE
		item_changed.emit(Items.NONE)
	return held

## Gets an item handed over by another player. False when the hands are already full.
func receive_item(gift: int) -> bool:
	if item != Items.NONE or gift == Items.NONE:
		return false
	item = gift
	turbo_charges = TRIPLE_TURBO_CHARGES if item == Items.TRIPLE_TURBO else 0
	item_changed.emit(item)
	return true

func use_item() -> void:
	if item == Items.NONE:
		return
	if item == Items.TRIPLE_TURBO:
		# One turbo per press; the item stays in the slot until the last one is used.
		turbo_charges -= 1
		boost(TURBO_SECONDS, TURBO_STRENGTH)
		if turbo_charges <= 0:
			item = Items.NONE
			item_changed.emit(Items.NONE)
		return
	var used := item
	item = Items.NONE
	item_changed.emit(Items.NONE)
	match used:
		Items.TURBO:
			boost(TURBO_SECONDS, TURBO_STRENGTH)
		Items.SUPERSTAR:
			boost(SUPERSTAR_SECONDS, SUPERSTAR_STRENGTH)
			_star_left = SUPERSTAR_SECONDS
			_star_light.visible = true
		Items.BUBBLE:
			_shield_left = BUBBLE_SECONDS
			_shield.visible = true
			_spark_sound.pitch_scale = 0.8
			_spark_sound.play()
		Items.SPRING:
			if colliding:
				sphere.linear_velocity.y = SPRING_JUMP
				_spring_trick = true
				impact_sound.volume_db = -8.0 + engine_db_offset
				impact_sound.pitch_scale = 1.6
				impact_sound.play()
		Items.TICKLE:
			tickle_thrown.emit()

## Hit by a tickle bubble: a shield pops, a superstar shrugs it off, otherwise the kart spins
## round twice with a giggle and loses only a little speed.
func wobble() -> void:
	if _star_left > 0.0:
		return
	if _shield_left > 0.0:
		_shield_left = 0.0
		_shield.visible = false
		boost_sound.pitch_scale = 1.4
		boost_sound.play()
		return
	wobbles += 1
	sphere.linear_velocity *= 0.9
	if bricks > 0:
		bricks -= 1
		bricks_changed.emit(bricks)
	if visual.driver:
		visual.driver.knock(2.0)
		visual.driver.hop(1.0)
	horn_sound.play()
	rumble_requested.emit(0.6, 0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(visual, "rotation:y", TAU * 2.0, WOBBLE_SECONDS).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: visual.rotation.y = 0.0)

func add_brick() -> void:
	bricks_picked += 1
	bricks = mini(bricks + 1, MAX_BRICKS)
	_pop_sound.pitch_scale = 1.0 + 0.06 * bricks
	_pop_sound.play()
	rumble_requested.emit(0.2, 0.0, 0.05)
	bricks_changed.emit(bricks)

## After a rescue: the kart's picture comes down onto the road from above (lowered by the rescue
## helicopter) with a little bounce. The kart itself is on the road already and can drive.
func drop_in(height := 2.5, seconds := 0.5) -> void:
	var tween := create_tween()
	tween.tween_property(visual, "position:y", 0.0, seconds).from(height).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_pop_sound.pitch_scale = 0.8
	_pop_sound.play()
	rumble_requested.emit(0.3, 0.4, 0.15)

func is_protected() -> bool:
	return _star_left > 0.0 or _shield_left > 0.0

## A see-through bubble around the kart (shield) and a warm light (superstar).
func _build_shield() -> void:
	_shield = MeshInstance3D.new()
	_shield.name = "Shield"
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.1
	sphere_mesh.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.8, 1.0, 0.25)
	mat.rim_enabled = true
	mat.rim = 1.0
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sphere_mesh.material = mat
	_shield.mesh = sphere_mesh
	_shield.position = Vector3(0, 0.6, 0)
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield.visible = false
	container.add_child(_shield)
	_star_light = OmniLight3D.new()
	_star_light.name = "StarLight"
	_star_light.light_color = Color(1.0, 0.8, 0.3)
	_star_light.light_energy = 3.0
	_star_light.omni_range = 3.5
	_star_light.position = Vector3(0, 1.2, 0)
	_star_light.visible = false
	container.add_child(_star_light)

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

	var steering_grip := clampf(absf(linear_speed), 0.2, 1.0)
	var rate := steer_rate() * (DRIFT_STEER if drifting else 1.0)
	var target_angular := -input.x * steering_grip * rate * direction
	if _ramp_air and not colliding:
		target_angular *= RAMP_AIR_STEER  # gentle air steering, so the kart lands on the road
	if frozen:
		target_angular = 0.0  # wheels turn during the countdown, the kart stays put
	angular_speed = lerpf(angular_speed, target_angular, minf(1.0, delta * STEER_RESPONSE))
	var turn := angular_speed * delta
	container.rotate_y(turn)
	# Grip: the ball's motion turns with the kart's nose. Without this the ball keeps rolling
	# the old way for a moment and the kart slides wide in every corner.
	if colliding:
		var grip_turn := turn * (DRIFT_GRIP if drifting else GRIP)
		sphere.angular_velocity = sphere.angular_velocity.rotated(Vector3.UP, grip_turn)
		sphere.linear_velocity = sphere.linear_velocity.rotated(Vector3.UP, grip_turn)
	elif _ramp_air:
		# Off a ramp the flight follows the nose too: a jump before a bend lands in the bend.
		sphere.linear_velocity = sphere.linear_velocity.rotated(Vector3.UP, turn * GRIP)

	# Ground alignment
	if raycast.is_colliding():
		if not colliding:
			if visual.body:
				visual.body.position = visual.body_rest - Vector3(0, 0.1, 0)  # landing bounce
			input.z = 0.0
			_land()
		_normal = raycast.get_collision_normal()
		if _normal.dot(container.global_basis.y) > 0.5:
			var xform := _align_with_y(container.global_transform, _normal)
			container.global_transform = container.global_transform.interpolate_with(xform, 0.2).orthonormalized()
	colliding = raycast.is_colliding()
	if _ramp_air:
		_ramp_time += delta
		if colliding and _ramp_time > 0.4:
			# Never left the ground (a slow kart): back to normal gravity.
			_ramp_air = false
			sphere.gravity_scale = _ground_gravity
	if not colliding and not frozen:
		_air_time += delta
		var pressed := intent.drift or intent.use or intent.horn
		best_air = maxf(best_air, _air_time)
		if not _trick and _air_time > 0.08 and (auto_trick or pressed or _spring_trick or _ramp_air):
			_start_trick()

	var accel_stat := kart_def.acceleration if kart_def else 1.0
	var target_speed := input.z
	if target_speed < 0.0 and linear_speed > 0.01:
		linear_speed = lerpf(linear_speed, 0.0, delta * 8.0)
	elif target_speed < 0.0:
		linear_speed = lerpf(linear_speed, target_speed / 2.0, delta * 2.0)
	else:
		linear_speed = lerpf(linear_speed, target_speed, delta * 6.0 * accel_stat)
	if _boost_left > 0.0 and not _boost_capped():
		linear_speed = maxf(linear_speed, 1.0)

	acceleration = lerpf(acceleration, linear_speed + (absf(sphere.angular_velocity.length() * linear_speed) / 100.0), delta)

	# The ball drives; the kart model follows it.
	sphere.angular_velocity += container.global_basis.x * (linear_speed * BASE_DRIVE * speed_multiplier()) * delta
	container.position = sphere.position - Vector3(0, SPHERE_OFFSET, 0)
	raycast.position = sphere.position

	linear_velocity = (container.position - _prev_position) / delta
	_prev_position = container.position

	if _boost_left > 0.0:
		var missing := (minf(_boost_target, boost_cap) if boost_cap > 0.0 else _boost_target) - speed()
		if missing > 0.0 and colliding:
			_push_forward(minf(missing, BOOST_PUSH * delta))
		elif colliding and _boost_capped():
			_push_forward(maxf(missing, -BOOST_PUSH * 0.5 * delta))  # boosted too fast into a bend
		_boost_left -= delta
		boost_time += delta
		if _boost_left <= 0.0:
			_fade_left = BOOST_FADE
			sparkles.emitting = false
			_flames.emitting = false
	elif _fade_left > 0.0:
		_fade_left -= delta
		if _fade_left <= 0.0:
			_boost_strength = 0.0

	_glance_off_walls()
	_hill_assist()
	if _shield_left > 0.0:
		_shield_left -= delta
		_shield.visible = _shield_left > 0.0 and (_shield_left > 2.0 or fmod(_shield_left, 0.3) > 0.12)
	if _star_left > 0.0:
		_star_left -= delta
		_star_light.light_energy = 2.0 + sin(_star_left * 20.0) * 1.5
		_star_light.visible = _star_left > 0.0

	_effect_engine(delta)
	_effect_rumble(delta)
	_effect_body(delta)
	_effect_wheels(delta)
	_effect_trails(delta)
	_effect_marker(delta)

func _handle_intent(delta: float) -> void:
	if frozen:
		input = Vector3(intent.steer, 0.0, 0.0)
		drifting = false
		_start_gas = intent.accelerate > 0.3
		_was_frozen = true
		if intent.horn:
			honk()
		return
	if _was_frozen:
		_was_frozen = false
		if _start_gas or free_start_boost:
			boost(START_BOOST_SECONDS, START_BOOST_STRENGTH)
			rumble_requested.emit(0.6, 1.0, 0.3)
	if raycast.is_colliding():
		input.x = intent.steer
		input.z = intent.accelerate - intent.brake
	if intent.horn:
		honk()
	if intent.use:
		use_item()
	var want_drift := intent.drift and colliding and absf(input.x) > 0.25 and linear_speed > 0.4
	# Kid mode: steering hard charges the sparks without sliding.
	var charging := want_drift or (intent.spark and colliding and linear_speed > 0.4)
	if intent.spark_cancel:
		_drift_time = 0.0
		_set_spark_tier(0)
	elif charging:
		_drift_time += delta
		var tier := 0
		for t in SPARK_TIERS.size():
			if _drift_time >= SPARK_TIERS[t] and t < max_spark_tier:
				tier = t + 1
		_set_spark_tier(tier)
	else:
		if spark_tier > 0:
			boost(SPARK_BOOST_SECONDS[spark_tier - 1], SPARK_BOOST_STRENGTH[spark_tier - 1])
		_drift_time = 0.0
		_set_spark_tier(0)
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
		wheel.rotation.x += acceleration * visual.wheel_spin_sign
	for wheel in visual.front_wheels:
		wheel.rotation.y = lerp_angle(wheel.rotation.y, -input.x / 1.5, delta * 10.0)
	if visual.fork:
		visual.fork.rotation.y = lerp_angle(visual.fork.rotation.y, -input.x / 1.5, delta * 5.0)

func _effect_rumble(delta: float) -> void:
	var loud := on_kerb and colliding and speed() > 2.0 and not frozen
	var target := (-6.0 + engine_db_offset) if loud else -60.0
	_rumble.volume_db = lerpf(_rumble.volume_db, target, delta * 12.0)
	_rumble.pitch_scale = clampf(0.6 + speed() / 15.0, 0.6, 1.6)
	if _rumble.volume_db > -50.0 and not _rumble.playing:
		_rumble.play()
	elif _rumble.volume_db <= -55.0 and _rumble.playing:
		_rumble.stop()

func _effect_engine(delta: float) -> void:
	var speed_factor := clampf(absf(linear_speed), 0.0, 1.0)
	var throttle_factor := clampf(absf(input.z), 0.0, 1.0)
	var target_volume := remap(speed_factor + (throttle_factor * 0.5), 0.0, 1.5, -15.0, -5.0) + engine_db_offset
	_engine_main.volume_db = lerpf(_engine_main.volume_db, target_volume, delta * 5.0)
	var target_pitch := remap(speed_factor, 0.0, 1.0, 0.5, 3.0) * lerpf(0.85, 1.15, clampf(class_factor - 0.5, 0.0, 1.0))
	if throttle_factor > 0.1:
		target_pitch += 0.2
	if _boost_left > 0.0:
		target_pitch += 0.5
	_engine_main.pitch_scale = lerpf(_engine_main.pitch_scale, target_pitch, delta * 2.0)
	# The whine comes in over the top of the speed range and with every boost.
	var high := smoothstep(0.55, 1.0, speed_factor) + (0.4 if _boost_left > 0.0 else 0.0)
	var high_volume := lerpf(-40.0, -11.0, clampf(high, 0.0, 1.0)) + engine_db_offset
	_engine_high.volume_db = lerpf(_engine_high.volume_db, high_volume, delta * 4.0)
	var high_pitch := (0.8 + 0.45 * speed_factor + (0.15 if _boost_left > 0.0 else 0.0)) * lerpf(0.9, 1.1, clampf(class_factor - 0.5, 0.0, 1.0))
	_engine_high.pitch_scale = lerpf(_engine_high.pitch_scale, high_pitch, delta * 3.0)

## Split screen: this kart's engine plays without position on `bus` (panned to the player's half),
## so each player hears their own kart from their side of the couch.
func use_own_engine(bus: StringName) -> void:
	for layer: Array in [[engine_sound, "_engine_main"], [_engine_high, "_engine_high"]]:
		var world_player := layer[0] as AudioStreamPlayer3D
		var own := AudioStreamPlayer.new()
		own.stream = world_player.stream
		own.bus = bus
		own.volume_db = world_player.volume_db
		own.pitch_scale = world_player.pitch_scale
		container.add_child(own)
		if world_player.playing:
			own.play()
		world_player.stop()
		set(layer[1], own)

## The bus this kart's engine plays on (the tunnel echo goes there).
func engine_bus() -> StringName:
	return _engine_main.get("bus") if _engine_main else &"Engines"

## AI engines shift pitch as they pass (doppler).
func use_doppler() -> void:
	engine_sound.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	(_engine_high as AudioStreamPlayer3D).doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP

static func _looped(wav: AudioStreamWAV) -> AudioStreamWAV:
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return wav

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

func _hill_assist() -> void:
	if not colliding or frozen:
		return
	var g := Vector3(0, -ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * sphere.gravity_scale, 0)
	var along := g - _normal * g.dot(_normal)
	if along.length_squared() < 0.01:
		return
	sphere.apply_central_force(-along * sphere.mass * HILL_ASSIST)

## A spin in the air: the kart turns once around, the driver jumps up in the seat.
func _start_trick() -> void:
	_trick = true
	_spark_sound.pitch_scale = 1.7
	_spark_sound.play()
	if visual.driver:
		visual.driver.hop(1.2)
	var tween := create_tween()
	if _ramp_air:
		# Off a ramp: a barrel roll around the kart's middle, lifted a little.
		tween.tween_method(_ramp_trick_pose, 0.0, 1.0, RAMP_TRICK_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func() -> void: visual.transform = Transform3D.IDENTITY)
		return
	tween.tween_property(visual, "rotation:y", TAU, 0.4).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: visual.rotation.y = 0.0)

func in_ramp_air() -> bool:
	return _ramp_air and not colliding

## In the air off a ramp: the flight bends toward `dir` (flat), so a jump before a bend
## lands on the road instead of at the outer wall. The racer calls this with the road ahead.
func ramp_guide(dir: Vector3, delta: float) -> void:
	var v := sphere.linear_velocity
	var flat := Vector2(v.x, v.z)
	if flat.length() < 1.0 or dir.length_squared() < 0.0001:
		return
	var angle := Vector2(dir.x, dir.z).angle_to(flat)
	var turn := clampf(-angle, -RAMP_GUIDE_RATE * delta, RAMP_GUIDE_RATE * delta)
	sphere.linear_velocity = v.rotated(Vector3.UP, -turn)
	container.rotate_y(-turn)

## The barrel roll's picture at t = 0..1 (the physics ball does not turn).
func _ramp_trick_pose(t: float) -> void:
	var pivot := Vector3(0.0, RAMP_TRICK_PIVOT, 0.0)
	var roll := Basis(Vector3(0, 0, 1), TAU * t)
	visual.transform = Transform3D(roll, pivot - roll * pivot + Vector3(0.0, RAMP_TRICK_LIFT * sin(PI * t), 0.0))

func _land() -> void:
	if _ramp_air:
		_ramp_air = false
		sphere.gravity_scale = _ground_gravity
	if _trick and _air_time >= TRICK_MIN_AIR:
		tricks += 1
		boost(TRICK_BOOST_SECONDS, TRICK_BOOST_STRENGTH)
		rumble_requested.emit(0.5, 0.6, 0.15)
	elif _air_time > 0.2:
		rumble_requested.emit(0.3, 0.5, 0.1)
	_trick = false
	_spring_trick = false
	_air_time = 0.0

## Walls take away only the speed going into them: the kart glances off and keeps rolling
## along the wall with its nose turned that way, instead of stopping dead.
func _glance_off_walls() -> void:
	var state := PhysicsServer3D.body_get_direct_state(sphere.get_rid())
	if state == null:
		return
	var center := sphere.global_position
	for i in state.get_contact_count():
		var contact := state.get_contact_local_position(i)
		if contact.y < center.y - BALL_RADIUS * 0.5:
			continue  # the ground
		var n := center - contact
		n.y = 0.0
		if n.length_squared() < 0.0001:
			continue
		n = n.normalized()
		var v := sphere.linear_velocity
		var into := v.dot(n)
		if into >= 0.0:
			continue
		v -= n * into * (1.0 + WALL_BOUNCE)
		sphere.linear_velocity = v
		# Spin the ball to match, so it does not roll back into the wall.
		sphere.angular_velocity = Vector3(v.z / BALL_RADIUS, sphere.angular_velocity.y, -v.x / BALL_RADIUS)
		var along := Vector3(v.x, 0.0, v.z)
		if along.length() > 1.0:
			var fwd := container.global_basis.z
			var yaw_now := atan2(fwd.x, fwd.z)
			var yaw_wall := atan2(along.x, along.z)
			var diff := wrapf(yaw_wall - yaw_now, -PI, PI)
			if absf(diff) < PI * 0.5:
				container.rotate_y(diff * WALL_STEER)

func _on_sphere_body_entered(body: Node) -> void:
	if body.name == "Ground" or body.name == "RoadFloor":
		return  # rolling from the flat ground onto the road floor is not a bump
	var impact := absf(linear_velocity.dot(container.global_basis.z))
	if impact < 1.0:
		return
	rumble_requested.emit(clampf(impact / 8.0, 0.2, 0.6), clampf(impact / 6.0, 0.2, 1.0), 0.12)
	wall_hits += 1
	if not impact_sound.playing:
		impact_sound.pitch_scale = 1.0
		impact_sound.volume_db = clampf(remap(impact, 0.0, 6.0, -20.0, 0.0), -20.0, 0.0) + engine_db_offset
		impact_sound.play()
	if visual.driver:
		visual.driver.knock(clampf(impact * 0.4, 0.5, 3.0))
	bumped.emit(clampf(impact / 8.0, 0.0, 1.0))
