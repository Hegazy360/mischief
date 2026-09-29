"""Tiny SVG kit for the Bellows generators (ported and extended from Booby's svgk.py).

Everything is authored in *local* coordinates with the part's joint (pivot) at (0, 0), y down.
A `Part` collects SVG element strings plus a bounding box; `fit_canvas` turns a set of variant
parts into same-size canvases that share one pivot (so texture swaps never jump).

Only presentation attributes are emitted; elements are limited to
path / rect / circle / ellipse / line / polyline / polygon / g (GDD §9.1).
"""
import math
import os

INK = "#1B2340"
SW = 6.0      # character outline
DET = 3.5     # inner detail line
MARGIN = 3    # empty canvas margin (px) beyond the outline


def f(v):
	"""Format a number with at most one decimal."""
	s = "%.1f" % v
	if s.endswith(".0"):
		s = s[:-2]
	if s == "-0":
		s = "0"
	return s


def _attrs(kw):
	out = []
	for k, v in kw.items():
		if v is None:
			continue
		k = k.rstrip("_").replace("_", "-")
		if isinstance(v, float) or isinstance(v, int) and not isinstance(v, bool):
			v = f(float(v))
		out.append('%s="%s"' % (k, v))
	return " ".join(out)


def stroke_kw(sw, color=INK):
	return dict(stroke=color, stroke_width=sw, stroke_linejoin="round", stroke_linecap="round")


def _el(tag, base, fill, sw, stroke, kw):
	a = dict(base)
	a["fill"] = fill
	if sw:
		a.update(stroke_kw(sw, stroke or INK))
	elif stroke:
		a["stroke"] = stroke
	a.update(kw)
	return "<%s %s/>" % (tag, _attrs(a))


def path(d, fill="none", sw=None, stroke=None, **kw):
	return _el("path", dict(d=d), fill, sw, stroke, kw)


def circle(cx, cy, r, fill="none", sw=None, stroke=None, **kw):
	return _el("circle", dict(cx=cx, cy=cy, r=r), fill, sw, stroke, kw)


def ellipse(cx, cy, rx, ry, fill="none", sw=None, stroke=None, **kw):
	return _el("ellipse", dict(cx=cx, cy=cy, rx=rx, ry=ry), fill, sw, stroke, kw)


def rect(x, y, w, h, rx=0, fill="none", sw=None, stroke=None, **kw):
	base = dict(x=x, y=y, width=w, height=h)
	if rx:
		base["rx"] = rx
	return _el("rect", base, fill, sw, stroke, kw)


def line(x1, y1, x2, y2, sw=DET, stroke=INK, **kw):
	a = dict(x1=x1, y1=y1, x2=x2, y2=y2)
	a.update(stroke_kw(sw, stroke))
	a.update(kw)
	return "<line %s/>" % _attrs(a)


def g(items, transform=None, **kw):
	a = {}
	if transform:
		a["transform"] = transform
	a.update(kw)
	at = _attrs(a)
	return "<g%s>%s</g>" % ((" " + at) if at else "", "".join(items))


def svg_doc(w, h, items):
	return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (w, h, w, h)
			+ "".join(items) + "</svg>\n")


def write(p, s):
	os.makedirs(os.path.dirname(p), exist_ok=True)
	with open(p, "w") as fh:
		fh.write(s)
	return p


# --- path building -------------------------------------------------------------------------

def pts_path(pts, close=True):
	s = "M" + " L".join("%s %s" % (f(x), f(y)) for x, y in pts)
	return s + (" Z" if close else "")


def smooth_closed(pts, t=0.5):
	"""Catmull-Rom -> cubic Bezier closed path through the points."""
	n = len(pts)
	d = "M%s %s" % (f(pts[0][0]), f(pts[0][1]))
	for i in range(n):
		p0 = pts[(i - 1) % n]
		p1 = pts[i]
		p2 = pts[(i + 1) % n]
		p3 = pts[(i + 2) % n]
		c1 = (p1[0] + (p2[0] - p0[0]) * t / 3, p1[1] + (p2[1] - p0[1]) * t / 3)
		c2 = (p2[0] - (p3[0] - p1[0]) * t / 3, p2[1] - (p3[1] - p1[1]) * t / 3)
		d += " C%s %s %s %s %s %s" % (f(c1[0]), f(c1[1]), f(c2[0]), f(c2[1]), f(p2[0]), f(p2[1]))
	return d + " Z"


