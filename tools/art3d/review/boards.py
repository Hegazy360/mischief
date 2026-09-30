#!/usr/bin/env python3
"""Labelled boards: grids and before/after pairs at 1200×540 per cell (the r3d-ref2d 2D frames against the 3D ones,
the cast's hybrid_vs_ab.png, the sets' before_after.png, …).

usage:
  boards.py grid <out.png> --cells=<a.png,b.png,…|dir> [--labels=A,B,…] [--cols=C] [--cell=1200x540]
                 [--title=…] [--sep=,] [--scale=1.0] [--notes=…,…]
  boards.py pair <out.png> <before.png> <after.png> [--labels="2D,3D"] [--cell=1200x540] [--title=…] [--stack]
                 [--scale=1.0]

Every cell keeps its image's aspect (letterboxed on the board's dark ground, never stretched) with its label in a bar
under it (and an optional second line from --notes). --cols defaults to the cell count up to 3, else ⌈√n⌉. --sep
changes the label / note separator when a label needs a comma (cells are always comma-separated). --scale shrinks the whole board (e.g. 0.5 for a small index
thumbnail). Output PNG (or JPEG q90 by extension).
Importable: `grid(cells, labels, out, …)`, `pair(before, after, out, …)`.
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _common as cm  # noqa: E402


def _parse_cell(s: str) -> tuple[int, int]:
	w, h = s.lower().split("x")
	return int(w), int(h)


def grid(cells: list[Path | Image.Image], labels: list[str] | None, out, cols: int | None = None,
		cell: tuple[int, int] = (1200, 540), title: str = "", notes: list[str] | None = None,
		scale: float = 1.0) -> Image.Image:
	"""A labelled grid; returns the board image (also written to `out` when given)."""
	n = len(cells)
	if n == 0:
		raise ValueError("boards: no cells")
	labels = list(labels or [])
	labels += [""] * (n - len(labels))
	notes = list(notes or [])
	notes += [""] * (n - len(notes))
	if cols is None:
		cols = n if n <= 3 else math.ceil(math.sqrt(n))
	rows = math.ceil(n / cols)
	cw, ch = cell
	pad = 16
	lab_h = 52 + (30 if any(notes) else 0)
	head = 64 if title else 0
	W = cols * cw + (cols + 1) * pad
	H = head + rows * (ch + lab_h) + (rows + 1) * pad
	board = Image.new("RGB", (W, H), cm.BG)
	d = ImageDraw.Draw(board)
	f_title, f_lab, f_note = cm.font(40), cm.font(32), cm.font(22)
	if title:
		d.text((pad, 12), title, font=f_title, fill=cm.INK)
	for k, c in enumerate(cells):
		r, cc = divmod(k, cols)
		x = pad + cc * (cw + pad)
		y = head + pad + r * (ch + lab_h + pad)
		im = c if isinstance(c, Image.Image) else Image.open(c)
		board.paste(cm.fit_image(im, cw, ch, bg=(12, 10, 18)), (x, y))
		d.rectangle((x, y + ch, x + cw - 1, y + ch + lab_h - 1), fill=cm.PANEL)
		d.text((x + 14, y + ch + 8), labels[k], font=f_lab, fill=cm.INK)
		if notes[k]:
			d.text((x + 14, y + ch + 50), notes[k], font=f_note, fill=cm.MUTED)
	if scale != 1.0:
		board = board.resize((max(1, round(W * scale)), max(1, round(H * scale))), Image.LANCZOS)
	if out:
		cm.save_image(board, out, quality=90)
	return board


def pair(before, after, out, labels: tuple[str, str] = ("before", "after"), cell: tuple[int, int] = (1200, 540),
		title: str = "", stack: bool = False, scale: float = 1.0) -> Image.Image:
	"""Before | after (or stacked), same cell size, labelled."""
	return grid([Path(before), Path(after)], list(labels), out, cols=1 if stack else 2, cell=cell, title=title,
				scale=scale)


def main(argv: list[str] | None = None) -> int:
	ap = argparse.ArgumentParser(prog="boards.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	sub = ap.add_subparsers(dest="cmd", required=True)
	p = sub.add_parser("grid")
	p.add_argument("out")
	p.add_argument("--cells", required=True)
	p.add_argument("--labels")
	p.add_argument("--notes")
	p.add_argument("--cols", type=int)
	p.add_argument("--cell", default="1200x540")
	p.add_argument("--title", default="")
	p.add_argument("--sep", default=",")
	p.add_argument("--scale", type=float, default=1.0)
	p = sub.add_parser("pair")
	p.add_argument("out")
	p.add_argument("before")
	p.add_argument("after")
	p.add_argument("--labels", default="before,after")
	p.add_argument("--cell", default="1200x540")
	p.add_argument("--title", default="")
	p.add_argument("--sep", default=",")
	p.add_argument("--stack", action="store_true")
	p.add_argument("--scale", type=float, default=1.0)
	a = ap.parse_args(argv)
	if a.cmd == "grid":
		cells = cm.expand_items(a.cells)
		missing = [str(c) for c in cells if not c.exists()]
		if missing:
			print("boards: missing %s" % ", ".join(missing), file=sys.stderr)
			return 2
		labels = cm.split_list(a.labels, a.sep) if a.labels is not None else [c.stem for c in cells]
		notes = cm.split_list(a.notes, a.sep) if a.notes else None
		b = grid(cells, labels, a.out, a.cols, _parse_cell(a.cell), a.title, notes, a.scale)
	else:
		labels = cm.split_list(a.labels, a.sep)
		if len(labels) != 2:
			print("boards: pair needs two labels", file=sys.stderr)
			return 2
		for pth in (a.before, a.after):
			if not Path(pth).exists():
				print("boards: missing %s" % pth, file=sys.stderr)
				return 2
		b = pair(a.before, a.after, a.out, (labels[0], labels[1]), _parse_cell(a.cell), a.title, a.stack, a.scale)
	print("wrote %s (%dx%d)" % (a.out, b.width, b.height))
	return 0


if __name__ == "__main__":
	sys.exit(cm.run_cli(main, "boards.py"))
