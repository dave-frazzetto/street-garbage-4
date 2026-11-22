extends TestCase
## Node-free rule tests: stats, run state, perk deck and every perk in the default pool.

const POOL_PATH: String = "res://data/perks/perk_pool_default.tres"


func _ready() -> void:
	run_all()


func _pool() -> Array[Perk]:
	return (load(POOL_PATH) as PerkPool).perks


func _perk(id: String) -> Perk:
	for p: Perk in _pool():
		if p.get_key() == StringName(id):
			return p
	return null


func test_stats_flat_and_percent() -> void:
	var s: PlayerStats = PlayerStats.new(PlayerConfig.new())
	check_eq(s.get_value(PlayerStats.Stat.MAX_HEALTH), 100.0, "base health")
	s.add_modifier(PlayerStats.Stat.MAX_HEALTH, PlayerStats.Mode.FLAT, 20.0)
	s.add_modifier(PlayerStats.Stat.MAX_HEALTH, PlayerStats.Mode.PERCENT, -0.5)
	check_eq(s.get_value(PlayerStats.Stat.MAX_HEALTH), 60.0, "(100+20)*0.5")
	check_eq(s.format_value(PlayerStats.Stat.FIRE_RATE, 1.125), "12.5%", "bonus percent format")
	check_eq(s.format_value(PlayerStats.Stat.FIRE_RATE, 1.0), "0%", "zero bonus format")


func test_run_xp_and_levels() -> void:
	var cfg: RunConfig = RunConfig.new()
	cfg.xp_first_level = 5.0
	cfg.xp_growth = 1.0
	cfg.xp_flat_increase = 0.0
	var run: RunState = RunState.new(cfg)
	check_eq(run.add_xp(4.0), 0, "no level at 4/5")
	check_eq(run.add_xp(11.0), 3, "15 xp = 3 levels of 5")
	check_eq(run.level, 4, "level 4")
	check_eq(run.pending_level_ups, 3, "3 pending")
	run.add_xp(0.5)
	run.add_xp(0.5)
	check_eq(run.xp, 1, "fractions accumulate")
	check(RunConfig.new().xp_needed(5) > RunConfig.new().xp_needed(1), "xp curve grows")


func test_run_timer_nukes() -> void:
	var cfg: RunConfig = RunConfig.new()
	cfg.duration_seconds = 10.0
	var run: RunState = RunState.new(cfg)
	run.tick(9.0)
	check_eq(run.outcome, RunState.Outcome.NONE, "still running")
	run.tick(2.0)
	check_eq(run.outcome, RunState.Outcome.NUKED, "nuked at zero")
	run.finish(RunState.Outcome.EXTRACTED)
	check_eq(run.outcome, RunState.Outcome.NUKED, "outcome is final")


func test_gears_and_extraction() -> void:
	var run: RunState = RunState.new(RunConfig.new())
	check(not run.can_extract(), "cannot extract with 0 gears")
	for i: int in 7:
		run.add_gear()
	check_eq(run.gears, 6, "gears capped at required")
	check(run.can_extract(), "can extract with 6")


func test_streak_resets_on_damage() -> void:
	var run: RunState = RunState.new(RunConfig.new())
	for i: int in 5:
		run.register_kill()
	run.register_damage()
	run.register_kill()
	check_eq(run.kills, 6, "kills")
	check_eq(run.streak, 1, "streak reset")
	check_eq(run.best_streak, 5, "best streak kept")


func test_redraws_limited() -> void:
	var run: RunState = RunState.new(RunConfig.new())
	check(run.use_redraw() and run.use_redraw() and run.use_redraw(), "three redraws")
	check(not run.use_redraw(), "no fourth redraw")


func test_pool_has_twenty_valid_perks() -> void:
	var perks: Array[Perk] = _pool()
	check_eq(perks.size(), 20, "20 perks")
	var rare: int = 0
	var keys: Dictionary = {}
	for p: Perk in perks:
		check(p != null, "perk loads")
		check(not p.effects.is_empty(), "%s has effects" % p.display_name)
		check(not keys.has(p.get_key()), "%s unique id" % p.display_name)
		keys[p.get_key()] = true
		if p.rarity == Perk.Rarity.RARE:
			rare += 1
		var ctx: PerkContext = PerkContext.new(RunState.new(RunConfig.new()), PlayerStats.new())
		check(not p.describe(ctx).is_empty(), "%s describes itself" % p.display_name)
	check(rare >= 5, "at least 5 rare perks (got %d)" % rare)


func test_trigger_happy_card_text_matches_original() -> void:
	var ctx: PerkContext = PerkContext.new(RunState.new(RunConfig.new()), PlayerStats.new())
	check_eq(_perk("trigger_happy").describe(ctx)[0], "Rate of Fire: 0% -> 12.5%", "trigger happy text")
	check_eq(_perk("blood_money").describe(ctx)[0], "XP from Kills: 0% -> 5%", "blood money text")


