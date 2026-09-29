"""Ear proxies: spectrogram + waveform PNGs (Pillow) and simple onset / loop-seam stats.

  python3 tools/audio/review.py <wav> [<wav> ...] --out DIR      # one PNG per file
  python3 tools/audio/review.py --pack                           # the docs/review/audio set

Each PNG shows, top to bottom: the title line (name, duration, peak, loudest 50 ms RMS),
a mel-scaled spectrogram 0-11 kHz (dB, magma-ish colours, formant bands F1/F2/F3 guide
lines at 500/1500/2500 Hz), the waveform with detected onsets (red ticks) and a time
axis. For music loops a seam strip (last 60 ms + first 60 ms) is drawn at the right.
"""
from __future__ import annotations

import argparse
import math
import struct
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
SR = 22050


def read_wav_mono(path: Path) -> tuple[np.ndarray, tuple | None]:
    b = path.read_bytes()
    pos = 12
    data = b""
    ch = 1
    loop = None
    while pos + 8 <= len(b):
        cid, sz = struct.unpack("<4sI", b[pos:pos + 8])
        body = b[pos + 8:pos + 8 + sz]
        if cid == b"fmt ":
            ch = struct.unpack("<H", body[2:4])[0]
        elif cid == b"data":
            data = body
        elif cid == b"smpl" and len(body) >= 60:
            if struct.unpack("<I", body[28:32])[0]:
                loop = struct.unpack("<4I", body[36:52])[1:]
        pos += 8 + sz + (sz & 1)
    x = np.frombuffer(data[: len(data) // 2 * 2], dtype="<i2").astype(float) / 32768.0
    if ch == 2:
        x = x[0::2]
    return x, loop


def _colour(v: np.ndarray) -> np.ndarray:
    """0..1 → RGB (a compact magma-like ramp)."""
    stops = np.array([[0.0, 0, 0, 4], [0.25, 60, 15, 110], [0.5, 180, 55, 120], [0.75, 250, 140, 60],
                      [1.0, 252, 253, 191]])
    v = np.clip(v, 0, 1)
    out = np.zeros(v.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(v, stops[:, 0], stops[:, c + 1])
    return out.astype(np.uint8)


def _mel(f):
    return 2595.0 * np.log10(1.0 + np.asarray(f, float) / 700.0)


def onsets(x: np.ndarray, thresh_db: float = 9.0) -> list[float]:
    """Simple energy-flux onsets (seconds): 10 ms frames, rise ≥ thresh_db over 30 ms."""
    hop = int(0.01 * SR)
    if len(x) < hop * 4:
        return []
    fr = len(x) // hop
    e = np.array([np.sum(x[i * hop:(i + 1) * hop] ** 2) for i in range(fr)]) + 1e-10
    d = 10 * np.log10(e)
    out = []
    last = -1.0
    for i in range(3, fr):
        if d[i] - np.min(d[i - 3:i]) >= thresh_db and d[i] > np.max(d) - 40:
            t = i * hop / SR
            if t - last > 0.06:
                out.append(t)
                last = t
    return out


def spectrogram_png(x: np.ndarray, out: Path, title: str, loop: bool = False, width: int | None = None,
                    marks: list[tuple[float, str]] | None = None) -> None:
    from PIL import Image, ImageDraw
    dur = len(x) / SR
    width = width or int(min(1400, max(520, dur * 360)))
    spec_h, wave_h, top, axis = 260, 90, 22, 18
    seam_w = 160 if loop else 0
    W, H = width + seam_w, top + spec_h + wave_h + axis
    img = Image.new("RGB", (W, H), (18, 14, 26))
    dr = ImageDraw.Draw(img)
    # spectrogram (STFT 1024/hop adaptive, mel rows)
    nfft = 1024
    hop = max(32, int(len(x) / width))
    pad = np.concatenate([np.zeros(nfft // 2), x, np.zeros(nfft)])
    frames = max(1, (len(pad) - nfft) // hop)
    win = np.hanning(nfft)
    idx = np.arange(nfft)[None, :] + hop * np.arange(frames)[:, None]
    S = np.abs(np.fft.rfft(pad[idx] * win, axis=1)) + 1e-9
    Sdb = 20 * np.log10(S / (np.max(S) + 1e-12))
    freqs = np.fft.rfftfreq(nfft, 1 / SR)
    mel_rows = np.linspace(_mel(40), _mel(11000), spec_h)
    row_f = 700 * (10 ** (mel_rows / 2595) - 1)
    bins = np.clip(np.searchsorted(freqs, row_f), 0, len(freqs) - 1)
    M = Sdb[:, bins].T[::-1]                      # [rows, frames], low freq at the bottom
    cols = np.clip((np.arange(width) * frames / width).astype(int), 0, frames - 1)
    M = M[:, cols]
    rgb = _colour((M + 80) / 80)
    img.paste(Image.fromarray(rgb, "RGB"), (0, top))
    for fg, lab in ((500, "500"), (1500, "1.5k"), (2500, "2.5k"), (5000, "5k")):
        y = top + spec_h - 1 - int((_mel(fg) - _mel(40)) / (_mel(11000) - _mel(40)) * (spec_h - 1))
        dr.line([(0, y), (width, y)], fill=(90, 200, 255), width=1)
        dr.text((2, y - 11), lab, fill=(150, 220, 255))
    # waveform
    wy0 = top + spec_h
    mid = wy0 + wave_h // 2
    dr.rectangle([0, wy0, width, wy0 + wave_h], fill=(10, 10, 16))
    step = max(1, len(x) // width)
    for c in range(width):
        seg = x[c * step:(c + 1) * step]
        if len(seg) == 0:
            continue
        a, b = float(np.min(seg)), float(np.max(seg))
        dr.line([(c, mid - b * wave_h / 2), (c, mid - a * wave_h / 2)], fill=(120, 230, 160))
    for o in onsets(x):
        cx = int(o / dur * width)
        dr.line([(cx, wy0), (cx, wy0 + 10)], fill=(255, 60, 60), width=2)
    for (tm, lab) in (marks or []):
        cx = int(tm / dur * width)
        dr.line([(cx, top), (cx, wy0 + wave_h)], fill=(255, 255, 255), width=1)
        dr.text((cx + 2, top + 2), lab, fill=(255, 255, 255))
    # axis
    ay = wy0 + wave_h
    step_s = 0.1 if dur <= 1.2 else 0.25 if dur <= 3 else 0.5 if dur <= 6 else 2.0 if dur <= 30 else 5.0
    k = 0
    while k * step_s <= dur + 1e-6:
        cx = int(k * step_s / dur * (width - 1))
        dr.line([(cx, ay), (cx, ay + 4)], fill=(200, 200, 200))
        dr.text((cx + 1, ay + 4), f"{k * step_s:g}", fill=(200, 200, 200))
        k += 1
    # title
    pk = 20 * math.log10(float(np.max(np.abs(x))) + 1e-12)
    w = int(0.05 * SR)
    c = np.concatenate([[0.0], np.cumsum(x * x)])
    rms = 20 * math.log10(math.sqrt(max(float(np.max(c[w:] - c[:-w])) / w, 1e-12))) if len(x) > w else -99
    dr.text((4, 4), f"{title}   {dur:.2f} s   peak {pk:.1f} dBFS   loudest-50ms RMS {rms:.1f} dBFS",
            fill=(255, 230, 200))
    if loop:
        n = int(0.06 * SR)
        seg = np.concatenate([x[-n:], x[:n]])
        sx0 = width
        dr.rectangle([sx0, top, W, H], fill=(24, 18, 34))
        dr.text((sx0 + 4, top + 2), "loop seam", fill=(255, 230, 200))
        sm = top + (spec_h + wave_h) // 2
        for c2 in range(seam_w):
            j = int(c2 / seam_w * len(seg))
            v = seg[j]
            dr.point((sx0 + c2, sm - v * (spec_h / 2)), fill=(120, 230, 160))
        dr.line([(sx0 + seam_w // 2, top + 14), (sx0 + seam_w // 2, H)], fill=(255, 80, 80))
    out.parent.mkdir(parents=True, exist_ok=True)
    img.quantize(colors=128, method=Image.Quantize.MEDIANCUT).save(out, optimize=True)   # ~3× smaller in git


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("wavs", nargs="*")
    ap.add_argument("--out", default=".")
    ap.add_argument("--pack", action="store_true", help="write the docs/review/audio Gate-0 pack")
    a = ap.parse_args()
    if a.pack:
        return _main_pack()
    for w in a.wavs:
        p = Path(w)
        x, loop = read_wav_mono(p)
        spectrogram_png(x, Path(a.out) / (p.stem + ".png"), p.stem, loop=loop is not None)
        print("wrote", Path(a.out) / (p.stem + ".png"))
    return 0



# =============================================================================== the Gate-0 review pack

ROOT = HERE.parents[1]
AUD = ROOT / "game" / "audio"
DOCS = ROOT / "docs" / "review" / "audio"
AB = DOCS / "ab"

VOICE_AB = [("pipe_down_1", "PIPE DOWN! (shout)"), ("aria_1", "aria after Bizet's Toreador"),
            ("crack_1", "warm-up scale cracking into a yodel (the Prologue squeak bit)"),
            ("lecture_a", "the Lecture: a sung scolding, finger-wag rhythm"), ("the_pipes_1", "…the pipes."),
            ("hmph_1", "hmph"), ("wha_1", "WHA!"), ("who_squeaked", "WHO SQUEAKED?! (Livid bit)")]
CROWD_AB = [("t0_1", "T0 titter"), ("t1_1", "T1 chuckle"), ("t2_1", "T2 laugh + one HA!"),
            ("t3_1", "T3 laugh + applause"), ("t4_1", "T4 roar, whistles, stomps"), ("relief_1", "relief (near miss)"),
            ("cheer_1", "curtain cheer")]
TOP_SFX = [("clarence_squeak_3", "Clarence squeak (pitch 3 of 5) — the core comic verb"),
           ("woodblock_bonk", "the woodblock BONK on contact frames"),
           ("freeze_clack", "FREEZE: Hush becomes a statue"), ("sting_rigged", "rigged: ding + three pizz"),
           ("sting_spot", "the '?' as he starts to notice"), ("sting_near_miss", "near miss: harp glissando"),
           ("sting_caught", "caught: sad trombone"), ("door_jiggle", "the 1.5 s entry warning"),
           ("crash_tail", "crash, 300 ms of silence, a pan spinning to rest"),
           ("slide_down", "slide whistle (falls only)")]


def _load(fid: str) -> np.ndarray:
    for folder in ("sfx", "voice", "music"):
        p = AUD / folder / f"{fid}.wav"
        if p.exists():
            return read_wav_mono(p)[0]
    raise FileNotFoundError(fid)


def _write(path: Path, x: np.ndarray) -> None:
    import gen_audio
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(gen_audio.wav_bytes(np.clip(x, -0.89, 0.89)))


def _at(total_s: float, parts) -> np.ndarray:
    y = np.zeros(int(total_s * SR))
    for t, x, g in parts:
        i = int(t * SR)
        m = min(len(x), len(y) - i)
        if m > 0:
            y[i:i + m] += x[:m] * g
    return y


def sneeze_sequence() -> tuple[np.ndarray, list]:
    """GDD §2.3 / §5.7 #1: ah (20 f) … ahh (24 f) … AHHH (30 f) … false stop (20 f), CHOO
    (3 f accent) → the stool rockets back → the sink; the Stalls laugh from the hold."""
    f = 1 / 60.0
    ah1, ah2, ah3 = _load("vo_bellows_sneeze_ah1"), _load("vo_bellows_sneeze_ah2"), _load("vo_bellows_sneeze_ah3")
    t_ah1, t_ah2 = 0.3, 0.3 + 20 * f + 0.25
    t_ah3 = t_ah2 + 24 * f + 0.25
    t_choo = t_ah3 + 30 * f + 20 * f + 0.2
    parts = [(t_ah1, ah1, 1.0), (t_ah2, ah2, 1.0), (t_ah3, ah3, 1.0), (t_choo, _load("vo_bellows_sneeze_choo_1"), 1.0),
             (t_choo + 0.03, _load("stool_zip"), 0.8), (t_choo + 0.3, _load("sink_splash"), 0.8),
             (t_choo + 0.12, _load("woodblock_bonk"), 0.5), (t_choo + 0.3, _load("crowd_t2_1"), 0.7)]
    marks = [(t_ah1, "ah"), (t_ah2, "ahh"), (t_ah3, "AHHH"), (t_ah3 + 30 * f, "false stop"), (t_choo, "CHOO!"),
             (t_choo + 0.3, "laugh")]
    return _at(t_choo + 2.6, parts), marks


def tiptoe_walk() -> np.ndarray:
    """Hush tiptoes: one pizzicato note per footfall (10 f per step), walking up the scale."""
    steps = [_load(f"step_pizz_{i}") for i in range(1, 9)]
    return _at(1.8, [(0.05 + i * 10 / 60.0 * 1.6, s, 1.0) for i, s in enumerate(steps)])


def adaptive_demo() -> tuple[np.ndarray, list]:
    """Offline mix of what the Audio autoload does: sneak → suspense fades in (a '?') →
    Running Gag links 1–4 switch Mountain King sections on bar lines → back to sneak."""
    import json
    meta = json.loads((AUD / "sfx_map.json").read_text())["music"]

    def bar(fid):
        m = meta[fid]
        return m["spb"] * m["beats_per_bar"] / SR

    sneak, sus = _load("mus_sneak"), _load("mus_suspense")
    sus_t = np.tile(sus, len(sneak) // len(sus))
    b0 = bar("mus_sneak")
    t_sus_on, t_sus_off = 4 * b0, 6 * b0
    n_sneak = int(8 * b0 * SR)
    g = np.ones(n_sneak)
    tx = np.arange(n_sneak) / SR
    ramp = np.clip((tx - t_sus_on) / 0.4, 0, 1) * np.clip((t_sus_off + 0.4 - tx) / 0.4, 0, 1)
    y = [sneak[:n_sneak] * (1 - 0.25 * ramp) + sus_t[:n_sneak] * ramp]
    marks = [(0.0, "sneak"), (t_sus_on, "'?' suspense"), (t_sus_off, "near miss")]
    t = 8 * b0
    for k, bars in ((1, 4), (2, 4), (3, 4), (4, 6)):
        fid = f"mus_chain_{k}"
        seg = np.tile(_load(fid), 3)[: int(bars * bar(fid) * SR)]
        marks.append((t, f"link {k}"))
        y.append(seg)
        t += bars * bar(fid)
    marks.append((t, "gag ends"))
    y.append(sneak[: int(4 * b0 * SR)])
    out = np.concatenate(y)
    st = _load("sting_rigged")
    i = int(2 * b0 * SR)
    out[i:i + len(st)] += st * 0.9
    marks.append((2 * b0, "sting (music ducks)"))
    out[i:i + len(st)] *= 1.0
    return out * 0.9, marks


def strip(ids: list[str], gap: float = 0.25) -> np.ndarray:
    parts, t = [], 0.1
    for fid in ids:
        x = _load(fid)
        parts.append((t, x, 1.0))
        t += len(x) / SR + gap
    return _at(t, parts)


def pack() -> list[str]:
    """Write docs/review/audio: spectrogram PNGs, A/B WAVs, composites, index.md."""
    DOCS.mkdir(parents=True, exist_ok=True)
    AB.mkdir(parents=True, exist_ok=True)
    for old in list(AB.glob("*.wav")) + list(DOCS.glob("*.png")):
        old.unlink()
    wrote = []

    def png(name, x, title, loop=False, marks=None, width=None):
        spectrogram_png(x, DOCS / f"{name}.png", title, loop=loop, marks=marks, width=width)
        wrote.append(f"{name}.png")

    seq, marks = sneeze_sequence()
    _write(AB / "demo_sneeze_sequence.wav", seq)
    png("sneeze_sequence", seq, "ACHOO-RIA! sequence: ah / ahh / AHHH / false stop / CHOO / stool / sink / laugh",
        marks=marks, width=1400)
    walk = tiptoe_walk()
    _write(AB / "demo_tiptoe_walk.wav", walk)
    demo, dmarks = adaptive_demo()
    _write(AB / "demo_adaptive_music.wav", demo)
    png("adaptive_music", demo, "adaptive music: sneak, suspense layer, Mountain King links 1-4 switched on bar lines, back to sneak",
        marks=dmarks, width=1400)
    for lid, _ in VOICE_AB:
        for style, prefix in (("formant", "vo_bellows_"), ("tuba", "vo_bellows_tuba_")):
            x = _load(prefix + lid)
            _write(AB / f"voice_{lid}_{style}.wav", x)
    for lid in ("pipe_down_1", "aria_1", "crack_1"):
        for style, prefix in (("formant", "vo_bellows_"), ("tuba", "vo_bellows_tuba_")):
            png(f"voice_{lid}_{style}", _load(prefix + lid), f"Bellows {lid} ({style})")
    for cid, _ in CROWD_AB:
        for style, prefix in (("formant", "crowd_"), ("fallback", "crowd_fb_")):
            x = _load(prefix + cid)
            _write(AB / f"crowd_{cid}_{style}.wav", x)
    for cid in ("t2_1", "t4_1"):
        for style, prefix in (("formant", "crowd_"), ("fallback", "crowd_fb_")):
            png(f"crowd_{cid}_{style}", _load(prefix + cid), f"the Stalls {cid} ({style})")
    for fid, _ in TOP_SFX:
        _write(AB / f"sfx_{fid}.wav", _load(fid))
    png("clarence", strip([f"clarence_squeak_{i}" for i in range(1, 6)] + ["clarence_wheeze", "clarence_smitten"]),
        "Clarence: 5 squeak pitches, the falling wheeze, smitten", width=1200)
    png("sfx_top10", strip([f for f, _ in TOP_SFX], 0.2), "the ten most important SFX, in order", width=1400)
    png("mus_chain_1", _load("mus_chain_1"), "mus_chain_1 (Mountain King, 120 bpm), loop seam at right", loop=True,
        width=1200)
    png("mus_sneak", _load("mus_sneak"), "mus_sneak (60 s loop), loop seam at right", loop=True, width=1400)
    png("mus_curtain", _load("mus_curtain"), "mus_curtain: roll, fanfare, title slam")
    return wrote


def _main_pack() -> int:
    for w in pack():
        print("wrote", DOCS / w)
    tot = sum(p.stat().st_size for p in AB.glob("*.wav"))
    print(f"A/B folder: {len(list(AB.glob('*.wav')))} WAVs, {tot / 1e6:.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
