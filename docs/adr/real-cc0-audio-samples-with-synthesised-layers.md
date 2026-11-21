---
type: Architecture Decision Record
title: Real CC0 audio samples with synthesised layers
description: Gunshots, zombie voices, explosions and footsteps are processed CC0 recordings with synth layers; ambience is synthesised; sources in audio/CREDITS.md.
tags: [audio]
generated:
  by: arkouda/0.8.0
  at: 2026-11-21T18:09:39Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Real CC0 audio samples with synthesised layers

## Status

Accepted

## Context

The sfxr-style sounds felt thin and artificial next to the game's intensity (supersedes the sound choice of ADR 12 for weapons, zombies, explosions and footsteps).

## Decision

Gunshots, zombie voices, explosions and footsteps are processed CC0 recordings with synthesised punch layers, committed as small WAVs; city ambience is synthesised. Sources and licences are in audio/CREDITS.md and scripts/sfx/process_real_samples.py. Footsteps (FootstepStepper), zombie groans (ZombieGroaner) and the ambient bed (AmbientPlayer) are small nodes wired by GameFlow.

## Consequences

About 4 MB added. Footsteps are subway recordings, not asphalt. Sounds are not positional. The mix was only checked numerically, so judge it by ear.
