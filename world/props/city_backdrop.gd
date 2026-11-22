@tool
class_name CityBackdrop
extends Node3D
## A ring of cheap low-detail buildings that continues the city street grid beyond the playable area, so the camera
## never sees the end of the map. All buildings are ONE MultiMesh (one draw call, no shadows, no collision).
## Buildings near the playable area are kept low so they never hide the player from the camera: a building height is
## limited to `height_per_metre` times its distance from the playable area (0.85 suits the current 41.5 degree camera pitch;
## tan(pitch) is the exact limit).

## Playable area in metres (x = world X, y = world Z); no backdrop buildings are placed inside it.
@export var inner_rect: Rect2 = Rect2(0, 0, 120, 120):
	set(value):
		inner_rect = value
		_rebuild()
## Distance between street centre lines. Must match the ground shader (street_spacing).
@export_range(5, 100, 1) var block_spacing: float = 20.0:
	set(value):
		block_spacing = value
		_rebuild()
## How many rings of city blocks surround the playable area.
@export_range(1, 12) var rings: int = 4:
	set(value):
		rings = value
		_rebuild()
@export_range(2, 20, 0.5) var block_width: float = 10.0:
	set(value):
		block_width = value
		_rebuild()
@export_range(1, 10, 0.5) var building_depth: float = 3.0:
	set(value):
		building_depth = value
		_rebuild()
## Offset of each of the two buildings of a block from the block centre (leaves an alley between them).
@export_range(1, 10, 0.25) var building_offset: float = 3.5:
	set(value):
		building_offset = value
		_rebuild()
@export_range(1, 40, 0.5) var min_height: float = 3.5:
	set(value):
		min_height = value
		_rebuild()
@export_range(2, 80, 0.5) var max_height: float = 26.0:
	set(value):
		max_height = value
		_rebuild()
## Height allowed per metre of distance from the playable area (keeps the camera view of the player clear).
@export_range(0.2, 4.0, 0.05) var height_per_metre: float = 0.85:
	set(value):
		height_per_metre = value
		_rebuild()
## Fraction of windows that are lit, from darkest to brightest building.
@export var lit_fraction: Vector2 = Vector2(0.15, 0.5):
	set(value):
		lit_fraction = value
		_rebuild()
@export var facade_colors: PackedColorArray = PackedColorArray([Color(0.13, 0.1, 0.09), Color(0.1, 0.11, 0.14), Color(0.14, 0.12, 0.09), Color(0.09, 0.12, 0.12)]):
	set(value):
		facade_colors = value
		_rebuild()
## Areas kept free of backdrop buildings (x = world X, y = world Z): the streets that run out of the playable area, so
## the city visibly continues past the fences that close them.
@export var open_rects: Array[Rect2] = []:
	set(value):
		open_rects = value
		_rebuild()
@export var seed_value: int = 11:
	set(value):
		seed_value = value
		_rebuild()
@export var material: ShaderMaterial:
	set(value):
		material = value
		_rebuild()

var _instances: MultiMeshInstance3D
var _pending: bool = false


func _ready() -> void:
	_rebuild()


func building_count() -> int:
	return _instances.multimesh.instance_count if _instances != null and _instances.multimesh != null else 0


## Footprint rects ("rect": Rect2 on x/z) and "height" of the generated buildings, for tests and tools.
func footprints() -> Array[Dictionary]:
	return _layout()


func _rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_do_rebuild.call_deferred()


func _do_rebuild() -> void:
	_pending = false
	if not is_inside_tree():
		return
	if _instances == null:
		_instances = get_node_or_null("Buildings") as MultiMeshInstance3D
	if _instances == null:
		_instances = MultiMeshInstance3D.new()
		_instances.name = "Buildings"
		add_child(_instances)
	var layout: Array[Dictionary] = _layout()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = layout.size()
	for i: int in layout.size():
		var b: Dictionary = layout[i]
		var rect: Rect2 = b["rect"]
		var h: float = b["height"]
		var centre: Vector2 = rect.get_center()
		var scale_basis: Basis = Basis.from_scale(Vector3(rect.size.x, h, rect.size.y))
		mm.set_instance_transform(i, Transform3D(scale_basis, Vector3(centre.x, h / 2.0, centre.y)))
		mm.set_instance_color(i, b["color"])
		mm.set_instance_custom_data(i, Color(rect.size.x, h, rect.size.y, 0.0))
	_instances.multimesh = mm
	_instances.material_override = material
	_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var span: float = float(rings + 2) * block_spacing
	var box: Rect2 = inner_rect.grow(span)
	_instances.custom_aabb = AABB(Vector3(box.position.x, 0, box.position.y), Vector3(box.size.x, max_height + 1.0, box.size.y))


func _layout() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var nx: int = roundi(inner_rect.size.x / block_spacing)
	var nz: int = roundi(inner_rect.size.y / block_spacing)
	var colors: PackedColorArray = facade_colors if facade_colors.size() > 0 else PackedColorArray([Color(0.1, 0.1, 0.12)])
	for i: int in range(-rings, nx + rings):
		for j: int in range(-rings, nz + rings):
			if i >= 0 and i < nx and j >= 0 and j < nz:
				continue
			var cx: float = inner_rect.position.x + block_spacing * (float(i) + 0.5)
			var cz: float = inner_rect.position.y + block_spacing * (float(j) + 0.5)
			var along_x: bool = (i + j) % 2 == 0
			var base_color: Color = colors[rng.randi() % colors.size()]
			for side: int in [-1, 1]:
				var rect: Rect2
				if along_x:
					rect = Rect2(cx - block_width / 2.0, cz + float(side) * building_offset - building_depth / 2.0, block_width, building_depth)
				else:
					rect = Rect2(cx + float(side) * building_offset - building_depth / 2.0, cz - block_width / 2.0, building_depth, block_width)
				var gap: float = _distance_to_rect(rect, inner_rect)
				var wanted: float = rng.randf_range(min_height, max_height)
				var h: float = clampf(minf(wanted, gap * height_per_metre), min_height, max_height)
				var shade: float = rng.randf_range(0.8, 1.25)
				var lit: float = lerpf(lit_fraction.x, lit_fraction.y, rng.randf())
				var col: Color = Color(base_color.r * shade, base_color.g * shade, base_color.b * shade, lit)
				if not _blocks_street(rect):
					out.append({"rect": rect, "height": h, "color": col})
	return out


func _blocks_street(rect: Rect2) -> bool:
	for open: Rect2 in open_rects:
		if open.grow(0.5).intersects(rect):
			return true
	return false


static func _distance_to_rect(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x))
	var dy: float = maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y))
	return sqrt(dx * dx + dy * dy)
