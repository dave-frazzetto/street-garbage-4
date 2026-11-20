extends Node3D
## Windowed visual check of the generated player and its pistol on an isolated night stage: close-up at a low angle
## (to tune the weapon in the hand), then the game camera. Saves PNGs to res://tests/output/. Run without --headless.

var model: PlayerModel


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
	env.ambient_light_energy = 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.85)
	moon.light_energy = 0.8
	moon.rotation_degrees = Vector3(-50, 30, 0)
	add_child(moon)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.light_color = Color(1, 0.62, 0.28)
	lamp.light_energy = 4.0
	lamp.omni_range = 10.0
	lamp.position = Vector3(1.5, 3.5, 1.5)
	add_child(lamp)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40, 40)
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


## Feeds the model like Player does: one update_motion call per physics frame for the given time.
func _drive(seconds: float, speed: float, firing: bool) -> void:
	var frames: int = int(seconds * Engine.physics_ticks_per_second)
	for i: int in frames:
		model.update_motion(speed, firing)
		await get_tree().physics_frame


func _run() -> void:
	model = (load("res://world/player/player_model.tscn") as PackedScene).instantiate() as PlayerModel
	add_child(model)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	# Close-up from the front-right, low angle, to see the pistol.
	cam.position = Vector3(2.2, 1.5, -3.2)
	cam.look_at(Vector3(0, 1.0, 0))
	await _drive(1.2, 0.0, false)
	await _shot("player_1_idle")
	cam.position = Vector3(-2.6, 1.3, -2.6)
	cam.look_at(Vector3(0, 1.1, -0.6))
	await _drive(0.8, 0.0, true)
	await _shot("player_2_stand_and_shoot")
	await _drive(0.6, 5.25, true)
	await _shot("player_2b_run_and_shoot")
	# Game camera angle.
	var rig: IsoCamera = (load("res://world/camera/iso_camera.tscn") as PackedScene).instantiate() as IsoCamera
	add_child(rig)
	rig.pitch_degrees = 50.0
	rig.distance = 9.0
	cam.current = false
	rig.get_node("Camera3D").current = true
	model.rotation.y = 0.6
	await _drive(0.5, 5.25, true)
	await _shot("player_3_game_angle")
	print("DONE player preview")
	get_tree().quit(0)
