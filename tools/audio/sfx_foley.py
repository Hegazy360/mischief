"""Foley and the Treg-Brown kit: footsteps, doors, bonks, boings, slide whistles, whooshes,
the crash-tail, and every slice prank prop (pepper to coat stand).

Rules (GDD §9.5, comedy.md §3.1): a woodblock bonk sits on the contact frame, the slide
whistle only rises and falls, a crash is followed by 300 ms of silence and one pan
spinning to rest. Hits start on sample one; low thumps are saturated so they survive a
phone speaker.
"""
from __future__ import annotations

import math

import numpy as np

import instruments as I
from registry import sfx
from synth import (SR, TAU, arr, bell_tone, brown, burst, crackle, drive, env_exp, env_lin, fade, filt, fm, lp,
                   midi, mix, noise_sweep, norm, ns, pad, perc, phase_of, pink, place, reverb, saw, sine,
                   smooth_noise, square, sweep, tri, tt, white)


# ----------------------------------------------------------------------------- building blocks

def jawharp(f, form, n, bright=1.0):
    """Buzzy tone whose harmonics are emphasised around a moving formant (the 'wow')."""
    f = arr(f, n)
    form = arr(form, n)
    base = phase_of(f, n)
    out = np.zeros(n)
    K = int(min(30, (SR / 2 * 0.9) / max(np.min(f), 20.0)))
    for k in range(1, K + 1):
        fk = f * k
        res = 1.0 / (1.0 + ((fk - form) / (0.35 * form)) ** 2)
        a = (0.35 / k ** (1.3 - 0.3 * bright) + res) * (fk < SR / 2 * 0.95)
        out += a * np.sin(TAU * base * k)
    return out


def thump(dur=0.25, f_hi=130.0, f_lo=50.0, decay=None):
    """Low body thump, saturated so its harmonics survive small speakers."""
    n = ns(dur)
    t = tt(n)
    f = f_lo + (f_hi - f_lo) * np.exp(-t / 0.03)
    return drive(np.sin(TAU * phase_of(f, n)) * perc(n, 0.001, decay or dur * 0.8), 2.2)


def droplet(rng, f=None, dur=0.07):
    """Bubble / droplet 'plip': a sine whose pitch rises as it decays."""
    f = f or rng.uniform(700, 1600)
    n = ns(dur)
    t = tt(n)
    fr = f * (1 + 1.2 * (1 - np.exp(-t / 0.02)))
    return np.sin(TAU * phase_of(fr, n)) * perc(n, 0.001, dur)


def grains(rng, dur, density, lo=800, hi=5000, glen=(0.002, 0.008), shape=None):
    """Random short band-passed noise grains (crunch, rattle, rustle, pepper)."""
    n = ns(dur)
    out = np.zeros(n)
    for _ in range(int(density * dur)):
        s = rng.uniform(0, dur)
        if shape is not None and rng.random() > shape(s / dur):
            continue
        g = rng.uniform(*glen)
        fc = math.exp(rng.uniform(math.log(lo), math.log(hi)))
        gn = ns(g)
        x = filt(white(gn, rng), ("bp", fc, 1.5)) * perc(gn, 0.0003, g)
        i = ns(s)
        m = min(gn, n - i)
        if m > 0:
            out[i:i + m] += x[:m] * rng.uniform(0.3, 1.0)
    return out


def pings(rng, dur, count, lo, hi, decay=(0.02, 0.12), shape=None, amp=1.0):
    """Tiny sine pings (glass, crystal, sparkles)."""
    n = ns(dur)
    out = np.zeros(n)
    for _ in range(count):
        s = rng.uniform(0, dur)
        if shape is not None and rng.random() > shape(s / dur):
            continue
        d = rng.uniform(*decay)
        f = math.exp(rng.uniform(math.log(lo), math.log(hi)))
        pn = ns(d * 1.2)
        p = np.sin(TAU * f * tt(pn) + rng.uniform(0, TAU)) * perc(pn, 0.0005, d)
        i = ns(s)
        m = min(pn, n - i)
        if m > 0:
            out[i:i + m] += p[:m] * rng.uniform(0.3, 1.0) * amp
    return out


def whoosh_shape(rng, dur, f_lo, f_hi, peak, bw=1.0, color=-1.5):
    """Air past the ear: a noise band rising to `peak` s then falling."""
    n = ns(dur)
    x = np.linspace(0, 1, n)
    p = min(max(peak / dur, 0.02), 0.98)
    shape = np.where(x < p, x / p, 1 - (x - p) / (1 - p))
    center = f_lo * (f_hi / f_lo) ** (np.where(x < p, (x / p) ** 0.7, 1 - 0.6 * (x - p) / (1 - p)))
    nz = noise_sweep(n, rng, center, bw, color=color)
    return nz * shape ** 1.3


def boing(rng, f0, dur, wob, depth, rise, thud_amt):
    """Jaw-harp boing: a wobbling pitch with a bouncing formant and a thud."""
    n = ns(dur)
    t = tt(n)
    wobble = depth * np.exp(-t / (dur * 0.38)) * np.sin(TAU * wob * t)
    f = f0 * (1 + rise * (1 - np.exp(-t / 0.12))) * (1 + wobble)
    form = f0 * 3.2 * (1 + 1.6 * np.exp(-t / (dur * 0.3)) * (0.5 + 0.5 * np.sin(TAU * wob * t)))
    y = norm(jawharp(f, form, n) * perc(n, 0.002, dur))
    y += 0.5 * np.sin(TAU * phase_of(f, n)) * perc(n, 0.002, dur * 0.9)
    return mix(y, (thump(0.18, f0 * 0.9, f0 * 0.35), thud_amt))


def metal_hit(rng, f0, dur=0.6, ratios=(1.0, 2.32, 3.87, 5.2, 7.1), bright=1.0, decay=0.35):
    """Pan / pot / lid strike: inharmonic plate modes and a click."""
    n = ns(dur)
    t = tt(n)
    y = np.zeros(n)
    for i, r in enumerate(ratios):
        a = (0.7 ** i) * (bright if i > 1 else 1.0)
        d = decay / (1 + 0.5 * i)
        y += a * np.sin(TAU * f0 * r * t * (1 + 0.0006 * i) + rng.uniform(0, TAU)) * np.exp(-6.9 * t / d)
    y += burst(n, rng, 1500, 9000, 0.0001, 0.004) * 0.5
    return y


