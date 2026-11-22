extends TestCase
## "Stuck and surrounded" on the real level with the current GameTuning.
## 1. A player standing still in the start area is reached by zombies from at least two corridors within
##    ARRIVAL_SECONDS: each arriving zombie is classified by where it was when its walk to the player first dropped to
##    ENTRY_WALK metres (the street or alley mouth it came through); entry points closer than CORRIDOR_MERGE are one
##    corridor. Every top-up spawn must be on ground the test's own grid (0.5 m, zombie radius) can reach from the start.
## 2. Single zombies that have to go round a block (the court gate, the Main Avenue / Cross Street corner, alley mouths)
##    reach a standing player: regression for zombies freezing where the street-routing check sits on its threshold.
## Needs simulated time: ALWAYS start it with --fixed-fps 60 (tests/run_tests.sh does).

const LEVEL: PackedScene = preload("res://world/levels/freedom_city.tscn")
const TUNING: GameTuning = preload("res://data/config/game_tuning.tres")
const WALKER: EnemyData = preload("res://data/enemies/walker.tres")
## Seconds a standing player waits for the first zombies.
const ARRIVAL_SECONDS: float = 32.0
## A zombie "arrives" when it gets this close.
const ARRIVAL_DISTANCE: float = 6.0
## Walking distance (metres) at which a zombie's approach corridor is read.
const ENTRY_WALK: float = 12.0
## Entry points closer than this (metres) are the same corridor.
const CORRIDOR_MERGE: float = 7.0
## A spawn counts as on the reachable streets when the check grid has reachable ground within this many metres (its
## 0.5 m cells next to a wall are solid although a zombie fits there; half a cell diagonal is 0.35 m).
const SPAWN_TOLERANCE: float = 0.4

var level: Level
var _elapsed: float = 0.0
## The test's own reachability grid, built once from the level's footprints with the walker's radius.
var _check_grid: WalkGrid


func _ready() -> void:
	run_all()


func _physics_process(delta: float) -> void:
	_elapsed += delta


func _start_at(p: Vector3, run_seed: int) -> void:
	_elapsed = 0.0
	seed(run_seed)  # Zombies draw their speed spread and wander from the global RNG.
	level = LEVEL.instantiate() as Level
	add_child(level)
	(level.get_node("PlayerStart") as Node3D).global_position = p
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = run_seed
	level.start(PlayerStats.new(PlayerConfig.new(), TUNING), RunConfig.new(), rng, func() -> float: return _elapsed, TUNING)
	level.player.health.max_health = 1000000.0
	level.player.health.current = 1000000.0


func _stop_level() -> void:
	level.queue_free()
	await wait_frames(2)
	level = null


## Stands at `p`; returns the entry point (x, z) of every zombie that came within ARRIVAL_DISTANCE.
func _arrivals(p: Vector3, run_seed: int) -> Array[Vector2]:
	await _start_at(p, run_seed)
	if _check_grid == null:
		await wait_frames(1)
		_check_grid = WalkGrid.build(level.bounds, StreetNavigation.footprints_of(level.solid_roots()), 0.5, WALKER.radius, Vector2(p.x, p.z))
	var entry: Dictionary = {}
	var arrived: Dictionary = {}
	var points: Array[Vector2] = []
	var bad_spawns: Array[int] = [0, 0]
	level.director.zombie_spawned.connect(func(z: Zombie) -> void:
		bad_spawns[1] += 1
		if _check_grid.nearest_open(Vector2(z.position.x, z.position.z), SPAWN_TOLERANCE).x == INF:
			bad_spawns[0] += 1
			printerr("  spawn off the reachable streets at %s" % z.position)
	)
	var flow: FlowField = level.navigation.flow
	var frames: int = int(ARRIVAL_SECONDS * 60.0)
	for i: int in frames:
		await get_tree().physics_frame
		if i % 10 != 0:
			continue
		var at: Vector3 = level.player.global_position
		for node: Node in get_tree().get_nodes_in_group(Zombie.GROUP):
			var z: Zombie = node as Zombie
			if z == null or z.is_dead:
				continue
			var id: int = z.get_instance_id()
			var zp: Vector2 = Vector2(z.global_position.x, z.global_position.z)
			if not entry.has(id) and flow.distance_at(zp) <= ENTRY_WALK:
				entry[id] = zp
			if arrived.has(id) or zp.distance_to(Vector2(at.x, at.z)) > ARRIVAL_DISTANCE:
				continue
			arrived[id] = true
			points.append(entry.get(id, zp))
	check_eq(bad_spawns[0], 0, "top-up zombies spawned off the reachable streets (of %d)" % bad_spawns[1])
	await _stop_level()
	return points


