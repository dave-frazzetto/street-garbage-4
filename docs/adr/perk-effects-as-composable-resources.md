---
type: Architecture Decision Record
title: Perk effects as composable resources
description: A Perk .tres holds a rarity, a category and a list of PerkEffect sub-resources (stat modifier, temporary weapon, grant gear, flag) that apply themselves to the run.
tags: [data, perks]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T15:32:41Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Perk effects as composable resources

## Status

Accepted

## Context

The original game offers three perk cards at every level-up, each with a category (Chaos, Combat, Economy, Survival,
Duality, Loadout) and an effect shown as "Stat: before → after". Some perks are trade-offs (Vampire: lifesteal but no
health pickups), some are temporary weapons (Auto Shotgun for 30 s), some grant items (Gear). A designer must be able to
add and rebalance perks without code. A `match perk_id:` block would break this.

## Decision

- `Perk` (`data/perks/perk.gd`) is a Resource with `display_name`, `category`, `rarity` (COMMON or RARE), `weight`,
  `max_stacks`, `description` and `effects: Array[PerkEffect]`.
- `PerkEffect` is an abstract Resource with `apply(context: PerkContext)` and `describe(context)`.
  Subclasses: `StatModifierEffect` (stat enum plus amount), `TempWeaponEffect` (WeaponData plus duration),
  `GrantGearEffect`, `FlagEffect` (turns on a `PlayerStats.Flag`, e.g. no health pickups).
- `PerkContext` gives effects access to the `RunState`, the `PlayerStats` and a temporary-weapon callback. Effects never
  reach into scenes.
- Weapon mods (ricochet, explosive rounds, extra barrels) are plain stats read by the weapon and bullet scenes, so a
  permanent mod is just a `StatModifierEffect`.
- Rarity sets the default draw weight (rare is drawn less often) and the card style.

## Consequences

- New perks are new `.tres` files. A new kind of effect needs one small `PerkEffect` subclass.
- Card text comes from the effects, so it cannot drift from the real numbers.
- Shared Resources are never mutated: stacks are counted in `RunState`, not on the Perk.
