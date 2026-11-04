#!/usr/bin/python3
"""scripts/make-sounds.py — synthesize the Overworld Hyprland UI cues.

Outputs (48 kHz, 16-bit mono WAV, peak -6 dBFS, 20 ms fades, no clipping):
    assets/sounds/login.wav          guqin-like Karplus-Strong pluck, 3 descending
                                     pentatonic notes (~1.8 s, 110-220 Hz)
    assets/sounds/notify.wav         one soft wood-block (~180 ms)
    assets/sounds/notify-urgent.wav  two wood-blocks
    assets/sounds/brew-done.wav      three ascending plucks
    assets/sounds/seal.wav           very short soft thud (~120 ms)

Only numpy + the standard library are used.  Deterministic (fixed RNG seed),
so re-running produces byte-identical files.  Usage:

    scripts/make-sounds.py            # write all five into assets/sounds/
    scripts/make-sounds.py --check    # print duration / peak of each file
"""
import math
import pathlib
import sys
import wave

import numpy as np

SR = 48000
PEAK = 10 ** (-6 / 20)          # -6 dBFS
FADE = 0.020                    # 20 ms in / out
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sounds"
rng = np.random.default_rng(1848)   # 植物名實圖考, 1848


# ------------------------------------------------------------------ utils --
def seconds(n):
    return int(round(n * SR))


