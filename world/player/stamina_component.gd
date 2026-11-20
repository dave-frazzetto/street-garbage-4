class_name StaminaComponent
extends Node
## Stamina pool for sprinting. Drains while in use, regenerates after a short delay otherwise.

signal changed(current: float, maximum: float)
signal exhausted

@export_range(1, 500) var max_stamina: float = 100.0
@export_range(0, 200) var drain_per_second: float = 28.0
@export_range(0, 200) var regen_per_second: float = 16.0
## Seconds after draining stops before regeneration starts.
@export_range(0, 5, 0.05) var regen_delay: float = 0.6

var current: float = 100.0
var _since_drain: float = 999.0


func _ready() -> void:
	current = max_stamina


## Call every physics frame. Returns false if stamina ran out (draining stops).
func update(delta: float, draining: bool) -> bool:
	var before: float = current
	var ok: bool = true
	if draining:
		_since_drain = 0.0
		current = maxf(0.0, current - drain_per_second * delta)
		if current <= 0.0:
			ok = false
			exhausted.emit()
	else:
		_since_drain += delta
		if _since_drain >= regen_delay:
			current = minf(max_stamina, current + regen_per_second * delta)
	if not is_equal_approx(before, current):
		changed.emit(current, max_stamina)
	return ok
