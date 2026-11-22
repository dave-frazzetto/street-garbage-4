---
type: Architecture Decision Record
title: 'Survival-style combat: rooted shooting, hitscan line, tougher zombies'
description: Shooting roots the player, bullets are instant lines of light, zombies are fewer but tougher and flinch when hit; phones get a population scale.
tags: [gameplay, performance]
generated:
  by: arkouda/0.8.0
  at: 2026-11-21T18:30:59Z
status: stable
lifecycle: accepted
deciders: [owner, claude]
---

# Survival-style combat: rooted shooting, hitscan line, tougher zombies

## Status

Accepted

## Context

Playtesting showed too many weak zombies (a performance risk on phones) and fast run-and-gun play. The owner asked for a survival, old Resident Evil feel: fewer, more dangerous zombies, and shooting that costs mobility.

## Decision

Firing roots the player (PlayerConfig.firing_move_multiplier = 0, aiming still works). Bullets are hitscan: the whole path is resolved on the first physics frame and drawn as one static line of light from the muzzle to the first hit or the end of range, fading in 0.12 s. Weapons fire about half as often and hit about 2.5x harder. Walkers have 60 HP (armoured 180, boss 700), the director allows 24 to 70 zombies instead of 70 to 260, hordes are smaller, and GraphicsProfile.zombie_population_scale (0.6 on mobile) lowers the cap further. A hit makes a zombie stagger (Zombie.hit_stun_seconds, EnemyData.stagger_resistance), tilt away from the shot (ZombieModel.play_hit) and be knocked back further.

## Consequences

Fewer nodes and physics bodies, so better frame time on mobile, and each kill takes deliberate shots. Danger rises because the player cannot kite while shooting. Bullets no longer travel, so weapon bullet_speed and beam_length were removed from WeaponData. Balance (kill time, damage taken) has been tested by numbers only and needs hand playing.

Update: the zombie speed, health and population numbers were superseded by ADR 26 (GameTuning) and ADR 27 (world-anchored population).
