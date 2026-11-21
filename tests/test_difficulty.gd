extends TestCase
## Difficulty ramp, spawn table (boss timing and cap), boss size, lazy horde activation and ambient culling.

const ZOMBIE: PackedScene = preload("res://world/enemies/zombie.tscn")
const WALKER: EnemyData = preload("res://data/enemies/walker.tres")
const BOSS: EnemyData = preload("res://data/enemies/boss.tres")
const DIRECTOR_CONFIG: DirectorConfig = preload("res://data/config/director_default.tres")


func _ready() -> void:
	run_all()


func test_ramp_node_free() -> void:
	var c: DirectorConfig = DirectorConfig.new()
	c.ramp_seconds = 100.0
	check_eq(c.ramp(-5.0), 0.0, "ramp clamps low")
	check_eq(c.ramp(500.0), 1.0, "ramp clamps high")
	check_eq(c.speed_multiplier(0.0), c.speed_multiplier_start, "speed at start")
	check_eq(c.speed_multiplier(100.0), c.speed_multiplier_end, "speed at end")
	check_eq(c.speed_multiplier(50.0), (c.speed_multiplier_start + c.speed_multiplier_end) / 2.0, "speed halfway")
	check(c.speed_multiplier_end > c.speed_multiplier_start, "speed ramps up")
	check(c.max_alive_at(100.0) > c.max_alive_at(0.0), "max alive ramps up")
	check(c.batch_at(100.0) > c.batch_at(0.0), "batch ramps up")
	check(c.interval_at(100.0) < c.interval_at(0.0), "interval shrinks")
	check(c.health_multiplier(100.0) > c.health_multiplier(0.0), "health ramps up")
	check(DIRECTOR_CONFIG.max_alive_at(0.0) >= 20 and DIRECTOR_CONFIG.max_alive_at(DIRECTOR_CONFIG.ramp_seconds) <= 100, "fewer zombies than before, but still a crowd")


func test_boss_spawn_table() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var early: int = 0
	for i: int in 400:
		if DIRECTOR_CONFIG.pick(30.0, rng) == BOSS:
			early += 1
	check_eq(early, 0, "no boss before its min time")
	var boss_min: float = 0.0
	for e: SpawnEntry in DIRECTOR_CONFIG.spawn_table:
		if e.enemy == BOSS:
			boss_min = e.min_elapsed_seconds
	check(boss_min > 0.0, "boss has a min time (%s)" % boss_min)
	var count_at := func(elapsed: float) -> int:
		var n: int = 0
		for i: int in 3000:
			if DIRECTOR_CONFIG.pick(elapsed, rng) == BOSS:
				n += 1
		return n
	var mid: int = count_at.call(boss_min + 1.0)
	var late: int = count_at.call(DIRECTOR_CONFIG.ramp_seconds)
	check(mid > 0, "boss appears after min time")
	check(late > mid * 2, "boss gets more frequent (%d -> %d)" % [mid, late])
	var capped: Dictionary = {BOSS: BOSS.max_alive}
	var hits: int = 0
	for i: int in 2000:
		if DIRECTOR_CONFIG.pick(DIRECTOR_CONFIG.ramp_seconds, rng, capped) == BOSS:
			hits += 1
	check_eq(hits, 0, "boss never picked at its alive cap")


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
	z.data = WALKER
	z.health_multiplier = 2.0
	add_child(z)
	check_eq(z.health, WALKER.max_health * 2.0, "health multiplier applied")
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
	d.start(player, holder, Rect2(-200, -200, 400, 400), rng, func() -> float: return 0.0)
	await wait_frames(4)
	var n: int = d.alive_count()
	check(n >= DIRECTOR_CONFIG.initial_burst / 2, "initial burst spawned (%d)" % n)
	var z: Zombie = holder.get_child(0) as Zombie
	check(z.speed_multiplier == DIRECTOR_CONFIG.speed_multiplier(0.0), "speed multiplier injected")
	var far: Zombie = holder.get_child(0) as Zombie
	far.global_position = Vector3(DIRECTOR_CONFIG.despawn_distance + 20.0, 0, 0)
	await wait_frames(3)
	check(not is_instance_valid(far) or far.is_queued_for_deletion(), "far zombie freed")
	d.queue_free()
	holder.queue_free()
	player.queue_free()
