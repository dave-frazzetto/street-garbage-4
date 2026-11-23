extends Node
## Frame-time benchmark of the real game (GameFlow: level, lights, HUD, desktop graphics profile). Run it WINDOWED (--no-warmup skips the shader warm-up, to compare):
##   Godot_v4.7.2-stable_win64_console.exe --path . res://tests/benchmark_fps.tscn [-- --elapsed=900 --vsync]
## The player is invulnerable and plays a scripted route (walk, sprint, stop and shoot) through the streets for
## `seconds_per_stage` at each run time in `stages`. Prints per stage: FPS, frame-time percentiles, worst frames and the
## split between scripts, physics and rendering, so a change can be compared before/after. Not part of run_tests.sh.

const FLOW: PackedScene = preload("res://core/game_flow.tscn")

## Run times (seconds into the 18 min run) to measure at; later stages have more zombies.
@export var stages: PackedFloat32Array = [30.0, 600.0, 1000.0]
@export_range(5, 120) var seconds_per_stage: float = 20.0
## Vsync off by default so the numbers show the real headroom, not the monitor's refresh rate.
@export var vsync: bool = false
## Stress: start next to the helicopter-crash horde and blow up a nearby car or barrel every few seconds.
@export var stress: bool = false
## Where the stress stage puts the player (next to the HelicopterCrash horde in freedom_city).
@export var stress_position: Vector3 = Vector3(92.0, 0.0, 38.5)

var _flow: GameFlow
var _frames: PackedFloat32Array = []
var _proc: float = 0.0
var _phys: float = 0.0
var _gpu: float = 0.0
var _cpu_render: float = 0.0
var _draws: float = 0.0
var _objects: float = 0.0
var _samples: int = 0
var _zombies_max: int = 0
var _nodes_max: int = 0
var _phys_steps: Dictionary = {}
var _last_phys: int = 0
var _hitches: Array[String] = []


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--elapsed="):
			stages = PackedFloat32Array([float(arg.get_slice("=", 1))])
		elif arg.begins_with("--seconds="):
			seconds_per_stage = float(arg.get_slice("=", 1))
		elif arg == "--vsync":
			vsync = true
		elif arg == "--stress":
			stress = true
		elif arg == "--no-warmup":
			ShaderWarmup._done = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	print("BENCH device=%s gpu=%s window=%s renderer=%s vsync=%s" % [OS.get_name(), RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size(), ProjectSettings.get_setting("rendering/renderer/rendering_method"), vsync])
	_flow = FLOW.instantiate() as GameFlow
	_flow.auto_start = false
	_flow.seed_value = 4242
	add_child(_flow)
	await get_tree().process_frame
	await get_tree().process_frame
	for elapsed: float in stages:
		await _run_stage(elapsed)
	print("BENCH DONE")
	get_tree().quit()


func _run_stage(elapsed: float) -> void:
	await _flow.start_run()
	await get_tree().process_frame
	_flow.run.elapsed = elapsed
	var player: Player = _flow.level.player
	player.health.max_health = 1.0e9
	player.health.current = 1.0e9
	player.input._set_device(PlayerInput.Device.GAMEPAD)
	if stress:
		player.global_position = stress_position
	# Warm-up: let the population around the start wake up and shaders compile before measuring.
	await _play(3.0, false)
	_reset()
	await _play(seconds_per_stage, true)
	_release_all()
	_report(elapsed)


## Scripted play: walk a while, sprint, stop and shoot in a circle, turn, repeat.
func _play(seconds: float, measure: bool) -> void:
	var dirs: Array[String] = ["move_right", "move_down", "move_left", "move_up"]
	var aims: Array[String] = ["aim_right", "aim_down", "aim_left", "aim_up"]
	var t: float = 0.0
	var leg: int = 0
	while t < seconds:
		var phase: float = fmod(t, 6.0)
		_release_all()
		if _flow.get_tree().paused:
			_flow.perk_select.skipped.emit()
		if phase < 3.0:
			Input.action_press(dirs[leg % 4])
			if phase > 1.5:
				Input.action_press("sprint")
		else:
			Input.action_press(aims[int(t * 2.0) % 4])
			Input.action_press("shoot")
		if phase >= 5.9:
			leg += 1
			if stress:
				_blow_up_nearest()
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		t += dt
		_flow.run.elapsed = maxf(_flow.run.elapsed, 0.0)
		if measure:
			_sample(dt)


func _blow_up_nearest() -> void:
	var at: Vector3 = _flow.level.player.global_position
	var best: Destructible = null
	var best_d: float = 30.0
	for node: Node in get_tree().root.find_children("*", "Destructible", true, false):
		var d: Destructible = node as Destructible
		var host: Node3D = d.get_parent() as Node3D
		if host == null or d.health <= 0.0:
			continue
		var dist: float = host.global_position.distance_to(at)
		if dist < best_d:
			best_d = dist
			best = d
	if best != null:
		best.take_damage(100000.0)


func _release_all() -> void:
	for a: String in ["move_left", "move_right", "move_up", "move_down", "aim_left", "aim_right", "aim_up", "aim_down", "shoot", "sprint"]:
		Input.action_release(a)


func _reset() -> void:
	_frames = PackedFloat32Array()
	_proc = 0.0
	_phys = 0.0
	_gpu = 0.0
	_cpu_render = 0.0
	_draws = 0.0
	_objects = 0.0
	_samples = 0
	_zombies_max = 0
	_nodes_max = 0
	_phys_steps = {}
	_last_phys = Engine.get_physics_frames()
	_hitches = []


func _sample(dt: float) -> void:
	var vp: RID = get_viewport().get_viewport_rid()
	_frames.append(dt * 1000.0)
	var steps: int = Engine.get_physics_frames() - _last_phys
	_last_phys = Engine.get_physics_frames()
	_phys_steps[steps] = int(_phys_steps.get(steps, 0)) + 1
	if dt > 0.05 and _hitches.size() < 12:
		_hitches.append("%.0fms@t=%.1f z=%d proc=%.0f phys=%.0f rcpu=%.0f rgpu=%.0f" % [dt * 1000.0, _flow.run.elapsed, get_tree().get_nodes_in_group(Zombie.GROUP).size(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp)])
	_proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	_cpu_render += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	_samples += 1
	_zombies_max = maxi(_zombies_max, get_tree().get_nodes_in_group(Zombie.GROUP).size())
	_nodes_max = maxi(_nodes_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))


func _report(elapsed: float) -> void:
	var sorted: PackedFloat32Array = _frames.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var total: float = 0.0
	var over_33: int = 0
	for f: float in _frames:
		total += f
		if f > 33.4:
			over_33 += 1
	var s: float = maxf(1.0, float(_samples))
	print("BENCH stage%s elapsed=%.0fs frames=%d avg_fps=%.1f | frame ms p50=%.1f p95=%.1f p99=%.1f max=%.1f | frames>33ms=%d (%.1f%%)" % [" STRESS" if stress else "", elapsed, n, 1000.0 * n / total, sorted[n / 2], sorted[int(n * 0.95)], sorted[int(n * 0.99)], sorted[n - 1], over_33, 100.0 * over_33 / n])
	print("BENCH   physics steps per frame %s | hitches>50ms %s" % [_phys_steps, _hitches])
	print("BENCH   avg ms: process=%.2f physics=%.2f render_cpu=%.2f render_gpu=%.2f | draw_calls=%.0f objects=%.0f | zombies_max=%d nodes_max=%d" % [_proc / s, _phys / s, _cpu_render / s, _gpu / s, _draws / s, _objects / s, _zombies_max, _nodes_max])
