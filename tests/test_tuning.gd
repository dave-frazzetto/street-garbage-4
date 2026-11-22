extends TestCase
## Node-free checks of the balance numbers (GameTuning) and the world population rules (PopulationGrid): speed ratios,
## tier shares over time, XP pace, deterministic and evenly spread slots, wake/sleep/respawn, and "no empty streets".

const TUNING: GameTuning = preload("res://data/config/game_tuning.tres")
const WALKER: EnemyData = preload("res://data/enemies/walker.tres")
const ARMOURED: EnemyData = preload("res://data/enemies/armoured.tres")
const BOSS: EnemyData = preload("res://data/enemies/boss.tres")
const MAP: Rect2 = Rect2(0, 0, 120, 120)
const START: Vector2 = Vector2(24, 66.5)


func _ready() -> void:
	run_all()


func _grid(run_seed: int = 4242) -> PopulationGrid:
	return PopulationGrid.new(MAP, run_seed, TUNING.world_density_max(), 10.0, START, TUNING.start_safe_radius)


func test_1_speed_ratio_makes_zombies_a_threat() -> void:
	var walk: float = TUNING.player_walk_speed
	var fastest_early: float = TUNING.zombie_speed(WALKER, 0.0) * (1.0 + WALKER.speed_variance)
	var fastest_late: float = TUNING.zombie_speed(WALKER, TUNING.ramp_seconds) * (1.0 + WALKER.speed_variance)
	check(TUNING.zombie_speed(WALKER, 0.0) < walk, "an average zombie is slower than a walking player")
	check(TUNING.zombie_speed(WALKER, 0.0) > walk * 0.7, "but not by much (%.2f vs %.2f)" % [TUNING.zombie_speed(WALKER, 0.0), walk])
	check(fastest_late >= walk, "the fastest late zombies catch a walking player (%.2f vs %.2f)" % [fastest_late, walk])
	check(TUNING.sprint_speed() > fastest_late * 1.25, "sprinting clearly outruns even those (%.2f vs %.2f)" % [TUNING.sprint_speed(), fastest_late])
	check(fastest_early < TUNING.sprint_speed(), "sprinting always opens a gap")
	check(TUNING.zombie_speed(BOSS, 0.0) < TUNING.zombie_speed(WALKER, 0.0), "bosses are slower than standard zombies")
	var gap_per_sprint: float = (TUNING.sprint_speed() - TUNING.zombie_speed(WALKER, 450.0)) * TUNING.sprint_seconds
	check(gap_per_sprint > 5.0 and gap_per_sprint < 25.0, "one full sprint opens a gap of %.1f m" % gap_per_sprint)
	check(TUNING.stamina_recharge_seconds > TUNING.sprint_seconds, "recharging takes longer than sprinting")


func test_2_player_stats_come_from_tuning() -> void:
	var cfg: PlayerConfig = PlayerConfig.new()
	var stats: PlayerStats = PlayerStats.new(cfg, TUNING)
	check_eq(stats.get_value(PlayerStats.Stat.MOVE_SPEED), TUNING.player_walk_speed, "walk speed from tuning")
	check_eq(stats.get_value(PlayerStats.Stat.MAX_STAMINA) / stats.get_value(PlayerStats.Stat.STAMINA_DRAIN), TUNING.sprint_seconds, "sprint seconds")
	check_eq(stats.get_value(PlayerStats.Stat.MAX_STAMINA) / stats.get_value(PlayerStats.Stat.STAMINA_REGEN), TUNING.stamina_recharge_seconds, "recharge seconds")
	check_eq(stats.get_value(PlayerStats.Stat.SPRINT_BONUS), TUNING.sprint_speed_multiplier - 1.0, "sprint bonus")
	var custom: GameTuning = GameTuning.new()
	custom.player_walk_speed = 7.0
	check_eq(PlayerStats.new(cfg, custom).get_value(PlayerStats.Stat.MOVE_SPEED), 7.0, "a changed tuning changes the player")
	# Fleet Foot (+10% x4) makes the player faster than any zombie, as the perk should.
	stats.add_modifier(PlayerStats.Stat.MOVE_SPEED, PlayerStats.Mode.PERCENT, 0.4)
	var late_fast_zombie: float = TUNING.zombie_speed(WALKER, TUNING.ramp_seconds) * (1.0 + WALKER.speed_variance)
	check(stats.get_value(PlayerStats.Stat.MOVE_SPEED) > late_fast_zombie * 1.1, "four Fleet Foots outpace zombies by a clear margin")


