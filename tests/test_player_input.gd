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


func _joy_button(button: JoyButton, pressed: bool) -> void:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)


func test_2_sprint_while_shift_is_held() -> void:
	_key(KEY_SHIFT, true)
	await wait_frames(2)
	check(player.sprinting, "holding shift sprints")
	var st0: float = player.stamina.current
	var p0: Vector3 = player.global_position
	_key(KEY_D, true)
	await wait_frames(20)
	_key(KEY_D, false)
	var sprint_dist: float = (player.global_position - p0).length()
	check(player.sprinting, "still sprinting while shift stays held")
	check(player.stamina.current < st0, "sprinting drains stamina")
	check(sprint_dist > player.stats.get_value(PlayerStats.Stat.MOVE_SPEED) * 20.0 / 60.0 * 1.3, "sprint is faster (%.2f m)" % sprint_dist)
	_key(KEY_SHIFT, false)
	await wait_frames(2)
	check(not player.sprinting, "releasing shift stops the sprint")
	# A second press is not a toggle: pressing and releasing in the same frame never leaves it on.
	_key(KEY_SHIFT, true)
	_key(KEY_SHIFT, false)
	await wait_frames(2)
	check(not player.sprinting, "a tap does not latch the sprint on")


func test_2b_empty_stamina_ends_the_sprint_until_released() -> void:
	_key(KEY_SHIFT, true)
	_key(KEY_D, true)
	await wait_frames(2)
	player.stamina.current = 0.5
	await wait_frames(3)
	check(not player.sprinting, "an empty bar ends the sprint even while shift is held")
	player.stamina.current = player.stamina.max_stamina
	await wait_frames(3)
	check(not player.sprinting, "holding on does not restart it once the bar refills")
	_key(KEY_SHIFT, false)
	await wait_frames(1)
	_key(KEY_SHIFT, true)
	await wait_frames(2)
	check(player.sprinting, "release and hold again sprints")
	_key(KEY_SHIFT, false)
	await wait_frames(3)
	check(not player.sprinting, "released again")
	# Re-holding on an almost empty bar must not flick the sprint on for a few frames and off again.
	var changes: Array[int] = [0]
	var count_change: Callable = func(_on: bool) -> void: changes[0] += 1
	player.sprint_changed.connect(count_change)
	var minimum: float = player.stamina.max_stamina * player.stats.min_sprint_stamina
	check(player.stats.min_sprint_stamina > 0.05, "a sprint needs a real share of the bar (%.2f)" % player.stats.min_sprint_stamina)
	player.stamina.current = minimum * 0.5
	_key(KEY_SHIFT, true)
	await wait_frames(6)
	check(not player.sprinting and changes[0] == 0, "held on a nearly empty bar: no sprint and no flicker (%d changes)" % changes[0])
	player.stamina.current = minimum + 2.0
	await wait_frames(2)
	check(player.sprinting and changes[0] == 1, "starts once the bar holds the minimum")
	player.sprint_changed.disconnect(count_change)
	_key(KEY_SHIFT, false)
	_key(KEY_D, false)
	await wait_frames(2)


func test_2c_gamepad_shoulder_holds_sprint() -> void:
	_joy_button(JOY_BUTTON_LEFT_SHOULDER, true)
	await wait_frames(2)
	check(player.sprinting, "holding LB sprints")
	_joy_button(JOY_BUTTON_LEFT_SHOULDER, false)
	await wait_frames(2)
	check(not player.sprinting, "releasing LB stops")
	_joy_button(JOY_BUTTON_LEFT_STICK, true)
	await wait_frames(2)
	check(player.sprinting, "holding L3 sprints")
	_joy_button(JOY_BUTTON_LEFT_STICK, false)
	await wait_frames(2)
	check(not player.sprinting, "releasing L3 stops")


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


func _held_weapon_length() -> float:
	var holder: Node = player.find_child("WeaponHolder", true, false)
	var longest: float = 0.0
	if holder == null:
		return 0.0
	for node: Node in holder.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		longest = maxf(longest, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	return longest


func test_7_player_follows_the_character_scale() -> void:
	var size: float = GameTuning.fallback().character_scale
	check(size > 1.0, "characters are drawn larger than the generated models (%.2f)" % size)
	check(player.visual.scale.is_equal_approx(Vector3.ONE * size), "standalone player uses the default character scale")
	var shape: CylinderShape3D = (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
	check(is_equal_approx(player.body_radius, player.base_body_radius * size), "contact radius follows the scale (%.3f)" % player.body_radius)
	check(is_equal_approx(shape.radius, player.body_radius) and is_equal_approx(shape.height, 1.8 * size), "collision body follows the scale")
	check(is_equal_approx(player.weapon.position.y, 1.0) and is_equal_approx(player.input.aim_height, 1.0), "bullets keep flying at 1 m, the props' scale (%.2f)" % player.weapon.position.y)
	var held_scaled: float = _held_weapon_length()
	player.set_body_scale(1.0)
	check(player.visual.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(shape.height, 1.8), "scale can be set back to 1")
	var held_unscaled: float = _held_weapon_length()
	check(absf(held_scaled / held_unscaled - size) < 0.02, "the gun in hand grows with the model (%.3f vs %.3f m)" % [held_scaled, held_unscaled])
	player.set_body_scale(size)
	player._model.hold_weapon(player.weapon.current_weapon())
	await wait_frames(1)
	check(absf(_held_weapon_length() - held_scaled) < 0.01, "a gun picked up after scaling has the same size (%.3f m)" % _held_weapon_length())
	var other: Player = (load("res://world/player/player.tscn") as PackedScene).instantiate() as Player
	var other_shape: CylinderShape3D = (other.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
	check(is_equal_approx(other_shape.height, 1.8), "the scene's shared collision shape is not modified")
	other.free()
