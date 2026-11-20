---
type: Architecture Decision Record
title: Level authored as scene of prefab instances
description: The city is a .tscn of placed Building, GearSpawnPoint, HordeSpawner and ExtractionZone instances, not tilemaps or code layouts.
tags: [world, levels]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T15:32:41Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Level authored as scene of prefab instances

## Status

Accepted

## Context

Levels must be editable in the Godot editor. A TileMapLayer would need a tileset image and stores its cells in an
opaque packed array, which is hard to review in text diffs. Slice 1 has placeholder art.

## Decision

`world/levels/freedom_city.tscn` is built from instances of small prefabs:

- `Building` (a `@tool` StaticBody2D with an exported `size` and `color`; its collision follows the size).
- `GearSpawnPoint` (a Marker2D). At run start the level picks `RunConfig.gears_required` of them at random.
- `HordeSpawner` (spawns an exported number of zombies around itself once, e.g. the crashed helicopter on the
  basketball court).
- `ExtractionZone` (the High-Rise in the quarantine zone).
- `PlayerStart` (a Marker2D) and the `ZombieDirector`, which spawns ambient zombies off-screen over time.

The ground is a large drawn rectangle with streets drawn by `Building`-free gaps.

## Consequences

- Designers move buildings and spawn points in the editor and every change is a readable text diff.
- Real tile art can replace this later without touching the gameplay prefabs.
- Zombies chase in straight lines and slide along walls. Add navigation if that turns out to be too simple.
