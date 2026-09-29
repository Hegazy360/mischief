"""Stealth feedback, Clarence the rubber chicken, Hush's instrument-voice and the UI set.

Hush never speaks: the pit plays her (slide-whistle take, woodblock freeze clack, a
breathy 'hff-hff' silent laugh). Clarence's squeak is the game's core comic verb, so it
gets five tuned pitches (the view picks by press), a falling wheeze and a smitten double.
"""
from __future__ import annotations

import math

import numpy as np

import instruments as I
from registry import sfx
from sfx_foley import creak, droplet, grains, metal_hit, pings, splat, thump, whoosh_shape
from synth import (SR, TAU, bell_tone, burst, env_exp, env_lin, filt, midi, noise_sweep, norm, ns, pad, perc, phase_of,
                   place, reverb, saw, sine, smooth_noise, square, sweep, tri, tt, vowel_track, voice, white)


# ----------------------------------------------------------------------------- stealth

@sfx("dive", desc="dives into a hiding spot: whoosh down + soft thump")
def dive(rng):
    air = whoosh_shape(rng, 0.3, 3500, 700, 0.1, 1.0)
    n = ns(0.3)
    cloth = filt(white(n, rng), ("bp", 900, 0.8)) * perc(n, 0.001, 0.08)
    return place([(0, air, 0.8), (0.2, pad(thump(0.18, 170, 80), n) * 0.7 + norm(cloth) * 0.4)])


@sfx("pop_out", desc="pops out of hiding: cork pop + little fwip")
def pop_out(rng):
    n = ns(0.2)
    t = tt(n)
    pop = np.sin(TAU * phase_of(480 * (1 + 1.6 * (1 - np.exp(-t / 0.01))), n)) * perc(n, 0.0005, 0.07)
    pop += burst(n, rng, 1000, 7000, 0.0001, 0.005) * 0.5
    fwip = I.slide_whistle((700, 1500), 0.14, 0.6, rng)
    return place([(0, pop), (0.05, fwip, 0.5)])


@sfx("freeze_clack", desc="FREEZE: one sharp woodblock clack")
def freeze_clack(rng):
    n = ns(0.3)
    a = I.woodblock(1420, 1.0, rng, 0.2)
    b = I.woodblock(2150, 0.35, rng, 0.1)
    return reverb(pad(a, n) + pad(b, n), 0.15, 0.35, keep_len=True)


@sfx("door_slam_bonk", max_dur=1.2, desc="Hush slams the door, he bonks into it")
def door_slam_bonk(rng):
    n = ns(0.9)
    slam = pad(thump(0.35, 150, 55), n) + norm(filt(white(n, rng), ("bp", 380, 2.0), ("lp", 2000)) * perc(n, 0.0005, 0.15)) * 0.7
    slam += grains(rng, 0.9, 120, 800, 4000, shape=lambda x: math.exp(-x * 6)) * 0.4
    bonk = I.woodblock(520, 1.0, rng, 0.3) + pad(I.woodblock(780, 0.4, rng, 0.2), ns(0.3))
    t = tt(ns(0.5))
    wob = np.sin(TAU * 240 * (1 + 0.08 * np.sin(TAU * 12 * t)) * t) * perc(ns(0.5), 0.002, 0.45)
    return reverb(place([(0, slam), (0.16, bonk), (0.18, wob, 0.4)]), 0.15, 0.45, keep_len=True)


@sfx("knocker_bonk", desc="the door knocker bonks Hush on the doorstep")
def knocker_bonk(rng):
    clonk = metal_hit(rng, 330, 0.5, (1.0, 2.2, 3.7), decay=0.3)
    bonk = I.woodblock(900, 0.9, rng, 0.25)
    return place([(0, clonk, 0.8), (0.07, bonk)])


@sfx("tomato_splat", desc="a tomato from the Stalls: juicy splat")
def tomato_splat(rng):
    y = splat(rng, 0.55, 1.2)
    seeds = place([(rng.uniform(0.03, 0.25), droplet(rng, rng.uniform(1500, 3000), 0.03), 0.2) for _ in range(8)], 0.55)
    return y + pad(seeds, len(y))


