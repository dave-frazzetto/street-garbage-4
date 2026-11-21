class_name ImpactEffect
extends Node3D
## One-shot spark / flash burst where a bullet hits. Unshaded CPU particles, no lights, frees itself.

@export_range(0.05, 2, 0.05) var lifetime: float = 0.3
## Tint of the sparks; the bullet sets it to its own colour.
@export var color: Color = Color(1.0, 0.7, 0.3)

@onready var _sparks: CPUParticles3D = $Sparks


func _ready() -> void:
	var mat: StandardMaterial3D = _sparks.material_override.duplicate() as StandardMaterial3D
	mat.albedo_color = color
	_sparks.material_override = mat
	_sparks.lifetime = lifetime
	_sparks.restart()
	_sparks.emitting = true
	get_tree().create_timer(lifetime + 0.2).timeout.connect(queue_free)