def smooth_open(pts, t=0.5):
	n = len(pts)
	d = "M%s %s" % (f(pts[0][0]), f(pts[0][1]))
	for i in range(n - 1):
		p0 = pts[max(i - 1, 0)]
		p1 = pts[i]
		p2 = pts[i + 1]
		p3 = pts[min(i + 2, n - 1)]
		c1 = (p1[0] + (p2[0] - p0[0]) * t / 3, p1[1] + (p2[1] - p0[1]) * t / 3)
		c2 = (p2[0] - (p3[0] - p1[0]) * t / 3, p2[1] - (p3[1] - p1[1]) * t / 3)
		d += " C%s %s %s %s %s %s" % (f(c1[0]), f(c1[1]), f(c2[0]), f(c2[1]), f(p2[0]), f(p2[1]))
	return d


def qcurve(p0, c, p1):
	return "M%s %s Q%s %s %s %s" % (f(p0[0]), f(p0[1]), f(c[0]), f(c[1]), f(p1[0]), f(p1[1]))


def rot(p, ang, c=(0, 0)):
	a = math.radians(ang)
	x, y = p[0] - c[0], p[1] - c[1]
	return (c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a))


def xform(pts, dx=0, dy=0, sx=1, sy=1, ang=0, c=(0, 0)):
	out = []
	for p in pts:
		q = (c[0] + (p[0] - c[0]) * sx, c[1] + (p[1] - c[1]) * sy)
		q = rot(q, ang, c)
		out.append((q[0] + dx, q[1] + dy))
	return out


def ellipse_pts(cx, cy, rx, ry, n=16, a0=0.0, wobble=0.0, seed=1):
	out = []
	for i in range(n):
		a = a0 + 2 * math.pi * i / n
		w = 1.0 + wobble * math.sin(i * 2.7 + seed * 1.3)
		out.append((cx + rx * math.cos(a) * w, cy + ry * math.sin(a) * w))
	return out


