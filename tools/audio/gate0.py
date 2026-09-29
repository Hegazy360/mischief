#!/usr/bin/env python3
"""The Gate-0 in-context A/B pack (s2-sound §4.1.4): the owner judges the voice and the crowd *in the
scene*, not as isolated files.

  python3 tools/audio/gate0.py            # write docs/review/s2-sound/gate0/ (WAVs, PNGs, index.md)
  python3 tools/audio/gate0.py --stats    # print the loudness / timing table only

Every mix is built the way the game plays it:
  * clip sounds come from the clip-event table (tools/audio/clip_events.py) at their frames, with
    each row's vol_db; frames after a hit-stop are held by it (view time, ruling L12);
  * event-level sounds come from game/data/audio/cues.json semantics (the crowd laugh at the hold =
    accent + laugh_tiers.hold_delay_s, in view time; stingers duck the music −6 dB);
  * bus levels are the Settings defaults (music 0.7, sfx 0.9, voice 0.9, crowd 0.8), the crowd
    ducks −6 dB under his voice (80 ms ramps), the sneak loop sits under everything (the suspense
    layer while an armed prank is ≤ 2 s away), and the master limits at −1 dBFS;
  * the voice style maps vo_bellows_* → vo_bellows_tuba_*, the crowd style crowd_* → crowd_fb_*,
    exactly as Audio._styled_files_as() does (a kind without a fallback file keeps the formant one).
Banks play their first take (the pair buttons do the same), so A and B differ only in the style.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
ROOT = HERE.parents[1]
AUD = ROOT / "game" / "audio"
OUT = ROOT / "docs" / "review" / "s2-sound" / "gate0"
SR = 22050
FPS = 60.0
# Settings DEFAULTS (game/autoload/settings.gd) → bus gain; the UI bus follows sfx_vol.
BUS_DB = {"Music": 20 * math.log10(0.7), "SFX": 20 * math.log10(0.9), "Voice": 20 * math.log10(0.9),
          "Crowd": 20 * math.log10(0.8), "UI": 20 * math.log10(0.9)}
CROWD_DUCK_DB = -6.0
STING_DUCK_DB = -6.0
SUSPENSE_SNEAK_DB = -2.5
LIMIT_DB = -1.0
HOLD_DELAY_S = 0.15   # cues.json laugh_tiers.hold_delay_s (read at run time when present)


def _db(x: float) -> float:
    return 10 ** (x / 20.0)


_DOC: dict | None = None
_WAV: dict[str, np.ndarray] = {}


def doc() -> dict:
    global _DOC
    if _DOC is None:
        _DOC = json.loads((AUD / "sfx_map.json").read_text())
    return _DOC


def load(fid: str) -> np.ndarray:
    if fid not in _WAV:
        from review import read_wav_mono
        _WAV[fid] = read_wav_mono(AUD / doc()["files"][fid]["path"])[0]
    return _WAV[fid]


def files_of(name: str) -> list[str]:
    from gen_audio import resolve_ids
    return resolve_ids(name, doc())


def styled(name: str, vstyle: str, cstyle: str, take: int = 0) -> str:
    """The file the game plays for `name` in these styles (Audio._styled_files_as), take `take` of a bank."""
    fs = files_of(name)
    if not fs:
        raise KeyError(name)
    c = fs[0]
    if c.startswith("vo_bellows_") and not c.startswith(("vo_bellows_tuba_", "vo_bellows_squeaky_")) \
            and vstyle == "tuba":
        # map the id (bank or file) itself, so a bank maps to the tuba bank
        base = name if name.startswith("vo_bellows_") else c
        tb = files_of("vo_bellows_tuba_" + base[len("vo_bellows_"):])
        if tb:
            fs = tb
    elif c.startswith("crowd_") and not c.startswith("crowd_fb_") and cstyle == "fallback":
        base = name if name.startswith("crowd_") else c
        fb = files_of("crowd_fb_" + base[len("crowd_"):])
        if fb:
            fs = fb
    return fs[min(take, len(fs) - 1)]


class Mix:
    """An offline stand-in for the Audio autoload + AudioDirector: buses, ducks, limiter, marks."""

    def __init__(self, dur: float, vstyle: str = "formant", cstyle: str = "formant"):
        self.n = int(dur * SR)
        self.vstyle, self.cstyle = vstyle, cstyle
        self.bus = {b: np.zeros(self.n) for b in BUS_DB}
        self.voice_win: list[tuple[float, float]] = []
        self.sting_win: list[tuple[float, float]] = []
        self.marks: list[tuple[float, str]] = []
        self.played: list[tuple[float, str, str]] = []   # (t, id asked, file played)
        self.suspense: list[tuple[float, float]] = []

    # --- primitives -------------------------------------------------------------------------
    def _put(self, bus: str, t: float, x: np.ndarray, gain_db: float = 0.0) -> None:
        i = int(round(t * SR))
        if i >= self.n or i + len(x) <= 0:
            return
        s = max(0, -i)
        m = min(len(x) - s, self.n - i - s)
        self.bus[bus][i + s:i + s + m] += x[s:s + m] * _db(gain_db)

    def play(self, t: float, name: str, vol_db: float = 0.0, take: int = 0, mark: str | None = None) -> str:
        fid = styled(name, self.vstyle, self.cstyle, take)
        info = doc()["files"][fid]
        bus = info.get("bus", "SFX")
        x = load(fid)
        self._put(bus, t, x, vol_db)
        if bus == "Voice":
            self.voice_win.append((t, t + len(x) / SR))
        if fid.startswith("sting_"):
            self.sting_win.append((t, t + len(x) / SR))
        self.played.append((t, name, fid))
        if mark:
            self.marks.append((t, mark))
        return fid

    def crowd(self, t: float, kind: str, take: int = 0, mark: str | None = None) -> str:
        return self.play(t, "crowd_" + kind, 0.0, take, mark)

    def clip(self, t0: float, clip_id: str, hitstop: tuple[int, int] | None = None, until_f: int | None = None,
             skip: tuple[str, ...] = (), marks: dict[int, str] | None = None) -> float:
        """Place a clip's clip-event rows from t0; a hit-stop (accent_f, frames) holds every later row.
        Returns the real time of frame 0 + the hit-stop, for event-level timing."""
        from clip_events import clip_rows
        hs_f, hs_n = hitstop or (10 ** 9, 0)
        for r in clip_rows(clip_id):
            if (until_f is not None and r["f"] >= until_f) or r["id"] in skip:
                continue
            f = r["f"] + (hs_n if r["f"] > hs_f else 0)
            self.play(t0 + f / FPS, r["id"], float(r["vol_db"]), mark=(marks or {}).get(r["f"]))
        return t0

    def at_f(self, t0: float, f: int, hitstop: tuple[int, int] | None = None) -> float:
        hs_f, hs_n = hitstop or (10 ** 9, 0)
        return t0 + (f + (hs_n if f > hs_f else 0)) / FPS

    def music(self, t0: float, fid: str, t1: float | None = None, offset_s: float = 0.0) -> None:
        """A music loop from t0 (to t1), from `offset_s` into the file, on the Music bus."""
        x = load(fid)
        t1 = self.n / SR if t1 is None else t1
        need = int((t1 - t0) * SR)
        if need <= 0:
            return
        start = int(offset_s * SR) % len(x)
        reps = int(math.ceil((start + need) / len(x))) + 1
        y = np.tile(x, reps)[start:start + need].copy()
        fade = min(len(y), int(0.05 * SR))
        y[-fade:] *= np.linspace(1, 0, fade)
        self._put("Music", t0, y)

    def suspense_layer(self, t0: float, t1: float, sneak_offset_s: float = 0.0) -> None:
        """The suspense stem over the sneak (phase-locked), fading out over 0.6 s at t1."""
        x = load("mus_suspense")
        need = int((t1 + 0.6 - t0) * SR)
        start = int((t0 + sneak_offset_s) * SR) % len(x)
        y = np.tile(x, int(math.ceil((start + need) / len(x))) + 1)[start:start + need].copy()
        k = int(0.6 * SR)
        y[-k:] *= np.linspace(1, 0, k)
        self._put("Music", t0, y)
        self.suspense.append((t0, t1))

    # --- render -----------------------------------------------------------------------------
    def _env(self, wins: list[tuple[float, float]], depth_db: float, ramp: float = 0.08) -> np.ndarray:
        g = np.zeros(self.n)
        for a, b in wins:
            i0, i1 = int(a * SR), min(self.n, int(b * SR))
            if i1 > i0:
                g[i0:i1] = 1.0
        k = max(1, int(ramp * SR))
        ker = np.ones(k) / k
        g = np.convolve(g, ker, mode="same")
        return _db(depth_db) ** np.clip(g, 0, 1)

    def render(self) -> np.ndarray:
        y = np.zeros(self.n)
        for b, x in self.bus.items():
            g = _db(BUS_DB[b])
            if b == "Crowd":
                x = x * self._env(self.voice_win, CROWD_DUCK_DB)
            elif b == "Music":
                x = x * self._env(self.sting_win, STING_DUCK_DB, 0.05)
                if self.suspense:
                    x = x * self._env(self.suspense, SUSPENSE_SNEAK_DB, 0.3)
            y += x * g
        return limit(y, LIMIT_DB)


def limit(y: np.ndarray, ceiling_db: float) -> np.ndarray:
    """A simple master limiter: per 64-sample block the gain drops at once to what the block needs and
    recovers with an 80 ms release (a stand-in for the Master bus limiter), then a hard clip at the ceiling."""
    c = _db(ceiling_db)
    need = np.minimum(1.0, c / (np.abs(y) + 1e-12))
    B = 64
    rel = math.exp(-B / (0.08 * SR))
    g = np.ones_like(y)
    cur = 1.0
    for i in range(0, len(y), B):
        m = float(np.min(need[i:i + B]))
        cur = m if m < cur else 1.0 - (1.0 - cur) * rel
        g[i:i + B] = min(cur, m)
    return np.clip(y * g, -c, c)


# ----------------------------------------------------------------------------- measurements

def k_weight(x: np.ndarray) -> np.ndarray:
    from synth import filt
    return filt(x, ("highshelf", 1681.97, 0.7072, 4.0), ("hp", 38.13, 0.5003))


def lufs(x: np.ndarray) -> tuple[float, float]:
    """(integrated LUFS, max short-term 400 ms LUFS), BS.1770 gating (−70 abs, −10 rel), mono."""
    k = k_weight(x)
    blk, hop = int(0.4 * SR), int(0.1 * SR)
    if len(k) < blk:
        k = np.pad(k, (0, blk - len(k)))
    ms = np.array([np.mean(k[i:i + blk] ** 2) for i in range(0, len(k) - blk + 1, hop)]) + 1e-12
    l_blk = -0.691 + 10 * np.log10(ms)
    g1 = ms[l_blk > -70]
    if len(g1) == 0:
        return -70.0, float(np.max(l_blk))
    rel = -0.691 + 10 * np.log10(np.mean(g1)) - 10
    g2 = ms[(l_blk > -70) & (l_blk > rel)]
    return float(-0.691 + 10 * np.log10(np.mean(g2))), float(np.max(l_blk))


def true_peak_db(x: np.ndarray) -> float:
    """4× oversampled peak (FFT interpolation)."""
    N = len(x)
    X = np.fft.rfft(x)
    up = np.fft.irfft(X, 4 * N) * 4
    return 20 * math.log10(max(1e-9, float(np.max(np.abs(up)))))


# ----------------------------------------------------------------------------- the scenes

def _hold_delay() -> float:
    try:
        cues = json.loads((ROOT / "game" / "data" / "audio" / "cues.json").read_text())
        return float(cues["laugh_tiers"]["hold_delay_s"])
    except (OSError, ValueError, KeyError):
        return HOLD_DELAY_S


def _reactions() -> dict:
    return json.loads((ROOT / "game" / "data" / "reactions.json").read_text())["archetypes"]


def scene_sneeze(vs: str, cs: str) -> Mix:
    """ACHOO-RIA! in g0_sneeze: the end of the tea (sniff, sip) → the sneeze clip → the Stalls' T3 laugh +
    applause at the hold (event-level). The suspense layer runs while the armed prank is ≤ 2 s away."""
    rx = _reactions()["sneeze_blast_a"]
    marks, hs = rx["marks"], (int(rx["marks"]["accent"]), int(rx["cam"]["hitstop"]))
    m = Mix(6.9, vs, cs)
    tea0 = -318 / FPS + 0.2                     # the tea pass, so its f318 (the sniff) lands at 0.2 s
    t_fire = tea0 + 420 / FPS                   # trigger.mark_s 7.0 = the sip → reaction_start
    m.music(0.0, "mus_sneak", offset_s=21.0)
    m.suspense_layer(0.0, t_fire, 21.0)
    for r_f, r_id, r_vol, mk in ((318, "tea_sniff", 0.0, "sniff"), (388, "tea_slurp", 0.0, "sip")):
        m.play(tea0 + r_f / FPS, r_id, r_vol, mark=mk)
    m.clip(t_fire, "bellows/rx_sneeze_blast_a", hitstop=hs,
           marks={0: "ah", 20: "ahh", 44: "AHHH", 76: "hm (false stop)", 94: "CHOO!", 112: "sink", 154: "ladle"})
    t_hold = m.at_f(t_fire, int(marks["accent"]), hs) + hs[1] / FPS + _hold_delay()
    m.crowd(t_hold, "t3", mark="T3 at the hold")
    return m


def scene_warmup(vs: str, cs: str) -> Mix:
    """The Prologue's first seconds: the warm-up phrase nudging the vase note by note, the horn micro-gag at
    2.0 s ('mm-HM!' + the kiss) while the vase smashes behind him (laugh_vase at 2.3 s) and the Stalls titter."""
    m = Mix(4.4, vs, cs)
    m.music(0.0, "mus_sneak")
    t0 = 0.3
    m.clip(t0, "bellows/act_warmup", until_f=300, marks={0: "MI-MI-MI-MI-MIIII"})
    m.clip(t0 + 2.0, "bellows/mg_admire_reflection_horn", marks={14: "mm-HM!", 44: "mwah"})
    m.play(t0 + 2.3, "vase_smash", mark="vase smash")
    m.crowd(t0 + 2.55, "t0", mark="titter")
    return m


def scene_pipe_down(vs: str, cs: str) -> Mix:
    """A lure too many: two squeaks from Clarence, 'huh?', a third — 'PIPE DOWN!' (lure_fatigue), a chuckle."""
    m = Mix(4.2, vs, cs)
    m.music(0.0, "mus_sneak", offset_s=8.0)
    m.play(0.2, "clarence_squeak_2", mark="squeak")
    m.play(0.55, "vo_bellows_huh", mark="huh?")
    m.play(1.5, "clarence_squeak_4", mark="squeak")
    fid = m.play(1.75, "vo_bellows_pipe_down", mark="PIPE DOWN!")
    m.crowd(1.75 + len(load(fid)) / SR * 0.55, "t1", mark="chuckle")
    return m


def scene_lecture(vs: str, cs: str) -> Mix:
    """Caught: the sad trombone, the Stalls' 'awww', then Lecture A while he dangles her (the crowd ducks)."""
    m = Mix(5.6, vs, cs)
    m.music(0.0, "mus_sneak", t1=0.3, offset_s=30.0)
    m.play(0.2, "sting_caught", mark="caught")
    m.crowd(0.45, "aww", mark="awww")
    m.play(1.4, "vo_bellows_lecture_a", mark="Lecture A")
    return m


