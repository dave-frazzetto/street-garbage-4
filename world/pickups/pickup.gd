class_name Pickup
extends Node3D
## Base for things the player collects. Flies to the collector inside its pickup radius, then emits collected.
## The owner of the pickup (the level) decides what collecting means.

signal collected(pickup: Pickup)

## Distance in metres at which the pickup is taken.
@export_range(0.1, 5, 0.05) var collect_distance: float = 0.6
@export_range(1, 50) var fly_speed: float = 13.0
## If false the pickup does not fly to the player (e.g. gears stay put).
@export var magnetic: bool = true

var collector: Node3D
## Callable() -> float giving the current attraction radius.
var radius_provider: Callable
var _time: float = 0.0
var _taken: bool = false


func _physics_process(delta: float) -> void:
	_time += delta
	_animate(delta)
	if _taken or collector == null or not is_instance_valid(collector):
		return
	var to: Vector3 = collector.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	if dist <= collect_distance:
		_taken = true
		collected.emit(self)
		queue_free()
		return
	var radius: float = radius_provider.call() if radius_provider.is_valid() else 0.0
	if magnetic and dist <= radius:
		global_position += to / dist * minf(dist, fly_speed * delta)


## Override for idle animation.
func _animate(_delta: float) -> void:
	pass
