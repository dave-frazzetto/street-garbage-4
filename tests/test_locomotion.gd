extends TestCase
## Directional locomotion: the node-free maths (LocomotionBlend), the per-direction speeds (LocomotionProfile) and that the
## player model's legs follow the angle between movement and facing, with the right clips and without snapping.

const SPEED: float = 4.4

var model: PlayerModel


func _ready() -> void:
	model = (load("res://world/player/player_model.tscn") as PackedScene).instantiate() as PlayerModel
	add_child(model)
	run_all()


func check_vec(actual: Vector2, expected: Vector2, message: String) -> void:
	check(actual.distance_to(expected) < 0.01, "%s (expected %s, got %s)" % [message, expected, actual])


## World velocity of a body facing `yaw` moving relative to its facing: forward is -Z turned by yaw, right is +X turned by yaw.
func _world(local: Vector2, yaw: float) -> Vector3:
	var forward: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	return (right * local.x + forward * local.y) * SPEED


func _drive(frames: int, velocity: Vector3, firing: bool = false) -> void:
	for i: int in frames:
		model.update_motion(velocity, firing)
		await get_tree().physics_frame


func _tree() -> AnimationTree:
	return model._tree


# --- node-free maths -------------------------------------------------------------------------------------------------

func test_1_local_direction_follows_facing() -> void:
	var v: Vector3 = Vector3(0.0, 0.0, -SPEED)
	check_vec(LocomotionBlend.local_direction(v, 0.0), Vector2(0, 1), "moving along the facing is forward")
	check_vec(LocomotionBlend.local_direction(-v, 0.0), Vector2(0, -1), "moving against the facing is backward")
	check_vec(LocomotionBlend.local_direction(Vector3(SPEED, 0, 0), 0.0), Vector2(1, 0), "moving to the facing's right strafes right")
	check_vec(LocomotionBlend.local_direction(Vector3(-SPEED, 0, 0), 0.0), Vector2(-1, 0), "moving to the facing's left strafes left")
	# Aiming right (+X) means yaw -90 degrees (atan2(-aim.x, -aim.z) for aim = +X).
	var yaw: float = atan2(-1.0, 0.0)
	check_vec(LocomotionBlend.local_direction(Vector3(-SPEED, 0, 0), yaw), Vector2(0, -1), "walking left while aiming right is backward")
	check_vec(LocomotionBlend.local_direction(Vector3(SPEED, 0, 0), yaw), Vector2(0, 1), "walking right while aiming right is forward")
	check_vec(LocomotionBlend.local_direction(Vector3(0, 0, -SPEED), yaw), Vector2(-1, 0), "walking up while aiming right is a left strafe")
	var diagonal: Vector2 = LocomotionBlend.local_direction(Vector3(SPEED, 0, -SPEED), 0.0)
	check_vec(diagonal, Vector2(0.7071, 0.7071), "forward-right diagonal is a unit vector")
	check_eq(LocomotionBlend.local_direction(Vector3(0.01, 0, 0.01), 0.0), Vector2.ZERO, "standing still has no direction")
	for turn: int in 8:
		var facing: float = turn * PI / 4.0
		check_vec(LocomotionBlend.local_direction(_world(Vector2(0, 1), facing), facing), Vector2(0, 1), "forward at facing %d" % turn)
		check_vec(LocomotionBlend.local_direction(_world(Vector2(-1, 0), facing), facing), Vector2(-1, 0), "left at facing %d" % turn)


func test_2_blend_position_and_weights_mix_two_neighbours() -> void:
	check_vec(LocomotionBlend.blend_position(Vector2(0, 1)), Vector2(0, 1), "forward sits at the forward corner")
	check_vec(LocomotionBlend.blend_position(Vector2(0.7071, 0.7071)), Vector2(0.5, 0.5), "a diagonal sits mid-edge")
	var w: Dictionary = LocomotionBlend.weights(Vector2(0.7071, 0.7071))
	check_eq(w[&"forward"], 0.5, "diagonal is half forward")
	check_eq(w[&"right"], 0.5, "diagonal is half right")
	check_eq(w[&"back"], 0.0, "diagonal has no backward clip")
	check_eq(w[&"left"], 0.0, "diagonal has no left clip")
	for angle: int in range(0, 360, 15):
		var d: Vector2 = Vector2(sin(deg_to_rad(angle)), cos(deg_to_rad(angle)))
		var total: float = 0.0
		var active: int = 0
		var ws: Dictionary = LocomotionBlend.weights(d)
		for side: StringName in ws:
			total += float(ws[side])
			active += 1 if float(ws[side]) > 0.0001 else 0
		check(is_equal_approx(total, 1.0), "weights sum to 1 at %d degrees (%.3f)" % [angle, total])
		check(active <= 2, "at most two clips play at %d degrees (%d)" % [angle, active])