func test_every_perk_applies() -> void:
	for p: Perk in _pool():
		var run: RunState = RunState.new(RunConfig.new())
		var stats: PlayerStats = PlayerStats.new()
		var equipped: Array = []
		var ctx: PerkContext = PerkContext.new(run, stats, func(w: WeaponData, t: float) -> void: equipped.append([w, t]))
		var before: Dictionary = {}
		for s: int in PlayerStats.Stat.values():
			before[s] = stats.get_value(s)
		p.apply(ctx)
		var changed: bool = run.gears > 0 or not equipped.is_empty() or stats.has_flag(PlayerStats.Flag.NO_HEALTH_PICKUPS)
		for s: int in PlayerStats.Stat.values():
			if not is_equal_approx(float(before[s]), stats.get_value(s)):
				changed = true
		check(changed, "%s changes something" % p.display_name)
		check_eq(run.perk_stacks(p), 1, "%s stack counted" % p.display_name)


func test_specific_perk_effects() -> void:
	var run: RunState = RunState.new(RunConfig.new())
	var stats: PlayerStats = PlayerStats.new()
	var ctx: PerkContext = PerkContext.new(run, stats)
	_perk("vampire").apply(ctx)
	check(stats.has_flag(PlayerStats.Flag.NO_HEALTH_PICKUPS), "vampire disables health pickups")
	check(stats.get_value(PlayerStats.Stat.LIFESTEAL) > 0.0, "vampire lifesteal")
	_perk("double_sprint").apply(ctx)
	check_eq(stats.get_value(PlayerStats.Stat.SPRINT_BONUS), stats.get_base(PlayerStats.Stat.SPRINT_BONUS) * 2.0, "double sprint doubles bonus")
	_perk("glass_cannon").apply(ctx)
	check_eq(stats.get_value(PlayerStats.Stat.MAX_HEALTH), 70.0, "glass cannon -30% health")
	_perk("gear").apply(ctx)
	check_eq(run.gears, 1, "gear perk gives a gear")


func test_deck_draws_distinct_available() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var deck: PerkDeck = PerkDeck.new(_pool(), rng)
	var run: RunState = RunState.new(RunConfig.new())
	var ctx: PerkContext = PerkContext.new(run, PlayerStats.new())
	for i: int in 50:
		var hand: Array[Perk] = deck.draw_hand(ctx, 3)
		check_eq(hand.size(), 3, "hand of 3")
		check(hand[0] != hand[1] and hand[1] != hand[2] and hand[0] != hand[2], "distinct cards")
	# Maxed or ineligible perks are never dealt.
	for i: int in 6:
		run.add_gear()
	var vampire: Perk = _perk("vampire")
	run.add_perk_stack(vampire)
	for i: int in 200:
		for p: Perk in deck.draw_hand(ctx, 3):
			check(p.get_key() != &"gear", "no gear perk when all gears collected")
			check(p != vampire, "no maxed perk")


func test_rare_perks_are_rarer() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var deck: PerkDeck = PerkDeck.new(_pool(), rng)
	var ctx: PerkContext = PerkContext.new(RunState.new(RunConfig.new()), PlayerStats.new())
	var rare: int = 0
	var total: int = 0
	for i: int in 400:
		for p: Perk in deck.draw_hand(ctx, 3):
			total += 1
			if p.rarity == Perk.Rarity.RARE:
				rare += 1
	var share: float = float(rare) / float(total)
	# 6 of 20 perks are rare; with weight 0.3 they should be well under their 30% share.
	check(share > 0.03 and share < 0.2, "rare share %.2f" % share)


## A 20 x 20 m map split by a wall along z = 10 with a 2 m gap at x 16..18, and a sealed 3 x 3 m box at the corner.
func _walled_grid() -> WalkGrid:
	var fps: Array[WalkGrid.Footprint] = [
		WalkGrid.Footprint.box(Vector2(8, 10), Vector2(8, 0.25), 0.0),
		WalkGrid.Footprint.box(Vector2(19, 10), Vector2(1, 0.25), 0.0),
		WalkGrid.Footprint.box(Vector2(1.5, 18.5), Vector2(1.5, 0.1), 0.0),
		WalkGrid.Footprint.box(Vector2(3.0, 18.5), Vector2(0.1, 1.5), 0.0),
	]
	return WalkGrid.build(Rect2(0, 0, 20, 20), fps, 0.5, 0.3, Vector2(5, 5))


