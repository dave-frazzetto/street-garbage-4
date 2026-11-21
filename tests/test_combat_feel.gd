extends TestCase
## Combat feel (slice 8): firing slows the player, bullets are forgiving near zombies but walls still block,
## and the bullet draws a beam that fades after impact.

var projectiles: Node3D
var pistol: WeaponData


func _ready() -> void:
	projectiles = Node3D.new()
	add_child(projectiles)
	pistol = load("res://data/weapons/pistol.tres") as WeaponData
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.0, 3.0, 8.0)
	cs.shape = box
	floor_body.add_child(cs)
	floor_body.position = Vector3(100, 1.5, 0)  # wall at x=100, blocks along x
	add_child(floor_body)
	run_all()


func _spawn_zombie(at: Vector3, data: EnemyData = null) -> Zombie:
	var z: Zombie = (load("res://world/enemies/zombie.tscn") as PackedScene).instantiate() as Zombie
	if data != null:
		z.setup(data, null, 0.0)
	z.position = at
	add_child(z)
	return z


func _shoot(from: Vector3, dir: Vector3, range_m: float = 12.0) -> Bullet:
	var b: Bullet = (load("res://world/projectiles/bullet.tscn") as PackedScene).instantiate() as Bullet
	b.setup(from, dir, pistol, 5.0, range_m, 0, 0.0)
	projectiles.add_child(b)
	return b


func test_1_firing_speed_stat() -> void:
	var cfg: PlayerConfig = PlayerConfig.new()
	check_eq(cfg.firing_move_multiplier, 0.0, "default firing multiplier")
	var stats: PlayerStats = PlayerStats.new(cfg)
	check_eq(stats.get_value(PlayerStats.Stat.FIRING_MOVE_SPEED), 0.0, "stat carries multiplier")


func test_2_player_moves_slower_while_firing() -> void:
	var p: Player = (load("res://world/player/player.tscn") as PackedScene).instantiate() as Player
	p.position = Vector3(20, 0, 20)
	add_child(p)
	p.setup(PlayerStats.new(), projectiles)
	await wait_frames(2)
	Input.action_press("move_right")
	await wait_frames(10)
	var walk: float = Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_press("shoot")
	await wait_frames(10)
	var firing: float = Vector2(p.velocity.x, p.velocity.z).length()
	var was_firing: bool = p.input.is_firing()
	Input.action_release("shoot")
	Input.action_release("move_right")
	check(walk > 4.0, "walks at normal speed (%.2f)" % walk)
	check(was_firing, "firing state read")
	check_eq(snappedf(firing, 0.01), 0.0, "cannot walk while shooting (speed %.2f)" % firing)
	p.queue_free()
	for b: Node in projectiles.get_children():
		b.queue_free()


func test_3_hit_forgiveness() -> void:
	var z: Zombie = _spawn_zombie(Vector3(0, 0, 0))
	await wait_frames(3)
	var start_z: float = z.health
	_shoot(Vector3(-5.0, 1.0, 0.45), Vector3.RIGHT)  # 0.45 m beside the centre: outside body (0.33), inside forgiveness
	await wait_frames(30)
	check(z.health < start_z, "bullet passing 0.45 m beside zombie hits (hp %.1f)" % z.health)
	var hp: float = z.health
	_shoot(Vector3(-5.0, 1.0, 3.0), Vector3.RIGHT)
	await wait_frames(30)
	check_eq(z.health, hp, "bullet passing 3 m beside zombie misses")
	z.queue_free()


func test_4_hurtbox_scales_with_radius() -> void:
	var big: EnemyData = EnemyData.new()
	big.radius = 0.66
	var z: Zombie = _spawn_zombie(Vector3(0, 0, 0), big)
	await wait_frames(3)
	var shape: CylinderShape3D = (z.get_node("Hurtbox/CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
	check(shape.radius > 0.66 + 0.2, "boss hurtbox radius %.2f" % shape.radius)
	var small: CylinderShape3D = null
	var z2: Zombie = _spawn_zombie(Vector3(30, 0, 0))
	await wait_frames(3)
	small = (z2.get_node("Hurtbox/CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
	check(small.radius < shape.radius, "shapes are per zombie (%.2f vs %.2f)" % [small.radius, shape.radius])
	z.queue_free()
	z2.queue_free()


func test_5_wall_blocks_and_beam_fades() -> void:
	var z: Zombie = _spawn_zombie(Vector3(103, 0, 0))  # behind the wall at x=100
	await wait_frames(3)
	var b: Bullet = _shoot(Vector3(95, 1.0, 0), Vector3.RIGHT, 20.0)
	await wait_frames(3)
	check_eq(z.health, z.data.max_health, "wall blocks bullet")
	check(b.global_position.x < 100.0, "bullet stopped at wall (x=%.2f)" % b.global_position.x)
	check(is_instance_valid(b) and b._segments.size() == 1, "one static line of light")
	check(b._segments[0][1].x < 100.0 and b._segments[0][1].x > 99.0, "line ends at the wall (x=%.2f)" % b._segments[0][1].x)
	var beam: MeshInstance3D = b.get_node("Beam") as MeshInstance3D
	check(beam.visible, "line still visible just after impact")
	check_eq(beam.global_position.x, (b._segments[0][0].x + b._segments[0][1].x) * 0.5, "line spans muzzle to wall (centre)")
	await wait_seconds(pistol.beam_fade_seconds + 0.3)
	check(not is_instance_valid(b), "beam faded and bullet freed")
	z.queue_free()


func test_6_open_air_line_spans_full_range() -> void:
	var b: Bullet = _shoot(Vector3(0, 1.0, 40), Vector3.RIGHT, 12.0)
	await wait_frames(3)
	check(is_instance_valid(b) and b._segments.size() == 1, "one segment in open air")
	check_eq(snappedf(b._segments[0][0].distance_to(b._segments[0][1]), 0.01), 12.0, "line is as long as the weapon range")
	var p0: Vector3 = b._segments[0][1]
	await wait_frames(3)
	check_eq(b._segments[0][1], p0, "line does not move")
	b.queue_free()


func test_7_hit_is_instant_and_zombie_flinches() -> void:
	var z: Zombie = _spawn_zombie(Vector3(60, 0, 0), load("res://data/enemies/walker.tres") as EnemyData)
	await wait_frames(3)
	var hp: float = z.health
	_shoot(Vector3(56, 1.0, 0), Vector3.RIGHT, 12.0)
	await wait_frames(2)
	check(z.health < hp, "damage lands on the first frames, no travel time")
	var model: ZombieModel = z.get_node("Visual/Model") as ZombieModel
	check(z._stun > 0.0, "zombie staggers after the hit")
	check(model._hit_left > 0.0, "hit reaction plays")
	var tilted: bool = not model.basis.is_equal_approx(model._rest.basis)
	check(tilted, "model tilted by the hit")
	await wait_seconds(model.hit_recover_seconds + 0.2)
	check(model.basis.is_equal_approx(model._rest.basis), "model returns to rest")
	check_eq(z._stun, 0.0, "stagger ends")
	z.queue_free()


func test_8_weapons_fire_slower_but_hit_harder() -> void:
	check(pistol.shots_per_second <= 2.0, "pistol fire rate %.1f/s" % pistol.shots_per_second)
	var walker: EnemyData = load("res://data/enemies/walker.tres") as EnemyData
	var shots: int = ceili(walker.max_health / pistol.damage)
	check(shots >= 2 and shots <= 4, "walker takes %d pistol shots" % shots)
