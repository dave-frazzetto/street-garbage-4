class_name SfxCue
extends Resource
## One designer-tunable sound event: which clips to pick from, how loud, how much pitch variation, how often it may fire.

## Clips to choose from at random each time the cue plays (several variants keep repeated sounds from feeling robotic).
@export var streams: Array[AudioStream] = []
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db: float = 0.0
## Random pitch change per play: 0.1 = anywhere from 10% lower to 10% higher.
@export_range(0.0, 0.5, 0.01) var pitch_variance: float = 0.05
## Minimum seconds between two plays of this cue; stops machine guns and shotgun pellets from stacking into noise.
@export_range(0.0, 2.0, 0.01, "suffix:s") var min_interval: float = 0.0


## A random clip, or null when the cue has none.
func pick_stream(rng: RandomNumberGenerator) -> AudioStream:
	if streams.is_empty():
		return null
	return streams[rng.randi() % streams.size()]


## A random pitch multiplier within the variance.
func pick_pitch(rng: RandomNumberGenerator) -> float:
	return 1.0 + rng.randf_range(-pitch_variance, pitch_variance)