def scene_the_pipes(vs: str, cs: str) -> Mix:
    """The Prologue squeak bit: Clarence squeaks mid-scale, the high note cracks into a yodel, he clutches his
    throat — '…the pipes.' — the rim-shot, the Stalls laugh (the first player-caused laugh)."""
    m = Mix(4.8, vs, cs)
    m.music(0.0, "mus_sneak", offset_s=4.0)
    m.play(0.25, "clarence_squeak_3", mark="squeak")
    fid = m.play(0.4, "vo_bellows_warmup_crack", mark="crack!")
    t = 0.4 + len(load(fid)) / SR + 0.35
    fid2 = m.play(t, "vo_bellows_the_pipes", mark="…the pipes.")
    m.play(0.25 + 0.6, "sting_bit", mark="rim-shot")
    m.crowd(t + len(load(fid2)) / SR * 0.5, "t2", mark="laugh")
    return m


def scene_t2(vs: str, cs: str) -> Mix:
    """A mid gag: the blind shuffle into the door frame — BONK, 'oof!' — and a T2 laugh at the hold."""
    m = Mix(3.8, vs, cs)
    m.music(0.0, "mus_sneak", offset_s=12.0)
    m.clip(0.1, "bellows/loco_blind_shuffle")
    m.clip(0.5, "bellows/cue_doorframe_bonk", marks={4: "BONK", 7: "oof!"})
    m.crowd(0.5 + 4 / FPS + _hold_delay(), "t2", mark="T2")
    return m


