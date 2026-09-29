"""The Stalls: a formant-synthesised theatre audience (GDD §6.5) and its fallback.

Laughter is built from individual laughers — each with its own voice (men / women /
children), laugh style (giggle, chuckle, cackle, guffaw, snort, wheezy), rate, pitch fall
across the bout, aspirated 'h' onsets and an inhale gasp between bouts — mixed into a
theatre room with a murmur bed. Tiers, all with ≥ 3 variants:

  crowd_t0  titter   2–3 voices, 0.6 s, quiet (−18 dB)
  crowd_t1  chuckle  5–6 voices, 1.2 s
  crowd_t2  laugh    12–14 voices + one standout "HA!", 2 s
  crowd_t3  laugh + applause, 20+ voices, 3 s
  crowd_t4  roar + whistles + stomps + applause, 4.5 s

Specials: ooh, gasp, aww, shh, behind_you (chanted), chant ("PIPE-DOWN!" ×2), bow_chant,
boo (playful), relief, cheer. The fallback set `crowd_fb_*` (applause, whistles, 'ooh', a
kazoo "ha-ha" choir) covers the laughter tiers, the laugh-like specials and — so every crowd
sound of the Gate-0 scene exists in both styles — BEHIND YOU! (a kazoo choir blaring the
rhythm) and the gasp; the autoload falls back to the formant file for kinds the fallback
doesn't re-voice (shh, the chants), which contain no laughter.
"""
from __future__ import annotations

import math

import numpy as np

import instruments as I
import voices as V
from registry import sfx
from sfx_foley import thump
from synth import (SR, TAU, env_lin, filt, midi, noise_sweep, norm, ns, pad, perc, phase_of, pink, place, reverb,
                   smooth_noise, tt, vowel_track, voice, white)

ROOM_RT = 1.1    # a small theatre
ROOM_WET = 0.28


# ----------------------------------------------------------------------------- people

def person(rng, kind: str | None = None) -> dict:
    """A random audience member: laughing f0 (Hz — laughter sits well above speech),
    vocal-tract scale, and a laugh style."""
    r = rng.random()
    who = kind or ("man" if r < 0.45 else "woman" if r < 0.9 else "child")
    if who == "man":
        f0, tract = rng.uniform(165, 265), rng.uniform(0.94, 1.05)
    elif who == "woman":
        f0, tract = rng.uniform(270, 420), rng.uniform(1.1, 1.22)
    else:
        f0, tract = rng.uniform(380, 520), rng.uniform(1.28, 1.4)
    style = rng.choice(["giggle", "chuckle", "cackle", "guffaw", "snort", "wheezy", "ha"],
                       p=[0.14, 0.2, 0.12, 0.14, 0.08, 0.08, 0.24])
    return {"who": who, "f0": f0, "tract": tract, "style": str(style)}


STYLE = {  # rate (syllables/s), vowel, voiced share of each syllable, breath, pitch lift, level
    "giggle": (6.8, "i", 0.5, 0.55, 1.12, 0.75),
    "chuckle": (4.6, "uh", 0.55, 0.6, 0.85, 0.7),
    "cackle": (6.0, "a", 0.62, 0.45, 1.1, 0.9),
    "guffaw": (4.2, "aw", 0.7, 0.45, 0.85, 1.0),
    "snort": (5.0, "n", 0.45, 0.65, 0.9, 0.75),
    "wheezy": (5.4, "e", 0.3, 1.1, 1.0, 0.65),
    "ha": (5.0, "a", 0.6, 0.5, 1.0, 0.9),
}


