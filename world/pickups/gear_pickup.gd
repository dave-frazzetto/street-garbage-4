class_name GearPickup
extends Pickup
## A floating blue cog. Collect all of them to extract.

@export var color: Color = Color(0.25, 0.65, 1.0)
@export_range(6, 40) var size: float = 14.0


func _draw() -> void:
	var bob: float = sin(_time * 3.0) * 4.0
	var c: Vector2 = Vector2(0, -10 + bob)
	draw_circle(Vector2(0, 6), size * 0.8, Color(0, 0, 0, 0.3))
	draw_circle(c, size * 2.2, Color(color, 0.12 + 0.08 * sin(_time * 4.0)))
	var teeth: int = 8
	for i: int in teeth:
		var a: float = TAU * i / teeth + _time
		draw_line(c + Vector2.from_angle(a) * size * 0.7, c + Vector2.from_angle(a) * size * 1.25, color, 5.0)
	draw_circle(c, size * 0.85, color)
	draw_circle(c, size * 0.35, Color(0.05, 0.1, 0.2))
