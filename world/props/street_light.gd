@tool
class_name StreetLight
extends Node3D
## A light source prop: street lamp, neon sign or fire. The look comes from the scene; colour, energy, flicker and the
## sign text are tunable here.

@export var light_color: Color = Color(1.0, 0.62, 0.28):
	set(value):
		light_color = value
		_refresh()
@export_range(0, 16, 0.1) var energy: float = 2.5:
	set(value):
		energy = value
		_refresh()
@export_range(1, 40, 0.5) var light_range: float = 10.0:
	set(value):
		light_range = value
		_refresh()
## 0 = steady, 1 = strong flicker (fires, broken neon).
@export_range(0, 1, 0.05) var flicker: float = 0.0
## Text for neon signs (only used if the scene has a Sign Label3D).
@export var sign_text: String = "":
	set(value):
		sign_text = value
		_refresh()

var _time: float = 0.0
var _light: Light3D


func _ready() -> void:
	_time = randf() * 10.0
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	_light = get_node_or_null("Light") as Light3D
	if _light != null:
		_light.light_color = light_color
		_light.light_energy = energy
		if _light is OmniLight3D:
			(_light as OmniLight3D).omni_range = light_range
		elif _light is SpotLight3D:
			(_light as SpotLight3D).spot_range = light_range
	var bulb: GeometryInstance3D = get_node_or_null("Bulb") as GeometryInstance3D
	if bulb != null:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = light_color
		bulb.material_override = mat
	var sign_label: Label3D = get_node_or_null("Sign") as Label3D
	if sign_label != null:
		sign_label.text = sign_text
		sign_label.modulate = light_color
		sign_label.outline_modulate = Color(light_color, 0.35)


func _process(delta: float) -> void:
	if flicker <= 0.0 or _light == null or Engine.is_editor_hint():
		return
	_time += delta
	var n: float = sin(_time * 13.0) * 0.5 + sin(_time * 29.0 + 1.3) * 0.3 + sin(_time * 7.0) * 0.2
	_light.light_energy = energy * (1.0 - flicker * 0.5 + flicker * 0.5 * n)
