extends Node3D
## Short-lived explosion flash: an expanding, fading sphere plus a brief light.

@export var radius: float = 1.75
@export_range(0.05, 2, 0.05) var lifetime: float = 0.3
@export var color: Color = Color(1.0, 0.55, 0.15)

@onready var _mesh: MeshInstance3D = $Sphere
@onready var _light: OmniLight3D = $Light

var _age: float = 0.0
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(color, 0.7)
	_mesh.material_override = _material
	_light.light_color = color
	_light.omni_range = radius * 3.0


func _process(delta: float) -> void:
	_age += delta
	var t: float = clampf(_age / lifetime, 0.0, 1.0)
	_mesh.scale = Vector3.ONE * radius * (0.4 + 0.6 * t)
	_material.albedo_color.a = 0.7 * (1.0 - t)
	_light.light_energy = 4.0 * (1.0 - t)
	if _age >= lifetime:
		queue_free()
