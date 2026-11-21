#!/usr/bin/env python3
"""Turns downloaded CC0 recordings into the game's small mono WAV clips (audio/sfx/*.wav).

The recordings themselves are NOT in the repo (only the processed clips are). Sources, authors and licences are listed in
audio/CREDITS.md. To rebuild, download the files below into one empty folder and run:

    python scripts/sfx/process_real_samples.py --src <folder> [--out audio/sfx]

Needs numpy and soundfile (pip install numpy soundfile). Deterministic: fixed seeds, no randomness at run time.

Expected files in <folder> (OpenGameArt.org, all CC0):
    22 Magnum.wav, 22 Pistol.wav, Black Powder.wav, Unkown.wav      (gunshots by LarkPay)
    explosion.wav                                                   (Explosion by number99)
    undead-1.ogg .. undead-4.ogg                                    (Undead Moans by Antum Deluge)
    darsycho__zombie-moans.ogg, hungry-ghoul.ogg                    (Zombie moans / Hungry ghoul by darsycho)
    01-footstep.ogg .. 06-footstep.ogg                              (Footsteps by gboxmikefozzy)

What is real and what is synthesised: the recorded part of every clip is the CC0 file. Gunshots and the explosion
additionally get a synthesised low "thump" layer (sine with a pitch drop) and the explosion a decaying noise rumble
tail, to add weight the old recordings lack. Zombie hits are a synthesised wet impact plus a short real grunt.
"""
from __future__ import annotations

import argparse
import sys
import wave
from pathlib import Path

import numpy as np
import soundfile as sf

OUT_RATE = 44100


# --- helpers -----------------------------------------------------------------------------------------------------

def load_mono(path: Path) -> tuple[np.ndarray, int]:
    if path.suffix.lower() == ".wav":
        w = wave.open(str(path))
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
        data = data.reshape(-1, w.getnchannels()).mean(axis=1)
        return data, w.getframerate()
    data, rate = sf.read(str(path), dtype="float64")
    if data.ndim > 1:
        data = data.mean(axis=1)
    return data, rate


def resample(x: np.ndarray, rate_from: int, rate_to: int, pitch: float = 1.0) -> np.ndarray:
    """Resample to rate_to; pitch > 1 plays faster (higher and shorter)."""
    ratio = rate_from * pitch / rate_to
    if ratio > 1.0:  # decimating: crude box low-pass first to avoid aliasing
        k = int(round(ratio))
        if k > 1:
            x = np.convolve(x, np.ones(k) / k, mode="same")
    n = int(len(x) / ratio)
    return np.interp(np.arange(n) * ratio, np.arange(len(x)), x)


def seg(x: np.ndarray, rate: int, start: float, end: float) -> np.ndarray:
    return x[int(start * rate):int(end * rate)]


def fade(x: np.ndarray, rate: int, fade_in: float = 0.004, fade_out: float = 0.03) -> np.ndarray:
    x = x.copy()
    a, b = int(fade_in * rate), int(fade_out * rate)
    if a > 0:
        x[:a] *= np.linspace(0.0, 1.0, a)
    if b > 0:
        x[-b:] *= np.linspace(1.0, 0.0, b)
    return x


def lowpass(x: np.ndarray, cutoff: float, rate: int) -> np.ndarray:
    """One-pole low-pass (twice, for 12 dB/oct)."""
    a = np.exp(-2.0 * np.pi * cutoff / rate)
    for _ in range(2):
        y = np.empty_like(x)
        acc = 0.0
        for i in range(len(x)):
            acc = (1.0 - a) * x[i] + a * acc
            y[i] = acc
        x = y
    return x


def mix(*parts: tuple[np.ndarray, float, float], rate: int = OUT_RATE) -> np.ndarray:
    """parts = (samples, gain, offset_seconds)."""
    total = max(int(off * rate) + len(s) for s, _g, off in parts)
    out = np.zeros(total)
    for s, g, off in parts:
        i = int(off * rate)
        out[i:i + len(s)] += s * g
    return out


def normalise(x: np.ndarray, peak: float, drive: float = 1.0) -> np.ndarray:
    """Remove DC, optionally soft-compress (tanh `drive`: raises the body and tail against the sharp crack, which the
    raw recordings lack), then scale to `peak`."""
    x = x - x.mean()
    x = x / max(np.abs(x).max(), 1e-9)
    if drive > 1.0:
        x = np.tanh(x * drive)
    return x * (peak / max(np.abs(x).max(), 1e-9))


