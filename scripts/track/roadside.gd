class_name Roadside extends Node3D
## Life beside the start/finish line, built by the race at runtime:
## - toy buildings (3D models of the police station and the Duplo shop, built by
##   tools/blender/build_duplo_buildings.py; the photo cards from tools/make_props.py only if a
##   model is missing) standing well off the road, facing the karts coming up;
## - every driver that is not in this race, standing at the roadside to watch. They sway,
##   hop when a human kart drives past and cheer when a human finishes.
## Nothing here has a collider: no kart can ever touch or get stuck on it.

## Ground below the racing line (kart models sit 0.15 m below the physics floor).
const GROUND_Y := -0.17
## Spectators stand this far from the racing line (the barrier ends at about 4.2 m).
const FAN_LATERAL := 5.0
const FAN_SPACING := 1.7
const FAN_SCALE := 1.8           ## driver rig scale; 1.0 is a driver sitting in a kart
const MAX_FANS := 14
const GATE_CLEAR := 1.8          ## metres around the start line kept free (gate posts)
const HOP_RANGE := 6.0           ## metres: a human kart this close makes a fan hop
const HOP_COOLDOWN := 1.6
const CHEER_SECONDS := 4.0
## Each prop: id (model `assets/models/props/<id>.glb`, else the photo card
## `assets/props/<id>_front.png`), height in metres, metres after the start line (negative:
## before), side (+1 right of travel, -1 left; 0 = whichever side has room), metres from the
## line, and how far (radians) it turns toward the karts coming up.
## (The old "polizeiwache_turm" card was the station seen end-on: the 3D station has that side.)
const PROPS: Array[Dictionary] = [
	{"id": "polizeiwache", "height": 7.0, "s": 18.0, "side": 1.0, "lateral": 12.5, "turn": 0.85},
	{"id": "duplo_laden", "height": 6.5, "s": 31.0, "side": 1.0, "lateral": 11.0, "turn": 0.6},
]
## Per-track changes, by track id: {prop id: {key: value}}, "fans_s" (metres after the line
## where the fan rows start) or "prop_scale".
## "prop_scale" makes all buildings bigger (in the living room the toys are giants).
const TRACK_TUNING := {
	"wohnzimmer": {"prop_scale": 1.5},
}
## Track scenery props must not stand inside (node names; the fan stand and living-room
## furniture), and groups whose children each count as one obstacle.
const OBSTACLES: Array[String] = ["Crowd", "Sofa", "CoffeeTable", "Bookshelf", "FloorLamp", "Plant", "ToyBox"]
const OBSTACLE_GROUPS: Array[String] = ["Blocks", "GiantToys"]
## If a prop's spot is taken (road, pond, fan stand, another prop), these shifts are tried in
## turn: [metres along the line, metres further out].
const SHIFTS: Array[Vector2] = [Vector2(0, 0), Vector2(6, 0), Vector2(-6, 0), Vector2(0, 4),
	Vector2(12, 0), Vector2(6, 4), Vector2(-6, 4), Vector2(18, 0), Vector2(12, 6), Vector2(24, 2)]

var _track: Track
var _racers: Array[Racer] = []
var _fans: Array[DriverRig] = []
var _fan_wait := PackedFloat32Array()
var _finished := {}             ## Racer -> true once their finish was cheered
var _cheer_left := 0.0
var _time := 0.0
var _taken: Array[Vector3] = []   ## circles on the ground (x, z, radius) props keep out of
var _blocked: Array[Rect2] = []   ## rectangles on the ground (x, z) props keep out of

func _init(track: Track, racers: Array[Racer]) -> void:
	name = "Roadside"
	_track = track
	_racers = racers

func _ready() -> void:
	if _track == null or _track.length <= 0.0:
		return
	if Game.smoke and Game.smoke_args.get("roadside", "1") == "0":
		return  # --roadside=0: without, for comparing frame rates
	var tuning: Dictionary = TRACK_TUNING.get(Game.track.id if Game.track else "", {})
	_collect_keep_out()
	for prop in PROPS:
		var cfg := prop.duplicate()
		cfg.merge(tuning.get(cfg["id"], {}), true)
		cfg["height"] = float(cfg["height"]) * float(tuning.get("prop_scale", 1.0))
		_add_prop(cfg)
	_add_fans(float(tuning.get("fans_s", -4.5)))
	if Game.smoke and Game.smoke_args.has("roadside_view"):
		_look_from_above.call_deferred(int(Game.smoke_args["roadside_view"]))

# --- Props ---------------------------------------------------------------------------------

