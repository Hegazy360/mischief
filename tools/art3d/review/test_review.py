#!/usr/bin/env python3
"""Tests for the R3D review toolset: `python3 -m unittest tools/art3d/review/test_review.py` (< 30 s).

Reference values, synthetic fixtures with known answers, the §3.7 rules, the IoU invariants, the strip size cap and
marks, the packets' opacity and scoring, and the perf budgets of the brief (§7).
"""
from __future__ import annotations

import io
import json
import re
import shutil
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import _common as cm  # noqa: E402
import boards  # noqa: E402
import lab  # noqa: E402
import packets  # noqa: E402
import sil64  # noqa: E402
import strip  # noqa: E402

FIX = HERE / "fixtures"


def _quiet(fn, *a, **k):
	with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
		return fn(*a, **k)


class TmpCase(unittest.TestCase):
	def setUp(self) -> None:
		self.tmp = Path(tempfile.mkdtemp(prefix="review_test_"))

	def tearDown(self) -> None:
		shutil.rmtree(self.tmp, ignore_errors=True)


# --- lab: colour science -----------------------------------------------------------------------------------------

class TestLabReference(unittest.TestCase):
	# CIELAB (D65, 2°) of the sRGB corners: the standard published values.
	REF = {
		"#FFFFFF": (100.0, 0.0, 0.0), "#000000": (0.0, 0.0, 0.0), "#808080": (53.585, 0.0, 0.0),
		"#FF0000": (53.241, 80.092, 67.203), "#00FF00": (87.735, -86.183, 83.179),
		"#0000FF": (32.297, 79.188, -107.860), "#00FFFF": (91.113, -48.088, -14.131),
		"#FF00FF": (60.324, 98.234, -60.825), "#FFFF00": (97.139, -21.554, 94.478),
	}

	def test_reference_values(self) -> None:
		for hx, (L, a, b) in self.REF.items():
			l2, a2, b2 = lab.lab_of(hx)
			self.assertAlmostEqual(l2, L, delta=0.5, msg=hx)
			self.assertAlmostEqual(a2, a, delta=0.5, msg=hx)
			self.assertAlmostEqual(b2, b, delta=0.5, msg=hx)

	def test_blockout_kitchen_wall(self) -> None:
		L, a, b = lab.lab_of("#C7B684")
		self.assertAlmostEqual(L, 74.0, delta=0.5)
		self.assertAlmostEqual(float(np.hypot(a, b)), 28.0, delta=0.5)

	def test_array_matches_scalar_and_float_input(self) -> None:
		arr = np.array([[[199, 182, 132], [30, 39, 72]]], dtype=np.uint8)
		out = lab.rgb_to_lab(arr)
		self.assertEqual(out.shape, (1, 2, 3))
		self.assertTrue(np.allclose(out[0, 0], lab.lab_of("#C7B684"), atol=1e-6))
		fl = lab.rgb_to_lab(arr.astype(np.float64) / 255.0)
		self.assertTrue(np.allclose(fl, out, atol=1e-6))

	def test_deltas(self) -> None:
		w, k = lab.lab_of("#FFFFFF"), lab.lab_of("#000000")
		self.assertAlmostEqual(lab.delta_l(w, k), 100.0, delta=1e-3)
		self.assertAlmostEqual(lab.delta_e76(w, k), 100.0, delta=0.01)
		self.assertAlmostEqual(lab.chroma(lab.lab_of("#808080")), 0.0, delta=0.01)
		self.assertEqual(lab.hue_deg(lab.lab_of("#FFFFFF")), 0.0)

	def test_hex_parsing(self) -> None:
		self.assertEqual(cm.hex_to_rgb("#c7b684"), (199, 182, 132))
		self.assertEqual(cm.hex_to_rgb("C7B684"), (199, 182, 132))
		self.assertEqual(cm.hex_to_rgb("#fff"), (255, 255, 255))
		self.assertEqual(cm.hex_to_rgb("10,20,30"), (10, 20, 30))
		with self.assertRaises(ValueError):
			cm.hex_to_rgb("#12345")


# --- lab: regions / value / rules --------------------------------------------------------------------------------

def _regions_images(w: int = 400, h: int = 200):
	"""Four flat regions + a 1 px off-legend ID border round the prop: known medians, known eroded counts."""
	beauty = np.zeros((h, w, 3), dtype=np.uint8)
	idp = np.zeros((h, w, 3), dtype=np.uint8)
	beauty[:120] = cm.hex_to_rgb("#C7B684")
	idp[:120] = (255, 0, 0)
	beauty[120:] = cm.hex_to_rgb("#76624F")
	idp[120:] = (0, 0, 255)
	beauty[40:100, 50:110] = cm.hex_to_rgb("#F2A413")
	idp[40:100, 50:110] = (0, 255, 255)
	idp[39, 49:111] = idp[100, 49:111] = (90, 90, 90)
	idp[39:101, 49] = idp[39:101, 110] = (90, 90, 90)
	legend = {"regions": [
		{"color": "#FF0000", "name": "wall", "class": "wall", "room": "kitchen"},
		{"color": "#0000FF", "name": "floor", "class": "floor", "room": "kitchen"},
		{"color": "#00FFFF", "name": "honey", "class": "live_prop"},
		{"color": "#FF00FF", "name": "ghost", "class": "dressing"},
	]}
	return beauty, idp, legend


