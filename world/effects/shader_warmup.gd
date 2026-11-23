class_name ShaderWarmup
extends Node3D
## Prepares everything the run will draw for the first time, behind the loading screen, so the first shot, kill, blood
## splat, explosion or new street does not freeze the game for 50-130 ms (shader compiles on the Compatibility renderer,
## the procedural blood-splat textures, the car's burning and wreck looks). While the tree is paused it:
## 1. shows each scene in `live_scenes` (scripts running, as in play) and `static_scenes` (scripts stripped: they need
##    setup calls) in front of the gameplay camera, with every particle system forced on;
## 2. destroys every destructible among them, so burning and wreck looks are drawn too;
## 3. renders the whole level for a few frames from an overview camera, so every building and prop material is drawn.
## Shaders stay compiled for the rest of the launch, so only the first run of a session warms up. Skipped headless.
## The level calls warm(); without a camera it does nothing.

signal finished

## Scenes spawned during play whose scripts work on their own (effects, blood splat, props, zombie models).
@export var live_scenes: Array[PackedScene] = []
## Scenes whose scripts expect setup calls (bullet, pickups) or have none (weapon models): only their looks are drawn.
@export var static_scenes: Array[PackedScene] = []
## Frames each step is drawn for. Particles need a couple of frames to emit and draw.
@export_range(1, 30) var frames_per_step: int = 3
## Distance in front of the gameplay camera where the warm-up scenes are shown.
@export_range(1.0, 50.0, 0.5) var show_distance: float = 12.0
## Height of the overview camera above the level, in metres.
@export_range(10.0, 500.0, 5.0) var overview_height: float = 150.0

static var _done: bool = false
var _warming: bool = false
var _restore_pause: bool = false


## True once this launch has warmed up (later runs skip it).
static func is_done() -> bool:
	return _done


## Pauses the tree, draws everything once and resumes; emits `finished`. Await it before revealing the game.
func warm(camera: Camera3D, level_bounds: Rect2) -> void:
	if _done or camera == null or DisplayServer.get_name() == "headless":
		_done = true
		finished.emit.call_deferred()
		return
	_done = true
	var tree: SceneTree = get_tree()
	_restore_pause = tree.paused
	_warming = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	tree.paused = true
	var shown: Array[Node3D] = _show_scenes(camera)
	await _frames(frames_per_step)
	_destroy_props(shown)
	await _frames(frames_per_step)
	var overview: Camera3D = _overview_camera(level_bounds)
	add_child(overview)
	overview.make_current()
	var centre: Vector2 = level_bounds.get_center()
	for i: int in shown.size():
		# Also drawn inside the overview, so effects meet the whole-map lighting setup too.
		if is_instance_valid(shown[i]):
			shown[i].global_position = Vector3(centre.x + float(i % 6) * 2.0, 0.5, centre.y + float(i / 6) * 2.0)
	await _frames(frames_per_step)
	camera.make_current()
	overview.queue_free()
	for node: Node3D in shown:
		if is_instance_valid(node):
			node.queue_free()
	await _frames(1)
	_warming = false
	tree.paused = _restore_pause
	finished.emit()


func _exit_tree() -> void:
	# Freed mid-warm-up (the level was replaced): never leave the game paused.
	if _warming:
		_warming = false
		get_tree().paused = _restore_pause


func _show_scenes(camera: Camera3D) -> Array[Node3D]:
	var shown: Array[Node3D] = []
	var basis: Basis = camera.global_transform.basis
	var centre: Vector3 = camera.global_position - basis.z * show_distance
	var entries: Array[Array] = []
	for scene: PackedScene in live_scenes:
		entries.append([scene, false])
	for scene: PackedScene in static_scenes:
		entries.append([scene, true])
	for i: int in entries.size():
		var scene: PackedScene = entries[i][0] as PackedScene
		if scene == null:
			continue
		var node: Node = scene.instantiate()
		if bool(entries[i][1]):
			_strip_scripts(node)
		var spot: Node3D = node as Node3D
		if spot == null:
			node.free()
			continue
		add_child(spot)
		var col: float = float(i % 6) - 2.5
		var row: float = float(i / 6) - 1.0
		spot.global_position = centre + basis.x * col * 1.6 + basis.y * row * 1.6
		_force_particles(spot)
		shown.append(spot)
	return shown


## Removes every script below `node` (only its meshes, materials and particles are wanted).
func _strip_scripts(node: Node) -> void:
	node.set_script(null)
	for child: Node in node.get_children():
		_strip_scripts(child)


func _force_particles(node: Node) -> void:
	var found: Array[Node] = node.find_children("*", "GPUParticles3D", true, false)
	if node is GPUParticles3D:
		found.append(node)
	for p: Node in found:
		var particles: GPUParticles3D = p as GPUParticles3D
		particles.emitting = true
		particles.restart()


## Wrecks every destructible prop among the warm-up scenes (not connected to the level, so nothing is hurt).
func _destroy_props(shown: Array[Node3D]) -> void:
	for node: Node3D in shown:
		if not is_instance_valid(node):
			continue
		for d: Node in node.find_children("*", "Destructible", true, false):
			(d as Destructible).take_damage(1.0e9)
		_force_particles(node)


func _overview_camera(level_bounds: Rect2) -> Camera3D:
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(level_bounds.size.x, level_bounds.size.y) * 1.1
	cam.far = overview_height * 2.0
	var c: Vector2 = level_bounds.get_center()
	cam.transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)), Vector3(c.x, overview_height, c.y))
	return cam


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
