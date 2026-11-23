class_name Player
extends CharacterBody3D
## The survivor. Moves, sprints while the sprint input is held, shoots; reports health and deaths upward.
## Runs on its own (F6) with default stats and its own camera; the level injects stats, camera, size and projectile parent.

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
## Collision radius in metres for the model at scale 1 (see set_body_scale; zombies use body_radius for contact range).
@export_range(0.1, 2, 0.05) var base_body_radius: float = 0.35
## Seconds of invulnerability after a hit.
@export_range(0, 2, 0.05) var hit_invulnerability: float = 0.25

@onready var input: PlayerInput = $PlayerInput
@onready var health: HealthComponent = $Health
@onready var stamina: StaminaComponent = $Stamina
@onready var weapon: WeaponComponent = $Weapon
@onready var visual: Node3D = $Visual
@onready var _model: PlayerModel = $Visual/Model
@onready var _body: CollisionShape3D = $CollisionShape3D
@onready var _ring: Node3D = $Ring

var stats: PlayerStats
var sprinting: bool = false
## Collision radius in metres after the body scale.
var body_radius: float = 0.35
## Size relative to the generated model (GameTuning.character_scale).
var body_scale: float = 1.0
## Set when stamina ran out mid-sprint: sprinting waits until the sprint input is released and held again.
var _sprint_spent: bool = false
## Heights of the scaled parts at scale 1, read from the scene.
var _base_heights: Dictionary[Node3D, float] = {}
var _base_shape_height: float = 1.8
var _scale_set: bool = false
var _invulnerable: float = 0.0
## Seconds since the player last took damage (calm regeneration waits for it).
var _since_damage: float = 0.0
var _hit_flash: float = 0.0


func _ready() -> void:
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
	if not _scale_set:
		set_body_scale(GameTuning.fallback().character_scale)
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


## Call down: size relative to the generated model (GameTuning.character_scale). Scales the model, the held weapon, the
## collision body and the ground ring together; the legs' animation follows on its own. The bullet height (the
## Weapon node) and the mouse aim plane stay in world units, so shots still hit props sized in metres (1 m fire barrels).
func set_body_scale(value: float) -> void:
	if _base_heights.is_empty():
		var cylinder: CylinderShape3D = (_body.shape as CylinderShape3D).duplicate() as CylinderShape3D
		_body.shape = cylinder
		_base_shape_height = cylinder.height
		var scaled_parts: Array[Node3D] = [_body]
		for part: Node3D in scaled_parts:
			_base_heights[part] = part.position.y
	_scale_set = true
	body_scale = value
	body_radius = base_body_radius * value
	var shape: CylinderShape3D = _body.shape as CylinderShape3D
	shape.radius = body_radius
	shape.height = _base_shape_height * value
	for part: Node3D in _base_heights:
		part.position.y = _base_heights[part] * value
	visual.scale = Vector3.ONE * value
	_ring.scale = Vector3.ONE * value


## Call down: the camera that defines screen directions.
func set_view(camera: IsoCamera) -> void:
	input.view = camera


func get_pickup_radius() -> float:
	return stats.get_value(PlayerStats.Stat.PICKUP_RADIUS)


func take_damage(amount: float) -> void:
	if _invulnerable > 0.0 or health.is_dead:
		return
	_invulnerable = hit_invulnerability
	_since_damage = 0.0
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
	_since_damage += delta
	var move: Vector3 = input.get_move_vector()
	var moving: bool = move.length() > 0.1 and not (input.is_firing() and stats.get_value(PlayerStats.Stat.FIRING_MOVE_SPEED) <= 0.0)
	_update_sprint(input.is_sprint_held())
	if sprinting and not stamina.update(delta, moving):
		_set_sprinting(false)
		_sprint_spent = true
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
	if _since_damage >= stats.calm_regen_delay:
		regen += stats.calm_regen_per_second
	if regen > 0.0:
		health.heal(regen * delta)
	if _hit_flash > 0.0:
		_model.flash(hit_color)
	else:
		_model.clear_flash()
	_model.update_motion(velocity, input.is_firing())


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


## Sprint lasts while the input is held and stamina remains. Once the bar runs dry, the input must be let go first, and a
## sprint starts only with more than stats.min_sprint_stamina of the bar (no on/off flicker while it refills).
func _update_sprint(held: bool) -> void:
	if not held:
		_sprint_spent = false
		_set_sprinting(false)
	elif not sprinting and not _sprint_spent and stamina.current > maxf(1.0, stamina.max_stamina * stats.min_sprint_stamina):
		_set_sprinting(true)


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
