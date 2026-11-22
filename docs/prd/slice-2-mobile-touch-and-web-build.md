---
type: Product Requirements Document
title: Slice 2 mobile touch and web build
description: Touch twin-sticks for mobile browsers and a single-threaded HTML5 export zipped for itch.io.
tags: []
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T16:00:10Z
status: stable
lifecycle: shipped
owner: [claude]
decisions:
  - unified-player-input-component
  - single-threaded-web-export-for-itch-io
---

# Slice 2 mobile touch and web build

## Status

Shipped

## Problem

Requirement R2b of [slice-1-core-run](slice-1-core-run.md) (nice to have): the game should be playable in a mobile
browser from itch.io, in landscape, with two touch sticks. Slice 1 only supports mouse+keyboard and gamepad.

## Approach

Add an on-screen `TouchControls` layer with two floating virtual sticks (left half moves, right half aims and fires)
and a sprint button, injected into `PlayerInput`. Add a Web export preset and a script that builds and zips it.

## Requirements

- T1 Touching the left half of the screen places a move stick under the finger; dragging moves the survivor.
- T2 Touching the right half places an aim stick; dragging aims and fires once past the fire threshold.
- T3 Both sticks work at the same time (multi-touch), each tracking its own finger.
- T4 ~~A SPRINT button toggles sprint.~~ Removed in slice 15: touch play walks only (ADR hold-to-sprint-walk-only-on-touch).
- T5 Touch controls show only on touch devices (or after the first touch) and hide while menus are open.
- T6 Title, perk cards (tap to pick), redraw/skip buttons and end screen work by tap.
- T7 In portrait, a "rotate your device" overlay asks for landscape.
- T8 Emulated mouse events from touch do not switch the aim source away from touch.
- T9 `scripts/build_web.sh` exports a single-threaded HTML5 build to `build/web/` and a zip ready for itch.io upload.
- T10 Mouse+keyboard and gamepad keep working unchanged.

## Non-Goals

- Native Android/iOS builds, haptics, on-screen layout customisation.
- Automated testing in a real mobile browser (the owner tests on device).

## Success Metrics

- A headless test drives both sticks with simulated multi-touch events: the player moves and shoots, and sprint
  toggles.
- The web export completes without errors and produces `index.html`, `.wasm` and `.pck` plus the zip.
- All slice 1 tests still pass.
