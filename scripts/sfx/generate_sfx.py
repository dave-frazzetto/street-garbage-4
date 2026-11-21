#!/usr/bin/env python3
"""Procedural sound-effect generator (sfxr-style synth, Python standard library only).

Renders every effect listed in SOUNDS to a mono 16-bit 44.1 kHz WAV. Output is deterministic: each effect and
variant uses a fixed seed, so re-running produces identical files and git diffs stay quiet.

Usage:
    python scripts/sfx/generate_sfx.py [--out audio/sfx] [--only name1,name2] [--list]

An effect is a list of layers; a layer is (offset_seconds, gain, params). `params` are sfxr parameters (see P).
Hz() converts a pitch in Hz into sfxr's base-frequency parameter. Variants (name_1, name_2 ...) mutate the
frequency and length a little so repeated sounds (gunshots, hits) do not feel mechanical.

Designers: tweak a preset below and re-run, or just replace the .wav files; the game only reads audio/sfx/*.wav
through the SfxCue resources in audio/cues/.
"""
from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
SQUARE, SAW, SINE, NOISE = 0, 1, 2, 3

# sfxr parameter defaults.
P = dict(
    wave=SQUARE, attack=0.0, sustain=0.3, punch=0.0, decay=0.4,
    freq=0.3, freq_limit=0.0, ramp=0.0, dramp=0.0,
    vib_strength=0.0, vib_speed=0.0,
    arp_mod=0.0, arp_speed=0.0,
    duty=0.0, duty_ramp=0.0,
    repeat_speed=0.0,
    pha_offset=0.0, pha_ramp=0.0,
    lpf=1.0, lpf_ramp=0.0, lpf_res=0.0,
    hpf=0.0, hpf_ramp=0.0,
)


def Hz(hz: float) -> float:
    """sfxr base-frequency parameter for a pitch in Hz."""
    return math.sqrt(max(hz / 3528.0 - 0.001, 0.0))


def T(seconds: float) -> float:
    """sfxr envelope parameter for a duration in seconds (envelope samples = parameter^2 * 100000)."""
    return math.sqrt(seconds * RATE / 100000.0)


def layer(offset: float = 0.0, gain: float = 1.0, **kw: float) -> tuple[float, float, dict]:
    """One synth voice. attack / sustain / decay are given in seconds; everything else is a raw sfxr parameter."""
    p = dict(P)
    p.update(kw)
    for key in ("attack", "sustain", "decay"):
        if key in kw:
            p[key] = T(kw[key])
    return (offset, gain, p)


