class_name PlayerConfig
extends Resource
## Base stats of the survivor before perks. Tune in the Inspector.

@export_range(1, 500) var max_health: float = 100.0
## Health regenerated per second.
@export_range(0, 20, 0.1) var health_regen: float = 0.0
## Walking speed in pixels per second.
@export_range(50, 600) var move_speed: float = 210.0
## Extra speed while sprinting, as a fraction of walk speed (0.6 = 60% faster).
@export_range(0, 3, 0.05) var sprint_bonus: float = 0.6
@export_range(10, 500) var max_stamina: float = 100.0
## Stamina drained per second while sprinting.
@export_range(1, 200) var stamina_drain: float = 28.0
## Stamina regained per second while not sprinting.
@export_range(1, 200) var stamina_regen: float = 16.0
## Fraction of each hit that is converted into health (0 = none).
@export_range(0, 1, 0.01) var lifesteal: float = 0.0
## Chance that a killed zombie drops a health pickup.
@export_range(0, 1, 0.01) var health_drop_chance: float = 0.06
## Radius in pixels at which pickups start flying to the player.
@export_range(10, 400) var pickup_radius: float = 70.0


func to_base_stats() -> Dictionary:
	return {
		PlayerStats.Stat.MAX_HEALTH: max_health,
		PlayerStats.Stat.HEALTH_REGEN: health_regen,
		PlayerStats.Stat.MOVE_SPEED: move_speed,
		PlayerStats.Stat.SPRINT_BONUS: sprint_bonus,
		PlayerStats.Stat.MAX_STAMINA: max_stamina,
		PlayerStats.Stat.STAMINA_DRAIN: stamina_drain,
		PlayerStats.Stat.STAMINA_REGEN: stamina_regen,
		PlayerStats.Stat.DAMAGE: 1.0,
		PlayerStats.Stat.FIRE_RATE: 1.0,
		PlayerStats.Stat.RANGE: 1.0,
		PlayerStats.Stat.EXTRA_PROJECTILES: 0.0,
		PlayerStats.Stat.RICOCHET: 0.0,
		PlayerStats.Stat.EXPLOSION: 0.0,
		PlayerStats.Stat.DAMAGE_TAKEN: 1.0,
		PlayerStats.Stat.XP_GAIN: 1.0,
		PlayerStats.Stat.HEALTH_DROP_CHANCE: health_drop_chance,
		PlayerStats.Stat.PICKUP_RADIUS: pickup_radius,
		PlayerStats.Stat.LIFESTEAL: lifesteal,
	}
