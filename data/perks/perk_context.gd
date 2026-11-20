class_name PerkContext
extends RefCounted
## What a perk effect may touch: the run rules, the player stats, and a callback to equip a temporary weapon.

var run: RunState
var stats: PlayerStats
## Callable(weapon: WeaponData, duration: float) -> void. May be empty in tests.
var equip_temp_weapon: Callable


func _init(run_state: RunState, player_stats: PlayerStats, equip_callback: Callable = Callable()) -> void:
	run = run_state
	stats = player_stats
	equip_temp_weapon = equip_callback
