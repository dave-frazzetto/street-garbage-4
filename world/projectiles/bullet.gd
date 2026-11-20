class_name Bullet
extends Node3D
## A bullet with a glowing tracer: moves, ray-casts against walls and zombies, supports ricochet (jump to the next
## zombie) and explosions.

signal damage_dealt(amount: float)

## Zombies within this distance (metres) can receive a ricochet.
@export_range(1, 30) var ricochet_search_radius: float = 8.0
@export_range(0.25, 10) var explosion_radius: float = 1.75
@export var explosion_scene: PackedScene

const WORLD_MASK: int = 1
const ZOMBIE_MASK: int = 4

@onready var _tracer: MeshInstance3D = $Tracer

var velocity: Vector3
var damage: float
var range_left: float
var ricochets_left: int
var explosion_fraction: float
var color: Color = Color.YELLOW
var radius: float = 0.08
var _excluded: Array[RID] = []


func setup(start: Vector3, direction: Vector3, weapon: WeaponData, dmg: float, max_range: float, ricochets: int, explosion: float) -> void:
	position = start
	velocity = direction * weapon.bullet_speed
	damage = dmg
	range_left = max_range
	ricochets_left = ricochets
	explosion_fraction = explosion
	color = weapon.bullet_color
	radius = weapon.bullet_radius


func _ready() -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	_tracer.material_override = mat
	_tracer.scale = Vector3(radius / 0.08, radius / 0.08, 1.0)
	_face_velocity()


func _physics_process(delta: float) -> void:
	var step: Vector3 = velocity * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + step
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK | ZOMBIE_MASK, _excluded)
	# Zombies hugging the player overlap the spawn point; still count them as hit.
	query.hit_from_inside = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		range_left -= step.length()
		if range_left <= 0.0:
			queue_free()
		return
	var collider: Object = hit["collider"]
	global_position = hit["position"]
	if collider is Zombie:
		_hit_zombie(collider as Zombie)
		return
	var prop: Destructible = Destructible.of(collider)
	if prop != null:
		prop.take_damage(damage)
	queue_free()


func _hit_zombie(zombie: Zombie) -> void:
	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z).normalized()
	var dealt: float = zombie.take_damage(damage, flat)
	if dealt > 0.0:
		damage_dealt.emit(dealt)
	if explosion_fraction > 0.0:
		_explode(zombie)
	_excluded.append(zombie.get_rid())
	if ricochets_left > 0:
		var next: Zombie = _find_ricochet_target(zombie)
		if next != null:
			ricochets_left -= 1
			var to_next: Vector3 = next.global_position - global_position
			to_next.y = 0.0
			velocity = to_next.normalized() * velocity.length()
			range_left = maxf(range_left, ricochet_search_radius)
			_face_velocity()
			return
	queue_free()


func _explode(center_zombie: Zombie) -> void:
	var splash: float = damage * explosion_fraction
	for node: Node in get_tree().get_nodes_in_group(Zombie.GROUP):
		var z: Zombie = node as Zombie
		if z == null or z.is_dead or z == center_zombie:
			continue
		var offset: Vector3 = z.global_position - global_position
		offset.y = 0.0
		if offset.length() <= explosion_radius:
			var dealt: float = z.take_damage(splash, offset.normalized())
			if dealt > 0.0:
				damage_dealt.emit(dealt)
	if explosion_scene != null:
		var fx: Node3D = explosion_scene.instantiate() as Node3D
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


func _face_velocity() -> void:
	if is_inside_tree() and velocity.length() > 0.01:
		var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		rotation.y = atan2(-flat.x, -flat.z)
