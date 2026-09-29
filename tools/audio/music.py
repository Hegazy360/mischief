"""The pit orchestra: adaptive music for a stage farce (GDD §9.5).

  mus_sneak      E minor, 128 bpm, 32 bars (60 s): sparse pizzicato — bass on 1 and 3, a sly
                 clarinet tune, a comic bassoon, tiptoe pizz — near-silent between beats
  mus_suspense   the same tempo, 4 bars (7.5 s) over an E–B pedal: tremolo strings, a ticking
                 clock and a timpani heartbeat; plays on top of mus_sneak through
                 AudioStreamSynchronized and loops exactly 8× per sneak loop, bar-aligned
  mus_chase      after Offenbach's Galop infernal: C major 2/4, 168 bpm, 16 bars
  mus_chain_1..4 Grieg's In the Hall of the Mountain King at stepped tempos 120 / 140 / 168 /
                 210 bpm — the 8-bar theme for section 1, then the 4-bar ostinato as it speeds
                 up: creeping bassoon + pizz → + clarinet → + brass and snare → full climax.
                 The autoload switches sections on the bar line.
  mus_curtain    a 4 s overture sting (timpani roll, fanfare, title slam) — one-shot
  mus_results    a 20 s curtain-call waltz loop (F major 3/4, 180 bpm)

Loops are rendered circularly (a note or reverb tail that runs past the end wraps to the
start) and every tempo has a whole number of samples per beat, so loops and bar lines are
sample-exact. All compositions are public domain; every note is rendered by our synth.
"""
from __future__ import annotations

import numpy as np

import instruments as I
from synth import (SR, _box, _max_filter, _min_filter, convolve, env_lin, filt, limit, make_ir, midi, ns, weighted)

# file id → timing, written into sfx_map.json "music" (the autoload's bar maths use it)
META: dict[str, dict] = {
    "mus_sneak": {"bpm": 127.995, "beats_per_bar": 4, "bars": 32, "spb": 10336, "loop": True},
    "mus_suspense": {"bpm": 127.995, "beats_per_bar": 4, "bars": 4, "spb": 10336, "loop": True},
    "mus_chase": {"bpm": 168.0, "beats_per_bar": 2, "bars": 16, "spb": 7875, "loop": True},
    "mus_chain_1": {"bpm": 120.0, "beats_per_bar": 4, "bars": 8, "spb": 11025, "loop": True},
    "mus_chain_2": {"bpm": 140.0, "beats_per_bar": 4, "bars": 4, "spb": 9450, "loop": True},
    "mus_chain_3": {"bpm": 168.0, "beats_per_bar": 4, "bars": 4, "spb": 7875, "loop": True},
    "mus_chain_4": {"bpm": 210.0, "beats_per_bar": 4, "bars": 4, "spb": 6300, "loop": True},
    "mus_curtain": {"bpm": 120.0, "beats_per_bar": 4, "bars": 2, "spb": 11025, "loop": False},
    "mus_results": {"bpm": 180.0, "beats_per_bar": 3, "bars": 20, "spb": 7350, "loop": True},
}
# synchronized sets: music state → [base stem, layers...]; a layer may be shorter if it divides the base
STEM_SETS: dict[str, list[str]] = {"sneak": ["mus_sneak", "mus_suspense"]}


class Loop:
    """A circular multitrack buffer on a sample-exact beat grid."""

    def __init__(self, spb: int, beats: int, seed: int, circular: bool = True, tail: float = 0.0):
        self.spb = spb
        self.beats = beats
        self.circular = circular
        self.n = spb * beats + (0 if circular else ns(tail))
        self.buses: dict[str, np.ndarray] = {}
        self.rng = np.random.default_rng(seed)

    def add(self, bus: str, sig: np.ndarray, beat: float, gain: float = 1.0, human: float = 0.003) -> None:
        buf = self.buses.setdefault(bus, np.zeros(self.n))
        start = int(round(beat * self.spb + self.rng.normal(0, human) * SR))
        x = np.asarray(sig, float) * gain
        if not self.circular:
            start = max(0, start)
            m = min(len(x), self.n - start)
            if m > 0:
                buf[start:start + m] += x[:m]
            return
        start %= self.n
        pos = 0
        while pos < len(x):
            i = (start + pos) % self.n
            m = min(len(x) - pos, self.n - i)
            buf[i:i + m] += x[pos:pos + m]
            pos += m

    def bus(self, name: str) -> np.ndarray:
        return self.buses.get(name, np.zeros(self.n))

    def sec(self, beats: float) -> float:
        return beats * self.spb / SR


