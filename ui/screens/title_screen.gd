class_name TitleScreen
extends CanvasLayer
## Title screen. Emits start_requested once on Enter / Space / A / Start / click, or on any tap on a touch screen,
## and shows "LOADING..." straight away so the player sees the tap registered while the city loads.

signal start_requested

@export var loading_text: String = "LOADING..."

@onready var _button: Button = %StartButton

var _requested: bool = false
var _idle_text: String


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_idle_text = _button.text
	_button.pressed.connect(_request)


func _input(event: InputEvent) -> void:
	# Any tap starts on touch screens, so a missed button press cannot leave the player stuck here.
	if visible and event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		get_viewport().set_input_as_handled()
		_request()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("start_game"):
		get_viewport().set_input_as_handled()
		_request()


func is_loading() -> bool:
	return _requested


## Back to the idle state (e.g. if the title is shown again).
func reset() -> void:
	_requested = false
	_button.text = _idle_text
	_button.disabled = false


func _request() -> void:
	if _requested:
		return
	_requested = true
	_button.text = loading_text
	_button.disabled = true
	start_requested.emit()
