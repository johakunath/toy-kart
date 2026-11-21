extends Node
## Autoload "Music": one player for the background music, on the "Music" bus.
## play("menu") / play("race") cross-fade; the race tune speeds up a little on the last lap.
## Switched off with Game.music_on (options page). Test runs stay silent.

const TRACKS := {
	"menu": "res://assets/music/menu.wav",
	"race": "res://assets/music/race.wav",
}
const FADE_SECONDS := 0.8

var _player: AudioStreamPlayer
var _current := ""
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps playing in the pause menu
	_player = AudioStreamPlayer.new()
	_player.bus = &"Music"
	add_child(_player)

func play(track: String) -> void:
	if not _allowed():
		stop()
		return
	if track == _current and _player.playing:
		return
	_current = track
	var stream := load(TRACKS[track]) as AudioStream
	if stream is AudioStreamWAV:
		# Loop the whole file, whatever the import settings say.
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_fade_to(-40.0, 0.25 if _player.playing else 0.0)
	await get_tree().create_timer(0.25 if _player.playing else 0.0).timeout
	_player.stream = stream
	_player.pitch_scale = 1.0
	_player.volume_db = -40.0
	_player.play()
	_fade_to(0.0, FADE_SECONDS)

## Last lap: a touch faster and higher, like in the big kart games.
func hurry() -> void:
	if _player.playing:
		create_tween().tween_property(_player, "pitch_scale", 1.08, 1.0)

func stop(seconds := 1.2) -> void:
	_current = ""
	if not _player.playing:
		return
	_fade_to(-40.0, seconds)
	_tween.tween_callback(_player.stop)

## Called when the music switch changes.
func refresh(track_if_on: String) -> void:
	if _allowed():
		play(track_if_on)
	else:
		stop(0.3)

func _allowed() -> bool:
	# Test and screenshot runs (save_enabled off) stay silent.
	return Game.music_on and Game.save_enabled

func _fade_to(db: float, seconds: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", db, maxf(seconds, 0.01))