def slap_hit(rng, dur=0.3, bright=1.0):
    n = ns(dur)
    crack = filt(white(n, rng), ("hp", 700, 0.7), ("peak", 2500, 1.0, 6)) * perc(n, 0.0002, 0.05)
    body = pad(thump(0.12, 300, 140), n) * 0.5
    return norm(crack) * bright + body


def creak(rng, dur=1.0, base=14.0, span=70.0, bands=(650, 1400, 2300), shape=None):
    """Stick-slip wood creak: a pulse train through wooden resonances."""
    n = ns(dur)
    arc = shape if shape is not None else env_lin([(0, 0.35), (dur * 0.3, 1.0), (dur * 0.7, 0.55), (dur, 0.2)], n)
    rate = (base + span * arc) * (1 + 0.35 * smooth_noise(n, 6, rng))
    ph = phase_of(rate, n)
    pulses = np.zeros(n)
    idx = np.nonzero(np.diff(np.floor(ph)) > 0)[0]
    pulses[idx] = rng.uniform(0.6, 1.0, len(idx))
    body = filt(pulses, ("bp", bands[0], 6.0), ("bp", bands[1], 3.0))
    body += filt(pulses, ("bp", bands[2], 8.0)) * 0.4
    e = env_lin([(0, 0), (0.03, 1), (dur * 0.8, 0.8), (dur, 0)], n)
    return norm(body) * e


def water_gush(rng, dur, center=1400.0, wobble=0.3):
    n = ns(dur)
    c = center * (1 + wobble * smooth_noise(n, 6, rng))
    x = noise_sweep(n, rng, c, 1.6, color=-1.0)
    drops = place([(rng.uniform(0, dur * 0.95), droplet(rng, rng.uniform(900, 2600), rng.uniform(0.03, 0.07)),
                    rng.uniform(0.2, 0.6)) for _ in range(int(20 * dur))], dur)
    return norm(x) + pad(drops, n) * 0.4


def splat(rng, dur=0.5, wet=1.0):
    n = ns(dur)
    slp = filt(white(n, rng), ("hp", 300)) * perc(n, 0.0002, 0.03)
    goo = noise_sweep(n, rng, env_exp([(0, 3000), (0.2, 350), (dur, 250)], n), 1.2) * perc(n, 0.001, 0.35)
    blobs = place([(rng.uniform(0.02, 0.2), droplet(rng, rng.uniform(250, 600), 0.06), rng.uniform(0.3, 0.7))
                   for _ in range(6)], dur)
    low = pad(thump(0.2, 140, 70), n)
    return norm(slp) * 0.6 + norm(goo) * 0.9 * wet + pad(blobs, n) * 0.5 * wet + low * 0.6


# ----------------------------------------------------------------------------- footsteps

STEP_SCALE = (64, 66, 67, 69, 71, 72, 74, 76)   # E minor, E4 → E5: Hush tiptoes up the scale


def _step_pizz(rng, m):
    n = ns(0.36)
    note = I.pizz(midi(m), 0.2, 0.95, rng, bright=0.5, ring=0.2)
    tip = filt(white(ns(0.012), rng), ("bp", 2400, 1.2)) * perc(ns(0.012), 0.0002, 0.006)
    return pad(note, n) + pad(tip, n) * 0.12


for _i, _m in enumerate(STEP_SCALE, start=1):
    def _mk(m=_m, i=_i):
        @sfx(f"step_pizz_{i}", cat="soft", max_dur=0.45, bank="step_pizz", level=-20.0,
             desc=f"Hush tiptoe: pizzicato note {i}/8 of the E-minor scale (midi {m})")
        def _f(rng):
            return _step_pizz(rng, m)
    _mk()


def _patter(rng, count=4, gap=0.085):
    evs = []
    for k in range(count):
        m = ns(0.05)
        fc = rng.uniform(1600, 2600) * (1.08 if k % 2 else 1.0)
        x = filt(white(m, rng), ("bp", fc, 1.6)) * perc(m, 0.0004, 0.018)
        body = np.sin(TAU * rng.uniform(170, 210) * tt(m)) * perc(m, 0.0005, 0.03) * 0.5
        evs.append((k * gap * rng.uniform(0.92, 1.08), norm(x) + body, 0.75 + 0.25 * (k % 2)))
    return place(evs, count * gap + 0.08)


@sfx("run_patter_1", cat="soft", max_dur=0.5, bank="run_patter", level=-17.0, vary=0.04,
     desc="Hush running: four quick shoe pats (noisy)")
def run_patter_1(rng):
    return _patter(rng)


@sfx("run_patter_2", cat="soft", max_dur=0.5, bank="run_patter", level=-17.0, vary=0.04,
     desc="Hush running: four quick shoe pats, variant")
def run_patter_2(rng):
    return _patter(rng, 4, 0.08)


def _fwip(rng, tile: bool):
    """Bellows' slipper: a soft brushed 'fwip' and the weight of a barrel-shaped baritone."""
    dur = 0.3
    n = ns(dur)
    brush = noise_sweep(n, rng, env_exp([(0, 3200), (0.09, 900), (dur, 600)], n), 1.2, color=-1.0)
    brush *= env_lin([(0, 0), (0.012, 1), (0.1, 0.35), (dur, 0)], n)
    weight = pad(thump(0.16, 120, 60, 0.12), n) * 0.55
    y = norm(brush) * 0.7 + weight
    if tile:
        smack = filt(white(n, rng), ("hp", 900), ("peak", 3000, 1.2, 6)) * perc(n, 0.0003, 0.02)
        y += norm(smack) * 0.45
        y = reverb(y, 0.12, 0.35, keep_len=True)
    else:
        knock = I.woodblock(rng.uniform(220, 260), 0.3, rng, 0.12)
        y += pad(knock, n) * 0.35
    return y


for _k in (1, 2):
    def _mk2(k=_k):
        @sfx(f"slipper_wood_{k}", cat="soft", max_dur=0.35, bank="slipper_wood", level=-19.0, vary=0.05,
             desc=f"Bellows' slipper 'fwip' on floorboards #{k}")
        def _w(rng):
            return _fwip(rng, False)

        @sfx(f"slipper_tile_{k}", cat="soft", max_dur=0.4, bank="slipper_tile", level=-19.0, vary=0.05,
             desc=f"Bellows' slipper 'fwip' on kitchen tile #{k}")
        def _t(rng):
            return _fwip(rng, True)
    _mk2()


