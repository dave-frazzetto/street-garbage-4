extends Node
## Windowed visual check of the generated zombie model from the game camera. Saves PNGs to res://tests/output/.
## Run without --headless.

var flow: GameFlow


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	flow = (load("res://core/game_flow.tscn") as PackedScene).instantiate() as GameFlow
	flow.seed_value = 7
	add_child(flow)
	_run()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/output/%s.png" % file)
	print("saved ", file)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _spawn(path: String, at: Vector3) -> Zombie:
	var z: Zombie = (load("res://world/enemies/zombie.tscn") as PackedScene).instantiate() as Zombie
	z.setup(load(path) as EnemyData, flow.level.player, 0.0)
	z.position = at
	flow.level.entities.add_child(z)
	flow.level._on_zombie_spawned(z)
	return z


func _run() -> void:
	await _wait(0.5)
	flow.start_run()
	await _wait(0.3)
	var p: Player = flow.level.player
	p.health.max_health = 100000.0
	p.health.current = 100000.0
	p.global_position = Vector3(60.0, 0, 70.0)
	flow.level.camera_rig.snap()
	for z: Node in get_tree().get_nodes_in_group(Zombie.GROUP):
		z.queue_free()
	await _wait(0.2)
	var c: Vector3 = p.global_position
	var fwd: Vector3 = flow.level.camera_rig.view_forward()
	var right: Vector3 = flow.level.camera_rig.view_right()
	var a: Zombie = _spawn("res://data/enemies/walker.tres", c + fwd * 2.0 - right * 2.2)
	var b: Zombie = _spawn("res://data/enemies/walker.tres", c + fwd * 2.5 + right * 2.2)
	var armoured: Zombie = _spawn("res://data/enemies/armoured.tres", c + fwd * 5.0)
	for z: Zombie in [a, b, armoured]:
		z.aggro_radius = 0.0
	await _wait(1.2)
	await _shot("zombie_1_walking")
	await _wait(1.5)
	await _shot("zombie_2_game_view")
	flow.level.camera_rig.distance = 12.0
	await _wait(0.3)
	await _shot("zombie_2_close")
	a.take_damage(100000.0)
	await _wait(0.6)
	await _shot("zombie_3_dying")
	print("DONE zombie preview")
	get_tree().quit(0)
