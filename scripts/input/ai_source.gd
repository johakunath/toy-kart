class_name AiSource extends InputSource
## An AI driver. It produces the same intents as a human device: it steers toward a point
## further along the racing line (with its own lane) and slows down for tight corners.

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

func _init() -> void:
	id = "ai"
	label = "Computer"
	icon = "robot"
	_lane_timer = randf_range(2.0, 6.0)

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

	var want_lane := lane
	if slow > 0.02:
		var bend := track.curvature_at(progress.s() + 4.0 + speed * 0.5)
		var outside := -signf(bend) * (track.half_width - 1.4)
		want_lane = lerpf(lane, outside, clampf(slow * 3.0, 0.0, 1.0) * clampf(absf(bend) * 15.0, 0.0, 1.0))
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
			# Decide early, while still in the middle of the road.
			_fork_plan[i] = slow < 0.02 and randf() < 0.4 and s < s0
		if _fork_plan[i]:
			var side: float = fork["side"]
			return side * Track.fork_offset(fork, s + 2.0 + speed * 0.35)
	return NAN
