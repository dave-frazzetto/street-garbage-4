extends TestCase
## Difficulty ramp, spawn table (boss timing and cap), boss size, lazy horde activation and ambient culling.

const ZOMBIE: PackedScene = preload("res://world/enemies/zombie.tscn")
const WALKER: EnemyData = preload("res://data/enemies/walker.tres")
const BOSS: EnemyData = preload("res://data/enemies/boss.tres")
const ARMOURED: EnemyData = preload("res://data/enemies/armoured.tres")
const DIRECTOR_CONFIG: DirectorConfig = preload("res://data/config/director_default.tres")
const TUNING: GameTuning = preload("res://data/config/game_tuning.tres")


func _ready() -> void:
	run_all()


func test_ramp_node_free() -> void:
	var t: GameTuning = GameTuning.new()
	t.ramp_seconds = 100.0
	check_eq(t.ramp(-5.0), 0.0, "ramp clamps low")
	check_eq(t.ramp(500.0), 1.0, "ramp clamps high")
	var w: float = t.zombie_speed(WALKER, 0.0)
	check_eq(t.zombie_speed(WALKER, 100.0), w * (1.0 + t.zombie_speed_growth), "speed at end of ramp")
	check_eq(t.zombie_speed(WALKER, 50.0), w * (1.0 + t.zombie_speed_growth * 0.5), "speed halfway")
	check(t.zombie_max_health(WALKER, 100.0) > t.zombie_max_health(WALKER, 0.0), "health ramps up")
	check(t.zombie_xp(WALKER, 100.0) > t.zombie_xp(WALKER, 0.0), "xp rises with health")
	check(t.trickle_alive(100.0) >= t.trickle_alive(0.0), "trickle ramps up")
	check(t.world_density(100.0) > t.world_density(0.0), "world density ramps up")
	check_eq(t.world_density_fraction(100.0), 1.0, "all planned world zombies exist at full ramp")
	check(t.world_density_fraction(0.0) < 1.0, "fewer at the start")
	check(DIRECTOR_CONFIG.interval_at(t, 100.0) < DIRECTOR_CONFIG.interval_at(t, 0.0), "interval shrinks")
	check(DIRECTOR_CONFIG.batch_at(t, 100.0) > DIRECTOR_CONFIG.batch_at(t, 0.0), "batch grows")


func test_boss_spawn_table() -> void:
	var t: GameTuning = TUNING
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var early: int = 0
	for i: int in 400:
		if DIRECTOR_CONFIG.pick(t.boss_start_seconds - 1.0, t, rng) == BOSS:
			early += 1
	check_eq(early, 0, "no boss before its start time")
	var count_at := func(elapsed: float) -> int:
		var n: int = 0
		for i: int in 6000:
			if DIRECTOR_CONFIG.pick(elapsed, t, rng) == BOSS:
				n += 1
		return n
	var mid: int = count_at.call(t.boss_start_seconds + 1.0)
	var late: int = count_at.call(t.ramp_seconds)
	check(mid > 0, "boss appears after its start time")
	check(late > mid * 1.5, "boss gets more frequent (%d -> %d)" % [mid, late])
	check(late < 6000 * 0.04, "bosses stay a small share (%d of 6000)" % late)
	var capped: Dictionary = {BOSS: BOSS.max_alive}
	var hits: int = 0
	for i: int in 3000:
		if DIRECTOR_CONFIG.pick(t.ramp_seconds, t, rng, capped) == BOSS:
			hits += 1
	check_eq(hits, 0, "boss never picked at its alive cap")
	var armoured: int = 0
	for i: int in 3000:
		if DIRECTOR_CONFIG.pick(t.ramp_seconds, t, rng) == ARMOURED:
			armoured += 1
	check(absf(armoured / 3000.0 - t.elite_share_end) < 0.06, "armoured share near the tuned value (%d of 3000)" % armoured)