def laugher(rng, n: int, start: float, p: dict, bout_s: float, level: float = 1.0, energy: float = 1.0,
            rate_hint: float | None = None) -> np.ndarray:
    """One person laughing from `start` for about `bout_s` seconds: bouts of aspirated
    'ha' syllables (pitch and level falling through the bout) separated by inhales."""
    rate, vow, voiced, br, lift, lv0 = STYLE[p["style"]]
    if rate_hint is not None:
        rate = 0.6 * rate + 0.4 * rate_hint      # early on, a crowd laughs roughly together
    rate *= rng.uniform(0.94, 1.06) * (0.92 + 0.12 * energy)
    f0b = p["f0"] * lift
    sylls, f_pts, v_pts, b_pts = [], [], [], []
    t = start
    end = min(start + bout_s, n / SR - 0.08)
    bout = 0
    while t < end:
        count = int(rng.integers(4, 9)) if bout == 0 else int(rng.integers(2, 6))
        for k in range(count):
            if t >= end:
                break
            d = 1.0 / rate * rng.uniform(0.9, 1.1)
            asp = d * (1 - voiced)
            von = t + asp
            fall = (1.0 - 0.07 * k) * (0.8 if bout else 1.0)
            lv = level * lv0 * fall * rng.uniform(0.85, 1.1)
            sylls.append((von, t + d * 0.88, lv))
            fk = f0b * (1.08 - 0.04 * k) * (0.92 if bout else 1.0) * 2 ** (rng.uniform(-1.0, 1.0) / 12)
            f_pts += [(von, fk), (von + (t + d - von) * 0.3, fk * 1.03), (t + d * 0.86, fk * 0.9)]
            b_pts.append((t, von + 0.015, lv * br))
            v_pts += [(t, vow), (t + d, vow)]
            t += d
        bout += 1
        if t < end - 0.25:
            gd = rng.uniform(0.12, 0.2)          # the inhale between bouts
            b_pts.append((t + 0.01, t + gd, level * 0.45 * br))
            v_pts += [(t, "i"), (t + gd, "i")]
            f_pts += [(t, f0b * 1.3), (t + gd, f0b * 1.45)]
            t += gd + rng.uniform(0.02, 0.06)
    if not sylls:
        return np.zeros(n)
    tx = tt(n)
    amp = np.zeros(n)
    for a, b, lv in sylls:
        seg = np.clip((tx - a) / 0.008, 0, 1) * np.clip((b - tx) / 0.035, 0, 1) * lv
        amp = np.maximum(amp, seg * (1.0 - 0.35 * np.clip((tx - a) / max(b - a, 1e-3), 0, 1)))
    bamp = np.zeros(n)
    for a, b, lv in b_pts:
        bamp = np.maximum(bamp, np.clip((tx - a) / 0.006, 0, 1) * np.clip((b - tx) / 0.02, 0, 1) * lv)
    f_pts.sort()
    f0 = np.interp(tx, [q[0] for q in f_pts], [q[1] for q in f_pts])
    v_pts.sort(key=lambda q: q[0])
    forms = np.zeros((4, n))
    for j in range(4):
        forms[j] = np.interp(tx, [q[0] for q in v_pts], [V.VOWELS[q[1]][j] * p["tract"] for q in v_pts])
    nasal = 0.6 if p["style"] == "snort" else 0.0
    return voice(f0, forms, amp, breath=0.6, tilt=1.1, rng=rng, jitter=0.02, max_hz=6000, nasal=nasal,
                 breath_amp=np.maximum(bamp, amp * 0.35))


def murmur(rng, n: int, level: float = 1.0) -> np.ndarray:
    return filt(pink(n, rng), ("bp", 750, 0.7)) * (0.55 + 0.45 * smooth_noise(n, 7, rng)) * level


def room(x: np.ndarray, wet: float = ROOM_WET) -> np.ndarray:
    y = reverb(x, wet, ROOM_RT, tone=4200, keep_len=True)
    return filt(y, ("lp", 7500, 0.7), ("hp", 110, 0.7))


def laugh_crowd(rng, dur: float, voices_n: int, spread: float, energy: float, swell, bout=(0.5, 1.0),
                front: int = 2) -> np.ndarray:
    """A crowd bursting out laughing together: most start within ~0.1 s of the cue,
    a few stragglers later; `front` laughers are closer and clearer than the rest."""
    n = ns(dur)
    y = np.zeros(n)
    hint = rng.uniform(4.6, 5.4)
    for i in range(voices_n):
        p = person(rng)
        st = rng.exponential(0.05) if rng.random() < 0.8 else rng.uniform(0.1, max(0.12, spread))
        b = dur * rng.uniform(*bout) - st
        g = (1.5 if i < front else rng.uniform(0.45, 0.9))
        y += laugher(rng, n, st, p, max(0.25, b), g, energy, hint)
    y = norm(y) + norm(murmur(rng, n)) * 0.05
    return y * env_lin(swell, n)


