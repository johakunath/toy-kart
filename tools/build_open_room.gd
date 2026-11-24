extends SceneTree
## Builds the open living room for the "Entdecken" mode:
##
##   godot --headless --path . --script res://tools/build_open_room.gd
##
## Writes scenes/worlds/wohnzimmer_offen.tscn: the room (tools/open_room.gd), light and sky,
## the floor collider, turbo arrows on the yoga mat, and markers the mode reads at runtime:
##   Spots/Start0, Start1        where the karts start (facing north, toward the windows)
##   Spots/Park0 .. Park3        where the karts park at bedtime
##   Finds/<id>                  the 8 lost things; meta "for" = the friend who wants it
##   Friends/<id>                toy friends; meta "model", "height"
## To move a hiding spot: change FINDS below, run this, run the checks.

const OUT := "res://scenes/worlds/wohnzimmer_offen.tscn"

## The lost things, in the order of the Fundkiste: [id, position (x, z), friend or ""].
const FINDS := [
	["sock", Vector2(35.0, -6.0), ""],          # under the sofa
	["remote", Vector2(15.5, -3.5), ""],        # under the coffee table, by the projector
	["crayon", Vector2(-37.0, 53.0), ""],       # under the desk
	["puzzle", Vector2(-25.0, 10.0), ""],       # the hole in the puzzle mats
	["brick", Vector2(-2.0, -16.0), ""],        # inside the blanket tent
	["dummy", Vector2(3.0, 58.0), "sanitaeter"],  # by the high chair
	["car", Vector2(3.0, -50.0), "polizei"],    # under the veranda bench
	["dino", Vector2(-31.0, -62.0), "koba"],    # in the plant jungle
]
## Toy friends: [id, model, height in metres, position (x, z), facing (radians, 0 = south)].
const FRIENDS := [
	["koba", "loewe", 12.0, Vector2(-20.0, 0.0), 0.9],
	["sanitaeter", "duplojunge", 10.0, Vector2(-21.0, 67.0), PI - 0.4],
	["polizei", "polizei", 6.5, Vector2(22.0, -36.0), -0.6],
]
const STARTS := [Vector2(-11.0, 44.0), Vector2(-2.0, 44.0)]
const PARKING := [Vector2(-12.0, 36.0), Vector2(-5.0, 36.0), Vector2(2.0, 36.0), Vector2(-19.0, 36.0)]

func _process(_delta: float) -> bool:
	var root := Node3D.new()
	root.name = "OpenWorld"
	# The explore mode reads the room's floor from here (tools/ is not in the exported game).
	root.set_meta("room_lo", Vector2(OpenRoom.X0, OpenRoom.Z0))
	root.set_meta("room_hi", Vector2(OpenRoom.X1, OpenRoom.Z1))
	var center := Vector3(0, 0, 0)
	var size := Vector3(OpenRoom.X1 - OpenRoom.X0, 0, OpenRoom.Z1 - OpenRoom.Z0)
	TrackBuildCommon.add_atmosphere(root, Atmosphere.Look.LIVING_ROOM, center, size)
	TrackBuildCommon.add_ground_collider(root)
	var room := OpenRoom.build_open(root)
	var merged := OpenRoom.merge(room)

	var spots := _node(root, "Spots")
	for i in STARTS.size():
		_marker(spots, "Start%d" % i, STARTS[i], PI)
	for i in PARKING.size():
		_marker(spots, "Park%d" % i, PARKING[i], PI)
	var finds := _node(root, "Finds")
	for spec: Array in FINDS:
		_marker(finds, spec[0], spec[1], 0.0).set_meta("for", spec[2])
	var friends := _node(root, "Friends")
	for spec: Array in FRIENDS:
		var m := _marker(friends, spec[0], spec[3], spec[4])
		m.set_meta("model", spec[1])
		m.set_meta("height", spec[2])

	# Turbo arrows along the yoga mat, pointing north (toward the windows).
	var pads := _node(root, "BoostPads")
	var number := 1
	for z: float in [30.0, 17.0, 4.0]:
		var pad := BoostPad.new()
		pad.name = "Pad%d" % number
		number += 1
		pad.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(2.0, 0.0, z))
		pads.add_child(pad)
		pad.owner = root

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/worlds"))
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	var solids := root.get_node("Solids").get_child_count()
	print("open room written: %s  merged=%d  solids=%d  err=%d" % [OUT, merged, solids, err])
	root.free()
	quit(0 if err == OK else 1)
	return true

func _node(root: Node3D, node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	root.add_child(node)
	node.owner = root
	return node

func _marker(parent: Node3D, marker_name: String, at: Vector2, yaw: float) -> Marker3D:
	var m := Marker3D.new()
	m.name = marker_name
	m.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, 0, at.y))
	parent.add_child(m)
	m.owner = parent.owner
	return m
