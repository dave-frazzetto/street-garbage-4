class_name Destructible
extends Node
## Component that makes its parent body destructible: it takes damage and, at zero health, reports an explosion
## upward. It applies no damage itself: the level owns the blast (zombies, player, chain reactions).
## Add as a child named "Destructible" of a StaticBody3D on the world layer.

signal damaged(health: float, max_health: float)
signal destroyed(at: Vector3, radius: float, damage: float)

@export_range(1, 2000) var max_health: float = 120.0
## Blast radius in metres (0 = breaks without exploding).
@export_range(0, 30, 0.25) var explosion_radius: float = 5.0
## Damage at the centre of the blast; falls off to half at the edge.
@export_range(0, 1000) var explosion_damage: float = 80.0
## Optional node removed when destroyed (e.g. the whole barrel). Leave empty to keep a wreck.
@export var remove_on_destroy: Node

var health: float
var is_destroyed: bool = false


func _ready() -> void:
	health = max_health


## The Destructible component of a physics body hit by a bullet, or null.
static func of(body: Object) -> Destructible:
	var node: Node = body as Node
	if node == null:
		return null
	return node.get_node_or_null("Destructible") as Destructible


func take_damage(amount: float) -> float:
	if is_destroyed or amount <= 0.0:
		return 0.0
	var dealt: float = minf(health, amount)
	health -= dealt
	damaged.emit(health, max_health)
	if health <= 0.0:
		is_destroyed = true
		var origin: Node3D = get_parent() as Node3D
		destroyed.emit(origin.global_position if origin != null else Vector3.ZERO, explosion_radius, explosion_damage)
		if remove_on_destroy != null:
			remove_on_destroy.queue_free.call_deferred()
	return dealt
