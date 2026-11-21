@tool
class_name Building
extends StaticBody3D
## A solid block (building, wall, wreck). Size and colours are set in the Inspector; collision and mesh follow.
## Turns translucent while it hides the player from the camera (the level calls update_occlusion each frame).

@export var size: Vector3 = Vector3(5, 4, 4):
	set(value):
		size = value
		_refresh()
@export var color: Color = Color(0.28, 0.27, 0.3):
	set(value):
		color = value
		_refresh()
@export var roof_color: Color = Color(0.2, 0.19, 0.22):
	set(value):
		roof_color = value
		_refresh()
## Optional label shown on the roof.
@export var label: String = "":
	set(value):
		label = value
		_refresh()
## Show generated facade models instead of the plain box (the box stays as collision). Walls and fences leave this off.
@export var generated_facades: bool = false:
	set(value):
		generated_facades = value
		_refresh()
## Facade models by building height: below low_height, from tall_height up, and in between. A long building repeats the
## model along its length so a 10 m strip is not one stretched facade.
@export var low_facade: PackedScene
@export var mid_facade: PackedScene
@export var tall_facade: PackedScene
@export_range(1, 20, 0.5) var low_height: float = 5.5
@export_range(1, 30, 0.5) var tall_height: float = 8.0
## Alpha used while the building hides the player.
@export_range(0, 1, 0.05) var faded_alpha: float = 0.22
## Buildings lower than this never fade (walls, cars).
@export_range(0, 10, 0.1) var min_fade_height: float = 1.6

var _body_mat: StandardMaterial3D
var _roof_mat: StandardMaterial3D
var _faded: bool = false
var _tiles: Array[FitModel] = []


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null:
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size
		shape_node.shape = box
		shape_node.position = Vector3(0, size.y / 2.0, 0)
	var body: MeshInstance3D = get_node_or_null("Body") as MeshInstance3D
	if body != null:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		body.mesh = mesh
		body.position = Vector3(0, size.y / 2.0, 0)
		_body_mat = StandardMaterial3D.new()
		_body_mat.albedo_color = color
		_body_mat.roughness = 0.9
		body.material_override = _body_mat
	var roof: MeshInstance3D = get_node_or_null("Roof") as MeshInstance3D
	if roof != null:
		var rmesh: BoxMesh = BoxMesh.new()
		rmesh.size = Vector3(maxf(0.1, size.x - 0.4), 0.12, maxf(0.1, size.z - 0.4))
		roof.mesh = rmesh
		roof.position = Vector3(0, size.y + 0.06, 0)
		_roof_mat = StandardMaterial3D.new()
		_roof_mat.albedo_color = roof_color
		roof.material_override = _roof_mat
	var text: Label3D = get_node_or_null("Label") as Label3D
	if text != null:
		text.text = label
		text.visible = label != ""
		text.position = Vector3(0, size.y + 0.2, 0)
	_build_facades()
	_faded = false


func _build_facades() -> void:
	var old: Node = get_node_or_null("Facades")
	if old != null:
		remove_child(old)
		old.queue_free()
	_tiles.clear()
	var scene: PackedScene = mid_facade
	if size.y < low_height and low_facade != null:
		scene = low_facade
	elif size.y >= tall_height and tall_facade != null:
		scene = tall_facade
	var use: bool = generated_facades and scene != null
	for part: String in ["Body", "Roof"]:
		var node: Node3D = get_node_or_null(part) as Node3D
		if node != null:
			node.visible = not use
	if not use:
		return
	var holder: Node3D = Node3D.new()
	holder.name = "Facades"
	add_child(holder)
	var along_x: bool = size.x >= size.z
	var long_len: float = size.x if along_x else size.z
	var short_len: float = size.z if along_x else size.x
	var count: int = maxi(1, roundi(long_len / maxf(short_len * 1.15, 0.1)))
	var step: float = long_len / float(count)
	for i: int in count:
		var tile: FitModel = FitModel.new()
		tile.model_scene = scene
		tile.target_size = Vector3(step, size.y, short_len) if along_x else Vector3(short_len, size.y, step)
		var offset: float = -long_len / 2.0 + step * (float(i) + 0.5)
		tile.position = Vector3(offset, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, offset)
		holder.add_child(tile)
		_tiles.append(tile)


## Call down from the level: fade if this building stands between the camera and `focus`.
## `toward_camera` is the horizontal unit vector from the scene toward the camera; `tan_pitch` the camera tilt.
func update_occlusion(focus: Vector3, toward_camera: Vector3, tan_pitch: float) -> void:
	if size.y < min_fade_height or _body_mat == null:
		return
	var reach: float = size.y / maxf(tan_pitch, 0.05) + 0.6
	var hidden: bool = false
	for i: int in 7:
		var p: Vector3 = to_local(focus + toward_camera * (reach * float(i) / 6.0))
		if absf(p.x) <= size.x / 2.0 + 0.3 and absf(p.z) <= size.z / 2.0 + 0.3:
			hidden = true
			break
	if hidden != _faded:
		_set_faded(hidden)


func is_faded() -> bool:
	return _faded


func _set_faded(on: bool) -> void:
	_faded = on
	for mat: StandardMaterial3D in [_body_mat, _roof_mat]:
		if mat == null:
			continue
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if on else BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color.a = faded_alpha if on else 1.0
	for tile: FitModel in _tiles:
		tile.set_alpha(faded_alpha if on else 1.0)
	var body: GeometryInstance3D = get_node_or_null("Body") as GeometryInstance3D
	if body != null:
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _get_configuration_warnings() -> PackedStringArray:
	if get_node_or_null("CollisionShape3D") == null or get_node_or_null("Body") == null:
		return PackedStringArray(["Building needs CollisionShape3D and Body (MeshInstance3D) children."])
	return PackedStringArray()
