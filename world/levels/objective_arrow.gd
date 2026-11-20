class_name ObjectiveArrow
extends Node3D
## Arrow on the ground around the player pointing to the current objective when it is far away.

@export var color: Color = Color(0.3, 0.7, 1.0):
	set(value):
		color = value
		if _material != null:
			_material.albedo_color = value
			_material.emission = value
@export_range(0.5, 5) var orbit_radius: float = 1.4
## Hide when the objective is closer than this (metres).
@export_range(0, 50) var hide_distance: float = 9.0

@onready var _mesh: MeshInstance3D = $Mesh

var follow: Node3D
var objective: Vector3
var has_objective: bool = false
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = color
	_material.emission_enabled = true
	_material.emission = color
	_mesh.material_override = _material


func _process(_delta: float) -> void:
	if follow == null or not is_instance_valid(follow):
		visible = false
		return
	var to: Vector3 = objective - follow.global_position
	to.y = 0.0
	visible = has_objective and to.length() >= hide_distance
	if not visible:
		return
	var d: Vector3 = to.normalized()
	global_position = follow.global_position + d * orbit_radius + Vector3(0, 0.08, 0)
	rotation.y = atan2(-d.x, -d.z)
