extends TestCase
## Sound effects: every cue is wired to real, audible clips; the SfxPlayer rate-limits and mutes; and the real game
## events (shots, kills, pickups, explosions, perks, end of run) trigger the right cues. Runs headless in a few seconds.

const FLOW_SCENE: String = "res://core/game_flow.tscn"
const BANK_PATH: String = "res://audio/sfx_bank_default.tres"
const WEAPON_DIR: String = "res://data/weapons/"

var flow: GameFlow
var played: Array[SfxCue] = []


func _ready() -> void:
	run_all()


func _bank_cues(bank: SfxBank) -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in bank.get_property_list():
		if prop["type"] == TYPE_OBJECT and prop["class_name"] == &"SfxCue":
			out[prop["name"]] = bank.get(prop["name"])
	return out


## Peak level 0..1 of the source file. Read raw: the imported copy is ADPCM-compressed, so its bytes are not PCM.
func _peak(stream: AudioStreamWAV) -> float:
	var raw: AudioStreamWAV = AudioStreamWAV.load_from_file(stream.resource_path)
	var peak: int = 0
	var data: PackedByteArray = raw.data
	for i: int in range(0, data.size() / 2):
		peak = maxi(peak, absi(data.decode_s16(i * 2)))
	return peak / 32768.0


func test_1_bank_cues_have_audible_clips() -> void:
	var bank: SfxBank = load(BANK_PATH) as SfxBank
	check(bank != null, "default bank loads")
	var cues: Dictionary = _bank_cues(bank)
	check(cues.size() >= 15, "bank exposes its cue slots (%d)" % cues.size())
	for slot: String in cues:
		var cue: SfxCue = cues[slot] as SfxCue
		check(cue != null, "bank slot '%s' is filled" % slot)
		if cue != null:
			_check_cue(slot, cue)


func test_2_every_weapon_has_a_fire_sound() -> void:
	var dir: DirAccess = DirAccess.open(WEAPON_DIR)
	var count: int = 0
	for file: String in dir.get_files():
		if file.ends_with(".tres"):
			var weapon: WeaponData = load(WEAPON_DIR + file) as WeaponData
			count += 1
			check(weapon != null and weapon.fire_sound != null, "%s has a fire_sound" % file)
			if weapon != null and weapon.fire_sound != null:
				_check_cue(file, weapon.fire_sound)
	check(count >= 4, "weapons found (%d)" % count)


func _check_cue(label: String, cue: SfxCue) -> void:
	check(not cue.streams.is_empty(), "%s: has clips" % label)
	for stream: AudioStream in cue.streams:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		check(wav != null, "%s: clip is a WAV" % label)
		if wav == null:
			continue
		check(wav.get_length() > 0.05 and wav.get_length() < 3.0, "%s: sensible length (%.2fs)" % [label, wav.get_length()])
		check(_peak(wav) > 0.2, "%s: audible (peak %.2f)" % [label, _peak(wav)])
		check(_peak(wav) < 1.0, "%s: not clipping" % label)


func test_2b_music_track_is_a_long_audible_loop() -> void:
	var player: MusicPlayer = (load("res://audio/music_player.tscn") as PackedScene).instantiate() as MusicPlayer
	var wav: AudioStreamWAV = player.stream as AudioStreamWAV
	check(wav != null, "music track is a WAV")
	if wav != null:
		check(wav.get_length() > 10.0 and wav.get_length() < 60.0, "music loop length (%.1fs)" % wav.get_length())
		var peak: float = _peak(wav)
		check(peak > 0.3 and peak < 1.0, "music audible and not clipping (peak %.2f)" % peak)
	player.free()


func test_3_player_limits_and_mutes() -> void:
	var player: SfxPlayer = (load("res://audio/sfx_player.tscn") as PackedScene).instantiate() as SfxPlayer
	add_child(player)
	var cue: SfxCue = player.bank.zombie_hit
	var started: Array[int] = [0]
	player.cue_played.connect(func(_c: SfxCue) -> void: started[0] += 1)
	check(not player.play_cue(null), "null cue is a no-op")
	check(player.play_cue(cue), "first play starts")
	check(not player.play_cue(cue), "second play inside min_interval is dropped")
	# The player counts process time, so wait on a process-frame timer (wait_seconds counts physics time).
	await get_tree().create_timer(cue.min_interval + 0.05, true, false).timeout
	check(player.play_cue(cue), "plays again after the interval")
	check_eq(started[0], 2, "cue_played fired for the two starts only")
	player.muted = true
	check(not player.play_cue(player.bank.level_up), "muted player stays silent")
	player.muted = false
	var empty: SfxCue = SfxCue.new()
	check(not player.play_cue(empty), "cue without clips is a no-op")
	player.queue_free()


