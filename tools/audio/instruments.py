"""The pit orchestra: piano, pizzicato, bowed/tremolo strings, clarinet, bassoon, flute,
tuba, trombone, trumpet, horn, timpani, woodblock, celesta, harp, xylophone, glockenspiel,
triangle, slide whistle, kazoo and the drum kit.

Every function returns a mono float array at synth.SR whose length is the note plus its
release/ring. Pitches are Hz (use synth.midi()). Instruments are physically *inspired*
(modal strings and bars, formant-ish reeds, loudness-dependent brass brightness) and
tuned for small phone speakers: fundamentals are backed by a little 2nd/3rd harmonic.
"""
from __future__ import annotations

import math

import numpy as np

from synth import (SR, TAU, NYQ, additive, adsr, arr, brass, burst, clap, cymbal, drive, env_lin, filt,
                   hat, kazoo as _kazoo, kick, mallet, midi, noise_sweep, ns, perc, phase_of, piano as _piano,
                   pluck, rim, saw, sine, smooth_noise, snare, square, tom, tri, tt, white)

__all__ = [
    "piano", "pizz", "bowed", "clarinet", "bassoon", "flute", "tuba", "trombone", "trumpet", "horn",
    "timpani", "timp_roll", "woodblock", "celesta", "harp", "xylo", "glock", "triangle", "slide_whistle",
    "kazoo", "bass_drum", "snare", "cymbal", "rim", "hat", "clap", "tom", "kick", "seq", "midi",
]


def _rng(rng, salt: float) -> np.random.Generator:
    return rng if rng is not None else np.random.default_rng(int(abs(salt) * 1000) & 0xFFFFFFFF)


def _ramp(t: np.ndarray, start: float, length: float) -> np.ndarray:
    return np.clip((t - start) / max(length, 1e-4), 0.0, 1.0)


# ----------------------------------------------------------------------------- keyboards

def piano(f: float, dur: float, vel: float = 0.8, rng=None, release: float = 0.12) -> np.ndarray:
    """Additive upright piano (three detuned strings, hammer noise)."""
    return _piano(f, dur, vel, _rng(rng, f), release)


def celesta(f: float, dur: float = 1.2, vel: float = 0.8, rng=None) -> np.ndarray:
    """Celesta: struck steel bars over wooden resonators — pure, bell-like, soft attack."""
    n = ns(dur + 0.4)
    t = tt(n)
    y = np.zeros(n)
    for r, a, d in ((1.0, 1.0, 1.1), (2.0, 0.18, 0.5), (4.0, 0.22, 0.25), (9.8, 0.05, 0.06)):
        fr = f * r
        if fr < NYQ * 0.95:
            y += a * np.sin(TAU * fr * t) * np.exp(-6.9 * t / (d * (1.0 + dur * 0.3)))
    click = burst(min(n, ns(0.004)), _rng(rng, f), 2000, 8000, 0.0002, 0.002)
    y[: len(click)] += click * 0.08
    atk = min(n, ns(0.003))
    y[:atk] *= np.linspace(0, 1, atk)
    return y * vel


def glock(f: float, dur: float = 1.0, vel: float = 0.8, rng=None) -> np.ndarray:
    return mallet(f, max(dur, 0.6) + 0.4, (1.0, 2.76, 5.4), (1.0, 0.4, 0.15), (1.1, 0.5, 0.2), 0.3, _rng(rng, f)) * vel


def xylo(f: float, dur: float = 0.5, vel: float = 0.8, rng=None) -> np.ndarray:
    return mallet(f, 0.6, (1.0, 3.0, 6.0), (1.0, 0.35, 0.12), (0.45, 0.12, 0.05), 0.8, _rng(rng, f)) * vel


def harp(f: float, dur: float = 1.2, vel: float = 0.8, rng=None) -> np.ndarray:
    """Concert harp: gut string plucked near the middle, long warm ring."""
    return pluck(f, dur + 0.6, bright=0.3, decay=1.6 * (262.0 / f) ** 0.25, pos=0.3, rng=_rng(rng, f),
                 body=False) * vel


# ----------------------------------------------------------------------------- strings

