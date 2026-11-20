class_name Level
extends Node3D
## A playable map. Owns its entities and reports gameplay events upward; the run rules live in game flow.
## Runs on its own (F6) with default config.

signal zombie_killed(xp: float, at: Vector3)
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
@export var blood_scene: PackedScene
## Visual effect spawned when a destructible prop explodes.
@export var blast_scene: PackedScene
## Fraction of a blast's damage passed on to nearby destructibles (chain reactions).
@export_range(0, 2, 0.05) var chain_damage_fraction: float = 0.6
## Delay before a chained prop takes its blast damage, so chains ripple instead of popping at once.
@export_range(0, 2, 0.05) var chain_delay: float = 0.15
@export var default_run_config: RunConfig
@export var default_player_config: PlayerConfig
## Playable area on the ground plane in metres: x = world X, y = world Z.
@export var bounds: Rect2 = Rect2(0, 0, 100, 100)

@onready var entities: Node3D = $Entities
@onready var projectiles: Node3D = $Projectiles
@onready var effects: Node3D = $Effects
@onready var director: ZombieDirector = $ZombieDirector
@onready var extraction: ExtractionZone = $ExtractionZone
@onready var arrow: ObjectiveArrow = $ObjectiveArrow
@onready var camera_rig: IsoCamera = $IsoCamera
@onready var buildings: Node3D = $Buildings

var player: Player
var stats: PlayerStats
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _gears: Array[GearPickup] = []
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
	var cfg: RunConfig = run_config if run_config != null else RunConfig.new()
	_spawn_player()
	_spawn_gears(cfg.gears_required)
	for node: Node in $Hordes.get_children():
		var spawner: HordeSpawner = node as HordeSpawner
		if spawner != null:
			spawner.zombie_spawned.connect(_on_zombie_spawned)
			spawner.spawn(player, entities, rng)
	for node: Node in find_children("Destructible", "", true, false):
		var prop: Destructible = node as Destructible
		if prop != null:
			prop.destroyed.connect(_on_prop_destroyed)
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
func set_touch_input(move: Vector2, aim: Vector2, touching: bool = false) -> void:
	if player != null:
		player.input.set_touch(move, aim, touching)


func toggle_sprint() -> void:
	if player != null:
		player.input.request_sprint_toggle()


func gear_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for g: GearPickup in _gears:
		if is_instance_valid(g):
			out.append(g.global_position)
	return out


func player_start_position() -> Vector3:
	return ($PlayerStart as Node3D).global_position


func _process(_delta: float) -> void:
	if not _started or player == null:
		return
	_update_objective()
	_update_occlusion()


func _update_occlusion() -> void:
	var cam: Camera3D = camera_rig.camera
	var focus: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var to_cam: Vector3 = cam.global_position - focus
	var horizontal: Vector3 = Vector3(to_cam.x, 0.0, to_cam.z)
	if horizontal.length() < 0.01:
		return
	var tan_pitch: float = to_cam.y / horizontal.length()
	var dir: Vector3 = horizontal.normalized()
	for node: Node in buildings.get_children():
		var b: Building = node as Building
		if b != null:
			b.update_occlusion(player.global_position, dir, tan_pitch)


func _spawn_player() -> void:
	player = player_scene.instantiate() as Player
	player.position = player_start_position()
	entities.add_child(player)
	player.setup(stats, projectiles)
	player.set_view(camera_rig)
	camera_rig.target = player
	camera_rig.snap()
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
		gear.position = (points[i] as Node3D).global_position
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


func _on_zombie_died(_zombie: Zombie, xp: float, at: Vector3) -> void:
	zombie_killed.emit(xp, at)
	if blood_scene != null:
		_spawn_blood.call_deferred(at)
	if stats.has_flag(PlayerStats.Flag.NO_HEALTH_PICKUPS):
		return
	if rng.randf() < stats.get_value(PlayerStats.Stat.HEALTH_DROP_CHANCE):
		_spawn_health.call_deferred(at)


func _on_prop_destroyed(at: Vector3, radius: float, damage: float) -> void:
	if radius > 0.0:
		_blast.call_deferred(at, radius, damage)


## A prop explosion: damages zombies, the player and other destructibles inside the radius (falloff to half).
func _blast(at: Vector3, radius: float, damage: float) -> void:
	if blast_scene != null:
		var fx: Node3D = blast_scene.instantiate() as Node3D
		fx.position = at + Vector3(0, 0.8, 0)
		fx.set("radius", radius)
		fx.set("lifetime", 0.5)
		effects.add_child(fx)
	for node: Node in get_tree().get_nodes_in_group(Zombie.GROUP):
		var z: Zombie = node as Zombie
		if z != null and not z.is_dead:
			var off: Vector3 = Vector3(z.global_position.x - at.x, 0.0, z.global_position.z - at.z)
			if off.length() <= radius:
				z.take_damage(damage * lerpf(1.0, 0.5, off.length() / radius), off.normalized())
	if player != null:
		var poff: Vector3 = Vector3(player.global_position.x - at.x, 0.0, player.global_position.z - at.z)
		if poff.length() <= radius + player.body_radius:
			player.take_damage(damage * lerpf(1.0, 0.5, clampf(poff.length() / radius, 0.0, 1.0)))
	for node: Node in find_children("Destructible", "", true, false):
		var prop: Destructible = node as Destructible
		var body: Node3D = prop.get_parent() as Node3D if prop != null else null
		if prop == null or prop.is_destroyed or body == null:
			continue
		var d: float = Vector2(body.global_position.x - at.x, body.global_position.z - at.z).length()
		if d <= radius and d > 0.1:
			get_tree().create_timer(chain_delay, false).timeout.connect(_chain_damage.bind(weakref(prop), damage * chain_damage_fraction))


func _chain_damage(prop_ref: WeakRef, amount: float) -> void:
	var prop: Destructible = prop_ref.get_ref() as Destructible
	if prop != null:
		prop.take_damage(amount)


func _spawn_blood(at: Vector3) -> void:
	var splat: Node3D = blood_scene.instantiate() as Node3D
	splat.position = Vector3(at.x, 0.0, at.z)
	effects.add_child(splat)


func _spawn_health(at: Vector3) -> void:
	var hp: HealthPickup = health_scene.instantiate() as HealthPickup
	hp.position = Vector3(at.x, 0.0, at.z)
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
	var best: Vector3 = Vector3.ZERO
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
