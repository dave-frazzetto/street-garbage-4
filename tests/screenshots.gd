extends Node
## Windowed visual check: saves screenshots of the title, gameplay, a perk hand and the end screen to
## res://tests/output/ (gitignored). Run without --headless.

var flow: GameFlow


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	flow = (load("res://core/game_flow.tscn") as PackedScene).instantiate() as GameFlow
	flow.seed_value = 7
	add_child(flow)
	_run()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://tests/output/%s.png" % file)
	print("saved ", file)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	await _wait(0.5)
	await _shot("1_title")
	flow.start_run()
	await _wait(0.6)
	await _shot("2_start_banner")
	# Top-down overview of the whole map.
	var rig: IsoCamera = flow.level.camera_rig
	var follow_target: Node3D = rig.target
	var game_pitch: float = rig.pitch_degrees
	rig.target = null
	rig.perspective = false
	rig.pitch_degrees = 89.0
	rig.yaw_degrees = 0.0
	rig.view_size = 128.0
	rig.distance = 120.0
	rig.global_position = Vector3(60, 0, 60)
	await _wait(0.2)
	await _shot("0_map_overview")
	rig.perspective = true
	rig.pitch_degrees = game_pitch
	rig.yaw_degrees = 45.0
	rig.distance = 44.0
	rig.target = follow_target
	# Walk toward the horde at the basketball court and shoot to show combat.
	flow.level.player.health.max_health = 100000.0
	flow.level.player.health.current = 100000.0
	flow.level.player.global_position = Vector3(49.0, 0, 57.0)
	flow.level.camera_rig.snap()
	flow.level.player.stats.add_modifier(PlayerStats.Stat.EXPLOSION, PlayerStats.Mode.FLAT, 0.5)
	await _wait(0.1)
	var target_screen: Vector2 = flow.level.camera_rig.camera.unproject_position(Vector3(60, 1, 60))
	# Aim with the gamepad right stick (the windowed OS cursor cannot be held in place reliably).
	var player_screen: Vector2 = flow.level.camera_rig.camera.unproject_position(flow.level.player.global_position + Vector3(0, 1, 0))
	var stick: Vector2 = (target_screen - player_screen).normalized()
	_axis(JOY_AXIS_RIGHT_X, stick.x)
	_axis(JOY_AXIS_RIGHT_Y, stick.y)
	await _wait(2.5)
	await _shot("3_combat")
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_axis(JOY_AXIS_RIGHT_Y, 0.0)
	# Force a rare-containing hand.
	flow.run.add_xp(flow.run.xp_needed())
	await _wait(0.4)
	await _shot("4_perk_hand")
	flow.perk_select.skipped.emit()
	flow.run.finish(RunState.Outcome.EXTRACTED)
	await _wait(0.3)
	await _shot("5_end")
	print("DONE screenshots")
	get_tree().quit(0)


func _axis(axis: JoyAxis, value: float) -> void:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
