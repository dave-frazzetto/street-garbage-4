---
type: Architecture Decision Record
title: Looping background music from the same synth
description: One 20-second generated loop plays through a MusicPlayer node owned by GameFlow, fading in with the run and out when it ends.
tags: [audio]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T17:53:17Z
status: stable
lifecycle: accepted
deciders: [claude]
---

# Looping background music from the same synth

## Status

Accepted

## Context

After the sound effects (see `procedural-sound-effects-with-sfxr-style-generator`) the run still has no music. The owner
asked for something very simple, a little cyberpunk and eerie, made with the same tools.

## Decision

Generate one loop with `scripts/sfx/generate_music.py`, which imports the SFX synth: 8 bars at 96 BPM in A minor with a
Bb chord for the unease, a pulsing square bass, a slow detuned saw pad, a sparse echoing arpeggio, a kick and off-beat
hats. Notes that ring past the end wrap to the start, so the WAV loops without a click. The result is
`audio/music/street_loop.wav` (20 s, mono, about 1.7 MB, ADPCM after import).

`MusicPlayer` (scene in `audio/`) plays one stream with exported volume and fade times. It loops a duplicated copy of the
stream, so the shared import is never edited, and it keeps playing while the tree is paused. `GameFlow` starts it with a
run and fades it out when the run ends, so the end jingles are heard.

## Consequences

- Music is one track with no variation or intensity layers; richer music would be a later decision.
- Looping is set at runtime because the import sidecars are not committed.
- The music was composed by rule and checked for length, level and a continuous loop seam, not by ear. Volume
  (`volume_db` on the node, default -14) and the notes in the script will likely need tuning by the owner.
- The title screen is silent; music begins with the first run.
