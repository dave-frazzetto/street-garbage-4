class_name DirectorConfig
extends Resource
## How ambient zombie pressure rises over a run.

@export var spawn_table: Array[SpawnEntry] = []
## Seconds between spawn waves at the start and at full ramp.
@export_range(0.05, 10, 0.05) var interval_start: float = 1.4
@export_range(0.05, 10, 0.05) var interval_end: float = 0.35
## Zombies per wave at the start and at full ramp.
@export_range(1, 30) var batch_start: int = 2
@export_range(1, 30) var batch_end: int = 5
## Max ambient zombies alive at the start and at full ramp.
@export_range(1, 500) var max_alive_start: int = 30
@export_range(1, 500) var max_alive_end: int = 140
## Seconds of run time until full ramp.
@export_range(1, 3600) var ramp_seconds: float = 720.0
## Spawn distance from the player in metres (just off-screen).
@export_range(5, 80, 0.5) var spawn_distance_min: float = 24.0
@export_range(5, 80, 0.5) var spawn_distance_max: float = 28.0
## Zombies farther than this from the player are recycled.
@export_range(10, 150) var despawn_distance: float = 48.0


## 0 at run start, 1 at full ramp.
func ramp(elapsed: float) -> float:
	return clampf(elapsed / ramp_seconds, 0.0, 1.0)


func pick(elapsed: float, rng: RandomNumberGenerator) -> EnemyData:
	var total: float = 0.0
	for e: SpawnEntry in spawn_table:
		if elapsed >= e.min_elapsed_seconds:
			total += e.weight
	if total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	for e: SpawnEntry in spawn_table:
		if elapsed >= e.min_elapsed_seconds:
			roll -= e.weight
			if roll <= 0.0:
				return e.enemy
	return spawn_table.back().enemy
