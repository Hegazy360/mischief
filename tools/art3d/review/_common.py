"""Shared helpers for the R3D review toolset (`tools/art3d/review/`): fonts, JSON, image loading, colours.

Only Pillow + numpy. Every tool of the set imports this module; nothing here is a CLI.
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Iterable

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
FONT_DIR = REPO / "game" / "ui" / "theme" / "fonts"
IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".webp")

# Board palette (dark theatre background, cream text) shared by every board the tools draw.
BG = (24, 20, 34)
PANEL = (38, 33, 52)
INK = (245, 238, 222)
MUTED = (170, 160, 185)
RED = (255, 72, 60)
AMBER = (255, 184, 48)
GREEN = (92, 200, 110)
BLUE = (92, 158, 255)

_font_cache: dict[tuple[int, bool], ImageFont.FreeTypeFont | ImageFont.ImageFont] = {}


def font(size: int, display: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
	"""The game's own UI fonts (Nunito Black, OFL; Lilita One with `display=True`) with a DejaVu fallback.

	The boards use Nunito everywhere: Lilita One lacks ≥ ≤ × → and labels carry them ("head ×1.2")."""
	key = (size, display)
	if key in _font_cache:
		return _font_cache[key]
	cands = [FONT_DIR / ("LilitaOne-Regular.ttf" if display else "Nunito-Black.ttf"),
			Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
			Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")]
	f: ImageFont.FreeTypeFont | ImageFont.ImageFont | None = None
	for p in cands:
		try:
			f = ImageFont.truetype(str(p), size)
			break
		except OSError:
			continue
	if f is None:
		f = ImageFont.load_default()
	_font_cache[key] = f
	return f


def text_size(draw: ImageDraw.ImageDraw, text: str, f) -> tuple[int, int]:
	box = draw.textbbox((0, 0), text, font=f)
	return box[2] - box[0], box[3] - box[1]


def pill(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, f, fg=INK, bg=(0, 0, 0), pad: int = 6,
		anchor_right: bool = False) -> tuple[int, int, int, int]:
	"""A rounded label; returns its box."""
	w, h = text_size(draw, text, f)
	x, y = xy
	if anchor_right:
		x -= w + 2 * pad
	box = (x, y, x + w + 2 * pad, y + h + 2 * pad + 4)
	draw.rounded_rectangle(box, radius=min(10, (h + 2 * pad) // 2), fill=bg)
	draw.text((x + pad, y + pad), text, font=f, fill=fg)
	return box


def write_json(path: str | os.PathLike, obj) -> None:
	p = Path(path)
	p.parent.mkdir(parents=True, exist_ok=True)
	p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def read_json(path: str | os.PathLike):
	return json.loads(Path(path).read_text(encoding="utf-8"))


def natural_key(s: str) -> list:
	return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", s)]


def list_images(path: str | os.PathLike) -> list[Path]:
	"""Image files of a directory, natural-sorted (frame_2 before frame_10)."""
	p = Path(path)
	files = [f for f in p.iterdir() if f.is_file() and f.suffix.lower() in IMAGE_EXTS]
	return sorted(files, key=lambda f: (natural_key(f.stem), f.suffix.lower()))


def expand_items(spec: str | Iterable[str], sep: str = ",") -> list[Path]:
	"""`a.png,b.png` or a directory (its images, natural-sorted) or a list mixing both."""
	parts = spec.split(sep) if isinstance(spec, str) else list(spec)
	out: list[Path] = []
	for s in parts:
		s = s.strip()
		if not s:
			continue
		p = Path(s)
		if p.is_dir():
			out.extend(list_images(p))
		else:
			out.append(p)
	return out


def split_list(spec: str | None, sep: str = ",") -> list[str]:
	if spec is None:
		return []
	return [s.strip() for s in spec.split(sep)]


def hex_to_rgb(s: str) -> tuple[int, int, int]:
	"""`#RRGGBB`, `RRGGBB`, `#RGB` or `r,g,b` → (r, g, b)."""
	t = s.strip()
	if "," in t:
		r, g, b = (int(v) for v in t.split(",")[:3])
		return r, g, b
	t = t.lstrip("#")
	if len(t) == 3:
		t = "".join(c * 2 for c in t)
	if len(t) != 6:
		raise ValueError("not a colour: %r (want #RRGGBB)" % s)
	return int(t[0:2], 16), int(t[2:4], 16), int(t[4:6], 16)


def rgb_to_hex(rgb) -> str:
	r, g, b = (int(round(float(v))) for v in rgb[:3])
	return "#%02X%02X%02X" % (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))


def load_rgba(path: str | os.PathLike) -> np.ndarray:
	"""(H, W, 4) uint8."""
	with Image.open(path) as im:
		return np.asarray(im.convert("RGBA")).copy()


def has_real_alpha(rgba: np.ndarray) -> bool:
	return bool((rgba[..., 3] < 250).any())


def mask_from_image(rgba: np.ndarray, mode: str = "auto", color: str | None = None, tol: int = 2) -> np.ndarray:
	"""A boolean silhouette from a mask PNG.

	mode `auto`: a colour given → that exact ID colour (± tol per channel); else the alpha channel when the PNG has
	real transparency (alpha ≥ 128 is inside: a black-on-transparent mask or a cut-out render); else the dark pixels
	(luma < 128: a black shape on white). `alpha` / `dark` / `color` force one reading.
	"""
	if mode not in ("auto", "alpha", "dark", "color"):
		raise ValueError("mask mode %r (want auto, alpha, dark or color)" % mode)
	if mode == "color" and color is None:
		raise ValueError("mask mode 'color' needs a colour (--mask-color / --color)")
	if color is not None and mode in ("auto", "color"):
		c = np.array(hex_to_rgb(color), dtype=np.int16)
		m = np.abs(rgba[..., :3].astype(np.int16) - c).max(axis=-1) <= tol
		if has_real_alpha(rgba):
			m &= rgba[..., 3] >= 128
		return m
	if mode == "alpha" or (mode == "auto" and has_real_alpha(rgba)):
		return rgba[..., 3] >= 128
	luma = rgba[..., 0].astype(np.float32) * 0.299 + rgba[..., 1] * 0.587 + rgba[..., 2] * 0.114
	return luma < 128


def erode(mask: np.ndarray, n: int = 1) -> np.ndarray:
	"""Binary erosion with a 3×3 square, n times (edges of the frame count as inside)."""
	m = mask.copy()
	for _ in range(max(0, n)):
		p = np.pad(m, 1, mode="edge")
		out = p[1:-1, 1:-1].copy()
		for dy in (0, 1, 2):
			for dx in (0, 1, 2):
				out &= p[dy:dy + m.shape[0], dx:dx + m.shape[1]]
		m = out
	return m


def components(mask: np.ndarray) -> tuple[np.ndarray, list[int]]:
	"""4-connected components of a boolean mask: (labels int32, −1 outside; sizes per label)."""
	from collections import deque
	h, w = mask.shape
	lab = np.full((h, w), -1, dtype=np.int32)
	flat_m = mask.reshape(-1)
	flat_l = lab.reshape(-1)
	sizes: list[int] = []
	for start in np.flatnonzero(flat_m):
		if flat_l[start] >= 0:
			continue
		k = len(sizes)
		flat_l[start] = k
		q = deque([int(start)])
		n = 0
		while q:
			i = q.popleft()
			n += 1
			y, x = divmod(i, w)
			for j, ok in ((i - w, y > 0), (i + w, y < h - 1), (i - 1, x > 0), (i + 1, x < w - 1)):
				if ok and flat_m[j] and flat_l[j] < 0:
					flat_l[j] = k
					q.append(j)
		sizes.append(n)
	return lab, sizes


def despeckle(mask: np.ndarray, min_share: float = 0.002, min_px: int = 0) -> np.ndarray:
	"""Drop connected specks smaller than `min_share` of the mask's pixels (and than `min_px`): stray ID pixels,
	particles and flood-fill leftovers must not stretch a silhouette's bounds."""
	total = int(mask.sum())
	if total == 0 or (min_share <= 0 and min_px <= 0):
		return mask
	b = bbox(mask)
	x0, y0, x1, y1 = b
	crop = mask[y0:y1, x0:x1]
	lab, sizes = components(crop)
	limit = max(min_px, min_share * total)
	keep = np.array([sz >= limit for sz in sizes] + [False])
	out = np.zeros_like(mask)
	out[y0:y1, x0:x1] = keep[lab]
	return out


