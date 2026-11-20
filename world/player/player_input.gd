class_name PlayerInput
extends Node
## Merges mouse+keyboard, twin-stick gamepad and touch sticks into move / aim / fire intents.
## The last used device decides where aim comes from. See ADR unified-player-input-component.

signal sprint_toggled
signal device_changed(device: Device)

enum Device { MOUSE_KEYBOARD, GAMEPAD, TOUCH }

## Node whose position is the aim origin for the mouse (normally the player).
@export var aim_origin: Node2D
## Aim stick push needed to fire on gamepad/touch (like the original: push the right stick to shoot).
@export_range(0, 1, 0.05) var fire_threshold: float = 0.45
@export_range(0, 1, 0.05) var stick_deadzone: float = 0.2

var device: Device = Device.MOUSE_KEYBOARD
## Set by on-screen touch sticks (vectors of length 0..1). Zero when unused.
var touch_move: Vector2 = Vector2.ZERO
var touch_aim: Vector2 = Vector2.ZERO
## Mouse events this soon after touch-stick use are ignored for device switching: browsers and Godot synthesise
## mouse events from touches (following the first finger only), which would otherwise steal the aim.
@export_range(0, 5, 0.1) var touch_mouse_grace: float = 1.0
var _last_aim: Vector2 = Vector2.RIGHT
var _last_touch_ms: int = -100000


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		# Mouse events emulated from touch must not steal the aim source from the touch sticks.
		if event.device != InputEvent.DEVICE_ID_EMULATION and not _touch_recent():
			_set_device(Device.MOUSE_KEYBOARD)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.4:
			_set_device(Device.GAMEPAD)
	elif event is InputEventJoypadButton:
		_set_device(Device.GAMEPAD)
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_device(Device.TOUCH)
	if event.is_action_pressed("sprint_toggle"):
		sprint_toggled.emit()


## Called by touch controls' sprint button.
func request_sprint_toggle() -> void:
	sprint_toggled.emit()


## Fed every frame with the on-screen stick vectors (length 0..1). Using a stick switches to touch aim.
func set_touch(move: Vector2, aim: Vector2, touching: bool = false) -> void:
	touch_move = move
	touch_aim = aim
	if touching or move.length() > 0.05 or aim.length() > 0.05:
		_last_touch_ms = Time.get_ticks_msec()
		_set_device(Device.TOUCH)


func get_move_vector() -> Vector2:
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_move.length() > stick_deadzone:
		v = touch_move
	return v.limit_length(1.0)


func get_aim_direction() -> Vector2:
	match device:
		Device.MOUSE_KEYBOARD:
			if aim_origin != null:
				var to_mouse: Vector2 = aim_origin.get_global_mouse_position() - aim_origin.global_position
				if to_mouse.length() > 4.0:
					_last_aim = to_mouse.normalized()
		Device.GAMEPAD:
			var stick: Vector2 = _aim_stick()
			if stick.length() > stick_deadzone:
				_last_aim = stick.normalized()
			else:
				var mv: Vector2 = get_move_vector()
				if mv.length() > stick_deadzone and not is_firing():
					_last_aim = mv.normalized()
		Device.TOUCH:
			if touch_aim.length() > stick_deadzone:
				_last_aim = touch_aim.normalized()
	return _last_aim


func is_firing() -> bool:
	match device:
		Device.GAMEPAD:
			return Input.is_action_pressed("shoot") or _aim_stick().length() > fire_threshold
		Device.TOUCH:
			return touch_aim.length() > fire_threshold
		_:
			return Input.is_action_pressed("shoot")


func _aim_stick() -> Vector2:
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")


func _touch_recent() -> bool:
	return Time.get_ticks_msec() - _last_touch_ms < int(touch_mouse_grace * 1000.0)


func _set_device(value: Device) -> void:
	if device != value:
		device = value
		device_changed.emit(device)
