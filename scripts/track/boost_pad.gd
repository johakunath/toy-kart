class_name BoostPad extends Area3D
## A glowing arrow strip on the road. Drive over it for a short turbo, no button needed.
## Built in code so the track builders can drop pads anywhere along the racing line.

const SIZE := Vector2(2.4, 3.4)   ## width across the road, length along it (metres)
const COOLDOWN := 0.6             ## per kart, so one pass gives one boost
const BOOST_SECONDS := 1.0        ## a clear, felt turbo (like the turbo item: 1.0 s at 0.35)
const BOOST_STRENGTH := 0.45      ## share of extra top speed
const KART_LAYER := 8             ## the kart balls' collision layer (scenes/kart.tscn)

static var _mesh: ArrayMesh
static var _material: StandardMaterial3D

var _arrows: MeshInstance3D
var _time := 0.0
var _last_hit := {}
var _sound: AudioStreamPlayer3D

func _ready() -> void:
	monitoring = true
	monitorable = false
	# The pads are made with BoostPad.new(): without this they look for layer 1 and never
	# see a kart (the kart balls are on layer 8, like the stars and bricks expect).
	collision_layer = 0
	collision_mask = KART_LAYER
	var shape := BoxShape3D.new()
	shape.size = Vector3(SIZE.x, 1.6, SIZE.y)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.6
	add_child(collision)
	if _mesh == null:
		_mesh = _build_mesh()
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		# The colours below are meant as written (sRGB); read as linear they look washed out.
		_material.vertex_color_is_srgb = true
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arrows = MeshInstance3D.new()
	_arrows.mesh = _mesh
	_arrows.material_override = _material
	_arrows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrows.position.y = -0.13
	add_child(_arrows)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = load("res://assets/sfx/turbo.wav")
	_sound.bus = &"Effects"
	_sound.max_distance = 35.0
	add_child(_sound)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	# A pulse so the pad reads as "something happens here": above 1.0 the colours glow (bloom).
	var glow := 1.0 + 0.25 * (0.5 + 0.5 * sin(_time * 6.0))
	_material.albedo_color = Color(glow, glow, glow)

func _on_body_entered(body: Node) -> void:
	# Not typed as Kart: track builder tools load this script before the Game autoload exists.
	var kart := body.get_parent()
	if kart == null or not kart.has_method("pad_boost") or kart.get("frozen"):
		return
	var now := _time  # game time: headless checks run faster than real time
	if now - float(_last_hit.get(kart.get_instance_id(), -10.0)) < COOLDOWN:
		return
	_last_hit[kart.get_instance_id()] = now
	kart.call("pad_boost", BOOST_SECONDS, BOOST_STRENGTH)
	_sound.pitch_scale = randf_range(0.95, 1.08)
	_sound.play()

## Three chevrons pointing forward (+Z) on a dark plate.
static func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := SIZE.x * 0.5
	var hl := SIZE.y * 0.5
	_quad(st, Vector3(-hw, 0.0, -hl), Vector3(hw, 0.0, -hl), Vector3(hw, 0.0, hl), Vector3(-hw, 0.0, hl), Color(0.15, 0.55, 1.0))
	var colors := [Color(1.0, 0.95, 0.3), Color(1.0, 0.8, 0.15), Color(1.0, 0.6, 0.1)]
	for k in 3:
		var tip := -hl + 0.6 + k * 1.0 + 0.6
		var back := tip - 0.6
		var w := hw - 0.25
		var t := 0.38
		var y := 0.02
		# Left and right arm of the chevron.
		_quad(st, Vector3(-w, y, back), Vector3(-w, y, back + t), Vector3(0, y, tip + t), Vector3(0, y, tip), colors[k])
		_quad(st, Vector3(0, y, tip), Vector3(0, y, tip + t), Vector3(w, y, back + t), Vector3(w, y, back), colors[k])
	return st.commit()

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_color(color)
		st.set_normal(Vector3.UP)
		st.add_vertex(v)
