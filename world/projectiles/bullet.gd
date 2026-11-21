class_name Bullet
extends Node3D
## A hitscan shot drawn as one static line of light from the muzzle to the hit point (or the end of its range): ray-casts
## against walls and zombie hurtboxes at once, supports ricochet (jump to the next zombie) and explosions. The line fades out.

signal damage_dealt(amount: float)

## Zombies within this distance (metres) can receive a ricochet.
@export_range(1, 30) var ricochet_search_radius: float = 8.0
@export_range(0.25, 10) var explosion_radius: float = 1.75
@export var explosion_scene: PackedScene
## Spark burst spawned where the bullet hits a wall or prop (gets `color` set to the bullet colour).
@export var impact_scene: PackedScene
## Burst spawned where the bullet hits a zombie. Hook for blood: swap this scene.
@export var zombie_impact_scene: PackedScene

const WORLD_MASK: int = 1
## Bullets test zombies through their ZombieHurtbox areas (more forgiving than the body), never the body itself.
const HURTBOX_MASK: int = ZombieHurtbox.HURTBOX_LAYER

@onready var _beam: MeshInstance3D = $Beam

## Unit direction of the shot (a hitscan: the whole path is resolved on the first physics frame).
var velocity: Vector3
var damage: float
var range_left: float
var ricochets_left: int
var explosion_fraction: float
var color: Color = Color.YELLOW
var radius: float = 0.08
var beam_fade_seconds: float = 0.12
var _excluded: Array[RID] = []
var _hit_zombies: Array[Zombie] = []
var _resolved: bool = false
var _fade_left: float = 0.0
var _beam_material: StandardMaterial3D
## Straight pieces of the shot as [from, to] pairs (more than one only after a ricochet).
var _segments: Array[PackedVector3Array] = []
var _beams: Array[MeshInstance3D] = []


func setup(start: Vector3, direction: Vector3, weapon: WeaponData, dmg: float, max_range: float, ricochets: int, explosion: float) -> void:
	position = start
	velocity = direction.normalized()
	damage = dmg
	range_left = max_range
	ricochets_left = ricochets
	explosion_fraction = explosion
	color = weapon.bullet_color
	radius = weapon.bullet_radius
	beam_fade_seconds = weapon.beam_fade_seconds


func _ready() -> void:
	_beam_material = StandardMaterial3D.new()
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.albedo_color = color
	_beam.material_override = _beam_material
	_beam.visible = false
	_beams.append(_beam)
	_face_velocity()


func _physics_process(delta: float) -> void:
	if not _resolved:
		_resolve()
		return
	_fade_left -= delta
	if _fade_left <= 0.0:
		queue_free()
	else:
		_update_beams(_fade_left / maxf(0.001, beam_fade_seconds))


## Instant shot: follows the ray from the muzzle until it hits a wall, prop or zombie (or runs out of range), applies
## the hits, then shows one static line of light over the whole path that fades out.
func _resolve() -> void:
	_resolved = true
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var seg_start: Vector3 = global_position
	var from: Vector3 = seg_start
	var guard: int = 0
	while range_left > 0.0 and guard < 32:
		guard += 1
		var dir: Vector3 = velocity.normalized()
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * range_left, WORLD_MASK | HURTBOX_MASK, _excluded)
		query.collide_with_areas = true
		# Zombies hugging the player overlap the muzzle; still count them as hit.
		query.hit_from_inside = true
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			_add_segment(seg_start, from + dir * range_left)
			range_left = 0.0
			break
		var pos: Vector3 = hit["position"]
		range_left -= from.distance_to(pos)
		global_position = pos
		var collider: Object = hit["collider"]
		if collider is ZombieHurtbox:
			var zombie: Zombie = (collider as ZombieHurtbox).get_zombie()
			from = pos
			if zombie == null or zombie.is_dead:
				_excluded.append((collider as ZombieHurtbox).get_rid())
				continue
			_spawn_impact(zombie_impact_scene, hit["normal"])
			_add_segment(seg_start, pos)
			seg_start = pos
			if not _hit_zombie(zombie, (collider as ZombieHurtbox).get_rid()):
				break
			continue
		var prop: Destructible = Destructible.of(collider)
		if prop != null:
			prop.take_damage(damage)
		_spawn_impact(impact_scene, hit["normal"])
		_add_segment(seg_start, pos)
		break
	_fade_left = beam_fade_seconds
	_update_beams(1.0)


func _add_segment(a: Vector3, b: Vector3) -> void:
	if a.distance_to(b) < 0.02:
		return
	_segments.append(PackedVector3Array([a, b]))


## Draws every segment as a thin static box between its two points.
func _update_beams(alpha: float) -> void:
	while _beams.size() < _segments.size():
		var extra: MeshInstance3D = _beam.duplicate() as MeshInstance3D
		add_child(extra)
		_beams.append(extra)
	for i: int in _beams.size():
		var beam: MeshInstance3D = _beams[i]
		if i >= _segments.size():
			beam.visible = false
			continue
		var a: Vector3 = _segments[i][0]
		var b: Vector3 = _segments[i][1]
		var along: Vector3 = b - a
		var dir: Vector3 = along.normalized()
		var basis: Basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
		basis = basis.scaled_local(Vector3(radius, radius, along.length()))
		beam.visible = true
		beam.global_transform = Transform3D(basis, (a + b) * 0.5)
	_beam_material.albedo_color = Color(color, alpha)


func _spawn_impact(scene: PackedScene, normal: Vector3) -> void:
	if scene == null:
		return
	var fx: Node3D = scene.instantiate() as Node3D
	fx.set("color", color)
	fx.position = global_position
	get_parent().add_child(fx)
	if normal.length() > 0.1:
		fx.look_at(fx.position + normal, Vector3.UP if absf(normal.y) < 0.99 else Vector3.RIGHT)
		fx.rotate_object_local(Vector3.RIGHT, PI * 0.5)


## Applies the hit; returns true when the shot ricochets on to another zombie (the caller keeps tracing).
func _hit_zombie(zombie: Zombie, hurtbox: RID) -> bool:
	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z).normalized()
	var dealt: float = zombie.take_damage(damage, flat)
	if dealt > 0.0:
		damage_dealt.emit(dealt)
	if explosion_fraction > 0.0:
		_explode(zombie)
	_excluded.append(hurtbox)
	_hit_zombies.append(zombie)
	if ricochets_left > 0:
		var next: Zombie = _find_ricochet_target(zombie)
		if next != null:
			ricochets_left -= 1
			var to_next: Vector3 = next.global_position - global_position
			to_next.y = 0.0
			velocity = to_next.normalized()
			range_left = maxf(range_left, ricochet_search_radius)
			return true
	return false


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
		if z == null or z.is_dead or z == from_zombie or _hit_zombies.has(z):
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
