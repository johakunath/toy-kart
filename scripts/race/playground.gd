class_name Playground extends Node3D
## Things to do in free drive ("Freie Fahrt"), no reading needed (roadmap phase F, #30 and #31):
##   - Rings: each player has a glowing ring in their colour floating over the road ahead.
##     Driving through it chimes, gives a little boost, and the next ring appears further on.
##     Every fifth ring is a party. A kid's ring is wide and in the middle of the road.
##   - The brick jar: everyone's bricks fill one jar together; a full jar is a party for all.
##   - Fang Papa (catch dad): with a kid and a grown-up, the grown-up's kart carries a star.
##     When the kid gets close, dad is caught: his kart spins, the kid gets a boost and a star.
## Nothing here can slow the kid down or take anything from him.

const RING_AHEAD_MIN := 45.0
const RING_AHEAD_MAX := 75.0
const RING_DEPTH := 1.5          ## metres around a ring's spot where driving through it counts
const JAR_ICONS := 5             ## full jars shown as bricks beside the jar (more only count)
const RING_MISSED := 12.0        ## metres past a ring before it moves on ahead
const JAR_SIZE := 25
const CATCH_DISTANCE := 2.6
const CATCH_COOLDOWN := 5.0

var track: Track
var humans: Array[Racer] = []
var huds: Array[PlayerHud] = []

var rings_done := {}             ## player index -> rings passed
var catches := 0
var jars := 0

var _rings := {}                 ## player index -> {"node": Node3D, "s": float}
var _rng := RandomNumberGenerator.new()
var _papa: Racer
var _kid: Racer
var _catch_wait := 0.0
var _star: Sprite3D
var _ui: CanvasLayer
var _jar_fill: ColorRect
var _jar_label: Label
var _jar_count: HBoxContainer
var _catch_label: Label
var _time := 0.0

const CATCH_START := 6.0         ## no catching while both still stand on the start grid

func setup(p_track: Track, p_humans: Array[Racer], p_huds: Array[PlayerHud]) -> void:
	track = p_track
	humans = p_humans
	huds = p_huds
	_rng.seed = 2026
	for racer in humans:
		rings_done[racer.player_index] = 0
		if racer.control_mode == Game.ControlMode.KID and _kid == null:
			_kid = racer
		elif racer.control_mode == Game.ControlMode.FULL and _papa == null:
			_papa = racer
	if _kid == null or _papa == null:
		_papa = null
		_kid = null

func _ready() -> void:
	for racer in humans:
		_place_ring(racer, 30.0)
	if _papa:
		_star = Sprite3D.new()
		_star.texture = UiKit.icon("item_superstar")
		_star.pixel_size = 0.012
		_star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_star.modulate = UiKit.SUN
		_star.no_depth_test = true
		_star.render_priority = 5
		# Only the others see the star: it would sit right in front of Papa's own camera.
		_star.layers = 1 << 15
		add_child(_star)
		_hide_star_from_papa.call_deferred()
	_build_ui()

func _physics_process(delta: float) -> void:
	_time += delta
	for racer in humans:
		_watch_ring(racer)
	_watch_jar()
	if _papa:
		_watch_catch(delta)

# --- Rings ---------------------------------------------------------------------------------

func _place_ring(racer: Racer, ahead: float) -> void:
	var old: Dictionary = _rings.get(racer.player_index, {})
	if not old.is_empty():
		(old["node"] as Node3D).queue_free()
	var s := racer.progress.distance() + ahead
	var kid := racer.control_mode == Game.ControlMode.KID
	var lateral := 0.0 if kid else _rng.randf_range(-1.8, 1.8)
	var radius := 2.7 if kid else 1.9
	var ring := Node3D.new()
	ring.name = "Ring%d" % racer.player_index
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.4
	torus.outer_radius = radius
	torus.rings = 32
	torus.ring_segments = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = racer.color
	mat.emission_enabled = true
	mat.emission = racer.color
	mat.emission_energy_multiplier = 2.2
	mat.roughness = 0.3
	var mesh := MeshInstance3D.new()
	mesh.mesh = torus
	mesh.material_override = mat
	mesh.rotation.x = PI * 0.5  # stand the ring up, facing along the road
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_child(mesh)
	add_child(ring)
	ring.global_transform = track.transform_at(s, lateral, radius + 0.15)
	_rings[racer.player_index] = {"node": ring, "s": s, "lateral": lateral, "radius": radius, "mesh": mesh}

