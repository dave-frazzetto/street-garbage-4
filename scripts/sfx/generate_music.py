#!/usr/bin/env python3
"""Generates the background music loop with the same sfxr-style synth as the sound effects.

A deliberately simple 8-bar loop at 96 BPM in A minor with a flat-two chord (Bb) for the eerie feel:
a low pulsing bass, a slow detuned saw pad, a sparse arpeggio with an echo, a kick and off-beat hats.
Notes that ring past the end wrap around to the start, so the file loops without a click.

Usage:
    python scripts/sfx/generate_music.py [--out audio/music/street_loop.wav]
Tweak the constants and CHORDS below, re-run, done. Output is deterministic.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_sfx as g  # noqa: E402

BPM = 96
BARS = 8
BEAT = 60.0 / BPM
LOOP_SECONDS = BARS * 4 * BEAT
N = int(LOOP_SECONDS * g.RATE)
PEAK = 0.7

# One chord per two bars: (semitones above A, third in semitones). Am, Bb (the eerie one), Am, F.
CHORDS = [(0, 3), (1, 4), (0, 3), (-4, 4)]
BASS_PATTERN = [1, 0, 1, 1, 0, 1, 0, 1]      # eighth notes per bar
ARP_STEPS = [0, 3, 6, 8, 11, 14]             # sixteenth positions per bar
HAT_STEPS = [2, 6, 10, 14]                   # sixteenths (off-beat eighths)
GAINS = dict(pad=0.22, bass=0.55, arp=0.16, echo=0.07, kick=0.75, hat=0.1)

_buf = [0.0] * N
_cache: dict = {}


def hz(semitones: float, base: float = 110.0) -> float:
    return base * 2.0 ** (semitones / 12.0)


def add(t: float, gain: float, seed: int, **kw: float) -> None:
    """Mix one synth voice into the loop buffer at time t (seconds), wrapping around the loop end."""
    key = (tuple(sorted(kw.items())), seed)
    if key not in _cache:
        _, _, p = g.layer(**kw)
        _cache[key] = g.render_layer(p, seed)
    start = int(t * g.RATE) % N
    for i, v in enumerate(_cache[key]):
        _buf[(start + i) % N] += v * gain


def build() -> None:
    for chord_index, (root, third) in enumerate(CHORDS):
        t0 = chord_index * 2 * 4 * BEAT
        # Pad: root, fifth and a high third, slow attack, plus a detuned root for the unsettled shimmer.
        for k, st in enumerate([root, root + 7, root + third + 12, root + 0.15]):
            add(t0, GAINS["pad"], 10 + k, wave=g.SAW, freq=g.Hz(hz(st)), attack=0.9, sustain=3.2, decay=1.4,
                lpf=0.32, lpf_res=0.3)
        for bar in range(2):
            tb = t0 + bar * 4 * BEAT
            bass_st = root if root >= 0 else root + 12
            for i, on in enumerate(BASS_PATTERN):
                if on:
                    add(tb + i * BEAT / 2, GAINS["bass"], 20, wave=g.SQUARE, freq=g.Hz(hz(bass_st - 12 + 12, 55.0)),
                        duty=0.5, sustain=0.05, decay=0.17, lpf=0.36, punch=0.3)
            for beat in (0, 2):
                add(tb + beat * BEAT, GAINS["kick"], 30, wave=g.SINE, freq=g.Hz(120), ramp=-0.3, sustain=0.01,
                    decay=0.16, punch=0.4)
            for s in HAT_STEPS:
                add(tb + s * BEAT / 4, GAINS["hat"], 40, wave=g.NOISE, freq=g.Hz(6000), sustain=0.005, decay=0.04,
                    hpf=0.45)
            tones = [root + 24, root + third + 24, root + 31, root + third + 24, root + 19]
            for n, s in enumerate(ARP_STEPS):
                st = tones[n % len(tones)] + (12 if (bar == 1 and n == 5) else 0)
                t = tb + s * BEAT / 4
                add(t, GAINS["arp"], 50, wave=g.SQUARE, freq=g.Hz(hz(st)), duty=0.35, sustain=0.03, decay=0.14,
                    vib_strength=0.05, vib_speed=0.4, lpf=0.7)
                add(t + BEAT * 0.75, GAINS["echo"], 51, wave=g.SQUARE, freq=g.Hz(hz(st)), duty=0.35, sustain=0.03,
                    decay=0.18, lpf=0.5)


def write(path: Path) -> None:
    mean = sum(_buf) / N
    out = [s - mean for s in _buf]
    k = PEAK / (max(abs(s) for s in out) or 1.0)
    g.write_wav(path, [s * k for s in out])


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="audio/music/street_loop.wav")
    args = ap.parse_args()
    build()
    write(Path(args.out))
    print(f"{args.out}: {LOOP_SECONDS:.1f}s loop, {BPM} BPM")


if __name__ == "__main__":
    main()