func _add_prop(cfg: Dictionary) -> void:
	var height: float = cfg["height"]
	var building := _model(String(cfg["id"]), height)
	var half := 0.0
	if building:
		var box := _local_box(building)
		half = maxf(box.size.x, box.size.z) * 0.5
	else:
		building = _card_for(String(cfg["id"]), height)
		if building == null:
			return
		half = float(building.get_meta("half_width"))
	var sides: Array[float] = [1.0, -1.0]
	if float(cfg["side"]) != 0.0:
		sides = [float(cfg["side"]), -float(cfg["side"])]  # the other side if there is no room
	for side in sides:
		for shift in SHIFTS:
			var s := fposmod(float(cfg["s"]) + shift.x, _track.length)
			var spot := _spot(s, side * (float(cfg["lateral"]) + shift.y))
			if not _is_free(spot, half + 1.0):
				continue
			building.name = String(cfg["id"]).to_pascal_case()
			add_child(building)
			building.global_transform = Transform3D(_facing(s, side, float(cfg["turn"])), spot)
			_taken.append(Vector3(spot.x, spot.z, half + 0.5))
			_clear_trees(spot + building.global_basis.z * 2.0, half + 3.0)
			return
	building.free()
	push_warning("Roadside: no room for %s." % cfg["id"])

## Trees (and other scattered copies) standing in or just in front of a building go away,
## so the karts see it.
func _clear_trees(center: Vector3, radius: float) -> void:
	for node in _track.find_children("*", "MultiMeshInstance3D", true, false):
		if node is Scatter:
			(node as Scatter).clear_circle(center, radius)

## The 3D toy building scaled to `height` metres, or null when there is no model.
## The model's origin is the middle of its footprint on the ground; it looks along +Z.
func _model(id: String, height: float) -> Node3D:
	var path := "res://assets/models/props/%s.glb" % id
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	var holder := Node3D.new()
	holder.add_child(model)
	var box := _local_box(holder)
	if box.size.y > 0.0:
		model.scale = Vector3.ONE * (height / box.size.y)
	ToyLook.apply(model, ToyLook.Kind.DRIVER)  # the same soft rim of light as the toys
	return holder