func _watch_ring(racer: Racer) -> void:
	var ring: Dictionary = _rings.get(racer.player_index, {})
	if ring.is_empty():
		return
	var mesh := ring["mesh"] as MeshInstance3D
	mesh.rotation.y = sin(_time * 2.0 + racer.player_index) * 0.15
	mesh.scale = Vector3.ONE * (1.0 + 0.05 * sin(_time * 5.0))
	var gone := racer.progress.distance() - float(ring["s"])
	if gone < -0.5:
		return
	if gone > RING_MISSED:
		_place_ring(racer, _rng.randf_range(RING_AHEAD_MIN, RING_AHEAD_MAX))
		return
	if gone > RING_DEPTH:
		return  # past it without going through: it moves on ahead after RING_MISSED
	# Passing the ring's spot: through it if the kart is inside the ring's circle.
	var node := ring["node"] as Node3D
	var offset := racer.kart.ground_position() - node.global_position
	var r: float = ring["radius"]
	var side := offset.dot(node.global_basis.x)
	if absf(side) < r * 0.95 and absf(offset.y) < r * 2.0:
		_ring_passed(racer)

func _ring_passed(racer: Racer) -> void:
	var count: int = rings_done[racer.player_index] + 1
	rings_done[racer.player_index] = count
	var node := (_rings[racer.player_index] as Dictionary)["node"] as Node3D
	_burst(node.global_position, racer.color)
	racer.kart.boost(0.8, 0.3)
	var chime := AudioStreamPlayer.new()
	chime.stream = load("res://assets/sfx/star.wav")
	chime.pitch_scale = 1.0 + 0.08 * ((count - 1) % 5)
	chime.bus = &"Effects"
	add_child(chime)
	chime.play()
	chime.finished.connect(chime.queue_free)
	var hud := _hud_of(racer)
	if count % 5 == 0:
		UiKit.play(self, "fanfare", -6.0)
		if hud:
			hud.show_message("Super!", 1.6, 140, UiKit.SUN)
	_place_ring(racer, _rng.randf_range(RING_AHEAD_MIN, RING_AHEAD_MAX))

# --- Jar -----------------------------------------------------------------------------------

func _bricks() -> int:
	var total := 0
	for racer in humans:
		total += racer.kart.bricks_picked
	return total

func _watch_jar() -> void:
	var total := _bricks()
	var full := total / JAR_SIZE
	if full > jars:
		jars = full
		UiKit.play(self, "applause", -4.0)
		UiKit.play(self, "fanfare", -4.0)
		for racer in humans:
			var hud := _hud_of(racer)
			if hud:
				hud.show_message("Glas voll!", 2.0, 150, UiKit.SUN)
			_burst(racer.kart.ground_position() + Vector3.UP * 1.5, UiKit.SUN)
		if _jar_count.get_child_count() < JAR_ICONS:  # a long session must not fill the screen
			_jar_count.add_child(UiKit.icon_rect("brick", 44, UiKit.SUN))
	if _jar_fill:
		var part := float(total % JAR_SIZE) / JAR_SIZE
		_jar_fill.anchor_top = 1.0 - part
		_jar_label.text = "%d" % total

# --- Catch Papa ----------------------------------------------------------------------------

func _watch_catch(delta: float) -> void:
	_catch_wait = maxf(_catch_wait - delta, 0.0)
	if _time < CATCH_START:
		_catch_wait = maxf(_catch_wait, 0.01)
	var top := _papa.kart.ground_position() + Vector3.UP * (2.3 + 0.25 * sin(_time * 4.0))
	_star.global_position = top
	_star.visible = _catch_wait <= 0.0
	_star.rotation.z = sin(_time * 3.0) * 0.3
	if _catch_wait > 0.0:
		return
	var near := _kid.kart.ground_position().distance_to(_papa.kart.ground_position()) < CATCH_DISTANCE
	if not near:
		return
	catches += 1
	_catch_wait = CATCH_COOLDOWN
	_papa.kart.wobble()
	_kid.kart.boost(1.0, 0.35)
	_burst(_papa.kart.ground_position() + Vector3.UP * 1.2, UiKit.SUN)
	UiKit.play(self, "fanfare", -5.0)
	var hud := _hud_of(_kid)
	if hud:
		hud.show_message("Gefangen!", 1.8, 150, UiKit.SUN)
	var papa_hud := _hud_of(_papa)
	if papa_hud:
		papa_hud.show_message("Erwischt!", 1.4, 110, Color.WHITE)
	if _catch_label:
		_catch_label.text = "%d" % catches

# --- Look ----------------------------------------------------------------------------------

func _hide_star_from_papa() -> void:
	for node in get_tree().root.find_children("*", "ChaseCamera", true, false):
		var camera := node as ChaseCamera
		if camera.target == _papa.kart:
			camera.cull_mask &= ~(1 << 15)

func _hud_of(racer: Racer) -> PlayerHud:
	var i := humans.find(racer)
	return huds[i] if i >= 0 and i < huds.size() else null

## A short burst of coloured sparkles.
func _burst(where: Vector3, color: Color) -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.emitting = true
	sparks.amount = 40
	sparks.lifetime = 0.9
	sparks.explosiveness = 0.95
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 7.0
	sparks.gravity = Vector3(0, -6.0, 0)
	sparks.scale_amount_min = 0.15
	sparks.scale_amount_max = 0.3
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = load("res://assets/fx/dot.png")
	mat.albedo_color = color.lightened(0.2)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	quad.material = mat
	sparks.mesh = quad
	add_child(sparks)
	sparks.global_position = where
	sparks.finished.connect(sparks.queue_free)

## One panel at the top centre for everybody: the brick jar, and Papa's catches.
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	# Centred at the top, over the line between the two halves.
	var strip := CenterContainer.new()
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_top = 14
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(strip)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.55), 30))
	strip.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	# The jar: a glass that fills with bricks.
	var glass := PanelContainer.new()
	glass.custom_minimum_size = Vector2(56, 74)
	glass.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.25), 14, Color.WHITE, 4))
	glass.clip_contents = true
	_jar_fill = ColorRect.new()
	_jar_fill.color = Color("e8483f")
	_jar_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_jar_fill.anchor_top = 1.0
	_jar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.add_child(_jar_fill)
	glass.add_child(holder)
	row.add_child(glass)
	_jar_label = UiKit.label("0", 48, Color.WHITE, 12, UiKit.INK)
	row.add_child(_jar_label)
	_jar_count = HBoxContainer.new()
	_jar_count.add_theme_constant_override("separation", 2)
	row.add_child(_jar_count)
	if _papa:
		row.add_child(UiKit.icon_rect("item_superstar", 64, UiKit.SUN))
		var face := UiKit.rounded_picture(64, 32)
		if _papa.driver and _papa.driver.portrait:
			(face.get_child(0) as TextureRect).texture = _papa.driver.portrait
		face.add_theme_stylebox_override("panel", UiKit.box(_papa.color, 32))
		row.add_child(face)
		_catch_label = UiKit.label("0", 48, Color.WHITE, 12, UiKit.INK)
		row.add_child(_catch_label)

## For the checks: what happened.
func summary() -> String:
	var parts := []
	for racer in humans:
		parts.append("%s rings=%d" % [racer.display_name, int(rings_done[racer.player_index])])
	return "playground %s jar=%d full_jars=%d catches=%d" % [", ".join(parts), _bricks(), jars, catches]
