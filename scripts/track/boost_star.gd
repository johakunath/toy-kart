class_name BoostStar extends Area3D
## A spinning star on the track. Drive through it to get an item, with a sound and a sparkle.
## Every kart has its own star: one kart taking it pops it for a moment, but it stays there for
## the others, so the karts at the back get items too (Mario Kart item boxes).

const PICKUP_RADIUS := 0.7       ## metres (plus the kart ball's 0.5): drive through it, not past it
const KART_COOLDOWN := 6.0       ## seconds before the same kart can take this star again
const REGROW_SECONDS := 0.5      ## the popped star grows back this fast for the others

@onready var mesh_instance: MeshInstance3D = $Star
@onready var burst: GPUParticles3D = $Burst
@onready var sound: AudioStreamPlayer3D = $Sound

var _time := 0.0
var _hidden_for := 0.0
var _taken_at := {}              ## kart instance id -> time it took this star
static var _shared_mesh: ArrayMesh

func _ready() -> void:
	if _shared_mesh == null:
		_shared_mesh = _build_star_mesh(0.55, 0.25, 0.09)
	mesh_instance.mesh = _shared_mesh
	_time = randf() * TAU
	var shape := ($Shape as CollisionShape3D).shape as SphereShape3D
	if shape and shape.radius != PICKUP_RADIUS:
		var small := shape.duplicate() as SphereShape3D
		small.radius = PICKUP_RADIUS
		($Shape as CollisionShape3D).shape = small
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	mesh_instance.rotation.y = _time * 2.2
	mesh_instance.position.y = 0.95 + sin(_time * 2.5) * 0.1
	if _hidden_for > 0.0:
		_hidden_for -= delta
		if _hidden_for <= 0.0:
			mesh_instance.visible = true
			mesh_instance.scale = Vector3.ONE * 0.01
	elif mesh_instance.scale.x < 1.0:
		mesh_instance.scale = mesh_instance.scale.lerp(Vector3.ONE, minf(1.0, delta * 8.0))

func _on_body_entered(body: Node) -> void:
	var kart := body.get_parent() as Kart
	if kart == null:
		return
	var now := _time  # game time: headless checks run faster than real time
	var id := kart.get_instance_id()
	if _taken_at.has(id) and now - float(_taken_at[id]) < KART_COOLDOWN:
		return
	if not kart.give_item():
		return  # hands full: the star stays for later
	_taken_at[id] = now
	mesh_instance.visible = false
	_hidden_for = REGROW_SECONDS
	burst.restart()
	burst.emitting = true
	sound.pitch_scale = randf_range(0.95, 1.08)
	sound.play()

## A flat five-point star with a little thickness, pointing up, facing +Z.
static func _build_star_mesh(outer: float, inner: float, half_depth: float) -> ArrayMesh:
	var ring: Array[Vector2] = []
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		var a := PI / 2.0 + i * TAU / 10.0
		ring.append(Vector2(cos(a), sin(a)) * r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [1.0, -1.0]:
		var z := half_depth * side
		var normal := Vector3(0, 0, side)
		var bulge := Vector3(0, 0, z * 2.2)  # centre sticks out a bit, so light catches the facets
		for i in 10:
			var a := ring[i]
			var b := ring[(i + 1) % 10]
			var va := Vector3(a.x, a.y, z)
			var vb := Vector3(b.x, b.y, z)
			var n := (vb - bulge).cross(va - bulge).normalized() * side
			if n.dot(normal) < 0.0:
				n = -n
			st.set_normal(n)
			if side > 0.0:
				st.add_vertex(bulge)
				st.add_vertex(vb)
				st.add_vertex(va)
			else:
				st.add_vertex(bulge)
				st.add_vertex(va)
				st.add_vertex(vb)
	for i in 10:
		var a := ring[i]
		var b := ring[(i + 1) % 10]
		var edge := Vector3(b.x - a.x, b.y - a.y, 0)
		var n := edge.cross(Vector3(0, 0, 1)).normalized()
		st.set_normal(n)
		var a_front := Vector3(a.x, a.y, half_depth)
		var a_back := Vector3(a.x, a.y, -half_depth)
		var b_front := Vector3(b.x, b.y, half_depth)
		var b_back := Vector3(b.x, b.y, -half_depth)
		st.add_vertex(a_front)
		st.add_vertex(b_front)
		st.add_vertex(b_back)
		st.add_vertex(a_front)
		st.add_vertex(b_back)
		st.add_vertex(a_back)
	return st.commit()
