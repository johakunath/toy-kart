class_name CoopHelp extends Node3D
## Co-op help from dad (roadmap phase F, research #29). Only between human players: with one
## player, or with AI karts only, nothing here happens. The race adds one of these.
##
## Magic rope: when another human drives just ahead of a kid-mode player (close along the
## track, about the same lane, both on the road), a glowing rope ties the two karts together
## and the kid's kart gets a gentle pull: a little extra top speed (Kart.tow), never a sideways
## force, so the kid assist keeps steering and the kart can never be yanked into a wall.
## Following dad is worth it, which teaches following. The pull eases off right behind dad.
##
## Gifts: a full-mode player presses the gift button (Intent.gift: D-pad up or down, R, M)
## and his held item flies as a present to the kid-mode player, whose auto-use fires it.
## Only to a kid-mode human who holds no item; dad's HUD shows a hint while that is possible.

const ROPE_CONNECT := 10.0      ## metres along the track: the rope ties on at this gap or closer
const ROPE_BREAK := 13.0        ## ... and lets go beyond this (no flicker at the edge)
const ROPE_MIN_GAP := 1.2       ## closer than this (or the kid ahead) the rope lets go
const ROPE_LATERAL := 4.5       ## metres side to side between the two karts
const TOW_BONUS := 0.12         ## extra top speed at full pull
const FADE_IN := 2.2            ## rope strength per second
const FADE_OUT := 3.0
const CHIME_COOLDOWN := 4.0     ## seconds between two "rope ties on" chimes
const GIFT_FLIGHT_MIN := 0.7    ## seconds a present flies (more when the kid is far away)
const GIFT_FLIGHT_MAX := 1.6
const GIFT_ARC := 2.6           ## metres the present climbs in the middle of its flight
## Smoke test "--coop=1": dad holds this gap ahead of the kid, the pull is switched off in every
## other window of this many seconds to measure what it does, and dad gets an item to give.
const SMOKE_GAP := 5.0
const SMOKE_WINDOW := 8.0
const SMOKE_GIFT_EVERY := 14.0

## One kid-mode player and his rope.
class Link:
	var kid: Racer
	var leader: Racer
	var connected := false
	var strength := 0.0
	var gap := 0.0
	var chime_at := -99.0
	var rope: MagicRope

var _track: Track
var _humans: Array[Racer] = []
var _huds: Array[PlayerHud] = []
var _links: Array[Link] = []
var _presents: Array[Dictionary] = []
var _time := 0.0

# Smoke test bookkeeping.
var _smoke := false
var _smoke_gift_wait := 6.0
var _rope_ticks := 0
var _race_ticks := 0
var _towed_sum := 0.0
var _towed_n := 0
var _free_sum := 0.0
var _free_n := 0
var _gifts_sent := 0
var _gifts_got := 0
var _gifts_used := 0
var _gift_waiting := {}         ## Racer (kid) -> true while he holds a gifted item

func _init(track: Track, humans: Array[Racer], huds: Array[PlayerHud]) -> void:
	name = "CoopHelp"
	_track = track
	_humans = humans
	_huds = huds
	_smoke = Game.smoke and Game.smoke_args.get("coop", "0") == "1"

func _ready() -> void:
	if _humans.size() < 2:
		return
	for racer in _humans:
		if racer.assist.kid:
			var link := Link.new()
			link.kid = racer
			link.rope = MagicRope.new()
			add_child(link.rope)
			_links.append(link)
			racer.kart.item_changed.connect(_on_kid_item_changed.bind(racer))

# --- Rope --------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _links.is_empty():
		return
	_time += delta
	if _smoke:
		_smoke_drive(delta)
	for link in _links:
		_update_link(link, delta)
	for racer in _humans:
		if not racer.assist.kid and racer.kart.intent.gift and not racer.kart.frozen:
			try_gift(racer)

func _update_link(link: Link, delta: float) -> void:
	var kid := link.kid
	var best: Racer = null
	var best_gap := INF
	if _on_road(kid):
		for other in _humans:
			if other == kid or not _on_road(other):
				continue
			var gap := other.progress.distance() - kid.progress.distance()
			var limit := ROPE_BREAK if link.connected and other == link.leader else ROPE_CONNECT
			var side := absf(other.progress.lateral - kid.progress.lateral)
			if gap > ROPE_MIN_GAP and gap < limit and side < ROPE_LATERAL and gap < best_gap:
				best = other
				best_gap = gap
	if best != null:
		if not link.connected and _time - link.chime_at > CHIME_COOLDOWN:
			link.chime_at = _time
			UiKit.play(self, "magic_rope", -7.0)
			kid.kart.rumble_requested.emit(0.25, 0.0, 0.12)
		link.leader = best
		link.gap = best_gap
	link.connected = best != null
	link.strength = move_toward(link.strength, 1.0 if link.connected else 0.0, delta * (FADE_IN if link.connected else FADE_OUT))
	# The pull fades with the rope and eases off right behind dad, so the kid never rams him.
	var close := clampf((link.gap - ROPE_MIN_GAP - 1.0) / 3.0, 0.0, 1.0)
	var tow := TOW_BONUS * link.strength * close
	if _smoke and _smoke_tow_off():
		tow = 0.0
	kid.kart.tow = tow if not kid.finished else 0.0
	if _smoke and kid.kart.frozen == false and not kid.finished:
		_smoke_sample(link)

