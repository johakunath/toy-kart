class_name HornTrick extends Node3D
## What a vehicle does when it honks: planes loop or roll, bikes pull a wheelie, the police car
## flashes its lights, the train puffs steam, the tractor bounces. Purely visual. Sits between
## the KartVisual and the model, so the kart's own lean, bounce and the AI's hops still work.
## The Krankenwagen's roof is not here: KartVisual toggles it (Kind.ROOF only marks the kart).
## The kind comes from the toy vehicle's DriverDef, else from the KartDef.

enum Kind {
	HOP,      ## the driver (or the toy) hops: every kart without a trick of its own
	ROOF,     ## Krankenwagen: the roof opens on one honk and closes on the next
	LOOP,     ## planes: a looping in the air
	ROLL,     ## big plane: a barrel roll
	WHEELIE,  ## bikes: front wheel up
	SIREN,    ## police: blue lights flash for a while
	STEAM,    ## train: steam puffs from the chimney
	BOUNCE,   ## tractor: three bouncy hops
}

const SECONDS := {
	Kind.LOOP: 1.15, Kind.ROLL: 0.85, Kind.WHEELIE: 1.0, Kind.SIREN: 2.6,
	Kind.STEAM: 1.6, Kind.BOUNCE: 0.9,
}
const LOOP_RADIUS := 1.1
const PUFFS := 6

var kind := Kind.HOP
## Turning point (model centre) and size of the model, set by KartVisual from the model's box.
var centre := Vector3(0, 0.35, 0)
var half_length := 0.5
var top := 0.7

var _time := -1.0          ## seconds into the running trick, < 0 when idle
var _lights: Array[OmniLight3D] = []
var _lamps: Array[MeshInstance3D] = []
var _puffs: Array[MeshInstance3D] = []
var _puff_age := PackedFloat32Array()

func setup(p_kind: Kind, box: AABB) -> void:
	kind = p_kind
	if box.size.length() > 0.01:
		centre = box.get_center()
		half_length = box.size.z * 0.5
		top = box.end.y
	if kind == Kind.SIREN:
		_build_lights(box)
	elif kind == Kind.STEAM:
		_build_puffs()

## True while a trick runs (it lifts or turns the toy).
func active() -> bool:
	return _time >= 0.0

## Starts the trick. A honk during a running trick does not start it again.
func play() -> bool:
	if not SECONDS.has(kind) or active():
		return false
	_time = 0.0
	if kind == Kind.STEAM:
		_puff_age.fill(-1.0)
	return true

## Every physics tick from the kart (menus do not honk, so they never call it).
func animate(delta: float) -> void:
	_animate_puffs(delta)
	if _time < 0.0:
		return
	_time += delta
	var seconds: float = SECONDS[kind]
	var s := clampf(_time / seconds, 0.0, 1.0)
	var rot := Vector3.ZERO
	var pivot := centre
	var lift := 0.0
	match kind:
		Kind.LOOP:
			# Nose up and all the way round, rising on a circle; eased in and out.
			var a := TAU * _smooth(s)
			rot.x = -a
			lift = LOOP_RADIUS * (1.0 - cos(a)) + 0.25 * sin(PI * s)
		Kind.ROLL:
			rot.z = TAU * _smooth(s)
			lift = 0.7 * sin(PI * s)
		Kind.WHEELIE:
			# Up quickly, ride on the back wheel, come down with a little bump.
			var up := minf(1.0, s * 5.0) * minf(1.0, (1.0 - s) * 4.0)
			rot.x = -0.75 * up
			pivot = Vector3(0, 0, centre.z - half_length * 0.8)
		Kind.BOUNCE:
			var fade := 1.0 - s
			lift = absf(sin(3.0 * PI * s)) * 0.4 * fade
			rot.x = -0.18 * sin(6.0 * PI * s) * fade
		Kind.SIREN:
			_flash(s)
		Kind.STEAM:
			# A puff every quarter of a second, the train chugs a little.
			var due := int(_time / 0.26)
			if due < PUFFS and _puff_age[due] < 0.0:
				_puff_age[due] = 0.0
			lift = absf(sin(_time * 14.0)) * 0.05 * (1.0 - s)
	var b := Basis.from_euler(rot)
	transform = Transform3D(b, Vector3.UP * lift + pivot - b * pivot)
	if s >= 1.0:
		_time = -1.0
		transform = Transform3D.IDENTITY
		_flash(1.0)

static func _smooth(s: float) -> float:
	return s * s * (3.0 - 2.0 * s)

# --- Police lights -----------------------------------------------------------------------------

func _build_lights(box: AABB) -> void:
	var y := box.end.y + 0.06
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var color := Color(0.15, 0.4, 1.0) if i == 0 else Color(1.0, 0.15, 0.15)
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 0.0
		light.omni_range = 3.0
		light.shadow_enabled = false
		light.position = Vector3(side * box.size.x * 0.2, y + 0.15, box.get_center().z)
		add_child(light)
		_lights.append(light)
		var lamp := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.07
		sphere.height = 0.14
		lamp.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 4.0
		lamp.material_override = mat
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.position = Vector3(side * box.size.x * 0.2, y, box.get_center().z)
		lamp.visible = false
		add_child(lamp)
		_lamps.append(lamp)

## Blue and red take turns, four times a second; all dark when done (s = 1).
func _flash(s: float) -> void:
	for i in _lights.size():
		var on := s < 1.0 and (int(_time * 8.0) % 2) == i
		_lights[i].light_energy = 6.0 if on else 0.0
		_lamps[i].visible = s < 1.0
		(_lamps[i].material_override as StandardMaterial3D).emission_energy_multiplier = 6.0 if on else 0.3

# --- Train steam -------------------------------------------------------------------------------

func _build_puffs() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 10
	mesh.rings = 5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mesh.material = mat
	for i in PUFFS:
		var puff := MeshInstance3D.new()
		puff.mesh = mesh
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.visible = false
		add_child(puff)
		_puffs.append(puff)
	_puff_age.resize(PUFFS)
	_puff_age.fill(-1.0)

## Puffs rise from the chimney (front top of the train), grow and fade out.
func _animate_puffs(delta: float) -> void:
	for i in _puffs.size():
		var age := _puff_age[i]
		var puff := _puffs[i]
		if age < 0.0:
			puff.visible = false
			continue
		age += delta
		_puff_age[i] = age if age < 1.1 else -1.0
		var t := age / 1.1
		puff.visible = t < 1.0
		puff.position = Vector3(0.0, top + 0.05 + t * 0.9, centre.z + half_length * 0.6 - t * 0.5)
		puff.scale = Vector3.ONE * (0.6 + t * 1.8)
		puff.transparency = t
