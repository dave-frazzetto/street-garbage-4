class_name StreetNavigation
extends Node
## Where things can walk in a level, for the zombie spawners and the zombies themselves. At start the level hands it the
## nodes that hold its solid scenery; it draws their layer-1 colliders onto a WalkGrid (rules/walk_grid.gd) and keeps a
## FlowField (rules/flow_field.gd) toward the player up to date, a slice per physics frame.
## No navigation mesh: the streets are axis-aligned boxes and a grid is cheap on the single-threaded web build.

## Edge of a grid cell in metres.
@export_range(0.25, 4.0, 0.25) var cell_size: float = 1.0
## Solid scenery is grown by this much, about a zombie's radius, so a free cell has room for a body.
@export_range(0.0, 2.0, 0.05) var clearance: float = 0.4
## Paths longer than this (metres) are not explored by the flow field.
@export_range(10, 300, 5) var flow_max_distance: float = 70.0
## Seconds between flow field updates while the player moves.
@export_range(0.1, 5.0, 0.05) var flow_refresh_seconds: float = 0.5
## The flow field is recomputed only after the player moved this far (metres).
@export_range(0.0, 10.0, 0.25) var flow_repath_distance: float = 1.0
## Grid cells settled per physics frame (spreads the cost over several frames; about 3 microseconds a cell on desktop,
## several times that on the single-threaded web build).
@export_range(100, 100000, 100) var flow_cells_per_frame: int = 600

var walk_grid: WalkGrid
var flow: FlowField
var target: Node3D
var _timer: float = 0.0


## Call down: build the grid from the solid scenery under `roots`; `home` (the player start) marks the reachable area.
func build(area: Rect2, home: Vector3, roots: Array[Node]) -> void:
	walk_grid = WalkGrid.build(area, footprints_of(roots), cell_size, clearance, Vector2(home.x, home.z))
	flow = FlowField.new(walk_grid, flow_max_distance)
	flow.compute(Vector2(home.x, home.z))


## Call down: keep the flow field pointing at this node.
func track(chase_target: Node3D) -> void:
	target = chase_target
	_timer = 0.0


func _physics_process(delta: float) -> void:
	if flow == null:
		return
	if flow.is_busy():
		flow.step(flow_cells_per_frame)
		return
	if target == null or not is_instance_valid(target):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = flow_refresh_seconds
	var p: Vector2 = Vector2(target.global_position.x, target.global_position.z)
	if not flow.is_ready() or p.distance_to(flow.goal()) >= flow_repath_distance:
		flow.begin(p)
		flow.step(flow_cells_per_frame)


## Ground footprints of every solid (layer 1) static collider under `roots`: boxes and cylinders whose bottom is below
## head height. Used by the level at start and by the layout tests.
static func footprints_of(roots: Array[Node]) -> Array[WalkGrid.Footprint]:
	var out: Array[WalkGrid.Footprint] = []
	for root: Node in roots:
		if root == null:
			continue
		var bodies: Array[Node] = root.find_children("*", "StaticBody3D", true, false)
		if root is StaticBody3D:
			bodies.append(root)
		for node: Node in bodies:
			var body: StaticBody3D = node as StaticBody3D
			if body == null or (body.collision_layer & 1) == 0:
				continue
			for child: Node in body.get_children():
				var cs: CollisionShape3D = child as CollisionShape3D
				if cs == null or cs.disabled or cs.shape == null:
					continue
				var f: WalkGrid.Footprint = _footprint(cs)
				if f != null:
					out.append(f)
	return out


static func _footprint(cs: CollisionShape3D) -> WalkGrid.Footprint:
	var t: Transform3D = cs.global_transform
	var at: Vector2 = Vector2(t.origin.x, t.origin.z)
	var sx: float = t.basis.x.length()
	var sy: float = t.basis.y.length()
	var sz: float = t.basis.z.length()
	var box: BoxShape3D = cs.shape as BoxShape3D
	if box != null:
		if t.origin.y - box.size.y * sy / 2.0 > 1.6:
			return null
		var angle: float = atan2(-t.basis.x.z, t.basis.x.x)
		return WalkGrid.Footprint.box(at, Vector2(box.size.x * sx, box.size.z * sz) / 2.0, angle)
	var cyl: CylinderShape3D = cs.shape as CylinderShape3D
	if cyl != null:
		if t.origin.y - cyl.height * sy / 2.0 > 1.6:
			return null
		return WalkGrid.Footprint.circle(at, cyl.radius * maxf(sx, sz))
	var sphere: SphereShape3D = cs.shape as SphereShape3D
	if sphere != null:
		return WalkGrid.Footprint.circle(at, sphere.radius * maxf(sx, sz))
	return null