func test_3_health_xp_and_shots_to_kill() -> void:
	var pistol: WeaponData = load("res://data/weapons/pistol.tres") as WeaponData
	var shots: int = ceili(TUNING.zombie_max_health(WALKER, 0.0) / pistol.damage)
	check(shots >= 3 and shots <= 5, "a standard zombie takes %d pistol shots at the start" % shots)
	check(TUNING.zombie_max_health(ARMOURED, 0.0) > TUNING.zombie_max_health(WALKER, 0.0) * 1.5, "armoured is tougher")
	check(TUNING.zombie_max_health(BOSS, 0.0) >= TUNING.zombie_max_health(WALKER, 0.0) * 10.0, "boss is much tougher")
	check(TUNING.zombie_xp(WALKER, 0.0) >= 1.0, "a kill is worth at least one xp")
	var per_hp_start: float = TUNING.zombie_xp(WALKER, 0.0) / TUNING.zombie_max_health(WALKER, 0.0)
	var per_hp_end: float = TUNING.zombie_xp(WALKER, TUNING.ramp_seconds) / TUNING.zombie_max_health(WALKER, TUNING.ramp_seconds)
	check_eq(snappedf(per_hp_end / per_hp_start, 0.001), 1.0, "xp per health stays constant while zombies get tougher")
	check(TUNING.zombie_xp(BOSS, 0.0) > TUNING.zombie_xp(ARMOURED, 0.0) and TUNING.zombie_xp(ARMOURED, 0.0) > TUNING.zombie_xp(WALKER, 0.0), "tougher types give more xp")


func test_4_tier_shares_over_time() -> void:
	check_eq(TUNING.boss_share(TUNING.boss_start_seconds - 1.0), 0.0, "no boss share before its start")
	check_eq(TUNING.boss_share(TUNING.boss_start_seconds), TUNING.boss_share_start, "boss share starts at its start value")
	check_eq(TUNING.boss_share(TUNING.ramp_seconds), TUNING.boss_share_end, "boss share ends at its end value")
	check(TUNING.boss_share(TUNING.ramp_seconds * 2.0) <= TUNING.boss_share_end, "stays at the end value afterwards")
	check(TUNING.boss_share_end <= 0.03, "bosses stay a small share")
	check_eq(TUNING.elite_share(TUNING.elite_start_seconds - 1.0), 0.0, "no armoured early")
	check(TUNING.elite_share(600.0) > TUNING.elite_share(300.0), "armoured share grows")
	check(TUNING.trickle_alive(TUNING.ramp_seconds) >= TUNING.trickle_alive(0.0), "trickle never shrinks")
	var zero: GameTuning = GameTuning.new()
	zero.world_density_start = 0.0
	zero.world_density_end = 0.0
	check_eq(zero.world_density_fraction(100.0), 0.0, "no density, no world zombies")


