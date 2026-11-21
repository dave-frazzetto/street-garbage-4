class_name ModelLook
extends RefCounted
## Shared "readable at night" look for generated models: a brightness multiplier and a self-lit share of the texture.
## The lifted materials are copies shared by everything that uses the same source material and settings, so the imported
## resources are never modified and there is one copy per setting, not one per instance.

static var _lit_materials: Dictionary = {}


## Applies the lifted copy of every material on `mesh` as a per-surface override.
static func lift(mesh: MeshInstance3D, brightness: float, glow: float) -> void:
	if mesh.mesh == null:
		return
	for surface: int in mesh.mesh.get_surface_count():
		var source: StandardMaterial3D = mesh.get_active_material(surface) as StandardMaterial3D
		if source == null:
			continue
		var key: Array = [source, brightness, glow]
		if not _lit_materials.has(key):
			var lit: StandardMaterial3D = source.duplicate() as StandardMaterial3D
			lit.albedo_color = Color(brightness, brightness, brightness, source.albedo_color.a)
			if glow > 0.0 and source.albedo_texture != null:
				lit.emission_enabled = true
				lit.emission_texture = source.albedo_texture
				lit.emission = Color.WHITE
				lit.emission_energy_multiplier = glow
			_lit_materials[key] = lit
		mesh.set_surface_override_material(surface, _lit_materials[key])


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