def scene_t4(vs: str, cs: str) -> Mix:
    """ALLEGRO-GO-GO! (running gag ×1.5): the gramophone races, he babbles and spins, the Stalls roar (T4)
    over the Mountain King chain section."""
    m = Mix(5.6, vs, cs)
    m.music(0.0, "mus_chain_2")
    m.play(0.2, "gramophone_speedup", mark="speed-up")
    m.play(0.9, "vo_bellows_dizzy_babble", mark="babble")
    m.play(2.1, "dizzy_tweets", -3.0)
    m.crowd(1.3, "t4", mark="T4 roar")
    return m


def scene_relief(vs: str, cs: str) -> Mix:
    """A near miss: the '?' fills, the suspense layer ticks — he turns away: the harp, the Stalls' relief."""
    m = Mix(3.8, vs, cs)
    m.music(0.0, "mus_sneak", offset_s=40.0)
    m.suspense_layer(0.0, 1.2, 40.0)
    m.play(0.1, "sting_spot", mark="?")
    m.crowd(0.25, "gasp", mark="gasp")
    m.play(1.2, "sting_near_miss", mark="near miss")
    m.crowd(1.4, "relief", mark="relief")
    return m


def scene_behind_you(vs: str, cs: str) -> Mix:
    """The 1.5 s entry warning with Hush in the open: his steps grow, the door jiggles, 'BEHIND YOU!'."""
    m = Mix(3.4, vs, cs)
    m.music(0.0, "mus_sneak", offset_s=16.0)
    for k in range(4):
        m.play(0.1 + k * 16 / FPS, "bellows_step", -8.0 + 3.0 * k + 6.0, take=k % 2)
    m.play(0.3, "door_jiggle", mark="door jiggle")
    m.crowd(0.6, "behind_you", mark="BEHIND YOU!")
    return m


