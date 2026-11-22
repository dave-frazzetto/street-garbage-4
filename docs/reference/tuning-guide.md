# Tuning guide: zombie pressure, speeds, health and XP

All the main balance numbers are in one file: `data/config/game_tuning.tres` (script `data/config/game_tuning.gd`).
Open it in the Godot Inspector; every value has a tooltip and a safe range. The values in the script are the shipped
defaults, so a `.tres` with no overrides means "defaults". Nothing else needs a code change.

Detail layers, only touched for new content:

| File | What it holds |
|---|---|
| `data/enemies/*.tres` (`EnemyData`) | One zombie type: tier, health/speed/XP **relative to a standard zombie**, armour, contact damage, size |
| `data/config/director_default.tres` (`DirectorConfig`) | Which types can spawn (weights inside a tier), top-up wave pacing, spawn/despawn distances, wake/sleep radii |
| `data/config/player_default.tres` (`PlayerConfig`) | Health, stamina bar size, pickups. Speeds and sprint time come from `game_tuning.tres` |
| `data/config/run_default.tres` (`RunConfig`) | Run length, gears, the XP cost of each level |

## What the original game gives us

The original is a GTA VI minigame and no source publishes numbers, so the defaults are inferred from guides and the
reference video (see `original-game-video-notes.md`):

- Zombies chase through the streets, hordes are something you avoid while searching for gears, and the rooftop at the
  end is a dense, escalating horde.
- Guides say "run in circles and only sprint to avoid damage" and "kite", and recommend the speed and stamina perks. So
  zombies must be close to the player's walking speed, with stamina-limited sprint as a burst that opens a gap.
- One giant gear-carrying mutant appears late (after four or five gears) and "can withstand substantial damage".
- A run reaches about level 17 in 18 minutes.

## The parameters

### Pacing

| Parameter | Default | Meaning |
|---|---|---|
| `ramp_seconds` | 900 | Every "start / end" pair below moves linearly from start to end over this many seconds, then stays at end. The run lasts 1080 s, so the last 3 minutes are at full pressure. |

The shipped `game_tuning.tres` overrides three defaults by hand (the current design, tuned in play):
`player_walk_speed` 2.3 m/s (sprint 3.45 m/s), `zombie_speed_ratio` 0.56 (a standard zombie walks 1.29 m/s at the start,
the fastest late one about 1.78 m/s, so walking away works) and `xp_per_standard_kill` 2.0. The tables give the script
defaults; the examples in "How the parameters interact" use the defaults unless they say otherwise.

### Player movement

Sprint is **held**: the player sprints while Shift (gamepad LB or L3) is held and stamina remains, and walks as soon as it
is released. When the bar runs dry the sprint ends and the button must be released and held again (the "sprint" action in
the Input Map). A sprint starts only with more than `min_sprint_stamina` (15%) of the bar, so a held key on an almost empty
bar does not flick sprint on and off. Touch play has no sprint button: on phones the player walks only.

| Parameter | Default | Meaning |
|---|---|---|
| `player_walk_speed` | 4.4 m/s | Walking speed. Zombie speed is a ratio of this. |
| `sprint_speed_multiplier` | 1.5 | Sprint speed = walk x this (6.6 m/s at the default, 3.45 m/s in the shipped file). |
| `sprint_seconds` | 6 s | How long a full stamina bar lasts. |
| `min_sprint_stamina` | 0.15 | Share of the stamina bar needed to start a sprint (a sprint already running lasts until the bar is empty). |
| `stamina_recharge_seconds` | 6.5 s | Time to refill an empty bar (plus a 0.6 s delay set on the stamina component). Keep it above `sprint_seconds` or sprinting becomes a permanent state; `test_tuning` checks it. |

### Characters

