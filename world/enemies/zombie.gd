class_name Zombie
extends CharacterBody3D
## A zombie. Chases its target once aware of it, hurts on contact, dies and reports XP upward.

signal died(zombie: Zombie, xp: float, at: Vector3)
signal attacked(damage: float)
## Emitted on every hit that lands, before death. `at` is the zombie position, `direction` the push (zero for blasts).
signal damaged(at: Vector3, direction: Vector3, amount: float)

const GROUP: StringName = &"zombies"
## Seconds between animation-culling distance checks.
const CULL_CHECK_SECONDS: float = 0.25

@export var data: EnemyData
## Zombies notice the target within this distance in metres (directors set it very high; hordes keep it low).
@export_range(0, 100000) var aggro_radius: float = 100000.0
@export_range(0, 2, 0.05) var knockback_strength: float = 0.25
@export var hit_color: Color = Color(1, 1, 1)
## Seconds a corpse stays on the ground after its death animation ends.
@export_range(0, 30, 0.5) var corpse_linger: float = 2.0

## Set by the director before the zombie enters the tree: difficulty ramp multipliers on speed and health.
var speed_multiplier: float = 1.0
var health_multiplier: float = 1.0
## Beyond this distance from the target the walk animation is paused (nobody can see it, saves CPU).
@export_range(5, 100) var animation_cull_distance: float = 26.0
## Corpses left on the ground by all zombies at once; the oldest model is freed beyond this.
static var max_corpses: int = 40
static var _corpses: Array[Node3D] = []

@onready var _visual: Node3D = $Visual
@onready var _model: ZombieModel = $Visual/Model
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
var _max_health: float
var _animate: bool = true
var _cull_timer: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	if data == null:
		data = EnemyData.new()
	_max_health = data.max_health * health_multiplier
	health = _max_health
	_speed = data.speed * speed_multiplier * randf_range(1.0 - data.speed_variance, 1.0 + data.speed_variance)
	var shape_node: CollisionShape3D = $CollisionShape3D as CollisionShape3D
	var shape: CylinderShape3D = shape_node.shape as CylinderShape3D
	shape.radius = data.radius
	shape.height *= data.size_scale
	shape_node.position.y *= data.size_scale
	if data.model_scene != null:
		_swap_model(data.model_scene)
	_visual.scale = Vector3.ONE * data.size_scale
	_bar.position.y *= data.size_scale
	_model.set_tint(data.tint)
	_bar.visible = data.always_show_health_bar
	_cull_timer = randf() * CULL_CHECK_SECONDS


## Replaces the built-in walker model with this zombie type's own.
func _swap_model(scene: PackedScene) -> void:
	var old: Node = _visual.get_node("Model")
	_visual.remove_child(old)
	old.queue_free()
	var fresh: ZombieModel = scene.instantiate() as ZombieModel
	fresh.name = "Model"
	_visual.add_child(fresh)
	_model = fresh


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
	damaged.emit(global_position, direction, dealt)
	_flash = 0.08
	_model.flash(hit_color)
	_aware = true
	_knockback += direction * amount * knockback_strength * 0.5
	_bar.visible = true
	_bar_fill.scale.x = maxf(0.001, health / _max_health)
	if health <= 0.0:
		is_dead = true
		_leave_corpse()
		died.emit(self, data.xp, global_position)
		queue_free()
	return dealt


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_cull_timer -= delta
	if _cull_timer <= 0.0:
		_cull_timer = CULL_CHECK_SECONDS
		_update_animation_culling()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		if _flash == 0.0:
			_model.clear_flash()
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
				_model.play_attack()
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
	if _animate:
		_model.set_move_speed(dir.length() * _speed)
	if dir.length() > 0.05:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)


## Pauses the walk animation of zombies too far from the target to be seen.
func _update_animation_culling() -> void:
	if target == null or not is_instance_valid(target):
		return
	var off: Vector3 = target.global_position - global_position
	var animate: bool = Vector2(off.x, off.z).length_squared() <= animation_cull_distance * animation_cull_distance
	if animate != _animate:
		_animate = animate
		if not animate:
			_model.hold()


## The model outlives the zombie: it is handed to our parent, plays its death clip and is freed afterwards.
func _leave_corpse() -> void:
	var holder: Node = get_parent()
	if holder == null:
		return
	_visual.reparent(holder)
	var clip_length: float = _model.play_death()
	get_tree().create_timer(clip_length + corpse_linger).timeout.connect(_visual.queue_free)
	_corpses.assign(_corpses.filter(func(c: Variant) -> bool: return is_instance_valid(c) and not c.is_queued_for_deletion()))
	_corpses.append(_visual)
	while _corpses.size() > max_corpses:
		_corpses.pop_front().queue_free()
