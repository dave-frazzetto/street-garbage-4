class_name SfxPlayer
extends Node
## Plays SfxCues through a small pool of voices. Non-positional: the isometric camera is far from the action, so
## sounds are mixed flat. Keeps playing while the tree is paused (perk screen, end screen).
## Runs on its own: call play_cue() with any cue. GameFlow listens to world and rules events and calls it.

## Emitted whenever a cue actually starts (not when it is rate-limited or empty). Used by tests.
signal cue_played(cue: SfxCue)

@export var bank: SfxBank
## Simultaneous sounds; extra requests are dropped rather than cutting a sound that is playing.
@export_range(1, 64) var voices: int = 16
## Overall SFX level in dB, on top of each cue's own volume.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var master_db: float = 0.0
@export var muted: bool = false

var _pool: Array[AudioStreamPlayer] = []
## Game-time seconds, advanced in _process (keeps the rate limit consistent with timers and pauses).
var _clock: float = 0.0
var _last_played: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i: int in voices:
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(voice)
		_pool.append(voice)


func _process(delta: float) -> void:
	_clock += delta


## Play a cue. Returns true if it started; false when muted, empty, rate-limited or all voices are busy.
func play_cue(cue: SfxCue) -> bool:
	if cue == null or muted:
		return false
	var stream: AudioStream = cue.pick_stream(_rng)
	if stream == null:
		return false
	if cue.min_interval > 0.0 and _last_played.has(cue) and _clock - float(_last_played[cue]) < cue.min_interval:
		return false
	var voice: AudioStreamPlayer = _free_voice()
	if voice == null:
		return false
	_last_played[cue] = _clock
	voice.stream = stream
	voice.volume_db = cue.volume_db + master_db
	voice.pitch_scale = cue.pick_pitch(_rng)
	voice.play()
	cue_played.emit(cue)
	return true


## Seeds the pitch/variant randomness (tests).
func seed_rng(value: int) -> void:
	_rng.seed = value


func _free_voice() -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in _pool:
		if not voice.playing:
			return voice
	return null
