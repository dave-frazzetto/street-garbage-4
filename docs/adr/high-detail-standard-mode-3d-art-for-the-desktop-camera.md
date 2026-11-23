---
type: Architecture Decision Record
title: High-detail standard-mode 3D art for the desktop camera
description: Non-rigged props, weapons, pickups and buildings are regenerated as photoreal PBR models (Meshy 7.1 standard mode, 2k-4k textures, 20k-100k triangles) because the target is now Windows desktop with a closer camera.
tags: []
generated:
  by: arkouda/0.8.0
  at: 2026-11-23T13:23:33Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# High-detail standard-mode 3D art for the desktop camera

## Status

Accepted

## Context

The 3D art was generated for a far isometric camera and a web build: Meshy smart topology (meshy-t2, 1k to 10k triangles),
Meshy N1 base-colour-only textures, and a "chunky, hand-painted" style. The camera is now closer and the game targets Windows
desktop, where the old assets look flat and low quality. The owner asked for AAA quality on everything that is not rigged
(no player, no zombies) and accepts large asset files and any Meshy credit cost.

## Decision

- Non-rigged assets (weapons, pickups, car, street lamp, traffic light, power pole, neon sign, dumpster, barrel, barricade, the
  three building facades) are regenerated with the pipeline in `art/tools/generate_assets.sh`:
  text-to-image reference in a photoreal AAA style (`art/tools/style_hq.txt`) -> image-to-3d in **standard mode** (meshy-7.1)
  with the 4k Ultra geometry pass and **meshy-7 PBR** textures (base colour, normal, metallic-roughness) -> **remesh** to a
  triangle target per asset.
- Triangle targets (in `assets.tsv`): weapons 25k to 50k, pickups 20k, small props 20k to 50k, poles and lamp 40k, car 100k,
  building tiles 60k to 80k. Textures are 4k for the car, lamp and buildings, 2k for the rest.
- Characters keep their smart-topology pipeline (they are rigged); this decision does not touch them.
- GLBs are committed exactly as Meshy delivers them (no extra compression). The PNGs Godot extracts from a GLB on import
  (`*_texture_*.png`, `*_normal.png`, `*_emissive.png`) are regenerated, so they are git-ignored.
- `art/tools/model_sheet.gd` renders any set of GLBs under neutral light for an in-engine review.

## Consequences

- Much better close-up quality; materials react to the level lighting through real PBR maps.
- GLBs are 16 MB to 60+ MB each, so the repository grows by several hundred MB, and the web build is no longer a target
  for these assets (it would need the old low-poly set or a separate pass). Each file must stay under GitHub's 100 MB limit.
- Many triangles per instance (the building facade tiles repeat): frame time must be checked on the real level.
- Re-generating an asset costs about 50 credits (image 9, model 35, remesh 5); the style statement is in one file so a
  retune is a single edit.
