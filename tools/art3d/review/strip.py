#!/usr/bin/env python3
"""Numbered frame strips at phone scale — what reviewers read (Stage-2 ruling L10; replaces raw frame folders, R12).

usage:
  strip.py <frame dir> <out.jpg> [--every=N] [--cols=C] [--scale=1.0] [--width=2400] [--marks=<marks.json>]
           [--marks-offset=F] [--label-frames] [--frame-step=K] [--frame-offset=O] [--from=F0] [--to=F1]
           [--per-page=K] [--max-mb=4] [--quality=85] [--title=…] [--no-mark-text] [--json=/abs.json]

Frames: every PNG/JPEG of the directory, natural-sorted (Movie Maker `f00000123.png`, DevShot `frame_007.png`, …).
A frame's number is the last digit group of its file name × --frame-step + --frame-offset (a DevShot sequence shot
with `--every=3 --seq-from=30` → `--frame-step=3 --frame-offset=30`), so marks and labels use real frame numbers.
--every=N keeps every N-th file; marked frames are always kept. --from / --to limit by frame number.

Cells: frame × --scale (default 1.0 = 1200×540 for a phone-scale capture), --cols per row (default: as many as fit
--width, 2400 px), each numbered in its top-left corner — the cell index (#1, #2 …) or, with --label-frames, the
frame number (f 123). Marks outline a cell: `{"94": "accent", "74": "anticipation"}` (also `{"marks": {…}}`, a list
of `{"frame", "kind"}`, or a clip sidecar v2 — its `beats` starts and `mark` events; add --marks-offset=F when the
clip starts at frame F of the capture). Colours: accent red, anticipation blue, contact orange, hold green,
settle purple, key amber, anything else grey.

Output: JPEG q85 (PNG if the name ends in .png), ≤ --max-mb (quality, then cell scale, step down until it fits;
every reduction is printed); `--per-page=K` splits into <out>, <out>_2, <out>_3 … (K cells each) — use it for
reviewer packets (an image reader shrinks a tall strip). JSON: {"pages": […], "cells": [{"index", "frame", "file",
"mark"}], "cell_size": [w, h], "cols", "quality", "bytes": […]}.
"""
from __future__ import annotations

import argparse
import io
import math
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _common as cm  # noqa: E402

MARK_COLORS = {
	"accent": (255, 48, 48), "anticipation": (70, 140, 255), "contact": (255, 140, 30), "hold": (60, 200, 90),
	"settle": (170, 90, 230), "key": (255, 200, 40), "release": (60, 210, 210),
}
JPEG_MAX_DIM = 65000


def frame_number(path: Path, step: int = 1, offset: int = 0) -> int | None:
	nums = re.findall(r"\d+", path.stem)
	if not nums:
		return None
	return int(nums[-1]) * step + offset


def load_marks(path_or_obj, offset: int = 0) -> dict[int, str]:
	"""Frame → kind, from a marks JSON (several shapes) or a clip sidecar v2."""
	doc = cm.read_json(path_or_obj) if isinstance(path_or_obj, (str, Path)) else path_or_obj
	out: dict[int, str] = {}
	if isinstance(doc, dict) and doc.get("format") == "anim3d" or (isinstance(doc, dict) and "beats" in doc):
		for kind, span in (doc.get("beats") or {}).items():
			if isinstance(span, list) and span:
				out.setdefault(int(span[0]) + offset, kind)
		for ev in doc.get("events") or []:
			if ev.get("type") == "mark":
				out[int(ev["f"]) + offset] = str(ev.get("name", "key"))
		return out
	if isinstance(doc, dict) and "marks" in doc:
		doc = doc["marks"]
	if isinstance(doc, list):
		for m in doc:
			out[int(m["frame"]) + offset] = str(m.get("kind", "key"))
	elif isinstance(doc, dict):
		for k, v in doc.items():
			out[int(k) + offset] = str(v)
	return out


def select_frames(frame_dir: Path, every: int = 1, marks: dict[int, str] | None = None, step: int = 1,
				offset: int = 0, f_from: int | None = None, f_to: int | None = None) -> list[tuple[Path, int]]:
	files = cm.list_images(frame_dir)
	marks = marks or {}
	rows: list[tuple[Path, int]] = []
	for i, f in enumerate(files):
		n = frame_number(f, step, offset)
		fn = n if n is not None else i
		if f_from is not None and fn < f_from:
			continue
		if f_to is not None and fn > f_to:
			continue
		rows.append((f, fn))
	keep = []
	for k, (f, fn) in enumerate(rows):
		if k % max(1, every) == 0 or fn in marks:
			keep.append((f, fn))
	return keep