# ----------------------------------------------------------------------------- applause, whistles, stomps, whoops

def applause(rng, dur: float, people: int = 24, rate=(3.6, 5.2), swell=None) -> np.ndarray:
    n = ns(dur)
    y = np.zeros(n)
    cn = ns(0.03)
    for _ in range(people):
        r = rng.uniform(*rate)
        fc = rng.uniform(900, 2600)
        q = rng.uniform(1.0, 1.8)
        base = filt(white(cn, rng), ("bp", fc, q)) * perc(cn, 0.0005, 0.02)
        base = norm(base)
        t = rng.uniform(0, 0.25)
        g = rng.uniform(0.4, 1.0)
        stop = dur * rng.uniform(0.75, 1.0)
        while t < stop:
            i = ns(t)
            k = min(cn, n - i)
            if k > 0:
                y[i:i + k] += base[:k] * g * rng.uniform(0.6, 1.0)
            t += 1.0 / r * rng.uniform(0.9, 1.1)
    e = env_lin(swell or [(0, 0.4), (0.15, 1.0), (dur * 0.75, 0.85), (dur, 0.0)], n)
    return y * e


def whistle(rng, dur: float = 0.8, f: float | None = None) -> np.ndarray:
    """A finger whistle: wheeet-wooo."""
    f = f or rng.uniform(2200, 3000)
    n = ns(dur)
    t = tt(n)
    fc = env_lin([(0, f * 0.8), (0.12, f * 1.12), (dur * 0.55, f * 1.1), (dur, f * 0.72)], n)
    fc = fc * (1 + 0.006 * np.sin(TAU * 6 * t))
    y = np.sin(TAU * phase_of(fc, n)) + 0.1 * np.sin(TAU * phase_of(2 * fc, n))
    y += filt(white(n, rng), ("bp", f, 4.0)) * 0.25
    return y * env_lin([(0, 0), (0.03, 1), (dur * 0.85, 0.8), (dur, 0)], n)


def stomps(rng, dur: float, rate: float = 2.3, feet: int = 10) -> np.ndarray:
    n = ns(dur)
    y = np.zeros(n)
    t = 0.2
    k = 0
    while t < dur - 0.2:
        for _ in range(feet):
            s = t + rng.normal(0, 0.018)
            th = thump(0.2, rng.uniform(95, 140), rng.uniform(45, 60)) * rng.uniform(0.4, 1.0)
            i = ns(max(0.0, s))
            m_ = min(len(th), n - i)
            if m_ > 0:
                y[i:i + m_] += th[:m_]
        t += 1.0 / rate
        k += 1
    return y


def shout_line(rng, line: V.Line, count: int, spread: float = 0.03, dur: float | None = None) -> np.ndarray:
    """Many audience members shouting the same shaped line (a chant)."""
    parts = []
    for i in range(count):
        p = person(rng, "man" if i % 5 in (0, 2) else "woman" if i % 5 in (1, 3) else "child")
        tp = {"man": rng.uniform(-2, 2), "woman": rng.uniform(8, 11), "child": rng.uniform(13, 16)}[p["who"]]
        spk = V.Speaker("crowd", tract=p["tract"], vib_cents=0.0, ring_db=2.0, chest_db=0.0, room=0.0, max_hz=6000)
        y = V.render_formant(line, spk, rng, transpose=tp)
        parts.append((max(0.0, rng.normal(0.02, spread)), norm(y) * rng.uniform(0.6, 1.0)))
    y = place(parts, dur)
    return y


# ----------------------------------------------------------------------------- tiers

TIERS = {  # kind: (voices, dur, level dB, spread of starts, energy)
    "t0": ((2, 3), 0.6, -18.0, 0.08, 0.6),
    "t1": ((5, 6), 1.2, -16.0, 0.15, 0.8),
    "t2": ((12, 14), 2.0, -14.5, 0.25, 1.0),
    "t3": ((20, 24), 3.0, -13.5, 0.3, 1.15),
    "t4": ((28, 32), 4.0, -12.5, 0.35, 1.3),
}


