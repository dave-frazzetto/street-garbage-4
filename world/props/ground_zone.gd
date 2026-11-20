@tool
class_name GroundZone
extends Node3D
## A flat painted area on the ground (basketball court, quarantine zone, garage floor) with an optional label.

const SHADER: Shader = preload("res://world/props/ground_zone.gdshader")

@export var size: Vector2 = Vector2(16, 9.5):
	set(value):
		size = value
		_refresh()
@export var fill_color: Color = Color(0.5, 0.28, 0.16, 0.8):
	set(value):
		fill_color = value
		_refresh()
@export var line_color: Color = Color(1, 1, 1, 0.6):
	set(value):
		line_color = value
		_refresh()
@export var striped: bool = false:
	set(value):
		striped = value
		_refresh()
@export var court_markings: bool = true:
	set(value):
		court_markings = value
		_refresh()
@export var label: String = "":
	set(value):
		label = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var mesh_node: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node != null:
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = size
		mesh_node.mesh = plane
		mesh_node.position = Vector3(0, 0.01, 0)
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("fill_color", fill_color)
		mat.set_shader_parameter("line_color", line_color)
		mat.set_shader_parameter("size", size)
		mat.set_shader_parameter("striped", striped)
		mat.set_shader_parameter("court_markings", court_markings)
		mesh_node.material_override = mat
	var text: Label3D = get_node_or_null("Label") as Label3D
	if text != null:
		text.text = label
		text.visible = label != ""
		text.position = Vector3(0, 0.05, -size.y / 2.0 - 0.6)
