extends Node3D
## Windowed visual check of directional locomotion on the real PlayerModel: the aim is fixed to the right (+X) while the
## player moves in eight world directions at run speed, as the twin-stick controls allow. One contact sheet per frame
## time, saved to res://tests/output/ (dirs_a.png = 0.0 s into the cycle, dirs_b.png = a quarter second later).
## Run: godot --path . --resolution 360x460 res://tests/player_directions_preview.tscn

const SPEED: float = 4.4
## Name and world velocity direction of every shot. The body faces +X, so +X is forward, -X backward, -Z left, +Z right.
const SHOTS: Array = [
	["forward", Vector3(1, 0, 0)], ["forward-left", Vector3(1, 0, -1)], ["left", Vector3(0, 0, -1)], ["back-left", Vector3(-1, 0, -1)],
	["backward", Vector3(-1, 0, 0)], ["back-right", Vector3(-1, 0, 1)], ["right", Vector3(0, 0, 1)], ["forward-right", Vector3(1, 0, 1)],
]

var _model: PlayerModel


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.66)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var grey: StandardMaterial3D = StandardMaterial3D.new()
	grey.albedo_color = Color(0.3, 0.3, 0.34)
	ground.material_override = grey
	add_child(ground)
	# Red bar: where she aims. Yellow bar: where she moves.
	add_child(_bar(Vector3(1.2, 0.01, 0), Vector3(1.6, 0.01, 0.05), Color(0.9, 0.2, 0.2)))
	_model = (load("res://world/player/player_model.tscn") as PackedScene).instantiate() as PlayerModel
	add_child(_model)
	_model.rotation.y = atan2(-1.0, 0.0)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.position = Vector3(0.4, 3.0, 4.6)
	cam.look_at(Vector3(0.2, 0.9, 0))
	_run()


func _bar(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var bar: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	bar.mesh = box
	bar.position = at
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	bar.material_override = mat
	return bar


func _drive(seconds: float, velocity: Vector3) -> void:
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		_model.update_motion(velocity, false)
		await get_tree().physics_frame


func _run() -> void:
	await _drive(0.5, Vector3.ZERO)
	var sheets: Array[Image] = [null, null]
	for index: int in SHOTS.size():
		var velocity: Vector3 = (SHOTS[index][1] as Vector3).normalized() * SPEED
		await _drive(0.2, Vector3.ZERO)
		await _drive(1.2, velocity)
		var marker: MeshInstance3D = _bar(velocity.normalized() * 0.9 + Vector3(0, 0.02, 0), Vector3(0.06, 0.01, 0.06), Color(1, 0.9, 0.1))
		marker.scale = Vector3(1, 1, 1)
		add_child(marker)
		for frame: int in 2:
			await _drive(0.0 if frame == 0 else 0.25, velocity)
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			if sheets[frame] == null:
				sheets[frame] = Image.create(image.get_width() * 4, image.get_height() * 2, false, image.get_format())
			sheets[frame].blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((index % 4) * image.get_width(), (index / 4) * image.get_height()))
		marker.queue_free()
		print("shot ", SHOTS[index][0], " direction ", _model.move_direction())
	sheets[0].save_png("res://tests/output/dirs_a.png")
	sheets[1].save_png("res://tests/output/dirs_b.png")
	print("DONE player directions preview")
	get_tree().quit()