func test_3_turn_toward_takes_the_short_arc_through_strafe() -> void:
	var step: float = deg_to_rad(10.0)
	var d: Vector2 = Vector2(0, 1)
	var seen_strafe: bool = false
	for i: int in 40:
		d = LocomotionBlend.turn_toward(d, Vector2(0, -1), step)
		if absf(d.x) > 0.95:
			seen_strafe = true
		check(absf(d.length() - 1.0) < 0.001, "direction stays a unit vector")
	check(seen_strafe, "reversing sweeps through a strafe pose, not through the middle")
	check_vec(d, Vector2(0, -1), "reaches the target")
	check_eq(LocomotionBlend.turn_toward(Vector2(1, 0), Vector2.ZERO, step), Vector2(1, 0), "no target keeps the direction")
	var short: Vector2 = LocomotionBlend.turn_toward(Vector2(0, 1), Vector2(1, 0), step)
	check(short.x > 0.0 and short.y > 0.9, "a small step turns only a little")
	# Shortest arc: from 170 degrees (almost straight back, slightly right) to -20 (forward, slightly left) is 170 degrees
	# on through the back to the left, not 190 degrees back through the right.
	var from_angle: float = deg_to_rad(170.0)
	var start: Vector2 = Vector2(sin(from_angle), cos(from_angle))
	var goal: Vector2 = Vector2(sin(deg_to_rad(-20.0)), cos(deg_to_rad(-20.0)))
	var next: Vector2 = LocomotionBlend.turn_toward(start, goal, step)
	check(next.x < start.x, "turns the short way (round the back to the left, not through the right strafe)")


func test_4_clip_names() -> void:
	check_eq(LocomotionBlend.clip_name(&"walk", &"forward"), &"walk", "forward keeps the plain gait name")
	check_eq(LocomotionBlend.clip_name(&"run", &"back"), &"run_back", "backward run clip")
	check_eq(LocomotionBlend.clip_name(&"walk", &"left"), &"walk_left", "left walk clip")


func test_5_profile_reference_speeds() -> void:
	var p: LocomotionProfile = LocomotionProfile.new()
	check_eq(p.reference_speed(&"run", Vector2(0, 1)), p.run_forward, "forward uses the forward run speed")
	check_eq(p.reference_speed(&"run", Vector2(0, -1)), p.run_back, "backward uses the backward run speed")
	check_eq(p.reference_speed(&"walk", Vector2(-1, 0)), p.walk_left, "left uses the left walk speed")
	var mid: float = p.reference_speed(&"run", Vector2(0.7071, 0.7071))
	check_eq(mid, (p.run_forward + p.run_right) * 0.5, "a diagonal averages its two clips")
	var shipped: LocomotionProfile = load("res://data/config/player_locomotion.tres") as LocomotionProfile
	check(shipped != null and shipped.run_forward > 0.0, "the shipped profile loads")


# --- the model --------------------------------------------------------------------------------------------------------

func test_6_every_directional_clip_is_installed() -> void:
	await wait_frames(2)
	for gait: StringName in [&"walk", &"run"]:
		for side: StringName in [&"forward", &"back", &"left", &"right"]:
			var clip: StringName = LocomotionBlend.clip_name(gait, side)
			check(model.has_clip(clip), "player has the %s clip" % clip)
			check(model.clip_length(clip) > 0.3, "%s has a length" % clip)
	check(_tree() != null and _tree().active, "animation tree is active")