| Parameter | Default | Meaning |
|---|---|---|
| `character_scale` | 1.15 | Size of the player and every zombie relative to the generated models. Collision bodies (`EnemyData.radius` x this), bullet hurtboxes, health bars, the gun in the hand and the leg animation all follow. Bullets keep flying at 1.0 m (the `Weapon` node's height in `player.tscn`, in world units, not scaled) so they still hit props sized in metres, such as the 1 m fire barrels. A boss keeps its `EnemyData.size_scale` (1.2) on top, so it is 1.38 x the model. Bigger zombies are easier to hit and fill a street sooner. |

### Zombie movement

| Parameter | Default | Meaning |
|---|---|---|
| `zombie_speed_ratio` | 0.85 | A standard zombie's speed as a fraction of the player's **walking** speed (3.74 m/s). Each zombie varies it by `EnemyData.speed_variance` (15%, so 3.2 to 4.3 m/s). |
| `zombie_speed_growth` | 0.2 | Extra speed at the end of the ramp (4.5 m/s average, up to 5.2 m/s). Fixed when a zombie appears. |
| `zombie_intercept` | 0.6 | How far ahead of a moving player zombies aim (0 = straight at you, 1 = full interception). Each zombie uses 50 to 100% of it, so a crowd fans out. |
| `zombie_aggro_radius` | 18 m | Idle (world) zombies start chasing inside this distance. A zombie stays aware once it has noticed you. |
| `gunfire_alert_radius` | 24 m | Every shot wakes idle zombies inside this distance of the player. |

### Zombie health and damage

| Parameter | Default | Meaning |
|---|---|---|
| `zombie_health` | 100 | Health of a standard zombie at the start. The pistol does 28, so 4 shots (2.5 s of rooted shooting). |
| `zombie_health_growth` | 0.5 | Extra health at the end of the ramp (150 HP = 6 pistol shots before damage perks). |
| `zombie_damage_multiplier` | 1.0 | Scales all contact damage. Base per type is in `EnemyData` (table below): a standard zombie does 6 per second (6 per 1.0 s), an armoured one 12.5 per second (10 per 0.8 s), a boss 25 per second (20 per 0.8 s). The player is also immune for 0.25 s after a hit, so a crowd cannot do more than 4 hits per second. |

### Player recovery

| Parameter | Default | Meaning |
|---|---|---|
| `calm_regen_delay` | 5 s | Seconds without taking damage before the player starts to heal. |
| `calm_regen_per_second` | 0.5 | Health per second while calm (100 HP in 200 s). Perks that add Health Regen stack on top and work all the time. Health pickups drop with `PlayerConfig.health_drop_chance` (6%). |

### Zombie amounts

| Parameter | Default | Meaning |
|---|---|---|
| `world_density_start` / `_end` | 1.2 / 6.0 | Zombies waiting in the world per 1000 m2 of map. The 120 m map is 14.4 thousand m2, so 17 planned zombies at the start and 86 at the end of the ramp. A player in open ground has about 4 to 6 of them within the wake radius early and 25 or more late. |
| `trickle_alive_start` / `_end` | 4 / 12 | Extra chasers the director keeps coming from just off-screen. They refill cleared areas and keep pressure while you move. |
| `respawn_seconds` | 150 | A killed world zombie comes back at its place after this long, only while you are farther than 50 m away (0 = never). |
| `start_safe_radius` | 16 m | No world zombies are planned this close to the player start. |

How the world population works: the map is planned once, from the run seed, as fixed zombie places (`PopulationGrid`).
A place becomes a real zombie only when you are within `DirectorConfig.horde_activation_radius` (40 m) and goes back to
data when you are beyond `horde_deactivation_radius` (50 m). Density over time works by waking more of the same
places, not by inventing new ones, so the same seed always gives the same streets. `GraphicsProfile.zombie_population_scale`
(0.6 on phones) multiplies both the world density and the trickle.

### Zombie mix

| Parameter | Default | Meaning |
|---|---|---|
| `elite_start_seconds` | 120 | Armoured zombies appear from here. |
| `elite_share_start` / `_end` | 0.05 / 0.30 | Share of new zombies (bosses aside) that are armoured, at their start and at the end of the ramp. |
| `boss_start_seconds` | 480 | Bosses appear from here (the original's giant shows up around four or five gears). |
| `boss_share_start` / `_end` | 0.01 / 0.03 | Share of **all** new zombies that are bosses (1% at minute 8, 3% at the end of the ramp). At most `EnemyData.max_alive` (2) exist at once. |

A "new zombie" is a world place waking up or a trickle spawn: every time a place wakes it rolls its type again against the current run time, so the mix follows the ramp even for places that were visited early. Standard zombies are what is left over.
Which armoured or boss type is used comes from the weights in the spawn table (`director_default.tres`), so adding a
second armoured variant is a new `EnemyData` with tier Elite and a new row there.

### Zombie types

The per-type numbers are relative to a standard zombie and live in `data/enemies/*.tres` (`EnemyData`). Absolute values
come from multiplying with `GameTuning`, shown here at the start of the run.

| | Walker | Armoured | Boss |
|---|---|---|---|
| `tier` | standard | elite | boss |
| `health_scale` (HP) | 1 (100) | 2 (200) | 12 (1200) |
| `speed_scale` (m/s) | 1 (3.74) | 0.85 (3.2) | 0.75 (2.8) |
| `contact_damage` per `attack_interval` | 6 per 1.0 s | 10 per 0.8 s | 20 per 0.8 s |
| `armour` | 0 | 0.30 | 0.15 |
| `stagger_resistance` | 0 | 0 | 0.6 |
| `xp` (XP at the start) | 1 (1.5) | 3 (4.5) | 12 (18) |
| `speed_variance` | 0.15 | 0.15 | 0.15 |
| `max_alive` | no limit | no limit | 2 |

### Experience

| Parameter | Default | Meaning |
|---|---|---|
| `xp_per_standard_kill` | 1.5 | XP of one standard kill. Armoured gives x3 (4.5), a boss x12 (18) through `EnemyData.xp`. |
| `xp_health_credit` | 1.0 | How much of the health growth is paid back as XP. At 1 a zombie 50% tougher gives 50% more XP, so XP per hit point stays constant. |

The cost of reaching level L+1 is in `run_default.tres`: `xp_first_level * xp_growth^(L-1) + xp_flat_increase * (L-1)` (7 XP,
growth 1.15, flat 3: 7, 11, 15, 20, 24, 29 ...). A
player who kills one zombie every 5 s gets level 2 after about 30 to 35 s, a level every 50 to 70 s after that and about 16
levels in a full run. `tests/test_tuning.gd` simulates this and fails if the pace leaves 12 to 20 levels or level 2
comes before 20 s or after 45 s.

## Leg animation follows the speed

If you change the player's speeds or `character_scale`, the legs follow on their own. `PlayerModel` and `ZombieModel`
divide the ground speed by the model's scale (a bigger model takes longer strides), then play the walk clip at slow
speeds and the run clip at fast speeds, each at speed / reference so the planted foot stays still on the ground.

| Value (at model scale 1) | Player | Zombie | How it was measured |
|---|---|---|---|
| `walk_reference_speed` | 1.45 m/s | 1.45 m/s | Backward speed of the planted foot in the character's space, median over the stance (clips have no root motion) |
| `run_reference_speed` | 4.85 m/s | 4.85 m/s | Same; the run clip has a long stride, so a 3.45 m/s sprint at scale 1.15 plays it at about 0.62x |
| Walk to run | run above 2.9 m/s, walk below 2.7 m/s (`run_above_speed`, `walk_below_speed`) | switch at 2.7 m/s | Between the two speeds the legs keep the clip they have, so a steady speed always plays one clip: the clips are not phase matched and a blend of them slides. At scale 1.15 a plain walk is 2.0, a walk with four Fleet Foot 2.8 (in the band: it keeps the walk clip, or the run clip right after a sprint) and a sprint 3.0 m/s at scale 1. The walk clip looks right up to about 2x, the run clip down to about 0.55x |
| `cadence_soft_limit` | 2.0 | none | Above this playback the step rate grows at half rate and the feet slide on purpose. At 2.0 no reachable speed triggers it (the walk clip stops at 2.9 / 1.45 = 2x) |

The generated walk and run loops repeat their first pose for one frame; `CharacterModel.trim_held_first_frame` drops that
frame when the clip is installed (on a copy, the shared clip is not modified), so the planted foot does not stop for a frame
at every loop. `tests/test_player_model.gd` and `tests/test_zombie_model.gd` move the scaled models at the real speeds and
fail if a planted foot slides faster than 0.3 to 0.4 m/s (the old run reference of 3.5 slid about 1.5 m/s). If you swap a
character's clips, re-measure the references on the new clips (those tests print how fast the feet slide).

## How the parameters interact

- **Speed ratio decides whether outrunning works.** In the shipped file (0.56) every zombie is slower than a walking
  player, so the danger is numbers, getting cornered and standing still to shoot; a held sprint opens about 12 m in one
  burst. At the default 0.85 a zombie falls behind a walking player by about 0.7 m/s, but
  the random spread and the late growth let the fastest zombies catch a walking player after mid-run. Sprinting
  (1.5x) opens a gap of about 13 to 17 m in one 6 s burst (more early, less late) and then you wait 6.5 s to recharge. `zombie_speed_ratio x
  (1 + zombie_speed_growth)` near 1 means walking is no longer an escape; above `sprint_speed_multiplier` nothing is.
- **Perks.** Fleet Foot (+10% x4) and Double Sprint raise the player's speed over the base, but zombie speed follows
  the base walking speed only. At the defaults four Fleet Foots (6.2 m/s) outrun every zombie by a wide margin (`test_tuning` checks
  that they stay at least 10% faster than the fastest late zombie); if you want perks to matter less, raise `zombie_speed_ratio`.
- **Rooted shooting.** Shooting stops you. Time to kill a zombie = health / (28 x 1.6 shots/s), 2.5 s at the start. A
  zombie at 3.7 m/s covers 9 m in that time, so you can shoot only one or two zombies at their approach before you must
  walk or sprint away. Raise `zombie_health` or lower player damage and you shoot less and run more; the reverse gives a
  gunslinger feel.
- **Density vs health.** Pressure is roughly (zombies near you) x (seconds to kill each). Doubling health is similar to
  doubling density, but health makes single fights long and density makes them crowded. Prefer density for "surrounded"
  tension and health for "this one is dangerous".
- **Health vs XP.** Change `zombie_health` and `xp_per_standard_kill` together: XP per kill should scale with health
  or the level pace changes. The growth is credited automatically through `xp_health_credit`.
- **Boss share vs boss cap.** A boss is a 1200 HP, 15%-armoured target (about 50 pistol shots). Even a 1% share is
  noticeable; `max_alive` stops two bosses from stacking.
- **Damage vs recovery.** The balance target is a standing, non-shooting player who survives about 15 to 20 s after the
  first zombie reaches them at the start of the run (measured at the defaults: first contact at about 6 s, dead at about
  23 s; with the shipped slower zombies the first one walks in from off-screen after about 17 s), and
  about 6 to 8 s late in the run. Standing still is not meant to work; the player is meant to move, shoot in short bursts
  and heal in the calm (0.5 HP/s after 5 s). Raise `calm_regen_per_second` or lower contact damage to forgive mistakes.
- **Walls.** Chasers steer straight at you; one that gets pinned against a wall walks along it, always round the same
  way, until it sees you again or has walked `wall_follow_distance` (15 m, a distance so slow zombies still reach the
  corner of a building; `Zombie` export group "Getting around walls"). There is no navigation mesh, so very winding streets can still
  hold a zombie for a while, but camping behind a building no longer removes the pressure.
- **World vs trickle.** World density gives a street that feels inhabited and is always where you run; trickle is the
  pressure that follows you. Few world zombies and a big trickle feel like a chase; many world zombies and no trickle
  feel like a walk through a graveyard where you choose your fights.

## Recipes

| Goal | Change |
|---|---|
| Harder overall | `zombie_speed_ratio` 0.95, `zombie_intercept` 0.8, `trickle_alive_end` 20 |
| Make it impossible to walk away | `zombie_speed_ratio` 1.0 (sprint still outruns them) |
| Easier early game | `world_density_start` 0.8, `trickle_alive_start` 2, `zombie_health` 80 (and `xp_per_standard_kill` 1.2), or `calm_regen_per_second` 1 |
| Power fantasy | `zombie_health` 60, `xp_per_standard_kill` 1.0, `world_density_end` 12, `trickle_alive_end` 30, `zombie_speed_ratio` 0.6 |
| Run-and-gun instead of rooted | `PlayerConfig.firing_move_multiplier` 0.5, raise `zombie_speed_ratio` to 0.95 to compensate |
| More levels | `xp_per_standard_kill` 2.0 (or lower `xp_first_level` in `run_default.tres`) |
| Fewer levels | `xp_per_standard_kill` 1.0 |
| Boss-heavy | `boss_start_seconds` 240, `boss_share_end` 0.04, raise `max_alive` in `boss.tres` |
| No bosses | `boss_share_start` and `boss_share_end` 0 |
| Performance on weak devices | Lower `world_density_end` and `trickle_alive_end`; `zombie_population_scale` in the graphics profile does this for phones; lower `horde_activation_radius` in `director_default.tres` |
| Empty map worry | Keep `world_density_start` x map area / 1000 above about 15 and `start_safe_radius` below 25 m; `tests/test_pressure.gd` checks that a sprinting player always has zombies near |
| No respawns | `respawn_seconds` 0 |

## Checking a change

```sh
tests/run_tests.sh          # whole suite (about a minute)
godot --headless --path . res://tests/test_tuning.tscn                  # numbers: speed ratio, XP pace, density, mix
godot --headless --fixed-fps 60 --path . res://tests/test_pressure.tscn # standing player hurt, running never empty, chasers get round walls, regeneration
# (always pass --fixed-fps 60 to test_pressure: without it the scene runs in real time and takes about 100 s)
```

`test_tuning` fails when a change breaks the intent of the numbers (an average zombie faster than a walking player or slower
than 45% of it, zombies that cannot close in on a player who stops to shoot, late zombies not clearly faster than early ones,
a sprint that opens less than 5 m or more than 25 m, level 2 outside 20 to 45 s, a boss share above 3%, an
empty street along the test routes, a late mix that drifts from the shares, a zombie that sleeps where the grid cannot find it). If you change the intent on purpose, update the thresholds in the test and this
guide together. The numbers are inferred, not measured from the original, so playtest after any large change.
