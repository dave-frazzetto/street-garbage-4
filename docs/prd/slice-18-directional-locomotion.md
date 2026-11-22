---
type: Product Requirements Document
title: Slice 18 directional locomotion
description: 'Player walk and run animations that depend on the angle between movement and aim: forward, backpedal and strafe clips blended in a 2D blend space, with smooth transitions.'
tags: []
generated:
  by: arkouda/0.8.0
  at: 2026-11-22T20:54:18Z
status: stable
lifecycle: shipped
owner: []
decisions:
  - generated-3d-art-with-meshy
  - unified-player-input-component
  - survival-style-combat-rooted-shooting-hitscan-line-tougher-zombies
  - directional-locomotion-from-angle-smoothed-blend-spaces
---

# Slice 18 directional locomotion

## Status

Shipped

## Problem

The survivor body always faces the aim direction (`Player` sets `visual.rotation.y` from `PlayerInput.get_aim_direction()`), but the legs play a single forward walk or run clip (`PlayerModel`, blended by ground speed only). Moving left while aiming right therefore shows her running forward with her torso turned sideways, a "moonwalk" that reads as a bug. Twin-stick play makes this the common case: movement and aim are independent most of the time. The character is the focus of the screen, so this is the most visible animation flaw left after the art upgrade.

## Approach

Split movement into a local-space direction: take the ground velocity, rotate it into the character's facing frame, and use that 2D vector (x = strafe, y = forward) to drive a 2D blend space of directional clips. Generate the missing clips with Meshy (rigged on the existing player skeleton) and extract them with `art/tools/extract_clips.gd` like the current walk and run clips. `PlayerModel` stays the only owner of animation: `Player` keeps calling `update_motion()`, now also passing the facing, so the presentation changes without touching rules or input. Walk and run each get their own blend space, switched by speed as today (`PlayerModel.runs_at` with the `walk_below_speed` / `run_above_speed` hysteresis, slice 15), and the speed-to-playback-rate matching is kept per direction so feet do not slide. Do not blend the walk and run clips by speed: they are not phase matched and a blend of them makes the feet slide.

## Requirements

- FR-1 **Clip set.** The player has walk and run clips for 4 directions: forward, backward, strafe left, strafe right (8 new clips, plus the 2 existing forward ones). All use the existing Meshy skeleton, loop seamlessly, and are saved as `.res` through `extract_clips.gd`. Idle stays a single clip.
- FR-2 **Local-space movement.** `PlayerModel` receives the facing and the world velocity (or movement direction) and computes the movement vector relative to the facing. Moving along the facing plays forward, directly against it plays backward, perpendicular plays the matching strafe, and diagonals blend neighbouring clips.
- FR-3 **2D blend space.** (Shipped: the point positions are fixed corners of the diamond; the designer tunes the turn rate and the clip reference speeds in `LocomotionProfile`.) Locomotion is an `AnimationNodeBlendSpace2D` (one for walk, one for run) in the existing `AnimationTree`. The blend position is smoothed so that quickly flipping the aim does not snap the legs between clips. The blend space is built in code like the current tree, with the point positions exported or taken from a Resource so a designer can adjust them.
- FR-4 **Walk and run still switch by speed.** The walk/run switch uses the same hysteresis thresholds (`walk_below_speed`, `run_above_speed`, cross-fade on a switch, no speed blend) and applies to every direction. (A slower backpedal and strafe was optional and is not done: it is a gameplay change and stays an open question.)
- FR-5 **No foot sliding.** Playback speed of each directional clip is scaled to the ground speed using a per-clip reference speed (measured as for the current forward clips). These live in a Resource (for example `LocomotionProfile`) and not as literals.
- FR-6 **Transitions.** Idle to move, move to idle, and direction changes cross-fade without a visible pop. Start, stop and direction hysteresis are tunable (extending the existing `move_start_speed`, `move_stop_speed` and `blend_rate` knobs). Reversing from forward to backward blends through the strafe poses and does not snap.
- FR-7 **Aim and fire layering unchanged.** The upper-body fire overlay (`run_and_shoot` on `upper_body_bones`) and the "firing roots the player" rule are unchanged. While firing the player is rooted, so only the idle legs show. The overlay must not break when the legs play a directional clip.
- FR-8 **Death and weapons unaffected.** `play_death()` still stops the tree and plays `die`; the weapon stays attached to the hand bone in every direction.
- FR-9 **Graceful fallback.** If a directional clip is missing from `clips`, the model falls back to the forward clip for that direction (no error), so a character without the new clips still works.
- FR-10 **Tests.** A node-free helper (for example `LocomotionBlend`) maps (velocity, facing) to the blend-space position and is unit-tested headless: forward, backward, left, right, diagonals, zero speed and a rotated facing. An extended `PlayerModel` test checks that the blend position follows the movement/aim angle and that the tree stays valid when clips are missing. A windowed test saves screenshots of the player moving in each direction relative to the aim, for visual review.

## Non-Goals

- Moving while firing, or any change to the firing-roots-the-player combat rule.
- 8-way clips (separate diagonal clips); diagonals are blended.
- Zombie locomotion; zombies face where they walk.
- Turn-in-place animation, leaning, foot IK, or procedural hip twist.
- New idle, hit-reaction, reload or weapon-specific animations.
- Changes to player speed, controls, camera or the input component.

## Success Metrics

- Visual check in saved screenshots and a short play session: with the aim fixed right, moving left shows backpedalling, moving up or down shows strafing, and moving right shows a forward run. Nobody sees the character gliding or running forward while travelling sideways.
- Feet do not visibly slide in any of the 4 directions at walk and at run speed (checked by comparing planted-foot travel to ground speed, as was done for the forward clips).
- Spinning the aim 360 degrees while holding a move key produces a continuous blend: no frame where the pose snaps between clips.
- The unit tests and the headless smoke test pass, and each test run stays under 30 seconds.
- The web build size and frame rate on mobile stay within the numbers recorded in the existing ADRs (extra clips are small `.res` files; the tree adds two blend spaces).

## Open Questions

Resolved in the slice: the Meshy motions came out usable for placeholder art (backward walk from the library, the rest generated; 67 credits); reference speeds are per clip, in `LocomotionProfile`. Still open:


- Should backward and strafe movement be slower in `PlayerConfig` (FR-4), or is that a separate balance decision for the designer?
