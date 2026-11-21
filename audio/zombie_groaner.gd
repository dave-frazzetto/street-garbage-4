class_name ZombieGroaner
extends Node
## Picks, every few seconds, the nearest zombie in earshot and asks for one groan. At most one groan per interval no
## matter how many zombies there are, so it stays cheap and never turns into noise.
## Runs on its own: call update(delta, listener_position) each frame; listen to groan_requested.

## Time to play a groan. `volume_offset_db` is quieter the farther the zombie is (<= 0 dB).
signal groan_requested(volume_offset_db: float)

## Seconds between groans, picked at random in this range after each one.
@export_range(0.5, 30.0, 0.1, "suffix:s") var interval_min: float = 2.5
@export_range(0.5, 30.0, 0.1, "suffix:s") var interval_max: float = 6.0
## Zombies farther than this are out of earshot.
@export_range(2.0, 100.0, 0.5, "suffix:m") var hearing_range: float = 22.0
## Zombies closer than this are too busy attacking to groan (the hit and bite sounds cover them).
@export_range(0.0, 10.0, 0.1, "suffix:m") var min_range: float = 1.5
## How much quieter a groan at the edge of the hearing range is.
@export_range(0.0, 40.0, 0.5, "suffix:dB") var range_attenuation_db: float = 14.0
@export var muted: bool = false

var _cooldown: float = 2.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Returns true when a groan was requested this frame.
func update(delta: float, listener: Vector3) -> bool:
	if muted:
		return false
	_cooldown -= delta
	if _cooldown > 0.0:
		return false
	var nearest: float = nearest_distance(listener, get_tree().get_nodes_in_group(Zombie.GROUP))
	if nearest < 0.0:
		_cooldown = 0.5  # nobody near: look again soon instead of waiting a whole interval
		return false
	_cooldown = _rng.randf_range(minf(interval_min, interval_max), maxf(interval_min, interval_max))
	groan_requested.emit(volume_offset_for(nearest))
	return true


## Distance to the nearest living zombie within [min_range, hearing_range], or -1.0 when there is none.
func nearest_distance(listener: Vector3, zombies: Array[Node]) -> float:
	var best: float = -1.0
	for node: Node in zombies:
		var z: Zombie = node as Zombie
		if z == null or z.is_dead:
			continue
		var d: float = Vector2(z.global_position.x - listener.x, z.global_position.z - listener.z).length()
		if d < min_range or d > hearing_range:
			continue
		if best < 0.0 or d < best:
			best = d
	return best


## 0 dB up close, -range_attenuation_db at the edge of hearing_range.
func volume_offset_for(distance: float) -> float:
	var k: float = clampf(distance / maxf(hearing_range, 0.01), 0.0, 1.0)
	return -range_attenuation_db * k
