extends Node3D
## Windowed visual check of the generated street lamp and traffic light on an isolated night stage
## (same environment values as the city). Saves PNGs to res://tests/output/. Run without --headless.


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	_build_stage()
	_run()


func _build_stage() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.36, 0.42)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.16, 0.18)
	ground.material_override = mat
	add_child(ground)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/output/%s.png" % file)
	print("saved ", file)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _place(path: String, at: Vector3, yaw: float) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	node.position = at
	node.rotation.y = yaw
	add_child(node)
	return node


func _run() -> void:
	_place("res://world/props/street_lamp.tscn", Vector3(-4, 0, 0), 0.0)
	_place("res://world/props/street_lamp.tscn", Vector3(9, 0, -6), PI)
	_place("res://world/props/traffic_light.tscn", Vector3(3, 0, 0), -3.0 * PI / 4.0)
	var z: Zombie = (load("res://world/enemies/zombie.tscn") as PackedScene).instantiate() as Zombie
	z.aggro_radius = 0.0
	z.position = Vector3(0, 0, 3)
	add_child(z)
	var rig: IsoCamera = (load("res://world/camera/iso_camera.tscn") as PackedScene).instantiate() as IsoCamera
	add_child(rig)
	rig.position = Vector3(2, 2, -1)
	rig.pitch_degrees = 48.0
	rig.distance = 13.0
	await _wait(1.0)
	await _shot("props_1_stage")
	rig.distance = 24.0
	await _wait(0.4)
	await _shot("props_2_game_distance")
	print("DONE props preview")
	get_tree().quit(0)
