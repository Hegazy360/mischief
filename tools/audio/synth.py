"""Tiny numpy-only DSP toolkit for Mischief Next Door's procedural audio.

Ported from the owner's earlier game (same pipeline, same maths). Everything works on
1-D float64 arrays at SR (22.05 kHz). Nothing here needs scipy: static filters run in the
frequency domain (exact biquad responses via FFT), sweeping filters run as a per-sample
state-variable filter or as STFT gain masks, and voices are built additively (harmonics
weighted by a formant envelope), which keeps them alias-free and fast.
"""
from __future__ import annotations

import math
import zlib

import numpy as np

SR = 22050
NYQ = SR / 2.0
TAU = 2.0 * math.pi


# --------------------------------------------------------------------------- basics

def rng_for(name: str, salt: int = 0) -> np.random.Generator:
    """Deterministic RNG per sound name (same file bytes on every run)."""
    return np.random.default_rng((zlib.crc32(name.encode()) + salt * 7919) & 0xFFFFFFFF)


def ns(dur: float) -> int:
    return max(1, int(round(dur * SR)))


def tt(dur_or_n) -> np.ndarray:
    n = dur_or_n if isinstance(dur_or_n, (int, np.integer)) else ns(dur_or_n)
    return np.arange(n) / SR


def arr(v, n: int) -> np.ndarray:
    if np.isscalar(v):
        return np.full(n, float(v))
    a = np.asarray(v, dtype=float)
    if len(a) >= n:
        return a[:n]
    return np.concatenate([a, np.full(n - len(a), a[-1] if len(a) else 0.0)])


def midi(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def semis(s: float) -> float:
    return 2.0 ** (s / 12.0)


def db(x: float) -> float:
    return 10.0 ** (x / 20.0)


def pad_to(x: np.ndarray, n: int) -> np.ndarray:
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*parts) -> np.ndarray:
    """Sum arrays of different lengths (or (array, gain) tuples)."""
    items = []
    for p in parts:
        if p is None:
            continue
        if isinstance(p, tuple):
            items.append(np.asarray(p[0], float) * p[1])
        else:
            items.append(np.asarray(p, float))
    n = max(len(a) for a in items)
    out = np.zeros(n)
    for a in items:
        out[: len(a)] += a
    return out


def place(events, total: float | None = None) -> np.ndarray:
    """events: iterable of (start_sec, signal[, gain]) → summed buffer."""
    evs = [(e[0], np.asarray(e[1], float), e[2] if len(e) > 2 else 1.0) for e in events]
    n = max(int(round(s * SR)) + len(x) for s, x, _ in evs)
    if total is not None:
        n = max(n, ns(total))
    out = np.zeros(n)
    for s, x, g in evs:
        i = int(round(s * SR))
        out[i : i + len(x)] += x * g
    return out


def concat(*parts) -> np.ndarray:
    return np.concatenate([np.asarray(p, float) for p in parts])


def silence(dur: float) -> np.ndarray:
    return np.zeros(ns(dur))


# --------------------------------------------------------------------------- envelopes

def env_lin(points, n: int) -> np.ndarray:
    """Piecewise-linear envelope from [(t_sec, value), ...]."""
    ts = [p[0] for p in points]
    vs = [p[1] for p in points]
    return np.interp(np.arange(n) / SR, ts, vs)


def env_exp(points, n: int, floor: float = 1e-4) -> np.ndarray:
    """Piecewise-exponential (linear in dB) envelope; values ≤ floor are treated as floor."""
    ts = [p[0] for p in points]
    vs = [math.log(max(p[1], floor)) for p in points]
    e = np.exp(np.interp(np.arange(n) / SR, ts, vs))
    e[e <= floor * 1.0001] = 0.0
    return e