class TestRegions(TmpCase):
	def test_known_medians_and_counts(self) -> None:
		beauty, idp, legend = _regions_images()
		r = lab.regions(beauty, idp, legend, erode=1)
		by = {x["name"]: x for x in r["regions"]}
		L_wall = lab.lab_of("#C7B684")[0]
		self.assertAlmostEqual(by["wall"]["L"]["median"], L_wall, delta=0.01)
		self.assertAlmostEqual(by["wall"]["C"]["median"], 27.73, delta=0.01)
		self.assertAlmostEqual(by["floor"]["L"]["median"], lab.lab_of("#76624F")[0], delta=0.01)
		self.assertAlmostEqual(by["honey"]["C"]["median"], float(lab.chroma(lab.lab_of("#F2A413"))), delta=0.01)
		# the prop: 60×60, eroded by 1 → 58×58 (the off-legend border never counts)
		self.assertEqual(by["honey"]["px"], 58 * 58)
		self.assertEqual(by["ghost"]["px"], 0)
		self.assertFalse(by["ghost"]["visible"])
		self.assertEqual(by["honey"]["median_hex"], "#F2A413")
		self.assertGreater(r["unmatched_px"], 0)

	def test_tolerance_matches_near_colours(self) -> None:
		beauty, idp, legend = _regions_images()
		idp[:120] = (254, 1, 0)  # a rounding wobble in the ID pass
		self.assertEqual(lab.regions(beauty, idp, legend, tol=0)["regions"][0]["px"], 0)
		self.assertGreater(lab.regions(beauty, idp, legend, tol=2)["regions"][0]["px"], 0)

	def test_legend_shapes(self) -> None:
		a = lab.load_legend({"#FF0000": {"name": "wall", "class": "wall"}, "#00FF00": "floor"})
		self.assertEqual([(e["name"], e["class"]) for e in a], [("wall", "wall"), ("floor", "other")])
		b = lab.load_legend([{"color": "#ff0000", "name": "w"}])
		self.assertEqual(b[0]["hex"], "#FF0000")
		with self.assertRaises(ValueError):
			lab.load_legend({"regions": [{"color": "#FF0000", "name": "a"}, {"color": "#ff0000", "name": "b"}]})

	def test_size_mismatch_raises(self) -> None:
		beauty, idp, legend = _regions_images()
		with self.assertRaises(ValueError):
			lab.regions(beauty, idp[:100], legend)

	def test_transparent_beauty_pixels_ignored(self) -> None:
		beauty, idp, legend = _regions_images()
		rgba = np.concatenate([beauty, np.full(beauty.shape[:2] + (1,), 255, dtype=np.uint8)], axis=-1)
		rgba[:60, :, 3] = 0
		r = lab.regions(rgba, idp, legend, erode=0)
		self.assertEqual(r["regions"][0]["px"], int((idp[60:120] == (255, 0, 0)).all(axis=-1).sum()))
		self.assertLess(r["regions"][0]["px"], 60 * 400)

	def test_committed_fixture(self) -> None:
		r = lab.regions(FIX / "regions" / "beauty.png", FIX / "regions" / "id.png", FIX / "regions" / "legend.json")
		by = {x["name"]: x for x in r["regions"]}
		self.assertAlmostEqual(by["kitchen_wall"]["L"]["median"], 74.36, delta=0.05)
		# the character: 100×320 box, rows 0–127 cream, 128–319 navy; eroded 1 px → 98 × (127 + 191)
		self.assertEqual(by["hush"]["px"], 98 * 318)
		self.assertAlmostEqual(by["hush"]["share_hi"], 127 / 318, delta=1e-4)
		self.assertAlmostEqual(by["hush"]["share_lo"], 191 / 318, delta=1e-4)


class TestValue(TmpCase):
	def _two_tone(self, light_rows: int = 40, total: int = 100):
		img = np.full((200, 200, 4), 0, dtype=np.uint8)
		img[50:50 + light_rows, 60:140] = (250, 243, 230, 255)            # face paint, L* ≈ 96
		img[50 + light_rows:50 + total, 60:140] = (30, 39, 72, 255)       # navy, L* ≈ 16
		return img

	def test_exact_shares_from_alpha(self) -> None:
		r = lab.value_shares(self._two_tone(), "alpha")
		self.assertEqual(r["px"], 80 * 100)
		self.assertAlmostEqual(r["share_hi"], 0.40, places=6)
		self.assertAlmostEqual(r["share_lo"], 0.60, places=6)
		self.assertAlmostEqual(r["share_mid"], 0.0, places=6)
		self.assertTrue(r["pass"])

	def test_fails_below_twenty_percent(self) -> None:
		r = lab.value_shares(self._two_tone(light_rows=15), "alpha")
		self.assertAlmostEqual(r["share_hi"], 0.15, places=6)
		self.assertFalse(r["pass"])

	def test_mask_png_modes(self) -> None:
		img = self._two_tone()
		# black-on-white opaque mask of the lower half only
		m = np.full((200, 200, 3), 255, dtype=np.uint8)
		m[90:150, 60:140] = 0
		Image.fromarray(m).save(self.tmp / "m.png")
		r = lab.value_shares(img, self.tmp / "m.png")
		self.assertEqual(r["px"], 60 * 80)
		self.assertAlmostEqual(r["share_lo"], 1.0)
		# an ID-colour mask
		idm = np.zeros((200, 200, 3), dtype=np.uint8)
		idm[50:90, 60:140] = (0, 255, 128)
		Image.fromarray(idm).save(self.tmp / "id.png")
		r = lab.value_shares(img, self.tmp / "id.png", color="#00FF80")
		self.assertAlmostEqual(r["share_hi"], 1.0)

	def test_hist_png_and_cli(self) -> None:
		img = self._two_tone()
		Image.fromarray(img, "RGBA").save(self.tmp / "hush.png")
		rc = _quiet(lab.main, ["value", str(self.tmp / "hush.png"), "--mask=alpha", "--label=hush",
								"--hist=%s" % (self.tmp / "h.png"), "--json=%s" % (self.tmp / "v.json")])
		self.assertEqual(rc, 0)
		v = json.loads((self.tmp / "v.json").read_text())
		self.assertEqual(v["label"], "hush")
		self.assertTrue(v["pass"])
		self.assertNotIn("_L", v)
		with Image.open(self.tmp / "h.png") as h:
			self.assertEqual(h.size, (1200, 540))


