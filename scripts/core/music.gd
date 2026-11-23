extends Node
## Autoload "Music": the background music on the "Music" bus, with two players so tunes
## cross-fade. play("menu") / play("race"); hurry() on the last lap fades into the faster
## version of the race tune (Mario Kart style).
## Switched off with Game.music_on (options page). Test runs stay silent.

const TRACKS := {
	"menu": "res://assets/music/menu.wav",
	"race": "res://assets/music/race.wav",
	"race_final": "res://assets/music/race_final.wav",
}
const FADE_SECONDS := 0.8
const SILENT := -40.0

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _tweens: Array[Tween] = [null, null]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps playing in the pause menu
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = SILENT
		add_child(player)
		_players.append(player)

func play(track: String, fade := FADE_SECONDS) -> void:
	if not _allowed():
		stop()
		return
	if track == _current and _players[_active].playing:
		return
	_current = track
	var stream := load(TRACKS[track]) as AudioStream
	if stream is AudioStreamWAV:
		# Loop the whole file, whatever the import settings say.
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	var old := _active
	_active = 1 - _active
	var player := _players[_active]
	player.stream = stream
	player.volume_db = SILENT
	player.play()
	_fade(_active, 0.0, fade)
	if _players[old].playing:
		_fade(old, SILENT, fade, true)

## Last lap: cross-fade into the faster race tune.
func hurry() -> void:
	if _players[_active].playing and _current == "race":
		play("race_final", 1.2)

func stop(seconds := 1.2) -> void:
	_current = ""
	for i in 2:
		if _players[i].playing:
			_fade(i, SILENT, seconds, true)

## Called when the music switch changes.
func refresh(track_if_on: String) -> void:
	if _allowed():
		play(track_if_on)
	else:
		stop(0.3)

func _allowed() -> bool:
	# Test and screenshot runs (save_enabled off) stay silent.
	return Game.music_on and Game.save_enabled

func _fade(index: int, db: float, seconds: float, stop_after := false) -> void:
	if _tweens[index]:
		_tweens[index].kill()
	var tween := create_tween()
	tween.tween_property(_players[index], "volume_db", db, maxf(seconds, 0.01))
	if stop_after:
		tween.tween_callback(_players[index].stop)
	_tweens[index] = tween
