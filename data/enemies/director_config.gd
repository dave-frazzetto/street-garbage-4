class_name DirectorConfig
extends Resource
## Detail layer of the zombie population: which zombie types exist, how fast the ambient top-up refills, and how far
## from the player zombies exist at all. The headline numbers (how many, how tough, how fast, how often a boss) are in GameTuning.

@export var spawn_table: Array[SpawnEntry] = []

@export_group("Top-up pacing")
## Seconds between top-up waves at the start and at the end of the ramp (GameTuning.ramp_seconds).
@export_range(0.05, 10, 0.05) var interval_start: float = 1.3
@export_range(0.05, 10, 0.05) var interval_end: float = 0.6
## Zombies per wave at the start and at the end of the ramp.
@export_range(1, 30) var batch_start: int = 2
@export_range(1, 30) var batch_end: int = 4
## Zombies spawned around the player on the very first tick, so the run does not start empty.
@export_range(0, 200) var initial_burst: int = 6

@export_group("Distances")
## Spawn distance from the player in metres (just off-screen).
@export_range(5, 80, 0.5) var spawn_distance_min: float = 24.0
@export_range(5, 80, 0.5) var spawn_distance_max: float = 28.0
## Top-up zombies farther than this from the player are freed (the director spawns fresh ones near the player).
@export_range(10, 150) var despawn_distance: float = 48.0
## World and horde zombies exist as nodes only within this distance of the player (see WorldPopulation and HordeSpawner).
@export_range(10, 200) var horde_activation_radius: float = 40.0
## Active world and horde zombies beyond this go back to sleep as data.
@export_range(10, 250) var horde_deactivation_radius: float = 50.0
## Corpses left on the ground at once; the oldest is removed beyond this.
@export_range(0, 300) var max_corpses: int = 40


func interval_at(tuning: GameTuning, elapsed: float) -> float:
	return lerpf(interval_start, interval_end, tuning.ramp(elapsed))


func batch_at(tuning: GameTuning, elapsed: float) -> int:
	return roundi(lerpf(batch_start, batch_end, tuning.ramp(elapsed)))


## Picks a zombie type for a new zombie: first its tier (boss, armoured, standard) from GameTuning's shares, then a type
## inside the tier from the table weights. `alive_by_type` maps EnemyData -> how many are alive, to enforce EnemyData.max_alive.
## A tier with nothing usable falls back to the next lower one.
func pick(elapsed: float, tuning: GameTuning, rng: RandomNumberGenerator, alive_by_type: Dictionary = {}) -> EnemyData:
	var p_boss: float = tuning.boss_share(elapsed)
	var p_elite: float = tuning.elite_share(elapsed)
	var roll: float = rng.randf()
	var tier: int = EnemyData.Tier.STANDARD
	if roll < p_boss:
		tier = EnemyData.Tier.BOSS
	elif roll < p_boss + (1.0 - p_boss) * p_elite:
		tier = EnemyData.Tier.ELITE
	while tier >= EnemyData.Tier.STANDARD:
		var found: EnemyData = _pick_in_tier(tier as EnemyData.Tier, elapsed, rng, alive_by_type)
		if found != null:
			return found
		tier -= 1
	return null


func _pick_in_tier(tier: EnemyData.Tier, elapsed: float, rng: RandomNumberGenerator, alive_by_type: Dictionary) -> EnemyData:
	var total: float = 0.0
	for e: SpawnEntry in spawn_table:
		if e.enemy != null and e.enemy.tier == tier:
			total += _usable_weight(e, elapsed, alive_by_type)
	if total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	var last: EnemyData = null
	for e: SpawnEntry in spawn_table:
		if e.enemy == null or e.enemy.tier != tier:
			continue
		var w: float = _usable_weight(e, elapsed, alive_by_type)
		if w <= 0.0:
			continue
		last = e.enemy
		roll -= w
		if roll <= 0.0:
			return e.enemy
	return last


func _usable_weight(e: SpawnEntry, elapsed: float, alive_by_type: Dictionary) -> float:
	if elapsed < e.min_elapsed_seconds:
		return 0.0
	if e.enemy.max_alive > 0 and int(alive_by_type.get(e.enemy, 0)) >= e.enemy.max_alive:
		return 0.0
	return maxf(0.0, e.weight)
