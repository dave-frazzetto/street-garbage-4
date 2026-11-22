extends TestCase
## The street layout of freedom_city.tscn (slice 16): the level's solid footprints are drawn on a 0.5 m WalkGrid for a
## body of the player's radius and flood-filled from the player start. Everything the run needs is reachable, almost
## all free ground is one connected area, and the streets are corridors: little open ground, few crossings and only a
## few ways out of any spot. Also checks that the runtime grid (StreetNavigation) only plans zombies where the player
## can get to. Prints the layout numbers.

const LEVEL: PackedScene = preload("res://world/levels/freedom_city.tscn")
const TUNING: GameTuning = preload("res://data/config/game_tuning.tres")
## Player body radius after the 15% size increase (0.35 * 1.15), plus a little.
const PLAYER_RADIUS: float = 0.42
const CELL: float = 0.5
## "Escape routes": distinct ways out of a 30 m circle around a street spot.
const ESCAPE_RADIUS: float = 30.0
## Depth of the rim band (so a parked car on the circle does not split one street into two ways out).
const RIM_BAND: float = 4.0
## Rim groups smaller than this (m2) are slivers, not ways out.
const MIN_EXIT_AREA: float = 6.0
## Walker body radius, for the population-slot overlap query.
const ZOMBIE_RADIUS: float = 0.3
## Mobile-web budget for the level scene (it had 2565 nodes and 168 lights as the old grid city).
const MAX_NODES: int = 2250
const MAX_LIGHTS: int = 115

var level: Level
var grid: WalkGrid


func _ready() -> void:
	level = LEVEL.instantiate() as Level
	add_child(level)
	run_all()


func test_1_everything_is_reachable_from_the_start() -> void:
	await wait_frames(2)
	var t0: int = Time.get_ticks_msec()
	var start: Vector3 = level.player_start_position()
	grid = WalkGrid.build(level.bounds, StreetNavigation.footprints_of(level.solid_roots()), CELL, PLAYER_RADIUS, Vector2(start.x, start.z))
	print("  0.5 m grid built in %d ms" % (Time.get_ticks_msec() - t0))
	check(grid.is_reachable(Vector2(start.x, start.z)), "the player start is free")
	for node: Node in level.get_node("GearSpawnPoints").get_children():
		var p: Vector3 = (node as Node3D).global_position
		check(grid.is_reachable(Vector2(p.x, p.z)), "gear spot %s at %s is reachable" % [node.name, p])
	var ex: Vector3 = level.extraction.global_position
	check(grid.is_reachable(Vector2(ex.x, ex.z)), "the extraction zone is reachable")
	for node: Node in level.get_node("Hordes").get_children():
		var h: Vector3 = (node as Node3D).global_position
		check(grid.nearest_open(Vector2(h.x, h.z), 4.0).x != INF, "horde %s stands in reachable ground" % node.name)
	var open: int = 0
	for i: int in grid.width * grid.height:
		if grid.solid[i] != WalkGrid.SOLID:
			open += 1
	var share: float = float(grid.reachable_cells()) / float(open)
	print("  reachable %.0f m2 of %.0f m2 free ground (%.0f%%)" % [grid.reachable_cells() * CELL * CELL, open * CELL * CELL, share * 100.0])
	check(share > 0.95, "almost all free ground is one connected area, no big sealed pockets (%.0f%%)" % (share * 100.0))


func test_2_streets_are_corridors() -> void:
	var widths: PackedFloat32Array = grid.corridor_widths()
	var total: int = grid.reachable_cells()
	var under: Dictionary = {5.0: 0, 8.0: 0, 12.0: 0}
	for w: float in widths:
		if w <= 0.0:
			continue
		for limit: float in under.keys():
			if w < limit:
				under[limit] += 1
	var map_share: float = float(total) / float(grid.width * grid.height)
	print("  walkable share of the map %.0f%%" % (map_share * 100.0))
	for limit: float in under.keys():
		print("  walkable ground in corridors narrower than %.0f m: %.0f%%" % [limit, 100.0 * under[limit] / total])
	var roads: Array[Rect2] = (level.get_node("Ground") as Ground).roads
	var road_crossings: int = 0
	for i: int in roads.size():
		for j: int in range(i + 1, roads.size()):
			if roads[i].intersects(roads[j]) and roads[i].intersection(roads[j]).intersects(level.bounds):
				road_crossings += 1
	var crossings: Array[Vector2] = _merged(grid.crossings(20.0), 10.0)
	print("  road crossings %d; open spots with 20 m runs both ways (crossings, alley mouths, lots): %d" % [road_crossings, crossings.size()])
	check(map_share < 0.45, "most of the map is buildings (walkable %.0f%%)" % (map_share * 100.0))
	check(float(under[12.0]) / total > 0.6, "most walkable ground is in corridors under 12 m wide")
	check(float(under[8.0]) / total > 0.35, "a good share of it under 8 m")
	check(float(under[5.0]) / total > 0.08, "there are narrow alleys and passages under 5 m")
	check(road_crossings >= 1 and road_crossings <= 3, "few road crossings (%d)" % road_crossings)
	check(crossings.size() <= 18, "few open junctions (%d)" % crossings.size())


