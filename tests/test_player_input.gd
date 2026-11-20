extends TestCase
## Drives the player with simulated keyboard+mouse and gamepad events (R2a). Also checks weapon mods fire.

var player: Player
var projectiles: Node2D


func _ready() -> void:
	projectiles = Node2D.new()
	add_child(projectiles)
	player = (load("res://world/player/player.tscn") as PackedScene).instantiate() as Player
	player.position = Vector2(500, 500)
	add_child(player)
	player.setup(PlayerStats.new(), projectiles)
	run_all()


func _key(code: Key, pressed: bool) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _axis(axis: JoyAxis, value: float) -> void:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _bullets() -> int:
	return projectiles.get_child_count()


func test_1_keyboard_moves() -> void:
	var x0: float = player.global_position.x
	_key(KEY_D, true)
	await wait_frames(20)
	_key(KEY_D, false)
	check(player.global_position.x > x0 + 30.0, "D moves right (%.1f -> %.1f)" % [x0, player.global_position.x])
	var y0: float = player.global_position.y
	_key(KEY_W, true)
	await wait_frames(20)
	_key(KEY_W, false)
	check(player.global_position.y < y0 - 30.0, "W moves up")


func test_2_sprint_toggle_faster_and_drains() -> void:
	_key(KEY_SHIFT, true)
	_key(KEY_SHIFT, false)
	await wait_frames(1)
	check(player.sprinting, "shift toggles sprint on")
	var st0: float = player.stamina.current
	var x0: float = player.global_position.x
	_key(KEY_D, true)
	await wait_frames(20)
	_key(KEY_D, false)
	var sprint_dist: float = player.global_position.x - x0
	check(player.stamina.current < st0, "sprinting drains stamina")
	check(sprint_dist > 210.0 * 20.0 / 60.0 * 1.3, "sprint is faster (%.1f px)" % sprint_dist)
	_key(KEY_SHIFT, true)
	_key(KEY_SHIFT, false)
	await wait_frames(1)
	check(not player.sprinting, "shift toggles sprint off")


func test_3_mouse_shoots() -> void:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(900, 360)
	Input.parse_input_event(ev)
	await wait_frames(2)
	check_eq(player.input.device, PlayerInput.Device.MOUSE_KEYBOARD, "mouse device")
	check(player.input.is_firing(), "LMB fires")
	await wait_frames(30)
	check(_bullets() > 0, "bullets spawned (%d)" % _bullets())
	ev = ev.duplicate() as InputEventMouseButton
	ev.pressed = false
	Input.parse_input_event(ev)
	await wait_frames(2)
	check(not player.input.is_firing(), "release stops firing")


func test_4_gamepad_moves_and_shoots() -> void:
	for c: Node in projectiles.get_children():
		c.queue_free()
	await wait_frames(2)
	var x0: float = player.global_position.x
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await wait_frames(20)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	check_eq(player.input.device, PlayerInput.Device.GAMEPAD, "gamepad device")
	check(player.global_position.x > x0 + 30.0, "left stick moves")
	_axis(JOY_AXIS_RIGHT_Y, 1.0)
	await wait_frames(30)
	check(player.input.is_firing(), "right stick push fires")
	check(player.input.get_aim_direction().dot(Vector2.DOWN) > 0.9, "right stick aims down")
	check(_bullets() > 0, "gamepad bullets spawned")
	_axis(JOY_AXIS_RIGHT_Y, 0.0)
	await wait_frames(2)
	check(not player.input.is_firing(), "stick release stops")


func test_5_twin_barrel_and_temp_weapon() -> void:
	for c: Node in projectiles.get_children():
		c.queue_free()
	await wait_frames(2)
	player.stats.add_modifier(PlayerStats.Stat.EXTRA_PROJECTILES, PlayerStats.Mode.FLAT, 1.0)
	player.weapon._cooldown = 0.0
	player.weapon._fire(Vector2.RIGHT)
	check_eq(_bullets(), 2, "twin barrel fires 2 bullets")
	player.equip_temporary_weapon(load("res://data/weapons/auto_shotgun.tres") as WeaponData, 0.3)
	check_eq(player.weapon.current_weapon().display_name, "Auto Shotgun", "temp weapon equipped")
	await wait_seconds(0.5)
	check_eq(player.weapon.current_weapon().display_name, "Pistol", "temp weapon expires")