func test_4b_picked_mix_follows_the_run_time() -> void:
	var config: DirectorConfig = load("res://data/config/director_default.tres") as DirectorConfig
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var early: Dictionary = {}
	var late: Dictionary = {}
	for i: int in 4000:
		var e: EnemyData = config.pick(60.0, TUNING, rng)
		early[e] = int(early.get(e, 0)) + 1
		var l: EnemyData = config.pick(TUNING.ramp_seconds, TUNING, rng)
		late[l] = int(late.get(l, 0)) + 1
	check_eq(int(early.get(ARMOURED, 0)) + int(early.get(BOSS, 0)), 0, "only standard zombies in the first minute")
	var armoured_late: float = float(late.get(ARMOURED, 0)) / 4000.0
	var boss_late: float = float(late.get(BOSS, 0)) / 4000.0
	check(absf(armoured_late - TUNING.elite_share_end * (1.0 - TUNING.boss_share_end)) < 0.04, "late armoured share about %.2f (got %.3f)" % [TUNING.elite_share_end, armoured_late])
	check(boss_late > TUNING.boss_share_end * 0.5 and boss_late < TUNING.boss_share_end * 1.6, "late boss share about %.3f (got %.3f)" % [TUNING.boss_share_end, boss_late])
	var capped: Dictionary = {BOSS: BOSS.max_alive}
	var bosses_over_cap: int = 0
	for i: int in 2000:
		if config.pick(TUNING.ramp_seconds, TUNING, rng, capped) == BOSS:
			bosses_over_cap += 1
	check_eq(bosses_over_cap, 0, "no boss beyond EnemyData.max_alive")


func test_5_xp_pace_matches_tuned_kill_rate() -> void:
	# A player who kills about one zombie every five seconds early on and a bit faster as the street fills.
	var run: RunState = RunState.new(RunConfig.new())
	var level_times: Array[float] = []
	var t: float = 0.0
	while t < 1080.0:
		t += 1.0
		var rate: float = 0.2 * (0.7 + 0.8 * TUNING.ramp(t))
		var pb: float = TUNING.boss_share(t)
		var pe: float = TUNING.elite_share(t)
		var mix: float = (1.0 - pb) * ((1.0 - pe) * TUNING.zombie_xp(WALKER, t) + pe * TUNING.zombie_xp(ARMOURED, t)) + pb * TUNING.zombie_xp(BOSS, t)
		var gained: int = run.add_xp(rate * mix)
		for i: int in gained:
			level_times.append(t)
	check(level_times.size() >= 2, "levels are reached")
	check(level_times[0] >= 20.0 and level_times[0] <= 45.0, "level 2 after %.0f s" % level_times[0])
	check(level_times[1] - level_times[0] <= 60.0, "next level within a minute (%.0f s)" % (level_times[1] - level_times[0]))
	check(run.level >= 12 and run.level <= 20, "about 12 to 20 levels in a run (got %d)" % run.level)


func test_6_grid_is_deterministic_and_dense_enough() -> void:
	var a: PopulationGrid = _grid(11)
	var b: PopulationGrid = _grid(11)
	var c: PopulationGrid = _grid(12)
	var sa: Array[PopulationGrid.Slot] = a.all_slots()
	var sb: Array[PopulationGrid.Slot] = b.all_slots()
	var sc: Array[PopulationGrid.Slot] = c.all_slots()
	check_eq(sa.size(), sb.size(), "same seed, same count")
	var same: bool = sa.size() == sb.size()
	for i: int in mini(sa.size(), sb.size()):
		same = same and sa[i].position == sb[i].position and sa[i].threshold == sb[i].threshold
	check(same, "same seed, same places")
	check(sa.size() != sc.size() or sa[0].position != sc[0].position, "another seed, another street")
	var expected: float = TUNING.world_density_max() * MAP.get_area() / 1000.0
	check(sa.size() > expected * 0.6 and sa.size() <= expected * 1.3, "about %.0f planned, got %d" % [expected, sa.size()])
	var thin: int = 0
	var inside: bool = true
	var clear_of_start: bool = true
	for s: PopulationGrid.Slot in sa:
		inside = inside and MAP.has_point(Vector2(s.position.x, s.position.z))
		clear_of_start = clear_of_start and Vector2(s.position.x, s.position.z).distance_to(START) >= TUNING.start_safe_radius
		if s.threshold <= TUNING.world_density_fraction(0.0):
			thin += 1
	check(inside, "every slot is inside the map")
	check(clear_of_start, "no slot inside the start safe radius")
	var share: float = float(thin) / float(sa.size())
	check(absf(share - TUNING.world_density_fraction(0.0)) < 0.12, "start density keeps %.2f of the planned slots (target %.2f)" % [share, TUNING.world_density_fraction(0.0)])
	var lazy: PopulationGrid = _grid(11)
	lazy.slots_near(Vector3(10, 0, 10), 15.0)
	check(lazy._cells.size() < 30, "only cells near the player are filled (%d)" % lazy._cells.size())


