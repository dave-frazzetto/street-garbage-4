@tool
class_name Building
extends StaticBody2D
## A solid block (building, wall, car wreck). Size and colour are set in the Inspector; collision follows.

@export var size: Vector2 = Vector2(200, 160):
	set(value):
		size = value
		_refresh()
@export var color: Color = Color(0.28, 0.27, 0.3):
	set(value):
		color = value
		queue_redraw()
@export var roof_color: Color = Color(0.36, 0.34, 0.38):
	set(value):
		roof_color = value
		queue_redraw()
## Optional label drawn on the roof.
@export var label: String = "":
	set(value):
		label = value
		queue_redraw()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		var rect: RectangleShape2D = shape_node.shape as RectangleShape2D
		if rect == null:
			rect = RectangleShape2D.new()
		else:
			rect = rect.duplicate() as RectangleShape2D
		rect.size = size
		shape_node.shape = rect
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(-size / 2.0, size)
	draw_rect(r, color)
	draw_rect(r.grow(-8.0), roof_color)
	draw_rect(r, Color(0, 0, 0, 0.5), false, 3.0)
	if label != "":
		var font: Font = ThemeDB.fallback_font
		var fs: int = 18
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(-w / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.6))


func _get_configuration_warnings() -> PackedStringArray:
	if get_node_or_null("CollisionShape2D") == null:
		return PackedStringArray(["Building needs a CollisionShape2D child."])
	return PackedStringArray()
