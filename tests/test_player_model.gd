extends TestCase
## Player animation layers: standing and firing aims, shots with gaps do not flicker, speed jitter near zero does not
## toggle running, the upper-body overlay leaves the legs alone, and death takes the tree over.

var model: PlayerModel
var skeleton: Skeleton3D


func _ready() -> void:
	model = (load("res://world/player/player_model.tscn") as PackedScene).instantiate() as PlayerModel
	add_child(model)
	run_all()


func _tree() -> AnimationTree:
	return model._tree


func _loco() -> float:
	return float(_tree().get("parameters/loco/blend_amount"))


func _aim() -> float:
	return float(_tree().get("parameters/aim/blend_amount"))


## Feeds the model like Player does, one call per physics frame.
func _drive(frames: int, speed: float, firing: bool) -> void:
	for i: int in frames:
		model.update_motion(speed, firing)
		await get_tree().physics_frame


func test_1_tree_is_built() -> void:
	await wait_frames(2)
	check(_tree() != null, "animation tree exists")
	check(_tree().active, "animation tree is active")
	skeleton = model.find_first("Skeleton3D") as Skeleton3D
	check(skeleton != null, "skeleton found")


func test_2_standing_and_firing_aims() -> void:
	await _drive(30, 0.0, true)
	check(model.is_aiming(), "aiming while firing")
	check(not model.is_running(), "not running while standing")
	check_eq(_aim(), 1.0, "upper body fully in the shoot pose")
	check_eq(_loco(), 0.0, "legs idle")


func test_3_moving_without_firing_runs_and_releases_aim() -> void:
	await _drive(40, 5.0, false)
	check(model.is_running(), "running")
	check_eq(_loco(), 1.0, "legs fully running")
	check_eq(_aim(), 0.0, "aim released after the hold time")


func test_4_shots_with_gaps_do_not_flicker() -> void:
	# Fire for one frame every 20 frames (about 3 shots per second): the aim layer must stay up the whole time.
	await _drive(20, 0.0, true)
	var lowest: float = 1.0
	for shot: int in 8:
		await _drive(1, 0.0, true)
		for gap: int in 19:
			await _drive(1, 0.0, false)
			lowest = minf(lowest, _aim())
	check(lowest > 0.95, "aim layer stayed up between shots (lowest %.2f)" % lowest)


func test_5_speed_jitter_near_zero_does_not_toggle_running() -> void:
	await _drive(40, 0.0, false)
	var toggles: int = 0
	var was: bool = model.is_running()
	for i: int in 60:
		await _drive(1, 0.3 if i % 2 == 0 else 0.5, false)
		if model.is_running() != was:
			toggles += 1
			was = model.is_running()
	check_eq(toggles, 0, "jitter between the stop and start speeds never starts running")
	await _drive(5, 5.0, false)
	check(model.is_running(), "real movement starts running")
	was = model.is_running()
	toggles = 0
	for i: int in 60:
		await _drive(1, 0.3 if i % 2 == 0 else 0.5, false)
		if model.is_running() != was:
			toggles += 1
			was = model.is_running()
	check_eq(toggles, 0, "jitter while running does not stop it")


func test_6_upper_body_overlay_leaves_legs_alone() -> void:
	await _drive(40, 0.0, false)
	var t: AnimationTree = _tree()
	t.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	t.set_physics_process(false)
	model.set_physics_process(false)
	t.set("parameters/loco/blend_amount", 0.0)
	t.set("parameters/aim/blend_amount", 0.0)
	t.advance(0.0)
	var leg_without: Quaternion = skeleton.get_bone_pose_rotation(skeleton.find_bone("LeftUpLeg"))
	var arm_without: Quaternion = skeleton.get_bone_pose_rotation(skeleton.find_bone("RightForeArm"))
	t.set("parameters/aim/blend_amount", 1.0)
	t.advance(0.0)
	var leg_with: Quaternion = skeleton.get_bone_pose_rotation(skeleton.find_bone("LeftUpLeg"))
	var arm_with: Quaternion = skeleton.get_bone_pose_rotation(skeleton.find_bone("RightForeArm"))
	check(leg_without.is_equal_approx(leg_with), "leg pose is unchanged by the aim layer")
	check(not arm_without.is_equal_approx(arm_with), "arm pose changes with the aim layer")
	model.set_physics_process(true)
	t.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE


func test_7_death_takes_over() -> void:
	var length: float = model.play_death()
	await wait_frames(3)
	check(length > 1.0, "death clip has a length (%.2f s)" % length)
	check(not _tree().active, "tree handed the skeleton back for the death clip")
	check_eq(model.current_clip(), &"die", "death clip is playing")
	await _drive(10, 5.0, true)
	check_eq(model.current_clip(), &"die", "motion updates after death do not interrupt it")


