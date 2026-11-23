class_name AiSource extends InputSource
## An AI driver. It produces the same intents as a human device: it steers toward a point
## further along the racing line (with its own lane) and slows down for tight corners.
##
## A computer-driven toy also has a personality (DriverDef "AI personality"): a preferred
## lane, harmless little weaves, honks (or a siren), show-off hops and spins, a happy honk
## and jump when a kid passes it, a cheer when it finishes behind a kid, and how often it
## takes side lanes. Personality is style only: the race's pacing (kart.pace, `slow`) still
## decides the speed, weaves only happen on clear straights away from kids, and the hops and
## spins move the kart's picture, never its body.

const WEAVE_SECONDS := 1.6     ## one weave: out to one side, over to the other, back
const WEAVE_METRES := 0.8      ## how far a weave swings off the driver's lane
const KID_ROOM := 8.0          ## no weaves or show-offs this close (metres) to a kid
const GIVE_WAY_BEHIND := 7.0   ## a kid this close behind gets room to pass
const GIVE_WAY_SIDE := 1.6     ## ... when this close sideways
const REACT_COOLDOWN := 8.0    ## seconds between two reactions to the same kid
const SHOW_COOLDOWN := 6.0     ## seconds between two show-offs
const HONK_GAP := 0.22         ## seconds between the honks of a double honk or a siren
const SIREN := [1.22, 0.92, 1.22, 0.92]  ## "tatü-tata": horn pitch of each siren note

var kart: Kart
var progress: TrackProgress
var track: Track
var skill := 0.92        ## share of the kart's top speed this driver uses on straights
var lane := 0.0          ## metres to the side of the racing line the driver likes
## 0..1, set by the race when this driver should drop back: it then takes wide lines through
## corners (looks like a person making a mistake) instead of only driving slower.
var slow := 0.0
var _lane_timer := 0.0
## Side lanes (Track.forks): whether this driver takes each one on the current lap.
var _fork_plan := {}

## Personality (set by the race for AI karts only; null = plain driver, e.g. test bots).
var persona: DriverDef
## Kid-mode players in the race, for the friendly reactions and for giving way.
var kids: Array[TrackProgress] = []
## Everyone else in the race (not kids), for showing off after an overtake.
var rivals: Array[TrackProgress] = []
var laps := 3
## What the personality did this race (the smoke check prints it).
var stats := {"honks": 0, "jumps": 0, "shows": 0, "weaves": 0, "kid_passes": 0, "cheers": 0, "lanes": 0}

var _horn_timer := 0.0
var _show_timer := 0.0
var _weave_timer := 0.0
var _weave_left := 0.0
var _weave_side := 1.0
var _show_ready := 0.0
var _start_honk := INF        ## seconds into the countdown for an eager honk
var _countdown := 0.0
var _honks: Array[float] = []  ## pitch factors of honks still to come
var _honk_wait := 0.0
var _base_pitch := 1.0
var _gaps := {}                ## TrackProgress -> last signed gap (other minus me, metres)
var _react_ready := {}         ## kid TrackProgress -> seconds until it reacts to that kid again
var _done := false
var _jump: Tween

func _init() -> void:
	id = "ai"
	label = "Computer"
	icon = "robot"
	_lane_timer = randf_range(2.0, 6.0)

## Gives this driver its toy's personality. p_kids / p_rivals: the other racers' progress.
func set_personality(driver: DriverDef, p_kids: Array[TrackProgress], p_rivals: Array[TrackProgress], p_laps: int) -> void:
	persona = driver
	kids = p_kids
	rivals = p_rivals
	laps = p_laps
	if persona == null:
		return
	_base_pitch = kart.horn_sound.pitch_scale
	_horn_timer = _interval(persona.ai_horn, 4.0) * randf_range(0.3, 1.0)
	_show_timer = _interval(persona.ai_show_off, 3.0) * randf_range(0.5, 1.0)
	_weave_timer = _interval(persona.ai_wobble, 4.0) * randf_range(0.4, 1.0)
	if persona.ai_horn >= 0.5:
		_start_honk = randf_range(0.6, 2.6)  # can't wait for the start

