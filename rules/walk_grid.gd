class_name WalkGrid
extends RefCounted
## Where a body of a given radius can stand, as data: the map's solid footprints (buildings, fences, cars...) are drawn
## onto a square grid of cells, grown by `clearance`, and the free cells are split into connected regions. One region is
## marked "home" (the one holding the player start); everything outside it is solid or sealed off.
##
## Node-free: the level collects footprints from its scenes (StreetNavigation) and tests do the same. Used to keep
## zombies from being planned inside buildings or behind fences, for the zombie flow field and for the layout tests.

## A footprint: an oriented box (`center`, `half` extents, `angle` in radians around the vertical axis) or a circle
## (`radius` > 0). Coordinates are the ground plane: x = world X, y = world Z.
class Footprint extends RefCounted:
	var center: Vector2
	var half: Vector2
	var angle: float = 0.0
	var radius: float = 0.0

	static func box(at: Vector2, half_extents: Vector2, yaw: float) -> Footprint:
		var f: Footprint = Footprint.new()
		f.center = at
		f.half = half_extents
		f.angle = yaw
		return f

	static func circle(at: Vector2, r: float) -> Footprint:
		var f: Footprint = Footprint.new()
		f.center = at
		f.radius = r
		return f

const SOLID: int = 1
const NO_REGION: int = -1

var bounds: Rect2
var cell: float
var clearance: float
var width: int
var height: int
## 1 = solid (inside a footprint grown by the clearance, or outside the bounds).
var solid: PackedByteArray
## Connected region id per cell (NO_REGION for solid cells).
var region: PackedInt32Array
var region_sizes: PackedInt32Array = PackedInt32Array()
## The region that holds the player start (set by mark_home).
var home: int = NO_REGION
## Free runs along x and z per cell, from the last corridor_widths call.
var _last_hrun: PackedInt32Array
var _last_vrun: PackedInt32Array


func _init(area: Rect2, cell_size: float = 0.5, body_clearance: float = 0.35) -> void:
	bounds = area
	cell = maxf(cell_size, 0.05)
	clearance = maxf(body_clearance, 0.0)
	width = maxi(1, ceili(area.size.x / cell))
	height = maxi(1, ceili(area.size.y / cell))
	solid = PackedByteArray()
	solid.resize(width * height)
	solid.fill(0)
	region = PackedInt32Array()
	region.resize(width * height)
	region.fill(NO_REGION)


## Grid built from footprints in one go, with regions labelled and `home_point` (x, z) as the home region.
static func build(area: Rect2, footprints: Array[Footprint], cell_size: float, body_clearance: float, home_point: Vector2) -> WalkGrid:
	var g: WalkGrid = WalkGrid.new(area, cell_size, body_clearance)
	for f: Footprint in footprints:
		g.add(f)
	g.label_regions()
	g.mark_home(home_point)
	return g


func add(f: Footprint) -> void:
	if f.radius > 0.0:
		add_circle(f.center, f.radius)
	else:
		add_box(f.center, f.half, f.angle)


## Marks every cell whose centre lies within `clearance` of the oriented box, and always the cell holding its centre
## (so a small prop is never lost between cell centres).
func add_box(center: Vector2, half: Vector2, angle: float) -> void:
	_mark(_cell_floor(center))
	var c: float = cos(angle)
	var s: float = sin(angle)
	var ext: Vector2 = Vector2(absf(c) * half.x + absf(s) * half.y, absf(s) * half.x + absf(c) * half.y) + Vector2.ONE * clearance
	var lo: Vector2i = _cell_floor(center - ext)
	var hi: Vector2i = _cell_floor(center + ext)
	var hx: float = half.x + clearance
	var hy: float = half.y + clearance
	for cy: int in range(maxi(lo.y, 0), mini(hi.y, height - 1) + 1):
		for cx: int in range(maxi(lo.x, 0), mini(hi.x, width - 1) + 1):
			var d: Vector2 = centre_of(Vector2i(cx, cy)) - center
			# Box-local coordinates (rotation by -angle).
			var lx: float = absf(d.x * c - d.y * s)
			var ly: float = absf(d.x * s + d.y * c)
			if lx > hx or ly > hy:
				continue
			# Rounded corners: outside both half extents the distance is to the corner.
			var ox: float = maxf(0.0, lx - half.x)
			var oy: float = maxf(0.0, ly - half.y)
			if ox * ox + oy * oy > clearance * clearance:
				continue
			solid[cy * width + cx] = SOLID


