class_name MagicRope extends Node3D
## The glowing "magic rope" from dad's kart to the kid's kart: a candy-striped tube in strong
## colours with a soft halo and sparkles that flow from dad to the kid. Seen from every camera
## (a real tube, no billboards), so it works in both halves of the split screen.
## It shoots out from dad's end when it connects and pulls back when it lets go.

const SEGMENTS := 28
const SIDES := 8
const CORE_RADIUS := 0.16
const HALO_RADIUS := 0.42
const SAG := 0.35              ## metres the middle of the rope hangs down
const BEADS := 14              ## sparkles riding along the rope
const BEAD_COLORS: Array[Color] = [
	Color(1.0, 0.95, 0.6), Color(1.0, 0.4, 0.8), Color(0.4, 0.9, 1.0), Color(1.0, 0.8, 0.2),
]

var _core := MeshInstance3D.new()
var _halo := MeshInstance3D.new()
var _core_mesh := ImmediateMesh.new()
var _halo_mesh := ImmediateMesh.new()
var _core_mat := ShaderMaterial.new()
var _halo_mat := ShaderMaterial.new()
var _beads: Array[MeshInstance3D] = []
var _time := 0.0

func _init() -> void:
	name = "MagicRope"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_core_mat.shader = load("res://scripts/race/magic_rope_core.gdshader") as Shader
	_halo_mat.shader = load("res://scripts/race/magic_rope_halo.gdshader") as Shader
	for part: MeshInstance3D in [_core, _halo]:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(part)
	_core.mesh = _core_mesh
	_halo.mesh = _halo_mesh
	_core.material_override = _core_mat
	_halo.material_override = _halo_mat
	var sparkle := load("res://assets/fx/sparkle.png") as Texture2D
	for i in BEADS:
		var bead := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.55, 0.55)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = sparkle
		mat.albedo_color = BEAD_COLORS[i % BEAD_COLORS.size()] * 2.2
		mat.no_depth_test = false
		quad.material = mat
		bead.mesh = quad
		bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bead)
		_beads.append(bead)
	visible = false

## Draws the rope from `from` (dad's tail) toward `to` (the kid's nose). strength 0..1:
## 0 = gone, rising = shooting out from dad, 1 = tight and glowing.
func draw_rope(from: Vector3, to: Vector3, strength: float, delta: float) -> void:
	_time += delta
	visible = strength > 0.01
	if not visible:
		return
	var reach := clampf(strength * 1.6, 0.0, 1.0)  # the rope shoots out from dad's end
	var fade := clampf(strength * 2.0, 0.0, 1.0)
	var thick := lerpf(0.4, 1.0, clampf(strength * 1.4, 0.0, 1.0))
	_core_mat.set_shader_parameter("fade", fade)
	_halo_mat.set_shader_parameter("fade", fade)
	var length := from.distance_to(to)
	_build_tube(_core_mesh, from, to, reach, CORE_RADIUS * thick, length)
	_build_tube(_halo_mesh, from, to, reach, HALO_RADIUS * thick, length)
	for i in _beads.size():
		var bead := _beads[i]
		var t := fposmod(float(i) / BEADS + _time * 0.5, 1.0)
		bead.visible = t < reach
		if not bead.visible:
			continue
		var p := _point(from, to, t)
		var side := _side(from, to)
		var spin := _time * 6.0 + float(i) * 1.7
		p += side * cos(spin) * 0.2 + Vector3.UP * sin(spin) * 0.2
		bead.global_position = p
		var twinkle := 0.6 + 0.5 * absf(sin(_time * 7.0 + float(i) * 2.3))
		bead.scale = Vector3.ONE * twinkle * fade

## A point on the rope (t = 0 at dad, 1 at the kid): a gentle hanging curve with a small wave.
func _point(from: Vector3, to: Vector3, t: float) -> Vector3:
	var p := from.lerp(to, t)
	var hang := sin(t * PI)
	p.y -= SAG * hang
	p += _side(from, to) * sin(_time * 4.0 + t * 7.0) * 0.12 * hang
	return p

func _side(from: Vector3, to: Vector3) -> Vector3:
	var d := to - from
	d.y = 0.0
	if d.length_squared() < 0.0001:
		return Vector3.RIGHT
	return Vector3.UP.cross(d.normalized())

func _build_tube(mesh: ImmediateMesh, from: Vector3, to: Vector3, reach: float, radius: float, length: float) -> void:
	mesh.clear_surfaces()
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var ts: Array[float] = []
	for k in SEGMENTS + 1:
		var t := reach * float(k) / SEGMENTS
		var p := _point(from, to, t)
		var ahead := _point(from, to, minf(t + 0.01, 1.0))
		var behind := _point(from, to, maxf(t - 0.01, 0.0))
		var tangent := (ahead - behind).normalized()
		var right := tangent.cross(Vector3.UP)
		if right.length_squared() < 0.0001:
			right = Vector3.RIGHT
		right = right.normalized()
		var up := right.cross(tangent).normalized()
		# Thinner at both ends, so the rope looks tied on instead of cut off.
		var taper := clampf(minf(t, reach - t) * length / 0.6, 0.35, 1.0)
		var ring := PackedVector3Array()
		var ring_n := PackedVector3Array()
		for j in SIDES + 1:
			var a := TAU * float(j) / SIDES
			var n := right * cos(a) + up * sin(a)
			ring.append(p + n * radius * taper)
			ring_n.append(n)
		rings.append(ring)
		normals.append(ring_n)
		ts.append(t)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in SEGMENTS:
		for j in SIDES:
			var quad := [[k, j], [k + 1, j], [k + 1, j + 1], [k, j], [k + 1, j + 1], [k, j + 1]]
			for corner: Array in quad:
				var ki: int = corner[0]
				var ji: int = corner[1]
				var t: float = ts[ki]
				# UV2.x fades the free end while the rope is still shooting out.
				var end_fade := 1.0 if reach >= 1.0 else clampf((reach - t) * 6.0, 0.0, 1.0)
				mesh.surface_set_normal(normals[ki][ji])
				mesh.surface_set_uv(Vector2(t * length, float(ji) / SIDES))
				mesh.surface_set_uv2(Vector2(end_fade, 0.0))
				mesh.surface_add_vertex(rings[ki][ji])
	mesh.surface_end()
