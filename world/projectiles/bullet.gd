class_name Bullet
extends Node2D
## A bullet: moves, ray-casts against walls and zombies, supports ricochet (jump to next zombie) and explosions.

signal damage_dealt(amount: float)

## Zombies within this distance can receive a ricochet.
@export_range(50, 1000) var ricochet_search_radius: float = 320.0
@export_range(10, 300) var explosion_radius: float = 70.0
@export var explosion_scene: PackedScene

const WORLD_MASK: int = 1
const ZOMBIE_MASK: int = 4

var velocity: Vector2
var damage: float
var range_left: float
var ricochets_left: int
var explosion_fraction: float
var color: Color = Color.YELLOW
var radius: float = 3.0
var _excluded: Array[RID] = []


func setup(start: Vector2, direction: Vector2, weapon: WeaponData, dmg: float, max_range: float, ricochets: int, explosion: float) -> void:
	position = start
	velocity = direction * weapon.bullet_speed
	damage = dmg
	range_left = max_range
	ricochets_left = ricochets
	explosion_fraction = explosion
	color = weapon.bullet_color
	radius = weapon.bullet_radius


func _physics_process(delta: float) -> void:
	var step: Vector2 = velocity * delta
	var from: Vector2 = global_position
	var to: Vector2 = from + step
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK | ZOMBIE_MASK, _excluded)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		range_left -= step.length()
		if range_left <= 0.0:
			queue_free()
		queue_redraw()
		return
	var collider: Object = hit["collider"]
	global_position = hit["position"]
	if collider is Zombie:
		_hit_zombie(collider as Zombie)
	else:
		queue_free()


func _hit_zombie(zombie: Zombie) -> void:
	var dealt: float = zombie.take_damage(damage, velocity.normalized())
	if dealt > 0.0:
		damage_dealt.emit(dealt)
	if explosion_fraction > 0.0:
		_explode(zombie)
	_excluded.append(zombie.get_rid())
	if ricochets_left > 0:
		var next: Zombie = _find_ricochet_target(zombie)
		if next != null:
			ricochets_left -= 1
			velocity = (next.global_position - global_position).normalized() * velocity.length()
			range_left = maxf(range_left, ricochet_search_radius)
			return
	queue_free()


func _explode(center_zombie: Zombie) -> void:
	var splash: float = damage * explosion_fraction
	for node: Node in get_tree().get_nodes_in_group(Zombie.GROUP):
		var z: Zombie = node as Zombie
		if z == null or z.is_dead or z == center_zombie:
			continue
		if z.global_position.distance_to(global_position) <= explosion_radius:
			var dealt: float = z.take_damage(splash, (z.global_position - global_position).normalized())
			if dealt > 0.0:
				damage_dealt.emit(dealt)
	if explosion_scene != null:
		var fx: Node2D = explosion_scene.instantiate() as Node2D
		fx.position = global_position
		fx.set("radius", explosion_radius)
		get_parent().add_child(fx)


func _find_ricochet_target(from_zombie: Zombie) -> Zombie:
	var best: Zombie = null
	var best_d: float = ricochet_search_radius
	for node: Node in get_tree().get_nodes_in_group(Zombie.GROUP):
		var z: Zombie = node as Zombie
		if z == null or z.is_dead or z == from_zombie or _excluded.has(z.get_rid()):
			continue
		var d: float = z.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = z
	return best


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_line(Vector2.ZERO, -velocity.normalized() * radius * 3.0, Color(color, 0.5), radius)