def pizz(f: float, dur: float = 0.45, vel: float = 0.8, rng=None, bright: float = 0.42,
         ring: float | None = None) -> np.ndarray:
    """Pizzicato string: a finger pluck (soft 'thup' onset), fast decay, violin/cello body."""
    rng = _rng(rng, f)
    ring = ring if ring is not None else 0.2 + 0.45 * (196.0 / f) ** 0.5
    x = pluck(f, dur + 0.25, bright=bright, decay=ring, pos=0.14, rng=rng, body=False)
    body_f = 290.0 if f > 180 else 105.0
    x = filt(x, ("peak", body_f, 1.3, 5.0), ("peak", body_f * 1.62, 1.6, 3.0), ("peak", 2700, 1.0, 1.5),
             ("hp", 55.0, 0.7))
    n = len(x)
    t = tt(n)
    thup = np.sin(TAU * phase_of(f * (1.0 + 0.35 * np.exp(-t / 0.006)), n)) * perc(n, 0.0006, 0.035)
    return (x / (np.max(np.abs(x)) + 1e-9) + 0.25 * thup) * vel


def bowed(f, dur: float, vel: float = 0.7, rng=None, vib: float = 0.011, trem_hz: float = 0.0,
          attack: float = 0.08, release: float = 0.18, section: int = 3, bright: float = 0.7,
          pont: float = 0.0) -> np.ndarray:
    """Bowed string section: detuned saws, body resonances, bow noise; tremolo optional.

    f may be a scalar or an array (glissando). pont > 0 adds a glassy sul-ponticello edge.
    """
    rng = _rng(rng, float(np.mean(f)) + dur)
    n = ns(dur + release)
    t = tt(n)
    base = arr(f, n)
    out = np.zeros(n)
    for k in range(section):
        det = 2.0 ** (rng.uniform(-8, 8) / 1200.0)
        rate = 5.2 + 0.5 * k + rng.uniform(-0.2, 0.2)
        fv = base * det * (1.0 + vib * np.sin(TAU * rate * t + rng.uniform(0, TAU)) * _ramp(t, 0.1, 0.25))
        out += saw(fv, n, rng.uniform(0, 1))
    out /= section
    lp_hz = 2200.0 + 3800.0 * bright
    out = filt(out, ("lp", lp_hz, 0.6), ("peak", 460, 1.1, 4.0), ("peak", 2800, 1.0, 3.0 + 4.0 * pont),
               ("hp", 110.0 if float(np.mean(base)) > 150 else 45.0, 0.7))
    env = adsr(n, attack, 0.12, 0.85, release, hold=dur)
    if trem_hz > 0:
        ph = phase_of(trem_hz * (1.0 + 0.04 * smooth_noise(n, 3, rng)), n)
        am = 0.3 + 0.7 * np.abs(np.sin(math.pi * ph)) ** 0.5
        out *= am
    bow = filt(white(n, rng), ("bp", 2600, 0.8)) * (0.02 + 0.04 * pont)
    if trem_hz > 0:
        bow *= 1.0 + 1.5 * (np.abs(np.cos(math.pi * phase_of(trem_hz, n))) ** 8)
    return (out + bow) * env * vel


# ----------------------------------------------------------------------------- woodwinds

def clarinet(f, dur: float, vel: float = 0.8, rng=None, release: float = 0.07, vib: float = 0.0035,
             attack: float = 0.025) -> np.ndarray:
    """Clarinet: odd-harmonic reed tone, brightness with velocity, a breath of air."""
    rng = _rng(rng, float(np.mean(f)))
    n = ns(dur + release)
    t = tt(n)
    base = arr(f, n)
    fv = base * (1.0 + vib * np.sin(TAU * 5.1 * t) * _ramp(t, 0.18, 0.2))
    f0 = float(np.mean(base))
    cutoff = 1300.0 + 1900.0 * vel
    amps = []
    for k in range(1, 26):
        a = (1.0 / k) if k % 2 else (0.1 / k)
        amps.append(a / (1.0 + (k * f0 / cutoff) ** 2.2))
    y = additive(fv, n, amps)
    y += filt(white(n, rng), ("bp", 1800, 0.7)) * 0.012
    env = adsr(n, attack, 0.06, 0.9, release, hold=dur)
    return y * env * vel


def bassoon(f, dur: float, vel: float = 0.8, rng=None, release: float = 0.06, attack: float = 0.03,
            vib: float = 0.004) -> np.ndarray:
    """Bassoon: a reedy, nasal double reed — the orchestra's comedian."""
    rng = _rng(rng, float(np.mean(f)))
    n = ns(dur + release)
    t = tt(n)
    base = arr(f, n)
    fv = base * (1.0 + vib * np.sin(TAU * 5.0 * t) * _ramp(t, 0.2, 0.2))
    y = saw(fv, n) * 0.8 + square(fv, n, 0.42) * 0.3
    y = filt(y, ("peak", 470, 2.2, 11.0), ("peak", 1180, 2.8, 6.0), ("peak", 2600, 3.0, 2.0),
             ("lp", 3600, 0.7), ("hp", 45, 0.7))
    y += filt(white(n, rng), ("bp", 1200, 1.0)) * 0.01
    env = adsr(n, attack, 0.05, 0.88, release, hold=dur)
    return y / (np.max(np.abs(y)) + 1e-9) * env * vel


