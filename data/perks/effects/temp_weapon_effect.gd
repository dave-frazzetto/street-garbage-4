class_name TempWeaponEffect
extends PerkEffect
## Equips a weapon for a limited time, replacing the current one.

@export var weapon: WeaponData
@export_range(1, 300) var duration_seconds: float = 30.0


func apply(ctx: PerkContext) -> void:
	if ctx.equip_temp_weapon.is_valid():
		ctx.equip_temp_weapon.call(weapon, duration_seconds)


func describe(_ctx: PerkContext) -> String:
	var weapon_name: String = weapon.display_name if weapon != null else "?"
	return "Equips a %s for %s seconds." % [weapon_name, PlayerStats._num(duration_seconds)]
