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
## Metres per second.
@export_range(5, 100) var bullet_speed: float = 24.0
## Distance in metres a bullet travels before vanishing.
@export_range(1, 60, 0.5) var range_meters: float = 13.0
## Sound played on every shot.
@export var fire_sound: SfxCue
## Model the player holds for this weapon (a generated .glb whose barrel points the same way as the other weapons).
@export var held_model: PackedScene
## Length of the held model in metres.
@export_range(0.1, 2.0, 0.01) var held_length: float = 0.36
## Shift of the held model in the hand, in metres (hand space). Tune against the player preview.
@export var held_offset: Vector3 = Vector3.ZERO
@export var bullet_color: Color = Color(1.0, 0.6, 0.25)
## Tracer thickness in metres.
@export_range(0.02, 0.5, 0.01) var bullet_radius: float = 0.08