def perc(n: int, attack: float = 0.003, decay: float = 0.2, curve: float = 1.0) -> np.ndarray:
    """Fast linear attack then exponential decay (decay = time to -60 dB)."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-5), 0.0, 1.0)
    d = np.exp(-6.9 * np.maximum(t - attack, 0.0) / max(decay, 1e-4)) ** curve
    return a * d


def adsr(n: int, a=0.01, d=0.08, s=0.7, r=0.1, hold: float | None = None) -> np.ndarray:
    t = np.arange(n) / SR
    dur = n / SR
    rel_start = dur - r if hold is None else min(hold, dur - r)
    e = np.where(t < a, t / max(a, 1e-5), 0.0)
    m = (t >= a) & (t < a + d)
    e[m] = 1.0 - (1.0 - s) * (t[m] - a) / max(d, 1e-5)
    m2 = (t >= a + d) & (t < rel_start)
    e[m2] = s
    m3 = t >= rel_start
    lvl = s if rel_start >= a + d else 1.0
    e[m3] = lvl * np.clip(1.0 - (t[m3] - rel_start) / max(r, 1e-5), 0.0, 1.0)
    return e


def fade(x: np.ndarray, fin: float = 0.001, fout: float = 0.02) -> np.ndarray:
    x = x.copy()
    a, b = ns(fin), ns(fout)
    if a > 1 and len(x) > a:
        x[:a] *= np.linspace(0.0, 1.0, a)
    if b > 1 and len(x) > b:
        x[-b:] *= 0.5 * (1.0 + np.cos(np.linspace(0.0, math.pi, b)))
    return x


def smooth(x: np.ndarray, win: int) -> np.ndarray:
    """Centered moving average (box) with edge padding."""
    if win <= 1:
        return x
    k = np.ones(win) / win
    xp = np.pad(x, (win // 2, win - 1 - win // 2), mode="edge")
    return np.convolve(xp, k, mode="valid")


def smooth_noise(n: int, rate_hz: float, rng: np.random.Generator) -> np.ndarray:
    """Band-limited random curve in [-1, 1] changing at ~rate_hz."""
    pts = max(2, int(n / SR * rate_hz) + 3)
    ctrl = rng.uniform(-1.0, 1.0, pts)
    xs = np.linspace(0, n, pts)
    c = np.interp(np.arange(n), xs, ctrl)
    return smooth(c, max(1, int(SR / rate_hz / 2)))


# --------------------------------------------------------------------------- oscillators

def phase_of(f, n: int, phase0: float = 0.0) -> np.ndarray:
    """Cycles (not radians) accumulated from an instantaneous frequency."""
    f = arr(f, n)
    return phase0 + np.concatenate([[0.0], np.cumsum(f[:-1])]) / SR


def sine(f, n: int, phase0: float = 0.0) -> np.ndarray:
    return np.sin(TAU * phase_of(f, n, phase0))


def _blep(t: np.ndarray, dt: np.ndarray) -> np.ndarray:
    out = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m]
    out[m] = x + x - x * x - 1.0
    m = t > 1.0 - dt
    x = (t[m] - 1.0) / dt[m]
    out[m] = x * x + x + x + 1.0
    return out


def saw(f, n: int, phase0: float = 0.0) -> np.ndarray:
    f = arr(f, n)
    dt = np.clip(np.abs(f) / SR, 1e-6, 0.5)
    ph = phase_of(f, n, phase0) % 1.0
    return 2.0 * ph - 1.0 - _blep(ph, dt)


def square(f, n: int, pw=0.5, phase0: float = 0.0) -> np.ndarray:
    f = arr(f, n)
    pw = arr(pw, n)
    dt = np.clip(np.abs(f) / SR, 1e-6, 0.5)
    ph = phase_of(f, n, phase0) % 1.0
    y = np.where(ph < pw, 1.0, -1.0)
    y += _blep(ph, dt)
    y -= _blep((ph - pw) % 1.0, dt)
    return y


def tri(f, n: int, phase0: float = 0.0) -> np.ndarray:
    ph = phase_of(f, n, phase0 + 0.25) % 1.0
    return 2.0 * np.abs(2.0 * ph - 1.0) - 1.0


def fm(fc, n: int, ratio: float, index, phase0: float = 0.0) -> np.ndarray:
    """Two-operator FM: carrier fc, modulator fc*ratio, index (array or scalar)."""
    fc = arr(fc, n)
    mod = np.sin(TAU * phase_of(fc * ratio, n))
    return np.sin(TAU * phase_of(fc, n, phase0) + arr(index, n) * mod)


def additive(f0, n: int, amps, detune=None, phases=None) -> np.ndarray:
    """Sum of harmonics k·f0 (k from 1) with per-harmonic amplitude (scalar or array)."""
    f0 = arr(f0, n)
    base = phase_of(f0, n)
    out = np.zeros(n)
    for k, a in enumerate(amps, start=1):
        if np.isscalar(a) and a == 0:
            continue
        ratio = k * (1.0 + (detune[k - 1] if detune is not None else 0.0))
        fk = f0 * ratio
        ok = fk < NYQ * 0.96
        if not ok.any():
            break
        ph0 = phases[k - 1] if phases is not None else 0.0
        out += np.where(ok, np.sin(TAU * (base * ratio + ph0)), 0.0) * a
    return out


# --------------------------------------------------------------------------- noise

def white(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n)


def colored(n: int, rng: np.random.Generator, slope_db_oct: float = -3.0) -> np.ndarray:
    """Noise with a power slope (−3 = pink, −6 = brown)."""
    N = 1 << int(math.ceil(math.log2(max(n, 2))))
    spec = rng.standard_normal(N // 2 + 1) + 1j * rng.standard_normal(N // 2 + 1)
    f = np.fft.rfftfreq(N, 1.0 / SR)
    f[0] = f[1]
    spec *= (f / 1000.0) ** (slope_db_oct / 6.0206)
    y = np.fft.irfft(spec, N)[:n]
    return y / (np.std(y) + 1e-12)


def pink(n, rng):
    return colored(n, rng, -3.0)


def brown(n, rng):
    return colored(n, rng, -6.0)


def crackle(n: int, rng: np.random.Generator, density, amp_jitter: float = 1.0) -> np.ndarray:
    """Sparse random impulses; density (events/sec) may be an array."""
    d = arr(density, n)
    hits = rng.random(n) < d / SR
    x = np.zeros(n)
    x[hits] = rng.choice([-1.0, 1.0], hits.sum()) * (1.0 - amp_jitter * rng.random(hits.sum()))
    return x


# --------------------------------------------------------------------------- filters

def _next_pow2(n: int) -> int:
    return 1 << int(math.ceil(math.log2(max(n, 2))))


def rbj(kind: str, fc: float, q: float = 0.707, gain_db: float = 0.0):
    """RBJ cookbook biquad → (b, a) normalized."""
    fc = min(max(fc, 5.0), NYQ * 0.98)
    w = TAU * fc / SR
    c, s = math.cos(w), math.sin(w)
    al = s / (2.0 * q)
    A = 10.0 ** (gain_db / 40.0)
    if kind == "lp":
        b = [(1 - c) / 2, 1 - c, (1 - c) / 2]
        a = [1 + al, -2 * c, 1 - al]
    elif kind == "hp":
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
        a = [1 + al, -2 * c, 1 - al]
    elif kind == "bp":  # constant 0 dB peak
        b = [al, 0.0, -al]
        a = [1 + al, -2 * c, 1 - al]
    elif kind == "notch":
        b = [1.0, -2 * c, 1.0]
        a = [1 + al, -2 * c, 1 - al]
    elif kind == "peak":
        b = [1 + al * A, -2 * c, 1 - al * A]
        a = [1 + al / A, -2 * c, 1 - al / A]
    elif kind == "lowshelf":
        sq = 2 * math.sqrt(A) * al
        b = [A * ((A + 1) - (A - 1) * c + sq), 2 * A * ((A - 1) - (A + 1) * c), A * ((A + 1) - (A - 1) * c - sq)]
        a = [(A + 1) + (A - 1) * c + sq, -2 * ((A - 1) + (A + 1) * c), (A + 1) + (A - 1) * c - sq]
    elif kind == "highshelf":
        sq = 2 * math.sqrt(A) * al
        b = [A * ((A + 1) + (A - 1) * c + sq), -2 * A * ((A - 1) + (A + 1) * c), A * ((A + 1) + (A - 1) * c - sq)]
        a = [(A + 1) - (A - 1) * c + sq, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - sq]
    else:
        raise ValueError(kind)
    return [v / a[0] for v in b], [1.0, a[1] / a[0], a[2] / a[0]]


def _biquad_H(b, a, w):
    z1 = np.exp(-1j * w)
    z2 = z1 * z1
    return (b[0] + b[1] * z1 + b[2] * z2) / (a[0] + a[1] * z1 + a[2] * z2)


def filt(x: np.ndarray, *stages, tail: float = 0.0, circular: bool = False) -> np.ndarray:
    """Apply a cascade of biquads exactly, in the frequency domain.

    stages: tuples like ("lp", 1200, 0.7) / ("peak", 800, 2.0, 6.0) / ("hp", 80).
    tail: seconds appended so resonant ringing isn't cut. circular=True filters a loop
    in place (wrap-around, used for music loops).
    """
    n = len(x)
    N = n if circular else _next_pow2(n + ns(tail) + 256)
    X = np.fft.rfft(x, N)
    w = TAU * np.arange(len(X)) / N
    H = np.ones(len(X), dtype=complex)
    for st in stages:
        kind, fc = st[0], st[1]
        q = st[2] if len(st) > 2 else 0.707
        g = st[3] if len(st) > 3 else 0.0
        b, a = rbj(kind, fc, q, g)
        H *= _biquad_H(b, a, w)
    y = np.fft.irfft(X * H, N)
    return y[:n] if circular else y[: n + ns(tail)] if tail > 0 else y[:n]


def lp(x, fc, q=0.707, tail=0.0):
    return filt(x, ("lp", fc, q), tail=tail)


def hp(x, fc, q=0.707):
    return filt(x, ("hp", fc, q))


def bp(x, fc, q=1.0, tail=0.0):
    return filt(x, ("bp", fc, q), tail=tail)


def svf(x: np.ndarray, fc, q=0.7, mode: str = "lp") -> np.ndarray:
    """Per-sample Chamberlin/Simper state-variable filter with sweepable cutoff.

    fc and q may be arrays. mode: lp | bp | hp | notch. (Pure-python loop; ~40 ms/s.)
    """
    n = len(x)
    fc = np.clip(arr(fc, n), 10.0, NYQ * 0.45)
    q = arr(q, n)
    g = np.tan(math.pi * fc / SR)
    k = 1.0 / np.maximum(q, 0.05)
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    out = np.empty(n)
    ic1 = ic2 = 0.0
    xs = x.tolist()
    A1, A2, A3, K = a1.tolist(), a2.tolist(), a3.tolist(), k.tolist()
    m = {"lp": 0, "bp": 1, "hp": 2, "notch": 3}[mode]
    o = [0.0] * n
    for i in range(n):
        v0 = xs[i]
        v3 = v0 - ic2
        v1 = A1[i] * ic1 + A2[i] * v3
        v2 = ic2 + A2[i] * ic1 + A3[i] * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        if m == 0:
            o[i] = v2
        elif m == 1:
            o[i] = v1
        elif m == 2:
            o[i] = v0 - K[i] * v1 - v2
        else:
            o[i] = v0 - K[i] * v1
    out[:] = o
    return out


def onepole_lp(x: np.ndarray, fc) -> np.ndarray:
    """Sweepable one-pole lowpass (cheap loop)."""
    n = len(x)
    c = 1.0 - np.exp(-TAU * np.clip(arr(fc, n), 5.0, NYQ) / SR)
    y = 0.0
    xs, cs = x.tolist(), c.tolist()
    o = [0.0] * n
    for i in range(n):
        y += cs[i] * (xs[i] - y)
        o[i] = y
    return np.asarray(o)


def stft_filter(x: np.ndarray, gain_fn, win: int = 512, hop: int = 128) -> np.ndarray:
    """Time-varying zero-phase filtering: gain_fn(freqs[1,F], times[T,1]) → gains [T,F]."""
    n = len(x)
    pad = win
    xp = np.concatenate([np.zeros(pad), x, np.zeros(pad + win)])
    w = np.hanning(win + 1)[:-1]
    frames = 1 + (len(xp) - win) // hop
    idx = np.arange(win)[None, :] + hop * np.arange(frames)[:, None]
    F = np.fft.rfft(xp[idx] * w, axis=1)
    freqs = np.fft.rfftfreq(win, 1.0 / SR)[None, :]
    times = ((np.arange(frames) * hop + win / 2 - pad) / SR)[:, None]
    G = gain_fn(freqs, times)
    Y = np.fft.irfft(F * G, win, axis=1) * w
    out = np.zeros(len(xp))
    norm = np.zeros(len(xp))
    np.add.at(out, idx, Y)
    np.add.at(norm, idx, np.broadcast_to(w * w, Y.shape))
    out = out / np.maximum(norm, 1e-3)
    return out[pad : pad + n]


def band_gain(freqs, fc, bw_oct: float = 1.0):
    """Gaussian (in log-frequency) band gain, fc may be [T,1]."""
    lf = np.log2(np.maximum(freqs, 1.0) / np.maximum(fc, 1.0))
    return np.exp(-0.5 * (lf / (bw_oct / 2.355)) ** 2)


def noise_sweep(n: int, rng, fc_curve, bw_oct=1.0, color: float = 0.0) -> np.ndarray:
    """Noise band whose center follows fc_curve (array length n, Hz)."""
    src = colored(n, rng, color) if color else white(n, rng)
    fcs = arr(fc_curve, n)

    def g(freqs, times):
        i = np.clip((times * SR).astype(int), 0, n - 1)
        return band_gain(freqs, fcs[i], bw_oct)

    y = stft_filter(src, g)
    return y / (np.max(np.abs(y)) + 1e-9)


def drive(x: np.ndarray, amount: float = 2.0) -> np.ndarray:
    return np.tanh(x * amount) / math.tanh(amount)


def bitcrush(x: np.ndarray, levels: int = 16) -> np.ndarray:
    return np.round(x * levels) / levels


# --------------------------------------------------------------------------- space

def convolve(x: np.ndarray, ir: np.ndarray, circular: bool = False) -> np.ndarray:
    if circular:
        n = len(x)
        irp = np.zeros(n)
        m = min(n, len(ir))
        irp[:m] = ir[:m]
        return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(irp), n)
    N = _next_pow2(len(x) + len(ir))
    return np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[: len(x) + len(ir) - 1]


def make_ir(dur: float = 1.0, rt60: float = 0.8, tone: float = 5000.0, early: int = 8,
            seed: int = 7, spring: bool = False, predelay: float = 0.008) -> np.ndarray:
    """Synthetic room (or spring) impulse response, normalized to unit energy."""
    rng = np.random.default_rng(seed)
    n = ns(dur)
    t = np.arange(n) / SR
    tail = rng.standard_normal(n) * np.exp(-6.9 * t / rt60)
    # darker as it decays
    def g(freqs, times):
        fc = tone * np.exp(-np.maximum(times, 0) * 1.5)
        return 1.0 / (1.0 + (freqs / np.maximum(fc, 300.0)) ** 2)
    tail = stft_filter(tail, g)
    tail *= np.clip(t / 0.02, 0, 1)
    ir = np.zeros(n)
    pd = ns(predelay)
    ir[pd:] += tail[: n - pd] * 0.6
    for _ in range(early):
        i = pd + int(rng.uniform(0.002, 0.05) * SR)
        if i < n:
            ir[i] += rng.uniform(-1, 1) * 0.9 * math.exp(-i / SR / 0.06)
    if spring:  # dispersive chirps repeating every ~31 ms: the surf "drip"
        per = ns(0.031)
        ch_n = ns(0.03)
        tc = np.arange(ch_n) / SR
        chirp = np.sin(TAU * (3200 * tc - 0.5 * 90000 * tc * tc)) * np.hanning(ch_n)
        k = 0
        while pd + k * per + ch_n < n:
            ir[pd + k * per: pd + k * per + ch_n] += chirp * 0.35 * math.exp(-k * per / SR * 6.9 / rt60)
            k += 1
    return ir / (np.sqrt(np.sum(ir * ir)) + 1e-12)


def reverb(x: np.ndarray, wet: float = 0.25, rt60: float = 0.8, tone: float = 5000.0,
           seed: int = 3, spring: bool = False, keep_len: bool = False) -> np.ndarray:
    ir = make_ir(min(rt60 * 1.3 + 0.05, 3.0), rt60, tone, seed=seed, spring=spring)
    w = convolve(x, ir)
    y = pad_to(x, len(w)) + w * wet
    return y[: len(x)] if keep_len else y


def echo(x: np.ndarray, delay: float = 0.12, fb: float = 0.35, taps: int = 4, lp_hz: float = 4000) -> np.ndarray:
    d = ns(delay)
    out = pad_to(x, len(x) + d * taps)
    cur = x
    for k in range(1, taps + 1):
        cur = lp(cur, lp_hz) * fb
        out[d * k : d * k + len(cur)] += cur
    return out


# --------------------------------------------------------------------------- voices & formants

# (F1, F2, F3, F4) in Hz for an adult-ish voice; scaled by `tract` for small/large heads.
VOWELS = {
    "a": (800, 1250, 2600, 3400),
    "ah": (750, 1150, 2500, 3300),
    "e": (550, 1850, 2550, 3400),
    "i": (320, 2500, 3100, 3700),
    "ih": (420, 2100, 2750, 3500),
    "o": (520, 880, 2500, 3300),
    "u": (340, 850, 2350, 3200),
    "uh": (680, 1300, 2500, 3300),  # ʌ as in "up"
    "er": (500, 1350, 1750, 3300),  # r-coloured
    "schwa": (550, 1500, 2500, 3400),
    "m": (280, 1150, 2200, 3200),   # nasal murmur
    "n": (300, 1600, 2600, 3300),
    "aw": (650, 1000, 2500, 3300),
}
F_BW = (90.0, 110.0, 170.0, 250.0)
F_GAIN = (1.0, 0.62, 0.30, 0.15)


def vowel_track(seq, n: int, tract: float = 1.0) -> np.ndarray:
    """seq: [(t_sec, vowel_name), ...] → formant freqs [4, n] (linear glides)."""
    ts = [s[0] for s in seq]
    out = np.zeros((4, n))
    for j in range(4):
        vs = [VOWELS[s[1]][j] * tract for s in seq]
        out[j] = np.interp(np.arange(n) / SR, ts, vs)
    return out


def formant_gain(freq: np.ndarray, forms: np.ndarray, bw_scale: float = 1.0,
                 gains=F_GAIN, nasal: float = 0.0, f0=None) -> np.ndarray:
    """Spectral envelope at `freq` (shape n) for formant tracks `forms` [4, n].

    With f0 given, bandwidths widen for high voices so sparse harmonics still land on
    the formants (otherwise high voices lose whole syllables).
    """
    g = np.zeros_like(freq)
    for j in range(forms.shape[0]):
        bw = F_BW[j] * bw_scale * (1 + forms[j] / 3000.0)
        if f0 is not None:
            bw = np.sqrt(bw * bw + (0.55 * f0) ** 2)
        g += gains[j] / (1.0 + ((freq - forms[j]) / (bw * 0.5)) ** 2)
    if nasal:
        g *= 1.0 - nasal * (1.0 / (1.0 + ((freq - 900.0) / 250.0) ** 2))
    return g


def voice(f0, forms: np.ndarray, amp, breath: float = 0.08, tilt: float = 1.0,
          rng=None, bw_scale: float = 1.0, nasal: float = 0.0, jitter: float = 0.004,
          buzz: float = 0.0, max_hz: float = NYQ * 0.95, breath_amp=None) -> np.ndarray:
    """Formant voice: harmonic source shaped by moving formants + breath noise.

    f0: Hz (array), forms: [4, n], amp: envelope (array). tilt: source roll-off
    exponent (1 = bright, 2 = soft). buzz adds a hard edge (for kazoos/animals).
    """
    n = forms.shape[1]
    rng = rng or np.random.default_rng(1)
    f0 = arr(f0, n)
    if jitter:
        f0 = f0 * (1.0 + jitter * smooth_noise(n, 30.0, rng))
    base = phase_of(f0, n)
    out = np.zeros(n)
    kmax = int(max_hz / max(np.min(f0), 40.0)) + 1
    for k in range(1, min(kmax, 120) + 1):
        fk = f0 * k
        ok = fk < max_hz
        if not ok.any():
            break
        a = formant_gain(fk, forms, bw_scale, nasal=nasal, f0=f0) / (k ** tilt)
        if buzz:
            a = a + buzz * formant_gain(fk, forms, bw_scale * 2.5, f0=f0) / (k ** 0.6)
        out += np.where(ok, np.sin(TAU * base * k), 0.0) * a
    # level-flatten: the source's loudness should follow `amp`, not formant/harmonic luck
    lvl = _box(np.sqrt(np.maximum(_box(out * out, max(3, ns(0.015))), 0.0)), max(3, ns(0.03)))
    out = out / np.maximum(lvl, np.max(lvl) * 0.05 + 1e-9)
    if breath > 0:
        nz = white(n, rng)

        def g(freqs, times):
            i = np.clip((times * SR).astype(int), 0, n - 1)
            fr = forms[:, i[:, 0]].T  # [T,4]
            acc = np.zeros((len(i), freqs.shape[1]))
            for j in range(4):
                acc += F_GAIN[j] / (1.0 + ((freqs - fr[:, j:j + 1]) / (F_BW[j] * bw_scale * 1.5)) ** 2)
            return acc

        b = stft_filter(nz, g)
        out = out / (np.std(out) + 1e-9) * arr(amp, n)
        b = breath * b / (np.std(b) + 1e-9)
        return out + b * arr(amp if breath_amp is None else breath_amp, n)
    return out * arr(amp, n)


def burst(n: int, rng, lo: float, hi: float, attack: float = 0.001, decay: float = 0.03) -> np.ndarray:
    """Band-limited noise burst (consonants, clicks)."""
    x = filt(white(n, rng), ("hp", lo, 0.7), ("lp", hi, 0.7))
    return x * perc(n, attack, decay) / (np.max(np.abs(x)) + 1e-9)


# --------------------------------------------------------------------------- tonal instruments

def pluck(freq: float, dur: float, bright: float = 0.5, decay: float = 1.2, pos: float = 0.18,
          rng=None, vib: float = 0.0, bend=None, body: bool = True) -> np.ndarray:
    """Modal plucked string: harmonics with brightness-dependent decay + pick noise."""
    n = ns(dur)
    t = np.arange(n) / SR
    rng = rng or np.random.default_rng(int(freq * 10))
    f = np.full(n, freq)
    if vib:
        f *= 1.0 + vib * np.sin(TAU * 5.5 * t) * np.clip((t - 0.15) / 0.3, 0, 1)
    if bend is not None:
        f *= arr(bend, n)
    base = phase_of(f, n)
    out = np.zeros(n)
    K = int(min(40, NYQ * 0.9 / freq))
    for k in range(1, K + 1):
        amp = abs(math.sin(math.pi * k * pos)) / (k ** (1.6 - bright))
        tau = decay / (1.0 + (k - 1) * (0.25 + 1.2 * (1.0 - bright)) * (freq / 220.0) ** 0.5)
        inh = 1.0 + 0.00012 * k * k
        out += amp * np.sin(TAU * base * k * inh + rng.uniform(0, 0.2)) * np.exp(-t / max(tau, 0.01))
    atk = min(n, ns(0.004))
    out[:atk] *= np.linspace(0.2, 1.0, atk)
    pick = burst(min(n, ns(0.012)), rng, 1500, 7000, 0.0005, 0.008) * 0.15 * bright
    out[: len(pick)] += pick * np.max(np.abs(out[:2000]) + 1e-9)
    if body:
        out = filt(out, ("peak", 180, 1.2, 3.0), ("peak", 2500, 1.0, 2.0 * bright))
    return out * fade(np.ones(n), 0.0005, 0.03)


def mallet(freq: float, dur: float, ratios=(1.0, 3.93, 9.2), amps=(1.0, 0.35, 0.12),
           decays=(0.9, 0.25, 0.08), hardness: float = 0.5, rng=None) -> np.ndarray:
    """Marimba/xylophone/glock-style struck bar (inharmonic modes)."""
    n = ns(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for r, a, d in zip(ratios, amps, decays):
        f = freq * r
        if f < NYQ * 0.95:
            out += a * np.sin(TAU * f * t) * np.exp(-6.9 * t / d)
    rng = rng or np.random.default_rng(int(freq))
    click = burst(min(n, ns(0.006)), rng, 1000, 6000, 0.0003, 0.004) * hardness * 0.4
    out[: len(click)] += click
    atk = min(n, ns(0.0015))
    out[:atk] *= np.linspace(0, 1, atk)
    return out


def bell_tone(freq: float, dur: float, bright: float = 1.0, rng=None) -> np.ndarray:
    """Church/kitchen bell partials (hum, prime, tierce, quint, nominal…)."""
    ratios = (0.5, 1.0, 1.19, 1.5, 2.0, 2.5, 2.67, 3.0, 4.0, 5.33)
    amps = (0.35, 1.0, 0.55, 0.4, 0.6, 0.25 * bright, 0.2 * bright, 0.18 * bright, 0.12 * bright, 0.08 * bright)
    decays = (2.5, 1.8, 1.4, 1.1, 1.0, 0.6, 0.55, 0.5, 0.35, 0.25)
    n = ns(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for r, a, d in zip(ratios, amps, decays):
        f = freq * r
        if f < NYQ * 0.95:
            out += a * np.sin(TAU * f * t * (1 + 0.0007 * math.sin(r * 7))) * np.exp(-6.9 * t / (d * dur / 1.5 + 0.05))
    atk = min(n, ns(0.002))
    out[:atk] *= np.linspace(0, 1, atk)
    return out


def piano(freq: float, dur: float, vel: float = 0.8, rng=None, release: float = 0.12) -> np.ndarray:
    """Additive piano-ish tone: 3 detuned strings, inharmonic partials, hammer brightness."""
    n = ns(dur + release)
    t = np.arange(n) / SR
    rng = rng or np.random.default_rng(int(freq * 3))
    B = 0.0004 * (freq / 261.6) ** 0.5
    K = int(min(24, NYQ * 0.9 / freq))
    out = np.zeros(n)
    bright = 0.35 + 0.65 * vel
    for k in range(1, K + 1):
        fk = freq * k * math.sqrt(1 + B * k * k)
        if fk > NYQ * 0.95:
            break
        amp = (1.0 / k ** (1.9 - bright)) * (1.0 if k < 8 else 0.6)
        tau = (2.8 * (261.6 / freq) ** 0.45) / (1.0 + 0.35 * (k - 1))
        for det in (-0.6, 0.0, 0.7):
            fd = fk * (1 + det * 0.0012)
            out += amp / 3.0 * np.sin(TAU * fd * t + rng.uniform(0, TAU)) * (
                0.6 * np.exp(-t / (tau * 0.25)) + 0.4 * np.exp(-t / tau))
    hammer = burst(min(n, ns(0.01)), rng, 300, 3000 + 3000 * vel, 0.0003, 0.008) * 0.2 * vel
    out[: len(hammer)] += hammer
    # key release damping
    rel = np.ones(n)
    r0 = ns(dur)
    if r0 < n:
        rel[r0:] = np.exp(-np.arange(n - r0) / SR / (release / 5))
    atk = min(n, ns(0.002))
    out[:atk] *= np.linspace(0, 1, atk)
    return out * rel * vel


def brass(freq, dur: float, vel: float = 0.9, vib: float = 0.012, bright: float = 1.0,
          attack: float = 0.03, release: float = 0.08, rng=None, growl: float = 0.0,
          wah=None) -> np.ndarray:
    """Trumpet/trombone-ish: harmonic source whose brightness follows loudness."""
    n = ns(dur + release)
    t = np.arange(n) / SR
    rng = rng or np.random.default_rng(int(np.mean(freq) * 7) & 0xFFFF)
    f = arr(freq, n)
    f = f * (1.0 + vib * np.sin(TAU * 5.6 * t) * np.clip((t - 0.12) / 0.2, 0, 1))
    f = f * (1.0 + 0.002 * smooth_noise(n, 12, rng))
    # pitch scoop at attack (lip slur)
    f = f * (1.0 - 0.03 * np.exp(-t / 0.025))
    env = adsr(n, attack, 0.08, 0.8, release, hold=dur)
    loud = env * vel
    base = phase_of(f, n)
    out = np.zeros(n)
    K = int(min(30, NYQ * 0.9 / np.min(f)))
    for k in range(1, K + 1):
        cutoff = 1.5 + 9.0 * loud * bright
        a = 1.0 / (1.0 + (k / cutoff) ** 3) / k ** 0.3
        if wah is not None:
            wf = arr(wah, n)
            a = a * (0.25 + 1.2 / (1.0 + ((f * k - wf) / (wf * 0.45)) ** 2))
        out += a * np.sin(TAU * base * k) * (f * k < NYQ * 0.95)
    if growl:
        out *= 1.0 + growl * np.sin(TAU * 32 * t)
    breath = filt(white(n, rng), ("bp", 1800, 0.8)) * 0.02 * env
    return (out + breath) * env


def kazoo(freq, dur: float, vel: float = 0.9, rng=None, vowel: str = "u") -> np.ndarray:
    """Buzzy membrane voice: saw-ish source + nasal formants + buzz modulation."""
    n = ns(dur)
    t = np.arange(n) / SR
    rng = rng or np.random.default_rng(99)
    f = arr(freq, n) * (1.0 + 0.012 * np.sin(TAU * 6.2 * t) * np.clip((t - 0.1) / 0.2, 0, 1))
    forms = vowel_track([(0, vowel), (dur, vowel)], n, tract=1.15)
    env = adsr(n, 0.012, 0.05, 0.85, 0.05) * vel
    v = voice(f, forms, env, breath=0.02, tilt=0.55, rng=rng, bw_scale=1.4, jitter=0.006, buzz=0.9)
    # membrane buzz: hard clipping + AM at 2×f
    v = drive(v / (np.max(np.abs(v)) + 1e-9), 3.0)
    v = filt(v, ("peak", 1300, 1.5, 6.0), ("peak", 2600, 2.0, 4.0), ("hp", 200))
    return v * env


def sweep(f_start: float, f_end: float, dur: float, curve: str = "exp") -> np.ndarray:
    n = ns(dur)
    x = np.linspace(0, 1, n)
    if curve == "exp":
        return f_start * (f_end / f_start) ** x
    if curve == "lin":
        return f_start + (f_end - f_start) * x
    if curve == "ease":
        return f_start + (f_end - f_start) * (1 - (1 - x) ** 3)
    raise ValueError(curve)


# --------------------------------------------------------------------------- drums

def kick(dur: float = 0.35, f_hi: float = 150.0, f_lo: float = 48.0, click: float = 0.3, rng=None) -> np.ndarray:
    n = ns(dur)
    t = np.arange(n) / SR
    f = f_lo + (f_hi - f_lo) * np.exp(-t / 0.035)
    y = np.sin(TAU * phase_of(f, n)) * perc(n, 0.001, dur * 0.9)
    rng = rng or np.random.default_rng(5)
    c = burst(min(n, ns(0.008)), rng, 1500, 6000, 0.0002, 0.005) * click
    y[: len(c)] += c
    return drive(y, 1.4)


def snare(dur: float = 0.22, tone: float = 190.0, snappy: float = 0.7, rng=None) -> np.ndarray:
    n = ns(dur)
    t = np.arange(n) / SR
    rng = rng or np.random.default_rng(6)
    body = np.sin(TAU * phase_of(tone * (1 + 0.5 * np.exp(-t / 0.01)), n)) * perc(n, 0.001, 0.09)
    body += 0.5 * np.sin(TAU * phase_of(tone * 1.6, n)) * perc(n, 0.001, 0.05)
    nz = filt(white(n, rng), ("hp", 1500, 0.7), ("peak", 4500, 1.0, 4.0)) * perc(n, 0.001, dur * 0.9)
    return body * (1 - snappy) + nz / (np.max(np.abs(nz)) + 1e-9) * snappy


def hat(dur: float = 0.06, open_: bool = False, rng=None) -> np.ndarray:
    n = ns(0.45 if open_ else dur)
    rng = rng or np.random.default_rng(8)
    t = np.arange(n) / SR
    metal = np.zeros(n)
    for r in (2.0, 3.0, 4.16, 5.43, 6.79, 8.21):  # 808-ish square cluster
        metal += square(320 * r, n)
    x = filt(metal * 0.3 + white(n, rng) * 0.7, ("hp", 6500, 0.8), ("peak", 9000, 1.0, 3.0))
    return x * perc(n, 0.0005, 0.35 if open_ else dur) / (np.max(np.abs(x)) + 1e-9)


def shaker(dur: float = 0.09, rng=None) -> np.ndarray:
    n = ns(dur)
    rng = rng or np.random.default_rng(9)
    x = filt(white(n, rng), ("hp", 4000, 0.7), ("lp", 10000, 0.7))
    e = env_lin([(0, 0), (dur * 0.35, 1), (dur, 0)], n)
    return x * e / (np.max(np.abs(x)) + 1e-9)


def rim(dur: float = 0.06, rng=None) -> np.ndarray:
    n = ns(dur)
    t = np.arange(n) / SR
    rng = rng or np.random.default_rng(10)
    y = np.sin(TAU * 1700 * t) * perc(n, 0.0003, 0.03) + 0.6 * np.sin(TAU * 820 * t) * perc(n, 0.0003, 0.04)
    y += burst(n, rng, 2000, 8000, 0.0002, 0.006) * 0.5
    return y


def clap(dur: float = 0.25, rng=None) -> np.ndarray:
    n = ns(dur)
    rng = rng or np.random.default_rng(11)
    nz = filt(white(n, rng), ("bp", 1300, 1.2), ("hp", 600))
    e = np.zeros(n)
    for k, d in enumerate((0.0, 0.009, 0.018, 0.027)):
        i = ns(d)
        e[i:] += perc(n - i, 0.0003, 0.012 if k < 3 else dur * 0.8) * (0.8 if k < 3 else 1.0)
    return nz * e / (np.max(np.abs(nz * e)) + 1e-9)


def tom(freq: float = 140.0, dur: float = 0.3, rng=None) -> np.ndarray:
    n = ns(dur)
    t = np.arange(n) / SR
    f = freq * (1 + 0.6 * np.exp(-t / 0.02))
    y = np.sin(TAU * phase_of(f, n)) * perc(n, 0.001, dur * 0.8)
    rng = rng or np.random.default_rng(12)
    b = burst(min(n, ns(0.02)), rng, 400, 4000, 0.0003, 0.015) * 0.3
    y[: len(b)] += b
    return y


def cymbal(dur: float = 1.8, rng=None, bright: float = 1.0) -> np.ndarray:
    n = ns(dur)
    rng = rng or np.random.default_rng(13)
    t = np.arange(n) / SR
    metal = np.zeros(n)
    for _ in range(40):
        f = rng.uniform(3000, 10500)
        metal += np.sin(TAU * f * t + rng.uniform(0, TAU)) * rng.uniform(0.2, 1.0)
    metal = metal * (1 + 0.5 * fm(430, n, 1.41, 3.0))
    nz = filt(white(n, rng), ("hp", 4000 * bright, 0.7))
    x = metal / (np.max(np.abs(metal)) + 1e-9) * 0.5 + nz / (np.max(np.abs(nz)) + 1e-9) * 0.6
    e = perc(n, 0.001, dur) * (0.6 + 0.4 * np.exp(-t / 0.08))
    return filt(x * e, ("hp", 2500, 0.6))


# --------------------------------------------------------------------------- mastering

def _max_filter(x: np.ndarray, win: int, circular: bool = False) -> np.ndarray:
    h = win // 2
    xp = np.pad(x, (h, win - 1 - h), mode="wrap" if circular else "edge")
    v = np.lib.stride_tricks.sliding_window_view(xp, win)
    return v.max(axis=1)


def _min_filter(x, win, circular=False):
    return -_max_filter(-x, win, circular)


def _box(x: np.ndarray, win: int, circular: bool = False) -> np.ndarray:
    h = win // 2
    xp = np.pad(x, (h, win - 1 - h), mode="wrap" if circular else "edge")
    c = np.concatenate([[0.0], np.cumsum(xp)])
    return (c[win:] - c[:-win]) / win


def limit(x: np.ndarray, ceiling: float = 0.89, win_sec: float = 0.004, circular: bool = False) -> np.ndarray:
    """Look-ahead-style peak limiter: never exceeds ceiling, smooth gain changes."""
    win = max(3, ns(win_sec)) | 1
    env = _max_filter(np.abs(x), win, circular)
    g = np.minimum(1.0, ceiling / np.maximum(env, 1e-9))
    g = _min_filter(g, win, circular)
    g = _box(g, win, circular)
    y = x * g
    return np.clip(y, -ceiling, ceiling)


def short_rms(x: np.ndarray, win_sec: float = 0.05) -> np.ndarray:
    win = max(1, ns(win_sec))
    return np.sqrt(np.maximum(_box(x * x, win), 0.0))


def weighted(x: np.ndarray, circular: bool = False) -> np.ndarray:
    """Loudness weighting for level matching (K-weighting-ish, tilted for phone speakers:
    little below 120 Hz counts, presence region counts extra)."""
    return filt(x, ("hp", 120.0, 0.7), ("highshelf", 1500.0, 0.7, 4.0), circular=circular)


def dc_block(x: np.ndarray, fc: float = 25.0, circular: bool = False) -> np.ndarray:
    return filt(x, ("hp", fc, 0.6), circular=circular)


# --------------------------------------------------------------------------- additions (Mischief)

def soft_clip(x: np.ndarray, amount: float = 1.5) -> np.ndarray:
    """Symmetric tanh saturation that keeps unity gain for small signals."""
    return np.tanh(x * amount) / amount


def norm(x: np.ndarray, peak: float = 1.0) -> np.ndarray:
    """Peak-normalise to `peak` (silence stays silence)."""
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    return x * (peak / m) if m > 1e-12 else x


def pad(x: np.ndarray, n: int) -> np.ndarray:
    """Zero-pad or cut to exactly n samples."""
    return pad_to(np.asarray(x, float), n)


def cents(c) -> np.ndarray | float:
    """Frequency ratio of `c` cents."""
    return 2.0 ** (np.asarray(c, float) / 1200.0)


def vibrato(n: int, rate: float = 5.5, depth_cents: float = 40.0, onset: float = 0.15,
            rng=None, drift: float = 0.08) -> np.ndarray:
    """Pitch multiplier curve for a sung vibrato that fades in after `onset` seconds.

    The rate wanders a little (drift, fraction of `rate`) so long notes don't sound
    like an LFO.
    """
    t = np.arange(n) / SR
    rng = rng or np.random.default_rng(5)
    r = rate * (1.0 + drift * smooth_noise(n, 1.5, rng))
    ph = phase_of(r, n)
    ramp = np.clip((t - onset) / 0.18, 0.0, 1.0)
    return 2.0 ** (depth_cents * ramp * np.sin(TAU * ph) / 1200.0)
