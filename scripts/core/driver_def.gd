class_name DriverDef extends Resource
## One selectable driver. Add a driver by adding one .tres file in data/drivers/.

enum Type { MODEL, PAPER }
enum AiLane { ANY, MIDDLE, INSIDE, OUTSIDE }

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
## Stretch of a 3D toy vehicle along its length (1.0 = as modelled), for a toy that looks too short.
@export var vehicle_stretch := 1.0
## How far the toy tilts in curves, in radians at full steer and speed. A car only rocks a little
## so its wheels stay on the road; bikes and planes lean into the curve.
@export_range(0.0, 0.6, 0.01) var vehicle_tilt := 0.05

@export_group("AI personality")
## How this toy drives when the computer drives it (AiSource). Style only: the race's pacing
## still decides how fast it goes, and none of this touches human karts or the kid assist.
## Preferred lane: ANY wanders, MIDDLE stays near the racing line, INSIDE / OUTSIDE lean
## toward that side of the coming bend.
@export var ai_lane := AiLane.ANY
## 0..1: how often it makes a harmless little weave on a straight (up to 4 per minute).
@export_range(0.0, 1.0, 0.05) var ai_wobble := 0.2
## 0..1: how often it honks just for fun (up to 4 per minute).
@export_range(0.0, 1.0, 0.05) var ai_horn := 0.3
## Honks like a siren: a quick high-low "tatü-tata" instead of a single honk.
@export var ai_siren := false
## 0..1: how often it shows off with a hop and a spin on straights and after overtaking.
@export_range(0.0, 1.0, 0.05) var ai_show_off := 0.2
## 0..1: chance of a happy honk and a little jump when a kid passes it, and of a cheer when
## it crosses the line behind a kid.
@export_range(0.0, 1.0, 0.05) var ai_friendly := 0.7
## 0..1: chance it takes a side lane (Track.forks) on a lap.
@export_range(0.0, 1.0, 0.05) var ai_brave := 0.4
