#!/usr/bin/env python3
"""CIELAB sampling for the R3D review toolset (REDESIGN_3D §3.7 — the value hierarchy, measured the same way everywhere).

sRGB (IEC 61966-2-1 transfer curve) → XYZ → CIELAB, D65 white (0.95047, 1.0, 1.08883). L*, C*ab, ΔL*, ΔE76.

usage:
  lab.py color <#RRGGBB|r,g,b> [...] [--json=/abs.json]
      L*, a*, b*, C*, h° of each colour.
  lab.py regions <image.png> --id=<id_pass.png> --legend=<legend.json> [--erode=1] [--tol=2] [--min-px=20]
                 [--json=/abs.json]
      Per ID colour of the legend: median / p10 / p90 / mean of L* and C* (and median a*, b*), the pixel count and the
      shares at L* ≥ 85 / L* ≤ 40, sampled from the beauty image's pixels under that ID (ID edges eroded by --erode px,
      ID colours matched within ±--tol per channel).
  lab.py value <image.png> --mask=<mask.png|alpha> [--mask-color=#RRGGBB] [--mask-mode=auto|alpha|dark|color]
               [--erode=0] [--hi=85] [--lo=40] [--min-share=0.20] [--hist=/abs.png] [--label=hush] [--json=/abs.json]
      The share of a silhouette's pixels at L* ≥ 85 and at L* ≤ 40 (the character rule: ≥ 20 % each) + a histogram PNG.
      `--mask=alpha` uses the image's own alpha (a character rendered on a transparent background).
  lab.py rules <regions.json> [--rules=set|character] [--strict] [--no-fail] [--json=/abs.json]
      PASS / FAIL / SKIP / EXEMPT per region against the §3.7 rules (thresholds: SET_RULES). Exit 1 on any FAIL
      (with --strict also on SKIP) unless --no-fail.
  lab.py falsecolor <image.png> --out=/abs.png [--id=<id.png> --legend=<legend.json>] [--mask=<mask.png|alpha>]
      A board: the image, its L* bands and its C* bands (the rule thresholds as band edges), region medians printed
      when an ID pass is given.

Importable: `rgb_to_lab`, `lab_of`, `chroma`, `delta_e76`, `regions`, `value_shares`, `check_rules`, `falsecolor_board`.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _common as cm  # noqa: E402

# --- colour science -------------------------------------------------------------------------------------------------

WHITE_D65 = np.array([0.95047, 1.0, 1.08883])
M_SRGB_TO_XYZ = np.array([[0.4124564, 0.3575761, 0.1804375],
						[0.2126729, 0.7151522, 0.0721750],
						[0.0193339, 0.1191920, 0.9503041]])
_EPS = (6.0 / 29.0) ** 3
_KAPPA = 1.0 / (3.0 * (6.0 / 29.0) ** 2)


def _linear_lut() -> np.ndarray:
	c = np.arange(256, dtype=np.float64) / 255.0
	return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


_LUT = _linear_lut()


def rgb_to_lab(rgb) -> np.ndarray:
	"""sRGB → CIELAB (D65). `rgb`: (..., 3) uint8 (0–255) or float in 0–1. Returns (..., 3) float64 [L*, a*, b*]."""
	a = np.asarray(rgb)
	if a.dtype == np.uint8:
		lin = _LUT[a[..., :3]]
	else:
		c = np.clip(a[..., :3].astype(np.float64), 0.0, 1.0)
		lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
	xyz = lin @ M_SRGB_TO_XYZ.T / WHITE_D65
	f = np.where(xyz > _EPS, np.cbrt(xyz), xyz * _KAPPA + 4.0 / 29.0)
	L = 116.0 * f[..., 1] - 16.0
	aa = 500.0 * (f[..., 0] - f[..., 1])
	bb = 200.0 * (f[..., 1] - f[..., 2])
	return np.stack([L, aa, bb], axis=-1)


def lab_of(color) -> tuple[float, float, float]:
	"""L*, a*, b* of one colour: `#RRGGBB`, `r,g,b` or an (r, g, b) tuple of 0–255 ints."""
	rgb = cm.hex_to_rgb(color) if isinstance(color, str) else tuple(int(v) for v in color)
	L, a, b = rgb_to_lab(np.array(rgb, dtype=np.uint8))
	return float(L), float(a), float(b)


def chroma(lab) -> np.ndarray | float:
	"""C*ab = sqrt(a*² + b*²)."""
	x = np.asarray(lab, dtype=np.float64)
	c = np.hypot(x[..., 1], x[..., 2])
	return float(c) if c.ndim == 0 else c


def hue_deg(lab) -> float:
	"""h°ab in 0–360 (0 for a neutral colour)."""
	x = np.asarray(lab, dtype=np.float64)
	if np.hypot(x[..., 1], x[..., 2]) < 1e-3:
		return 0.0
	return float(np.degrees(np.arctan2(x[..., 2], x[..., 1])) % 360.0)


def delta_l(lab1, lab2) -> float:
	"""ΔL* = L*₁ − L*₂."""
	return float(np.asarray(lab1)[0] - np.asarray(lab2)[0])


def delta_e76(lab1, lab2) -> float:
	"""ΔE*ab (CIE 1976): the Euclidean distance in L*a*b*."""
	return float(np.linalg.norm(np.asarray(lab1, dtype=np.float64) - np.asarray(lab2, dtype=np.float64)))


def stats(v: np.ndarray) -> dict:
	if v.size == 0:
		return {"median": None, "p10": None, "p90": None, "mean": None}
	p10, med, p90 = np.percentile(v, [10, 50, 90])
	return {"median": cm.rounded(med), "p10": cm.rounded(p10), "p90": cm.rounded(p90), "mean": cm.rounded(v.mean())}


# --- regions (beauty + ID pass + legend) ----------------------------------------------------------------------------

LEGEND_CLASSES = ("wall", "wall_dim", "wainscot", "floor", "dressing", "live_prop", "character", "hiding", "other")


def load_legend(legend) -> list[dict]:
	"""A legend (path or parsed JSON) → a list of entries `{color: (r,g,b), hex, name, class, …extra fields}`.

	Accepted shapes: `{"regions": [{"color": "#RRGGBB", "name": …, "class": …, …}, …]}` (canonical),
	`[{"color": …}, …]`, or `{"#RRGGBB": {"name": …, "class": …}, …}` / `{"#RRGGBB": "name"}`.
	"""
	doc = cm.read_json(legend) if isinstance(legend, (str, Path)) else legend
	if isinstance(doc, dict) and "regions" in doc:
		rows = doc["regions"]
	elif isinstance(doc, list):
		rows = doc
	elif isinstance(doc, dict):
		rows = []
		for k, v in doc.items():
			if isinstance(v, str):
				rows.append({"color": k, "name": v})
			else:
				rows.append(dict(v, color=k))
	else:
		raise ValueError("legend: unsupported JSON shape")
	out = []
	seen: dict[str, str] = {}
	for r in rows:
		rgb = cm.hex_to_rgb(r["color"])
		hx = cm.rgb_to_hex(rgb)
		name = str(r.get("name", hx))
		if hx in seen:
			raise ValueError("legend: colour %s used by both %r and %r" % (hx, seen[hx], name))
		seen[hx] = name
		e = dict(r)
		e["color"] = rgb
		e["hex"] = hx
		e["name"] = name
		e["class"] = str(r.get("class", "other"))
		out.append(e)
	return out


def label_image(id_rgb: np.ndarray, legend: list[dict], tol: int = 2) -> np.ndarray:
	"""(H, W) int32: the legend index of every ID pixel (exact colour first, then the nearest legend colour within
	±tol per channel for the leftovers — antialiased edges, rounding), else −1."""
	px = id_rgb[..., :3].astype(np.int32)
	packed = (px[..., 0] << 16) | (px[..., 1] << 8) | px[..., 2]
	keys = np.array([(e["color"][0] << 16) | (e["color"][1] << 8) | e["color"][2] for e in legend], dtype=np.int32)
	order = np.argsort(keys)
	sk = keys[order]
	pos = np.clip(np.searchsorted(sk, packed), 0, max(0, len(sk) - 1))
	labels = np.full(packed.shape, -1, dtype=np.int32)
	if len(sk):
		hit = sk[pos] == packed
		labels[hit] = order[pos[hit]]
	if tol > 0 and len(legend):
		rest = np.flatnonzero(labels.reshape(-1) < 0)
		if rest.size:
			rp = px.reshape(-1, 3)[rest].astype(np.int16)
			best = np.full(rest.size, 10_000, dtype=np.int16)
			lab_r = np.full(rest.size, -1, dtype=np.int32)
			for i, e in enumerate(legend):
				d = np.abs(rp - np.array(e["color"], dtype=np.int16)).max(axis=-1)
				ok = (d <= tol) & (d < best)
				lab_r[ok] = i
				best[ok] = d[ok]
			flat = labels.reshape(-1)
			flat[rest] = lab_r
	return labels


def erode_labels(labels: np.ndarray, n: int = 1) -> np.ndarray:
	"""Drop every pixel whose 8 neighbours are not all its own label (antialiased ID edges), n times."""
	lab = labels.copy()
	h, w = lab.shape
	for _ in range(max(0, n)):
		p = np.pad(lab, 1, mode="edge")
		keep = np.ones_like(lab, dtype=bool)
		for dy in (0, 1, 2):
			for dx in (0, 1, 2):
				if dy == 1 and dx == 1:
					continue
				keep &= p[dy:dy + h, dx:dx + w] == lab
		lab = np.where(keep, lab, -1)
	return lab


def _pixel_stats(labv: np.ndarray, hi: float = 85.0, lo: float = 40.0) -> dict:
	L = labv[:, 0]
	C = np.hypot(labv[:, 1], labv[:, 2])
	n = int(L.size)
	return {
		"px": n,
		"L": stats(L),
		"C": stats(C),
		"a": cm.rounded(np.median(labv[:, 1])) if n else None,
		"b": cm.rounded(np.median(labv[:, 2])) if n else None,
		"share_hi": cm.rounded((L >= hi).mean(), 4) if n else None,
		"share_lo": cm.rounded((L <= lo).mean(), 4) if n else None,
	}


def regions(image, id_pass, legend, erode: int = 1, tol: int = 2, min_px: int = 20) -> dict:
	"""Sample every legend region of `image` (path or RGBA array) under the ID pass `id_pass` (path or array).

	Returns `{"size": [w, h], "erode": n, "tol": t, "regions": [{name, class, color, px, L{…}, C{…}, a, b, share_hi,
	share_lo, visible, …legend extras}], "unmatched_px": n}`. Beauty pixels with alpha < 128 are ignored.
	"""
	img = cm.load_rgba(image) if isinstance(image, (str, Path)) else np.asarray(image)
	idp = cm.load_rgba(id_pass) if isinstance(id_pass, (str, Path)) else np.asarray(id_pass)
	if img.shape[:2] != idp.shape[:2]:
		raise ValueError("image %s and ID pass %s differ in size" % (img.shape[1::-1], idp.shape[1::-1]))
	leg = load_legend(legend)
	labels = label_image(idp, leg, tol)
	if idp.shape[-1] == 4 and cm.has_real_alpha(idp):
		labels[idp[..., 3] < 128] = -1
	unmatched = int((labels < 0).sum())
	labels = erode_labels(labels, erode)
	if img.shape[-1] == 4:
		labels[img[..., 3] < 128] = -1
	lab = rgb_to_lab(img[..., :3].astype(np.uint8))
	flat_lab = lab.reshape(-1, 3)
	flat_lbl = labels.reshape(-1)
	order = np.argsort(flat_lbl, kind="stable")
	sorted_lbl = flat_lbl[order]
	out = []
	for i, e in enumerate(leg):
		lo_i, hi_i = np.searchsorted(sorted_lbl, [i, i + 1])
		sel = flat_lab[order[lo_i:hi_i]]
		row = {k: v for k, v in e.items() if k not in ("color", "hex")}
		row["color"] = e["hex"]
		row.update(_pixel_stats(sel))
		row["visible"] = row["px"] >= min_px
		row["median_hex"] = _lab_median_hex(img, labels, i) if row["px"] else None
		out.append(row)
	return {"size": [int(img.shape[1]), int(img.shape[0])], "erode": erode, "tol": tol, "min_px": min_px,
			"regions": out, "unmatched_px": unmatched}


def _lab_median_hex(img: np.ndarray, labels: np.ndarray, i: int) -> str:
	sel = img[..., :3][labels == i]
	return cm.rgb_to_hex(np.median(sel, axis=0))


# --- value shares (the character rule) -----------------------------------------------------------------------------

def load_mask(mask, image_rgba: np.ndarray | None = None, mode: str = "auto", color: str | None = None,
			tol: int = 2) -> np.ndarray:
	"""A boolean mask from a PNG path (or `"alpha"` = the image's own alpha, or a bool array)."""
	if isinstance(mask, np.ndarray):
		return mask.astype(bool)
	if str(mask) == "alpha":
		if image_rgba is None:
			raise ValueError("--mask=alpha needs the image")
		return image_rgba[..., 3] >= 128
	return cm.mask_from_image(cm.load_rgba(mask), mode=mode, color=color, tol=tol)


def value_shares(image, mask, hi: float = 85.0, lo: float = 40.0, min_share: float = 0.20, erode: int = 0,
				mode: str = "auto", color: str | None = None, tol: int = 2) -> dict:
	"""Shares of the masked pixels at L* ≥ hi and L* ≤ lo (REDESIGN §3.7: each ≥ 20 % for a character)."""
	img = cm.load_rgba(image) if isinstance(image, (str, Path)) else np.asarray(image)
	m = load_mask(mask, img, mode=mode, color=color, tol=tol)
	if m.shape != img.shape[:2]:
		raise ValueError("mask %s and image %s differ in size" % (m.shape[::-1], img.shape[1::-1]))
	if erode:
		m = cm.erode(m, erode)
	labv = rgb_to_lab(img[..., :3][m].astype(np.uint8))
	s = _pixel_stats(labv, hi, lo)
	n = s["px"]
	s["share_mid"] = cm.rounded(1.0 - s["share_hi"] - s["share_lo"], 4) if n else None
	s["hi"] = hi
	s["lo"] = lo
	s["min_share"] = min_share
	s["pass"] = bool(n and s["share_hi"] >= min_share and s["share_lo"] >= min_share)
	s["bbox"] = list(cm.bbox(m) or ())
	s["_L"] = labv[:, 0]
	return s


def value_hist_png(res: dict, out: str | Path, label: str = "", image=None, mask=None) -> None:
	"""A 1200×540 board: the L* histogram (bins of 2) with the ≤ lo and ≥ hi zones, the shares and PASS/FAIL, and
	the masked pixels painted dark / mid / light next to it."""
	L = res["_L"]
	W, H = 1200, 540
	im = Image.new("RGB", (W, H), cm.BG)
	d = ImageDraw.Draw(im)
	f_t, f_s, f_b = cm.font(30), cm.font(18), cm.font(24)
	verdict = "PASS" if res["pass"] else "FAIL"
	d.text((24, 16), "Value shares%s" % (" · " + label if label else ""), font=f_t, fill=cm.INK)
	cm.pill(d, (W - 24, 18), verdict, f_b, fg=(20, 20, 20), bg=cm.GREEN if res["pass"] else cm.RED, anchor_right=True)
	# histogram
	x0, y0, x1, y1 = 40, 80, 700, 470
	hist, _ = np.histogram(L, bins=50, range=(0, 100))
	top = max(1, int(hist.max()))
	lo_x = x0 + (x1 - x0) * res["lo"] / 100.0
	hi_x = x0 + (x1 - x0) * res["hi"] / 100.0
	d.rectangle((x0, y0, lo_x, y1), fill=(34, 40, 72))
	d.rectangle((hi_x, y0, x1, y1), fill=(72, 66, 40))
	bw = (x1 - x0) / 50.0
	for i, v in enumerate(hist):
		if v == 0:
			continue
		lstar = i * 2 + 1
		g = int(round(255 * (lstar / 100.0)))
		h = (y1 - y0) * v / top
		d.rectangle((x0 + i * bw + 1, y1 - h, x0 + (i + 1) * bw - 1, y1), fill=(g, g, g), outline=(90, 84, 110))
	d.line((x0, y1, x1, y1), fill=cm.MUTED, width=2)
	for t in range(0, 101, 10):
		x = x0 + (x1 - x0) * t / 100.0
		d.line((x, y1, x, y1 + 6), fill=cm.MUTED, width=1)
		d.text((x - 10, y1 + 8), str(t), font=f_s, fill=cm.MUTED)
	d.text((x0, y1 + 32), "L*", font=f_s, fill=cm.MUTED)
	d.text((x0 + 8, y0 + 8), "≤ %g: %.1f %%" % (res["lo"], 100 * res["share_lo"]), font=f_b, fill=cm.BLUE)
	d.text((hi_x + 8 if hi_x < x1 - 200 else x1 - 200, y0 + 8), "≥ %g: %.1f %%" % (res["hi"], 100 * res["share_hi"]),
		font=f_b, fill=cm.AMBER)
	d.text((x0, y0 - 30), "%d px · median L* %.1f · need ≥ %d %% at each end" % (
		res["px"], res["L"]["median"] or 0, round(100 * res["min_share"])), font=f_s, fill=cm.INK)
	# the silhouette painted by value band
	if image is not None and mask is not None and res["bbox"]:
		img = np.asarray(image)
		m = mask
		bx0, by0, bx1, by1 = res["bbox"]
		crop = img[by0:by1, bx0:bx1, :3].copy()
		mc = m[by0:by1, bx0:bx1]
		labc = rgb_to_lab(crop.astype(np.uint8))[..., 0]
		paint = np.zeros_like(crop)
		paint[:] = (60, 56, 76)
		paint[mc & (labc <= res["lo"])] = (40, 70, 200)
		paint[mc & (labc >= res["hi"])] = (255, 200, 60)
		paint[mc & (labc > res["lo"]) & (labc < res["hi"])] = (150, 150, 150)
		pa = Image.fromarray(paint)
		orig = Image.fromarray(np.where(mc[..., None], crop, np.array([60, 56, 76], dtype=np.uint8)))
		ph = 380
		s = ph / max(1, pa.height)
		pw = max(1, round(pa.width * s))
		if pw > 225:
			s = 225 / pa.width
			pw, ph = 225, max(1, round(pa.height * s))
		orig = orig.resize((pw, ph), Image.NEAREST)
		pa = pa.resize((pw, ph), Image.NEAREST)
		im.paste(orig, (730, 80))
		im.paste(pa, (730 + pw + 16, 80))
		d.text((730, 80 + ph + 8), "masked pixels", font=f_s, fill=cm.MUTED)
		d.text((730 + pw + 16, 80 + ph + 8), "dark / mid / light", font=f_s, fill=cm.MUTED)
	cm.save_image(im, out)


# --- rules (REDESIGN §3.7) -----------------------------------------------------------------------------------------

SET_RULES = {
	"wall_lit_L": [62.0, 76.0], "wall_lit_C_max": 28.0,
	"wall_dim_L": [45.0, 58.0], "wall_dim_C_max": 15.0,
	"wainscot_dL": [8.0, 10.0],
	"floor_L": [40.0, 50.0],
	"dressing_C_max": 30.0, "dressing_dL_max": 15.0,
	"live_C_min": 45.0,
	"char_hi": 85.0, "char_lo": 40.0, "char_share_min": 0.20,
}


def _is_dim(r: dict) -> bool:
	return r.get("class") == "wall_dim" or r.get("lit") is False


def _find_wall(r: dict, rows: list[dict]) -> dict | None:
	walls = [w for w in rows if w.get("class") in ("wall", "wall_dim")]
	if r.get("wall"):
		for w in walls:
			if w["name"] == r["wall"]:
				return w
		return None
	if r.get("room"):
		same = [w for w in walls if w.get("room") == r["room"]]
		if len(same) == 1:
			return same[0]
	if len(walls) == 1:
		return walls[0]
	return None


def check_rules(doc, rules: str = "set", thresholds: dict | None = None) -> dict:
	"""Check a `regions()` result (dict or path) against REDESIGN §3.7.

	Each result: `{name, class, rule, value, limit, status, detail}` with status PASS | FAIL | SKIP (not visible, no
	reference wall) | EXEMPT (legend `"exempt": "<reason>"`) | INFO (a region class without a rule). The medians are
	judged (L*, C*); characters by their shares. `rules="character"` checks characters only.
	"""
	t = dict(SET_RULES, **(thresholds or {}))
	d = cm.read_json(doc) if isinstance(doc, (str, Path)) else doc
	rows = d["regions"]
	res = []

	def add(r, rule, value, limit, ok, detail=""):
		res.append({"name": r["name"], "class": r.get("class"), "rule": rule, "value": value, "limit": limit,
					"status": ("PASS" if ok else "FAIL") if ok is not None else "SKIP", "detail": detail})

	for r in rows:
		cls = r.get("class", "other")
		if rules == "character" and cls != "character":
			continue
		if r.get("exempt"):
			res.append({"name": r["name"], "class": cls, "rule": "-", "value": None, "limit": None,
						"status": "EXEMPT", "detail": str(r["exempt"])})
			continue
		if not r.get("visible", r.get("px", 0) > 0):
			res.append({"name": r["name"], "class": cls, "rule": "visible", "value": r.get("px"), "limit": None,
						"status": "SKIP", "detail": "not visible (%s px)" % r.get("px")})
			continue
		Lm, Cm = r["L"]["median"], r["C"]["median"]
		if cls in ("wall", "wall_dim"):
			if _is_dim(r):
				lo, hi = t["wall_dim_L"]
				add(r, "dim wall L*", Lm, [lo, hi], lo <= Lm <= hi)
				add(r, "dim wall C*", Cm, t["wall_dim_C_max"], Cm <= t["wall_dim_C_max"])
			else:
				lo, hi = t["wall_lit_L"]
				add(r, "lit wall L*", Lm, [lo, hi], lo <= Lm <= hi)
				add(r, "lit wall C*", Cm, t["wall_lit_C_max"], Cm <= t["wall_lit_C_max"])
		elif cls == "wainscot":
			w = _find_wall(r, rows)
			if w is None or not w.get("visible", True) or w["L"]["median"] is None:
				add(r, "wainscot ΔL*", None, t["wainscot_dL"], None, "no reference wall (legend `wall` or `room`)")
			else:
				dl = cm.rounded(w["L"]["median"] - Lm)
				lo, hi = t["wainscot_dL"]
				add(r, "wainscot ΔL* (wall − wainscot)", dl, [lo, hi], lo <= dl <= hi, "vs %s" % w["name"])
		elif cls == "floor":
			if _is_dim(r):
				res.append({"name": r["name"], "class": cls, "rule": "floor L*", "value": Lm, "limit": None,
							"status": "INFO", "detail": "dimmed floor (no rule)"})
			else:
				lo, hi = t["floor_L"]
				add(r, "floor L*", Lm, [lo, hi], lo <= Lm <= hi)
		elif cls == "dressing":
			add(r, "dressing C*", Cm, t["dressing_C_max"], Cm <= t["dressing_C_max"])
			w = _find_wall(r, rows)
			if w is None or w["L"]["median"] is None:
				add(r, "dressing |ΔL*|", None, t["dressing_dL_max"], None,
					"no reference wall (legend `wall` or `room`)")
			else:
				dl = cm.rounded(abs(Lm - w["L"]["median"]))
				add(r, "dressing |ΔL*|", dl, t["dressing_dL_max"], dl <= t["dressing_dL_max"], "vs %s" % w["name"])
		elif cls == "live_prop":
			if r.get("halo"):
				add(r, "live prop C* or halo", Cm, t["live_C_min"], True, "verb halo (legend)")
			else:
				add(r, "live prop C*", Cm, t["live_C_min"], Cm >= t["live_C_min"])
		elif cls == "character":
			# regions() measures the shares at the §3.7 thresholds (L* ≥ 85, ≤ 40).
			need = t["char_share_min"]
			sh, sl = r.get("share_hi") or 0.0, r.get("share_lo") or 0.0
			add(r, "character share L* ≥ %g" % t["char_hi"], sh, need, sh >= need)
			add(r, "character share L* ≤ %g" % t["char_lo"], sl, need, sl >= need)
		else:
			res.append({"name": r["name"], "class": cls, "rule": "-", "value": Lm, "limit": None, "status": "INFO",
						"detail": "no rule for class %r" % cls})
	counts = {k: sum(1 for x in res if x["status"] == k) for k in ("PASS", "FAIL", "SKIP", "EXEMPT", "INFO")}
	return {"rules": rules, "thresholds": t, "results": res, "counts": counts, "pass": counts["FAIL"] == 0}


def format_rules(rep: dict) -> str:
	lines = ["%-7s %-26s %-11s %-34s %9s  %-12s %s" % ("status", "region", "class", "rule", "value", "limit",
																		"detail")]
	for x in rep["results"]:
		v = x["value"]
		vs = "-" if v is None else ("%.3f" % v if isinstance(v, float) and v < 1.0 and "share" in x["rule"]
									else "%.1f" % v if isinstance(v, (int, float)) else str(v))
		lim = x["limit"]
		ls = "-" if lim is None else ("%g–%g" % tuple(lim) if isinstance(lim, list) else "%g" % lim)
		lines.append("%-7s %-26s %-11s %-34s %9s  %-12s %s" % (x["status"], x["name"][:26], (x["class"] or "")[:11],
																x["rule"][:34], vs, ls, x["detail"]))
	c = rep["counts"]
	lines.append("%s — %d pass, %d fail, %d skip, %d exempt, %d info" % (
		"PASS" if rep["pass"] else "FAIL", c["PASS"], c["FAIL"], c["SKIP"], c["EXEMPT"], c["INFO"]))
	return "\n".join(lines)


# --- false colour --------------------------------------------------------------------------------------------------

L_BANDS = [  # (lo, hi, rgb, label) — the §3.7 thresholds as band edges
	(0, 40, (36, 52, 150), "≤ 40 dark (character darks)"),
	(40, 50, (40, 150, 190), "40–50 floor"),
	(50, 62, (70, 170, 120), "50–62 mid (dim walls 45–58)"),
	(62, 76, (160, 200, 70), "62–76 lit wall"),
	(76, 85, (240, 190, 60), "76–85 light"),
	(85, 101, (255, 90, 170), "≥ 85 highlight (character lights)"),
]
C_BANDS = [
	(0, 15, (110, 110, 118), "C* ≤ 15 grey (dim walls)"),
	(15, 30, (120, 170, 200), "15–30 soft (walls ≤ 28, dressing ≤ 30)"),
	(30, 45, (240, 150, 50), "30–45 loud for dressing, dull for a live prop"),
	(45, 1000, (235, 40, 140), "≥ 45 saturated (live props)"),
]


def _band_paint(v: np.ndarray, bands) -> np.ndarray:
	out = np.zeros(v.shape + (3,), dtype=np.uint8)
	for lo, hi, rgb, _ in bands:
		out[(v >= lo) & (v < hi)] = rgb
	return out


def falsecolor_board(image, out: str | Path, id_pass=None, legend=None, mask=None, title: str = "") -> dict:
	"""Image | L* bands / C* bands | legend (+ region medians when an ID pass and legend are given). Returns the
	`regions()` result when one was computed, else {}."""
	img = cm.load_rgba(image) if isinstance(image, (str, Path)) else np.asarray(image)
	lab = rgb_to_lab(img[..., :3].astype(np.uint8))
	L = lab[..., 0]
	C = np.hypot(lab[..., 1], lab[..., 2])
	h, w = L.shape
	m = None
	if mask is not None:
		m = load_mask(mask, img)
	pl = _band_paint(L, L_BANDS)
	pc = _band_paint(C, C_BANDS)
	if m is not None:
		pl[~m] = (pl[~m] * 0.25).astype(np.uint8)
		pc[~m] = (pc[~m] * 0.25).astype(np.uint8)
	reg = {}
	cw, ch = 1200, round(1200 * h / w)
	pad, head = 16, 56
	W = 2 * cw + 3 * pad
	H = head + 2 * (ch + 36) + 3 * pad
	board = Image.new("RGB", (W, H), cm.BG)
	d = ImageDraw.Draw(board)
	f_t, f_s, f_l = cm.font(30), cm.font(20), cm.font(16)
	d.text((pad, 12), title or "L* / C* false colour", font=f_t, fill=cm.INK)
	panels = [(Image.fromarray(img[..., :3]), "image"), (Image.fromarray(pl), "L* bands"),
			(Image.fromarray(pc), "C* bands")]
	pos = [(pad, head), (2 * pad + cw, head), (pad, head + ch + 36 + pad)]
	for (p, lab_txt), (x, y) in zip(panels, pos):
		board.paste(p.resize((cw, ch), Image.NEAREST if p.width < cw else Image.LANCZOS), (x, y))
		d.text((x, y + ch + 6), lab_txt, font=f_s, fill=cm.MUTED)
	# legend panel
	lx, ly = 2 * pad + cw, head + ch + 36 + pad
	d.rectangle((lx, ly, lx + cw, ly + ch), fill=cm.PANEL)
	yy = ly + 12
	d.text((lx + 16, yy), "L* bands", font=f_s, fill=cm.INK)
	yy += 28
	for lo, hi, rgb, txt in L_BANDS:
		d.rectangle((lx + 16, yy + 2, lx + 40, yy + 20), fill=rgb)
		d.text((lx + 50, yy), txt, font=f_l, fill=cm.INK)
		yy += 24
	yy += 8
	d.text((lx + 16, yy), "C* bands", font=f_s, fill=cm.INK)
	yy += 28
	for lo, hi, rgb, txt in C_BANDS:
		d.rectangle((lx + 16, yy + 2, lx + 40, yy + 20), fill=rgb)
		d.text((lx + 50, yy), txt, font=f_l, fill=cm.INK)
		yy += 24
	if id_pass is not None and legend is not None:
		reg = regions(img, id_pass, legend)
		verdicts: dict[str, str] = {}
		for x in check_rules(reg)["results"]:
			if x["status"] in ("PASS", "FAIL"):
				verdicts[x["name"]] = "FAIL" if x["status"] == "FAIL" or verdicts.get(x["name"]) == "FAIL" else "PASS"
		tx, ty = lx + cw // 2, ly + 12
		d.text((tx, ty), "region medians (L* / C*) · §3.7 rules", font=f_s, fill=cm.INK)
		ty += 28
		lbl = erode_labels(label_image(cm.load_rgba(id_pass) if isinstance(id_pass, (str, Path)) else id_pass,
										load_legend(legend)), 1)
		sx = cw / w
		for i, r in enumerate(reg["regions"]):
			if not r["px"]:
				continue
			if ty < ly + ch - 20:
				v = verdicts.get(r["name"], "")
				col = cm.RED if v == "FAIL" else cm.GREEN if v == "PASS" else cm.INK
				d.text((tx, ty), "%s  %s  L %.0f  C %.0f  %s" % (r["name"][:22], r["class"][:10], r["L"]["median"],
																	r["C"]["median"], v), font=f_l, fill=col)
				ty += 20
			ys, xs = np.nonzero(lbl == i)
			if ys.size:
				cx, cy = int(np.median(xs) * sx), int(np.median(ys) * sx)
				for (px0, py0) in pos[1:2]:
					cm.pill(d, (px0 + cx - 30, py0 + cy - 12), "%.0f" % r["L"]["median"], f_l, bg=(0, 0, 0))
				for (px0, py0) in pos[2:3]:
					cm.pill(d, (px0 + cx - 30, py0 + cy - 12), "%.0f" % r["C"]["median"], f_l, bg=(0, 0, 0))
	cm.save_image(board, out)
	return reg


# --- CLI -----------------------------------------------------------------------------------------------------------

def _cmd_color(a) -> int:
	rows = []
	for c in a.colors:
		L, aa, bb = lab_of(c)
		rows.append({"color": c, "hex": cm.rgb_to_hex(cm.hex_to_rgb(c)), "L": cm.rounded(L), "a": cm.rounded(aa),
					"b": cm.rounded(bb), "C": cm.rounded(np.hypot(aa, bb)), "h": cm.rounded(hue_deg([L, aa, bb]), 1)})
		print("%-9s L* %6.2f  a* %7.2f  b* %7.2f  C* %6.2f  h %5.1f" % (rows[-1]["hex"], L, aa, bb, rows[-1]["C"],
																		rows[-1]["h"]))
	if a.json:
		cm.write_json(a.json, {"colors": rows})
	return 0


def _cmd_regions(a) -> int:
	r = regions(a.image, a.id, a.legend, erode=a.erode, tol=a.tol, min_px=a.min_px)
	r["image"] = str(Path(a.image).resolve())
	r["id_pass"] = str(Path(a.id).resolve())
	r["legend"] = str(Path(a.legend).resolve())
	print("%-26s %-11s %7s %7s %7s %7s %7s %6s %6s" % ("region", "class", "px", "L*med", "L*p10", "L*p90", "C*med",
														"hi%", "lo%"))
	for x in r["regions"]:
		if not x["px"]:
			print("%-26s %-11s %7d  (not visible)" % (x["name"][:26], x["class"][:11], 0))
			continue
		print("%-26s %-11s %7d %7.1f %7.1f %7.1f %7.1f %6.1f %6.1f" % (
			x["name"][:26], x["class"][:11], x["px"], x["L"]["median"], x["L"]["p10"], x["L"]["p90"],
			x["C"]["median"], 100 * x["share_hi"], 100 * x["share_lo"]))
	print("unmatched ID px: %d" % r["unmatched_px"])
	if a.json:
		cm.write_json(a.json, r)
	return 0


def _cmd_value(a) -> int:
	img = cm.load_rgba(a.image)
	m = load_mask(a.mask, img, mode=a.mask_mode, color=a.mask_color, tol=a.tol)
	if a.erode:
		m = cm.erode(m, a.erode)
	r = value_shares(img, m, hi=a.hi, lo=a.lo, min_share=a.min_share)
	print("%s: %d px · L* ≥ %g: %.1f %% · L* ≤ %g: %.1f %% · median L* %.1f · %s (need ≥ %.0f %% each)" % (
		a.label or Path(a.image).name, r["px"], a.hi, 100 * (r["share_hi"] or 0), a.lo, 100 * (r["share_lo"] or 0),
		r["L"]["median"] or 0, "PASS" if r["pass"] else "FAIL", 100 * a.min_share))
	if a.hist:
		value_hist_png(r, a.hist, a.label, image=img, mask=m)
	out = {k: v for k, v in r.items() if not k.startswith("_")}
	out.update({"image": str(Path(a.image).resolve()), "mask": str(a.mask), "label": a.label, "erode": a.erode})
	if a.json:
		cm.write_json(a.json, out)
	return 0


def _cmd_rules(a) -> int:
	rep = check_rules(a.regions, a.rules)
	print(format_rules(rep))
	if a.json:
		cm.write_json(a.json, rep)
	bad = rep["counts"]["FAIL"] + (rep["counts"]["SKIP"] if a.strict else 0)
	return 0 if (a.no_fail or bad == 0) else 1


def _cmd_falsecolor(a) -> int:
	reg = falsecolor_board(a.image, a.out, id_pass=a.id, legend=a.legend, mask=a.mask, title=a.title)
	print("wrote %s" % a.out)
	if a.json and reg:
		cm.write_json(a.json, reg)
	return 0


def main(argv: list[str] | None = None) -> int:
	ap = argparse.ArgumentParser(prog="lab.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	sub = ap.add_subparsers(dest="cmd", required=True)
	p = sub.add_parser("color", help="L*, a*, b*, C*, h of colours")
	p.add_argument("colors", nargs="+")
	p.add_argument("--json")
	p.set_defaults(fn=_cmd_color)
	p = sub.add_parser("regions", help="per-ID-colour L*/C* stats")
	p.add_argument("image")
	p.add_argument("--id", required=True)
	p.add_argument("--legend", required=True)
	p.add_argument("--erode", type=int, default=1)
	p.add_argument("--tol", type=int, default=2)
	p.add_argument("--min-px", type=int, default=20)
	p.add_argument("--json")
	p.set_defaults(fn=_cmd_regions)
	p = sub.add_parser("value", help="silhouette shares at L* ≥ 85 and ≤ 40")
	p.add_argument("image")
	p.add_argument("--mask", required=True)
	p.add_argument("--mask-mode", default="auto", choices=("auto", "alpha", "dark", "color"))
	p.add_argument("--mask-color")
	p.add_argument("--tol", type=int, default=2)
	p.add_argument("--erode", type=int, default=0)
	p.add_argument("--hi", type=float, default=85.0)
	p.add_argument("--lo", type=float, default=40.0)
	p.add_argument("--min-share", type=float, default=0.20)
	p.add_argument("--hist")
	p.add_argument("--label", default="")
	p.add_argument("--json")
	p.set_defaults(fn=_cmd_value)
	p = sub.add_parser("rules", help="REDESIGN §3.7 PASS/FAIL per region")
	p.add_argument("regions")
	p.add_argument("--rules", default="set", choices=("set", "character"))
	p.add_argument("--strict", action="store_true")
	p.add_argument("--no-fail", action="store_true")
	p.add_argument("--json")
	p.set_defaults(fn=_cmd_rules)
	p = sub.add_parser("falsecolor", help="L*/C* false-colour board")
	p.add_argument("image")
	p.add_argument("--out", required=True)
	p.add_argument("--id")
	p.add_argument("--legend")
	p.add_argument("--mask")
	p.add_argument("--title", default="")
	p.add_argument("--json")
	p.set_defaults(fn=_cmd_falsecolor)
	a = ap.parse_args(argv)
	return a.fn(a)


if __name__ == "__main__":
	sys.exit(cm.run_cli(main, "lab.py"))
