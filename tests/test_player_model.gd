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
	# Fresh model: test 7 played the death clip.
	var m: PlayerModel = (load("res://world/player/player_model.tscn") as PackedScene).instantiate() as PlayerModel
	add_child(m)
	await wait_frames(2)
	check(m.has_clip(&"walk"), "walk clip is available")
	check_eq(m.gait_blend(1.4), 0.0, "walking pace plays only the walk clip")
	check_eq(m.gait_blend(4.4), 1.0, "walk speed of the player plays only the run clip")
	var mid: float = m.gait_blend(2.7)
	check(mid > 0.1 and mid < 0.9, "in between the clips blend (%.2f)" % mid)
	check_near(m.playback_scale(1.4, m.walk_reference_speed), 1.0, 0.01, "walk clip at its reference pace is not sped up")
	check_near(m.playback_scale(0.7, m.walk_reference_speed), 0.5, 0.01, "slow walking slows the walk clip")
	check_near(m.playback_scale(3.5, m.run_reference_speed), 1.0, 0.01, "run clip at its reference pace is not sped up")
	# Foot planted speed = clip speed * playback scale must equal the ground speed where the cadence is not eased.
	for v: float in [1.0, 1.4, 3.5, 4.4]:
		var ref: float = m.walk_reference_speed if v < 2.5 else m.run_reference_speed
		check_near(m.playback_scale(v, ref) * ref, v, 0.01, "feet match the ground at %.1f m/s" % v)
	# Sprint: faster than walking, but the step rate grows less than the speed (eased cadence).
	var walk_rate: float = m.playback_scale(4.4, m.run_reference_speed)
	var sprint_rate: float = m.playback_scale(6.6, m.run_reference_speed)
	check(sprint_rate > walk_rate, "sprint steps faster than the walk")
	check(sprint_rate / walk_rate < 6.6 / 4.4, "step rate grows slower than speed at sprint (%.2f vs %.2f)" % [sprint_rate / walk_rate, 6.6 / 4.4])
	m.queue_free()
