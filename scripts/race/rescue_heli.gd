class_name RescueHeli extends Node3D
## The toy rescue helicopter: when a kart is put back on the road, it hangs on a rope under a
## little red helicopter, is lowered onto the road, and the helicopter flies off. Only the
## picture is lowered; the kart itself is already on the road and can drive at once (the kid
## never waits). Built from simple shapes in toy colours.

const LOWER_SECONDS := 0.75
const LEAVE_SECONDS := 1.4
const DROP_HEIGHT := 3.2
const HANG := 2.8              ## rope length from the helicopter to the kart's roof

var _kart: Kart
var _time := 0.0
var _rotor: Node3D
var _tail_rotor: Node3D
var _rope: MeshInstance3D
var _leave_dir := Vector3.FORWARD

static var _parts := {}

## Starts the rescue of a kart that was just placed back on the road.
func carry(kart: Kart) -> void:
	_kart = kart
	_build()
	_leave_dir = kart.forward()
	_leave_dir.y = 0.0
	_leave_dir = _leave_dir.normalized()
	kart.drop_in(DROP_HEIGHT, LOWER_SECONDS)
	_follow()

func _process(delta: float) -> void:
	if _kart == null or not is_instance_valid(_kart):
		queue_free()
		return
	_time += delta
	_rotor.rotation.y += delta * 28.0
	_tail_rotor.rotation.x += delta * 34.0
	if _time < LOWER_SECONDS:
		_follow()
		return
	# Let go and fly away: up and on, tipping forward a little, then gone.
	var t := (_time - LOWER_SECONDS) / LEAVE_SECONDS
	_rope.visible = false
	global_position += (_leave_dir * 9.0 + Vector3.UP * 7.0) * delta
	rotation.x = lerpf(rotation.x, -0.25, delta * 3.0)
	scale = Vector3.ONE * maxf(0.01, 1.0 - maxf(t - 0.6, 0.0) * 2.5)
	if t >= 1.0:
		queue_free()

## Hover over the kart's picture while it is lowered, the rope reaching down to its roof.
func _follow() -> void:
	var low := _kart.visual.global_position
	global_position = low + Vector3.UP * (1.3 + HANG) + Vector3.UP * sin(_time * 6.0) * 0.05
	var fwd := _kart.forward()
	var yaw := atan2(fwd.x, fwd.z)  # the model's nose is +Z
	rotation = Vector3(0.0, yaw, sin(_time * 3.0) * 0.06)
	var length := global_position.y - (low.y + 1.25) - 0.35
	_rope.scale = Vector3(1.0, maxf(length, 0.1), 1.0)
	_rope.position = Vector3(0, -0.35 - maxf(length, 0.1) * 0.5, 0)

func _build() -> void:
	var red := _mat(Color("e8243c"))
	var yellow := _mat(Color("ffc81e"))
	var glass := _mat(Color("8fd6ff"), 0.1)
	var dark := _mat(Color("2a2b33"))
	_add(_mesh("body", func() -> Mesh:
		var m := SphereMesh.new()
		m.radius = 0.55
		m.height = 1.1
		return m), red, Vector3.ZERO, Vector3(1.0, 0.85, 1.3))
	_add(_mesh("cockpit", func() -> Mesh:
		var m := SphereMesh.new()
		m.radius = 0.36
		m.height = 0.72
		return m), glass, Vector3(0, 0.08, 0.42), Vector3(1.0, 0.85, 0.8))
	_add(_mesh("boom", func() -> Mesh:
		var m := CylinderMesh.new()
		m.top_radius = 0.09
		m.bottom_radius = 0.16
		m.height = 1.3
		return m), yellow, Vector3(0, 0.12, -0.95), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	_add(_mesh("fin", func() -> Mesh:
		var m := BoxMesh.new()
		m.size = Vector3(0.06, 0.4, 0.28)
		return m), red, Vector3(0, 0.32, -1.55), Vector3.ONE)
	for side: float in [-1.0, 1.0]:
		_add(_mesh("skid", func() -> Mesh:
			var m := CylinderMesh.new()
			m.top_radius = 0.04
			m.bottom_radius = 0.04
			m.height = 1.2
			return m), dark, Vector3(side * 0.42, -0.58, 0.05), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
		_add(_mesh("strut", func() -> Mesh:
			var m := BoxMesh.new()
			m.size = Vector3(0.05, 0.25, 0.05)
			return m), dark, Vector3(side * 0.36, -0.45, 0.05), Vector3.ONE)
	_add(_mesh("mast", func() -> Mesh:
		var m := CylinderMesh.new()
		m.top_radius = 0.06
		m.bottom_radius = 0.06
		m.height = 0.25
		return m), dark, Vector3(0, 0.55, 0), Vector3.ONE)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 0.68, 0)
	add_child(_rotor)
	for angle: float in [0.0, PI * 0.5]:
		var blade := MeshInstance3D.new()
		blade.mesh = _mesh("blade", func() -> Mesh:
			var m := BoxMesh.new()
			m.size = Vector3(2.4, 0.04, 0.16)
			return m)
		blade.material_override = yellow
		blade.rotation.y = angle
		_rotor.add_child(blade)
	_tail_rotor = Node3D.new()
	_tail_rotor.position = Vector3(0.1, 0.3, -1.55)
	add_child(_tail_rotor)
	var small := MeshInstance3D.new()
	small.mesh = _mesh("tail_blade", func() -> Mesh:
		var m := BoxMesh.new()
		m.size = Vector3(0.03, 0.6, 0.08)
		return m)
	small.material_override = yellow
	_tail_rotor.add_child(small)
	# The rope: a thin cylinder 1 m long, stretched each frame, with a hook at the end.
	_rope = MeshInstance3D.new()
	_rope.mesh = _mesh("rope", func() -> Mesh:
		var m := CylinderMesh.new()
		m.top_radius = 0.025
		m.bottom_radius = 0.025
		m.height = 1.0
		m.radial_segments = 6
		return m)
	_rope.material_override = dark
	add_child(_rope)

func _add(mesh: Mesh, mat: Material, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.rotation = rot
	inst.scale = size
	add_child(inst)

static func _mesh(key: String, make: Callable) -> Mesh:
	if not _parts.has(key):
		_parts[key] = make.call()
	return _parts[key]

static func _mat(color: Color, rough := 0.35) -> StandardMaterial3D:
	var key := "mat" + color.to_html()
	if not _parts.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = rough
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.5
		mat.rim_enabled = true
		mat.rim = 0.3
		mat.rim_tint = 0.85
		_parts[key] = mat
	return _parts[key]
