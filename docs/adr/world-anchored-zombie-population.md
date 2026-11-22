---
type: Architecture Decision Record
title: World-anchored zombie population
description: Zombies are planned as data across the whole map from the run seed, wake near the player, sleep when far and respawn slowly; the director only tops up.
tags: [gameplay, performance]
generated:
  by: arkouda/0.8.0
  at: 2026-11-22T09:16:47Z
status: stable
lifecycle: accepted
deciders: [owner, claude]
---

# World-anchored zombie population

## Status

Accepted

## Context

Zombies came only from the director, a ring spawner that kept a capped number of chasers 24 to 28 m from the player, plus two fixed hordes. A player who outran the chasers (the player was three times faster) reached streets with no zombies until the ring caught up, so there was no challenge. The owner asked for zombies to exist where the player goes: already placed in the level and inactive until the player is near, then despawned when far. ADR 20 already keeps hordes as data with wake and sleep radii; this generalises that idea to the whole map.

## Decision

A node-free `PopulationGrid` (rules/population_grid.gd) plans the world as slots, filled lazily per 10 m cell from the run seed and the cell coordinates, at the highest density of the run (GameTuning.world_density_*, zombies per 1000 m2), leaving the start safe radius empty. Each slot has a random threshold; at run time t only slots whose threshold is below density(t)/density_max exist, so the density ramps up by waking more of the same planned slots (no flicker, deterministic). A `WorldPopulation` node (world/spawning/world_population.gd, in the level scene) checks every 0.25 s: slots within DirectorConfig.horde_activation_radius (40 m) become real zombies (at most 6 per check, nearest first, nudged off walls via a physics query), active ones beyond horde_deactivation_radius (50 m) are freed and remember where they stood. A slot picks its zombie type every time it wakes (the type is cleared when it sleeps or is refilled) from the spawn table, using the tier shares of GameTuning (standard, armoured, boss) and the EnemyData.max_alive caps counted over all live zombies. Woken zombies idle until the player is within zombie_aggro_radius or fires (every shot alerts idle zombies within gunfire_alert_radius, through Zombie.alert). A killed zombie leaves its slot dead and it is refilled after respawn_seconds only while the player is farther than the deactivation radius, so nothing pops in view. The director stays as a top-up: it keeps GameTuning.trickle_alive chasers coming from just off-screen and frees chasers far behind. Chasers pinned against a wall walk along it until the target is in sight again (Zombie wall following, no navigation mesh), because straight-line steering made them stand behind buildings for minutes. Zombies also aim ahead of a moving target (Zombie._chase_direction, GameTuning.zombie_intercept) so circling no longer works. HordeSpawner stays for authored set pieces and receives the same tuning.

## Consequences

Outrunning cannot leave an empty street: a headless test sprints along four lines across the map early and late and asserts zombies are always near, and the integration test asserts a standing player is hurt within 15 s. Only zombies near the player are nodes (about 20 to 60), so cost does not grow with map size; the grid fills cells only where the player goes. Dormant zombies that were chasing and fell behind wait where they stood, are re-filed into the grid cell of that place (otherwise they could not be found again) and wake when the player returns there. The planned world is small (about 17 to 86 zombies on the 120 m map) and relies on the trickle and slow respawn for long runs. Damage on a sleeping zombie is lost when it is freed, and awake zombies are not put back to sleep if the density later falls. Levels still do not author per-area densities in the editor; density is one global number and can later become a per-zone multiplier.
