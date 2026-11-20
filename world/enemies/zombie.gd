class_name Zombie
extends CharacterBody2D
## A zombie. Chases its target once aware of it, hurts on contact, dies and reports XP upward.

signal died(zombie: Zombie, xp: float, at: Vector2)
signal attacked(damage: float)

const GROUP: StringName = &"zombies"

@export var data: EnemyData
## Zombies notice the target within this distance (directors set it very high; hordes keep it low).
@export_range(0, 100000) var aggro_radius: float = 100000.0
## Once aware, they never forget.
@export_range(0, 2, 0.05) var knockback_strength: float = 0.25

var target: Node2D
var target_radius: float = 14.0
var is_dead: bool = false
var health: float
var _speed: float
var _attack_cooldown: float = 0.0
var _aware: bool = false
var _flash: float = 0.0
var _wander: Vector2 = Vector2.ZERO
var _wander_time: float = 0.0
var _knockback: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group(GROUP)
	if data == null:
		data = EnemyData.new()
	health = data.max_health
	_speed = data.speed * randf_range(1.0 - data.speed_variance, 1.0 + data.speed_variance)
	($CollisionShape2D.shape as CircleShape2D).radius = data.radius
	queue_redraw()


## Call down: who to chase.
func setup(enemy: EnemyData, chase_target: Node2D, aggro: float) -> void:
	data = enemy
	target = chase_target
	aggro_radius = aggro


## Returns damage actually dealt after armour.
func take_damage(amount: float, direction: Vector2 = Vector2.ZERO) -> float:
	if is_dead:
		return 0.0
	var dealt: float = minf(health, amount * (1.0 - data.armour))
	health -= dealt
	_flash = 0.08
	_aware = true
	_knockback += direction * amount * knockback_strength * 20.0
	if health <= 0.0:
		is_dead = true
		died.emit(self, data.xp, global_position)
		queue_free()
	queue_redraw()
	return dealt


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		if _flash == 0.0:
			queue_redraw()
	var dir: Vector2 = Vector2.ZERO
	if target != null and is_instance_valid(target):
		var to_target: Vector2 = target.global_position - global_position
		var dist: float = to_target.length()
		if not _aware and dist <= aggro_radius:
			_aware = true
		if _aware:
			dir = to_target / maxf(dist, 0.001)
			if dist <= data.radius + target_radius + 4.0 and _attack_cooldown <= 0.0:
				_attack_cooldown = data.attack_interval
				attacked.emit(data.contact_damage)
	if not _aware:
		_wander_time -= delta
		if _wander_time <= 0.0:
			_wander_time = randf_range(1.0, 3.0)
			_wander = Vector2.from_angle(randf() * TAU) * randf_range(0.0, 0.35)
		dir = _wander
	velocity = dir * _speed + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()


func _draw() -> void:
	var col: Color = Color.WHITE if _flash > 0.0 else data.color
	draw_circle(Vector2.ZERO, data.radius, col)
	if data.armour > 0.0:
		draw_arc(Vector2.ZERO, data.radius - 2.0, 0, TAU, 20, data.armour_color, 4.0)
	draw_circle(Vector2(data.radius * 0.35, -data.radius * 0.3), 2.5, Color(0.8, 0.1, 0.1))
	draw_circle(Vector2(-data.radius * 0.35, -data.radius * 0.3), 2.5, Color(0.8, 0.1, 0.1))
	if health < data.max_health:
		var w: float = data.radius * 2.0
		draw_rect(Rect2(-w / 2.0, -data.radius - 8.0, w, 3.0), Color(0.2, 0, 0))
		draw_rect(Rect2(-w / 2.0, -data.radius - 8.0, w * health / data.max_health, 3.0), Color(0.9, 0.2, 0.2))
