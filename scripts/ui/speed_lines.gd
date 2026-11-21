class_name SpeedLines extends Control
## White streaks rushing in from the screen edges while the player's kart boosts.

const COUNT := 34

var kart: Kart
var _amount := 0.0
var _seeds: Array[Vector3] = []   ## angle, speed, length factor
var _time := 0.0

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in COUNT:
		_seeds.append(Vector3(rng.randf() * TAU, rng.randf_range(0.8, 1.6), rng.randf_range(0.6, 1.2)))

func _process(delta: float) -> void:
	_time += delta
	var want := 1.0 if kart != null and is_instance_valid(kart) and kart.is_boosting() else 0.0
	_amount = move_toward(_amount, want, delta * (6.0 if want > _amount else 2.5))
	if _amount > 0.0 or want > 0.0:
		queue_redraw()

func _draw() -> void:
	if _amount <= 0.001:
		return
	var center := size * 0.5
	var radius := size.length() * 0.5
	for s in _seeds:
		# Each streak slides inward from the edge, then starts again.
		var phase := fmod(_time * s.y * 2.2 + s.x, 1.0)
		var dir := Vector2(cos(s.x), sin(s.x))
		var outer := radius * (1.05 - phase * 0.35)
		var inner := outer - radius * 0.3 * s.z
		var color := Color(1, 1, 1, 0.85 * _amount * (1.0 - phase * 0.7))
		draw_line(center + dir * inner, center + dir * outer, color, 8.0 * s.z, true)
