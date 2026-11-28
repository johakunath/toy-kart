class_name KartDef extends Resource
## One selectable kart. Add a kart by adding one .tres file in data/karts/.

@export var id := ""
@export var display_name := ""
@export var sort_order := 100
@export var model_scene: PackedScene
## Size and direction fix for models from other packs (+Z must end up as forward).
@export var model_scale := 1.0
@export var model_yaw_degrees := 0.0
## Parts of the model to hide, for example a built-in driver figure.
@export var hide_nodes: PackedStringArray = []
## AI karts only pick vehicles with this ticked.
@export var ai_can_use := true

## Where the driver sits, in the kart model's space (+Z is forward, +Y is up).
@export var seat_position := Vector3(0, 0.75, -0.1)
@export var seat_scale := 1.0

@export_group("Horn trick")
## What the kart does when it honks (HornTrick.Kind). A toy vehicle's own trick wins.
@export var horn_trick := HornTrick.Kind.HOP

@export_group("Flip-up roof")
## Only for models with a "roof" node (built closed, origin on the hinge at its back edge, +X
## axis): how far it flips open in degrees, standing still and at full speed. Shut by default;
## a honk opens it, the next honk shuts it. At full speed it leans further back, so the chase
## camera sees the driver over it.
@export_range(0.0, 170.0, 1.0) var roof_open_degrees := 100.0
@export_range(0.0, 170.0, 1.0) var roof_open_fast_degrees := 135.0

@export_group("Stats (1.0 = standard)")
@export_range(0.8, 1.2, 0.01) var top_speed := 1.0
@export_range(0.8, 1.2, 0.01) var acceleration := 1.0
@export_range(0.8, 1.2, 0.01) var handling := 1.0

@export_group("Sound")
@export var engine_sound: AudioStream
@export_range(0.5, 2.0, 0.01) var horn_pitch := 1.0
## A horn of its own (the train whistles). Empty: the standard horn.
@export var horn_sound: AudioStream
