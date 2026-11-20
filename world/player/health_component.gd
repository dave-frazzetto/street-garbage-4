class_name HealthComponent
extends Node
## Health pool. Emits changes upward; knows nothing about who owns it.

signal changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

@export_range(1, 1000) var max_health: float = 100.0
var current: float = 100.0
var is_dead: bool = false


func _ready() -> void:
	current = max_health


func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = maxf(0.0, current - amount)
	damaged.emit(amount)
	changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0 or current >= max_health:
		return
	current = minf(max_health, current + amount)
	changed.emit(current, max_health)


## Changes the maximum. Gains in max health also heal by the same amount; losses clamp.
func set_max_health(value: float) -> void:
	var delta: float = value - max_health
	max_health = maxf(1.0, value)
	if delta > 0.0:
		current += delta
	current = minf(current, max_health)
	changed.emit(current, max_health)