def cfilt(x, *stages, circular=True):
    return filt(x, *stages, circular=circular)


def creverb(x, rt60=1.2, tone=4500, seed=3, circular=True):
    ir = make_ir(min(rt60 * 1.3 + 0.05, 3.0), rt60, tone, seed=seed)
    if circular:
        return convolve(x, ir, circular=True)
    return convolve(x, ir)[: len(x)]


def master(x: np.ndarray, rms_db: float, ceiling_db: float = -1.2, circular: bool = True) -> np.ndarray:
    """Loudness-match on the phone-weighted signal, a touch of glue, a seam-safe limiter."""
    x = filt(x, ("hp", 40.0, 0.7), circular=circular)
    w = weighted(x, circular=circular)
    r = np.sqrt(np.mean(w * w)) + 1e-12
    x = x * (10 ** (rms_db / 20) / r)
    x = np.tanh(x * 1.1) / 1.1 * 0.3 + x * 0.7
    return limit(x, 10 ** (ceiling_db / 20), 0.004, circular=circular)


def note(fn, f, dur, vel, rng, stacc: float = 1.0):
    """Render a note and cut it after `dur × stacc` (a finger lifted / a bow stopped)."""
    x = fn(f, dur * stacc, vel, rng)
    return x


# =============================================================================== SNEAK + SUSPENSE

SNEAK_HARM = [  # per bar of the 8-bar cycle: [(beat, root, fifth, chord tones)]
    [(0, 40, 47, (52, 55, 59))], [(0, 40, 47, (52, 55, 59))], [(0, 45, 52, (57, 60, 64))],
    [(0, 47, 54, (51, 54, 57, 59))], [(0, 40, 47, (52, 55, 59))], [(0, 48, 43, (55, 60, 64))],
    [(0, 45, 52, (57, 60, 64)), (2, 47, 54, (51, 54, 57, 59))], [(0, 40, 47, (52, 55, 59))],
]
# the sly tune (bar-in-cycle, beat, beats, midi) — clarinet in cycle 2, bassoon −12 in 3, pizz +12 in 4
SNEAK_TUNE = [
    (0, 0, 0.5, 52), (0, 0.5, 0.5, 55), (0, 1, 1, 59), (0, 2.5, 0.5, 58), (0, 3, 1, 59),
    (1, 0, 0.5, 60), (1, 0.5, 0.5, 59), (1, 1, 0.5, 58), (1, 1.5, 0.5, 59), (1, 2, 1.5, 55),
    (2, 0, 0.5, 57), (2, 0.5, 0.5, 60), (2, 1, 1, 64), (2, 2.5, 0.5, 63), (2, 3, 1, 64),
    (3, 0, 0.5, 66), (3, 0.5, 0.5, 64), (3, 1, 0.5, 63), (3, 1.5, 0.5, 60), (3, 2, 1, 59), (3, 3, 1, 57),
    (4, 0, 0.5, 55), (4, 0.5, 0.5, 59), (4, 1, 1, 64), (4, 2.5, 0.5, 62), (4, 3, 1, 64),
    (5, 0, 1.5, 67), (5, 1.5, 0.5, 64), (5, 2, 1, 60), (5, 3, 1, 55),
    (6, 0, 0.5, 57), (6, 0.5, 0.5, 60), (6, 1, 0.5, 64), (6, 1.5, 0.5, 60), (6, 2, 0.5, 59), (6, 2.5, 0.5, 63),
    (6, 3, 0.5, 66), (6, 3.5, 0.5, 63),
    (7, 0, 1, 64), (7, 1, 0.5, 59), (7, 1.5, 0.5, 55), (7, 2, 1, 52),
]


def _chord_at(bar_in_cycle: int, beat: float):
    slots = SNEAK_HARM[bar_in_cycle]
    return [s for s in slots if s[0] <= beat][-1]