@sfx("curtain_rise", max_dur=1.4, desc="the red curtain rises: velvet swish + pulley ratchet")
def curtain_rise(rng):
    dur = 1.3
    n = ns(dur)
    swish = noise_sweep(n, rng, env_lin([(0, 300), (1.0, 1300), (dur, 900)], n), 1.4, color=-2.5)
    swish *= env_lin([(0, 0), (0.2, 0.8), (0.95, 1.0), (dur, 0)], n)
    evs = [(0, norm(swish))]
    tpos = 0.05
    while tpos < 1.0:
        m = ns(0.03)
        evs.append((tpos, filt(white(m, rng), ("bp", 1900, 4)) * perc(m, 0.0002, 0.01), 0.35))
        tpos += 0.07 + 0.03 * tpos
    evs.append((1.08, pad(thump(0.2, 150, 70), ns(0.2)), 0.35))
    return place(evs, dur)


@sfx("curtain_fall", max_dur=1.5, desc="the curtain falls: velvet whoosh + heavy soft landing")
def curtain_fall(rng):
    dur = 1.2
    n = ns(dur)
    swish = noise_sweep(n, rng, env_lin([(0, 1400), (0.8, 350), (dur, 300)], n), 1.4, color=-2.5)
    swish *= env_lin([(0, 0), (0.1, 1.0), (0.75, 0.9), (0.85, 0.2), (dur, 0)], n)
    land = pad(thump(0.35, 110, 45), ns(0.4)) + filt(white(ns(0.4), rng), ("lp", 1200)) * perc(ns(0.4), 0.002, 0.2) * 0.4
    return place([(0, norm(swish)), (0.8, land, 0.8)], dur)


@sfx("roses_thrown", max_dur=1.4, desc="roses fly from the Stalls: soft whooshes + light landings")
def roses_thrown(rng):
    evs = []
    for k in range(6):
        s = k * 0.16 + rng.uniform(0, 0.06)
        evs.append((s, whoosh_shape(rng, 0.28, 900, 3200, 0.14, 0.9), 0.5))
        m = ns(0.08)
        evs.append((s + 0.24, filt(white(m, rng), ("bp", 1500, 1.0)) * perc(m, 0.001, 0.04), 0.4))
    return place(evs, 1.3)


# ----------------------------------------------------------------------------- Clarence

CLARENCE_PITCHES = (700.0, 850.0, 1010.0, 1210.0, 1450.0)


def rubber_squeak(rng, f, dur=0.3, vowel_to="a", rise=1.35, flutter=24.0, level=1.0):
    """A rubber chicken: squeaker reed tone (rise, plateau, droop), reed flutter, a nasal
    'EEk-ak' vowel sweep and a puff of air."""
    n = ns(dur)
    t = tt(n)
    fc = env_lin([(0, f / rise), (0.035, f), (dur * 0.6, f * 1.03), (dur, f * 0.9)], n)
    fc = fc * (1 + 0.03 * np.sin(TAU * flutter * t) * np.clip(t / 0.05, 0, 1))
    reed = saw(fc, n) * 0.5 + square(fc, n, 0.3) * 0.25 + sine(fc, n)
    forms = vowel_track([(0, "i"), (dur * 0.55, "i"), (dur, vowel_to)], n, 1.9)
    honk = voice(fc, forms, np.ones(n), breath=0.0, tilt=0.7, rng=rng, jitter=0.01, buzz=0.8, max_hz=10000)
    y = norm(reed) * 0.55 + norm(honk) * 0.6
    y *= 0.82 + 0.18 * np.abs(np.sin(TAU * flutter * 0.5 * t))
    y = filt(y, ("hp", 350), ("peak", 2600, 1.5, 4.0))
    air = filt(white(n, rng), ("bp", 3500, 1.2)) * env_lin([(0, 0.6), (0.03, 0.15), (dur, 0.05)], n) * 0.12
    e = env_lin([(0, 0), (0.008, 1), (dur * 0.7, 0.9), (dur, 0)], n)
    return (y + air) * e * level


for _i, _f in enumerate(CLARENCE_PITCHES, start=1):
    def _mk(i=_i, f=_f):
        @sfx(f"clarence_squeak_{i}", bank="clarence_squeak", desc=f"Clarence squeak, pitch {i}/5 ({f:.0f} Hz)")
        def _s(rng):
            return rubber_squeak(rng, f, 0.28 + 0.01 * i)
    _mk()


@sfx("clarence_wheeze", max_dur=1.7, desc="Clarence's long squeak: a falling, deflating wheeze")
def clarence_wheeze(rng):
    dur = 1.5
    n = ns(dur)
    t = tt(n)
    f = env_exp([(0, 1000), (0.06, 1450), (0.5, 1250), (1.2, 560), (dur, 360)], n)
    f = f * (1 + (0.02 + 0.06 * t / dur) * np.sin(TAU * phase_of(9 + 5 * t, n)))
    reed = saw(f, n) * 0.5 + sine(f, n)
    forms = vowel_track([(0, "i"), (0.5, "e"), (1.1, "a"), (dur, "o")], n, 1.9)
    honk = voice(f, forms, np.ones(n), breath=0.0, tilt=0.8, rng=rng, jitter=0.02, buzz=0.7, max_hz=10000)
    leak = filt(white(n, rng), ("bp", 2500, 0.8)) * env_lin([(0, 0.05), (0.8, 0.2), (dur, 0.4)], n)
    y = norm(reed) * 0.45 + norm(honk) * 0.6 + leak * 0.35
    y = filt(y, ("hp", 250))
    phht = pad(burst(ns(0.08), rng, 800, 4000, 0.002, 0.06), n)
    e = env_lin([(0, 0), (0.01, 1), (1.0, 0.8), (1.4, 0.4), (dur, 0)], n)
    return y * e + np.roll(phht, ns(1.4)) * 0.4


@sfx("clarence_smitten", desc="Clarence, smitten: squee-SQUEE! (+ a heart ding)")
def clarence_smitten(rng):
    a = rubber_squeak(rng, 1150, 0.16, "i", rise=1.5)
    b = rubber_squeak(rng, 1500, 0.24, "i", rise=1.6)
    heart = I.celesta(midi(96), 0.3, 0.5, rng)
    return place([(0, a), (0.17, b), (0.3, heart, 0.35)])


# ----------------------------------------------------------------------------- Hush (the pit plays her)

@sfx("hush_take", desc="Hush's take: a quick slide-whistle 'whoo-ee?'")
def hush_take(rng):
    dur = 0.38
    n = ns(dur)
    f = env_lin([(0, 480), (0.14, 1350), (0.24, 1180), (dur, 1420)], n)
    return I.slide_whistle(f, dur, 0.9, rng)


@sfx("hush_snicker", cat="soft", level=-19.0, desc="Hush's silent laugh: breathy hff-hff-hff")
def hush_snicker(rng):
    dur = 0.62
    n = ns(dur)
    y = np.zeros(n)
    for k in range(4):
        s = 0.02 + k * 0.14 + rng.uniform(-0.01, 0.01)
        m = ns(0.1)
        forms = vowel_track([(0, "i"), (0.1, "e")], m, 1.25)
        puff = voice(np.full(m, 300.0), forms, np.zeros(m), breath=1.0, tilt=1.0, rng=rng,
                     breath_amp=env_lin([(0, 0), (0.01, 1), (0.1, 0)], m) * (1 - 0.15 * k))
        i = ns(s)
        y[i:i + m] += puff[: n - i]
    return y


# ----------------------------------------------------------------------------- UI

@sfx("ui_tick", cat="ui", max_dur=0.2, desc="tap tick")
def ui_tick(rng):
    return I.woodblock(2200, 0.6, rng, 0.06)


@sfx("ui_press", cat="ui", max_dur=0.3, desc="button press: soft pok")
def ui_press(rng):
    m = ns(0.1)
    t = tt(m)
    f = 780 * (1 - 0.3 * (1 - np.exp(-t / 0.012)))
    y = np.sin(TAU * phase_of(f, m)) * perc(m, 0.0008, 0.06) + burst(m, rng, 1500, 6000, 0.0001, 0.003) * 0.25
    return y + pad(thump(0.06, 260, 150), m) * 0.25


