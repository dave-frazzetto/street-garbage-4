class_name ZombieModel
extends CharacterModel
## Visual of a zombie: walk, run, attack and death on top of the shared character model.

signal attack_finished

## Walking speed in m/s at which the walk clip plays at normal speed.
@export_range(0.2, 6.0, 0.05) var walk_reference_speed: float = 1.1
@export_range(0.5, 3.0, 0.05) var max_playback_scale: float = 2.5
## Normal speed of the attack clip.
@export_range(0.5, 3.0, 0.05) var attack_playback_scale: float = 1.6

## Tilt in degrees the body snaps to when a bullet hits, away from the shooter, then eases back.
@export_range(0, 60, 0.5) var hit_tilt_degrees: float = 22.0
## Seconds the hit reaction takes to settle.
@export_range(0.05, 1.0, 0.01) var hit_recover_seconds: float = 0.3
## Fraction of height lost at the peak of the hit reaction (squash).
@export_range(0, 0.4, 0.01) var hit_squash: float = 0.08

var _dead: bool = false
var _attacking: bool = false
var _hit_left: float = 0.0
var _hit_axis: Vector3 = Vector3.RIGHT
var _rest: Transform3D


func _ready() -> void:
	super._ready()
	_rest = transform
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


## Flinch: the body snaps away from where the bullet came from, squashes a little and eases back.
## `local_direction` is the bullet's travel direction in this model's parent space.
func play_hit(local_direction: Vector3) -> void:
	if _dead:
		return
	var flat: Vector3 = Vector3(local_direction.x, 0.0, local_direction.z)
	if flat.length() < 0.01:
		flat = Vector3.BACK
	_hit_axis = Vector3.UP.cross(flat.normalized()).normalized()
	_hit_left = hit_recover_seconds


func _process(delta: float) -> void:
	if _hit_left <= 0.0:
		return
	_hit_left = maxf(0.0, _hit_left - delta)
	var t: float = _hit_left / maxf(0.001, hit_recover_seconds)
	var amount: float = t * t
	var reaction: Basis = Basis(_hit_axis, deg_to_rad(hit_tilt_degrees) * amount).scaled(Vector3(1.0, 1.0 - hit_squash * amount, 1.0))
	transform = Transform3D(reaction * _rest.basis, _rest.origin)


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
