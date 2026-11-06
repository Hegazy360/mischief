#!/usr/bin/env python3
"""prune — drop rendered frames you cannot tell apart at game size.

Pose-space distance is a poor proxy for what the player sees: a finger moving 2 cm changes the pose
numbers and changes nothing on screen. So the dedupe happens here, on the rendered silhouette at the
size the sprite will actually be drawn. Frame 0 and the accent are never dropped.

    python3 tools/bakery/prune.py /tmp/bakery_frames/idle [--min-change 0.004] [--read-px 48]
"""
from __future__ import annotations

import argparse
import glob
import json
import os

import numpy as np
from PIL import Image


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--min-change", type=float, default=0.004)
    ap.add_argument("--read-px", type=int, default=48)
    a = ap.parse_args()

    paths = sorted(glob.glob(os.path.join(a.dir, "f*.png")))
    if len(paths) < 2:
        return
    mp = os.path.join(a.dir, "meta.json")
    meta = json.load(open(mp)) if os.path.exists(mp) else {}
    accent = int(meta.get("accent", 0))

    def sil(p: str) -> np.ndarray:
        al = Image.open(p).convert("RGBA").getchannel("A")
        return np.array(al.resize((a.read_px, a.read_px), Image.BILINEAR)) > 96

    sils = [sil(p) for p in paths]
    keep = [0]
    for i in range(1, len(paths)):
        if i == accent or float((sils[i] ^ sils[keep[-1]]).mean()) >= a.min_change:
            keep.append(i)
    if len(keep) == len(paths):
        return

    imgs = [Image.open(p).copy() for p in paths]
    for p in paths:
        os.remove(p)
    for new_i, old_i in enumerate(keep):
        imgs[old_i].save(os.path.join(a.dir, f"f{new_i:03d}.png"))
    meta["frames"] = len(keep)
    meta["accent"] = keep.index(accent) if accent in keep else 0
    meta["pruned"] = len(paths) - len(keep)
    with open(mp, "w") as fh:
        json.dump(meta, fh, indent=2)
    print(f"[prune] {os.path.basename(a.dir)}: dropped {len(paths) - len(keep)} "
          f"indistinguishable frame(s), {len(keep)} left")


if __name__ == "__main__":
    main()
