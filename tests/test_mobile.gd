extends TestCase
## Mobile start-up: tap-anywhere start with LOADING feedback, the mobile graphics profile (light budget, no shadows,
## glow or fog, lower 3D resolution) and the on-screen error console.

var flow: GameFlow


func _ready() -> void:
	flow = (load("res://core/game_flow.tscn") as PackedScene).instantiate() as GameFlow
	flow.seed_value = 3
	flow.force_mobile_graphics = true
	(flow.get_node("ErrorConsole") as ErrorConsole).always_enabled = true
	add_child(flow)
	run_all()


func test_1_tap_anywhere_starts_with_loading() -> void:
	check_eq(flow.graphics.display_name, "Mobile", "mobile profile picked")
	var ev: InputEventScreenTouch = InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = flow.get_viewport().get_final_transform() * Vector2(200, 150)
	Input.parse_input_event(ev)
	await get_tree().process_frame
	check(flow.title_screen.is_loading(), "tap shows LOADING")
	check(flow.level == null, "level not built yet (LOADING frame drawn first)")
	await wait_frames(6)
	check(flow.level != null and flow.level.player != null, "run started from a tap")
	var up: InputEventScreenTouch = ev.duplicate() as InputEventScreenTouch
	up.pressed = false
	Input.parse_input_event(up)


func test_2_mobile_graphics_applied() -> void:
	var p: GraphicsProfile = flow.graphics
	await wait_seconds(0.5)
	check(flow.level.static_lights_on() <= p.max_static_lights, "light budget (%d on, max %d)" % [flow.level.static_lights_on(), p.max_static_lights])
	check(flow.level.static_lights_on() > 0, "some lights still on")
	check(not (flow.level.get_node("Moon") as DirectionalLight3D).shadow_enabled, "no shadows")
	var env: Environment = (flow.level.get_node("WorldEnvironment") as WorldEnvironment).environment
	check(not env.glow_enabled and not env.fog_enabled, "no glow or fog")
	check_eq(flow.get_viewport().scaling_3d_scale, p.render_scale, "3D render scale")


func test_3_light_budget_follows_player() -> void:
	var lamp: Node3D = flow.level.get_node("Props").find_children("Lamp*", "", false, false)[0] as Node3D
	var light: Light3D = lamp.get_node("Light") as Light3D
	flow.level.player.global_position = lamp.global_position + Vector3(1.5, 0, 1.5)
	await wait_seconds(0.5)
	check(light.visible, "lamp next to the player is lit")


func test_4_error_console_shows_errors() -> void:
	var console: ErrorConsole = flow.get_node("ErrorConsole") as ErrorConsole
	var before: int = console.line_count()
	push_error("test error for the console")
	await wait_frames(2)
	check(console.line_count() > before, "error appears on screen")
