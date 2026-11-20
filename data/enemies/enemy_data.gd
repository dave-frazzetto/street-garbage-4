class_name EnemyData
extends Resource
## A zombie type.

@export var display_name: String = "Walker"
@export_range(1, 2000) var max_health: float = 20.0
## Chase speed in pixels per second. Each zombie varies it by speed_variance.
@export_range(10, 400) var speed: float = 70.0
@export_range(0, 1, 0.01) var speed_variance: float = 0.2
@export_range(0, 200) var contact_damage: float = 10.0
## Seconds between contact hits.
@export_range(0.1, 5, 0.05) var attack_interval: float = 0.8
## Fraction of incoming damage ignored (armour).
@export_range(0, 0.95, 0.01) var armour: float = 0.0
@export_range(0, 100) var xp: float = 1.0
@export_range(4, 64) var radius: float = 13.0
@export var color: Color = Color(0.45, 0.7, 0.35)
## Colour of the armour ring (drawn only if armour > 0).
@export var armour_color: Color = Color(0.6, 0.65, 0.75)
