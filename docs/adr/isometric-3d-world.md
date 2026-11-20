---
type: Architecture Decision Record
title: Isometric 3D world
description: The world is real 3D (CharacterBody3D, StaticBody3D, 3D ray casts) seen through an orthographic isometric camera rig; 1 unit = 1 m; buildings fade when they hide the player; placeholder primitive meshes.
tags: [world, art, camera]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T16:35:37Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Isometric 3D world

## Status

Accepted

## Context

The owner wants the game in 3D with an isometric view (placeholder assets for now). Slice 1 built the world in 2D
(CharacterBody2D, `_draw()` art, 2D ray casts). The rules layer (`RunState`, `PlayerStats`, `PerkDeck`), the perk data
and the UI do not depend on the world's dimension. Two options were considered:

1. Keep the 2D simulation and mirror it into a 3D view layer. Gameplay code stays, but levels would be authored in 2D
   while looking 3D, and every entity would exist twice.
2. Port `world/` to real 3D nodes. Levels are authored in the 3D editor, what you place is what you see.

## Decision

Option 2. Supersedes [level-authored-as-scene-of-prefab-instances](level-authored-as-scene-of-prefab-instances.md)
and [placeholder-art-drawn-in-code](placeholder-art-drawn-in-code.md).

- 1 unit = 1 metre. The ground is the XZ plane at y = 0; gameplay is planar (bodies keep y = 0).
- Entities are 3D scenes: `Player` and `Zombie` are `CharacterBody3D` in floating motion mode, `Building` is a `@tool`
  `StaticBody3D` with an exported `size: Vector3`, bullets ray-cast with `PhysicsRayQueryParameters3D`, pickups and
  the extraction zone are `Node3D`/`Area3D`. Collision layers are unchanged (1 world, 2 player, 3 zombies).
- `IsoCamera` (`world/camera/iso_camera.tscn`) is an orthographic camera rig with exported pitch (45°), yaw (45°),
  size and follow speed. It converts screen directions to world directions (so "up" on the stick or W is up on
  screen) and screen points to ground points (mouse aim).
- Buildings between the camera and the player fade to translucent. The level calls
  `Building.update_occlusion(player, view_dir, pitch)` each frame; no global state.
- Placeholder art is Godot primitive meshes (capsules, boxes, tori) with per-instance StandardMaterial3D colours from
  the same exported colour fields, plus Label3D text. One DirectionalLight3D with shadows and a WorldEnvironment.
- Levels are still scenes of prefab instances: `Building`, `GearSpawnPoint` (Marker3D), `HordeSpawner`,
  `ExtractionZone`, `PlayerStart`, `ZombieDirector`, plus `Ground` and `GroundZone` decals.

## Consequences

- All tunables changed units from pixels to metres (speeds, radii, ranges, distances).
- Tests move to Vector3 positions and check movement along the camera's screen axes.
- 3D costs more than 2D in the browser; keep meshes simple and the zombie cap modest, and re-check the web build.
- Real art later means swapping the primitive meshes inside each entity scene; gameplay code does not change.
- Bullet rays use `hit_from_inside` so zombies hugging the player are still hit. Obstacles lower than the 1 m bullet
  height (fences, railings) block movement but not shots; cars are tall enough to stop bullets (and get destroyed).
- Destructible props use a `Destructible` component that only reports `destroyed(at, radius, damage)`; the level
  applies blasts to zombies, the player and other destructibles (signal up, no cross-scene reaching).
- The compatibility renderer limits lights per mesh, so the ground is a shader plane and light ranges stay short.
