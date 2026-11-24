class_name LostThing extends Node3D
## One of the 8 lost things in the living room: big, bright, glowing, turning slowly, with a
## soft beam of light above it so it can be seen from far away. Toy models from
## tools/blender/build_lost_things.py, simple shapes as a fallback.
## Found: it spins up and pops (the Fundkiste fills). A friend's thing rides above the kart
## until it reaches the friend.

const IDS: Array[String] = ["sock", "remote", "crayon", "puzzle", "brick", "dummy", "car", "dino"]
const GLOW := Color(1.0, 0.88, 0.4)

var id := ""
var for_friend := ""
var found := false
var carrier: Kart

var _model: Node3D
var _beam: MeshInstance3D
var _ring: MeshInstance3D
var _light: OmniLight3D
var _time := 0.0
var _leaving := false

## The picture of a thing (Fundkiste, bubbles): rendered from its model (.png), else drawn (.svg).
static func icon_path(thing_id: String) -> String:
	var png := "res://assets/icons/find_%s.png" % thing_id
	return png if ResourceLoader.exists(png) else "res://assets/icons/find_%s.svg" % thing_id

func setup(p_id: String, p_for: String) -> void:
	id = p_id
	for_friend = p_for
	name = "Lost_%s" % id

func _ready() -> void:
	_time = randf() * 3.0
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_build_model()
	# A soft column of light and a glowing ring on the floor.
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.albedo_color = Color(GLOW, 0.22)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.6
	beam_mesh.bottom_radius = 1.6
	beam_mesh.height = 4.2
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	_beam = MeshInstance3D.new()
	_beam.mesh = beam_mesh
	_beam.material_override = beam_mat
	_beam.position.y = 2.1
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	var ring_mat := beam_mat.duplicate() as StandardMaterial3D
	ring_mat.albedo_color = Color(GLOW, 0.5)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.4
	ring_mesh.outer_radius = 2.9
	_ring = MeshInstance3D.new()
	_ring.mesh = ring_mesh
	_ring.material_override = ring_mat
	_ring.position.y = 0.05
	_ring.scale = Vector3(1, 0.15, 1)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.light_energy = 1.6
	_light.omni_range = 8.0
	_light.position.y = 2.0
	add_child(_light)

func _process(delta: float) -> void:
	_time += delta
	if _leaving:
		return
	if carrier and is_instance_valid(carrier):
		var at := carrier.container.get_global_transform_interpolated().origin
		global_position = at + Vector3(0, 1.65 + sin(_time * 4.0) * 0.1, 0)
		_model.rotation.y += delta * 2.5
		return
	_model.position.y = 0.6 + sin(_time * 2.0) * 0.35
	_model.rotation.y += delta * 0.9
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	_ring.scale = Vector3(1.0 + pulse * 0.12, 0.15, 1.0 + pulse * 0.12)
	_light.light_energy = 1.2 + pulse * 0.8

## A friend's thing: it hops onto the kart and rides along.
func ride_on(kart: Kart) -> void:
	carrier = kart
	_beam.visible = false
	_ring.visible = false
	_light.omni_range = 5.0
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE * 0.32, 0.35).set_trans(Tween.TRANS_BACK)
	_model.position.y = 0.0

## Found: a happy spin up into the air, then pop.
func celebrate() -> void:
	_leaving = true
	_beam.visible = false
	_ring.visible = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_model, "position:y", 9.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "rotation:y", _model.rotation.y + TAU * 3.0, 0.9)
	tween.tween_property(_model, "scale", Vector3.ONE * 1.5, 0.9)
	tween.chain().tween_property(_model, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(hide)  # stays in the list of things, just gone
	_burst(global_position + Vector3(0, 3.0, 0))

## Given to a friend: it flies into the friend's arms and stays there.
func fly_to(spot: Vector3) -> void:
	_leaving = true
	carrier = null
	_light.visible = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", spot, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_model, "scale", Vector3.ONE * 0.8, 0.7)
	_burst(spot)

## Coloured paper bits flying out.
func _burst(at: Vector3) -> void:
	var parts := GPUParticles3D.new()
	parts.amount = 60
	parts.one_shot = true
	parts.explosiveness = 0.95
	parts.lifetime = 1.4
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 70.0
	process.initial_velocity_min = 6.0
	process.initial_velocity_max = 11.0
	process.gravity = Vector3(0, -12.0, 0)
	process.angular_velocity_min = -360.0
	process.angular_velocity_max = 360.0
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	colors.colors = PackedColorArray([Color("e8483f"), Color("f2b90f"), Color("3b8beb"), Color("3fbf5f")])
	var ramp := GradientTexture1D.new()
	ramp.gradient = colors
	process.color_initial_ramp = ramp
	parts.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.35)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	parts.draw_pass_1 = quad
	get_parent().add_child(parts)
	parts.global_position = at
	parts.emitting = true
	get_tree().create_timer(2.0).timeout.connect(parts.queue_free)

# --- The models ------------------------------------------------------------------------------

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.35
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.6
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.25
	mat.rim_enabled = true
	mat.rim = 0.4
	return mat

func _add(mesh: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO, scale_by := Vector3.ONE) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _mat(color)
	inst.position = pos
	inst.rotation = rot
	inst.scale = scale_by
	_model.add_child(inst)
	return inst