def tier(rng, kind: str) -> np.ndarray:
    (lo, hi), dur, _, spread, energy = TIERS[kind]
    nv = int(rng.integers(lo, hi + 1))
    if kind == "t0":
        y = laugh_crowd(rng, dur, nv, spread, energy, [(0, 0.7), (0.03, 1.0), (0.4, 0.7), (dur, 0.0)], (0.6, 0.9), 1)
        return room(y, 0.16)
    if kind == "t1":
        y = laugh_crowd(rng, dur, nv, spread, energy, [(0, 0.6), (0.04, 1.0), (0.8, 0.7), (dur, 0.0)], (0.6, 0.95), 2)
        return room(y)
    if kind == "t2":
        y = laugh_crowd(rng, dur, nv, spread, energy, [(0, 0.6), (0.05, 1.0), (1.2, 0.8), (dur, 0.0)], front=3)
        return room(norm(y) + pad(norm(_ha(rng)), len(y)) * 0.5)
    if kind == "t3":
        n = ns(dur)
        y = laugh_crowd(rng, dur, nv, spread, energy, [(0, 0.6), (0.05, 1.0), (2.0, 0.8), (dur, 0.0)], (0.6, 1.0), 3)
        y = norm(y) + pad(norm(_ha(rng)), len(y)) * 0.4
        clap = applause(rng, dur, 26, swell=[(0, 0.0), (0.6, 0.3), (1.2, 1.0), (2.6, 0.8), (dur, 0.0)])
        return room(norm(y) + norm(clap) * 0.45 + norm(murmur(rng, n)) * 0.05)
    # t4: the roar
    n = ns(dur)
    y = laugh_crowd(rng, dur, nv, spread, energy, [(0, 0.6), (0.06, 1.0), (2.9, 0.85), (dur, 0.0)], (0.7, 1.0), 4)
    clap = applause(rng, dur, 34, (4.0, 5.6), [(0, 0.2), (0.8, 1.0), (3.4, 0.9), (dur, 0.0)])
    st = stomps(rng, dur * 0.8)
    wh = place([(rng.uniform(0.6, 1.1), whistle(rng, 0.8)), (rng.uniform(1.5, 2.1), whistle(rng, 0.7)),
                (rng.uniform(2.4, 2.9), whistle(rng, 0.8))], dur)
    whoops = place([(rng.uniform(0.3, 2.7), _whoop(rng), 1.0) for _ in range(3)], dur)
    return room(norm(y) + norm(clap) * 0.5 + pad(norm(st), n) * 0.35 + pad(wh, n) * 0.3 + pad(norm(whoops), n) * 0.25)


def _ha(rng) -> np.ndarray:
    """The one standout audience member: a big single 'HA!' just after the laugh starts."""
    p = person(rng, "man")
    line = V.Line([V.S("h", "a", 0.24, (V.hz2m(p["f0"]) + 2.0, V.hz2m(p["f0"]) - 2.0), lv=1.2)], mode="shout",
                  drive=1.3, tail=0.08)
    spk = V.Speaker("crowd", tract=p["tract"], vib_cents=0.0, ring_db=2.0, chest_db=0.0, room=0.0, max_hz=6000)
    y = V.render_formant(line, spk, rng)
    return np.concatenate([np.zeros(ns(rng.uniform(0.18, 0.3))), y])


def _whoop(rng) -> np.ndarray:
    p = person(rng, "man" if rng.random() < 0.6 else "woman")
    tp = 0.0 if p["who"] == "man" else 9.0
    line = V.Line([V.S("w", "u", 0.4, (52 + tp, 60 + tp), lv=1.1)], mode="shout", drive=1.4, tail=0.1)
    spk = V.Speaker("crowd", tract=p["tract"], vib_cents=0.0, ring_db=2.0, chest_db=0.0, room=0.0, max_hz=6000)
    return V.render_formant(line, spk, rng)


for _kind, (_v, _dur, _lvl, _s, _e) in TIERS.items():
    for _i in (1, 2, 3):
        def _mk(kind=_kind, i=_i, dur=_dur, lvl=_lvl):
            @sfx(f"crowd_{kind}_{i}", cat="crowd", max_dur=dur + 0.4, level=lvl, bank=f"crowd_{kind}",
                 desc=f"the Stalls: {kind} laugh, variant {i}", tags=("crowd", "formant"))
            def _f(rng):
                return tier(rng, kind)
        _mk()


# ----------------------------------------------------------------------------- specials

