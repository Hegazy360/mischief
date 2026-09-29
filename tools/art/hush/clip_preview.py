#!/usr/bin/env python3
"""clip_preview — fast Python frame strips of the Hush clips (the authoring loop; the engine sheets are the proof).

    python3 tools/art/hush/clip_preview.py <clip> [<clip> ...] --out DIR [--every N] [--zoom Z] [--skin pip]
                                           [--frames a,b,c] [--cols C] [--bg #RRGGBB]

Samples game/data/anim/hush/<clip>.json the way RigSampler does (keys = named pose + `set`, linear per-channel
interpolation with the incoming key's ease, discrete channels and faces stepping on keys, Clarence socket/state
from the prop events) and composes each frame with fk.Rig (rsvg-convert). Writes <clip>_strip.png: one cell per
sampled frame, the frame number and the key/event marks printed under it, the floor line drawn. No plant lock,
springs or breathing (those are the runtime's layers), so between sparse keys a planted foot may drift a pixel.
"""
import argparse
import copy
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fk  # noqa: E402
import preview  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

from clipkit import Clip, ease  # noqa: E402,F401  (the sampler lives with the kit: build.py uses it for smears)


def load(skin=None):
	rig, faces, poses = preview.load_rig("hush")
	named = fk.resolve_poses(poses, rig)
	return rig, faces, named, fk.Rig(rig, faces, skin)


def frame_image(R, clip, f, zoom=0.6, W=560, H=500, ox=230, oy=450, bg=None):
	pose, face = clip.sample(f)
	pose = copy.deepcopy(pose)
	pose["props"] = {"clarence": clip.props_at(f)}
	return preview.render(R, pose, face, W=W, H=H, ox=ox, oy=oy, zoom=zoom, bg=bg, floor=False)


def strip(cid, out_dir, every=2, zoom=0.5, skin=None, frames=None, cols=12, bg="#F2DFA6", W=380, H=470, ox=170,
		  oy=440):
	rig, faces, named, R = load(skin)
	data = json.load(open(os.path.join(fk.GAME, "data", "anim", "hush", cid + ".json")))
	c = Clip(rig, named, faces, data)
	fl = frames if frames else list(range(0, c.length + (0 if c.loop else 1), every))
	key_f = set(k["f"] for k in c.keys)
	ev_f = {}
	for e in c.events:
		ev_f.setdefault(e["f"], []).append(e.get("id") or e.get("op") or e.get("type"))
	cw, ch = int(W * zoom), int(H * zoom)
	rows = (len(fl) + cols - 1) // cols
	sheet = Image.new("RGBA", (cw * min(cols, len(fl)), (ch + 30) * rows + 30), (250, 246, 238, 255))
	d = ImageDraw.Draw(sheet)
	preview.label(d, (6, 6), "%s  %d f%s%s" % (data["clip"], c.length, " loop" if c.loop else "",
											   "  skin " + skin if skin else ""), 16, bold=True)
	for i, f in enumerate(fl):
		im = frame_image(R, c, f, zoom=1.0, W=W, H=H, ox=ox, oy=oy, bg=bg)
		im = im.resize((cw, ch), Image.LANCZOS)
		x, y = (i % cols) * cw, 30 + (i // cols) * (ch + 30)
		sheet.alpha_composite(im, (x, y))
		dd = ImageDraw.Draw(sheet)
		dd.line([(x, y + int(oy * zoom)), (x + cw, y + int(oy * zoom))], fill=(27, 35, 64, 140), width=1)
		col = (226, 59, 78, 255) if f in key_f else (27, 35, 64, 255)
		preview.label(dd, (x + 3, y + ch + 2), "f%d" % f, 12, fill=col, bold=f in key_f)
		evs = [s for ff, lst in ev_f.items() if f - every < ff <= f for s in lst]
		if evs:
			preview.label(dd, (x + 3, y + ch + 15), ",".join(evs)[:26], 9)
	os.makedirs(out_dir, exist_ok=True)
	path = os.path.join(out_dir, "%s%s_strip.png" % (cid, "_pip" if skin else ""))
	sheet.save(path)
	return path


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("clips", nargs="+")
	ap.add_argument("--out", required=True)
	ap.add_argument("--every", type=int, default=2)
	ap.add_argument("--zoom", type=float, default=0.5)
	ap.add_argument("--skin", default=None)
	ap.add_argument("--frames", default="")
	ap.add_argument("--cols", type=int, default=12)
	ap.add_argument("--bg", default="#F2DFA6")
	ap.add_argument("--tall", type=int, default=0, help="extra px of headroom above the floor (climbs, jumps)")
	ap.add_argument("--game", default="", help="read rigs/clips from another copy of game/ (a staging tree)")
	a = ap.parse_args()
	if a.game:
		fk.GAME = os.path.abspath(a.game)
	fr = [int(x) for x in a.frames.split(",") if x != ""] or None
	for cid in a.clips:
		print(strip(cid, a.out, a.every, a.zoom, a.skin, fr, a.cols, a.bg, H=470 + a.tall, oy=440 + a.tall))


if __name__ == "__main__":
	main()
