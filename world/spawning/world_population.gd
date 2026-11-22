class_name WorldPopulation
extends Node
## Zombies that live in the world: planned as data across the whole map (PopulationGrid), turned into real zombies while
## the player is within the activation radius and back into data when the player leaves. Running therefore never leaves
## the player in an empty street, and only the zombies near the player cost nodes and physics.
## A killed zombie leaves its slot empty and may come back after GameTuning.respawn_seconds, while the player is far away.

signal zombie_spawned(zombie: Zombie)

@export var zombie_scene: PackedScene
## Zombie types and the activation radii (the same ones hordes use).
@export var config: DirectorConfig
## Seconds between checks of who should wake or sleep.
@export_range(0.05, 2.0, 0.05) var check_interval: float = 0.25
## At most this many zombies are instanced per check, so running into a crowd does not hitch.
@export_range(1, 50) var max_wakes_per_check: int = 6
## Edge of a planning cell in metres.
@export_range(4, 50, 1) var cell_size: float = 10.0

var tuning: GameTuning
var target: Node3D
var container: Node3D
var bounds: Rect2 = Rect2(0, 0, 100, 100)
var elapsed_provider: Callable
## Scales the world density (the graphics profile lowers it on phones).
var population_scale: float = 1.0
var active: bool = false
var grid: PopulationGrid
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _timer: float = 0.0
var _live: Dictionary = {}


## Call down: plan the world. `start_position` (x, z) is kept free of zombies within GameTuning.start_safe_radius.
func start(chase_target: Node3D, zombie_container: Node3D, level_bounds: Rect2, random: RandomNumberGenerator, elapsed: Callable, game_tuning: GameTuning, start_position: Vector3) -> void:
	target = chase_target
	container = zombie_container
	bounds = level_bounds
	elapsed_provider = elapsed
	tuning = game_tuning if game_tuning != null else GameTuning.fallback()
	_rng.seed = random.randi()
	grid = PopulationGrid.new(bounds, random.randi(), tuning.world_density_max(), cell_size, Vector2(start_position.x, start_position.z), tuning.start_safe_radius)
	active = true
	_timer = 0.0


## Zombies of the world currently instanced as real nodes.
func awake_count() -> int:
	return grid.awake_count() if grid != null else 0


func _physics_process(delta: float) -> void:
	tick(delta)


## Advances the check timer; also called by tests that drive the population without waiting for frames.
func tick(delta: float) -> void:
	if not active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = check_interval
		refresh()


## Wakes and sleeps slots around the player now.
func refresh() -> void:
	if not active or target == null or not is_instance_valid(target):
		return
	var elapsed: float = _elapsed()
	for slot: PopulationGrid.Slot in grid.awake_slots():
		var z: Zombie = _live_zombie(slot)
		if z != null:
			slot.live_position = z.global_position
	var plan: PopulationGrid.Plan = grid.plan(target.global_position, elapsed, tuning.world_density_fraction(elapsed, population_scale), config.horde_activation_radius, config.horde_deactivation_radius, max_wakes_per_check)
	for slot: PopulationGrid.Slot in plan.sleep:
		var z: Zombie = _live_zombie(slot)
		_live.erase(slot)
		if z != null:
			z.queue_free()
		grid.sleep_slot(slot)
	for slot: PopulationGrid.Slot in plan.wake:
		_wake(slot, elapsed)


func _wake(slot: PopulationGrid.Slot, elapsed: float) -> void:
	if slot.enemy == null:
		slot.enemy = config.pick(elapsed, tuning, _rng, Zombie.count_by_type(get_tree()))
		if slot.enemy == null:
			grid.kill_slot(slot)
			return
	var pos: Vector3 = _free_position(slot.position, tuning.zombie_radius(slot.enemy))
	if pos.x == INF:
		# Walled in (inside a building): this slot never holds a zombie.
		grid.kill_slot(slot)
		return
	slot.position = pos
	var z: Zombie = zombie_scene.instantiate() as Zombie
	z.setup(slot.enemy, target, tuning.zombie_aggro_radius, tuning, elapsed)
	z.position = pos
	z.died.connect(_on_slot_zombie_died.bind(slot))
	_live[slot] = z
	grid.wake_slot(slot)
	zombie_spawned.emit(z)
	container.add_child(z)


func _on_slot_zombie_died(_zombie: Zombie, _xp: float, _at: Vector3, slot: PopulationGrid.Slot) -> void:
	_live.erase(slot)
	var again: float = _elapsed() + tuning.respawn_seconds if tuning.respawn_seconds > 0.0 else INF
	grid.kill_slot(slot, again)


## `pos` if nothing solid is there, else the nearest free spot within a few metres, else (INF, 0, 0).
func _free_position(pos: Vector3, radius: float) -> Vector3:
	if _is_free(pos, radius):
		return pos
	for attempt: int in 8:
		var candidate: Vector3 = pos + Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU) * _rng.randf_range(1.0, 3.0)
		if bounds.grow(-1.0).has_point(Vector2(candidate.x, candidate.z)) and _is_free(candidate, radius):
			return candidate
	return Vector3(INF, 0.0, 0.0)


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


## The zombie living in this slot, or null when there is none or it was freed from outside (checked before the cast).
func _live_zombie(slot: PopulationGrid.Slot) -> Zombie:
	var value: Variant = _live.get(slot)
	if value == null or not is_instance_valid(value):
		return null
	return value as Zombie
