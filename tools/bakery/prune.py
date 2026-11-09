#!/usr/bin/env python3
"""prune — drop rendered frames you cannot tell apart at game size.

Pose-space distance is a poor proxy for what the player sees: a finger moving 2 cm changes the pose
numbers and changes nothing on screen. So the dedupe happens here, on the rendered silhouette at the
size the sprite will actually be drawn. Frame 0 and the accent are never dropped. A dropped frame's
screen time is handed to the frame before it, so pruning never changes how long a clip takes — it
only stops the atlas paying for poses nobody can see. On a loop the last frame is also compared with
the first, because that is the frame it is shown next to.

    python3 tools/bakery/prune.py /tmp/bakery_frames/idle [--min-change 0.004] [--read-px 48]
"""
from __future__ import annotations

import argparse
import glob
import json
import os

import numpy as np
from PIL import Image

from validate import sil_one


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

    sils = [sil_one(np.array(Image.open(p).convert("RGBA"))[:, :, 3], a.read_px) for p in paths]
    durs = list(meta.get("durations", [0.0] * len(paths)))
    keep = [0]
    kdur = [durs[0]]
    for i in range(1, len(paths)):
        seam_dup = (bool(meta.get("loop")) and i == len(paths) - 1 and i != accent
                    and float((sils[i] ^ sils[0]).mean()) < a.min_change)
        if not seam_dup and (i == accent or float((sils[i] ^ sils[keep[-1]]).mean()) >= a.min_change):
            keep.append(i)
            kdur.append(durs[i])
        else:
            kdur[-1] += durs[i]
    # a loop's last frame sits next to its first: keep folding it back while the two are the same
    # pose, or every cycle stutters on a held frame
    while (meta.get("loop") and len(keep) > 2 and keep[-1] != accent
           and float((sils[keep[-1]] ^ sils[0]).mean()) < a.min_change):
        keep.pop()
        d = kdur.pop()
        kdur[-1] += d
    if len(keep) == len(paths):
        return

    imgs = [Image.open(p).copy() for p in paths]
    for p in paths:
        os.remove(p)
    for new_i, old_i in enumerate(keep):
        imgs[old_i].save(os.path.join(a.dir, f"f{new_i:03d}.png"))
    meta["frames"] = len(keep)
    meta["durations"] = [round(d, 4) for d in kdur]
    if "source_frames" in meta:
        meta["source_frames"] = [meta["source_frames"][i] for i in keep]
    meta["accent"] = keep.index(accent) if accent in keep else 0
    meta["pruned"] = len(paths) - len(keep)
    with open(mp, "w") as fh:
        json.dump(meta, fh, indent=2)
    print(f"[prune] {os.path.basename(a.dir)}: dropped {len(paths) - len(keep)} "
          f"indistinguishable frame(s), {len(keep)} left")


if __name__ == "__main__":
    main()