def ooh(rng, dur=0.95) -> np.ndarray:
    n = ns(dur)
    y = np.zeros(n)
    for i in range(16):
        p = person(rng, "man" if i % 2 == 0 else "woman")
        f0 = p["f0"] * 0.95
        s = rng.uniform(0, 0.08)
        contour = env_lin([(0, 0.9), (s + 0.1, 1.0), (0.45, 1.14), (0.75, 1.02), (dur, 0.86)], n)
        forms = vowel_track([(0, "u"), (0.35, "o"), (0.7, "u"), (dur, "u")], n, p["tract"])
        amp = env_lin([(0, 0), (s + 0.06, 0.8), (0.45, 1.0), (0.8, 0.6), (dur, 0)], n)
        y += voice(f0 * contour, forms, amp, breath=0.2, tilt=1.4, rng=rng, jitter=0.012, max_hz=4000)
    return room(norm(y) + norm(murmur(rng, n)) * 0.06)


def gasp(rng, dur=0.55) -> np.ndarray:
    n = ns(dur)
    y = np.zeros(n)
    for i in range(18):
        p = person(rng)
        s = rng.uniform(0.0, 0.06)
        m_ = ns(0.28)
        tx = tt(m_)
        forms = vowel_track([(0, "a"), (0.28, "ah")], m_, p["tract"])
        amp = env_lin([(0, 0), (0.03, 0.35), (0.12, 0.5), (0.28, 0)], m_)
        f0 = p["f0"] * 1.25 * (1 + 0.15 * tx / 0.28)
        g = voice(f0, forms, amp * 0.5, breath=1.2, tilt=1.2, rng=rng, jitter=0.02, max_hz=5000,
                  breath_amp=env_lin([(0, 0), (0.02, 1.0), (0.2, 0.6), (0.28, 0)], m_))
        i0 = ns(s)
        y[i0:i0 + m_] += g[: n - i0]
    return room(y, 0.22)


def aww(rng, dur=1.05) -> np.ndarray:
    n = ns(dur)
    y = np.zeros(n)
    for i in range(16):
        p = person(rng, "man" if i % 2 == 0 else "woman")
        s = rng.uniform(0, 0.06)
        contour = env_lin([(0, 1.12), (s + 0.12, 1.15), (0.6, 0.98), (dur, 0.85)], n)
        forms = vowel_track([(0, "aw"), (0.5, "aw"), (dur, "o")], n, p["tract"])
        amp = env_lin([(0, 0), (s + 0.08, 1.0), (0.6, 0.8), (dur, 0)], n)
        y += voice(p["f0"] * contour, forms, amp, breath=0.25, tilt=1.3, rng=rng, jitter=0.012, max_hz=4000)
    return room(norm(y))


def shh(rng, dur=0.95) -> np.ndarray:
    n = ns(dur)
    y = np.zeros(n)
    for i in range(7):
        s = rng.uniform(0.0, 0.3)
        d = rng.uniform(0.35, 0.6)
        m_ = ns(d)
        fc = rng.uniform(2300, 3400)
        x = filt(white(m_, rng), ("bp", fc, 1.3), ("peak", fc * 1.7, 1.5, 4))
        x = norm(x) * env_lin([(0, 0), (0.05, 1), (d * 0.7, 0.8), (d, 0)], m_) * rng.uniform(0.5, 1.0)
        i0 = ns(s)
        y[i0:i0 + m_] += x[: n - i0]
    return room(y, 0.2)


BEHIND_YOU = V.Line([V.S("b", "i", 0.13, 50, lv=0.8), V.S("h", "a+i", 0.3, 55, coda="nd", lv=1.2),
                     V.S("y", "u", 0.4, (53, 47), lv=1.1, gap=0.04)], mode="shout", drive=1.5, tail=0.3)
PIPE_DOWN_CHANT = V.Line([V.S("p", "a+i", 0.26, 52, coda="p", lv=1.1), V.S("d", "a+u", 0.32, 50, coda="n", gap=0.05),
                          V.S("p", "a+i", 0.26, 52, coda="p", lv=1.1, gap=0.3),
                          V.S("d", "a+u", 0.4, 50, coda="n", gap=0.05, lv=1.1)], mode="shout", drive=1.4, tail=0.3)
