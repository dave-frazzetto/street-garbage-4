class_name PlayerModel
extends CharacterModel
## Visual of the survivor: layered animation plus the weapon model held in the right hand.
## The legs play idle or a directional walk/run: forward, backward and strafe clips mixed by the angle between the movement
## and where the body faces (LocomotionBlend), so moving left while aiming right looks like a sidestep, not a moonwalk.
## While firing, the upper body overlays the shoot pose, so standing still and shooting aims properly and starting or
## stopping a run blends instead of snapping. Presentation only: the player scene calls update_motion() every physics
## frame and never reaches into the model.

## Bone of the Meshy skeleton the weapon is attached to.
@export var hand_bone: StringName = &"RightHand"
## Rotation of every held weapon relative to the hand bone, in degrees. All generated weapons point the same way, so one
## value fits them all; each weapon's length and offset live in its WeaponData.
@export var weapon_rotation_degrees: Vector3 = Vector3.ZERO
## Brightness multiplier and self-lit share of the held weapon's texture, so dark gunmetal stays readable from the game
## camera at night (see ModelLook).
@export_range(0.5, 4.0, 0.05) var weapon_brightness: float = 1.15
@export_range(0.0, 2.0, 0.05) var weapon_glow: float = 0.18
## All speeds below are for the model at scale 1: the ground speed is divided by the model's world scale first, because
## a bigger model takes proportionally longer strides (GameTuning.character_scale).
## Ground speed each directional walk and run clip covers at normal playback (the planted foot's backward speed in the
## character's space, measured on the clip with art/tools/measure_clips.gd), and how fast the leg direction follows the
## movement. Playing a clip at speed / its reference speed keeps the planted foot still on the ground.
@export var locomotion: LocomotionProfile
## The legs switch from the walk clip to the run clip above run_above_speed and back below walk_below_speed; in between
## they keep the clip they have, so a steady speed always plays one clip (the two clips are not phase matched, and a
## blend of them makes the feet slide). Each switch cross-fades at blend_rate. The usual speeds at character scale 1.15,
## in m/s at scale 1: walk 2.0, walk with four Fleet Foot 2.8, sprint 3.0. The walk clip looks right up to about 2x
## playback, the run clip down to about 0.55x.
@export_range(0.0, 8.0, 0.05) var walk_below_speed: float = 2.7
@export_range(0.0, 8.0, 0.05) var run_above_speed: float = 2.9
## Playback speed ratio (speed / reference) above which the step rate grows only by cadence_excess_share of the extra.
## Above it the feet slide on purpose (a very fast perk-boosted run would otherwise need a blur of steps). At 2 no speed
## the player can reach eases: the walk clip stops at run_above_speed / the walk reference speed (2x).
@export_range(1.0, 3.0, 0.05) var cadence_soft_limit: float = 2.0
## Share of the ratio above the soft limit that is still applied (1 = exact foot matching, 0 = cadence stops growing).
@export_range(0.0, 1.0, 0.05) var cadence_excess_share: float = 0.5
## Slowest and fastest playback of the walk and run clips (the playback that keeps the feet planted is clamped to this).
@export_range(0.1, 1.0, 0.05) var min_playback_scale: float = 0.4
@export_range(0.5, 4.0, 0.05) var max_playback_scale: float = 2.6
## Speed above which the legs start running, and below which they stop (the gap prevents flicker near zero).
@export_range(0.0, 3.0, 0.05) var move_start_speed: float = 0.6
@export_range(0.0, 3.0, 0.05) var move_stop_speed: float = 0.25
## The aim pose stays this many seconds after the last frame the player was firing (bridges the gaps between shots).
@export_range(0.0, 1.0, 0.05) var fire_hold_time: float = 0.35
## How fast layers blend in and out, in blend units per second (higher = snappier).
@export_range(1.0, 30.0, 0.5) var blend_rate: float = 9.0
## Bones that follow the shoot clip while firing; the rest (hips and legs) keep the locomotion layer.
@export var upper_body_bones: PackedStringArray = [
	"Spine02", "Spine01", "Spine", "neck", "Head", "head_end", "headfront",
	"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand",
]

const _WALK_SPACE: String = "parameters/walk_space/blend_position"
const _RUN_SPACE: String = "parameters/run_space/blend_position"
const _SIDES: Array[StringName] = [&"forward", &"back", &"left", &"right"]
## Where each clip sits in a blend space: x to the character's right, y forward.
const _SIDE_POSITIONS: Dictionary = {
	&"forward": Vector2(0, 1), &"back": Vector2(0, -1), &"left": Vector2(-1, 0), &"right": Vector2(1, 0),
}
const _LOCO: String = "parameters/loco/blend_amount"
const _AIM: String = "parameters/aim/blend_amount"
const _RUN_SPEED: String = "parameters/run_speed/scale"
const _WALK_SPEED: String = "parameters/walk_speed/scale"
const _GAIT: String = "parameters/gait/blend_amount"