def render_sneak() -> list:
    meta = META["mus_sneak"]
    L = Loop(meta["spb"], meta["bars"] * 4, seed=101)
    rng = L.rng
    for bar in range(meta["bars"]):
        cyc, b = divmod(bar, 8)
        # bass pizz: 1 and 3 (a walking line in the bassoon cycle)
        if cyc == 2:
            for beat in range(4):
                _, root, fifth, tones = _chord_at(b, beat)
                p = (root, root + 3 if root in (40, 45) else root + 4, fifth, fifth - 1)[beat]
                L.add("bass", I.pizz(midi(p), 0.35, 0.8 if beat % 2 == 0 else 0.6, rng, ring=0.3), bar * 4 + beat)
        else:
            for beat in (0, 2):
                _, root, fifth, _t = _chord_at(b, beat)
                L.add("bass", I.pizz(midi(root if beat == 0 else fifth), 0.4, 0.85 if beat == 0 else 0.7, rng,
                                     ring=0.32), bar * 4 + beat)
        # tiptoe plinks: high pizz pairs on 4& of even bars (cycles 1 and 3)
        if cyc in (0, 2) and b % 2 == 1:
            _, _, _, tones = _chord_at(b, 3)
            hi = [t + 24 for t in tones[-2:]]
            L.add("pizz", I.pizz(midi(hi[0]), 0.2, 0.55, rng, bright=0.55, ring=0.18), bar * 4 + 3.5)
            L.add("pizz", I.pizz(midi(hi[1]), 0.2, 0.5, rng, bright=0.55, ring=0.18), bar * 4 + 3.75)
        # chromatic creep into the next cycle
        if b == 7:
            for k, p in enumerate((59, 60, 61, 63)):
                L.add("pizz", I.pizz(midi(p), 0.18, 0.45 + 0.08 * k, rng, bright=0.5, ring=0.15),
                      bar * 4 + 3 + k * 0.25)
        # phrase-end woodblock and a soft off-beat chord in cycle 4
        if b == 7:
            L.add("perc", I.woodblock(760, 0.35, rng), bar * 4 + 2.5)
        if cyc == 3 and b % 2 == 0:
            _, _, _, tones = _chord_at(b, 1)
            for k, p in enumerate(tones[:3]):
                L.add("pizz", I.pizz(midi(p + 12), 0.25, 0.3, rng, ring=0.2), bar * 4 + 1.5 + k * 0.01)
    for bb, beat, d, p in SNEAK_TUNE:
        # cycle 2: clarinet
        L.add("clar", I.clarinet(midi(p), L.sec(d) * (0.55 if d <= 0.5 else 0.7), 0.5, rng), (8 + bb) * 4 + beat)
        # cycle 3: bassoon, an octave down, staccato and comic
        L.add("bsn", I.bassoon(midi(p - 12), L.sec(d) * (0.5 if d <= 0.5 else 0.7), 0.6, rng),
              (16 + bb) * 4 + beat)
        # cycle 4: tiptoe pizzicato an octave up, the clarinet shadowing long notes
        L.add("pizz", I.pizz(midi(p + 12), 0.3, 0.55, rng, bright=0.5, ring=0.22), (24 + bb) * 4 + beat)
        if d >= 1.5:
            L.add("clar", I.clarinet(midi(p), L.sec(d) * 0.6, 0.3, rng), (24 + bb) * 4 + beat)
    # a single glassy plink at the top of cycles 2 and 4
    for bar in (8, 24):
        L.add("perc", I.celesta(midi(88), 1.0, 0.3, rng), bar * 4)
    bass = cfilt(L.bus("bass"), ("hp", 45), ("peak", 120, 1.0, 2.0))
    pizz = cfilt(L.bus("pizz"), ("hp", 180))
    clar = cfilt(L.bus("clar"), ("hp", 150))
    bsn = cfilt(L.bus("bsn"), ("hp", 60))
    perc = L.bus("perc")
    dry = bass * 1.0 + pizz * 0.8 + clar * 0.7 + bsn * 0.75 + perc * 0.6
    wet = creverb(pizz * 0.6 + clar + bsn * 0.6 + bass * 0.3 + perc, 1.1, 4200, seed=102) * 0.16
    x = master(dry + wet, -21.0)
    return [("mus_sneak", x, meta)]


