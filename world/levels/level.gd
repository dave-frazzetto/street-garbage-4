class_name Level
extends Node2D
## A playable map. Owns its entities and reports gameplay events upward; the run rules live in game flow.
## Runs on its own (F6) with default config.

signal zombie_killed(xp: float, at: Vector2)
signal gear_collected
signal player_damaged(amount: float)
signal player_health_changed(current: float, maximum: float)
signal player_stamina_changed(current: float, maximum: float)
signal player_died
signal weapon_changed(weapon_name: String, seconds_left: float)
signal player_sprint_changed(sprinting: bool)
signal extraction_entered

@export var player_scene: PackedScene
@export var zombie_scene: PackedScene
@export var gear_scene: PackedScene
@export var health_scene: PackedScene
@export var default_run_config: RunConfig
@export var default_player_config: PlayerConfig
## Playable area; the director never spawns outside it.
@export var bounds: Rect2 = Rect2(0, 0, 4000, 4000)

@onready var entities: Node2D = $Entities
@onready var projectiles: Node2D = $Projectiles
@onready var director: ZombieDirector = $ZombieDirector
@onready var extraction: ExtractionZone = $ExtractionZone
@onready var arrow: ObjectiveArrow = $ObjectiveArrow

var player: Player
var stats: PlayerStats
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _gears: Array[GearPickup] = []
var _elapsed_provider: Callable
var _started: bool = false


func _ready() -> void:
	extraction.player_entered.connect(func() -> void: extraction_entered.emit())
	if get_parent() == get_tree().root:
		# Launched on its own: run with defaults.
		start.call_deferred(PlayerStats.new(default_player_config), default_run_config, RandomNumberGenerator.new(), Callable())


## Call down: spawn the player, gears and hordes and start the director.
func start(player_stats: PlayerStats, run_config: RunConfig, random: RandomNumberGenerator, elapsed_provider: Callable) -> void:
	if _started:
		return
	_started = true
	stats = player_stats
	rng = random
	_elapsed_provider = elapsed_provider
	var cfg: RunConfig = run_config if run_config != null else RunConfig.new()
	_spawn_player()
	_spawn_gears(cfg.gears_required)
	for node: Node in $Hordes.get_children():
		var spawner: HordeSpawner = node as HordeSpawner
		if spawner != null:
			spawner.zombie_spawned.connect(_on_zombie_spawned)
			spawner.spawn(player, entities, rng)
	director.zombie_spawned.connect(_on_zombie_spawned)
	director.start(player, entities, bounds, rng, elapsed_provider)
	arrow.follow = player
	_update_objective()


func set_extraction_unlocked(unlocked: bool) -> void:
	extraction.unlocked = unlocked
	_update_objective()


func equip_temporary_weapon(weapon: WeaponData, seconds: float) -> void:
	player.equip_temporary_weapon(weapon, seconds)


## Call down: on-screen stick vectors for this frame.
func set_touch_input(move: Vector2, aim: Vector2) -> void:
	if player != null:
		player.input.set_touch(move, aim)


func toggle_sprint() -> void:
	if player != null:
		player.input.request_sprint_toggle()


func gear_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for g: GearPickup in _gears:
		if is_instance_valid(g):
			out.append(g.global_position)
	return out


func _process(_delta: float) -> void:
	if _started:
		_update_objective()


func _spawn_player() -> void:
	player = player_scene.instantiate() as Player
	player.position = ($PlayerStart as Node2D).position
	entities.add_child(player)
	player.setup(stats, projectiles)
	player.health_changed.connect(func(c: float, m: float) -> void: player_health_changed.emit(c, m))
	player.stamina_changed.connect(func(c: float, m: float) -> void: player_stamina_changed.emit(c, m))
	player.damaged.connect(func(a: float) -> void: player_damaged.emit(a))
	player.died.connect(func() -> void: player_died.emit())
	player.weapon_changed.connect(func(n: String, t: float) -> void: weapon_changed.emit(n, t))
	player.sprint_changed.connect(func(on: bool) -> void: player_sprint_changed.emit(on))


func _spawn_gears(count: int) -> void:
	var points: Array[Node] = $GearSpawnPoints.get_children()
	# Fisher-Yates with the injected RNG so tests are deterministic.
	for i: int in range(points.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Node = points[i]
		points[i] = points[j]
		points[j] = tmp
	for i: int in mini(count, points.size()):
		var gear: GearPickup = gear_scene.instantiate() as GearPickup
		gear.position = (points[i] as Node2D).position
		gear.collector = player
		gear.radius_provider = player.get_pickup_radius
		gear.collected.connect(_on_gear_collected)
		entities.add_child(gear)
		_gears.append(gear)


func _on_gear_collected(pickup: Pickup) -> void:
	_gears.erase(pickup)
	gear_collected.emit()


func _on_zombie_spawned(zombie: Zombie) -> void:
	zombie.target_radius = player.body_radius
	zombie.died.connect(_on_zombie_died)
	zombie.attacked.connect(_on_zombie_attacked)


func _on_zombie_attacked(damage: float) -> void:
	player.take_damage(damage)


func _on_zombie_died(_zombie: Zombie, xp: float, at: Vector2) -> void:
	zombie_killed.emit(xp, at)
	if stats.has_flag(PlayerStats.Flag.NO_HEALTH_PICKUPS):
		return
	if rng.randf() < stats.get_value(PlayerStats.Stat.HEALTH_DROP_CHANCE):
		_spawn_health.call_deferred(at)


func _spawn_health(at: Vector2) -> void:
	var hp: HealthPickup = health_scene.instantiate() as HealthPickup
	hp.position = at
	hp.collector = player
	hp.radius_provider = player.get_pickup_radius
	hp.collected.connect(func(p: Pickup) -> void: player.heal((p as HealthPickup).heal_amount))
	entities.add_child(hp)


func _update_objective() -> void:
	if player == null:
		return
	if extraction.unlocked or _gears.is_empty():
		arrow.objective = extraction.global_position
		arrow.color = Color(0.3, 1.0, 0.5)
		arrow.has_objective = true
		return
	var best: Vector2 = Vector2.ZERO
	var best_d: float = INF
	for g: GearPickup in _gears:
		if is_instance_valid(g):
			var d: float = g.global_position.distance_squared_to(player.global_position)
			if d < best_d:
				best_d = d
				best = g.global_position
	arrow.objective = best
	arrow.color = Color(0.3, 0.7, 1.0)
	arrow.has_objective = best_d < INF