def flute(f, dur: float, vel: float = 0.8, rng=None, release: float = 0.08, piccolo: bool = False) -> np.ndarray:
    """Flute / piccolo: near-sine with a breathy chiff and a gentle vibrato."""
    rng = _rng(rng, float(np.mean(f)))
    n = ns(dur + release)
    t = tt(n)
    base = arr(f, n)
    fv = base * (1.0 + 0.007 * np.sin(TAU * 5.4 * t) * _ramp(t, 0.15, 0.2))
    y = sine(fv, n) + 0.22 * sine(2 * fv, n) + 0.07 * sine(3 * fv, n)
    air = filt(white(n, rng), ("bp", float(np.mean(base)) * 2.0, 1.5)) * 0.08
    chiff = burst(n, rng, 1500, 7000, 0.001, 0.025) * 0.15
    env = adsr(n, 0.035 if not piccolo else 0.02, 0.05, 0.9, release, hold=dur)
    return (y + air + chiff) * env * vel


# ----------------------------------------------------------------------------- brass

def tuba(f, dur: float, vel: float = 0.9, rng=None, release: float = 0.07) -> np.ndarray:
    """Tuba: round, buzzy oom on the bass; a touch of saturation so phones hear it."""
    x = brass(f, dur, vel, vib=0.0, bright=0.55, attack=0.014, release=release, rng=_rng(rng, float(np.mean(f))))
    return drive(x / (np.max(np.abs(x)) + 1e-9) * 1.25, 1.5) * vel


def trombone(f, dur: float, vel: float = 0.9, rng=None, release: float = 0.08, wah=None,
             vib: float = 0.008) -> np.ndarray:
    return brass(f, dur, vel, vib=vib, bright=0.9, attack=0.03, release=release,
                 rng=_rng(rng, float(np.mean(f))), wah=wah)


def trumpet(f, dur: float, vel: float = 0.9, rng=None, release: float = 0.07, vib: float = 0.012) -> np.ndarray:
    return brass(f, dur, vel, vib=vib, bright=1.15, attack=0.018, release=release, rng=_rng(rng, float(np.mean(f))))


def horn(f, dur: float, vel: float = 0.7, rng=None, release: float = 0.12) -> np.ndarray:
    x = brass(f, dur, vel, vib=0.004, bright=0.45, attack=0.05, release=release, rng=_rng(rng, float(np.mean(f))))
    return filt(x, ("lp", 2200, 0.7))


# ----------------------------------------------------------------------------- percussion

TIMP_MODES = ((1.0, 1.0, 1.25), (1.504, 0.55, 0.9), (1.742, 0.38, 0.7), (2.0, 0.26, 0.55),
              (2.245, 0.18, 0.45), (2.494, 0.12, 0.35), (2.8, 0.07, 0.25))


def timpani(f: float, dur: float = 1.6, vel: float = 0.9, rng=None, damp: float = 1.0) -> np.ndarray:
    """Kettle drum: membrane modes with a small pitch drop and a felt-mallet thump."""
    rng = _rng(rng, f + vel)
    n = ns(dur)
    t = tt(n)
    glide = 1.0 + 0.025 * vel * np.exp(-t / 0.06)
    y = np.zeros(n)
    for r, a, d in TIMP_MODES:
        fr = f * r
        if fr < NYQ * 0.9:
            y += a * np.sin(TAU * phase_of(fr * glide, n) + rng.uniform(0, TAU)) * np.exp(-6.9 * t / (d * damp))
    thump = filt(white(n, rng), ("lp", 900, 0.7)) * perc(n, 0.001, 0.05)
    y = y / (np.max(np.abs(y)) + 1e-9) + 0.35 * thump / (np.max(np.abs(thump)) + 1e-9)
    atk = min(n, ns(0.002))
    y[:atk] *= np.linspace(0.0, 1.0, atk)
    return drive(y * vel, 1.2)


