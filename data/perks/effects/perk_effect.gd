@abstract
class_name PerkEffect
extends Resource
## Base of all perk effects. Subclasses change the run or the player stats through the PerkContext only.


@abstract func apply(ctx: PerkContext) -> void


## One line of card text, or "" for none.
func describe(_ctx: PerkContext) -> String:
	return ""


## False if this effect makes no sense right now (e.g. a gear when all gears are collected).
func is_available(_ctx: PerkContext) -> bool:
	return true
