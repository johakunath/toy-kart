class_name Scatter extends MultiMeshInstance3D
## Many copies of one mesh (trees, grass patches), drawn in one go.
## The track builders store only the placements here; the copies are made when the track loads.
## (A MultiMesh built without a window cannot be saved, so it is rebuilt at start instead.)

## Sibling nodes in this group (ponds) keep copies away: none closer than their `keep_out_radius`.
const KEEP_OUT_GROUP := &"scatter_keep_out"

## A model file whose first mesh is used ...
@export var source_scene: PackedScene
## ... or a mesh given directly.
@export var source_mesh: Mesh
## One transform per copy.
@export var placements: Array[Transform3D] = []
## Optional colour per copy (the mesh material must use vertex colours).
@export var tints := PackedColorArray()

func _ready() -> void:
	var mesh := source_mesh
	if mesh == null and source_scene:
		var inst := source_scene.instantiate()
		var found := inst.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			mesh = (found[0] as MeshInstance3D).mesh
		inst.free()
	var keep := _free_copies()
	if mesh == null or keep.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not tints.is_empty()
	multi.mesh = mesh
	multi.instance_count = keep.size()
	for j in keep.size():
		var i := keep[j]
		multi.set_instance_transform(j, placements[i])
		if multi.use_colors:
			multi.set_instance_color(j, tints[i % tints.size()])
	multimesh = multi

## Indices of the placements that no keep-out sibling covers.
func _free_copies() -> PackedInt32Array:
	var blockers: Array[Node3D] = []
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(KEEP_OUT_GROUP):
			if node is Node3D and node.get_parent() == get_parent():
				blockers.append(node as Node3D)
	var keep := PackedInt32Array()
	for i in placements.size():
		var p := transform * placements[i].origin
		var free := true
		for b in blockers:
			var r: float = b.get("keep_out_radius")
			if Vector2(p.x - b.position.x, p.z - b.position.z).length() < r:
				free = false
				break
		if free:
			keep.append(i)
	return keep
