---
type: Architecture Decision Record
title: Hold to sprint, walk only on touch
description: Sprint lasts while the sprint action (Shift, LB, L3) is held and stamina remains; touch play has no sprint control and always walks.
tags: [input, mobile]
generated:
  by: arkouda/0.8.0
  at: 2026-11-22T20:21:58Z
status: stable
lifecycle: accepted
deciders: [owner, claude]
---

# Hold to sprint, walk only on touch

## Status

Accepted

## Context

The original game toggles sprint (its tutorial says "TOGGLE SPRINT (DRAINS STAMINA)") and
`unified-player-input-component` copied that: a `sprint_toggle` action (Shift, L3), a `sprint_toggled` signal and a
SPRINT button on the touch screen. In play the owner found the toggle awkward and asked for sprint to last only while
Shift is held. On phones the SPRINT button sat inside the move-stick area and needed special input routing; the owner
asked for walking only on mobile for now. With the current tuning (walk 2.3 m/s, zombies at 0.56 of it) a phone player
can still walk away from every zombie, so sprint is not essential there.

## Decision

- The Input Map action is `sprint` (keyboard Shift, gamepad LB and L3). `PlayerInput.is_sprint_held()` reports
  whether it is held; it returns false while the touch device is active. The `sprint_toggled` signal and
  `request_sprint_toggle()` are removed.
- `Player` polls the held state every physics frame: holding starts a sprint if stamina is above `GameTuning.min_sprint_stamina` of the bar (0.15, at least 1 point),
  releasing ends it. Any key press switches the input device back to keyboard, so a touchscreen laptop can sprint.
  When the bar runs dry mid-sprint the sprint ends and stays off until the input is released and held again (no flicker
  while the bar refills under a held key).
- Touch controls have no sprint button. `TouchControls`, `GameFlow` and `Level` lose the sprint plumbing
  (`sprint_pressed`, `Level.toggle_sprint()`).
- The title screen and README say "hold SHIFT / LB or L3" and "no sprint on touch".
- This refines `unified-player-input-component` (everything else there still holds).

## Consequences

- Touch players can still draw sprint perks (Double Sprint) from the pool, which do nothing for them, and the stamina bar
  stays on the HUD. Accepted for now; filtering sprint-only perks by input device is a follow-up.

- Sprint is a deliberate, short burst that ends the moment the key is let go, which matches how the stamina bar is
  tuned (6 s of sprint, 6.5 s to refill).
- The input contract is a polled state instead of a signal, so no event can be missed between frames and tests drive it
  with plain key presses (`tests/test_player_input.gd`).
- Phones lose the sprint escape. If later tuning makes zombies faster than walking, touch play needs a sprint control
  again (for example pushing the move stick to its rim), and this ADR should be superseded.
- Holding L3 while steering with the same stick is awkward, which is why LB is bound too.
