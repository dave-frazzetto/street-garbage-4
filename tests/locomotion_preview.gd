extends Node3D
## Windowed visual check of locomotion clips on the bare player rig: one contact sheet per clip (frames across one cycle) so
## direction, foot placement and loop seams can be judged by eye. Saves PNGs to res://tests/output/.
## Run: godot --path . --resolution 420x520 res://tests/locomotion_preview.tscn -- walk walk_back ...

const RIG: String = "res://art/models/characters/player/player_rigged.glb"
const CLIPS: String = "res://art/models/characters/player/clips/%s.res"
const FRAMES: int = 8

var _player: AnimationPlayer
var _skeleton: Skeleton3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.12, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	var grid: StandardMaterial3D = StandardMaterial3D.new()
	grid.albedo_color = Color(0.3, 0.3, 0.34)
	ground.material_override = grid
	add_child(ground)
	# A marker line along the character's forward (+z) so facing is obvious.
	var arrow: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.05, 0.01, 1.2)
	arrow.mesh = box
	arrow.position = Vector3(0, 0.01, 0.9)
	var red: StandardMaterial3D = StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.2, 0.2)
	arrow.material_override = red
	add_child(arrow)
	var rig: Node = (load(RIG) as PackedScene).instantiate()
	add_child(rig)
	_skeleton = rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_player = rig.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var cam: Camera3D = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.position = Vector3(2.6, 2.4, 3.4)
	cam.look_at(Vector3(0, 0.85, 0))
	_run()


func _run() -> void:
	var library: AnimationLibrary = AnimationLibrary.new()
	var names: PackedStringArray = OS.get_cmdline_user_args()
	for n: String in names:
		library.add_animation(n, load(CLIPS % n) as Animation)
	_player.add_animation_library(&"m", library)
	await get_tree().process_frame
	for n: String in names:
		var clip: Animation = _player.get_animation("m/" + n)
		_player.play("m/" + n)
		var sheet: Image = null
		for i: int in FRAMES:
			_player.seek(clip.length * i / FRAMES, true)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var frame: Image = get_viewport().get_texture().get_image()
			if sheet == null:
				sheet = Image.create(frame.get_width() * 4, frame.get_height() * 2, false, frame.get_format())
			sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i((i % 4) * frame.get_width(), (i / 4) * frame.get_height()))
		sheet.save_png("res://tests/output/loco_%s.png" % n)
		print("saved loco_", n)
	print("DONE locomotion preview")
	get_tree().quit()