def cloud_pts(cx, cy, rx, ry, bumps, depth, n_per=6, a0=-math.pi / 2, jitter=0.0, seed=3):
	"""Scalloped 'cloud' outline: an ellipse whose radius bulges into `bumps` round lobes."""
	pts = []
	total = bumps * n_per
	for i in range(total):
		a = a0 + 2 * math.pi * i / total
		ph = (i % n_per) / n_per
		lobe = math.sin(math.pi * ph)            # 0 at the notches, 1 at the lobe tip
		j = 1.0 + jitter * math.sin((i // n_per) * 2.3 + seed)
		r = 1.0 - depth + depth * (lobe ** 0.6) * j
		pts.append((cx + rx * r * math.cos(a), cy + ry * r * math.sin(a)))
	return pts


def spiky_pts(cx, cy, rx, ry, spikes, inner, a0=-math.pi / 2, jitter=0.0, seed=5):
	pts = []
	for i in range(spikes * 2):
		a = a0 + math.pi * i / spikes
		r = 1.0 if i % 2 == 0 else inner
		if i % 2 == 0:
			r *= 1.0 + jitter * math.sin(i * 1.7 + seed)
		pts.append((cx + rx * r * math.cos(a), cy + ry * r * math.sin(a)))
	return pts


def bbox_pts(pts, pad=0.0):
	xs = [p[0] for p in pts]
	ys = [p[1] for p in pts]
	return (min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad)


def union(*bbs):
	bbs = [b for b in bbs if b]
	return (min(b[0] for b in bbs), min(b[1] for b in bbs), max(b[2] for b in bbs), max(b[3] for b in bbs))


# --- shading ---------------------------------------------------------------------------------

def shaded(d, base, shade, c, s=0.86, sw=SW, hl=None):
	"""Shade-first inset: silhouette in `shade`, a smaller lit copy (scaled about `c`, which sits up-left
	of the centre so the shade shows on the lower-right), then the ink outline on top.
	`hl` = (cx, cy, rx, ry, ang) highlight capsule."""
	tr = "translate(%s %s) scale(%s) translate(%s %s)" % (f(c[0]), f(c[1]), s, f(-c[0]), f(-c[1]))
	out = [path(d, fill=shade), path(d, fill=base, transform=tr)]
	if hl:
		out.append(highlight(*hl))
	if sw:
		out.append(path(d, sw=sw))
	return out


def highlight(cx, cy, rx, ry, ang=-30, op=0.55):
	return ellipse(cx, cy, rx, ry, fill="#FFFFFF", fill_opacity=op,
				   transform="rotate(%s %s %s)" % (f(ang), f(cx), f(cy)))


# --- parts -----------------------------------------------------------------------------------

class Part:
	"""SVG content in local coords (pivot at 0,0) + its ink-inclusive bounding box."""

	def __init__(self, name, items, bbox):
		self.name = name
		self.items = list(items)
		self.bbox = bbox

	def canvas(self, bbox=None):
		"""(w, h, pivot) of a canvas holding `bbox` (default own) + margin, pivot rounded to 0.5 px."""
		bb = bbox or self.bbox
		minx = math.floor(bb[0]) - MARGIN
		miny = math.floor(bb[1]) - MARGIN
		maxx = math.ceil(bb[2]) + MARGIN
		maxy = math.ceil(bb[3]) + MARGIN
		return int(maxx - minx), int(maxy - miny), (float(-minx), float(-miny))

	def svg(self, canvas):
		w, h, piv = canvas
		return svg_doc(w, h, [g(self.items, transform="translate(%s %s)" % (f(piv[0]), f(piv[1])))])


def shared_canvas(parts, extra=None):
	"""One canvas (w, h, pivot) that fits every variant in `parts` (measured) (+ optional extra bbox)."""
	bb = union(*([measure(p) for p in parts] + ([extra] if extra else [])))
	return parts[0].canvas(bb)


def centered_canvas(parts, pad=0):
	"""Canvas centred on the pivot (pivot = canvas centre) that fits every variant (measured)."""
	bb = union(*[measure(p) for p in parts])
	hw = max(abs(bb[0]), abs(bb[2])) + MARGIN + pad
	hh = max(abs(bb[1]), abs(bb[3])) + MARGIN + pad
	hw = math.ceil(hw)
	hh = math.ceil(hh)
	return int(2 * hw), int(2 * hh), (float(hw), float(hh))


# --- sampling / clipping (no clipPath allowed, so detail lines are clipped in Python) ---------

def sample_closed(pts, t=0.5, n=8):
	"""Dense polygon of the Catmull-Rom closed curve used by `smooth_closed`."""
	out = []
	m = len(pts)
	for i in range(m):
		p0 = pts[(i - 1) % m]
		p1 = pts[i]
		p2 = pts[(i + 1) % m]
		p3 = pts[(i + 2) % m]
		c1 = (p1[0] + (p2[0] - p0[0]) * t / 3, p1[1] + (p2[1] - p0[1]) * t / 3)
		c2 = (p2[0] - (p3[0] - p1[0]) * t / 3, p2[1] - (p3[1] - p1[1]) * t / 3)
		for k in range(n):
			u = k / n
			a = (1 - u) ** 3
			b = 3 * (1 - u) ** 2 * u
			c = 3 * (1 - u) * u * u
			d = u ** 3
			out.append((a * p1[0] + b * c1[0] + c * c2[0] + d * p2[0], a * p1[1] + b * c1[1] + c * c2[1] + d * p2[1]))
	return out


def clip_segment(poly, p0, p1, inset=0.0):
	"""Parts of segment p0-p1 inside polygon `poly` (even-odd), each shortened by `inset` px at both ends."""
	ts = []
	n = len(poly)
	dx, dy = p1[0] - p0[0], p1[1] - p0[1]
	for i in range(n):
		a = poly[i]
		b = poly[(i + 1) % n]
		ex, ey = b[0] - a[0], b[1] - a[1]
		den = dx * ey - dy * ex
		if abs(den) < 1e-9:
			continue
		t = ((a[0] - p0[0]) * ey - (a[1] - p0[1]) * ex) / den
		u = ((a[0] - p0[0]) * dy - (a[1] - p0[1]) * dx) / den
		if 0 <= u < 1 and 0 <= t <= 1:
			ts.append(t)
	ts.sort()
	inside0 = point_in(poly, p0)
	edges = ([0.0] if inside0 else []) + ts + ([1.0] if (inside0 ^ (len(ts) % 2 == 1)) else [])
	L = math.hypot(dx, dy) or 1.0
	out = []
	for k in range(0, len(edges) - 1, 2):
		t0 = edges[k] + inset / L
		t1 = edges[k + 1] - inset / L
		if t1 > t0:
			out.append(((p0[0] + dx * t0, p0[1] + dy * t0), (p0[0] + dx * t1, p0[1] + dy * t1)))
	return out


def point_in(poly, p):
	x, y = p
	inside = False
	n = len(poly)
	for i in range(n):
		x1, y1 = poly[i]
		x2, y2 = poly[(i + 1) % n]
		if (y1 > y) != (y2 > y):
			xi = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
			if xi > x:
				inside = not inside
	return inside


def clipped_lines(poly, segs, inset, **stroke):
	"""Path elements for every (p0, p1) in `segs` clipped to `poly`."""
	out = []
	for p0, p1 in segs:
		for a, b in clip_segment(poly, p0, p1, inset):
			out.append(path("M%s %s L%s %s" % (f(a[0]), f(a[1]), f(b[0]), f(b[1])), **stroke))
	return out


def signed_area(poly):
	return 0.5 * sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
					 for i in range(len(poly)))


def clip_convex(subject, clip):
	"""Sutherland-Hodgman: `subject` polygon clipped by the CONVEX polygon `clip` (any orientation)."""
	if signed_area(clip) < 0:
		clip = list(reversed(clip))
	out = list(subject)

	def inside(p, a, b):
		return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) >= 0

	def inter(p, q, a, b):
		x1, y1 = p
		x2, y2 = q
		x3, y3 = a
		x4, y4 = b
		den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
		if abs(den) < 1e-12:
			return q
		t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
		return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))

	for i in range(len(clip)):
		a = clip[i]
		b = clip[(i + 1) % len(clip)]
		inp = out
		out = []
		if not inp:
			break
		s = inp[-1]
		for e in inp:
			if inside(e, a, b):
				if not inside(s, a, b):
					out.append(inter(s, e, a, b))
				out.append(e)
			elif inside(s, a, b):
				out.append(inter(s, e, a, b))
			s = e
	return out


