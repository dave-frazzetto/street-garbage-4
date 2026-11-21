@tool
extends SceneTree
## Saves animation clips out of generated (Meshy) GLBs as small Animation resources, so a character ships one GLB with the
## mesh and texture plus tiny clip files instead of one full GLB per animation.
## Run: godot --headless --path . -s res://art/tools/extract_clips.gd
## Add a row per new character. Each row: source GLB, clip name inside the GLB, output name, loops.

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
]


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_player(child)
		if found != null:
			return found
	return null


func _init() -> void:
	var failures: int = 0
	for job: Dictionary in JOBS:
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
		DirAccess.make_dir_recursive_absolute(String(job["out"]).get_base_dir())
		var err: int = ResourceSaver.save(clip, job["out"])
		print("saved ", job["out"], " (", clip.length, " s, err ", err, ")")
		failures += 1 if err != OK else 0
		instance.free()
	print("DONE extract_clips failures=", failures)
	quit(1 if failures > 0 else 0)
