---
type: Architecture Decision Record
title: Shader warm-up behind the loading screen
description: On the first run of a launch, ShaderWarmup draws every runtime effect, prop wreck and the whole map once while the tree is paused behind LOADING, removing first-use hitches.
tags: [performance, rendering]
generated:
  by: arkouda/0.8.0
  at: 2026-11-23T10:17:44Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Shader warm-up behind the loading screen

## Status

Accepted

## Context

The game felt laggy on a Windows desktop with an RTX 4070. A windowed benchmark of the real game
(`tests/benchmark_fps.tscn`, scripted play, 1440p fullscreen) showed the frame rate was never the problem: 450-590 FPS
without vsync in normal play, above 200 FPS in a stress run next to the helicopter horde with explosions (73 zombies),
and a locked 60 FPS with vsync. The lag was first-use hitches of 60-140 ms on a fresh shader cache: the Compatibility
renderer compiles each shader variant the first time it is drawn (first shot, first hit, first blood splat, first
explosion, first car wreck), and the first blood splat also generated its procedural splat textures in GDScript (88 ms).

## Decision

`Level.warm_shaders()` runs a `ShaderWarmup` scene (`world/effects/shader_warmup.tscn`) on the first run of each launch.
`GameFlow.start_run()` awaits it while the title's LOADING screen stays up, with the tree paused (the run timer does
not tick). The warm-up shows each `live_scenes` entry (effects, blood splat, car, fire barrel, zombie models; their
scripts run, so runtime materials and splat textures are created) and each `static_scenes` entry (bullet, pickups,
weapon models; scripts stripped because they need setup) in front of the gameplay camera with particles forced on,
destroys the props so their wreck/burning looks are drawn, then renders the whole map from an orthographic overview
camera. Skipped headless and on later runs (`ShaderWarmup.is_done()`). Unpauses if freed mid-way.

## Consequences

- Cold shader cache, stress benchmark: hitches over 50 ms went from 3 per run (up to 126 ms) to 0-1 (53 ms). With a
  warm cache (second launch) there were none either way.
- The first Start takes about 1.7 s behind LOADING on a cold cache (level build included).
- A new effect, prop or weapon model must be added to `shader_warmup.tscn`, or its first appearance may hitch again.
- `tests/benchmark_fps.tscn` (windowed, `--stress`, `--vsync`, `--no-warmup`, `--elapsed=`) is kept to re-measure.