def poly_path(poly):
	return "M" + " L".join("%s %s" % (f(x), f(y)) for x, y in poly) + " Z"


_MEASURE = {}


def measure(part, pad=90):
	"""Tight ink-inclusive bbox of `part` in local coords, measured by rasterising at 2x (rsvg-convert)."""
	import subprocess
	import tempfile
	from PIL import Image
	key = "".join(part.items)
	if key in _MEASURE:
		return _MEASURE[key]
	x0, y0, x1, y1 = part.bbox
	ox, oy = -x0 + pad, -y0 + pad
	w, h = int(x1 - x0 + 2 * pad), int(y1 - y0 + 2 * pad)
	doc = svg_doc(w, h, [g(part.items, transform="translate(%s %s)" % (f(ox), f(oy)))])
	fd, sp = tempfile.mkstemp(suffix=".svg")
	os.close(fd)
	with open(sp, "w") as fh:
		fh.write(doc)
	png = sp[:-4] + ".png"
	subprocess.check_call(["rsvg-convert", sp, "-z", "2", "-o", png])
	a = Image.open(png).convert("RGBA").split()[-1].point(lambda v: 255 if v > 2 else 0)
	bb = a.getbbox()
	os.remove(sp)
	os.remove(png)
	if not bb:
		out = part.bbox
	else:
		out = (bb[0] / 2 - ox - 0.5, bb[1] / 2 - oy - 0.5, bb[2] / 2 - ox + 0.5, bb[3] / 2 - oy + 0.5)
		if out[0] <= -ox + 1 or out[1] <= -oy + 1 or out[2] >= w - ox - 1 or out[3] >= h - oy - 1:
			return measure(part, pad * 2)
	_MEASURE[key] = out
	return out
