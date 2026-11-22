class_name ZombieDirector
extends Node
## The top-up of the zombie population: keeps GameTuning.trickle_alive zombies chasing the target, spawned just off-screen,
## with a type mix (armoured, bosses) that follows the run time. Top-up zombies far behind the player are freed and
## replaced near it. The zombies waiting in the world are WorldPopulation's job.

signal zombie_spawned(zombie: Zombie)

## Random spots tried on the spawn ring per zombie.
const SPAWN_TRIES: int = 12
## Fallback spawn spots are at least this share of spawn_distance_min away in a straight line (still off-screen).
const FALLBACK_MIN_SHARE: float = 0.8
## Walking distance from the target at which a chaser's side of approach is judged.
const FLANK_RADIUS: float = 9.0
## A chaser's cached arrival bearing is reused until it moved this far (metres) or the flow field changed.
const BEARING_CACHE_MOVE: float = 2.0

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
## Where zombies can stand and how far they walk to the target (injected by the level; null = ring only, physics check).
var walk_grid: WalkGrid
var flow: FlowField
var active: bool = false
var _timer: float = 0.0
var _burst_pending: bool = false
var _alive: Array[Zombie] = []
## Instance id -> [flow version, position, bearing] (see _chaser_bearing).
var _bearing_cache: Dictionary = {}


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
	var pos: Vector3 = _flanking_spawn_point(data)
	if pos.x == INF:
		return
	var z: Zombie = zombie_scene.instantiate() as Zombie
	z.setup(data, target, 100000.0, tuning, elapsed)
	z.position = pos
	container.add_child(z)
	_alive.append(z)
	zombie_spawned.emit(z)


## Of a few usable spawn spots, the one that reaches the target from the side farthest from every living chaser's: the
## side is where its walk down the streets comes within FLANK_RADIUS of the target (with a flow field), else its bearing.
func _flanking_spawn_point(data: EnemyData) -> Vector3:
	var origin: Vector3 = target.global_position
	var taken: Array[float] = []
	for z: Zombie in _alive:
		taken.append(_chaser_bearing(z, origin))
	var best: Vector3 = Vector3(INF, 0.0, 0.0)
	var best_gap: float = -1.0
	for i: int in maxi(config.spawn_flank_candidates, 1):
		var pos: Vector3 = _spawn_point(data)
		if pos.x == INF:
			continue
		var bearing: float = _arrival_bearing(pos, origin)
		var gap: float = PI
		for t: float in taken:
			gap = minf(gap, absf(angle_difference(bearing, t)))
		if gap > best_gap:
			best_gap = gap
			best = pos
		if taken.is_empty():
			break
	return best


## A living chaser's arrival bearing, cached per flow field version while it stays within BEARING_CACHE_MOVE metres
## (walking a field back is the costly part of picking a spawn spot on the single-threaded web build).
func _chaser_bearing(z: Zombie, origin: Vector3) -> float:
	var version: int = flow.version if flow != null else -1
	var key: int = z.get_instance_id()
	var cached: Array = _bearing_cache.get(key, [])
	if not cached.is_empty() and int(cached[0]) == version and (cached[1] as Vector3).distance_squared_to(z.global_position) < BEARING_CACHE_MOVE * BEARING_CACHE_MOVE:
		return float(cached[2])
	var bearing: float = _arrival_bearing(z.global_position, origin)
	_bearing_cache[key] = [version, z.global_position, bearing]
	return bearing


func _arrival_bearing(from: Vector3, origin: Vector3) -> float:
	var p: Vector2 = Vector2(from.x, from.z)
	if flow != null and flow.is_ready():
		var mouth: Vector2 = flow.approach_point(p, FLANK_RADIUS)
		if mouth.x != INF:
			p = mouth
	return Vector2(p.x - origin.x, p.y - origin.z).angle()


## A spot just off-screen where this zombie can stand and from which it can walk to the target; (INF, 0, 0) if none.
## First on the ring spawn_distance_min..max around the target; in a narrow street most of the ring is inside buildings,
## so then anywhere within spawn_max_walk_distance of walking that is at least the ring's inner radius away in a line.
func _spawn_point(data: EnemyData) -> Vector3:
	var origin: Vector3 = target.global_position
	for attempt: int in SPAWN_TRIES:
		var dist: float = rng.randf_range(config.spawn_distance_min, config.spawn_distance_max)
		var pos: Vector3 = origin + Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * dist
		pos.y = 0.0
		if _usable(pos, data):
			return _snapped(pos)
	if walk_grid == null or flow == null or not flow.is_ready() or config.spawn_max_walk_distance <= 0.0:
		return Vector3(INF, 0.0, 0.0)
	var reach: float = config.spawn_max_walk_distance
	for attempt: int in SPAWN_TRIES * 2:
		var pos: Vector3 = origin + Vector3(rng.randf_range(-reach, reach), 0.0, rng.randf_range(-reach, reach))
		pos.y = 0.0
		var flat: float = Vector2(pos.x - origin.x, pos.z - origin.z).length()
		if flat >= config.spawn_distance_min * FALLBACK_MIN_SHARE and _usable(pos, data):
			return _snapped(pos)
	return Vector3(INF, 0.0, 0.0)


func _usable(pos: Vector3, data: EnemyData) -> bool:
	if not _in_bounds(pos, 1.0):
		return false
	var p: Vector3 = _snapped(pos)
	if p.x == INF:
		return false
	if flow != null and flow.is_ready() and config.spawn_max_walk_distance > 0.0:
		if flow.distance_at(Vector2(p.x, p.z)) > config.spawn_max_walk_distance:
			return false
	return _is_free(p, tuning.zombie_radius(data))


## `pos` moved to the nearest free spot connected to the player start (within 2 m), or unchanged without a walk grid.
func _snapped(pos: Vector3) -> Vector3:
	if walk_grid == null:
		return pos
	var free: Vector2 = walk_grid.nearest_open(Vector2(pos.x, pos.z), 2.0)
	return Vector3(free.x, 0.0, free.y) if free.x != INF else Vector3(INF, 0.0, 0.0)


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
	if _bearing_cache.size() > _alive.size() * 2 + 16:
		_bearing_cache.clear()  # Entries of freed zombies.


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