def render_suspense() -> list:
    """4 bars over an E–B pedal (it fits every chord of the sneak cycle, and the major
    seventh over C is exactly the tension we want): violins and cellos in tremolo, the
    clock ticking on every beat, a timpani heartbeat, a chromatic viola creep in bar 4."""
    meta = META["mus_suspense"]
    L = Loop(meta["spb"], meta["bars"] * 4, seed=111)
    rng = L.rng
    bars = meta["bars"]
    for bar in range(bars):
        swell = 0.55 + 0.2 * (bar % 2) + (0.15 if bar == bars - 1 else 0.0)
        for p in (71, 76):
            L.add("trem", I.bowed(midi(p), L.sec(4) + 0.05, swell, rng, trem_hz=14.5, attack=0.12, release=0.08,
                                  section=2, bright=0.6, pont=0.5), bar * 4, 0.5, human=0)
        L.add("cello", I.bowed(midi(52), L.sec(4) + 0.05, 0.6, rng, trem_hz=12.0, attack=0.1, release=0.08,
                               section=2, bright=0.4), bar * 4, 0.45, human=0)
        for bt in ((0, 2) if bar == bars - 1 else (0,)):
            L.add("timp", I.timpani(midi(40), 0.8, 0.6, rng), bar * 4 + bt)
            L.add("timp", I.timpani(midi(40), 0.6, 0.4, rng), bar * 4 + bt + 0.4)
        for bt in range(4):
            L.add("clock", I.woodblock(2500 if bt % 2 == 0 else 1850, 0.5, rng, 0.08), bar * 4 + bt, human=0.0)
    for k, p in enumerate((64, 65, 66, 67)):
        L.add("trem", I.bowed(midi(p), L.sec(1.0), 0.35 + 0.08 * k, rng, trem_hz=15, section=2, bright=0.5, pont=0.4),
              (bars - 1) * 4 + k, 0.4, human=0)
    trem = cfilt(L.bus("trem"), ("hp", 200))
    cello = cfilt(L.bus("cello"), ("hp", 70))
    timp = cfilt(L.bus("timp"), ("hp", 40), ("lp", 1500))
    clock = cfilt(L.bus("clock"), ("hp", 600))
    dry = trem * 0.8 + cello * 0.7 + timp * 0.9 + clock * 0.35
    wet = creverb(trem + cello * 0.5 + clock * 0.4, 1.4, 4000, seed=112) * 0.25
    x = master(dry + wet, -21.0)
    return [("mus_suspense", x, meta)]


def render_sneak_set() -> list:
    """Both stems, then the suspense layer is trimmed so the synced sum stays ≤ −1 dBFS."""
    (sid, s, smeta), = render_sneak()
    (uid, u, umeta), = render_suspense()
    reps = len(s) // len(u)
    tot = s + np.tile(u, reps)
    pk = float(np.max(np.abs(tot)))
    lim = 10 ** (-1.3 / 20)
    if pk > lim:
        u = u * max(0.3, (lim - float(np.max(np.abs(s)))) / max(float(np.max(np.abs(u))), 1e-9))
    return [(sid, s, smeta), (uid, u, umeta)]


# =============================================================================== CHASE (Galop)

GALOP = [  # (bar, beat, beats, midi) in 2/4
    (0, 0, 2, 79),
    (1, 0, .5, 79), (1, .5, .5, 81), (1, 1, .5, 79), (1, 1.5, .5, 84),
    (2, 0, .5, 83), (2, .5, .5, 86), (2, 1, .5, 84), (2, 1.5, .5, 88),
    (3, 0, .5, 88), (3, .5, .5, 89), (3, 1, .5, 88), (3, 1.5, .5, 86),
    (4, 0, .5, 86), (4, .5, .5, 91), (4, 1, .5, 89), (4, 1.5, .5, 88),
    (5, 0, .5, 88), (5, .5, .5, 93), (5, 1, .5, 91), (5, 1.5, .5, 89),
    (6, 0, .5, 89), (6, .5, .5, 88), (6, 1, .5, 86), (6, 1.5, .5, 84),
    (7, 0, .5, 83), (7, .5, .5, 84), (7, 1, .5, 86), (7, 1.5, .5, 79),
]
GALOP_B_END = [(14, 0, .5, 89), (14, .5, .5, 86), (14, 1, .5, 83), (14, 1.5, .5, 79),
               (15, 0, .5, 84), (15, .5, .5, 72)]
GALOP_HARM = ["C", "C", "G7", "C", "G7", "C", "G7", "G7", "C", "C", "G7", "C", "G7", "C", "G7", "C"]
CHORDS = {"C": (36, 43, (60, 64, 67)), "G7": (43, 38, (59, 62, 65))}


