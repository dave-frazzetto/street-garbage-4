extends TestCase
## World dressing: fences close the whole perimeter (physics rays from inside, from the street ends and from inside the
## buildings that run to the edge, hit a Fence at the bounds), zombies and
## the player collide with them, and the ground and skyline backdrop extend far enough beyond the bounds that the
## camera can never see the end of the map.

## How far past the bounds the camera can see at its extreme positions (generous; measured from screenshots).
const VISIBLE_MARGIN: float = 80.0

var level: Level


func _ready() -> void:
	level = (load("res://world/levels/freedom_city.tscn") as PackedScene).instantiate() as Level
	add_child(level)
	run_all()


func test_1_fences_close_the_perimeter() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fences: Node3D = level.get_node("Fences")
	check(fences.get_child_count() >= 4, "at least four fence runs")
	for child: Node in fences.get_children():
		var fence: Fence = child as Fence
		check(fence != null and (fence.collision_layer & 1) != 0, "%s is a Fence on the world layer" % child.name)
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var b: Rect2 = level.bounds
	var misses: int = 0
	var total: int = 0
	for height: float in [0.5, 1.5, 3.0]:
		for t: float in range(2, 119, 4):
			var inside: Array[Vector2] = [Vector2(b.position.x + t, b.position.y + 3.0), Vector2(b.position.x + t, b.end.y - 3.0), Vector2(b.position.x + 3.0, b.position.y + t), Vector2(b.end.x - 3.0, b.position.y + t)]
			var outside: Array[Vector2] = [Vector2(inside[0].x, b.position.y - 6.0), Vector2(inside[1].x, b.end.y + 6.0), Vector2(b.position.x - 6.0, inside[2].y), Vector2(b.end.x + 6.0, inside[3].y)]
			for k: int in 4:
				total += 1
				var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(inside[k].x, height, inside[k].y), Vector3(outside[k].x, height, outside[k].y), 1)
				var hit: Dictionary = space.intersect_ray(query)
				if not hit.is_empty() and not (hit["collider"] is Fence) and (hit["position"] as Vector3).distance_to(query.from) < 0.05:
					# Starts on the shared wall of two buildings that run to the edge: solid, nothing can escape from here.
					total -= 1
					continue
				# Props in front of the fence (the barricade lines closing the street ends) are looked through: a fence
				# must still stand behind them.
				var exclude: Array[RID] = []
				while not hit.is_empty() and not (hit["collider"] is Fence) and not (hit["collider"] is Building) and exclude.size() < 4:
					exclude.append((hit["collider"] as CollisionObject3D).get_rid())
					query.exclude = exclude
					hit = space.intersect_ray(query)
				if hit.is_empty() or not (hit["collider"] is Fence):
					misses += 1
					continue
				var p: Vector3 = hit["position"]
				var off: float = minf(minf(absf(p.x - b.position.x), absf(p.x - b.end.x)), minf(absf(p.z - b.position.y), absf(p.z - b.end.y)))
				if off > 0.6:
					misses += 1
	check_eq(misses, 0, "rays that escape or hit something other than a fence at the bounds (of %d)" % total)


func test_2_actors_collide_with_fences() -> void:
	var player_body: CharacterBody3D = (load("res://world/player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	var zombie_body: CharacterBody3D = (load("res://world/enemies/zombie.tscn") as PackedScene).instantiate() as CharacterBody3D
	check((player_body.collision_mask & 1) != 0, "player collides with the world layer")
	check((zombie_body.collision_mask & 1) != 0, "zombies collide with the world layer")
	player_body.free()
	zombie_body.free()


func test_3_ground_extends_past_the_camera_view() -> void:
	var ground: Ground = level.get_node("Ground") as Ground
	var mesh: PlaneMesh = (ground.get_node("Mesh") as MeshInstance3D).mesh as PlaneMesh
	var b: Rect2 = level.bounds
	var rect: Rect2 = Rect2(ground.global_position.x - mesh.size.x / 2.0, ground.global_position.z - mesh.size.y / 2.0, mesh.size.x, mesh.size.y)
	check(rect.encloses(b.grow(VISIBLE_MARGIN)), "ground plane covers bounds + %d m (plane %s)" % [int(VISIBLE_MARGIN), str(rect)])


func test_4_backdrop_fills_beyond_the_fences() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var backdrop: CityBackdrop = level.get_node("CityBackdrop") as CityBackdrop
	check(backdrop.building_count() > 100, "backdrop has buildings (%d)" % backdrop.building_count())
	check(float(backdrop.rings) * backdrop.block_spacing >= VISIBLE_MARGIN, "backdrop rings reach the visible margin")
	var b: Rect2 = level.bounds
	var bad: int = 0
	var too_tall: int = 0
	var reach: float = 0.0
	for f: Dictionary in backdrop.footprints():
		var rect: Rect2 = f["rect"]
		if rect.intersects(b):
			bad += 1
		var gap: float = CityBackdrop._distance_to_rect(rect, b)
		reach = maxf(reach, gap)
		if float(f["height"]) > maxf(backdrop.min_height, gap * backdrop.height_per_metre) + 0.01:
			too_tall += 1
	check_eq(bad, 0, "backdrop buildings inside the playable area")
	check_eq(too_tall, 0, "backdrop buildings taller than the camera sight-line limit")
	check(reach >= VISIBLE_MARGIN - 10.0, "backdrop extends to %d m" % int(reach))
	var camera: IsoCamera = level.camera_rig
	check(backdrop.height_per_metre <= tan(deg_to_rad(camera.pitch_degrees)) + 0.01, "height limit within tan(camera pitch)")


func test_5_graphics_profile_switches_ground_detail() -> void:
	var ground: Ground = level.get_node("Ground") as Ground
	var mat: ShaderMaterial = (ground.get_node("Mesh") as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial
	level.apply_graphics(load("res://data/config/graphics_mobile.tres") as GraphicsProfile)
	check(not ground.detailed and mat.get_shader_parameter("detailed") == false, "mobile profile drops ground detail")
	level.apply_graphics(load("res://data/config/graphics_desktop.tres") as GraphicsProfile)
	check(ground.detailed and mat.get_shader_parameter("detailed") == true, "desktop profile keeps ground detail")
