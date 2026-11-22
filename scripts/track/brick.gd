class_name Brick extends Area3D
## A toy brick floating over the road. Drive through it: +1 brick (up to Kart.MAX_BRICKS, each a
## little extra top speed), a pop, and it comes back after a few seconds. Placed by the race.

const RESPAWN_SECONDS := 6.0
const COLORS: Array[Color] = [Color("e8483f"), Color("3b8beb"), Color("f2b90f"), Color("3fbf5f")]

static var _meshes: Array[ArrayMesh] = []

var _mesh_instance: MeshInstance3D
var _hidden_for := 0.0
var _time := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 8  # the kart balls
	monitorable = false
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.5
	add_child(collision)
	if _meshes.is_empty():
		for color in COLORS:
			_meshes.append(_build_mesh(color))
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _meshes[absi(hash(name)) % _meshes.size()]
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	_mesh_instance.rotation.y = _time * 1.8
	_mesh_instance.position.y = 0.75 + sin(_time * 3.0) * 0.08
	if _hidden_for > 0.0:
		_hidden_for -= delta
		if _hidden_for <= 0.0:
			_mesh_instance.visible = true
			set_deferred("monitoring", true)

func _on_body_entered(body: Node) -> void:
	if _hidden_for > 0.0:
		return
	var kart := body.get_parent() as Kart
	if kart == null:
		return
	kart.add_brick()
	_mesh_instance.visible = false
	set_deferred("monitoring", false)
	_hidden_for = RESPAWN_SECONDS

## A 2x1 toy brick with two studs, about 0.5 m long.
static func _build_mesh(color: Color) -> ArrayMesh:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.3
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.6
	mat.rim_enabled = true
	mat.rim = 0.3
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.25
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.28, 0.25)
	var stud := CylinderMesh.new()
	stud.top_radius = 0.075
	stud.bottom_radius = 0.075
	stud.height = 0.08
	stud.radial_segments = 12
	stud.rings = 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(box, 0, Transform3D.IDENTITY)
	for x: float in [-0.125, 0.125]:
		st.append_from(stud, 0, Transform3D(Basis.IDENTITY, Vector3(x, 0.18, 0)))
	st.set_material(mat)
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh
