class_name MenuBackdrop extends Control
## Behind the menu: a slow flight over the race tracks, one after the other, with a few toy
## karts driving along. Softly blurred and tinted sky blue so the cards stay easy to read.
## Kept light: rendered at a fraction of the screen size, MSAA off, small shadow map, and the
## karts are only pictures moved along the racing line (no physics, no AI).
## Not built in headless runs (menu check) or with "-- --backdrop=0" (frame-rate comparisons).

const HOLD := 12.0           ## seconds on one track
const FADE := 0.9            ## seconds for the soft fade between tracks
const RENDER_SCALE := 0.4    ## of 1920 x 1080
const KART_COUNT := 3
const KART_SPEED := 8.5      ## metres per second along the racing line
const CAM_BEHIND := 7.0
const CAM_HEIGHT := 3.6
const CAM_SIDE := 1.2
const LOOK_AHEAD := 14.0

const BLUR_SHADER := """
shader_type canvas_item;
uniform float radius = 1.2;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * radius;
	vec4 c = texture(TEXTURE, UV) * 0.25;
	c += (texture(TEXTURE, UV + vec2(px.x, 0.0)) + texture(TEXTURE, UV - vec2(px.x, 0.0))
		+ texture(TEXTURE, UV + vec2(0.0, px.y)) + texture(TEXTURE, UV - vec2(0.0, px.y))) * 0.125;
	c += (texture(TEXTURE, UV + px) + texture(TEXTURE, UV - px)
		+ texture(TEXTURE, UV + vec2(px.x, -px.y)) + texture(TEXTURE, UV + vec2(-px.x, px.y))) * 0.0625;
	COLOR = vec4(c.rgb, 1.0);
}
"""

var _viewport: SubViewport
var _camera: Camera3D
var _fade: TextureRect
var _track: Track
var _order: Array[TrackDef] = []
var _shown := -1             ## index in _order of the track on screen
var _time := 0.0
var _switching := false
## Tracks are loaded and built on a worker thread while another one is shown, and kept:
## coming round again costs nothing. Only a track's first _ready runs on the main thread,
## hidden under the fade.
var _cache := {}             ## scene path -> Track (not in the tree unless shown)
var _loading := ""           ## scene path being loaded / built
var _task := -1
var _built: Track
var _karts: Array[KartVisual] = []
var _kart_s: Array[float] = []
var _kart_speed: Array[float] = []
var _kart_lane: Array[float] = []
var _eye := Vector3.ZERO
var _look := Vector3.ZERO

## True when the menu should show the flyover (a real window, not switched off).
static func wanted() -> bool:
	return DisplayServer.get_name() != "headless" and Game.smoke_args.get("backdrop", "1") != "0" \
		and not Game.tracks.is_empty()

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	# Camera and karts move every drawn frame, not in physics steps.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(roundi(1920 * RENDER_SCALE), roundi(1080 * RENDER_SCALE))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.audio_listener_enable_3d = false
	_viewport.positional_shadow_atlas_size = 512
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 500.0
	_viewport.add_child(_camera)
	_camera.current = true

	var picture := TextureRect.new()
	picture.texture = _viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = BLUR_SHADER
	var blur := ShaderMaterial.new()
	blur.shader = shader
	picture.material = blur
	add_child(picture)

	# The menu's own sky gradient laid thinly over the picture: calmer, and the UI stays readable.
	var tint := UiKit.background()
	tint.modulate.a = 0.38
	add_child(tint)
	add_child(_vignette())

	# Covers the picture between tracks (and until the first one is ready): the plain menu sky.
	_fade = UiKit.background()
	add_child(_fade)

	# Start on the track the family picked last, then the others in turn.
	_order.assign(Game.tracks)
	_shown = maxi(_order.find(Game.track), 0) - 1
	_prepare(_upcoming())

