---
type: Architecture Decision Record
title: Bullet hits go through a zombie hurtbox layer
description: Bullets query a separate hurtbox Area3D on physics layer 8 sized from EnemyData.radius plus a forgiveness margin, leaving movement collision untouched.
tags: [combat]
generated:
  by: arkouda/0.8.0
  at: 2026-11-21T18:09:38Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Bullet hits go through a zombie hurtbox layer

## Status

Accepted

## Context

Bullets had to pass through the thin movement cylinder of a zombie, so players needed pixel-precise aim.

## Decision

Each zombie has a ZombieHurtbox (Area3D, physics layer 8, no mask) whose cylinder is EnemyData.radius plus a tunable hit_forgiveness (0.3 m). Bullets ray-query world plus layer 8 only. Zombie movement and contact collision are unchanged.

## Consequences

Hit feel is tunable in the Inspector and scales with boss size. Anything that changes data.radius after spawn must call Hurtbox.refresh(). Impact sparks land up to 0.3 m in front of the body.