def bbox(mask: np.ndarray) -> tuple[int, int, int, int] | None:
	"""(x0, y0, x1, y1) exclusive, or None for an empty mask."""
	ys = np.flatnonzero(mask.any(axis=1))
	xs = np.flatnonzero(mask.any(axis=0))
	if ys.size == 0:
		return None
	return int(xs[0]), int(ys[0]), int(xs[-1]) + 1, int(ys[-1]) + 1


def fit_image(im: Image.Image, w: int, h: int, bg=BG, upscale: bool = True) -> Image.Image:
	"""`im` letterboxed into a w×h canvas (aspect kept, centred)."""
	im = im.convert("RGBA")
	s = min(w / im.width, h / im.height)
	if not upscale:
		s = min(s, 1.0)
	nw, nh = max(1, round(im.width * s)), max(1, round(im.height * s))
	r = im.resize((nw, nh), Image.LANCZOS) if (nw, nh) != im.size else im
	canvas = Image.new("RGBA", (w, h), bg + (255,))
	canvas.alpha_composite(r, ((w - nw) // 2, (h - nh) // 2))
	return canvas.convert("RGB")


def save_image(im: Image.Image, path: str | os.PathLike, quality: int = 85) -> None:
	"""PNG or JPEG by extension, never carrying metadata (packets must stay opaque)."""
	p = Path(path)
	p.parent.mkdir(parents=True, exist_ok=True)
	if p.suffix.lower() in (".jpg", ".jpeg"):
		im.convert("RGB").save(p, "JPEG", quality=quality, optimize=True)
	else:
		im.save(p, "PNG", optimize=True)


def rounded(v: float, nd: int = 2) -> float:
	return float(round(float(v), nd))


def run_cli(main, prog: str) -> int:
	"""Run a tool's `main()`: bad input (ValueError, a missing file) prints one line and exits 2, never a traceback."""
	try:
		return int(main() or 0)
	except (ValueError, FileNotFoundError, KeyError) as e:
		import sys
		print("%s: %s" % (prog, e), file=sys.stderr)
		return 2
