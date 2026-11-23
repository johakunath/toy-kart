class_name Atmosphere extends Node3D
## Light, sky and weather of a track, built when the track starts. One node per track scene.
## Each look sets: a warm sun with soft shadows, a cool fill light from the other side, a
## gradient sky that also lights the shade, haze for depth, bloom, drifting clouds that
## cast moving shadows, and small things floating in the air near each camera.

enum Look { SUNNY_DAY, GOLDEN_EVENING, LIVING_ROOM }

const LOOKS := {
	Look.SUNNY_DAY: {
		"sky_top": Color(0.14, 0.38, 0.86), "sky_horizon": Color(0.68, 0.84, 0.98),
		"ground": Color(0.32, 0.55, 0.42),
		"sun_elevation": 47.0, "sun_azimuth": 215.0, "sun_color": Color(1.0, 0.95, 0.85), "sun_energy": 1.5,
		"fill_color": Color(0.62, 0.76, 1.0), "fill_energy": 0.28,
		"ambient_energy": 0.8, "ambient_color": Color(0.92, 0.92, 0.96), "ambient_sky": 0.7,
		"fog_color": Color(0.74, 0.86, 0.98), "fog_density": 0.0028, "fog_sun_scatter": 0.12,
		"glow": 0.55, "bloom": 0.05, "saturation": 1.3, "contrast": 1.06, "exposure": 1.0, "agx_contrast": 1.5,
		"volumetric": 0.0,
		"cloud_color": Color(1.0, 1.0, 1.0), "cloud_glow": Color(0.75, 0.82, 0.95), "cloud_count": 16,
		"mote_color": Color(1.0, 0.98, 0.85, 0.75),
		"leaf_colors": [Color(1.0, 0.86, 0.9), Color(1.0, 1.0, 1.0), Color(1.0, 0.7, 0.8), Color(1.0, 0.95, 0.75)],
		"leaf_amount": 26,
	},
	Look.GOLDEN_EVENING: {
		"sky_top": Color(0.2, 0.27, 0.6), "sky_horizon": Color(1.0, 0.68, 0.4),
		"ground": Color(0.4, 0.32, 0.3),
		"sun_elevation": 25.0, "sun_azimuth": 248.0, "sun_color": Color(1.0, 0.76, 0.5), "sun_energy": 2.1,
		"fill_color": Color(0.62, 0.66, 1.0), "fill_energy": 0.55,
		"ambient_energy": 1.25, "ambient_color": Color(1.0, 0.88, 0.84), "ambient_sky": 0.5,
		"fog_color": Color(1.0, 0.78, 0.6), "fog_density": 0.0028, "fog_sun_scatter": 0.4,
		"glow": 0.75, "bloom": 0.08, "saturation": 1.4, "contrast": 1.06, "exposure": 1.25, "agx_contrast": 1.5,
		"volumetric": 0.005,
		"cloud_color": Color(1.0, 0.82, 0.74), "cloud_glow": Color(0.9, 0.5, 0.45), "cloud_count": 12,
		"mote_color": Color(1.0, 0.82, 0.5, 0.8),
		"leaf_colors": [Color(0.95, 0.55, 0.15), Color(0.9, 0.3, 0.12), Color(0.98, 0.78, 0.2), Color(0.6, 0.35, 0.15)],
		"leaf_amount": 44,
	},
	# Indoors: afternoon sun through the window, warm lamp-like fill, dust glittering in the
	# light. No clouds and no leaves; the "sky" is the creamy ceiling seen above the walls.
	Look.LIVING_ROOM: {
		"sky_top": Color(1.0, 0.95, 0.86), "sky_horizon": Color(1.0, 0.9, 0.78),
		"ground": Color(0.6, 0.42, 0.28),
		"sun_elevation": 42.0, "sun_azimuth": 160.0, "sun_color": Color(1.0, 0.9, 0.74), "sun_energy": 1.7,
		"fill_color": Color(1.0, 0.8, 0.62), "fill_energy": 0.45,
		"ambient_energy": 1.0, "ambient_color": Color(1.0, 0.93, 0.86), "ambient_sky": 0.55,
		"fog_color": Color(1.0, 0.9, 0.78), "fog_density": 0.0005, "fog_sun_scatter": 0.25,
		"glow": 0.6, "bloom": 0.06, "saturation": 1.3, "contrast": 1.06, "exposure": 1.05, "agx_contrast": 1.5,
		"volumetric": 0.0,
		"cloud_color": Color(1.0, 1.0, 1.0), "cloud_glow": Color(1.0, 1.0, 1.0), "cloud_count": 0,
		"mote_color": Color(1.0, 0.94, 0.75, 0.9),
		"leaf_colors": [Color(1.0, 1.0, 1.0)],
		"leaf_amount": 0,
	},
}