def render_layer(p: dict, seed: int) -> list[float]:
    """Port of the classic sfxr synthesis loop. Returns samples in [-1, 1]."""
    rng = random.Random(seed)
    wave_type = int(p["wave"])
    fperiod_start = 100.0 / (p["freq"] ** 2 + 0.001)
    fmaxperiod = 100.0 / (p["freq_limit"] ** 2 + 0.001)
    fperiod = fperiod_start
    fslide = 1.0 - p["ramp"] ** 3 * 0.01
    fdslide = -(p["dramp"] ** 3) * 0.000001
    duty = 0.5 - p["duty"] * 0.5
    duty_slide = -p["duty_ramp"] * 0.00005
    arp_mod = 1.0 - p["arp_mod"] ** 2 * 0.9 if p["arp_mod"] >= 0 else 1.0 + p["arp_mod"] ** 2 * 10.0
    arp_limit = int((1.0 - p["arp_speed"]) ** 2 * 20000 + 32)
    if p["arp_speed"] == 1.0:
        arp_limit = 0
    arp_time = 0
    env_len = [int(p["attack"] ** 2 * 100000), int(p["sustain"] ** 2 * 100000), int(p["decay"] ** 2 * 100000)]
    env_len = [max(1, n) for n in env_len]
    fphase = p["pha_offset"] ** 2 * 1020.0 * (-1 if p["pha_offset"] < 0 else 1)
    fdphase = p["pha_ramp"] ** 2 * 1.0 * (-1 if p["pha_ramp"] < 0 else 1)
    iphase = min(1023, abs(int(fphase)))
    phaser = [0.0] * 1024
    ipp = 0
    fltw = p["lpf"] ** 3 * 0.1
    fltw_d = 1.0 + p["lpf_ramp"] * 0.0001
    fltdmp = min(0.8, 5.0 / (1.0 + p["lpf_res"] ** 2 * 20.0) * (0.01 + fltw))
    lpf_on = p["lpf"] != 1.0
    flthp = p["hpf"] ** 2 * 0.1
    flthp_d = 1.0 + p["hpf_ramp"] * 0.0003
    vib_speed = p["vib_speed"] ** 2 * 0.01
    vib_amp = p["vib_strength"] * 0.5
    vib_phase = 0.0
    rep_limit = int((1.0 - p["repeat_speed"]) ** 2 * 20000 + 32) if p["repeat_speed"] > 0 else 0
    rep_time = 0
    noise = [rng.random() * 2 - 1 for _ in range(32)]

    phase = 0
    stage = 0
    env_time = 0
    fltp = fltdp = fltphp = 0.0
    out: list[float] = []
    finished = False
    while not finished:
        rep_time += 1
        if rep_limit and rep_time >= rep_limit:
            rep_time = 0
            fperiod = fperiod_start
            fslide = 1.0 - p["ramp"] ** 3 * 0.01
            fdslide = -(p["dramp"] ** 3) * 0.000001
            arp_time = 0
        arp_time += 1
        if arp_limit and arp_time >= arp_limit:
            arp_limit = 0
            fperiod *= arp_mod
        fslide += fdslide
        fperiod *= fslide
        if fperiod > fmaxperiod:
            fperiod = fmaxperiod
            if p["freq_limit"] > 0.0:
                break
        rfperiod = fperiod
        if vib_amp > 0.0:
            vib_phase += vib_speed
            rfperiod = fperiod * (1.0 + math.sin(vib_phase) * vib_amp)
        period = max(8, int(rfperiod))
        duty = min(0.5, max(0.0, duty + duty_slide))
        env_time += 1
        if env_time > env_len[stage]:
            env_time = 0
            stage += 1
            if stage == 3:
                break
        if stage == 0:
            env_vol = env_time / env_len[0]
        elif stage == 1:
            env_vol = 1.0 + (1.0 - env_time / env_len[1]) * 2.0 * p["punch"]
        else:
            env_vol = 1.0 - env_time / env_len[2]
        fphase += fdphase
        iphase = min(1023, abs(int(fphase)))
        if flthp_d != 0.0:
            flthp = min(0.1, max(0.00001, flthp * flthp_d))
        ss = 0.0
        for _ in range(8):
            phase += 1
            if phase >= period:
                phase %= period
                if wave_type == NOISE:
                    noise = [rng.random() * 2 - 1 for _ in range(32)]
            fp = phase / period
            if wave_type == SQUARE:
                s = 0.5 if fp < duty else -0.5
            elif wave_type == SAW:
                s = 1.0 - fp * 2.0
            elif wave_type == SINE:
                s = math.sin(fp * 2.0 * math.pi)
            else:
                s = noise[int(phase * 32 / period)]
            pp = fltp
            fltw = min(0.1, max(0.0, fltw * fltw_d))
            if lpf_on:
                fltdp += (s - fltp) * fltw
                fltdp -= fltdp * fltdmp
            else:
                fltp = s
                fltdp = 0.0
            fltp += fltdp
            fltphp += fltp - pp
            fltphp -= fltphp * flthp
            s = fltphp
            phaser[ipp & 1023] = s
            s += phaser[(ipp - iphase + 1024) & 1023]
            ipp = (ipp + 1) & 1023
            ss += s * env_vol
        out.append(max(-1.0, min(1.0, ss / 8.0 * 2.0)))
    return out