def _squelch(rng, k: float):
    """SOAKED (GDD §5.4 "squelching steps"): the soggy slipper presses (a wet, falling 'shl-'), the
    trapped water burbles out of the sponge (a wobbling jaw-harp squish), bubbles pop, and the sole
    sucks off the boards ('-thwp'). `k` scales the pitch per take."""
    dur = 0.36
    n = ns(dur)
    t = tt(n)
    press = noise_sweep(n, rng, env_exp([(0, 2400 * k), (0.045, 900 * k), (0.16, 460 * k), (dur, 380 * k)], n),
                        1.3, color=-1.0)
    press *= env_lin([(0, 0), (0.005, 1.0), (0.05, 0.6), (0.15, 0.18), (0.24, 0.0), (dur, 0.0)], n)
    f = 160.0 * k * (1.0 + 0.22 * np.sin(TAU * 31.0 * t) * np.exp(-t / 0.12))
    form = env_exp([(0, 450 * k), (0.1, 1500 * k), (0.2, 800 * k), (dur, 600 * k)], n)
    squish = jawharp(f, form, n, bright=0.6) * env_lin([(0, 0), (0.025, 0), (0.06, 1.0), (0.17, 0.35), (0.24, 0),
                                                         (dur, 0)], n)
    bubbles = place([(0.05 + rng.uniform(0, 0.17), droplet(rng, rng.uniform(420, 1050) * k, rng.uniform(0.025, 0.05)),
                      rng.uniform(0.3, 0.75)) for _ in range(6)], dur)
    sn = ns(0.06)
    suck = sine(env_exp([(0, 260 * k), (0.06, 1100 * k)], sn), sn) * perc(sn, 0.006, 0.05)
    weight = pad(thump(0.14, 115, 55, 0.1), n)
    return (norm(press) * 0.75 + norm(squish) * 0.55 + pad(bubbles, n) * 0.6
            + pad(place([(0.24, suck)], dur), n) * 0.45 + weight * 0.3)


for _k, _pitch in ((1, 1.0), (2, 1.13)):
    def _mk_sq(k=_k, pitch=_pitch):
        @sfx(f"squelch_{k}", cat="soft", max_dur=0.45, bank="squelch", level=-18.5, vary=0.05,
             desc=f"Bellows' SOAKED slipper: a wet squelch-and-suck step #{k}")
        def _f(rng):
            return _squelch(rng, pitch)
    _mk_sq()


for _k, (_base, _span, _dur) in enumerate(((12, 55, 0.55), (18, 80, 0.45), (9, 40, 0.7)), start=1):
    def _mk3(k=_k, base=_base, span=_span, dur=_dur):
        @sfx(f"stair_creak_{k}", cat="soft", max_dur=0.8, bank="stair_creak", level=-18.0, vary=0.03,
             desc=f"stair tread creak #{k}")
        def _f(rng):
            return creak(rng, dur, base, span, (520 + 60 * k, 1250, 2100))
    _mk3()


# ----------------------------------------------------------------------------- doors

def _latch(rng, f=1800.0, g=1.0):
    m = ns(0.05)
    return (filt(white(m, rng), ("bp", f, 4.0)) * perc(m, 0.0001, 0.012) * 2.0
            + np.sin(TAU * f * 0.6 * tt(m)) * perc(m, 0.0001, 0.01)) * g


@sfx("door_front", max_dur=1.2, desc="heavy front door: handle, hinge creak, latch clunk")
def door_front(rng):
    hinge = creak(rng, 0.45, 20, 60, (480, 1100, 1900))
    clunk = pad(thump(0.3, 140, 55), ns(0.4)) + pad(I.woodblock(180, 0.6, rng, 0.25), ns(0.4)) * 0.5
    return reverb(place([(0, _latch(rng, 1600)), (0.05, hinge, 0.5), (0.62, clunk), (0.64, _latch(rng, 1300), 0.8)]),
                  0.14, 0.5, keep_len=True)


@sfx("door_back", max_dur=1.2, desc="back door: lighter creak, latch, rattling glass pane")
def door_back(rng):
    hinge = creak(rng, 0.35, 24, 70, (620, 1400, 2400))
    glass = pings(rng, 0.35, 40, 2500, 6500, (0.01, 0.05), lambda x: math.exp(-x * 5), 0.6)
    shut = pad(thump(0.2, 180, 80), ns(0.3)) * 0.7
    return reverb(place([(0, _latch(rng, 2000)), (0.04, hinge, 0.45), (0.46, shut), (0.47, glass, 0.6),
                         (0.48, _latch(rng, 1700), 0.8)]), 0.12, 0.45, keep_len=True)


@sfx("cupboard", max_dur=0.8, desc="cupboard door: small creak + wooden clack")
def cupboard(rng):
    hinge = creak(rng, 0.28, 30, 90, (800, 1700, 2800))
    clack = I.woodblock(420, 0.9, rng, 0.15)
    return place([(0, hinge, 0.6), (0.3, clack)])


@sfx("door_jiggle", max_dur=0.8, desc="door handle jiggle — the 1.5 s entry warning")
def door_jiggle(rng):
    evs = []
    for k in range(6):
        f = rng.uniform(1300, 2300)
        m = ns(0.06)
        x = filt(white(m, rng), ("bp", f, 5.0)) * perc(m, 0.0002, 0.02) * 2.0
        x += np.sin(TAU * f * 0.5 * tt(m)) * perc(m, 0.0002, 0.03) * 0.5
        evs.append((k * 0.085 + rng.uniform(0, 0.012), x, 1.0 if k % 2 == 0 else 0.7))
    evs.append((0.52, pad(thump(0.1, 200, 100), ns(0.1)), 0.35))
    return reverb(place(evs, 0.65), 0.1, 0.35, keep_len=True)


# ----------------------------------------------------------------------------- Treg-Brown kit

@sfx("woodblock_bonk", desc="the woodblock BONK (on the contact frame)", vary=0.03)
def woodblock_bonk(rng):
    n = ns(0.42)
    t = tt(n)
    a = I.woodblock(690, 1.0, rng, 0.3)
    b = I.woodblock(1030, 0.45, rng, 0.2)
    ring = 0.2 * np.sin(TAU * 1640 * t) * perc(n, 0.0005, 0.28)
    return pad(a, n) + pad(b, n) + ring + pad(thump(0.16, 190, 90), n) * 0.45


@sfx("boing_small", desc="small spring boing", vary=0.02)
def boing_small(rng):
    return boing(rng, 520, 0.5, 17, 0.22, 0.12, 0.3)


@sfx("boing_med", desc="medium boing", vary=0.02)
def boing_med(rng):
    return boing(rng, 300, 0.75, 12.5, 0.26, 0.15, 0.5)


