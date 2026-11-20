class_name VirtualStick
extends Control
## A floating touch stick. A touch that starts inside this control's rect places the stick under the finger;
## dragging sets `vector` (length 0..1). Each stick tracks its own finger, so two sticks work at once.

signal touched
signal released

@export_range(20, 300) var radius: float = 90.0
@export var base_color: Color = Color(1, 1, 1, 0.18)
@export var knob_color: Color = Color(1, 1, 1, 0.45)
## Where the stick rests (as a fraction of this control's size) when not touched.
@export var rest_anchor: Vector2 = Vector2(0.3, 0.7)

var vector: Vector2 = Vector2.ZERO
var _finger: int = -1
var _center: Vector2
var _knob: Vector2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset()


func is_active() -> bool:
	return _finger != -1


## Fed raw touch events by TouchControls (screen coordinates).
func handle_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event as InputEventScreenTouch
		if t.pressed and _finger == -1 and get_global_rect().has_point(t.position):
			_finger = t.index
			_center = t.position - global_position
			_knob = _center
			vector = Vector2.ZERO
			touched.emit()
			queue_redraw()
			return true
		if not t.pressed and t.index == _finger:
			_reset()
			released.emit()
			return true
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event as InputEventScreenDrag
		if d.index == _finger:
			var offset: Vector2 = (d.position - global_position) - _center
			offset = offset.limit_length(radius)
			_knob = _center + offset
			vector = offset / radius
			queue_redraw()
			return true
	return false


func _reset() -> void:
	_finger = -1
	vector = Vector2.ZERO
	_center = size * rest_anchor
	_knob = _center
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _finger == -1:
		_reset()


func _draw() -> void:
	var alpha: float = 1.0 if is_active() else 0.5
	draw_circle(_center, radius, Color(base_color, base_color.a * alpha))
	draw_arc(_center, radius, 0, TAU, 48, Color(knob_color, knob_color.a * alpha), 3.0)
	draw_circle(_knob, radius * 0.42, Color(knob_color, knob_color.a * alpha))
