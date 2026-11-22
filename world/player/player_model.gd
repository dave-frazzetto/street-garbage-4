class_name PlayerModel
extends CharacterModel
## Visual of the survivor: layered animation plus the weapon model held in the right hand.
## The legs play idle or run; while firing, the upper body overlays the shoot pose, so standing still and shooting aims
## properly and starting or stopping a run blends instead of snapping. Presentation only: the player scene calls
## update_motion() every physics frame and never reaches into the model.

## Bone of the Meshy skeleton the weapon is attached to.
@export var hand_bone: StringName = &"RightHand"
## Rotation of every held weapon relative to the hand bone, in degrees. All generated weapons point the same way, so one
## value fits them all; each weapon's length and offset live in its WeaponData.
@export var weapon_rotation_degrees: Vector3 = Vector3.ZERO
## Ground speed in m/s the walk clip covers at normal playback speed (measured from the foot travel while a foot is planted:
## the clip's feet move about 1.1 to 1.7 m/s). Playing it at speed / this value keeps the feet from sliding.
@export_range(0.3, 6.0, 0.05) var walk_reference_speed: float = 1.4
## Same for the run clip (measured about 3.1 to 3.9 m/s).
@export_range(0.5, 12.0, 0.05) var run_reference_speed: float = 3.5
## Below this ground speed the legs play only the walk clip; above walk_to_run_end only the run clip; in between they blend.
@export_range(0.0, 8.0, 0.05) var walk_to_run_start: float = 2.2
@export_range(0.0, 8.0, 0.05) var walk_to_run_end: float = 3.2
## Playback speed ratio (speed / reference) above which the step rate grows only by cadence_excess_share of the extra.
## A clip has a fixed stride, so keeping the feet planted at sprint speed would need an unnaturally quick step rate.
@export_range(1.0, 3.0, 0.05) var cadence_soft_limit: float = 1.5
## Share of the ratio above the soft limit that is still applied (1 = exact foot matching, 0 = cadence stops growing).
@export_range(0.0, 1.0, 0.05) var cadence_excess_share: float = 0.5
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
var _fire_hold: float = 0.0
var _moving: bool = false
var _loco_blend: float = 0.0
var _aim_blend: float = 0.0


func _ready() -> void:
	super._ready()
	_build_tree()
	_attach_weapon()


## Shows this weapon's model in the hand (WeaponData.held_model, length and offset). Call when the weapon changes.
func hold_weapon(weapon: WeaponData) -> void:
	_held = weapon
	_attach_weapon()


## Call every physics frame with the player's ground speed (m/s) and whether the fire input is held.
func update_motion(ground_speed: float, firing: bool) -> void:
	_ground_speed = ground_speed
	if firing:
		_fire_hold = fire_hold_time


## True while the upper body is (or is blending into) the aim pose.
func is_aiming() -> bool:
	return _fire_hold > 0.0


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
	_loco_blend = move_toward(_loco_blend, 1.0 if _moving else 0.0, blend_rate * delta)
	_aim_blend = move_toward(_aim_blend, 1.0 if _fire_hold > 0.0 else 0.0, blend_rate * delta)
	_tree.set(_LOCO, _loco_blend)
	_tree.set(_AIM, _aim_blend)
	_tree.set(_GAIT, gait_blend(_ground_speed))
	_tree.set(_WALK_SPEED, playback_scale(_ground_speed, walk_reference_speed))
	_tree.set(_RUN_SPEED, playback_scale(_ground_speed, run_reference_speed))


## 0 = walk clip, 1 = run clip for this ground speed.
func gait_blend(ground_speed: float) -> float:
	if not has_clip(&"walk"):
		return 1.0
	return smoothstep(walk_to_run_start, maxf(walk_to_run_end, walk_to_run_start + 0.01), ground_speed)


## Playback speed of a locomotion clip so its planted foot travels at the ground speed, with the step rate eased at sprint.
func playback_scale(ground_speed: float, reference_speed: float) -> float:
	var ratio: float = ground_speed / reference_speed
	if ratio > cadence_soft_limit:
		ratio = cadence_soft_limit + (ratio - cadence_soft_limit) * cadence_excess_share
	return clampf(ratio, 0.5, max_playback_scale)


# Layers: locomotion = idle blended into a walk/run gait; upper body = that, overlaid with the shoot pose on the upper-body bones.
func _build_tree() -> void:
	if _player == null or not (has_clip(&"idle") and has_clip(&"run") and has_clip(&"shoot")):
		return
	var graph: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var names: Array = [["idle", &"idle"], ["run", &"run"], ["shoot", &"shoot"]]
	var with_walk: bool = has_clip(&"walk")
	if with_walk:
		names.append(["walk", &"walk"])
	for pair: Array in names:
		var clip_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
		clip_node.animation = pair[1]
		graph.add_node(pair[0], clip_node)
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
	graph.connect_node("run_speed", 0, "run")
	graph.connect_node("loco", 0, "idle")
	if with_walk:
		graph.connect_node("walk_speed", 0, "walk")
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
	# The Meshy skeleton is in centimetres (node scale 0.01), so convert metres into the bone's space.
	var bone_space: float = maxf(_weapon_holder.global_transform.basis.get_scale().x, 0.0001)
	var box: AABB = FitModel.measure(_held.held_model)
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	var unit: float = (_held.held_length / maxf(longest, 0.0001)) / bone_space
	var turn: Basis = Basis.from_euler(weapon_rotation_degrees * (PI / 180.0))
	weapon.basis = turn * Basis.from_scale(Vector3.ONE * unit)
	# Centre the model's bounding box on the hand, then shift by the weapon's offset.
	weapon.position = _held.held_offset / bone_space - turn * (box.get_center() * unit)
	for mesh: MeshInstance3D in ModelLook.meshes_of(weapon):
		ModelLook.lift(mesh, 1.3, 0.12)