@export var look := Look.SUNNY_DAY
## Middle and size of the area the track covers; clouds drift across it.
@export var area_center := Vector3.ZERO
@export var area_size := Vector3(140, 0, 110)

var _clouds: Array[Node3D] = []
var _wind := Vector3(1.6, 0.0, 0.7)
var _cfg: Dictionary

func _ready() -> void:
	_cfg = LOOKS[look]
	_build_sky_and_environment()
	_build_lights()
	_build_clouds()

func _process(delta: float) -> void:
	var half := area_size * 0.5 + Vector3(90, 0, 90)
	for cloud in _clouds:
		cloud.position += _wind * delta
		if cloud.position.x > area_center.x + half.x:
			cloud.position.x -= half.x * 2.0
		if cloud.position.z > area_center.z + half.z:
			cloud.position.z -= half.z * 2.0

# --- Sky, haze, bloom ----------------------------------------------------------------------

func _build_sky_and_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = _cfg["sky_top"]
	sky_material.sky_horizon_color = _cfg["sky_horizon"]
	sky_material.sky_curve = 0.11
	sky_material.ground_bottom_color = _cfg["ground"]
	sky_material.ground_horizon_color = _cfg["sky_horizon"]
	sky_material.ground_curve = 0.06
	sky_material.sun_angle_max = 22.0
	sky_material.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# The sky lights the shade: cool shadows next to warm sunlight give the scene depth.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = _cfg["ambient_energy"]
	env.ambient_light_color = _cfg["ambient_color"]
	env.ambient_light_sky_contribution = _cfg["ambient_sky"]
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = _cfg["exposure"]
	env.tonemap_white = 6.0
	# Above Godot's 1.25: deeper colours, less of the washed-out pastel look.
	env.tonemap_agx_contrast = _cfg["agx_contrast"]

	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 3.0
	env.ssao_power = 1.8
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.9

	env.glow_enabled = true
	env.glow_intensity = _cfg["glow"]
	env.glow_bloom = _cfg["bloom"]
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.fog_enabled = true
	env.fog_light_color = _cfg["fog_color"]
	env.fog_density = _cfg["fog_density"]
	env.fog_sun_scatter = _cfg["fog_sun_scatter"]
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.0

	var volumetric: float = _cfg["volumetric"]
	if volumetric > 0.0:
		# Thin mist that shows the low sun as shafts of light between the trees.
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = volumetric
		env.volumetric_fog_albedo = _cfg["fog_color"]
		env.volumetric_fog_anisotropy = 0.65
		env.volumetric_fog_length = 90.0
		env.volumetric_fog_ambient_inject = 0.3

	env.adjustment_enabled = true
	env.adjustment_saturation = _cfg["saturation"]
	env.adjustment_contrast = _cfg["contrast"]

	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	add_child(world_env)

# --- Sun and fill light --------------------------------------------------------------------

func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-float(_cfg["sun_elevation"]), _cfg["sun_azimuth"], 0.0)
	sun.light_color = _cfg["sun_color"]
	sun.light_energy = _cfg["sun_energy"]
	sun.light_angular_distance = 0.9       # soft shadow edges that widen with distance
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.4
	sun.shadow_opacity = 0.92
	sun.shadow_blur = 1.3
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 95.0
	sun.directional_shadow_fade_start = 0.85
	add_child(sun)

	# A weak, cool light from the opposite side lifts the shaded faces without flattening them.
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-32.0, float(_cfg["sun_azimuth"]) + 165.0, 0.0)
	fill.light_color = _cfg["fill_color"]
	fill.light_energy = _cfg["fill_energy"]
	fill.light_specular = 0.0
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)

# --- Clouds --------------------------------------------------------------------------------

