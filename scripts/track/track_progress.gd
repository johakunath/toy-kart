class_name TrackProgress extends RefCounted
## Follows one kart along the racing line: where it is, how far off the line, which lap.

var track: Track
var index := 0       ## closest sample on the line
var lap := -1        ## -1 until the kart crosses the start line for the first time
var lateral := 0.0   ## metres to the right (+) or left (-) of the line
var heading_error := 0.0  ## radians between kart heading and track direction, + = pointing right of it

func _init(p_track: Track) -> void:
	track = p_track

## Full search, for spawns and resets. Keeps the lap count.
func snap_to(pos: Vector3) -> void:
	index = track.closest_index(pos)
	lateral = track.lateral_at(pos, index)

func update(pos: Vector3, forward: Vector3) -> void:
	var new_index := track.closest_index(pos, index)
	var half := track.count >> 1
	if new_index < index - half:
		lap += 1
	elif new_index > index + half:
		lap -= 1
	index = new_index
	lateral = track.lateral_at(pos, index)
	var tangent := track.sample_tangent(index)
	var flat := Vector3(forward.x, 0.0, forward.z).normalized()
	heading_error = tangent.signed_angle_to(flat, Vector3.DOWN)

## Metres along the line from the finish line, within the current lap.
func s() -> float:
	return track.s_at(index)

## Total metres raced. Negative while still behind the start line.
func distance() -> float:
	return lap * track.length + s()
