---
type: Architecture Decision Record
title: Placeholder art drawn in code
description: Entities render with _draw() shapes and exported colours, so no binary art assets are committed in slice 1.
tags: [art]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T15:32:41Z
status: deprecated
lifecycle: superseded
superseded_by: isometric-3d-world
deciders: [claude]
---

# Placeholder art drawn in code

## Status

Superseded by isometric-3d-world

## Context

The project goal states that art and audio can be placeholders. The focus is gameplay.

## Decision

Every entity draws itself with `_draw()` (circles, rectangles, polygons) using exported colours and sizes. There are no
textures or audio in slice 1. UI uses default Godot controls with theme overrides.

## Consequences

- No binary churn in git; colours and sizes are tunable in the Inspector.
- Swapping in sprites later means adding a Sprite2D child and turning the `_draw()` off. Gameplay code does not change.
