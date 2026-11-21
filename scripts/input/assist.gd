class_name Assist extends RefCounted
## The per-player assist layer. It sits between the device (or AI) and the kart:
## it takes the driver's intent and returns the intent the kart actually gets.
##
## Kid mode:
##   - Auto-accelerate, easing off by itself before tight corners.
##   - Smart steering: the stick does not turn the kart freely, it picks a lane on the road.
##     Left moves the kart to the left side, right to the right side, and the assist steers
##     along that lane. Hands off the stick: the kart keeps its lane round the whole track.
##   - Soft walls: an invisible cushion pushes the kart back before it reaches a real wall.
##   - Pickups fire by themselves.
##   - Reset onto the track after 2 s off course, or when stuck.
## Full mode and AI: the intent passes through; only a rescue when lost or stuck.

const KID_OFF_COURSE_SECONDS := 2.0
const KID_STUCK_SECONDS := 2.5
const OTHER_RESCUE_SECONDS := 4.0
const AUTO_USE_DELAY := 0.35
const LANE_SPEED := 4.0          ## metres per second the lane moves sideways at full stick
const WALL_MARGIN := 1.3         ## the kid's lane stays this far from the walls
const DIRECT_FEEL := 0.35        ## share of the stick that reaches the wheels directly

var kid := false
var is_ai := false

## Set when the racer should be put back on the track; the race reads and clears it.
var wants_reset := false

var _out := Intent.new()
var _lane := 0.0
var _lane_known := false
var _off_time := 0.0
var _stuck_time := 0.0
var _stuck_ref := 0.0
var _use_timer := 0.0

func apply(raw: Intent, racer: Racer, track: Track, racing: bool, delta: float) -> Intent:
	_out.copy_from(raw)
	if not _lane_known:
		_lane = racer.progress.lateral
		_lane_known = true
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
		_out.steer = _smart_steer(raw.steer, racer, track, delta)
		_out.accelerate = _auto_accelerate(racer, track)
		_out.brake = 0.0
		_out.drift = false
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

## Called after a reset or at the start: forget timers, keep the lane where the kart is.
func clear_timers(racer: Racer) -> void:
	_off_time = 0.0
	_stuck_time = 0.0
	_stuck_ref = racer.progress.distance()
	_lane = racer.progress.lateral
	wants_reset = false

# --- Kid mode ------------------------------------------------------------------------------

func _smart_steer(stick: float, racer: Racer, track: Track, delta: float) -> float:
	var progress := racer.progress
	var safe := track.half_width - WALL_MARGIN
	if absf(stick) > 0.15:
		_lane += stick * LANE_SPEED * delta
	_lane = clampf(_lane, -safe, safe)
	var auto := LineFollow.steer_to_lane(racer.kart, progress, track, _lane)
	# A bit of the stick goes straight to the wheels so the kart answers at once,
	# fading out as the kart gets close to the wall on that side.
	var room := clampf((safe - progress.lateral * signf(stick)) / safe, 0.0, 1.0)
	return clampf(auto + stick * DIRECT_FEEL * room, -1.0, 1.0)

func _auto_accelerate(racer: Racer, track: Track) -> float:
	var kart := racer.kart
	var limit := LineFollow.corner_speed(kart, racer.progress, track)
	var top := maxf(kart.top_speed(), 0.1)
	return clampf(limit / top, 0.35, 1.0)

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
