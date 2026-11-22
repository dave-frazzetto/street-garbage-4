---
type: Architecture Decision Record
title: Central GameTuning resource for the main balance knobs
description: One Resource holds the numbers a designer tunes (speeds, zombie health, amounts, mix, bosses, XP per kill); DirectorConfig, EnemyData and PlayerConfig keep per-type shapes and are scaled by it.
tags: [gameplay, data]
generated:
  by: arkouda/0.8.0
  at: 2026-11-22T09:16:47Z
status: stable
lifecycle: accepted
deciders: [owner, claude]
---

# Central GameTuning resource for the main balance knobs

## Status

Accepted

## Context

Playtesting showed zombies were not a threat: the player walked at 5.25 m/s against zombies at 1.75 m/s (about 1.4 to 3 m/s with the ramp), so circling and outrunning were trivial. Pressure numbers were spread over PlayerConfig (speeds, stamina), DirectorConfig (ramps, population, ramp multipliers), EnemyData (absolute health, speed, XP) and RunConfig, and a designer could not see how they relate. The owner asked for the main numbers (standard zombie amount and ratios, zombies over time, bosses over time, player and zombie speed, zombie health, XP per kill) to be tunable in one place and explained. The original game gives no numbers; the research (docs/reference/tuning-guide.md) infers zombies slightly slower than a walking player, sprint limited by stamina, a dense street and one rare giant.

## Decision

A new Resource `GameTuning` (data/config/game_tuning.gd, default data/config/game_tuning.tres) holds the main knobs in groups: pacing (ramp seconds), player movement (walk speed, sprint multiplier, seconds of sprint, recharge seconds), zombie movement (speed as a ratio of the player's walk speed, speed growth, intercept, aggro and gunfire-alert radii), zombie health and damage, zombie amounts (world density, trickle, respawn, start safe radius), zombie mix (armoured and boss share over time) and experience (XP per standard kill). All derived numbers are pure functions on the resource, so they are unit tested without nodes. EnemyData is now relative to a standard zombie (health_scale, speed_scale, xp weight, and a tier), SpawnEntry weights only choose inside a tier, and DirectorConfig lost its ramp multipliers and alive caps. PlayerConfig lost move_speed, sprint_bonus, stamina_drain and stamina_regen; PlayerConfig.to_base_stats(tuning) derives them. GameFlow injects the resource into PlayerStats, the level, the director, the population and every horde; scenes that run alone fall back to GameTuning.fallback(). The resource is never mutated at runtime; zombies read it once when they appear. This refines ADR 19 (ramp and bosses) and ADR 24 (zombie numbers): their numbers now live here. Defaults: player 4.4 m/s walking, 1.5x sprint for 6 s, 6.5 s recharge; standard zombie 0.85x the walking speed (about 3.7 m/s, up to 20% faster by the end of a run), 100 HP (four pistol shots, up to 50% more by the end), 1.5 XP per kill, bosses 1 to 3% of new zombies from minute 8. Contact damage was lowered after a simulated playthrough showed a standing player dying about 6 s after the first contact (standard zombie 6 per second, armoured 10, boss 20 per 0.8 s) and the player regenerates 0.5 HP/s after 5 s without damage (GameTuning.calm_regen_*). The XP curve in RunConfig was raised to 7 XP for level 2 (growth 1.15, flat 3) so a level comes every 30 to 70 s.

## Consequences

One file to tune and one guide (docs/reference/tuning-guide.md) to read; speed ratios stay valid when the player speed changes. Perks that raise player speed still help because zombie speed follows the base walking speed only, not perk bonuses. Breaking change: PlayerConfig fields and DirectorConfig ramp fields were removed, EnemyData.max_health and speed became health_scale and speed_scale, Zombie.speed_multiplier and health_multiplier were replaced by Zombie.setup(..., tuning, elapsed). The numbers are inferred from guides, not measured from the original, and have been checked by numbers and headless simulation only; they need hand playing.
