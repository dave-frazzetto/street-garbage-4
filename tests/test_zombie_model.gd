extends TestCase
## Generated zombie model: the merged clips exist and loop correctly, attack and death play, and a dead zombie
## leaves its model behind as a corpse that is cleaned up afterwards.

var root: Node3D


func _ready() -> void:
	root = Node3D.new()
	add_child(root)
	run_all()


func _spawn(data_path: String) -> Zombie:
	var zombie: Zombie = (load("res://world/enemies/zombie.tscn") as PackedScene).instantiate() as Zombie
	zombie.data = load(data_path) as EnemyData
	zombie.corpse_linger = 0.3
	root.add_child(zombie)
	return zombie


func _player_of(node: Node) -> AnimationPlayer:
	for child: Node in node.find_children("*", "AnimationPlayer", true, false):
		return child as AnimationPlayer
	return null


func test_1_clips_are_merged() -> void:
	var zombie: Zombie = _spawn("res://data/enemies/walker.tres")
	await wait_frames(2)
	var player: AnimationPlayer = _player_of(zombie)
	check(player != null, "model has an AnimationPlayer")
	for clip: StringName in [&"walk", &"run", &"attack", &"die"]:
		check(player.has_animation(clip), "clip '%s' present" % clip)
	check_eq(player.get_animation(&"walk").loop_mode, Animation.LOOP_LINEAR, "walk loops")
	check_eq(player.get_animation(&"run").loop_mode, Animation.LOOP_LINEAR, "run loops")
	check_eq(player.get_animation(&"attack").loop_mode, Animation.LOOP_NONE, "attack does not loop")
	check_eq(player.get_animation(&"die").loop_mode, Animation.LOOP_NONE, "die does not loop")
	zombie.queue_free()


func test_2_model_is_a_human_sized_character() -> void:
	var zombie: Zombie = _spawn("res://data/enemies/walker.tres")
	await wait_frames(2)
	var top: float = 0.0
	for mesh: Node in zombie.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mesh as MeshInstance3D
		var aabb: AABB = m.global_transform * m.get_aabb()
		top = maxf(top, aabb.end.y)
	check(top > 1.5 and top < 2.2, "model height %.2f m is about 1.8 m" % top)
	zombie.queue_free()


func test_3_moving_plays_walk_and_contact_plays_attack() -> void:
	var zombie: Zombie = _spawn("res://data/enemies/walker.tres")
	var target: Node3D = Node3D.new()
	root.add_child(target)
	target.global_position = Vector3(0, 0, -6)
	zombie.target = target
	await wait_frames(6)
	var player: AnimationPlayer = _player_of(zombie)
	check_eq(player.current_animation, "walk", "chasing zombie walks")
	check(player.is_playing(), "walk is playing")
	target.global_position = Vector3(0, 0, -0.6)
	await wait_frames(12)
	check_eq(player.current_animation, "attack", "zombie in contact plays attack")
	target.queue_free()
	zombie.queue_free()


func test_4_death_leaves_a_corpse_then_cleans_up() -> void:
	var zombie: Zombie = _spawn("res://data/enemies/armoured.tres")
	await wait_frames(2)
	var model: ZombieModel = zombie.get_node("Visual/Model") as ZombieModel
	var visual: Node3D = zombie.get_node("Visual") as Node3D
	check(model.get_node("Facing/Model") != null, "model instance present")
	var died: Array = []
	zombie.died.connect(func(_z: Zombie, xp: float, _at: Vector3) -> void: died.append(xp))
	zombie.take_damage(100000.0)
	await wait_frames(2)
	check_eq(died.size(), 1, "died signal emitted once")
	check(not is_instance_valid(zombie) or zombie.is_queued_for_deletion(), "zombie node is gone")
	check(is_instance_valid(visual), "corpse visual survives the zombie")
	check(visual.get_parent() == root, "corpse handed to the zombie's parent")
	var player: AnimationPlayer = _player_of(visual)
	check_eq(player.current_animation, "die", "corpse plays the death clip")
	var corpse_mesh: MeshInstance3D = visual.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	check((corpse_mesh.material_overlay as StandardMaterial3D).albedo_color.a < 0.5, "corpse is not stuck in the hit flash")
	var length: float = player.get_animation(&"die").length
	await wait_seconds(length + 0.8)
	check(not is_instance_valid(visual), "corpse removed after it lingers")


func test_5_tint_is_applied_for_variants() -> void:
	var tinted: EnemyData = (load("res://data/enemies/walker.tres") as EnemyData).duplicate() as EnemyData
	tinted.tint = Color(0.35, 0.5, 0.75, 0.35)
	var zombie: Zombie = (load("res://world/enemies/zombie.tscn") as PackedScene).instantiate() as Zombie
	zombie.data = tinted
	root.add_child(zombie)
	await wait_frames(2)
	var mesh: MeshInstance3D = zombie.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var overlay: StandardMaterial3D = mesh.material_overlay as StandardMaterial3D
	check(overlay != null, "overlay material set")
	check(overlay.albedo_color.a > 0.0, "a variant with a tint is tinted")
	zombie.take_damage(1.0)
	check_eq(overlay.albedo_color.r, 1.0, "hit flash is white")
	await wait_seconds(0.2)
	check(overlay.albedo_color.a < 0.75, "flash cleared back to tint")
	zombie.queue_free()


func test_6_zombie_types_use_their_own_model() -> void:
	var walker: Zombie = _spawn("res://data/enemies/walker.tres")
	var armoured: Zombie = _spawn("res://data/enemies/armoured.tres")
	await wait_frames(2)
	var armoured_model: Node = armoured.get_node("Visual/Model")
	check_eq(armoured_model.scene_file_path, "res://world/enemies/zombie_armoured_model.tscn", "armoured zombie shows its own model")
	check_eq(walker.get_node("Visual/Model").scene_file_path, "res://world/enemies/zombie_model.tscn", "walker keeps the walker model")
	check(armoured_model is ZombieModel, "swapped model is a ZombieModel")
	var player: AnimationPlayer = _player_of(armoured)
	for clip: StringName in [&"walk", &"run", &"attack", &"die"]:
		check(player.has_animation(clip), "armoured clip '%s' present" % clip)
	check_eq(armoured.get_node("Visual").scale, Vector3.ONE, "own-model zombies are not stretched by radius")
	walker.queue_free()
	armoured.queue_free()
