---
type: Architecture Decision Record
title: Lazy horde activation and far zombie despawn
description: Hordes are data instantiated only near the player with hysteresis; far ambient zombies are freed and respawned near the player.
tags: [performance]
generated:
  by: arkouda/0.8.0
  at: 2026-11-21T18:09:39Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Lazy horde activation and far zombie despawn

## Status

Accepted

## Context

Every horde zombie was instanced at level start and ambient zombies far away were teleported forever, costing nodes and physics time.

## Decision

HordeSpawner keeps its horde as data and instances a zombie only within activation_radius, freeing it beyond deactivation_radius (hysteresis, checked every 0.25 s, at most 10 wake-ups per check). The director frees ambient zombies beyond despawn_distance and respawns near the player. Distant zombies also pause animation (animation_cull_distance) and corpses are capped.

## Consequences

Headless measurement with 200+ zombies: about 11% fewer objects and about 10% less physics time. Tests must not assume hordes exist far from the player. Draw-distance culling was skipped because camera frustum culling already covers it.
