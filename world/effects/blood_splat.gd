class_name BloodSplat
extends Node3D
## A flat blood decal left where a zombie dies. Fades out slowly so the ground does not fill up forever.

@export_range(1, 600) var lifetime: float = 90.0
@export var color: Color = Color(0.45, 0.02, 0.02, 0.85)

@onready var _mesh: MeshInstance3D = $Splat

var _age: float = 0.0
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = color
	_material.roughness = 0.2
	_mesh.material_override = _material
	rotation.y = randf() * TAU
	scale = Vector3.ONE * randf_range(0.7, 1.4)


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime - 5.0:
		_material.albedo_color.a = color.a * clampf((lifetime - _age) / 5.0, 0.0, 1.0)
	if _age >= lifetime:
		queue_free()
