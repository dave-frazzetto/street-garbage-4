---
type: Architecture Decision Record
title: Feature folder module layout
description: Code lives in core/, data/, rules/, world/, ui/ and tests/ folders; modules talk only through signals wired by core/game_flow.
tags: [architecture]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T15:32:41Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Feature folder module layout

## Status

Accepted

## Context

Several developers must work in parallel (for example one on combat feel, one on the city) without editing the same
files, and every scene must run on its own (F6).

## Decision

- `data/`: `Resource` scripts and their `.tres` instances (perks, weapons, enemies, run and player config).
- `rules/`: node-free model classes (`RunState`, `PlayerStats`, `PerkDeck`).
- `world/`: game-world scenes, one subfolder per entity (player, enemies, projectiles, pickups, props, spawning, levels).
- `ui/`: HUD, perk selection, title and end screens.
- `core/`: `game_flow.tscn`, the main scene and only place where world and UI are wired together.
- `tests/`: headless unit tests and per-module test scenes.

The contract between modules:

- The level (`world/levels/level.gd`) emits `zombie_killed(xp, position)`, `gear_collected(total)`,
  `player_health_changed`, `player_damaged`, `player_died`, `extraction_reached` and `extraction_denied`.
- The perk UI emits `perk_chosen(perk)`, `redraw_requested` and `skipped`.
- `game_flow` owns `RunState` and `PlayerStats` and calls down into the level and the UI.

## Consequences

- World and UI never reference each other; each can be launched alone with fake data.
- `game_flow.gd` grows with each feature; split it into sub-coordinators if it grows past about 300 lines.
