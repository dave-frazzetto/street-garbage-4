---
type: Product Requirements Document
title: Slice 3 isometric 3D presentation
description: Port the playable run from 2D to an isometric 3D view with placeholder meshes, keeping all gameplay, controls and tests.
tags: []
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T16:35:37Z
status: stable
lifecycle: shipped
owner: [claude]
decisions:
  - isometric-3d-world
  - unified-player-input-component
---

# Slice 3 isometric 3D presentation

## Status

Shipped

## Problem

Sources: the YouTube video "Street Trash 3: Dezombifier - Top Down Zombie Shooter (GTA 6 Minigame)" (q4IzdXGOfOs),
reviewed as one still every 10 seconds; findings in docs/reference/original-game-video-notes.md.

The owner wants the game to be 3D with an isometric camera. Assets can stay placeholders; the run must play exactly
as in slices 1 and 2.

## Requirements

- I1 The whole world renders in 3D through a high-angle camera that follows the survivor smoothly: perspective by
  default like the reference video (pitch 45 degrees after owner feedback; was 60, then 70), with an orthographic (true isometric) option on the rig.
- I2 Same map layout as slice 1 (alleys, basketball court with helicopter horde, quarantine zone, High-Rise, garage
  start), now with buildings that have height.
- I3 Buildings that hide the survivor turn translucent.
- I4 Controls are screen-relative: W / stick up / touch up moves up the screen; the mouse aims at the ground point under
  the cursor; gamepad and touch aim sticks are screen-relative.
- I5 All slice 1 gameplay is unchanged: gears, timer, extraction, zombies and hordes, XP, perks (including ricochet,
  explosions, twin barrel), pickups, HUD, menus, touch controls.
- I6 Placeholder meshes are readable: survivor blue capsule with a gun; zombies green capsules (armoured with a grey
  band) that face their target and flash when hit, with health bars; gears are glowing blue cogs; health pickups are
  white boxes with a red cross; the High-Rise entrance glows when unlocked.
- I7 The web build still loads and plays.
- I8 Night-time city like the original video: dark ambient light, street lamps and neon signs as local lights, burning
  fires, cars with headlights as props, blood decals where zombies die, glowing bullet tracers.
- I9 HUD laid out like the original: top-left portrait with level badge and health / stamina / XP bars; countdown top
  centre; top-right gear icon with "x/6" and a framed current-weapon panel.
- I10 Destructible world elements (owner request): cars and fire barrels have health, take bullet damage, start
  burning when badly damaged, and explode at zero, damaging zombies and the survivor inside the blast radius
  (falloff from the centre) and chaining into nearby destructibles. Cars leave a burnt wreck. Health, radius and
  damage are tunable per prop (`Destructible` component).
- I11 (owner feedback) Streets are about 10 m wide and alleys 4 m, on a 120 m city. Street segments are partly
  blocked by roadblocks of wrecked cars, concrete barriers and dumpsters with a gap to pass through. The camera looks
  down at 45 degrees (second round of feedback: 70 was too steep).

## Non-Goals

- The perk set, pack opening and card flip, kill-streak multiplier and Game Over screen seen in the video: these are
  slice 4 (see docs/reference/original-game-video-notes.md).
- Real models, animation, audio; camera rotation by the player; vertical gameplay (stairs, jumping).

## Success Metrics

- All headless suites pass after the port (rules, input, touch, game flow).
- Windowed and web screenshots show the isometric city, combat and HUD.
