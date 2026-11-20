@tool
class_name GearIcon
extends Control
## A cog drawn in code (the bundled web font has no gear glyph).

@export var color: Color = Color(0.92, 0.92, 0.95):
	set(value):
		color = value
		queue_redraw()
@export_range(4, 16) var teeth: int = 8


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) * 0.5
	for i: int in teeth:
		var a: float = TAU * i / teeth
		var d: Vector2 = Vector2.from_angle(a)
		var side: Vector2 = d.orthogonal() * r * 0.18
		var inner: Vector2 = c + d * r * 0.6
		var outer: Vector2 = c + d * r * 0.98
		draw_colored_polygon(PackedVector2Array([inner - side, outer - side, outer + side, inner + side]), color)
	draw_circle(c, r * 0.68, color)
	draw_circle(c, r * 0.3, Color(0.05, 0.05, 0.07))
