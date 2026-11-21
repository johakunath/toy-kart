class_name TrackDef extends Resource
## One selectable track. The files in data/tracks/ are written by the track builders in tools/.

@export var id := ""
@export var display_name := ""
@export var sort_order := 100
@export_file("*.tscn") var scene_path := ""
## The shape of the track for the menu button: points in a -1..1 box, in driving order.
@export var outline := PackedVector2Array()