VOICE_PAIRS = [
    ("warmup", "The warm-up: MI-MI-MIIII", scene_warmup,
     "the sung phrase over the pit: is he a pompous baritone you'd laugh at (A) or a muted tuba 'singing' (B)? "
     "Each note should nudge the vase audibly, and 'mm-HM!' must read as smug."),
    ("sneeze", "The sneeze: ah... ahh... AHHH... hm. CHOO!", scene_sneeze,
     "the rule of three must *climb* (pitch and loudness), the false stop must feel like a relieved breath, and the "
     "CHOO must be the loudest thing in the scene."),
    ("pipe_down", "PIPE DOWN!", scene_pipe_down,
     "a shout that's angry but not scary; the words must be understood over the music on a phone speaker."),
    ("lecture_a", "The Lecture (A)", scene_lecture,
     "a sung scolding with a finger-wag rhythm; with the tuba, can you still tell he's scolding?"),
    ("the_pipes", "...the pipes.", scene_the_pipes,
     "the crack into a yodel is the joke; '…the pipes' should be small, hoarse and self-pitying."),
]
CROWD_PAIRS = [
    ("t2", "A laugh (T2)", scene_t2,
     "a warm, human room laugh with one standout 'HA!' (A) vs applause + kazoo 'ha-ha' choir (B): which never "
     "sounds creepy?"),
    ("sneeze_t3", "The sneeze's laugh + applause (T3)", scene_sneeze,
     "the big payoff: the laugh must start at the hold and lift the gag, not bury the sink crash."),
    ("t4", "The roar (T4)", scene_t4,
     "the room on its feet — whistles, stamping; it should feel like winning, over the Mountain King."),
    ("relief", "Relief (a near miss)", scene_relief,
     "a collective exhale + titter after the harp; it must read as 'phew', not as a laugh at you."),
    ("behind_you", "BEHIND YOU!", scene_behind_you,
     "the panto warning: urgent and fun. The fallback (kazoo choir) has no words — can you still hear 'behind you'?"),
]