func test_4_game_events_trigger_cues() -> void:
	flow = (load(FLOW_SCENE) as PackedScene).instantiate() as GameFlow
	flow.seed_value = 777
	add_child(flow)
	flow.sfx.cue_played.connect(func(c: SfxCue) -> void: played.append(c))
	flow.start_run()
	await wait_frames(3)
	check(flow.music.is_playing(), "music starts with the run")
	check(flow.ambient.is_playing(), "ambience starts with the run")
	var bank: SfxBank = flow.sfx.bank
	var level: Level = flow.level
	var p: Player = level.player
	p.health.max_health = 100000.0
	p.health.current = 100000.0

	played.clear()
	p.weapon.tick(0.5, true, Vector3.FORWARD)
	await wait_frames(1)
	check(played.has(p.weapon.current_weapon().fire_sound), "firing plays the weapon's fire_sound")

	played.clear()
	p.weapon.damage_dealt.emit(5.0)
	await wait_frames(1)
	check(played.has(bank.zombie_hit), "a bullet hit plays zombie_hit")

	played.clear()
	var z: Zombie = get_tree().get_nodes_in_group(Zombie.GROUP)[0] as Zombie
	z.take_damage(99999.0)
	await wait_frames(2)
	check(played.has(bank.zombie_die), "a kill plays zombie_die")

	played.clear()
	p.take_damage(5.0)
	await wait_frames(1)
	check(played.has(bank.player_hurt), "damage plays player_hurt")

	played.clear()
	p.global_position = level.gear_positions()[0]
	await wait_frames(4)
	check(played.has(bank.pickup_gear), "gear pickup plays pickup_gear")

	# Footsteps follow movement at a stride cadence; walking 6 m must give several steps, standing still none.
	played.clear()
	flow.footsteps.reset()
	await wait_frames(2)
	played.clear()
	# Count the stepper's own events: the footstep cue is rate limited by game time, which depends on frame speed.
	var step_events: Array[int] = [0]
	var on_step: Callable = func(_sprinting: bool) -> void: step_events[0] += 1
	flow.footsteps.step_taken.connect(on_step)
	for i: int in 12:
		p.global_position += Vector3(0.5, 0.0, 0.0)
		await wait_frames(1)
	flow.footsteps.step_taken.disconnect(on_step)
	check(step_events[0] > 0, "moving produces footstep events")
	var steps: int = step_events[0]
	check(steps >= 2 and steps <= 7, "footstep count follows distance (6 m, got %d)" % steps)
	played.clear()
	await wait_frames(6)
	check(not played.has(bank.footstep), "standing still plays no footsteps")

	# A zombie close to the player groans, quieter when farther away.
	# Hordes are dormant far from the player, so put a zombie next to the player instead of looking one up.
	var near: Zombie = (load("res://world/enemies/zombie.tscn") as PackedScene).instantiate() as Zombie
	near.position = p.global_position + Vector3(-4.0, 0.0, 0.0)
	level.entities.add_child(near)
	await wait_frames(1)
	flow.groaner._cooldown = 0.0
	played.clear()
	await wait_frames(3)
	check(played.has(bank.zombie_groan), "a nearby zombie groans")

	played.clear()
	var boom: Destructible = null
	var plain: Destructible = null
	for node: Node in level.find_children("Destructible", "", true, false):
		var d: Destructible = node as Destructible
		if d.explosion_radius > 0.0 and boom == null:
			boom = d
		elif d.explosion_radius <= 0.0 and plain == null:
			plain = d
	check(boom != null, "level has an explosive prop")
	if boom != null:
		boom.take_damage(99999.0)
		await wait_frames(3)
		check(played.has(bank.prop_explode), "explosive prop plays prop_explode")
	# Every prop in the current level explodes, so cover the non-explosive wiring through the level's signal.
	played.clear()
	if plain != null:
		plain.take_damage(99999.0)
	else:
		level.prop_destroyed.emit(Vector3.ZERO, false)
	await wait_frames(3)
	check(played.has(bank.prop_break), "non-explosive prop plays prop_break")

	played.clear()
	p.global_position = level.extraction.global_position
	await wait_frames(4)
	check(played.has(bank.extraction_denied), "extracting without gears plays extraction_denied")
	p.global_position = level.player_start_position()


func test_5_perk_and_end_of_run_cues() -> void:
	played.clear()
	var bank: SfxBank = flow.sfx.bank
	flow.run.add_xp(flow.run.xp_needed())
	await wait_frames(2)
	check(flow.perk_select.is_open(), "perk hand open")
	check(played.has(bank.level_up), "level-up plays level_up")
	await wait_seconds(0.3)
	flow._on_redraw()
	check(played.has(bank.perk_redraw), "redraw plays perk_redraw")
	flow._on_perk_chosen(0)
	await wait_frames(2)
	check(played.has(bank.perk_pick), "choosing plays perk_pick")
	played.clear()
	flow.run.add_xp(flow.run.xp_needed())
	await wait_frames(2)
	flow._on_skip()
	await wait_frames(2)
	check(played.has(bank.perk_skip), "skipping plays perk_skip")
	played.clear()
	flow.level.player.take_damage(1000000.0)
	await wait_frames(3)
	check_eq(flow.run.outcome, RunState.Outcome.KILLED, "run ended by death")
	check(played.has(bank.run_killed), "death plays run_killed")
	check(not flow.music.is_playing(), "music fades out when the run ends")
	check(not flow.ambient.is_playing(), "ambience fades out when the run ends")
	await get_tree().create_timer(flow.music.fade_out + 0.3, true, false).timeout
	check(not flow.music._player.playing, "music has stopped after the fade")
	flow.start_run()
	await wait_frames(2)
	check(flow.music.is_playing(), "music restarts with the next run")
	played.clear()
	flow.run.time_left = 0.1
	await wait_seconds(0.3)
	check(played.has(bank.run_nuked), "nuke plays run_nuked")
	flow.start_run()
	await wait_frames(2)
	played.clear()
	for pos: Vector3 in flow.level.gear_positions():
		flow.level.player.global_position = pos
		await wait_frames(3)
	flow.level.player.global_position = flow.level.extraction.global_position
	await wait_frames(4)
	check_eq(flow.run.outcome, RunState.Outcome.EXTRACTED, "extracted")
	check(played.has(bank.run_extracted), "extraction plays run_extracted")


