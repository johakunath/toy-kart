class_name OpenRoom extends LivingRoom
## The open living room for the "Entdecken" mode (tools/build_open_room.gd): our real living
## room and veranda, laid out after the family's photos and floor plan, at toy scale
## (1 m in the game = 5 cm in the room, so the 4.3 x 7.6 m room is 87 x 152 m).
##
## North (-z) is the window wall with the river view; the veranda is behind a glass sliding
## wall that stands open in the middle. South (+z) is the hall door. x runs west to east.
## Sofa, desk, tables and chairs stand a little higher than the real ones, so the karts and
## the camera fit underneath (caves to explore). Everything solid gets a box collider on layer
## 1; the floor is the one big ground collider. Simple shapes in strong colours, no new assets.

const X0 := -43.3
const X1 := 43.3
const Z0 := -76.0
const Z1 := 76.0
const HEIGHT := 50.0          ## 2.5 m ceiling
const GLASS_Z := -27.0        ## the glass sliding wall between living room and veranda
const GLASS_OPEN := Vector2(-22.0, 28.0)  ## the open part of the sliding wall (x from, to)
const HALL_DOOR := Vector2(-30.0, -13.0)  ## the hall door in the south wall (x from, to)
const EAST_DOOR := Vector2(44.0, 60.0)    ## the balcony door in the east wall (z from, to)
const FLOOR_Y := -0.15        ## kart models sit 0.15 m below the physics floor (Kenney kit)

const C_WALL_OPEN := Color("8fd0f5")
const C_OAK := Color("dba862")
const C_OAK_DARK := Color("b9864a")
const C_PLANK: Array[Color] = [Color("b8682f"), Color("a85b28"), Color("c47538"), Color("b06232")]
const C_SOFA_GREY := Color("5a6378")
const C_SOFA_DARK := Color("434a5c")
const C_BLACK := Color("26272e")
const C_WHITE := Color("f6f4ee")
const C_PLANT := Color("2fa84a")
const C_PLANT_DARK := Color("1f7d3a")
const C_POT := Color("d2693a")
const C_VELVET := Color("a3204a")
const C_TEAL := Color("17808a")
const C_SAGE := Color("86c9a0")
const C_CARDBOARD := Color("c99a5e")

static var _solids: Node3D

## Builds the whole room under `root`. Returns the room node.
static func build_open(root: Node3D) -> Node3D:
	_root = root
	_materials.clear()
	_meshes.clear()
	var room := _group(root, "Room", Vector3(0, FLOOR_Y, 0))
	_solids = _group(root, "Solids")
	_floor_planks(room)
	_room_walls(room)
	_window_wall(room)
	_glass_wall(room)
	_veranda(room)
	_play_corner(room)
	_tent(room)
	_sofa_corner(room)
	_coffee_table_and_lamp(room)
	_yoga_mat(room)
	_desk(room)
	_dining(room)
	_south_wall(room)
	_east_door(room)
	_pendants(room)
	return room

# --- Helpers ---------------------------------------------------------------------------------