# ----------------------------------------------------------------------------- output

def _write(path: Path, x: np.ndarray) -> None:
    import gen_audio
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(gen_audio.wav_bytes(x))


def _stack(pngs: list[Path], out: Path, labels: list[str]) -> None:
    from PIL import Image, ImageDraw
    ims = [Image.open(p).convert("RGB") for p in pngs]
    W = max(i.width for i in ims)
    lab_h = 20
    H = sum(i.height + lab_h for i in ims)
    img = Image.new("RGB", (W, H), (18, 14, 26))
    dr = ImageDraw.Draw(img)
    y = 0
    for im, lab in zip(ims, labels):
        dr.rectangle([0, y, W, y + lab_h], fill=(40, 30, 60))
        dr.text((6, y + 4), lab, fill=(255, 230, 150))
        img.paste(im, (0, y + lab_h))
        y += im.height + lab_h
    img.quantize(colors=96, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).save(out, optimize=True)
    for p in pngs:
        p.unlink()


def _stats_row(name: str, x: np.ndarray) -> dict:
    il, st = lufs(x)
    return {"file": name, "dur_s": round(len(x) / SR, 2), "lufs_i": round(il, 1), "lufs_st_max": round(st, 1),
            "true_peak_db": round(true_peak_db(x), 2)}


