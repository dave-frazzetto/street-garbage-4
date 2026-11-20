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
	# Walk toward the horde at the basketball court and shoot to show combat.
	flow.level.player.health.max_health = 100000.0
	flow.level.player.health.current = 100000.0
	flow.level.player.global_position = Vector2(1700, 1800)
	flow.level.player.stats.add_modifier(PlayerStats.Stat.EXPLOSION, PlayerStats.Mode.FLAT, 0.5)
	get_viewport().warp_mouse(Vector2(900, 400))
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(900, 380)
	Input.parse_input_event(ev)
	await _wait(2.5)
	await _shot("3_combat")
	ev = ev.duplicate() as InputEventMouseButton
	ev.pressed = false
	Input.parse_input_event(ev)
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
