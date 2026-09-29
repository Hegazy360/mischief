#!/usr/bin/env python3
"""Movie Maker capture → review GIFs + a numbered frame strip (TECH §11, s2-rig §4.1.6).

usage: python3 tools/anim/gif.py <capture_dir> <out.gif> [--width=720] [--fps=30] [--max-mb=4]
                                 [--strip-every=3] [--strip-range=F0-F1] [--strip-w=400]
                                 [--strip-cols=6] [--strip-max=60]

<capture_dir> holds Godot Movie Maker output (f00000000.png …, f.wav at 60 fps) and the
capture.gd event log (events.json). Writes:
  <out>.gif        the picture + a SOUND STRIP under it: the WAV's loudness per frame,
                   detected onsets (orange ticks), the scene's sfx/voice/mark events (labels)
                   and a playhead — so a reviewer can SEE whether sound lands on the frame
  <out>_mute.gif   the picture only (the mute test pack)
  <out>_strip.png  numbered PNG frame strip (ruling L10: what reviewers read): a cell every
                   N frames (default 3) with its movie frame number, at phone scale; more
                   than --strip-max cells continue in <out>_strip_2.png, _3 …
  <out>.wav        the captured audio (the game's own mix)
  <out>_events.json, <out>_sync.json   the event log and onset ↔ event offsets (frames)
GIFs stay under --max-mb: width shrinks first (to a 320 px floor), then the fps drops
(30 → 20 → 15 → 10); every reduction is reported on stderr.
Frames stream from disk (a 2400-frame in-game capture never sits in memory).
"""
import glob
import json
import math
import os
import shutil
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFont

STRIP_H = 64
MIN_W = 320
FPS_STEPS = (30, 20, 15, 10)


def font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
              "/usr/share/fonts/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default()


def read_wav(path):
    if not os.path.exists(path):
        return None, 0
    with wave.open(path, "rb") as w:
        n, ch, sw, rate = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
        raw = w.readframes(n)
    if sw == 2:
        a = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    elif sw == 4:
        a = np.frombuffer(raw, dtype="<i4").astype(np.float32) / 2147483648.0
    else:
        a = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
    if ch > 1:
        a = a.reshape(-1, ch).mean(axis=1)
    return a, rate


def envelope(a, rate, frames, fps=60):
    """RMS per video frame."""
    if a is None or rate == 0:
        return np.zeros(frames)
    spf = rate / fps
    env = np.zeros(frames)
    for i in range(frames):
        s = a[int(i * spf):int((i + 1) * spf)]
        env[i] = float(np.sqrt(np.mean(s * s))) if s.size else 0.0
    return env