@sfx("boing_big", max_dur=1.3, desc="big bouncy boing", vary=0.02)
def boing_big(rng):
    return boing(rng, 150, 1.15, 8.5, 0.3, 0.2, 0.9)


@sfx("slide_up", desc="slide whistle up (rises only)")
def slide_up(rng):
    return I.slide_whistle((480, 1750), 0.6, 0.9, rng)


@sfx("slide_down", desc="slide whistle down (falls only)")
def slide_down(rng):
    return I.slide_whistle((1750, 430), 0.65, 0.9, rng)


@sfx("whoosh", desc="medium air whoosh", vary=0.05)
def whoosh(rng):
    return whoosh_shape(rng, 0.55, 350, 2400, 0.17, 1.1)


@sfx("zip", desc="zip-away: fast rising 'zwip'", vary=0.04)
def zip_(rng):
    dur = 0.24
    n = ns(dur)
    air = whoosh_shape(rng, dur, 1500, 7000, 0.12, 0.8)
    ch = sine(sweep(700, 3200, dur, "exp"), n) * env_lin([(0, 0), (0.01, 0.6), (0.16, 0.4), (dur, 0)], n)
    return norm(air) + ch * 0.5


def _crockery(rng, dur=0.7):
    n = ns(dur)
    body = filt(white(n, rng), ("hp", 500), ("lp", 9000)) * perc(n, 0.0005, 0.3)
    shards = pings(rng, dur, 140, 2500, 9000, (0.02, 0.18), lambda x: math.exp(-x * 4.0), 0.6)
    clatter = grains(rng, dur, 90, 600, 3500, (0.004, 0.02), lambda x: math.exp(-x * 5))
    return norm(body) * 0.8 + shards + clatter * 0.8 + pad(thump(0.25, 150, 60), n) * 0.6


def pan_spin(rng, dur=1.3, f0=410.0):
    """A dropped pan spinning to rest: impacts accelerate while they fade (Euler's disk)."""
    n = ns(dur)
    y = np.zeros(n)
    tpos, gap, k = 0.0, 0.16, 0
    while tpos < dur - 0.08 and gap > 0.006:
        hit = metal_hit(rng, f0 * (1.0 + 0.03 * (k % 2)), 0.35, decay=0.25)
        g = (1.0 - tpos / dur) ** 1.2 * (0.9 if k % 2 else 1.0)
        i = ns(tpos)
        m = min(len(hit), n - i)
        y[i:i + m] += hit[:m] * g
        tpos += gap
        gap *= 0.86
        k += 1
    rest = metal_hit(rng, f0 * 0.98, 0.5, decay=0.4)
    i = ns(min(tpos, dur - 0.5))
    y[i:i + len(rest)] += rest[: n - i] * 0.35
    return y


@sfx("crash_tail", max_dur=2.6, tags=("keep_tail",),
     desc="crash → 300 ms of silence → one pan spinning to rest")
def crash_tail(rng):
    return place([(0, reverb(_crockery(rng), 0.15, 0.5, keep_len=True)), (1.0, pan_spin(rng), 0.7)], 2.4)


@sfx("record_scratch", desc="needle scratch (the pratfall)")
def record_scratch(rng):
    src_d = 2.0
    n_src = ns(src_d)
    src = (saw(midi(60), n_src) + saw(midi(64), n_src) + saw(midi(67), n_src)) * 0.3
    src = lp(src, 3500) + filt(white(n_src, rng), ("bp", 3000, 0.7)) * 0.4
    dur = 0.62
    n = ns(dur)
    speed = env_lin([(0, 1.0), (0.06, 1.0), (0.1, -2.6), (0.22, -2.2), (0.26, 2.4), (0.36, 1.8),
                     (0.4, -1.6), (0.5, -1.0), (0.56, 0.0), (dur, 0.0)], n)
    pos = 0.6 * SR + np.cumsum(speed)
    y = np.interp(pos, np.arange(n_src), src)
    fric = filt(white(n, rng), ("bp", 2500, 0.8)) * np.abs(speed) * 0.25
    return (y + fric) * np.clip(np.abs(speed) * 1.5, 0, 1)


@sfx("dizzy_tweets", max_dur=1.5, desc="orbiting dizzy birdies")
def dizzy_tweets(rng):
    dur = 1.4
    n = ns(dur)
    evs = []
    tpos = 0.0
    k = 0
    while tpos < dur - 0.12:
        m = ns(0.09)
        f0 = (3300, 3900, 2900)[k % 3] * rng.uniform(0.97, 1.03)
        f = f0 * (1 + 0.45 * np.sin(TAU * 15 * tt(m)))
        evs.append((tpos, sine(f, m) * perc(m, 0.002, 0.08), 0.7 + 0.3 * (k % 3 == 0)))
        tpos += rng.uniform(0.1, 0.16)
        k += 1
    y = place(evs, dur)
    orbit = 0.65 + 0.35 * np.sin(TAU * 1.4 * tt(len(y)))
    return reverb(y * orbit, 0.2, 0.6, keep_len=True)


@sfx("stamp_thunk", desc="rubber stamp ka-THUNK (caption stamps)")
def stamp_thunk(rng):
    n = ns(0.45)
    t = tt(n)
    clack = pad(filt(white(ns(0.015), rng), ("bp", 2200, 3)) * perc(ns(0.015), 0.0001, 0.006), n)
    body = pad(thump(0.32, 170, 65), n)
    wood = np.sin(TAU * 250 * t) * perc(n, 0.0005, 0.07)
    paper = filt(white(n, rng), ("bp", 1800, 1.2)) * perc(n, 0.0005, 0.03)
    y = np.zeros(n)
    s = ns(0.022)
    y[s:] += (body + wood * 0.6 + norm(paper) * 0.5)[: n - s]
    return y + clack * 0.6


# ----------------------------------------------------------------------------- kitchen pranks

@sfx("pepper_shake", desc="pepper pot: three shakes onto the honey")
def pepper_shake(rng):
    def shake():
        g = grains(rng, 0.14, 900, 3000, 9000, (0.001, 0.004), lambda x: math.sin(math.pi * x))
        return g + pad(I.woodblock(900, 0.25, rng, 0.08), len(g))
    return place([(0, shake()), (0.19, shake(), 0.9), (0.38, shake(), 1.0)], 0.6)