def build(write: bool = True) -> tuple[list[dict], list[dict]]:
    from review import spectrogram_png
    OUT.mkdir(parents=True, exist_ok=True)
    if write:
        for old in list(OUT.glob("*.wav")) + list(OUT.glob("*.png")):
            old.unlink()
    rows, timing = [], []
    # the sneeze in every voice style × crowd style
    grid = []
    for vs in ("formant", "tuba"):
        for cs in ("formant", "fallback"):
            m = scene_sneeze(vs, cs)
            x = m.render()
            name = f"sneeze_voice-{vs}_crowd-{cs}"
            rows.append(_stats_row(name + ".wav", x))
            if vs == "formant" and cs == "formant":
                timing = [{"t_s": round(t, 3), "id": i, "file": f} for t, i, f in sorted(m.played)]
            if write:
                _write(OUT / f"{name}.wav", x)
                p = OUT / f"_{name}.png"
                spectrogram_png(x, p, f"ACHOO-RIA! in context — voice {vs}, crowd {cs}", marks=m.marks, width=1400)
                grid.append((p, f"voice {vs} · crowd {cs}"))
    if write:
        _stack([g[0] for g in grid], OUT / "sneeze_ab.png", [g[1] for g in grid])
    for sect, pairs, styles in (("voice", VOICE_PAIRS, ("formant", "tuba")), ("crowd", CROWD_PAIRS, ("formant", "fallback"))):
        for pid, label, fn, _ in pairs:
            if pid in ("sneeze", "sneeze_t3"):
                continue          # the sneeze grid above covers both pairs
            pngs = []
            for side, st in zip("ab", styles):
                m = fn(st, "formant") if sect == "voice" else fn("formant", st)
                x = m.render()
                name = f"{sect}_{pid}_{side}_{st}"
                rows.append(_stats_row(name + ".wav", x))
                if write:
                    _write(OUT / f"{name}.wav", x)
                    p = OUT / f"_{name}.png"
                    spectrogram_png(x, p, f"{label} — {side.upper()}: {st}", marks=m.marks, width=1100)
                    pngs.append((p, f"{side.upper()} = {st}"))
            if write:
                _stack([q[0] for q in pngs], OUT / f"{sect}_{pid}.png", [q[1] for q in pngs])
    return rows, timing