def mutate(p: dict, rng: random.Random, amount: float) -> dict:
    q = dict(p)
    for key in ("freq", "ramp", "decay", "sustain", "lpf", "arp_mod", "vib_strength"):
        if q[key] != 0.0 and not (key == "lpf" and q[key] == 1.0):
            q[key] = q[key] * (1.0 + rng.uniform(-amount, amount))
    q["freq"] = max(0.02, q["freq"])
    q["lpf"] = min(1.0, q["lpf"])
    return q


def render_sound(layers: list[tuple[float, float, dict]], seed: int, variant: int, amount: float) -> list[float]:
    rng = random.Random(seed * 1000 + variant)
    rendered: list[tuple[int, list[float]]] = []
    total = 0
    for i, (offset, gain, params) in enumerate(layers):
        p = mutate(params, rng, amount) if variant > 0 else params
        samples = render_layer(p, seed * 31 + i + variant * 7)
        start = int(offset * RATE)
        rendered.append((start, [s * gain for s in samples]))
        total = max(total, start + len(samples))
    mix = [0.0] * total
    for start, samples in rendered:
        for i, s in enumerate(samples):
            mix[start + i] += s
    return mix


def finish(samples: list[float], peak: float) -> list[float]:
    """Remove DC offset, fade the last 8 ms (no click), normalise to `peak`."""
    if not samples:
        return samples
    mean = sum(samples) / len(samples)
    samples = [s - mean for s in samples]
    fade = min(len(samples), int(0.008 * RATE))
    for i in range(fade):
        samples[len(samples) - 1 - i] *= i / fade
    top = max(abs(s) for s in samples) or 1.0
    k = peak / top
    return [s * k for s in samples]


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))


# ---------------------------------------------------------------------------------------------------------------
# Presets. name -> (variants, mutation amount, peak, layers).
# ---------------------------------------------------------------------------------------------------------------

def notes(hzs: list[float], step: float, wave_type: int = SQUARE, sustain: float = 0.06, decay: float = 0.15,
          gain: float = 1.0, **kw: float) -> list:
    """A little melody: one layer per note (times in seconds)."""
    return [layer(i * step, gain, wave=wave_type, freq=Hz(h), sustain=sustain, decay=decay, **kw)
            for i, h in enumerate(hzs)]