def _row(name, cls, L, C, px=500, **kw):
	d = {"name": name, "class": cls, "px": px, "visible": px >= 20,
		"L": {"median": L, "p10": L, "p90": L, "mean": L}, "C": {"median": C, "p10": C, "p90": C, "mean": C},
		"share_hi": kw.pop("share_hi", 0.0), "share_lo": kw.pop("share_lo", 0.0)}
	d.update(kw)
	return d


class TestRules(unittest.TestCase):
	def _status(self, rep, name, rule_sub=""):
		return [x["status"] for x in rep["results"] if x["name"] == name and rule_sub in x["rule"]]

	def test_good_set_passes(self) -> None:
		doc = {"regions": [
			_row("wall", "wall", 73, 26, room="k"), _row("wains", "wainscot", 64, 20, room="k"),
			_row("floor", "floor", 44, 20), _row("stool", "dressing", 60, 18, wall="wall"),
			_row("honey", "live_prop", 70, 72), _row("tap", "live_prop", 80, 10, halo=True),
			_row("dim", "wall", 50, 9, lit=False, room="p"), _row("hush", "character", 50, 10, share_hi=0.3, share_lo=0.5),
			_row("lamp", "dressing", 89, 10, exempt="the light source"), _row("door", "architecture", 40, 10)]}
		rep = lab.check_rules(doc)
		self.assertTrue(rep["pass"], lab.format_rules(rep))
		self.assertEqual(self._status(rep, "lamp"), ["EXEMPT"])
		self.assertEqual(self._status(rep, "door"), ["INFO"])

	def test_fails_loud_dressing_and_bright_wall(self) -> None:
		doc = {"regions": [_row("wall", "wall", 80, 20), _row("rug", "dressing", 75, 40, wall="wall")]}
		rep = lab.check_rules(doc)
		self.assertFalse(rep["pass"])
		self.assertEqual(self._status(rep, "wall", "L*"), ["FAIL"])
		self.assertEqual(self._status(rep, "rug", "C*"), ["FAIL"])
		self.assertEqual(self._status(rep, "rug", "ΔL"), ["PASS"])

	def test_each_rule_edge(self) -> None:
		rep = lab.check_rules({"regions": [
			_row("wall", "wall", 70, 29, room="k"),
			_row("dimw", "wall_dim", 50, 16, room="p"), _row("fl", "floor", 51, 5),
			_row("st", "dressing", 50, 10, room="k"), _row("jar", "live_prop", 60, 44),
			_row("hush", "character", 50, 10, share_hi=0.19, share_lo=0.5)]})
		fails = sorted((x["name"], x["rule"]) for x in rep["results"] if x["status"] == "FAIL")
		# dim wall C* 16 > 15, floor L* 51 > 50, Hush 19 % light, jar C* 44 < 45, stool |ΔL*| 20 > 15, wall C* 29 > 28
		self.assertEqual([n for n, _ in fails], ["dimw", "fl", "hush", "jar", "st", "wall"])

	def test_wainscot_delta(self) -> None:
		rep = lab.check_rules({"regions": [_row("wall", "wall", 70, 10, room="k"),
											_row("wa", "wainscot", 63, 10, room="k"),
											_row("wb", "wainscot", 61, 10, wall="wall")]})
		self.assertEqual(self._status(rep, "wa"), ["FAIL"])  # 7 L* darker
		self.assertEqual(self._status(rep, "wb"), ["PASS"])  # 9 L* darker

	def test_skips(self) -> None:
		rep = lab.check_rules({"regions": [_row("a", "wall", 70, 10, room="k"), _row("b", "wall", 70, 10, room="k"),
											_row("st", "dressing", 60, 10), _row("gone", "live_prop", 0, 0, px=3)]})
		self.assertTrue(rep["pass"])
		self.assertIn("SKIP", self._status(rep, "st"))
		self.assertEqual(self._status(rep, "gone"), ["SKIP"])
		self.assertEqual(rep["counts"]["SKIP"], 2)

	def test_character_only(self) -> None:
		rep = lab.check_rules({"regions": [_row("wall", "wall", 90, 50),
											_row("hush", "character", 50, 10, share_hi=0.3, share_lo=0.3)]},
							rules="character")
		self.assertTrue(rep["pass"])
		self.assertEqual({x["name"] for x in rep["results"]}, {"hush"})

	def test_cli_exit_codes(self) -> None:
		tmp = Path(tempfile.mkdtemp())
		try:
			p = tmp / "r.json"
			p.write_text(json.dumps({"regions": [_row("wall", "wall", 80, 20)]}))
			self.assertEqual(_quiet(lab.main, ["rules", str(p)]), 1)
			self.assertEqual(_quiet(lab.main, ["rules", str(p), "--no-fail"]), 0)
			p.write_text(json.dumps({"regions": [_row("st", "dressing", 60, 10)]}))
			self.assertEqual(_quiet(lab.main, ["rules", str(p)]), 0)
			self.assertEqual(_quiet(lab.main, ["rules", str(p), "--strict"]), 1)
		finally:
			shutil.rmtree(tmp)


