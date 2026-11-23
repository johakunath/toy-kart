extends SceneTree
## Builds a track scene from a short description: Kenney tiles in a GridMap plus the racing line.
## Tiles and line come from the same list of moves, so they always match.
##
##   godot --headless --path . --script res://tools/build_track.gd
##
## Writes scenes/tracks/waldkurs.tscn and data/tracks/waldkurs.tres. After that the scene can be edited in the Godot editor
## (GridMap tiles, the RacingLine path, the stars). Re-running this script overwrites it.

const CELL := 9.99          # GridMap cell size in tile units (as in the Kenney kit)
const SCALE := 0.75         # GridMap scale (as in the Kenney kit)
const TILE_HALF := 5.0      # tiles are 10 units wide
const ITEM_EMPTY := 0
const ITEM_FOREST := 1
const ITEM_TENTS := 2
const ITEM_CORNER := 3
const ITEM_FINISH := 4
const ITEM_STRAIGHT := 6
const ARC := 0.5523         # Bezier handle factor for a quarter circle

## x grows to the east, z to the south. The first tile is the finish tile.
## S = straight on, L = turn left, R = turn right.
const TRACK := {
	"name": "waldkurs",
	"display_name": "Waldkurs",
	"sort_order": 20,
	"start": Vector2i(4, 6),
	"heading": Vector2i(1, 0),
	"moves": "SSS L SSSSS L S L SSS R SSS R S R S L S L SSS L SSSSS L SSS",
	# Stars: [tile number along the track, sideways offsets in metres]
	"stars": [[8, [-1.6, 0.0, 1.6]], [18, [-1.2]], [22, [-1.6, 0.0, 1.6]], [32, [1.4]], [38, [-1.6, 0.0, 1.6]]],
	# Turbo arrows: [metres along the racing line, sideways offsets in metres]
	"pads": [[12.0, [-1.4, 1.4]], [108.0, [-1.2]], [210.0, [0.0]]],
	# Signature moment (tools/track_moments.gd): the owl tree gate over the middle of a straight
	# tile; the tiles on both sides stay empty for the trees.
	"moment": {"kind": "owl", "tile": 7},
}

func _process(_delta: float) -> bool:
	var err := _build(TRACK)
	quit(0 if err == OK else 1)
	return true

func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * CELL * SCALE, 0.0, (cell.y + 0.5) * CELL * SCALE)

func _dir3(d: Vector2i) -> Vector3:
	return Vector3(d.x, 0, d.y)

func _yaw_index(grid: GridMap, quarter_turns: int) -> int:
	return grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, quarter_turns * PI / 2.0))

## Which quarter turn makes the corner tile connect the two given edges.
## Unrotated, the corner tile connects its -X edge and its +Z edge.
func _corner_turns(edge_a: Vector2i, edge_b: Vector2i) -> int:
	for k in 4:
		var basis := Basis(Vector3.UP, k * PI / 2.0)
		var e1 := basis * Vector3(-1, 0, 0)
		var e2 := basis * Vector3(0, 0, 1)
		var v1 := Vector2i(roundi(e1.x), roundi(e1.z))
		var v2 := Vector2i(roundi(e2.x), roundi(e2.z))
		if (v1 == edge_a and v2 == edge_b) or (v1 == edge_b and v2 == edge_a):
			return k
	push_error("No corner rotation for edges %s %s" % [edge_a, edge_b])
	return 0

