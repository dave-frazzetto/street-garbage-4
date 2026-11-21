extends TestCase
## Drives the player with simulated keyboard+mouse and gamepad events (R2a). Also checks weapon mods fire.

var player: Player
var projectiles: Node3D


func _ready() -> void:
	projectiles = Node3D.new()
	add_child(projectiles)
	player = (load("res://world/player/player.tscn") as PackedScene).instantiate() as Player
	player.position = Vector3(20, 0, 20)
	add_child(player)
	player.fired.connect(func(_w: WeaponData) -> void: shots_fired += 1)
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


## Shots fired so far (bullets are instant now and free themselves after their line fades).
var shots_fired: int = 0


func _bullets() -> int:
	return projectiles.get_child_count()


func test_1_keyboard_moves() -> void:
	var p0: Vector3 = player.global_position
	_key(KEY_D, true)
	await wait_frames(20)
	_key(KEY_D, false)
	var right: float = (player.global_position - p0).dot(player.input.screen_to_world(Vector2.RIGHT))
	check(right > 1.0, "D moves screen-right (%.2f m)" % right)
	p0 = player.global_position
	_key(KEY_W, true)
	await wait_frames(20)
	_key(KEY_W, false)
	var up: float = (player.global_position - p0).dot(player.input.screen_to_world(Vector2.UP))
	check(up > 1.0, "W moves screen-up (%.2f m)" % up)
	check(player.input.view != null, "standalone player brought its own camera")


func test_2_sprint_toggle_faster_and_drains() -> void:
	_key(KEY_SHIFT, true)
	_key(KEY_SHIFT, false)
	await wait_frames(1)
	check(player.sprinting, "shift toggles sprint on")
	var st0: float = player.stamina.current
	var p0: Vector3 = player.global_position
	_key(KEY_D, true)
	await wait_frames(20)
	_key(KEY_D, false)
	var sprint_dist: float = (player.global_position - p0).length()
	check(player.stamina.current < st0, "sprinting drains stamina")
	check(sprint_dist > 5.25 * 20.0 / 60.0 * 1.3, "sprint is faster (%.2f m)" % sprint_dist)
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
	check(shots_fired > 0, "shots fired (%d)" % shots_fired)
	ev = ev.duplicate() as InputEventMouseButton
	ev.pressed = false
	Input.parse_input_event(ev)
	await wait_frames(2)
	check(not player.input.is_firing(), "release stops firing")


func test_4_gamepad_moves_and_shoots() -> void:
	for c: Node in projectiles.get_children():
		c.queue_free()
	await wait_frames(2)
	var p0: Vector3 = player.global_position
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await wait_frames(20)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	check_eq(player.input.device, PlayerInput.Device.GAMEPAD, "gamepad device")
	check((player.global_position - p0).dot(player.input.screen_to_world(Vector2.RIGHT)) > 1.0, "left stick moves screen-right")
	_axis(JOY_AXIS_RIGHT_Y, 1.0)
	await wait_frames(30)
	check(player.input.is_firing(), "right stick push fires")
	check(player.input.get_aim_direction().dot(player.input.screen_to_world(Vector2.DOWN)) > 0.9, "right stick aims screen-down")
	check(shots_fired > 1, "gamepad shots fired")
	_axis(JOY_AXIS_RIGHT_Y, 0.0)
	await wait_frames(2)
	check(not player.input.is_firing(), "stick release stops")


func test_5_twin_barrel_and_temp_weapon() -> void:
	for c: Node in projectiles.get_children():
		c.queue_free()
	await wait_frames(2)
	player.stats.add_modifier(PlayerStats.Stat.EXTRA_PROJECTILES, PlayerStats.Mode.FLAT, 1.0)
	player.weapon._cooldown = 0.0
	player.weapon._fire(Vector3.FORWARD)
	check_eq(_bullets(), 2, "twin barrel fires 2 bullets")
	player.equip_temporary_weapon(load("res://data/weapons/auto_shotgun.tres") as WeaponData, 0.3)
	check_eq(player.weapon.current_weapon().display_name, "Auto Shotgun", "temp weapon equipped")
	await wait_seconds(0.5)
	check_eq(player.weapon.current_weapon().display_name, "Pistol", "temp weapon expires")


func test_6_bullets_hit_zombies_point_blank_and_at_range() -> void:
	var dir: Vector3 = player.input.screen_to_world(Vector2.RIGHT).normalized()
	var zombie_scene: PackedScene = load("res://world/enemies/zombie.tscn") as PackedScene
	var near: Zombie = zombie_scene.instantiate() as Zombie
	near.setup(load("res://data/enemies/walker.tres") as EnemyData, null, 0.0)
	near.position = player.global_position + dir * 0.5
	add_child(near)
	var far: Zombie = zombie_scene.instantiate() as Zombie
	far.setup(load("res://data/enemies/armoured.tres") as EnemyData, null, 0.0)
	far.position = player.global_position + dir.rotated(Vector3.UP, 0.6) * 5.0
	add_child(far)
	await wait_frames(3)
	var near_hp: float = near.health
	player.weapon._cooldown = 0.0
	player.weapon._fire(dir)
	await wait_frames(10)
	check(not is_instance_valid(near) or near.health < near_hp, "point-blank zombie hit (%s)" % (str(near.health) if is_instance_valid(near) else "dead"))
	# Tougher walkers survive the first shot and would sit in the line of fire (their hurtbox is wide), so clear it.
	if is_instance_valid(near):
		near.free()
	var far_hp: float = far.health
	var far_dir: Vector3 = (far.global_position - player.weapon.global_position)
	far_dir.y = 0.0
	player.weapon._cooldown = 0.0
	player.weapon._fire(far_dir.normalized())
	await wait_frames(30)
	check(far.health < far_hp, "zombie at 5 m hit (%.1f -> %.1f)" % [far_hp, far.health])
