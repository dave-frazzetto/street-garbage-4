@tool
class_name FitModel
extends Node3D
## Places a generated (Meshy) model into a scene at real-world size: scaled to a height or to a box in metres, standing on
## the ground at this node's origin, turned to face the right way. Designer-tunable in the Inspector, no transform maths.
## Also gives the model a tint (variants, wrecks) and a fade (buildings that hide the player).

## The generated model (a .glb).
@export var model_scene: PackedScene:
	set(value):
		model_scene = value
		_rebuild()
## Height in metres. The model is scaled uniformly to this. Ignored when target_size has a positive component.
@export_range(0.05, 60.0, 0.05) var target_height: float = 1.0:
	set(value):
		target_height = value
		_rebuild()
## Optional box in metres (x width, y height, z depth). When any component is above 0 the model is stretched to fit this
## box (a 0 component keeps the proportion of the others). Used for buildings, whose footprint is set per instance.
@export var target_size: Vector3 = Vector3.ZERO:
	set(value):
		target_size = value
		_rebuild()
## Turns the model around the vertical axis so its front faces the scene's front (-Z). Generated models face +Z, so 180
## makes them face -Z; use 90 or -90 when a prop's long side must run the other way.
@export_range(-180.0, 180.0, 1.0) var yaw_degrees: float = 0.0:
	set(value):
		yaw_degrees = value
		_rebuild()
## Stand the model on its base instead of the centre of its bounding box: the origin goes to the centroid of the model's
## lowest 5%. For poles and lamps, whose base is not under the middle of the whole model.
@export var anchor_on_base: bool = false:
	set(value):
		anchor_on_base = value
		_rebuild()
## Brightness multiplier and self-lit share of the texture, so props stay readable in the dark city (1 and 0 = as generated).
@export_range(0.5, 4.0, 0.05) var brightness: float = 1.3:
	set(value):
		brightness = value
		_rebuild()
@export_range(0.0, 2.0, 0.05) var glow: float = 0.12:
	set(value):
		glow = value
		_rebuild()

# Measurements per model scene, so dozens of identical props measure once: path -> {"box": AABB, "base": Vector3}.
static var _measured: Dictionary = {}

var _instance: Node3D
var _meshes: Array[MeshInstance3D] = []
var _tint_material: StandardMaterial3D
var _alpha_materials: Dictionary = {}


func _ready() -> void:
	_rebuild()


## Re-fits to a new box (a building whose size changed).
func fit_to(size: Vector3) -> void:
	target_size = size


## Mixes a colour over the texture. The alpha is the strength (0 removes the tint).
func set_tint(tint: Color) -> void:
	if _tint_material == null:
		_tint_material = StandardMaterial3D.new()
		_tint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tint_material.albedo_color = tint
	for mesh: MeshInstance3D in _meshes:
		mesh.material_overlay = _tint_material if tint.a > 0.0 else null


## Fades the whole model (1 = opaque). Works with any renderer because it swaps materials instead of using the
## GeometryInstance3D transparency property.
func set_alpha(alpha: float) -> void:
	for mesh: MeshInstance3D in _meshes:
		if alpha >= 0.999:
			ModelLook.lift(mesh, brightness, glow)
			continue
		for surface: int in mesh.mesh.get_surface_count():
			var base: StandardMaterial3D = mesh.get_surface_override_material(surface) as StandardMaterial3D
			if base == null:
				continue
			var key: Array = [base, snappedf(alpha, 0.01)]
			if not _alpha_materials.has(key):
				var faded: StandardMaterial3D = base.duplicate() as StandardMaterial3D
				faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				faded.albedo_color = Color(base.albedo_color.r, base.albedo_color.g, base.albedo_color.b, alpha)
				faded.cull_mode = BaseMaterial3D.CULL_DISABLED
				_alpha_materials[key] = faded
			mesh.set_surface_override_material(surface, _alpha_materials[key])


## Bounding box of a model scene in its own space (position and size), from its meshes. Handy for sizing held items.
static func measure(scene: PackedScene) -> AABB:
	return _measurements(scene)["box"]


static func _measurements(scene: PackedScene) -> Dictionary:
	var key: String = scene.resource_path
	if key != "" and _measured.has(key):
		return _measured[key]
	var instance: Node = scene.instantiate()
	var box: AABB = _bounds(instance, Transform3D.IDENTITY)
	var sums: Dictionary = {"sum": Vector3.ZERO, "count": 0}
	_base_sums(instance, Transform3D.IDENTITY, box.position.y + box.size.y * 0.05, sums)
	var base: Vector3 = box.get_center()
	if sums["count"] > 0:
		base = sums["sum"] / float(sums["count"])
	instance.free()
	var result: Dictionary = {"box": box, "base": base}
	if key != "":
		_measured[key] = result
	return result


# Adds up the x/z of every vertex below `limit` height (in the model's own space).
static func _base_sums(node: Node, parent_to_root: Transform3D, limit: float, sums: Dictionary) -> void:
	var here: Transform3D = parent_to_root
	if node is Node3D:
		here = parent_to_root * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in vertices:
				var at: Vector3 = here * v
				if at.y <= limit:
					sums["sum"] += Vector3(at.x, 0.0, at.z)
					sums["count"] += 1
	for child: Node in node.get_children():
		_base_sums(child, here, limit, sums)


static func _bounds(node: Node, parent_to_root: Transform3D) -> AABB:
	var here: Transform3D = parent_to_root
	if node is Node3D:
		here = parent_to_root * (node as Node3D).transform
	var box: AABB = AABB()
	var has_box: bool = false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		box = here * (node as MeshInstance3D).get_aabb()
		has_box = true
	for child: Node in node.get_children():
		var child_box: AABB = _bounds(child, here)
		if child_box.size == Vector3.ZERO and child_box.position == Vector3.ZERO:
			continue
		box = child_box if not has_box else box.merge(child_box)
		has_box = true
	return box


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _instance != null:
		remove_child(_instance)
		_instance.queue_free()
		_instance = null
	_meshes.clear()
	if model_scene == null:
		return
	var measurements: Dictionary = _measurements(model_scene)
	var box: AABB = measurements["box"]
	if box.size.y <= 0.0001:
		return
	_instance = model_scene.instantiate() as Node3D
	var fit: Vector3
	if target_size.x > 0.0 or target_size.y > 0.0 or target_size.z > 0.0:
		var uniform: float = target_size.y / box.size.y if target_size.y > 0.0 else 1.0
		fit = Vector3(
			target_size.x / box.size.x if target_size.x > 0.0 else uniform,
			uniform,
			target_size.z / box.size.z if target_size.z > 0.0 else uniform)
	else:
		fit = Vector3.ONE * (target_height / box.size.y)
	var anchor: Vector3 = measurements["base"] if anchor_on_base else box.get_center()
	var bottom_centre: Vector3 = Vector3(anchor.x, box.position.y, anchor.z)
	var turn: Basis = Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	_instance.basis = turn * Basis.from_scale(fit)
	_instance.position = -(turn * (bottom_centre * fit))
	add_child(_instance)
	_meshes = ModelLook.meshes_of(_instance)
	for mesh: MeshInstance3D in _meshes:
		ModelLook.lift(mesh, brightness, glow)
