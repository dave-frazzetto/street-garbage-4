extends Node3D
## Windowed visual check of the GPU particle effects on a night stage with the city's glow setting. Saves PNGs to
## res://tests/output/. Run without --headless: godot --path . res://tests/vfx_preview.tscn --resolution 1280x720

const EXPLOSION: String = "res://world/effects/explosion_effect.tscn"

var _rig: IsoCamera


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
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.32, 0.36)
	ground.material_override = mat
	add_child(ground)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.9)
	moon.light_energy = 0.7
	moon.rotation_degrees = Vector3(-55, 30, 0)
	add_child(moon)
	var wall: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(10, 4, 0.5)
	wall.mesh = box
	wall.position = Vector3(0, 2, -4)
	wall.material_override = mat
	add_child(wall)
	_rig = (load("res://world/camera/iso_camera.tscn") as PackedScene).instantiate() as IsoCamera
	add_child(_rig)
	_rig.pitch_degrees = 48.0


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/output/%s.png" % file)
	print("saved ", file)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _spawn(path: String, at: Vector3, dir: Vector3 = Vector3.ZERO) -> Node3D:
	var fx: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	fx.position = at
	if fx is VfxBurst and dir != Vector3.ZERO:
		(fx as VfxBurst).aim(dir)
	add_child(fx)
	return fx


func _run() -> void:
	_rig.position = Vector3(0, 1, 0)
	_rig.distance = 14.0
	await _wait(1.0)
	_spawn(EXPLOSION, Vector3(0, 0, 0))
	await _wait(0.12)
	await _shot("vfx_1_explosion_early")
	await _wait(0.25)
	await _shot("vfx_2_explosion_mid")
	await _wait(0.6)
	await _shot("vfx_3_explosion_late")
	await _wait(1.5)
	# Fires, blood and hits side by side.
	_rig.position = Vector3(2, 1, 0)
	_rig.distance = 12.0
	_spawn("res://world/effects/flame_effect.tscn", Vector3(-3, 0, 0))
	_spawn("res://world/effects/flame_effect.tscn", Vector3(0.5, 0, 0)).scale = Vector3(1.4, 1.4, 1.4)
	_spawn("res://world/effects/blood_burst.tscn", Vector3(4, 0.8, 0))
	_spawn("res://world/effects/blood_hit.tscn", Vector3(6, 0.8, 0), Vector3(-1, 0.3, 0.5))
	_spawn("res://world/effects/impact_effect.tscn", Vector3(8, 0.8, 0))
	await _wait(0.2)
	await _shot("vfx_4_misc_early")
	await _wait(1.5)
	await _shot("vfx_5_fire_steady")
	print("DONE vfx preview")
	get_tree().quit(0)