func _build(def: Dictionary) -> Error:
	var root := Track.new()
	root.name = "Track"
	root.half_width = 4.5 * SCALE

	TrackBuildCommon.add_ground_collider(root)

	# --- Tiles ---
	var grid := GridMap.new()
	grid.name = "GridMap"
	grid.mesh_library = load("res://assets/kenney_racing/models/Library/mesh-library.tres")
	grid.cell_size = Vector3(CELL, 1, CELL)
	grid.transform = Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3(0, -0.5, 0))
	var wall_material := PhysicsMaterial.new()
	wall_material.friction = 0.0
	wall_material.bounce = 0.1
	grid.physics_material = wall_material
	root.add_child(grid)

	var cell: Vector2i = def["start"]
	var dir: Vector2i = def["heading"]
	var moves: String = (def["moves"] as String).replace(" ", "")
	var tiles: Array[Dictionary] = []   # {cell, dir_in, dir_out}
	tiles.append({"cell": cell, "dir_in": dir, "dir_out": dir, "finish": true})
	for move in moves:
		cell += dir
		var out_dir := dir
		if move == "L":
			out_dir = Vector2i(dir.y, -dir.x)
		elif move == "R":
			out_dir = Vector2i(-dir.y, dir.x)
		tiles.append({"cell": cell, "dir_in": dir, "dir_out": out_dir, "finish": false})
		dir = out_dir
	if cell + dir != def["start"] or dir != def["heading"]:
		push_error("Track does not close: ends at %s heading %s" % [cell + dir, dir])
		return ERR_INVALID_DATA

	var used := {}
	for tile in tiles:
		var c: Vector2i = tile["cell"]
		if used.has(c):
			push_error("Track crosses itself at %s" % c)
			return ERR_INVALID_DATA
		used[c] = true
		var d_in: Vector2i = tile["dir_in"]
		var d_out: Vector2i = tile["dir_out"]
		if d_in == d_out:
			# The straight tile runs along Z when unrotated.
			var turns := 0 if d_in.x == 0 else 1
			grid.set_cell_item(Vector3i(c.x, 0, c.y), ITEM_FINISH if tile["finish"] else ITEM_STRAIGHT, _yaw_index(grid, turns))
		else:
			grid.set_cell_item(Vector3i(c.x, 0, c.y), ITEM_CORNER, _yaw_index(grid, _corner_turns(-d_in, d_out)))

	# The moment's trees stand on the tiles beside its tile: keep those free.
	var keep_free := {}
	var moment_tile := {}
	if def.has("moment"):
		moment_tile = tiles[int(def["moment"]["tile"])]
		if moment_tile["dir_in"] != moment_tile["dir_out"]:
			push_error("The moment needs a straight tile.")
			return ERR_INVALID_DATA
		var d_in: Vector2i = moment_tile["dir_in"]
		for side: Vector2i in [Vector2i(d_in.y, -d_in.x), Vector2i(-d_in.y, d_in.x)]:
			var c: Vector2i = moment_tile["cell"] + side
			if used.has(c):
				push_error("The moment's trees would stand on the road at %s." % c)
				return ERR_INVALID_DATA
			keep_free[c] = true

	# Scenery around the track: grass next to the road, forest and a few tents further out.
	var min_c := Vector2i(999, 999)
	var max_c := Vector2i(-999, -999)
	for c: Vector2i in used:
		min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261121
	for x in range(min_c.x - 4, max_c.x + 5):
		for z in range(min_c.y - 4, max_c.y + 5):
			var c := Vector2i(x, z)
			if used.has(c):
				continue
			var near_track := false
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if used.has(c + Vector2i(dx, dz)):
						near_track = true
			var item := ITEM_FOREST
			var roll := rng.randf()
			if keep_free.has(c):
				grid.set_cell_item(Vector3i(x, 0, z), ITEM_EMPTY)
				continue
			if near_track:
				item = ITEM_EMPTY if roll < 0.8 else ITEM_TENTS
			elif roll < 0.12:
				item = ITEM_EMPTY
			elif roll < 0.18:
				item = ITEM_TENTS
			grid.set_cell_item(Vector3i(x, 0, z), item, _yaw_index(grid, rng.randi_range(0, 3)))

	# --- Racing line: one point per tile border, along the middle of the road ---
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	var straight_handle := CELL * SCALE / 3.0
	var arc_handle := ARC * TILE_HALF * SCALE
	var start_dir := _dir3(def["heading"])
	var start_pos := _cell_center(def["start"])
	curve.add_point(start_pos, -start_dir * straight_handle, start_dir * straight_handle)
	for i in tiles.size():
		var tile := tiles[i]
		var next_tile := tiles[(i + 1) % tiles.size()]
		var d: Vector2i = tile["dir_out"]
		var border := _cell_center(tile["cell"]) + _dir3(d) * (CELL * SCALE * 0.5)
		var h_in := arc_handle if tile["dir_in"] != tile["dir_out"] else straight_handle
		var h_out := arc_handle if next_tile["dir_in"] != next_tile["dir_out"] else straight_handle
		curve.add_point(border, -_dir3(d) * h_in, _dir3(d) * h_out)
	curve.add_point(start_pos, -start_dir * straight_handle, start_dir * straight_handle)
	var path := Path3D.new()
	path.name = "RacingLine"
	path.curve = curve
	root.add_child(path)

	# --- Boost stars ---
	var stars := Node3D.new()
	stars.name = "Stars"
	root.add_child(stars)
	var star_scene: PackedScene = load("res://scenes/boost_star.tscn")
	var star_number := 1
	for entry in def["stars"]:
		var tile: Dictionary = tiles[entry[0]]
		var d3 := _dir3(tile["dir_in"])
		var right := d3.cross(Vector3.UP)
		var center := _cell_center(tile["cell"])
		if tile["dir_in"] != tile["dir_out"]:
			continue  # keep stars on straights
		for lateral: float in entry[1]:
			var star := star_scene.instantiate() as Node3D
			star.name = "Star%d" % star_number
			star_number += 1
			star.position = center + right * lateral
			stars.add_child(star)
			star.owner = root

	for node in [grid, path, stars]:
		node.owner = root
	TrackBuildCommon.add_pads(root, curve, def["pads"], -0.15)
	if def.has("moment"):
		_add_moment(root, def, curve, _cell_center(moment_tile["cell"]))

	# Warm evening light with long tree shadows across the road.
	var area_lo := _cell_center(min_c)
	var area_hi := _cell_center(max_c)
	TrackBuildCommon.add_atmosphere(root, Atmosphere.Look.GOLDEN_EVENING, (area_lo + area_hi) * 0.5, area_hi - area_lo)

	var err := TrackBuildCommon.save_scene(root, def["name"])
	if err == OK:
		err = TrackBuildCommon.write_track_def(def["name"], def["display_name"], def["sort_order"], curve)
	print("track written: res://scenes/tracks/%s.tscn" % def["name"], "  tiles=", tiles.size(), "  line length=%.1f m" % curve.get_baked_length(), "  stars=", star_number - 1, "  err=", err)
	root.free()
	return err

## The signature moment over the given tile centre. tools/track_moments.gd builds it from road
## slices: here they come from the racing line (flat road, no banking).
func _add_moment(root: Node3D, def: Dictionary, curve: Curve3D, at: Vector3) -> void:
	var length := curve.get_baked_length()
	var count := int(round(length / 0.75))
	var pos := PackedVector3Array()
	var right := PackedVector3Array()
	pos.resize(count)
	right.resize(count)
	for i in count:
		pos[i] = curve.sample_baked(length * i / count, true)
	for i in count:
		var dir := pos[(i + 1) % count] - pos[(i - 1 + count) % count]
		dir.y = 0.0
		right[i] = dir.normalized().cross(Vector3.UP).normalized()
	var flat := PackedFloat32Array()
	flat.resize(count)
	var moment: Dictionary = (def["moment"] as Dictionary).duplicate()
	moment["at"] = curve.get_closest_offset(at)
	TrackMoments.new(pos, right, flat, flat, length / count, -0.15, 4.5 * SCALE).build(root, {"id": def["name"], "moment": moment})
