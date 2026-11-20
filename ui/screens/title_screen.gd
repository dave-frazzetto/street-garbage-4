class_name TitleScreen
extends CanvasLayer
## Title screen. Emits start_requested on Enter / Space / A / Start / click / tap.

signal start_requested


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	(%StartButton as Button).pressed.connect(func() -> void: start_requested.emit())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("start_game"):
		get_viewport().set_input_as_handled()
		start_requested.emit()
