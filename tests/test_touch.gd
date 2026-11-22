extends TestCase
## Slice 2: drives the on-screen twin sticks with simulated multi-touch (T1-T5, T8) inside the real game flow.

var flow: GameFlow


func _ready() -> void:
	flow = (load("res://core/game_flow.tscn") as PackedScene).instantiate() as GameFlow
	flow.seed_value = 99
	(flow.get_node("TouchControls") as TouchControls).force_visible = true
	add_child(flow)
	run_all()


## Converts a viewport position into window coordinates (events are scaled by the stretch transform).
func _win(pos: Vector2) -> Vector2:
	return flow.get_viewport().get_final_transform() * pos


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev: InputEventScreenTouch = InputEventScreenTouch.new()
	ev.index = index
	ev.position = _win(pos)
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(index: int, pos: Vector2) -> void:
	var ev: InputEventScreenDrag = InputEventScreenDrag.new()
	ev.index = index
	ev.position = _win(pos)
	Input.parse_input_event(ev)


func test_1_hidden_until_gameplay() -> void:
	check(not flow.touch_controls.visible, "touch controls hidden on title")
	flow.start_run()
	await wait_frames(3)
	check(flow.touch_controls.visible, "touch controls shown in gameplay")
	flow.level.player.health.max_health = 100000.0
	flow.level.player.health.current = 100000.0


func test_2_left_stick_moves() -> void:
	var p: Player = flow.level.player
	var p0: Vector3 = p.global_position
	_touch(0, Vector2(300, 500), true)
	_drag(0, Vector2(420, 500))
	await wait_frames(30)
	check(flow.touch_controls.move_vector.x > 0.9, "move stick vector right (%s)" % str(flow.touch_controls.move_vector))
	# Half a second at walking speed, less the drag start-up.
	var walk: float = p.stats.get_value(PlayerStats.Stat.MOVE_SPEED)
	var moved: float = (p.global_position - p0).dot(p.input.screen_to_world(Vector2.RIGHT))
	check(moved > walk * 0.25, "player moved screen-right by touch (%.2f m)" % moved)
	check(not p.sprinting, "touch play walks")
	check_eq(p.input.device, PlayerInput.Device.TOUCH, "touch device (emulated mouse ignored)")


func test_3_both_sticks_at_once() -> void:
	var p: Player = flow.level.player
	var shots: Array[int] = [0]
	p.weapon.fired.connect(func(_w: WeaponData) -> void: shots[0] += 1)
	_touch(1, Vector2(950, 450), true)
	_drag(1, Vector2(950, 560))
	await wait_frames(30)
	check(flow.touch_controls.move_vector.length() > 0.9, "move stick still held")
	check(flow.touch_controls.aim_vector.y > 0.9, "aim stick down")
	check(p.input.is_firing(), "aim stick past threshold fires")
	check(p.input.get_aim_direction().dot(p.input.screen_to_world(Vector2.DOWN)) > 0.9, "aims down")
	check(shots[0] > 0, "shots fired by touch (%d)" % shots[0])
	check_eq(p.input.device, PlayerInput.Device.TOUCH, "still touch device")


func test_3b_browser_mouse_events_do_not_steal_aim() -> void:
	# Phone browsers synthesise real mouse events that follow the FIRST finger (the left stick).
	var p: Player = flow.level.player
	var switches: Array[int] = [0]
	var count_mouse: Callable = func(d: PlayerInput.Device) -> void:
		if d == PlayerInput.Device.MOUSE_KEYBOARD:
			switches[0] += 1
	p.input.device_changed.connect(count_mouse)
	for i: int in 10:
		var mm: InputEventMouseMotion = InputEventMouseMotion.new()
		mm.device = 0
		mm.position = _win(Vector2(420, 500))
		Input.parse_input_event(mm)
		var mb: InputEventMouseButton = InputEventMouseButton.new()
		mb.device = 0
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = true
		mb.position = mm.position
		Input.parse_input_event(mb)
		await wait_frames(1)
	p.input.device_changed.disconnect(count_mouse)
	check_eq(switches[0], 0, "browser mouse events never switch aim to the mouse")
	check_eq(p.input.device, PlayerInput.Device.TOUCH, "touch aim kept")
	check(p.input.get_aim_direction().dot(p.input.screen_to_world(Vector2.DOWN)) > 0.9, "still aims where the right stick points")
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.device = 0
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	Input.parse_input_event(up)


func test_4_release_stops() -> void:
	_touch(0, Vector2(420, 500), false)
	_touch(1, Vector2(950, 560), false)
	await wait_frames(2)
	check_eq(flow.touch_controls.move_vector, Vector2.ZERO, "move released")
	check(not flow.level.player.input.is_firing(), "fire released")


func test_5_no_sprint_on_touch() -> void:
	check(flow.touch_controls.find_children("*", "Button", true, false).is_empty(), "no sprint button on screen")
	var p: Player = flow.level.player
	_touch(0, Vector2(300, 500), true)
	_drag(0, Vector2(420, 500))
	Input.action_press("sprint")
	await wait_frames(10)
	check_eq(p.input.device, PlayerInput.Device.TOUCH, "touch device")
	check(not p.sprinting, "touch play never sprints")
	Input.action_release("sprint")
	_touch(0, Vector2(420, 500), false)
	await wait_frames(2)


func test_6_hidden_during_perk_choice() -> void:
	flow.run.add_xp(flow.run.xp_needed())
	await wait_frames(3)
	check(flow.perk_select.is_open(), "perk hand open")
	check(not flow.touch_controls.visible, "touch controls hidden during perk choice")
	flow.perk_select.skipped.emit()
	await wait_frames(2)
	check(flow.touch_controls.visible, "touch controls back after choice")