@sfx("sink_splash", max_dur=1.3, desc="into the sink: metal bong + splash")
def sink_splash(rng):
    dur = 1.1
    n = ns(dur)
    bong = metal_hit(rng, 260, 0.9, (1.0, 2.1, 3.3, 4.6), decay=0.6)
    impact = filt(white(n, rng), ("lp", 6000), ("hp", 200)) * perc(n, 0.0005, 0.08)
    body = noise_sweep(n, rng, env_exp([(0, 2500), (0.3, 900), (dur, 700)], n), 1.4) * perc(n, 0.002, 0.6)
    drops = place([(rng.uniform(0.05, 0.8) ** 1.5, droplet(rng, rng.uniform(900, 2400), rng.uniform(0.03, 0.07)),
                    rng.uniform(0.2, 0.6)) for _ in range(26)], dur)
    return pad(bong, n) * 0.6 + norm(impact) * 0.7 + norm(body) + pad(drops, n) * 0.5 + pad(thump(0.25, 120, 55), n) * 0.5


@sfx("spray_blast", max_dur=0.95, desc="spray tap twisted: eek + high-pressure face blast")
def spray_blast(rng):
    dur = 1.0
    n = ns(dur)
    t = tt(n)
    eek = pad(sine(env_lin([(0, 1800), (0.06, 2400)], ns(0.07)), ns(0.07)) * perc(ns(0.07), 0.002, 0.07), n)
    jet = filt(white(n, rng), ("hp", 1500), ("peak", 4200, 1.0, 5)) * (0.8 + 0.2 * np.sin(TAU * 11 * t))
    gush = water_gush(rng, dur, 1600, 0.25)
    e = env_lin([(0, 0), (0.06, 0.0), (0.075, 1.0), (0.7, 0.8), (dur, 0)], n)
    return eek * 0.5 + (norm(jet) * 0.7 + norm(gush) * 0.8) * e


@sfx("hose_wrestle", max_dur=1.7, desc="wrestling the hose like a python (and losing)")
def hose_wrestle(rng):
    dur = 1.6
    n = ns(dur)
    t = tt(n)
    gush = water_gush(rng, dur, 1300, 0.45) * (0.6 + 0.4 * np.abs(np.sin(TAU * 1.7 * t + 0.4)))
    evs = [(0, gush * 0.7)]
    for k in range(3):
        m = ns(0.18)
        f = env_lin([(0, 700), (0.08, 1100), (0.18, 800)], m) * rng.uniform(0.9, 1.2)
        sq = (sine(f, m) + 0.4 * saw(f, m) * 0.4) * perc(m, 0.004, 0.16)
        evs.append((0.2 + k * 0.45 + rng.uniform(0, 0.06), sq, 0.4))
    for k in range(3):
        evs.append((0.38 + k * 0.42 + rng.uniform(0, 0.05), slap_hit(rng, 0.25), 0.55))
        evs.append((0.28 + k * 0.42, whoosh_shape(rng, 0.3, 500, 2500, 0.12, 1.0), 0.4))
    return place(evs, dur)


def _squeaker_note(rng, f, d, v=1.0):
    """A rubber squeaker blown like a kettle whistle."""
    n = ns(d + 0.04)
    t = tt(n)
    fr = f * (1 + 0.04 * np.exp(-t / 0.03)) * (1 + 0.018 * np.sin(TAU * 7 * t))
    y = sine(fr, n) + 0.35 * sine(2 * fr, n) + 0.12 * saw(fr, n) * 0.5
    y *= 0.75 + 0.25 * np.abs(np.sin(TAU * 26 * t))
    air = filt(white(n, rng), ("bp", f * 1.5, 2.0)) * 0.12
    return (y + air) * env_lin([(0, 0), (0.015, 1), (d, 0.85), (d + 0.04, 0)], n) * v


@sfx("kettle_melody", max_dur=1.5, desc="the squeaker in the kettle whistles a cheeky tune")
def kettle_melody(rng):
    notes = [(0.0, 0.18, 76), (0.2, 0.18, 79), (0.4, 0.18, 81), (0.6, 0.14, 79), (0.76, 0.6, 84)]
    evs = [(s, _squeaker_note(rng, midi(p), d), 0.9) for s, d, p in notes]
    steam = filt(white(ns(1.6), rng), ("hp", 3000)) * env_lin([(0, 0), (0.3, 0.1), (1.6, 0)], ns(1.6))
    y = place(evs, 1.6) + pad(steam, ns(1.6))
    return reverb(y, 0.12, 0.4, keep_len=True)


@sfx("lid_boink", desc="kettle lid pops onto his nose: tink + boink")
def lid_boink(rng):
    tink = metal_hit(rng, 1250, 0.35, (1.0, 2.7, 4.9), decay=0.25)
    bk = boing(rng, 620, 0.42, 19, 0.2, 0.18, 0.15)
    return place([(0, tink, 0.6), (0.02, bk, 0.9)])


@sfx("jar_strain", max_dur=1.25, desc="over-tightened onion jar: straining lid creak")
def jar_strain(rng):
    dur = 1.15
    n = ns(dur)
    shape = env_lin([(0, 0.1), (0.75, 0.7), (1.0, 1.0), (dur, 1.0)], n)
    c = creak(rng, dur, 10, 120, (900, 2000, 3300), shape)
    t = tt(n)
    squeal = sine(env_lin([(0, 900), (dur, 1800)], n), n) * env_lin([(0, 0), (0.75, 0.0), (0.95, 0.3), (dur, 0.25)], n)
    return c + squeal * (0.6 + 0.4 * np.sin(TAU * 23 * t))


@sfx("onion_pop", desc="the jar lid gives: onion POP")
def onion_pop(rng):
    n = ns(0.35)
    t = tt(n)
    crack = filt(white(n, rng), ("hp", 400)) * perc(n, 0.0001, 0.02)
    tone = np.sin(TAU * phase_of(420 * np.exp(-t / 0.05) + 110, n)) * perc(n, 0.0005, 0.12)
    air = whoosh_shape(rng, 0.2, 800, 3500, 0.03, 1.0)
    return norm(crack) * 0.8 + tone + pad(air, n) * 0.3


for _k, _f in enumerate((520, 640, 790), start=1):
    def _mk4(k=_k, f=_f):
        @sfx(f"pinball_bonk_{k}", bank="pinball_bonk", desc=f"onion pinballs off pan #{k} (rising pitch)")
        def _p(rng):
            h = metal_hit(rng, f, 0.45, (1.0, 2.4, 3.9, 5.6), decay=0.3)
            return h + pad(boing(rng, f * 1.1, 0.25, 22, 0.12, 0.05, 0.0), len(h)) * 0.25
    _mk4()