BOW_CHANT = V.Line([V.S("b", "a+u", 0.34, 52, lv=1.1), V.S("b", "a+u", 0.34, 52, lv=1.1, gap=0.28),
                    V.S("b", "a+u", 0.42, 52, lv=1.2, gap=0.28)], mode="shout", drive=1.4, tail=0.3)
BOO = V.Line([V.S("b", "u", 0.7, (50, 45), lv=1.0)], mode="spoken", tail=0.3)


def behind_you(rng) -> np.ndarray:
    return room(norm(shout_line(rng, BEHIND_YOU, 16, 0.025)), 0.25)


def chant(rng, line: V.Line, claps_at: list[float], dur: float) -> np.ndarray:
    y = norm(shout_line(rng, line, 18, 0.03, dur))
    n = len(y)
    cl = np.zeros(n)
    for c in claps_at:
        a = applause(rng, 0.12, 20, (8.0, 9.0), [(0, 1.0), (0.12, 0.0)])
        i0 = ns(c)
        cl[i0:i0 + len(a)] += a[: n - i0]
    return room(y + norm(cl) * 0.4)


def boo(rng) -> np.ndarray:
    y = norm(shout_line(rng, BOO, 14, 0.05, 1.3))
    tail = laugh_crowd(rng, 1.3, 5, 0.1, 0.7, [(0, 0.0), (0.55, 0.0), (0.75, 1.0), (1.3, 0.0)], (0.9, 1.0))
    return room(y + norm(tail) * 0.35)


def relief(rng) -> np.ndarray:
    dur = 1.25
    n = ns(dur)
    phew = filt(white(ns(0.35), rng), ("bp", 1100, 0.8)) * env_lin([(0, 0), (0.05, 1), (0.35, 0)], ns(0.35))
    y = laugh_crowd(rng, dur, 8, 0.15, 0.75, [(0, 0.0), (0.2, 0.3), (0.35, 1.0), (0.9, 0.7), (dur, 0.0)], (0.6, 0.9))
    return room(pad(norm(phew), n) * 0.3 + norm(y))


def cheer(rng) -> np.ndarray:
    dur = 2.2
    n = ns(dur)
    clap = applause(rng, dur, 36, (4.2, 6.0), [(0, 0.3), (0.3, 1.0), (1.7, 0.9), (dur, 0.0)])
    wh = place([(rng.uniform(0.2, 0.5), whistle(rng, 0.8)), (rng.uniform(0.9, 1.3), whistle(rng, 0.7))], dur)
    whoops = place([(rng.uniform(0.1, 1.5), _whoop(rng), 1.0) for _ in range(5)], dur)
    return room(norm(clap) + pad(wh, n) * 0.3 + pad(norm(whoops), n) * 0.4)


SPECIALS = {  # kind: (fn, variants, cap s, level)
    "ooh": (ooh, 2, 1.1, -15.0),
    "gasp": (gasp, 2, 0.8, -15.0),
    "aww": (aww, 2, 1.3, -15.0),
    "shh": (shh, 2, 1.2, -17.0),
    "behind_you": (behind_you, 2, 1.6, -13.0),
    "chant": (lambda r: chant(r, PIPE_DOWN_CHANT, [0.02, 0.36, 0.95, 1.29], 2.3), 1, 2.6, -13.0),
    "bow_chant": (lambda r: chant(r, BOW_CHANT, [0.05, 0.67, 1.3], 2.1), 1, 2.5, -13.0),
    "boo": (boo, 1, 1.6, -15.0),
    "relief": (relief, 2, 1.5, -15.5),
    "cheer": (cheer, 1, 2.5, -13.0),
}

for _kind, (_fn, _nvar, _cap, _lvl) in SPECIALS.items():
    for _i in range(1, _nvar + 1):
        def _mk2(kind=_kind, fn=_fn, i=_i, cap=_cap, lvl=_lvl):
            @sfx(f"crowd_{kind}_{i}", cat="crowd", max_dur=cap, level=lvl, bank=f"crowd_{kind}",
                 desc=f"the Stalls: {kind.replace('_', ' ')} #{i}", tags=("crowd", "formant"))
            def _f(rng):
                return fn(rng)
        _mk2()


# ----------------------------------------------------------------------------- fallback crowd

def kazoo_ha(rng, notes, step=0.14, vowel="a") -> np.ndarray:
    """A kazoo going 'ha-ha-ha' on `notes` (MIDI)."""
    evs = []
    for k, p in enumerate(notes):
        evs.append((k * step, I.kazoo(midi(p), step * 0.7, 0.9 - 0.05 * k, rng, vowel), 1.0))
    return place(evs)


def kazoo_choir(rng, dur: float, parts: int, top: float = 72.0, rate: float = 6.0) -> np.ndarray:
    n = ns(dur)
    y = np.zeros(n)
    for i in range(parts):
        root = top - (0, 4, 7, 12, 16, 19)[i % 6] + rng.uniform(-0.15, 0.15)
        steps = int(dur * rate * rng.uniform(0.7, 0.95))
        notes = [root - 0.8 * k - (1 if k % 3 == 2 else 0) for k in range(steps)]
        x = kazoo_ha(rng, notes, 1.0 / rate * rng.uniform(0.95, 1.05), "a" if i % 2 else "o")
        s = rng.uniform(0, 0.12)
        i0 = ns(s)
        y[i0:i0 + len(x)] += x[: n - i0] * rng.uniform(0.6, 1.0)
    return y


def fb_tier(rng, kind: str) -> np.ndarray:
    dur = TIERS[kind][1]
    n = ns(dur)
    if kind == "t0":
        claps = applause(rng, dur, 3, (3.0, 4.0), [(0, 1.0), (dur, 0.0)])
        ha = kazoo_ha(rng, [74, 72], 0.14, "u")
        return room(pad(norm(claps), n) * 0.6 + pad(norm(ha), n) * 0.7, 0.2)
    if kind == "t1":
        ch = kazoo_choir(rng, dur * 0.85, 2, 74, 6.5)
        claps = applause(rng, dur, 8, swell=[(0, 0.6), (0.2, 1.0), (dur, 0.0)])
        return room(pad(norm(ch), n) + norm(claps) * 0.4)
    if kind == "t2":
        ch = kazoo_choir(rng, dur * 0.9, 5, 76, 6.0)
        claps = applause(rng, dur, 18, swell=[(0, 0.2), (0.5, 1.0), (dur, 0.0)])
        return room(pad(norm(ch), n) + norm(claps) * 0.55)
    if kind == "t3":
        ch = kazoo_choir(rng, dur * 0.6, 6, 77, 6.0)
        claps = applause(rng, dur, 30, swell=[(0, 0.4), (0.4, 1.0), (2.4, 0.85), (dur, 0.0)])
        wh = whistle(rng, 0.8)
        return room(pad(norm(ch), n) * 0.8 + norm(claps) * 0.8 + pad(np.roll(pad(wh, n), ns(1.4)), n) * 0.3)
    ch = kazoo_choir(rng, 2.0, 6, 79, 6.5)
    claps = applause(rng, dur, 40, (4.2, 6.0), [(0, 0.3), (0.5, 1.0), (3.4, 0.9), (dur, 0.0)])
    st = stomps(rng, dur * 0.8)
    wh = place([(rng.uniform(0.5, 1.0), whistle(rng, 0.8)), (rng.uniform(1.8, 2.6), whistle(rng, 0.9))], dur)
    return room(pad(norm(ch), n) * 0.8 + norm(claps) + pad(norm(st), n) * 0.35 + pad(wh, n) * 0.35)