## Marks every cell whose centre lies within `clearance` of the circle, and every cell the circle itself overlaps (a
## thin pole standing on a cell corner is in the grid, not between four free cells).
func add_circle(center: Vector2, r: float) -> void:
	var rr: float = r + clearance
	var lo: Vector2i = _cell_floor(center - Vector2.ONE * rr)
	var hi: Vector2i = _cell_floor(center + Vector2.ONE * rr)
	var half_cell: Vector2 = Vector2.ONE * cell * 0.5
	for cy: int in range(maxi(lo.y, 0), mini(hi.y, height - 1) + 1):
		for cx: int in range(maxi(lo.x, 0), mini(hi.x, width - 1) + 1):
			var c: Vector2 = centre_of(Vector2i(cx, cy))
			var inside: Vector2 = ((center - c).abs() - half_cell).max(Vector2.ZERO)
			if c.distance_squared_to(center) <= rr * rr or inside.length_squared() < r * r:
				solid[cy * width + cx] = SOLID


func _mark(c: Vector2i) -> void:
	if in_grid(c):
		solid[index_of(c)] = SOLID


## Splits the free cells into 4-connected regions.
func label_regions() -> void:
	region.fill(NO_REGION)
	region_sizes = PackedInt32Array()
	var stack: PackedInt32Array = PackedInt32Array()
	for start: int in width * height:
		if solid[start] == SOLID or region[start] != NO_REGION:
			continue
		var id: int = region_sizes.size()
		var size: int = 0
		region[start] = id
		stack.append(start)
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			size += 1
			var x: int = i % width
			if x > 0 and solid[i - 1] != SOLID and region[i - 1] == NO_REGION:
				region[i - 1] = id
				stack.append(i - 1)
			if x < width - 1 and solid[i + 1] != SOLID and region[i + 1] == NO_REGION:
				region[i + 1] = id
				stack.append(i + 1)
			if i >= width and solid[i - width] != SOLID and region[i - width] == NO_REGION:
				region[i - width] = id
				stack.append(i - width)
			if i < width * (height - 1) and solid[i + width] != SOLID and region[i + width] == NO_REGION:
				region[i + width] = id
				stack.append(i + width)
		region_sizes.append(size)


## The home region is the one at `p`, or the nearest free one within 3 m.
func mark_home(p: Vector2) -> void:
	var q: Vector2 = nearest_open(p, 3.0, false)
	home = region_at(q) if q.x != INF else NO_REGION


func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func cell_of(p: Vector2) -> Vector2i:
	return _cell_floor(p)


func index_of(c: Vector2i) -> int:
	return c.y * width + c.x


func centre_of(c: Vector2i) -> Vector2:
	return bounds.position + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func is_open(p: Vector2) -> bool:
	var c: Vector2i = _cell_floor(p)
	return in_grid(c) and solid[index_of(c)] != SOLID


func region_at(p: Vector2) -> int:
	var c: Vector2i = _cell_floor(p)
	return region[index_of(c)] if in_grid(c) else NO_REGION


## Free and connected to the player start.
func is_reachable(p: Vector2) -> bool:
	return home != NO_REGION and region_at(p) == home


func is_cell_reachable(i: int) -> bool:
	return home != NO_REGION and region[i] == home