@sfx("slip_whoosh", desc="feet shoot up: whoosh + quick slide-whistle rise")
def slip_whoosh(rng):
    air = whoosh_shape(rng, 0.35, 600, 4000, 0.1, 0.9)
    rise = I.slide_whistle((520, 1500), 0.26, 0.7, rng)
    return place([(0, air), (0.03, rise, 0.6)])


@sfx("gulp", desc="a nervous cartoon gulp (before a launch)")
def gulp(rng):
    n = ns(0.3)
    t = tt(n)
    f = 360 * np.exp(-t / 0.07) + 105
    y = np.sin(TAU * phase_of(f, n)) * perc(n, 0.006, 0.22)
    click = filt(white(ns(0.012), rng), ("bp", 1400, 2.0)) * perc(ns(0.012), 0.0002, 0.005)
    return y + pad(click, n) * 0.4 + filt(white(n, rng), ("lp", 700)) * perc(n, 0.003, 0.06) * 0.25


@sfx("slip_thud", desc="lands flat: body thud + floor rattle")
def slip_thud(rng):
    n = ns(0.6)
    body = pad(thump(0.45, 110, 42, 0.35), n)
    rattle = grains(rng, 0.6, 140, 700, 4000, (0.003, 0.012), lambda x: math.exp(-x * 6))
    flesh = filt(white(n, rng), ("lp", 700)) * perc(n, 0.0005, 0.08)
    return body + rattle * 0.4 + norm(flesh) * 0.35


# ----------------------------------------------------------------------------- parlour pranks

def _record_music(rng, dur):
    """A scratchy 78 of a pompous baritone band (chords + melody), band-limited."""
    n = ns(dur)
    y = np.zeros(n)
    mel = [67, 72, 76, 74, 72, 71, 72, 79, 76, 72]
    step = 0.22
    for k in range(int(dur / step) + 1):
        p = mel[k % len(mel)]
        x = I.trumpet(midi(p - 12), step * 0.9, 0.8, rng)
        i = ns(k * step)
        m = min(len(x), n - i)
        if m > 0:
            y[i:i + m] += x[:m]
    oom = sum(pad(I.tuba(midi(p), dur, 0.6, rng), n) for p in (36,)) * 0.3
    return filt(y + oom, ("hp", 350), ("lp", 3200))


@sfx("gramophone_speedup", max_dur=1.5, desc="speed lever to ×3: the record screeches up")
def gramophone_speedup(rng):
    src = _record_music(rng, 6.0)
    dur = 1.35
    n = ns(dur)
    t = tt(n)
    speed = 1.0 + 2.0 * np.clip((t - 0.15) / 0.8, 0, 1) ** 1.5
    pos = np.cumsum(speed)
    y = np.interp(pos, np.arange(len(src)), src)
    whine = sine(env_lin([(0, 600), (0.15, 600), (0.95, 2100), (dur, 2200)], n), n)
    whine *= env_lin([(0, 0), (0.15, 0), (0.3, 0.25), (1.0, 0.35), (dur, 0)], n)
    surface = filt(crackle(n, rng, 300 * speed), ("hp", 1200)) * 0.8 + filt(white(n, rng), ("bp", 2500, 0.8)) * 0.04
    lever = pad(I.woodblock(1500, 0.6, rng, 0.08), n) + pad(burst(ns(0.03), rng, 2000, 6000), n) * 0.3
    return norm(y) * 0.8 + whine + surface * 0.5 + lever * 0.5


@sfx("gramophone_babble", max_dur=1.4, desc="the ×3 record: his own aria as chipmunk babble")
def gramophone_babble(rng):
    import voices
    src = voices.render_line("bellows", "aria_4", "formant")
    dur = 1.3
    n = ns(dur)
    pos = np.arange(n) * 2.6 % max(1, len(src) - 1)
    y = np.interp(pos, np.arange(len(src)), src)
    y = filt(y, ("hp", 500), ("lp", 3600), ("peak", 1500, 1.5, 6))
    surface = filt(crackle(n, rng, 500), ("hp", 1500)) * 0.4
    return norm(y) + surface


@sfx("recliner_twang", desc="recliner spring cranked: a huge TWANG")
def recliner_twang(rng):
    dur = 1.0
    n = ns(dur)
    t = tt(n)
    f = 72 * (1 + 0.7 * np.exp(-t / 0.05)) * (1 + 0.06 * np.sin(TAU * 7 * t) * np.exp(-t / 0.35))
    y = jawharp(f, 520 * (1 + 1.8 * np.exp(-t / 0.08)), n) * perc(n, 0.001, 0.9)
    ring = metal_hit(rng, 880, dur, (1.0, 2.9, 5.3), decay=0.6) * 0.15
    return norm(y) + ring + pad(whoosh_shape(rng, 0.2, 1200, 5000, 0.05, 0.8), n) * 0.4


@sfx("catapult_whoosh", desc="catapulted: long launch whoosh + slide-whistle rise")
def catapult_whoosh(rng):
    air = whoosh_shape(rng, 0.85, 300, 3500, 0.45, 1.1)
    rise = I.slide_whistle((360, 1900), 0.75, 0.8, rng)
    return place([(0, air), (0.02, rise, 0.55)])


@sfx("chandelier_jingle", max_dur=1.3, desc="cravat snags the chandelier: crystal jingle, swinging")
def chandelier_jingle(rng):
    dur = 1.25
    n = ns(dur)
    y = np.zeros(n)
    for k, s in enumerate((0.0, 0.36, 0.68, 0.94)):
        g = pings(rng, 0.45, 50, 2500, 8500, (0.04, 0.25), lambda x: math.exp(-x * 3.0), 1.0) * (0.85 ** k)
        i = ns(s)
        y[i:i + len(g)] += g[: n - i]
    creak_ = creak(rng, dur, 5, 18, (500, 1200, 2000)) * 0.12
    return reverb(y + creak_, 0.25, 0.8, keep_len=True)


@sfx("logbasket_crash", max_dur=1.1, desc="drops into the log basket: wicker crunch + tumbling logs")
def logbasket_crash(rng):
    dur = 1.3
    n = ns(dur)
    crunch = grains(rng, 0.5, 900, 800, 5000, (0.002, 0.01), lambda x: math.exp(-x * 3))
    evs = [(0, pad(thump(0.4, 120, 45), n), 1.0), (0, crunch, 0.7)]
    tpos = 0.08
    for k in range(6):
        evs.append((tpos, I.woodblock(rng.uniform(170, 330), 0.8 - 0.1 * k, rng, 0.2), 1.0))
        tpos += rng.uniform(0.09, 0.2)
    return reverb(place(evs, dur), 0.15, 0.5, keep_len=True)


