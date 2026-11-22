class_name PopulationGrid
extends RefCounted
## The zombies waiting in the world, as data. The map is cut into square cells; each cell is filled the first time it is
## needed, from the run seed and the cell coordinates alone, so the same seed always gives the same street and nothing
## is generated for places the player never visits. Slots are planned at the highest density the run reaches; each one
## has a threshold, so a lower density early in the run simply leaves the high-threshold slots asleep until later.
##
## Node-free: the WorldPopulation node turns slots near the player into real zombies and back. See ADR
## world-anchored-zombie-population.

enum State { DORMANT, AWAKE, DEAD }

## With a walk grid, slots sit at most this share of a grid cell off their cell's centre.
const SNAP_JITTER: float = 0.1

## One waiting zombie: where it stands, what it is (decided when it first wakes), and whether it is alive in the world.
class Slot extends RefCounted:
	var position: Vector3
	## 0..1. The slot exists once the density fraction of the run reaches this value.
	var threshold: float = 0.0
	## What the zombie is. Decided again at every wake (null = not decided), so the mix follows the run time.
	var enemy: EnemyData
	## The cell whose list holds this slot (the cell of `position`, kept in step when a sleeping zombie waits elsewhere).
	var cell: Vector2i
	var state: State = State.DORMANT
	## Run time at which a dead slot may be refilled (INF = never).
	var respawn_at: float = INF
	## Where the live zombie stands; kept up to date by the node while the slot is awake.
	var live_position: Vector3

## What one update decided: slots to turn into zombies and slots to put back to sleep.
class Plan extends RefCounted:
	var wake: Array[Slot] = []
	var sleep: Array[Slot] = []

var bounds: Rect2
var seed_value: int
## Edge of a cell in metres.
var cell_size: float
## Zombies per 1000 m2 the cells are filled with (the highest density of the run).
var density_max: float
## No slots within this many metres of safe_center (x, z); the player start.
var safe_center: Vector2
var safe_radius: float
## Slots stay this far from the edge of the bounds.
var edge_margin: float = 1.5
## Optional: where zombies can stand. With it, slots are placed only on free ground connected to the player start, and
## the map's total (density_max per 1000 m2 of the whole bounds) is spread over that ground: a cell gets its share in
## proportion to its free area, so narrow streets between big blocks are as crowded as the tuning intends overall.
var walk: WalkGrid:
	set(value):
		walk = value
		_walk_share = -1.0
var _walk_share: float = -1.0

var _cells: Dictionary = {}
var _awake: Array[Slot] = []
var _dead: Array[Slot] = []


func _init(map_bounds: Rect2, run_seed: int, max_density_per_1000_m2: float, cell_edge: float = 10.0, start_center: Vector2 = Vector2.ZERO, start_safe_radius: float = 0.0) -> void:
	bounds = map_bounds
	seed_value = run_seed
	density_max = max_density_per_1000_m2
	cell_size = maxf(cell_edge, 1.0)
	safe_center = start_center
	safe_radius = start_safe_radius


## Slots of every cell touching the circle around `center` (x, z) with this radius. Fills those cells if needed.
func slots_near(center: Vector3, radius: float) -> Array[Slot]:
	var out: Array[Slot] = []
	var lo: Vector2i = _cell_of(Vector2(center.x - radius, center.z - radius))
	var hi: Vector2i = _cell_of(Vector2(center.x + radius, center.z + radius))
	var limit_sq: float = radius * radius
	for cx: int in range(lo.x, hi.x + 1):
		for cz: int in range(lo.y, hi.y + 1):
			for slot: Slot in _cell(Vector2i(cx, cz)):
				if _flat_dist_sq(slot.position, center) <= limit_sq:
					out.append(slot)
	return out


## Every slot of the map (fills all cells; for tests and tools).
func all_slots() -> Array[Slot]:
	var out: Array[Slot] = []
	var lo: Vector2i = _cell_of(bounds.position)
	var hi: Vector2i = _cell_of(bounds.end)
	for cx: int in range(lo.x, hi.x + 1):
		for cz: int in range(lo.y, hi.y + 1):
			out.append_array(_cell(Vector2i(cx, cz)))
	return out


## Slots currently awake (a copy).
func awake_slots() -> Array[Slot]:
	return _awake.duplicate()


## Number of slots currently awake (live zombies).
func awake_count() -> int:
	return _awake.size()