func _read_raw(_control_mode: int) -> Dictionary:
	if kart == null or progress == null or track == null:
		return {}
	var speed := kart.speed()
	var delta := 1.0 / Engine.physics_ticks_per_second

	# Wander between lanes now and then, so AI karts do not drive in a single file.
	_lane_timer -= delta
	if _lane_timer <= 0.0:
		_lane_timer = randf_range(3.0, 8.0)
		lane = randf_range(-1.0, 1.0) * (track.half_width - 1.6)

	var want_lane := _preferred_lane(lane, speed)
	if slow > 0.02:
		var bend := track.curvature_at(progress.s() + 4.0 + speed * 0.5)
		var outside := -signf(bend) * (track.half_width - 1.4)
		want_lane = lerpf(want_lane, outside, clampf(slow * 3.0, 0.0, 1.0) * clampf(absf(bend) * 15.0, 0.0, 1.0))
	if persona:
		want_lane = _give_way(_weave(want_lane, speed, delta))
		want_lane = clampf(want_lane, -(track.half_width - 1.4), track.half_width - 1.4)
	var fork_lane := _fork_lane(speed)
	var corner := LineFollow.corner_speed(kart, progress, track)
	if not is_nan(fork_lane):
		want_lane = fork_lane
		corner *= 0.8  # the side lane bends tighter than the road
	var steer := LineFollow.steer_to_lane(kart, progress, track, want_lane)
	var top := maxf(kart.top_speed(), 0.1)
	var target_speed := minf(top * skill, corner)
	return {
		"steer": steer,
		"accelerate": clampf(target_speed / top, 0.0, 1.0),
		"brake": 1.0 if speed > target_speed * 1.3 + 1.0 else 0.0,
		"horn": _personality(speed, delta) if persona else false,
	}

## The lane offset to follow through a side lane, or NAN to stay on the road. Each driver
## decides once per lap, before the fork; a driver who is dropping back never takes it.
func _fork_lane(speed: float) -> float:
	var s := progress.s()
	for i in track.forks.size():
		var fork: Dictionary = track.forks[i]
		var s0: float = fork["from"]
		var s1: float = fork["to"]
		if s < s0 - 30.0 or s > s1:
			_fork_plan.erase(i)
			continue
		if not _fork_plan.has(i):
			# Decide early, while still in the middle of the road. Brave toys go more often.
			var chance := persona.ai_brave if persona else 0.4
			_fork_plan[i] = slow < 0.02 and randf() < chance and s < s0
			if _fork_plan[i]:
				stats["lanes"] += 1
		if _fork_plan[i]:
			var side: float = fork["side"]
			return side * Track.fork_offset(fork, s + 2.0 + speed * 0.35)
	return NAN

# --- Personality ---------------------------------------------------------------------------

## The driver's lane with its preference: MIDDLE stays close to the racing line, INSIDE and
## OUTSIDE lean toward that side of the coming bend (and wander freely on straights).
func _preferred_lane(base: float, speed: float) -> float:
	if persona == null or persona.ai_lane == DriverDef.AiLane.ANY:
		return base
	if persona.ai_lane == DriverDef.AiLane.MIDDLE:
		return base * 0.3
	var bend := track.curvature_at(progress.s() + 6.0 + speed * 0.8)
	var side := signf(bend) * (1.0 if persona.ai_lane == DriverDef.AiLane.INSIDE else -1.0)
	var weight := clampf(absf(bend) * 12.0, 0.0, 1.0)
	return lerpf(base * 0.5, side * (track.half_width - 1.6) * 0.7, weight)

## A harmless little weave now and then, only on a clear straight away from kids and walls.
func _weave(want: float, speed: float, delta: float) -> float:
	if _weave_left > 0.0:
		_weave_left -= delta
		var t := 1.0 - _weave_left / WEAVE_SECONDS
		return want + sin(t * TAU) * WEAVE_METRES * _weave_side
	_weave_timer -= delta
	if _weave_timer <= 0.0:
		_weave_timer = _interval(persona.ai_wobble, 4.0)
		if _calm(speed):
			_weave_left = WEAVE_SECONDS
			_weave_side = 1.0 if randf() < 0.5 else -1.0
			stats["weaves"] += 1
	return want

## A kid close behind and in the same lane gets room: the toy moves over a little.
func _give_way(want: float) -> float:
	var me := progress.distance()
	for k in kids:
		var gap := k.distance() - me
		if gap > -GIVE_WAY_BEHIND and gap < 0.5:
			var side := want - k.lateral
			if absf(side) < GIVE_WAY_SIDE:
				var away := signf(side) if absf(side) > 0.05 else -signf(k.lateral)
				if away == 0.0:
					away = 1.0
				want += away * (GIVE_WAY_SIDE - absf(side))
	return want

## Honks, reactions, show-offs. Returns the horn button for this tick.
func _personality(speed: float, delta: float) -> bool:
	if kart.frozen:
		# On the grid: an eager toy honks once before "Los!".
		_countdown += delta
		if _countdown >= _start_honk:
			_start_honk = INF
			_honk(1)
		return _next_honk(delta)
	_watch_others(speed, delta)
	_horn_timer -= delta
	if _horn_timer <= 0.0:
		_horn_timer = _interval(persona.ai_horn, 4.0)
		_honk(2 if persona.ai_horn >= 0.7 and randf() < 0.5 else 1)
	_show_timer -= delta
	_show_ready -= delta
	if _show_timer <= 0.0:
		_show_timer = _interval(persona.ai_show_off, 3.0)
		if _calm(speed):
			_show_off()
	if not _done and progress.lap >= laps:
		_done = true
		_on_finish()
	return _next_honk(delta)

