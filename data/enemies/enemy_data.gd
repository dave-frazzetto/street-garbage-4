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
## Fraction of the hit stagger ignored (1 = never staggers). Bosses shrug hits off more.
@export_range(0, 1, 0.01) var stagger_resistance: float = 0.0
@export_range(0, 100) var xp: float = 1.0
## Body radius in metres (collision). Keep it at 0.33 x size_scale so hit boxes match the visible body.
@export_range(0.1, 1.5, 0.01) var radius: float = 0.33
## Uniform size of the model and collision body relative to a normal zombie (1.2 = 20% larger).
@export_range(0.5, 3.0, 0.05) var size_scale: float = 1.0
## Show the health bar from the start instead of after the first hit (bosses).
@export var always_show_health_bar: bool = false
## At most this many of this type alive at once from the director's spawn table (0 = no limit).
@export_range(0, 50) var max_alive: int = 0
## Model for this zombie type (a ZombieModel scene). Empty = the walker model already in the zombie scene.
@export var model_scene: PackedScene
## Colour mixed over the model's texture to tell variants apart. The alpha is the mix strength (0 = no tint).
@export var tint: Color = Color(1, 1, 1, 0)