def render_chase() -> list:
    meta = META["mus_chase"]
    L = Loop(meta["spb"], meta["bars"] * 2, seed=121)
    rng = L.rng
    tune = [(b, bt, d, p) for (b, bt, d, p) in GALOP] + [(b + 8, bt, d, p) for (b, bt, d, p) in GALOP if b < 6] \
        + GALOP_B_END
    for bar, beat, d, p in tune:
        L.add("lead", I.flute(midi(p), L.sec(d) * 0.75, 0.8, rng, piccolo=True), bar * 2 + beat)
        L.add("clar", I.clarinet(midi(p - 12), L.sec(d) * 0.75, 0.7, rng), bar * 2 + beat)
        if bar >= 8:
            L.add("tpt", I.trumpet(midi(p - 12), L.sec(d) * 0.7, 0.8, rng, vib=0.0), bar * 2 + beat)
    for bar in range(16):
        root, fifth, tones = CHORDS[GALOP_HARM[bar]]
        L.add("tuba", I.tuba(midi(root), L.sec(0.4), 0.95, rng), bar * 2)
        L.add("tuba", I.tuba(midi(fifth), L.sec(0.4), 0.85, rng), bar * 2 + 1)
        for off in (0.5, 1.5):
            for k, p in enumerate(tones):
                L.add("oom", I.pizz(midi(p), 0.18, 0.55, rng, bright=0.6, ring=0.12), bar * 2 + off + k * 0.004)
                L.add("oom", I.trombone(midi(p - 12), L.sec(0.18), 0.6, rng, vib=0.0), bar * 2 + off, 0.25)
        for e in range(4):
            L.add("drums", I.snare(0.1, 210, 0.8, rng), bar * 2 + e * 0.5, 0.35 if e % 2 else 0.2)
        L.add("drums", I.bass_drum(0.5, 0.8, rng), bar * 2, 0.6)
        for s16 in range(8):
            L.add("wood", I.woodblock(1150 if s16 % 2 else 900, 0.3, rng, 0.06), bar * 2 + s16 * 0.25, 0.4)
    for bar in (0, 8):
        L.add("drums", I.cymbal(1.4, rng), bar * 2, 0.35)
    for k in range(4):
        L.add("drums", I.snare(0.12, 220, 0.85, rng), 31 + k * 0.25, 0.3 + 0.1 * k)
    lead = cfilt(L.bus("lead"), ("hp", 400))
    clar = cfilt(L.bus("clar"), ("hp", 180))
    tpt = cfilt(L.bus("tpt"), ("hp", 200))
    tuba = cfilt(L.bus("tuba"), ("hp", 40), ("lp", 2500))
    oom = cfilt(L.bus("oom"), ("hp", 150))
    drums = L.bus("drums")
    wood = cfilt(L.bus("wood"), ("hp", 500))
    dry = lead * 0.8 + clar * 0.6 + tpt * 0.55 + tuba * 0.7 + oom * 0.8 + drums * 0.8 + wood * 0.25
    wet = creverb(lead * 0.5 + clar * 0.5 + tpt * 0.5 + oom * 0.4, 1.0, 5000, seed=122) * 0.22
    return [("mus_chase", master(dry + wet, -16.0), meta)]


# =============================================================================== CHAIN (Mountain King)

KING = [  # (bar, beat, beats, midi) — the theme in B minor at bassoon pitch
    (0, 0, 1, 47), (0, 1, 1, 49), (0, 2, 1, 50), (0, 3, 1, 52),
    (1, 0, 1, 54), (1, 1, 1, 50), (1, 2, 2, 54),
    (2, 0, 1, 53), (2, 1, 1, 49), (2, 2, 2, 53),
    (3, 0, 1, 52), (3, 1, 1, 48), (3, 2, 2, 52),
    (4, 0, 1, 47), (4, 1, 1, 49), (4, 2, 1, 50), (4, 3, 1, 52),
    (5, 0, 1, 54), (5, 1, 1, 50), (5, 2, 1, 54), (5, 3, 1, 59),
    (6, 0, 1, 57), (6, 1, 1, 54), (6, 2, 1, 50), (6, 3, 1, 54),
    (7, 0, 4, 57),
]
KING_HARM = [(47, (59, 62, 66)), (47, (59, 62, 66)), (49, (61, 65, 68, 71)), (48, (60, 64, 67)),
             (47, (59, 62, 66)), (47, (59, 62, 66)), (50, (62, 66, 69)), (45, (61, 64, 69))]