func test_boss_size_and_health() -> void:
	var w: Zombie = ZOMBIE.instantiate() as Zombie
	w.data = WALKER
	var b: Zombie = ZOMBIE.instantiate() as Zombie
	b.data = BOSS
	add_child(w)
	add_child(b)
	var wv: Node3D = w.get_node("Visual") as Node3D
	var bv: Node3D = b.get_node("Visual") as Node3D
	check_eq(bv.scale.x / wv.scale.x, 1.2, "boss model 1.2x walker (x)")
	check_eq(bv.scale.y / wv.scale.y, 1.2, "boss model 1.2x walker (y)")
	var ws: CylinderShape3D = (w.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
	var bs: CylinderShape3D = (b.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
	check_eq(bs.radius / ws.radius, 1.2, "boss collision radius 1.2x")
	check_eq(BOSS.radius, WALKER.radius * BOSS.size_scale, "data.radius consistent with size_scale")
	check(b.health > w.health * 5.0, "boss health >> walker")
	check((b.get_node("HealthBar") as Node3D).visible, "boss bar always shown")
	check(not (w.get_node("HealthBar") as Node3D).visible, "walker bar hidden")
	w.queue_free()
	b.queue_free()


func test_multipliers_applied() -> void:
	var z: Zombie = ZOMBIE.instantiate() as Zombie
	z.setup(WALKER, null, 0.0, TUNING, TUNING.ramp_seconds)
	add_child(z)
	check_eq(z.health, TUNING.zombie_health * (1.0 + TUNING.zombie_health_growth), "tuning health at full ramp applied")
	check_eq(z.max_health, z.health, "max health recorded")
	z.queue_free()


func test_lazy_horde() -> void:
	var player: Node3D = Node3D.new()
	add_child(player)
	player.position = Vector3(0, 0, 500)
	var holder: Node3D = Node3D.new()
	add_child(holder)
	var spawner: HordeSpawner = HordeSpawner.new()
	spawner.zombie_scene = ZOMBIE
	spawner.enemies = [WALKER]
	spawner.count = 25
	spawner.activation_radius = 30.0
	spawner.deactivation_radius = 40.0
	spawner.max_activations_per_check = 100
	add_child(spawner)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	spawner.spawn(player, holder, rng)
	check_eq(spawner.remaining(), 25, "25 planned")
	check_eq(spawner.active_count(), 0, "none instanced while far")
	check_eq(holder.get_child_count(), 0, "no nodes while far")
	player.position = Vector3(0, 0, 20)
	await wait_seconds(0.4)
	check_eq(spawner.active_count(), 25, "all instanced when near")
	check_eq(holder.get_child_count(), 25, "nodes exist when near")
	var victim: Zombie = holder.get_child(0) as Zombie
	victim.take_damage(99999.0)
	await wait_frames(2)
	check_eq(spawner.remaining(), 24, "killed zombie leaves the horde")
	player.position = Vector3(0, 0, 500)
	await wait_seconds(0.4)
	await wait_frames(2)
	check_eq(spawner.active_count(), 0, "freed again when far")
	check_eq(spawner.remaining(), 24, "still remembered")
	spawner.queue_free()
	holder.queue_free()
	player.queue_free()


func test_director_culls_far_zombies() -> void:
	var player: Node3D = Node3D.new()
	add_child(player)
	var holder: Node3D = Node3D.new()
	add_child(holder)
	var d: ZombieDirector = ZombieDirector.new()
	d.config = DIRECTOR_CONFIG
	d.zombie_scene = ZOMBIE
	add_child(d)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	d.start(player, holder, Rect2(-200, -200, 400, 400), rng, func() -> float: return 0.0, TUNING)
	await wait_frames(4)
	var n: int = d.alive_count()
	check(n >= mini(DIRECTOR_CONFIG.initial_burst, TUNING.trickle_alive(0.0)) / 2, "initial burst spawned (%d)" % n)
	var z: Zombie = holder.get_child(0) as Zombie
	check(z.max_health == TUNING.zombie_max_health(z.data, 0.0), "tuning injected into director zombies")
	var far: Zombie = holder.get_child(0) as Zombie
	far.global_position = Vector3(DIRECTOR_CONFIG.despawn_distance + 20.0, 0, 0)
	await wait_frames(3)
	check(not is_instance_valid(far) or far.is_queued_for_deletion(), "far zombie freed")
	d.queue_free()
	holder.queue_free()
	player.queue_free()
