---
type: Architecture Decision Record
title: Godot 4.7 with typed GDScript
description: Build the game in Godot 4.7.2 using statically typed GDScript only.
tags: [engine]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T15:32:16Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Godot 4.7 with typed GDScript

## Status

Accepted

## Context

The project recreates the top-down roguelike shooter Street Trash III: Dezombifier (the arcade game inside GTA VI).
The project rules mandate Godot; the installed engine is 4.7.2 stable. Several developers and a designer will work on
it, so errors should surface early and scripts must stay readable.

## Decision

Use Godot 4.7.2 and GDScript only (no C#, no GDExtension). All variables, parameters, returns, arrays and signals are
statically typed. Shared types get a `class_name`. Run scripts from the console executable
`Godot_v4.7.2-stable_win64_console.exe` so tests print to the terminal.

## Consequences

- No build step; headless tests run with `--headless --path . res://tests/...`.
- Typed GDScript catches many errors at parse time; adding a `class_name` needs `--import` to refresh the class cache.
- Performance limits of GDScript are fine for a few hundred zombies; revisit if hordes grow far beyond that.
