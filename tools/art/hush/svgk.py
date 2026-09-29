"""svgk — tiny SVG authoring kit for the art-hush generators (Hush, Pip, Clarence, Figgis, the Stalls).

Ported from the Booby style kit (same discipline: presentation attributes only, 1-decimal coordinates,
round joins/caps, navy ink) and extended with the geometry the Mischief cast needs without clipPath/masks:
Catmull-Rom sampling, Sutherland-Hodgman clipping against convex regions (for Breton stripes), and the
"stroke-under" union trick (every shape stroked 2x wide in ink first, fills on top -> one clean outline
around the union of overlapping shapes, e.g. glove fingers + palm).

Everything here is pure Python (no third-party deps); Pillow/rsvg-convert are only used by preview.py.
"""
import math
import os

INK = "#1B2340"
SW = 6.0      # character outline (GDD 9.1)
DET = 3.5     # character inner detail
MARGIN = 3    # empty canvas margin (px) kept clear of any paint


# --- number formatting ---------------------------------------------------------------------------
def f(v):
	"""1-decimal, trailing .0 stripped, no -0."""
	s = "%.1f" % float(v)
	if s.endswith(".0"):
		s = s[:-2]
	if s == "-0":
		s = "0"
	return s


def attrs(**kw):
	out = []
	for k, v in kw.items():
		if v is None:
			continue
		k = k.rstrip("_").replace("_", "-")
		if isinstance(v, (int, float)) and not isinstance(v, bool):
			v = f(v) if "opacity" not in k else ("%.2f" % v).rstrip("0").rstrip(".")
		out.append('%s="%s"' % (k, v))
	return " ".join(out)


def stroke_kw(sw, color=INK):
	return dict(stroke=color, stroke_width=sw, stroke_linejoin="round", stroke_linecap="round")


def _el(tag, fill, sw, stroke, kw, base):
	a = dict(base)
	a["fill"] = fill
	if sw:
		a.update(stroke_kw(sw, stroke or INK))
	elif stroke:
		a["stroke"] = stroke
	a.update(kw)
	return "<%s %s/>" % (tag, attrs(**a))


def path(d, fill="none", sw=None, stroke=None, **kw):
	return _el("path", fill, sw, stroke, kw, dict(d=d))


def circle(cx, cy, r, fill="none", sw=None, stroke=None, **kw):
	return _el("circle", fill, sw, stroke, kw, dict(cx=float(cx), cy=float(cy), r=float(r)))


def ellipse(cx, cy, rx, ry, fill="none", sw=None, stroke=None, **kw):
	return _el("ellipse", fill, sw, stroke, kw, dict(cx=float(cx), cy=float(cy), rx=float(rx), ry=float(ry)))


def rect(x, y, w, h, rx=0, fill="none", sw=None, stroke=None, **kw):
	b = dict(x=float(x), y=float(y), width=float(w), height=float(h))
	if rx:
		b["rx"] = float(rx)
	return _el("rect", fill, sw, stroke, kw, b)


def line(x1, y1, x2, y2, sw=DET, stroke=INK, **kw):
	a = dict(x1=float(x1), y1=float(y1), x2=float(x2), y2=float(y2))
	a.update(stroke_kw(sw, stroke))
	a.update(kw)
	return "<line %s/>" % attrs(**a)


def g(items, transform=None, **kw):
	a = {}
	if transform:
		a["transform"] = transform
	a.update(kw)
	at = attrs(**a)
	return "<g%s>%s</g>" % ((" " + at) if at else "", "".join(items))


def svg(w, h, items):
	return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (w, h, w, h)
			+ "".join(items) + "</svg>\n")


def write(p, s):
	os.makedirs(os.path.dirname(p), exist_ok=True)
	with open(p, "w") as fh:
		fh.write(s)
	return p


# --- point maths ----------------------------------------------------------------------------------
def rot(p, ang, c=(0.0, 0.0)):
	a = math.radians(ang)
	x, y = p[0] - c[0], p[1] - c[1]
	return (c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a))


