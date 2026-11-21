---
type: Architecture Decision Record
title: Cyberpunk world and female protagonist
description: 'Art direction change: a cyberpunk megacity at night, a female cyberpunk punk-rocker protagonist, infected citizens with failing cybernetics, neon accent palette.'
tags: [art, meshy]
generated:
  by: arkouda/0.8.0
  at: 2026-11-21T00:11:20Z
status: stable
lifecycle: accepted
deciders: [owner, claude]
---

# Cyberpunk world and female protagonist

## Status

Accepted

## Context

The first generated art (ADR `generated-3d-art-with-meshy`) used a generic grim zombie-apocalypse look and a male survivor.
The owner changed the direction: the main character is a woman and the world is cyberpunk. Some assets already exist in the
old look (zombie walker, player, pistol, street lamp, traffic light) and the rest are still primitives.

## Decision

- **World:** a rain-slick cyberpunk megacity block at night overrun by the infected: neon signs, holographic ads, chrome,
  cables. Gritty and worn, not clean sci-fi.
- **Protagonist:** a woman, a cyberpunk punk rocker with neon hair, cybernetic implants, and worn leather and metal armour.
  One written brief in `docs/art/style-guide.md` is reused in every prompt that shows her.
- **Zombies:** infected citizens with failing cybernetics, so they belong to the same world.
- **Palette:** desaturated base with one neon accent per asset (magenta, cyan or orange); red is kept for the infected and danger.
- The style guide is the single source: its style statement, protagonist brief and asset manifest (with a state per asset)
  are updated first, then assets are regenerated from it. Gameplay scenes, scripts, collision and data are unchanged.

## Consequences

- Five existing assets (zombie walker, player, pistol, street lamp, traffic light) no longer match and are marked `regen`
  in the manifest. Regenerating costs Meshy credits and replaces their GLB, texture and clips only.
- The player is regenerated first; the female model must be re-rigged, and the weapon attachment rotation re-solved.
- Cyberpunk neon needs real lights, not texture glow, so lamps, signs and implants keep an `OmniLight3D` in the scene.
- Prompts stay original: genre words only, never a franchise, character or studio name.
