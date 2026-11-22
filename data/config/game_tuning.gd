class_name GameTuning
extends Resource
## The main balance knobs of a run in one place: how fast the player and the zombies move, how tough and how many
## zombies there are, how that grows over a run, how often bosses show up and how much XP a kill is worth.
## Edit data/config/game_tuning.tres in the Inspector; docs/reference/tuning-guide.md explains every value.
##
## This resource is read-only at runtime (never mutate it); the detailed layers (PlayerConfig, DirectorConfig, EnemyData)
## hold per-type shapes and are scaled by these numbers. Everything here is a pure function of the numbers, so the
## rules can be unit tested without nodes.

## Shared default used when a scene runs on its own without a tuning resource. Never modified.
static var _fallback: GameTuning


static func fallback() -> GameTuning:
	if _fallback == null:
		_fallback = GameTuning.new()
	return _fallback


@export_group("Pacing")
## Seconds of run time until every "start to end" value below has reached its end value (the run lasts 1080 s, the
## last stretch stays at full pressure).
@export_range(60, 3600, 10) var ramp_seconds: float = 900.0

@export_group("Player movement")
## Walking speed in metres per second. Zombie speed is a ratio of this, so changing it changes how easy outrunning is.
@export_range(1.0, 12.0, 0.1) var player_walk_speed: float = 4.4
## Sprint speed as a multiple of walking speed (1.5 = 50% faster).
@export_range(1.0, 3.0, 0.05) var sprint_speed_multiplier: float = 1.5
## Seconds a full stamina bar lasts while sprinting (PlayerConfig.max_stamina divided by this is the drain per second).
@export_range(0.5, 30.0, 0.1) var sprint_seconds: float = 6.0
## Seconds to refill an empty stamina bar while not sprinting.
@export_range(0.5, 60.0, 0.5) var stamina_recharge_seconds: float = 6.5
## Share of the stamina bar needed to start a sprint (a running sprint lasts until the bar is empty). Keeps a held sprint
## key on an almost empty bar from flicking sprint on and off while the bar refills.
@export_range(0.0, 1.0, 0.01) var min_sprint_stamina: float = 0.15

@export_group("Characters")
## Size of the player and of every zombie relative to the generated models (1.15 = 15% larger). Bodies, bullet hit boxes,
## health bars, the held weapon and the animation playback all follow (bullets keep their 1 m height); EnemyData.size_scale (bosses) multiplies on top.
## Bigger zombies are easier to hit and fill a street sooner.
@export_range(0.5, 2.0, 0.05) var character_scale: float = 1.15

@export_group("Zombie movement")
## Chase speed of a standard zombie as a fraction of the player's walking speed. Below 1 the player can walk away from
## them, above 1 only sprinting helps. Each zombie varies it by EnemyData.speed_variance.
@export_range(0.2, 1.6, 0.01) var zombie_speed_ratio: float = 0.85
## Extra zombie speed at the end of the ramp (0.2 = 20% faster; applied to each zombie when it appears).
@export_range(0.0, 1.0, 0.01) var zombie_speed_growth: float = 0.2
## How much zombies aim ahead of a moving player instead of at where they are now (0 = chase the current position,
## which makes circling easy; 1 = full interception). Each zombie uses a random 50% to 100% of this, so a crowd spreads out.
@export_range(0.0, 1.0, 0.05) var zombie_intercept: float = 0.6
## An idle zombie notices the player within this many metres (zombies from the director always chase).
@export_range(2.0, 60.0, 0.5) var zombie_aggro_radius: float = 18.0
## Each shot alerts idle zombies within this many metres of the player.
@export_range(0.0, 80.0, 0.5) var gunfire_alert_radius: float = 24.0

@export_group("Zombie health and damage")
## Health of a standard zombie at the start of the run. A pistol shot does 28, so 100 is four shots. Other types scale it
## through EnemyData.health_scale.
@export_range(10.0, 1000.0, 1.0) var zombie_health: float = 100.0
## Extra zombie health at the end of the ramp (0.5 = 50% tougher; applied to each zombie when it appears).
@export_range(0.0, 3.0, 0.05) var zombie_health_growth: float = 0.5
## Multiplier on all zombie contact damage (each type's base is EnemyData.contact_damage).
@export_range(0.0, 4.0, 0.05) var zombie_damage_multiplier: float = 1.0

@export_group("Player recovery")
## The player slowly heals once this many seconds have passed without taking damage, so a fight that went badly can be
## walked off. Perks that add health regeneration stack on top and work all the time.
@export_range(0.0, 60.0, 0.5) var calm_regen_delay: float = 5.0
## Health per second regained while calm (0 = no regeneration without perks).
@export_range(0.0, 10.0, 0.1) var calm_regen_per_second: float = 0.5

@export_group("Zombie amounts")
## Zombies waiting in the world per 1000 square metres of map at the start of the run and at the end of the ramp. They
## stand at fixed places, become real zombies when the player is within DirectorConfig.horde_activation_radius and
## go back to sleep when the player leaves, so running never leaves the player in an empty street.
@export_range(0.0, 30.0, 0.1) var world_density_start: float = 1.2
@export_range(0.0, 30.0, 0.1) var world_density_end: float = 6.0
## Extra zombies kept chasing the player from just off-screen (the director's top-up), at the start and at the end of the
## ramp. This is the continuous trickle: it also refills the street when the player has cleared an area.
@export_range(0, 200) var trickle_alive_start: int = 4
@export_range(0, 200) var trickle_alive_end: int = 12
## A killed world zombie comes back at its place this many seconds later, but only while the player is far away
## (0 = never). Keeps long runs from emptying the map.
@export_range(0, 1800, 5) var respawn_seconds: float = 150.0
## No world zombies are placed within this many metres of the player start.
@export_range(0.0, 60.0, 0.5) var start_safe_radius: float = 16.0

