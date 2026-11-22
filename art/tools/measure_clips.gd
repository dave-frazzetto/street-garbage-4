@tool
extends SceneTree
## Measures locomotion clips on the player rig: travel direction and speed (from the planted foot), steps per cycle and how
## well the loop closes. Used to fill LocomotionProfile.
## Run: godot --headless --path . -s res://art/tools/measure_clips.gd -- walk walk_back walk_left ...
## Directions are in the character's frame: +z forward, +x the character's left (glTF convention, model faces +Z).

const RIG: String = "res://art/models/characters/player/player_rigged.glb"
const CLIPS: String = "res://art/models/characters/player/clips/%s.res"
const SAMPLES: int = 120


func _initialize() -> void:
	var root: Node = (load(RIG) as PackedScene).instantiate()
	get_root().add_child.call_deferred(root)
	_run.call_deferred(root)


func _run(root: Node) -> void:
	var names: PackedStringArray = OS.get_cmdline_user_args()
	var skeleton: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library: AnimationLibrary = AnimationLibrary.new()
	for n: String in names:
		library.add_animation(n, load(CLIPS % n) as Animation)
	player.add_animation_library(&"m", library)
	for n: String in names:
		_measure(root, skeleton, player, n)
	print("DONE measure_clips")
	quit()


func _local(root: Node3D, skeleton: Skeleton3D, bone: int) -> Vector3:
	return root.global_transform.affine_inverse() * (skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin)


func _measure(root: Node3D, skeleton: Skeleton3D, player: AnimationPlayer, clip_name: String) -> void:
	var clip: Animation = player.get_animation("m/" + clip_name)
	var feet: Array[int] = [skeleton.find_bone("LeftFoot"), skeleton.find_bone("RightFoot")]
	var hips: int = skeleton.find_bone("Hips")
	var length: float = clip.length
	var dt: float = length / SAMPLES
	player.play("m/" + clip_name)
	var rel: Array = [[], []]
	var height: Array = [[], []]
	for i: int in SAMPLES + 1:
		player.seek(minf(i * dt, length), true)
		var h: Vector3 = _local(root, skeleton, hips)
		for f: int in 2:
			var p: Vector3 = _local(root, skeleton, feet[f]) - Vector3(h.x, 0.0, h.z)
			rel[f].append(p)
			height.append(p.y)
	var low: float = INF
	for f: int in 2:
		for p: Vector3 in rel[f]:
			low = minf(low, p.y)
	# Planted foot: within 4 cm of the lowest point; its velocity relative to the hips is the body's ground travel, reversed.
	var vel_sum: Vector3 = Vector3.ZERO
	var speeds: Array[float] = []
	for f: int in 2:
		for i: int in SAMPLES:
			var a: Vector3 = rel[f][i]
			var b: Vector3 = rel[f][i + 1]
			if a.y < low + 0.04 and b.y < low + 0.04:
				var v: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z) / dt
				vel_sum += v
				speeds.append(v.length())
	speeds.sort()
	var planted: int = speeds.size()
	var travel: Vector3 = -vel_sum / maxf(1.0, planted)
	var median: float = speeds[planted / 2] if planted > 0 else 0.0
	# Steps per cycle: planted-to-airborne transitions of both feet.
	var steps: int = 0
	for f: int in 2:
		var was_planted: bool = (rel[f][0] as Vector3).y < low + 0.04
		for i: int in range(1, SAMPLES):
			var is_planted: bool = (rel[f][i] as Vector3).y < low + 0.04
			if is_planted and not was_planted:
				steps += 1
			was_planted = is_planted
	# Loop closure: distance between the first and last pose of both feet (metres).
	var closure: float = 0.0
	for f: int in 2:
		closure = maxf(closure, ((rel[f][0] as Vector3) - (rel[f][SAMPLES] as Vector3)).length())
	print("%-14s len %.2fs | planted %d | median planted foot speed %.2f m/s | travel dir (x left, z fwd) (%.2f, %.2f) | foot landings per cycle %d | loop gap %.3f m" % [
		clip_name, length, planted, median, travel.x, travel.z, steps, closure])
