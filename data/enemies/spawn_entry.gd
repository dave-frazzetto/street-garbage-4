class_name SpawnEntry
extends Resource
## One row of the zombie director's spawn table.

@export var enemy: EnemyData
@export_range(0, 100, 0.1) var weight: float = 1.0
## The entry is only used after this many seconds of the run.
@export_range(0, 3600) var min_elapsed_seconds: float = 0.0
