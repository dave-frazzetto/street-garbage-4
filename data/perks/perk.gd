class_name Perk
extends Resource
## One perk card. Its behaviour is the list of effects; add new perks as .tres files and list them in the PerkPool.

enum Category { CHAOS, COMBAT, ECONOMY, SURVIVAL, DUALITY, LOADOUT, WEAPON_MOD }
enum Rarity { COMMON, RARE }

const CATEGORY_NAMES: Dictionary = {
	Category.CHAOS: "CHAOS",
	Category.COMBAT: "COMBAT",
	Category.ECONOMY: "ECONOMY",
	Category.SURVIVAL: "SURVIVAL",
	Category.DUALITY: "DUALITY",
	Category.LOADOUT: "LOADOUT",
	Category.WEAPON_MOD: "WEAPON MOD",
}

## Stable identifier (used for stack counting). Defaults to the file name.
@export var id: StringName
@export var display_name: String = "Perk"
@export var category: Category = Category.COMBAT
@export var rarity: Rarity = Rarity.COMMON
## Relative draw weight, multiplied by the rarity weight in RunConfig.
@export_range(0, 10, 0.05) var weight: float = 1.0
## How many times this perk can be taken in one run.
@export_range(1, 99) var max_stacks: int = 5
## Optional flavour line under the effect text.
@export_multiline var flavour: String = ""
@export var effects: Array[PerkEffect] = []


func get_key() -> StringName:
	if id != &"":
		return id
	return StringName(resource_path.get_file().get_basename())


func category_name() -> String:
	return String(CATEGORY_NAMES[category])


func is_available(ctx: PerkContext) -> bool:
	if ctx.run.perk_stacks(self) >= max_stacks:
		return false
	for effect: PerkEffect in effects:
		if not effect.is_available(ctx):
			return false
	return true


## Lines describing what taking this perk now would do, e.g. "Rate of Fire: 0% -> 12.5%".
func describe(ctx: PerkContext) -> PackedStringArray:
	var lines: PackedStringArray = []
	for effect: PerkEffect in effects:
		var line: String = effect.describe(ctx)
		if line != "":
			lines.append(line)
	return lines


func apply(ctx: PerkContext) -> void:
	ctx.run.add_perk_stack(self)
	for effect: PerkEffect in effects:
		effect.apply(ctx)
