class_name FlowField
extends RefCounted
## Walking distance from every free cell of a WalkGrid to one goal (the player), and the direction that gets closer.
## Zombies whose straight line to the player is blocked by a block of buildings follow it down a corridor instead of
## pressing against the wall. Computed with Dial's algorithm (8 neighbours, costs 10 and 14 per cell, no diagonal
## corner cutting) up to `max_distance` metres, and in slices (`step(budget)`) so a large map never costs one long frame.
## The finished field stays readable while the next one is computed.
##
## Node-free; StreetNavigation drives it.

const UNSET: int = 0x3fffffff
const STRAIGHT: int = 10
const DIAGONAL: int = 14
## The 8 neighbours as (dx, dy) pairs, straight ones first (typed constants: no Array allocation in the inner loops).
const NX: PackedInt32Array = [1, -1, 0, 0, 1, 1, -1, -1]
const NY: PackedInt32Array = [0, 0, 1, -1, 1, -1, 1, -1]

var grid: WalkGrid
## Paths longer than this (metres) are not explored.
var max_distance: float = 70.0

## Finished field: cost per cell (UNSET = unknown or too far) and the goal it was computed for.
var _cost: PackedInt32Array = PackedInt32Array()
var _goal: Vector2 = Vector2(INF, INF)
var _ready: bool = false
## Counts finished fields, so callers can cache what they derived from one (ZombieDirector's arrival bearings).
var version: int = 0
## Field being computed.
var _work: PackedInt32Array = PackedInt32Array()
## Dial buckets (cost modulo 15); plain Arrays are shared by reference, so appending does not copy.
var _buckets: Array[Array] = []
var _bucket_at: int = 0
var _pending: int = 0
var _work_goal: Vector2 = Vector2(INF, INF)
var _busy: bool = false
var _limit: int = 0


func _init(walk_grid: WalkGrid, max_path_metres: float = 70.0) -> void:
	grid = walk_grid
	max_distance = max_path_metres


## True once a field has been finished.
func is_ready() -> bool:
	return _ready


## True while a new field is being computed.
func is_busy() -> bool:
	return _busy


## Goal of the finished field.
func goal() -> Vector2:
	return _goal


## Starts a new field toward `target` (x, z). The previous one stays in use until this one is finished.
func begin(target: Vector2) -> void:
	var p: Vector2 = grid.nearest_open(target, 3.0, true)
	if p.x == INF:
		p = grid.nearest_open(target, 3.0, false)
	if p.x == INF:
		_busy = false
		return
	var n: int = grid.width * grid.height
	if _work.size() != n:
		_work.resize(n)
	_work.fill(UNSET)
	_buckets.clear()
	for i: int in DIAGONAL + 1:
		_buckets.append([])
	_bucket_at = 0
	_pending = 1
	_limit = int(max_distance / grid.cell * STRAIGHT)
	var start: int = grid.index_of(grid.cell_of(p))
	_work[start] = 0
	_buckets[0].append(start)
	_work_goal = target
	_busy = true


## Settles up to `budget` cells. Returns true when the field is finished (it then replaces the old one).
func step(budget: int) -> bool:
	if not _busy:
		return true
	var w: int = grid.width
	var h: int = grid.height
	var solid: PackedByteArray = grid.solid
	var settled: int = 0
	var size: int = DIAGONAL + 1
	var cost_now: int = _bucket_at
	while _pending > 0 and settled < budget:
		var b: Array = _buckets[cost_now % size]
		if b.is_empty():
			cost_now += 1
			continue
		var i: int = b.pop_back()
		_pending -= 1
		if _work[i] != cost_now:
			continue  # Stale entry: a cheaper path was found later.
		settled += 1
		var x: int = i % w
		var y: int = i / w
		for k: int in 8:
			var nx: int = x + NX[k]
			var ny: int = y + NY[k]
			if nx < 0 or nx >= w or ny < 0 or ny >= h:
				continue
			var j: int = ny * w + nx
			if solid[j] == WalkGrid.SOLID:
				continue
			var step_cost: int = STRAIGHT
			if k >= 4:
				# No cutting round a solid corner.
				if solid[y * w + nx] == WalkGrid.SOLID or solid[ny * w + x] == WalkGrid.SOLID:
					continue
				step_cost = DIAGONAL
			var c: int = cost_now + step_cost
			if c < _work[j] and c <= _limit:
				_work[j] = c
				_buckets[c % size].append(j)
				_pending += 1
	_bucket_at = cost_now
	if _pending > 0:
		return false
	var done: PackedInt32Array = _cost
	_cost = _work
	_work = done
	_goal = _work_goal
	_ready = true
	_busy = false
	version += 1
	return true


## Computes a whole field at once (tests, start-up).
func compute(target: Vector2) -> void:
	begin(target)
	while not step(1 << 20):
		pass


## Walking distance in metres from `p` (x, z) to the goal; INF if unknown, sealed off or beyond max_distance.
func distance_at(p: Vector2) -> float:
	if not _ready:
		return INF
	var c: Vector2i = grid.cell_of(p)
	if not grid.in_grid(c):
		return INF
	var v: int = _cost[grid.index_of(c)]
	if v == UNSET:
		v = _best_neighbour_cost(c)
		if v == UNSET:
			return INF
	return float(v) / STRAIGHT * grid.cell


## Unit direction (x, z) from `p` toward the cheapest neighbouring cell; zero if there is no field here.
func direction_at(p: Vector2) -> Vector2:
	if not _ready:
		return Vector2.ZERO
	var c: Vector2i = grid.cell_of(p)
	if not grid.in_grid(c):
		return Vector2.ZERO
	var w: int = grid.width
	var here: int = _cost[grid.index_of(c)]
	var best: int = here
	var best_c: Vector2i = c
	for k: int in 8:
		var n: Vector2i = c + Vector2i(NX[k], NY[k])
		if not grid.in_grid(n):
			continue
		if k >= 4 and (grid.solid[c.y * w + n.x] == WalkGrid.SOLID or grid.solid[n.y * w + c.x] == WalkGrid.SOLID):
			continue
		var v: int = _cost[n.y * w + n.x]
		if v < best:
			best = v
			best_c = n
	if best_c == c:
		return Vector2.ZERO
	return (grid.centre_of(best_c) - p).normalized()


## Where someone walking the field from `p` first comes within `radius` metres (walking distance) of the goal: the
## mouth of the street or alley it arrives from. `p` itself if it is already that close; (INF, INF) without a path.
func approach_point(p: Vector2, radius: float) -> Vector2:
	if distance_at(p) == INF:
		return Vector2(INF, INF)
	var limit: int = int(radius / grid.cell * STRAIGHT)
	var c: Vector2i = grid.cell_of(p)
	var w: int = grid.width
	for i: int in grid.width + grid.height:
		var here: int = _cost[c.y * w + c.x]
		if here <= limit:
			break
		var best: int = here
		var best_c: Vector2i = c
		for k: int in 8:
			var n: Vector2i = c + Vector2i(NX[k], NY[k])
			if grid.in_grid(n) and _cost[n.y * w + n.x] < best:
				best = _cost[n.y * w + n.x]
				best_c = n
		if best_c == c:
			break
		c = best_c
	return grid.centre_of(c)


func _best_neighbour_cost(c: Vector2i) -> int:
	var best: int = UNSET
	for k: int in 8:
		var n: Vector2i = c + Vector2i(NX[k], NY[k])
		if grid.in_grid(n):
			best = mini(best, _cost[grid.index_of(n)] + (STRAIGHT if k < 4 else DIAGONAL))
	return best if best < UNSET else UNSET
