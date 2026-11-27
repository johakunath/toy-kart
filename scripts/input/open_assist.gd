class_name OpenAssist extends RefCounted
## The assist layer for open driving (the "Entdecken" mode), where there is no racing line.
## It sits in the same place as Assist: device or bot intent in, the intent the kart gets out.
##
## Kid mode, lighter than the race helper (he said a strong autopilot felt like no control):
##   - Auto-accelerate to a cruise; gas gives full speed; it slows down close to furniture.
##   - Soft steering away from walls and furniture: five feelers look ahead; only when
##     something is close does the helper steer, more the closer it is.
##   - A gentle pull toward the next lost thing (`guide`), only while the stick rests. Any
##     stick input wins at once.
##   - Never stuck: pushed against something, the kart backs out by itself after a moment;
##     stuck again right after, it glides out toward open floor (the floor map knows where).
## Full mode and bots: the intent passes through; they back out only when really stuck.
## Everyone is put back on free floor (wants_reset) after a long time without moving.

const CRUISE := 0.9               ## kid: share of top speed without gas
const SLOW_NEAR := 0.5            ## kid: throttle right in front of furniture
const LOOK_SECONDS := 0.55        ## how far the feelers reach, in seconds of driving ...
const LOOK_MIN := 3.0             ## ... but at least this many metres
const FEELERS: Array[float] = [-0.95, -0.45, 0.0, 0.45, 0.95]  ## radians, + = right
const AVOID_GAIN := 1.5
const PULL_HAND := 0.22           ## kid: how much the pull steers (0..1), with the stick at rest
const PULL_AFTER := 0.6           ## seconds the stick must rest before the pull starts
const STICK_FEEL := 0.9
const STUCK_SPEED := 1.2          ## m/s
const KID_STUCK_SECONDS := 1.0    ## then back out ...
const OTHER_STUCK_SECONDS := 4.0   ## grown-ups and bots: only when really stuck (like the race rescue)
const BACK_SECONDS := 0.9         ## ... for this long
const RESCUE_SECONDS := 7.0       ## no progress at all for this long: put back on free floor
## Stuck again while this much of the last back-out is still remembered (it fades by 0.25 a
## second, so within about 2.4 s): glide out instead of backing out once more.
const AGAIN := 0.4
const ESCAPE_SECONDS := 1.3       ## the glide out of a corner ...
const ESCAPE_PUSH := 16.0         ## ... with this push (m/s²)

var kid := false
## Flat unit vector toward the next thing to find (zero = none). Set by the explore mode.
var guide := Vector3.ZERO
var wants_reset := false
## The floor map (set by the explore mode): where open floor is, for gliding out of corners.
var map: OpenMap
## For the checks: how often the kart backed out by itself, and glided out of a corner.
var backups := 0
var escapes := 0

var _out := Intent.new()
var _stuck := 0.0
var _back_left := 0.0
var _back_steer := 0.0
var _rest := 0.0
var _no_progress := 0.0
var _anchor := Vector3.INF
var _last_avoid := 1.0
var _recent := 0.0  ## back-outs lately (fades over a few seconds)
var _escape_left := 0.0
var _escape_dir := Vector3.ZERO
var _exclude: Array[RID] = []

func apply(raw: Intent, kart: Kart, delta: float) -> Intent:
	_out.copy_from(raw)
	_out.use = false
	_out.gift = false
	_watch(raw, kart, delta)
	if _escape_left > 0.0:
		_escape_left -= delta
		kart.nudge(_escape_dir * ESCAPE_PUSH)
		var angle := _flat(kart.forward()).signed_angle_to(_escape_dir, Vector3.UP)
		var facing := absf(angle) < PI * 0.5
		_out.accelerate = 0.5 if facing else 0.0
		_out.brake = 0.0 if facing else 0.6
		_out.steer = clampf(-angle * 1.5, -1.0, 1.0) if facing else 0.0
		_out.drift = false
		_out.spark = false
		_out.spark_cancel = true  # a charge must not fire a boost back into the corner
		return _out
	if _back_left > 0.0:
		_back_left -= delta
		_out.accelerate = 0.0
		_out.brake = 1.0
		_out.steer = _back_steer
		_out.drift = false
		_out.spark = false
		_out.spark_cancel = true
		return _out
	if not kid:
		return _out

	var feel := _feel(kart)
	var avoid: float = feel[0]
	var near: float = feel[1]      # 0 = nothing close, 1 = touching
	var ahead: float = feel[2]     # the same, only for the forward feelers
	if absf(raw.steer) > 0.15:
		_rest = 0.0
	else:
		_rest += delta
	var pull := 0.0
	if guide != Vector3.ZERO and _rest > PULL_AFTER:
		var fwd := _flat(kart.forward())
		var angle := fwd.signed_angle_to(guide, Vector3.UP)  # + = guide is to the left
		pull = clampf(-angle * 1.3, -1.0, 1.0) * PULL_HAND
	# The stick fades a little only when it steers right into the thing that is close.
	var toward := signf(raw.steer) == -signf(avoid) and absf(avoid) > 0.05
	var stick := raw.steer * STICK_FEEL * (1.0 - near * 0.6 if toward else 1.0)
	_out.steer = clampf(stick + avoid * near + pull * (1.0 - near), -1.0, 1.0)
	var want := lerpf(CRUISE, 1.0, clampf(raw.accelerate, 0.0, 1.0))
	if ahead > 0.0:
		want = minf(want, lerpf(CRUISE, SLOW_NEAR, ahead))
	_out.accelerate = want
	_out.brake = 0.0
	_out.drift = false
	_out.spark = absf(raw.steer) >= 0.5 and near < 0.2
	_out.spark_cancel = near > 0.5
	return _out

