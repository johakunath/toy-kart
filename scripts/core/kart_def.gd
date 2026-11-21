class_name KartDef extends Resource
## One selectable kart. Add a kart by adding one .tres file in data/karts/.

@export var id := ""
@export var display_name := ""
@export var sort_order := 100
@export var model_scene: PackedScene

## Where the driver sits, in the kart model's space (+Z is forward, +Y is up).
@export var seat_position := Vector3(0, 0.75, -0.1)
@export var seat_scale := 1.0

@export_group("Stats (1.0 = standard)")
@export_range(0.8, 1.2, 0.01) var top_speed := 1.0
@export_range(0.8, 1.2, 0.01) var acceleration := 1.0
@export_range(0.8, 1.2, 0.01) var handling := 1.0

@export_group("Sound")
@export var engine_sound: AudioStream
@export_range(0.5, 2.0, 0.01) var horn_pitch := 1.0