## Decides what changes around `origin` (x, z) at run time `elapsed`:
## - dead slots whose respawn time has come refill, but only while the player is beyond sleep_radius, so nobody pops in view
##   (it then wakes normally when the player comes back within wake_radius);
## - awake slots farther than sleep_radius are listed in `sleep` (the node frees the zombie and calls sleep_slot);
## - dormant slots within wake_radius whose threshold is under `density_fraction` are listed in `wake`, nearest first, at
##   most `max_wakes` per call so walking into a crowd does not hitch.
func plan(origin: Vector3, elapsed: float, density_fraction: float, wake_radius: float, sleep_radius: float, max_wakes: int) -> Plan:
	var result: Plan = Plan.new()
	var sleep_sq: float = sleep_radius * sleep_radius
	for slot: Slot in _awake:
		if _flat_dist_sq(slot.live_position, origin) > sleep_sq:
			result.sleep.append(slot)
	for slot: Slot in _dead.duplicate():
		if elapsed >= slot.respawn_at and _flat_dist_sq(slot.position, origin) > sleep_sq:
			slot.state = State.DORMANT
			slot.respawn_at = INF
			slot.enemy = null
			_dead.erase(slot)
	var candidates: Array[Slot] = []
	var wake_sq: float = wake_radius * wake_radius
	for slot: Slot in slots_near(origin, wake_radius):
		if slot.state == State.DORMANT and slot.threshold <= density_fraction and _flat_dist_sq(slot.position, origin) <= wake_sq:
			candidates.append(slot)
	candidates.sort_custom(func(a: Slot, b: Slot) -> bool: return _flat_dist_sq(a.position, origin) < _flat_dist_sq(b.position, origin))
	result.wake = candidates.slice(0, maxi(max_wakes, 0))
	return result


## The zombie of this slot now exists.
func wake_slot(slot: Slot) -> void:
	if slot.state == State.AWAKE:
		return
	slot.state = State.AWAKE
	slot.live_position = slot.position
	_awake.append(slot)


## The zombie of this slot was freed alive: it waits where it stood (the slot moves to the cell of that place, so it is
## found again when the player comes back there) and is decided afresh when it next wakes.
func sleep_slot(slot: Slot) -> void:
	slot.position = slot.live_position
	slot.state = State.DORMANT
	slot.enemy = null
	_awake.erase(slot)
	var new_cell: Vector2i = _cell_of(Vector2(slot.position.x, slot.position.z))
	if new_cell != slot.cell:
		_cell(slot.cell).erase(slot)
		slot.cell = new_cell
		_cell(new_cell).append(slot)


## The zombie of this slot was killed: the slot stays empty until `respawn_at` (INF = for good).
func kill_slot(slot: Slot, respawn_at: float = INF) -> void:
	slot.state = State.DEAD
	slot.respawn_at = respawn_at
	_awake.erase(slot)
	if respawn_at < INF and not _dead.has(slot):
		_dead.append(slot)


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - bounds.position.x) / cell_size), floori((p.y - bounds.position.y) / cell_size))


func _cell(c: Vector2i) -> Array[Slot]:
	if _cells.has(c):
		return _cells[c]
	var slots: Array[Slot] = _fill_cell(c)
	_cells[c] = slots
	return slots


## Deterministic content of one cell: depends only on the seed, the cell and the density.
func _fill_cell(c: Vector2i) -> Array[Slot]:
	var slots: Array[Slot] = []
	var origin: Vector2 = bounds.position + Vector2(c) * cell_size
	var area: Rect2 = Rect2(origin, Vector2(cell_size, cell_size)).intersection(bounds.grow(-edge_margin))
	if area.size.x <= 0.0 or area.size.y <= 0.0 or density_max <= 0.0:
		return slots
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (seed_value * 73856093) ^ (c.x * 19349663) ^ (c.y * 83492791)
	var open_share: float = 1.0
	if walk != null:
		if _walk_share < 0.0:
			_walk_share = float(walk.reachable_cells()) * walk.cell * walk.cell / maxf(bounds.get_area(), 1.0)
		open_share = walk.reachable_fraction(area) / maxf(_walk_share, 0.05)
	var expected: float = density_max * area.get_area() * open_share / 1000.0
	var count: int = floori(expected) + (1 if rng.randf() < expected - floorf(expected) else 0)
	for i: int in count:
		var slot: Slot = Slot.new()
		slot.position = Vector3(rng.randf_range(area.position.x, area.end.x), 0.0, rng.randf_range(area.position.y, area.end.y))
		if walk != null:
			var tries: int = 0
			while not walk.is_reachable(Vector2(slot.position.x, slot.position.z)) and tries < 12:
				slot.position = Vector3(rng.randf_range(area.position.x, area.end.x), 0.0, rng.randf_range(area.position.y, area.end.y))
				tries += 1
			if tries >= 12:
				continue
			# Onto the centre of its walk-grid cell (with a little jitter): a free cell's centre is at least the grid's
			# clearance from every wall, so the zombie does not start half inside a facade or a fence.
			var centre: Vector2 = walk.centre_of(walk.cell_of(Vector2(slot.position.x, slot.position.z)))
			var jitter: float = walk.cell * SNAP_JITTER
			slot.position = Vector3(centre.x + rng.randf_range(-jitter, jitter), 0.0, centre.y + rng.randf_range(-jitter, jitter))
		slot.threshold = rng.randf()
		slot.cell = c
		if safe_radius > 0.0 and Vector2(slot.position.x, slot.position.z).distance_to(safe_center) < safe_radius:
			continue
		slots.append(slot)
	return slots


func _flat_dist_sq(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length_squared()
