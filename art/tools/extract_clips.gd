@tool
extends SceneTree
## Saves animation clips out of generated (Meshy) GLBs as small Animation resources, so a character ships one GLB with the
## mesh and texture plus tiny clip files instead of one full GLB per animation.
## Run: godot --headless --path . -s res://art/tools/extract_clips.gd
## Add a row per new character. Each row: source GLB, clip name inside the GLB, output name, loops.
## "strip_root": true removes the horizontal travel of the Hips (Meshy text-to-motion clips walk away from the origin); the
## measured ground speed and direction are printed so they can be copied into the LocomotionProfile.
## A row whose source GLB is no longer in the project (Meshy tasks expire, sources are not committed) is skipped when its
## output already exists.

const JOBS: Array[Dictionary] = [
	{"glb": "res://art/models/enemies/zombie_walker/zombie_walker_walk.glb", "clip": "Armature|walking_man|baselayer", "out": "res://art/models/enemies/zombie_walker/clips/walk.res", "loop": true},
	{"glb": "res://art/models/enemies/zombie_walker/zombie_walker_run.glb", "clip": "Armature|running|baselayer", "out": "res://art/models/enemies/zombie_walker/clips/run.res", "loop": true},
	{"glb": "res://art/models/enemies/zombie_walker/zombie_walker_actions.glb", "clip": "Attack", "out": "res://art/models/enemies/zombie_walker/clips/attack.res", "loop": false},
	{"glb": "res://art/models/enemies/zombie_walker/zombie_walker_actions.glb", "clip": "dying_backwards", "out": "res://art/models/enemies/zombie_walker/clips/die.res", "loop": false},
	{"glb": "res://art/models/enemies/zombie_armoured/zombie_armoured_walk.glb", "clip": "Armature|walking_man|baselayer", "out": "res://art/models/enemies/zombie_armoured/clips/walk.res", "loop": true},
	{"glb": "res://art/models/enemies/zombie_armoured/zombie_armoured_run.glb", "clip": "Armature|running|baselayer", "out": "res://art/models/enemies/zombie_armoured/clips/run.res", "loop": true},
	{"glb": "res://art/models/enemies/zombie_armoured/zombie_armoured_actions.glb", "clip": "Attack", "out": "res://art/models/enemies/zombie_armoured/clips/attack.res", "loop": false},
	{"glb": "res://art/models/enemies/zombie_armoured/zombie_armoured_actions.glb", "clip": "dying_backwards", "out": "res://art/models/enemies/zombie_armoured/clips/die.res", "loop": false},
	{"glb": "res://art/models/characters/player/player_walk.glb", "clip": "Armature|walking_man|baselayer", "out": "res://art/models/characters/player/clips/walk.res", "loop": true},
	{"glb": "res://art/models/characters/player/player_run.glb", "clip": "Armature|running|baselayer", "out": "res://art/models/characters/player/clips/run.res", "loop": true},
	{"glb": "res://art/models/characters/player/player_actions.glb", "clip": "Idle", "out": "res://art/models/characters/player/clips/idle.res", "loop": true},
	{"glb": "res://art/models/characters/player/player_actions.glb", "clip": "Run_and_Shoot", "out": "res://art/models/characters/player/clips/run_and_shoot.res", "loop": true},
	{"glb": "res://art/models/characters/player/player_actions.glb", "clip": "dying_backwards", "out": "res://art/models/characters/player/clips/die.res", "loop": false},
	{"glb": "res://art/models/characters/player/player_dirs.glb", "clip": "Walk_Backward_inplace", "out": "res://art/models/characters/player/clips/walk_back.res", "loop": true},
	{"glb": "res://art/models/characters/player/player_walk_left.glb", "clip": "retarget_clip", "out": "res://art/models/characters/player/clips/walk_left.res", "loop": true, "strip_root": true},
	{"glb": "res://art/models/characters/player/player_walk_right.glb", "clip": "retarget_clip", "out": "res://art/models/characters/player/clips/walk_right.res", "loop": true, "strip_root": true},
	{"glb": "res://art/models/characters/player/player_run_back.glb", "clip": "retarget_clip", "out": "res://art/models/characters/player/clips/run_back.res", "loop": true, "strip_root": true},
	{"glb": "res://art/models/characters/player/player_run_left.glb", "clip": "retarget_clip", "out": "res://art/models/characters/player/clips/run_left.res", "loop": true, "strip_root": true},
	{"glb": "res://art/models/characters/player/player_run_right.glb", "clip": "retarget_clip", "out": "res://art/models/characters/player/clips/run_right.res", "loop": true, "strip_root": true},
]


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_player(child)
		if found != null:
			return found
	return null


## Keeps the Hips height but pins its horizontal position, and prints how fast and which way the clip travelled
## (skeleton units are centimetres; the direction is in the rig's frame: +z forward, +x the character's left).
func _strip_root(clip: Animation, label: String) -> void:
	for t: int in clip.get_track_count():
		if clip.track_get_type(t) != Animation.TYPE_POSITION_3D or not String(clip.track_get_path(t)).ends_with(":Hips"):
			continue
		var count: int = clip.track_get_key_count(t)
		var first: Vector3 = clip.track_get_key_value(t, 0)
		var last: Vector3 = clip.track_get_key_value(t, count - 1)
		var span: float = clip.track_get_key_time(t, count - 1) - clip.track_get_key_time(t, 0)
		var travel: Vector3 = (last - first) * 0.01
		var velocity: Vector2 = Vector2(travel.x, travel.z) / maxf(span, 0.001)
		print("  root travel of ", label.get_file(), ": ", snappedf(velocity.length(), 0.01), " m/s, direction (x ", snappedf(velocity.x, 0.01), ", z ", snappedf(velocity.y, 0.01), ")")
		for k: int in count:
			var p: Vector3 = clip.track_get_key_value(t, k)
			clip.track_set_key_value(t, k, Vector3(first.x, p.y, first.z))
		return


func _init() -> void:
	var failures: int = 0
	for job: Dictionary in JOBS:
		if not ResourceLoader.exists(job["glb"]) and ResourceLoader.exists(job["out"]):
			print("skip ", job["out"], " (source GLB gone, output kept)")
			continue
		var scene: PackedScene = load(job["glb"]) as PackedScene
		if scene == null:
			printerr("missing ", job["glb"])
			failures += 1
			continue
		var instance: Node = scene.instantiate()
		var player: AnimationPlayer = _find_player(instance)
		if player == null or not player.has_animation(job["clip"]):
			printerr("no clip ", job["clip"], " in ", job["glb"])
			failures += 1
			instance.free()
			continue
		var clip: Animation = player.get_animation(job["clip"]).duplicate() as Animation
		clip.loop_mode = Animation.LOOP_LINEAR if job["loop"] else Animation.LOOP_NONE
		if job.get("strip_root", false):
			_strip_root(clip, String(job["out"]))
		DirAccess.make_dir_recursive_absolute(String(job["out"]).get_base_dir())
		var err: int = ResourceSaver.save(clip, job["out"])
		print("saved ", job["out"], " (", clip.length, " s, err ", err, ")")
		failures += 1 if err != OK else 0
		instance.free()
	print("DONE extract_clips failures=", failures)
	quit(1 if failures > 0 else 0)
