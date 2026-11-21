class_name DriverDef extends Resource
## One selectable driver. Add a driver by adding one .tres file in data/drivers/.

enum Type { MODEL, PAPER }

@export var id := ""
@export var display_name := ""
@export var type := Type.MODEL
@export var sort_order := 100

@export_group("3D model driver")
@export var model_scene: PackedScene
@export var animation := "drive"
@export var model_scale := 0.8

@export_group("Paper driver")
@export var front_texture: Texture2D
@export var back_texture: Texture2D
## Height of the card in metres; width follows the photo's aspect ratio.
@export var card_height := 0.8