static func _boxm(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

static func _cylm(r_top: float, r_bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = height
	m.radial_segments = 20
	return m

static func _capm(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m

static func _ballm(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m

## The toy models from tools/blender/build_lost_things.py (scale: the dino is drawn big).
const MODEL := "res://assets/models/finds/%s.glb"
const MODEL_SCALE := {"dino": 0.8}

func _build_model() -> void:
	if ResourceLoader.exists(MODEL % id):
		var scene := load(MODEL % id) as PackedScene
		if scene:
			var model := scene.instantiate() as Node3D
			model.scale = Vector3.ONE * float(MODEL_SCALE.get(id, 1.0))
			_model.add_child(model)
			ToyLook.apply(model, ToyLook.Kind.KART)
			return
	# Fallback: simple shapes (also what the models were sized after).
	match id:
		"sock":
			_add(_capm(0.75, 3.4), Color("e8483f"), Vector3(0, 0.75, -0.4), Vector3(PI * 0.5, 0, 0))
			_add(_capm(0.75, 2.6), Color("e8483f"), Vector3(0, 1.6, 1.0), Vector3(0.5, 0, 0))
			_add(_cylm(0.8, 0.8, 0.6), Color("fffdf5"), Vector3(0, 2.4, 1.5), Vector3(0.5, 0, 0))
			for k in 3:
				_add(_ballm(0.28), Color("ffd23f"), Vector3(0.62, 0.8, -1.4 + k * 0.9))
		"remote":
			_add(_boxm(Vector3(1.6, 0.6, 4.4)), Color("3a3d4a"), Vector3(0, 0.3, 0))
			_add(_cylm(0.3, 0.3, 0.2), Color("e8483f"), Vector3(0, 0.7, -1.5))
			var colors: Array[Color] = [Color("3b8beb"), Color("3fbf5f"), Color("ffd23f"), Color("fffdf5")]
			for k in 4:
				_add(_boxm(Vector3(0.45, 0.2, 0.45)), colors[k], Vector3(-0.35 + (k % 2) * 0.7, 0.68, -0.2 + floorf(k / 2.0) * 0.7))
		"crayon":
			_add(_cylm(0.5, 0.5, 4.0), Color("3b8beb"), Vector3(0, 0.5, 0), Vector3(PI * 0.5, 0, 0))
			_add(_cylm(0.0, 0.5, 1.0), Color("f4d1a0"), Vector3(0, 0.5, -2.5), Vector3(-PI * 0.5, 0, 0))
			_add(_cylm(0.52, 0.52, 1.6), Color("fffdf5"), Vector3(0, 0.5, 0.6), Vector3(PI * 0.5, 0, 0))
		"puzzle":
			_add(_boxm(Vector3(5.0, 0.5, 5.0)), Color("3fbf5f"), Vector3(0, 0.25, 0))
			_add(_cylm(1.0, 1.0, 0.5), Color("3fbf5f"), Vector3(0, 0.25, -3.0))
			_add(_cylm(1.0, 1.0, 0.5), Color("3fbf5f"), Vector3(3.0, 0.25, 0))
			_add(_cylm(1.1, 1.1, 0.55), Color("ffd23f"), Vector3(-0.8, 0.3, 0.8))
		"brick":
			_add(_boxm(Vector3(3.2, 1.9, 1.6)), Color("ffd23f"), Vector3(0, 0.95, 0))
			for k in 4:
				_add(_cylm(0.5, 0.5, 0.45), Color("ffd23f"), Vector3(-1.2 + k * 0.8, 2.1, 0))
		"dummy":
			_add(_cylm(1.5, 1.5, 0.5), Color("a55de0"), Vector3(0, 1.8, 0), Vector3(PI * 0.5, 0, 0), Vector3(1.4, 1, 1))
			_add(_ballm(0.75), Color("f9c5d9"), Vector3(0, 1.8, 0.9), Vector3.ZERO, Vector3(1, 1, 1.3))
			var ring := TorusMesh.new()
			ring.inner_radius = 0.55
			ring.outer_radius = 0.95
			_add(ring, Color("a55de0"), Vector3(0, 1.8, -0.7), Vector3(PI * 0.5, 0, 0))
		"car":
			_add(_boxm(Vector3(2.0, 0.9, 3.8)), Color("f08a24"), Vector3(0, 0.95, 0))
			_add(_boxm(Vector3(1.7, 0.8, 1.8)), Color("bfe8ff"), Vector3(0, 1.8, 0.2))
			for x: float in [-1.05, 1.05]:
				for z: float in [-1.2, 1.2]:
					_add(_cylm(0.55, 0.55, 0.4), Color("2a2b33"), Vector3(x, 0.55, z), Vector3(0, 0, PI * 0.5))
		"dino":
			_add(_capm(1.0, 3.6), Color("3fbf5f"), Vector3(0, 2.0, 0), Vector3(PI * 0.5, 0, 0))
			_add(_capm(0.5, 2.2), Color("3fbf5f"), Vector3(0, 3.2, -1.8), Vector3(-0.6, 0, 0))
			_add(_ballm(0.75), Color("3fbf5f"), Vector3(0, 4.1, -2.4))
			_add(_cylm(0.0, 0.6, 2.6), Color("3fbf5f"), Vector3(0, 1.8, 2.6), Vector3(PI * 0.5 + 0.25, 0, 0))
			for x: float in [-0.6, 0.6]:
				for z: float in [-0.9, 0.9]:
					_add(_cylm(0.3, 0.35, 1.4), Color("2f9e4c"), Vector3(x, 0.7, z))
			for k in 3:
				_add(_cylm(0.0, 0.35, 0.8), Color("ffd23f"), Vector3(0, 3.1, -0.8 + k * 0.8))
			_add(_ballm(0.15), Color("1d2b53"), Vector3(0.55, 4.3, -2.7))
			_add(_ballm(0.15), Color("1d2b53"), Vector3(-0.55, 4.3, -2.7))
