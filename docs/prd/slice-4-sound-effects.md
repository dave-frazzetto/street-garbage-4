---
type: Product Requirements Document
title: Slice 4 sound effects
description: Give every gameplay event a placeholder sound effect so the run can be played with audio.
tags: [audio]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T17:34:51Z
status: stable
lifecycle: shipped
owner: [claude]
decisions:
  - procedural-sound-effects-with-sfxr-style-generator
  - feature-folder-module-layout
---

# Slice 4 sound effects

## Status

Shipped

## Problem

The run is playable but silent. Shooting, killing, getting hurt and picking things up give no audio feedback, so the game
is hard to judge and does not feel like the original. Audio may be placeholder, but every event needs a sound.

## Approach

Generate the sounds procedurally (see the linked ADR), describe each event as an `SfxCue` resource, and let `GameFlow`
translate level and rules events into cues played by one `SfxPlayer`.

## Requirements

- Each weapon plays its own shot sound; shots vary in clip and pitch so automatic fire does not sound mechanical.
- Sounds exist for: zombie hit, zombie death, player hurt, explosive and non-explosive prop destruction, gear pickup,
  health pickup, level-up, perk pick / redraw / skip, run start, extraction denied, extracted, killed and nuked.
- Rapid events (hits, deaths) are rate-limited per cue so a shotgun volley does not stack into noise.
- Sounds keep playing while the game is paused for the perk screen.
- A designer can change volume, pitch variance, rate limit and clips, or silence an event, from the Inspector with no code
  change; a new weapon gets a sound via `WeaponData.fire_sound`.
- The generator re-creates every WAV deterministically with one command.
- Modules stay decoupled: the level only emits signals, `GameFlow` maps them to sounds, and the level still runs alone.
- A headless test verifies every cue has audible, non-clipping clips and that each game event triggers its cue.

## Non-Goals

- Music, ambient loops, zombie groans or footsteps.
- Positional (3D) audio and audio buses or a volume settings menu.
- Realistic or recorded sound quality.

## Success Metrics

- `tests/test_audio.tscn` passes (all cues filled and audible, every listed event triggers its cue) and the existing test
  scenes stay green.
- The game runs windowed with the real audio driver without errors.
- The owner can hear a distinct sound for each event and rebalance volumes without touching code.

## Open Questions

- Do the synth presets sound right to the owner? They were tuned by design intent only; expect a tuning round.
- Should zombie groans or low-time warnings come next, and should a volume option be added to the menu?