## Entry points merged into corridors (points closer than CORRIDOR_MERGE are one).
func _corridors(points: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for q: Vector2 in points:
		var known: bool = false
		for c: Vector2 in out:
			if c.distance_to(q) < CORRIDOR_MERGE:
				known = true
				break
		if not known:
			out.append(q)
	return out


func test_1_zombies_close_in_from_several_corridors() -> void:
	# The start and spots a few metres either side of it on Main Avenue (not at the fenced west end, where a cornered
	# player is meant to have them all coming from one side).
	var spots: Array[Vector3] = [Vector3(24, 0, 66.5), Vector3(32, 0, 66.5), Vector3(16, 0, 66.5)]
	for k: int in spots.size():
		var points: Array[Vector2] = await _arrivals(spots[k], 40 + k)
		var corridors: Array[Vector2] = _corridors(points)
		print("  standing at %s: %d zombies arrived within %.0f s through %d corridors %s" % [spots[k], points.size(), ARRIVAL_SECONDS, corridors.size(), corridors])
		check(points.size() >= 3, "several zombies reach a player standing at %s (%d)" % [spots[k], points.size()])
		check(corridors.size() >= 2, "they come through at least two corridors at %s (%d)" % [spots[k], corridors.size()])


func test_2_single_zombies_get_round_the_blocks() -> void:
	# [zombie start, standing player]: each needs the street, not the straight line.
	var cases: Array[Array] = [
		[Vector3(96.5, 0, 44.5), Vector3(91, 0, 56)],    # out of the fenced court through its gate
		[Vector3(57, 0, 62.5), Vector3(68, 0, 44)],      # Main Avenue round the corner into Cross Street
		[Vector3(88.5, 0, 71.2), Vector3(97, 0, 96)],    # down alley D into the south-east yard
		[Vector3(42, 0, 42), Vector3(30, 0, 66.5)],      # yard E out through alley B
		[Vector3(40, 0, 18.5), Vector3(44, 0, 42)],      # Back Street through alley A and yard W into yard E
	]
	for c: Array in cases:
		var from: Vector3 = c[0]
		var to: Vector3 = c[1]
		await _start_at(to, 7)
		level.director.active = false
		level.population.active = false
		for node: Node in level.get_node("Hordes").get_children():
			node.set_process(false)
		for node: Node in get_tree().get_nodes_in_group(Zombie.GROUP):
			node.queue_free()
		await wait_frames(30)  # The flow field settles on the player.
		var z: Zombie = level.zombie_scene.instantiate() as Zombie
		z.setup(WALKER, level.player, 100000.0, TUNING, 0.0)
		z.position = from
		z.flow = level.navigation.flow
		z.target_radius = level.player.body_radius
		level.entities.add_child(z)
		var walk: float = level.navigation.flow.distance_at(Vector2(from.x, from.z))
		var speed: float = TUNING.zombie_speed(WALKER, 0.0) * (1.0 - WALKER.speed_variance)
		var limit: float = walk / speed * 1.5 + 4.0
		var t: float = 0.0
		var reached: bool = false
		while t < limit:
			await get_tree().physics_frame
			t += 1.0 / 60.0
			if Vector2(z.global_position.x - to.x, z.global_position.z - to.z).length() < 2.0:
				reached = true
				break
		print("  %s -> %s: walk %.0f m, %s after %.1f s (limit %.0f s), at %s" % [from, to, walk, "reached" if reached else "NOT reached", t, limit, z.global_position])
		check(walk < INF, "the zombie at %s can walk to %s" % [from, to])
		check(reached, "a zombie at %s gets round to a player at %s" % [from, to])
		await _stop_level()
