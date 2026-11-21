class_name AmbientPlayer
extends Node
## City ambience: one looping bed (traffic hum, wind) with fade in and out, plus occasional random one-shots (far sirens,
## barking dogs, distant booms). Keeps playing while the tree is paused. Mirrors MusicPlayer.
## Runs on its own: add it to a scene, call play_ambient() / stop_ambient().

## Emitted when a one-shot starts (used by tests).
signal one_shot_played(stream: AudioStream)

@export var bed: AudioStream
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var bed_volume_db: float = -17.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var fade_in: float = 3.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var fade_out: float = 1.5
@export_group("One-shots")
## Far sirens, dogs, distant booms: one is chosen at random each time.
@export var one_shots: Array[AudioStream] = []
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var one_shot_volume_db: float = -16.0
## Random pause between two one-shots.
@export_range(1.0, 120.0, 0.5, "suffix:s") var one_shot_min_gap: float = 12.0
@export_range(1.0, 120.0, 0.5, "suffix:s") var one_shot_max_gap: float = 30.0
@export_group("")
@export var muted: bool = false

const SILENT_DB: float = -60.0

var _bed_player: AudioStreamPlayer
var _shot_player: AudioStreamPlayer
var _tween: Tween
var _stopping: bool = false
var _active: bool = false
var _gap_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_bed_player = AudioStreamPlayer.new()
	_bed_player.volume_db = SILENT_DB
	_bed_player.stream = _looping(bed)
	add_child(_bed_player)
	_bed_player.finished.connect(func() -> void:
		if _active and not _stopping:
			_bed_player.play()
	)
	_shot_player = AudioStreamPlayer.new()
	_shot_player.volume_db = one_shot_volume_db
	add_child(_shot_player)
	set_process(false)


func _process(delta: float) -> void:
	_gap_left -= delta
	if _gap_left <= 0.0:
		_gap_left = _next_gap()
		play_one_shot()


## Starts the bed (fading in) and the one-shot timer. Does nothing if it is already running.
func play_ambient() -> void:
	if muted:
		return
	_kill_tween()
	_stopping = false
	_active = true
	if _bed_player.stream != null:
		if not _bed_player.playing:
			_bed_player.volume_db = SILENT_DB
			_bed_player.play()
		_tween = create_tween()
		_tween.tween_property(_bed_player, "volume_db", bed_volume_db, fade_in)
	if _gap_left <= 0.0:
		_gap_left = _next_gap()
	set_process(not one_shots.is_empty())


## Fades out, then stops everything.
func stop_ambient() -> void:
	if not _active:
		return
	_active = false
	_stopping = true
	set_process(false)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_bed_player, "volume_db", SILENT_DB, fade_out)
	_tween.tween_callback(func() -> void:
		_bed_player.stop()
		_shot_player.stop()
	)


func is_playing() -> bool:
	return _active and _bed_player != null and _bed_player.playing


## Plays one random one-shot now (also called by the timer). Returns false when none is available or one is still playing.
func play_one_shot() -> bool:
	if muted or one_shots.is_empty() or _shot_player.playing:
		return false
	var stream: AudioStream = one_shots[_rng.randi() % one_shots.size()]
	_shot_player.stream = stream
	_shot_player.volume_db = one_shot_volume_db
	_shot_player.pitch_scale = _rng.randf_range(0.92, 1.08)
	_shot_player.play()
	one_shot_played.emit(stream)
	return true


func _next_gap() -> float:
	return _rng.randf_range(minf(one_shot_min_gap, one_shot_max_gap), maxf(one_shot_min_gap, one_shot_max_gap))


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
