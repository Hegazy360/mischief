#!/usr/bin/env python3
"""Motion-stability report for a Movie Maker capture: finds pops, jitter and frozen frames.

usage: python3 tools/anim/stability.py <capture_dir> <out_prefix> [--roi=x0,y0,x1,y1] [--pop=3.0]

A contact strip shows every Nth frame, so it cannot show a one-frame pop, a two-frame oscillation
or a dead hold -- exactly the faults that read as "unstable" in motion. This reads EVERY frame of
the capture (f00000000.png ...) and measures, per frame, the mean absolute pixel change against the
previous frame inside the ROI (default: the middle band of the image, where the character stands).
From that series it reports:

  pops      frames whose change is > --pop x the median change (a snap, a teleport, an IK flip)
  jitter    how much the change itself oscillates frame to frame (high = shimmering/vibrating)
  frozen    runs of >= 6 frames with ~zero change while the clip is supposed to be moving
  smooth    0-100 score: 100 means every frame moved about as much as its neighbours

Reference values measured on this project: a clean library clip sits at jitter 0.14-0.23
(smooth 88-93). The first cut of our own runtime scored 0.42 (smooth 79) from a jiggle/grounding
feedback loop -- see docs/review/oss_cast/index.md.

Writes <out_prefix>_stability.png (the curve with pops marked) and <out_prefix>_stability.json and
prints one summary line. Pure Pillow + numpy; no engine needed.
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

# A clip blending in from rest is not a pop: ignore the first frames when taking the median.
WARMUP = 6
FROZEN_RUN = 6


def series(cap, roi=None):
    """Mean absolute frame-to-frame change inside the ROI, one value per frame transition."""
    files = sorted(glob.glob(os.path.join(cap, "f*.png")))
    if len(files) < 3:
        raise SystemExit("[stability] fewer than 3 frames in %s" % cap)
    prev, diffs = None, []
    for f in files:
        im = np.asarray(Image.open(f).convert("L"), dtype=np.float32)
        if roi is None:
            h, w = im.shape
            roi = (int(w * 0.2), int(h * 0.05), int(w * 0.8), int(h * 0.95))
        x0, y0, x1, y1 = roi
        im = im[y0:y1, x0:x1]
        if prev is not None:
            diffs.append(float(np.abs(im - prev).mean()))
        prev = im
    return np.array(diffs), roi, len(files)


def report(d, roi, frames, pop_k=3.0):
    body = d[WARMUP:] if len(d) > WARMUP * 2 else d
    med = float(np.median(body)) if body.size else 0.0
    pops = [i + 1 for i, v in enumerate(d) if i >= WARMUP and med > 0 and v > pop_k * med]
    # Jitter: mean |second difference| normalised by the median motion. A smooth cycle has a low
    # second difference; a 2-frame oscillation has a large one every frame.
    jitter = float(np.abs(np.diff(body, 2)).mean() / med) if med > 0 and body.size > 3 else 0.0
    frozen, run = [], 0
    for i, v in enumerate(d):
        if v < max(0.05, med * 0.08):
            run += 1
        else:
            if run >= FROZEN_RUN:
                frozen.append((i - run + 1, i))
            run = 0
    if run >= FROZEN_RUN:
        frozen.append((len(d) - run + 1, len(d)))
    smooth = max(0.0, 100.0 - 100.0 * min(1.0, jitter * 0.5) - 8.0 * len(pops))
    return {"frames": frames, "median_change": round(med, 3), "pops": pops,
            "jitter": round(jitter, 3), "frozen_runs": frozen,
            "smooth_score": round(smooth, 1), "roi": list(roi)}


def plot(d, rep, path, pop_k=3.0):
    W, H = 1200, 260
    img = Image.new("RGB", (W, H), (26, 22, 36))
    dr = ImageDraw.Draw(img)
    top = float(d.max()) if d.size and d.max() > 0 else 1.0
    pts = [(40 + i * (W - 60) / max(1, len(d) - 1), H - 30 - v / top * (H - 60)) for i, v in enumerate(d)]
    med = rep["median_change"]
    if med > 0:
        y = H - 30 - med * pop_k / top * (H - 60)
        dr.line([(40, y), (W - 20, y)], fill=(120, 80, 80), width=1)
    dr.line(pts, fill=(140, 200, 255), width=2)
    for p in rep["pops"]:
        x, y = pts[p - 1]
        dr.ellipse([x - 5, y - 5, x + 5, y + 5], outline=(255, 90, 90), width=2)
    for a, b in rep["frozen_runs"]:
        dr.rectangle([pts[a - 1][0], 20, pts[min(b, len(pts)) - 1][0], H - 30], outline=(255, 200, 80))
    dr.text((40, 6), "frame-to-frame change (ROI) - red ring = pop, yellow box = frozen run, "
                     "red line = pop threshold", fill=(220, 215, 230))
    dr.text((40, H - 22), "smooth %.0f/100  pops %d  jitter %.2f  frozen runs %d  median change %.2f" % (
        rep["smooth_score"], len(rep["pops"]), rep["jitter"], len(rep["frozen_runs"]), med),
        fill=(255, 235, 170))
    img.save(path)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    cap, out = sys.argv[1], sys.argv[2]
    roi, pop_k = None, 3.0
    for a in sys.argv[3:]:
        if a.startswith("--roi="):
            roi = tuple(int(v) for v in a[6:].split(","))
        elif a.startswith("--pop="):
            pop_k = float(a[6:])
    d, roi, frames = series(cap, roi)
    rep = report(d, roi, frames, pop_k)
    with open(out + "_stability.json", "w") as f:
        json.dump(rep, f, indent=1)
    plot(d, rep, out + "_stability.png", pop_k)
    print("[stability] %s: smooth %.0f/100, pops %d %s, jitter %.2f, frozen %s" % (
        os.path.basename(out), rep["smooth_score"], len(rep["pops"]), rep["pops"][:8],
        rep["jitter"], rep["frozen_runs"][:4]))


if __name__ == "__main__":
    main()
