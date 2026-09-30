#!/usr/bin/env python3
"""Regenerates the committed fixtures of the review toolset (deterministic; Pillow + numpy only).

  fixtures/masks/*.png     black-on-transparent prop silhouettes (distinct families + one 5 %-scaled copy of the jar,
                           which sil64 must flag as the same family)
  fixtures/regions/        a synthetic beauty image + ID pass + legend with known medians (a lit kitchen: wall,
                           wainscot, floor, two dressing pieces, two live props, a character) — lab.py regions / rules
  fixtures/frames/         24 numbered 1200×540 frames (f00000000.png …) of a ball dropping, squashing and bouncing
                           + marks.json (anticipation 6, accent 12) — strip.py
  fixtures/answers/        a packet answer sheet in every accepted line style — packets.py score

usage: python3 tools/art3d/review/fixtures/make_fixtures.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import _common as cm  # noqa: E402

INK = (0, 0, 0, 255)


def _canvas(w=400, h=480):
	im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	return im, ImageDraw.Draw(im)


def mask_jar(scale=1.0):
	im, d = _canvas()
	s = scale
	cx, base = 200, 440
	w, h = 150 * s, 170 * s
	d.rounded_rectangle((cx - w, base - h, cx + w, base), radius=int(40 * s), fill=INK)  # squat body
	d.rectangle((cx - w * 0.8, base - h - 40 * s, cx + w * 0.8, base - h + 4), fill=INK)  # lid
	return im


def mask_kettle():
	im, d = _canvas()
	d.ellipse((90, 200, 330, 440), fill=INK)  # round body
	d.polygon([(110, 300), (20, 220), (35, 205), (130, 270)], fill=INK)  # spout
	d.arc((130, 110, 290, 290), 180, 360, fill=INK, width=26)  # arched handle
	d.rectangle((180, 185, 240, 210), fill=INK)  # lid knob
	return im


def mask_bottle():
	im, d = _canvas()
	d.rounded_rectangle((150, 120, 250, 460), radius=30, fill=INK)
	d.rectangle((180, 40, 220, 130), fill=INK)
	return im


def mask_horn():
	im, d = _canvas()
	d.rectangle((110, 360, 290, 460), fill=INK)  # cabinet
	d.polygon([(195, 360), (210, 360), (330, 60), (390, 110), (215, 340)], fill=INK)  # horn neck + bell
	d.ellipse((250, 20, 399, 170), fill=INK)
	return im


def mask_armchair():
	im, d = _canvas()
	d.rounded_rectangle((40, 120, 360, 330), radius=60, fill=INK)  # back
	d.rounded_rectangle((20, 250, 380, 420), radius=40, fill=INK)  # seat + arms
	d.rectangle((50, 420, 80, 460), fill=INK)
	d.rectangle((320, 420, 350, 460), fill=INK)
	return im


def mask_clock():
	im, d = _canvas(260, 480)
	d.rectangle((80, 120, 180, 470), fill=INK)
	d.ellipse((50, 10, 210, 170), fill=INK)
	return im


def mask_phone():
	im, d = _canvas()
	d.ellipse((130, 420, 270, 470), fill=INK)  # base
	d.rectangle((185, 120, 215, 440), fill=INK)  # stem
	d.ellipse((160, 60, 240, 140), fill=INK)  # mouthpiece
	d.rectangle((250, 110, 275, 300), fill=INK)  # hanging earpiece
	d.ellipse((240, 90, 285, 135), fill=INK)
	return im


def regions_fixture(out: Path):
	"""A 1200×540 beauty + ID pass. Every region is a flat colour (so its median is exact) with a 1 px antialiased
	border in the ID pass that the default erosion must drop."""
	W, H = 1200, 540
	beauty = np.zeros((H, W, 3), dtype=np.uint8)
	idp = np.zeros((H, W, 3), dtype=np.uint8)
	legend = []
	spec = [  # name, class, extra, id colour, beauty colour, rect
		("kitchen_wall", "wall", {"room": "kitchen"}, "#FF0000", "#C7B684", (0, 0, 1200, 300)),
		("kitchen_wainscot", "wainscot", {"room": "kitchen"}, "#00FF00", "#AE9D6C", (0, 300, 1200, 380)),
		("kitchen_floor", "floor", {"room": "kitchen"}, "#0000FF", "#76624F", (0, 380, 1200, 540)),
		("stool", "dressing", {"room": "kitchen"}, "#FFFF00", "#A8966E", (100, 330, 220, 460)),
		("loud_rug", "dressing", {"room": "kitchen"}, "#FF00FF", "#D0401C", (300, 470, 520, 530)),
		("honey_jar", "live_prop", {"room": "kitchen"}, "#00FFFF", "#F2A413", (620, 200, 700, 290)),
		("sink_tap", "live_prop", {"room": "kitchen", "halo": True}, "#800000", "#C9CED3", (760, 180, 800, 290)),
		("hush", "character", {}, "#008000", None, (900, 150, 1000, 470)),
	]
	for name, cls, extra, idc, bc, (x0, y0, x1, y1) in spec:
		idp[y0:y1, x0:x1] = cm.hex_to_rgb(idc)
		if bc is not None:
			beauty[y0:y1, x0:x1] = cm.hex_to_rgb(bc)
		legend.append(dict({"color": idc, "name": name, "class": cls}, **extra))
	# the character: top 40 % cream face paint (L* ≈ 96), bottom 60 % navy (L* ≈ 22) — exact shares after erosion
	cx0, cy0, cx1, cy1 = 900, 150, 1000, 470
	beauty[cy0:cy0 + 128, cx0:cx1] = cm.hex_to_rgb("#FAF3E6")
	beauty[cy0 + 128:cy1, cx0:cx1] = cm.hex_to_rgb("#1E2748")
	# antialiased ID borders: a 1 px line of an off colour round each region box (not in the legend)
	d = Image.fromarray(idp)
	dr = ImageDraw.Draw(d)
	for name, cls, extra, idc, bc, (x0, y0, x1, y1) in spec[3:]:
		dr.rectangle((x0 - 1, y0 - 1, x1, y1), outline=(77, 77, 77))
	idp = np.asarray(d).copy()
	out.mkdir(parents=True, exist_ok=True)
	Image.fromarray(beauty).save(out / "beauty.png")
	Image.fromarray(idp).save(out / "id.png")
	cm.write_json(out / "legend.json", {"regions": legend})


def frames_fixture(out: Path, n: int = 24):
	out.mkdir(parents=True, exist_ok=True)
	for old in out.glob("*.png"):
		old.unlink()
	for f in range(n):
		im = Image.new("RGB", (1200, 540), (214, 204, 160))
		d = ImageDraw.Draw(im)
		d.rectangle((0, 420, 1200, 540), fill=(118, 98, 79))
		# the ball: rises (anticipation, f 0–6), falls, squashes at f 12 (the accent), rebounds
		t = f / (n - 1)
		y = 420 - 60 - 300 * abs(np.cos(np.pi * (t * 1.5 + 0.0)))
		if f == 12:
			rx, ry, y = 90, 36, 420 - 36
		else:
			rx, ry = 60, 60
		x = 200 + 800 * t
		d.ellipse((x - rx, y - ry, x + rx, y + ry), fill=(230, 60, 40), outline=(20, 16, 30), width=5)
		im.save(out / ("f%08d.png" % f))
	cm.write_json(out.parent / "frames_marks.json", {"6": "anticipation", "12": "accent", "18": "settle"})


def answers_fixture(out: Path):
	out.mkdir(parents=True, exist_ok=True)
	(out / "answers.md").write_text(
		"# Answers\n\n"
		"pkt_01: sneaking along on tiptoe\n"
		"- **pkt_02**: she is running away\n"
		"| pkt_03 | diving into a hiding place |\n"
		"pkt_04 — frozen like a statue (unsure)\n"
		"pkt_05: bowing to the audience\n"
		"pkt_06: running\n"
		"pkt_07: waving at someone\n", encoding="utf-8")


def main() -> int:
	masks = HERE / "masks"
	masks.mkdir(parents=True, exist_ok=True)
	for name, fn in (("jar", mask_jar), ("kettle", mask_kettle), ("bottle", mask_bottle), ("gramophone", mask_horn),
					("armchair", mask_armchair), ("clock", mask_clock), ("phone", mask_phone),
					("jar_scaled_105", lambda: mask_jar(1.05))):
		fn().save(masks / ("%s.png" % name), optimize=True)
	regions_fixture(HERE / "regions")
	frames_fixture(HERE / "frames")
	answers_fixture(HERE / "answers")
	print("fixtures written under %s" % HERE)
	return 0


if __name__ == "__main__":
	sys.exit(main())
