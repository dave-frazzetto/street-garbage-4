class_name PlayerModel
extends CharacterModel
## Visual of the survivor: layered animation plus the weapon model held in the right hand.
## The legs play idle or run; while firing, the upper body overlays the shoot pose, so standing still and shooting aims
## properly and starting or stopping a run blends instead of snapping. Presentation only: the player scene calls
## update_motion() every physics frame and never reaches into the model.

## Weapon model held in the hand (one scene per weapon; swap it when the weapon changes).
@export var weapon_scene: PackedScene:
	set(value):
		weapon_scene = value
		if is_node_ready():
			_attach_weapon()
## Bone of the Meshy skeleton the weapon is attached to.
@export var hand_bone: StringName = &"RightHand"
## Weapon placement relative to the hand bone, in metres and degrees (tune in the Inspector against the preview).
@export var weapon_position: Vector3 = Vector3.ZERO
@export var weapon_rotation_degrees: Vector3 = Vector3.ZERO
## Size in metres of the weapon model's unit size (the generated weapon GLBs are about one unit long).
@export_range(0.01, 2.0, 0.01) var weapon_scale: float = 0.36
## Ground speed in m/s at which the run clip plays at normal speed.
@export_range(0.5, 12.0, 0.1) var run_reference_speed: float = 3.6
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

var _dead: bool = false
var _weapon_holder: BoneAttachment3D
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
	_tree.set(_RUN_SPEED, clampf(_ground_speed / run_reference_speed, 0.5, max_playback_scale))


# Layers: locomotion = idle blended into run; upper body = that, overlaid with the shoot pose on the upper-body bones.
func _build_tree() -> void:
	if _player == null or not (has_clip(&"idle") and has_clip(&"run") and has_clip(&"shoot")):
		return
	var graph: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	for pair: Array in [["idle", &"idle"], ["run", &"run"], ["shoot", &"shoot"]]:
		var clip_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
		clip_node.animation = pair[1]
		graph.add_node(pair[0], clip_node)
	graph.add_node("run_speed", AnimationNodeTimeScale.new())
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
	graph.connect_node("loco", 1, "run_speed")
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
	if skeleton == null or weapon_scene == null or skeleton.find_bone(hand_bone) < 0:
		return
	_weapon_holder = BoneAttachment3D.new()
	_weapon_holder.name = "WeaponHolder"
	_weapon_holder.bone_name = hand_bone
	skeleton.add_child(_weapon_holder)
	var weapon: Node3D = weapon_scene.instantiate() as Node3D
	_weapon_holder.add_child(weapon)
	# The Meshy skeleton is in centimetres (node scale 0.01), so convert metres into the bone's space.
	var bone_space: float = maxf(_weapon_holder.global_transform.basis.get_scale().x, 0.0001)
	weapon.position = weapon_position / bone_space
	weapon.rotation_degrees = weapon_rotation_degrees
	weapon.scale = Vector3.ONE * (weapon_scale / bone_space)
