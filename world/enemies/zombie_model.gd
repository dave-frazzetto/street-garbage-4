class_name ZombieModel
extends CharacterModel
## Visual of a zombie: walk, run, attack and death on top of the shared character model.

signal attack_finished

## Walking speed in m/s at which the walk clip plays at normal speed.
@export_range(0.2, 6.0, 0.05) var walk_reference_speed: float = 1.1
@export_range(0.5, 3.0, 0.05) var max_playback_scale: float = 2.5
## Normal speed of the attack clip.
@export_range(0.5, 3.0, 0.05) var attack_playback_scale: float = 1.6

var _dead: bool = false
var _attacking: bool = false


func _ready() -> void:
	super._ready()
	clip_finished.connect(_on_clip_finished)
	play(&"walk", 0.0)
	hold()


## Walk while moving at the given ground speed (m/s), freeze the pose when standing still.
func set_move_speed(speed: float) -> void:
	if _dead or _attacking:
		return
	if speed < 0.05:
		hold()
		return
	var clip: StringName = &"run" if speed > walk_reference_speed * 2.2 else &"walk"
	var reference: float = walk_reference_speed * (2.6 if clip == &"run" else 1.0)
	play(clip, 0.15, clampf(speed / reference, 0.4, max_playback_scale))


func play_attack() -> void:
	if _dead or _attacking:
		return
	_attacking = true
	play(&"attack", 0.1, attack_playback_scale)


## Plays the death clip once and returns its length in seconds (0 when there is no clip).
func play_death() -> float:
	_dead = true
	_attacking = false
	clear_flash()
	play(&"die", 0.1, 1.0)
	return clip_length(&"die")


func _on_clip_finished(clip: StringName) -> void:
	if clip == &"attack":
		_attacking = false
		attack_finished.emit()