func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (%.3f vs %.3f)" % [message, actual, expected])


func test_8_gait_and_playback_match_ground_speed() -> void:
	# Fresh model: test 7 played the death clip. Speeds given to runs_at/playback_scale are at model scale 1.
	var m: PlayerModel = (load("res://world/player/player_model.tscn") as PackedScene).instantiate() as PlayerModel
	add_child(m)
	await wait_frames(2)
	check(m.has_clip(&"walk"), "walk clip is available")
	var tuning: GameTuning = load("res://data/config/game_tuning.tres") as GameTuning
	var walk: float = tuning.player_walk_speed / tuning.character_scale
	var sprint: float = tuning.sprint_speed() / tuning.character_scale
	var fleet_walk: float = walk * 1.4
	check(not m.runs_at(walk, false) and not m.runs_at(walk, true), "walking (%.2f m/s at scale 1) plays the walk clip" % walk)
	check(m.runs_at(sprint, false) and m.runs_at(sprint, true), "sprinting (%.2f m/s at scale 1) plays the run clip" % sprint)
	# A walk boosted by four Fleet Foot sits between the thresholds: it keeps whichever clip it has, never a blend.
	check(fleet_walk > m.walk_below_speed and fleet_walk < m.run_above_speed, "four Fleet Foot walk (%.2f) is in the hysteresis band" % fleet_walk)
	check(not m.runs_at(fleet_walk, false) and m.runs_at(fleet_walk, true), "inside the band the legs keep their current clip")
	check(m.run_above_speed < sprint, "a plain sprint is above the run switch")
	check_near(m.playback_scale(m.walk_reference_speed, m.walk_reference_speed), 1.0, 0.01, "walk clip at its reference pace is not sped up")
	check_near(m.playback_scale(m.walk_reference_speed * 0.5, m.walk_reference_speed), 0.5, 0.01, "slow walking slows the walk clip")
	check_near(m.playback_scale(m.run_reference_speed, m.run_reference_speed), 1.0, 0.01, "run clip at its reference pace is not sped up")
	# Foot planted speed = clip speed * playback scale must equal the ground speed at every speed the player really uses.
	for v: float in [walk, sprint, fleet_walk, sprint * 1.4]:
		var ref: float = m.run_reference_speed if m.runs_at(v, false) else m.walk_reference_speed
		check_near(m.playback_scale(v, ref) * ref, v, 0.01, "playback matches the ground at %.2f m/s" % v)
	# The generated loops repeat their first pose for a frame; it is dropped so the planted foot never stops mid-stride.
	var source: Animation = load("res://art/models/characters/player/clips/run.res") as Animation
	check(m.clip_length(&"run") < source.length - 0.02, "run loop without its held first frame (%.3f s)" % m.clip_length(&"run"))
	check(source.length > 0.66, "the shared clip resource is not modified")
	m.queue_free()


## Drives a scaled model at a ground speed with the real playback rules and measures its planted feet in world space.
func _slip_at(world_speed: float, size: float) -> float:
	var holder: Node3D = Node3D.new()
	holder.scale = Vector3.ONE * size
	add_child(holder)
	var m: PlayerModel = (load("res://world/player/player_model.tscn") as PackedScene).instantiate() as PlayerModel
	holder.add_child(m)
	await wait_frames(1)
	m.set_physics_process(false)
	var t: AnimationTree = m._tree
	t.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skel: Skeleton3D = m.find_first("Skeleton3D") as Skeleton3D
	var advance: Callable = func(dt: float) -> void:
		m.update_motion(world_speed, false)
		m._physics_process(dt)
		t.advance(dt)
	var slip: float = FootSlip.worst_planted_speed(skel, holder, world_speed, advance)
	holder.queue_free()
	return slip


func test_9_planted_feet_do_not_slide_at_walk_and_sprint() -> void:
	var tuning: GameTuning = load("res://data/config/game_tuning.tres") as GameTuning
	# Plain walk, a walk with four Fleet Foot (between the walk and run switch speeds) and a plain sprint.
	for v: float in [tuning.player_walk_speed, tuning.player_walk_speed * 1.4, tuning.sprint_speed()]:
		var slip: float = await _slip_at(v, tuning.character_scale)
		check(slip < 0.4, "planted foot stays put at %.2f m/s, scale %.2f (slides %.2f m/s)" % [v, tuning.character_scale, slip])
	# The same speed on a model at scale 1 needs a different playback: the scale is taken into account.
	var unscaled: float = await _slip_at(tuning.sprint_speed(), 1.0)
	check(unscaled < 0.4, "planted foot stays put at scale 1 too (slides %.2f m/s)" % unscaled)
