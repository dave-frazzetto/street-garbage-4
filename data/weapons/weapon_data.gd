class_name WeaponData
extends Resource
## A gun. Player stats (damage, fire rate, range, projectiles, ricochet, explosion) scale these values.

@export var display_name: String = "Pistol"
@export_range(0.1, 30, 0.1) var shots_per_second: float = 3.0
@export_range(0, 500) var damage: float = 10.0
## Bullets fired per shot (shotguns fire several).
@export_range(1, 20) var projectiles: int = 1
## Total cone in degrees across which projectiles are spread, plus random jitter.
@export_range(0, 90) var spread_degrees: float = 4.0
@export_range(100, 3000) var bullet_speed: float = 950.0
## Distance in pixels a bullet travels before vanishing.
@export_range(50, 2000) var range_pixels: float = 520.0
@export var bullet_color: Color = Color(1.0, 0.9, 0.4)
@export_range(1, 10) var bullet_radius: float = 3.0