## Centre of the nearest free (or, with `reachable_only`, home-region) cell within `max_dist` of `p`; (INF, INF) if none.
func nearest_open(p: Vector2, max_dist: float, reachable_only: bool = true) -> Vector2:
	var c0: Vector2i = _cell_floor(p)
	if _cell_ok(c0, reachable_only):
		return p
	var rings: int = ceili(max_dist / cell)
	var best: Vector2 = Vector2(INF, INF)
	var best_d: float = INF
	for r: int in range(1, rings + 1):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c: Vector2i = c0 + Vector2i(dx, dy)
				if _cell_ok(c, reachable_only):
					var d: float = centre_of(c).distance_squared_to(p)
					if d < best_d:
						best_d = d
						best = centre_of(c)
		if best_d < INF:
			return best if best_d <= max_dist * max_dist else Vector2(INF, INF)
	return best


## Share of `rect` (clipped to the bounds) covered by home-region cells.
func reachable_fraction(rect: Rect2) -> float:
	var lo: Vector2i = _cell_floor(rect.position)
	var hi: Vector2i = _cell_floor(rect.end - Vector2.ONE * 0.0001)
	var total: int = 0
	var good: int = 0
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			total += 1
			if in_grid(Vector2i(cx, cy)) and is_cell_reachable(index_of(Vector2i(cx, cy))):
				good += 1
	return float(good) / float(total) if total > 0 else 0.0


## Number of home-region cells.
func reachable_cells() -> int:
	return region_sizes[home] if home >= 0 and home < region_sizes.size() else 0


## For every home-region cell, the width in metres of the corridor through it: the shorter of its free horizontal and
## vertical runs (plus the clearance on both sides, so it measures wall to wall). Other cells get 0.
func corridor_widths() -> PackedFloat32Array:
	var hrun: PackedInt32Array = PackedInt32Array()
	hrun.resize(width * height)
	var vrun: PackedInt32Array = PackedInt32Array()
	vrun.resize(width * height)
	for y: int in height:
		var x: int = 0
		while x < width:
			if solid[y * width + x] == SOLID:
				x += 1
				continue
			var x1: int = x
			while x1 < width and solid[y * width + x1] != SOLID:
				x1 += 1
			for k: int in range(x, x1):
				hrun[y * width + k] = x1 - x
			x = x1
	for x: int in width:
		var y: int = 0
		while y < height:
			if solid[y * width + x] == SOLID:
				y += 1
				continue
			var y1: int = y
			while y1 < height and solid[y1 * width + x] != SOLID:
				y1 += 1
			for k: int in range(y, y1):
				vrun[k * width + x] = y1 - y
			y = y1
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(width * height)
	for i: int in width * height:
		out[i] = float(mini(hrun[i], vrun[i])) * cell + 2.0 * clearance if is_cell_reachable(i) else 0.0
	_last_hrun = hrun
	_last_vrun = vrun
	return out


## Groups of home-region cells whose free runs are at least `min_run` metres both across and along: where two long
## corridors cross (street crossings, alley mouths on a street, open lots). Returns the centre of each group.
## Call corridor_widths first.
func crossings(min_run: float) -> Array[Vector2]:
	if _last_hrun.is_empty():
		corridor_widths()
	var need: int = ceili(min_run / cell)
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(width * height)
	seen.fill(0)
	var out: Array[Vector2] = []
	for start: int in width * height:
		if seen[start] == 1 or not is_cell_reachable(start) or _last_hrun[start] < need or _last_vrun[start] < need:
			continue
		var stack: PackedInt32Array = PackedInt32Array([start])
		seen[start] = 1
		var sum: Vector2 = Vector2.ZERO
		var n: int = 0
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			sum += centre_of(Vector2i(i % width, i / width))
			n += 1
			for j: int in [i - 1, i + 1, i - width, i + width]:
				if j < 0 or j >= width * height or seen[j] == 1:
					continue
				if (j == i - 1 or j == i + 1) and j / width != i / width:
					continue
				if is_cell_reachable(j) and _last_hrun[j] >= need and _last_vrun[j] >= need:
					seen[j] = 1
					stack.append(j)
		out.append(sum / float(n))
	return out


func _cell_ok(c: Vector2i, reachable_only: bool) -> bool:
	if not in_grid(c):
		return false
	var i: int = index_of(c)
	return is_cell_reachable(i) if reachable_only else solid[i] != SOLID


func _cell_floor(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - bounds.position.x) / cell), floori((p.y - bounds.position.y) / cell))
