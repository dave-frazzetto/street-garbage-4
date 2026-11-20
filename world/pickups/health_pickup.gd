class_name HealthPickup
extends Pickup
## Restores health when collected.

@export_range(1, 200) var heal_amount: float = 20.0
## Seconds before it disappears.
@export_range(1, 300) var lifetime: float = 25.0


func _physics_process(delta: float) -> void:
	super(delta)
	if _time >= lifetime:
		queue_free()


func _draw() -> void:
	var blink: bool = _time > lifetime - 4.0 and int(_time * 6.0) % 2 == 0
	if blink:
		return
	draw_rect(Rect2(-9, -9, 18, 18), Color(0.95, 0.95, 0.95))
	draw_rect(Rect2(-2.5, -7, 5, 14), Color(0.85, 0.1, 0.15))
	draw_rect(Rect2(-7, -2.5, 14, 5), Color(0.85, 0.1, 0.15))
