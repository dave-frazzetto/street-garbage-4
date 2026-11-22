class_name SpawnEntry
extends Resource
## One row of the zombie spawn table. GameTuning decides how often each tier (standard, armoured, boss) is picked;
## the weights here only choose between the types inside one tier.

@export var enemy: EnemyData
@export_range(0, 100, 0.1) var weight: float = 1.0
## The entry is only used after this many seconds of the run.
@export_range(0, 3600) var min_elapsed_seconds: float = 0.0
