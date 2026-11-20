@tool
class_name Ground
extends Node2D
## The city floor: asphalt with lane markings and optional decorative zones (courts, quarantine area).

@export var size: Vector2 = Vector2(4000, 4000):
	set(value):
		size = value
		queue_redraw()
@export var asphalt_color: Color = Color(0.16, 0.16, 0.18):
	set(value):
		asphalt_color = value
		queue_redraw()
@export var grid_color: Color = Color(0.2, 0.2, 0.22):
	set(value):
		grid_color = value
		queue_redraw()
@export_range(50, 1000) var grid_step: float = 200.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), asphalt_color)
	var x: float = 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 2.0)
		x += grid_step
	var y: float = 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 2.0)
		y += grid_step
