class_name Assist extends RefCounted
## The per-player assist layer. It sits between the device (or AI) and the kart:
## it takes the driver's intent and returns the intent the kart actually gets.
##
## Kid mode: auto-accelerate, smart steering toward the racing line, soft walls,
## pickups fire by themselves, reset after 2 s off course or when stuck.
## Full mode and AI: intent passes through; only a rescue when lost or stuck.

const KID_OFF_COURSE_SECONDS := 2.0
const KID_STUCK_SECONDS := 2.5
const OTHER_RESCUE_SECONDS := 4.0
const AUTO_USE_DELAY := 0.35

var kid := false
var is_ai := false

## Set when the racer should be put back on the track; the race reads and clears it.
var wants_reset := false

var _out := Intent.new()
var _off_time := 0.0
var _stuck_time := 0.0
var _stuck_ref := 0.0
var _use_timer := 0.0

func apply(raw: Intent, racer: Racer, track: Track, racing: bool, delta: float) -> Intent:
	_out.copy_from(raw)
	if not racing:
		_out.accelerate = 0.0
		_out.brake = 0.0
		_out.drift = false
		_out.use = false
		_off_time = 0.0
		_stuck_time = 0.0
		_stuck_ref = racer.progress.distance()
		return _out

	_watch_for_trouble(racer, track, delta)
	if kid:
		_out.accelerate = 1.0
		_out.brake = 0.0
		_out.drift = false
		_out.steer = _smart_steer(raw.steer, racer, track)
		_soft_walls(racer, track)
		_out.use = false
		if racer.kart.has_item:
			_use_timer += delta
			if _use_timer >= AUTO_USE_DELAY:
				_out.use = true
				_use_timer = 0.0
		else:
			_use_timer = 0.0
	return _out

func clear_timers(racer: Racer) -> void:
	_off_time = 0.0
	_stuck_time = 0.0
	_stuck_ref = racer.progress.distance()
	wants_reset = false

# --- Smart steering ------------------------------------------------------------------------

## Blends the player's steering with steering toward a point ahead on the track.
## In the middle of the road the player decides. Near a wall, when pointing the wrong way,
## or with hands off the stick, the assist takes over.
func _smart_steer(player_steer: float, racer: Racer, track: Track) -> float:
	var kart := racer.kart
	var progress := racer.progress
	var speed := kart.speed()
	var safe := track.half_width - 1.3

	# The lane the kid is aiming for: where the kart is now, shifted by the stick, kept on the road.
	var lane := clampf(progress.lateral * 0.92 + player_steer * 2.5, -safe, safe)
	var look := 5.0 + speed * 0.5
	var s_ahead := progress.s() + look
	var target := track.pos_at(s_ahead) + track.right_at(s_ahead) * lane
	var to := target - kart.ground_position()
	to.y = 0.0
	var fwd := kart.forward()
	fwd.y = 0.0
	var error := fwd.normalized().signed_angle_to(to.normalized(), Vector3.DOWN)
	var auto := clampf(error * 2.2, -1.0, 1.0)

	var near_wall := smoothstep(safe - 0.8, safe + 0.4, absf(progress.lateral))
	var wrong_way := smoothstep(0.6, 1.2, absf(progress.heading_error))
	var hands_off := 0.8 if absf(player_steer) < 0.15 else 0.3
	var weight := maxf(hands_off, maxf(near_wall, wrong_way))
	return clampf(lerpf(player_steer, auto, weight), -1.0, 1.0)

## An invisible cushion in front of the real walls: pushes the kart back before it hits.
func _soft_walls(racer: Racer, track: Track) -> void:
	var progress := racer.progress
	var limit := track.half_width - 1.0
	var over := absf(progress.lateral) - limit
	if over <= 0.0:
		return
	var inward := -track.sample_right(progress.index) * signf(progress.lateral)
	racer.kart.nudge(inward * minf(over * 30.0, 25.0))

# --- Rescue --------------------------------------------------------------------------------

func _watch_for_trouble(racer: Racer, track: Track, delta: float) -> void:
	var progress := racer.progress
	var pos := racer.kart.ground_position()
	var off_course := absf(progress.lateral) > track.half_width + 1.0 or pos.y < -3.0
	_off_time = _off_time + delta if off_course else 0.0

	# Stuck = no real progress along the track for a while.
	var dist := progress.distance()
	if absf(dist - _stuck_ref) > 1.5:
		_stuck_ref = dist
		_stuck_time = 0.0
	else:
		_stuck_time += delta

	if kid:
		if _off_time >= KID_OFF_COURSE_SECONDS or _stuck_time >= KID_STUCK_SECONDS:
			wants_reset = true
	elif is_ai:
		if _off_time >= OTHER_RESCUE_SECONDS or _stuck_time >= OTHER_RESCUE_SECONDS:
			wants_reset = true
	else:
		# Full mode: only rescued when really lost (off the map or far outside the walls).
		if _off_time >= OTHER_RESCUE_SECONDS:
			wants_reset = true
