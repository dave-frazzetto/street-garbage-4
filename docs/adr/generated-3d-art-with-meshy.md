---
type: Architecture Decision Record
title: Generated 3D art with Meshy
description: Replace code-built placeholder meshes with GLB models generated through the Meshy CLI, guided by a written art direction and asset manifest.
tags: [art, meshy]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T17:18:16Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Generated 3D art with Meshy

## Status

Accepted

## Context

The isometric 3D world (see `isometric-3d-world`) renders every entity from primitive meshes (capsules, boxes, spheres)
built in the scenes. The project goal allows placeholder art, but the game is now played and shown, and the owner has a
Meshy subscription and a set of reference images from comparable games. Reference art is third-party and copyrighted.

## Decision

Generate the 3D models with Meshy, driven from the Meshy CLI, and replace the primitive meshes with GLB files.

- Art direction and an asset manifest with one prompt per asset live in `docs/art/style-guide.md`. Prompts describe the style
  in our own words and never name a franchise or character.
- Reference images stay in `art/concept art/`, which is gitignored. They guide the written style only and are never sent to
  Meshy as input, so generated models are not derivatives of them.
- Pipeline: text-to-image reference (approved by the owner), then image-to-3d with smart topology, then rigging and animation
  for characters. GLB goes under `art/models/<group>/` with its `_meta.json` sidecar.
- Collision shapes, scripts and data Resources stay as they are; a generated model replaces only the `Visual` child.
- Procedural effects (ground shader, blood, explosion, fire, bullets, markers, health bars) stay procedural.
- Credentials: the CLI keeps its own session outside the repo. No key is stored in the project.

## Consequences

- Binary GLB files enter git, so triangle and texture budgets are set per asset to keep the web build small.
- Meshy keeps task files for 3 days, so each model is downloaded and committed right after generation.
- Generated characters need rigging and animation, which costs extra credits and may need hand-tuning.
- Output style can drift between assets; the shared style statement and per-asset references are how we control that.
- Meshy terms and plan limits apply to commercial use of the models; check them before a public itch.io release.
- Swapping to another generator later only changes the import step, since the scenes consume plain GLB files.
