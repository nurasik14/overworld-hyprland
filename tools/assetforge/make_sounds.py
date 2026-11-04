#!/usr/bin/env python3
"""Synthesize the original fallback UI sounds -> assets/gen/sounds/*.wav (committed; project licence).

Everything is made from scratch with numpy (noise bursts, sine/triangle tones, envelopes) — nothing is derived
from Mojang audio.  The theme uses these only when assets/mc/sounds is absent (tokens/sounds.json "fallback").

Usage: make_sounds.py [--out DIR]
"""
import argparse
import wave
import zlib
from pathlib import Path

import numpy as np

SR = 24000


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.002, d=0.1, sustain=0.0, curve=3.0):
    """attack/exp-decay envelope over n samples"""
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-6), np.exp(-(t - a) / max(d, 1e-6) * curve / 3))
    return e * (1 - sustain) + sustain * (t < a + d)


def fft_filter(x, lo=None, hi=None):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    m = np.ones_like(f)
    if lo:
        m *= 1 / (1 + (lo / np.maximum(f, 1)) ** 4)
    if hi:
        m *= 1 / (1 + (f / hi) ** 4)
    return np.fft.irfft(X * m, len(x))


def noise(rng, dur, lo=None, hi=None):
    return fft_filter(rng.standard_normal(int(SR * dur)), lo, hi)


def tone(freq, dur, kind="sine", phase=0.0):
    t = t_(dur)
    p = 2 * np.pi * freq * t + phase
    if kind == "sine":
        return np.sin(p)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(p))
    if kind == "square":
        return np.sign(np.sin(p)) * 0.6
    if kind == "bell":  # inharmonic partials
        return sum(a * np.sin(p * r) * np.exp(-t * dk) for r, a, dk in
                   [(1, 1, 3), (2.76, .5, 5), (5.4, .3, 8), (8.93, .15, 12)])
    raise ValueError(kind)


def mix(*parts, dur=None):
    parts = [(int(round(SR * o)), p) for o, p in parts]
    n = max([int(SR * dur) if dur else 0] + [o + len(p) for o, p in parts])
    out = np.zeros(n)
    for o, p in parts:
        out[o:o + len(p)] += p
    return out


