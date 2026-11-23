class_name GrassField extends Node3D
## Grass tufts, reeds and little flowers along a track, swaying in the wind (assets/shaders/grass.gdshader).
## The track builder stores only where each one stands; the copies are made when the track loads
## (a MultiMesh built without a window cannot be saved). They are cut into square chunks, one
## MultiMesh per chunk and kind, so the camera skips chunks it does not see and far chunks are
## not drawn at all. No shadows: those would cost the most.

const CHUNK := 16.0      ## chunk size in metres
const FADE_START := 30.0 ## grass starts sinking into the lawn this far from the camera ...
const FADE_END := 42.0   ## ... and is gone here
## Kinds: 0 grass tuft, 1 reeds, 2 and up a flower in FLOWER_COLORS[kind - 2].
const GRASS := 0
const REEDS := 1
const FLOWER := 2
const FLOWER_COLORS: Array[Color] = [
	Color("e3241b"), Color("ffd21e"), Color("2f7fe8"), Color("ff4fa3"), Color("ffffff"), Color("ff8a1e"), Color("9b4dff"),
]

## One entry per plant: x, y, z of its foot and its size.
@export var spots := PackedVector4Array()
## One kind per plant (see GRASS, REEDS, FLOWER).
@export var kinds := PackedByteArray()

func _ready() -> void:
	if spots.is_empty():
		return
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/grass.gdshader")
	material.set_shader_parameter("fade_start", FADE_START)
	material.set_shader_parameter("fade_end", FADE_END)
	var meshes: Array[Mesh] = [_tuft_mesh(), _reed_mesh(), _flower_mesh()]
	var buckets := {}  # Vector3i(chunk x, chunk z, mesh) -> PackedInt32Array
	for i in spots.size():
		var s := spots[i]
		var key := Vector3i(floori(s.x / CHUNK), floori(s.z / CHUNK), mini(kinds[i], FLOWER))
		if not buckets.has(key):
			buckets[key] = PackedInt32Array()
		var ids: PackedInt32Array = buckets[key]
		ids.append(i)
		buckets[key] = ids
	for key: Vector3i in buckets:
		var ids: PackedInt32Array = buckets[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = meshes[key.z]
		multi.instance_count = ids.size()
		for j in ids.size():
			var i := ids[j]
			var s := spots[i]
			var phase := fmod(i * 0.618034, 1.0)
			var stretch := 0.85 + 0.3 * fmod(i * 0.7548, 1.0)
			var basis := Basis(Vector3.UP, i * 2.39996).scaled(Vector3(s.w, s.w * stretch, s.w))
			multi.set_instance_transform(j, Transform3D(basis, Vector3(s.x, s.y, s.z)))
			var petal := FLOWER_COLORS[(kinds[i] - FLOWER) % FLOWER_COLORS.size()] if kinds[i] >= FLOWER else Color.WHITE
			multi.set_instance_custom_data(j, Color(petal.r, petal.g, petal.b, phase))
		var chunk := MultiMeshInstance3D.new()
		chunk.name = "Chunk_%d_%d_%d" % [key.x, key.y, key.z]
		chunk.multimesh = multi
		chunk.material_override = material
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.extra_cull_margin = 0.6  # the wind bends tips a little outside the mesh bounds
		chunk.visibility_range_end = FADE_END + CHUNK * 0.75
		add_child(chunk)

# --- Meshes (built once per track load; small) --------------------------------------------------

const C_ROOT := Color("2c9a36")
const C_TIP := Color("a2e83a")

## A tuft of seven chunky blades leaning outward, about 0.5 m tall.
static func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for j in 7:
		var a := TAU * j / 7.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0.0, sin(a))
		var r0 := rng.randf_range(0.02, 0.09)
		var h := rng.randf_range(0.3, 0.55)
		var lean := rng.randf_range(0.1, 0.24)
		_blade(st, out * r0, out * (r0 + lean), h, rng.randf_range(0.06, 0.085), C_ROOT, C_TIP)
	st.generate_normals()
	st.index()
	return st.commit()

## Tall thin reeds with two brown cattails, for pond shores.
static func _reed_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for j in 6:
		var a := TAU * j / 6.0 + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0.0, sin(a))
		var r0 := rng.randf_range(0.02, 0.08)
		_blade(st, out * r0, out * (r0 + rng.randf_range(0.08, 0.2)), rng.randf_range(0.75, 1.1), 0.05, Color("23883a"), Color("7fd23a"))
	for top: Vector3 in [Vector3(0.04, 1.2, 0.02), Vector3(-0.06, 1.0, -0.05)]:
		_stem(st, Vector3(top.x * 0.3, 0.0, top.z * 0.3), top, 0.018, Color("2c8f3a"), Color("4fae3a"))
		_prism(st, top - Vector3(0, 0.26, 0), top - Vector3(0, 0.03, 0), 0.05, Color("8a4b1e"))
	st.generate_normals()
	st.index()
	return st.commit()

