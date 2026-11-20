---
type: Architecture Decision Record
title: Node-free rules layer
description: RunState, PlayerStats and PerkDeck are RefCounted classes with no node dependencies, unit-tested headless; scenes only present them.
tags: [architecture, testing]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T15:32:41Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Node-free rules layer

## Status

Accepted

## Context

Run rules (countdown, gears, XP curve, level-ups, kill streak, redraws, perk stacking, stat maths) must be testable in
well under 30 seconds and should not depend on how the world is drawn.

## Decision

- `RunState` (`rules/run_state.gd`) holds the run: time left, gears, XP, level, pending level-ups, kills, kill streak,
  redraws left, perk stacks and the outcome. It emits signals when these change.
- `PlayerStats` (`rules/player_stats.gd`) computes final stats as `(base + flat) * (1 + percent)` from a `PlayerConfig`
  and the active modifiers, plus boolean flags.
- `PerkDeck` (`rules/perk_deck.gd`) draws weighted hands of distinct perks with an injected `RandomNumberGenerator`,
  skipping perks that are maxed out or not eligible.
- Scenes read from these objects and forward input. Only `game_flow` writes to them.

## Consequences

- `tests/test_rules.tscn` checks the rules headless in about a second.
- The rules are deterministic when tests pass a seeded RNG.
