class_name Intent extends RefCounted
## What a driver wants the kart to do this physics tick.
## Devices and AI produce intents; the assist layer may change them; only then the kart sees them.

var steer := 0.0       ## -1 = full left, +1 = full right
var accelerate := 0.0  ## 0..1
var brake := 0.0       ## 0..1 (brakes, then reverses)
var drift := false     ## held
var use := false       ## true only on the tick the button went down
var horn := false      ## true only on the tick the button went down
var spark := false     ## kid mode: steering hard charges drift sparks (set by the assist)
var spark_cancel := false  ## kid mode: drop the charge without a boost (set by the assist)

func copy_from(other: Intent) -> void:
	steer = other.steer
	accelerate = other.accelerate
	brake = other.brake
	drift = other.drift
	use = other.use
	horn = other.horn
	spark = other.spark
	spark_cancel = other.spark_cancel

func clear() -> void:
	steer = 0.0
	accelerate = 0.0
	brake = 0.0
	drift = false
	use = false
	horn = false
	spark = false
	spark_cancel = false
