@tool
extends SceneTree
## Renders generated models under neutral light into one contact sheet so a batch can be reviewed in engine (PBR maps,
## scale, orientation). Needs a window (rendering): godot --path . -s res://art/tools/model_sheet.gd -- out.png model.glb...
## Each model is framed by its bounding box and viewed from the front-right, a little above.

const CELL: int = 640
const COLUMNS: int = 3

var _models: Array[String] = []
var _out: String = "res://tests/output/model_sheet.png"
var _viewports: Array[SubViewport] = []


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0]
	for i: int in range(1, args.size()):
		_models.append(args[i])
	_run.call_deferred()


func _run() -> void:
	for path: String in _models:
		_viewports.append(_make_view(path))
	await _finish()


func _make_view(path: String) -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(CELL, CELL)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.19, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.65)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	view.add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.light_energy = 1.6
	view.add_child(sun)
	var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	view.add_child(model)
	var box: AABB = _bounds(model)
	var camera: Camera3D = Camera3D.new()
	view.add_child(camera)
	var centre: Vector3 = box.get_center()
	var reach: float = box.size.length() * 1.5
	camera.look_at_from_position(centre + Vector3(0.7, 0.45, 1.0).normalized() * reach, centre)
	camera.fov = 40.0
	return view


func _bounds(node: Node) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for mesh: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mesh as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _finish() -> void:
	for i: int in 4:
		await process_frame
	var rows: int = ceili(float(_viewports.size()) / COLUMNS)
	var sheet: Image = Image.create_empty(COLUMNS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	for i: int in _viewports.size():
		var img: Image = _viewports[i].get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % COLUMNS) * CELL, (i / COLUMNS) * CELL))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out).get_base_dir())
	sheet.save_png(ProjectSettings.globalize_path(_out))
	print("DONE model_sheet ", _out, " ", _viewports.size(), " models")
	quit()
