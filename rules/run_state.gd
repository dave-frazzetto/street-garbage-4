class_name RunState
extends RefCounted
## State and rules of one run: countdown, gears, XP and levels, kills and streaks, redraws, perk stacks, outcome.
## Node-free; game flow drives it and presents it.

signal time_changed(seconds_left: float)
signal gears_changed(have: int, need: int)
signal xp_changed(xp: int, xp_needed: int, level: int)
signal level_up_pending(count: int)
signal kills_changed(kills: int, streak: int)
signal ended(outcome: Outcome)

enum Outcome { NONE, EXTRACTED, KILLED, NUKED }

var config: RunConfig
var time_left: float
var elapsed: float = 0.0
var gears: int = 0
var xp: int = 0
var level: int = 1
var pending_level_ups: int = 0
var kills: int = 0
var streak: int = 0
var best_streak: int = 0
var redraws_left: int
var outcome: Outcome = Outcome.NONE
var _xp_fraction: float = 0.0
var _perk_stacks: Dictionary = {}


func _init(run_config: RunConfig = null) -> void:
	config = run_config if run_config != null else RunConfig.new()
	time_left = config.duration_seconds
	redraws_left = config.redraws


func is_over() -> bool:
	return outcome != Outcome.NONE


func tick(delta: float) -> void:
	if is_over():
		return
	elapsed += delta
	time_left = maxf(0.0, time_left - delta)
	time_changed.emit(time_left)
	if time_left <= 0.0:
		finish(Outcome.NUKED)


func xp_needed() -> int:
	return config.xp_needed(level)


## Adds XP (fractions accumulate). Returns how many levels were gained.
func add_xp(amount: float) -> int:
	if is_over():
		return 0
	_xp_fraction += amount
	var whole: int = floori(_xp_fraction)
	_xp_fraction -= whole
	xp += whole
	var gained: int = 0
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		gained += 1
	if gained > 0:
		pending_level_ups += gained
		level_up_pending.emit(pending_level_ups)
	xp_changed.emit(xp, xp_needed(), level)
	return gained


func consume_level_up() -> void:
	pending_level_ups = maxi(0, pending_level_ups - 1)


func register_kill() -> void:
	kills += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	kills_changed.emit(kills, streak)


## Taking damage breaks the kill streak.
func register_damage() -> void:
	if streak != 0:
		streak = 0
		kills_changed.emit(kills, streak)


func add_gear() -> void:
	gears = mini(gears + 1, config.gears_required)
	gears_changed.emit(gears, config.gears_required)


func gears_missing() -> int:
	return config.gears_required - gears


func can_extract() -> bool:
	return gears >= config.gears_required


func use_redraw() -> bool:
	if redraws_left <= 0:
		return false
	redraws_left -= 1
	return true


func perk_stacks(perk: Perk) -> int:
	return int(_perk_stacks.get(perk.get_key(), 0))


func add_perk_stack(perk: Perk) -> void:
	_perk_stacks[perk.get_key()] = perk_stacks(perk) + 1


func finish(result: Outcome) -> void:
	if is_over():
		return
	outcome = result
	ended.emit(outcome)