def coverage() -> list[tuple[str, str, bool, str]]:
    """Every voice / crowd id the Gate-0 scene can play (the Phase-G clip events + cues.json events that fire
    in g0_sneeze) → (id, where, both styles?, the B file)."""
    import clip_events
    out = []
    seen = set()
    for c in clip_events.spec():
        if c["phase"] != "G":
            continue
        for r in c["rows"]:
            if r[1] == "voice" and r[2] not in seen:
                seen.add(r[2])
                b = styled(r[2], "tuba", "formant")
                out.append((r[2], c["clip"], b.startswith("vo_bellows_tuba_"), b))
    cues = json.loads((ROOT / "game" / "data" / "audio" / "cues.json").read_text())
    g0_events = ["rigged", "hide", "entry_warning", "spot_start", "near_miss", "b_detour", "doorway_pause", "ear_pip",
                 "head_turn", "lure", "lure_fatigue", "bump", "squeak_bit", "night_end"]
    for e in g0_events:
        acts = cues["events"].get(e)
        stack = [acts]
        while stack:
            a = stack.pop()
            if isinstance(a, list):
                stack += a
            elif isinstance(a, dict):
                for k in ("voice",):
                    if k in a and a[k] not in seen:
                        seen.add(a[k])
                        b = styled(a[k], "tuba", "formant")
                        out.append((a[k], f"cues {e}", b.startswith("vo_bellows_tuba_"), b))
                if "crowd" in a and "crowd:" + a["crowd"] not in seen:
                    seen.add("crowd:" + a["crowd"])
                    b = styled("crowd_" + a["crowd"], "formant", "fallback")
                    out.append(("crowd " + a["crowd"], f"cues {e}", b.startswith("crowd_fb_"), b))
                by = a.get("by")
                if isinstance(by, dict):
                    stack += list((by.get("map") or {}).values()) + [by.get("default")]
                if isinstance(a.get("then"), list):
                    stack += a["then"]
    for kind in ("t0", "t1", "t2", "t3", "shh"):
        if "crowd:" + kind not in seen:
            seen.add("crowd:" + kind)
            b = styled("crowd_" + kind, "formant", "fallback")
            out.append(("crowd " + kind, "laugh path" if kind != "shh" else "the Stalls shush (climb-in)",
                        b.startswith("crowd_fb_"), b))
    return out


