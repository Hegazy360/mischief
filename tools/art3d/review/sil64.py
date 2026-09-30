#!/usr/bin/env python3
"""64 px silhouettes + pairwise IoU (REDESIGN_3D §3.6: every live prop — and every Hush verb — reads as a black shape
at 64 px; no two in one family).

usage:
  sil64.py masks <dir|mask.png> [...] --out=/abs/board.png [--same-family=0.80] [--height=64] [--canvas=96]
                 [--fit=height|box] [--names=a,b,…] [--mode=auto|alpha|dark] [--cells-dir=/abs/dir] [--title=…]
                 [--despeckle=0.002] [--json=/abs.json]
      Each mask (a black shape on transparent or on white) loses its specks (connected parts under --despeckle of its
      pixels: stray ID pixels, particles; 0 keeps everything), is cropped to its bounds, scaled so its HEIGHT is 64 px
      (aspect kept; `--fit=box` fits the longer side instead), centred (bounding-box centre) on a 96×96 canvas (widened
      for everyone when a shape is wider than the canvas); the IoU of every pair on that canvas; pairs at or above
      `--same-family` are flagged. Board: the 64 px silhouettes at 1× (+ 2×), the IoU matrix, the flagged pairs
      overlaid. `--cells-dir` writes each normalised silhouette as its own PNG (e.g. to build reviewer packets).
  sil64.py extract <image.png> --out=/abs/mask.png [--mode=alpha|dark|color] [--color=#RRGGBB] [--tol=2]
      A black-on-transparent mask PNG from a render: its alpha, its dark pixels or one exact ID colour.

JSON (`masks`): {"names": […], "files": […], "iou": [[…]], "pairs_over": [{"a", "b", "iou"}], "threshold": 0.8,
"height": 64, "canvas": [w, h], "fit": "height", "sizes": [[w, h], …] (the normalised shapes' sizes)}.
Importable: `load_mask`, `normalise`, `iou`, `iou_matrix`, `run_masks`.
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _common as cm  # noqa: E402


def load_mask(path, mode: str = "auto", color: str | None = None, tol: int = 2) -> np.ndarray:
	"""Boolean shape of a mask PNG: auto = alpha when the PNG has transparency, else the dark pixels."""
	return cm.mask_from_image(cm.load_rgba(path), mode=mode, color=color, tol=tol)


def shape_size(mask: np.ndarray, height: int = 64, fit: str = "height") -> tuple[int, int]:
	"""(w, h) of the normalised shape before it is placed on the canvas."""
	b = cm.bbox(mask)
	if b is None:
		return (0, 0)
	w, h = b[2] - b[0], b[3] - b[1]
	s = height / h if fit == "height" else height / max(w, h)
	return max(1, round(w * s)), max(1, round(h * s))


def normalise(mask: np.ndarray, height: int = 64, canvas: tuple[int, int] = (96, 96), fit: str = "height") -> np.ndarray:
	"""Crop to the bounds, area-resample to `height` px tall (or the longer side, `fit="box"`), threshold at ½,
	centre on a canvas (w, h). A shape wider than the canvas is clipped — size the canvas with `shape_size` first."""
	cw, ch = canvas
	out = np.zeros((ch, cw), dtype=bool)
	b = cm.bbox(mask)
	if b is None:
		return out
	x0, y0, x1, y1 = b
	crop = Image.fromarray((mask[y0:y1, x0:x1] * 255).astype(np.uint8), "L")
	nw, nh = shape_size(mask, height, fit)
	small = np.asarray(crop.resize((nw, nh), Image.BOX if nw < crop.width else Image.BILINEAR)) >= 128
	ox, oy = (cw - nw) // 2, (ch - nh) // 2
	sx0, sy0 = max(0, -ox), max(0, -oy)
	dx0, dy0 = max(0, ox), max(0, oy)
	w = min(nw - sx0, cw - dx0)
	h = min(nh - sy0, ch - dy0)
	out[dy0:dy0 + h, dx0:dx0 + w] = small[sy0:sy0 + h, sx0:sx0 + w]
	return out


def iou(a: np.ndarray, b: np.ndarray) -> float:
	"""|A ∩ B| / |A ∪ B| (1.0 for two empty masks)."""
	u = np.logical_or(a, b).sum()
	if u == 0:
		return 1.0
	return float(np.logical_and(a, b).sum() / u)


def iou_matrix(norm: list[np.ndarray]) -> np.ndarray:
	n = len(norm)
	m = np.eye(n)
	for i in range(n):
		for j in range(i + 1, n):
			m[i, j] = m[j, i] = iou(norm[i], norm[j])
	return m


def run_masks(paths: list[Path], names: list[str] | None = None, height: int = 64, canvas: int = 96,
			fit: str = "height", threshold: float = 0.80, mode: str = "auto", despeckle: float = 0.002) -> dict:
	"""Normalise every mask on one shared canvas and compute the IoU matrix. Returns the JSON dict plus `_norm`
	(the normalised boolean arrays). `despeckle` drops specks under that share of a mask's pixels first."""
	masks = [cm.despeckle(load_mask(p, mode=mode), despeckle) for p in paths]
	names = names or [p.stem for p in paths]
	if len(names) != len(paths):
		raise ValueError("%d names for %d masks" % (len(names), len(paths)))
	sizes = [shape_size(m, height, fit) for m in masks]
	cw = max([canvas] + [w + 4 for w, _ in sizes])
	cw += cw % 2
	chh = max([canvas] + [h + 4 for _, h in sizes])
	norm = [normalise(m, height, (cw, chh), fit) for m in masks]
	mat = iou_matrix(norm)
	pairs = []
	for i in range(len(norm)):
		for j in range(i + 1, len(norm)):
			if mat[i, j] >= threshold:
				pairs.append({"a": names[i], "b": names[j], "iou": cm.rounded(mat[i, j], 4)})
	pairs.sort(key=lambda p: -p["iou"])
	empty = [names[i] for i, m in enumerate(masks) if not m.any()]
	return {"names": names, "files": [str(p) for p in paths], "iou": [[cm.rounded(v, 4) for v in row] for row in mat],
			"pairs_over": pairs, "threshold": threshold, "height": height, "canvas": [cw, chh], "fit": fit,
			"sizes": [list(s) for s in sizes], "empty": empty, "_norm": norm}


