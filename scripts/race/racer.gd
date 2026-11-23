class_name Racer extends RefCounted
## One participant of a race: a kart plus whoever drives it (device or AI),
## the assist layer in between, and the race bookkeeping.

var kart: Kart
var source: InputSource
var assist := Assist.new()
var progress: TrackProgress

var is_human := false
var player_index := -1          ## 0 or 1 for humans, -1 for AI
var ai_number := 0              ## 0, 1, 2 for AI karts
var control_mode := Game.ControlMode.FULL
var color := Color.WHITE
var display_name := ""
var driver: DriverDef
var kart_def: KartDef

var place := 1
var finished := false
var finish_time := 0.0
var lap_times: Array[float] = []
## Who this racer is across the races of a cup: the player, or the computer driver's number.
func cup_key() -> String:
	return "p%d" % player_index if is_human else "ai%d" % ai_number

## Times this racer drove through a side lane (the checks report it).
var side_lanes := 0
var _in_side_lane := false
var _lap_started_at := 0.0
var _last_s := 0.0

## Reads the driver, applies the assists, hands the result to the kart.
func tick(track: Track, racing: bool, delta: float) -> void:
	progress.update(kart.ground_position(), kart.forward())
	# Over a jump ramp's lip: the kart takes off.
	var s := progress.s()
	if racing:
		for lip in track.jump_lips:
			var ahead := fposmod(s - lip + 0.3, track.length)
			var before := fposmod(_last_s - lip + 0.3, track.length)
			if ahead < 3.0 and before > track.length - 3.0:
				kart.ramp_launch()
		if kart.in_ramp_air():
			# Fly along the road, drifting back toward it when near a wall.
			var safe := track.half_width - 1.8
			var s_ahead := s + kart.speed() * 0.25
			var back := clampf(clampf(progress.lateral, -safe, safe) - progress.lateral, -1.0, 1.0) * 0.3
			kart.ramp_guide((track.tangent_at(s_ahead) + track.right_at(s_ahead) * back).normalized(), delta)
	_last_s = s
	var raw := source.read(control_mode)
	var final := assist.apply(raw, self, track, racing, delta)
	kart.intent.copy_from(final)

## Laps of this race, set by the race (kept here so test tools can load this script
## before the Game autoload exists).
var laps := 3

## Lap shown to the player: 1 on the first lap.
func display_lap() -> int:
	return clampi(progress.lap + 1, 1, laps)

func note_lap(race_time: float) -> void:
	lap_times.append(race_time - _lap_started_at)
	_lap_started_at = race_time
