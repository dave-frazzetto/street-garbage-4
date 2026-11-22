class_name VfxBurst
extends GPUParticles3D
## A GPU particle burst or loop used by the effect scenes. Tune everything in the Inspector (amount, lifetime, the
## Process Material's velocity, colour ramp and scale curve, the draw material's shader parameters); this script only
## adds "aim it", "scale it" and "free it when done".
##
## The Process Material is a Resource shared by every instance of the scene, so anything that changes it per effect
## (aiming, scaling) goes through [method params], which gives this instance its own copy first.

## One-shot bursts free themselves after their lifetime. Looping flames never do.
@export var free_when_done: bool = true

var _owns_params: bool = false


func _ready() -> void:
	if one_shot and free_when_done:
		# lifetime plus the random spread of particle lifetimes, plus a small margin.
		get_tree().create_timer(total_lifetime() + 0.15, false).timeout.connect(queue_free)


## Seconds until the last particle of a burst has died: lifetime plus the random spread of particle lifetimes.
func total_lifetime() -> float:
	var spread: float = (process_material as ParticleProcessMaterial).lifetime_randomness
	return lifetime * (1.0 + spread) / maxf(speed_scale, 0.01)


## This burst's own copy of the Process Material, safe to change without touching other instances.
func params() -> ParticleProcessMaterial:
	if not _owns_params:
		process_material = process_material.duplicate()
		_owns_params = true
	return process_material as ParticleProcessMaterial


## Aims the burst along a world direction (the node must not be rotated). Zero keeps the authored direction.
func aim(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		params().direction = dir.normalized()


## Scales speeds, sizes and the emission radius together, so one authored effect can be drawn bigger or smaller.
func scale_by(factor: float) -> void:
	var p: ParticleProcessMaterial = params()
	p.initial_velocity_min *= factor
	p.initial_velocity_max *= factor
	p.scale_min *= factor
	p.scale_max *= factor
	p.emission_sphere_radius *= factor


## Aims the burst (see [method aim]) and starts it.
func play(dir: Vector3 = Vector3.ZERO) -> void:
	aim(dir)
	restart()
	emitting = true
