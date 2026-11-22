class_name ZombieDirector
extends Node
## The top-up of the zombie population: keeps GameTuning.trickle_alive zombies chasing the target, spawned just off-screen,
## with a type mix (armoured, bosses) that follows the run time. Top-up zombies far behind the player are freed and
## replaced near it. The zombies waiting in the world are WorldPopulation's job.

signal zombie_spawned(zombie: Zombie)

@export var config: DirectorConfig
@export var zombie_scene: PackedScene
## Balance numbers (the level injects them; null uses GameTuning defaults).
var tuning: GameTuning

var target: Node3D
var container: Node3D
## Playable area on the ground plane: x = world X, y = world Z.
var bounds: Rect2 = Rect2(0, 0, 100, 100)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Callable() -> float giving run time elapsed (drives the ramp).
var elapsed_provider: Callable
## Scales the trickle size (the graphics profile lowers it on phones).
var population_scale: float = 1.0
var active: bool = false
var _timer: float = 0.0
var _burst_pending: bool = false
var _alive: Array[Zombie] = []


func start(chase_target: Node3D, zombie_container: Node3D, level_bounds: Rect2, random: RandomNumberGenerator, elapsed: Callable, game_tuning: GameTuning = null) -> void:
	tuning = game_tuning if game_tuning != null else GameTuning.fallback()
	target = chase_target
	container = zombie_container
	bounds = level_bounds
	rng = random
	elapsed_provider = elapsed
	active = true
	_timer = 1.0
	_burst_pending = true


func alive_count() -> int:
	return _alive.size()


func _physics_process(delta: float) -> void:
	if not active or target == null or not is_instance_valid(target):
		return
	# Untyped lambda parameter: freed zombies cannot be converted to a typed argument.
	_alive.assign(_alive.filter(func(z: Variant) -> bool: return is_instance_valid(z) and not z.is_dead))
	_cull_far()
	var elapsed: float = _elapsed()
	var max_alive: int = maxi(0, roundi(tuning.trickle_alive(elapsed) * population_scale))
	if _burst_pending:
		_burst_pending = false
		for i: int in config.initial_burst:
			if _alive.size() >= max_alive:
				break
			_spawn_one()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = config.interval_at(tuning, elapsed)
	for i: int in config.batch_at(tuning, elapsed):
		if _alive.size() >= max_alive:
			break
		_spawn_one()


## Number of living ambient zombies of this type.
func alive_of(enemy: EnemyData) -> int:
	var n: int = 0
	for z: Zombie in _alive:
		if z.data == enemy:
			n += 1
	return n


func _spawn_one() -> void:
	var elapsed: float = _elapsed()
	var data: EnemyData = config.pick(elapsed, tuning, rng, Zombie.count_by_type(get_tree()))
	if data == null:
		return
	var pos: Vector3 = Vector3.ZERO
	var found: bool = false
	for attempt: int in 8:
		var dist: float = rng.randf_range(config.spawn_distance_min, config.spawn_distance_max)
		pos = target.global_position + Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * dist
		pos.y = 0.0
		if _in_bounds(pos, 1.0) and _is_free(pos, tuning.zombie_radius(data)):
			found = true
			break
	if not found:
		return
	var z: Zombie = zombie_scene.instantiate() as Zombie
	z.setup(data, target, 100000.0, tuning, elapsed)
	z.position = pos
	container.add_child(z)
	_alive.append(z)
	zombie_spawned.emit(z)


## Frees ambient zombies that fell far behind; the spawner brings fresh ones in near the player, so pressure stays constant.
func _cull_far() -> void:
	var limit_sq: float = config.despawn_distance * config.despawn_distance
	var origin: Vector3 = target.global_position
	var kept: Array[Zombie] = []
	for z: Zombie in _alive:
		if Vector2(z.global_position.x - origin.x, z.global_position.z - origin.z).length_squared() > limit_sq:
			z.queue_free()
		else:
			kept.append(z)
	_alive = kept


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
