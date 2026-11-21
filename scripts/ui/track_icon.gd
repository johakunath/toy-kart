class_name TrackIcon extends Control
## Draws the shape of a track, so a track can be picked without reading its name.

var outline := PackedVector2Array()

func _init(p_outline: PackedVector2Array) -> void:
	outline = p_outline
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if outline.size() < 3:
		return
	var half := minf(size.x, size.y) * 0.5 - 12.0
	var points := PackedVector2Array()
	for p in outline:
		points.append(size * 0.5 + p * half)
	points.append(points[0])
	draw_polyline(points, UiKit.INK, 15.0, true)
	draw_polyline(points, Color("6b6e80"), 9.0, true)
	# Start line: a small white dash across the road.
	var start := points[0]
	var dir := (points[1] - points[0]).normalized()
	var across := Vector2(-dir.y, dir.x) * 9.0
	draw_line(start - across, start + across, Color.WHITE, 5.0, true)
