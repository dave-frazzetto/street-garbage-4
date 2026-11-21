class_name VfxBurst
extends CPUParticles3D
## A particle burst or loop used by the effect scenes. Tune everything in the Inspector (amount, lifetime, velocity,
## gradient, size curve); this script only adds "aim it" and "free it when done". CPUParticles3D keeps it web/mobile safe.

## One-shot bursts free themselves after their lifetime. Looping flames never do.
@export var free_when_done: bool = true


func _ready() -> void:
	if one_shot and free_when_done:
		# lifetime plus the random spread of particle lifetimes, plus a small margin.
		var wait: float = lifetime * (1.0 + lifetime_randomness) + 0.15
		get_tree().create_timer(wait, false).timeout.connect(queue_free)


## Aims the burst along a world direction (the node must not be rotated) and starts it. Zero keeps the authored direction.
func play(dir: Vector3 = Vector3.ZERO) -> void:
	if dir.length_squared() > 0.0001:
		direction = dir.normalized()
	restart()
	emitting = true
