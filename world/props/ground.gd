class_name Ground
extends StaticBody3D
## The street surface. A big plane with a procedural world-space shader (see ground.gdshader), so it can be much
## larger than the playable area and the real end of the map is never visible. The level's street layout is set here
## (roads and lots as rects); colours and wear are shader parameters on the material in the Inspector.

const MAX_ROADS: int = 16
const MAX_LOTS: int = 12

## Plane edge length in metres. Keep it well beyond the level bounds plus what the camera can see.
@export_range(50, 2000, 10) var extent: float = 400.0:
	set(value):
		extent = value
		_refresh()
## Full detail (cracks, patches, puddles, manholes). Off for the cheap mobile profile.
@export var detailed: bool = true:
	set(value):
		detailed = value
		_refresh()
## The level's playable area (x = world X, y = world Z). Inside it the ground follows `roads` and `lots`; outside it a
## regular street grid continues under the skyline backdrop. Empty roads = the grid everywhere.
@export var play_area: Rect2 = Rect2(0, 0, 120, 120):
	set(value):
		play_area = value
		_refresh()
## Asphalt with lane lines, centre line and crosswalks; the long side of a rect is its direction of travel. A road may
## run past the play area (it then continues through the backdrop). At most 16.
@export var roads: Array[Rect2] = []:
	set(value):
		roads = value
		_refresh()
## Asphalt without markings (parking lots, yards). At most 12.
@export var lots: Array[Rect2] = []:
	set(value):
		lots = value
		_refresh()

var _material: ShaderMaterial


func _ready() -> void:
	_refresh()


## Call down from the level with the graphics profile's setting.
func set_detail(on: bool) -> void:
	detailed = on


func _refresh() -> void:
	if not is_inside_tree():
		return
	var mesh_node: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node == null:
		return
	var plane: PlaneMesh = mesh_node.mesh as PlaneMesh
	if plane != null:
		plane.size = Vector2(extent, extent)
	var mat: ShaderMaterial = mesh_node.get_surface_override_material(0) as ShaderMaterial
	if mat == null:
		return
	if _material == null or mat != _material:
		# Own copy: the layout is per level, the material in ground.tscn is shared.
		_material = mat.duplicate() as ShaderMaterial
		mesh_node.set_surface_override_material(0, _material)
	_material.set_shader_parameter("detailed", detailed)
	_material.set_shader_parameter("play_area", _rect4(play_area))
	_material.set_shader_parameter("roads", _pack(roads, MAX_ROADS))
	_material.set_shader_parameter("road_count", mini(roads.size(), MAX_ROADS))
	_material.set_shader_parameter("lots", _pack(lots, MAX_LOTS))
	_material.set_shader_parameter("lot_count", mini(lots.size(), MAX_LOTS))


## The shader material in use (tests read its parameters).
func material() -> ShaderMaterial:
	return _material


static func _rect4(r: Rect2) -> Vector4:
	return Vector4(r.position.x, r.position.y, r.end.x, r.end.y)


static func _pack(rects: Array[Rect2], limit: int) -> PackedVector4Array:
	var out: PackedVector4Array = PackedVector4Array()
	out.resize(limit)
	for i: int in mini(rects.size(), limit):
		out[i] = _rect4(rects[i])
	return out