def fb_special(rng, kind: str) -> np.ndarray:
    if kind == "relief":
        dur = 1.25
        n = ns(dur)
        f = np.geomspace(midi(79), midi(67), ns(0.45))
        phew = I.kazoo(f, 0.45, 0.8, rng, "u")
        claps = applause(rng, dur, 10, swell=[(0, 0.0), (0.3, 1.0), (dur, 0.0)])
        return room(pad(phew, n) + norm(claps) * 0.5)
    if kind == "cheer":
        dur = 2.2
        n = ns(dur)
        claps = applause(rng, dur, 40, (4.2, 6.0), [(0, 0.3), (0.3, 1.0), (1.7, 0.9), (dur, 0.0)])
        wh = place([(0.3, whistle(rng, 0.8)), (1.2, whistle(rng, 0.9))], dur)
        return room(norm(claps) + pad(wh, n) * 0.35)
    if kind == "aww":
        return room(norm(sum(pad(I.kazoo(np.geomspace(midi(p), midi(p - 3), ns(0.8)), 0.8, 0.9, rng, "o"), ns(1.0))
                             for p in (71, 67, 64))))
    if kind == "boo":
        f = np.geomspace(midi(50), midi(45), ns(0.9))
        return room(norm(sum(pad(I.kazoo(f * 2 ** (d / 12), 0.9, 0.9, rng, "u"), ns(1.1)) for d in (0, 3, 7))))
    if kind == "ooh":
        return room(norm(sum(pad(I.kazoo(np.geomspace(midi(p), midi(p + 2), ns(0.7)), 0.7, 0.8, rng, "u"), ns(0.9))
                             for p in (64, 68, 71))))
    if kind == "behind_you":
        # the panto warning with no voices: a kazoo choir blares the BE-HIND-YOU! rhythm (short,
        # long, falling) in thirds, two whistles on the top, a clap on each syllable
        dur = 1.25
        n = ns(dur)
        notes = [(0.0, 0.12, 62.0, 62.0), (0.15, 0.3, 67.0, 67.0), (0.49, 0.42, 65.0, 59.0)]
        y = np.zeros(n)
        for part, off in enumerate((0.0, -4.0, -7.0, 5.0)):
            for (s0, d, a, b) in notes:
                f = np.geomspace(midi(a + off), midi(b + off), ns(d)) * 2 ** (rng.uniform(-0.12, 0.12) / 12)
                x = I.kazoo(f, d, 0.9 - 0.12 * part, rng, "a" if part % 2 else "u")
                i0 = ns(s0 + rng.uniform(0, 0.015))
                y[i0:i0 + len(x)] += x[: n - i0]
        claps = np.zeros(n)
        for c in (0.0, 0.15, 0.49):
            a = applause(rng, 0.12, 16, (8.0, 9.0), [(0, 1.0), (0.12, 0.0)])
            i0 = ns(c)
            claps[i0:i0 + len(a)] += a[: n - i0]
        wh = place([(0.14, whistle(rng, 0.35, 2600.0)), (0.5, whistle(rng, 0.45, 2300.0))], dur)
        return room(norm(y) + norm(claps) * 0.35 + pad(wh, n) * 0.25, 0.22)
    if kind == "gasp":
        # a sharp intake from the pit: kazoos squeeze up a third, a quick timpani tap under it
        dur = 0.6
        n = ns(dur)
        y = sum(pad(I.kazoo(np.geomspace(midi(p), midi(p + 4), ns(0.3)), 0.3, 0.85, rng, "u"), n) for p in (66, 70, 73))
        tap = pad(I.timpani(midi(45), 0.4, 0.5, rng), n)
        return room(norm(y) + tap * 0.3, 0.22)
    raise ValueError(kind)


for _kind in TIERS:
    for _i in range(1, (4 if _kind in ("t0", "t1", "t2") else 3)):
        def _mk3(kind=_kind, i=_i):
            dur, lvl = TIERS[kind][1], TIERS[kind][2]

            @sfx(f"crowd_fb_{kind}_{i}", cat="crowd", max_dur=dur + 0.4, level=lvl, bank=f"crowd_fb_{kind}",
                 desc=f"fallback Stalls: {kind} (applause + kazoo 'ha-ha' choir) #{i}", tags=("crowd", "fallback"))
            def _f(rng):
                return fb_tier(rng, kind)
        _mk3()

for _kind, _cap, _lvl in (("relief", 1.5, -15.5), ("cheer", 2.5, -13.0), ("aww", 1.3, -15.0), ("boo", 1.4, -15.0),
                          ("ooh", 1.1, -15.0), ("behind_you", 1.6, -13.0), ("gasp", 0.8, -15.0)):
    def _mk4(kind=_kind, cap=_cap, lvl=_lvl):
        @sfx(f"crowd_fb_{kind}_1", cat="crowd", max_dur=cap, level=lvl, bank=f"crowd_fb_{kind}",
             desc=f"fallback Stalls: {kind}", tags=("crowd", "fallback"))
        def _f(rng):
            return fb_special(rng, kind)
    _mk4()
