---
type: Architecture Decision Record
title: Single-threaded web export for itch.io
description: Export with the Web nothreads template and gl_compatibility so the game runs on itch.io and mobile browsers without SharedArrayBuffer headers.
tags: []
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T16:00:10Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Single-threaded web export for itch.io

## Status

Accepted

## Context

The threaded Godot web build needs cross-origin isolation (COOP/COEP headers) for SharedArrayBuffer. itch.io supports
that only behind an opt-in flag, and some mobile browsers handle it poorly. The game is single-threaded GDScript and
already uses the Compatibility (WebGL 2) renderer.

## Decision

Export with the `Web` preset using the no-threads template (`variant/thread_support=false`), Compatibility renderer,
canvas resize policy "adaptive" so it fills the itch.io frame and phone screens. `scripts/build_web.sh` runs the export
and zips `build/web/` into `build/street-garbage-web.zip` (index.html at the zip root, as itch.io expects). Build
outputs are gitignored.

## Consequences

- Upload the zip to itch.io as an HTML project with "SharedArrayBuffer support" off; enable fullscreen and mobile
  friendly options there.
- Audio may start only after the first tap (browser autoplay rules); there is no audio yet.
- Threaded performance features are not available; fine for this game's load.