def write_index(rows: list[dict], timing: list[dict]) -> None:
    by = {r["file"]: r for r in rows}

    def line(f):
        r = by.get(f)
        return f"{r['lufs_i']:.1f} LUFS · peak {r['true_peak_db']:.1f} dBTP" if r else ""

    L = ["# Gate 0 — voice and crowd A/B, in context", "",
         "_Generated by `tools/audio/gate0.py` (owner `s2-sound`). Listen on a **phone speaker at half volume** "
         "first, then headphones. Every clip is the scene the way the game plays it: the clip sounds at their "
         "frames (`docs/review/s2-sound/clip_events.md`), the event-level crowd and stingers from `cues.json`, the "
         "pit's sneak loop underneath, the Settings default volumes, the crowd ducking −6 dB under his voice, the "
         "master limiter. A and B differ only in the one style being judged._", "",
         "**On the phone:** the stage door's **Play Gate 0 with voice A / B** and **… crowd A / B** set "
         "`voice_style` / `crowd_style` and launch `g0_sneeze` (the whole scene in that style); the pair buttons "
         "play each line alone with `Audio.preview(id, style)` (`game/data/audio/ab.json`).", "",
         "## The sneeze — every voice × crowd combination", "",
         "![the sneeze in all four styles](sneeze_ab.png)", "",
         "| | crowd A (formant) | crowd B (fallback) |", "|---|---|---|"]
    for vs, lab in (("formant", "**voice A** (formant baritone)"), ("tuba", "**voice B** (talking tuba)")):
        L.append(f"| {lab} | [sneeze_voice-{vs}_crowd-formant.wav](sneeze_voice-{vs}_crowd-formant.wav) — "
                 f"{line(f'sneeze_voice-{vs}_crowd-formant.wav')} | [sneeze_voice-{vs}_crowd-fallback.wav]"
                 f"(sneeze_voice-{vs}_crowd-fallback.wav) — {line(f'sneeze_voice-{vs}_crowd-fallback.wav')} |")
    L += ["", "Listen for: the three 'ah's **climbing** in pitch and loudness (f0 / f20 / f44), a relieved 'hm.' and "
          "near-silence in the false stop (f74–94), the **CHOO** on f94 as the loudest hit, the stool scrape + the "
          "slide whistle rising over the flight, the sink **crash on f112 → 300 ms of dead silence → one ladle spinning "
          "to rest → drips**, and the Stalls' laugh + applause starting at the hold, never on top of the CHOO.", "",
          "Sound timeline of the formant/formant mix (seconds from the start of the file; 5-f hit-stop after f94):", "",
          "| t (s) | id | file |", "|---|---|---|"]
    for t in timing:
        L.append(f"| {t['t_s']:.3f} | {t['id']} | {t['file']} |")
    L += ["", "## Voice A/B — formant baritone (A) vs talking tuba (B)", ""]
    for pid, label, _, hint in VOICE_PAIRS:
        if pid == "sneeze":
            L += [f"### {label}", "", "See the sneeze grid above (rows = voice).", ""]
            continue
        a, b = f"voice_{pid}_a_formant.wav", f"voice_{pid}_b_tuba.wav"
        L += [f"### {label}", "", f"- A: [{a}]({a}) — {line(a)}", f"- B: [{b}]({b}) — {line(b)}",
              f"- **Listen for:** {hint}", "", f"![{pid}](voice_{pid}.png)", ""]
    L += ["## Crowd A/B — formant Stalls (A) vs fallback crowd (B)", ""]
    for pid, label, _, hint in CROWD_PAIRS:
        if pid == "sneeze_t3":
            L += [f"### {label}", "", "See the sneeze grid above (columns = crowd).", ""]
            continue
        a, b = f"crowd_{pid}_a_formant.wav", f"crowd_{pid}_b_fallback.wav"
        L += [f"### {label}", "", f"- A: [{a}]({a}) — {line(a)}", f"- B: [{b}]({b}) — {line(b)}",
              f"- **Listen for:** {hint}", "", f"![{pid}](crowd_{pid}.png)", ""]
    cov = coverage()
    L += ["## Does every voice / crowd sound of the Gate-0 scene exist in both styles?", "",
          "The phone A/B runs the whole `g0_sneeze` scene in one style, so every voice line and crowd kind it can "
          "play must have its B take. The Gate-0 clip events + the `cues.json` events that fire there:", "",
          "| id | where | both styles | B plays |", "|---|---|---|---|"]
    for i, where, ok, b in cov:
        L.append(f"| {i} | {where} | {'yes' if ok else '**no** — the formant take plays'} | {b} |")
    missing = [c for c in cov if not c[2]]
    L += ["", f"{len(cov) - len(missing)} of {len(cov)} exist in both styles." +
          ("" if not missing else " The rest (" + ", ".join(m[0] for m in missing) + ") contain no voice / no "
           "laughter (the shush is breath), so the fallback keeps the formant file on purpose (Stage-1 deviation 6)."),
          "", "## Loudness of every mix", "",
          "Integrated loudness (BS.1770 K-weighted, gated) and 4× oversampled true peak after the bus gains and the "
          "−1 dBFS master limiter.", "", "| file | s | LUFS-I | max short-term | true peak dBTP |", "|---|---|---|---|---|"]
    for r in rows:
        L.append(f"| {r['file']} | {r['dur_s']} | {r['lufs_i']} | {r['lufs_st_max']} | {r['true_peak_db']} |")
    L.append("")
    (OUT / "index.md").write_text("\n".join(L))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stats", action="store_true")
    a = ap.parse_args()
    rows, timing = build(write=not a.stats)
    for r in rows:
        print(f"{r['file']:44s} {r['dur_s']:5.2f}s  {r['lufs_i']:6.1f} LUFS  st-max {r['lufs_st_max']:6.1f}  "
              f"TP {r['true_peak_db']:6.2f} dBTP")
    if not a.stats:
        write_index(rows, timing)
        tot = sum(p.stat().st_size for p in OUT.glob("*.wav"))
        print(f"wrote {OUT.relative_to(ROOT)}: {len(list(OUT.glob('*.wav')))} WAVs ({tot / 1e6:.2f} MB), "
              f"{len(list(OUT.glob('*.png')))} PNGs, index.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