def xform(pts, dx=0.0, dy=0.0, sx=1.0, sy=1.0, ang=0.0, c=(0.0, 0.0)):
	out = []
	for p in pts:
		q = (c[0] + (p[0] - c[0]) * sx, c[1] + (p[1] - c[1]) * sy)
		q = rot(q, ang, c)
		out.append((q[0] + dx, q[1] + dy))
	return out


def lerp(a, b, t):
	return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def polar(c, r, ang_deg):
	"""point at angle (deg, 0 = +x, 90 = +y/down) and radius r from c."""
	a = math.radians(ang_deg)
	return (c[0] + r * math.cos(a), c[1] + r * math.sin(a))


# --- path building ----------------------------------------------------------------------------------
def pts_path(pts, close=True):
	s = "M" + " L".join("%s %s" % (f(x), f(y)) for x, y in pts)
	return s + (" Z" if close else "")


def _cr_ctrl(p0, p1, p2, p3, t):
	c1 = (p1[0] + (p2[0] - p0[0]) * t / 3.0, p1[1] + (p2[1] - p0[1]) * t / 3.0)
	c2 = (p2[0] - (p3[0] - p1[0]) * t / 3.0, p2[1] - (p3[1] - p1[1]) * t / 3.0)
	return c1, c2


def smooth_closed(pts, t=0.5):
	"""Catmull-Rom -> cubic bezier closed path through points."""
	n = len(pts)
	d = "M%s %s" % (f(pts[0][0]), f(pts[0][1]))
	for i in range(n):
		p0 = pts[(i - 1) % n]; p1 = pts[i]; p2 = pts[(i + 1) % n]; p3 = pts[(i + 2) % n]
		c1, c2 = _cr_ctrl(p0, p1, p2, p3, t)
		d += " C%s %s %s %s %s %s" % (f(c1[0]), f(c1[1]), f(c2[0]), f(c2[1]), f(p2[0]), f(p2[1]))
	return d + " Z"


def smooth_open(pts, t=0.5):
	n = len(pts)
	d = "M%s %s" % (f(pts[0][0]), f(pts[0][1]))
	for i in range(n - 1):
		p0 = pts[max(i - 1, 0)]; p1 = pts[i]; p2 = pts[i + 1]; p3 = pts[min(i + 2, n - 1)]
		c1, c2 = _cr_ctrl(p0, p1, p2, p3, t)
		d += " C%s %s %s %s %s %s" % (f(c1[0]), f(c1[1]), f(c2[0]), f(c2[1]), f(p2[0]), f(p2[1]))
	return d


def _bez(p0, c1, c2, p3, u):
	a = (1 - u) ** 3; b = 3 * (1 - u) ** 2 * u; c = 3 * (1 - u) * u * u; d = u ** 3
	return (a * p0[0] + b * c1[0] + c * c2[0] + d * p3[0], a * p0[1] + b * c1[1] + c * c2[1] + d * p3[1])


def sample_closed(pts, t=0.5, n=10):
	"""Polygon approximating smooth_closed(pts, t) (n samples per segment)."""
	out = []
	m = len(pts)
	for i in range(m):
		p0 = pts[(i - 1) % m]; p1 = pts[i]; p2 = pts[(i + 1) % m]; p3 = pts[(i + 2) % m]
		c1, c2 = _cr_ctrl(p0, p1, p2, p3, t)
		for k in range(n):
			out.append(_bez(p1, c1, c2, p2, k / float(n)))
	return out


def sample_open(pts, t=0.5, n=10):
	out = []
	m = len(pts)
	for i in range(m - 1):
		p0 = pts[max(i - 1, 0)]; p1 = pts[i]; p2 = pts[i + 1]; p3 = pts[min(i + 2, m - 1)]
		c1, c2 = _cr_ctrl(p0, p1, p2, p3, t)
		for k in range(n):
			out.append(_bez(p1, c1, c2, p2, k / float(n)))
	out.append(pts[-1])
	return out


def ellipse_pts(cx, cy, rx, ry, n=36, ang=0.0):
	pts = []
	for i in range(n):
		a = 2 * math.pi * i / n
		pts.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
	return xform(pts, ang=ang, c=(cx, cy)) if ang else pts


