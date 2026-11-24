class_name Explorer extends RefCounted
## One player in the open world: a kart, whoever drives it, and the open-driving assist in
## between (InputSource -> Intent -> OpenAssist -> Kart). Also what the player carries.

var kart: Kart
var source: InputSource
var assist := OpenAssist.new()
var control_mode := 0
var player_index := 0
var color := Color.WHITE
var display_name := ""
## A friend's lost thing riding above the kart, on its way to the friend (or null).
var carrying: LostThing
## Metres driven (the checks report it).
var distance := 0.0
var found := 0

var _last := Vector3.INF

func tick(delta: float) -> void:
	var p := kart.ground_position()
	if _last != Vector3.INF:
		distance += Vector2(p.x - _last.x, p.z - _last.z).length()
	_last = p
	var raw := source.read(control_mode)
	kart.intent.copy_from(assist.apply(raw, kart, delta))

func reset_tracking() -> void:
	_last = Vector3.INF