func _build_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + look
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 14
	puff.rings = 7
	var material := StandardMaterial3D.new()
	material.albedo_color = _cfg["cloud_color"]
	material.roughness = 1.0
	material.emission_enabled = true
	material.emission = _cfg["cloud_glow"]
	material.emission_energy_multiplier = 0.45
	material.disable_fog = true
	puff.material = material
	var half := area_size * 0.5 + Vector3(90, 0, 90)
	for i in int(_cfg["cloud_count"]):
		var cloud := Node3D.new()
		cloud.name = "Cloud%d" % i
		cloud.position = area_center + Vector3(rng.randf_range(-half.x, half.x), rng.randf_range(34.0, 52.0), rng.randf_range(-half.z, half.z))
		var size := rng.randf_range(0.8, 1.5)
		for k in rng.randi_range(4, 6):
			var blob := MeshInstance3D.new()
			blob.mesh = puff
			blob.position = Vector3((k - 2.5) * 3.6 * size, rng.randf_range(-0.6, 1.2), rng.randf_range(-2.2, 2.2))
			blob.scale = Vector3(rng.randf_range(3.5, 6.0), rng.randf_range(2.0, 3.3), rng.randf_range(3.2, 5.2)) * size
			blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			cloud.add_child(blob)
		add_child(cloud)
		_clouds.append(cloud)

# --- Things floating in the air near a camera ----------------------------------------------

## Returns a node to add under a player's camera: glowing dust in the sunlight, and petals
## (day) or autumn leaves (evening) drifting past. They stay in the world as the camera moves on.
func make_camera_weather() -> Node3D:
	var holder := Node3D.new()
	holder.name = "Weather"
	holder.add_child(_make_motes())
	if int(_cfg["leaf_amount"]) > 0:
		holder.add_child(_make_leaves())
	return holder

func _make_motes() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(9.0, 3.0, 9.0)
	process.direction = Vector3(1, 0.2, 0.4)
	process.spread = 180.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.35
	process.gravity = Vector3(0.12, 0.03, 0.05)
	process.scale_min = 0.03
	process.scale_max = 0.085
	process.color = _cfg["mote_color"]
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.5
	process.turbulence_noise_scale = 3.0
	process.alpha_curve = _fade_curve()

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load("res://assets/fx/dot.png")
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.disable_fog = true
	var quad := QuadMesh.new()
	quad.material = material

	var motes := GPUParticles3D.new()
	motes.name = "Motes"
	motes.amount = 260
	motes.lifetime = 6.0
	motes.preprocess = 6.0
	motes.local_coords = false
	motes.process_material = process
	motes.draw_pass_1 = quad
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.visibility_aabb = AABB(Vector3(-60, -30, -60), Vector3(120, 60, 120))
	motes.position = Vector3(0, -0.5, -9.0)
	return motes

func _make_leaves() -> GPUParticles3D:
	var colors: Array = _cfg["leaf_colors"]
	var ramp := Gradient.new()
	var offsets := PackedFloat32Array()
	var ramp_colors := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / maxf(1.0, colors.size() - 1.0))
		ramp_colors.append(colors[i])
	ramp.offsets = offsets
	ramp.colors = ramp_colors
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(11.0, 2.5, 11.0)
	process.direction = Vector3(1, -0.3, 0.45)
	process.spread = 35.0
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 1.8
	process.gravity = Vector3(0, -0.55, 0)
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -160.0
	process.angular_velocity_max = 160.0
	process.scale_min = 0.16
	process.scale_max = 0.3
	process.color_initial_ramp = ramp_texture
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.8
	process.turbulence_noise_scale = 2.0
	process.alpha_curve = _fade_curve()

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load("res://assets/fx/leaf.png")
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	var quad := QuadMesh.new()
	quad.material = material

	var leaves := GPUParticles3D.new()
	leaves.name = "Leaves"
	leaves.amount = int(_cfg["leaf_amount"])
	leaves.lifetime = 7.0
	leaves.preprocess = 7.0
	leaves.local_coords = false
	leaves.process_material = process
	leaves.draw_pass_1 = quad
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaves.visibility_aabb = AABB(Vector3(-60, -30, -60), Vector3(120, 60, 120))
	leaves.position = Vector3(-3.0, 3.0, -10.0)
	return leaves

func _fade_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture
