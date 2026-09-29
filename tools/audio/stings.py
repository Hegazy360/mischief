"""Musical stingers (≤ 1.5 s): the pit orchestra's punctuation. `Audio.sting(id)` plays
`sting_<id>` and ducks the music −6 dB for its length (GDD §9.5).

  rigged   ding + three rising pizzicato notes       bit       rim-shot (ba-dum-TSS)
  fizzle   tuba 'wah-waah'                           caught    sad trombone (four notes, wobbly end)
  near_miss harp glissando                           combo     brass rip into a bright chord
  new      celesta sparkle                           meltdown  timpani roll + kettle-whistle shriek
  link2/3  rising brass (two / three notes)          spot      the '?' — a rising, questioning clarinet
  alert    the '!' — brass stab + xylophone + cymbal
"""
from __future__ import annotations

import numpy as np

import instruments as I
from registry import sfx
from sfx_foley import pings, whoosh_shape
from synth import (TAU, bell_tone, burst, env_lin, filt, midi, norm, ns, pad, place, reverb, sine, tt, white)


def _sting(name: str, desc: str, max_dur: float = 1.5):
    return sfx(name, cat="sting", max_dur=max_dur, desc=desc, tags=("keep_tail",))


@_sting("sting_rigged", "rigged: ding + three rising pizzicato notes")
def sting_rigged(rng):
    ding = bell_tone(1568, 1.0, 0.8, rng) + pad(burst(ns(0.004), rng, 3000, 9000), ns(1.0)) * 0.2
    notes = [(0.16, 79), (0.27, 83), (0.38, 88)]
    evs = [(0, ding, 0.55)] + [(s, I.pizz(midi(m), 0.3, 0.9, rng, bright=0.55, ring=0.3), 0.8) for s, m in notes]
    return reverb(place(evs, 1.2), 0.18, 0.7, keep_len=True)


@_sting("sting_bit", "squeak bit: rim-shot ba-dum-TSS")
def sting_bit(rng):
    return reverb(place([(0, I.tom(210, 0.25, rng), 0.7), (0.13, I.tom(150, 0.3, rng), 0.75),
                         (0.28, I.kick(0.35, 120, 45, 0.2, rng), 0.8), (0.28, I.snare(0.2, 200, 0.8, rng), 0.7),
                         (0.28, I.cymbal(1.1, rng), 0.55)], 1.3), 0.12, 0.6, keep_len=True)


@_sting("sting_fizzle", "fizzle: tuba wah-waah")
def sting_fizzle(rng):
    evs = []
    for s, d, p in ((0.0, 0.3, 46), (0.36, 0.75, 45)):
        n = ns(d + 0.1)
        t = tt(n)
        wah = env_lin([(0, 250), (0.12, 900), (d * 0.8, 700), (d + 0.1, 300)], n)
        f = midi(p) * (1 - 0.04 * t / max(d, 0.1)) if d > 0.5 else midi(p)
        x = I.trombone(f, d, 0.95, rng, wah=wah, vib=0.0)
        tb = I.tuba(midi(p - 12), d, 0.7, rng)
        m = max(len(x), len(tb))
        evs.append((s, pad(tb, m) * 0.6 + pad(x, m), 1.0))
    return reverb(place(evs, 1.3), 0.12, 0.5, keep_len=True)


@_sting("sting_caught", "caught: sad trombone wah wah wah waaah")
def sting_caught(rng):
    notes = [(0.0, 0.26, 62), (0.3, 0.26, 61), (0.6, 0.26, 60), (0.9, 0.55, 59)]
    y = np.zeros(ns(1.5))
    for i, (s, d, p) in enumerate(notes):
        f = midi(p - 12)
        n = ns(d + 0.12)
        t = tt(n)
        fc = f
        wah = env_lin([(0, 400), (0.08, 1500), (d * 0.8, 1200), (d + 0.12, 500)], n)
        if i == 3:
            fc = f * (1 + 0.035 * np.sin(TAU * 6.0 * t) * np.clip((t - 0.1) / 0.15, 0, 1)) * (1 - 0.02 * t)
            wah = 900 + 700 * (0.5 + 0.5 * np.sin(TAU * 3.0 * t - 1.5))
        x = I.trombone(fc, d, 0.9, rng, release=0.1, wah=wah, vib=0.0)
        i0 = ns(s)
        y[i0:i0 + len(x)] += x[: len(y) - i0]
    return reverb(norm(y), 0.15, 0.6, keep_len=True)


@_sting("sting_near_miss", "near miss: harp glissando (relief)")
def sting_near_miss(rng):
    notes = [60, 62, 64, 67, 69, 72, 74, 76, 79, 81, 84, 86, 88, 91]
    y = I.seq([(i * 0.04, 0.8, p, 0.75 + 0.015 * i) for i, p in enumerate(notes)],
              lambda f, d, v: I.harp(f, 0.9, v, rng))
    return reverb(y, 0.3, 1.0, keep_len=True)


