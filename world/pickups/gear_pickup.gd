class_name GearPickup
extends Pickup
## A floating, glowing blue cog. Collect all of them to extract.

@onready var _cog: Node3D = $Cog


func _animate(_delta: float) -> void:
	_cog.rotation.y = _time * 1.2
	_cog.position.y = 1.3 + sin(_time * 2.5) * 0.15
