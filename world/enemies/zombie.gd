class_name Zombie
extends CharacterBody3D
## A zombie. Chases its target once aware of it, hurts on contact, dies and reports XP upward.

signal died(zombie: Zombie, xp: float, at: Vector3)
signal attacked(damage: float)

const GROUP: StringName = &"zombies"

@export var data: EnemyData
## Zombies notice the target within this distance in metres (directors set it very high; hordes keep it low).
@export_range(0, 100000) var aggro_radius: float = 100000.0
@export_range(0, 2, 0.05) var knockback_strength: float = 0.25
@export var hit_color: Color = Color(1, 1, 1)

@onready var _visual: Node3D = $Visual
@onready var _body: MeshInstance3D = $Visual/Body
@onready var _band: MeshInstance3D = $Visual/Band
@onready var _bar: Node3D = $HealthBar
@onready var _bar_fill: Node3D = $HealthBar/Fill

var target: Node3D
var target_radius: float = 0.35
var is_dead: bool = false
var health: float
var _speed: float
var _attack_cooldown: float = 0.0
var _aware: bool = false
var _flash: float = 0.0
var _wander: Vector3 = Vector3.ZERO
var _wander_time: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _material: StandardMaterial3D


func _ready() -> void:
	add_to_group(GROUP)
	if data == null:
		data = EnemyData.new()
	health = data.max_health
	_speed = data.speed * randf_range(1.0 - data.speed_variance, 1.0 + data.speed_variance)
	var shape: CylinderShape3D = ($CollisionShape3D as CollisionShape3D).shape as CylinderShape3D
	shape.radius = data.radius
	var s: float = data.radius / 0.33
	_visual.scale = Vector3(s, 1.0 + (s - 1.0) * 0.5, s)
	_material = StandardMaterial3D.new()
	_material.albedo_color = data.color
	_body.material_override = _material
	_band.visible = data.armour > 0.0
	if _band.visible:
		var band_mat: StandardMaterial3D = StandardMaterial3D.new()
		band_mat.albedo_color = data.armour_color
		band_mat.metallic = 0.6
		_band.material_override = band_mat
	_bar.visible = false


## Call down: who to chase.
func setup(enemy: EnemyData, chase_target: Node3D, aggro: float) -> void:
	data = enemy
	target = chase_target
	aggro_radius = aggro


## Returns damage actually dealt after armour.
func take_damage(amount: float, direction: Vector3 = Vector3.ZERO) -> float:
	if is_dead:
		return 0.0
	var dealt: float = minf(health, amount * (1.0 - data.armour))
	health -= dealt
	_flash = 0.08
	_material.albedo_color = hit_color
	_aware = true
	_knockback += direction * amount * knockback_strength * 0.5
	_bar.visible = true
	_bar_fill.scale.x = maxf(0.001, health / data.max_health)
	if health <= 0.0:
		is_dead = true
		died.emit(self, data.xp, global_position)
		queue_free()
	return dealt


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		if _flash == 0.0:
			_material.albedo_color = data.color
	var dir: Vector3 = Vector3.ZERO
	if target != null and is_instance_valid(target):
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		var dist: float = to_target.length()
		if not _aware and dist <= aggro_radius:
			_aware = true
		if _aware:
			dir = to_target / maxf(dist, 0.001)
			if dist <= data.radius + target_radius + 0.15 and _attack_cooldown <= 0.0:
				_attack_cooldown = data.attack_interval
				attacked.emit(data.contact_damage)
	if not _aware:
		_wander_time -= delta
		if _wander_time <= 0.0:
			_wander_time = randf_range(1.0, 3.0)
			_wander = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(0.0, 0.35)
		dir = _wander
	velocity = dir * _speed + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 22.0 * delta)
	move_and_slide()
	global_position.y = 0.0
	if dir.length() > 0.05:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
