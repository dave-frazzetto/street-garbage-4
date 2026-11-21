@tool
class_name Fence
extends StaticBody3D
## A straight run of perimeter fence: concrete barrier base, steel posts, chain-link panel and a top rail. The run is
## `length` metres along local X and is centred on the node, so rotate it 90 degrees for the east and west sides.
## One box collider on the world layer blocks the player, zombies and bullets for the full height.
## Everything is built from primitives so the look can be swapped later without touching the layout.

@export_range(1.0, 400.0, 0.5) var length: float = 10.0:
	set(value):
		length = value
		_refresh()
## Total height including the concrete base.
@export_range(1.0, 10.0, 0.1) var height: float = 3.2:
	set(value):
		height = value
		_refresh()
## Height of the solid concrete base under the chain-link.
@export_range(0.2, 3.0, 0.05) var base_height: float = 0.9:
	set(value):
		base_height = value
		_refresh()
## Thickness of the collider and base across the fence line.
@export_range(0.1, 2.0, 0.05) var thickness: float = 0.5:
	set(value):
		thickness = value
		_refresh()
## Distance between steel posts.
@export_range(1.0, 20.0, 0.5) var post_spacing: float = 4.0:
	set(value):
		post_spacing = value
		_refresh()
@export var concrete_color: Color = Color(0.3, 0.29, 0.28):
	set(value):
		concrete_color = value
		_refresh()
@export var steel_color: Color = Color(0.2, 0.21, 0.23):
	set(value):
		steel_color = value
		_refresh()
## Reflective hazard stripe along the base (set alpha to 0 to hide).
@export var stripe_color: Color = Color(1.0, 0.62, 0.15, 1.0):
	set(value):
		stripe_color = value
		_refresh()
## Chain-link look (diamond mesh shader). Shared between fences; the size is set per fence through a duplicate.
@export var mesh_material: ShaderMaterial:
	set(value):
		mesh_material = value
		_refresh()

const POST_SIZE: float = 0.14


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null:
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(length, height, thickness)
		shape_node.shape = box
		shape_node.position = Vector3(0, height / 2.0, 0)
	var concrete: StandardMaterial3D = _flat(concrete_color, 0.95)
	var steel: StandardMaterial3D = _flat(steel_color, 0.5)
	steel.metallic = 0.6
	_set_box("Base", Vector3(length, base_height, thickness), Vector3(0, base_height / 2.0, 0), concrete)
	var stripe_h: float = minf(0.18, base_height * 0.25)
	var stripe: MeshInstance3D = _set_box("Stripe", Vector3(length, stripe_h, thickness + 0.02), Vector3(0, base_height * 0.6, 0), _flat(stripe_color, 0.4))
	if stripe != null:
		stripe.visible = stripe_color.a > 0.0
		(stripe.material_override as StandardMaterial3D).emission_enabled = true
		(stripe.material_override as StandardMaterial3D).emission = stripe_color
		(stripe.material_override as StandardMaterial3D).emission_energy_multiplier = 0.35
	_set_box("TopRail", Vector3(length, POST_SIZE, POST_SIZE), Vector3(0, height - POST_SIZE / 2.0, 0), steel)
	var panel: MeshInstance3D = get_node_or_null("Panel") as MeshInstance3D
	if panel != null:
		var panel_h: float = maxf(0.1, height - base_height)
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(length, panel_h)
		panel.mesh = quad
		panel.position = Vector3(0, base_height + panel_h / 2.0, 0)
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_material != null:
			var mat: ShaderMaterial = mesh_material.duplicate() as ShaderMaterial
			mat.set_shader_parameter("panel_size", Vector2(length, panel_h))
			panel.material_override = mat
	_build_posts(steel)


func _flat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _set_box(node_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node: MeshInstance3D = get_node_or_null(node_name) as MeshInstance3D
	if node == null:
		return null
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	return node


func _build_posts(mat: Material) -> void:
	var posts: MultiMeshInstance3D = get_node_or_null("Posts") as MultiMeshInstance3D
	if posts == null:
		return
	var count: int = maxi(2, ceili(length / post_spacing) + 1)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(POST_SIZE, height, POST_SIZE)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i: int in count:
		var x: float = -length / 2.0 + length * float(i) / float(count - 1)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, height / 2.0, 0)))
	posts.multimesh = mm
	posts.material_override = mat


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	for child_name: String in ["CollisionShape3D", "Base", "Panel", "Posts", "TopRail"]:
		if get_node_or_null(child_name) == null:
			warnings.append("Fence needs a child named %s (use fence.tscn)." % child_name)
	return warnings
