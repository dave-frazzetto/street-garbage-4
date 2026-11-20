@tool
class_name DecalZone
extends Node2D
## A flat painted area on the ground (basketball court, quarantine zone). Purely visual.

@export var size: Vector2 = Vector2(400, 300):
	set(value):
		size = value
		queue_redraw()
@export var color: Color = Color(0.55, 0.3, 0.18, 0.6):
	set(value):
		color = value
		queue_redraw()
@export var line_color: Color = Color(1, 1, 1, 0.5):
	set(value):
		line_color = value
		queue_redraw()
@export var label: String = "":
	set(value):
		label = value
		queue_redraw()
@export var striped: bool = false:
	set(value):
		striped = value
		queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(-size / 2.0, size)
	draw_rect(r, color)
	draw_rect(r, line_color, false, 3.0)
	if striped:
		var x: float = -size.x / 2.0
		while x < size.x / 2.0:
			draw_line(Vector2(x, -size.y / 2.0), Vector2(minf(x + 40.0, size.x / 2.0), -size.y / 2.0 + 20.0), Color(1, 0.85, 0.1, 0.8), 6.0)
			x += 60.0
	else:
		draw_line(Vector2(0, -size.y / 2.0), Vector2(0, size.y / 2.0), line_color, 3.0)
		draw_arc(Vector2.ZERO, minf(size.x, size.y) * 0.18, 0, TAU, 32, line_color, 3.0)
	if label != "":
		var font: Font = ThemeDB.fallback_font
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, Vector2(-w / 2.0, -size.y / 2.0 - 10.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, line_color)