## Forget timers (after a reset).
func clear() -> void:
	_stuck = 0.0
	_back_left = 0.0
	_escape_left = 0.0
	_no_progress = 0.0
	_anchor = Vector3.INF
	wants_reset = false

## The feelers: [steer away (-1..1), how close the nearest thing is (0..1), the same ahead].
func _feel(kart: Kart) -> Array[float]:
	var space := kart.get_world_3d().direct_space_state
	if _exclude.is_empty():
		_exclude = [kart.sphere.get_rid()]
	var fwd := _flat(kart.forward())
	var right := fwd.cross(Vector3.UP)
	var from := kart.sphere.global_position + Vector3(0, 0.1, 0)  # low: sees foot bars too
	var reach := LOOK_MIN + maxf(kart.speed(), 0.0) * LOOK_SECONDS
	var push := 0.0
	var near := 0.0
	var ahead := 0.0
	var space_left := 0.0
	var space_right := 0.0
	var center_hit := 0.0
	for a in FEELERS:
		var dir := fwd * cos(a) + right * sin(a)
		var length := reach * (1.0 if absf(a) < 0.5 else 0.7)
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * length, 1, _exclude)
		var hit := space.intersect_ray(query)
		var free := 1.0
		if not hit.is_empty():
			free = from.distance_to(hit["position"]) / length
		var w := 1.0 - free
		if a < 0.0:
			space_left += free
		elif a > 0.0:
			space_right += free
		if w <= 0.0:
			continue
		near = maxf(near, w * (1.0 if absf(a) < 0.5 else 0.7))
		if absf(a) < 0.5:
			ahead = maxf(ahead, w)
		if a == 0.0:
			center_hit = w
		else:
			push -= signf(a) * w * (0.6 + 0.4 * cos(a))
	if center_hit > 0.0:
		# Straight at something: turn toward the side with more room (or the way it went last).
		var side := signf(space_right - space_left)
		if side == 0.0:
			side = _last_avoid
		push += side * center_hit
	if absf(push) > 0.05:
		_last_avoid = signf(push)
	return [clampf(push * AVOID_GAIN, -1.0, 1.0), clampf(near, 0.0, 1.0), clampf(ahead, 0.0, 1.0)]

func _watch(raw: Intent, kart: Kart, delta: float) -> void:
	var pos := kart.ground_position()
	if pos.y < -3.0:
		wants_reset = true
		return
	_recent = maxf(_recent - delta * 0.25, 0.0)
	var trying := kid or raw.accelerate > 0.3 or raw.brake > 0.3
	if trying and kart.speed() < STUCK_SPEED and _back_left <= 0.0 and _escape_left <= 0.0:
		_stuck += delta
	else:
		_stuck = maxf(_stuck - delta * 2.0, 0.0)
	if _stuck >= (KID_STUCK_SECONDS if kid else OTHER_STUCK_SECONDS):
		_stuck = 0.0
		if _recent >= AGAIN and map and map.is_ready():
			# Stuck again right after backing out: glide toward open floor.
			var to := map.open_spot(pos) - pos
			to.y = 0.0
			if to.length() < 0.5:
				to = -_flat(kart.forward())
			_escape_dir = to.normalized()
			_escape_left = ESCAPE_SECONDS
			_recent = 0.0
			escapes += 1
		else:
			_back_left = BACK_SECONDS
			_recent += 1.0
			_back_steer = 0.0
			backups += 1
	# Real progress = moved 4 m away from where it was. Driving circles is not stuck: only
	# time spent slow counts.
	if _anchor == Vector3.INF or pos.distance_to(_anchor) > 4.0:
		_anchor = pos
		_no_progress = 0.0
	elif not trying:
		_no_progress = 0.0  # a grown-up who parks and watches is not stuck
	elif kart.speed() < STUCK_SPEED * 2.0:
		_no_progress += delta
	if _no_progress >= RESCUE_SECONDS and trying:
		wants_reset = true

static func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.001 else Vector3.FORWARD
