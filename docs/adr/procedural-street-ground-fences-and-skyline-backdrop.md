---
type: Architecture Decision Record
title: Procedural street ground, fences and skyline backdrop
description: World-space ground shader, an instanced Fence prefab and a MultiMesh skyline ring hide the map end without texture files.
tags: [world]
generated:
  by: arkouda/0.8.0
  at: 2026-11-21T18:09:39Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Procedural street ground, fences and skyline backdrop

## Status

Accepted

## Context

The floor was flat, the player could walk to the plane's end and see the void.

## Decision

The ground is a 400 m plane with a world-space procedural street shader (asphalt wear, lane markings, crosswalks, kerbs, manholes), with a cheaper tier on mobile via GraphicsProfile.detailed_ground. Perimeter fences are an instanced @tool Fence prefab with a layer-1 collider. A MultiMesh skyline ring (one draw call) continues the city beyond the fences, its height capped at tan(camera pitch) so it never hides the player.

## Consequences

No texture files to ship. The shader grid must match the street grid in freedom_city.tscn, and tools/level_gen still emits the old Wall buildings. MultiMesh shaders must read size from INSTANCE_CUSTOM because MODEL_MATRIX lacks the instance transform in the Compatibility renderer.