## Darker edges pull the eye to the middle, like a console menu.
static func _vignette() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UiKit.INK, 0.0))
	gradient.set_color(1, Color(UiKit.INK, 0.42))
	gradient.add_point(0.55, Color(UiKit.INK, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	return rect

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _built != null:
			_built.free()
			_built = null
	for path: String in _cache:
		var track := _cache[path] as Track
		if is_instance_valid(track) and not track.is_inside_tree():
			track.free()
	_cache.clear()

func _process(delta: float) -> void:
	_poll_loading()
	if _track == null:
		if _cache.has(_order[_upcoming()].scene_path):
			_show_next()
		return
	_time += delta
	_drive(delta)
	_fly(delta, false)
	var next_ready := _cache.has(_order[_upcoming()].scene_path)
	if _order.size() > 1 and not _switching and _time > HOLD - FADE and next_ready:
		_switching = true
		var tween := create_tween()
		tween.tween_property(_fade, "modulate:a", 1.0, FADE)
		tween.tween_callback(_show_next)

func _upcoming() -> int:
	return (_shown + 1) % _order.size()

## Starts loading a track in the background (unless it is built already).
func _prepare(index: int) -> void:
	var path := _order[index].scene_path
	if _cache.has(path) or _loading != "":
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_loading = path

func _poll_loading() -> void:
	if _loading == "":
		return
	if _task < 0:
		var status := ResourceLoader.load_threaded_get_status(_loading)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		var packed := ResourceLoader.load_threaded_get(_loading) as PackedScene
		if packed == null:
			_loading = ""
			return
		# Building the nodes is allowed off the main thread as long as they are not in the tree.
		_task = WorkerThreadPool.add_task(func() -> void: _built = packed.instantiate() as Track)
	elif WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _built != null:
			_cache[_loading] = _built
		_built = null
		_loading = ""

## Swaps in the next track under the full fade, then fades back in.
func _show_next() -> void:
	_shown = _upcoming()
	var track := _cache.get(_order[_shown].scene_path) as Track
	if track == null:
		return
	if _track != null:
		_viewport.remove_child(_track)
	_track = track
	var first_time := not _track.is_node_ready()
	_viewport.add_child(_track)
	if first_time:
		_lighten(_track)
	if _karts.is_empty():
		_add_karts()
	_place_karts()
	_fly(0.0, true)
	_time = 0.0
	_switching = false
	_fade.modulate.a = 1.0
	create_tween().tween_property(_fade, "modulate:a", 0.0, FADE)
	# Load and build the next track in the background while this one is shown.
	if _order.size() > 1:
		_prepare(_upcoming())

## Cheaper light for a background picture: one shadow split, shorter shadow distance.
func _lighten(root: Node) -> void:
	for node in root.find_children("*", "DirectionalLight3D", true, false):
		var sun := node as DirectionalLight3D
		if sun.shadow_enabled:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 60.0

## Three toy karts with drivers, built once and moved to each new track.
func _add_karts() -> void:
	var drivers: Array[DriverDef] = []
	drivers.assign(Game.drivers.filter(func(d: DriverDef) -> bool: return not d.is_vehicle))
	drivers.shuffle()
	var karts: Array[KartDef] = []
	karts.assign(Game.karts.filter(func(k: KartDef) -> bool: return k.ai_can_use))
	if karts.is_empty():
		karts.assign(Game.karts)
	karts.shuffle()
	if drivers.is_empty() or karts.is_empty():
		return
	for i in KART_COUNT:
		var visual := KartVisual.new()
		_viewport.add_child(visual)
		visual.build(karts[i % karts.size()], drivers[i % drivers.size()])
		_karts.append(visual)
		_kart_speed.append(KART_SPEED * (1.0 - i * 0.035))
		_kart_lane.append([0.0, -1.4, 1.5][i % 3])

## Puts the karts at a random place of the shown track: the camera follows kart 0, the others
## are a little ahead in other lanes.
func _place_karts() -> void:
	_kart_s.clear()
	var start := randf() * _track.length
	for i in _karts.size():
		_kart_s.append(start + i * 7.0)
	_drive(0.0)

func _drive(delta: float) -> void:
	for i in _karts.size():
		_kart_s[i] += _kart_speed[i] * delta
		var s := _kart_s[i]
		var here := _track.pos_at(s)
		var ahead := _track.pos_at(s + 1.5)
		var forward := ahead - here
		if forward.length_squared() < 0.0001:
			continue
		forward = forward.normalized()
		var right := forward.cross(Vector3.UP).normalized()
		var up := right.cross(forward).normalized()
		var basis := Basis(-right, up, forward)
		var visual := _karts[i]
		var lane := _kart_lane[i] * _track.half_width / 3.4
		visual.global_transform = Transform3D(basis, here + right * lane)
		if visual.driver:
			visual.driver.animate(delta, clampf(_track.curvature_at(s) * 6.0, -1.0, 1.0), 0.8, 0.0)
		for wheel in visual.wheels:
			wheel.rotation.x += _kart_speed[i] * delta * 2.5 * visual.wheel_spin_sign

## A drone a little behind and above the first kart, looking down the road ahead of it.
func _fly(delta: float, snap: bool) -> void:
	var s := _kart_s[0] if not _kart_s.is_empty() else _time * KART_SPEED
	var eye := _track.pos_at(s - CAM_BEHIND) + _track.right_at(s - CAM_BEHIND) * CAM_SIDE + Vector3.UP * CAM_HEIGHT
	var look := _track.pos_at(s + LOOK_AHEAD) + Vector3.UP * 2.0
	if snap:
		_eye = eye
		_look = look
	else:
		# The eye stays close behind the kart; the view turns a little later, like a calm drone.
		_eye = _eye.lerp(eye, 1.0 - exp(-delta * 6.0))
		_look = _look.lerp(look, 1.0 - exp(-delta * 2.5))
	if _eye.distance_squared_to(_look) > 0.01:
		_camera.look_at_from_position(_eye, _look, Vector3.UP)
