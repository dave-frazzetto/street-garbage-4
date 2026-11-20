class_name HealthPickup
extends Pickup
## Restores health when collected.

@export_range(1, 200) var heal_amount: float = 20.0
## Seconds before it disappears.
@export_range(1, 300) var lifetime: float = 25.0

@onready var _visual: Node3D = $Visual


func _animate(_delta: float) -> void:
	_visual.rotation.y = _time * 1.5
	_visual.position.y = 0.4 + sin(_time * 3.0) * 0.08
	_visual.visible = not (_time > lifetime - 4.0 and int(_time * 6.0) % 2 == 0)
	if _time >= lifetime:
		queue_free()
