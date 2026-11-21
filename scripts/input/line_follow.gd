class_name LineFollow extends RefCounted
## Shared driving maths for everyone who follows the racing line: AI karts and the kid assist.

## Steering (-1..1) that takes the kart toward a lane: a path `lane` metres to the right (+)
## or left (-) of the racing line. Aims at a point a short way ahead; works from any heading.
static func steer_to_lane(kart: Kart, progress: TrackProgress, track: Track, lane: float) -> float:
	var look := 2.0 + kart.speed() * 0.35
	var s_ahead := progress.s() + look
	# Aiming at a point ahead cuts corners toward the inside. Shift the aim point outward by
	# about the amount of that cut, so the kart holds its lane and stays off the inner wall.
	var bend := track.curvature_at(progress.s() + look * 0.5)
	var cut := bend * look * look / 8.0
	var target := track.pos_at(s_ahead) + track.right_at(s_ahead) * (lane - cut * 0.7)
	var to := target - kart.ground_position()
	to.y = 0.0
	var fwd := kart.forward()
	fwd.y = 0.0
	if to.length_squared() < 0.0001 or fwd.length_squared() < 0.0001:
		return 0.0
	var error := fwd.normalized().signed_angle_to(to.normalized(), Vector3.DOWN)
	return clampf(error * 2.5, -1.0, 1.0)

## The speed in m/s the kart can hold through the corners coming up (INF on straights).
static func corner_speed(kart: Kart, progress: TrackProgress, track: Track) -> float:
	var curvature := track.max_curvature(progress.s(), 4.0 + kart.speed() * 0.7)
	if curvature < 0.02:
		return INF
	return kart.steer_rate() * 0.95 / curvature
