class_name DirectorConfig
extends Resource
## How ambient zombie pressure rises over a run, and how far from the player zombies exist at all.

@export var spawn_table: Array[SpawnEntry] = []

@export_group("Pressure ramp")
## Seconds of run time until full ramp.
@export_range(1, 3600) var ramp_seconds: float = 600.0
## Seconds between spawn waves at the start and at full ramp.
@export_range(0.05, 10, 0.05) var interval_start: float = 1.3
@export_range(0.05, 10, 0.05) var interval_end: float = 0.6
## Zombies per wave at the start and at full ramp.
@export_range(1, 30) var batch_start: int = 2
@export_range(1, 30) var batch_end: int = 4
## Max ambient zombies alive at the start and at full ramp.
@export_range(1, 800) var max_alive_start: int = 24
@export_range(1, 800) var max_alive_end: int = 70
## Zombies spawned around the player on the very first tick, so the run does not start empty.
@export_range(0, 200) var initial_burst: int = 10

@export_group("Zombie strength ramp")
## Chase speed multiplier at the start and at full ramp (applied to each zombie when it spawns).
@export_range(0.5, 3, 0.05) var speed_multiplier_start: float = 1.0
@export_range(0.5, 3, 0.05) var speed_multiplier_end: float = 1.5
## Health multiplier at the start and at full ramp.
@export_range(0.5, 5, 0.05) var health_multiplier_start: float = 1.0
@export_range(0.5, 5, 0.05) var health_multiplier_end: float = 1.8

@export_group("Distances")
## Spawn distance from the player in metres (just off-screen).
@export_range(5, 80, 0.5) var spawn_distance_min: float = 24.0
@export_range(5, 80, 0.5) var spawn_distance_max: float = 28.0
## Ambient zombies farther than this from the player are freed (the director spawns fresh ones near the player).
@export_range(10, 150) var despawn_distance: float = 48.0
## Horde zombies exist as nodes only within this distance of the player (see HordeSpawner).
@export_range(10, 200) var horde_activation_radius: float = 40.0
## Active horde zombies beyond this go back to sleep as data.
@export_range(10, 250) var horde_deactivation_radius: float = 50.0
## Corpses left on the ground at once; the oldest is removed beyond this.
@export_range(0, 300) var max_corpses: int = 40


## 0 at run start, 1 at full ramp.
func ramp(elapsed: float) -> float:
	return clampf(elapsed / ramp_seconds, 0.0, 1.0)


func interval_at(elapsed: float) -> float:
	return lerpf(interval_start, interval_end, ramp(elapsed))


func max_alive_at(elapsed: float) -> int:
	return roundi(lerpf(max_alive_start, max_alive_end, ramp(elapsed)))


func batch_at(elapsed: float) -> int:
	return roundi(lerpf(batch_start, batch_end, ramp(elapsed)))


func speed_multiplier(elapsed: float) -> float:
	return lerpf(speed_multiplier_start, speed_multiplier_end, ramp(elapsed))


func health_multiplier(elapsed: float) -> float:
	return lerpf(health_multiplier_start, health_multiplier_end, ramp(elapsed))


## Picks an enemy type from the spawn table. `alive_by_type` maps EnemyData -> how many are alive, to enforce EnemyData.max_alive.
func pick(elapsed: float, rng: RandomNumberGenerator, alive_by_type: Dictionary = {}) -> EnemyData:
	var r: float = ramp(elapsed)
	var total: float = 0.0
	for e: SpawnEntry in spawn_table:
		total += _usable_weight(e, elapsed, r, alive_by_type)
	if total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	var last: EnemyData = null
	for e: SpawnEntry in spawn_table:
		var w: float = _usable_weight(e, elapsed, r, alive_by_type)
		if w <= 0.0:
			continue
		last = e.enemy
		roll -= w
		if roll <= 0.0:
			return e.enemy
	return last


func _usable_weight(e: SpawnEntry, elapsed: float, r: float, alive_by_type: Dictionary) -> float:
	if e.enemy == null or elapsed < e.min_elapsed_seconds:
		return 0.0
	if e.enemy.max_alive > 0 and int(alive_by_type.get(e.enemy, 0)) >= e.enemy.max_alive:
		return 0.0
	return maxf(0.0, e.weight_at(r))
