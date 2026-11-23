class_name Pond extends Node3D
## A toy pond on the lawn: bright toon water (assets/shaders/toon_water.gdshader) inside a sandy
## rim, lily pads drifting round and rubber ducks paddling in circles. Built when the track loads;
## the track builder stores only size and shape. It lies outside the walls, so no kart gets in.
## Trees and lawn patches keep away from it (Scatter.KEEP_OUT_GROUP, `keep_out_radius`).

const SHORE := 1.1     ## width of the sandy rim, metres
const WATER_Y := 0.06  ## water surface above the lawn
const SEGMENTS := 72
const RINGS := 6
const C_SAND := Color("f7c948")
const C_SAND_DARK := Color("e2a536")
const C_PAD := Color("2e9a3c")
const C_PAD_LIGHT := Color("5cc944")

## Middle radius of the water; the shore wobbles around it (shore_radius).
@export var radius := 7.0
@export var shape_seed := 1
@export var ducks := 1
@export var lily_pads := 5

## Nothing scattered (trees, patches) stands closer to the middle than this.
var keep_out_radius: float:
	get:
		return radius * 1.16 + SHORE + 1.2

var _ducks: Array[Node3D] = []
var _pads: Node3D
var _time := 0.0

## Distance from the middle to the water's edge in a direction (radians): a soft, uneven round.
static func shore_radius(angle: float, r: float, seed_value: int) -> float:
	return r * (1.0 + 0.1 * sin(2.0 * angle + seed_value * 1.7) + 0.06 * sin(3.0 * angle + seed_value * 2.9))

func _ready() -> void:
	_build_water()
	_build_rim()
	_build_pads()
	for k in ducks:
		var duck := _make_duck(1.0 if k == 0 else 0.55)
		add_child(duck)
		_ducks.append(duck)
	_place_ducks()

func _process(delta: float) -> void:
	_time += delta
	_place_ducks()
	if _pads:
		_pads.rotation.y = _time * 0.03
		_pads.position.y = sin(_time * 1.3) * 0.008

func _place_ducks() -> void:
	# Mum paddles in a slow circle, the little ones follow close behind.
	for k in _ducks.size():
		var a := _time * 0.16 - k * 0.32
		var r := radius * 0.5
		var duck := _ducks[k]
		duck.position = Vector3(cos(a) * r, WATER_Y + sin(_time * 2.3 + k) * 0.025, sin(a) * r)
		var heading := Vector3(-sin(a), 0.0, cos(a))
		duck.basis = Basis.looking_at(heading).rotated(heading, sin(_time * 1.7 + k) * 0.06).scaled(Vector3.ONE * duck.get_meta("size", 1.0))

# --- Building --------------------------------------------------------------------------------

func _edge(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle)) * shore_radius(angle, radius, shape_seed)

## Adds a triangle facing `n` (Godot draws the side where the corners run clockwise).
static func _tri(st: SurfaceTool, v: Array[Vector3], colors: Array[Color], uvs: Array[Vector2], n: Vector3) -> void:
	var order := [0, 1, 2]
	if (v[2] - v[0]).cross(v[1] - v[0]).dot(n) < 0.0:
		order = [0, 2, 1]
	for k: int in order:
		st.set_color(colors[k])
		st.set_uv(uvs[k])
		st.set_normal(n)
		st.add_vertex(v[k])

func _build_water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color.WHITE
	for s in SEGMENTS:
		var a0 := TAU * s / SEGMENTS
		var a1 := TAU * (s + 1) / SEGMENTS
		var e0 := _edge(a0)
		var e1 := _edge(a1)
		for k in RINGS:
			# Ring k runs from (k / RINGS) of the way out to (k + 1) / RINGS; UV.x is 1 in the middle, 0 at the shore.
			var f0 := float(k) / RINGS
			var f1 := float(k + 1) / RINGS
			var p00 := e0 * f0 + Vector3(0, WATER_Y, 0)
			var p01 := e1 * f0 + Vector3(0, WATER_Y, 0)
			var p10 := e0 * f1 + Vector3(0, WATER_Y, 0)
			var p11 := e1 * f1 + Vector3(0, WATER_Y, 0)
			var u0 := Vector2(1.0 - f0, 0.0)
			var u1 := Vector2(1.0 - f1, 0.0)
			_tri(st, [p00, p10, p11], [white, white, white], [u0, u1, u1], Vector3.UP)
			if k > 0:
				_tri(st, [p00, p11, p01], [white, white, white], [u0, u1, u0], Vector3.UP)
	var mesh := st.commit()
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/toon_water.gdshader")
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _build_rim() -> void:
	# Cross-section from the water outward: [metres past the water's edge, height, colour].
	var profile := [[-0.2, WATER_Y - 0.03, C_SAND], [0.25, 0.15, C_SAND], [0.6, 0.12, C_SAND], [SHORE, -0.03, C_SAND_DARK]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uv := Vector2.ZERO
	for s in SEGMENTS:
		var a0 := TAU * s / SEGMENTS
		var a1 := TAU * (s + 1) / SEGMENTS
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var r0 := shore_radius(a0, radius, shape_seed)
		var r1 := shore_radius(a1, radius, shape_seed)
		for k in profile.size() - 1:
			var pa: Array = profile[k]
			var pb: Array = profile[k + 1]
			var v00 := d0 * (r0 + float(pa[0])) + Vector3(0, pa[1], 0)
			var v01 := d1 * (r1 + float(pa[0])) + Vector3(0, pa[1], 0)
			var v10 := d0 * (r0 + float(pb[0])) + Vector3(0, pb[1], 0)
			var v11 := d1 * (r1 + float(pb[0])) + Vector3(0, pb[1], 0)
			var slope := Vector2(float(pb[0]) - float(pa[0]), float(pb[1]) - float(pa[1]))
			var n := (d0 * -slope.y + Vector3.UP * slope.x).normalized()
			var ca: Color = pa[2]
			var cb: Color = pb[2]
			_tri(st, [v00, v10, v11], [ca, cb, cb], [uv, uv, uv], n)
			_tri(st, [v00, v11, v01], [ca, cb, ca], [uv, uv, uv], n)
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	rim.mesh = st.commit()
	rim.material_override = _vertex_color_material(0.9)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)

