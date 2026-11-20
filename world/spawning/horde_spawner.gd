@tool
class_name HordeSpawner
extends Marker2D
## Spawns a waiting horde around itself once, when the level starts (e.g. the helicopter crash).
## Zombies stay idle until the player gets within aggro_radius or shoots them.

signal zombie_spawned(zombie: Zombie)

@export var zombie_scene: PackedScene
@export var enemies: Array[EnemyData] = []
@export_range(1, 300) var count: int = 30
@export_range(10, 1000) var scatter_radius: float = 220.0
@export_range(50, 2000) var aggro_radius: float = 420.0
@export var draw_wreck: bool = true


func spawn(target: Node2D, container: Node, rng: RandomNumberGenerator) -> void:
	if enemies.is_empty() or zombie_scene == null:
		return
	for i: int in count:
		var z: Zombie = zombie_scene.instantiate() as Zombie
		z.setup(enemies[rng.randi() % enemies.size()], target, aggro_radius)
		var offset: Vector2 = Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * scatter_radius
		z.position = global_position + offset
		container.add_child(z)
		zombie_spawned.emit(z)


func _draw() -> void:
	if not draw_wreck:
		return
	# Crashed helicopter placeholder.
	draw_rect(Rect2(-60, -22, 120, 44), Color(0.25, 0.3, 0.22))
	draw_rect(Rect2(50, -6, 90, 12), Color(0.22, 0.26, 0.2))
	draw_line(Vector2(-110, -80), Vector2(110, 80), Color(0.1, 0.1, 0.1), 6.0)
	draw_line(Vector2(-110, 80), Vector2(110, -80), Color(0.1, 0.1, 0.1), 6.0)
	draw_circle(Vector2(-20, 0), 30, Color(1, 0.45, 0.1, 0.35))
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, scatter_radius, 0, TAU, 48, Color(1, 0, 0, 0.5), 2.0)
