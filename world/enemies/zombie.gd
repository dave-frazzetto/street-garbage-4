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
## Physics layer of walls and other solid scenery.
const WALL_LAYER: int = 1

@export var data: EnemyData
## Zombies notice the target within this distance in metres (directors set it very high; hordes keep it low).
@export_range(0, 100000) var aggro_radius: float = 100000.0
@export_range(0, 2, 0.05) var knockback_strength: float = 0.6
## Seconds a zombie staggers (stops chasing and attacking) after a hit, before EnemyData.stagger_resistance.
@export_range(0, 1, 0.01) var hit_stun_seconds: float = 0.3
@export var hit_color: Color = Color(1, 1, 1)
## Seconds a corpse stays on the ground after its death animation ends.
@export_range(0, 30, 0.5) var corpse_linger: float = 2.0

## Furthest ahead (in seconds of the zombie's own travel time) it aims at a moving target, see GameTuning.zombie_intercept.
@export_range(0, 5, 0.1) var max_lead_seconds: float = 1.5
## Each zombie uses a random share of GameTuning.zombie_intercept between this fraction and 1, so a crowd fans out.
@export_range(0, 1, 0.05) var intercept_spread_min: float = 0.5
## The target's estimated speed is capped at this many m/s, so a teleport does not fling zombies.
@export_range(1, 40, 0.5) var target_speed_cap: float = 12.0
## A target slower than this (m/s) counts as standing still: zombies aim straight at it instead of ahead of it.
@export_range(0, 2, 0.05) var min_lead_speed: float = 0.2
## How fast the estimate of the target's velocity follows its real velocity (per second).
@export_range(1, 60, 1) var velocity_smoothing: float = 12.0
@export_group("Getting around walls")
## A chasing zombie that moves slower than this fraction of its speed is blocked (a wall in the way).
@export_range(0, 1, 0.05) var blocked_speed_fraction: float = 0.3
## Seconds of being blocked before it starts to walk along the wall instead of into it.
@export_range(0.05, 3, 0.05) var blocked_seconds: float = 0.3
## Longest distance in metres it walks along a wall before it tries the straight way again (it also stops as soon as it
## sees the target again; 0 = never gets around walls). A distance, not a time, so slow zombies still reach the corner
## of a building.
@export_range(0, 60, 0.5) var wall_follow_distance: float = 15.0
## Blocked zombies closer than this to the target are just crowding it, not stuck behind a wall.
@export_range(0, 10, 0.25) var wall_follow_min_distance: float = 2.5
## After this many walk-along-the-wall attempts in a row it turns the other way round the obstacle.
@export_range(1, 10) var wall_follow_flip_after: int = 3
@export_group("")
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
## Collision radius in metres and model size after GameTuning.character_scale (set in _ready; the hurtbox reads them).
var body_radius: float = 0.33
var body_scale: float = 1.0
var is_dead: bool = false
var health: float
## Health at spawn (GameTuning.zombie_max_health); the bar and tests read it.
var max_health: float
var _speed: float
var _tuning: GameTuning
var _spawn_elapsed: float = 0.0
var _contact_damage: float = 0.0
var _xp_reward: float = 0.0
var _intercept: float = 0.0
var _target_velocity: Vector3 = Vector3.ZERO
var _target_last: Vector3 = Vector3.ZERO
var _has_target_last: bool = false
var _attack_cooldown: float = 0.0
var _aware: bool = false
var _flash: float = 0.0
var _wander: Vector3 = Vector3.ZERO
var _wander_time: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _stun: float = 0.0
var _animate: bool = true
var _target_dist: float = 0.0
var _blocked_time: float = 0.0
var _unblocked_time: float = 0.0
var _follow_time: float = 0.0
var _follow_normal: Vector3 = Vector3.ZERO
## Which way round an obstacle it walks: +1 or -1 quarter turns from the wall normal (0 = not decided).
var _follow_side: float = 0.0
var _follow_count: int = 0
var _cull_timer: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	if data == null:
		data = EnemyData.new()
	var tuning: GameTuning = _tuning if _tuning != null else GameTuning.fallback()
	max_health = tuning.zombie_max_health(data, _spawn_elapsed)
	health = max_health
	_speed = tuning.zombie_speed(data, _spawn_elapsed) * randf_range(1.0 - data.speed_variance, 1.0 + data.speed_variance)
	_contact_damage = tuning.zombie_contact_damage(data)
	_xp_reward = tuning.zombie_xp(data, _spawn_elapsed)
	_intercept = tuning.zombie_intercept * randf_range(intercept_spread_min, 1.0)
	body_radius = tuning.zombie_radius(data)
	body_scale = tuning.zombie_size(data)
	var shape_node: CollisionShape3D = $CollisionShape3D as CollisionShape3D
	var shape: CylinderShape3D = shape_node.shape as CylinderShape3D
	shape.radius = body_radius
	shape.height *= body_scale
	shape_node.position.y *= body_scale
	if data.model_scene != null:
		_swap_model(data.model_scene)
	_visual.scale = Vector3.ONE * body_scale
	_bar.position.y *= body_scale
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