@sfx("paper_rustle", cat="soft", level=-18.0, desc="newspaper rustle")
def paper_rustle(rng):
    dur = 0.7
    y = grains(rng, dur, 1400, 1500, 8000, (0.002, 0.006), lambda x: 0.5 + 0.5 * math.sin(math.pi * x))
    n = len(y)
    return y + filt(white(n, rng), ("bp", 4000, 0.7)) * 0.08 * env_lin([(0, 0), (0.2, 1), (dur, 0)], n)


@sfx("paper_rip", desc="newspaper ripped in half")
def paper_rip(rng):
    dur = 0.42
    n = ns(dur)
    dens = env_lin([(0, 200), (0.05, 3500), (0.35, 2500), (dur, 0)], n)
    x = filt(crackle(n, rng, dens, 0.6), ("bp", 3000, 0.6)) * 2.0
    tear = noise_sweep(n, rng, sweep(1200, 4500, dur), 0.8) * env_lin([(0, 0), (0.03, 1), (0.33, 0.8), (dur, 0)], n)
    return norm(x) * 0.8 + norm(tear) * 0.6


@sfx("eye_boing", desc="magnifier eyes balloon out: BWOOING + glass ting")
def eye_boing(rng):
    dur = 0.8
    n = ns(dur)
    t = tt(n)
    f = env_lin([(0, 180), (0.12, 420), (dur, 460)], n) * (1 + 0.2 * np.exp(-t / 0.3) * np.sin(TAU * 13 * t))
    y = jawharp(f, f * 3.5, n) * perc(n, 0.004, dur)
    stretch = filt(saw(env_lin([(0, 120), (0.12, 380)], n), n), ("bp", 1300, 2.0)) * env_lin([(0, 0), (0.02, 0.6), (0.14, 0)], n)
    ting = pad(metal_hit(rng, 2100, 0.3, (1.0, 2.8), decay=0.2), n) * 0.2
    return norm(y) + stretch * 0.4 + ting


# ----------------------------------------------------------------------------- hall pranks

def _wet_flop(rng, g=1.0):
    m = ns(0.12)
    x = filt(white(m, rng), ("lp", 2500), ("peak", 700, 1.2, 6)) * perc(m, 0.0004, 0.05)
    return (norm(x) + pad(thump(0.08, 220, 120), m) * 0.4) * g


@sfx("fish_flop", desc="the kipper flops on the phone table")
def fish_flop(rng):
    return place([(0, _wet_flop(rng)), (0.18, _wet_flop(rng, 0.8)), (0.33, _wet_flop(rng, 0.9))], 0.5)


for _k in (1, 2):
    def _mk5(k=_k):
        @sfx(f"fish_slap_{k}", bank="fish_slap", vary=0.04, desc=f"wet kipper slaps his face #{k}")
        def _s(rng):
            n = ns(0.35)
            flick = pad(place([(rng.uniform(0.05, 0.2), droplet(rng, rng.uniform(1200, 2600), 0.05), 0.3)
                               for _ in range(5)]), n)
            return pad(slap_hit(rng, 0.3, 1.2), n) + pad(_wet_flop(rng, 0.6), n) + flick
    _mk5()


@sfx("phone_ring", max_dur=2.0, desc="old bell telephone: brrring-brrring")
def phone_ring(rng):
    def ring(d):
        n = ns(d + 0.4)
        exc = np.zeros(n)
        exc[: ns(d): ns(1 / 22.0)] = 1.0
        y = np.zeros(n)
        for f in (1080, 1340):
            for r, a, dd in ((1.0, 1.0, 0.4), (2.32, 0.5, 0.25), (4.25, 0.3, 0.15)):
                ir = np.sin(TAU * f * r * tt(ns(0.5))) * np.exp(-6.9 * tt(ns(0.5)) / dd)
                y += np.convolve(exc, ir)[:n] * a
        return y
    return reverb(place([(0, ring(0.6)), (0.9, ring(0.5))], 1.6), 0.12, 0.4, keep_len=True)


@sfx("clock_chimes", max_dur=1.5, desc="over-wound clock: machine-gun chimes (a-a-a-a)")
def clock_chimes(rng):
    dur = 1.3
    evs = []
    k = 0
    tpos = 0.0
    while tpos < dur - 0.1:
        f = (659.3, 880.0, 784.0, 987.8)[k % 4]
        evs.append((tpos, bell_tone(f, 0.4, 0.8, rng), 0.7 + 0.3 * (k % 2)))
        evs.append((tpos, I.woodblock(2400, 0.2, rng, 0.03), 1.0))
        tpos += 1 / 12.5
        k += 1
    return reverb(place(evs, dur), 0.18, 0.6, keep_len=True)


@sfx("pendulum_smack", desc="the pendulum door smacks his bum")
def pendulum_smack(rng):
    whack = slap_hit(rng, 0.3, 1.0)
    wood = I.woodblock(330, 1.0, rng, 0.25)
    tang = metal_hit(rng, 1500, 0.4, (1.0, 2.6), decay=0.3) * 0.2
    return place([(0, whack, 0.8), (0, wood), (0.01, tang)])


@sfx("coatstand_spin", max_dur=1.3, desc="the coat stand spins him like a revolving door")
def coatstand_spin(rng):
    dur = 1.2
    n = ns(dur)
    t = tt(n)
    rate = 4.6 * (1 - 0.55 * t / dur)
    ph = phase_of(rate, n)
    am = 0.5 - 0.5 * np.cos(TAU * ph)
    nz = noise_sweep(n, rng, (700 + 1500 * am), 0.9)
    evs = [(0, nz * (0.3 + 0.7 * am) * env_lin([(0, 0.4), (0.05, 1), (dur * 0.8, 0.8), (dur, 0)], n))]
    idx = np.nonzero(np.diff(np.floor(ph)) > 0)[0]
    for i in idx:
        evs.append((i / SR, creak(rng, 0.14, 40, 60, (600, 1400, 2200)), 0.35))
    return place(evs, dur)


# ----------------------------------------------------------------------------- fridge / residue