## A flower: stem, two leaves and five flat petals (painted in the plant's colour) round a centre.
static func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0.0, 0.55, 0.0)
	_stem(st, Vector3.ZERO, top, 0.024, C_ROOT, Color("4fc23a"))
	for a: float in [0.6, 3.6]:
		var out := Vector3(cos(a), 0.0, sin(a))
		_blade(st, out * 0.01, out * 0.2, 0.22, 0.075, C_ROOT, Color("6fd23a"))
	# The head tilts ~45° to one side, so the low chase camera sees its face, not its edge
	# (each plant is turned a different way).
	var head := Basis(Vector3.BACK, -0.8)
	var petal := Color(1, 1, 1, 1)  # alpha 1: the shader paints the plant's colour
	for k in 5:
		var a := TAU * k / 5.0
		var d := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-d.z, 0.0, d.x)
		var lift := Vector3(0, 0.05, 0)
		var pts: Array[Vector3] = [
			d * 0.03, d * 0.12 + side * 0.09 + lift * 0.5, d * 0.23 + side * 0.075 + lift,
			d * 0.29 + lift * 1.2, d * 0.23 - side * 0.075 + lift, d * 0.12 - side * 0.09 + lift * 0.5,
		]
		for t in range(1, pts.size() - 1):
			for v: Vector3 in [pts[0], pts[t], pts[t + 1]]:
				_vertex(st, top + head * v, petal, 1.0)
	var middle := Color("ffb21e")
	middle.a = 0.0
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		var c := Vector3(0, 0.03, 0)
		for v: Vector3 in [c + Vector3(0, 0.025, 0), c + Vector3(cos(a0), 0, sin(a0)) * 0.075, c + Vector3(cos(a1), 0, sin(a1)) * 0.075]:
			_vertex(st, top + head * v, middle, 1.0)
	st.generate_normals()
	st.index()
	return st.commit()

static func _vertex(st: SurfaceTool, v: Vector3, color: Color, tip: float) -> void:
	st.set_color(color)
	st.set_uv(Vector2(0.0, tip))
	st.add_vertex(v)

## One blade from `base` to a tip that leans out to `tip_xz`, `h` tall, `w` wide at the root.
static func _blade(st: SurfaceTool, base: Vector3, tip_xz: Vector3, h: float, w: float, root: Color, tip_color: Color) -> void:
	var out := (tip_xz - base).normalized()
	var side := Vector3(-out.z, 0.0, out.x) * 0.5
	var mid := base.lerp(tip_xz, 0.4) + Vector3(0, h * 0.55, 0)
	var tip := tip_xz + Vector3(0, h, 0)
	root.a = 0.0
	tip_color.a = 0.0
	var b0 := base - side * w
	var b1 := base + side * w
	var m0 := mid - side * w * 0.8
	var m1 := mid + side * w * 0.8
	for tri: Array in [[b0, 0.0, b1, 0.0, m1, 0.55], [b0, 0.0, m1, 0.55, m0, 0.55], [m0, 0.55, m1, 0.55, tip, 1.0]]:
		for k in 3:
			var u: float = tri[k * 2 + 1]
			_vertex(st, tri[k * 2], root.lerp(tip_color, u), u)

## A thin upright stem: two crossed strips.
static func _stem(st: SurfaceTool, from: Vector3, to: Vector3, w: float, root: Color, top_color: Color) -> void:
	root.a = 0.0
	top_color.a = 0.0
	for side: Vector3 in [Vector3(w, 0, 0), Vector3(0, 0, w)]:
		for v: Array in [[from - side, 0.0], [from + side, 0.0], [to + side, 1.0], [from - side, 0.0], [to + side, 1.0], [to - side, 1.0]]:
			var u: float = v[1]
			_vertex(st, v[0], root.lerp(top_color, u), u)

## A four-sided upright block (cattail head), swaying with the tip.
static func _prism(st: SurfaceTool, from: Vector3, to: Vector3, r: float, color: Color) -> void:
	color.a = 0.0
	var corners: Array[Vector3] = [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
	for k in 4:
		var a := corners[k]
		var b := corners[(k + 1) % 4]
		for v: Vector3 in [from + a, to + a, to + b, from + a, to + b, from + b]:
			_vertex(st, v, color, 1.0)
	for v: Vector3 in [to + corners[0], to + Vector3(0, r * 1.5, 0), to + corners[2], to + corners[1], to + Vector3(0, r * 1.5, 0), to + corners[3]]:
		_vertex(st, v, color, 1.0)
