class_name MusicPlayer
extends Node
## Plays one looping background track with fade in and out. Keeps playing while the tree is paused.
## Runs on its own: add it to a scene, call play_music() / stop_music().

@export var stream: AudioStream
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var volume_db: float = -14.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var fade_in: float = 2.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var fade_out: float = 1.5
@export var muted: bool = false

const SILENT_DB: float = -60.0

var _player: AudioStreamPlayer
var _tween: Tween
var _stopping: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_db = SILENT_DB
	add_child(_player)
	_player.stream = _looping(stream)
	# Safety net for streams that cannot loop by themselves.
	_player.finished.connect(func() -> void:
		if not _stopping:
			_player.play()
	)


## Starts the track (fading in). Does nothing if it is already playing.
func play_music() -> void:
	if muted or _player.stream == null:
		return
	_kill_tween()
	_stopping = false
	if not _player.playing:
		_player.volume_db = SILENT_DB
		_player.play()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", volume_db, fade_in)


## Fades out, then stops.
func stop_music() -> void:
	if not _player.playing:
		return
	_kill_tween()
	_stopping = true
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", SILENT_DB, fade_out)
	_tween.tween_callback(_player.stop)


func is_playing() -> bool:
	return _player != null and _player.playing and not _stopping


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


## A loop-enabled copy, so the shared imported resource is never changed.
func _looping(source: AudioStream) -> AudioStream:
	var wav: AudioStreamWAV = source as AudioStreamWAV
	if wav == null:
		return source
	var copy: AudioStreamWAV = wav.duplicate() as AudioStreamWAV
	copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
	copy.loop_begin = 0
	copy.loop_end = roundi(wav.get_length() * wav.mix_rate)
	return copy