def fade(sig, t=FADE):
    """Apply a raised-cosine fade in/out of t seconds (clamped to length/2)."""
    n = min(seconds(t), len(sig) // 2)
    if n <= 0:
        return sig
    ramp = 0.5 - 0.5 * np.cos(np.linspace(0, math.pi, n))
    sig = sig.copy()
    sig[:n] *= ramp
    sig[-n:] *= ramp[::-1]
    return sig


def normalize(sig, peak=PEAK):
    m = np.max(np.abs(sig))
    return sig * (peak / m) if m > 0 else sig


def mix(events, length):
    """events: list of (start_seconds, signal)."""
    out = np.zeros(seconds(length))
    for start, sig in events:
        i = seconds(start)
        sig = sig[: max(0, len(out) - i)]
        out[i:i + len(sig)] += sig
    return out


def lowpass_onepole(sig, cutoff):
    """Cheap one-pole low-pass (used to soften transients)."""
    a = math.exp(-2 * math.pi * cutoff / SR)
    out = np.empty_like(sig)
    y = 0.0
    for i, x in enumerate(sig):
        y = (1 - a) * x + a * y
        out[i] = y
    return out


def bandpass_fft(sig, lo, hi, soft=120.0):
    """Zero-phase band-pass via FFT with soft (cosine) skirts of `soft` Hz."""
    spec = np.fft.rfft(sig)
    f = np.fft.rfftfreq(len(sig), 1 / SR)
    gain = np.zeros_like(f)
    inside = (f >= lo) & (f <= hi)
    gain[inside] = 1.0
    lo_sk = (f >= lo - soft) & (f < lo)
    gain[lo_sk] = 0.5 - 0.5 * np.cos(math.pi * (f[lo_sk] - (lo - soft)) / soft)
    hi_sk = (f > hi) & (f <= hi + soft)
    gain[hi_sk] = 0.5 + 0.5 * np.cos(math.pi * (f[hi_sk] - hi) / soft)
    return np.fft.irfft(spec * gain, n=len(sig))


def vibrato(sig, rate=5.0, depth_cents=6.0, onset=0.25):
    """Gentle pitch vibrato by fractional-delay modulation; fades in after `onset` s."""
    n = len(sig)
    t = np.arange(n) / SR
    # depth in samples: cents -> ratio -> time offset accumulates slowly; use
    # a small sinusoidal delay (a few samples) which reads as a soft wobble
    depth = (2 ** (depth_cents / 1200) - 1) * SR / (2 * math.pi * rate)
    env = np.clip((t - onset) / 0.4, 0, 1)
    d = depth * env * np.sin(2 * math.pi * rate * t)
    idx = np.arange(n) - d
    idx = np.clip(idx, 0, n - 1)
    i0 = np.floor(idx).astype(int)
    i1 = np.minimum(i0 + 1, n - 1)
    frac = idx - i0
    return sig[i0] * (1 - frac) + sig[i1] * frac


# --------------------------------------------------------------- voices --
def pluck(freq, dur, decay=0.996, brightness=0.55, pick=0.18, body=True):
    """Karplus-Strong string with a pick-position comb and a soft body resonance.

    decay      per-period loss (closer to 1 = longer sustain)
    brightness 0..1 mix of the two-point average (lower = darker / silk strings)
    pick       pick position as a fraction of the string (comb filter)
    """
    n = seconds(dur)
    period = SR / freq
    L = int(round(period))
    # excitation: low-passed noise burst with the pick-position comb notch
    exc = rng.uniform(-1, 1, L)
    exc = lowpass_onepole(exc, 6000)
    k = max(1, int(round(pick * L)))
    exc[k:] -= 0.9 * exc[:-k]
    exc -= exc.mean()
    buf = exc.copy()
    out = np.empty(n)
    # fractional tuning via a first-order all-pass is overkill here; integer L
    # is within a few cents at these pitches, which suits an old silk-string guqin
    j = 0
    y_prev = buf[-1]
    for i in range(n):
        y = buf[j]
        nxt = buf[(j + 1) % L]
        new = decay * ((1 - brightness) * y + brightness * 0.5 * (y + nxt))
        # one-zero string damping (averages with the previous output)
        new = 0.5 * (new + decay * y_prev) if brightness < 0.5 else new
        y_prev = new
        buf[j] = new
        out[i] = y
        j = (j + 1) % L
    if body:
        # wooden-body lift: a touch of the low-passed signal + slow amplitude decay
        out = 0.85 * out + 0.15 * lowpass_onepole(out, 900)
    t = np.arange(n) / SR
    out *= np.exp(-t * 1.6)
    return out


def wood_block(freq=820.0, dur=0.18, thunk=180.0, seed_off=0):
    """One soft wood-block: band-passed noise burst + short sine thunk."""
    n = seconds(dur)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    burst = bandpass_fft(noise, freq - 110, freq + 110, soft=90)
    burst *= np.exp(-t * 55)                     # very fast noise decay
    thunk_sig = np.sin(2 * math.pi * thunk * t) * np.exp(-t * 38)
    click = np.sin(2 * math.pi * freq * t) * np.exp(-t * 90)
    sig = 1.0 * burst + 0.55 * thunk_sig + 0.35 * click
    sig *= 1 - np.exp(-t * 2500)                 # 0.4 ms attack ramp
    return sig


def thud(dur=0.12):
    """Seal stamp: a soft low thud with a tiny paper 'tap'."""
    n = seconds(dur)
    t = np.arange(n) / SR
    f0 = 140 * np.exp(-t * 18) + 70             # falling pitch 210 -> ~75 Hz
    phase = 2 * math.pi * np.cumsum(f0) / SR
    body = np.sin(phase) * np.exp(-t * 32)
    tap = bandpass_fft(rng.uniform(-1, 1, n), 1800, 3200, soft=300) * np.exp(-t * 160)
    sig = 1.0 * body + 0.22 * tap
    sig *= 1 - np.exp(-t * 3000)
    return sig


# ---------------------------------------------------------------- notes --
# pentatonic (gong/shang/jue/zhi/yu) around A2–A3
A2 = 110.0
PENTA = {"A2": A2, "C3": A2 * 2 ** (3 / 12), "D3": A2 * 2 ** (5 / 12),
         "E3": A2 * 2 ** (7 / 12), "G3": A2 * 2 ** (10 / 12), "A3": 220.0}


def make_login():
    # three descending notes A3 -> E3 -> C3, each ringing into the next
    ev = [(0.00, vibrato(pluck(PENTA["A3"], 1.8, decay=0.9975, brightness=0.45))),
          (0.42, vibrato(pluck(PENTA["E3"], 1.4, decay=0.9975, brightness=0.45))),
          (0.86, vibrato(pluck(PENTA["C3"], 1.0, decay=0.9965, brightness=0.40), depth_cents=8))]
    return mix(ev, 1.85)


def make_brew_done():
    # three ascending plucks C3 -> E3 -> A3, slightly brighter (good news)
    ev = [(0.00, pluck(PENTA["C3"], 1.1, decay=0.996, brightness=0.55)),
          (0.30, pluck(PENTA["E3"], 1.0, decay=0.996, brightness=0.55)),
          (0.60, vibrato(pluck(PENTA["A3"], 1.3, decay=0.997, brightness=0.5), onset=0.15))]
    return mix(ev, 1.9)


def make_notify():
    return mix([(0.015, wood_block(820.0))], 0.195)


def make_notify_urgent():
    return mix([(0.015, wood_block(760.0)), (0.185, wood_block(880.0))], 0.375)


def make_seal():
    return mix([(0.015, thud())], 0.135)


# ---------------------------------------------------------------- write --
def write_wav(path, sig):
    sig = normalize(fade(sig))          # fade first so the peak really lands at -6 dBFS
    sig = np.clip(sig, -PEAK, PEAK)
    pcm = (sig * 32767).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def check(paths):
    for p in paths:
        with wave.open(str(p), "rb") as w:
            n = w.getnframes()
            data = np.frombuffer(w.readframes(n), dtype="<i2").astype(float) / 32768
        peak = np.max(np.abs(data))
        print(f"{p.name:20s} {n / SR:6.3f} s  peak {20 * math.log10(peak):6.2f} dBFS  "
              f"{w.getframerate()} Hz {w.getnchannels()} ch {8 * w.getsampwidth()}-bit")


def main():
    targets = {
        "login.wav": make_login,
        "notify.wav": make_notify,
        "notify-urgent.wav": make_notify_urgent,
        "brew-done.wav": make_brew_done,
        "seal.wav": make_seal,
    }
    if "--check" in sys.argv:
        check([OUT / n for n in targets])
        return 0
    for name, fn in targets.items():
        write_wav(OUT / name, fn())
        print(f"wrote {OUT / name}")
    check([OUT / n for n in targets])
    return 0


if __name__ == "__main__":
    sys.exit(main())