def _render(frames: list[tuple[Path, int]], marks: dict[int, str], cols: int, cell: tuple[int, int],
			label_frames: bool, title: str, mark_text: bool, start_index: int = 1) -> Image.Image:
	cw, ch = cell
	gap = 6
	head = 48 if title else 0
	rows = math.ceil(len(frames) / cols)
	W = cols * cw + (cols + 1) * gap
	H = head + rows * ch + (rows + 1) * gap
	im = Image.new("RGB", (W, H), cm.BG)
	d = ImageDraw.Draw(im)
	fsz = max(14, min(30, ch // 14))
	f_lab, f_mark = cm.font(fsz), cm.font(max(12, fsz - 6))
	if title:
		d.text((gap + 4, 10), title, font=cm.font(28), fill=cm.INK)
	for k, (path, fn) in enumerate(frames):
		r, c = divmod(k, cols)
		x, y = gap + c * (cw + gap), head + gap + r * (ch + gap)
		with Image.open(path) as src:
			fr = src.convert("RGB")
			if fr.size != (cw, ch):
				if abs(fr.width * ch - fr.height * cw) <= max(fr.width, fr.height):
					fr = fr.resize((cw, ch), Image.BILINEAR, reducing_gap=2.0)
				else:
					fr = cm.fit_image(fr, cw, ch)
		im.paste(fr, (x, y))
		label = ("f %d" % fn) if label_frames else ("#%d" % (start_index + k))
		cm.pill(d, (x + 6, y + 6), label, f_lab, bg=(0, 0, 0))
		kind = marks.get(fn)
		if kind:
			col = MARK_COLORS.get(kind, (200, 200, 200))
			t = max(4, ch // 90)
			d.rectangle((x - 2, y - 2, x + cw + 1, y + ch + 1), outline=col, width=t)
			if mark_text:
				cm.pill(d, (x + cw - 6, y + 6), kind, f_mark, fg=(0, 0, 0), bg=col, anchor_right=True)
	return im


def _encode(im: Image.Image, fmt: str, quality: int) -> bytes:
	buf = io.BytesIO()
	if fmt == "JPEG":
		im.save(buf, "JPEG", quality=quality, optimize=True)
	else:
		im.save(buf, "PNG", optimize=True)
	return buf.getvalue()


def _page_px(n_cells: int, cols: int, cell: tuple[int, int], title: str) -> int:
	rows = math.ceil(n_cells / cols)
	return (cols * cell[0] + (cols + 1) * 6) * ((48 if title else 0) + rows * cell[1] + (rows + 1) * 6)


def _predict(frames, mk, cols, cell, label_frames, mark_text, pages, title, quality, limit, max_mb, log):
	"""Pick the JPEG quality / cell size that fits `limit` from a sample row pair (JPEG bytes scale with pixels), so
	a long strip renders once instead of shrinking step by step."""
	sample = frames[:min(len(frames), 2 * cols)]
	im = _render(sample, mk, cols, cell, label_frames, "", mark_text)
	px_s = im.width * im.height
	worst = max(_page_px(len(pg), cols, cell, title) for pg in pages)
	qs = [q for q in (quality, quality - 10, quality - 20) if q >= 65] or [quality]
	bpp = {}
	for q in qs:
		bpp[q] = len(_encode(im, "JPEG", q)) / px_s
		if bpp[q] * worst * 1.08 <= limit:
			if q != quality:
				log("strip: over %.1f MB at q%d, JPEG quality → %d" % (max_mb, quality, q), file=sys.stderr)
			return q, cell
	q = qs[-1]
	s = math.sqrt(limit * 0.9 / (bpp[q] * worst))
	new = (max(1, int(cell[0] * s)), max(1, int(cell[1] * s)))
	log("strip: over %.1f MB, JPEG quality → %d, cells → %dx%d" % (max_mb, q, new[0], new[1]), file=sys.stderr)
	return q, new


def make_strip(frame_dir, out, every: int = 1, cols: int | None = None, scale: float = 1.0, width: int = 2400,
			marks=None, marks_offset: int = 0, label_frames: bool = False, frame_step: int = 1,
			frame_offset: int = 0, f_from: int | None = None, f_to: int | None = None, per_page: int = 0,
			max_mb: float = 4.0, quality: int = 85, title: str = "", mark_text: bool = True,
			log=print) -> dict:
	"""Build the strip page(s); returns the JSON dict."""
	frame_dir, out = Path(frame_dir), Path(out)
	mk = load_marks(marks, marks_offset) if marks else {}
	frames = select_frames(frame_dir, every, mk, frame_step, frame_offset, f_from, f_to)
	if not frames:
		raise SystemExit("strip: no frames in %s" % frame_dir)
	with Image.open(frames[0][0]) as f0:
		fw, fh = f0.size
	cw, ch = max(1, round(fw * scale)), max(1, round(fh * scale))
	if cols is None:
		cols = max(1, width // cw)
	if cols * cw > width:
		s = width / (cols * cw)
		cw, ch = max(1, int(cw * s)), max(1, int(ch * s))
	fmt = "PNG" if out.suffix.lower() == ".png" else "JPEG"
	per = per_page if per_page > 0 else len(frames)
	max_rows = max(1, (JPEG_MAX_DIM - 60) // (ch + 6))
	per = min(per, max_rows * cols)
	pages = [frames[i:i + per] for i in range(0, len(frames), per)]
	names = [out] + [out.with_name("%s_%d%s" % (out.stem, k + 1, out.suffix)) for k in range(1, len(pages))]
	q, cell = quality, (cw, ch)
	limit = int(max_mb * 1024 * 1024)
	if fmt == "JPEG":
		q, cell = _predict(frames, mk, cols, cell, label_frames, mark_text, pages, title, quality, limit, max_mb, log)
	blobs: list[bytes] = []
	while True:
		blobs = []
		for k, pg in enumerate(pages):
			t = title + ("  (%d/%d)" % (k + 1, len(pages)) if title and len(pages) > 1 else "")
			im = _render(pg, mk, cols, cell, label_frames, t, mark_text, start_index=1 + k * per)
			blobs.append(_encode(im, fmt, q))
		if max(len(b) for b in blobs) <= limit or cell[0] < 160:
			break
		if fmt == "JPEG" and q > 65:
			q -= 10
			log("strip: over %.1f MB, JPEG quality → %d" % (max_mb, q), file=sys.stderr)
		else:
			f = min(0.95, math.sqrt(limit * 0.9 / max(len(b) for b in blobs)))
			cell = (max(1, int(cell[0] * f)), max(1, int(cell[1] * f)))
			log("strip: over %.1f MB, cells → %dx%d" % (max_mb, cell[0], cell[1]), file=sys.stderr)
	out.parent.mkdir(parents=True, exist_ok=True)
	for p, b in zip(names, blobs):
		p.write_bytes(b)
	cells = []
	for k, (f, fn) in enumerate(frames):
		cells.append({"index": k + 1, "frame": fn, "file": f.name, "mark": mk.get(fn)})
	return {"pages": [str(p) for p in names], "page_cells": [len(pg) for pg in pages], "cells": cells,
			"cell_size": list(cell), "cols": cols,
			"quality": q if fmt == "JPEG" else None, "bytes": [len(b) for b in blobs], "every": every,
			"marks": {str(k): v for k, v in sorted(mk.items())}, "frame_dir": str(frame_dir.resolve())}


def main(argv: list[str] | None = None) -> int:
	ap = argparse.ArgumentParser(prog="strip.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("frame_dir")
	ap.add_argument("out")
	ap.add_argument("--every", type=int, default=1)
	ap.add_argument("--cols", type=int)
	ap.add_argument("--scale", type=float, default=1.0)
	ap.add_argument("--width", type=int, default=2400)
	ap.add_argument("--marks")
	ap.add_argument("--marks-offset", type=int, default=0)
	ap.add_argument("--label-frames", action="store_true")
	ap.add_argument("--frame-step", type=int, default=1)
	ap.add_argument("--frame-offset", type=int, default=0)
	ap.add_argument("--from", dest="f_from", type=int)
	ap.add_argument("--to", dest="f_to", type=int)
	ap.add_argument("--per-page", type=int, default=0)
	ap.add_argument("--max-mb", type=float, default=4.0)
	ap.add_argument("--quality", type=int, default=85)
	ap.add_argument("--title", default="")
	ap.add_argument("--no-mark-text", action="store_true")
	ap.add_argument("--json")
	a = ap.parse_args(argv)
	res = make_strip(a.frame_dir, a.out, a.every, a.cols, a.scale, a.width, a.marks, a.marks_offset, a.label_frames,
					a.frame_step, a.frame_offset, a.f_from, a.f_to, a.per_page, a.max_mb, a.quality, a.title,
					not a.no_mark_text)
	for p, b, n in zip(res["pages"], res["bytes"], res["page_cells"]):
		print("wrote %s (%.2f MB, %d cells of %dx%d)" % (p, b / 1048576, n, *res["cell_size"]))
	rows = math.ceil(max(res["page_cells"]) / res["cols"])
	if rows * res["cell_size"][1] > 3000 and a.per_page == 0:
		print("strip: a %d-row page — for reviewers use --per-page=12 --cols=4 (an image reader shrinks tall strips)"
			% rows, file=sys.stderr)
	if a.json:
		cm.write_json(a.json, res)
	return 0


if __name__ == "__main__":
	sys.exit(cm.run_cli(main, "strip.py"))