## Racing, on the road (inside the lane's walls), not finished.
func _on_road(racer: Racer) -> bool:
	if racer.finished or racer.kart.frozen:
		return false
	var band := _track.corridor(racer.progress.s(), racer.progress.lateral)
	return racer.progress.lateral > band.x - 0.5 and racer.progress.lateral < band.y + 0.5

func _process(delta: float) -> void:
	for link in _links:
		if link.leader == null or link.strength <= 0.0:
			link.rope.draw_rope(Vector3.ZERO, Vector3.ZERO, 0.0, delta)
			continue
		var tail := link.leader.kart.container.get_global_transform_interpolated()
		var nose := link.kid.kart.container.get_global_transform_interpolated()
		var from := tail.origin + tail.basis.y * 0.55 - tail.basis.z * 0.75
		var to := nose.origin + nose.basis.y * 0.55 + nose.basis.z * 0.8
		link.rope.draw_rope(from, to, link.strength, delta)
	_fly_presents(delta)
	_update_hints(delta)

# --- Gifts -------------------------------------------------------------------------------

## The kid-mode player a full-mode player can give his item to right now, or null.
func gift_target(giver: Racer) -> Racer:
	if giver.assist.kid or giver.finished or not giver.kart.has_item:
		return null
	var best: Racer = null
	var best_d := INF
	for other in _humans:
		if other == giver or not other.assist.kid or other.finished or other.kart.has_item:
			continue
		if _present_for(other):
			continue
		var d := absf(other.progress.distance() - giver.progress.distance())
		if d < best_d:
			best_d = d
			best = other
	return best

## Sends the giver's item to the kid as a flying present. False when nobody can take it.
func try_gift(giver: Racer) -> bool:
	var kid := gift_target(giver)
	if kid == null:
		return false
	var item := giver.kart.take_item()
	if item == Items.NONE:
		return false
	_launch_present(giver, kid, item)
	return true

func _present_for(kid: Racer) -> bool:
	for p in _presents:
		if p["kid"] == kid:
			return true
	return false

func _launch_present(giver: Racer, kid: Racer, item: int) -> void:
	var present := _make_present()
	add_child(present)
	var from := giver.kart.ground_position() + Vector3(0, 1.3, 0)
	present.global_position = from
	var dist := from.distance_to(kid.kart.ground_position())
	var flight := clampf(GIFT_FLIGHT_MIN + dist / 40.0, GIFT_FLIGHT_MIN, GIFT_FLIGHT_MAX)
	_presents.append({"node": present, "from": from, "giver": giver, "kid": kid, "item": item,
		"t": 0.0, "flight": flight})
	_gifts_sent += 1
	UiKit.play(self, "gift", -4.0)
	giver.kart.rumble_requested.emit(0.3, 0.2, 0.1)
	if giver.kart.visual.driver:
		giver.kart.visual.driver.hop(0.8)

func _fly_presents(delta: float) -> void:
	for i in range(_presents.size() - 1, -1, -1):
		var p: Dictionary = _presents[i]
		var node: Node3D = p["node"]
		var kid: Racer = p["kid"]
		p["t"] = float(p["t"]) + delta / float(p["flight"])
		var t: float = minf(p["t"], 1.0)
		var to := kid.kart.ground_position() + Vector3(0, 1.0, 0)
		var eased := t * t * (3.0 - 2.0 * t)
		var pos := (p["from"] as Vector3).lerp(to, eased)
		pos.y += sin(t * PI) * GIFT_ARC
		node.global_position = pos
		node.rotation = Vector3(sin(t * 9.0) * 0.4, t * TAU * 1.5, 0.0)
		var grow := minf(t * 6.0, 1.0)
		var shrink := 1.0 - clampf((t - 0.85) / 0.15, 0.0, 1.0) * 0.6
		node.scale = Vector3.ONE * grow * shrink
		if float(p["t"]) >= 1.0:
			_deliver(p)
			node.queue_free()
			_presents.remove_at(i)

func _deliver(p: Dictionary) -> void:
	var kid: Racer = p["kid"]
	var giver: Racer = p["giver"]
	var item: int = p["item"]
	if not kid.finished and kid.kart.receive_item(item):
		_gifts_got += 1
		_gift_waiting[kid] = true
		UiKit.play(self, "star", -6.0)
		kid.kart.rumble_requested.emit(0.4, 0.2, 0.15)
		if kid.kart.visual.driver:
			kid.kart.visual.driver.hop(1.2)
	elif not giver.finished:
		# His hands were full after all (he drove through a star): the present goes back.
		giver.kart.receive_item(item)

func _on_kid_item_changed(item: int, kid: Racer) -> void:
	if item == Items.NONE and _gift_waiting.has(kid):
		_gift_waiting.erase(kid)
		_gifts_used += 1