def onsets(a, rate, frames, fps=60, floor=0.012, rise=1.6):
    """Sound onsets as movie frames: RMS over ~6 ms hops; an onset is a hop louder than
    `floor` and `rise` × the mean of the previous ~30 ms (so a sound starting over another
    still counts), at least 3 frames after the previous onset."""
    if a is None or rate == 0:
        return []
    hop = max(32, rate // 160)
    n = len(a) // hop
    if n < 2:
        return []
    r = np.sqrt(np.mean(a[:n * hop].reshape(n, hop) ** 2, axis=1))
    spf = rate / fps
    out = []
    for i in range(1, n):
        prev = max(float(r[max(0, i - 5):i].mean()), 1e-5)
        if r[i] > floor and r[i] > prev * rise:
            f = int(i * hop / spf)
            if f < frames and (not out or f - out[-1] >= 3):
                out.append(f)
    return out


def sync_report(events, ons):
    """Each sfx / voice event vs the nearest WAV onset (`offset_f`; ± 1 f = in sync; None when
    no onset within 6 f — soft sounds, music underneath) and, for clip sfx / voice events, vs
    the nearest sound an AudioStreamPlayer actually started (`audio_offset_f`, exact: from the
    capture log)."""
    starts = [int(e["engine_frame"]) for e in events if e.get("type") == "audio"]
    sync = []
    for e in events:
        if e.get("type") in ("sfx", "voice", "audio"):
            f = int(e["engine_frame"])
            near = min(ons, key=lambda o: abs(o - f)) if ons else None
            if near is not None and abs(near - f) > 6:
                near = None
            row = {"engine_frame": f, "type": e["type"], "id": e.get("id", ""), "clip": e.get("clip", ""),
                   "clip_frame": e.get("clip_frame"), "onset": near, "offset_f": (near - f) if near is not None else None}
            if e.get("type") != "audio" and starts:
                a = min(starts, key=lambda o: abs(o - f))
                row["audio_offset_f"] = (a - f) if abs(a - f) <= 6 else None
            sync.append(row)
    offs = [abs(s["offset_f"]) for s in sync if s["offset_f"] is not None]
    return sync, (max(offs) if offs else None)


def parse_range(s, frames):
    if not s:
        return 0, frames - 1
    a, _, b = s.partition("-")
    lo = int(a) if a else 0
    hi = int(b) if b else frames - 1
    return max(0, lo), min(frames - 1, hi)


def write_strips(pngs, base, every, rng, cell_w, cols, max_cells):
    """Numbered frame strip(s): a cell every `every` frames in `rng`, frame number on each."""
    lo, hi = rng
    picks = list(range(lo, hi + 1, max(1, every)))
    if not picks:
        return []
    with Image.open(pngs[picks[0]]) as first:
        cell_h = round(first.height * cell_w / first.width)
    lab_h = 30
    f_lab = font(20)
    out = []
    for sheet in range(0, len(picks), max_cells):
        chunk = picks[sheet:sheet + max_cells]
        rows = math.ceil(len(chunk) / cols)
        ncol = min(cols, len(chunk))
        im = Image.new("RGB", (ncol * (cell_w + 6) + 6, rows * (cell_h + lab_h + 6) + 6), (16, 14, 26))
        d = ImageDraw.Draw(im)
        for k, f in enumerate(chunk):
            x = 6 + (k % cols) * (cell_w + 6)
            y = 6 + (k // cols) * (cell_h + lab_h + 6)
            with Image.open(pngs[f]) as src:
                im.paste(src.convert("RGB").resize((cell_w, cell_h), Image.LANCZOS), (x, y + lab_h))
            d.text((x + 4, y + 4), "f%d" % f, fill=(255, 236, 170), font=f_lab)
        name = base + ("_strip.png" if sheet == 0 else "_strip_%d.png" % (sheet // max_cells + 1))
        im.save(name, optimize=True)
        out.append(name)
    return out


class Renderer:
    """Renders one output frame (picture, or picture + sound strip) at width `w`."""

    def __init__(self, pngs, env, ons, events, frames):
        self.pngs, self.env, self.ons, self.events, self.frames = pngs, env, ons, events, frames
        self.peak = max(float(env.max()), 1e-4) if len(env) else 1e-4
        self.f_small = font(11)
        self.by_f = {}
        for e in events:
            if e.get("type") in ("sfx", "voice", "mark") or (e.get("type") == "audio" and e.get("player") != "Blips"):
                self.by_f.setdefault(int(e["engine_frame"]), []).append(str(e.get("id", "")))

    def picture(self, i, w):
        with Image.open(self.pngs[i]) as src:
            im = src.convert("RGB")
            h = round(im.height * w / im.width)
            return im.resize((w, h), Image.LANCZOS)

    def _strips(self, w, h):
        """The sound strip at width w, drawn once: (played, unplayed) images (envelope,
        onsets, event ticks) — each frame only pastes the played part and draws the playhead."""
        key = (w, h)
        if getattr(self, "_strip_key", None) == key:
            return self._strip_imgs
        n = max(1, self.frames - 1)
        y0, y1 = 6, STRIP_H - 18
        imgs = []
        for col in ((90, 200, 255), (60, 70, 100)):
            s = Image.new("RGB", (w, STRIP_H), (16, 14, 26))
            d = ImageDraw.Draw(s)
            for k in range(self.frames):
                x = k * (w - 1) / n
                v = self.env[k] / self.peak
                d.line([x, y1, x, y1 - (y1 - y0) * v], fill=col)
            for o in self.ons:
                x = o * (w - 1) / n
                d.line([x, y0 - 4, x, y0 + 2], fill=(255, 170, 40), width=2)
            for e in self.events:
                if e.get("type") not in ("sfx", "voice", "hitstop", "mark", "audio"):
                    continue
                x = int(e["engine_frame"]) * (w - 1) / n
                d.line([x, y1, x, y1 + 4], fill=(255, 90, 107) if e.get("type") == "mark" else (240, 240, 240))
            imgs.append(s)
        self._strip_key = key
        self._strip_imgs = imgs
        return imgs

    def with_strip(self, i, w):
        pic = self.picture(i, w)
        h = pic.height
        played, rest = self._strips(w, h)
        n = max(1, self.frames - 1)
        xp = i * (w - 1) / n
        strip = rest.copy()
        if xp >= 1:
            strip.paste(played.crop((0, 0, int(xp) + 1, STRIP_H)), (0, 0))
        s = Image.new("RGB", (w, h + STRIP_H), (16, 14, 26))
        s.paste(pic, (0, 0))
        s.paste(strip, (0, h))
        d = ImageDraw.Draw(s)
        y0, y1 = h + 6, h + STRIP_H - 18
        recent = [f for f in self.by_f if 0 <= i - f <= 20]
        if recent:
            f = max(recent)
            x = f * (w - 1) / n
            d.text((min(x + 2, w - 220), y1 + 3), " + ".join(self.by_f[f])[:48], fill=(255, 220, 120), font=self.f_small)
        d.line([xp, y0 - 6, xp, h + STRIP_H], fill=(255, 255, 255), width=2)
        d.text((4, h + STRIP_H - 14), "frame %d/%d · sound (blue) · onsets (orange) · events (labels)" % (i, self.frames),
               fill=(180, 180, 200), font=self.f_small)
        return s


def save_gif(path, picks, make, fps):
    """Stream frames into a GIF with one shared palette (from up to 4 sample frames)."""
    n = len(picks)
    ns = min(4, n)
    samples = [make(picks[k * n // ns]) for k in range(ns)]
    pal_src = Image.new("RGB", (samples[0].width, samples[0].height * ns))
    for k, im in enumerate(samples):
        pal_src.paste(im, (0, samples[0].height * k))
    pal = pal_src.quantize(colors=160, method=Image.Quantize.MEDIANCUT)

    def rest():
        for i in picks[1:]:
            yield make(i).quantize(palette=pal, dither=Image.Dither.NONE)

    first = make(picks[0]).quantize(palette=pal, dither=Image.Dither.NONE)
    first.save(path, save_all=True, append_images=rest(), duration=round(1000 / fps), loop=0, optimize=True, disposal=1)
    return os.path.getsize(path) / (1024 * 1024)


def fit_gif(path, frames, make, width, fps, max_mb, label):
    """Save, then shrink the width (then the fps) until the GIF fits `max_mb`. → (mb, w, fps)."""
    w = width
    mb = 0.0
    for _ in range(8):
        step = max(1, round(60 / fps))
        picks = list(range(0, frames, step))
        mb = save_gif(path, picks, lambda i: make(i, w), fps)
        if mb <= max_mb:
            return mb, w, fps
        nw = int(w * math.sqrt(max_mb / mb) * 0.93)
        if nw >= MIN_W:
            print("[gif] %s: %.2f MB > %.1f MB at %d px / %d fps → width %d px" % (label, mb, max_mb, w, fps, nw), file=sys.stderr)
            w = nw
            continue
        if w > MIN_W:
            print("[gif] %s: %.2f MB > %.1f MB → width %d px (the floor)" % (label, mb, max_mb, MIN_W), file=sys.stderr)
            w = MIN_W
            continue
        lower = [f for f in FPS_STEPS if f < fps]
        if not lower:
            print("[gif] %s: still %.2f MB at %d px / %d fps (over %.1f MB) — shorten the capture" % (label, mb, w, fps, max_mb),
                  file=sys.stderr)
            return mb, w, fps
        print("[gif] %s: %.2f MB > %.1f MB at %d px → %d fps" % (label, mb, max_mb, w, lower[0]), file=sys.stderr)
        fps = lower[0]
    return mb, w, fps


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    cap, out = argv[1], argv[2]
    width, fps, max_mb = 720, 30, 4.0
    strip_every, strip_range, strip_w, strip_cols, strip_max = 3, "", 400, 6, 60
    for a in argv[3:]:
        k, _, v = a.partition("=")
        if k == "--width":
            width = int(v)
        elif k == "--fps":
            fps = int(v)
        elif k == "--max-mb":
            max_mb = float(v)
        elif k == "--strip-every":
            strip_every = int(v)
        elif k == "--strip-range":
            strip_range = v
        elif k == "--strip-w":
            strip_w = int(v)
        elif k == "--strip-cols":
            strip_cols = int(v)
        elif k == "--strip-max":
            strip_max = int(v)
    pngs = sorted(glob.glob(os.path.join(cap, "f*.png")))
    if not pngs:
        print("[gif] no frames in %s" % cap, file=sys.stderr)
        return 1
    events, scenes = [], []
    ev_path = os.path.join(cap, "events.json")
    if os.path.exists(ev_path):
        log = json.load(open(ev_path))
        events, scenes = log.get("events", []), log.get("scenes", [])
    a, rate = read_wav(os.path.join(cap, "f.wav"))
    frames = len(pngs)
    env = envelope(a, rate, frames)
    ons = onsets(a, rate, frames)
    base = out[:-4] if out.endswith(".gif") else out
    sync, worst = sync_report(events, ons)
    unmatched = sum(1 for e in sync if e["offset_f"] is None)
    aoffs = [abs(e["audio_offset_f"]) for e in sync if e.get("audio_offset_f") is not None]
    silent = sum(1 for e in sync if "audio_offset_f" in e and e["audio_offset_f"] is None)
    json.dump({"frames": frames, "onsets": ons, "worst_offset_f": worst, "no_onset_within_6f": unmatched,
               "worst_audio_offset_f": max(aoffs) if aoffs else None, "events_without_a_sound": silent, "scenes": scenes,
               "events": sync},
              open(base + "_sync.json", "w"), indent=1)
    if os.path.exists(os.path.join(cap, "f.wav")):
        shutil.copy(os.path.join(cap, "f.wav"), base + ".wav")
    if os.path.exists(ev_path):
        shutil.copy(ev_path, base + "_events.json")
    strips = write_strips(pngs, base, strip_every, parse_range(strip_range, frames), strip_w, strip_cols, strip_max)
    r = Renderer(pngs, env, ons, events, frames)
    mb, w, f1 = fit_gif(base + ".gif", frames, r.with_strip, width, fps, max_mb, os.path.basename(base) + ".gif")
    mb2, w2, f2 = fit_gif(base + "_mute.gif", frames, r.picture, width, fps, max_mb, os.path.basename(base) + "_mute.gif")
    print("[gif] %s.gif (%.2f MB, %d px, %d fps), %s_mute.gif (%.2f MB, %d px, %d fps), %d frames, %d onsets, "
          "%d sound events, worst sync %s f (%d without an onset), strip %s" % (base, mb, w, f1, base, mb2, w2, f2, frames, len(ons),
                                                         len(sync), "n/a" if worst is None else worst, unmatched,
                                                         ", ".join(os.path.basename(s) for s in strips)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
