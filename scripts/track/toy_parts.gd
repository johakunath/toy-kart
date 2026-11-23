class_name ToyParts extends RefCounted
## Builds a small toy figure (teddy, owl, hedgehog ...) at runtime from primitive shapes: every
## shape is merged into one mesh with one surface per colour, so a whole figure costs a few
## draw calls. Balls can be squashed into eggs; their normals stay correct.
##
##   var parts := ToyParts.new(0.8)
##   parts.ball(Vector3(0, 1, 0), Vector3(1.0, 1.3, 0.9), Color("e8731e"))
##   add_child(parts.instance())

var _rough := 0.6
var _coat := 0.0
var _parts := {}                  ## Color -> SurfaceTool
static var _materials := {}       ## "color/rough/coat" -> StandardMaterial3D
static var _arrays := {}          ## mesh key -> mesh arrays

func _init(rough := 0.6, coat := 0.0) -> void:
	_rough = rough
	_coat = coat

## A ball (or an egg, with three radii) around `at`, turned by `basis`.
func ball(at: Vector3, radii: Vector3, color: Color, basis := Basis.IDENTITY, detail := 1) -> void:
	var key := "ball%d" % detail
	if not _arrays.has(key):
		var mesh := SphereMesh.new()
		mesh.radial_segments = 14 * detail
		mesh.rings = 7 * detail
		_arrays[key] = mesh.get_mesh_arrays()
	add(_arrays[key], Transform3D(basis * Basis.from_scale(radii), at), color)

## A cylinder or cone (top radius 0) standing along the basis' y axis, centred on `at`.
func cylinder(at: Vector3, top: float, bottom: float, height: float, color: Color, basis := Basis.IDENTITY, sides := 12) -> void:
	var key := "cyl%.3f/%.3f/%d" % [top / maxf(bottom, 0.001), height / maxf(bottom, 0.001), sides]
	var scale := maxf(bottom, 0.001)
	if not _arrays.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = top / scale
		mesh.bottom_radius = 1.0
		mesh.height = height / scale
		mesh.radial_segments = sides
		mesh.rings = 1
		_arrays[key] = mesh.get_mesh_arrays()
	add(_arrays[key], Transform3D(basis * Basis.from_scale(Vector3.ONE * scale), at), color)

func box(at: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
	if not _arrays.has("box"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		_arrays["box"] = mesh.get_mesh_arrays()
	add(_arrays["box"], Transform3D(basis * Basis.from_scale(size), at), color)

## Adds mesh arrays moved by `xform` (no mirroring). Normals use the inverse transpose, so
## squashed balls still shade like eggs.
func add(arrays: Array, xform: Transform3D, color: Color) -> void:
	if not _parts.has(color):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_parts[color] = st
	var st := _parts[color] as SurfaceTool
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nb := xform.basis.inverse().transposed()
	for k in indices:
		st.set_normal((nb * normals[k]).normalized())
		st.add_vertex(xform * verts[k])

## The finished figure as one MeshInstance3D (empty parts are fine).
func instance(shadow := true) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for color: Color in _parts:
		var st := _parts[color] as SurfaceTool
		st.index()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(color, _rough, _coat))
	_parts.clear()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	if not shadow:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static func material(color: Color, rough := 0.6, coat := 0.0) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f" % [color.to_html(), rough, coat]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	if coat > 0.0:
		mat.clearcoat_enabled = true
		mat.clearcoat = coat
		mat.clearcoat_roughness = 0.3
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.rim_tint = 0.85
	_materials[key] = mat
	return mat
