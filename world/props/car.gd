@tool
class_name Car
extends StaticBody3D
## An abandoned car: solid obstacle with optional headlights and tail lights. With a Destructible child it burns when
## badly damaged and turns into a charred wreck when it explodes.

@export var paint: Color = Color(0.55, 0.15, 0.12):
	set(value):
		paint = value
		_refresh()
## How strongly the paint colour is mixed over the model's own PBR paint (0 keeps the generated texture untouched).
@export_range(0.0, 1.0, 0.05) var paint_strength: float = 0.15:
	set(value):
		paint_strength = value
		_refresh()
## Headlights on (spotlights forward) and glowing tail lights.
@export var lights_on: bool = false:
	set(value):
		lights_on = value
		_refresh()
@export var wreck_color: Color = Color(0.07, 0.06, 0.06)
## Health fraction below which the car starts burning as a warning.
@export_range(0, 1, 0.05) var burn_threshold: float = 0.4

## True once the car has exploded.
var wrecked: bool = false
var _material: StandardMaterial3D


func _ready() -> void:
	_refresh()
	if Engine.is_editor_hint():
		return
	var d: Destructible = Destructible.of(self)
	if d != null:
		d.damaged.connect(_on_damaged)
		d.destroyed.connect(_on_destroyed)


func _refresh() -> void:
	if not is_inside_tree():
		return
	_material = StandardMaterial3D.new()
	_material.albedo_color = paint
	_material.metallic = 0.4
	_material.roughness = 0.4
	for part: String in ["Body", "Cabin"]:
		var mesh: MeshInstance3D = get_node_or_null(part) as MeshInstance3D
		if mesh != null:
			mesh.material_override = _material
	var model: FitModel = get_node_or_null("Model") as FitModel
	if model != null:
		model.set_tint(Color(paint, paint_strength) if not wrecked else Color(wreck_color, 0.85))
	var lights: Node3D = get_node_or_null("Lights") as Node3D
	if lights != null:
		lights.visible = lights_on


func _on_damaged(health: float, max_health: float) -> void:
	var fire: Node3D = get_node_or_null("Burning") as Node3D
	if fire != null and health / max_health < burn_threshold:
		fire.visible = true


func _on_destroyed(_at: Vector3, _radius: float, _damage: float) -> void:
	wrecked = true
	var model: FitModel = get_node_or_null("Model") as FitModel
	if model != null:
		model.set_tint(Color(wreck_color, 0.85))
	_material.albedo_color = wreck_color
	_material.metallic = 0.0
	_material.roughness = 1.0
	var lights: Node3D = get_node_or_null("Lights") as Node3D
	if lights != null:
		lights.visible = false
	var glass: Node3D = get_node_or_null("Glass") as Node3D
	if glass != null:
		glass.visible = false
	var fire: Node3D = get_node_or_null("Burning") as Node3D
	if fire != null:
		fire.visible = true
		fire.scale = Vector3.ONE * 1.6
