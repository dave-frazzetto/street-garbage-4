class_name RunConfig
extends Resource
## Rules of one run. Tune in the Inspector.

## Countdown before the city gets a "nuclear makeover", in seconds.
@export_range(10, 3600) var duration_seconds: float = 1080.0
## Gears needed to extract at the High-Rise.
@export_range(1, 20) var gears_required: int = 6
## Perk redraws available for the whole run.
@export_range(0, 20) var redraws: int = 3
## Number of perk cards dealt at each level-up.
@export_range(1, 5) var hand_size: int = 3
## Day shown on the opening banner of the first run; each new run in a session adds one.
@export var day_number: int = 1

@export_group("XP curve")
## How much a kill is worth is set in GameTuning (xp_per_standard_kill); this is only the cost of each level.
## XP needed to go from level 1 to level 2.
@export_range(1, 500) var xp_first_level: float = 7.0
## Each level needs this much more XP than the previous one (multiplier).
@export_range(1.0, 2.0, 0.01) var xp_growth: float = 1.15
## Flat XP added per level on top of the multiplier.
@export_range(0, 100) var xp_flat_increase: float = 3.0

@export_group("Perk rarity")
## Draw weight multiplier for common perks.
@export_range(0, 10, 0.05) var common_weight: float = 1.0
## Draw weight multiplier for rare perks.
@export_range(0, 10, 0.05) var rare_weight: float = 0.3


## XP needed to advance from `level` to `level + 1`.
func xp_needed(level: int) -> int:
	var l: int = maxi(level, 1) - 1
	return maxi(1, roundi(xp_first_level * pow(xp_growth, l) + xp_flat_increase * l))
