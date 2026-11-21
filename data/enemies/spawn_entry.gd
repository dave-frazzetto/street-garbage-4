class_name SpawnEntry
extends Resource
## One row of the zombie director's spawn table.

@export var enemy: EnemyData
@export_range(0, 100, 0.1) var weight: float = 1.0
## The entry is only used after this many seconds of the run.
@export_range(0, 3600) var min_elapsed_seconds: float = 0.0
## Weight once the ramp is complete (-1 = same as weight). The weight blends linearly with run time, so a type can grow more frequent.
@export_range(-1, 100, 0.1) var weight_at_full_ramp: float = -1.0


func weight_at(ramp: float) -> float:
	return weight if weight_at_full_ramp < 0.0 else lerpf(weight, weight_at_full_ramp, ramp)