func _build_pads() -> void:
	if lily_pads <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed * 31 + 5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uv := Vector2.ZERO
	for p in lily_pads:
		var a := TAU * (p + rng.randf_range(0.1, 0.6)) / lily_pads
		var center := Vector3(cos(a), 0, sin(a)) * shore_radius(a, radius, shape_seed) * rng.randf_range(0.66, 0.76) + Vector3(0, WATER_Y + 0.015, 0)
		var size := rng.randf_range(0.45, 0.75)
		var notch := rng.randf() * TAU
		var seg := 14
		for s in seg:
			if s == 0:
				continue  # the notch
			var a0 := notch + TAU * s / seg
			var a1 := notch + TAU * (s + 1) / seg
			var v1 := center + Vector3(cos(a0), 0, sin(a0)) * size
			var v2 := center + Vector3(cos(a1), 0, sin(a1)) * size
			_tri(st, [center, v1, v2], [C_PAD, C_PAD_LIGHT, C_PAD_LIGHT], [uv, uv, uv], Vector3.UP)
		if p % 2 == 0:
			# A pink water lily on every other pad.
			var top := center + Vector3(size * 0.2, 0.09, 0)
			for k in 6:
				var b0 := TAU * k / 6.0
				var b1 := TAU * (k + 0.5) / 6.0
				var b2 := TAU * (k + 1) / 6.0
				var tip := top + Vector3(cos(b1) * 0.22, 0.08, sin(b1) * 0.22)
				var c0 := top + Vector3(cos(b0) * 0.06, -0.06, sin(b0) * 0.06)
				var c2 := top + Vector3(cos(b2) * 0.06, -0.06, sin(b2) * 0.06)
				_tri(st, [c0, tip, c2], [Color("ff4fa3"), Color("ffd0e6"), Color("ff4fa3")], [uv, uv, uv], Vector3.UP)
			_tri(st, [top + Vector3(-0.05, 0.0, 0), top + Vector3(0.05, 0.0, 0), top + Vector3(0, 0.05, 0.06)],
				[Color("ffd21e"), Color("ffd21e"), Color("ffd21e")], [uv, uv, uv], Vector3.UP)
	var pads := MeshInstance3D.new()
	pads.name = "LilyPads"
	pads.mesh = st.commit()
	var material := _vertex_color_material(0.6)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	pads.material_override = material
	pads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pads)
	_pads = pads

static func _vertex_color_material(roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = roughness
	return material

## A yellow rubber duck about a metre long, front toward -z.
func _make_duck(size: float) -> Node3D:
	var duck := Node3D.new()
	duck.name = "Duck"
	duck.set_meta("size", size)
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color("ffd21e")
	yellow.roughness = 0.3
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color("ff7a00")
	orange.roughness = 0.35
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("1c1c24")
	black.roughness = 0.2
	var body := SphereMesh.new()
	body.radius = 0.5
	body.height = 1.0
	var head := SphereMesh.new()
	head.radius = 0.26
	head.height = 0.52
	var eye := SphereMesh.new()
	eye.radius = 0.045
	eye.height = 0.09
	var beak := BoxMesh.new()
	beak.size = Vector3(0.2, 0.07, 0.22)
	var tail := PrismMesh.new()
	tail.size = Vector3(0.3, 0.3, 0.2)
	var parts := [
		[body, yellow, Vector3(0, 0.12, 0), Vector3(0.78, 0.55, 1.0)],
		[head, yellow, Vector3(0, 0.55, -0.3), Vector3.ONE],
		[beak, orange, Vector3(0, 0.5, -0.58), Vector3.ONE],
		[eye, black, Vector3(0.14, 0.62, -0.47), Vector3.ONE],
		[eye, black, Vector3(-0.14, 0.62, -0.47), Vector3.ONE],
		[tail, yellow, Vector3(0, 0.36, 0.42), Vector3.ONE],
	]
	for part: Array in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = part[1]
		mi.position = part[2]
		mi.scale = part[3]
		duck.add_child(mi)
	return duck