def thump(freq_start: float, freq_end: float, seconds: float, decay: float, rate: int = OUT_RATE) -> np.ndarray:
    """Low sine whose pitch falls exponentially: the 'punch' of a gun or explosion."""
    t = np.arange(int(seconds * rate)) / rate
    freq = freq_end + (freq_start - freq_end) * np.exp(-t * 18.0)
    phase = 2.0 * np.pi * np.cumsum(freq) / rate
    return np.sin(phase) * np.exp(-t * decay)


def rumble(seconds: float, cutoff: float, decay: float, seed: int, rate: int = OUT_RATE) -> np.ndarray:
    """Low-passed noise with a slow decay and a gentle tremolo: debris and rolling echo."""
    rng = np.random.default_rng(seed)
    n = int(seconds * rate)
    noise = lowpass(rng.uniform(-1, 1, n), cutoff, rate)
    t = np.arange(n) / rate
    return noise * np.exp(-t * decay) * (0.75 + 0.25 * np.sin(2 * np.pi * 7.0 * t))


def write_wav(path: Path, x: np.ndarray, rate: int = OUT_RATE) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(x, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())
    print(f"{path.name:26s} {len(x) / rate:5.2f}s")


# --- recipes -----------------------------------------------------------------------------------------------------

def shot(x96: np.ndarray, rate: int, onset: float, length: float, pitch: float, thump_gain: float,
         thump_hz: float, peak: float = 0.92) -> np.ndarray:
    """A recorded shot (crack + natural tail) with a synthesised punch layered under the first milliseconds."""
    clip = seg(x96, rate, max(0.0, onset - 0.012), onset - 0.012 + length)
    clip = resample(clip, rate, OUT_RATE, pitch)
    clip = clip / max(np.abs(clip).max(), 1e-9)
    punch = thump(thump_hz * 1.8, thump_hz, 0.22, 16.0) * thump_gain
    return normalise(fade(mix((clip, 1.0, 0.0), (punch, 1.0, 0.004)), OUT_RATE, 0.001, 0.05), peak, 4.0)


