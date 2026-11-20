extends TestCase
## Integration smoke test of a run: start, zombies, kills/XP, perk hand (choose, redraw, skip), gears,
## extraction, restart, death and nuke. Runs headless in a few seconds.

const FLOW_SCENE: String = "res://core/game_flow.tscn"

var flow: GameFlow


func _ready() -> void:
	flow = (load(FLOW_SCENE) as PackedScene).instantiate() as GameFlow
	flow.seed_value = 4242
	add_child(flow)
	run_all()


func _press(action_key: Key) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = action_key
	ev.keycode = action_key
	ev.pressed = true
	Input.parse_input_event(ev)
	var up: InputEventKey = ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)


func test_1_title_then_start() -> void:
	check(flow.title_screen.visible, "title visible at boot")
	_press(KEY_ENTER)
	await wait_frames(3)
	check(not flow.title_screen.visible, "title hidden after Enter")
	check(flow.level != null and flow.level.player != null, "level and player spawned")
	check_eq(flow.level.gear_positions().size(), 6, "6 gears placed")
	check(get_tree().get_nodes_in_group(Zombie.GROUP).size() >= 50, "hordes spawned")


func test_2_time_and_director() -> void:
	var t0: float = flow.run.time_left
	var horde: int = get_tree().get_nodes_in_group(Zombie.GROUP).size()
	await wait_seconds(2.0)
	check(flow.run.time_left < t0 - 1.5, "countdown runs")
	check(flow.level.director.alive_count() > 0, "director spawned ambient zombies (total %d -> %d)" % [horde, get_tree().get_nodes_in_group(Zombie.GROUP).size()])


func test_3_kill_gives_xp() -> void:
	var z: Zombie = get_tree().get_nodes_in_group(Zombie.GROUP)[0] as Zombie
	var kills: int = flow.run.kills
	z.take_damage(99999.0)
	await wait_frames(2)
	check_eq(flow.run.kills, kills + 1, "kill counted")
	check(flow.run.xp > 0 or flow.run.level > 1, "xp gained")


func test_4_level_up_choose_perk() -> void:
	# Keep the player safe from the horde during UI tests.
	flow.level.player.health.max_health = 100000.0
	flow.level.player.health.current = 100000.0
	flow.run.add_xp(flow.run.xp_needed())
	await wait_frames(2)
	check(flow.perk_select.is_open(), "perk hand open")
	check(get_tree().paused, "game paused during perk choice")
	check_eq(flow.perk_select.card_count(), 3, "3 cards")
	var t: float = flow.run.time_left
	await wait_seconds(0.3)
	check_eq(flow.run.time_left, t, "timer frozen while choosing")
	var chosen: Perk = flow._hand[0]
	var stacks: int = flow.run.perk_stacks(chosen)
	_press(KEY_ENTER)
	await wait_frames(2)
	check(not flow.perk_select.is_open(), "hand closed after confirm")
	check(not get_tree().paused, "unpaused")
	check_eq(flow.run.perk_stacks(chosen), stacks + 1, "chosen perk applied: %s" % chosen.display_name)


func test_5_redraw_and_skip() -> void:
	flow.run.add_xp(flow.run.xp_needed())
	await wait_frames(2)
	await wait_seconds(0.3)
	_press(KEY_R)
	await wait_frames(2)
	check_eq(flow.run.redraws_left, 2, "redraw used")
	check(flow.perk_select.is_open(), "still choosing after redraw")
	await wait_seconds(0.3)
	_press(KEY_ESCAPE)
	await wait_frames(2)
	check(not flow.perk_select.is_open(), "skip closes")
	check_eq(flow.run.pending_level_ups, 0, "no pending level-ups")


func test_6_multiple_level_ups_queue() -> void:
	var needed: int = flow.run.xp_needed() + flow.run.config.xp_needed(flow.run.level + 1)
	flow.run.add_xp(needed)
	await wait_frames(2)
	check_eq(flow.run.pending_level_ups, 2, "two pending")
	await wait_seconds(0.3)
	_press(KEY_ESCAPE)
	await wait_frames(2)
	check(flow.perk_select.is_open(), "second hand shown")
	await wait_seconds(0.3)
	_press(KEY_ESCAPE)
	await wait_frames(2)
	check(not flow.perk_select.is_open(), "all hands done")


func test_7_extraction_needs_gears() -> void:
	var p: Player = flow.level.player
	p.global_position = flow.level.extraction.global_position
	await wait_frames(4)
	check_eq(flow.run.outcome, RunState.Outcome.NONE, "cannot extract without gears")
	check(flow.hud.message_text().contains("MORE GEAR"), "hud says gears missing: '%s'" % flow.hud.message_text())
	p.global_position = flow.level.player_start_position()
	await wait_frames(4)


func test_8_collect_gears_and_extract() -> void:
	var p: Player = flow.level.player
	for pos: Vector3 in flow.level.gear_positions():
		p.global_position = pos
		await wait_frames(3)
	check_eq(flow.run.gears, 6, "all gears collected")
	check(flow.level.extraction.unlocked, "high-rise unlocked")
	p.global_position = flow.level.extraction.global_position
	await wait_frames(4)
	check_eq(flow.run.outcome, RunState.Outcome.EXTRACTED, "extracted")
	check(flow.end_screen.visible, "end screen shown")


func test_9_restart_then_die() -> void:
	flow.start_run()
	await wait_frames(3)
	check_eq(flow.run.gears, 0, "fresh run")
	check(not flow.end_screen.visible, "end screen hidden")
	flow.level.player.take_damage(100000.0)
	await wait_frames(2)
	check_eq(flow.run.outcome, RunState.Outcome.KILLED, "killed")


func test_10_nuke() -> void:
	flow.start_run()
	await wait_frames(2)
	flow.run.time_left = 0.1
	await wait_seconds(0.3)
	check_eq(flow.run.outcome, RunState.Outcome.NUKED, "nuked when timer ends")
