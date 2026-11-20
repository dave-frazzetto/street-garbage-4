extends Node2D
## Short-lived explosion flash.

@export var radius: float = 70.0
@export_range(0.05, 2, 0.05) var lifetime: float = 0.25
@export var color: Color = Color(1.0, 0.55, 0.15)

var _age: float = 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_age / lifetime, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * (0.4 + 0.6 * t), Color(color, 0.6 * (1.0 - t)))
