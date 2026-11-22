---
type: Architecture Decision Record
title: One character scale for player and zombies
description: GameTuning.character_scale (1.15) sizes the player and every zombie with their bodies, hurtboxes and held weapon; models divide ground speed by their scale for foot-planted playback.
tags: [art, gameplay, animation]
generated:
  by: arkouda/0.8.0
  at: 2026-11-22T20:21:59Z
status: stable
lifecycle: accepted
deciders: [owner, claude]
---

# One character scale for player and zombies

## Status

Accepted

## Context

The generated player and zombie models looked too small in the isometric view, and the owner asked for all of them
(standard, armoured, boss) to be 15% larger. Size is not only looks: the player's collision radius sets zombie contact
range and blast range, a zombie's radius sets its body, bullet hurtbox, spawn free checks and attack range, and the
legs' playback rate must follow the stride, which grows with the model. The boss is already 1.2x a standard zombie
through `EnemyData.size_scale`. At the same time the run animation slid: its reference speed (3.5 m/s) was measured
relative to the hips with a fixed stance threshold, while the clip's planted foot really travels about 4.85 m/s, and the
walk and run loops repeat their first pose for one frame.

## Decision

- One designer knob, `GameTuning.character_scale` (default 1.15, in the "Characters" group), sizes every character.
  `GameTuning.zombie_size(enemy)` is `size_scale x character_scale` and `zombie_radius(enemy)` is `radius x
  character_scale`; `EnemyData` keeps describing a type relative to the model at scale 1.
- `Zombie` scales its visual, body height, health bar height and collision radius from those and exposes `body_radius`
  and `body_scale`; the hurtbox, the attack range and the spawners' free checks use them.
- `Player.set_body_scale()` (called by `Level` with the tuning value, the fallback value when the player runs alone)
  scales the visual, the ring, a per-instance copy of the collision cylinder, `body_radius` and the glow height. The
  bullet height (the `Weapon` node, 1.0 m) and the mouse aim plane stay in world units: props are sized in metres, and
  a scaled 1.15 m bullet flew over the 1 m fire barrels. The weapon in the hand is measured in the model's own space, so it grows with the model whether
  it was attached before or after scaling.
- `PlayerModel` and `ZombieModel` divide the ground speed by their world scale before choosing clip and playback, with
  re-measured references (walk 1.45, run 4.85 m/s, player later 5.1 m/s on the slice-17 hero rig, planted-foot speed in character space), a walk-to-run switch with
  hysteresis instead of a blend (run above 2.9, walk below 2.7 m/s at scale 1, cross-faded on a switch, so a steady
  speed such as a four Fleet Foot walk never mixes two clips) and the cadence easing moved to 2x, above any reachable
  playback. `CharacterModel` drops the held first frame of
  the walk and run loops on install (cached copies; the shared clip is never modified).

## Consequences

- Designers resize everyone with one value and the gameplay sizes stay consistent; a boss stays 1.2x a standard zombie.
- Bigger bodies make zombies easier to hit and streets fill sooner; the camera framing was left unchanged.
- The feet stay planted at the real walk and sprint speeds (measured in `tests/test_player_model.gd` and
  `tests/test_zombie_model.gd`, which fail if a planted foot slides faster than about 0.3 to 0.4 m/s). The sprint plays
  the long-stride run clip at about 0.6x, which looks like a loping run; a quicker-looking sprint needs a run clip with a
  shorter stride, not a faster playback.
- A steady speed inside the 2.7 to 2.9 m/s band plays whichever clip it had (walk from a standstill, run right after a
  sprint); both keep the feet planted, only the look differs.
- The tracer starts at 1.0 m while the gun in the scaled hand is about 15 cm higher; at the game camera this is not
  visible.