class TestFalsecolor(TmpCase):
	def test_board(self) -> None:
		beauty, idp, legend = _regions_images(600, 270)
		Image.fromarray(idp).save(self.tmp / "id.png")
		reg = lab.falsecolor_board(beauty, self.tmp / "fc.png", id_pass=self.tmp / "id.png", legend=legend)
		self.assertEqual(len(reg["regions"]), 4)
		with Image.open(self.tmp / "fc.png") as im:
			self.assertGreater(im.width, 2400)


# --- sil64 ---------------------------------------------------------------------------------------------------------

def _shape(kind: str, scale: float = 1.0, size=(400, 400), dx: int = 0) -> np.ndarray:
	im = Image.new("L", size, 0)
	d = ImageDraw.Draw(im)
	s = scale
	cx, cy = size[0] // 2 + dx, size[1] // 2
	if kind == "jar":
		d.rounded_rectangle((cx - 120 * s, cy - 60 * s, cx + 120 * s, cy + 100 * s), radius=int(30 * s), fill=255)
		d.rectangle((cx - 90 * s, cy - 95 * s, cx + 90 * s, cy - 55 * s), fill=255)
	elif kind == "pole":
		d.rectangle((cx - 12 * s, cy - 150 * s, cx + 12 * s, cy + 150 * s), fill=255)
		d.ellipse((cx - 50 * s, cy - 190 * s, cx + 50 * s, cy - 110 * s), fill=255)
	elif kind == "bars":  # | |  — two bars at the sides of a square
		d.rectangle((cx - 100, cy - 100, cx - 70, cy + 100), fill=255)
		d.rectangle((cx + 70, cy - 100, cx + 100, cy + 100), fill=255)
	elif kind == "bar":  # one bar in the middle: disjoint from "bars" after centring
		d.rectangle((cx - 15, cy - 100, cx + 15, cy + 100), fill=255)
	return np.asarray(im) >= 128


class TestSil64(TmpCase):
	def _norm(self, m):
		return sil64.normalise(m, 64, (96, 96))

	def test_identical_is_one(self) -> None:
		a = self._norm(_shape("jar"))
		self.assertEqual(sil64.iou(a, a), 1.0)

	def test_disjoint_is_near_zero(self) -> None:
		a, b = self._norm(_shape("bars")), self._norm(_shape("bar"))
		self.assertLess(sil64.iou(a, b), 0.02)
		self.assertEqual(sil64.iou(np.zeros((4, 4), bool) | True, np.zeros((4, 4), bool)), 0.0)

	def test_scaled_copy_same_family_and_scale_invariant(self) -> None:
		a = self._norm(_shape("jar"))
		b = self._norm(_shape("jar", 1.05))
		self.assertGreaterEqual(sil64.iou(a, b), 0.80)
		c = self._norm(_shape("jar", 0.5, dx=-60))  # half size, off-centre: normalisation removes both
		self.assertGreaterEqual(sil64.iou(a, c), 0.93)
		self.assertLess(sil64.iou(a, self._norm(_shape("pole"))), 0.5)

	def test_height_is_64(self) -> None:
		n = self._norm(_shape("pole"))
		b = cm.bbox(n)
		self.assertEqual(b[3] - b[1], 64)
		n2 = sil64.normalise(_shape("jar"), 64, (96, 96), fit="box")
		b2 = cm.bbox(n2)
		self.assertEqual(max(b2[2] - b2[0], b2[3] - b2[1]), 64)

	def test_run_masks_board_json_and_wide_canvas(self) -> None:
		d = self.tmp / "m"
		d.mkdir()
		for name, m in (("jar", _shape("jar")), ("jar2", _shape("jar", 1.05)), ("pole", _shape("pole"))):
			rgba = np.zeros(m.shape + (4,), np.uint8)
			rgba[m] = (0, 0, 0, 255)
			Image.fromarray(rgba, "RGBA").save(d / ("%s.png" % name))
		wide = np.full((100, 400, 3), 255, np.uint8)  # black on white, 4:1 → wider than the 96 px canvas
		wide[30:70, 20:380] = 0
		Image.fromarray(wide).save(d / "bench.png")
		rc = _quiet(sil64.main, ["masks", str(d), "--out=%s" % (self.tmp / "b.png"),
								"--json=%s" % (self.tmp / "s.json"), "--cells-dir=%s" % (self.tmp / "cells")])
		self.assertEqual(rc, 0)
		j = json.loads((self.tmp / "s.json").read_text())
		self.assertEqual(j["names"], ["bench", "jar", "jar2", "pole"])
		self.assertEqual(len(j["iou"]), 4)
		self.assertEqual([(p["a"], p["b"]) for p in j["pairs_over"]], [("jar", "jar2")])
		self.assertGreater(j["canvas"][0], 96)  # widened for the bench
		self.assertTrue((self.tmp / "b.png").exists())
		self.assertEqual(len(list((self.tmp / "cells").glob("*.png"))), 4)

	def test_committed_fixture_flags_only_the_scaled_jar(self) -> None:
		res = sil64.run_masks(cm.list_images(FIX / "masks"))
		self.assertEqual([(p["a"], p["b"]) for p in res["pairs_over"]], [("jar", "jar_scaled_105")])

	def test_despeckle_ignores_stray_pixels(self) -> None:
		clean = _shape("jar")
		dirty = clean.copy()
		dirty[2, 2] = dirty[397, 396] = True  # two stray ID pixels far from the prop
		self.assertNotEqual(cm.bbox(dirty), cm.bbox(clean))
		self.assertEqual(cm.bbox(cm.despeckle(dirty)), cm.bbox(clean))
		lab_c, sizes = cm.components(dirty)
		self.assertEqual(sorted(sizes)[:2], [1, 1])
		for n, m in (("clean", clean), ("dirty", dirty)):
			Image.fromarray((~m * 255).astype(np.uint8)).save(self.tmp / ("%s.png" % n))
		res = sil64.run_masks([self.tmp / "clean.png", self.tmp / "dirty.png"])
		self.assertEqual(res["iou"][0][1], 1.0)
		raw = sil64.run_masks([self.tmp / "clean.png", self.tmp / "dirty.png"], despeckle=0)
		self.assertLess(raw["iou"][0][1], 0.9)

	def test_extract(self) -> None:
		img = np.zeros((50, 50, 4), np.uint8)
		img[10:20, 10:30] = (200, 10, 10, 255)
		Image.fromarray(img, "RGBA").save(self.tmp / "r.png")
		_quiet(sil64.main, ["extract", str(self.tmp / "r.png"), "--out=%s" % (self.tmp / "m.png")])
		self.assertEqual(int(sil64.load_mask(self.tmp / "m.png").sum()), 200)


