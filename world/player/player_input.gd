class_name PlayerInput
extends Node
## Merges mouse+keyboard, twin-stick gamepad and touch sticks into world-space move / aim / fire intents.
## Directions are screen-relative through the IsoCamera ("up" moves up the screen). The last used device decides
## where aim comes from. See ADR unified-player-input-component.

signal sprint_toggled
signal device_changed(device: Device)

enum Device { MOUSE_KEYBOARD, GAMEPAD, TOUCH }

## Node whose position is the aim origin for the mouse (normally the player).
@export var aim_origin: Node3D
## Aim stick push needed to fire on gamepad/touch (like the original: push the right stick to shoot).
@export_range(0, 1, 0.05) var fire_threshold: float = 0.45
@export_range(0, 1, 0.05) var stick_deadzone: float = 0.2
## Height of the gun above the ground, used for mouse aim.
@export_range(0, 3, 0.05) var aim_height: float = 1.0

var device: Device = Device.MOUSE_KEYBOARD
## Camera used to map screen to world. Injected by the player; null falls back to a 45° yaw.
var view: IsoCamera
## Set by on-screen touch sticks (screen-space vectors of length 0..1). Zero when unused.
var touch_move: Vector2 = Vector2.ZERO
var touch_aim: Vector2 = Vector2.ZERO
var _last_aim: Vector3 = Vector3.FORWARD


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		# Mouse events emulated from touch must not steal the aim source from the touch sticks.
		if event.device != InputEvent.DEVICE_ID_EMULATION:
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
func set_touch(move: Vector2, aim: Vector2) -> void:
	touch_move = move
	touch_aim = aim
	if move.length() > 0.05 or aim.length() > 0.05:
		_set_device(Device.TOUCH)


## Screen-space vector (x right, y down) to a world ground-plane vector.
func screen_to_world(v: Vector2) -> Vector3:
	if view != null and is_instance_valid(view):
		return view.screen_to_world(v)
	return Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, deg_to_rad(-45.0))


## World-space move vector on the ground plane, length 0..1.
func get_move_vector() -> Vector3:
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_move.length() > stick_deadzone:
		v = touch_move
	return screen_to_world(v.limit_length(1.0))


## World-space unit aim direction on the ground plane.
func get_aim_direction() -> Vector3:
	match device:
		Device.MOUSE_KEYBOARD:
			if aim_origin != null and view != null and is_instance_valid(view):
				var mouse: Vector2 = aim_origin.get_viewport().get_mouse_position()
				var to_mouse: Vector3 = view.ground_point(mouse, aim_height) - aim_origin.global_position
				to_mouse.y = 0.0
				if to_mouse.length() > 0.1:
					_last_aim = to_mouse.normalized()
		Device.GAMEPAD:
			var stick: Vector2 = _aim_stick()
			if stick.length() > stick_deadzone:
				_last_aim = screen_to_world(stick).normalized()
			else:
				var mv: Vector3 = get_move_vector()
				if mv.length() > stick_deadzone and not is_firing():
					_last_aim = mv.normalized()
		Device.TOUCH:
			if touch_aim.length() > stick_deadzone:
				_last_aim = screen_to_world(touch_aim).normalized()
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


func _set_device(value: Device) -> void:
	if device != value:
		device = value
		device_changed.emit(device)
