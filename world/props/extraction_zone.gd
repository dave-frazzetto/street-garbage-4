@tool
class_name ExtractionZone
extends Area3D
## The High-Rise entrance in the quarantine zone. Reports when the player steps in; the run rules decide the rest.

signal player_entered

@export var size: Vector3 = Vector3(6, 3, 4):
	set(value):
		size = value
		_refresh()
@export var locked_color: Color = Color(0.85, 0.85, 0.85):
	set(value):
		locked_color = value
		_refresh()
@export var unlocked_color: Color = Color(0.2, 1.0, 0.5):
	set(value):
		unlocked_color = value
		_refresh()
@export var label: String = "HIGH-RISE":
	set(value):
		label = value
		_refresh()

var unlocked: bool = false:
	set(value):
		unlocked = value
		_refresh()
var _time: float = 0.0
var _material: StandardMaterial3D


func _ready() -> void:
	_refresh()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if _material != null:
		_material.albedo_color.a = 0.15 + 0.12 * (0.5 + 0.5 * sin(_time * 3.0))


func _refresh() -> void:
	if not is_inside_tree():
		return
	var col: Color = unlocked_color if unlocked else locked_color
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null:
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size
		shape_node.shape = box
		shape_node.position = Vector3(0, size.y / 2.0, 0)
	var mesh_node: MeshInstance3D = get_node_or_null("Glow") as MeshInstance3D
	if mesh_node != null:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		mesh_node.mesh = mesh
		mesh_node.position = Vector3(0, size.y / 2.0, 0)
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.albedo_color = Color(col, 0.2)
		mesh_node.material_override = _material
	var light: OmniLight3D = get_node_or_null("Light") as OmniLight3D
	if light != null:
		light.light_color = col
		light.light_energy = 3.0 if unlocked else 0.8
	var text: Label3D = get_node_or_null("Label") as Label3D
	if text != null:
		text.text = label if unlocked else label + " (LOCKED)"
		text.modulate = col
		text.position = Vector3(0, size.y + 0.8, 0)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player_entered.emit()