# --- strip ---------------------------------------------------------------------------------------------------------

def _frames(d: Path, n: int, size=(1200, 540), name="f%08d.png", noise: bool = True) -> None:
	d.mkdir(parents=True, exist_ok=True)
	rng = np.random.default_rng(3)
	base = np.zeros((size[1], size[0], 3), np.uint8)
	base[:] = (214, 204, 160)
	base[int(size[1] * 0.78):] = (118, 98, 79)
	if noise:  # game-like texture so the JPEG size is realistic
		base = np.clip(base.astype(np.int16) + rng.integers(-12, 12, base.shape), 0, 255).astype(np.uint8)
	for f in range(n):
		im = Image.fromarray(base)
		dr = ImageDraw.Draw(im)
		x = 60 + f * (size[0] - 120) // max(1, n)
		dr.ellipse((x, 200, x + 90, 290), fill=(230, 60, 40), outline=(20, 16, 30), width=5)
		if name.endswith(".jpg"):
			im.save(d / (name % f), quality=92)
		else:
			im.save(d / (name % f), compress_level=1)


class TestStrip(TmpCase):
	def test_hundred_frames_under_cap_with_accent(self) -> None:
		_frames(self.tmp / "fr", 100, name="f%08d.jpg")
		out = self.tmp / "s.jpg"
		res = _quiet(strip.make_strip, self.tmp / "fr", out, every=1, marks={"37": "accent", "20": "anticipation"},
					label_frames=True)
		self.assertLessEqual(max(res["bytes"]), 4 * 1024 * 1024)
		self.assertEqual(len(res["cells"]), 100)
		self.assertEqual([c["frame"] for c in res["cells"] if c["mark"] == "accent"], [37])
		# the accent cell carries the red outline
		cw, ch = res["cell_size"]
		cols = res["cols"]
		k = 37
		r, c = divmod(k, cols)
		x, y = 6 + c * (cw + 6), 6 + r * (ch + 6)
		with Image.open(out) as im:
			px = np.asarray(im.convert("RGB"))[y + ch // 2, x]
		self.assertGreater(int(px[0]), 180)
		self.assertLess(int(px[1]), 110)

	def test_every_keeps_marked_frames_and_numbers(self) -> None:
		_frames(self.tmp / "seq", 12, size=(240, 108), name="frame_%03d.png", noise=False)
		res = _quiet(strip.make_strip, self.tmp / "seq", self.tmp / "s.png", every=4, marks={"35": "accent"},
					frame_step=3, frame_offset=30, label_frames=True)
		# files 0..11 → frames 30, 33 … 63; every 4th file → 30, 42, 54 + the marked 35? (35 is no frame) → no
		self.assertEqual([c["frame"] for c in res["cells"]], [30, 42, 54])
		res = _quiet(strip.make_strip, self.tmp / "seq", self.tmp / "s.png", every=4, marks={"39": "accent"},
					frame_step=3, frame_offset=30)
		self.assertEqual([c["frame"] for c in res["cells"]], [30, 39, 42, 54])

	def test_marks_from_sidecar_and_list(self) -> None:
		side = {"version": 2, "format": "anim3d", "beats": {"anticipation": [74, 94], "accent": [94, 97],
															"hold": [97, 145]},
				"events": [{"f": 120, "type": "mark", "name": "release"}, {"f": 94, "type": "voice", "id": "x"}]}
		self.assertEqual(strip.load_marks(side, 10), {84: "anticipation", 104: "accent", 107: "hold",
													130: "release"})
		self.assertEqual(strip.load_marks([{"frame": 5, "kind": "contact"}]), {5: "contact"})
		self.assertEqual(strip.load_marks({"marks": {"7": "accent"}}), {7: "accent"})

	def test_pages(self) -> None:
		_frames(self.tmp / "fr", 30, size=(300, 135), noise=False)
		res = _quiet(strip.make_strip, self.tmp / "fr", self.tmp / "p.jpg", every=1, cols=4, per_page=12)
		self.assertEqual(res["page_cells"], [12, 12, 6])
		self.assertEqual([Path(p).name for p in res["pages"]], ["p.jpg", "p_2.jpg", "p_3.jpg"])
		self.assertEqual(res["cells"][12]["index"], 13)


# --- boards --------------------------------------------------------------------------------------------------------

class TestBoards(TmpCase):
	def test_grid_and_pair(self) -> None:
		a = Image.new("RGB", (1200, 540), (200, 40, 40))
		b = Image.new("RGB", (960, 540), (40, 200, 40))  # a 16:9 cell letterboxes, never stretches
		a.save(self.tmp / "a.png")
		b.save(self.tmp / "b.png")
		g = boards.grid([self.tmp / "a.png", self.tmp / "b.png", self.tmp / "a.png"], ["A", "B ×1.2", "C ≥"],
						self.tmp / "g.png", title="t")
		self.assertEqual(g.width, 3 * 1200 + 4 * 16)
		px = np.asarray(g)[64 + 16 + 270, 16 + 1200 + 16 + 60]  # left letterbox bar of the 16:9 cell
		self.assertLess(int(px.sum()), 100)
		p = boards.pair(self.tmp / "a.png", self.tmp / "b.png", self.tmp / "p.png", ("2D", "3D"))
		self.assertEqual(p.width, 2 * 1200 + 3 * 16)
		s = boards.pair(self.tmp / "a.png", self.tmp / "b.png", None, stack=True, scale=0.5)
		self.assertLess(s.width, 700)

	def test_cli_labels_with_separator(self) -> None:
		Image.new("RGB", (120, 54)).save(self.tmp / "a.png")
		rc = _quiet(boards.main, ["grid", str(self.tmp / "g.png"), "--cells=%s,%s" % (self.tmp / "a.png",
									self.tmp / "a.png"), "--labels=x, y|z", "--sep=|"])
		self.assertEqual(rc, 0)
		self.assertEqual(_quiet(boards.main, ["pair", str(self.tmp / "p.png"), str(self.tmp / "a.png"),
											str(self.tmp / "nope.png")]), 2)


# --- packets -------------------------------------------------------------------------------------------------------

class TestPackets(TmpCase):
	NAMES = ["sneak", "run", "dive", "statue", "bow", "snicker", "reach_high"]

	def _items(self) -> list[str]:
		d = self.tmp / "src"
		d.mkdir()
		out = []
		for i, n in enumerate(self.NAMES):
			im = Image.new("RGB", (120, 54), (i * 30, 90, 200))
			p = d / ("hush_%s_20x9.png" % n)
			# a PNG text chunk carrying the name: the packet must strip it
			from PIL.PngImagePlugin import PngInfo
			info = PngInfo()
			info.add_text("Title", "hush %s" % n)
			im.save(p, pnginfo=info)
			out.append(str(p))
		return out

	def test_build_is_opaque(self) -> None:
		items = self._items()
		key = packets.build(self.tmp / "pk", items, self.tmp / "key.json", kind="frames", seed=5,
							names=self.NAMES, question="What is the character doing?")
		files = sorted(p.name for p in (self.tmp / "pk").iterdir())
		self.assertEqual(files, ["pkt_%02d.png" % i for i in range(1, 8)] + ["prompt.md"])
		blob = b"".join(p.read_bytes() for p in (self.tmp / "pk").iterdir())
		for n in self.NAMES + ["hush"]:
			self.assertNotIn(n.encode(), blob, n)
		ids = [r["id"] for r in key["items"]]
		self.assertEqual(ids, sorted(ids))
		self.assertNotEqual([r["name"] for r in key["items"]], self.NAMES)  # shuffled
		# deterministic by seed
		key2 = packets.build(self.tmp / "pk2", items, self.tmp / "key2.json", seed=5, names=self.NAMES,
							question="What is the character doing?")
		self.assertEqual([r["name"] for r in key["items"]], [r["name"] for r in key2["items"]])

	def test_guards(self) -> None:
		items = self._items()
		with self.assertRaises(ValueError):  # key inside the packet dir
			packets.build(self.tmp / "pk", items, self.tmp / "pk" / "KEY.json")
		with self.assertRaises(ValueError):  # the question names an item
			packets.build(self.tmp / "pk3", items, self.tmp / "k.json", names=self.NAMES, question="Is she diving? dive")
		self.assertFalse((self.tmp / "pk3").exists())  # nothing written on a refusal
		packets.build(self.tmp / "pk4", items, self.tmp / "k.json", names=self.NAMES, question="What?")
		with self.assertRaises(ValueError):  # non-empty packet dir
			packets.build(self.tmp / "pk4", items, self.tmp / "k.json", names=self.NAMES, question="What?")
		packets.build(self.tmp / "pk4", items, self.tmp / "k.json", names=self.NAMES, question="What?", force=True)
		# choices may name the items (a list with distractors); the leak check skips them
		k = packets.build(self.tmp / "pk5", items, self.tmp / "k5.json", kind="crops", names=self.NAMES,
						choices=self.NAMES + ["wave", "sit", "fall"], question="Which verb?")
		prompt = (self.tmp / "pk5" / "prompt.md").read_text()
		self.assertIn("- wave", prompt)
		self.assertEqual(k["answer_format"], "choice")

	def test_score_reproduces_fixture_sheet(self) -> None:
		key = {"kind": "frames", "seed": 1, "answer_format": "free", "question": "q", "choices": [], "items": [
			{"id": "pkt_01", "name": "sneak", "expected": "sneak", "aliases": ["tiptoe"]},
			{"id": "pkt_02", "name": "run", "expected": "run", "aliases": []},
			{"id": "pkt_03", "name": "dive", "expected": "dive", "aliases": ["hide"]},
			{"id": "pkt_04", "name": "statue", "expected": "statue", "aliases": ["freeze", "frozen"]},
			{"id": "pkt_05", "name": "bow", "expected": "bow", "aliases": []},
			{"id": "pkt_06", "name": "snicker", "expected": "snicker", "aliases": []},
			{"id": "pkt_07", "name": "reach_high", "expected": "reach_high", "aliases": []},
			{"id": "pkt_08", "name": "squeak", "expected": "squeak", "aliases": []}]}
		res = packets.score(key, (FIX / "answers" / "answers.md").read_text())
		v = {r["id"]: (r["verdict"], r["given"]) for r in res["rows"]}
		self.assertEqual(v["pkt_01"], ("correct", "sneak"))
		self.assertEqual(v["pkt_02"], ("correct", "run"))
		self.assertEqual(v["pkt_03"], ("correct", "dive"))       # table row, "diving"
		self.assertEqual(v["pkt_04"], ("correct", "statue"))     # "frozen … statue" → first named: frozen (alias)
		self.assertEqual(v["pkt_05"], ("correct", "bow"))        # "bowing"
		self.assertEqual(v["pkt_06"], ("confused", "run"))       # snicker read as running
		self.assertEqual(v["pkt_07"], ("unmatched", None))       # "waving at someone"
		self.assertEqual(v["pkt_08"], ("missing", None))
		self.assertEqual(res["correct"], 5)
		self.assertEqual(res["confused_pairs"], [["run", "snicker"]])
		md = packets.verdict_md(res, key)
		self.assertIn("**Correct: 5/8**", md)
		self.assertIn("snicker → run (pkt_06)", md)

	def test_first_named_and_longest_candidate(self) -> None:
		key = {"kind": "crops", "answer_format": "choice", "choices": ["reach", "reach high", "reach low"],
				"items": [{"id": "pkt_01", "name": "reach high", "expected": "reach high", "aliases": []},
						{"id": "pkt_02", "name": "reach low", "expected": "reach low", "aliases": []}]}
		res = packets.score(key, "pkt_01: reaching up high, maybe low\npkt_02: reach (unsure)\n")
		self.assertEqual([(r["verdict"], r["given"]) for r in res["rows"]],
						[("correct", "reach high"), ("confused", "reach")])

	def test_pairs_yesno_scores(self) -> None:
		items = self._items()
		pk = packets.build(self.tmp / "pairs", ["%s:%s" % (items[0], items[1]), "%s:%s" % (items[2], items[3])],
							self.tmp / "pk.json", kind="pairs", seed=2, names=["m1", "m2"], question="Which reads better?")
		self.assertEqual(pk["answer_format"], "ab")
		for it in pk["items"]:
			self.assertEqual(it[it["expected"]], it["candidate"])
		sheet = "\n".join("%s: %s — clearer" % (it["id"], it["expected"]) for it in pk["items"])
		self.assertEqual(packets.score(pk, sheet)["correct"], 2)
		with Image.open(self.tmp / "pairs" / "pkt_01.png") as im:
			self.assertEqual(im.width, 2 * 1200 + 3 * 16)
		yn = packets.build(self.tmp / "yn", items[:3], self.tmp / "yn.json", fmt="yesno", expected="no",
							question="Is this screen crowded?")
		r = packets.score(yn, "pkt_01: No, calm\npkt_02: yes — too much\npkt_03: no")
		self.assertEqual((r["yes"], r["no"], r["correct"]), (1, 2, 2))
		sc = packets.build(self.tmp / "sc", items[:2], self.tmp / "sc.json", kind="strips", fmt="scores")
		self.assertEqual(sc["score_fields"], ["funny", "readable", "fresh"])
		r = packets.score(sc, "pkt_01: funny=4 readable=5 fresh=3 — f 12\npkt_02: funny 2, readable: 4, fresh=3",
						bar=3)
		self.assertEqual([x["verdict"] for x in r["rows"]], ["scored", "under_bar"])
		self.assertEqual(r["scores"]["funny"], {"mean": 3.0, "min": 2.0})

	def test_folder_items_become_page_folders(self) -> None:
		d = self.tmp / "strips"
		for g in ("gag_sneeze", "gag_spin"):
			(d / g).mkdir(parents=True)
			for k in range(2):
				Image.new("RGB", (240, 108), (k * 90, 30, 30)).save(d / g / ("%s_%d.jpg" % (g, k)))
		rc = _quiet(packets.main, ["build", str(self.tmp / "pk"), "--items=%s" % d, "--kind=strips",
									"--key=%s" % (self.tmp / "k.json")])
		self.assertEqual(rc, 0)
		names = sorted(str(p.relative_to(self.tmp / "pk")) for p in (self.tmp / "pk").rglob("*"))
		self.assertEqual(names, ["pkt_01", "pkt_01/page_1.jpg", "pkt_01/page_2.jpg", "pkt_02", "pkt_02/page_1.jpg",
								"pkt_02/page_2.jpg", "prompt.md"])
		k = json.loads((self.tmp / "k.json").read_text())
		self.assertEqual(sorted(i["name"] for i in k["items"]), ["gag_sneeze", "gag_spin"])

	def test_parse_answer_styles(self) -> None:
		a = packets.parse_answers((FIX / "answers" / "answers.md").read_text())
		self.assertEqual(a["pkt_02"], "she is running away")
		self.assertEqual(a["pkt_03"], "diving into a hiding place")
		self.assertEqual(a["pkt_04"], "frozen like a statue (unsure)")

	def test_stemmer(self) -> None:
		for a, b in (("sneaking", "sneak"), ("diving", "dive"), ("running", "run"), ("bowing", "bow"),
					("snickers", "snicker"), ("squeaked", "squeak"), ("freezes", "freeze")):
			self.assertEqual(packets.stem(a), packets.stem(b), (a, b))


# --- the real look-dev image (fixtures/lookdev, docs/review/r3d-tools-a) --------------------------------------------

class TestLookdevKitchen(unittest.TestCase):
	"""Pins the numbers the toolset reads off look A's in-game kitchen, so a change to the colour maths shows."""
	IMG = cm.REPO / "docs" / "review" / "lookdev" / "look-toy" / "ingame_kitchen.png"
	LD = FIX / "lookdev"

	def setUp(self) -> None:
		if not self.IMG.exists():
			self.skipTest("look-dev image not in this checkout")

	def test_regions_and_rules(self) -> None:
		r = lab.regions(self.IMG, self.LD / "id.png", self.LD / "legend.json")
		by = {x["name"]: x for x in r["regions"]}
		self.assertAlmostEqual(by["kitchen_wall"]["L"]["median"], 90.6, delta=0.3)   # pale mint: too light for §3.7
		self.assertAlmostEqual(by["kitchen_floor"]["L"]["median"], 64.3, delta=0.3)
		self.assertAlmostEqual(by["gramophone_horn"]["C"]["median"], 65.7, delta=0.5)
		rep = lab.check_rules(r)
		fails = sorted({x["name"] for x in rep["results"] if x["status"] == "FAIL"})
		self.assertEqual(fails, ["fireplace", "hush", "kitchen_floor", "kitchen_wall", "pantry_curtain",
								"parlour_floor", "parlour_wall"])

	def test_value_shares(self) -> None:
		h = lab.value_shares(self.IMG, self.LD / "hush_mask.png")
		b = lab.value_shares(self.IMG, self.LD / "bellows_mask.png")
		self.assertLess(h["share_hi"], 0.20)       # the face paint in shade: not enough light pixels
		self.assertGreater(h["share_lo"], 0.50)    # navy costume + bob + ink
		self.assertTrue(b["pass"])                 # bouffant light, plum jacket dark

	def test_cast_silhouettes_differ(self) -> None:
		res = sil64.run_masks([self.LD / "hush_mask.png", self.LD / "bellows_mask.png"])
		self.assertLess(res["iou"][0][1], 0.80)


# --- perf budgets (brief §7) --------------------------------------------------------------------------------------

class TestPerf(TmpCase):
	def test_regions_value_under_two_seconds(self) -> None:
		beauty, idp, legend = _regions_images(1200, 540)
		leg = {"regions": [{"color": "#%02X%02X%02X" % (i * 6, 255 - i * 5, (i * 37) % 256), "name": "r%d" % i,
							"class": "dressing"} for i in range(36)] + legend["regions"]}
		t = time.perf_counter()
		lab.regions(beauty, idp, leg)
		self.assertLess(time.perf_counter() - t, 2.0)
		rgba = np.concatenate([beauty, np.full(beauty.shape[:2] + (1,), 255, np.uint8)], axis=-1)
		t = time.perf_counter()
		lab.value_shares(rgba, "alpha")
		self.assertLess(time.perf_counter() - t, 2.0)

	def test_sil64_twenty_masks_under_five_seconds(self) -> None:
		d = self.tmp / "m"
		d.mkdir()
		for i in range(20):
			m = _shape("jar" if i % 2 else "pole", 0.6 + i * 0.02)
			Image.fromarray((~m * 255).astype(np.uint8)).save(d / ("m%02d.png" % i))
		t = time.perf_counter()
		res = sil64.run_masks(cm.list_images(d))
		sil64.board(res, self.tmp / "b.png")
		self.assertLess(time.perf_counter() - t, 5.0)

	def test_strip_150_frames_under_ten_seconds(self) -> None:
		_frames(self.tmp / "fr", 150, name="f%08d.jpg", noise=False)
		t = time.perf_counter()
		res = _quiet(strip.make_strip, self.tmp / "fr", self.tmp / "s.jpg", every=1, label_frames=True)
		self.assertLess(time.perf_counter() - t, 10.0)
		self.assertLessEqual(max(res["bytes"]), 4 * 1024 * 1024)


if __name__ == "__main__":
	unittest.main()
