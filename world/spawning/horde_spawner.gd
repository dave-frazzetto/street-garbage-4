@tool
class_name HordeSpawner
extends Marker3D
## Spawns a waiting horde around itself once, when the level starts (e.g. the helicopter crash).
## Zombies stay idle until the player gets within aggro_radius or shoots them.

signal zombie_spawned(zombie: Zombie)

@export var zombie_scene: PackedScene
@export var enemies: Array[EnemyData] = []
@export_range(1, 300) var count: int = 30
## Radius in metres around the spawner.
@export_range(0.5, 40) var scatter_radius: float = 6.0
@export_range(1, 60) var aggro_radius: float = 10.5
## Show the crashed helicopter wreck child.
@export var show_wreck: bool = true:
	set(value):
		show_wreck = value
		var wreck: Node3D = get_node_or_null("Wreck") as Node3D
		if wreck != null:
			wreck.visible = value
			var body: CollisionObject3D = wreck.get_node_or_null("Body") as CollisionObject3D
			if body != null:
				body.collision_layer = 1 if value else 0


func _ready() -> void:
	show_wreck = show_wreck


func spawn(target: Node3D, container: Node, rng: RandomNumberGenerator) -> void:
	if enemies.is_empty() or zombie_scene == null:
		return
	for i: int in count:
		var z: Zombie = zombie_scene.instantiate() as Zombie
		z.setup(enemies[rng.randi() % enemies.size()], target, aggro_radius)
		var offset: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * (2.5 + sqrt(rng.randf()) * scatter_radius)
		z.position = global_position + offset
		container.add_child(z)
		zombie_spawned.emit(z)