def timp_roll(f: float, dur: float, v0: float = 0.2, v1: float = 1.0, rng=None, rate: float = 16.0,
              accent: bool = True) -> np.ndarray:
    """Timpani roll: alternating strokes ~16/s, crescendo v0 → v1, optional final accent."""
    rng = _rng(rng, f + dur)
    n = ns(dur + 1.4)
    y = np.zeros(n)
    tpos = 0.0
    k = 0
    while tpos < dur:
        v = v0 + (v1 - v0) * (tpos / max(dur, 1e-3)) ** 1.3
        hit = timpani(f, 0.6, v * rng.uniform(0.85, 1.0) * (1.0 if k % 2 else 0.92), rng, damp=0.6)
        i = ns(tpos)
        m = min(len(hit), n - i)
        y[i:i + m] += hit[:m] * 0.55
        tpos += (1.0 / rate) * rng.uniform(0.9, 1.1)
        k += 1
    if accent:
        hit = timpani(f, 1.4, v1, rng)
        i = ns(dur)
        m = min(len(hit), n - i)
        y[i:i + m] += hit[:m]
    return y


def woodblock(f: float = 880.0, vel: float = 0.9, rng=None, dur: float = 0.2) -> np.ndarray:
    """Woodblock / temple block 'tok': a hollow two-mode resonance and a sharp click."""
    rng = _rng(rng, f)
    n = ns(dur)
    t = tt(n)
    bend = 1.0 + 0.04 * np.exp(-t / 0.004)
    y = np.sin(TAU * phase_of(f * bend, n)) * np.exp(-t / 0.038)
    y += 0.42 * np.sin(TAU * phase_of(f * 2.61 * bend, n)) * np.exp(-t / 0.014)
    y += 0.18 * np.sin(TAU * f * 4.12 * t) * np.exp(-t / 0.007)
    y += burst(n, rng, 1500, 9000, 0.0001, 0.003) * 0.55
    return y * vel


def triangle(dur: float = 1.5, vel: float = 0.6, rng=None) -> np.ndarray:
    n = ns(dur)
    t = tt(n)
    y = np.zeros(n)
    for r, a, d in ((1.0, 1.0, 1.4), (2.71, 0.7, 1.1), (5.12, 0.5, 0.8), (7.9, 0.35, 0.6), (10.6, 0.2, 0.4)):
        y += a * np.sin(TAU * 1180 * r * t) * np.exp(-6.9 * t / d)
    y += burst(n, _rng(rng, 7), 4000, 10000, 0.0001, 0.003) * 0.3
    return y * vel


def bass_drum(dur: float = 0.8, vel: float = 0.9, rng=None) -> np.ndarray:
    """Orchestral bass drum: a big soft boom."""
    rng = _rng(rng, 3)
    n = ns(dur)
    t = tt(n)
    f = 48 + 40 * np.exp(-t / 0.04)
    y = np.sin(TAU * phase_of(f, n)) * perc(n, 0.002, dur)
    y += filt(white(n, rng), ("lp", 300, 0.7)) * perc(n, 0.001, 0.08) * 0.4
    return drive(y * vel, 1.8)


# ----------------------------------------------------------------------------- toys

def slide_whistle(f_curve, dur: float, vel: float = 0.8, rng=None) -> np.ndarray:
    """Slide whistle on an arbitrary pitch curve (array in Hz or (f_from, f_to))."""
    rng = _rng(rng, dur)
    n = ns(dur)
    t = tt(n)
    if isinstance(f_curve, tuple):
        x = np.linspace(0, 1, n)
        shape = 0.5 - 0.5 * np.cos(math.pi * np.clip(x * 1.06, 0, 1))
        f = f_curve[0] * (f_curve[1] / f_curve[0]) ** shape
    else:
        f = arr(f_curve, n)
    f = f * (1.0 + 0.012 * np.sin(TAU * 6.5 * t))
    tone = np.sin(TAU * phase_of(f, n)) + 0.12 * np.sin(TAU * phase_of(2 * f, n))
    breath = noise_sweep(n, rng, f, 0.4) * 0.12
    e = env_lin([(0, 0), (0.012, 1), (dur * 0.85, 0.9), (dur, 0)], n)
    return (tone + breath) * e * vel


def kazoo(f, dur: float, vel: float = 0.9, rng=None, vowel: str = "u") -> np.ndarray:
    return _kazoo(f, dur, vel, _rng(rng, float(np.mean(f))), vowel)


# ----------------------------------------------------------------------------- helpers

def seq(notes, voice_fn, total: float | None = None) -> np.ndarray:
    """notes: [(start_s, dur_s, midi_or_hz, vel), ...] → one buffer (midi when < 128)."""
    from synth import place
    evs = []
    for s, d, p, v in notes:
        fr = midi(p) if p < 128 else p
        evs.append((s, voice_fn(fr, d, v), 1.0))
    return place(evs, total)
