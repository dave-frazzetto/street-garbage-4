---
type: Architecture Decision Record
title: Mobile graphics profile and on-screen errors
description: Mobile browsers get a cheap GraphicsProfile (no shadows, glow or fog, 0.6 render scale, 8 nearest static lights); web builds show engine errors on screen; the title shows LOADING and starts on any tap.
tags: [web, mobile, rendering]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T18:41:08Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Mobile graphics profile and on-screen errors

## Status

Accepted

## Context

On a phone (itch.io in the mobile browser) the 3D build stayed on the title screen after a tap, while desktop Chrome
was fine. The 3D city has about 60 dynamic lights, shadows, glow and fog, which phone GPUs on WebGL 2 handle far worse
than desktops, and a phone gives no console to read errors from.

## Decision

- `GraphicsProfile` Resource (`data/config/graphics_profile.gd`): shadows, glow, fog, `render_scale`, and
  `max_static_lights`. `graphics_desktop.tres` keeps everything; `graphics_mobile.tres` turns off shadows, glow and
  fog, renders 3D at 0.6 scale and keeps only the 8 static lights nearest to the player on.
- Game flow picks the mobile profile on `web_android`, `web_ios`, or a touch screen on the web (or
  `force_mobile_graphics` for testing on a PC) and calls `Level.apply_graphics(profile)`. The level re-picks the
  nearest lights every 0.3 s; lights under hidden parents do not use a slot.
- `ErrorConsole` (`ui/debug/error_console.tscn`) registers an engine `Logger` on web builds and shows errors at the
  bottom of the screen, so a phone screenshot tells us what failed.
- The title screen shows "LOADING..." immediately and starts on any tap on a touch screen; game flow waits two frames
  before building the level so that feedback is visible.

## Consequences

- Phones look plainer (no shadows or glow, softer image) but should start and run.
- The light budget costs a sort of about 60 lights every 0.3 s; negligible.
- Errors on web builds are visible to players too; acceptable for a research build.