var _dead: bool = false
var _weapon_holder: BoneAttachment3D
var _held: WeaponData
var _tree: AnimationTree
var _ground_speed: float = 0.0
var _velocity: Vector3 = Vector3.ZERO
## Smoothed movement direction in the body's frame (x right, y forward) that drives the blend spaces.
var _direction: Vector2 = Vector2(0.0, 1.0)
var _fire_hold: float = 0.0
var _moving: bool = false
var _loco_blend: float = 0.0
var _aim_blend: float = 0.0
var _running_gait: bool = false
var _gait_blend: float = 0.0


func _ready() -> void:
	super._ready()
	if locomotion == null:
		locomotion = LocomotionProfile.new()
	_build_tree()
	_attach_weapon()


## Shows this weapon's model in the hand (WeaponData.held_model, length and offset). Call when the weapon changes.
func hold_weapon(weapon: WeaponData) -> void:
	_held = weapon
	_attach_weapon()


## Call every physics frame with the player's world velocity (m/s, world units) and whether the fire input is held. Which
## way the legs play comes from the velocity relative to this node's own facing, so rotate the model (or its parent) to aim.
func update_motion(velocity: Vector3, firing: bool) -> void:
	_velocity = velocity
	_ground_speed = Vector2(velocity.x, velocity.z).length()
	if firing:
		_fire_hold = fire_hold_time


## True while the upper body is (or is blending into) the aim pose.
func is_aiming() -> bool:
	return _fire_hold > 0.0


## The smoothed movement direction relative to the facing (x right, y forward) that the legs are playing.
func move_direction() -> Vector2:
	return _direction


## True while the legs are running (with hysteresis).
func is_running() -> bool:
	return _moving


## Plays the death clip once and returns its length in seconds (0 when there is no clip).
func play_death() -> float:
	_dead = true
	clear_flash()
	if _tree != null:
		_tree.active = false
	if has_clip(&"die"):
		_player.play(&"die", 0.1)
		_player.speed_scale = 1.0
	return clip_length(&"die")


func _physics_process(delta: float) -> void:
	if _dead or _tree == null:
		return
	_fire_hold = maxf(0.0, _fire_hold - delta)
	if _moving and _ground_speed < move_stop_speed:
		_moving = false
	elif not _moving and _ground_speed > move_start_speed:
		_moving = true
	_update_direction(delta)
	_loco_blend = move_toward(_loco_blend, 1.0 if _moving else 0.0, blend_rate * delta)
	_aim_blend = move_toward(_aim_blend, 1.0 if _fire_hold > 0.0 else 0.0, blend_rate * delta)
	_tree.set(_LOCO, _loco_blend)
	_tree.set(_AIM, _aim_blend)
	var unit_speed: float = _ground_speed / maxf(global_transform.basis.get_scale().x, 0.1)
	_running_gait = runs_at(unit_speed, _running_gait)
	_gait_blend = move_toward(_gait_blend, 1.0 if _running_gait else 0.0, blend_rate * delta)
	_tree.set(_GAIT, _gait_blend)
	var position: Vector2 = LocomotionBlend.blend_position(_direction)
	_tree.set(_WALK_SPACE, position)
	_tree.set(_RUN_SPACE, position)
	_tree.set(_WALK_SPEED, playback_scale(unit_speed, locomotion.reference_speed(&"walk", _direction)))
	_tree.set(_RUN_SPEED, playback_scale(unit_speed, locomotion.reference_speed(&"run", _direction)))


## Follows the movement direction. While the legs are idle the direction snaps (nothing visible to swing), so a start
## from standing never sweeps from a stale direction; while moving it turns at locomotion.turn_rate_degrees.
func _update_direction(delta: float) -> void:
	var target: Vector2 = LocomotionBlend.local_direction(_velocity, _facing_yaw())
	if not _moving or _loco_blend < 0.05:
		_direction = target if target != Vector2.ZERO else _direction
	else:
		_direction = LocomotionBlend.turn_toward(_direction, target, deg_to_rad(locomotion.turn_rate_degrees) * delta)


func _facing_yaw() -> float:
	var forward: Vector3 = -global_basis.z
	return atan2(-forward.x, -forward.z)


## True when the legs play the run clip at this ground speed (m/s at model scale 1), given whether they play it now.
func runs_at(ground_speed: float, running_now: bool) -> bool:
	if not has_clip(&"walk"):
		return true
	if ground_speed > run_above_speed:
		return true
	if ground_speed < walk_below_speed:
		return false
	return running_now


## Playback speed of a locomotion clip so its planted foot travels at the ground speed, with the step rate eased at sprint.
func playback_scale(ground_speed: float, reference_speed: float) -> float:
	var ratio: float = ground_speed / reference_speed
	if ratio > cadence_soft_limit:
		ratio = cadence_soft_limit + (ratio - cadence_soft_limit) * cadence_excess_share
	return clampf(ratio, min_playback_scale, max_playback_scale)