func test_6_footstep_cadence_is_node_free() -> void:
	var stepper: FootstepStepper = FootstepStepper.new()
	var count: Array[int] = [0]
	var last_sprint: Array[bool] = [false]
	stepper.step_taken.connect(func(sprinting: bool) -> void:
		count[0] += 1
		last_sprint[0] = sprinting
	)
	check_eq(stepper.advance(stepper.walk_stride * 0.5, false), 0, "half a stride is no step")
	check_eq(stepper.advance(stepper.walk_stride * 0.6, false), 1, "completing the stride steps once")
	check_eq(stepper.advance(stepper.walk_stride * 3.0, false), 3, "three strides give three steps")
	check_eq(count[0], 4, "signal fired per step")
	count[0] = 0
	var walk_steps: int = stepper.advance(10.0, false)
	stepper.reset()
	var sprint_steps: int = stepper.advance(10.0, true)
	check(sprint_steps < walk_steps, "sprint stride is longer: fewer steps for the same distance (%d < %d)" % [sprint_steps, walk_steps])
	check(last_sprint[0], "step_taken reports sprinting")
	stepper.reset()
	check_eq(stepper.track(Vector3.ZERO, 0.016, false), 0, "first sample only anchors")
	check_eq(stepper.track(Vector3(100.0, 0.0, 0.0), 0.016, false), 0, "a teleport gives no steps")
	check_eq(stepper.track(Vector3(100.0, 0.0, 0.0), 0.016, false), 0, "no movement, no steps")
	check_eq(stepper.track(Vector3(100.0 + stepper.walk_stride + 0.01, 0.0, 0.0), 0.2, false), 1, "walking one stride steps once")
	stepper.free()


func test_7_groan_falloff_and_limits() -> void:
	var g: ZombieGroaner = ZombieGroaner.new()
	check_eq(g.volume_offset_for(0.0), 0.0, "no attenuation at zero distance")
	check_eq(g.volume_offset_for(g.hearing_range), -g.range_attenuation_db, "full attenuation at the edge of hearing")
	check(g.volume_offset_for(g.hearing_range * 0.5) > g.volume_offset_for(g.hearing_range), "farther is quieter")
	check_eq(g.nearest_distance(Vector3.ZERO, [] as Array[Node]), -1.0, "no zombies, nobody to groan")
	g.free()


func test_8_ambient_player_loops_and_stops() -> void:
	var amb: AmbientPlayer = (load("res://audio/ambient_player.tscn") as PackedScene).instantiate() as AmbientPlayer
	amb.fade_in = 0.1
	amb.fade_out = 0.1
	add_child(amb)
	var bed: AudioStreamWAV = amb.bed as AudioStreamWAV
	check(bed != null, "ambient bed is a WAV")
	if bed != null:
		check(bed.get_length() > 10.0 and bed.get_length() < 60.0, "ambient bed length (%.1fs)" % bed.get_length())
		var peak: float = _peak(bed)
		check(peak > 0.2 and peak < 1.0, "ambient bed audible, not clipping (peak %.2f)" % peak)
	check(amb.one_shots.size() >= 3, "ambient has random one-shots (%d)" % amb.one_shots.size())
	for stream: AudioStream in amb.one_shots:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		check(wav != null and _peak(wav) > 0.2, "one-shot is audible")
	amb.play_ambient()
	await wait_frames(2)
	check(amb.is_playing(), "ambient plays")
	check(amb._bed_player.stream is AudioStreamWAV and (amb._bed_player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "bed loops")
	var shots: Array[int] = [0]
	amb.one_shot_played.connect(func(_s: AudioStream) -> void: shots[0] += 1)
	check(amb.play_one_shot(), "a one-shot can be triggered")
	check_eq(shots[0], 1, "one_shot_played fired")
	amb.stop_ambient()
	await get_tree().create_timer(0.4, true, false).timeout
	check(not amb.is_playing() and not amb._bed_player.playing, "ambient stops after fade-out")
	amb.queue_free()