def star_pts(cx, cy, r1, r2, n=5, ang=-90):
	pts = []
	for i in range(n * 2):
		r = r1 if i % 2 == 0 else r2
		a = math.radians(ang + i * 180.0 / n)
		pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
	return pts


def heart_path(cx, cy, s):
	"""a chunky heart centred at (cx, cy), about 2s wide."""
	return ("M%s %s C%s %s %s %s %s %s C%s %s %s %s %s %s Z" % (
		f(cx), f(cy + s * 0.9),
		f(cx - s * 1.6), f(cy - s * 0.1), f(cx - s * 0.8), f(cy - s * 1.2), f(cx), f(cy - s * 0.45),
		f(cx + s * 0.8), f(cy - s * 1.2), f(cx + s * 1.6), f(cy - s * 0.1), f(cx), f(cy + s * 0.9)))


# --- clipping (Sutherland-Hodgman against a convex clip polygon) -----------------------------------------
def _inside(p, a, b):
	return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) >= 0


def _isect(p1, p2, a, b):
	x1, y1 = p1; x2, y2 = p2; x3, y3 = a; x4, y4 = b
	den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
	if abs(den) < 1e-9:
		return p2
	t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
	return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))


def clip_convex(subject, clip):
	"""Clip polygon `subject` by convex polygon `clip` (clockwise in y-down screen space)."""
	out = list(subject)
	n = len(clip)
	for i in range(n):
		a = clip[i]; b = clip[(i + 1) % n]
		inp = out
		out = []
		if not inp:
			break
		s = inp[-1]
		for e in inp:
			if _inside(e, a, b):
				if not _inside(s, a, b):
					out.append(_isect(s, e, a, b))
				out.append(e)
			elif _inside(s, a, b):
				out.append(_isect(s, e, a, b))
			s = e
	return out


def band(y0, y1, x0=-2000.0, x1=2000.0, tilt=0.0):
	"""clockwise (y-down) quad between y0 and y1; tilt = dy per px of x (slanted stripes)."""
	return [(x0, y0 + tilt * x0), (x1, y0 + tilt * x1), (x1, y1 + tilt * x1), (x0, y1 + tilt * x0)]


def half_plane(a, b, far=4000.0):
	"""convex quad covering the side of line a->b where _inside() is true."""
	dx, dy = b[0] - a[0], b[1] - a[1]
	L = math.hypot(dx, dy) or 1.0
	ux, uy = dx / L, dy / L
	nx, ny = -uy, ux   # inside normal for clockwise-in-screen convention
	p0 = (a[0] - ux * far, a[1] - uy * far)
	p1 = (a[0] + ux * far, a[1] + uy * far)
	return [p0, p1, (p1[0] + nx * far, p1[1] + ny * far), (p0[0] + nx * far, p0[1] + ny * far)]


def poly_area(pts):
	s = 0.0
	for i in range(len(pts)):
		x1, y1 = pts[i]; x2, y2 = pts[(i + 1) % len(pts)]
		s += x1 * y2 - x2 * y1
	return s * 0.5


# --- drawing idioms -----------------------------------------------------------------------------------
def shaded(d, base, shade, pivot, s=0.86, dx=0.0, dy=0.0, sw=SW, outline=True):
	"""Shade-first inset: silhouette in the shade tone, a smaller lit copy shifted up-left, outline on top."""
	px, py = pivot
	tr = "translate(%s %s) scale(%s) translate(%s %s)" % (f(px + dx), f(py + dy), s, f(-px), f(-py))
	out = [path(d, fill=shade), path(d, fill=base, transform=tr)]
	if outline:
		out.append(path(d, sw=sw))
	return out


def capsule_d(x1, y1, x2, y2, w):
	"""closed path of a capsule (stadium) between two points, width w."""
	dx, dy = x2 - x1, y2 - y1
	L = math.hypot(dx, dy) or 0.001
	nx, ny = -dy / L * w / 2, dx / L * w / 2
	r = w / 2
	return ("M%s %s L%s %s A%s %s 0 0 0 %s %s L%s %s A%s %s 0 0 0 %s %s Z" % (
		f(x1 + nx), f(y1 + ny), f(x2 + nx), f(y2 + ny), f(r), f(r), f(x2 - nx), f(y2 - ny),
		f(x1 - nx), f(y1 - ny), f(r), f(r), f(x1 + nx), f(y1 + ny)))