def fade_edges(x, ms=3):
    n = int(SR * ms / 1000)
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def save(path: Path, x, peak=0.7):
    x = fade_edges(x)
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * peak
    pcm = (x * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def build(out: Path):
    out.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(1234)
    S = {}

    # ---- UI
    n = int(SR * 0.05)
    S["click"] = (noise(rng, 0.05, 1500, 6000) * env(n, .0005, .012) * .8 + tone(1800, 0.05, "tri") * env(n, .0005, .01) * .4)
    n = int(SR * 0.12)
    f = np.linspace(500, 1400, n)  # rising blip
    S["pop"] = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, .001, .05) + noise(rng, 0.12, 800, 4000) * env(n, .0005, .01) * .3
    S["orb"] = mix((0, tone(1318.5, .22, "tri") * env(int(SR * .22), .002, .12)),
                   (0.06, tone(1760, .26, "tri") * env(int(SR * .26), .002, .14)),
                   (0.12, tone(2217, .30, "sine") * env(int(SR * .30), .002, .16) * .7))
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    S["levelup"] = mix(*[(i * 0.085, tone(f_, .5, "tri") * env(int(SR * .5), .003, .22) * (0.6 + .1 * i)) for i, f_ in enumerate(notes)],
                       (0.42, tone(1568, .8, "sine") * env(int(SR * .8), .003, .4) * .6))
    n = int(SR * .35)
    S["toast_in"] = noise(rng, .35, 300, 2500) * np.sin(np.linspace(0, np.pi, n)) ** 2 * .6 + tone(660, .35, "sine") * np.exp(-np.arange(n) / SR * 10) * .25
    S["toast_out"] = S["toast_in"][::-1] * .8
    S["challenge"] = mix(*[(i * 0.11, tone(f_, 1.0, "bell") * env(int(SR * 1.0), .002, .5)) for i, f_ in enumerate([392, 523.25, 659.25, 784, 1046.5])],
                         (0.6, tone(130.8, .9, "sine") * env(int(SR * .9), .01, .5) * .6))
    S["notify"] = mix((0, tone(988, .25, "tri") * env(int(SR * .25), .002, .1)), (0.1, tone(1319, .35, "tri") * env(int(SR * .35), .002, .16)))
    S["notify_urgent"] = mix(*[(i * 0.14, tone(880 if i % 2 == 0 else 660, .22, "square") * env(int(SR * .22), .002, .09) * .6) for i in range(4)])

    # ---- containers / paper / glass bottle
    n = int(SR * .3)
    S["chest_open"] = mix((0, noise(rng, .25, 80, 900) * env(int(SR * .25), .01, .1) * .5),
                          (0.02, tone(130, .3, "sine") * env(n, .004, .12) * np.linspace(1, .5, n) * .9),
                          (0.18, tone(70, .2, "sine") * env(int(SR * .2), .002, .08)))
    S["chest_close"] = mix((0, noise(rng, .12, 80, 1200) * env(int(SR * .12), .001, .04) * .9),
                           (0, tone(85, .18, "sine") * env(int(SR * .18), .001, .07)))
    S["door_open"] = mix((0, noise(rng, .3, 200, 1600) * np.sin(np.linspace(0, np.pi, int(SR * .3))) * .35),
                         (0, tone(150, .22, "sine") * np.linspace(1, 1.4, int(SR * .22)) * env(int(SR * .22), .02, .1) * .6))
    S["door_close"] = mix((0, noise(rng, .1, 100, 1800) * env(int(SR * .1), .001, .03)),
                          (0, tone(110, .16, "sine") * env(int(SR * .16), .001, .06)))
    n = int(SR * .22)
    S["page"] = noise(rng, .22, 2500, 9000) * np.sin(np.linspace(0, np.pi, n)) ** 2 * (1 + .6 * np.sin(np.linspace(0, 40, n)) ** 2) * .6
    bub = [(i * .09 + rng.uniform(0, .03), tone(rng.uniform(500, 1100), .08, "sine") * env(int(SR * .08), .001, .03)) for i in range(7)]
    S["brew"] = mix(*bub, (0, noise(rng, .7, 600, 2500) * .08), dur=.7)
    n = int(SR * .5)
    S["drink"] = mix(*[(i * .13, tone(rng.uniform(200, 320), .1, "sine") * np.linspace(1, 1.5, int(SR * .1)) * env(int(SR * .1), .003, .05) + noise(rng, .1, 300, 1200) * .2) for i in range(3)])
    S["anvil"] = mix((0, tone(220, .6, "bell") * env(int(SR * .6), .001, .3)), (0, noise(rng, .06, 1000, 8000) * env(int(SR * .06), .0005, .01)))
    S["bell"] = tone(784, 1.6, "bell") * env(int(SR * 1.6), .001, .9)
    S["harp"] = tone(587.33, .6, "tri") * env(int(SR * .6), .002, .28) + tone(1174.7, .6, "sine") * env(int(SR * .6), .002, .14) * .3
    n = int(SR * 1.2)
    S["portal"] = (tone(110, 1.2, "sine") * (1 + .5 * np.sin(2 * np.pi * 5 * t_(1.2))) + noise(rng, 1.2, 100, 600) * .5) * np.sin(np.linspace(0, np.pi, n)) ** 2
    nh = int(SR * .35)
    S["hurt"] = mix((0, noise(rng, .2, 200, 2200) * env(int(SR * .2), .001, .06)),
                    (0, tone(180, .25, "square") * np.linspace(1.3, .8, int(SR * .25)) * env(int(SR * .25), .002, .09) * .5))
    S["death"] = mix((0, noise(rng, .35, 150, 1500) * env(nh, .001, .12)),
                     (0, tone(160, .6, "square") * env(int(SR * .6), .002, .25) * .5 * np.linspace(1.4, .5, int(SR * .6))))
    n = int(SR * 1.6)
    S["thunder"] = noise(rng, 1.6, None, 400) * (np.exp(-np.arange(n) / SR * 2.2) * (1 + .6 * np.sin(np.arange(n) / SR * 14)) ** 2) * 3
    n = int(SR * 3)
    S["rain"] = noise(rng, 3, 1500, 9000) * (.6 + .4 * noise(rng, 3, None, 20) / 3) * .6

    # ---- materials: break / place / hit, 2 variants each
    mats = {
        "stone": dict(lo=150, hi=3500, f=95, d=.09),
        "wood": dict(lo=100, hi=2200, f=170, d=.08),
        "glass": dict(lo=2000, hi=9000, f=0, d=.12),
        "grass": dict(lo=500, hi=4000, f=0, d=.07),
        "wool": dict(lo=80, hi=1100, f=0, d=.06),
        "metal": dict(lo=700, hi=7000, f=420, d=.18),
    }
    for m, p in mats.items():
        for v in (1, 2):
            r = np.random.default_rng(zlib.crc32(f"{m}{v}".encode()))
            # break: multi-crunch (3 chips)
            chips = []
            for k in range(4 if m != "glass" else 7):
                nn = int(SR * p["d"])
                c = noise(r, p["d"], p["lo"] * r.uniform(.8, 1.3), p["hi"] * r.uniform(.7, 1.1)) * env(nn, .0005, p["d"] / 3)
                if p["f"]:
                    c = c + tone(p["f"] * r.uniform(.9, 1.2) * (1 + (k % 3) * (.5 if m == "metal" else 0)), p["d"], "sine" if m != "metal" else "bell") * env(nn, .0005, p["d"] / 2) * .6
                chips.append((k * r.uniform(.015, .035), c * (1 - k * .1)))
            S[f"break_{m}_{v}"] = mix(*chips)
            nn = int(SR * (p["d"] + .03))
            c = noise(r, p["d"] + .03, p["lo"] * .8, p["hi"] * .8) * env(nn, .001, p["d"] / 2)
            if p["f"]:
                c = c + tone(p["f"] * .9 * r.uniform(.95, 1.1), p["d"] + .03, "sine" if m != "metal" else "bell") * env(nn, .0008, p["d"] / 1.5) * .8
            S[f"place_{m}_{v}"] = c
            nn = int(SR * (p["d"] * .8))
            c = noise(r, p["d"] * .8, p["lo"], p["hi"] * .7) * env(nn, .0005, p["d"] / 4)
            if p["f"]:
                c = c + tone(p["f"] * 1.1 * r.uniform(.95, 1.1), p["d"] * .8, "sine") * env(nn, .0005, p["d"] / 3) * .4
            S[f"hit_{m}_{v}"] = c * .8

    for name, x in S.items():
        save(out / f"{name}.wav", x)
    print(f"wrote {len(S)} sounds to {out}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=Path(__file__).resolve().parents[2] / "assets/gen/sounds")
    build(ap.parse_args().out)
