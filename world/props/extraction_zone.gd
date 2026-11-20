@tool
class_name ExtractionZone
extends Area2D
## The High-Rise entrance in the quarantine zone. Reports when the player steps in; the run rules decide the rest.

signal player_entered

@export var size: Vector2 = Vector2(220, 160):
	set(value):
		size = value
		_refresh()
@export var color: Color = Color(0.2, 1.0, 0.5):
	set(value):
		color = value
		queue_redraw()
@export var label: String = "HIGH-RISE":
	set(value):
		label = value
		queue_redraw()

var unlocked: bool = false:
	set(value):
		unlocked = value
		queue_redraw()
var _time: float = 0.0


func _ready() -> void:
	_refresh()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = size
		shape_node.shape = rect
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_entered.emit()


func _draw() -> void:
	var r: Rect2 = Rect2(-size / 2.0, size)
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
	var col: Color = color if unlocked else Color(0.8, 0.8, 0.8)
	draw_rect(r, Color(col, 0.15 + 0.15 * pulse))
	draw_rect(r, col, false, 4.0)
	var font: Font = ThemeDB.fallback_font
	var text: String = label if unlocked else label + " (LOCKED)"
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font, Vector2(-w / 2.0, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
