#!/usr/bin/env python3
"""run — bake every clip in a manifest, pack the sheets, and validate the lot.

    python3 tools/bakery/run.py [tools/bakery/clips.json] [--only walk,throw] [--contact]

This is the whole loop an agent drives: edit a number in clips.json, run this, read the verdict.
It never opens Blender's UI, never asks anyone to look at a curve, and exits non-zero if any clip
fails its checks.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BAKE = os.path.join(ROOT, "tools", "bakery", "bake.py")
SHEET = os.path.join(ROOT, "tools", "bakery", "sheet.py")
PRUNE = os.path.join(ROOT, "tools", "bakery", "prune.py")
VALIDATE = os.path.join(ROOT, "tools", "bakery", "validate.py")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest", nargs="?", default=os.path.join(ROOT, "tools", "bakery", "clips.json"))
    ap.add_argument("--only", default="")
    ap.add_argument("--contact", action="store_true", help="also write one contact sheet of every clip")
    ap.add_argument("--keep-frames", action="store_true")
    a = ap.parse_args()

    man = json.load(open(a.manifest))
    d = man.get("defaults", {})
    out_dir = os.path.join(ROOT, man["out"])
    lib_dir = os.path.join(ROOT, man["lib_dir"])
    char = os.path.join(ROOT, man["character"])
    os.makedirs(out_dir, exist_ok=True)
    wanted = set(x for x in a.only.split(",") if x)
    tmp_root = os.path.join("/tmp", "bakery_frames")
    index = {"character": os.path.basename(char), "clips": {}}
    fails: list[str] = []
    dirs: list[str] = []
    labels: list[str] = []
    t0 = time.time()

    for c in man["clips"]:
        name = c["name"]
        if wanted and name not in wanted:
            continue
        frames_dir = os.path.join(tmp_root, name)
        shutil.rmtree(frames_dir, ignore_errors=True)
        cmd = [
            "blender", "-b", "--factory-startup", "--python-exit-code", "1", "-P", BAKE, "--",
            "--char", char,
            "--lib", os.path.join(lib_dir, f"Rig_Medium_{c['lib']}.glb"),
            "--clip", c["clip"], "--out", frames_dir,
            "--amount", str(c.get("amount", 1.0)),
            "--sigma", str(c.get("sigma", d.get("sigma", 2.5))),
            "--frames", str(c.get("frames", d.get("frames", 12))),
            "--angle", str(c.get("angle", d.get("angle", 70))),
            "--res", str(c.get("res", d.get("res", 256))),
            "--loop", "true" if c.get("loop") else "false",
            "--max_deg", str(c.get("max_deg", d.get("max_deg", 28))),
        ]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            print(f"[run] {name}: BAKE FAILED\n{r.stdout[-1500:]}\n{r.stderr[-800:]}")
            fails.append(name)
            continue
        pr = subprocess.run([sys.executable, PRUNE, frames_dir,
                             "--min-change", str(c.get("min_change", d.get("min_change", 0.004)))],
                            capture_output=True, text=True)
        if pr.stdout.strip():
            print(pr.stdout.rstrip())
        sheet_png = os.path.join(out_dir, f"{name}.png")
        s = subprocess.run([sys.executable, SHEET, frames_dir, "--out", sheet_png,
                            "--ink", str(c.get("ink", d.get("ink", 2)))], capture_output=True, text=True)
        if s.returncode != 0:
            print(f"[run] {name}: SHEET FAILED\n{s.stderr[-600:]}")
            fails.append(name)
            continue
        v = subprocess.run([sys.executable, VALIDATE, frames_dir,
                            "--min-span", str(c.get("min_span", d.get("min_span", 0.08))),
                            "--min-change", str(c.get("min_change", d.get("min_change", 0.004)))],
                           capture_output=True, text=True)
        print(v.stdout.rstrip())
        if v.returncode != 0:
            fails.append(name)
        info = json.load(open(os.path.splitext(sheet_png)[0] + ".json"))
        index["clips"][name] = {k: info[k] for k in ("sheet", "frame_w", "frame_h", "count", "accent", "loop", "clip", "amount")}
        dirs.append(frames_dir)
        labels.append(f"{name}  ({c['clip']}, amount {c.get('amount', 1.0)})")

    with open(os.path.join(out_dir, "index.json"), "w") as fh:
        json.dump(index, fh, indent=2)
    if a.contact and dirs:
        subprocess.run([sys.executable, SHEET, "--compare", *dirs, "--labels", *labels,
                        "--out", os.path.join(out_dir, "_contact.png"), "--ink", "2", "--scale", "0.6"])
    if not a.keep_frames:
        shutil.rmtree(tmp_root, ignore_errors=True)
    n = len(index["clips"])
    print(f"\n[run] {n} clip(s) baked in {time.time() - t0:.1f}s -> {man['out']}"
          f"{'' if not fails else '   FAILED: ' + ', '.join(fails)}")
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
