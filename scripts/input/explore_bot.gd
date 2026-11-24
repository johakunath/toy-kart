class_name ExploreBot extends InputSource
## A test driver for the open world (checks, and "steering well" in kid mode): it follows the
## way the explore mode points (`guide`, round the furniture) at full gas.

var kart: Kart
## Flat direction to drive (set every tick by the explore mode).
var guide := Vector3.ZERO

func _init(number := 0) -> void:
	id = "explorebot%d" % number
	label = "Test %d" % (number + 1)

func _read_raw(_control_mode: int) -> Dictionary:
	if kart == null or guide == Vector3.ZERO:
		return {"accelerate": 0.6}
	var fwd := kart.forward()
	fwd.y = 0.0
	var angle := fwd.normalized().signed_angle_to(guide, Vector3.UP)
	var steer := clampf(-angle * 1.6, -1.0, 1.0)
	return {"steer": steer, "accelerate": 1.0 if absf(angle) < 0.9 else 0.55}
