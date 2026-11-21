---
type: Architecture Decision Record
title: CPUParticles3D effects with capped effect spawner
description: All VFX are CPUParticles3D scenes limited per kind by an EffectSpawner; Zombie.damaged signal is the hit-VFX contract.
tags: [vfx]
generated:
  by: arkouda/0.8.0
  at: 2026-11-21T18:09:39Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# CPUParticles3D effects with capped effect spawner

## Status

Accepted

## Context

The game lacked blood, explosion and fire effects, and Meshy cannot generate particle VFX.

## Decision

All effects are CPUParticles3D scenes with generated soft textures and tunable exports (web and mobile safe). Zombie emits damaged(at, direction, amount); Level decides what to spawn through an EffectSpawner that caps live effects per kind. Looping fires pause off screen.

## Consequences

Zombie stays free of effects code. About 300 particles come from the level's fires. Per-effect point lights are not pooled.
