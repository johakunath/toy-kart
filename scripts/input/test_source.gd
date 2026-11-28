class_name TestSource extends InputSource
## A fake device for the headless checks. It stands in for a small child at the controls:
## "none" never touches anything, "gas" only holds the gas button, "left"/"right" hold the stick to one side all race long,
## "random" mashes sticks and buttons at random, "honk" holds the gas and honks every 2.5 s
## (first at 1 s; for pictures of the horn tricks).

var pattern := "none"
var _steer := 0.0
var _timer := 0.0
var _buttons := false
var _clock := 0.0

func _init(p_pattern: String, number: int) -> void:
	pattern = p_pattern
	id = "test%d" % number
	label = "Test %d" % (number + 1)

func _read_raw(_control_mode: int) -> Dictionary:
	match pattern:
		"left":
			return {"steer": -1.0}
		"right":
			return {"steer": 1.0}
		"gas":
			return {"accelerate": 1.0}
		"honk":
			_clock += 1.0 / Engine.physics_ticks_per_second
			return {"accelerate": 1.0, "horn": fmod(_clock + 1.5, 2.5) < 0.05}
		"random":
			_timer -= 1.0 / Engine.physics_ticks_per_second
			if _timer <= 0.0:
				_timer = randf_range(0.1, 1.2)
				_steer = [-1.0, -1.0, 0.0, 1.0, 1.0][randi() % 5]
				_buttons = randf() < 0.4
			return {"steer": _steer, "horn": _buttons, "use": _buttons, "accelerate": 1.0, "drift": _buttons}
	return {}
