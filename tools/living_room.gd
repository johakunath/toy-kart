class_name LivingRoom extends RefCounted
## The living-room world for tools/build_round_track.gd (track "wohnzimmer"): a toy road through
## a room seen from toy height. One metre in the game is about 5 cm in the real room, so the
## sofa is a mountain, the coffee table a bridge, and his toys stand around as giants.
##
## Zones along the lap: wooden floor with the red sofa (start, cushion jump), the round rug with
## the coffee table, the play corner on foam puzzle mats. Every zone has one big landmark that
## can be seen in half a split screen. Toys that move get a ToyMotion node (background life).
## Built from simple shapes in strong toy colours; no new asset files.

const ROOM_LO := Vector2(-98.0, -94.0)
const ROOM_HI := Vector2(88.0, 36.0)
const WALL_HEIGHT := 70.0
const TOY := "res://assets/models/toys/%s.glb"
const FIGURE := "res://assets/characters/kenney_mini/character-%s.glb"

const C_WALL := Color("eeeae2")      ## warm white, like our real walls
const C_SKIRTING := Color("fbf7ee")
const C_WOOD_A := Color("6f4e31")    ## darker oak floor, like ours
const C_WOOD_B := Color("65462b")
const C_WOOD_C := Color("7a5739")
const C_SOFA := Color("6c6e73")      ## our grey sofa
const C_TABLE := Color("3b2416")     ## dark wood, like the real coffee table (darker than the floor)
const TOY_COLORS: Array[Color] = [Color("e8483f"), Color("3b8beb"), Color("f2b90f"), Color("3fbf5f"),
	Color("a55de0"), Color("f08a24")]

static var _root: Node3D
static var _clear: Callable
static var _materials := {}
static var _meshes := {}

## Builds the room around the road. `floor_y` is the height of the floor (just under the road);
## `clear` (p: Vector3, radius: float) -> bool says if a spot keeps off the road.
static func build(root: Node3D, floor_y: float, clear: Callable) -> void:
	_root = root
	_clear = clear
	_materials.clear()
	_meshes.clear()
	var room := _group(root, "Room", Vector3(0, floor_y, 0))
	_floor(room)
	_walls(room)
	_windows(room)
	_drawings(room)
	_sofa(room)
	_coffee_table(room)
	_rug(room)
	_puzzle_mats(room)
	_bookshelf(room)
	_floor_lamp(room)
	_plant(room)
	_toy_box(room)
	_blocks(room)
	_giant_toys(room)
	_crowd(room)

# --- Building blocks -----------------------------------------------------------------------

static func _own(node: Node) -> void:
	node.owner = _root