## Call down, before the zombie enters the tree: what it is, who to chase, and the balance numbers (GameTuning) and
## run time that set its speed, health, damage and XP.
func setup(enemy: EnemyData, chase_target: Node3D, aggro: float, tuning: GameTuning = null, elapsed: float = 0.0) -> void:
	data = enemy
	target = chase_target
	aggro_radius = aggro
	_tuning = tuning
	_spawn_elapsed = elapsed


## Someone made noise at `at`: an idle zombie within `radius` metres starts chasing.
func alert(at: Vector3, radius: float) -> void:
	if is_dead or _aware:
		return
	if Vector2(at.x - global_position.x, at.z - global_position.z).length_squared() <= radius * radius:
		_aware = true


## Number of living zombies per EnemyData, for spawn caps (EnemyData.max_alive).
static func count_by_type(tree: SceneTree) -> Dictionary:
	var counts: Dictionary = {}
	for node: Node in tree.get_nodes_in_group(GROUP):
		var z: Zombie = node as Zombie
		if z != null and not z.is_dead and z.data != null:
			counts[z.data] = int(counts.get(z.data, 0)) + 1
	return counts


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
	_stun = hit_stun_seconds * (1.0 - data.stagger_resistance)
	_model.play_hit(_visual.global_transform.basis.inverse() * direction)
	_knockback += direction * amount * knockback_strength * 0.5
	_bar.visible = true
	_bar_fill.scale.x = maxf(0.001, health / max_health)
	if health <= 0.0:
		is_dead = true
		_leave_corpse()
		died.emit(self, _xp_reward, global_position)
		queue_free()
	return dealt


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_stun = maxf(0.0, _stun - delta)
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
		_target_dist = dist
		_track_target_velocity(delta)
		if _aware and _stun <= 0.0:
			dir = _chase_direction(to_target, dist)
			if _follow_time > 0.0:
				dir = _follow_direction(delta)
			if dist <= body_radius + target_radius + 0.15 and _attack_cooldown <= 0.0:
				_attack_cooldown = data.attack_interval
				_model.play_attack()
				attacked.emit(_contact_damage)
	if not _aware and _stun <= 0.0:
		_wander_time -= delta
		if _wander_time <= 0.0:
			_wander_time = randf_range(1.0, 3.0)
			_wander = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(0.0, 0.35)
		dir = _wander
	velocity = dir * _speed + _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 22.0 * delta)
	move_and_slide()
	global_position.y = 0.0
	_track_blocked(delta, dir)
	if _animate:
		_model.set_move_speed(dir.length() * _speed)
	if dir.length() > 0.05:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)