@export_group("Zombie mix")
## Armoured zombies appear after this many seconds. Their share of all zombies (bosses aside) grows from the first value
## to the second at the end of the ramp.
@export_range(0, 3600, 10) var elite_start_seconds: float = 120.0
@export_range(0.0, 1.0, 0.01) var elite_share_start: float = 0.05
@export_range(0.0, 1.0, 0.01) var elite_share_end: float = 0.3
## Bosses appear after this many seconds (the original shows one giant once the player holds four or five gears). Their
## share of all new zombies grows from the first value to the second at the end of the ramp; at most
## EnemyData.max_alive of them exist at once.
@export_range(0, 3600, 10) var boss_start_seconds: float = 480.0
@export_range(0.0, 0.2, 0.001) var boss_share_start: float = 0.01
@export_range(0.0, 0.2, 0.001) var boss_share_end: float = 0.03

@export_group("Experience")
## XP of one standard zombie kill (the XP curve in RunConfig says how much a level costs). Other types give this times
## EnemyData.xp.
@export_range(0.1, 20.0, 0.1) var xp_per_standard_kill: float = 1.5
## How much of the zombie health growth is paid back as XP (1 = a zombie 50% tougher gives 50% more XP, 0 = none).
@export_range(0.0, 1.0, 0.05) var xp_health_credit: float = 1.0


## 0 at the start of the run, 1 at the end of the ramp.
func ramp(elapsed: float) -> float:
	return clampf(elapsed / ramp_seconds, 0.0, 1.0)


# --- Player ---------------------------------------------------------------

## SPRINT_BONUS stat (extra speed as a fraction of walking speed).
func sprint_bonus() -> float:
	return sprint_speed_multiplier - 1.0


func sprint_speed() -> float:
	return player_walk_speed * sprint_speed_multiplier


## Stamina drained per second while sprinting for a pool of `max_stamina`.
func stamina_drain(max_stamina: float) -> float:
	return max_stamina / sprint_seconds


func stamina_regen(max_stamina: float) -> float:
	return max_stamina / stamina_recharge_seconds


# --- Zombies --------------------------------------------------------------

## Average chase speed of this zombie type at this point of the run, in metres per second.
func zombie_speed(enemy: EnemyData, elapsed: float) -> float:
	return player_walk_speed * zombie_speed_ratio * enemy.speed_scale * (1.0 + zombie_speed_growth * ramp(elapsed))


## Uniform size of this zombie type's model and body relative to the generated model (EnemyData.size_scale x character_scale).
func zombie_size(enemy: EnemyData) -> float:
	return enemy.size_scale * character_scale


## Collision radius of this zombie type in metres (EnemyData.radius x character_scale).
func zombie_radius(enemy: EnemyData) -> float:
	return enemy.radius * character_scale


## Maximum health of this zombie type when it appears at this point of the run.
func zombie_max_health(enemy: EnemyData, elapsed: float) -> float:
	return zombie_health * enemy.health_scale * health_factor(elapsed)


func health_factor(elapsed: float) -> float:
	return 1.0 + zombie_health_growth * ramp(elapsed)


func zombie_contact_damage(enemy: EnemyData) -> float:
	return enemy.contact_damage * zombie_damage_multiplier


## XP for killing this zombie type if it appeared at this point of the run.
func zombie_xp(enemy: EnemyData, elapsed: float) -> float:
	return xp_per_standard_kill * enemy.xp * (1.0 + zombie_health_growth * ramp(elapsed) * xp_health_credit)


# --- Amounts and mix --------------------------------------------------------

## Waiting world zombies per 1000 m2 at this point of the run.
func world_density(elapsed: float) -> float:
	return lerpf(world_density_start, world_density_end, ramp(elapsed))


## Highest density the run reaches; the world is planned at this density and thinned out early on.
func world_density_max() -> float:
	return maxf(world_density_start, world_density_end)


## Fraction (0..1) of the planned world zombies that exist at this point of the run, times a platform scale.
func world_density_fraction(elapsed: float, population_scale: float = 1.0) -> float:
	var peak: float = world_density_max()
	if peak <= 0.0:
		return 0.0
	return clampf(world_density(elapsed) * population_scale / peak, 0.0, 1.0)


func trickle_alive(elapsed: float) -> int:
	return roundi(lerpf(trickle_alive_start, trickle_alive_end, ramp(elapsed)))


## Share (0..1) of new zombies that are armoured at this point of the run.
func elite_share(elapsed: float) -> float:
	return _share(elapsed, elite_start_seconds, elite_share_start, elite_share_end)


## Share (0..1) of new zombies that are bosses at this point of the run.
func boss_share(elapsed: float) -> float:
	return _share(elapsed, boss_start_seconds, boss_share_start, boss_share_end)


func _share(elapsed: float, from_seconds: float, at_start: float, at_end: float) -> float:
	if elapsed < from_seconds:
		return 0.0
	var span: float = maxf(ramp_seconds - from_seconds, 1.0)
	return lerpf(at_start, at_end, clampf((elapsed - from_seconds) / span, 0.0, 1.0))