## Who passed whom since the last tick: a kid passing this toy gets a happy honk and a jump;
## this toy passing a grown-up or another toy may make it show off.
func _watch_others(speed: float, delta: float) -> void:
	var me := progress.distance()
	for k in kids:
		var gap := k.distance() - me
		var ready: float = _react_ready.get(k, 0.0) - delta
		_react_ready[k] = ready
		var before: float = _gaps.get(k, gap)
		if before < 0.0 and gap >= 0.0 and gap < 6.0 and ready <= 0.0 and not _done:
			_react_ready[k] = REACT_COOLDOWN
			stats["kid_passes"] += 1
			if randf() < persona.ai_friendly:
				_honk(1)
				_little_jump(0.3)
		_gaps[k] = gap
	for r in rivals:
		var gap := r.distance() - me
		var before: float = _gaps.get(r, gap)
		if before > 0.0 and gap <= 0.0 and gap > -6.0 and randf() < persona.ai_show_off * 0.6 and _calm(speed):
			_show_off()
		_gaps[r] = gap

## Crossing the line: behind a kid, a friendly toy cheers (bouncing driver, honks, a jump).
func _on_finish() -> void:
	var kid_ahead := false
	for k in kids:
		kid_ahead = kid_ahead or k.lap >= laps
	if kid_ahead and randf() < 0.5 + 0.5 * persona.ai_friendly:
		stats["cheers"] += 1
		if kart.visual.driver:
			kart.visual.driver.set_cheering(true)
		_honk(2)
		_little_jump(0.4)

## A hop and a spin of the kart's picture (the body keeps rolling straight on).
func _show_off() -> void:
	if _show_ready > 0.0:
		return
	_show_ready = SHOW_COOLDOWN
	stats["shows"] += 1
	_little_jump(0.35)
	if kart.visual.driver:
		kart.visual.driver.hop(1.2)
	var spin := kart.create_tween()
	spin.tween_property(kart.visual, "rotation:y", TAU, 0.5).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	spin.tween_callback(func() -> void: kart.visual.rotation.y = 0.0)

## The whole toy jumps up a little and lands again (picture only).
func _little_jump(height: float) -> void:
	if _jump and _jump.is_running():
		return
	stats["jumps"] += 1
	_jump = kart.create_tween()
	_jump.tween_property(kart.visual, "position:y", height, 0.16).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_jump.tween_property(kart.visual, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

## Queue a honk (a siren toy plays its "tatü-tata" instead).
func _honk(count: int) -> void:
	if not _honks.is_empty():
		return
	if persona.ai_siren:
		_honks.assign(SIREN)
	else:
		for i in count:
			_honks.append(1.0)

func _next_honk(delta: float) -> bool:
	_honk_wait -= delta
	if _honks.is_empty() or _honk_wait > 0.0:
		return false
	kart.horn_sound.pitch_scale = _base_pitch * _honks.pop_front()
	_honk_wait = HONK_GAP
	stats["honks"] += 1
	return true

## A clear straight on the ground, away from side lanes and kids: room for some fun.
func _calm(speed: float) -> bool:
	if not kart.colliding or speed < 3.0 or slow > 0.3:
		return false
	if track.max_curvature(progress.s(), 12.0 + speed) > 0.03:
		return false
	var s := progress.s()
	for fork in track.forks:
		if s > float(fork["from"]) - 30.0 and s < float(fork["to"]) + 5.0:
			return false
	var me := progress.distance()
	for k in kids:
		if absf(k.distance() - me) < KID_ROOM:
			return false
	return true

## Seconds until the next event for a 0..1 trait that happens up to `per_minute` times a minute.
static func _interval(amount: float, per_minute: float) -> float:
	if amount <= 0.0:
		return 1.0e9
	return 60.0 / (amount * per_minute) * randf_range(0.6, 1.4)

## One line for the smoke check: what this toy's personality did.
func mood_report() -> String:
	if persona == null:
		return "no personality"
	return "lane=%s honks=%d jumps=%d shows=%d weaves=%d kid_passes=%d cheers=%d side_lanes=%d" % [
		DriverDef.AiLane.keys()[persona.ai_lane].to_lower(), stats["honks"], stats["jumps"], stats["shows"],
		stats["weaves"], stats["kid_passes"], stats["cheers"], stats["lanes"]]