# Times (offset, attack, sustain, decay) are in seconds.
# Gunshots, zombie hit/die/groans, explosions and footsteps are NOT here any more: they are built from CC0
# recordings by scripts/sfx/process_real_samples.py (see audio/CREDITS.md). Ambience is synthesised below.
SOUNDS: dict[str, tuple[int, float, float, list]] = {
    # Player takes damage: falling buzz with a bite.
    "player_hurt": (2, 0.08, 0.9, [
        layer(0.0, 1.0, wave=SQUARE, freq=Hz(330), ramp=-0.3, duty=0.3, vib_strength=0.2, vib_speed=0.6,
              sustain=0.05, decay=0.22, punch=0.3),
        layer(0.0, 0.7, wave=NOISE, freq=Hz(900), sustain=0.03, decay=0.12, lpf=0.5),
    ]),
    # Pickups.
    "pickup_gear": (1, 0.0, 0.85, [
        layer(0.00, 1.0, wave=SQUARE, freq=Hz(660), duty=0.3, sustain=0.04, decay=0.12),
        layer(0.08, 1.0, wave=SQUARE, freq=Hz(990), duty=0.3, sustain=0.06, decay=0.28),
        layer(0.08, 0.5, wave=SINE, freq=Hz(1980), sustain=0.04, decay=0.28),
    ]),
    "pickup_health": (1, 0.0, 0.8, [
        layer(0.0, 1.0, wave=SINE, freq=Hz(440), ramp=-0.15, sustain=0.1, decay=0.25, vib_strength=0.1, vib_speed=0.4),
        layer(0.08, 0.8, wave=SINE, freq=Hz(660), sustain=0.08, decay=0.28),
    ]),
    "prop_break": (2, 0.1, 0.9, [
        layer(0.0, 1.0, wave=NOISE, freq=Hz(1400), sustain=0.04, decay=0.28, punch=0.5, lpf=0.7, repeat_speed=0.7),
        layer(0.0, 0.6, wave=SQUARE, freq=Hz(310), ramp=-0.2, duty=0.6, sustain=0.03, decay=0.18, hpf=0.1),
    ]),
    # Progression jingles.
    "level_up": (1, 0.0, 0.85, notes([523, 659, 784, 1047], 0.075, SQUARE, sustain=0.06, decay=0.18, duty=0.35)),
    "perk_pick": (1, 0.0, 0.8, notes([784, 1175], 0.08, SQUARE, sustain=0.06, decay=0.18, duty=0.3)
                  + [layer(0.08, 0.4, wave=SINE, freq=Hz(2350), sustain=0.04, decay=0.18)]),
    "perk_redraw": (1, 0.0, 0.7, [
        layer(0.00, 0.7, wave=NOISE, freq=Hz(2000), sustain=0.015, decay=0.05, lpf=0.5, hpf=0.2),
        layer(0.07, 0.7, wave=NOISE, freq=Hz(2600), sustain=0.015, decay=0.05, lpf=0.5, hpf=0.2),
        layer(0.14, 0.7, wave=NOISE, freq=Hz(3200), sustain=0.015, decay=0.07, lpf=0.5, hpf=0.2),
    ]),
    "perk_skip": (1, 0.0, 0.6, [
        layer(0.0, 1.0, wave=SQUARE, freq=Hz(300), ramp=-0.25, duty=0.5, sustain=0.02, decay=0.08),
    ]),
    "ui_start": (1, 0.0, 0.8, notes([392, 523, 784], 0.09, SQUARE, sustain=0.06, decay=0.25, duty=0.4)),
    "extraction_denied": (1, 0.0, 0.8, [
        layer(0.00, 1.0, wave=SQUARE, freq=Hz(150), duty=0.5, sustain=0.06, decay=0.08),
        layer(0.16, 1.0, wave=SQUARE, freq=Hz(120), duty=0.5, sustain=0.08, decay=0.14),
    ]),
    "run_win": (1, 0.0, 0.85, notes([523, 659, 784, 659, 784, 1047, 1319], 0.11, SQUARE, sustain=0.08, decay=0.22, duty=0.35)),
    "run_lose": (1, 0.0, 0.85, notes([392, 330, 262, 196], 0.22, SAW, sustain=0.12, decay=0.3, ramp=-0.05, lpf=0.6)),
    "run_nuked": (1, 0.0, 1.0, [
        layer(0.0, 1.0, wave=NOISE, freq=Hz(90), sustain=0.5, decay=1.2, punch=0.9, lpf=0.45, lpf_ramp=-0.1),
        layer(0.0, 1.0, wave=SINE, freq=Hz(45), ramp=-0.1, sustain=0.4, decay=1.1, punch=0.7),
        layer(0.4, 0.5, wave=NOISE, freq=Hz(250), sustain=0.3, decay=1.0, lpf=0.35),
    ]),
}


# ---------------------------------------------------------------------------------------------------------------
# Ambience (synthesised). Rendered at a lower rate to keep the files small: it is all low-frequency.
# ---------------------------------------------------------------------------------------------------------------

AMB_RATE = 22050


def one_pole_lp(x: list[float], cutoff: float, rate: int) -> list[float]:
    a = math.exp(-2.0 * math.pi * cutoff / rate)
    out, acc = [], 0.0
    for v in x:
        acc = (1.0 - a) * v + a * acc
        out.append(acc)
    return out


def lp2(x: list[float], cutoff: float, rate: int) -> list[float]:
    return one_pole_lp(one_pole_lp(x, cutoff, rate), cutoff, rate)


def white(n: int, rng: random.Random) -> list[float]:
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def normalised(x: list[float], peak: float) -> list[float]:
    top = max(abs(v) for v in x) or 1.0
    return [v * peak / top for v in x]