@sfx("fridge_avalanche", max_dur=1.4, desc="fridge shelf avalanche: tins, jars, a jelly")
def fridge_avalanche(rng):
    dur = 1.3
    evs = []
    tpos = 0.0
    k = 0
    while tpos < dur - 0.2:
        kind = k % 3
        if kind == 0:
            x = metal_hit(rng, rng.uniform(450, 900), 0.3, (1.0, 2.2, 3.6), decay=0.18)
        elif kind == 1:
            x = pings(rng, 0.2, 12, 2500, 6000, (0.02, 0.08), None, 0.8)
        else:
            x = pad(thump(0.15, rng.uniform(150, 220), 80), ns(0.2)) + grains(rng, 0.2, 200, 800, 3000)
        g = (1.0 - tpos / dur) ** 0.6
        evs.append((tpos, x, g))
        tpos += rng.uniform(0.035, 0.1) * (1 + tpos)
        k += 1
    return reverb(place(evs, dur), 0.12, 0.5, keep_len=True)


@sfx("jelly_splat", desc="jelly-mould helmet: splat + wobble")
def jelly_splat(rng):
    dur = 0.85
    n = ns(dur)
    t = tt(n)
    rate = 9 * (1 - 0.3 * t / dur)
    ph = phase_of(rate, n)
    f = 170 * (1 + 0.3 * np.sin(TAU * ph))
    wob = jawharp(f, 500 + 700 * (0.5 + 0.5 * np.sin(TAU * ph)), n) * perc(n, 0.02, dur)
    return pad(splat(rng, 0.45), n) + norm(wob) * 0.45


@sfx("mirror_lift", desc="lifting the glass out of the cheval mirror")
def mirror_lift(rng):
    dur = 0.7
    n = ns(dur)
    t = tt(n)
    slide = noise_sweep(n, rng, env_lin([(0, 2500), (0.5, 4000), (dur, 3500)], n), 0.5)
    squeal = sine(env_lin([(0, 1700), (0.5, 2300), (dur, 2200)], n), n) * (0.5 + 0.5 * np.sin(TAU * 17 * t))
    e = env_lin([(0, 0), (0.05, 1), (0.5, 0.8), (0.55, 0.0), (dur, 0)], n)
    ting = pad(metal_hit(rng, 2600, 0.5, (1.0, 2.76, 5.4), decay=0.4), ns(0.5))
    return place([(0, (norm(slide) * 0.5 + squeal * 0.2) * e), (0.52, ting, 0.5)], dur + 0.2)


@sfx("flour_poof", desc="POOF: a cloud of flour")
def flour_poof(rng):
    dur = 0.8
    n = ns(dur)
    x = np.linspace(0, 1, n)
    nz = noise_sweep(n, rng, 1500 * (1 - 0.65 * x), 1.8, color=-2)
    return nz * perc(n, 0.004, 0.65) + pad(thump(0.2, 170, 80), n) * 0.35


@sfx("bellows_pump", desc="the fireplace bellows: two wheezy pumps")
def bellows_pump(rng):
    def pump():
        m = ns(0.36)
        air = noise_sweep(m, rng, env_lin([(0, 600), (0.15, 1400), (0.36, 700)], m), 1.2, color=-2)
        leather = creak(rng, 0.2, 30, 40, (400, 900, 1600)) * 0.25
        return air * env_lin([(0, 0), (0.05, 1), (0.25, 0.8), (0.36, 0)], m) + pad(leather, m)
    return place([(0, pump()), (0.46, pump(), 0.9)], 0.9)


@sfx("fire_crackle", cat="ambient", max_dur=1.3, desc="fireplace crackle (ambience)")
def fire_crackle(rng):
    dur = 1.2
    n = ns(dur)
    roar = filt(pink(n, rng), ("lp", 700), ("hp", 80)) * (0.7 + 0.3 * smooth_noise(n, 3, rng))
    cr = filt(crackle(n, rng, 60), ("bp", 2200, 0.8)) * 3.0
    pops = filt(crackle(n, rng, 8), ("bp", 900, 1.5)) * 5.0
    return (norm(roar) * 0.4 + cr + pops) * env_lin([(0, 0), (0.1, 1), (dur - 0.2, 1), (dur, 0)], n)


# ----------------------------------------------------------------------------- set dressing

@sfx("specs_tink", desc="specs jammed on: a glassy TINK + glint")
def specs_tink(rng):
    t1 = metal_hit(rng, 3100, 0.35, (1.0, 2.1, 3.4), decay=0.25)
    glint = pings(rng, 0.35, 10, 5000, 9000, (0.03, 0.1), lambda x: 1 - x, 0.4)
    return place([(0, t1), (0.05, glint)])


@sfx("vase_smash", desc="the vase smashes behind him")
def vase_smash(rng):
    return reverb(_crockery(rng, 0.75), 0.2, 0.7, keep_len=True)


@sfx("window_creak", desc="the kitchen window creaks open")
def window_creak(rng):
    return creak(rng, 0.8, 16, 55, (900, 1900, 3100))


@sfx("stomp_quake", max_dur=1.0, desc="Meltdown stomp: the whole house shakes")
def stomp_quake(rng):
    n = ns(1.1)
    boom = pad(thump(0.8, 90, 32, 0.7), n)
    rattle = grains(rng, 1.1, 260, 600, 5000, (0.003, 0.015), lambda x: math.exp(-x * 3))
    crockery = pings(rng, 1.1, 40, 2500, 7000, (0.02, 0.08), lambda x: math.exp(-x * 4), 0.4)
    return drive(boom * 1.2, 1.4) + rattle * 0.6 + crockery


@sfx("picture_fall", desc="a picture falls on his head: whoosh, BONK, frame clatter")
def picture_fall(rng):
    fall = whoosh_shape(rng, 0.25, 1200, 400, 0.12, 0.8)
    bonk = woodblock_bonk(rng)
    clatter = grains(rng, 0.3, 300, 800, 4000, (0.003, 0.012), lambda x: math.exp(-x * 5))
    return place([(0, fall, 0.5), (0.22, bonk), (0.3, clatter, 0.6)])


@sfx("house_lights_dim", cat="ambient", max_dur=1.8, desc="house lights dim: a descending hum, the murmur settles")
def house_lights_dim(rng):
    dur = 1.7
    n = ns(dur)
    t = tt(n)
    f = env_lin([(0, 120), (dur, 104)], n)
    hum = sum(sine(f * k, n) * a for k, a in ((1, 1.0), (2, 0.6), (3, 0.4), (5, 0.25)))
    hum *= env_lin([(0, 0), (0.12, 1), (1.1, 0.6), (dur, 0)], n)
    murmur = filt(pink(n, rng), ("bp", 700, 0.7)) * (0.6 + 0.4 * smooth_noise(n, 9, rng))
    murmur *= env_lin([(0, 0.9), (0.7, 0.5), (1.3, 0.08), (dur, 0)], n)
    return norm(hum) * 0.5 + norm(murmur) * 0.5
