class_name Scatter extends MultiMeshInstance3D
## Many copies of one mesh (trees, grass patches), drawn in one go.
## The track builders store only the placements here; the copies are made when the track loads.
## (A MultiMesh built without a window cannot be saved, so it is rebuilt at start instead.)

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
	if mesh == null or placements.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not tints.is_empty()
	multi.mesh = mesh
	multi.instance_count = placements.size()
	for i in placements.size():
		multi.set_instance_transform(i, placements[i])
		if multi.use_colors:
			multi.set_instance_color(i, tints[i % tints.size()])
	multimesh = multi
