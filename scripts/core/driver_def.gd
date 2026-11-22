class_name DriverDef extends Resource
## One selectable driver. Add a driver by adding one .tres file in data/drivers/.

enum Type { MODEL, PAPER }

@export var id := ""
@export var display_name := ""
@export var type := Type.MODEL
@export var sort_order := 100
## Face picture for the selection menu (tools/make_portraits.py). Empty: no picture.
@export var portrait: Texture2D

@export_group("3D model driver")
@export var model_scene: PackedScene
@export var animation := "drive"
@export var model_scale := 0.8

@export_group("Paper driver")
@export var front_texture: Texture2D
@export var back_texture: Texture2D
## Height of the card in metres; width follows the photo's aspect ratio.
@export var card_height := 0.8

@export_group("Toy vehicle")
## A toy that is a vehicle itself (motorbike, police car, plane): it replaces the kart
## instead of sitting in it. The kart's stats and sounds still apply.
@export var is_vehicle := false
## Width of the toy vehicle in metres (a kart is about 0.75 wide).
@export var vehicle_width := 1.0
## Height above the road in metres, for toys that fly.
@export var vehicle_hover := 0.0
