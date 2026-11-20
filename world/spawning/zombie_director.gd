class_name ZombieDirector
extends Node
## Spawns ambient zombies just off-screen around the target, with pressure that ramps up over the run.

signal zombie_spawned(zombie: Zombie)

@export var config: DirectorConfig
@export var zombie_scene: PackedScene

var target: Node3D
var container: Node3D
## Playable area on the ground plane: x = world X, y = world Z.
var bounds: Rect2 = Rect2(0, 0, 100, 100)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Callable() -> float giving run time elapsed (drives the ramp).
var elapsed_provider: Callable
var active: bool = false
var _timer: float = 0.0
var _alive: Array[Zombie] = []


func start(chase_target: Node3D, zombie_container: Node3D, level_bounds: Rect2, random: RandomNumberGenerator, elapsed: Callable) -> void:
	target = chase_target
	container = zombie_container
	bounds = level_bounds
	rng = random
	elapsed_provider = elapsed
	active = true
	_timer = 1.0


func alive_count() -> int:
	return _alive.size()


func _physics_process(delta: float) -> void:
	if not active or target == null or not is_instance_valid(target):
		return
	_alive = _alive.filter(func(z: Zombie) -> bool: return is_instance_valid(z) and not z.is_dead)
	_recycle_far()
	var t: float = config.ramp(_elapsed())
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = lerpf(config.interval_start, config.interval_end, t)
	var max_alive: int = roundi(lerpf(config.max_alive_start, config.max_alive_end, t))
	var batch: int = roundi(lerpf(config.batch_start, config.batch_end, t))
	for i: int in batch:
		if _alive.size() >= max_alive:
			break
		_spawn_one()


func _spawn_one() -> void:
	var data: EnemyData = config.pick(_elapsed(), rng)
	if data == null:
		return
	var pos: Vector3 = Vector3.ZERO
	var found: bool = false
	for attempt: int in 8:
		var dist: float = rng.randf_range(config.spawn_distance_min, config.spawn_distance_max)
		pos = target.global_position + Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * dist
		pos.y = 0.0
		if _in_bounds(pos, 1.0) and _is_free(pos, data.radius):
			found = true
			break
	if not found:
		return
	var z: Zombie = zombie_scene.instantiate() as Zombie
	z.setup(data, target, 100000.0)
	z.position = pos
	container.add_child(z)
	_alive.append(z)
	zombie_spawned.emit(z)


func _recycle_far() -> void:
	for z: Zombie in _alive:
		if z.global_position.distance_to(target.global_position) > config.despawn_distance:
			# Move it back near the player rather than deleting it, so pressure stays constant.
			var away: Vector3 = z.global_position - target.global_position
			away.y = 0.0
			var dir: Vector3 = away.normalized().rotated(Vector3.UP, rng.randf_range(-1.5, 1.5))
			var pos: Vector3 = target.global_position + dir * config.spawn_distance_max
			pos.y = 0.0
			if _in_bounds(pos, 0.0) and _is_free(pos, z.data.radius):
				z.global_position = pos


func _in_bounds(pos: Vector3, margin: float) -> bool:
	return bounds.grow(-margin).has_point(Vector2(pos.x, pos.z))


func _is_free(pos: Vector3, radius: float) -> bool:
	var space: PhysicsDirectSpaceState3D = container.get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius + 0.1
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.9, 0))
	q.collision_mask = 1
	return space.intersect_shape(q, 1).is_empty()


func _elapsed() -> float:
	return float(elapsed_provider.call()) if elapsed_provider.is_valid() else 0.0