static func _group(parent: Node3D, node_name: String, pos := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	parent.add_child(node)
	_own(node)
	return node

static func _mat(color: Color, rough := 0.6, coat := 0.0, glow := 0.0) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f/%.2f" % [color.to_html(), rough, coat, glow]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	if coat > 0.0:
		mat.clearcoat_enabled = true
		mat.clearcoat = coat
		mat.clearcoat_roughness = 0.3
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	mat.rim_enabled = true
	mat.rim = 0.2
	mat.rim_tint = 0.85
	_materials[key] = mat
	return mat

static func _place(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, yaw := 0.0, shadow := true) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.rotation.y = yaw
	if not shadow:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	_own(inst)
	return inst

## A box standing on `bottom` (the centre of its underside).
static func _box(parent: Node3D, size: Vector3, bottom: Vector3, color: Color, yaw := 0.0, rough := 0.6, coat := 0.0) -> MeshInstance3D:
	var key := "box%s" % size
	if not _meshes.has(key):
		var box := BoxMesh.new()
		box.size = size
		_meshes[key] = box
	var mesh: Mesh = _meshes[key]
	return _place(parent, mesh, bottom + Vector3(0, size.y * 0.5, 0), _mat(color, rough, coat), yaw)

## A cylinder (or cone) standing on `bottom`.
static func _cyl(parent: Node3D, r_top: float, r_bottom: float, height: float, bottom: Vector3, color: Color, sides := 24) -> MeshInstance3D:
	var key := "cyl%.2f/%.2f/%.2f/%d" % [r_top, r_bottom, height, sides]
	if not _meshes.has(key):
		var cyl := CylinderMesh.new()
		cyl.top_radius = r_top
		cyl.bottom_radius = r_bottom
		cyl.height = height
		cyl.radial_segments = sides
		cyl.rings = 1
		_meshes[key] = cyl
	var mesh: Mesh = _meshes[key]
	return _place(parent, mesh, bottom + Vector3(0, height * 0.5, 0), _mat(color, 0.5, 0.3))

static func _ball(parent: Node3D, radius: float, center: Vector3, color: Color, coat := 0.6) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	return _place(parent, mesh, center, _mat(color, 0.3, coat))

## One of his toys, scaled to `height` metres, standing on `bottom`, front toward `yaw`.
static func _toy(parent: Node3D, id: String, height: float, bottom: Vector3, yaw: float, kind: ToyMotion.Kind,
		amount: float, speed: float, phase := 0.0, radius := 0.0) -> ToyMotion:
	var motion := ToyMotion.new()
	motion.name = "Toy_%s" % id
	motion.kind = kind
	motion.amount = amount
	motion.speed = speed
	motion.phase = phase
	motion.radius = radius
	motion.toy_look = true
	var s := height / 0.7  # the prepared toy models are 0.7 m tall (vehicles a little less)
	motion.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), bottom)
	parent.add_child(motion)
	_own(motion)
	var model := (load(TOY % id) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	motion.add_child(model)
	_own(model)
	return motion

static func _check(where: Vector3, radius: float, what: String) -> void:
	if not _clear.call(where, radius):
		push_warning("Living room: %s at %s is close to the road." % [what, where])

# --- Floor, walls, windows -----------------------------------------------------------------

static func _floor(room: Node3D) -> void:
	# Long planks running east-west, each row a little different, with dark joints between.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	var plank := 3.2
	var z := ROOM_LO.y
	var row := 0
	var woods: Array[Color] = [C_WOOD_A, C_WOOD_B, C_WOOD_C]
	while z < ROOM_HI.y:
		var x := ROOM_LO.x - rng.randf_range(0.0, 30.0)
		while x < ROOM_HI.x:
			var length := rng.randf_range(22.0, 40.0)
			var color := woods[(row + int(x * 0.1) + rng.randi_range(0, 2)) % 3]
			color = color.lightened(rng.randf_range(-0.04, 0.05))
			var x0 := maxf(x + 0.12, ROOM_LO.x)
			var x1 := minf(x + length - 0.12, ROOM_HI.x)
			var z1 := minf(z + plank - 0.12, ROOM_HI.y)
			if x1 > x0:
				for v: Vector3 in [Vector3(x0, 0, z), Vector3(x1, 0, z), Vector3(x1, 0, z1), Vector3(x0, 0, z), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]:
					st.set_color(color)
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
			x += length
		z += plank
		row += 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.45
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.35
	var planks := _place(room, st.commit(), Vector3.ZERO, mat, 0.0, false)
	planks.name = "Floor"
	# The joints: a dark board just under the planks.
	var under := PlaneMesh.new()
	under.size = ROOM_HI - ROOM_LO + Vector2(4, 4)
	var joints := _place(room, under, Vector3((ROOM_LO.x + ROOM_HI.x) * 0.5, -0.01, (ROOM_LO.y + ROOM_HI.y) * 0.5), _mat(Color("38271a"), 0.9), 0.0, false)
	joints.name = "Joints"

static func _walls(room: Node3D) -> void:
	var walls := _group(room, "Walls")
	var cx := (ROOM_LO.x + ROOM_HI.x) * 0.5
	var cz := (ROOM_LO.y + ROOM_HI.y) * 0.5
	var w := ROOM_HI.x - ROOM_LO.x
	var d := ROOM_HI.y - ROOM_LO.y
	var t := 2.0
	var sides := [
		[Vector3(w + 2 * t, WALL_HEIGHT, t), Vector3(cx, 0, ROOM_LO.y - t * 0.5)],
		[Vector3(w + 2 * t, WALL_HEIGHT, t), Vector3(cx, 0, ROOM_HI.y + t * 0.5)],
		[Vector3(t, WALL_HEIGHT, d), Vector3(ROOM_LO.x - t * 0.5, 0, cz)],
		[Vector3(t, WALL_HEIGHT, d), Vector3(ROOM_HI.x + t * 0.5, 0, cz)],
	]
	for side: Array in sides:
		var wall := _box(walls, side[0], side[1], C_WALL, 0.0, 0.9)
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# White skirting board along the bottom.
		var size: Vector3 = side[0]
		var skirting := _box(walls, Vector3(size.x + 0.8 if size.x > size.z else 0.8 + t, 3.2, size.z + 0.8 if size.z > size.x else 0.8 + t),
			side[1], C_SKIRTING, 0.0, 0.4, 0.3)
		skirting.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Wide stripes of wallpaper on the long walls, to show speed.
	for k in 13:
		var x := ROOM_LO.x + 7.0 + k * 14.0
		for z: float in [ROOM_LO.y + 0.05, ROOM_HI.y - 0.05]:
			var stripe := _box(walls, Vector3(5.0, WALL_HEIGHT - 6.0, 0.2), Vector3(x, 3.2, z), Color("e2ddd2"), 0.0, 0.9)
			stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Two big windows on the north wall: bright sky in the panes, white frames, red curtains.
static func _windows(room: Node3D) -> void:
	var group := _group(room, "Windows")
	var z := ROOM_LO.y + 0.3
	for cx: float in [-36.0, 30.0]:
		var pane := _box(group, Vector3(34.0, 38.0, 0.3), Vector3(cx, 18.0, z), Color("9ad8ff"), 0.0, 0.2)
		pane.material_override = _mat(Color("a8deff"), 0.2, 0.0, 1.6)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for bar: Array in [[Vector3(36.0, 1.6, 0.8), Vector3(cx, 16.6, z + 0.3)], [Vector3(36.0, 1.6, 0.8), Vector3(cx, 55.6, z + 0.3)],
				[Vector3(36.0, 1.2, 0.8), Vector3(cx, 36.4, z + 0.3)], [Vector3(1.6, 38.0, 0.8), Vector3(cx - 17.2, 18.0, z + 0.3)],
				[Vector3(1.6, 38.0, 0.8), Vector3(cx + 17.2, 18.0, z + 0.3)], [Vector3(1.2, 38.0, 0.8), Vector3(cx, 18.0, z + 0.3)]]:
			_box(group, bar[0], bar[1], C_SKIRTING, 0.0, 0.4, 0.4).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Window sill and curtains.
		_box(group, Vector3(40.0, 1.2, 3.0), Vector3(cx, 15.4, z + 1.4), C_SKIRTING, 0.0, 0.4, 0.4)
		for side: float in [-1.0, 1.0]:
			var curtain := _box(group, Vector3(7.0, 58.0, 2.2), Vector3(cx + side * 22.0, 0.0, z + 1.6), Color("ddd6c8"), 0.0, 0.95)
			curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for fold in 3:
				_box(group, Vector3(1.4, 58.0, 0.6), Vector3(cx + side * 22.0 - 2.4 + fold * 2.4, 0.0, z + 2.8), Color("cbc3b3"), 0.0, 0.95).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## His drawings on the west wall (ahead when driving into the play corner).
static func _drawings(room: Node3D) -> void:
	var group := _group(room, "Drawings")
	var x := ROOM_LO.x + 0.3
	var spots := [-64.0, -32.0, 0.0]
	for k in spots.size():
		var z: float = spots[k]
		var frame := Vector3(x, 22.0, z)
		_box(group, Vector3(0.6, 20.0, 26.0), frame, TOY_COLORS[(k + 2) % 6], 0.0, 0.5, 0.4)
		_box(group, Vector3(0.8, 17.0, 23.0), frame + Vector3(0, 1.5, 0), Color("fffdf5"), 0.0, 0.95)
		var face := x + 0.85
		match k:
			0:  # the sun and a green hill
				var sun := _cyl(group, 4.0, 4.0, 0.2, Vector3(face, 31.0, z - 5.0), Color("ffc81e"))
				sun.rotation.z = PI * 0.5
				sun.position = Vector3(face, 33.0, z - 5.0)
				var hill := _cyl(group, 9.0, 9.0, 0.2, Vector3(face, 24.0, z + 3.0), Color("3fbf5f"))
				hill.rotation.z = PI * 0.5
				hill.position = Vector3(face - 0.05, 25.0, z + 3.0)
			1:  # a red house with a blue door
				_box(group, Vector3(0.2, 8.0, 10.0), Vector3(face, 25.0, z), Color("e8483f"), 0.0, 0.9)
				_box(group, Vector3(0.25, 4.0, 2.6), Vector3(face, 25.0, z + 2.0), Color("3b8beb"), 0.0, 0.9)
				var roof := PrismMesh.new()
				roof.size = Vector3(13.0, 5.0, 0.2)
				var r := _place(group, roof, Vector3(face, 35.5, z), _mat(Color("8e44d8"), 0.9), PI * 0.5)
				r.name = "Roof"
			2:  # a smiling face: Koba
				var head := _cyl(group, 6.0, 6.0, 0.2, Vector3.ZERO, Color("f2b90f"))
				head.rotation.z = PI * 0.5
				head.position = Vector3(face, 31.0, z)
				for e: float in [-2.2, 2.2]:
					var eye := _cyl(group, 0.9, 0.9, 0.2, Vector3.ZERO, Color("2a2b33"))
					eye.rotation.z = PI * 0.5
					eye.position = Vector3(face + 0.1, 32.5, z + e)
				var mouth := _box(group, Vector3(0.25, 0.9, 5.0), Vector3(face + 0.1, 28.2, z), Color("e8483f"), 0.0, 0.9)
				mouth.name = "Mouth"

# --- Furniture -----------------------------------------------------------------------------

## The big red sofa along the south wall, behind the start straight. Bobo sits on it.
static func _sofa(room: Node3D) -> void:
	var group := _group(room, "Sofa", Vector3(0, 0, 21.0))
	_check(group.position + Vector3(0, 0, -9.0), 2.0, "sofa front")
	var light := C_SOFA.lightened(0.08)
	for x: float in [-24.0, 24.0]:
		for z: float in [-8.0, 8.0]:
			_cyl(group, 0.9, 0.7, 1.4, Vector3(x, 0, z), C_TABLE)
	_box(group, Vector3(52.0, 6.0, 20.0), Vector3(0, 1.4, 0), C_SOFA, 0.0, 0.95)
	for x: float in [-12.6, 12.6]:
		_box(group, Vector3(24.6, 3.0, 16.0), Vector3(x, 7.4, -1.6), light, 0.0, 0.95)
		var back := _box(group, Vector3(23.6, 12.0, 4.5), Vector3(x, 10.0, 6.8), light, 0.0, 0.95)
		back.rotation.x = -0.12
	_box(group, Vector3(52.0, 18.0, 4.0), Vector3(0, 1.4, 8.0), C_SOFA, 0.0, 0.95)
	for side: float in [-1.0, 1.0]:
		_box(group, Vector3(5.0, 11.0, 20.0), Vector3(side * 28.5, 1.4, 0), C_SOFA, 0.0, 0.95)
		var roll := _cyl(group, 2.6, 2.6, 20.0, Vector3.ZERO, C_SOFA)
		roll.rotation.x = PI * 0.5
		roll.position = Vector3(side * 28.5, 12.4, 0)
		roll.material_override = _mat(C_SOFA, 0.95)
	# A spare cushion on the floor, the twin of the one on the road.
	var cushion := _box(group, Vector3(11.0, 2.6, 11.0), Vector3(40.0, 0, -2.0), Color("55575c"), 0.5, 0.95)
	cushion.name = "SpareCushion"
	_check(Vector3(40.0, 0, 19.0), 7.0, "spare cushion")

## The coffee table on the rug: the road runs under it like under a bridge.
static func _coffee_table(room: Node3D) -> void:
	var group := _group(room, "CoffeeTable", Vector3(-18.0, 0, -66.0))
	var half := Vector2(15.0, 7.4)
	_box(group, Vector3(half.x * 2.0 + 1.0, 1.6, half.y * 2.0 + 1.0), Vector3(0, 9.0, 0), C_TABLE, 0.0, 0.35, 0.5)
	_box(group, Vector3(half.x * 2.0 - 1.0, 1.2, half.y * 2.0 - 1.0), Vector3(0, 7.8, 0), C_TABLE.darkened(0.2), 0.0, 0.5)
	for x: float in [-half.x + 0.6, half.x - 0.6]:
		for z: float in [-half.y + 0.6, half.y - 0.6]:
			_box(group, Vector3(1.4, 9.0, 1.4), Vector3(x, 0, z), C_TABLE, 0.0, 0.4, 0.4)
			_check(group.position + Vector3(x, 0, z), 0.4, "table leg")  # 0.4 m from the barrier: fine
	# On the table: a mug, a picture book, crayons, and the police car on patrol.
	var top := 10.6
	var mug := _cyl(group, 1.6, 1.4, 3.4, Vector3(-9.0, top, -2.5), Color("3b8beb"))
	mug.name = "Mug"
	_box(group, Vector3(9.0, 0.8, 6.5), Vector3(8.0, top, 2.0), Color("f2b90f"), 0.2, 0.5)
	for k in 4:
		var crayon := _cyl(group, 0.35, 0.35, 6.0, Vector3.ZERO, TOY_COLORS[k])
		crayon.rotation = Vector3(PI * 0.5, 0.0, 0.3 + k * 0.25)
		crayon.position = Vector3(-2.0 + k * 1.2, top + 0.35, 3.5)
	var police := _toy(group, "polizei", 4.2, Vector3(2.0, top, -2.0), 0.0, ToyMotion.Kind.ORBIT, 0.08, 3.0, 0.0, 4.5)
	var lights := ToyMotion.new()
	lights.name = "Lights"
	lights.kind = ToyMotion.Kind.BLINK
	lights.speed = 1.6
	lights.position = Vector3(0, 0.82, 0.0)
	police.add_child(lights)
	_own(lights)
	for color: Color in [Color("ff2a2a"), Color("2a6aff")]:
		var mesh := SphereMesh.new()
		mesh.radius = 0.07
		mesh.height = 0.14
		var lamp := MeshInstance3D.new()
		lamp.mesh = mesh
		lamp.material_override = _mat(color, 0.2, 0.0, 6.0)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lights.add_child(lamp)
		_own(lamp)

## The round rug in strong rings around the coffee table (thin, so the road lies on top).
static func _rug(room: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Calm wool colours, like a real round rug (it was a rainbow).
	var rings: Array[Array] = [[40.0, Color("cfc4b2")], [34.0, Color("b9ad99")], [27.0, Color("d8cfbf")],
		[20.0, Color("a99c88")], [13.0, Color("cfc4b2")], [6.0, Color("b9ad99")]]
	var steps := 72
	for k in rings.size():
		var outer: float = rings[k][0]
		var inner: float = rings[k + 1][0] if k + 1 < rings.size() else 0.0
		var color: Color = rings[k][1]
		for j in steps:
			var a0 := TAU * j / steps
			var a1 := TAU * (j + 1) / steps
			var quad := [Vector3(cos(a0) * inner, 0, sin(a0) * inner), Vector3(cos(a0) * outer, 0, sin(a0) * outer),
				Vector3(cos(a1) * outer, 0, sin(a1) * outer), Vector3(cos(a1) * inner, 0, sin(a1) * inner)]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				st.set_color(color)
				st.set_normal(Vector3.UP)
				st.add_vertex(quad[idx])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	var rug := _place(room, st.commit(), Vector3(-12.0, 0.02, -60.0), mat, 0.0, false)
	rug.name = "Rug"

## Foam puzzle mats in the play corner (west), in four colours.
static func _puzzle_mats(room: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size := 11.0
	var colors: Array[Color] = [Color("e8483f"), Color("3b8beb"), Color("f2b90f"), Color("3fbf5f")]
	var gx := 0
	var x := ROOM_LO.x + 1.0
	while x + size <= -52.0:
		var gz := 0
		var z := -86.0
		while z + size <= 26.0:
			var color := colors[(gx + gz * 2) % 4]
			var x0 := x + 0.1
			var x1 := x + size - 0.1
			var z0 := z + 0.1
			var z1 := z + size - 0.1
			for v: Vector3 in [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]:
				st.set_color(color)
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
			z += size
			gz += 1
		x += size
		gx += 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.85
	var mats := _place(room, st.commit(), Vector3(0, 0.02, 0), mat, 0.0, false)
	mats.name = "PuzzleMats"

## A bookshelf on the east wall, full of colourful books, with the motorbike on top.
static func _bookshelf(room: Node3D) -> void:
	var group := _group(room, "Bookshelf", Vector3(ROOM_HI.x - 4.0, 0, -44.0))
	var depth := 7.0
	var width := 50.0
	var wood := Color("f4f1ea")
	_box(group, Vector3(depth, 1.2, width), Vector3(0, 0, 0), wood, 0.0, 0.5)
	_box(group, Vector3(0.6, 48.0, width), Vector3(depth * 0.5 - 0.3, 0, 0), wood, 0.0, 0.5)
	for z: float in [-width * 0.5, width * 0.5]:
		_box(group, Vector3(depth, 48.0, 1.2), Vector3(0, 0, z), wood, 0.0, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for level in 4:
		var y := 1.2 + level * 11.6
		_box(group, Vector3(depth, 1.0, width), Vector3(0, y + 10.6, 0), wood, 0.0, 0.5)
		var z := -width * 0.5 + 1.6
		while z < width * 0.5 - 3.0:
			var thick := rng.randf_range(1.2, 2.6)
			var tall := rng.randf_range(6.5, 10.0)
			var book := _box(group, Vector3(depth - 1.4, tall, thick), Vector3(-0.4, y, z + thick * 0.5), TOY_COLORS[rng.randi_range(0, 5)], 0.0, 0.7)
			if rng.randf() < 0.12:
				book.rotation.x = 0.22  # one leaning over now and then
			z += thick + 0.15
	_toy(group, "motorrad", 7.0, Vector3(-0.5, 47.0, 4.0), -PI * 0.5, ToyMotion.Kind.ROCK, 0.05, 0.25, 1.3)

## A floor lamp in the south-east corner with a warm light in its yellow shade.
static func _floor_lamp(room: Node3D) -> void:
	var group := _group(room, "FloorLamp", Vector3(72.0, 0, 20.0))
	_check(group.position, 6.0, "floor lamp")
	_cyl(group, 4.0, 5.0, 1.0, Vector3.ZERO, Color("2a2b33"))
	_cyl(group, 0.6, 0.6, 44.0, Vector3(0, 1.0, 0), Color("2a2b33"))
	var shade := _cyl(group, 5.0, 9.0, 10.0, Vector3(0, 40.0, 0), Color("f6f4ee"))
	shade.material_override = _mat(Color("fff4d8"), 0.5, 0.0, 0.4)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.position = Vector3(0, 39.0, 0)
	light.light_color = Color(1.0, 0.82, 0.5)
	light.light_energy = 3.0
	light.omni_range = 55.0
	light.shadow_enabled = false
	group.add_child(light)
	_own(light)

## A big potted plant in the north-east corner.
static func _plant(room: Node3D) -> void:
	var group := _group(room, "Plant", Vector3(76.0, 0, -82.0))
	_cyl(group, 7.0, 5.0, 12.0, Vector3.ZERO, Color("e07a3c"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 9:
		var angle := k * TAU / 9.0
		var leaf := _ball(group, rng.randf_range(5.0, 7.0), Vector3(cos(angle) * 5.0, 18.0 + rng.randf_range(0.0, 12.0), sin(angle) * 5.0), Color("2fa84a"), 0.2)
		leaf.scale = Vector3(0.7, 1.4, 0.7)
	_ball(group, 7.0, Vector3(0, 30.0, 0), Color("38b552"), 0.2).scale = Vector3(0.8, 1.3, 0.8)

## The toy box in the infield: open lid, balls peeking out.
static func _toy_box(room: Node3D) -> void:
	var group := _group(room, "ToyBox", Vector3(-22.0, 0, -32.0))
	_check(group.position, 11.0, "toy box")
	_box(group, Vector3(18.0, 10.0, 12.0), Vector3.ZERO, Color("3b8beb"), 0.25, 0.4, 0.5)
	for side: float in [-1.0, 1.0]:
		_box(group, Vector3(18.4, 1.4, 0.6), Vector3(0, 4.0, side * 6.05), Color("f2b90f"), 0.25, 0.4, 0.5)
	var lid := _box(group, Vector3(18.4, 1.0, 12.4), Vector3(0, 10.0, 0), Color("f2b90f"), 0.25, 0.4, 0.5)
	lid.rotation.x = -1.15
	lid.position = Vector3(0, 15.2, 9.0).rotated(Vector3.UP, 0.25)
	var balls: Array[Array] = [[Vector3(-4.0, 10.5, -1.0), 3.2, 0], [Vector3(2.5, 10.0, 1.5), 2.6, 3], [Vector3(5.5, 11.0, -2.0), 2.2, 2]]
	for b: Array in balls:
		_ball(group, b[1], b[0], TOY_COLORS[b[2]])

## Giant wooden letter blocks, stacked here and there in the infield.
static func _blocks(room: Node3D) -> void:
	var group := _group(room, "Blocks")
	var stacks: Array[Array] = [[Vector3(32.0, 0, -28.0), 3, 0.3], [Vector3(-4.0, 0, -16.0), 2, -0.4],
		[Vector3(46.0, 0, -36.0), 1, 0.8], [Vector3(-40.0, 0, -18.0), 2, 0.2], [Vector3(-86.0, 0, -78.0), 3, 0.5]]
	var k := 0
	for stack: Array in stacks:
		var base: Vector3 = stack[0]
		_check(base, 4.0, "block stack")
		for level in int(stack[1]):
			var yaw: float = stack[2] + level * 0.35
			var block := _box(group, Vector3(5.0, 5.0, 5.0), base + Vector3(0, level * 5.0, 0), TOY_COLORS[k % 6], yaw, 0.5, 0.3)
			block.name = "Block%d" % k
			# A lighter square on each face: the letter plate.
			_box(group, Vector3(3.4, 3.4, 5.1), base + Vector3(0, level * 5.0 + 0.8, 0), TOY_COLORS[k % 6].lightened(0.35), yaw, 0.6)
			_box(group, Vector3(5.1, 3.4, 3.4), base + Vector3(0, level * 5.0 + 0.8, 0), TOY_COLORS[k % 6].lightened(0.35), yaw, 0.6)
			k += 1

## His toys as giants: one landmark per zone, and two planes circling the room.
static func _giant_toys(room: Node3D) -> void:
	var group := _group(room, "GiantToys")
	# Zone 1: Bobo sits on the sofa, rocking gently.
	_toy(group, "baer", 12.0, Vector3(-11.0, 10.4, 19.0), PI, ToyMotion.Kind.ROCK, 0.07, 0.3)
	# Zone 2: the fox by the window, looking at the road.
	_check(Vector3(30.0, 0, -80.0), 5.0, "fox")
	_toy(group, "katze", 11.0, Vector3(30.0, 0, -80.0), 0.2, ToyMotion.Kind.ROCK, 0.06, 0.4, 0.8)
	# Zone 3 and the infield: Koba, the biggest of all, nodding at everyone who drives past.
	_check(Vector3(10.0, 0, -30.0), 7.0, "Koba")
	_toy(group, "loewe", 15.0, Vector3(10.0, 0, -30.0), 0.35, ToyMotion.Kind.NOD, 0.05, 0.25, 0.4)
	# High above: the Duplo plane and the toy plane, flying round the room in opposite ways.
	_toy(group, "duploflieger", 5.5, Vector3(0, 32.0, -30.0), 0.0, ToyMotion.Kind.ORBIT, 0.3, 11.0, 0.0, 58.0)
	_toy(group, "flieger", 6.0, Vector3(8.0, 22.0, -30.0), 0.0, ToyMotion.Kind.ORBIT, 0.35, 9.0, 4.0, -36.0)

## Fans on a picture book by the start line, cheering and hopping.
static func _crowd(room: Node3D) -> void:
	_check(Vector3(-26.0, 0, 7.8), 1.8, "crowd")
	crowd(room, Vector3(-26.0, 0, 7.8), 0.0)

## A stand of cheering toy figures on a big green book. Faces -z of `yaw` (toward the road).
static func crowd(parent: Node3D, bottom: Vector3, yaw: float) -> Node3D:
	var group := _group(parent, "Crowd", bottom)
	group.rotation.y = yaw
	_box(group, Vector3(28.0, 1.2, 5.0), Vector3.ZERO, Color("3fbf5f"), 0.0, 0.6, 0.3)
	_box(group, Vector3(27.4, 1.0, 4.6), Vector3(0, 1.2, 0), Color("fffdf5"), 0.0, 0.9)
	_box(group, Vector3(28.0, 0.4, 5.0), Vector3(0, 2.2, 0), Color("3fbf5f"), 0.0, 0.6, 0.3)
	var figures := ["male-a", "female-a", "robot", "knight", "female-b", "alien", "male-b", "worker"]
	var moves := ["emote-yes", "jump", "emote-yes", "idle"]
	for k in figures.size():
		var fan := ToyMotion.new()
		fan.name = "Fan%d" % k
		fan.kind = ToyMotion.Kind.HOP
		fan.amount = 0.5
		fan.speed = 1.3 + 0.17 * (k % 3)
		fan.phase = k * 0.37
		fan.animation = moves[k % moves.size()]
		fan.toy_look = true
		fan.transform = Transform3D(Basis(Vector3.UP, PI + (k - 3.5) * 0.06).scaled(Vector3.ONE * 2.2), Vector3(-12.2 + k * 3.5, 2.6, 0.0))
		group.add_child(fan)
		_own(fan)
		var model := (load(FIGURE % figures[k]) as PackedScene).instantiate() as Node3D
		model.name = "Model"
		fan.add_child(model)
		_own(model)
	return group

## Background life for the outdoor tracks: fans by the start line and a toy plane overhead.
static func outdoor_life(root: Node3D, crowd_bottom: Vector3, crowd_yaw: float, sky_center: Vector3, sky_radius: float) -> void:
	_root = root
	_materials.clear()
	_meshes.clear()
	var life := _group(root, "Life")
	crowd(life, crowd_bottom, crowd_yaw)
	_toy(life, "duploflieger", 4.5, sky_center + Vector3(0, 26.0, 0), 0.0, ToyMotion.Kind.ORBIT, 0.3, 10.0, 0.0, sky_radius)

# --- Pieces placed on the road by the track builder ----------------------------------------

## A giant brick: studs on top, in a toy colour.
static func _brick(parent: Node3D, size: Vector3, bottom: Vector3, color: Color, yaw: float) -> void:
	_box(parent, size, bottom, color, yaw, 0.3, 0.6)
	var studs_x := int(round(size.x / 1.6))
	var studs_z := int(round(size.z / 1.6))
	var basis := Basis(Vector3.UP, yaw)
	for i in studs_x:
		for j in studs_z:
			var local := Vector3((i + 0.5) * size.x / studs_x - size.x * 0.5, size.y, (j + 0.5) * size.z / studs_z - size.z * 0.5)
			_cyl(parent, 0.5, 0.5, 0.45, bottom + basis * local, color, 16)

## An arch of giant bricks over the road where the play corner starts.
static func brick_arch(root: Node3D, center: Vector3, right: Vector3, half_span: float) -> void:
	_root = root
	_meshes.clear()
	var group := _group(root, "BrickArch", center)
	var yaw := atan2(right.x, right.z)
	var basis := Basis(Vector3.UP, yaw)
	var colors: Array[Color] = [Color("e8483f"), Color("f2b90f"), Color("3b8beb"), Color("3fbf5f")]
	for side: float in [-1.0, 1.0]:
		for level in 4:
			var pos := basis * Vector3(0, level * 2.4, side * (half_span + 1.2))
			_brick(group, Vector3(3.2, 2.4, 2.4), pos, colors[(level + (1 if side > 0 else 0)) % 4], yaw)
	_brick(group, Vector3(3.2, 2.4, half_span * 2.0 + 4.8), Vector3(0, 9.6, 0), Color("a55de0"), yaw)

## A tower of giant bricks on the side lane's island.
static func brick_tower(root: Node3D, bottom: Vector3, along: Vector3, layers: int, seed_value: int) -> void:
	_root = root
	var tower := _group(root, "BrickTower%d" % seed_value, bottom)
	var yaw := atan2(along.x, along.z)
	for level in layers:
		var twist := 0.0 if level % 2 == 0 else 0.12
		_brick(tower, Vector3(2.4, 2.4, 4.8), Vector3(0, level * 2.4, 0), TOY_COLORS[(level + seed_value * 2) % 6], yaw + twist)