def _sil_img(m: np.ndarray, scale: int = 1) -> Image.Image:
	a = np.where(m, 0, 255).astype(np.uint8)
	im = Image.fromarray(a, "L").convert("RGB")
	if scale != 1:
		im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
	return im


def _heat(v: float, thr: float) -> tuple[int, int, int]:
	if v >= thr:
		return (200, 40, 40)
	if v >= thr - 0.2:
		return (190, 130, 30)
	return (40, 110, 60)


def board(res: dict, out: str | Path, title: str = "") -> None:
	"""The 64 px silhouettes (1× and 2×), the IoU matrix and the flagged pairs overlaid (A red, B blue, both purple)."""
	names, norm, thr = res["names"], res["_norm"], res["threshold"]
	n = len(names)
	cw, ch = res["canvas"]
	f_t, f_s, f_l = cm.font(30), cm.font(16), cm.font(14)
	pad = 16
	cols = max(1, min(n, max(4, int(2200 // (2 * cw + pad)))))
	rows = math.ceil(n / cols) if n else 0
	cell_w, cell_h = 2 * cw + cw + 3 * pad, 2 * ch + 40
	grid_w = cols * cell_w
	mat_cell = 44 if n <= 16 else 30
	lab_w = 180
	col_h = 30
	mat_w = lab_w + n * mat_cell
	mat_h = col_h + n * mat_cell
	pairs = res["pairs_over"]
	ov_h = (2 * ch + 40) if pairs else 0
	W = max(grid_w, mat_w + 2 * pad, 1200) + 2 * pad
	H = 64 + rows * cell_h + pad + mat_h + pad + (40 + ov_h if pairs else 40) + pad
	im = Image.new("RGB", (W, H), cm.BG)
	d = ImageDraw.Draw(im)
	d.text((pad, 14), title or "64 px silhouettes · IoU (same family ≥ %.2f)" % thr, font=f_t, fill=cm.INK)
	y0 = 64
	for k, name in enumerate(names):
		r, c = divmod(k, cols)
		x, y = pad + c * cell_w, y0 + r * cell_h
		im.paste(_sil_img(norm[k], 1), (x, y + ch // 2))
		im.paste(_sil_img(norm[k], 2), (x + cw + pad, y))
		flagged = any(p["a"] == name or p["b"] == name for p in pairs)
		d.text((x, y + 2 * ch + 6), "%d %s" % (k + 1, name[:28]), font=f_s, fill=cm.RED if flagged else cm.INK)
	# matrix
	my = y0 + rows * cell_h + pad
	mx = pad
	d.text((mx, my + 4), "IoU matrix", font=f_s, fill=cm.MUTED)
	for i in range(n):
		d.text((mx, my + col_h + i * mat_cell + mat_cell // 3), "%d %s" % (i + 1, names[i][:18]),
			font=f_l, fill=cm.INK)
		d.text((mx + lab_w + i * mat_cell + 6, my + 8), str(i + 1), font=f_l, fill=cm.INK)
		for j in range(n):
			v = res["iou"][i][j]
			bx, by = mx + lab_w + j * mat_cell, my + col_h + i * mat_cell
			fill = (60, 56, 76) if i == j else _heat(v, thr)
			d.rectangle((bx, by, bx + mat_cell - 2, by + mat_cell - 2), fill=fill)
			if i != j:
				txt = "%.2f" % v
				d.text((bx + 3, by + mat_cell // 3), txt[1:] if txt.startswith("0") else txt, font=f_l, fill=cm.INK)
	# flagged pairs
	oy = my + mat_h + pad
	if not pairs:
		d.text((pad, oy), "no pair at or above %.2f — every silhouette is its own family" % thr, font=f_s,
			fill=cm.GREEN)
	else:
		d.text((pad, oy), "same family (IoU ≥ %.2f): %d pair(s) — red A, blue B, purple both" % (thr, len(pairs)),
			font=f_s, fill=cm.RED)
		x = pad
		idx = {nm: k for k, nm in enumerate(names)}
		for p in pairs[:8]:
			a, b = norm[idx[p["a"]]], norm[idx[p["b"]]]
			rgb = np.full(a.shape + (3,), 255, dtype=np.uint8)
			rgb[a & ~b] = (220, 50, 50)
			rgb[b & ~a] = (50, 90, 220)
			rgb[a & b] = (120, 40, 140)
			o = Image.fromarray(rgb).resize((cw * 2, ch * 2), Image.NEAREST)
			if x + o.width > W - pad:
				break
			im.paste(o, (x, oy + 30))
			d.text((x, oy + 30 + o.height + 4), "%s × %s %.2f" % (p["a"][:10], p["b"][:10], p["iou"]), font=f_l,
				fill=cm.INK)
			x += o.width + pad
	cm.save_image(im, out)


def _cmd_masks(a) -> int:
	paths: list[Path] = []
	for s in a.inputs:
		paths.extend(cm.expand_items(s))
	if not paths:
		print("sil64: no mask PNGs found", file=sys.stderr)
		return 2
	names = cm.split_list(a.names) if a.names else None
	res = run_masks(paths, names, a.height, a.canvas, a.fit, a.same_family, a.mode, a.despeckle)
	for p in res["pairs_over"]:
		print("SAME FAMILY  %-24s %-24s IoU %.3f" % (p["a"], p["b"], p["iou"]))
	if res["empty"]:
		print("EMPTY masks: %s" % ", ".join(res["empty"]), file=sys.stderr)
	print("%d masks, %d pair(s) ≥ %.2f, canvas %dx%d" % (len(paths), len(res["pairs_over"]), a.same_family,
														*res["canvas"]))
	if a.out:
		board(res, a.out, a.title)
		print("wrote %s" % a.out)
	if a.cells_dir:
		cd = Path(a.cells_dir)
		cd.mkdir(parents=True, exist_ok=True)
		for nm, m in zip(res["names"], res["_norm"]):
			rgba = np.zeros(m.shape + (4,), dtype=np.uint8)
			rgba[m] = (0, 0, 0, 255)
			cm.save_image(Image.fromarray(rgba, "RGBA"), cd / ("%s.png" % nm))
	if a.json:
		cm.write_json(a.json, {k: v for k, v in res.items() if not k.startswith("_")})
	return 0


def _cmd_extract(a) -> int:
	rgba = cm.load_rgba(a.image)
	m = cm.mask_from_image(rgba, mode=a.mode, color=a.color, tol=a.tol)
	out = np.zeros(m.shape + (4,), dtype=np.uint8)
	out[m] = (0, 0, 0, 255)
	cm.save_image(Image.fromarray(out, "RGBA"), a.out)
	print("wrote %s (%d px)" % (a.out, int(m.sum())))
	return 0


def main(argv: list[str] | None = None) -> int:
	ap = argparse.ArgumentParser(prog="sil64.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	sub = ap.add_subparsers(dest="cmd", required=True)
	p = sub.add_parser("masks", help="normalise masks to 64 px, IoU matrix, board")
	p.add_argument("inputs", nargs="+")
	p.add_argument("--out")
	p.add_argument("--same-family", type=float, default=0.80)
	p.add_argument("--height", type=int, default=64)
	p.add_argument("--canvas", type=int, default=96)
	p.add_argument("--fit", default="height", choices=("height", "box"))
	p.add_argument("--names")
	p.add_argument("--mode", default="auto", choices=("auto", "alpha", "dark"))
	p.add_argument("--cells-dir")
	p.add_argument("--despeckle", type=float, default=0.002)
	p.add_argument("--title", default="")
	p.add_argument("--json")
	p.set_defaults(fn=_cmd_masks)
	p = sub.add_parser("extract", help="a black-on-transparent mask PNG from a render")
	p.add_argument("image")
	p.add_argument("--out", required=True)
	p.add_argument("--mode", default="alpha", choices=("auto", "alpha", "dark", "color"))
	p.add_argument("--color")
	p.add_argument("--tol", type=int, default=2)
	p.set_defaults(fn=_cmd_extract)
	a = ap.parse_args(argv)
	return a.fn(a)


if __name__ == "__main__":
	sys.exit(cm.run_cli(main, "sil64.py"))
