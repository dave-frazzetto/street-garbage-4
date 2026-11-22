extends TestCase
## Integration test of the zombie pressure on the real level: a standing player is reached and hurt, a player running
## across the map always has zombies around, killed world zombies stay dead, far zombies are not nodes, and zombies lead
## a moving target, and chasers get round a wall. Needs simulated time: ALWAYS start it with --fixed-fps 60 (tests/run_tests.sh
## does; the engine then runs as fast as the CPU allows). Without the flag it runs in real time and takes about 100 s.

const LEVEL: PackedScene = preload("res://world/levels/freedom_city.tscn")
const ZOMBIE: PackedScene = preload("res://world/enemies/zombie.tscn")
const WALKER: EnemyData = preload("res://data/enemies/walker.tres")
const TUNING: GameTuning = preload("res://data/config/game_tuning.tres")
var level: Level
var _elapsed: float = 0.0


func _ready() -> void:
	run_all()


func _physics_process(delta: float) -> void:
	_elapsed += delta


func _start_level(elapsed_at_start: float = 0.0) -> void:
	_elapsed = elapsed_at_start
	level = LEVEL.instantiate() as Level
	add_child(level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	level.start(PlayerStats.new(PlayerConfig.new(), TUNING), RunConfig.new(), rng, func() -> float: return _elapsed, TUNING)
	level.player.health.max_health = 1000000.0
	level.player.health.current = 1000000.0


func _stop_level() -> void:
	level.queue_free()
	await wait_frames(2)
	level = null


func _live_zombies() -> Array[Zombie]:
	var out: Array[Zombie] = []
	for node: Node in get_tree().get_nodes_in_group(Zombie.GROUP):
		var z: Zombie = node as Zombie
		if z != null and not z.is_dead and not z.is_queued_for_deletion():
			out.append(z)
	return out


func _nearest_and_count(pos: Vector3, radius: float) -> Vector2:
	var nearest: float = INF
	var count: int = 0
	for z: Zombie in _live_zombies():
		var d: float = Vector2(z.global_position.x - pos.x, z.global_position.z - pos.z).length()
		nearest = minf(nearest, d)
		if d <= radius:
			count += 1
	return Vector2(nearest, count)


func test_1_a_standing_player_is_reached_and_hurt() -> void:
	_start_level()
	var hurt: Array[float] = [-1.0]
	var start_health: float = level.player.health.current
	level.player_damaged.connect(func(_a: float) -> void:
		if hurt[0] < 0.0:
			hurt[0] = _elapsed
	)
	await wait_frames(int(15.0 * 60.0))
	var hurt_at: float = hurt[0]
	print("  standing player first hurt at %.1f s" % hurt_at)
	check(hurt_at > 0.0, "a zombie reached the standing player")
	check(hurt_at < 15.0, "within 15 s of the start (hurt at %.1f s)" % hurt_at)
	check(level.player.health.current < start_health, "health went down")
	await _stop_level()


func test_2_running_across_the_map_always_has_zombies_around() -> void:
	_start_level()
	var lines: Array = [
		[Vector3(10, 0, 95), Vector3(10, 0, 8)],
		[Vector3(15, 0, 60), Vector3(110, 0, 60)],
		[Vector3(110, 0, 110), Vector3(30, 0, 30)],
		[Vector3(60, 0, 10), Vector3(60, 0, 110)],
	]
	var worst_nearest: float = 0.0
	var fewest_near: int = 1 << 20
	for line: Array in lines:
		var from: Vector3 = line[0]
		var to: Vector3 = line[1]
		level.player.global_position = from
		await wait_frames(60 * 3)
		var dir: Vector3 = (to - from).normalized()
		var steps: int = int(from.distance_to(to) / TUNING.sprint_speed() * 60.0)
		for i: int in steps:
			level.player.global_position += dir * TUNING.sprint_speed() / 60.0
			await wait_frames(1)
			if i % 30 == 0:
				var s: Vector2 = _nearest_and_count(level.player.global_position, 40.0)
				worst_nearest = maxf(worst_nearest, s.x)
				fewest_near = mini(fewest_near, int(s.y))
	print("  running: worst nearest zombie %.1f m, fewest within 40 m: %d" % [worst_nearest, fewest_near])
	check(worst_nearest <= 32.0, "a zombie was always within 32 m (worst %.1f m)" % worst_nearest)
	check(fewest_near >= 3, "at least 3 zombies were always within 40 m (fewest %d)" % fewest_near)
	var nodes: int = _live_zombies().size()
	check(nodes < 90, "far zombies are data, not nodes (%d nodes)" % nodes)
	await _stop_level()


func test_3_killed_world_zombies_stay_dead_and_far_ones_sleep() -> void:
	_start_level()
	level.player.global_position = Vector3(60, 0, 60)
	await wait_frames(90)
	var awake: int = level.population.awake_count()
	check(awake > 3, "world zombies woke around the player (%d)" % awake)
	var dead_before: int = _dead_slots()
	for z: Zombie in _live_zombies():
		z.take_damage(99999.0)
	await wait_frames(20)
	var dead_after: int = _dead_slots()
	check(dead_after >= dead_before + awake, "killed world zombies leave empty slots (%d -> %d)" % [dead_before, dead_after])
	await wait_frames(60)
	check(level.population.awake_count() == 0, "they do not respawn while the player stays (%d awake)" % level.population.awake_count())
	level.player.global_position = Vector3(110, 0, 5)
	await wait_frames(90)
	var nodes: int = _live_zombies().size()
	check(nodes < 60, "zombies far from the player are data again (%d nodes)" % nodes)
	await _stop_level()


func _dead_slots() -> int:
	var n: int = 0
	for s: PopulationGrid.Slot in level.population.grid.all_slots():
		if s.state == PopulationGrid.State.DEAD:
			n += 1
	return n


## Seconds until a chasing zombie catches a target that runs across its path at 3 m/s (a bit slower than the zombie); 99 if never.
func _time_to_catch(tuning: GameTuning, start_z: float) -> float:
	var holder: Node3D = Node3D.new()
	add_child(holder)
	var target: Node3D = Node3D.new()
	holder.add_child(target)
	var data: EnemyData = WALKER.duplicate() as EnemyData
	data.speed_variance = 0.0
	var z: Zombie = ZOMBIE.instantiate() as Zombie
	z.setup(data, target, 100000.0, tuning, 0.0)
	z.intercept_spread_min = 1.0
	z.position = Vector3(0, 0, start_z)
	holder.add_child(z)
	var caught: float = 99.0
	for i: int in 12 * 60:
		target.global_position += Vector3(3.0 / 60.0, 0, 0)
		await wait_frames(1)
		if Vector2(z.global_position.x - target.global_position.x, z.global_position.z - target.global_position.z).length() < 1.0:
			caught = i / 60.0
			break
	holder.queue_free()
	return caught


func test_4_zombies_lead_a_moving_target() -> void:
	var lead: GameTuning = GameTuning.new()
	lead.zombie_intercept = 1.0
	var plain: GameTuning = GameTuning.new()
	plain.zombie_intercept = 0.0
	var without: float = await _time_to_catch(plain, 14.0)
	var with_lead: float = await _time_to_catch(lead, 14.0)
	print("  catch times: straight %.1f s, leading %.1f s" % [without, with_lead])
	check(with_lead < 12.0, "a leading zombie catches a target running across its path (%.1f s)" % with_lead)
	check(with_lead < without - 1.5, "leading cuts the corner: %.1f s vs %.1f s chasing straight" % [with_lead, without])


## Seconds until a zombie reaches a target that stands right behind a wall (straight line blocked); 99 if it never does.
func _time_to_get_round_wall(follow_seconds: float) -> float:
	var holder: Node3D = Node3D.new()
	add_child(holder)
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	var wall_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(16.0, 3.0, 1.0)
	wall_shape.shape = box
	wall_shape.position.y = 1.5
	wall.add_child(wall_shape)
	holder.add_child(wall)
	var target: Node3D = Node3D.new()
	holder.add_child(target)
	target.global_position = Vector3(0, 0, -6)
	var data: EnemyData = WALKER.duplicate() as EnemyData
	data.speed_variance = 0.0
	var z: Zombie = ZOMBIE.instantiate() as Zombie
	z.setup(data, target, 100000.0, TUNING, 0.0)
	z.wall_follow_seconds = follow_seconds
	z.position = Vector3(0, 0, 6)
	holder.add_child(z)
	var arrived: float = 99.0
	for i: int in 25 * 60:
		await wait_frames(1)
		if Vector2(z.global_position.x - target.global_position.x, z.global_position.z - target.global_position.z).length() < 2.5:
			arrived = i / 60.0
			break
	holder.queue_free()
	return arrived


func test_5_chasers_get_round_a_wall() -> void:
	var stuck: float = await _time_to_get_round_wall(0.0)
	var round_it: float = await _time_to_get_round_wall(4.0)
	print("  behind a wall: without wall-following %.1f s, with %.1f s" % [stuck, round_it])
	check(stuck >= 99.0, "a zombie that only steers straight stays pinned against the wall")
	check(round_it < 15.0, "a zombie that follows the wall reaches the target behind it (%.1f s)" % round_it)


func test_6_the_player_recovers_slowly_when_left_alone() -> void:
	var p: Player = (load("res://world/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(p)
	p.setup(PlayerStats.new(PlayerConfig.new(), TUNING), self)
	p.take_damage(40.0)
	var after_hit: float = p.health.current
	await wait_frames(int((TUNING.calm_regen_delay - 1.0) * 60.0))
	check_eq(p.health.current, after_hit, "no regeneration before %.0f calm seconds" % TUNING.calm_regen_delay)
	await wait_frames(int(6.0 * 60.0))
	var gained: float = p.health.current - after_hit
	check(gained > 1.5 and gained <= TUNING.calm_regen_per_second * 6.0 + 0.5, "then it heals %.1f HP over 6 s (%.1f/s)" % [gained, TUNING.calm_regen_per_second])
	p.take_damage(10.0)
	var hurt_again: float = p.health.current
	await wait_frames(int((TUNING.calm_regen_delay - 1.0) * 60.0))
	check_eq(p.health.current, hurt_again, "taking damage restarts the wait")
	p.queue_free()
	await wait_frames(2)
