class_name GrantGearEffect
extends PerkEffect
## Gives gears immediately. Not offered once all gears are collected.

@export_range(1, 6) var count: int = 1


func apply(ctx: PerkContext) -> void:
	for i: int in count:
		ctx.run.add_gear()


func describe(ctx: PerkContext) -> String:
	return "Gears: %d -> %d" % [ctx.run.gears, mini(ctx.run.gears + count, ctx.run.config.gears_required)]


func is_available(ctx: PerkContext) -> bool:
	return ctx.run.gears_missing() > 0
