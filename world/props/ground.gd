class_name Ground
extends StaticBody3D
## The street surface. A big plane with a procedural world-space shader (see ground.gdshader), so it can be much
## larger than the playable area and the real end of the map is never visible. Street layout, colours and wear are
## shader parameters on the material in the Inspector.

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
	if mat != null:
		mat.set_shader_parameter("detailed", detailed)