def build(src: Path, out: Path) -> None:
    gun = {k: load_mono(src / f"{k}.wav") for k in ("22 Magnum", "22 Pistol", "Black Powder", "Unkown")}

    # Gunshots. onset times (s) were found with a simple threshold on the 10 ms envelope of each file.
    pistol, pr = gun["22 Pistol"]
    magnum, mr = gun["22 Magnum"]
    powder, br = gun["Black Powder"]
    unknown, ur = gun["Unkown"]
    for i, (on, pitch) in enumerate(((0.14, 1.0), (0.59, 0.96), (0.95, 1.04)), start=1):
        write_wav(out / f"shot_pistol_{i}.wav", shot(pistol, pr, on, 0.38, pitch, 0.5, 130.0))
    for i, (on, pitch) in enumerate(((1.39, 1.25), (1.74, 1.3), (0.95, 1.2)), start=1):
        write_wav(out / f"shot_smg_{i}.wav", shot(pistol, pr, on, 0.3, pitch, 0.4, 150.0, 0.85))
    for i, (on, pitch) in enumerate(((0.14, 0.85), (0.84, 0.9), (1.55, 0.82)), start=1):
        write_wav(out / f"shot_shotgun_{i}.wav", shot(powder, br, on, 0.66, pitch, 0.9, 85.0, 0.95))
    for i, (on, pitch) in enumerate(((0.23, 0.8), (0.93, 0.85), (1.65, 0.78)), start=1):
        write_wav(out / f"shot_hmg_{i}.wav", shot(magnum, mr, on, 0.55, pitch, 0.8, 100.0, 0.95))
    # The "Unkown" file is a heavier rifle-like report; kept as a fourth HMG variant source.
    write_wav(out / "shot_hmg_4.wav", shot(unknown, ur, 0.26, 0.6, 0.95, 0.8, 95.0, 0.95))

    # Explosions: the recording, deepened (pitch down), with a sub boom and a long debris rumble tail.
    boom, er = load_mono(src / "explosion.wav")
    for i, (pitch, tail, hz) in enumerate(((0.8, 1.6, 48.0), (0.65, 2.0, 40.0), (0.95, 1.2, 55.0)), start=1):
        body = resample(boom, er, OUT_RATE, pitch)
        body = body / max(np.abs(body).max(), 1e-9)
        sub = thump(hz * 2.0, hz, 1.1, 3.2) * 1.1
        debris = rumble(tail, 700.0 + 200.0 * i, 1.9, 40 + i) * 0.7
        crackle = rumble(0.5, 6000.0, 8.0, 80 + i) * 0.25
        x = mix((body, 0.9, 0.0), (sub, 1.0, 0.0), (debris, 0.8, 0.12), (crackle, 1.0, 0.25))
        write_wav(out / f"explosion_{i}.wav", normalise(fade(x, OUT_RATE, 0.001, 0.2), 0.97, 3.0))

    # Zombie voices: real human-performed groans/growls at 22.05 kHz (voices do not need more).
    voice_rate = 22050
    groans = [(src / f"undead-{i}.ogg", 0.0, 2.2) for i in (1, 2, 3, 4)]
    groans += [(src / "darsycho__zombie-moans.ogg", 0.28, 2.3), (src / "darsycho__zombie-moans.ogg", 3.68, 2.4)]
    for i, (path, start, length) in enumerate(groans, start=1):
        x, r = load_mono(path)
        clip = resample(seg(x, r, start, start + length), r, voice_rate)
        write_wav(out / f"zombie_groan_{i}.wav", normalise(fade(clip, voice_rate, 0.02, 0.25), 0.8, 2.0), voice_rate)

    ghoul, gr = load_mono(src / "hungry-ghoul.ogg")
    moans, zr = load_mono(src / "darsycho__zombie-moans.ogg")
    # Death: a short ghoul cry (pitch up a bit: smaller, sharper) over a synthesised wet splat.
    deaths = [(ghoul, gr, 21.82, 22.56, 1.0), (ghoul, gr, 24.94, 25.8, 0.9), (moans, zr, 14.82, 15.64, 1.1)]
    for i, (x, r, a, b, pitch) in enumerate(deaths, start=1):
        cry = resample(seg(x, r, a, b), r, OUT_RATE, pitch)
        splat = rumble(0.35, 1800.0, 9.0, 120 + i) * 1.2
        body = thump(160.0, 70.0, 0.2, 14.0) * 0.8
        x2 = mix((fade(cry, OUT_RATE, 0.005, 0.15), 0.8, 0.02), (splat, 0.9, 0.0), (body, 0.6, 0.0))
        write_wav(out / f"zombie_die_{i}.wav", normalise(fade(x2, OUT_RATE, 0.001, 0.1), 0.88, 2.5))

    # Hit: wet thud plus a tiny grunt fragment.
    grunts = [(ghoul, gr, 2.28, 2.5, 1.1), (moans, zr, 9.34, 9.58, 1.0), (moans, zr, 10.46, 10.7, 1.15), (ghoul, gr, 26.52, 26.76, 1.0)]
    for i, (x, r, a, b, pitch) in enumerate(grunts, start=1):
        grunt = resample(seg(x, r, a, b), r, OUT_RATE, pitch)
        wet = rumble(0.12, 2500.0, 24.0, 160 + i) * 1.4
        body = thump(210.0, 90.0, 0.12, 26.0)
        x2 = mix((wet, 0.9, 0.0), (body, 0.8, 0.0), (fade(grunt, OUT_RATE, 0.004, 0.06), 0.5, 0.015))
        write_wav(out / f"zombie_hit_{i}.wav", normalise(fade(x2, OUT_RATE, 0.001, 0.04), 0.8, 2.5))

    # Footsteps on hard ground: recordings, lightly deepened and low-passed so they sit under the gunfire.
    for i in range(1, 7):
        x, r = load_mono(src / f"{i:02d}-footstep.ogg")
        step = resample(x, r, OUT_RATE, 0.92 + 0.03 * i)
        step = lowpass(step, 5000.0, OUT_RATE)
        write_wav(out / f"footstep_{i}.wav", normalise(fade(step, OUT_RATE, 0.002, 0.04), 0.75, 2.0))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", required=True, help="folder with the downloaded CC0 recordings")
    ap.add_argument("--out", default="audio/sfx")
    args = ap.parse_args()
    build(Path(args.src), Path(args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
