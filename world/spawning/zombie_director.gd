class_name ZombieDirector
extends Node
## Spawns ambient zombies just off-screen around the target, with pressure that ramps up over the run.

signal zombie_spawned(zombie: Zombie)

@export var config: DirectorConfig
@export var zombie_scene: PackedScene

var target: Node2D
var container: Node2D
var bounds: Rect2 = Rect2(0, 0, 4000, 4000)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Callable() -> float giving run time elapsed (drives the ramp).
var elapsed_provider: Callable
var active: bool = false
var _timer: float = 0.0
var _alive: Array[Zombie] = []


func start(chase_target: Node2D, zombie_container: Node2D, level_bounds: Rect2, random: RandomNumberGenerator, elapsed: Callable) -> void:
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
	var pos: Vector2 = Vector2.ZERO
	var found: bool = false
	for attempt: int in 8:
		var dist: float = rng.randf_range(config.spawn_distance_min, config.spawn_distance_max)
		pos = target.global_position + Vector2.from_angle(rng.randf() * TAU) * dist
		if bounds.grow(-40.0).has_point(pos) and _is_free(pos, data.radius):
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
			var dir: Vector2 = (z.global_position - target.global_position).normalized().rotated(rng.randf_range(-1.5, 1.5))
			var pos: Vector2 = target.global_position + dir * config.spawn_distance_max
			if bounds.has_point(pos) and _is_free(pos, z.data.radius):
				z.global_position = pos


func _is_free(pos: Vector2, radius: float) -> bool:
	var space: PhysicsDirectSpaceState2D = container.get_world_2d().direct_space_state
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius + 4.0
	var q: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, pos)
	q.collision_mask = 1
	return space.intersect_shape(q, 1).is_empty()


func _elapsed() -> float:
	return float(elapsed_provider.call()) if elapsed_provider.is_valid() else 0.0
