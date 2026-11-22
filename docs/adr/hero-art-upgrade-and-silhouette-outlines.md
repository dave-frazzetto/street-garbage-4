---
type: Architecture Decision Record
title: Hero art upgrade and silhouette outlines
description: Raise triangle budgets and keep 2k textures for hero assets, and add world-space outlines and a colour grade so characters read from the iso camera.
tags: []
generated:
  by: arkouda/0.8.0
  at: 2026-11-22T20:35:18Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Hero art upgrade and silhouette outlines

## Status

Accepted

## Context

The Meshy models looked low quality in game. Triangle budgets were small (characters 6k, buildings 5k, car 4k), textures were
shrunk to 1024 px, and from the high isometric camera the zombies were flat grey figures with little contrast against the
dark ground.

## Decision

- Regenerate the hero assets from their existing references with higher budgets: player 15k, zombies 12k, buildings 10k,
  car 8k triangles (`art/tools/assets.tsv`). Small props and weapons are unchanged.
- Hero textures stay at the 2048 px Meshy N1 size; `shrink_textures.gd` is no longer run on them.
- Characters are re-rigged from the new meshes and reuse the existing animation clips (`.res`), since Meshy rigs share bone names.
- Characters get an inverted-hull outline (`world/characters/outline.gdshader`) as the next pass of the lifted material, red for
  the infected and cyan for the player, set per model scene (`outline_color`, `outline_width` in metres). The width is divided
  by the model matrix scale so it is world-space.
- The level environment gets a colour grade (contrast 1.12, saturation 1.3).

## Consequences

- More triangles per zombie and per building tile (about 2x); the web build and low-end mobile need a check before release.
- GLB files stay around 4 to 5 MB each; the web zip grew from 51.9 MB to 56.2 MB (+8%) with the 2k textures.
- The outline doubles the draw cost of characters. It is controlled by exports, so a mobile profile can set the colour alpha to 0.
- If a future rig has different bone names the clips must be re-extracted with `art/tools/extract_clips.gd`.
