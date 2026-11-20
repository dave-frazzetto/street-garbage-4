class_name Player
extends CharacterBody2D
## The survivor. Moves, sprints, shoots; reports health and deaths upward.
## Runs on its own (F6) with default stats; the level injects real stats with setup().

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal damaged(amount: float)
signal died
signal weapon_changed(weapon_name: String, seconds_left: float)
signal sprint_changed(sprinting: bool)

@export var default_config: PlayerConfig
@export var body_color: Color = Color(0.35, 0.65, 1.0)
@export var sprint_color: Color = Color(0.6, 0.85, 1.0)
@export_range(4, 40) var body_radius: float = 14.0
## Seconds of invulnerability after a hit.
@export_range(0, 2, 0.05) var hit_invulnerability: float = 0.25

@onready var input: PlayerInput = $PlayerInput
@onready var health: HealthComponent = $Health
@onready var stamina: StaminaComponent = $Stamina
@onready var weapon: WeaponComponent = $Weapon

var stats: PlayerStats
var sprinting: bool = false
var _invulnerable: float = 0.0
var _hit_flash: float = 0.0


func _ready() -> void:
	input.sprint_toggled.connect(_toggle_sprint)
	health.changed.connect(func(c: float, m: float) -> void: health_changed.emit(c, m))
	health.damaged.connect(func(a: float) -> void: damaged.emit(a))
	health.died.connect(func() -> void: died.emit())
	stamina.changed.connect(func(c: float, m: float) -> void: stamina_changed.emit(c, m))
	weapon.weapon_changed.connect(func(n: String, t: float) -> void: weapon_changed.emit(n, t))
	weapon.damage_dealt.connect(_on_damage_dealt)
	if stats == null:
		setup(PlayerStats.new(default_config), null)


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
		velocity = Vector2.ZERO
		return
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	var move: Vector2 = input.get_move_vector()
	var moving: bool = move.length() > 0.1
	if sprinting and not stamina.update(delta, moving):
		_set_sprinting(false)
	elif not sprinting:
		stamina.update(delta, false)
	var speed: float = stats.get_value(PlayerStats.Stat.MOVE_SPEED)
	if sprinting:
		speed *= 1.0 + stats.get_value(PlayerStats.Stat.SPRINT_BONUS)
	velocity = move * speed
	move_and_slide()
	var aim: Vector2 = input.get_aim_direction()
	weapon.rotation = aim.angle()
	weapon.tick(delta, input.is_firing(), aim)
	var regen: float = stats.get_value(PlayerStats.Stat.HEALTH_REGEN)
	if regen > 0.0:
		health.heal(regen * delta)
	queue_redraw()


func _draw() -> void:
	var col: Color = sprint_color if sprinting else body_color
	if _hit_flash > 0.0:
		col = Color(1, 0.3, 0.3)
	draw_circle(Vector2.ZERO, body_radius, col)
	draw_arc(Vector2.ZERO, body_radius, 0, TAU, 24, Color(0.05, 0.1, 0.2), 2.0)
	var aim: Vector2 = Vector2.from_angle(weapon.rotation)
	draw_line(aim * 6.0, aim * (body_radius + 10.0), Color(0.15, 0.15, 0.15), 6.0)


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
	var lifesteal: float = stats.get_value(PlayerStats.Stat.LIFESTEAL)
	if lifesteal > 0.0:
		health.heal(amount * lifesteal)