def comb_reverb(x: list[float], rate: int, wet: float = 0.35) -> list[float]:
    """Cheap Schroeder-style echo tail: four feedback combs, used to make far-away sounds feel distant."""
    out = list(x)
    for delay_s, fb in ((0.0297, 0.62), (0.0371, 0.58), (0.0411, 0.55), (0.0437, 0.5)):
        d = int(delay_s * rate)
        buf = [0.0] * len(x)
        for i in range(len(x)):
            buf[i] = x[i] + (buf[i - d] * fb if i >= d else 0.0)
        out = [o + b * wet / 4.0 for o, b in zip(out, buf)]
    return out


def city_bed(seconds: int = 24, seed: int = 11) -> list[float]:
    """Seamless loop: distant traffic rumble, passing-car swells, wind gusts and a faint electrical hum.
    Every modulator completes a whole number of cycles in `seconds`, and the noise seam is cross-faded."""
    rate = AMB_RATE
    rng = random.Random(seed)
    pad = 2 * rate
    n = seconds * rate + pad
    t = [i / rate for i in range(n)]
    cyc = 1.0 / seconds
    # Traffic rumble: low-passed noise whose level breathes slowly.
    rumble = lp2(white(n, rng), 140.0, rate)
    rumble = [r * (0.75 + 0.25 * math.sin(2 * math.pi * cyc * 3 * ti + 1.0) + 0.1 * math.sin(2 * math.pi * cyc * 7 * ti))
              for r, ti in zip(rumble, t)]
    # Road hiss: mid noise with a few car-pass swells.
    hiss = lp2(white(n, rng), 1100.0, rate)
    swell = [0.0] * n
    for centre, width, level in ((4.0, 1.6, 0.9), (9.5, 2.2, 0.7), (14.0, 1.4, 1.0), (19.0, 2.0, 0.6)):
        for i in range(n):
            swell[i] += level * math.exp(-(((t[i] - centre) / width) ** 2))
    hiss = [h * (0.12 + 0.9 * sw) for h, sw in zip(hiss, swell)]
    # Wind: band-limited noise with gusts.
    wind_lo = lp2(white(n, rng), 650.0, rate)
    wind_hi = lp2(wind_lo, 160.0, rate)
    wind = [(a - b) * (0.55 + 0.45 * math.sin(2 * math.pi * cyc * 5 * ti + 0.4) * math.sin(2 * math.pi * cyc * 2 * ti + 2.0))
            for a, b, ti in zip(wind_lo, wind_hi, t)]
    hum = [0.04 * math.sin(2 * math.pi * 50.0 * ti) + 0.025 * math.sin(2 * math.pi * 100.0 * ti) for ti in t]
    mixed = [1.0 * r + 0.55 * h + 1.0 * w + hm for r, h, w, hm in zip(rumble, hiss, wind, hum)]
    # Seamless: the last `pad` samples fade into the first ones.
    body = mixed[:seconds * rate]
    for i in range(pad):
        k = i / pad
        body[i] = body[i] * k + mixed[seconds * rate + i] * (1.0 - k)
    mean = sum(body) / len(body)
    return normalised([v - mean for v in body], 0.6)


def siren_far(variant: int) -> list[float]:
    """A distant wail / yelp siren drifting past, with echo."""
    rate = AMB_RATE
    seconds = 7.0 + variant
    n = int(seconds * rate)
    out, phase = [], 0.0
    for i in range(n):
        ti = i / rate
        if variant == 0:  # slow wail
            f = 700.0 + 350.0 * (0.5 - 0.5 * math.cos(2 * math.pi * ti / 2.4))
        else:  # yelp: faster, steeper
            f = 650.0 + 450.0 * (ti * 3.2 % 1.0)
        phase += 2 * math.pi * f / rate
        v = math.sin(phase) + 0.5 * math.sin(2 * phase) + 0.25 * math.sin(3 * phase)
        env = math.sin(math.pi * ti / seconds) ** 2  # swells up and fades: it drives by
        out.append(v * env)
    out = lp2(out, 1800.0, rate)
    return normalised(comb_reverb(out, rate, 0.7), 0.5)


