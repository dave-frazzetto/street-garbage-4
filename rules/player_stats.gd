class_name PlayerStats
extends RefCounted
## Final survivor stats: (base + flat) * (1 + percent), from a PlayerConfig plus perk modifiers.
## Node-free so it can be unit tested headless. Only game flow (via perk effects) writes to it.

signal changed

enum Stat {
	MAX_HEALTH,
	HEALTH_REGEN,
	MOVE_SPEED,
	SPRINT_BONUS,
	MAX_STAMINA,
	STAMINA_DRAIN,
	STAMINA_REGEN,
	DAMAGE,
	FIRE_RATE,
	RANGE,
	EXTRA_PROJECTILES,
	RICOCHET,
	EXPLOSION,
	DAMAGE_TAKEN,
	XP_GAIN,
	HEALTH_DROP_CHANCE,
	PICKUP_RADIUS,
	LIFESTEAL,
}

enum Mode { FLAT, PERCENT }

enum Flag { NO_HEALTH_PICKUPS }

## How a stat is written on a perk card.
enum Format {
	NUMBER, ## plain number, e.g. "100 -> 120"
	PER_SECOND, ## "0 -> 0.5/s"
	BONUS_PERCENT, ## multiplier shown as bonus over base, e.g. "0% -> 12.5%"
	ABSOLUTE_PERCENT, ## fraction shown as percent, e.g. "6% -> 11%"
	COUNT, ## integer, e.g. "0 -> 1"
}

const STAT_INFO: Dictionary = {
	Stat.MAX_HEALTH: ["Max Health", Format.NUMBER],
	Stat.HEALTH_REGEN: ["Health Regen", Format.PER_SECOND],
	Stat.MOVE_SPEED: ["Move Speed", Format.BONUS_PERCENT],
	Stat.SPRINT_BONUS: ["Sprint Bonus", Format.ABSOLUTE_PERCENT],
	Stat.MAX_STAMINA: ["Max Stamina", Format.NUMBER],
	Stat.STAMINA_DRAIN: ["Sprint Stamina Drain", Format.BONUS_PERCENT],
	Stat.STAMINA_REGEN: ["Stamina Regen", Format.BONUS_PERCENT],
	Stat.DAMAGE: ["Damage", Format.BONUS_PERCENT],
	Stat.FIRE_RATE: ["Rate of Fire", Format.BONUS_PERCENT],
	Stat.RANGE: ["Range", Format.BONUS_PERCENT],
	Stat.EXTRA_PROJECTILES: ["Extra Projectiles", Format.COUNT],
	Stat.RICOCHET: ["Ricochet Bounces", Format.COUNT],
	Stat.EXPLOSION: ["Explosion Damage", Format.ABSOLUTE_PERCENT],
	Stat.DAMAGE_TAKEN: ["Damage Taken", Format.BONUS_PERCENT],
	Stat.XP_GAIN: ["XP from Kills", Format.BONUS_PERCENT],
	Stat.HEALTH_DROP_CHANCE: ["Health Drop Chance", Format.ABSOLUTE_PERCENT],
	Stat.PICKUP_RADIUS: ["Pickup Radius", Format.BONUS_PERCENT],
	Stat.LIFESTEAL: ["Lifesteal", Format.ABSOLUTE_PERCENT],
}

var _base: Dictionary = {}
var _flat: Dictionary = {}
var _percent: Dictionary = {}
var _flags: Dictionary = {}


func _init(config: PlayerConfig = null) -> void:
	if config == null:
		config = PlayerConfig.new()
	_base = config.to_base_stats()
	for stat: int in Stat.values():
		_flat[stat] = 0.0
		_percent[stat] = 0.0


func get_base(stat: Stat) -> float:
	return float(_base.get(stat, 0.0))


func get_value(stat: Stat) -> float:
	return _compute(stat, float(_flat[stat]), float(_percent[stat]))


## Value the stat would have after adding `amount` in `mode`, without changing anything.
func preview_value(stat: Stat, mode: Mode, amount: float) -> float:
	var flat: float = float(_flat[stat]) + (amount if mode == Mode.FLAT else 0.0)
	var pct: float = float(_percent[stat]) + (amount if mode == Mode.PERCENT else 0.0)
	return _compute(stat, flat, pct)


func add_modifier(stat: Stat, mode: Mode, amount: float) -> void:
	if mode == Mode.FLAT:
		_flat[stat] = float(_flat[stat]) + amount
	else:
		_percent[stat] = float(_percent[stat]) + amount
	changed.emit()


func set_flag(flag: Flag, on: bool = true) -> void:
	_flags[flag] = on
	changed.emit()


func has_flag(flag: Flag) -> bool:
	return bool(_flags.get(flag, false))


static func stat_name(stat: Stat) -> String:
	return String(STAT_INFO[stat][0])


## Formats a stat value for a perk card.
func format_value(stat: Stat, value: float) -> String:
	var fmt: int = int(STAT_INFO[stat][1])
	match fmt:
		Format.PER_SECOND:
			return "%s/s" % _num(value)
		Format.BONUS_PERCENT:
			var base: float = get_base(stat)
			var bonus: float = (value / base - 1.0) * 100.0 if base != 0.0 else value * 100.0
			return "%s%%" % _num(bonus)
		Format.ABSOLUTE_PERCENT:
			return "%s%%" % _num(value * 100.0)
		Format.COUNT:
			return str(roundi(value))
		_:
			return _num(value)


func _compute(stat: Stat, flat: float, pct: float) -> float:
	return maxf(0.0, (get_base(stat) + flat) * (1.0 + pct))


static func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(roundi(v))
	var s: String = "%.2f" % v
	s = s.rstrip("0").rstrip(".")
	return s