@sfx("ring_tick", cat="ui", max_dur=0.25, desc="the rig ring passes 50 %: a glassy tick")
def ring_tick(rng):
    m = ns(0.12)
    t = tt(m)
    return (np.sin(TAU * 2640 * t) * perc(m, 0.0003, 0.05) + 0.4 * np.sin(TAU * 3960 * t) * perc(m, 0.0003, 0.03)
            + burst(m, rng, 3000, 9000, 0.0001, 0.002) * 0.3)


@sfx("rig_done", cat="ui", max_dur=0.6, desc="the rig ring completes: tick-tink confirm")
def rig_done(rng):
    a = I.glock(midi(88), 0.2, 0.7, rng)[: ns(0.3)]
    b = I.glock(midi(95), 0.3, 0.9, rng)[: ns(0.45)]
    return place([(0, a), (0.07, b)])


@sfx("ui_pause", cat="ui", max_dur=0.5, desc="pause: two soft falling notes")
def ui_pause(rng):
    return place([(0, tri(midi(84), ns(0.08)) * perc(ns(0.08), 0.001, 0.07)),
                  (0.08, tri(midi(79), ns(0.14)) * perc(ns(0.14), 0.001, 0.12))])


@sfx("card_whoosh", cat="ui", max_dur=0.45, desc="a card slides in: paper whoosh")
def card_whoosh(rng):
    air = whoosh_shape(rng, 0.3, 700, 4500, 0.12, 0.9)
    flick = filt(white(ns(0.02), rng), ("bp", 3500, 1.5)) * perc(ns(0.02), 0.0002, 0.01)
    return place([(0, air), (0.25, flick, 0.4)])


# ----------------------------------------------------------------------------- flow cues

@sfx("figgis_psst", cat="ui", max_dur=0.6, desc="Old Figgis whispers from the prompt box: psst!")
def figgis_psst(rng):
    n = ns(0.5)
    p = burst(ns(0.03), rng, 600, 2600, 0.0004, 0.015)
    forms = vowel_track([(0, "schwa"), (0.06, "schwa")], ns(0.06), 1.1)
    vow = voice(np.full(ns(0.06), 180.0), forms, np.zeros(ns(0.06)), breath=1.0, rng=rng,
                breath_amp=env_lin([(0, 0), (0.01, 1), (0.06, 0.3)], ns(0.06)))
    s = filt(white(ns(0.3), rng), ("hp", 4200, 0.7), ("lp", 9500, 0.7))
    s = norm(s) * env_lin([(0, 0), (0.03, 1), (0.22, 0.8), (0.3, 0)], ns(0.3))
    t = burst(ns(0.03), rng, 3000, 8000, 0.0003, 0.01)
    return place([(0, p, 0.8), (0.02, vow, 0.5), (0.09, s, 0.6), (0.41, t, 0.5)], 0.5)


@sfx("sparkle", desc="a hint sparkle on a prop (the gramophone lever glints)")
def sparkle(rng):
    y = pings(rng, 0.7, 26, 3500, 9000, (0.03, 0.14), lambda x: 1 - x * 0.8, 0.6)
    gl = I.celesta(midi(100), 0.4, 0.4, rng)
    return reverb(place([(0, y), (0.02, gl, 0.4)], 0.8), 0.2, 0.6, keep_len=True)


@sfx("sting_drumroll", cat="sting", max_dur=1.5, tags=("keep_tail",),
     desc="the Big Number unseals: snare drum roll + cymbal")
def sting_drumroll(rng):
    evs = []
    tpos = 0.0
    while tpos < 1.0:
        v = 0.2 + 0.8 * (tpos / 1.0) ** 1.6
        evs.append((tpos, I.snare(0.09, 205, 0.85, rng), v))
        tpos += 1 / 24.0
    evs += [(1.02, I.cymbal(0.5, rng), 0.8), (1.02, I.bass_drum(0.4, 0.9, rng), 0.8)]
    return place(evs, 1.5)