def dog_far(variant: int) -> list[float]:
    """Three muffled distant barks."""
    rate = AMB_RATE
    rng = random.Random(30 + variant)
    n = int(2.2 * rate)
    out = [0.0] * n
    for k in range(3):
        start = int((0.1 + k * (0.42 + 0.05 * variant)) * rate)
        base = 470.0 - 60.0 * variant
        phase = 0.0
        for i in range(int(0.2 * rate)):
            ti = i / rate
            f = base * (1.0 - 0.35 * ti / 0.2) * (1.0 - 0.08 * k)
            phase += 2 * math.pi * f / rate
            v = (math.sin(phase) + 0.6 * math.sin(2 * phase) + 0.4 * math.sin(3 * phase)) * (0.7 + 0.3 * rng.uniform(-1, 1))
            env = math.sin(math.pi * min(1.0, ti / 0.2)) ** 0.7 * math.exp(-ti * 5.0)
            if start + i < n:
                out[start + i] += v * env
    out = lp2(out, 1500.0, rate)
    return normalised(comb_reverb(out, rate, 0.9), 0.5)


def thud_far() -> list[float]:
    """A far-off boom rolling across the city."""
    rate = AMB_RATE
    rng = random.Random(77)
    n = int(3.5 * rate)
    noise = lp2(white(n, rng), 120.0, rate)
    out = [noise[i] * math.exp(-i / rate * 1.6) * min(1.0, i / (0.05 * rate)) for i in range(n)]
    for i in range(int(0.5 * rate)):
        ti = i / rate
        out[i] += 0.8 * math.sin(2 * math.pi * 45.0 * ti) * math.exp(-ti * 6.0)
    return normalised(out, 0.7)


# name -> renderers (one file per entry: name_1, name_2 ...; a single one is just name.wav).
AMBIENT = {
    "city_bed": [city_bed],
    "siren_far": [lambda: siren_far(0), lambda: siren_far(1)],
    "dog_far": [lambda: dog_far(0), lambda: dog_far(1)],
    "thud_far": [thud_far],
}


def write_wav_rate(path: Path, samples: list[float], rate: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))



def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="audio/sfx", help="output directory (default audio/sfx)")
    ap.add_argument("--only", default="", help="comma-separated effect names to render")
    ap.add_argument("--ambient-out", default="audio/ambient", help="output directory for the ambience clips")
    ap.add_argument("--list", action="store_true", help="list effect names and exit")
    args = ap.parse_args()
    if args.list:
        for name, (variants, *_rest) in SOUNDS.items():
            print(name, f"x{variants}" if variants > 1 else "")
        for name, renderers in AMBIENT.items():
            print(name, f"x{len(renderers)}" if len(renderers) > 1 else "", "(ambient)")
        return
    wanted = {n for n in args.only.split(",") if n}
    unknown = wanted - set(SOUNDS) - set(AMBIENT)
    if unknown:
        raise SystemExit(f"unknown effects: {', '.join(sorted(unknown))}")
    out = Path(args.out)
    for seed, (name, (variants, amount, peak, layers)) in enumerate(SOUNDS.items(), start=1):
        if wanted and name not in wanted:
            continue
        for v in range(variants):
            samples = finish(render_sound(layers, seed, v, amount), peak)
            file = f"{name}_{v + 1}.wav" if variants > 1 else f"{name}.wav"
            write_wav(out / file, samples)
            print(f"{file:28s} {len(samples) / RATE:5.2f}s  peak {max(abs(s) for s in samples):.2f}")
    for name, renderers in AMBIENT.items():
        if wanted and name not in wanted:
            continue
        for v, render in enumerate(renderers):
            samples = render()
            file = f"{name}_{v + 1}.wav" if len(renderers) > 1 else f"{name}.wav"
            write_wav_rate(Path(args.ambient_out) / file, samples, AMB_RATE)
            print(f"{file:28s} {len(samples) / AMB_RATE:5.2f}s  peak {max(abs(s) for s in samples):.2f}")


if __name__ == "__main__":
    main()
