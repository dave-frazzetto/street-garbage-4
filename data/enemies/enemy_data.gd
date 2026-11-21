class_name EnemyData
extends Resource
## A zombie type.

@export var display_name: String = "Walker"
@export_range(1, 2000) var max_health: float = 20.0
## Chase speed in metres per second. Each zombie varies it by speed_variance.
@export_range(0.2, 10, 0.05) var speed: float = 1.75
@export_range(0, 1, 0.01) var speed_variance: float = 0.2
@export_range(0, 200) var contact_damage: float = 10.0
## Seconds between contact hits.
@export_range(0.1, 5, 0.05) var attack_interval: float = 0.8
## Fraction of incoming damage ignored (armour).
@export_range(0, 0.95, 0.01) var armour: float = 0.0
@export_range(0, 100) var xp: float = 1.0
## Body radius in metres. Also scales the model (0.33 is the model's natural size).
@export_range(0.1, 1.5, 0.01) var radius: float = 0.33
## Model for this zombie type (a ZombieModel scene). Empty = the walker model already in the zombie scene.
@export var model_scene: PackedScene
## Colour mixed over the model's texture to tell variants apart. The alpha is the mix strength (0 = no tint).
@export var tint: Color = Color(1, 1, 1, 0)
