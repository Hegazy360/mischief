#!/usr/bin/env python3
"""Plot a clip's motion curves (TECH §11): <clip>_curves.json (from sheet.gd) → PNG.

usage: python3 tools/anim/curves.py <clip>_curves.json <out.png> [--top=N] [--channels=a,b]

One row per channel (the N most active by default, 12): the value curve (left axis) and its
velocity per frame (thin grey, right axis), key frames as red ticks with their ease names on
the first row, beats as coloured bands, events as dots on the time axis. Flat-then-steep =
a snap; evenly sloped = floaty; wiggles = jitter. Pillow + numpy only (no matplotlib).
"""
import json
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

BG = (250, 248, 242)
INK = (27, 35, 64)
KEY = (214, 40, 57)
VEL = (150, 150, 160)
GRID = (225, 222, 214)
BEATS = {"anticipation": (242, 179, 61), "accent": (214, 40, 57), "hold": (46, 111, 216), "settle": (47, 163, 154)}


def font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def activity(v):
    a = np.asarray(v, dtype=float)
    return float(np.abs(np.diff(a)).sum()) if a.size > 1 else 0.0


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    doc = json.load(open(argv[1]))
    out = argv[2]
    top = 12
    only = None
    for a in argv[3:]:
        if a.startswith("--top="):
            top = int(a[6:])
        elif a.startswith("--channels="):
            only = a[11:].split(",")
    chans = doc.get("channels", {})
    names = list(chans.keys())
    if only:
        names = [n for n in names if n in only]
    else:
        names.sort(key=lambda n: -activity(chans[n]) * (0.01 if n.endswith((".sx", ".sy", ".alpha")) and False else 1))
        names = names[:top]
    length = int(doc.get("length", 1))
    W, row_h, left, right, head = 1600, 120, 190, 70, 70
    H = head + row_h * max(1, len(names)) + 40
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    f_small, f_mid, f_big = font(12), font(14), font(20)
    plot_w = W - left - right

    def fx(f):
        return left + plot_w * f / max(1, length)

    title = "%s — %d f%s  tier %s%s  (value = ink, velocity/f = grey; red = keys)" % (
        doc.get("clip", "?"), length, " loop" if doc.get("loop") else "", doc.get("tier", 1),
        " suppressed" if doc.get("suppressed") else "")
    d.text((14, 12), title, fill=INK, font=f_big)
    # Beats band + events on top.
    for bn, (b0, b1) in doc.get("beats", {}).items():
        col = BEATS.get(bn, (154, 143, 176))
        d.rectangle([fx(b0), head - 26, fx(b1), head - 10], fill=col)
        d.text((fx(b0) + 3, head - 26), bn, fill=INK, font=f_small)
    for ev in doc.get("events", []):
        x = fx(ev["f"])
        d.ellipse([x - 3, head - 8, x + 3, head - 2], fill=INK)
    keys = doc.get("keys", [])
    for r, name in enumerate(names):
        y0 = head + r * row_h
        y1 = y0 + row_h - 14
        d.rectangle([left, y0, left + plot_w, y1], outline=GRID)
        for (b0, b1), col in [((v[0], v[1]), BEATS.get(k, (154, 143, 176))) for k, v in doc.get("beats", {}).items()]:
            d.rectangle([fx(b0), y0 + 1, fx(b1), y1 - 1], fill=tuple(int(c * 0.12 + 250 * 0.88) for c in col))
        for k in keys:
            x = fx(k["f"])
            d.line([x, y0, x, y1], fill=KEY, width=1)
            if r == 0:
                d.text((x + 2, y0 + 2), k.get("ease", ""), fill=KEY, font=f_small)
        v = np.asarray(chans[name], dtype=float)
        lo, hi = float(v.min()), float(v.max())
        if hi - lo < 1e-6:
            hi = lo + 1.0
        pad = (hi - lo) * 0.08
        lo, hi = lo - pad, hi + pad
        pts = [(fx(i), y1 - (y1 - y0) * (val - lo) / (hi - lo)) for i, val in enumerate(v)]
        vel = np.diff(v) if v.size > 1 else np.zeros(1)
        vm = float(np.abs(vel).max()) or 1.0
        vpts = [(fx(i + 0.5), (y0 + y1) / 2 - (y1 - y0) * 0.45 * val / vm) for i, val in enumerate(vel)]
        d.line([(left, (y0 + y1) / 2), (left + plot_w, (y0 + y1) / 2)], fill=GRID)
        if len(vpts) > 1:
            d.line(vpts, fill=VEL, width=1)
        if len(pts) > 1:
            d.line(pts, fill=INK, width=2)
        for i, p in enumerate(pts):
            d.ellipse([p[0] - 1.5, p[1] - 1.5, p[0] + 1.5, p[1] + 1.5], fill=INK)
        d.text((10, y0 + 4), name, fill=INK, font=f_mid)
        d.text((10, y0 + 24), "%.1f … %.1f" % (float(v.min()), float(v.max())), fill=INK, font=f_small)
        d.text((10, y0 + 40), "peak |v| %.1f/f" % vm, fill=VEL, font=f_small)
    # Frame axis.
    ya = H - 34
    for f in range(0, length + 1, 10):
        d.line([fx(f), ya, fx(f), ya + 5], fill=INK)
        d.text((fx(f) - 6, ya + 7), str(f), fill=INK, font=f_small)
    img.save(out)
    print("[curves] wrote %s (%d channels)" % (out, len(names)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
