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
signal player_fired(weapon: WeaponData)
## A player bullet damaged a zombie.
signal zombie_hit
signal health_collected
## A destructible prop was destroyed; `explosive` is true when it blew up.
signal prop_destroyed(at: Vector3, explosive: bool)

@export var player_scene: PackedScene
@export var zombie_scene: PackedScene
@export var gear_scene: PackedScene
@export var health_scene: PackedScene
@export var blood_scene: PackedScene
## Small droplet burst spawned where a zombie is hit.
@export var blood_hit_scene: PackedScene
## Height above the zombie origin where hit blood appears.
@export_range(0, 3, 0.1) var blood_hit_height: float = 1.0
## Most hit bursts alive at once (extra hits in a big fight are skipped).
@export_range(1, 200) var max_hit_effects: int = 24
## Most blood splats (decal + burst) alive at once; the oldest is replaced.
@export_range(1, 500) var max_blood_splats: int = 80
## Visual effect spawned when a destructible prop explodes.
@export var blast_scene: PackedScene
## Fraction of a blast's damage passed on to nearby destructibles (chain reactions).
@export_range(0, 2, 0.05) var chain_damage_fraction: float = 0.6
## Delay before a chained prop takes its blast damage, so chains ripple instead of popping at once.
@export_range(0, 2, 0.05) var chain_delay: float = 0.15
@export var default_run_config: RunConfig
@export var default_player_config: PlayerConfig
## Balance numbers used when the level runs on its own (game flow injects its own).
@export var default_tuning: GameTuning
## Playable area on the ground plane in metres: x = world X, y = world Z.
@export var bounds: Rect2 = Rect2(0, 0, 100, 100)

@onready var entities: Node3D = $Entities
@onready var projectiles: Node3D = $Projectiles
@onready var effects: Node3D = $Effects
@onready var director: ZombieDirector = $ZombieDirector
@onready var population: WorldPopulation = $WorldPopulation
@onready var extraction: ExtractionZone = $ExtractionZone
@onready var arrow: ObjectiveArrow = $ObjectiveArrow
@onready var camera_rig: IsoCamera = $IsoCamera
@onready var buildings: Node3D = $Buildings
@onready var navigation: StreetNavigation = $StreetNavigation

var player: Player
var stats: PlayerStats
var tuning: GameTuning
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _gears: Array[GearPickup] = []
var _started: bool = false
var _graphics: GraphicsProfile
var _static_lights: Array[Light3D] = []
var _light_timer: float = 0.0


var _hit_spawner: EffectSpawner
var _splat_spawner: EffectSpawner


func _ready() -> void:
	_hit_spawner = EffectSpawner.new()
	_hit_spawner.max_live = max_hit_effects
	add_child(_hit_spawner)
	_splat_spawner = EffectSpawner.new()
	_splat_spawner.max_live = max_blood_splats
	_splat_spawner.replace_oldest = true
	add_child(_splat_spawner)
	extraction.player_entered.connect(func() -> void: extraction_entered.emit())
	if get_parent() == get_tree().root:
		# Launched on its own: run with defaults.
		start.call_deferred(PlayerStats.new(default_player_config, default_tuning), default_run_config, RandomNumberGenerator.new(), Callable(), default_tuning)


## Call down: spawn the player, gears and hordes and start the director.
func start(player_stats: PlayerStats, run_config: RunConfig, random: RandomNumberGenerator, elapsed_provider: Callable, game_tuning: GameTuning = null) -> void:
	if _started:
		return
	_started = true
	stats = player_stats
	rng = random
	tuning = game_tuning if game_tuning != null else (default_tuning if default_tuning != null else GameTuning.fallback())
	var cfg: RunConfig = run_config if run_config != null else RunConfig.new()
	Zombie.max_corpses = director.config.max_corpses
	navigation.build(bounds, player_start_position(), solid_roots())
	_spawn_player()
	navigation.track(player)
	_spawn_gears(cfg.gears_required)
	for node: Node in $Hordes.get_children():
		var spawner: HordeSpawner = node as HordeSpawner
		if spawner != null:
			spawner.zombie_spawned.connect(_on_zombie_spawned)
			spawner.activation_radius = director.config.horde_activation_radius
			spawner.deactivation_radius = director.config.horde_deactivation_radius
			spawner.tuning = tuning
			spawner.walk_grid = navigation.walk_grid
			spawner.elapsed_provider = elapsed_provider
			spawner.spawn(player, entities, rng)
	for node: Node in find_children("Destructible", "", true, false):
		var prop: Destructible = node as Destructible
		if prop != null:
			prop.destroyed.connect(_on_prop_destroyed)
	director.zombie_spawned.connect(_on_zombie_spawned)
	director.walk_grid = navigation.walk_grid
	director.flow = navigation.flow
	director.start(player, entities, bounds, rng, elapsed_provider, tuning)
	population.zombie_spawned.connect(_on_zombie_spawned)
	population.walk_grid = navigation.walk_grid
	population.start(player, entities, bounds, rng, elapsed_provider, tuning, player_start_position())
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


