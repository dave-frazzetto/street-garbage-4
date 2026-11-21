class_name FootstepStepper
extends Node
## Turns movement into footstep events at a stride cadence: one step each time the tracked body has travelled one stride.
## Runs on its own: call track(position, delta, sprinting) every frame (or advance(distance, sprinting) directly) and
## listen to step_taken. The sound itself is chosen by whoever listens (GameFlow plays the bank's footstep cue).

## A foot hit the ground.
signal step_taken(sprinting: bool)

## Metres travelled between two steps while walking.
@export_range(0.2, 5.0, 0.05, "suffix:m") var walk_stride: float = 1.1
## Metres between two steps while sprinting (longer stride, so the cadence rises less than the speed does).
@export_range(0.2, 6.0, 0.05, "suffix:m") var sprint_stride: float = 1.6
## Movement slower than this (m/s) counts as standing still, so a jittering body does not shuffle.
@export_range(0.0, 3.0, 0.05, "suffix:m/s") var min_speed: float = 0.4
## Moves longer than this in a single frame (a teleport, a respawn) do not produce steps.
@export_range(1.0, 50.0, 0.5, "suffix:m") var max_step_jump: float = 6.0

var _travelled: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _has_last: bool = false


## Feed the body's world position every frame; emits step_taken as strides complete. Returns steps taken this call.
func track(position: Vector3, delta: float, sprinting: bool) -> int:
	if not _has_last:
		_last_position = position
		_has_last = true
		return 0
	var flat: Vector3 = position - _last_position
	flat.y = 0.0
	_last_position = position
	var distance: float = flat.length()
	if distance > max_step_jump or delta <= 0.0 or distance / delta < min_speed:
		return 0
	return advance(distance, sprinting)


## Adds travelled distance; returns (and emits) how many steps that completed. Node-free logic, used by tests.
func advance(distance: float, sprinting: bool) -> int:
	var stride: float = sprint_stride if sprinting else walk_stride
	_travelled += distance
	var steps: int = 0
	while _travelled >= stride:
		_travelled -= stride
		steps += 1
		step_taken.emit(sprinting)
	return steps


## Forget the last position (new run, teleport) so no step is produced for the jump.
func reset() -> void:
	_has_last = false
	_travelled = 0.0
