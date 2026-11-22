class_name Assist extends RefCounted
## The per-player assist layer. It sits between the device (or AI) and the kart:
## it takes the driver's intent and returns the intent the kart actually gets.
##
## Kid mode: he steers, the assist only catches mistakes, and mistakes cost a little speed.
##   - Auto-accelerate to a cruising speed; holding gas (A, RT, W) gives full speed.
##     Before tight corners it eases off by itself.
##   - Steering: in the middle of the road the stick steers the kart for real, with only a
##     light hand on the wheel. Hands off, the kart drifts wide in curves. Near the edge the
##     assist takes over and steers back, and the edge strip slows the kart down.
##   - Soft walls: an invisible cushion pushes the kart back before it reaches a real wall.
##   - Steering hard in the middle of the road charges drift sparks (blue, then orange);
##     letting go fires a boost. Near the edge the charge is dropped, never fired.
##   - A start boost every time, bigger feeling with gas held.
##   - Items fire by themselves after a second (so he sees which one he got).
##   - Reset onto the track after 2 s off course, or when stuck.
## Full mode and AI: the intent passes through; only a rescue when lost or stuck.

const KID_OFF_COURSE_SECONDS := 2.0
const KID_STUCK_SECONDS := 2.5
const OTHER_RESCUE_SECONDS := 4.0
const AUTO_USE_DELAY := 1.0   ## the item roulette shows first, then the item fires
const WALL_MARGIN := 1.3         ## the assist steers back to this far from the walls
const EDGE_ZONE := 2.6           ## metres from the wall where the assist starts to take over
const LIGHT_HAND := 0.15         ## how much the assist helps in the middle of the road (0..1)
const STICK_FEEL := 0.8          ## share of the stick that reaches the wheels
const LOOK_AHEAD := 0.6         ## seconds the assist looks ahead for the walls
const KID_CRUISE := 0.9          ## share of top speed without gas
const EDGE_SLOW := 0.7           ## throttle on the edge strip
const SPARK_STICK := 0.5         ## kid: this much stick charges sparks

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
var _edge := 0.0

func apply(raw: Intent, racer: Racer, track: Track, racing: bool, delta: float) -> Intent:
	_out.copy_from(raw)
	if not _lane_known:
		_lane = racer.progress.lateral
		_lane_known = true
	if not racing:
		# Gas during the countdown is kept: the kart reads it for the start boost.
		_out.brake = 0.0
		_out.spark = false
		_out.drift = false
		_out.use = false
		_off_time = 0.0
		_stuck_time = 0.0
		_stuck_ref = racer.progress.distance()
		return _out

	_watch_for_trouble(racer, track, delta)
	# On the kerb: the kart rumbles (a sound for every driver, a gentle "oops" for the kid).
	racer.kart.on_kerb = absf(racer.progress.lateral) > track.half_width - WALL_MARGIN - 0.4
	if kid:
		_out.steer = _smart_steer(raw.steer, racer, track, delta)
		_out.accelerate = _auto_accelerate(raw.accelerate, racer, track)
		_out.brake = 0.0
		_out.drift = false
		_out.spark = absf(raw.steer) >= SPARK_STICK and _edge <= 0.0
		_out.spark_cancel = _edge > 0.3
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

func _smart_steer(stick: float, racer: Racer, track: Track, _delta: float) -> float:
	var progress := racer.progress
	var safe := track.half_width - WALL_MARGIN
	# Where the kart will be in a moment if it keeps its heading: the assist reacts to that,
	# so a kart pointing at the wall is caught early, one driving along the edge is left alone.
	var ahead := progress.lateral + sin(progress.heading_error) * racer.kart.speed() * LOOK_AHEAD
	var near := ahead if absf(ahead) > absf(progress.lateral) else progress.lateral
	# 0 in the middle of the road, 1 at the wall cushion.
	var edge := clampf((absf(near) - (track.half_width - EDGE_ZONE)) / (EDGE_ZONE - WALL_MARGIN + 0.5), 0.0, 1.0)
	_edge = edge
	# The assist's line: where the kart is now, kept inside the safe band.
	_lane = clampf(progress.lateral, -safe, safe)
	if edge > 0.0:
		_lane = signf(progress.lateral) * minf(absf(_lane), safe - 0.6 * edge)
	var auto := LineFollow.steer_to_lane(racer.kart, progress, track, _lane)
	var help := lerpf(LIGHT_HAND, 1.0, edge)
	# The stick fades out when it pushes toward the wall it is already close to.
	var toward_wall := signf(stick) == signf(near)
	var room := 1.0 - edge if toward_wall else 1.0
	return clampf(auto * help + stick * STICK_FEEL * room, -1.0, 1.0)

func _auto_accelerate(gas: float, racer: Racer, track: Track) -> float:
	var kart := racer.kart
	var limit := LineFollow.corner_speed(kart, racer.progress, track)
	var top := maxf(kart.top_speed(), 0.1)
	var want := lerpf(KID_CRUISE, 1.0, clampf(gas, 0.0, 1.0))
	if absf(racer.progress.lateral) > track.half_width - WALL_MARGIN - 0.4:
		want = minf(want, EDGE_SLOW)
	return clampf(minf(limit / top, want), 0.35, 1.0)

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
