#!/usr/bin/env python3
"""build — render Act I's set in headless Blender and pack it for the game.

    python3 tools/stage/build.py [--only bg,prop_glove]

Runs tools/stage/act1_set.py (the room, props, proscenium, audience and HUD icons, all modelled
from primitives there), crops every layer to its pixels, and writes game/proto/act1/art/ + layout.json:
for each layer its PNG, its top-left in the 2400x1080 stage, and (for props) the pivot it turns or
falls about. The game only ever draws these PNGs at those positions.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SET = os.path.join(ROOT, "tools", "stage", "act1_set.py")
OUT = os.path.join(ROOT, "game", "proto", "act1", "art")
FULL = ("bg",)          # drawn whole, never cropped


def main() -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("--only", default="")
	ap.add_argument("--engine", default="cycles", help="cycles (final) or eevee (fast preview)")
	ap.add_argument("--samples", type=int, default=128)
	a = ap.parse_args()
	raw = tempfile.mkdtemp(prefix="act1_set_")
	cmd = ["blender", "-b", "--factory-startup", "--python-exit-code", "1", "-P", SET, "--", "--out", raw,
		   "--engine", a.engine, "--samples", str(a.samples)]
	if a.only:
		cmd += ["--only", a.only]
	r = subprocess.run(cmd, capture_output=True, text=True)
	if r.returncode != 0:
		print(r.stdout[-2000:], r.stderr[-1000:])
		return 1
	marks = json.load(open(os.path.join(raw, "marks.json")))
	os.makedirs(OUT, exist_ok=True)
	lay_path = os.path.join(OUT, "layout.json")
	layout = json.load(open(lay_path)) if (a.only and os.path.exists(lay_path)) else {"layers": {}}
	layout.update({k: marks[k] for k in ("size", "px_per_unit", "floor_px", "tilt_deg", "marks", "pivots")})
	for f in sorted(os.listdir(raw)):
		if not f.endswith(".png"):
			continue
		name = f[:-4]
		im = Image.open(os.path.join(raw, f)).convert("RGBA")
		box = (0, 0, im.width, im.height) if name in FULL else im.getchannel("A").point(lambda v: 255 if v > 2 else 0).getbbox()
		if box is None:
			print(f"[stage] {name}: EMPTY render")
			return 1
		im.crop(box).save(os.path.join(OUT, f), optimize=True)
		layout["layers"][name] = {"png": f, "pos": [box[0], box[1]], "size": [box[2] - box[0], box[3] - box[1]]}
		print(f"[stage] {name:16s} {box[2] - box[0]:5d}x{box[3] - box[1]:<5d} at ({box[0]}, {box[1]})")
	# frame sequences: seq_<name>_NN (in place on the stage) and fxs_<name>_NN (local effects)
	seqs: dict = {}
	for name in sorted(layout["layers"]):
		for pre in ("seq_", "fxs_"):
			if name.startswith(pre) and name[-3] == "_" and name[-2:].isdigit():
				seqs.setdefault(name[:-3], []).append(name)
	layout["seqs"] = {k: sorted(v) for k, v in seqs.items()}
	layout["doc"] = ("Act I set, rendered by tools/stage/build.py from tools/stage/act1_set.py. Positions are "
					 "logical px in the 2400x1080 stage; `marks` and `pivots` are named world points projected "
					 "by the same camera.")
	with open(lay_path, "w") as fh:
		json.dump(layout, fh, indent=1)
	shutil.rmtree(raw, ignore_errors=True)
	print(f"[stage] {len(layout['layers'])} layers -> {os.path.relpath(OUT, ROOT)}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