# Layers: locomotion = idle blended into a walk/run gait, each gait a blend space of forward, backward and strafe clips;
# upper body = that, overlaid with the shoot pose on the upper-body bones.
func _build_tree() -> void:
	if _player == null or not (has_clip(&"idle") and has_clip(&"run") and has_clip(&"shoot")):
		return
	var graph: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var with_walk: bool = has_clip(&"walk")
	for pair: Array in [["idle", &"idle"], ["shoot", &"shoot"]]:
		var clip_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
		clip_node.animation = pair[1]
		graph.add_node(pair[0], clip_node)
	graph.add_node("run_space", _build_space(&"run"))
	if with_walk:
		graph.add_node("walk_space", _build_space(&"walk"))
	graph.add_node("run_speed", AnimationNodeTimeScale.new())
	graph.add_node("walk_speed", AnimationNodeTimeScale.new())
	graph.add_node("gait", AnimationNodeBlend2.new())
	var loco: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	graph.add_node("loco", loco)
	var aim: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	aim.filter_enabled = true
	var skeleton_path: String = String(_player.get_node(_player.root_node).get_path_to(find_first("Skeleton3D")))
	for bone: String in upper_body_bones:
		aim.set_filter_path(NodePath("%s:%s" % [skeleton_path, bone]), true)
	graph.add_node("aim", aim)
	graph.connect_node("run_speed", 0, "run_space")
	graph.connect_node("loco", 0, "idle")
	if with_walk:
		graph.connect_node("walk_speed", 0, "walk_space")
		graph.connect_node("gait", 0, "walk_speed")
	else:
		graph.connect_node("gait", 0, "run_speed")
	graph.connect_node("gait", 1, "run_speed")
	graph.connect_node("loco", 1, "gait")
	graph.connect_node("aim", 0, "loco")
	graph.connect_node("aim", 1, "shoot")
	graph.connect_node("output", 0, "aim")
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.tree_root = graph
	# Sibling of the AnimationPlayer, so the default root_node ("..") resolves the clips' track paths the same way.
	_player.get_parent().add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_player)
	_tree.active = true


## A blend space with the gait's forward, backward, left and right clips at the corners of the unit diamond. A direction
## without its own clip plays the forward one, so a character with only walk and run still works.
func _build_space(gait: StringName) -> AnimationNodeBlendSpace2D:
	var space: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	space.min_space = Vector2(-1, -1)
	space.max_space = Vector2(1, 1)
	space.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	# Keep every clip advancing so a clip fading in is not stuck at the pose where it last stopped.
	space.sync = true
	for side: StringName in _SIDES:
		var clip_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
		var wanted: StringName = LocomotionBlend.clip_name(gait, side)
		clip_node.animation = wanted if has_clip(wanted) else gait
		space.add_blend_point(clip_node, _SIDE_POSITIONS[side], -1, side)
	return space


func _attach_weapon() -> void:
	if _weapon_holder != null:
		_weapon_holder.get_parent().remove_child(_weapon_holder)
		_weapon_holder.queue_free()
		_weapon_holder = null
	var skeleton: Skeleton3D = find_first("Skeleton3D") as Skeleton3D
	if skeleton == null or _held == null or _held.held_model == null or skeleton.find_bone(hand_bone) < 0:
		return
	_weapon_holder = BoneAttachment3D.new()
	_weapon_holder.name = "WeaponHolder"
	_weapon_holder.bone_name = hand_bone
	skeleton.add_child(_weapon_holder)
	var weapon: Node3D = _held.held_model.instantiate() as Node3D
	_weapon_holder.add_child(weapon)
	# The Meshy skeleton is in centimetres (node scale 0.01), so convert metres into the bone's space. Measured against this
	# model's own space, so the weapon grows with the model when the player is scaled (GameTuning.character_scale).
	var to_model: Transform3D = global_transform.affine_inverse() * _weapon_holder.global_transform
	var bone_space: float = maxf(to_model.basis.get_scale().x, 0.0001)
	var box: AABB = FitModel.measure(_held.held_model)
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	var unit: float = (_held.held_length / maxf(longest, 0.0001)) / bone_space
	var turn: Basis = Basis.from_euler(weapon_rotation_degrees * (PI / 180.0))
	weapon.basis = turn * Basis.from_scale(Vector3.ONE * unit)
	# Centre the model's bounding box on the hand, then shift by the weapon's offset.
	weapon.position = _held.held_offset / bone_space - turn * (box.get_center() * unit)
	for mesh: MeshInstance3D in ModelLook.meshes_of(weapon):
		ModelLook.lift(mesh, weapon_brightness, weapon_glow)
