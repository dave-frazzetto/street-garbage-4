extends TestCase
## Destructible props (slice 3, I10): bullets damage them, they explode, the blast hurts zombies and the player,
## and it chains into nearby destructibles.

var flow: GameFlow
var car: Car
var barrel: Node3D


func _ready() -> void:
	flow = (load("res://core/game_flow.tscn") as PackedScene).instantiate() as GameFlow
	flow.seed_value = 5
	add_child(flow)
	run_all()


func test_1_setup_scene() -> void:
	flow.start_run()
	await wait_frames(3)
	var p: Player = flow.level.player
	p.health.max_health = 1000.0
	p.health.current = 1000.0
	# Stage a car in an open spot of the street, with a barrel next to it.
	var at: Vector3 = Vector3(44.0, 0.0, 48.0)
	car = (load("res://world/props/car.tscn") as PackedScene).instantiate() as Car
	car.position = at
	flow.level.get_node("Props").add_child(car)
	barrel = (load("res://world/props/fire.tscn") as PackedScene).instantiate() as Node3D
	barrel.position = at + Vector3(2.5, 0, 0)
	flow.level.get_node("Props").add_child(barrel)
	# Re-wire destructibles added after start (level connects them at start).
	for node: Node in [car.get_node("Destructible"), barrel.get_node("Body/Destructible")]:
		(node as Destructible).destroyed.connect(flow.level._on_prop_destroyed)
	await wait_frames(2)
	check(Destructible.of(car) != null, "car is destructible")


func test_2_bullets_damage_car() -> void:
	var d: Destructible = Destructible.of(car)
	var bullet: Bullet = (load("res://world/projectiles/bullet.tscn") as PackedScene).instantiate() as Bullet
	var pistol: WeaponData = load("res://data/weapons/pistol.tres") as WeaponData
	bullet.setup(car.global_position + Vector3(0, 0.8, -6), Vector3.BACK, pistol, 25.0, 20.0, 0, 0.0)
	flow.level.projectiles.add_child(bullet)
	await wait_frames(20)
	check_eq(d.health, d.max_health - 25.0, "bullet damaged the car")


func test_3_explosion_hurts_zombies_and_player_and_chains() -> void:
	var p: Player = flow.level.player
	p.global_position = car.global_position + Vector3(-2.0, 0, 3.0)
	var zombie: Zombie = (load("res://world/enemies/zombie.tscn") as PackedScene).instantiate() as Zombie
	zombie.setup(load("res://data/enemies/armoured.tres") as EnemyData, p, 0.0)
	zombie.position = car.global_position + Vector3(0, 0, -3.0)
	flow.level.entities.add_child(zombie)
	flow.level._on_zombie_spawned(zombie)
	var far_zombie: Zombie = (load("res://world/enemies/zombie.tscn") as PackedScene).instantiate() as Zombie
	far_zombie.setup(load("res://data/enemies/walker.tres") as EnemyData, p, 0.0)
	far_zombie.position = car.global_position + Vector3(0, 0, -15.0)
	flow.level.entities.add_child(far_zombie)
	await wait_frames(3)
	var hp0: float = p.health.current
	var z_hp0: float = zombie.health
	Destructible.of(car).take_damage(10000.0)
	await wait_frames(4)
	check(Destructible.of(car).is_destroyed, "car destroyed")
	check(not (car.get_node("Glass") as Node3D).visible, "car became a wreck")
	check(not is_instance_valid(zombie) or zombie.health < z_hp0, "zombie in blast damaged")
	check_eq(far_zombie.health, far_zombie.data.max_health, "zombie outside blast untouched")
	check(p.health.current < hp0, "player in blast damaged (%.0f -> %.0f)" % [hp0, p.health.current])
	await wait_seconds(0.4)
	check(not is_instance_valid(barrel), "barrel chained and removed")
