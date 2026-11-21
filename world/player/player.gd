class_name Player
extends CharacterBody3D
## The survivor. Moves, sprints, shoots; reports health and deaths upward.
## Runs on its own (F6) with default stats and its own camera; the level injects stats, camera and projectile parent.

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal damaged(amount: float)
signal died
signal weapon_changed(weapon_name: String, seconds_left: float)
signal sprint_changed(sprinting: bool)
## A shot left the gun.
signal fired(weapon: WeaponData)
## One of our bullets damaged a zombie.
signal hit_landed(amount: float)

@export var default_config: PlayerConfig
@export var camera_scene: PackedScene
## Colour the model flashes when the player is hit.
@export var hit_color: Color = Color(1.0, 0.3, 0.3)
## Collision radius in metres (zombies use it for contact range).
@export_range(0.1, 2, 0.05) var body_radius: float = 0.35
## Seconds of invulnerability after a hit.
@export_range(0, 2, 0.05) var hit_invulnerability: float = 0.25

@onready var input: PlayerInput = $PlayerInput
@onready var health: HealthComponent = $Health
@onready var stamina: StaminaComponent = $Stamina
@onready var weapon: WeaponComponent = $Weapon
@onready var visual: Node3D = $Visual
@onready var _model: PlayerModel = $Visual/Model

var stats: PlayerStats
var sprinting: bool = false
var _invulnerable: float = 0.0
var _hit_flash: float = 0.0


func _ready() -> void:
	input.sprint_toggled.connect(_toggle_sprint)
	health.changed.connect(func(c: float, m: float) -> void: health_changed.emit(c, m))
	health.damaged.connect(func(a: float) -> void: damaged.emit(a))
	health.died.connect(_on_died)
	stamina.changed.connect(func(c: float, m: float) -> void: stamina_changed.emit(c, m))
	weapon.weapon_changed.connect(func(n: String, t: float) -> void: weapon_changed.emit(n, t))
	weapon.weapon_changed.connect(func(_n: String, _t: float) -> void: _model.hold_weapon(weapon.current_weapon()))
	_model.hold_weapon(weapon.current_weapon())
	weapon.damage_dealt.connect(_on_damage_dealt)
	weapon.fired.connect(func(w: WeaponData) -> void: fired.emit(w))
	if stats == null:
		setup(PlayerStats.new(default_config), null)
	_ensure_camera.call_deferred()


## Call down: inject stats and the node that holds projectiles.
func setup(player_stats: PlayerStats, projectile_parent: Node) -> void:
	if stats != null and stats.changed.is_connected(_apply_stats):
		stats.changed.disconnect(_apply_stats)
	stats = player_stats
	stats.changed.connect(_apply_stats)
	weapon.stats = stats
	weapon.projectile_parent = projectile_parent
	health.max_health = stats.get_value(PlayerStats.Stat.MAX_HEALTH)
	health.current = health.max_health
	_apply_stats()


## Call down: the camera that defines screen directions.
func set_view(camera: IsoCamera) -> void:
	input.view = camera


func get_pickup_radius() -> float:
	return stats.get_value(PlayerStats.Stat.PICKUP_RADIUS)


func take_damage(amount: float) -> void:
	if _invulnerable > 0.0 or health.is_dead:
		return
	_invulnerable = hit_invulnerability
	_hit_flash = 0.15
	health.take_damage(amount * stats.get_value(PlayerStats.Stat.DAMAGE_TAKEN))


func heal(amount: float) -> void:
	health.heal(amount)


func equip_temporary_weapon(data: WeaponData, seconds: float) -> void:
	weapon.equip_temporary(data, seconds)


func _physics_process(delta: float) -> void:
	if health.is_dead:
		velocity = Vector3.ZERO
		return
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	var move: Vector3 = input.get_move_vector()
	var moving: bool = move.length() > 0.1
	if sprinting and not stamina.update(delta, moving):
		_set_sprinting(false)
	elif not sprinting:
		stamina.update(delta, false)
	var speed: float = stats.get_value(PlayerStats.Stat.MOVE_SPEED)
	if sprinting:
		speed *= 1.0 + stats.get_value(PlayerStats.Stat.SPRINT_BONUS)
	if input.is_firing():
		speed *= stats.get_value(PlayerStats.Stat.FIRING_MOVE_SPEED)
	velocity = move * speed
	move_and_slide()
	global_position.y = 0.0
	var aim: Vector3 = input.get_aim_direction()
	visual.rotation.y = atan2(-aim.x, -aim.z)
	weapon.rotation.y = visual.rotation.y
	weapon.tick(delta, input.is_firing(), aim)
	var regen: float = stats.get_value(PlayerStats.Stat.HEALTH_REGEN)
	if regen > 0.0:
		health.heal(regen * delta)
	if _hit_flash > 0.0:
		_model.flash(hit_color)
	else:
		_model.clear_flash()
	_model.update_motion(Vector2(velocity.x, velocity.z).length(), input.is_firing())


func _on_died() -> void:
	_model.play_death()
	died.emit()


func _ensure_camera() -> void:
	# Standalone (F6 / tests): no camera injected and none in the scene, so bring our own.
	if input.view == null and get_viewport().get_camera_3d() == null and camera_scene != null:
		var cam: IsoCamera = camera_scene.instantiate() as IsoCamera
		cam.target = self
		get_parent().add_child(cam)
		cam.snap()
		set_view(cam)


func _toggle_sprint() -> void:
	if not sprinting and stamina.current <= 1.0:
		return
	_set_sprinting(not sprinting)


func _set_sprinting(value: bool) -> void:
	if sprinting != value:
		sprinting = value
		sprint_changed.emit(sprinting)


func _apply_stats() -> void:
	health.set_max_health(stats.get_value(PlayerStats.Stat.MAX_HEALTH))
	stamina.max_stamina = stats.get_value(PlayerStats.Stat.MAX_STAMINA)
	stamina.current = minf(stamina.current, stamina.max_stamina)
	stamina.drain_per_second = stats.get_value(PlayerStats.Stat.STAMINA_DRAIN)
	stamina.regen_per_second = stats.get_value(PlayerStats.Stat.STAMINA_REGEN)


func _on_damage_dealt(amount: float) -> void:
	hit_landed.emit(amount)
	var lifesteal: float = stats.get_value(PlayerStats.Stat.LIFESTEAL)
	if lifesteal > 0.0:
		health.heal(amount * lifesteal)