## Bounding box of all meshes under `root`, in root's own space (root is not in the tree yet).
func _local_box(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## Fallback: the two-sided photo card; meta "half_width" is half its width in metres.
func _card_for(id: String, height: float) -> Node3D:
	var front := load("res://assets/props/%s_front.png" % id) as Texture2D
	var back := load("res://assets/props/%s_back.png" % id) as Texture2D
	if front == null:
		return null
	var card := _two_sided_card(front, back if back else front, height)
	card.set_meta("half_width", height * float(front.get_width()) / maxf(1.0, float(front.get_height())) * 0.5)
	return card

## Areas props must keep out of, as rectangles on the ground (x, z): the fan stand, and
## circles (x, z, radius): ponds and props already placed.
func _collect_keep_out() -> void:
	var solid: Array[Node] = []
	for node_name in OBSTACLES:
		solid.append_array(_track.find_children(node_name, "Node3D", true, false))
	for node_name in OBSTACLE_GROUPS:
		for group in _track.find_children(node_name, "Node3D", true, false):
			solid.append_array((group as Node).get_children())
	for node in solid:
		var box := AABB()
		var first := true
		var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
		if node is MeshInstance3D:
			meshes.append(node)
		for mesh in meshes:
			var mi := mesh as MeshInstance3D
			var world := mi.global_transform * mi.get_aabb()
			box = world if first else box.merge(world)
			first = false
		if not first:
			_blocked.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
	for node in get_tree().get_nodes_in_group(Scatter.KEEP_OUT_GROUP):
		var n3 := node as Node3D
		if n3 and n3.get("keep_out_radius") != null:
			_taken.append(Vector3(n3.global_position.x, n3.global_position.z, float(n3.get("keep_out_radius"))))

func _is_free(p: Vector3, radius: float) -> bool:
	if not _clear_of_road(p, radius):
		return false
	var here := Vector2(p.x, p.z)
	for c in _taken:
		if here.distance_to(Vector2(c.x, c.y)) < c.z + radius:
			return false
	for r in _blocked:
		if r.grow(radius).has_point(here):
			return false
	return true

## A position beside the line at s, on the ground.
func _spot(s: float, lateral: float) -> Vector3:
	var p := _track.pos_at(s) + _track.right_at(s) * lateral
	p.y = _track.pos_at(s).y + GROUND_Y
	return p

## Looks at the road from `side`, turned by `turn` toward the karts coming up the line.
func _facing(s: float, side: float, turn: float) -> Basis:
	var to_road := -_track.right_at(s) * side
	var z := to_road.rotated(Vector3.UP, side * turn).normalized()
	if z.dot(_track.tangent_at(s)) > 0.0:
		z = to_road.rotated(Vector3.UP, -side * turn).normalized()
	return Basis.looking_at(-z, Vector3.UP)

## True when no part of the track (any lap position) comes within `radius` of the road edge.
func _clear_of_road(p: Vector3, radius: float) -> bool:
	var limit := _track.half_width + 1.0 + radius
	for i in range(0, _track.count, 2):
		var q := _track.sample_pos(i)
		if Vector2(p.x - q.x, p.z - q.z).length() < limit:
			return false
	for fork in _track.forks:
		var from: float = fork["from"]
		var to: float = fork["to"]
		var s := from
		while s < to:
			var c := Track.fork_offset(fork, s) * float(fork["side"])
			var q := _track.pos_at(s) + _track.right_at(s) * c
			if Vector2(p.x - q.x, p.z - q.z).length() < float(fork["lane"]) + 1.0 + radius:
				return false
			s += 1.0
	return true

func _two_sided_card(front: Texture2D, back: Texture2D, height: float) -> Node3D:
	var holder := Node3D.new()
	holder.add_child(_card(front, height, false))
	holder.add_child(_card(back, height, true))
	return holder

func _card(tex: Texture2D, height: float, is_back: bool) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(height * float(tex.get_width()) / maxf(1.0, float(tex.get_height())), height)
	quad.center_offset = Vector3(0, height * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	# Unshaded like the paper drivers: the toy photo keeps its strong colours.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if is_back:
		mi.rotation.y = PI
	return mi

# --- Spectators ----------------------------------------------------------------------------

func _add_fans(start_s: float) -> void:
	var racing := {}
	for racer in _racers:
		if racer.driver:
			racing[racer.driver.id] = true
	var idle: Array[DriverDef] = []
	for d in Game.drivers:
		if not racing.has(d.id):
			idle.append(d)
	idle = idle.slice(0, MAX_FANS)
	# Two rows, one on each side of the road, beside the start grid and past the line;
	# nobody stands under the gate.
	for k in idle.size():
		var side := 1.0 if k % 2 == 0 else -1.0
		var slot := k >> 1
		var s := start_s + slot * FAN_SPACING
		if s > -GATE_CLEAR:
			s += 2.0 * GATE_CLEAR
		s = fposmod(s, _track.length)
		var rig := DriverRig.new()
		rig.name = "Fan_%s" % idle[k].id
		add_child(rig)
		# Toy vehicles (police car, motorbike) park at their normal size; figures stand taller.
		rig.build(idle[k], 1.0 if idle[k].is_vehicle else FAN_SCALE)
		rig.global_transform = Transform3D(_facing(s, side, 1.1 if idle[k].is_vehicle else 0.35), _spot(s, side * (FAN_LATERAL + 0.35 * (slot % 2))))
		_play_idle(rig)
		_fans.append(rig)
	_fan_wait.resize(_fans.size())

## Models drive by default; a standing fan uses an idle animation if the model has one.
func _play_idle(rig: DriverRig) -> void:
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	for anim in ["idle", "static"]:
		if player.has_animation(anim):
			player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
			player.play(anim)
			return

func _physics_process(delta: float) -> void:
	if _fans.is_empty():
		return
	_time += delta
	var cheer_now := false
	for racer in _racers:
		if racer.is_human and racer.finished and not _finished.has(racer):
			_finished[racer] = true
			cheer_now = true
	if cheer_now:
		_cheer_left = CHEER_SECONDS
		for fan in _fans:
			fan.set_cheering(true)
	elif _cheer_left > 0.0:
		_cheer_left -= delta
		if _cheer_left <= 0.0:
			for fan in _fans:
				fan.set_cheering(false)
	for i in _fans.size():
		var fan := _fans[i]
		_fan_wait[i] = maxf(0.0, _fan_wait[i] - delta)
		if _fan_wait[i] <= 0.0:
			for racer in _racers:
				if racer.is_human and racer.kart.global_position.distance_squared_to(fan.global_position) < HOP_RANGE * HOP_RANGE:
					fan.hop(1.2)
					_fan_wait[i] = HOP_COOLDOWN
					break
		# A gentle sway, each fan at its own pace.
		fan.animate(delta, sin(_time * 1.7 + i * 1.3) * 0.5, 0.6, 0.0)

# --- Looking at it (development) -----------------------------------------------------------

## --roadside_view=0|1|2 (smoke runs): the first player's view shows the start area from above
## instead of the chase camera, for checking where props and fans stand.
func _look_from_above(view: int) -> void:
	var chase := get_tree().root.find_children("*", "ChaseCamera", true, false)
	if chase.is_empty():
		return
	var cam := Camera3D.new()
	(chase[0] as Node).get_parent().add_child(cam)
	var at := _track.pos_at(4.0)
	var back := -_track.tangent_at(0.0)
	var right := _track.right_at(0.0)
	var eye: Vector3 = [at + back * 26.0 + Vector3.UP * 16.0,
		at + right * 24.0 + Vector3.UP * 12.0,
		at - right * 24.0 + Vector3.UP * 12.0][clampi(view, 0, 2)]
	cam.fov = 60.0
	cam.look_at_from_position(eye, at, Vector3.UP)
	cam.current = true
