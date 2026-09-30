#!/usr/bin/env python3
"""Hand-made masks + ID pass for the look-A in-game kitchen (`docs/review/lookdev/look-toy/ingame_kitchen.png`), the
real-image fixture of the review toolset (`test_review.py` pins its numbers; `docs/review/r3d-tools-a/` shows them).

  hush_mask.png, bellows_mask.png   black-on-transparent: a hand-traced polygon per character, refined by a flood fill
                                    from the polygon's border through non-ink pixels (L* > 30; the ink outline stops it),
                                    an opening (r 2) and the largest part only
  id.png + legend.json              flat rectangles in flat areas (kitchen / parlour walls and floors, the fireplace,
                                    the gramophone horn, the pantry curtain) + the two character masks

usage: python3 tools/art3d/review/fixtures/lookdev/make_lookdev.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
import _common as cm  # noqa: E402
import lab  # noqa: E402

SRC = cm.REPO / "docs" / "review" / "lookdev" / "look-toy" / "ingame_kitchen.png"
POLY = {
	"hush": [(546, 330), (538, 370), (536, 400), (528, 430), (515, 452), (512, 470), (600, 470), (600, 420),
			(612, 400), (648, 365), (660, 330), (662, 300), (645, 275), (600, 268), (560, 272), (552, 300)],
	"bellows": [(643, 240), (660, 200), (690, 172), (740, 165), (790, 188), (802, 240), (792, 300), (795, 330),
				(794, 370), (760, 390), (724, 386), (700, 384), (660, 396), (648, 380), (643, 320)],
}
RECTS = [  # name, class, extra, ID colour, rectangles (x0, y0, x1, y1)
	("kitchen_wall", "wall", {"room": "kitchen"}, "#FF0000", [(495, 82, 660, 165)]),
	("kitchen_floor", "floor", {"room": "kitchen"}, "#0000FF", [(760, 442, 1040, 492)]),
	("parlour_wall", "wall", {"room": "parlour"}, "#FF8000", [(25, 80, 85, 280), (185, 80, 235, 250)]),
	("parlour_floor", "floor", {"room": "parlour"}, "#8000FF", [(240, 445, 400, 492)]),
	("fireplace", "dressing", {"room": "parlour"}, "#FFFF00", [(38, 300, 78, 420)]),
	("gramophone_horn", "live_prop", {}, "#00FFFF", [(318, 238, 360, 262)]),
	("pantry_curtain", "live_prop", {}, "#00FF00", [(925, 170, 1025, 405)]),
]
CHAR_ID = {"hush": "#008000", "bellows": "#800080"}


def char_mask(img: np.ndarray, L: np.ndarray, poly) -> np.ndarray:
	pm = Image.new("L", (img.shape[1], img.shape[0]), 0)
	ImageDraw.Draw(pm).polygon(poly, fill=255)
	inside = np.asarray(pm) > 0
	allowed = inside & (L > 30)
	cur = inside & ~cm.erode(inside, 1) & allowed
	while True:
		p = np.pad(cur, 1)
		nxt = (cur | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]) & allowed
		if (nxt == cur).all():
			break
		cur = nxt
	mask = inside & ~cur
	er = cm.erode(mask, 2)
	p2 = np.pad(er, 2)
	dil = np.zeros_like(er)
	for dy in range(5):
		for dx in range(5):
			dil |= p2[dy:dy + er.shape[0], dx:dx + er.shape[1]]
	mask &= dil
	lab_c, sizes = cm.components(mask)
	return lab_c == int(np.argmax(sizes))


def main() -> int:
	img = cm.load_rgba(SRC)
	L = lab.rgb_to_lab(img[..., :3])[..., 0]
	idp = np.zeros(img.shape[:2] + (3,), np.uint8)
	legend = []
	for name, cls, extra, col, rects in RECTS:
		for x0, y0, x1, y1 in rects:
			idp[y0:y1, x0:x1] = cm.hex_to_rgb(col)
		legend.append(dict({"color": col, "name": name, "class": cls}, **extra))
	for name, poly in POLY.items():
		m = char_mask(img, L, poly)
		rgba = np.zeros(img.shape, np.uint8)
		rgba[m] = (0, 0, 0, 255)
		Image.fromarray(rgba, "RGBA").save(HERE / ("%s_mask.png" % name), optimize=True)
		idp[m] = cm.hex_to_rgb(CHAR_ID[name])
		legend.append({"color": CHAR_ID[name], "name": name, "class": "character"})
	Image.fromarray(idp).save(HERE / "id.png", optimize=True)
	cm.write_json(HERE / "legend.json", {"source": "docs/review/lookdev/look-toy/ingame_kitchen.png", "regions": legend})
	print("wrote the look-A kitchen fixture under %s" % HERE)
	return 0


if __name__ == "__main__":
	sys.exit(main())