## An invisible solid box standing on `bottom` (world floor at y = 0).
static func _solid(size: Vector3, bottom: Vector3, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(bottom.x, bottom.y + size.y * 0.5, bottom.z)
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_solids.add_child(body)
	_own(body)
	_own(shape)

## A box that is seen and solid. `bottom` is in `parent`'s space (the collider is placed in
## the world: groups like the tent and the walker sit somewhere in the room).
static func _block(parent: Node3D, size: Vector3, bottom: Vector3, color: Color, rough := 0.6, coat := 0.0) -> MeshInstance3D:
	var world := _to_world(parent, bottom)
	_solid(size, Vector3(world.x, maxf(world.y, 0.0), world.z))
	return _box(parent, size, bottom, color, 0.0, rough, coat)

## A point in `node`'s space, in the world (the scene is not in the tree while it is built).
static func _to_world(node: Node3D, p: Vector3) -> Vector3:
	var xform := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != _root:
		xform = (n as Node3D).transform * xform
		n = n.get_parent()
	return xform * p

static func _glass_mat() -> StandardMaterial3D:
	var key := "glass"
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.9, 1.0, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mat.metallic_specular = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = mat
	return mat

static func _no_shadow(node: GeometryInstance3D) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Four legs under a rectangle (x0..x1, z0..z1), seen and solid.
static func _legs(parent: Node3D, x0: float, x1: float, z0: float, z1: float, height: float, thick: float, color: Color, inset := 0.8) -> void:
	for x: float in [x0 + inset + thick * 0.5, x1 - inset - thick * 0.5]:
		for z: float in [z0 + inset + thick * 0.5, z1 - inset - thick * 0.5]:
			_block(parent, Vector3(thick, height, thick), Vector3(x, 0, z), color, 0.4, 0.3)

## A leafy plant: a pot, a trunk and balls of leaves.
static func _plant_pot(parent: Node3D, at: Vector3, pot_r: float, tall: float, seed_value: int, leaf_r := 5.0) -> void:
	_cyl(parent, pot_r, pot_r * 0.8, pot_r * 1.6, at, C_POT)
	_solid(Vector3(pot_r * 1.8, pot_r * 1.6, pot_r * 1.8), at)
	_cyl(parent, 0.5, 0.6, tall * 0.8, at + Vector3(0, pot_r * 1.6, 0), Color("6b4a2a"), 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in 9:
		var angle := rng.randf_range(0.0, TAU)
		var reach := rng.randf_range(1.5, leaf_r)
		var y := lerpf(tall * 0.45, tall, rng.randf())
		var leaf := _ball(parent, rng.randf_range(leaf_r * 0.6, leaf_r), at + Vector3(cos(angle) * reach, y, sin(angle) * reach),
			C_PLANT if k % 3 else C_PLANT_DARK, 0.2)
		leaf.scale = Vector3(1.0, 0.55, 1.0)

# --- Floor and walls -------------------------------------------------------------------------

## Laminate planks running north-south, as in the room.
static func _floor_planks(room: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	var width := 4.0
	var x := X0
	var col := 0
	while x < X1:
		var z := Z0 - rng.randf_range(0.0, 20.0)
		while z < Z1:
			var length := rng.randf_range(20.0, 28.0)
			var color := C_PLANK[(col + rng.randi_range(0, 3)) % C_PLANK.size()].lightened(rng.randf_range(-0.04, 0.05))
			var x0 := x + 0.1
			var x1 := minf(x + width - 0.1, X1)
			var z0 := maxf(z + 0.1, Z0)
			var z1 := minf(z + length - 0.1, Z1)
			if z1 > z0:
				for v: Vector3 in [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]:
					st.set_color(color)
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
			z += length
		x += width
		col += 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.4
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.4
	var planks := _place(room, st.commit(), Vector3.ZERO, mat, 0.0, false)
	planks.name = "Floor"
	var under := PlaneMesh.new()
	under.size = Vector2(X1 - X0 + 4, Z1 - Z0 + 4)
	_place(room, under, Vector3(0, -0.01, 0), _mat(Color("5e3216"), 0.9), 0.0, false).name = "Joints"

## Walls (seen, no shadows: the room is lit softly), white skirting, and solid edges.
static func _room_walls(room: Node3D) -> void:
	var walls := _group(room, "Walls")
	var t := 1.0
	var depth := Z1 - Z0
	var parts: Array[Array] = [
		# west wall
		[Vector3(t, HEIGHT, depth), Vector3(X0 - t * 0.5, 0, 0)],
		# south wall, left and right of the hall door, and above it
		[Vector3(HALL_DOOR.x - X0, HEIGHT, t), Vector3((X0 + HALL_DOOR.x) * 0.5, 0, Z1 + t * 0.5)],
		[Vector3(X1 - HALL_DOOR.y, HEIGHT, t), Vector3((X1 + HALL_DOOR.y) * 0.5, 0, Z1 + t * 0.5)],
		[Vector3(HALL_DOOR.y - HALL_DOOR.x, HEIGHT - 40.0, t), Vector3((HALL_DOOR.x + HALL_DOOR.y) * 0.5, 40.0, Z1 + t * 0.5)],
		# east wall, beside and above the balcony door
		[Vector3(t, HEIGHT, EAST_DOOR.x - Z0), Vector3(X1 + t * 0.5, 0, (Z0 + EAST_DOOR.x) * 0.5)],
		[Vector3(t, HEIGHT, Z1 - EAST_DOOR.y), Vector3(X1 + t * 0.5, 0, (Z1 + EAST_DOOR.y) * 0.5)],
		[Vector3(t, HEIGHT - 44.0, EAST_DOOR.y - EAST_DOOR.x), Vector3(X1 + t * 0.5, 44.0, (EAST_DOOR.x + EAST_DOOR.y) * 0.5)],
	]
	for part in parts:
		var size: Vector3 = part[0]
		var bottom: Vector3 = part[1]
		_no_shadow(_box(walls, size, bottom, C_WALL, 0.0, 0.9))
		if bottom.y == 0.0:
			var skirt := Vector3(size.x + 0.6 if size.x > size.z else 0.6 + t, 2.4, size.z + 0.6 if size.z > size.x else 0.6 + t)
			_no_shadow(_box(walls, skirt, bottom, C_SKIRTING, 0.0, 0.5, 0.3))
	# Stripes of lighter wallpaper on the long walls, to feel the speed.
	for z in range(int(Z0) + 34, int(Z1) - 4, 14):
		_no_shadow(_box(walls, Vector3(0.2, HEIGHT - 6.0, 4.0), Vector3(X0 + 0.05, 2.4, z), C_WALL_OPEN, 0.0, 0.9))
		if z < EAST_DOOR.x - 6.0 or z > EAST_DOOR.y + 6.0:
			_no_shadow(_box(walls, Vector3(0.2, HEIGHT - 6.0, 4.0), Vector3(X1 - 0.05, 2.4, z), C_WALL_OPEN, 0.0, 0.9))
	# The hall behind the door: a short, darker corridor.
	var hall := _group(room, "Hall")
	_no_shadow(_box(hall, Vector3(HALL_DOOR.y - HALL_DOOR.x + 4.0, 0.2, 30.0), Vector3((HALL_DOOR.x + HALL_DOOR.y) * 0.5, -0.1, Z1 + 16.0), Color("8a5a32"), 0.0, 0.6))
	for side: float in [HALL_DOOR.x - 1.0, HALL_DOOR.y + 1.0]:
		_no_shadow(_box(hall, Vector3(1.0, HEIGHT, 30.0), Vector3(side, 0, Z1 + 16.0), Color("e6e2d8"), 0.0, 0.9))
	_no_shadow(_box(hall, Vector3(HALL_DOOR.y - HALL_DOOR.x + 4.0, HEIGHT, 1.0), Vector3((HALL_DOOR.x + HALL_DOOR.y) * 0.5, 0, Z1 + 31.0), Color("c8c2b6"), 0.0, 0.9))
	# Door frame.
	for side: float in [HALL_DOOR.x, HALL_DOOR.y]:
		_no_shadow(_box(hall, Vector3(1.0, 40.0, 1.6), Vector3(side, 0, Z1), C_WHITE, 0.0, 0.4, 0.4))
	_no_shadow(_box(hall, Vector3(HALL_DOOR.y - HALL_DOOR.x + 1.0, 1.0, 1.6), Vector3((HALL_DOOR.x + HALL_DOOR.y) * 0.5, 40.0, Z1), C_WHITE, 0.0, 0.4, 0.4))
	# Solid edges all round (the hall and balcony doors are closed for karts).
	var thick := 6.0
	_solid(Vector3(thick, 60.0, depth + 2 * thick), Vector3(X0 - thick * 0.5, 0, 0))
	_solid(Vector3(thick, 60.0, depth + 2 * thick), Vector3(X1 + thick * 0.5, 0, 0))
	_solid(Vector3(X1 - X0 + 2 * thick, 60.0, thick), Vector3(0, 0, Z0 - thick * 0.5))
	_solid(Vector3(X1 - X0 + 2 * thick, 60.0, thick), Vector3(0, 0, Z1 + thick * 0.5))

## The north wall is all window: the river, autumn trees and red houses across the water,
## white frames, a balcony railing, green blinds and a grey curtain.
static func _window_wall(room: Node3D) -> void:
	var group := _group(room, "Windows")
	var z := Z0 - 0.6
	var w := X1 - X0
	# The view, in bands: river, far bank with trees and houses, sky.
	_no_shadow(_box(group, Vector3(w, 16.0, 0.3), Vector3(0, 0, z - 0.4), Color("4f86b0"), 0.0, 0.2))
	_no_shadow(_box(group, Vector3(w, 12.0, 0.3), Vector3(0, 16.0, z - 0.4), Color("d98a3a"), 0.0, 0.9))
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var x := X0 + 3.0
	while x < X1 - 3.0:
		var tall := rng.randf_range(5.0, 11.0)
		var house := rng.randf() < 0.35
		_no_shadow(_box(group, Vector3(rng.randf_range(4.0, 8.0), tall, 0.2), Vector3(x, 26.0, z - 0.3),
			Color("c0563a") if house else [Color("e0a040"), Color("c8742e"), Color("b5522a")][rng.randi_range(0, 2)], 0.0, 0.9))
		x += rng.randf_range(5.0, 9.0)
	_no_shadow(_box(group, Vector3(w, HEIGHT - 28.0, 0.3), Vector3(0, 28.0, z - 0.4), Color("bfe3fb"), 0.0, 0.3))
	# Frames.
	for k in 5:
		var fx := lerpf(X0 + 0.8, X1 - 0.8, k / 4.0)
		_no_shadow(_box(group, Vector3(1.6, HEIGHT, 1.2), Vector3(fx, 0, z + 0.2), C_WHITE, 0.0, 0.4, 0.4))
	for y: float in [0.0, 36.0, HEIGHT - 1.4]:
		_no_shadow(_box(group, Vector3(w, 1.4, 1.2), Vector3(0, y, z + 0.2), C_WHITE, 0.0, 0.4, 0.4))
	# Green blinds above the doors.
	_no_shadow(_box(group, Vector3(w - 4.0, 3.0, 0.4), Vector3(0, 32.6, z + 0.9), Color("3fae5f"), 0.0, 0.8))
	# Balcony railing outside.
	_no_shadow(_box(group, Vector3(w, 0.8, 0.8), Vector3(0, 18.0, z - 0.1), C_WHITE, 0.0, 0.4))
	var bar := X0 + 1.5
	while bar < X1:
		_no_shadow(_box(group, Vector3(0.35, 18.0, 0.35), Vector3(bar, 0, z - 0.1), C_WHITE, 0.0, 0.4))
		bar += 2.6
	# Grey curtain at the west end.
	_box(group, Vector3(5.0, HEIGHT - 3.0, 2.0), Vector3(X0 + 20.0, 0, Z0 + 1.6), Color("4e535e"), 0.0, 0.95)

## The glass sliding wall: frames and glass at both ends, wide open in the middle.
static func _glass_wall(room: Node3D) -> void:
	var group := _group(room, "GlassWall")
	_no_shadow(_box(group, Vector3(X1 - X0, 4.0, 1.6), Vector3(0, HEIGHT - 4.0, GLASS_Z), C_WHITE, 0.0, 0.4, 0.4))
	for span: Vector2 in [Vector2(X0, GLASS_OPEN.x), Vector2(GLASS_OPEN.y, X1)]:
		var width := span.y - span.x
		var mid := (span.x + span.y) * 0.5
		# Two panels side by side (the open doors slid behind the fixed ones).
		for offset: float in [-0.6, 0.6]:
			var pane := _place(group, _pane_mesh(Vector3(width, HEIGHT - 4.0, 0.3)), Vector3(mid, (HEIGHT - 4.0) * 0.5, GLASS_Z + offset), _glass_mat())
			_no_shadow(pane)
		for fx: float in [span.x + 0.8, span.y - 0.8]:
			_box(group, Vector3(1.6, HEIGHT - 4.0, 2.6), Vector3(fx, 0, GLASS_Z), C_WHITE, 0.0, 0.4, 0.4)
		_no_shadow(_box(group, Vector3(width, 1.0, 2.6), Vector3(mid, 0, GLASS_Z), C_WHITE, 0.0, 0.4, 0.4))
		_solid(Vector3(width, HEIGHT, 3.0), Vector3(mid, 0, GLASS_Z))
	# Floor rail across the opening (flat, drive over it).
	_no_shadow(_box(group, Vector3(GLASS_OPEN.y - GLASS_OPEN.x, 0.25, 1.4), Vector3((GLASS_OPEN.x + GLASS_OPEN.y) * 0.5, 0, GLASS_Z), Color("d8dde4"), 0.0, 0.3, 0.5))

static func _pane_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

# --- Veranda ---------------------------------------------------------------------------------

static func _veranda(room: Node3D) -> void:
	var group := _group(room, "Veranda")
	# The wooden garden bench with the big moving box on it. Drive under the seat.
	var bench := _group(group, "Bench")
	var wood := Color("8a4b2a")
	var bx0 := -15.0
	var bx1 := 20.0
	var bz0 := -56.0
	var bz1 := -44.0
	for x: float in [bx0 + 0.9, bx1 - 0.9]:
		for z: float in [bz0 + 0.9, bz1 - 0.9]:
			_block(bench, Vector3(1.8, 12.0 if z > bz0 + 1.0 else 20.0, 1.8), Vector3(x, 0, z), wood, 0.6)
		_box(bench, Vector3(1.6, 1.0, bz1 - bz0), Vector3(x, 12.0, (bz0 + bz1) * 0.5), wood, 0.0, 0.6)
	for k in 5:
		_box(bench, Vector3(bx1 - bx0 - 1.0, 0.8, 1.9), Vector3((bx0 + bx1) * 0.5, 7.6, bz0 + 2.0 + k * 2.2), wood, 0.0, 0.6)
	for k in 4:
		_box(bench, Vector3(bx1 - bx0 - 1.0, 1.6, 0.6), Vector3((bx0 + bx1) * 0.5, 10.0 + k * 2.6, bz0 + 0.9), wood, 0.0, 0.6)
	for x: float in [bx0 + 9.0, bx1 - 9.0]:
		_box(bench, Vector3(15.0, 1.6, 10.0), Vector3(x, 8.4, (bz0 + bz1) * 0.5 + 0.4), Color("f3efe4"), 0.0, 0.95)
	var box := _box(bench, Vector3(15.0, 12.0, 11.0), Vector3(3.0, 10.0, -50.0), C_CARDBOARD, 0.06, 0.95)
	box.name = "MovingBox"
	_box(bench, Vector3(15.2, 0.3, 2.0), Vector3(3.0, 22.0, -50.0), Color("8f939c"), 0.06, 0.6)
	# Plant shelf in the north-west corner and a monstera beside it: the jungle.
	var shelf := _group(group, "PlantShelf")
	for x: float in [-37.0, -25.0]:
		_box(shelf, Vector3(1.0, 34.0, 6.0), Vector3(x, 0, -72.0), C_OAK, 0.0, 0.6)
	# Solid from the wall to the shelf front, and the corner beside it (rolled-up yoga mats
	# and a crate stand there): no pockets for a kart to get stuck in.
	_solid(Vector3(-24.5 - X0, 34.0, 7.0), Vector3((X0 - 24.5) * 0.5, 0, Z0 + 3.5))
	_box(shelf, Vector3(5.6, 5.0, 6.0), Vector3(-40.4, 0, -72.5), Color("2f8f4f"), 0.0, 0.6, 0.3)
	for k in 2:
		_cyl(shelf, 1.3, 1.3, 13.0, Vector3(-41.6 + k * 2.8, 5.0, -73.5), [Color("5a6f8a"), Color("3a8a9a")][k], 16)
	for y: float in [6.0, 16.0, 26.0]:
		_box(shelf, Vector3(12.0, 0.8, 6.0), Vector3(-31.0, y, -72.0), C_OAK, 0.0, 0.6)
		_cyl(shelf, 1.6, 1.3, 2.6, Vector3(-33.0, y + 0.8, -72.0), C_POT, 12)
		_cyl(shelf, 1.4, 1.1, 2.2, Vector3(-28.0, y + 0.8, -72.0), Color("e8483f"), 12)
		for k in 3:
			_ball(shelf, 2.4, Vector3(-34.0 + k * 3.0, y + 4.6, -72.0), C_PLANT if k != 1 else C_PLANT_DARK, 0.2).scale = Vector3(1.0, 0.6, 0.8)
	_box(shelf, Vector3(0.4, 12.0, 14.0), Vector3(X0 + 0.3, 22.0, -60.0), Color("c03070"), 0.0, 0.7)  # the pink painting
	_plant_pot(group, Vector3(-21.0, 0, -64.0), 4.0, 26.0, 7, 7.0)
	# Two tall dracaenas by the east windows.
	_plant_pot(group, Vector3(36.0, 0, -52.0), 3.5, 44.0, 11, 6.0)
	_plant_pot(group, Vector3(36.0, 0, -38.0), 3.5, 40.0, 12, 6.0)
	# A planter box with herbs along the east window.
	_block(group, Vector3(4.0, 3.0, 12.0), Vector3(X1 - 2.0, 0, -66.0), Color("e8a07a"), 0.6)
	for k in 4:
		_ball(group, 1.8, Vector3(X1 - 2.0, 4.0, -70.5 + k * 3.0), C_PLANT, 0.2)
	# The toy walker, parked.
	var walker := _group(group, "Walker", Vector3(14.0, 0, -36.0))
	_block(walker, Vector3(6.0, 3.0, 4.0), Vector3(0, 0.8, 0), Color("e8483f"), 0.4, 0.5)
	for x: float in [-2.6, 2.6]:
		_box(walker, Vector3(0.8, 9.0, 0.8), Vector3(x, 3.0, 1.8), Color("3b8beb"), 0.0, 0.4, 0.5)
	_box(walker, Vector3(6.0, 1.0, 1.0), Vector3(0, 12.0, 1.8), Color("3b8beb"), 0.0, 0.4, 0.5)
	for x: float in [-2.8, 2.8]:
		for z: float in [-1.6, 1.6]:
			_cyl(walker, 0.8, 0.8, 0.6, Vector3(x, 0, z), Color("3b8beb"), 12)
	# The robot vacuum makes its rounds by the west wall (it gently pushes karts aside).
	var robot := ToyMotion.new()
	robot.name = "RobotVacuum"
	robot.kind = ToyMotion.Kind.ORBIT
	robot.amount = 0.0
	robot.speed = 2.2
	robot.radius = 7.0
	robot.position = Vector3(-30.0, 0, -45.0)
	group.add_child(robot)
	_own(robot)
	_cyl(robot, 3.4, 3.5, 1.6, Vector3.ZERO, C_BLACK, 24)
	_cyl(robot, 1.0, 1.0, 0.6, Vector3(0, 1.6, 0.8), Color("3a3d4a"), 16)
	var eye := _ball(robot, 0.35, Vector3(0, 1.0, 3.3), Color("3fdf6f"), 0.0)
	eye.material_override = _mat(Color("3fdf6f"), 0.3, 0.0, 3.0)
	var pusher := AnimatableBody3D.new()
	pusher.name = "Bumper"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 3.5
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position.y = 1.0
	pusher.add_child(shape)
	robot.add_child(pusher)
	_own(pusher)
	_own(shape)

# --- Living room -----------------------------------------------------------------------------

## The red play kitchen and the green workbench by the glass, the foam puzzle mats along the
## west wall (one piece is missing), the clear toy box, a cardboard box and the activity table.
static func _play_corner(room: Node3D) -> void:
	var group := _group(room, "PlayCorner")
	var kz := GLASS_Z + 1.6
	# Play kitchen.
	var red := Color("d1302e")
	# It reaches from the west wall to the workbench (no gap for a kart to wedge into).
	var kw := -29.0 - X0
	var kx := (X0 - 29.0) * 0.5
	_block(group, Vector3(kw, 10.0, 6.0), Vector3(kx, 0, kz + 3.0), red, 0.5, 0.4)
	_box(group, Vector3(kw, 0.8, 6.4), Vector3(kx, 10.0, kz + 3.0), C_WHITE, 0.0, 0.4, 0.4)
	for x: float in [X0 + 0.4, -29.4]:
		_block(group, Vector3(0.8, 10.0, 6.0), Vector3(x, 10.8, kz + 3.0), red, 0.5, 0.4)
	_box(group, Vector3(kw, 4.0, 6.0), Vector3(kx, 17.0, kz + 3.0), red, 0.0, 0.5, 0.4)
	_box(group, Vector3(5.0, 3.0, 0.3), Vector3(-38.0, 3.0, kz + 6.1), Color("2a2b33"), 0.0, 0.2, 0.6)  # oven door
	_cyl(group, 1.4, 1.4, 0.3, Vector3(-33.0, 10.8, kz + 3.0), C_BLACK, 16)
	_box(group, Vector3(5.0, 1.2, 2.0), Vector3(-39.0, 10.8, kz + 3.5), Color("f2b90f"), 0.4, 0.6)  # a toy dino on the stove
	# Workbench.
	var green := Color("23683c")
	_block(group, Vector3(12.0, 9.0, 6.0), Vector3(-23.0, 0, kz + 3.0), Color("8f939c"), 0.5, 0.3)
	_box(group, Vector3(12.4, 1.0, 6.4), Vector3(-23.0, 9.0, kz + 3.0), green, 0.0, 0.5, 0.3)
	_block(group, Vector3(12.0, 13.0, 1.0), Vector3(-23.0, 10.0, kz + 0.6), green, 0.5, 0.3)
	var tools: Array[Color] = [Color("e8483f"), Color("f2b90f"), Color("3b8beb"), Color("f08a24")]
	for k in 4:
		_box(group, Vector3(1.2, 4.0, 0.6), Vector3(-26.5 + k * 2.6, 15.0, kz + 1.3), tools[k], 0.3, 0.5)
	# Puzzle mats: 6 m tiles (30 cm foam) in four colours, one tile missing.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colors: Array[Color] = [Color("e8483f"), Color("3b8beb"), Color("f2b90f"), Color("3fbf5f")]
	var size := 6.0
	var gx := 0
	var x := X0 + 1.2
	while x + size <= -8.0:
		var gz := 0
		var z := -13.0
		while z + size <= 35.5:
			var missing := absf(x + size * 0.5 - -25.0) < 3.0 and absf(z + size * 0.5 - 10.0) < 3.0
			if not missing:
				var color := colors[(gx + gz * 2) % 4]
				for v: Vector3 in [Vector3(x + 0.08, 0, z + 0.08), Vector3(x + size - 0.08, 0, z + 0.08), Vector3(x + size - 0.08, 0, z + size - 0.08),
						Vector3(x + 0.08, 0, z + 0.08), Vector3(x + size - 0.08, 0, z + size - 0.08), Vector3(x + 0.08, 0, z + size - 0.08)]:
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
	_place(room, st.commit(), Vector3(0, 0.05, 0), mat, 0.0, false).name = "PuzzleMats"
	# Clear toy box full of blocks, and the cardboard box.
	var clear := _place(group, _pane_mesh(Vector3(10.0, 6.5, 7.0)), Vector3(-31.0, 3.25, 31.0), _glass_mat())
	_no_shadow(clear)
	_solid(Vector3(10.0, 6.5, 7.0), Vector3(-31.0, 0, 31.0))
	for k in 8:
		_box(group, Vector3(2.0, 2.0, 2.0), Vector3(-34.5 + (k % 4) * 2.3, int(k / 4.0) * 2.0, 29.5 + (k % 2) * 2.4), TOY_COLORS[k % 6], k * 0.4, 0.5, 0.4)
	_block(group, Vector3(7.0, 8.0, 7.0), Vector3(-19.0, 0, 29.0), C_CARDBOARD, 0.95)
	_box(group, Vector3(7.2, 0.3, 2.4), Vector3(-19.0, 8.0, 26.6), C_CARDBOARD.darkened(0.15), 0.0, 0.95)
	# The activity table: three blue legs, an orange top with a wheel. Drive under it.
	var table := _group(group, "ActivityTable", Vector3(-15.0, 0, 17.0))
	for k in 3:
		var angle := TAU * k / 3.0
		_block(table, Vector3(1.4, 8.0, 1.4), Vector3(cos(angle) * 4.0, 0, sin(angle) * 4.0), Color("2fa0e0"), 0.4, 0.5)
	_cyl(table, 5.6, 5.6, 1.4, Vector3(0, 8.0, 0), Color("f08a24"))
	_cyl(table, 1.6, 1.6, 1.0, Vector3(1.5, 9.4, 0), Color("e8483f"), 16)
	_ball(table, 1.0, Vector3(-2.0, 10.0, 1.5), Color("3fbf5f"))

## The green sheet over a frame by the glass: a blanket tent to drive into.
static func _tent(room: Node3D) -> void:
	var group := _group(room, "Tent", Vector3(-2.0, 0, -16.0))
	var half := Vector2(10.0, 9.0)
	var top := 17.0
	for x: float in [-half.x, half.x]:
		for z: float in [-half.y, half.y]:
			_block(group, Vector3(0.8, top, 0.8), Vector3(x, 0, z), Color("6b4a2a"), 0.5)
	_box(group, Vector3(half.x * 2.0 + 2.0, 0.5, half.y * 2.0 + 2.0), Vector3(0, top, 0), C_SAGE, 0.0, 0.95)
	# North and west sides hang to the floor; the east side stops above a kart; the south side
	# is the door with two flaps.
	_block(group, Vector3(half.x * 2.0 + 2.0, top, 0.4), Vector3(0, 0, -half.y - 1.0), C_SAGE.darkened(0.08), 0.95)
	_block(group, Vector3(0.4, top, half.y * 2.0 + 2.0), Vector3(-half.x - 1.0, 0, 0), C_SAGE.darkened(0.12), 0.95)
	_box(group, Vector3(0.4, top - 6.0, half.y * 2.0 + 2.0), Vector3(half.x + 1.0, 6.0, 0), C_SAGE.darkened(0.04), 0.0, 0.95)
	for x: float in [-half.x + 2.0, half.x - 2.0]:
		_block(group, Vector3(4.0, top - 8.0, 0.4), Vector3(x, 8.0, half.y + 1.0), Color("e89ab4"), 0.95)
	# A pink duvet over one corner.
	_box(group, Vector3(8.0, 10.0, 0.6), Vector3(half.x - 3.0, top - 10.0, half.y + 1.4), Color("e86e9a"), 0.0, 0.95)

## The grey corner sofa along the east wall, raised: a dark cave underneath. The fox and the
## bear sit on the back rest.
static func _sofa_corner(room: Node3D) -> void:
	var group := _group(room, "Sofa")
	var lift := 5.0
	var bx := Vector2(27.0, X1 - 0.4)  # back section, x
	var bz := Vector2(-25.0, 21.0)     # back section, z
	var cx := Vector2(13.0, 27.0)      # chaise, x
	var cz := Vector2(5.0, 21.0)       # chaise, z
	for leg: Vector2 in [Vector2(bx.x + 1, bz.x + 1), Vector2(bx.y - 1, bz.x + 1), Vector2(bx.y - 1, bz.y - 1), Vector2(cx.x + 1, cz.x + 1),
			Vector2(cx.x + 1, cz.y - 1), Vector2(bx.x + 1, cz.x - 2), Vector2(bx.x + 1, (bz.x + cz.x) * 0.5)]:
		_block(group, Vector3(1.4, lift, 1.4), Vector3(leg.x, 0, leg.y), C_BLACK, 0.4, 0.4)
	_box(group, Vector3(bx.y - bx.x, 5.0, bz.y - bz.x), Vector3((bx.x + bx.y) * 0.5, lift, (bz.x + bz.y) * 0.5), C_SOFA_GREY, 0.0, 0.95)
	_box(group, Vector3(cx.y - cx.x, 5.0, cz.y - cz.x), Vector3((cx.x + cx.y) * 0.5, lift, (cz.x + cz.y) * 0.5), C_SOFA_GREY, 0.0, 0.95)
	_solid(Vector3(bx.y - bx.x, 20.0, bz.y - bz.x), Vector3((bx.x + bx.y) * 0.5, lift, (bz.x + bz.y) * 0.5))
	_solid(Vector3(cx.y - cx.x, 8.0, cz.y - cz.x), Vector3((cx.x + cx.y) * 0.5, lift, (cz.x + cz.y) * 0.5))
	# Seat cushions, back cushions, the arm at the north end.
	var seat := lift + 5.0
	for z: float in [-17.5, -2.5, 12.5]:
		_box(group, Vector3(bx.y - bx.x - 5.0, 2.6, 14.4), Vector3((bx.x + bx.y - 5.0) * 0.5, seat, z), C_SOFA_GREY.lightened(0.05), 0.0, 0.95)
		_box(group, Vector3(5.0, 10.0, 14.4), Vector3(bx.y - 2.5, seat, z), C_SOFA_GREY.lightened(0.02), 0.0, 0.95)
	_box(group, Vector3(cx.y - cx.x, 2.6, cz.y - cz.x - 0.6), Vector3((cx.x + cx.y) * 0.5, seat, (cz.x + cz.y) * 0.5), C_SOFA_GREY.lightened(0.05), 0.0, 0.95)
	_box(group, Vector3(bx.y - bx.x, 6.0, 4.0), Vector3((bx.x + bx.y) * 0.5, seat, bz.x + 2.0), C_SOFA_GREY, 0.0, 0.95)
	for k in 2:
		var pillow := _box(group, Vector3(3.0, 6.0, 9.0), Vector3(bx.y - 7.0, seat + 2.4, -18.0 + k * 9.0), C_SOFA_DARK, 0.2 - k * 0.4, 0.95)
		pillow.rotation.z = 0.3
	# The blue throw blanket on the chaise.
	_box(group, Vector3(11.0, 0.8, 9.0), Vector3(20.0, seat + 2.6, 12.0), Color("4f7fc8"), 0.3, 0.95)
	_box(group, Vector3(10.0, 0.9, 2.0), Vector3(20.0, seat + 2.7, 10.0), Color("dfe9f7"), 0.3, 0.95)
	# Duplo blocks on the seat.
	for k in 3:
		_box(group, Vector3(1.6, 1.2, 1.6), Vector3(33.0 + k * 1.8, seat + 2.6, 4.0), TOY_COLORS[k + 1], k * 0.5, 0.5, 0.4)
	# The fox and the bear on the back rest.
	var top := seat + 10.0
	_toy(group, "katze", 7.0, Vector3(X1 - 3.0, top, -16.0), -PI * 0.5, ToyMotion.Kind.ROCK, 0.06, 0.35, 0.3)
	_toy(group, "baer", 6.0, Vector3(X1 - 3.0, top, -8.0), -PI * 0.5, ToyMotion.Kind.ROCK, 0.06, 0.3, 1.1)

## The small dark coffee table with the projector under it; the tall floor lamp and the white
## side table by the sofa's south end.
static func _coffee_table_and_lamp(room: Node3D) -> void:
	var group := _group(room, "CoffeeTable")
	var x := Vector2(11.0, 20.0)
	var z := Vector2(-15.0, 3.0)
	_legs(group, x.x, x.y, z.x, z.y, 8.4, 0.7, C_BLACK, 0.2)
	_box(group, Vector3(x.y - x.x, 1.0, z.y - z.x), Vector3((x.x + x.y) * 0.5, 8.4, (z.x + z.y) * 0.5), Color("6b4226"), 0.0, 0.4, 0.5)
	_box(group, Vector3(5.0, 0.3, 7.0), Vector3(15.0, 9.4, -8.0), Color("f3f0e6"), 0.2, 0.9)  # newspaper
	_box(group, Vector3(3.6, 0.3, 4.6), Vector3(16.0, 9.7, -4.0), Color("3b8beb"), -0.2, 0.4)  # picture book
	var projector := _block(group, Vector3(4.4, 2.2, 3.6), Vector3(15.5, 0, -10.0), C_WHITE, 0.4, 0.5)
	projector.name = "Projector"
	_cyl(group, 0.9, 0.9, 0.4, Vector3(15.5, 0.9, -8.0), Color("2a2b33"), 16).rotation.x = PI * 0.5
	# Floor lamp: dark pole, a big white shade and a small reading arm. Its light comes on at
	# bedtime (named "LampLight", switched on by the explore mode).
	var lamp := _group(room, "FloorLamp", Vector3(41.0, 0, 23.5))
	_cyl(lamp, 2.6, 2.8, 0.6, Vector3.ZERO, C_BLACK)
	_cyl(lamp, 0.35, 0.35, 36.0, Vector3(0, 0.6, 0), C_BLACK, 8)
	_solid(Vector3(1.4, 36.0, 1.4), Vector3(41.0, 0, 23.5))
	_solid(Vector3(5.0, 0.7, 5.0), Vector3(41.0, 0, 23.5))
	var shade := _cyl(lamp, 4.6, 1.2, 4.0, Vector3(0, 35.0, 0), C_WHITE)
	shade.material_override = _mat(Color("fff4d8"), 0.5, 0.0, 0.4)
	_cyl(lamp, 1.6, 0.6, 1.8, Vector3(-3.0, 26.0, 0.5), C_WHITE)
	var light := OmniLight3D.new()
	light.name = "LampLight"
	light.light_color = Color(1.0, 0.78, 0.45)
	light.light_energy = 0.0
	light.omni_range = 70.0
	light.shadow_enabled = false
	light.position = Vector3(0, 33.0, 0)
	lamp.add_child(light)
	_own(light)
	# White side table with a laptop and cables.
	var side := _group(room, "SideTable")
	# It stands right against the lamp's foot: no gap to wedge into.
	_legs(side, 35.0, X1 - 0.4, 26.4, 36.4, 11.0, 0.8, C_WHITE, 0.2)
	_box(side, Vector3(X1 - 35.4, 0.8, 10.0), Vector3((35.0 + X1 - 0.4) * 0.5, 11.0, 31.4), C_WHITE, 0.0, 0.4, 0.4)
	_box(side, Vector3(5.0, 0.4, 3.6), Vector3(38.0, 11.8, 30.4), Color("8f939c"), 0.3, 0.3, 0.6)

## The purple yoga mat in the middle of the room (the builder puts turbo arrows on it).
static func _yoga_mat(room: Node3D) -> void:
	_no_shadow(_box(room, Vector3(12.0, 0.12, 36.0), Vector3(2.0, 0.02, 20.0), Color("a23b72"), 0.0, 0.9))

## Dad's desk on the west wall: drive under it between the black legs. The chair on its mat.
static func _desk(room: Node3D) -> void:
	var group := _group(room, "Desk")
	var x := Vector2(X0 + 0.2, -28.5)
	var z := Vector2(38.0, 66.0)
	var top := 14.0
	# Four black legs at the corners (the real desk has T-feet; for a toy kart that was a maze).
	for lx: float in [X0 + 1.2, x.y - 1.2]:
		for lz: float in [z.x + 1.2, z.y - 1.2]:
			_block(group, Vector3(2.0, top, 2.0), Vector3(lx, 0, lz), C_BLACK, 0.4, 0.4)
	_box(group, Vector3(x.y - x.x, 1.0, z.y - z.x), Vector3((x.x + x.y) * 0.5, top, (z.x + z.y) * 0.5), C_OAK, 0.0, 0.4, 0.4)
	_solid(Vector3(x.y - x.x, 1.0, z.y - z.x), Vector3((x.x + x.y) * 0.5, top, (z.x + z.y) * 0.5))
	# Two screens, keyboard, a mug, headphones.
	for k in 2:
		var screen := _box(group, Vector3(0.6, 9.0, 12.0), Vector3(-41.0, top + 4.0, 42.0 + k * 13.0), C_BLACK, 0.0, 0.3, 0.6)
		screen.rotation.y = 0.15 - k * 0.3
		var glow := _box(group, Vector3(0.2, 8.0, 11.0), Vector3(-40.6, top + 4.5, 42.0 + k * 13.0), Color("5a3fd0"), 0.0, 0.3)
		glow.material_override = _mat(Color("5a3fd0"), 0.3, 0.0, 1.2)
		glow.rotation.y = 0.15 - k * 0.3
		_box(group, Vector3(2.0, 4.0, 1.0), Vector3(-41.0, top + 1.0, 42.0 + k * 13.0), C_BLACK, 0.0, 0.4)
	_box(group, Vector3(4.0, 0.5, 10.0), Vector3(-33.0, top + 1.0, 49.0), C_BLACK, 0.0, 0.3, 0.6)
	_cyl(group, 1.2, 1.0, 2.4, Vector3(-32.0, top + 1.0, 58.0), Color("e9f2e2"), 16)
	# PC tower and a speaker under the desk.
	_block(group, Vector3(4.6, 9.0, 8.0), Vector3(X0 + 2.3, 0, 47.0), C_BLACK, 0.3, 0.6)
	# The chair mat (clear), and the white desk chair: five feet, seat, back.
	var mat := _place(group, _pane_mesh(Vector3(20.0, 0.1, 26.0)), Vector3(-19.0, 0.08, 47.0), _glass_mat())
	_no_shadow(mat)
	var chair := _group(group, "Chair", Vector3(-22.0, 0, 46.0))
	for k in 5:
		var foot := _box(chair, Vector3(0.8, 0.8, 5.6), Vector3(0, 0.8, 0), Color("e4e6ea"), TAU * k / 5.0, 0.4, 0.4)
		foot.position += Vector3(sin(TAU * k / 5.0), 0, cos(TAU * k / 5.0)) * 2.6
		_ball(chair, 0.6, Vector3(sin(TAU * k / 5.0) * 5.2, 0.6, cos(TAU * k / 5.0) * 5.2), Color("e4e6ea"))
	_solid(Vector3(10.0, 1.6, 10.0), Vector3(-22.0, 0, 46.0))
	_solid(Vector3(1.6, 9.0, 1.6), Vector3(-22.0, 0, 46.0))
	_cyl(chair, 0.6, 0.6, 8.0, Vector3(0, 1.2, 0), Color("c9ccd2"), 8)
	_box(chair, Vector3(9.0, 1.6, 8.6), Vector3(0, 9.0, 0), Color("dfe1e6"), 0.0, 0.8)
	var back := _box(chair, Vector3(8.0, 13.0, 1.2), Vector3(4.8, 10.0, 0), Color("dfe1e6"), PI * 0.5, 0.8)
	back.rotation.z = -0.12
	_box(chair, Vector3(5.0, 3.0, 1.2), Vector3(5.6, 24.0, 0), Color("dfe1e6"), PI * 0.5, 0.8)

## The oak dining table with four velvet tub chairs, the high chair, all on legs to drive under.
static func _dining(room: Node3D) -> void:
	var group := _group(room, "Dining")
	var x := Vector2(10.0, 34.0)
	var z := Vector2(47.0, 61.0)
	var top := 14.4
	_legs(group, x.x, x.y, z.x, z.y, top, 1.6, C_OAK, 1.0)
	_box(group, Vector3(x.y - x.x, 1.0, z.y - z.x), Vector3((x.x + x.y) * 0.5, top, (z.x + z.y) * 0.5), C_OAK, 0.0, 0.35, 0.5)
	_solid(Vector3(x.y - x.x, 1.0, z.y - z.x), Vector3((x.x + x.y) * 0.5, top, (z.x + z.y) * 0.5))
	var glass := _cyl(group, 1.0, 0.8, 3.0, Vector3(24.0, top + 1.0, 52.0), C_WHITE)
	glass.material_override = _glass_mat()
	for spot: Array in [[Vector3(16.0, 0, 42.0), 0.0], [Vector3(28.0, 0, 42.0), 0.0], [Vector3(16.0, 0, 63.0), PI], [Vector3(28.0, 0, 63.0), PI]]:
		_tub_chair(group, spot[0], spot[1])
	# The high chair: white tray on four thin silver legs.
	var high := _group(group, "HighChair", Vector3(-6.0, 0, 56.0))
	for lx: float in [-3.0, 3.0]:
		for lz: float in [-3.0, 3.0]:
			var leg := _box(high, Vector3(0.5, 13.5, 0.5), Vector3(lx, 0, lz), Color("c9ccd2"), 0.0, 0.3, 0.6)
			leg.rotation = Vector3(-lz * 0.03, 0, lx * 0.03)
			_solid(Vector3(0.8, 13.0, 0.8), Vector3(-6.0 + lx * 1.1, 0, 56.0 + lz * 1.1))
	_box(high, Vector3(7.0, 2.4, 6.0), Vector3(0, 13.0, 0), C_WHITE, 0.0, 0.4, 0.5)
	_box(high, Vector3(7.0, 0.8, 4.0), Vector3(0, 15.4, -3.6), C_WHITE, 0.0, 0.4, 0.5)
	_box(high, Vector3(7.0, 6.0, 0.8), Vector3(0, 15.4, 3.0), C_WHITE, 0.0, 0.4, 0.5)

## A velvet tub chair on four wooden legs; its back faces `yaw` (0 = back to the north).
static func _tub_chair(parent: Node3D, at: Vector3, yaw: float) -> void:
	var chair := _group(parent, "TubChair", at)
	chair.rotation.y = yaw
	for lx: float in [-3.6, 3.6]:
		for lz: float in [-3.6, 3.6]:
			_box(chair, Vector3(0.7, 8.6, 0.7), Vector3(lx, 0, lz), C_OAK, 0.0, 0.4, 0.4)
			_solid(Vector3(0.9, 8.6, 0.9), at + Vector3(lx, 0, lz).rotated(Vector3.UP, yaw))
	_cyl(chair, 5.4, 4.8, 2.4, Vector3(0, 8.4, 0), C_VELVET)
	var back := _cyl(chair, 5.6, 5.4, 6.0, Vector3(0, 10.8, -1.4), C_VELVET.darkened(0.1))
	back.scale = Vector3(1.0, 1.0, 0.5)
	_cyl(chair, 4.6, 4.6, 0.8, Vector3(0, 10.8, 0.6), C_VELVET.lightened(0.1))

## The south wall: the tall narrow shelf with blue drawers, the photo wall, and the two oak
## bookshelves with board games on top.
static func _south_wall(room: Node3D) -> void:
	var group := _group(room, "SouthWall")
	# Tall narrow shelf in the south-west corner.
	var sx := Vector2(X0 + 0.2, -35.0)
	var sz := Vector2(66.0, Z1 - 0.2)
	_block(group, Vector3(sx.y - sx.x, 44.0, sz.y - sz.x), Vector3((sx.x + sx.y) * 0.5, 0, (sz.x + sz.y) * 0.5), C_OAK, 0.6)
	for k in 5:
		_box(group, Vector3(0.4, 3.4, sz.y - sz.x - 1.6), Vector3(sx.y + 0.1, 1.0 + k * 3.8, (sz.x + sz.y) * 0.5), Color("1f3f7a"), 0.0, 0.4, 0.4)
		_cyl(group, 0.4, 0.4, 0.6, Vector3(sx.y + 0.4, 2.4 + k * 3.8, (sz.x + sz.y) * 0.5), C_WHITE, 8).rotation.z = PI * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for shelf in 4:
		var y := 22.0 + shelf * 5.4
		var z := sz.x + 1.0
		while z < sz.y - 1.2:
			var thick := rng.randf_range(0.6, 1.2)
			_box(group, Vector3(0.4, rng.randf_range(3.0, 4.4), thick), Vector3(sx.y + 0.1, y, z + thick * 0.5), TOY_COLORS[rng.randi_range(0, 5)], 0.0, 0.7)
			z += thick + 0.1
	# Photo wall (family pictures and his drawing).
	for k in 14:
		var px := -9.0 + (k % 5) * 2.8 + rng.randf_range(-0.8, 0.8)
		var py := 18.0 + int(k / 5.0) * 4.0 + rng.randf_range(-0.8, 0.8)
		var photo := _box(group, Vector3(2.6, 3.2, 0.2), Vector3(px, py, Z1 - 0.15), [Color("fffdf5"), Color("8fd0ff"), Color("f2b90f"), Color("e8483f"), Color("3fbf5f")][k % 5], 0.0, 0.6)
		photo.rotation.z = rng.randf_range(-0.3, 0.3)
	# Oak bookshelf with doors below and board games on top, and a low one beside it.
	var tall := Vector2(6.0, 21.0)
	var low := Vector2(21.2, 34.0)
	var bz := Vector2(70.5, Z1 - 0.2)
	_block(group, Vector3(tall.y - tall.x, 40.0, bz.y - bz.x), Vector3((tall.x + tall.y) * 0.5, 0, (bz.x + bz.y) * 0.5), C_OAK, 0.6)
	_block(group, Vector3(low.y - low.x, 21.0, bz.y - bz.x), Vector3((low.x + low.y) * 0.5, 0, (bz.x + bz.y) * 0.5), C_OAK, 0.6)
	for k in 2:
		_box(group, Vector3(6.8, 15.0, 0.3), Vector3(tall.x + 3.8 + k * 7.4, 0.8, bz.x - 0.1), C_OAK.lightened(0.12), 0.0, 0.6)
	for row in 3:
		var y := 17.0 + row * 7.6
		var x := tall.x + 1.0
		while x < tall.y - 1.0:
			var thick := rng.randf_range(0.6, 1.3)
			_box(group, Vector3(thick, rng.randf_range(4.0, 6.0), 4.0), Vector3(x + thick * 0.5, y, bz.x + 2.6), TOY_COLORS[rng.randi_range(0, 5)], 0.0, 0.7)
			x += thick + 0.1
	for row in 2:
		var x := low.x + 1.0
		while x < low.y - 1.0:
			var thick := rng.randf_range(0.6, 1.3)
			_box(group, Vector3(thick, rng.randf_range(3.5, 5.5), 4.0), Vector3(x + thick * 0.5, 2.0 + row * 9.5, bz.x + 2.6), TOY_COLORS[rng.randi_range(0, 5)], 0.0, 0.7)
			x += thick + 0.1
	var gy := 40.0
	for k in 5:
		var game_box := _box(group, Vector3(rng.randf_range(9.0, 13.0), 1.6, 5.0), Vector3(13.5 + rng.randf_range(-1.0, 1.0), gy, bz.x + 2.8), TOY_COLORS[(k + 2) % 6], rng.randf_range(-0.1, 0.1), 0.6)
		game_box.name = "Game%d" % k
		gy += 1.6

## The balcony door on the east wall with teal curtains.
static func _east_door(room: Node3D) -> void:
	var group := _group(room, "EastDoor")
	var mid := (EAST_DOOR.x + EAST_DOOR.y) * 0.5
	_no_shadow(_box(group, Vector3(0.3, 44.0, EAST_DOOR.y - EAST_DOOR.x), Vector3(X1 + 0.6, 0, mid), Color("bfe3fb"), 0.0, 0.2))
	for z: float in [EAST_DOOR.x + 0.6, EAST_DOOR.y - 0.6, mid]:
		_no_shadow(_box(group, Vector3(1.0, 44.0, 1.2), Vector3(X1 + 0.3, 0, z), C_WHITE, 0.0, 0.4, 0.4))
	_no_shadow(_box(group, Vector3(1.0, 1.0, EAST_DOOR.y - EAST_DOOR.x), Vector3(X1 + 0.3, 32.0, mid), C_WHITE, 0.0, 0.4, 0.4))
	for z: float in [EAST_DOOR.x - 1.0, EAST_DOOR.y + 1.0]:
		_box(group, Vector3(1.4, HEIGHT - 3.0, 4.0), Vector3(X1 - 0.8, 0, z), C_TEAL, 0.0, 0.95)

## The rattan pendant over the sofa corner and the bare bulb over the dining table.
static func _pendants(room: Node3D) -> void:
	var group := _group(room, "Pendants")
	_cyl(group, 0.15, 0.15, 8.0, Vector3(17.0, HEIGHT - 8.0, -6.0), C_WHITE, 6)
	var shade := _ball(group, 6.0, Vector3(17.0, HEIGHT - 13.0, -6.0), Color("c8915a"), 0.0)
	shade.scale = Vector3(1.0, 0.9, 1.0)
	_cyl(group, 0.15, 0.15, 14.0, Vector3(22.0, HEIGHT - 14.0, 54.0), C_BLACK, 6)
	var bulb := _ball(group, 1.6, Vector3(22.0, HEIGHT - 15.6, 54.0), Color("ffe7a8"), 0.0)
	bulb.material_override = _mat(Color("ffe7a8"), 0.3, 0.0, 1.5)
	var light := OmniLight3D.new()
	light.name = "BulbLight"
	light.light_color = Color(1.0, 0.8, 0.5)
	light.light_energy = 0.0
	light.omni_range = 40.0
	light.position = Vector3(22.0, HEIGHT - 16.0, 54.0)
	group.add_child(light)
	_own(light)

# --- Merging ---------------------------------------------------------------------------------

## Fewer draw calls: every plain box, cylinder and ball under `room` (not under a moving toy)
## that shares a material and shadow setting becomes one mesh.
static func merge(room: Node3D) -> int:
	var groups := {}
	var removed: Array[MeshInstance3D] = []
	for node in room.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not (mi.mesh is PrimitiveMesh) or mi.material_override == null or _under_motion(mi, room):
			continue
		var mat := mi.material_override
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var key := "%d/%d" % [mat.get_instance_id(), mi.cast_shadow]
		if not groups.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = [st, mat, mi.cast_shadow]
		var xform := mi.transform
		var parent := mi.get_parent()
		while parent != room:
			xform = (parent as Node3D).transform * xform
			parent = parent.get_parent()
		(groups[key][0] as SurfaceTool).append_from(mi.mesh, 0, xform)
		removed.append(mi)
	for mi in removed:
		mi.get_parent().remove_child(mi)
		mi.free()
	var holder := Node3D.new()
	holder.name = "Merged"
	room.add_child(holder)
	holder.owner = _root
	var n := 0
	for key: String in groups:
		var spec: Array = groups[key]
		var inst := MeshInstance3D.new()
		inst.name = "Part%d" % n
		inst.mesh = (spec[0] as SurfaceTool).commit()
		inst.material_override = spec[1]
		inst.cast_shadow = spec[2]
		holder.add_child(inst)
		inst.owner = _root
		n += 1
	return removed.size()

static func _under_motion(node: Node, room: Node3D) -> bool:
	var p := node.get_parent()
	while p != null and p != room:
		if p is ToyMotion:
			return true
		p = p.get_parent()
	return false