func test_3_few_ways_out_of_any_street_spot() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var samples: int = 0
	var total: int = 0
	var most: int = 0
	var hist: Dictionary = {}
	while samples < 60:
		var p: Vector2 = Vector2(rng.randf_range(2, 118), rng.randf_range(2, 118))
		if not grid.is_reachable(p):
			continue
		samples += 1
		var n: int = _escape_routes(p, ESCAPE_RADIUS)
		total += n
		most = maxi(most, n)
		hist[n] = int(hist.get(n, 0)) + 1
	var mean: float = float(total) / samples
	print("  ways out of a %d m circle: mean %.1f, most %d, histogram %s" % [int(ESCAPE_RADIUS), mean, most, hist])
	check(mean <= 3.8, "on average at most 3.8 ways out within %d m (%.1f)" % [int(ESCAPE_RADIUS), mean])
	check(most <= 8, "never more than 8 ways out, even at the busiest crossing (%d)" % most)


func test_4_runtime_grid_only_plans_reachable_zombies() -> void:
	var nav: StreetNavigation = level.navigation
	var start: Vector3 = level.player_start_position()
	nav.build(level.bounds, start, level.solid_roots())
	var pop: PopulationGrid = PopulationGrid.new(level.bounds, 1234, TUNING.world_density_max(), 10.0, Vector2(start.x, start.z), TUNING.start_safe_radius)
	pop.walk = nav.walk_grid
	var bad: int = 0
	var overlapping: int = 0
	var slots: Array[PopulationGrid.Slot] = pop.all_slots()
	for s: PopulationGrid.Slot in slots:
		if grid.nearest_open(Vector2(s.position.x, s.position.z), 0.5).x == INF:
			bad += 1
			printerr("  slot at %s is off the player's reachable ground" % s.position)
		if _overlaps_scenery(s.position, ZOMBIE_RADIUS):
			overlapping += 1
			printerr("  slot at %s overlaps scenery" % s.position)
	print("  %d world slots at full density, %d outside the player's reach, %d overlapping scenery" % [slots.size(), bad, overlapping])
	check(slots.size() > 50, "the world is populated (%d slots)" % slots.size())
	check_eq(bad, 0, "world zombies are planned where the player can reach")
	check_eq(overlapping, 0, "world zombies do not start inside a wall, fence or car (physics query)")
	var t0: int = Time.get_ticks_usec()
	nav.flow.compute(Vector2(60, 67))
	print("  one flow field from the middle of Main Avenue: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var probe: Vector2 = Vector2(68, 40)
	check(nav.flow.distance_at(probe) < INF, "Cross Street is within the flow field of Main Avenue")
	var d: Vector2 = nav.flow.direction_at(probe)
	check(d.y > 0.5, "the flow leads down Cross Street toward Main Avenue (%s)" % d)


func test_5_object_count_stays_mobile_friendly() -> void:
	var nodes: int = _count(level)
	var lights: int = level.find_children("*", "Light3D", true, false).size()
	print("  level nodes %d, lights %d" % [nodes, lights])
	check(nodes < MAX_NODES, "level nodes stay under %d (old grid city 2565): %d" % [MAX_NODES, nodes])
	check(lights < MAX_LIGHTS, "level lights stay under %d (old grid city 168): %d" % [MAX_LIGHTS, lights])


func test_6_camera_sees_what_matters() -> void:
	# The gameplay camera looks down from the south-east: a tall building just south or east of a spot hides it, and
	# two or more faded buildings in a row hide it completely. Gear spots, the start and the extraction must be hidden
	# by at most one building.
	var rig: IsoCamera = level.camera_rig
	var spots: Dictionary = {"start": level.player_start_position(), "extraction": level.extraction.global_position}
	for node: Node in level.get_node("GearSpawnPoints").get_children():
		spots[node.name] = (node as Node3D).global_position
	var worst: int = 0
	for key: String in spots.keys():
		var n: int = _buildings_in_view(spots[key], rig.yaw_degrees, rig.pitch_degrees)
		worst = maxi(worst, n)
		check(n <= 1, "%s at %s is hidden by at most one building (%d)" % [key, spots[key], n])
	print("  most buildings between a gear / start / extraction spot and the camera: %d" % worst)


## Distinct ways out of the circle of `radius` around `p`: flood fill inside the circle, then count the separate groups
## of reached cells on its rim.
func _escape_routes(p: Vector2, radius: float) -> int:
	var c0: Vector2i = grid.cell_of(p)
	var r_cells: int = ceili(radius / CELL)
	var seen: Dictionary = {}
	var rim: Dictionary = {}
	var stack: Array[Vector2i] = [c0]
	seen[c0] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		var off: float = Vector2(c - c0).length()
		if off >= r_cells - RIM_BAND / CELL:
			rim[c] = true
		for n: Vector2i in [c + Vector2i.LEFT, c + Vector2i.RIGHT, c + Vector2i.UP, c + Vector2i.DOWN]:
			if seen.has(n) or not grid.in_grid(n) or not grid.is_cell_reachable(grid.index_of(n)):
				continue
			if Vector2(n - c0).length() > r_cells:
				continue
			seen[n] = true
			stack.append(n)
	var groups: int = 0
	var done: Dictionary = {}
	for c: Vector2i in rim.keys():
		if done.has(c):
			continue
		var size: int = 0
		var s: Array[Vector2i] = [c]
		done[c] = true
		while not s.is_empty():
			var k: Vector2i = s.pop_back()
			size += 1
			for dx: int in [-1, 0, 1]:
				for dy: int in [-1, 0, 1]:
					var n: Vector2i = k + Vector2i(dx, dy)
					if rim.has(n) and not done.has(n):
						done[n] = true
						s.append(n)
		if size * CELL * CELL >= MIN_EXIT_AREA:
			groups += 1
	return groups


## Points closer than `dist` merged into one (their mean).
func _merged(points: Array[Vector2], dist: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var counts: Array[int] = []
	for p: Vector2 in points:
		var hit: int = -1
		for i: int in out.size():
			if out[i].distance_to(p) < dist:
				hit = i
				break
		if hit < 0:
			out.append(p)
			counts.append(1)
		else:
			out[hit] = (out[hit] * counts[hit] + p) / float(counts[hit] + 1)
			counts[hit] += 1
	return out


## True if a body of `radius` standing at `p` would overlap a solid (layer 1) collider.
func _overlaps_scenery(p: Vector3, radius: float) -> bool:
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, 0.9, p.z))
	q.collision_mask = 1
	return not level.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Buildings (taller than a person) crossed by the line from `p` (1 m up) toward a camera at this yaw and pitch.
func _buildings_in_view(p: Vector3, yaw_degrees: float, pitch_degrees: float) -> int:
	var to_cam: Vector2 = Vector2(sin(deg_to_rad(yaw_degrees)), cos(deg_to_rad(yaw_degrees)))
	var tan_pitch: float = tan(deg_to_rad(pitch_degrees))
	var n: int = 0
	for node: Node in level.buildings.get_children():
		var b: Building = node as Building
		if b == null or b.size.y < 1.6:
			continue
		var reach: float = (b.size.y - 1.0) / tan_pitch
		var half: Vector2 = Vector2(b.size.x, b.size.z) / 2.0
		var c: Vector2 = Vector2(b.global_position.x, b.global_position.z)
		for i: int in 25:
			var q: Vector2 = Vector2(p.x, p.z) + to_cam * (reach * float(i) / 24.0) - c
			if absf(q.x) <= half.x and absf(q.y) <= half.y:
				n += 1
				break
	return n


func _count(n: Node) -> int:
	var c: int = 1
	for ch: Node in n.get_children():
		c += _count(ch)
	return c
