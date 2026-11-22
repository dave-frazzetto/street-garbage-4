class_name ModelLook
extends RefCounted
## Shared "readable at night" look for generated models: a brightness multiplier and a self-lit share of the texture.
## The lifted materials are copies shared by everything that uses the same source material and settings, so the imported
## resources are never modified and there is one copy per setting, not one per instance.

const OUTLINE_SHADER: Shader = preload("res://world/characters/outline.gdshader")

static var _lit_materials: Dictionary = {}
static var _outline_materials: Dictionary = {}


## Applies the lifted copy of every material on `mesh` as a per-surface override. A visible `outline` colour (alpha above 0)
## adds a silhouette outline of `outline_width` metres as the next render pass.
static func lift(mesh: MeshInstance3D, brightness: float, glow: float, outline: Color = Color(0, 0, 0, 0), outline_width: float = 0.04) -> void:
	if mesh.mesh == null:
		return
	for surface: int in mesh.mesh.get_surface_count():
		var source: StandardMaterial3D = mesh.get_active_material(surface) as StandardMaterial3D
		if source == null:
			continue
		var key: Array = [source, brightness, glow, outline, outline_width]
		if not _lit_materials.has(key):
			var lit: StandardMaterial3D = source.duplicate() as StandardMaterial3D
			lit.albedo_color = Color(brightness, brightness, brightness, source.albedo_color.a)
			if glow > 0.0 and source.albedo_texture != null:
				lit.emission_enabled = true
				lit.emission_texture = source.albedo_texture
				lit.emission = Color.WHITE
				lit.emission_energy_multiplier = glow
			if outline.a > 0.0:
				lit.next_pass = _outline_material(outline, outline_width)
			_lit_materials[key] = lit
		mesh.set_surface_override_material(surface, _lit_materials[key])


static func _outline_material(color: Color, width: float) -> ShaderMaterial:
	var key: Array = [color, width]
	if not _outline_materials.has(key):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = OUTLINE_SHADER
		material.set_shader_parameter("outline_color", color)
		material.set_shader_parameter("width", width)
		_outline_materials[key] = material
	return _outline_materials[key]


## Every MeshInstance3D at or below `node`.
static func meshes_of(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	_collect(node, found)
	return found


static func _collect(node: Node, found: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		found.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect(child, found)
