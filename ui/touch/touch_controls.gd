class_name TouchControls
extends CanvasLayer
## On-screen twin sticks for touch screens. Pure input view: PlayerInput reads move_vector / aim_vector. There is no
## sprint on touch (phones walk only, see ADR hold-to-sprint-walk-only-on-touch). Hidden on devices without touch until
## the first touch.

signal first_touch

@onready var move_stick: VirtualStick = %MoveStick
@onready var aim_stick: VirtualStick = %AimStick
@onready var rotate_overlay: Control = %RotateOverlay

## Force visible (tests, or a settings toggle later).
@export var force_visible: bool = false

var touch_seen: bool = false
var move_vector: Vector2:
	get:
		return move_stick.vector
var aim_vector: Vector2:
	get:
		return aim_stick.vector


func _ready() -> void:
	touch_seen = force_visible or DisplayServer.is_touchscreen_available()
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if not touch_seen:
		touch_seen = true
		first_touch.emit()
		_update_layout()
	if not visible:
		return
	if move_stick.handle_touch(event) or aim_stick.handle_touch(event):
		get_viewport().set_input_as_handled()


## True while a finger is on either stick.
func is_touching() -> bool:
	return move_stick.is_active() or aim_stick.is_active()


## Shown during gameplay only (game flow calls this when menus open/close).
func set_gameplay_active(active: bool) -> void:
	visible = active and touch_seen
	if not visible:
		move_stick._reset()
		aim_stick._reset()


func _update_layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	rotate_overlay.visible = touch_seen and s.y > s.x