## A present box: red with a yellow ribbon and bow, glowing a little, sparkles behind it.
func _make_present() -> Node3D:
	var root := Node3D.new()
	root.name = "Present"
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.95, 0.15, 0.2)
	red.roughness = 0.35
	red.emission_enabled = true
	red.emission = Color(0.9, 0.1, 0.2)
	red.emission_energy_multiplier = 0.5
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.15)
	gold.roughness = 0.3
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.75, 0.1)
	gold.emission_energy_multiplier = 0.8
	var parts := [
		[Vector3(0.6, 0.5, 0.6), Vector3.ZERO, red],
		[Vector3(0.62, 0.52, 0.16), Vector3.ZERO, gold],
		[Vector3(0.16, 0.52, 0.62), Vector3.ZERO, gold],
	]
	for part: Array in parts:
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		mesh.material = part[2]
		var box := MeshInstance3D.new()
		box.mesh = mesh
		box.position = part[1]
		root.add_child(box)
	for side in [-1.0, 1.0]:
		var bow := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.06
		torus.outer_radius = 0.16
		torus.material = gold
		bow.mesh = torus
		bow.position = Vector3(0.12 * side, 0.36, 0.0)
		bow.rotation = Vector3(0.0, 0.0, PI * 0.5 + 0.5 * side)
		root.add_child(bow)
	var trail := GPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 0.5
	trail.local_coords = false
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 180.0
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 1.0
	process.gravity = Vector3(0, -1.0, 0)
	process.scale_min = 0.4
	process.scale_max = 0.8
	process.color = Color(1.0, 0.85, 0.4) * 2.0
	trail.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = load("res://assets/fx/sparkle.png")
	quad.material = mat
	trail.draw_pass_1 = quad
	root.add_child(trail)
	return root

func _update_hints(delta: float) -> void:
	for i in mini(_humans.size(), _huds.size()):
		var racer := _humans[i]
		if racer.assist.kid:
			continue
		var can := not racer.kart.frozen and gift_target(racer) != null
		_huds[i].show_gift_hint(can, racer.source, delta)

# --- Smoke test (tools/check.ps1, "--coop=1") ---------------------------------------------

## Dad (the full-mode test driver) holds a spot just ahead of the kid and gets items to give.
func _smoke_drive(delta: float) -> void:
	var kid: Racer = _links[0].kid
	for racer in _humans:
		if racer.assist.kid or racer.finished:
			continue
		var gap := racer.progress.distance() - kid.progress.distance()
		var want := clampf(1.0 + (SMOKE_GAP - gap) * 0.1, 0.5, 1.4)
		racer.kart.pace = lerpf(racer.kart.pace, want, minf(1.0, delta * 4.0))
		if racer.kart.frozen:
			continue
		_smoke_gift_wait -= delta
		if _smoke_gift_wait <= 0.0 and not racer.kart.has_item:
			_smoke_gift_wait = SMOKE_GIFT_EVERY
			racer.kart.give_item()
		if racer.kart.has_item and not Game.smoke_args.has("coop_hold"):
			try_gift(racer)  # stands in for dad pressing the gift button ("--coop_hold=1": he keeps it)

func _smoke_tow_off() -> bool:
	return int(_time / SMOKE_WINDOW) % 2 == 1

func _smoke_sample(link: Link) -> void:
	_race_ticks += 1
	if link.strength > 0.0:
		_rope_ticks += 1
	# Skip the start of each window (the kart needs a moment to change speed) and boosts.
	if fmod(_time, SMOKE_WINDOW) < 2.0 or link.strength < 0.95 or link.kid.kart.is_boosting():
		return
	var ratio := link.kid.kart.speed() / maxf(link.kid.kart.top_speed(), 0.1)
	if _smoke_tow_off():
		_free_sum += ratio
		_free_n += 1
	else:
		_towed_sum += ratio
		_towed_n += 1

## Prints the co-op line of the smoke test; false when the rope or the gifts did not work.
func smoke_report() -> bool:
	if not _smoke:
		return true
	var rope_share := float(_rope_ticks) / maxf(_race_ticks, 1.0)
	var towed := _towed_sum / maxf(_towed_n, 1.0)
	var free := _free_sum / maxf(_free_n, 1.0)
	print("SMOKE COOP rope=%.0f%% kid_speed_towed=%.3f kid_speed_without_pull=%.3f gain=%+.1f%% gifts_sent=%d gifts_arrived=%d gifts_used=%d" % [
		100.0 * rope_share, towed, free, 100.0 * (towed / maxf(free, 0.01) - 1.0), _gifts_sent, _gifts_got, _gifts_used])
	# The speed gain is printed but not required: the catch-up help already keeps the kid close,
	# so the measured gain swings between about 0 and +12 % from run to run. Required: the rope
	# connects, it never slows him down, and the gifts arrive.
	var ok := rope_share > 0.4 and _towed_n > 100 and _free_n > 100 and towed > free * 0.97 \
		and _gifts_got >= 1 and _gifts_used >= 1  # a gift flies back when the kid already has an item
	if not ok:
		print("SMOKE   co-op help did not work (rope, pull or gifts)")
	return ok