func test_7_legs_follow_movement_relative_to_facing() -> void:
	# Facing -Z (yaw 0): run forward, backward, left, right.
	for case: Array in [[Vector2(0, 1), "forward"], [Vector2(0, -1), "backward"], [Vector2(-1, 0), "left"], [Vector2(1, 0), "right"]]:
		var local: Vector2 = case[0]
		model.rotation.y = 0.0
		await _drive(5, Vector3.ZERO)
		await _drive(60, _world(local, 0.0))
		check_vec(model.move_direction(), local, "legs play %s" % case[1])
		check_vec(_tree().get("parameters/run_space/blend_position") as Vector2, local, "run blend position is %s" % case[1])
		check_vec(_tree().get("parameters/walk_space/blend_position") as Vector2, local, "walk blend position is %s" % case[1])
	# Same world movement, different aim: moving left (-X) while aiming right (yaw -90) is a backpedal.
	model.rotation.y = atan2(-1.0, 0.0)
	await _drive(5, Vector3.ZERO)
	await _drive(60, Vector3(-SPEED, 0, 0))
	check_vec(model.move_direction(), Vector2(0, -1), "moving left while aiming right backpedals")
	# Turning the aim while the movement stays the same changes the legs (a strafe becomes forward running).
	await _drive(2, Vector3(-SPEED, 0, 0))
	model.rotation.y = atan2(1.0, 0.0)
	await _drive(60, Vector3(-SPEED, 0, 0))
	check_vec(model.move_direction(), Vector2(0, 1), "moving left while aiming left runs forward")
	model.rotation.y = 0.0


func test_8_aim_flip_blends_without_snapping() -> void:
	model.rotation.y = 0.0
	await _drive(5, Vector3.ZERO)
	await _drive(60, _world(Vector2(0, 1), 0.0))
	check_vec(model.move_direction(), Vector2(0, 1), "starts running forward")
	# The aim flips 180 degrees in one frame: the legs must turn gradually, through a strafe pose.
	model.rotation.y = PI
	var previous: Vector2 = model.move_direction()
	var biggest_jump: float = 0.0
	var passed_strafe: bool = false
	for i: int in 60:
		await _drive(1, _world(Vector2(0, 1), 0.0))
		var d: Vector2 = model.move_direction()
		biggest_jump = maxf(biggest_jump, absf(angle_difference(atan2(previous.x, previous.y), atan2(d.x, d.y))))
		passed_strafe = passed_strafe or absf(d.x) > 0.95
		previous = d
	var limit: float = deg_to_rad(model.locomotion.turn_rate_degrees) / float(Engine.physics_ticks_per_second) + 0.01
	check(biggest_jump <= limit, "the legs never turn faster than the turn rate (%.3f rad per frame, limit %.3f)" % [biggest_jump, limit])
	check(passed_strafe, "the reversal passed through a strafe pose")
	check_vec(model.move_direction(), Vector2(0, -1), "ends backpedalling")
	model.rotation.y = 0.0


func test_9_standing_start_has_no_sweep() -> void:
	model.rotation.y = 0.0
	await _drive(40, Vector3.ZERO)
	# The legs last ran backward; starting to the right from a stop must show right at once, not sweep from backward.
	await _drive(40, _world(Vector2(0, -1), 0.0))
	await _drive(40, Vector3.ZERO)
	await _drive(1, _world(Vector2(1, 0), 0.0))
	check_vec(model.move_direction(), Vector2(1, 0), "the first moving frame already plays right")


func test_10_speed_scale_uses_the_direction_reference() -> void:
	model.rotation.y = 0.0
	await _drive(5, Vector3.ZERO)
	await _drive(60, _world(Vector2(0, 1), 0.0))
	var forward_scale: float = float(_tree().get("parameters/run_speed/scale"))
	await _drive(5, Vector3.ZERO)
	await _drive(60, _world(Vector2(0, -1), 0.0))
	var back_scale: float = float(_tree().get("parameters/run_speed/scale"))
	check(back_scale > forward_scale, "backpedalling at the same speed plays its slower clip faster (%.2f vs %.2f)" % [back_scale, forward_scale])
	check_eq(back_scale, model.playback_scale(SPEED, model.locomotion.run_back), "scale comes from the backward reference speed")


func test_11_missing_directional_clips_fall_back_to_forward() -> void:
	var bare: PlayerModel = (load("res://world/player/player_model.tscn") as PackedScene).instantiate() as PlayerModel
	for clip: StringName in [&"walk_back", &"walk_left", &"walk_right", &"run_back", &"run_left", &"run_right"]:
		bare.clips = bare.clips.duplicate()
		bare.clips.erase(clip)
	add_child(bare)
	await wait_frames(2)
	check(bare._tree != null and bare._tree.active, "tree still builds without directional clips")
	for i: int in 30:
		bare.update_motion(Vector3(SPEED, 0, 0), false)
		await get_tree().physics_frame
	check(bare.is_running(), "a model with forward clips only still runs when moving sideways")
	bare.queue_free()