func gear_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for g: GearPickup in _gears:
		if is_instance_valid(g):
			out.append(g.global_position)
	return out


## The nodes holding the level's solid scenery (walls, fences, cars, wrecks): what StreetNavigation and the layout
## tests draw onto the walk grid.
func solid_roots() -> Array[Node]:
	var roots: Array[Node] = []
	for root_name: String in ["Buildings", "Fences", "Props", "Hordes"]:
		var node: Node = get_node_or_null(root_name)
		if node != null:
			roots.append(node)
	return roots


func player_start_position() -> Vector3:
	return ($PlayerStart as Node3D).global_position


## Call down: apply a rendering budget (shadows, glow, fog, how many static lights stay on).
func apply_graphics(profile: GraphicsProfile) -> void:
	_graphics = profile
	director.population_scale = profile.zombie_population_scale
	population.population_scale = profile.zombie_population_scale
	navigation.flow_cells_per_frame = profile.flow_cells_per_frame
	var env_node: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node != null and env_node.environment != null:
		env_node.environment = env_node.environment.duplicate() as Environment
		env_node.environment.glow_enabled = profile.glow
		env_node.environment.fog_enabled = profile.fog
	var moon: DirectionalLight3D = get_node_or_null("Moon") as DirectionalLight3D
	if moon != null:
		moon.shadow_enabled = profile.shadows
	var ground: Ground = get_node_or_null("Ground") as Ground
	if ground != null:
		ground.set_detail(profile.detailed_ground)
	_static_lights.clear()
	for root_name: String in ["Props", "Hordes", "ExtractionZone"]:
		var root: Node = get_node_or_null(root_name)
		if root != null:
			for node: Node in root.find_children("*", "Light3D", true, false):
				var light: Light3D = node as Light3D
				if light != null and not (light is DirectionalLight3D):
					light.shadow_enabled = light.shadow_enabled and profile.shadows
					_static_lights.append(light)
	_light_timer = 0.0


## Number of static lights currently switched on (for tests and diagnostics).
func static_lights_on() -> int:
	var count: int = 0
	for light: Light3D in _static_lights:
		if is_instance_valid(light) and light.is_visible_in_tree():
			count += 1
	return count


func _process(delta: float) -> void:
	if not _started or player == null:
		return
	_update_objective()
	_update_occlusion()
	_update_light_budget(delta)


## Keeps only the N static lights nearest to the player on (mobile GPUs cannot afford dozens of dynamic lights).
func _update_light_budget(delta: float) -> void:
	if _graphics == null or _graphics.max_static_lights <= 0:
		return
	_light_timer -= delta
	if _light_timer > 0.0:
		return
	_light_timer = _graphics.light_refresh_seconds
	_static_lights = _static_lights.filter(func(l: Light3D) -> bool: return is_instance_valid(l))
	var origin: Vector3 = player.global_position
	# Lights under a hidden parent (wrecked car beams, flames not yet burning) do not take a slot.
	var sorted: Array[Light3D] = _static_lights.filter(func(l: Light3D) -> bool:
		var parent: Node3D = l.get_parent() as Node3D
		return parent == null or parent.is_visible_in_tree())
	sorted.sort_custom(func(a: Light3D, b: Light3D) -> bool:
		return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	for i: int in sorted.size():
		sorted[i].visible = i < _graphics.max_static_lights


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
	player.set_body_scale(tuning.character_scale)
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
	player.fired.connect(func(w: WeaponData) -> void:
		player_fired.emit(w)
		get_tree().call_group(Zombie.GROUP, "alert", player.global_position, tuning.gunfire_alert_radius)
	)
	player.hit_landed.connect(func(_a: float) -> void: zombie_hit.emit())


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
	zombie.flow = navigation.flow
	zombie.died.connect(_on_zombie_died)
	zombie.damaged.connect(_on_zombie_damaged)
	zombie.attacked.connect(_on_zombie_attacked)


func _on_zombie_damaged(at: Vector3, direction: Vector3, _amount: float) -> void:
	var dir: Vector3 = Vector3(direction.x, 0.0, direction.z)
	_hit_spawner.spawn(blood_hit_scene, effects, at + Vector3(0, blood_hit_height, 0), dir.normalized() + Vector3(0, 0.35, 0))


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
	prop_destroyed.emit(at, radius > 0.0)
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
	_splat_spawner.spawn(blood_scene, effects, Vector3(at.x, 0.0, at.z))


func _spawn_health(at: Vector3) -> void:
	var hp: HealthPickup = health_scene.instantiate() as HealthPickup
	hp.position = Vector3(at.x, 0.0, at.z)
	hp.collector = player
	hp.radius_provider = player.get_pickup_radius
	hp.collected.connect(func(p: Pickup) -> void:
		player.heal((p as HealthPickup).heal_amount)
		health_collected.emit()
	)
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