func test_7_wake_sleep_kill_respawn() -> void:
	var g: PopulationGrid = _grid(5)
	var origin: Vector3 = Vector3(60, 0, 60)
	var p: PopulationGrid.Plan = g.plan(origin, 0.0, 1.0, 40.0, 50.0, 1000)
	check(p.wake.size() > 8, "slots within the wake radius wake (%d)" % p.wake.size())
	var all_near: bool = true
	for s: PopulationGrid.Slot in p.wake:
		all_near = all_near and Vector2(s.position.x, s.position.z).distance_to(Vector2(60, 60)) <= 40.01
	check(all_near, "only slots inside the radius wake")
	var limited: PopulationGrid.Plan = g.plan(origin, 0.0, 1.0, 40.0, 50.0, 3)
	check_eq(limited.wake.size(), 3, "wakes are limited per call")
	var d0: float = Vector2(limited.wake[0].position.x, limited.wake[0].position.z).distance_to(Vector2(60, 60))
	var d2: float = Vector2(limited.wake[2].position.x, limited.wake[2].position.z).distance_to(Vector2(60, 60))
	check(d0 <= d2, "nearest wake first")
	var none: PopulationGrid.Plan = g.plan(origin, 0.0, 0.0, 40.0, 50.0, 1000)
	check_eq(none.wake.size(), 0, "no density, nothing wakes")
	for s: PopulationGrid.Slot in p.wake:
		g.wake_slot(s)
	check_eq(g.awake_count(), p.wake.size(), "awake counted")
	check_eq(g.plan(origin, 0.0, 1.0, 40.0, 50.0, 1000).wake.size(), 0, "awake slots do not wake twice")
	var far: PopulationGrid.Plan = g.plan(Vector3(0, 0, 0), 0.0, 1.0, 40.0, 50.0, 0)
	check(far.sleep.size() > 0, "awake slots far from the player go to sleep")
	var victim: PopulationGrid.Slot = p.wake[0]
	victim.position = Vector3(100, 0, 100)
	g.kill_slot(victim, 100.0)
	check_eq(g.awake_count(), p.wake.size() - 1, "dead slot is no longer awake")
	g.plan(Vector3(100, 0, 100), 200.0, 1.0, 40.0, 50.0, 1000)
	check_eq(victim.state, PopulationGrid.State.DEAD, "respawn waits while the player is near, so nobody pops into view")
	g.plan(Vector3(0, 0, 0), 50.0, 1.0, 40.0, 50.0, 0)
	check_eq(victim.state, PopulationGrid.State.DEAD, "respawn waits for its time")
	g.plan(Vector3(0, 0, 0), 200.0, 1.0, 40.0, 50.0, 0)
	check_eq(victim.state, PopulationGrid.State.DORMANT, "refilled once the player is far away and the time has come")
	var forever: PopulationGrid.Slot = p.wake[1]
	forever.position = Vector3(100, 0, 100)
	g.kill_slot(forever)
	g.plan(Vector3(0, 0, 0), 99999.0, 1.0, 40.0, 50.0, 0)
	check_eq(forever.state, PopulationGrid.State.DEAD, "no respawn time means dead for good")
	var moved: PopulationGrid.Slot = p.wake[2]
	moved.live_position = Vector3(1, 0, 2)
	g.sleep_slot(moved)
	check_eq(moved.position, Vector3(1, 0, 2), "a sleeping zombie waits where it stood")


