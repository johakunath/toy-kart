class_name ToyMotion extends Node3D
## Background life: a toy beside the track that moves a little, so the world feels alive.
## The track builder places it and sets the kind and numbers; everything is played from the
## transform it starts with, so it never drifts away. Nothing here touches the karts.

enum Kind {
	BOB,    ## floats up and down
	ROCK,   ## rocks from side to side, like a happy plush toy
	NOD,    ## tips forward and back
	HOP,    ## little jumps with a squash on landing (crowd figures)
	ORBIT,  ## flies or drives in a circle around where it was placed, facing the way it goes
	BLINK,  ## its children take turns being visible (police lights)
}

@export var kind := Kind.BOB
## Metres for BOB and HOP, radians for ROCK and NOD, banking for ORBIT.
@export var amount := 0.5
## Cycles per second; for ORBIT metres per second along the circle.
@export var speed := 0.5
## Start offset in seconds, so neighbours do not move in step.
@export var phase := 0.0
## ORBIT: radius of the circle in metres (negative flies the other way round).
@export var radius := 0.0
## An animation of the model to loop (Kenney figures: "emote-yes", "jump", "idle" ...).
@export var animation := ""
## Give the model the toy material look (soft rim light), like the drivers.
@export var toy_look := false

var _base: Transform3D
var _time := 0.0

func _ready() -> void:
	_base = transform
	_time = phase
	if toy_look:
		ToyLook.apply(self, ToyLook.Kind.DRIVER)
	if animation != "":
		for node in find_children("*", "AnimationPlayer", true, false):
			var player := node as AnimationPlayer
			if player.has_animation(animation):
				player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
				player.play(animation)
				player.speed_scale = 0.85 + fposmod(phase * 0.37, 0.4)
				player.seek(fposmod(phase, 1.0), true)
	if kind == Kind.BLINK:
		_blink()

func _process(delta: float) -> void:
	_time += delta
	var wave := sin(_time * TAU * speed)
	match kind:
		Kind.BOB:
			transform = Transform3D(_base.basis, _base.origin + Vector3.UP * wave * amount)
		Kind.ROCK:
			transform = Transform3D(_base.basis * Basis(Vector3.BACK, wave * amount), _base.origin)
		Kind.NOD:
			transform = Transform3D(_base.basis * Basis(Vector3.RIGHT, wave * amount), _base.origin)
		Kind.HOP:
			var up := absf(sin(_time * PI * speed))
			var squash := 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.25, up))
			var squash_basis := Basis.from_scale(Vector3(1.0 / sqrt(squash), squash, 1.0 / sqrt(squash)))
			transform = Transform3D(_base.basis * squash_basis, _base.origin + Vector3.UP * up * amount)
		Kind.ORBIT:
			var r := absf(radius)
			if r < 0.01:
				return
			var dir := signf(radius)
			var angle := _time * speed / r * dir
			var offset := Vector3(cos(angle), 0.0, sin(angle)) * r
			var heading := Vector3(-sin(angle), 0.0, cos(angle)) * dir
			var look := Basis.looking_at(heading, Vector3.UP, true)
			# Lean into the circle, and a gentle up and down.
			look = look * Basis(Vector3.BACK, -amount * dir)
			var bob := Vector3.UP * sin(_time * 0.7) * 0.6
			transform = Transform3D(look.scaled(_base.basis.get_scale()), _base.origin + offset + bob)
		Kind.BLINK:
			_blink()

func _blink() -> void:
	var count := get_child_count()
	if count == 0:
		return
	var on := int(_time * speed * count) % count
	for i in count:
		(get_child(i) as Node3D).visible = i == on
