#!/usr/bin/env python3
"""validate — judge a baked clip without a human looking at it.

An agent cannot see motion. These checks are the substitute: they fail the things that actually go
wrong in a bake — an empty frame, a stalled frame, a silhouette too mushy to read at game size, a
character clipped by the edge of its own cell. Everything is measured off the rendered PNGs, so it
tests what will ship, not what the rig intended.

    python3 tools/bakery/validate.py /tmp/bake/throw_0.8 [--min-change 0.02] [--read-px 48]
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image


def alpha_stack(d: str) -> tuple[np.ndarray, list[str]]:
    paths = sorted(glob.glob(os.path.join(d, "f*.png")))
    if not paths:
        raise SystemExit(f"no frames in {d}")
    arrs = [np.array(Image.open(p).convert("RGBA"))[:, :, 3] for p in paths]
    return np.stack(arrs), [os.path.basename(p) for p in paths]


def silhouette(a: np.ndarray, px: int) -> np.ndarray:
    """Binary silhouette downsampled to `px` tall — what the shape reads as at game size."""
    out = []
    for f in a:
        im = Image.fromarray((f > 96).astype(np.uint8) * 255).resize((px, px), Image.BILINEAR)
        out.append(np.array(im) > 96)
    return np.stack(out)


def check(d: str, min_change: float, min_span: float, read_px: int, edge_tol: int) -> int:
    a, names = alpha_stack(d)
    meta = {}
    mp = os.path.join(d, "meta.json")
    if os.path.exists(mp):
        meta = json.load(open(mp))
    n = len(a)
    fails: list[str] = []
    rows: list[tuple[str, bool, str]] = []

    def add(name: str, ok: bool, detail: str) -> None:
        rows.append((name, ok, detail))
        if not ok:
            fails.append(name)

    cover = (a > 96).mean(axis=(1, 2))
    add("every frame has a character in it", bool(cover.min() > 0.004),
        f"thinnest frame {names[int(np.argmin(cover))]} covers {cover.min() * 100:.2f}%")

    sil = silhouette(a, read_px)
    if n > 1:
        deltas = np.array([(sil[i] ^ sil[i - 1]).mean() for i in range(1, n)])
        worst = int(np.argmin(deltas)) + 1
        # a frame that barely changed is a BUG (a stall, a duplicate pose); the floor is low on
        # purpose, because a gentle idle is not a bug
        add("no dead frames (each one moves)", bool(deltas.min() >= min_change),
            f"smallest step {deltas.min() * 100:.2f}% at {names[worst]} (floor {min_change * 100:.2f}%)")
        # how much the whole clip reads at game size is the QUALITY bar, and it is per clip: an idle
        # and a throw have different jobs
        span = max((sil[i] ^ sil[j]).mean() for i in range(n) for j in range(i + 1, n))
        add(f"reads at {read_px}px (span >= {min_span * 100:.0f}%)", bool(span >= min_span),
            f"widest silhouette change {span * 100:.1f}%")
    else:
        add("no dead frames (each one moves)", True, "single frame, skipped")

    h, w = a.shape[1], a.shape[2]
    border = max(a[:, :edge_tol, :].max(), a[:, -edge_tol:, :].max(),
                 a[:, :, :edge_tol].max(), a[:, :, -edge_tol:].max())
    add("nothing is clipped by the cell edge", bool(border <= 8), f"strongest edge alpha {int(border)}/255")

    acc = int(meta.get("accent", -1))
    add("the accent frame is recorded", 0 <= acc < n, f"accent {acc} of {n}")

    dup = sum(1 for i in range(1, n) if np.array_equal(a[i], a[i - 1]))
    add("no duplicate frames", dup == 0, f"{dup} repeated frame(s)")

    label = f"{meta.get('clip', os.path.basename(d))} amount={meta.get('amount', '?')}"
    print(f"\n[validate] {label}  ({n} frames, {w}x{h})")
    for name, ok, detail in rows:
        print(f"  {'PASS' if ok else 'FAIL'}  {name:38s} {detail}")
    print(f"  => {'PASS' if not fails else 'FAIL'} ({len(rows) - len(fails)}/{len(rows)})")
    return 1 if fails else 0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--min-change", type=float, default=0.004)
    ap.add_argument("--min-span", type=float, default=0.08)
    ap.add_argument("--read-px", type=int, default=48)
    ap.add_argument("--edge-tol", type=int, default=2)
    a = ap.parse_args()
    rc = 0
    for d in a.dirs:
        rc |= check(d, a.min_change, a.min_span, a.read_px, a.edge_tol)
    sys.exit(rc)


if __name__ == "__main__":
    main()
