"""Bellows' voice: a pre-rendered phrase bank from a tiny score language, rendered by two
engines so the Gate-0 A/B compares like with like (GDD §9.5, R5):

  * "formant" — an additive formant singer (synth.voice): baritone, 5.5 Hz vibrato ±40
    cents, operatic scoops, a singer's-formant ring, drive on shouts, a falsetto crack;
  * "tuba"    — the same score played by a muted "talking tuba": identical pitch curve,
    rhythm and loudness, with a plunger wah that follows each vowel's openness, tongued
    attacks for t/d/k, lip closures for p/b/m and a breath of air for s/sh/f.

Everything is gibberish except the shaped lines the brief asks for ("PIPE DOWN!",
"…the pipes.", "pardon", "WHO SQUEAKED?!"). Pitches are MIDI numbers; spoken lines sit
around f0 90–110 Hz (MIDI 42–45).

Files (bank = the id without the variant suffix):
  vo_bellows_<line>[_n]            formant (default)
  vo_bellows_tuba_<line>[_n]       the talking-tuba fallback (same bank shape)
  vo_bellows_squeaky_<line>_n      chipmunk (+12 st) aria / shout sets for the SQUEAKY residue

Speaker presets (`SPEAKERS`) keep the recipe structure ready for Delphine and Beryl (S3).
"""
from __future__ import annotations

import math
import zlib
from dataclasses import dataclass, field, replace

import numpy as np

from registry import sfx
from synth import (SR, TAU, VOWELS, arr, burst, cents, drive, env_lin, filt, norm, ns, phase_of, reverb,
                   smooth_noise, tt, voice, white)

