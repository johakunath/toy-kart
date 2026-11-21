class_name KartPreview extends SubViewportContainer
## A small live 3D picture of a kart with its driver, slowly turning.
## Used on the selection screen and on the finish screen. It has its own little 3D world.

var cheering := false
var spin_speed := 0.7

var _viewport: SubViewport
var _visual: KartVisual
var _time := 0.0

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.75
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.1
	_viewport.add_child(sun)

	var camera := Camera3D.new()
	camera.fov = 32.0
	_viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.75, 4.1), Vector3(0, 0.62, 0), Vector3.UP)
	camera.current = true

	_visual = KartVisual.new()
	_visual.rotation.y = 0.6
	_viewport.add_child(_visual)

func show_kart(kart_def: KartDef, driver_def: DriverDef) -> void:
	_visual.build(kart_def, driver_def)
	if _visual.driver:
		_visual.driver.set_cheering(cheering)

func _process(delta: float) -> void:
	_time += delta
	_visual.rotation.y += delta * spin_speed
	if _visual.driver:
		_visual.driver.animate(delta, sin(_time * 1.3) * 0.6, 0.7, 0.0)
