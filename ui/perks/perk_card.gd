class_name PerkCard
extends PanelContainer
## One card in the level-up hand. Pure view.

signal hovered
signal clicked

@export var common_border: Color = Color(0.75, 0.75, 0.8)
@export var rare_border: Color = Color(1.0, 0.78, 0.2)
@export var selected_border: Color = Color(0.3, 0.8, 1.0)
@export var background: Color = Color(0.1, 0.1, 0.13, 0.97)
@export var rare_background: Color = Color(0.2, 0.15, 0.05, 0.97)

@onready var _category: Label = %Category
@onready var _name: Label = %Name
@onready var _rarity: Label = %Rarity
@onready var _effects: Label = %Effects
@onready var _flavour: Label = %Flavour

var is_rare: bool = false
var selected: bool = false:
	set(value):
		selected = value
		_restyle()


func _ready() -> void:
	mouse_entered.connect(func() -> void: hovered.emit())
	gui_input.connect(_on_gui_input)
	_restyle()


func show_perk(category: String, title: String, rare: bool, effect_lines: PackedStringArray, flavour: String) -> void:
	is_rare = rare
	_category.text = category
	_name.text = title.to_upper()
	_rarity.text = "RARE" if rare else "COMMON"
	_rarity.modulate = rare_border if rare else common_border
	_effects.text = "\n".join(effect_lines)
	_flavour.text = flavour
	_restyle()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		clicked.emit()


func _restyle() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = rare_background if is_rare else background
	box.border_color = selected_border if selected else (rare_border if is_rare else common_border)
	box.set_border_width_all(6 if selected else 3)
	box.set_corner_radius_all(10)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	add_theme_stylebox_override("panel", box)
	scale = Vector2.ONE * (1.05 if selected else 1.0)
	pivot_offset = size / 2.0