VOWELS.setdefault("l", (360, 1300, 2700, 3300))
VOWELS.setdefault("y", (300, 2300, 3000, 3700))
VOWELS.setdefault("w", (330, 750, 2300, 3200))
VOWELS.setdefault("ng", (300, 1500, 2600, 3300))

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def m(name: str) -> float:
    """'C3' / 'F#4' / 'Bb3' → MIDI number (C4 = 60)."""
    base = NOTE[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        base += 1 if name[i] == "#" else -1
        i += 1
    return float(base + 12 * (int(name[i:]) + 1))


def hz2m(f: float) -> float:
    return 69.0 + 12.0 * math.log2(f / 440.0)


# ----------------------------------------------------------------------------- the score

@dataclass
class Syl:
    """One syllable: onset consonants `c`, vowel `v` (a diphthong is 'a+i'), slot length
    `d` seconds, pitch `p` (MIDI, or (start, end) for a glide), level `lv`."""
    c: str
    v: str
    d: float
    p: float | tuple
    lv: float = 1.0
    coda: str = ""
    vib: float = 1.0          # vibrato depth scale (sung lines)
    gap: float = 0.0          # silence before the syllable
    acc: bool = False         # operatic scoop into the note
    fals: bool = False        # falsetto (the yodel crack)
    trill: float = 0.0        # amplitude trill Hz (lip trill, growl)


@dataclass
class Line:
    syls: list
    mode: str = "sung"        # sung | spoken | shout
    drive: float = 0.0
    breath: float | None = None
    tilt: float | None = None
    jitter: float | None = None
    fry: float = 0.0          # vocal-fry roughness (ugh, the pipes)
    tail: float = 0.15        # seconds of release/reverb after the last syllable
    pre: list = field(default_factory=list)   # [(t, kind, gain)] extra noises: inhale, sigh


@dataclass
class Speaker:
    name: str
    tract: float = 0.86       # formant scale (< 1 = a big man)
    transpose: float = 0.0    # semitones added to every pitch
    vib_hz: float = 5.5
    vib_cents: float = 40.0
    jitter: float = 0.005
    breath: float = 0.07
    tilt: float = 1.05
    ring_db: float = 5.0      # the singer's formant
    ring_hz: float = 2700.0
    chest_db: float = 3.0
    room: float = 0.1
    max_hz: float = 8500.0


SPEAKERS: dict[str, Speaker] = {
    "bellows": Speaker("bellows"),
    # Stage 3 presets (lines land with s3 tasks): soprano f0 280-340 Hz with a glass-crack tail;
    # Beryl's "mehhh" uses the same engine with a bleat trill.
    "delphine": Speaker("delphine", tract=1.2, vib_hz=6.2, vib_cents=55.0, breath=0.09, tilt=1.2, ring_hz=3100.0,
                        chest_db=0.0),
    "beryl": Speaker("beryl", tract=1.45, vib_hz=7.5, vib_cents=90.0, breath=0.2, tilt=0.8, ring_db=0.0,
                     chest_db=0.0),
}


def S(c, v, d, p, **kw) -> Syl:
    return Syl(c, v, d, m(p) if isinstance(p, str) else (tuple(m(q) if isinstance(q, str) else q for q in p)
                                                         if isinstance(p, tuple) else p), **kw)


# ----------------------------------------------------------------------------- consonants

PLOSIVE = {"p": (600, 2600, False, 0.03), "b": (500, 2200, True, 0.018), "t": (3000, 8000, False, 0.028),
           "d": (2500, 6500, True, 0.016), "k": (1500, 4500, False, 0.03), "g": (1300, 3800, True, 0.02)}
FRIC = {"s": (4500, 9500, 0.08), "sh": (2200, 6000, 0.08), "f": (1500, 7000, 0.07), "h": (500, 6000, 0.05),
        "th": (1800, 7000, 0.06), "ch": (2200, 6500, 0.06)}
MURMUR = {"m": ("m", 0.06), "n": ("n", 0.055), "l": ("l", 0.05), "w": ("w", 0.045), "y": ("y", 0.04),
          "r": ("er", 0.05), "ng": ("ng", 0.06)}


def phones(cluster: str) -> list[str]:
    """'skw' → ['s', 'k', 'w']; 'sh', 'th', 'ch', 'ng' stay whole."""
    out, i = [], 0
    while i < len(cluster):
        two = cluster[i:i + 2]
        if two in ("sh", "th", "ch", "ng"):
            out.append(two)
            i += 2
        else:
            out.append(cluster[i])
            i += 1
    return out


def phone_len(ph: str) -> float:
    if ph in PLOSIVE:
        return PLOSIVE[ph][3]
    if ph in FRIC:
        return FRIC[ph][2]
    if ph in MURMUR:
        return MURMUR[ph][1]
    return 0.03


def nucleus(v: str) -> list[tuple[float, str]]:
    """Vowel targets across the nucleus as (fraction, vowel)."""
    if "+" in v:
        a, b = v.split("+", 1)
        return [(0.0, a), (0.3, a), (0.85, b)]
    return [(0.0, v)]


# ----------------------------------------------------------------------------- timeline

@dataclass
class Timeline:
    n: int
    f0: np.ndarray            # Hz, vibrato included
    forms: np.ndarray         # [4, n] Hz (already tract-scaled)
    amp: np.ndarray
    breath: np.ndarray
    fals: np.ndarray          # 0..1 falsetto mask
    trill: np.ndarray         # amplitude-trill rate (Hz, 0 = none)
    noises: list              # [(t, kind, phone, gain)]
    tongue: list              # [(t, depth)] tongued-attack dips for the tuba
    end: float


def build(line: Line, spk: Speaker, transpose: float = 0.0, tract_mul: float = 1.0) -> Timeline:
    sung = line.mode == "sung"
    port = 0.05 if sung else 0.03
    tp = spk.transpose + transpose
    t = 0.02
    f_pts: list[tuple[float, float]] = []
    a_pts: list[tuple[float, float]] = [(0.0, 0.0)]
    b_pts: list[tuple[float, float]] = [(0.0, 0.0)]
    v_pts: list[tuple[float, str]] = []
    fal_pts: list[tuple[float, float]] = [(0.0, 0.0)]
    tr_pts: list[tuple[float, float]] = [(0.0, 0.0)]
    vib_spans: list[tuple[float, float, float]] = []
    noises: list = []
    tongue: list = []
    prev_end_p = None
    for s in line.syls:
        t += s.gap
        if s.gap > 0.0:
            a_pts.append((t - 0.005, 0.0))
        p0, p1 = (s.p if isinstance(s.p, tuple) else (s.p, s.p))
        p0 += tp
        p1 += tp
        on = phones(s.c)
        co = phones(s.coda)
        on_len = sum(phone_len(q) for q in on)
        co_len = sum(phone_len(q) for q in co)
        budget = s.d * 0.45
        k_on = min(1.0, budget / on_len) if on_len > 0 else 1.0
        k_co = min(1.0, budget / co_len) if co_len > 0 else 1.0
        vt = t + on_len * k_on
        ve = t + s.d - co_len * k_co
        ve = max(ve, vt + 0.03)
        # onset consonants
        c_t = t
        first_vowel = nucleus(s.v)[0][1]
        for q in on:
            ql = phone_len(q) * k_on
            if q in PLOSIVE:
                lo, hi, voiced, _ = PLOSIVE[q]
                a_pts += [(c_t, 0.04 if voiced else 0.0), (c_t + ql - 0.003, 0.05 if voiced else 0.0)]
                noises.append((c_t + ql - 0.004, "burst", q, (0.45 if voiced else 0.7) * s.lv))
                tongue.append((c_t + ql, 0.85))
                v_pts.append((c_t, first_vowel if q not in "pbm" else "m"))
            elif q in FRIC:
                a_pts += [(c_t, 0.0), (c_t + ql - 0.004, 0.03)]
                noises.append((c_t, "fric", q, (0.5 if q != "h" else 0.35) * s.lv * (ql / FRIC[q][2])))
                b_pts += [(c_t, 0.0), (c_t + ql * 0.4, 0.6 * s.lv if q == "h" else 0.1), (c_t + ql, 0.0)]
                if q in ("t", "ch"):
                    tongue.append((c_t, 0.7))
                v_pts.append((c_t, first_vowel))
            elif q in MURMUR:
                loc = MURMUR[q][0]
                a_pts += [(c_t + 0.006, 0.5 * s.lv), (c_t + ql, 0.7 * s.lv)]
                v_pts += [(c_t, loc), (c_t + ql * 0.7, loc)]
                if q in ("m", "b", "p"):
                    tongue.append((c_t + ql, 0.3))
            c_t += ql
        # nucleus
        nl = ve - vt
        a_pts += [(vt + (0.012 if on else 0.03), s.lv), (ve - 0.03, s.lv * 0.9)]
        for frac, vv in nucleus(s.v):
            v_pts.append((vt + frac * nl + (0.035 if frac == 0 else 0.0), vv))
        scoop = -0.7 if (s.acc and sung) else 0.0
        start_p = prev_end_p if prev_end_p is not None and not on and s.gap == 0 else p0 + scoop
        f_pts += [(t, start_p), (vt + port + (0.04 if scoop else 0.0), p0), (ve - 0.015, p1)]
        if sung and nl > 0.2:
            vib_spans.append((vt, ve, s.vib))
        fal_pts += [(t, 1.0 if s.fals else 0.0), (ve, 1.0 if s.fals else 0.0)]
        tr_pts += [(t, s.trill), (ve, s.trill)]
        # coda
        c_t = ve
        a_pts.append((ve, s.lv * 0.8))
        for q in co:
            ql = phone_len(q) * k_co
            if q in PLOSIVE:
                lo, hi, voiced, _ = PLOSIVE[q]
                a_pts += [(c_t + 0.008, 0.0), (c_t + ql, 0.0)]
                noises.append((c_t + ql - 0.004, "burst", q, 0.4 * s.lv))
                v_pts.append((c_t + 0.01, "m" if q in "pb" else nucleus(s.v)[-1][1]))
            elif q in FRIC:
                a_pts += [(c_t + 0.01, 0.05), (c_t + ql, 0.0)]
                noises.append((c_t, "fric", q, 0.45 * s.lv))
            elif q in MURMUR:
                loc = MURMUR[q][0]
                a_pts += [(c_t + 0.01, 0.6 * s.lv), (c_t + ql - 0.01, 0.45 * s.lv)]
                v_pts.append((c_t + 0.012, loc))
            c_t += ql
        t = t + s.d
        a_pts.append((t - 0.004, 0.0 if (co and co[-1] in PLOSIVE) else a_pts[-1][1] * 0.3))
        prev_end_p = p1
    end = t
    total = end + line.tail
    n = ns(total)
    tx = np.arange(n) / SR

    def interp(pts, default=0.0):
        if not pts:
            return np.full(n, default)
        pts = sorted(pts, key=lambda q: q[0])
        return np.interp(tx, [q[0] for q in pts], [q[1] for q in pts])

    amp = np.clip(interp(a_pts + [(end + 0.01, 0.0), (total, 0.0)]), 0.0, 1.3)
    pitch = interp(f_pts)
    vib = np.zeros(n)
    for a, b, depth in vib_spans:
        ramp = np.clip((tx - a - 0.12) / 0.18, 0, 1) * (tx < b + 0.05)
        vib = np.maximum(vib, ramp * depth)
    rng = np.random.default_rng(len(line.syls) * 7919 + int(pitch[0] * 10))
    rate = spk.vib_hz * (1 + 0.06 * smooth_noise(n, 1.2, rng))
    pitch = pitch + (spk.vib_cents / 100.0) * vib * np.sin(TAU * phase_of(rate, n))
    f0 = 440.0 * 2 ** ((pitch - 69.0) / 12.0)
    v_pts = sorted(v_pts, key=lambda q: q[0])
    forms = np.zeros((4, n))
    for j in range(4):
        forms[j] = np.interp(tx, [q[0] for q in v_pts], [VOWELS[q[1]][j] * spk.tract * tract_mul for q in v_pts])
    breath = np.clip(interp(b_pts), 0.0, 1.0)
    return Timeline(n, f0, forms, amp, breath, np.clip(interp(fal_pts), 0, 1), interp(tr_pts), noises, tongue, end)


def noise_signal(kind: str, ph: str, rng) -> np.ndarray:
    if kind == "burst":
        lo, hi, voiced, _ = PLOSIVE[ph]
        return burst(ns(0.03), rng, lo, hi, 0.0004, 0.012 if voiced else 0.018)
    lo, hi, dur = FRIC[ph]
    mlen = ns(dur * (1.4 if ph in ("s", "sh", "ch") else 1.0))
    x = filt(white(mlen, rng), ("hp", lo, 0.7), ("lp", hi, 0.7))
    e = env_lin([(0, 0), (0.012, 1), (mlen / SR * 0.7, 0.8), (mlen / SR, 0)], mlen)
    return norm(x) * e


# ----------------------------------------------------------------------------- engines

def render_formant(line: Line, spk: Speaker, rng, transpose: float = 0.0, tract_mul: float = 1.0) -> np.ndarray:
    tl = build(line, spk, transpose, tract_mul)
    n = tl.n
    tx = tt(n)
    mode = line.mode
    breath = line.breath if line.breath is not None else {"sung": 0.06, "spoken": 0.1, "shout": 0.14}[mode] + spk.breath * 0.3
    tilt = line.tilt if line.tilt is not None else {"sung": spk.tilt, "spoken": spk.tilt + 0.1, "shout": 0.72}[mode]
    jit = line.jitter if line.jitter is not None else {"sung": spk.jitter, "spoken": spk.jitter * 1.6, "shout": 0.012}[mode]
    f0 = tl.f0
    if line.fry:
        f0 = f0 * (1 + line.fry * 0.25 * smooth_noise(n, 60, rng))
    amp = tl.amp.copy()
    if np.any(tl.trill > 0):
        amp *= 1 - 0.55 * (tl.trill > 0) * (0.5 + 0.5 * np.sin(TAU * phase_of(np.maximum(tl.trill, 1.0), n)))
    b_amp = np.maximum(amp * 0.7, tl.breath)
    y = voice(f0, tl.forms, amp, breath=breath, tilt=tilt, rng=rng, jitter=jit, max_hz=spk.max_hz,
              breath_amp=b_amp)
    if np.any(tl.fals > 0.01):
        # falsetto: a thin, breathy, near-sinusoidal voice an octave-ish up the same curve
        yf = voice(f0, tl.forms * 1.06, amp, breath=0.45, tilt=2.2, rng=rng, jitter=0.012, max_hz=spk.max_hz,
                   breath_amp=amp)
        mix = tl.fals
        y = norm(y) * (1 - mix) + norm(yf) * mix * 0.8
        edges = np.nonzero(np.abs(np.diff((mix > 0.5).astype(float))) > 0)[0]
        for e in edges:
            c = burst(ns(0.02), rng, 800, 5000, 0.0002, 0.006)
            y[e:e + len(c)] += c[: n - e] * 0.35   # the audible 'crack'
    y = norm(y)
    for (at, kind, ph, g) in tl.noises:
        sig = noise_signal(kind, ph, rng)
        i = ns(max(0.0, at))
        k = min(len(sig), n - i)
        if k > 0:
            y[i:i + k] += sig[:k] * g * 0.55
    for (at, kind, g) in line.pre:
        sig = _extra(kind, rng)
        i = ns(max(0.0, at))
        k = min(len(sig), n - i)
        if k > 0:
            y[i:i + k] += sig[:k] * g
    eq = [("peak", 170, 1.0, spk.chest_db), ("hp", 70, 0.7)]
    if mode != "spoken":
        eq.append(("peak", spk.ring_hz, 1.6, spk.ring_db + (3.0 if mode == "shout" else 0.0)))
    y = filt(y, *eq)
    if line.drive or mode == "shout":
        y = drive(norm(y) * 1.1, line.drive or 2.0)
    return reverb(norm(y), spk.room, 0.38, keep_len=True)


def render_tuba(line: Line, spk: Speaker, rng, transpose: float = 0.0) -> np.ndarray:
    """The talking tuba: same score, a muted low-brass voice with a vowel-following wah."""
    tl = build(line, spk, transpose)
    n = tl.n
    tx = tt(n)
    f0 = tl.f0
    if np.any(tl.fals > 0.01):
        f0 = f0 * (1 + 0.5 * tl.fals)   # the crack: an overblown partial
    amp = filt(tl.amp, ("lp", 60.0, 0.7))
    for at, depth in tl.tongue:           # tongued re-attacks
        i = ns(at)
        k = ns(0.035)
        if i < n:
            seg = min(k, n - i)
            amp[i:i + seg] *= 1 - depth * np.hanning(2 * k)[k:k + seg]
    amp = np.clip(amp, 0.0, 1.3)
    if np.any(tl.trill > 0):
        amp *= 1 - 0.5 * (tl.trill > 0) * (0.5 + 0.5 * np.sin(TAU * phase_of(np.maximum(tl.trill, 1.0), n)))
    f1, f2 = tl.forms[0] / spk.tract, tl.forms[1] / spk.tract
    openness = np.clip((f1 - 280.0) / 520.0, 0.0, 1.0)
    w1 = 380.0 + 1250.0 * openness
    w2 = np.clip(f2 * 0.75, 600.0, 2200.0)
    loud = amp / (np.max(amp) + 1e-9)
    shout = line.mode == "shout"
    cutoff = 2.0 + (9.0 if shout else 6.5) * loud
    base = phase_of(f0, n)
    out = np.zeros(n)
    kmax = int(6000.0 / max(float(np.min(f0)), 40.0))
    for k in range(1, min(kmax, 60) + 1):
        fk = f0 * k
        ok = fk < 6000.0
        if not ok.any():
            break
        a = 1.0 / (1.0 + (k / cutoff) ** 3) / k ** 0.3
        wah = 0.18 + 1.25 / (1.0 + ((fk - w1) / (0.45 * w1)) ** 2) + 0.55 / (1.0 + ((fk - w2) / (0.35 * w2)) ** 2)
        out += np.where(ok, np.sin(TAU * base * k), 0.0) * a * wah
    lvl = np.sqrt(np.maximum(filt(out * out, ("lp", 30.0, 0.7)), 1e-9))
    out = out / np.maximum(lvl, np.max(lvl) * 0.05) * amp
    if shout:
        out *= 1 + 0.18 * np.sin(TAU * 31 * tx)
    y = norm(out)
    for (at, kind, ph, g) in tl.noises:
        if kind == "fric" and ph != "h":
            sig = filt(noise_signal(kind, ph, rng), ("lp", 5000, 0.7))
            gain = 0.1
        elif kind == "burst" and ph in "tdkg":
            sig = burst(ns(0.02), rng, 900, 3000, 0.0003, 0.008)
            gain = 0.15
        else:
            continue
        i = ns(max(0.0, at))
        k = min(len(sig), n - i)
        if k > 0:
            y[i:i + k] += sig[:k] * gain * g
    y = filt(y, ("peak", 1600, 1.4, 5.0), ("lp", 5200, 0.7), ("hp", 45, 0.7))
    y = drive(norm(y) * 1.15, 1.9 if shout else 1.3)
    return reverb(norm(y), spk.room + 0.03, 0.4, keep_len=True)


def _extra(kind: str, rng) -> np.ndarray:
    """Non-phonetic noises: an inhale before a sneeze, a weary sigh."""
    if kind == "inhale":
        mlen = ns(0.22)
        x = filt(white(mlen, rng), ("bp", 2200, 1.0), ("peak", 3200, 2.0, 6))
        return norm(x) * env_lin([(0, 0), (0.15, 1), (0.22, 0)], mlen) * 0.3
    if kind == "sigh":
        mlen = ns(0.4)
        x = filt(white(mlen, rng), ("bp", 900, 0.8))
        return norm(x) * env_lin([(0, 0), (0.08, 1), (0.4, 0)], mlen) * 0.22
    if kind == "blast":
        mlen = ns(0.07)
        x = filt(white(mlen, rng), ("hp", 1800, 0.7), ("peak", 4000, 1.0, 6.0))
        return norm(x) * env_lin([(0, 1.0), (0.015, 0.9), (0.07, 0)], mlen) * 0.9
    if kind == "spray":
        mlen = ns(0.3)
        x = filt(white(mlen, rng), ("hp", 1500))
        return norm(x) * env_lin([(0, 1), (0.3, 0)], mlen) * 0.5
    raise ValueError(kind)


# ----------------------------------------------------------------------------- Bellows' lines

def _nv(v: int, base: float) -> float:
    """Variant pitch offsets for the 3 takes of a nonverbal."""
    return base + (0.0, 1.7, -1.4)[v]


def _dur(v: int) -> float:
    return (1.0, 1.12, 0.9)[v]


def nonverbal(kind: str, v: int) -> Line:
    k = _dur(v)
    P = lambda x: _nv(v, x)   # noqa: E731
    if kind == "hmph":
        return Line([S("m", "m", 0.16 * k, (P(45), P(43)), lv=0.8), S("p", "uh", 0.05, P(42), lv=0.3, coda="f")],
                    mode="spoken", tail=0.12)
    if kind == "huh":
        return Line([S("h", "uh", 0.3 * k, (P(43), P(50)))], mode="spoken", tail=0.12)
    if kind == "wha":
        return Line([S("w", "a", 0.36 * k, (P(48), P(55)), lv=1.1), S("", "a", 0.12, (P(55), P(50)), lv=0.8)],
                    mode="shout", drive=1.7, tail=0.15)
    if kind == "yow":
        return Line([S("y", "a+u", 0.46 * k, (P(53), P(48)), lv=1.1)], mode="shout", drive=1.6, tail=0.15)
    if kind == "grr":
        return Line([S("g", "er", 0.55 * k, (P(41), P(40)), trill=26.0)], mode="spoken", drive=1.6, fry=0.5, tail=0.1)
    if kind == "ahem":
        return Line([S("", "a", 0.12, P(44), lv=0.7), S("h", "e", 0.15 * k, P(47)), S("", "e", 0.03, P(45)),
                     S("m", "m", 0.2 * k, (P(45), P(43)), lv=0.7)], mode="spoken", tail=0.12)
    if kind == "ooh":
        return Line([S("", "u+o", 0.45 * k, (P(45), P(51))), S("", "o", 0.2, (P(51), P(46)), lv=0.8)],
                    mode="sung", tail=0.18)
    if kind == "hah":
        return Line([S("h", "a", 0.2 * k, (P(50), P(46)), lv=1.1)], mode="shout", drive=1.4, tail=0.14)
    if kind == "tut":
        return Line([S("t", "uh", 0.07, P(44), lv=0.25, coda="t"), S("t", "uh", 0.07, P(44), lv=0.25, coda="t",
                                                                         gap=0.14 * k)], mode="spoken", tail=0.1)
    if kind == "pff":
        return Line([S("p", "uh", 0.06, P(45), lv=0.35, coda="f"), S("f", "uh", 0.14 * k, P(43), lv=0.1)],
                    mode="spoken", breath=0.4, tail=0.1)
    if kind == "ugh":
        return Line([S("", "uh", 0.34 * k, (P(40), P(37)), lv=0.9, coda="g")], mode="spoken", fry=1.0, tail=0.1)
    if kind == "oof":
        return Line([S("", "u", 0.18 * k, (P(50), P(44)), lv=1.1, coda="f")], mode="shout", drive=1.3, tail=0.1)
    raise ValueError(kind)


NONVERBALS = ("hmph", "huh", "wha", "yow", "grr", "ahem", "ooh", "hah", "tut", "pff", "ugh", "oof")


def _scale(sylls, notes, d, last_d, vowels="i", c="m", acc_last=True, lv_last=1.1):
    out = []
    for i, p in enumerate(notes):
        last = i == len(notes) - 1
        v = vowels[i % len(vowels)] if len(vowels) > 1 else vowels
        out.append(S(c, v, last_d if last else d, p, lv=lv_last if last else 0.9, acc=last and acc_last,
                     vib=1.0 if last else 0.3))
    return out


def lines_bellows() -> dict[str, Line]:
    L: dict[str, Line] = {}
    # --- warm-ups (MI-MI-MIII) -------------------------------------------------------
    L["warmup_1"] = Line(_scale(None, ["C3", "E3", "G3", "C4", "C4"], 0.17, 0.85, "i")[:4]
                         + [S("m", "i", 0.75, "C4", lv=1.15, acc=True)], tail=0.18)
    L["warmup_2"] = Line([S("m", v, 0.14, p, lv=0.9, vib=0.2) for v, p in
                          zip("aeiouoiea", ["C3", "D3", "E3", "F3", "G3", "F3", "E3", "D3"])]
                         + [S("m", "a", 0.5, "C3", lv=1.0)], tail=0.18)
    L["warmup_3"] = Line([S("l", "a", 0.2, "D3", lv=0.9), S("l", "a", 0.2, "A3", lv=0.95),
                          S("l", "a", 0.8, "D4", lv=1.15, acc=True)], tail=0.18)
    L["warmup_4"] = Line([S("b", "u", 1.0, ("G2", "G3"), trill=24.0, lv=0.8, vib=0.0),
                          S("", "u", 0.35, ("G3", "C3"), trill=24.0, lv=0.7, vib=0.0),
                          S("h", "a", 0.3, "C3", lv=1.1, gap=0.06)], tail=0.15)
    L["warmup_5"] = Line([S("n", v, 0.16, p, lv=0.95, vib=0.2) for v, p in zip("ieaou", ["G3", "F3", "E3", "D3", "C3"])]
                         + [S("m", "m", 0.55, "C3", lv=0.8)], tail=0.18)
    # --- the note that cracks into a yodel ---------------------------------------------
    L["crack_1"] = Line([S("m", "i", 0.17, "E3", lv=0.9), S("m", "i", 0.17, "G#3", lv=0.95),
                         S("m", "i", 0.17, "B3", lv=1.0), S("m", "i", 0.32, "E4", lv=1.15, acc=True),
                         S("", "i", 0.16, "A4", fals=True, lv=0.9, vib=0.0), S("", "i", 0.12, "E4", fals=True, lv=0.8),
                         S("", "i", 0.14, "A4", fals=True, lv=0.8), S("", "i", 0.3, ("B4", "F4"), fals=True, lv=0.6)],
                        tail=0.15)
    L["crack_2"] = Line([S("l", "a", 0.18, "G3", lv=0.9), S("l", "a", 0.18, "C4", lv=1.0),
                         S("l", "a", 0.36, "E4", lv=1.15, acc=True),
                         S("", "a+i", 0.22, ("C5", "D5"), fals=True, lv=0.8, vib=0.0),
                         S("", "i", 0.28, ("D5", "G4"), fals=True, lv=0.55)], tail=0.15)
    # --- aria phrases after public-domain melodies (gibberish syllables) -------------------
    # 1 Bizet, Toreador refrain (F major, the baritone's own aria)
    L["aria_1"] = Line([S("t", "o", 0.28, "C4", acc=True), S("r", "e", 0.13, "D4"), S("", "a", 0.14, "C4"),
                        S("d", "o", 0.5, "A3", coda="r"), S("", "e", 0.13, "A3", gap=0.04), S("g", "a", 0.13, "G3"),
                        S("r", "a", 0.13, "A3"), S("t", "a", 0.13, "Bb3"), S("d", "a", 0.5, "A3", acc=True, lv=1.1)],
                       tail=0.2)
    # 2 Wagner, Bridal Chorus (hummed-sung "dum, da-da-DUM")
    L["aria_2"] = Line([S("d", "u", 0.36, "C3", coda="m"), S("d", "a", 0.27, "F3"), S("d", "a", 0.09, "F3"),
                        S("d", "u", 0.5, "F3", coda="m", acc=True), S("d", "u", 0.34, "C3", coda="m", gap=0.04),
                        S("d", "a", 0.27, "G3"), S("d", "a", 0.09, "E3"), S("d", "u", 0.55, "F3", coda="m", lv=1.1)],
                       tail=0.2)
    # 3 Beethoven, Ode to Joy (D major)
    L["aria_3"] = Line([S("l", "a", 0.2, p, vib=0.3) for p in ("F#3", "F#3", "G3", "A3", "A3", "G3", "F#3")]
                       + [S("l", "a", 0.55, "E3", acc=True, lv=1.1)], tail=0.2)
    # 4 Bizet, Habanera — the chromatic slink, sung by entirely the wrong man
    L["aria_4"] = Line([S("l", "a", 0.3, "D4", acc=True), S("m", "o", 0.15, "C#4"), S("r", "e", 0.3, "C4"),
                        S("l", "a", 0.15, "B3"), S("m", "o", 0.3, "Bb3"), S("r", "e", 0.5, "A3", lv=1.1)], tail=0.2)
    # 5 Mozart, Eine kleine Nachtmusik (G major)
    L["aria_5"] = Line([S("d", "a", 0.3, "G3"), S("d", "a", 0.15, "D3"), S("d", "a", 0.3, "G3"), S("d", "a", 0.15, "D3"),
                        S("d", "a", 0.12, "G3"), S("d", "a", 0.12, "D3"), S("d", "a", 0.12, "G3"),
                        S("d", "i", 0.12, "B3"), S("d", "a", 0.5, "D4", acc=True, lv=1.1)], tail=0.2)
    # 6 Grieg, Morning Mood (E major)
    L["aria_6"] = Line([S("l", v, 0.22, p, vib=0.3) for v, p in zip("oiaoai", ("B3", "G#3", "F#3", "E3", "F#3", "G#3"))]
                       + [S("l", "o", 0.55, "B3", acc=True, lv=1.1)], tail=0.2)
    # --- PIPE DOWN! ----------------------------------------------------------------------
    L["pipe_down_1"] = Line([S("p", "a+i", 0.32, ("G3", "A3"), coda="p", lv=1.1),
                             S("d", "a+u", 0.4, ("F#3", "C3"), coda="n", gap=0.05, lv=1.15)], mode="shout", drive=2.2)
    L["pipe_down_2"] = Line([S("p", "a+i", 0.52, ("A3", "B3"), coda="p", lv=1.1),
                             S("d", "a+u", 0.34, ("F#3", "D3"), coda="n", gap=0.04, lv=1.15)], mode="shout", drive=2.3)
    L["pipe_down_3"] = Line([S("p", "a+i", 0.26, "G3", coda="p", lv=1.05),
                             S("d", "a+u", 0.62, ("A3", "C3"), coda="n", gap=0.12, lv=1.2)], mode="shout", drive=2.4)
    L["pipe_down_4"] = Line([S("p", "a+i", 0.5, "D4", coda="p", lv=1.1, acc=True),
                             S("d", "a+u", 0.7, "G3", coda="n", gap=0.06, lv=1.15, acc=True)], mode="sung", drive=1.5)
    # --- the Lecture: sung scoldings with a finger-wag beat (2.2 s) --------------------------
    wag = 0.25
    L["lecture_a"] = Line([S("t", "uh", 0.08, "E3", lv=0.35, coda="k")]
                          + [S("n", "a", wag, p, lv=lv, vib=0.2) for p, lv in
                             (("E3", 0.9), ("E3", 0.85), ("F3", 1.1), ("E3", 0.85), ("D3", 0.9), ("D3", 0.85))]
                          + [S("n", "a", 0.62, "C3", lv=1.1, acc=True)], mode="sung", drive=1.3, tail=0.2)
    L["lecture_b"] = Line([S("n", "e", wag, p, lv=lv, vib=0.2) for p, lv in
                           (("D3", 0.9), ("F3", 0.9), ("E3", 1.1), ("D3", 0.9), ("F3", 0.9), ("E3", 1.1))]
                          + [S("n", "o", wag, "A3", lv=1.1), S("n", "o", 0.16, "G3"), S("n", "o", 0.34, "E3", lv=1.1)],
                          mode="sung", drive=1.3, tail=0.2)
    L["lecture_c"] = Line([S("l", "a", wag, "C3"), S("d", "i", wag, "A3", lv=1.1), S("d", "a", wag, "G#3"),
                           S("d", "i", wag, "A3", lv=1.1), S("d", "a", wag, "G#3"), S("d", "a", wag, "A3", lv=1.1),
                           S("d", "u", 0.66, "E3", coda="m", lv=1.15, acc=True)], mode="sung", drive=1.3, tail=0.2)
    # --- nonverbals ------------------------------------------------------------------------
    for kind in NONVERBALS:
        for v in range(3):
            L[f"{kind}_{v + 1}"] = nonverbal(kind, v)
    # --- the sneeze (rule of three, then CHOO) -----------------------------------------------
    L["sneeze_ah1"] = Line([S("h", "a", 0.3, (43, 46), lv=0.6)], mode="spoken", breath=0.45, tail=0.08,
                           pre=[(0.0, "inhale", 1.0)])
    L["sneeze_ah2"] = Line([S("h", "a", 0.36, (45, 49), lv=0.8)], mode="spoken", breath=0.4, tail=0.08,
                           pre=[(0.0, "inhale", 1.0)])
    L["sneeze_ah3"] = Line([S("h", "a", 0.46, (47, 55), lv=1.0, trill=8.0)], mode="sung", breath=0.35, tail=0.1,
                           pre=[(0.0, "inhale", 1.2)])
    L["sneeze_choo_1"] = Line([S("tsh", "u", 0.32, (58, 48), lv=1.2)], mode="shout", drive=2.6, tail=0.15,
                              pre=[(0.0, "blast", 1.0), (0.03, "spray", 1.3)])
    L["sneeze_choo_2"] = Line([S("tsh", "u", 0.38, (60, 47), lv=1.2)], mode="shout", drive=2.8, tail=0.15,
                              pre=[(0.0, "blast", 1.1), (0.03, "spray", 1.4)])
    L["sneeze_small"] = Line([S("h", "i", 0.14, (50, 53), lv=0.5), S("tsh", "u", 0.14, (55, 50), lv=0.8, gap=0.08)],
                             mode="spoken", tail=0.1)
    # --- humming (hm-hm-hmm…) ---------------------------------------------------------------------
    L["hum_1"] = Line([S("h", "m", 0.2, "C3", lv=0.8), S("", "m", 0.2, "E3", lv=0.8, gap=0.05),
                       S("", "m", 0.55, ("G3", "A3"), lv=0.95, gap=0.05)], tail=0.15)
    L["hum_2"] = Line([S("", "m", 0.34, "G3", lv=0.85), S("", "m", 0.16, "E3", lv=0.75, gap=0.04),
                       S("", "m", 0.48, "C3", lv=0.85, gap=0.04)], tail=0.15)
    L["hum_3"] = Line([S("", "m", 0.26, "C4"), S("", "m", 0.13, "D4"), S("", "m", 0.13, "C4"), S("", "m", 0.5, "A3")],
                      tail=0.15)
    L["hum_4"] = Line([S("", "m", 0.3, "A2", lv=0.7), S("", "m", 0.45, "D3", lv=1.0, acc=True),
                       S("", "m", 0.3, "A2", lv=0.7)], tail=0.15)
    # --- shaped words -----------------------------------------------------------------------
    L["the_pipes_1"] = Line([S("th", "uh", 0.12, 44, lv=0.6), S("p", "a+i", 0.34, (45, 41), coda="ps", lv=0.85)],
                            mode="spoken", breath=0.35, fry=0.6, jitter=0.02, tail=0.15, pre=[(0.0, "sigh", 1.0)])
    L["the_pipes_2"] = Line([S("th", "uh", 0.14, 42, lv=0.5), S("p", "a+i", 0.46, (43, 38), coda="ps", lv=0.8,
                                                                 gap=0.08)],
                            mode="spoken", breath=0.4, fry=0.8, jitter=0.025, tail=0.15, pre=[(0.0, "sigh", 1.3)])
    L["pardon_1"] = Line([S("p", "ah", 0.24, (45, 46)), S("d", "uh", 0.1, 47, lv=0.8, coda="n"),
                          S("", "n", 0.12, (48, 51), lv=0.6)], mode="spoken", tail=0.12)
    L["pardon_2"] = Line([S("p", "ah", 0.34, (46, 49), lv=1.0), S("d", "o", 0.26, (47, 43), coda="n", lv=0.9)],
                         mode="spoken", tail=0.14)
    L["who_squeaked"] = Line([S("h", "u", 0.5, "D4", lv=1.15, acc=True),
                              S("skw", "i", 0.62, ("E4", "F4"), coda="kt", lv=1.2, gap=0.06, acc=True)],
                             mode="shout", drive=2.1, tail=0.18)
    L["wheeze"] = Line([S("h", "i", 0.45, (40, 42), lv=0.15), S("h", "u", 0.4, (40, 37), lv=0.3, gap=0.05),
                        S("h", "i", 0.3, (40, 42), lv=0.12, gap=0.05), S("h", "u", 0.3, (39, 36), lv=0.25, gap=0.04)],
                       mode="spoken", breath=0.9, fry=0.4, tail=0.1)
    L["dizzy_babble"] = Line([S(c, v, 0.13, p, lv=0.9) for c, v, p in
                              (("bl", "a", 48), ("bl", "e", 52), ("w", "a", 47), ("w", "o", 53), ("bl", "i", 50),
                               ("l", "a", 45), ("bl", "u", 51), ("w", "a", 46), ("bl", "e", 49), ("l", "o", 44))],
                             mode="spoken", tail=0.2)
    return L


BELLOWS_LINES = lines_bellows()
SQUEAKY_LINES = [k for k in BELLOWS_LINES if k.startswith(("aria_", "pipe_down_"))]


def bank_of(line_id: str) -> str:
    """'hmph_2' → 'hmph', 'aria_3' → 'aria', 'crack_1' → 'warmup_crack', 'lecture_b' → 'lecture',
    single files (sneeze_ah1, who_squeaked…) → ''."""
    if line_id.startswith("crack_"):
        return "warmup_crack"
    if line_id.startswith("lecture_"):
        return "lecture"
    if line_id.startswith("sneeze_choo_"):
        return "sneeze_choo"
    head, _, tail = line_id.rpartition("_")
    if tail.isdigit() and head:
        return head
    return ""


def render_line(speaker: str, line_id: str, style: str = "formant", squeaky: bool = False, rng=None) -> np.ndarray:
    spk = SPEAKERS[speaker]
    line = BELLOWS_LINES[line_id]
    rng = rng if rng is not None else np.random.default_rng(zlib.crc32(line_id.encode()))
    if style == "tuba":
        return render_tuba(line, spk, rng)
    if squeaky:
        return render_formant(line, spk, rng, transpose=12.0, tract_mul=1.32)
    return render_formant(line, spk, rng)


# Per-line loudness (loudest 50 ms, phone-weighted dBFS): the sneeze builds, shouts are
# loud, mutters and hums sit under the action. Default = the voice category (−14).
LINE_LEVEL = {"sneeze_ah1": -21.0, "sneeze_ah2": -18.0, "sneeze_ah3": -15.5, "sneeze_choo": -11.5,
              "sneeze_small": -17.0, "hum": -17.0, "the_pipes": -17.0, "wheeze": -17.5, "tut": -17.5, "pff": -17.5,
              "hmph": -15.5, "ahem": -16.0, "huh": -15.0, "pardon": -15.5, "ugh": -15.5, "dizzy_babble": -15.0,
              "pipe_down": -12.5, "wha": -12.5, "who_squeaked": -12.0, "yow": -13.0, "oof": -13.5, "hah": -13.5,
              "lecture": -13.5, "warmup_crack": -13.5}


def line_level(lid: str) -> float | None:
    b = bank_of(lid) or lid
    return LINE_LEVEL.get(b, LINE_LEVEL.get(lid))


def _register() -> None:
    for lid, line in BELLOWS_LINES.items():
        b = bank_of(lid)
        lvl = line_level(lid)
        dur = sum(s.d + s.gap for s in line.syls) + line.tail + 0.2
        cap = round(max(0.5, dur + 0.3), 2)
        for style, prefix in (("formant", "vo_bellows_"), ("tuba", "vo_bellows_tuba_")):
            def _mk(lid=lid, style=style, prefix=prefix, b=b, cap=cap, lvl=lvl):
                @sfx(prefix + lid, cat="voice", max_dur=cap, bank=(prefix + b) if b else "", level=lvl,
                     desc=f"Bellows ({style}): {lid.replace('_', ' ')}", tags=("voice", style))
                def _f(rng):
                    return render_line("bellows", lid, style, rng=rng)
            _mk()
        if lid in SQUEAKY_LINES:
            def _mk2(lid=lid, b=b, cap=cap, lvl=lvl):
                @sfx("vo_bellows_squeaky_" + lid, cat="voice", max_dur=cap, bank="vo_bellows_squeaky_" + b, level=lvl,
                     desc=f"Bellows SQUEAKY (+12 st): {lid.replace('_', ' ')}", tags=("voice", "squeaky"))
                def _f(rng):
                    return render_line("bellows", lid, "formant", squeaky=True, rng=rng)
            _mk2()


_register()
