@tool
class_name HordeSpawner
extends Marker3D
## A waiting horde around this marker (e.g. the helicopter crash). The horde is stored as data and only turns into real
## zombies while the player is within activation_radius; when the player leaves, the zombies are freed again and
## remembered where they stood (performance: hundreds of far-away zombies never cost physics or rendering).
## Zombies stay idle until the player gets within aggro_radius or shoots them.

signal zombie_spawned(zombie: Zombie)

@export var zombie_scene: PackedScene
@export var enemies: Array[EnemyData] = []
@export_range(1, 300) var count: int = 30
## Radius in metres around the spawner.
@export_range(0.5, 40) var scatter_radius: float = 6.0
@export_range(1, 60) var aggro_radius: float = 10.5
## Zombies within this distance of the player exist as real nodes. The level copies it from the DirectorConfig.
@export_range(5, 200) var activation_radius: float = 40.0
## Active zombies farther than this are freed again (larger than activation_radius so they do not flicker).
@export_range(5, 250) var deactivation_radius: float = 50.0
## Seconds between distance checks.
@export_range(0.05, 2.0, 0.05) var check_interval: float = 0.25
## At most this many zombies are instanced per check, so walking into a horde does not hitch.
@export_range(1, 100) var max_activations_per_check: int = 10
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

## One member of the horde: what it is, where it stands while asleep and its live node (if any).
class Slot extends RefCounted:
	var enemy: EnemyData
	var position: Vector3
	var zombie: Zombie

## Balance numbers for the zombies this horde wakes (the level injects them; null uses GameTuning defaults).
var tuning: GameTuning
## Callable() -> float giving run time elapsed, so a horde woken late is as tough as the zombies around it.
var elapsed_provider: Callable
var _slots: Array[Slot] = []
var _target: Node3D
var _container: Node
var _timer: float = 0.0


func _ready() -> void:
	show_wreck = show_wreck
	set_process(false)


## Plans the horde. Zombies near the player are instanced right away, the rest wait as data.
func spawn(target: Node3D, container: Node, rng: RandomNumberGenerator) -> void:
	if enemies.is_empty() or zombie_scene == null:
		return
	_target = target
	_container = container
	for i: int in count:
		var slot: Slot = Slot.new()
		slot.enemy = enemies[rng.randi() % enemies.size()]
		var offset: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * (2.5 + sqrt(rng.randf()) * scatter_radius)
		slot.position = global_position + offset
		_slots.append(slot)
	_refresh()
	set_process(true)


## Horde members not yet killed (asleep or awake).
func remaining() -> int:
	return _slots.size()


## Horde members currently instanced as real zombies.
func active_count() -> int:
	var n: int = 0
	for slot: Slot in _slots:
		if slot.zombie != null:
			n += 1
	return n


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = check_interval
		_refresh()


func _refresh() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var origin: Vector3 = _target.global_position
	var wake_sq: float = activation_radius * activation_radius
	var sleep_sq: float = deactivation_radius * deactivation_radius
	var woken: int = 0
	for slot: Slot in _slots:
		if slot.zombie != null:
			if not is_instance_valid(slot.zombie):
				slot.zombie = null
			elif _flat_dist_sq(slot.zombie.global_position, origin) > sleep_sq:
				slot.position = slot.zombie.global_position
				slot.zombie.queue_free()
				slot.zombie = null
		elif woken < max_activations_per_check and _flat_dist_sq(slot.position, origin) <= wake_sq:
			_wake(slot)
			woken += 1


func _wake(slot: Slot) -> void:
	var z: Zombie = zombie_scene.instantiate() as Zombie
	z.setup(slot.enemy, _target, aggro_radius, tuning, float(elapsed_provider.call()) if elapsed_provider.is_valid() else 0.0)
	z.position = slot.position
	slot.zombie = z
	z.died.connect(func(_z: Zombie, _xp: float, _at: Vector3) -> void: _slots.erase(slot))
	zombie_spawned.emit(z)
	_container.add_child(z)


func _flat_dist_sq(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length_squared()