func test_walk_grid_finds_the_reachable_ground() -> void:
	var g: WalkGrid = _walled_grid()
	check(g.is_reachable(Vector2(5, 5)), "start side reachable")
	check(g.is_reachable(Vector2(5, 15)), "far side reachable through the gap")
	check(not g.is_open(Vector2(5, 10)), "the wall is solid")
	check(not g.is_reachable(Vector2(0.8, 19.5)), "the boxed-in corner is sealed off")
	check(g.is_open(Vector2(0.8, 19.5)), "but it is free ground")
	var snapped: Vector2 = g.nearest_open(Vector2(5, 10), 2.0)
	check(snapped.x != INF and g.is_reachable(snapped) and absf(snapped.y - 10.0) < 1.0, "nearest reachable spot next to the wall (%s)" % snapped)
	check_eq(g.nearest_open(Vector2(0.8, 19.5), 0.4).x, INF, "nothing reachable near the sealed corner")
	var rotated: WalkGrid = WalkGrid.build(Rect2(0, 0, 20, 20), [WalkGrid.Footprint.box(Vector2(10, 10), Vector2(4, 0.5), PI / 2)], 0.5, 0.0, Vector2(2, 2))
	check(not rotated.is_open(Vector2(10, 13)) and rotated.is_open(Vector2(13, 10)), "a box turned 90 degrees runs along z")


func test_flow_field_walks_round_the_wall() -> void:
	var g: WalkGrid = _walled_grid()
	var f: FlowField = FlowField.new(g, 100.0)
	f.begin(Vector2(5, 5))
	var slices: int = 0
	while not f.step(50):
		slices += 1
	check(slices > 2, "computed in slices (%d)" % slices)
	var walk: float = f.distance_at(Vector2(5, 15))
	check(walk > 24.0 and walk < 30.0, "walking distance round the wall (%.1f m: 25 m as the crow flies through the gap, straight 10 m)" % walk)
	var d: Vector2 = f.direction_at(Vector2(5, 15))
	check(d.x > 0.5, "the way leads toward the gap (%s)" % d)
	var mouth: Vector2 = f.approach_point(Vector2(5, 15), 13.0)
	check(mouth.y > 9.0 and mouth.x > 13.0, "arrives through the gap (%s)" % mouth)
	check_eq(f.distance_at(Vector2(0.8, 19.5)), INF, "no path into the sealed corner")
	var pop: PopulationGrid = PopulationGrid.new(Rect2(0, 0, 20, 20), 3, 400.0, 10.0)
	pop.walk = g
	var all: Array[PopulationGrid.Slot] = pop.all_slots()
	var off: int = 0
	for s: PopulationGrid.Slot in all:
		if not g.is_reachable(Vector2(s.position.x, s.position.z)):
			off += 1
	check(all.size() > 50, "population planned (%d)" % all.size())
	check_eq(off, 0, "population slots only on reachable ground")


func test_walk_grid_keeps_thin_poles_on_cell_corners() -> void:
	# A 0.15 m pole on the corner of four 1 m cells, with 0.4 m clearance: no cell centre is within 0.55 m of it, but the
	# pole itself overlaps all four cells, so they are solid; a box prop is always solid at its centre cell.
	var g: WalkGrid = WalkGrid.build(Rect2(0, 0, 10, 10), [WalkGrid.Footprint.circle(Vector2(5, 5), 0.15), WalkGrid.Footprint.box(Vector2(2.0, 2.0), Vector2(0.05, 0.05), 0.0)], 1.0, 0.4, Vector2(8, 8))
	for p: Vector2 in [Vector2(4.5, 4.5), Vector2(5.5, 4.5), Vector2(4.5, 5.5), Vector2(5.5, 5.5)]:
		check(not g.is_open(p), "the cell at %s under the pole is solid" % p)
	check(g.is_open(Vector2(6.5, 5.5)), "the cells beyond it are free")
	check(not g.is_open(Vector2(2.2, 2.2)), "a tiny box marks its own cell")


func test_flow_field_counts_finished_fields() -> void:
	var f: FlowField = FlowField.new(_walled_grid(), 100.0)
	check_eq(f.version, 0, "no field yet")
	f.compute(Vector2(5, 5))
	f.compute(Vector2(6, 5))
	check_eq(f.version, 2, "two fields finished")


func test_population_slots_sit_on_walk_cell_centres() -> void:
	var g: WalkGrid = WalkGrid.build(Rect2(0, 0, 20, 20), [WalkGrid.Footprint.box(Vector2(10, 10), Vector2(10, 0.5), 0.0)], 1.0, 0.4, Vector2(5, 5))
	var pop: PopulationGrid = PopulationGrid.new(Rect2(0, 0, 20, 20), 9, 300.0, 10.0)
	pop.walk = g
	var worst: float = 0.0
	for s: PopulationGrid.Slot in pop.all_slots():
		var p: Vector2 = Vector2(s.position.x, s.position.z)
		worst = maxf(worst, p.distance_to(g.centre_of(g.cell_of(p))))
		check(absf(p.y - 10.0) > 0.5 + 0.4, "slot at %s keeps the clearance from the wall" % p)
	check(worst <= PopulationGrid.SNAP_JITTER * sqrt(2.0) + 0.001, "slots stay near their cell centre (%.2f m)" % worst)
