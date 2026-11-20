---
type: Architecture Decision Record
title: Unified player input component
description: A PlayerInput node merges keyboard/mouse, twin-stick gamepad and on-screen touch sticks into move, aim and fire intents; the last used device picks the aim source.
tags: []
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T15:36:06Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Unified player input component

## Status

Accepted

## Context

The game must play on PC with a twin-stick gamepad or with mouse and keyboard, and (nice to have) on mobile browsers
with two on-screen touch sticks. Movement and shooting code must not care which device is used.

## Decision

- Input actions are defined in the Input Map in `project.godot`: `move_*`, `aim_*` (right stick), `shoot`
  (mouse left, right trigger), `sprint_toggle` (Shift, L3), and `ui_*`/`perk_redraw`/`perk_skip` for menus.
- `PlayerInput` (`world/player/player_input.gd`) is a child node of the player that exposes `move_vector`,
  `aim_direction`, `is_firing` and a `sprint_toggled` signal. It remembers the last device class used (mouse,
  gamepad, touch) and picks the aim source from it. Gamepad and touch fire while the aim stick is pushed past a dead
  zone, like the original.
- `TouchSticks` (`ui/touch/touch_sticks.tscn`) is a CanvasLayer with two `VirtualStick` controls (left and right half
  of the screen) and a sprint button. It is shown only when `DisplayServer.is_touchscreen_available()`, or after the
  first touch event. Game flow injects it into `PlayerInput`, which reads the sticks' vectors.

## Consequences

- Tests can drive the player by injecting `InputEvent`s or by setting the touch stick vectors directly.
- Adding a new device means touching only `PlayerInput`.