## Estimates how fast the target moves (smoothed, so a teleport does not fling zombies).
func _track_target_velocity(delta: float) -> void:
	var pos: Vector3 = target.global_position
	if _has_target_last and delta > 0.0:
		var raw: Vector3 = (pos - _target_last) / delta
		raw.y = 0.0
		_target_velocity = _target_velocity.lerp(raw.limit_length(target_speed_cap), minf(1.0, velocity_smoothing * delta))
	_target_last = pos
	_has_target_last = true


## Direction to run in: straight at the target, or ahead of it along its movement so circling does not work.
func _chase_direction(to_target: Vector3, dist: float) -> Vector3:
	if _intercept <= 0.0 or _target_velocity.length_squared() < min_lead_speed * min_lead_speed:
		return to_target / maxf(dist, 0.001)
	var lead: float = minf(dist / maxf(_speed, 0.1), max_lead_seconds) * _intercept
	var aim: Vector3 = to_target + _target_velocity * lead
	aim.y = 0.0
	if aim.length_squared() < 0.0001:
		return to_target / maxf(dist, 0.001)
	return aim.normalized()


## Notices a chasing zombie that is pushed against a wall and makes it walk along the wall for a moment, always round
## the obstacle the same way, so a crowd behind a building finds the corner instead of standing there.
func _track_blocked(delta: float, dir: Vector3) -> void:
	var chasing: bool = _aware and _stun <= 0.0 and dir.length_squared() > 0.01 and _target_dist > wall_follow_min_distance
	if not chasing or wall_follow_distance <= 0.0:
		_blocked_time = 0.0
		return
	var real: Vector3 = get_real_velocity()
	if Vector2(real.x, real.z).length() < blocked_speed_fraction * _speed:
		_unblocked_time = 0.0
		_blocked_time += delta
		if _blocked_time >= blocked_seconds and _follow_time <= 0.0:
			_start_wall_follow()
	else:
		_blocked_time = 0.0
		_unblocked_time += delta
		if _unblocked_time > 2.0 and _follow_time <= 0.0 and _follow_side != 0.0:
			# Sliding along the same wall does not count as free: keep going round the same way until the target is in sight.
			if _wall_in_the_way():
				_unblocked_time = 0.0
			else:
				_follow_side = 0.0
				_follow_count = 0


func _start_wall_follow() -> void:
	_blocked_time = 0.0
	var normal: Vector3 = _wall_normal()
	if normal == Vector3.ZERO or not _wall_in_the_way():
		return
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	if _follow_side == 0.0:
		_follow_side = 1.0 if normal.rotated(Vector3.UP, PI * 0.5).dot(to_target) >= 0.0 else -1.0
	_follow_count += 1
	if _follow_count > wall_follow_flip_after:
		_follow_side = -_follow_side
		_follow_count = 1
	_follow_normal = normal
	_follow_time = wall_follow_distance / maxf(_speed, 0.1)


## While walking along a wall: along it, hugging it a little, until the target is in sight again or the time is up.
func _follow_direction(delta: float) -> Vector3:
	_follow_time -= delta
	var normal: Vector3 = _wall_normal()
	if normal != Vector3.ZERO:
		_follow_normal = normal
	if not _wall_in_the_way():
		_follow_time = 0.0
		return (target.global_position - global_position).normalized()
	var along: Vector3 = _follow_normal.rotated(Vector3.UP, _follow_side * PI * 0.5)
	return (along - _follow_normal * 0.3).normalized()


## Flat normal of the wall this zombie is pressed against right now (zero if none).
func _wall_normal() -> Vector3:
	for i: int in range(get_slide_collision_count() - 1, -1, -1):
		var hit: KinematicCollision3D = get_slide_collision(i)
		var body: CollisionObject3D = hit.get_collider() as CollisionObject3D
		if body == null or (body.collision_layer & WALL_LAYER) == 0:
			continue
		var n: Vector3 = hit.get_normal()
		n.y = 0.0
		if n.length_squared() > 0.0001:
			return n.normalized()
	return Vector3.ZERO


## True while something solid stands between this zombie and its target.
func _wall_in_the_way() -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), target.global_position + Vector3(0, 0.6, 0), WALL_LAYER)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


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
