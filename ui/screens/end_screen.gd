class_name EndScreen
extends CanvasLayer
## Result screen. Emits restart_requested.

signal restart_requested

var _lock: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	(%RestartButton as Button).pressed.connect(func() -> void: restart_requested.emit())


func show_result(title: String, subtitle: String, lines: PackedStringArray, won: bool) -> void:
	(%Title as Label).text = title
	(%Title as Label).modulate = Color(0.4, 1.0, 0.5) if won else Color(1.0, 0.35, 0.3)
	(%Subtitle as Label).text = subtitle
	(%Stats as Label).text = "\n".join(lines)
	visible = true
	_lock = 0.8


func _process(delta: float) -> void:
	_lock = maxf(0.0, _lock - delta)


func _unhandled_input(event: InputEvent) -> void:
	if visible and _lock <= 0.0 and event.is_action_pressed("start_game"):
		get_viewport().set_input_as_handled()
		restart_requested.emit()
