---
type: Architecture Decision Record
title: GPU particle effects with shader-driven look, desktop first
description: All VFX are GPUParticles3D with three shared spatial shaders (noise puff, velocity streak, ground ring); desktop quality is the target, web keeps working on gl_compatibility.
tags: [vfx, rendering, shaders]
generated:
  by: arkouda/0.8.0
  at: 2026-11-22T20:48:02Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# GPU particle effects with shader-driven look, desktop first

## Status

Accepted

## Context

The CPUParticles3D effects (ADR 22) were chosen to be safe on web and phones. They looked flat: round soft discs, dull
additive fire, needle-thin sparks, and every particle faded in the same smooth way. The project now targets the
desktop build first. `GPUParticles3D` also runs on the `gl_compatibility` renderer, so the web export keeps working
without a renderer change (the mobile profile still removes shadows and glow, see ADR 14). Sub-emitters, particle
collision and attractors are not available there, so effects rely only on what Compatibility supports.

## Decision

- Every effect is a `GPUParticles3D` (`VfxBurst`) with a `ParticleProcessMaterial` for motion, a colour ramp and a
  scale curve, drawing a quad with a `ShaderMaterial` in `world/effects/shared/`:
  - `fx_blob.gdshader`: camera-facing puff for fire, smoke, flash and embers. Scrolling noise erodes it as it ages;
    `additive` slides it between adding light and alpha blending; `stretch_y` makes flame tongues; a depth-texture
    fade (`soft_distance`) stops puffs slicing into the ground.
  - `fx_streak.gdshader`: velocity-stretched streak for sparks, blood drops and bullet hits (Process Material
    "Align Y"), recoloured per bullet through the `tint` uniform.
  - `fx_ring.gdshader`: expanding ground ring for the explosion shockwave.
- Looks are Resources: one `mat_*.tres` per kind of fire, smoke, spark and so on, tuned in the Inspector.
- The Process Material is shared by every instance of a scene, so `VfxBurst.params()` duplicates it before an instance
  is aimed (`aim`) or scaled (`scale_by`). Nothing mutates the shared Resource.
- Effects set `visibility_aabb` by hand (GPU particles cull on it) and `fixed_fps = 60`. Looping fires are
  pre-processed so they start full.
- `tests/vfx_preview.tscn` renders the effects windowed on a lit stage and saves screenshots to `tests/output/`.

## Consequences

- Fire, smoke, explosions and blood read much better, at the same particle counts (about 80 for an explosion).
- Particle simulation moves off the CPU; the first use of each effect compiles its shader, which can hitch once.
  Prewarming effects at level load is not done yet.
- Soft depth needs the depth texture. It works on Compatibility desktop; it is untested on the web and mobile builds.
- Sub-emitters, trails and particle collision are not used. They would need the Forward+ or Mobile renderer, which is a
  separate decision.
- Supersedes ADR 22 (the CPU particle choice). The EffectSpawner cap and the `Zombie.damaged` signal contract stay.
