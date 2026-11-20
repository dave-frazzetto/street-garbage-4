class_name WeaponComponent
extends Node3D
## Fires bullets from a WeaponData, scaled by PlayerStats. Supports a temporary weapon that expires.

signal damage_dealt(amount: float)
signal weapon_changed(weapon_name: String, seconds_left: float)
signal fired

@export var base_weapon: WeaponData
@export var bullet_scene: PackedScene
## Distance in metres from the owner's centre where bullets appear.
@export_range(0, 3, 0.05) var muzzle_distance: float = 0.15

## Where bullets are added. Injected by the level; falls back to the owner's parent.
var projectile_parent: Node
var stats: PlayerStats
var temp_weapon: WeaponData
var temp_time_left: float = 0.0
var _cooldown: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func current_weapon() -> WeaponData:
	return temp_weapon if temp_weapon != null else base_weapon


func equip_temporary(weapon: WeaponData, seconds: float) -> void:
	temp_weapon = weapon
	temp_time_left = seconds
	weapon_changed.emit(weapon.display_name, temp_time_left)


func tick(delta: float, firing: bool, direction: Vector3) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if temp_weapon != null:
		temp_time_left -= delta
		if temp_time_left <= 0.0:
			temp_weapon = null
			temp_time_left = 0.0
			weapon_changed.emit(base_weapon.display_name, 0.0)
		else:
			weapon_changed.emit(temp_weapon.display_name, temp_time_left)
	if firing and _cooldown <= 0.0 and direction != Vector3.ZERO:
		_fire(direction.normalized())


func _fire(direction: Vector3) -> void:
	var weapon: WeaponData = current_weapon()
	var fire_rate_mult: float = _stat(PlayerStats.Stat.FIRE_RATE, 1.0)
	_cooldown = 1.0 / maxf(0.1, weapon.shots_per_second * fire_rate_mult)
	var count: int = weapon.projectiles + roundi(_stat(PlayerStats.Stat.EXTRA_PROJECTILES, 0.0))
	var spread: float = deg_to_rad(weapon.spread_degrees)
	# Extra barrels widen the cone a little so the bullets do not overlap.
	if count > weapon.projectiles:
		spread += deg_to_rad(6.0) * (count - weapon.projectiles)
	var parent: Node = projectile_parent if projectile_parent != null else get_parent().get_parent()
	var origin: Vector3 = global_position + direction * muzzle_distance
	for i: int in count:
		var t: float = 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var jitter: float = _rng.randf_range(-0.5, 0.5) * deg_to_rad(weapon.spread_degrees) * 0.35
		var dir: Vector3 = direction.rotated(Vector3.UP, t * spread + jitter)
		var bullet: Bullet = bullet_scene.instantiate() as Bullet
		bullet.setup(
			origin,
			dir,
			weapon,
			weapon.damage * _stat(PlayerStats.Stat.DAMAGE, 1.0),
			weapon.range_meters * _stat(PlayerStats.Stat.RANGE, 1.0),
			roundi(_stat(PlayerStats.Stat.RICOCHET, 0.0)),
			_stat(PlayerStats.Stat.EXPLOSION, 0.0)
		)
		bullet.damage_dealt.connect(_on_bullet_damage)
		parent.add_child(bullet)
	fired.emit()


func _on_bullet_damage(amount: float) -> void:
	damage_dealt.emit(amount)


func _stat(stat: PlayerStats.Stat, fallback: float) -> float:
	return stats.get_value(stat) if stats != null else fallback
