class_name FlagEffect
extends PerkEffect
## Turns on a rule-changing flag on the player stats.

@export var flag: PlayerStats.Flag = PlayerStats.Flag.NO_HEALTH_PICKUPS
## Card text, since flags have no number to show.
@export var text: String = "Health pickups no longer spawn."


func apply(ctx: PerkContext) -> void:
	ctx.stats.set_flag(flag, true)


func describe(_ctx: PerkContext) -> String:
	return text
