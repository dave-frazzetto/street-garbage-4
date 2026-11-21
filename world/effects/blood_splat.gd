class_name BloodSplat
extends Node3D
## Where a zombie dies: a burst of blood droplets (child Burst) and a flat irregular decal on the ground that fades out
## slowly so the ground does not fill up forever.

@export_range(1, 600) var lifetime: float = 90.0
## Seconds over which the decal fades at the end of its life.
@export_range(0.5, 30, 0.5) var fade_time: float = 5.0
@export var color: Color = Color(0.45, 0.02, 0.02, 0.9)
## Random decal scale range (uniform).
@export var scale_range: Vector2 = Vector2(0.7, 1.5)
## How many different splat shapes are generated and shared.
@export_range(1, 8) var shape_variants: int = 4

@onready var _mesh: MeshInstance3D = $Splat

var _age: float = 0.0
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = color
	_material.albedo_texture = SplatTexture.get_variant(randi(), shape_variants)
	_material.roughness = 0.25
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = _material
	_mesh.rotation.y = randf() * TAU
	_mesh.scale = Vector3.ONE * randf_range(scale_range.x, scale_range.y)


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime - fade_time:
		_material.albedo_color.a = color.a * clampf((lifetime - _age) / fade_time, 0.0, 1.0)
	if _age >= lifetime:
		queue_free()
