class_name ToyLook extends RefCounted
## Makes karts and drivers read like shiny toys: a soft rim of light around the edges (the
## Nintendo look comes from rim light and bloom, not outlines) and a clear-coat shine on karts.
## Materials are copied once per original and shared, so many karts cost no extra materials.

enum Kind { KART, DRIVER }

static var _cache := {}

static func apply(root: Node, kind: Kind) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.material_override != null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var original := mesh_instance.get_active_material(i) as BaseMaterial3D
			if original == null or original.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				continue
			mesh_instance.set_surface_override_material(i, _shiny(original, kind))

static func _shiny(original: BaseMaterial3D, kind: Kind) -> BaseMaterial3D:
	var key := "%d:%d" % [original.get_instance_id(), kind]
	if _cache.has(key):
		return _cache[key]
	var mat := original.duplicate() as BaseMaterial3D
	mat.rim_enabled = true
	mat.rim_tint = 0.85  # rim in the material colour, not white: no pastel
	if kind == Kind.KART:
		mat.rim = 0.25
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.5
		mat.clearcoat_roughness = 0.25
		mat.roughness = minf(mat.roughness, 0.55)
	else:
		mat.rim = 0.4  # plush and figures: a soft glowing edge, no shine
	_cache[key] = mat
	return mat
