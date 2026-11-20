class_name StatModifierEffect
extends PerkEffect
## Permanently changes one player stat. Card text shows "Stat: before -> after".

@export var stat: PlayerStats.Stat = PlayerStats.Stat.DAMAGE
## FLAT adds to the base value, PERCENT adds to the multiplier (0.125 = +12.5%).
@export var mode: PlayerStats.Mode = PlayerStats.Mode.PERCENT
@export var amount: float = 0.1


func apply(ctx: PerkContext) -> void:
	ctx.stats.add_modifier(stat, mode, amount)


func describe(ctx: PerkContext) -> String:
	var before: float = ctx.stats.get_value(stat)
	var after: float = ctx.stats.preview_value(stat, mode, amount)
	return "%s: %s -> %s" % [
		PlayerStats.stat_name(stat), ctx.stats.format_value(stat, before), ctx.stats.format_value(stat, after)
	]
