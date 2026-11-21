class_name AiSource extends InputSource
## An AI driver. It produces the same intents as a human device: it steers toward a point
## further along the racing line (with its own lane) and slows down for tight corners.

var kart: Kart
var progress: TrackProgress
var track: Track
var skill := 0.92        ## share of the kart's top speed this driver uses on straights
var lane := 0.0          ## metres to the side of the racing line the driver likes
var _lane_timer := 0.0

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

	var steer := LineFollow.steer_to_lane(kart, progress, track, lane)
	var top := maxf(kart.top_speed(), 0.1)
	var target_speed := minf(top * skill, LineFollow.corner_speed(kart, progress, track))
	return {
		"steer": steer,
		"accelerate": clampf(target_speed / top, 0.0, 1.0),
		"brake": 1.0 if speed > target_speed * 1.3 + 1.0 else 0.0,
	}
