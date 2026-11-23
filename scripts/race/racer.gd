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
## Times this racer drove through a side lane (the checks report it).
var side_lanes := 0
var _in_side_lane := false
var _lap_started_at := 0.0

## Reads the driver, applies the assists, hands the result to the kart.
func tick(track: Track, racing: bool, delta: float) -> void:
	progress.update(kart.ground_position(), kart.forward())
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
