---
type: Architecture Decision Record
title: Procedural sound effects with sfxr-style generator
description: Sound effects are synthesised by a deterministic sfxr-style Python script into WAV files, played through designer-tunable SfxCue resources.
tags: [audio]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T17:34:51Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Procedural sound effects with sfxr-style generator

## Status

Accepted

## Context

The project goal allows placeholder audio, but a game with no sound is hard to judge: shots, hits and pickups carry a lot
of the feel. The owner asked whether generated audio services exist and then asked for a non-AI route that needs no
account, credit or licence check. Free sfxr-family tools (jsfxr, Bfxr) are interactive web or desktop apps, which an
agent cannot drive reliably, and downloaded packs bring licence terms to track. Git history and the web build both
favour small, reproducible, text-reviewable inputs.

## Decision

Synthesise the effects ourselves with a classic sfxr-style synth and play them through data-driven cues.

- `scripts/sfx/generate_sfx.py` (Python standard library only) holds one preset per effect (layered sfxr voices with
  timings in seconds) and renders mono 16-bit 44.1 kHz WAVs into `audio/sfx/`. Seeds are fixed, so output is
  byte-identical on every run. Effects with variants (shots, hits, deaths, explosions) render three mutated takes.
- `SfxCue` (Resource) holds the clips to pick from, volume in dB, pitch variance and a minimum interval. `SfxBank`
  (Resource) has one typed slot per non-weapon event. `WeaponData.fire_sound` carries each gun's cue, so a designer
  gives a new weapon a sound in the Inspector.
- `SfxPlayer` (scene in `audio/`) owns a pool of 16 `AudioStreamPlayer` voices, rate-limits per cue using game time and keeps
  running while the tree is paused. It is non-positional because the isometric camera is far from the action.
- Modules stay decoupled: the level emits gameplay signals (`player_fired`, `zombie_hit`, `prop_destroyed`,
  `health_collected`), and `GameFlow` is the only place that maps events to cues.
- WAVs are committed. The generator is a developer tool; replacing any WAV or cue by hand needs no code change.

## Consequences

- No account, cost or third-party licence: the sounds are ours to ship, including on itch.io.
- The retro synth character is consistent but limited. Realistic gunshots or zombie voices would need recorded or
  AI-generated audio later; swapping is a WAV or cue change only.
- About 1 MB of WAV in git (Godot re-imports them as ADPCM for the build). Editor `.import` sidecars stay gitignored.
- The agent that wrote the presets cannot listen to them. Levels and pitches are set by design intent and checked by
  tests for length, audibility and clipping, but the owner must audition the result and tune the presets or cue volumes.
- Godot's headless clock is not wall time, so rate limiting counts game time; tests wait on matching timers.
- Positional audio, music and ambience are not covered and would be a later decision.
