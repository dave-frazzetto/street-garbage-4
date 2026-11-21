---
type: Architecture Decision Record
title: Beam bullets drawn as fading stretched boxes
description: Bullets are ray-cast steppers with an unshaded fading beam box and exported impact scenes, cheap for mobile.
tags: [combat, vfx]
generated:
  by: arkouda/0.8.0
  at: 2026-11-21T18:09:38Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Beam bullets drawn as fading stretched boxes

## Status

Accepted

## Context

The small travelling tracer did not read as a bullet trajectory.

## Decision

A bullet stays a per-step ray-cast stepper; its visual is a top-level unshaded alpha box stretched from muzzle to the current point (beam_length) that lingers beam_fade_seconds after impact. Impact sparks come from exported impact_scene and zombie_impact_scene. Width and colour come from WeaponData.

## Consequences

Cheap on mobile and web (no lights, no ImmediateMesh). A spent bullet node lives about 0.18 s longer. A ricochet restarts the beam at the bounce point.