class Union:
	"""Shapes drawn as ONE outlined silhouette (stroke-under trick) with a flat shade rim.

	render() emits: every shape in ink with a 2*sw stroke (the union's outline, `sw` wide, outside the
	shapes), then per shape in order: the shape in the shade tone and its lit inset (edges pulled in by
	`inset` px and shifted up-left by `shift`), so each shape keeps a shade crescent on its lower-right
	edge — also where a later shape (a finger) overlaps an earlier one (the palm), which reads as the
	separation between them."""

	def __init__(self, base, shade, sw=SW, inset=3.0, shift=2.1):
		self.base, self.shade, self.sw = base, shade, sw
		self.inset, self.shift = inset, shift
		self.shapes = []

	def add(self, d, lit_d=None):
		self.shapes.append((d, lit_d))
		return self

	def add_capsule(self, x1, y1, x2, y2, w):
		s, i = self.shift, self.inset
		return self.add(capsule_d(x1, y1, x2, y2, w), capsule_d(x1 - s, y1 - s, x2 - s, y2 - s, max(w - 2 * i, 1.0)))

	def add_poly(self, pts, t=0.6):
		cx = sum(p[0] for p in pts) / len(pts); cy = sum(p[1] for p in pts) / len(pts)
		r = sum(math.hypot(p[0] - cx, p[1] - cy) for p in pts) / len(pts)
		k = max(0.2, 1.0 - self.inset / max(r, 1.0))
		lit = [(cx + (p[0] - cx) * k - self.shift, cy + (p[1] - cy) * k - self.shift) for p in pts]
		return self.add(smooth_closed(pts, t), smooth_closed(lit, t))

	def add_circle(self, x, y, r):
		return self.add_poly(ellipse_pts(x, y, r, r, n=12), 0.5)

	def render(self, detail=None):
		out = []
		for d, _ in self.shapes:
			out.append(path(d, fill=INK, stroke=INK, stroke_width=self.sw * 2, stroke_linejoin="round"))
		for d, lit in self.shapes:
			out.append(path(d, fill=self.shade))
			if lit:
				out.append(path(lit, fill=self.base))
		if detail:
			out += detail
		return out


def highlight(cx, cy, rx, ry, ang=-30.0, op=0.55):
	return ellipse(cx, cy, rx, ry, fill="#FFFFFF", fill_opacity=op, transform="rotate(%s %s %s)" % (f(ang), f(cx), f(cy)))


# --- canvases ---------------------------------------------------------------------------------------
class Part:
	"""A part drawn in joint-local coords (joint = (0,0), y down) on a FIXED canvas box (minx, miny, maxx, maxy).

	The canvas box is shared by every skin/variant of a part so pivots stay identical. `scale` draws the
	authored geometry smaller/larger (the canvas box scales with it, rounded outward to whole px, so the
	joint stays on an integer pivot)."""

	def __init__(self, name, items, box, scale=1.0):
		self.name = name
		self.items = items
		self.scale = scale
		minx, miny, maxx, maxy = box
		self.box = box
		sb = (math.floor(minx * scale), math.floor(miny * scale), math.ceil(maxx * scale), math.ceil(maxy * scale))
		self.sbox = sb
		self.w = int(sb[2] - sb[0])
		self.h = int(sb[3] - sb[1])
		self.pivot = (float(-sb[0]), float(-sb[1]))

	def svg(self):
		tr = "translate(%s %s)" % (f(self.pivot[0]), f(self.pivot[1]))
		if self.scale != 1.0:
			tr += " scale(%s)" % ("%.3f" % self.scale).rstrip("0").rstrip(".")
		return svg(self.w, self.h, [g(self.items, transform=tr)])


def box_around(cx0, cy0, cx1, cy1, pad=MARGIN):
	"""canvas box from a content bbox plus margin, rounded outward to whole px."""
	return (math.floor(cx0 - pad), math.floor(cy0 - pad), math.ceil(cx1 + pad), math.ceil(cy1 + pad))
