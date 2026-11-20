class_name PlayerModel
extends CharacterModel
## Visual of the survivor: idle, run, run-and-shoot and death, with the weapon model held in the right hand.
## Presentation only. The player scene tells it what is happening; it never reaches into gameplay.

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

var _dead: bool = false
var _weapon_holder: BoneAttachment3D


func _ready() -> void:
	super._ready()
	play(&"idle", 0.0)
	_attach_weapon()


## Call every physics frame with the current motion. Picks idle, run or run-and-shoot.
func update_motion(ground_speed: float, firing: bool) -> void:
	if _dead:
		return
	if ground_speed < 0.2:
		play(&"idle", 0.2, 1.0)
		return
	var clip: StringName = &"shoot" if firing and has_clip(&"shoot") else &"run"
	play(clip, 0.12, clampf(ground_speed / run_reference_speed, 0.5, max_playback_scale))


## Plays the death clip once and returns its length in seconds (0 when there is no clip).
func play_death() -> float:
	_dead = true
	clear_flash()
	play(&"die", 0.1, 1.0)
	return clip_length(&"die")


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