func test_7b_a_zombie_that_chased_far_is_found_where_it_sleeps() -> void:
	var g: PopulationGrid = _grid(5)
	var slot: PopulationGrid.Slot = g.plan(Vector3(60, 0, 60), 0.0, 1.0, 40.0, 50.0, 1).wake[0]
	g.wake_slot(slot)
	slot.enemy = WALKER
	var home: Vector3 = slot.position
	var far: Vector3 = Vector3(clampf(home.x + 70.0, 3.0, 117.0), 0.0, clampf(home.z + 70.0, 3.0, 117.0))
	if far.distance_to(home) < 60.0:
		far = Vector3(clampf(home.x - 70.0, 3.0, 117.0), 0.0, clampf(home.z - 70.0, 3.0, 117.0))
	check(far.distance_to(home) > 60.0, "the zombie chased more than 60 m (%.0f m)" % far.distance_to(home))
	slot.live_position = far
	g.sleep_slot(slot)
	check(g.slots_near(far, 40.0).has(slot), "found again from where it sleeps")
	check(not g.slots_near(home, 20.0).has(slot) or home.distance_to(far) <= 20.0, "no longer listed at its old place")
	check_eq(slot.enemy, null, "the type is decided again at the next wake")
	var plan: PopulationGrid.Plan = g.plan(far, 0.0, 1.0, 40.0, 50.0, 1000)
	check(plan.wake.has(slot), "it wakes when the player comes to where it waits")
	var dead: PopulationGrid.Slot = plan.wake[0]
	g.wake_slot(dead)
	dead.enemy = BOSS
	g.kill_slot(dead, 10.0)
	g.plan(Vector3(0, 0, 0), 20.0, 1.0, 40.0, 50.0, 0)
	check_eq(dead.enemy, null, "a refilled slot rolls its type again, so late respawns follow the late mix")


## Moves a player along a straight line and wakes/sleeps slots the way WorldPopulation does; returns the fewest world
## zombies within `near` metres seen at any sample after the first two seconds.
func _fewest_near(from: Vector2, to: Vector2, speed: float, seconds: float, elapsed0: float, near: float) -> int:
	var g: PopulationGrid = _grid(77)
	var fewest: int = 1 << 20
	var steps: int = int(seconds / 0.25)
	for i: int in steps + 1:
		var pos2: Vector2 = from.lerp(to, minf(1.0, speed * i * 0.25 / from.distance_to(to)))
		var pos: Vector3 = Vector3(pos2.x, 0, pos2.y)
		var elapsed: float = elapsed0 + i * 0.25
		var plan: PopulationGrid.Plan = g.plan(pos, elapsed, TUNING.world_density_fraction(elapsed), 40.0, 50.0, 6)
		for s: PopulationGrid.Slot in plan.sleep:
			g.sleep_slot(s)
		for s: PopulationGrid.Slot in plan.wake:
			g.wake_slot(s)
		var count: int = 0
		for s: PopulationGrid.Slot in g.awake_slots():
			if Vector2(s.live_position.x, s.live_position.z).distance_to(pos2) <= near:
				count += 1
		if i >= 8:
			fewest = mini(fewest, count)
	return fewest


func test_8_running_across_the_map_never_leaves_an_empty_street() -> void:
	# Fixed seed, deterministic. Sprinting in four directions, early and late in the run.
	var lines: Array = [
		[Vector2(10, 100), Vector2(10, 10)],
		[Vector2(15, 60), Vector2(110, 60)],
		[Vector2(110, 110), Vector2(20, 20)],
		[Vector2(60, 10), Vector2(60, 110)],
	]
	for line: Array in lines:
		for elapsed0: float in [0.0, 600.0]:
			var fewest: int = _fewest_near(line[0], line[1], TUNING.sprint_speed(), 20.0, elapsed0, 40.0)
			print("  fewest world zombies within 40 m, %s -> %s at %.0f s: %d" % [line[0], line[1], elapsed0, fewest])
			check(fewest >= 3, "at least 3 world zombies within 40 m along %s -> %s at %.0f s (fewest %d)" % [line[0], line[1], elapsed0, fewest])