@_sting("sting_combo", "combo: brass rip into a bright chord")
def sting_combo(rng):
    rip = I.trumpet(np.geomspace(midi(64), midi(76), ns(0.12)), 0.12, 0.8, rng, vib=0.0)
    chord = sum(pad(I.trumpet(midi(p), 0.55, 0.95, rng), ns(0.8)) for p in (72, 76, 79, 84))
    chord += sum(pad(I.trombone(midi(p), 0.55, 0.9, rng), ns(0.8)) for p in (48, 60))
    hit = place([(0, I.kick(0.4), 0.8), (0, I.cymbal(1.2, rng), 0.5), (0, chord, 0.35)])
    return reverb(place([(0, rip, 0.5), (0.12, hit)], 1.4), 0.2, 0.8, keep_len=True)


@_sting("sting_new", "+NEW!: celesta sparkle")
def sting_new(rng):
    y = I.seq([(i * 0.065, 0.5, p, 0.7 + 0.05 * i) for i, p in enumerate((84, 88, 91, 96, 100))],
              lambda f, d, v: I.celesta(f, 0.9, v, rng))
    sp = pings(rng, 1.0, 26, 4000, 9000, (0.03, 0.12), lambda x: 1 - x, 0.25)
    return reverb(place([(0, y), (0.1, sp)], 1.3), 0.3, 0.9, keep_len=True)


@_sting("sting_meltdown", "MELTDOWN: timpani roll + kettle-whistle shriek")
def sting_meltdown(rng):
    roll = I.timp_roll(midi(40), 0.85, 0.25, 1.0, rng, accent=True)
    n = ns(1.2)
    t = tt(n)
    f = env_lin([(0, 1400), (0.8, 3300), (1.2, 3500)], n) * (1 + 0.01 * np.sin(TAU * 7 * t))
    whistle = sine(f, n) + 0.25 * sine(2 * f, n)
    whistle += filt(white(n, rng), ("bp", 3000, 1.5)) * 0.3
    whistle *= env_lin([(0, 0), (0.2, 0.4), (0.85, 1.0), (1.2, 0)], n)
    return place([(0, roll), (0.05, whistle, 0.28)], 1.5)


@_sting("sting_link2", "Running Gag link 2: rising brass pair")
def sting_link2(rng):
    a = sum(pad(I.trumpet(midi(p), 0.14, 0.9, rng), ns(0.3)) for p in (67, 71))
    b = sum(pad(I.trumpet(midi(p), 0.45, 1.0, rng), ns(0.7)) for p in (72, 76))
    return reverb(place([(0, a, 0.6), (0.16, b, 0.6), (0.16, I.cymbal(0.9, rng), 0.3)], 1.0), 0.18, 0.7,
                  keep_len=True)


@_sting("sting_link3", "Running Gag link 3+: rising brass triple, up to a held high chord")
def sting_link3(rng):
    parts = []
    for i, (s, d, ps) in enumerate(((0.0, 0.12, (67, 71)), (0.14, 0.12, (72, 76)), (0.28, 0.7, (79, 84, 88)))):
        c = sum(pad(I.trumpet(midi(p), d, 0.95, rng), ns(d + 0.3)) for p in ps)
        parts.append((s, c, 0.55))
    parts += [(0.28, I.timpani(midi(43), 1.0, 0.9, rng), 0.6), (0.28, I.cymbal(1.2, rng), 0.45)]
    return reverb(place(parts, 1.4), 0.2, 0.8, keep_len=True)


@_sting("sting_spot", "the '?': a rising, questioning clarinet over a pizz", max_dur=1.0)
def sting_spot(rng):
    n = ns(0.62)
    f = np.concatenate([np.full(ns(0.22), midi(59)), np.geomspace(midi(59), midi(66), ns(0.4))])[:n]
    cl = I.clarinet(f, 0.55, 0.8, rng)
    pz = I.pizz(midi(40), 0.4, 0.9, rng)
    trem = I.bowed(midi(71), 0.55, 0.35, rng, trem_hz=14, attack=0.1, pont=0.6)
    return reverb(place([(0, pz, 0.8), (0.02, cl), (0.1, trem, 0.4)], 0.9), 0.2, 0.6, keep_len=True)


@_sting("sting_alert", "the '!': brass stab + xylophone + cymbal", max_dur=1.0)
def sting_alert(rng):
    stab = sum(pad(I.trumpet(midi(p), 0.22, 1.0, rng, vib=0.0), ns(0.5)) for p in (70, 73, 76, 79))
    low = sum(pad(I.trombone(midi(p), 0.22, 1.0, rng, vib=0.0), ns(0.5)) for p in (46, 58))
    xy = I.xylo(midi(91), 0.3, 1.0, rng)
    return reverb(place([(0, stab, 0.35), (0, low, 0.35), (0, xy, 0.6), (0, I.cymbal(0.7, rng), 0.45),
                         (0, I.kick(0.3), 0.6)], 0.9), 0.15, 0.5, keep_len=True)