def render_chain(section: int) -> list:
    key = f"mus_chain_{section}"
    meta = META[key]
    L = Loop(meta["spb"], meta["bars"] * 4, seed=130 + section)
    rng = L.rng
    stac = (0.62, 0.55, 0.5, 0.55)[section - 1]
    bars = meta["bars"]
    for bar, beat, d, p in KING:
        if bar >= bars:
            continue
        dd = L.sec(d) * (stac if d < 2 else 0.85)
        L.add("bsn", I.bassoon(midi(p), dd, 0.75 + 0.05 * section, rng, attack=0.02), bar * 4 + beat)
        L.add("pizz", I.pizz(midi(p - 12), 0.35, 0.75, rng, ring=0.3), bar * 4 + beat)
        if section >= 2:
            L.add("clar", I.clarinet(midi(p + 12), dd, 0.7, rng), bar * 4 + beat)
        if section >= 3:
            L.add("brass", I.trombone(midi(p), dd, 0.85, rng, vib=0.0), bar * 4 + beat)
            L.add("brass", I.tuba(midi(p - 12), dd, 0.85, rng), bar * 4 + beat)
        if section >= 4:
            L.add("lead", I.trumpet(midi(p + 12), dd, 0.95, rng, vib=0.0), bar * 4 + beat)
            L.add("lead", I.flute(midi(p + 36), dd, 0.8, rng, piccolo=True), bar * 4 + beat)
            L.add("str", I.bowed(midi(p + 24), dd + 0.05, 0.8, rng, attack=0.01, release=0.05, bright=0.9),
                  bar * 4 + beat)
    for bar in range(bars):
        root, tones = KING_HARM[bar]
        # horn pedal on F# (sections 1-2), timpani on 1 (and 3 from section 2)
        if section <= 2:
            L.add("horn", I.horn(midi(54), L.sec(4) + 0.05, 0.35, rng, release=0.08), bar * 4, human=0)
        for bt in ((0,) if section == 1 else (0, 2) if section == 2 else (0, 1, 2, 3)):
            L.add("timp", I.timpani(midi(42 if bt % 2 else 35 + 12), 0.9, 0.55 + 0.1 * section, rng), bar * 4 + bt)
        if section >= 2:
            for bt in (1, 3):
                for k, p in enumerate(tones[:3]):
                    L.add("chord", I.pizz(midi(p), 0.2, 0.5, rng, ring=0.15), bar * 4 + bt + k * 0.004)
        if section >= 3:
            for e in range(8):
                L.add("drums", I.snare(0.1, 205, 0.8, rng), bar * 4 + e * 0.5, 0.18 + (0.12 if e % 2 else 0.0))
            for bt in (0, 2) if section == 3 else (0, 1, 2, 3):
                L.add("drums", I.bass_drum(0.5, 0.9, rng), bar * 4 + bt, 0.55)
            for bt in (1, 3):
                for p in tones[:3]:
                    L.add("stab", I.trumpet(midi(p + 12), L.sec(0.22), 0.7, rng, vib=0.0), bar * 4 + bt + 0.5, 0.2)
        if section >= 4:
            for e in range(8):
                L.add("timp", I.timpani(midi(35 + 12 if e % 2 == 0 else 42), 0.4, 0.7, rng), bar * 4 + e * 0.5, 0.45)
    if section >= 3:
        for bar in ((0,) if section == 3 else (0, 2)):
            L.add("drums", I.cymbal(1.3, rng), bar * 4, 0.3)
    buses = {k: L.bus(k) for k in ("bsn", "pizz", "clar", "brass", "lead", "str", "horn", "timp", "chord", "drums", "stab")}
    dry = (cfilt(buses["bsn"], ("hp", 50)) * 0.9 + cfilt(buses["pizz"], ("hp", 40)) * 0.7
           + cfilt(buses["clar"], ("hp", 150)) * 0.6 + cfilt(buses["brass"], ("hp", 40)) * 0.6
           + cfilt(buses["lead"], ("hp", 300)) * 0.6 + cfilt(buses["str"], ("hp", 200)) * 0.5
           + buses["horn"] * 0.5 + cfilt(buses["timp"], ("hp", 40)) * 0.7 + buses["chord"] * 0.5
           + buses["drums"] * 0.7 + cfilt(buses["stab"], ("hp", 250)) * 0.5)
    wet = creverb(dry, 1.2, 4500, seed=140 + section) * 0.2
    target = (-19.0, -18.0, -16.5, -15.0)[section - 1]
    return [(key, master(dry + wet, target), meta)]


