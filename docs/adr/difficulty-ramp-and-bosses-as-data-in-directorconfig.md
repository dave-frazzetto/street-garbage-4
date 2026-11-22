---
type: Architecture Decision Record
title: Difficulty ramp and bosses as data in DirectorConfig
description: Node-free ramp functions for count, speed and health, plus boss as EnemyData.size_scale 1.2 and spawn-table weights, no boss-specific code.
tags: [gameplay]
generated:
  by: arkouda/0.8.0
  at: 2026-11-21T18:09:39Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Difficulty ramp and bosses as data in DirectorConfig

## Status

Accepted

## Context

The game was too easy and had no escalation.

## Decision

DirectorConfig holds node-free ramp functions (max_alive_at, batch_at, interval_at, speed_multiplier, health_multiplier) injected into Zombie before _ready, so EnemyData is never mutated. A boss is plain data: EnemyData.size_scale 1.2 (model, collision, health bar), max_alive, always_show_health_bar, and SpawnEntry.weight_at_full_ramp for its frequency over time.

## Consequences

Designers retune pressure and bosses in director_default.tres and boss.tres. Ramps apply at spawn only, not to zombies already alive. First-minute fairness was not hand-played yet.

Update: the ramp functions and numbers described here were superseded by ADR 25 (GameTuning); the boss-as-data idea still stands.
