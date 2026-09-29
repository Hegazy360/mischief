#!/usr/bin/env python3
"""Movie Maker capture → review GIFs (TECH §11). Pillow + numpy only.

usage: python3 tools/anim/gif.py <capture_dir> <out.gif> [--width=720] [--fps=30] [--max-mb=4]

<capture_dir> holds Godot Movie Maker output (f00000000.png …, f.wav at 60 fps) and the
capture.gd event log (events.json). Writes:
  <out>.gif        30 fps, with a SOUND STRIP under the picture: the WAV's loudness per frame,
                   detected onsets (orange ticks), the scene's sfx/voice events (labels) and a
                   playhead — so a reviewer can see whether sound lands on the contact frame
  <out>_mute.gif   the picture only (the mute test pack, docs/review/mute_test/)
  <out>.wav        the captured audio (kept for sync checks)
  <out>_events.json, <out>_sync.json   the event log and onset ↔ event offsets (frames)
GIFs are shrunk until they fit --max-mb.
"""
import glob
import json
import os
import shutil
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFont

STRIP_H = 64


def font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"):
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


def onsets(env, thresh=0.02, rise=2.5):
    out = []
    for i in range(1, len(env)):
        prev = max(env[max(0, i - 3):i].mean(), 1e-5)
        if env[i] > thresh and env[i] > prev * rise and (not out or i - out[-1] > 3):
            out.append(i)
    return out


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    cap, out = argv[1], argv[2]
    width, fps, max_mb = 720, 30, 4.0
    for a in argv[3:]:
        if a.startswith("--width="):
            width = int(a[8:])
        elif a.startswith("--fps="):
            fps = int(a[6:])
        elif a.startswith("--max-mb="):
            max_mb = float(a[9:])
    pngs = sorted(glob.glob(os.path.join(cap, "f*.png")))
    if not pngs:
        print("[gif] no frames in %s" % cap)
        return 1
    events = []
    ev_path = os.path.join(cap, "events.json")
    if os.path.exists(ev_path):
        events = json.load(open(ev_path)).get("events", [])
    a, rate = read_wav(os.path.join(cap, "f.wav"))
    frames = len(pngs)
    env = envelope(a, rate, frames)
    ons = onsets(env)
    base = out[:-4] if out.endswith(".gif") else out
    # Sync report: each sfx / voice event vs the nearest onset.
    sync = []
    for e in events:
        if e.get("type") in ("sfx", "voice"):
            f = int(e["engine_frame"])
            near = min(ons, key=lambda o: abs(o - f)) if ons else None
            sync.append({"engine_frame": f, "type": e["type"], "id": e.get("id", ""), "clip_frame": e.get("clip_frame"),
                         "onset": near, "offset_f": (near - f) if near is not None else None})
    json.dump({"frames": frames, "onsets": ons, "events": sync}, open(base + "_sync.json", "w"), indent=1)
    if os.path.exists(os.path.join(cap, "f.wav")):
        shutil.copy(os.path.join(cap, "f.wav"), base + ".wav")
    if os.path.exists(ev_path):
        shutil.copy(ev_path, base + "_events.json")
    step = max(1, round(60 / fps))
    pick = list(range(0, frames, step))
    peak = max(float(env.max()), 1e-4)
    f_small = font(11)

    def render(w):
        pics, strips = [], []
        for i in pick:
            im = Image.open(pngs[i]).convert("RGB")
            h = round(im.height * w / im.width)
            im = im.resize((w, h), Image.LANCZOS)
            pics.append(im)
            s = Image.new("RGB", (w, h + STRIP_H), (16, 14, 26))
            s.paste(im, (0, 0))
            d = ImageDraw.Draw(s)
            y0 = h + 6
            y1 = h + STRIP_H - 18
            for k in range(frames):
                x = k * (w - 1) / max(1, frames - 1)
                v = env[k] / peak
                d.line([x, y1, x, y1 - (y1 - y0) * v], fill=(90, 200, 255) if k <= i else (60, 70, 100))
            for o in ons:
                x = o * (w - 1) / max(1, frames - 1)
                d.line([x, y0 - 4, x, y0 + 2], fill=(255, 170, 40), width=2)
            by_f = {}
            for e in events:
                if e.get("type") not in ("sfx", "voice", "hitstop", "mark"):
                    continue
                f = int(e["engine_frame"])
                x = f * (w - 1) / max(1, frames - 1)
                col = (255, 90, 107) if e.get("type") == "mark" else (240, 240, 240)
                d.line([x, y1, x, y1 + 4], fill=col)
                if e.get("type") in ("sfx", "voice", "mark"):
                    by_f.setdefault(f, []).append(str(e.get("id", "")))
            # One label: the latest sound events at or before the playhead (within 20 f).
            recent = [f for f in by_f if 0 <= i - f <= 20]
            if recent:
                f = max(recent)
                x = f * (w - 1) / max(1, frames - 1)
                d.text((min(x + 2, w - 220), y1 + 3), " + ".join(by_f[f])[:48], fill=(255, 220, 120), font=f_small)
            xp = i * (w - 1) / max(1, frames - 1)
            d.line([xp, y0 - 6, xp, h + STRIP_H], fill=(255, 255, 255), width=2)
            d.text((4, h + STRIP_H - 14), "frame %d/%d · sound (blue) · onsets (orange) · events (labels)" % (i, frames), fill=(180, 180, 200), font=f_small)
            strips.append(s)
        return pics, strips

    def save(images, path):
        pal_src = Image.new("RGB", (images[0].width, images[0].height * min(4, len(images))))
        for k in range(min(4, len(images))):
            pal_src.paste(images[k * len(images) // min(4, len(images))], (0, images[0].height * k))
        pal = pal_src.quantize(colors=160, method=Image.Quantize.MEDIANCUT)
        q = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in images]
        q[0].save(path, save_all=True, append_images=q[1:], duration=round(1000 / fps), loop=0, optimize=True, disposal=1)
        return os.path.getsize(path) / (1024 * 1024)

    w = width
    for attempt in range(6):
        pics, strips = render(w)
        mb = save(strips, base + ".gif")
        mb2 = save(pics, base + "_mute.gif")
        if max(mb, mb2) <= max_mb:
            break
        w = int(w * 0.85)
    print("[gif] %s.gif (%.2f MB), %s_mute.gif (%.2f MB), %d frames @ %d fps, width %d, %d onsets, %d sound events" % (
        base, mb, base, mb2, len(pick), fps, w, len(ons), len(sync)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