# =============================================================================== CURTAIN (one-shot)

def render_curtain() -> list:
    meta = META["mus_curtain"]
    L = Loop(meta["spb"], meta["bars"] * 4, seed=151, circular=False)
    rng = L.rng
    b = lambda s: s * SR / meta["spb"]   # noqa: E731  seconds → beats
    L.add("timp", I.timp_roll(midi(43), 1.1, 0.15, 1.0, rng, accent=False), 0)
    for k in range(int(1.1 * 20)):
        L.add("snare", I.snare(0.08, 210, 0.85, rng), b(k / 20.0), 0.08 + 0.3 * (k / 22.0) ** 1.5, human=0)
    for i, s in enumerate((1.1, 1.2, 1.3)):
        for p in (67, 72):
            L.add("brass", I.trumpet(midi(p), 0.08, 0.95, rng, vib=0.0), b(s), 0.4)
    for p in (72, 76, 79, 84):
        L.add("brass", I.trumpet(midi(p), 1.3, 1.0, rng), b(1.42), 0.35)
    for p in (48, 55, 64):
        L.add("brass", I.trombone(midi(p), 1.3, 0.95, rng), b(1.42), 0.35)
    L.add("brass", I.tuba(midi(36), 1.3, 0.95, rng), b(1.42), 0.6)
    for p in (72, 76, 79):
        L.add("str", I.bowed(midi(p), 1.3, 0.7, rng, trem_hz=15, attack=0.03), b(1.42), 0.4)
    L.add("hit", I.cymbal(2.0, rng), b(1.42), 0.45)
    L.add("hit", I.timpani(midi(36), 1.4, 1.0, rng), b(1.42), 0.8)
    harp = I.seq([(i * 0.035, 0.6, p, 0.8) for i, p in enumerate((60, 64, 67, 72, 76, 79, 84, 88, 91, 96))],
                 lambda f, d, v: I.harp(f, 0.8, v, rng))
    L.add("str", harp, b(1.6), 0.5)
    # the title slam
    for p in (48, 60, 64, 67, 72, 76):
        L.add("brass", I.trumpet(midi(p + 12), 0.25, 1.0, rng, vib=0.0) if p >= 60 else
              I.trombone(midi(p), 0.25, 1.0, rng, vib=0.0), b(2.9), 0.4)
    L.add("hit", I.bass_drum(1.0, 1.0, rng), b(2.9), 1.0)
    L.add("hit", I.timpani(midi(36), 1.1, 1.0, rng), b(2.9), 0.9)
    L.add("hit", I.cymbal(1.2, rng), b(2.9), 0.5)
    dry = (L.bus("timp") * 0.8 + L.bus("snare") * 0.6 + cfilt(L.bus("brass"), ("hp", 60), circular=False) * 0.8
           + L.bus("str") * 0.6 + L.bus("hit") * 0.8)
    wet = creverb(dry, 1.6, 4500, seed=152, circular=False) * 0.25
    x = dry + wet
    x = x * env_lin([(0, 1), (3.75, 1), (4.0, 0)], len(x))
    return [("mus_curtain", master(x, -14.0, circular=False), meta)]


# =============================================================================== RESULTS (waltz)

WALTZ_HARM = ["F", "F", "C7", "C7", "C7", "C7", "F", "F", "F", "F7", "Bb", "Bb", "F", "C7", "F", "F",
              "Gm", "C7", "F", "C7"]
WALTZ_CH = {"F": (41, 48, (57, 60, 65)), "C7": (36, 43, (58, 60, 64)), "F7": (41, 48, (57, 63, 65)),
            "Bb": (46, 41, (58, 62, 65)), "Gm": (43, 50, (58, 62, 67))}
