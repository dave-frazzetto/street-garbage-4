---
type: Architecture Decision Record
title: Directional locomotion from angle-smoothed blend spaces
description: Player legs mix forward, backward and strafe clips in two 2D blend spaces driven by the movement angle relative to the facing, turned at a capped rate so reversals sweep through a strafe; clips are Meshy library and text-to-motion output with root motion stripped.
tags: []
generated:
  by: arkouda/0.8.0
  at: 2026-11-22T21:29:20Z
status: draft
lifecycle: accepted
deciders: []
---

# Directional locomotion from angle-smoothed blend spaces

## Status

Accepted

## Context

The survivor always faces the aim direction but her legs played one forward walk or run clip, so moving left while aiming right
looked like a moonwalk (PRD slice-18-directional-locomotion). The art comes from Meshy (ADR generated-3d-art-with-meshy), whose
animation library has a plain backward walk but no upright strafe clips, and the player is a twin-stick character whose movement
and aim are independent (ADR unified-player-input-component).

## Decision

- **Maths is node-free.** `LocomotionBlend` turns a world velocity and the model's facing into a direction (x right, y forward),
  turns it toward the target by at most `LocomotionProfile.turn_rate_degrees` along the shortest arc, and maps it onto the
  diamond of a 2D blend space. A reversal therefore sweeps through a strafe pose instead of crossing the middle of the space,
  where forward and backward clips would be mixed with their feet out of step. While the legs are idle the direction snaps, so a
  start from standing never sweeps.
- **Two `AnimationNodeBlendSpace2D`s** (walk and run) sit inside the existing `AnimationTree`, each with forward, back, left and
  right clips at the corners; `PlayerModel` still owns all animation and `Player` only passes its velocity. The upper-body shoot
  overlay and the walk/run hysteresis added by hold-to-sprint are unchanged. A missing directional clip falls back to the forward
  clip.
- **Feet do not slide by reference speeds, not by phase matching.** `LocomotionProfile` (a `.tres`) holds the ground speed of
  each clip; playback speed is ground speed divided by the clip speeds weighted by what the blend space plays. Clips of
  different lengths are not phase matched; only two neighbouring clips are ever mixed, which keeps that unnoticeable.
- **Clips:** backward walk is a Meshy library action; strafe walks and all backward and strafe runs are Meshy text-to-motion
  clips applied to the player's rig. The library's only left walk is a deep stalking crouch, so it was not used. Text-to-motion
  output carries horizontal root motion, so `extract_clips.gd` strips it (`strip_root`) and prints the measured speed.
  About 67 Meshy credits were spent.

## Consequences

- Moving without firing now always shows a believable direction; the clips are placeholder quality (generated), and the run
  reference speeds of the generated clips are estimates from their root travel, so some foot slide remains. Re-measure and edit
  `data/config/player_locomotion.tres` when a clip is replaced; no code changes.
- A slower backpedal or strafe (a gameplay change, not an animation one) is not implemented: the legs play the backward clip at
  the real ground speed.
- Source GLBs from Meshy are not committed (tasks expire after 3 days); `extract_clips.gd` skips rows whose source is gone and
  whose output exists.
- Adds 6 small clip resources and two blend spaces; the contact sheets are produced by `tests/locomotion_preview.tscn` and
  `tests/player_directions_preview.tscn` (windowed).
- Tests: `test_locomotion` (maths, profile, model direction, no snapping, fallback) joins the headless suite.
