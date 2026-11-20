class_name ObjectiveArrow
extends Node2D
## Arrow around the player pointing to the current objective when it is off-screen.

@export var color: Color = Color(0.3, 0.7, 1.0)
@export_range(20, 300) var orbit_radius: float = 60.0
## Hide when the objective is closer than this.
@export_range(0, 2000) var hide_distance: float = 380.0

var follow: Node2D
var objective: Vector2
var has_objective: bool = false


func _process(_delta: float) -> void:
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position
	queue_redraw()


func _draw() -> void:
	if not has_objective:
		return
	var to: Vector2 = objective - global_position
	if to.length() < hide_distance:
		return
	var d: Vector2 = to.normalized()
	var tip: Vector2 = d * (orbit_radius + 14.0)
	var base: Vector2 = d * orbit_radius
	var side: Vector2 = d.orthogonal() * 9.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), color)