WALTZ_TUNE = [
    (0, 0, 1, 72), (0, 1, 1, 69), (0, 2, 1, 72), (1, 0, 2, 77), (1, 2, 1, 76),
    (2, 0, 1, 74), (2, 1, 1, 72), (2, 2, 1, 70), (3, 0, 3, 67),
    (4, 0, 1, 70), (4, 1, 1, 67), (4, 2, 1, 70), (5, 0, 2, 76), (5, 2, 1, 74),
    (6, 0, 1, 72), (6, 1, 1, 70), (6, 2, 1, 69), (7, 0, 3, 65),
    (8, 0, 1, 72), (8, 1, 1, 69), (8, 2, 1, 72), (9, 0, 2, 75), (9, 2, 1, 74),
    (10, 0, 1, 74), (10, 1, 1, 72), (10, 2, 1, 70), (11, 0, 2, 70), (11, 2, 1, 74),
    (12, 0, 2, 72), (12, 2, 1, 69), (13, 0, 1, 67), (13, 1, 1, 70), (13, 2, 1, 76),
    (14, 0, 3, 77),
    (16, 0, 1, 67), (16, 1, 1, 70), (16, 2, 1, 74), (17, 0, 1, 72), (17, 1, 1, 70), (17, 2, 1, 67),
    (18, 0, 2, 69), (18, 2, 1, 72), (19, 0, 1, 67), (19, 1, 1, 64), (19, 2, 1, 60),
]


def render_results() -> list:
    meta = META["mus_results"]
    L = Loop(meta["spb"], meta["bars"] * 3, seed=161)
    rng = L.rng
    for bar, name in enumerate(WALTZ_HARM):
        root, fifth, tones = WALTZ_CH[name]
        L.add("tuba", I.tuba(midi(root if bar % 2 == 0 else fifth), L.sec(0.8), 0.9, rng), bar * 3)
        for bt in (1, 2):
            for k, p in enumerate(tones):
                L.add("pah", I.pizz(midi(p), 0.2, 0.55 if bt == 1 else 0.45, rng, ring=0.15), bar * 3 + bt + k * 0.005)
        if bar in (0, 8):
            L.add("perc", I.triangle(1.2, 0.35, rng), bar * 3)
    for bar, beat, d, p in WALTZ_TUNE:
        L.add("clar", I.clarinet(midi(p), L.sec(d) * 0.85, 0.75, rng), bar * 3 + beat)
        if d >= 2 or bar >= 16:
            L.add("glock", I.glock(midi(p + 12), 0.8, 0.5, rng), bar * 3 + beat)
    for k, p in enumerate((77, 81, 84, 89)):
        L.add("glock", I.glock(midi(p), 0.7, 0.55, rng), 15 * 3 + k * 0.5)
    for bar in range(8, 16):
        root, fifth, tones = WALTZ_CH[WALTZ_HARM[bar]]
        L.add("str", I.bowed(midi(tones[-1] + 12), L.sec(3) + 0.05, 0.35, rng, attack=0.2, release=0.1), bar * 3,
              human=0)
    dry = (cfilt(L.bus("tuba"), ("hp", 40), ("lp", 2500)) * 0.6 + cfilt(L.bus("pah"), ("hp", 150)) * 0.8
           + cfilt(L.bus("clar"), ("hp", 180)) * 0.8 + cfilt(L.bus("glock"), ("hp", 400)) * 0.5
           + L.bus("perc") * 0.4 + cfilt(L.bus("str"), ("hp", 250)) * 0.5)
    wet = creverb(dry, 1.3, 4500, seed=162) * 0.22
    return [("mus_results", master(dry + wet, -18.0), meta)]


class Job:
    def __init__(self, fn, desc: str):
        self.fn = fn
        self.desc = desc

    def render(self) -> list:
        return self.fn()


JOBS: dict[str, Job] = {
    "sneak": Job(render_sneak_set, "mus_sneak + mus_suspense (synchronised stems)"),
    "chase": Job(render_chase, "mus_chase: after Offenbach's Galop infernal"),
    "chain_1": Job(lambda: render_chain(1), "mus_chain_1: Mountain King, creeping bassoon + pizz (120 bpm)"),
    "chain_2": Job(lambda: render_chain(2), "mus_chain_2: + clarinet (140 bpm)"),
    "chain_3": Job(lambda: render_chain(3), "mus_chain_3: + brass and snare (168 bpm)"),
    "chain_4": Job(lambda: render_chain(4), "mus_chain_4: full climax (210 bpm)"),
    "curtain": Job(render_curtain, "mus_curtain: 4 s overture sting (one-shot)"),
    "results": Job(render_results, "mus_results: 20 s curtain-call waltz"),
}
