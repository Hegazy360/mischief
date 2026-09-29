"""The Stalls: 24 audience head/hat silhouettes seen from behind (they face the stage), single flat fill
#2A1E3A, no outline (alpha is applied at runtime). Frames per head: `rest`, `laugh` (head thrown back,
turned to profile, jaw open), `lean` (toward a neighbour), `point` (an arm jabbing at the stage for
"BEHIND YOU!"). Plus a 4-frame `tumble` of one audience member laughing out of his seat (the T4 roar).

Every canvas: pivot = bottom centre (the shoulder line sits on the canvas bottom edge — the strip is cut by
the screen's bottom edge anyway). Heads are 40-110 px tall at rest.
"""
import math
from collections import OrderedDict

from svgk import Part, path, circle, ellipse, rect, g, smooth_closed, pts_path, capsule_d, ellipse_pts, xform, f, rot
import pal

FILL = pal.STALLS["fill"]
ART = "res://art/chars/stalls/"


def E(cx, cy, rx, ry, ang=0.0):
	return smooth_closed(ellipse_pts(cx, cy, rx, ry, n=16, ang=ang), 0.5)


def C(cx, cy, r):
	return E(cx, cy, r, r)


def CAP(x1, y1, x2, y2, w):
	return capsule_d(x1, y1, x2, y2, w)


def POLY(pts, t=0.0):
	return smooth_closed(pts, t) if t else pts_path(pts)


# --- head types: (id, head rx, ry, shoulder half-width, hair/hat builder(rx, ry) -> [d], face_dir) -------------
def bowler(rx, ry):
	return [E(0, -ry * 0.62, rx * 1.02, ry * 0.58), E(0, -ry * 0.3, rx * 1.42, 4.5)]


def beehive(rx, ry):
	return [E(0, -ry * 1.25, rx * 0.95, ry * 1.25), E(0, -ry * 0.2, rx * 1.05, ry * 0.9)]


def bald(rx, ry):
	return [C(-rx, 2, 5.5), C(rx, 2, 5.5)]


def toddler(rx, ry):
	cy = -ry - 14
	return [C(0, cy, 10.5), CAP(-6, cy + 8, -rx - 2, -ry * 0.1, 7), CAP(6, cy + 8, rx + 2, -ry * 0.1, 7),
			CAP(-7, cy - 2, -17, cy - 12, 6), CAP(7, cy - 2, 17, cy - 12, 6), C(0, cy - 10, 4)]


def feather_hat(rx, ry):
	return [E(0, -ry * 0.72, rx * 0.9, ry * 0.42),
			POLY([(4, -ry * 0.9), (14, -ry - 18), (28, -ry - 30), (25, -ry - 14), (16, -ry * 0.8)], 0.5),
			E(-rx * 0.7, -ry * 0.5, 7, 5)]


def curlers(rx, ry):
	out = []
	for k in range(6):
		a = math.radians(-160 + k * 28)
		out.append(C(math.cos(a) * rx * 1.02, -ry * 0.1 + math.sin(a) * ry * 1.02, 7.5))
	return out


def top_hat(rx, ry):
	return [rect_d(-rx * 0.82, -ry * 0.55 - 40, rx * 1.64, 42), E(0, -ry * 0.55, rx * 1.4, 4.5)]


def rect_d(x, y, w, h):
	return pts_path([(x, y), (x + w, y), (x + w, y + h), (x, y + h)])


def flat_cap(rx, ry):
	return [E(0, -ry * 0.55, rx * 1.08, ry * 0.52), E(rx * 0.9, -ry * 0.3, rx * 0.6, 4, ang=10)]


def pigtails(rx, ry):
	return [E(-rx - 7, 4, 7, 12, ang=20), E(rx + 7, 4, 7, 12, ang=-20), C(-rx - 1, -4, 4), C(rx + 1, -4, 4)]


def afro(rx, ry):
	return [C(0, -ry * 0.35, rx * 1.55)]


def topknot(rx, ry):
	return [C(0, -ry - 7, 10)]


def mohawk(rx, ry):
	pts = []
	for k in range(7):
		t = k / 6.0
		a = math.radians(-160 + t * 140)
		pts.append((math.cos(a) * rx * 0.3, -ry * 0.6 + math.sin(a) * ry * 0.3 - (18 if k % 2 == 0 else 6)))
	return [POLY([(-6, -ry * 0.5)] + [(p[0] * 2.4, p[1]) for p in pts] + [(6, -ry * 0.5)])]


def cowlick(rx, ry):
	return [POLY([(-4, -ry + 2), (-2, -ry - 14), (10, -ry - 20), (4, -ry - 10), (6, -ry + 2)], 0.5)]


def sunhat(rx, ry):
	return [E(0, -ry * 0.62, rx * 0.95, ry * 0.5), E(0, -ry * 0.38, rx * 2.1, 6.5)]


def beanie(rx, ry):
	return [E(0, -ry * 0.5, rx * 1.05, ry * 0.68), C(0, -ry * 1.18, 8)]


def ponytail(rx, ry):
	return [CAP(0, -ry * 0.2, 2, ry + 12, 12), C(0, -ry * 0.1, 6)]


def spiky(rx, ry):
	pts = []
	n = 9
	for k in range(n):
		a = math.radians(-180 + k * 180.0 / (n - 1))
		r = (ry + 12) if k % 2 == 1 else ry * 0.95
		pts.append((math.cos(a) * (rx + (6 if k % 2 == 1 else 0)), -2 + math.sin(a) * r))
	return [POLY([(-rx, 4)] + pts + [(rx, 4)])]


def bob(rx, ry):
	return [POLY([(-rx - 5, ry * 0.7), (-rx - 6, -ry * 0.4), (-rx * 0.6, -ry - 4), (rx * 0.6, -ry - 4),
				  (rx + 6, -ry * 0.4), (rx + 5, ry * 0.7)], 0.5)]


def side_cap(rx, ry):
	return [E(0, -ry * 0.5, rx * 1.05, ry * 0.6), E(-rx * 1.1, -ry * 0.25, rx * 0.7, 4, ang=-8)]


def flower_hat(rx, ry):
	out = [E(0, -ry * 0.6, rx * 0.95, ry * 0.5), E(0, -ry * 0.35, rx * 1.4, 4)]
	for k in range(5):
		a = math.radians(-90 + k * 72)
		out.append(C(8 + math.cos(a) * 7, -ry - 8 + math.sin(a) * 7, 5.5))
	return out


def big_ears(rx, ry):
	return [E(-rx - 4, 0, 7, 11), E(rx + 4, 0, 7, 11),
			POLY([(-rx - 2, -ry * 0.5), (-rx - 9, -ry * 0.75), (-rx + 3, -ry * 0.7)]),
			POLY([(rx + 2, -ry * 0.5), (rx + 9, -ry * 0.75), (rx - 3, -ry * 0.7)])]


def bunny(rx, ry):
	return [E(-8, -ry - 16, 5.5, 17, ang=-12), E(8, -ry - 16, 5.5, 17, ang=12)]


def tiara(rx, ry):
	out = [E(0, -ry * 0.75, rx * 0.8, ry * 0.5)]
	pts = [(-12, -ry * 1.1), (-9, -ry * 1.1 - 9), (-5, -ry * 1.1 - 2), (0, -ry * 1.1 - 12), (5, -ry * 1.1 - 2),
		   (9, -ry * 1.1 - 9), (12, -ry * 1.1), (0, -ry * 1.1 + 4)]
	out.append(POLY(pts))
	return out


def big_bow(rx, ry):
	y = -ry - 4
	return [POLY([(0, y), (-20, y - 12), (-18, y + 8)]), POLY([(0, y), (20, y - 12), (18, y + 8)]), C(0, y, 5)]


HEADS = [
	("bowler", 16, 19, 30, bowler, 1), ("beehive", 15, 18, 26, beehive, -1), ("bald", 18, 21, 32, bald, 1),
	("toddler", 16, 19, 30, toddler, -1), ("feather", 15, 18, 26, feather_hat, 1), ("curlers", 16, 19, 27, curlers, -1),
	("top_hat", 16, 19, 30, top_hat, 1), ("flat_cap", 16, 19, 31, flat_cap, -1), ("pigtails", 13, 16, 22, pigtails, 1),
	("afro", 15, 18, 28, afro, -1), ("topknot", 15, 18, 26, topknot, 1), ("mohawk", 15, 19, 29, mohawk, -1),
	("cowlick", 12, 15, 20, cowlick, 1), ("sunhat", 15, 18, 27, sunhat, -1), ("beanie", 15, 18, 28, beanie, 1),
	("ponytail", 15, 18, 26, ponytail, -1), ("spiky", 14, 17, 25, spiky, 1), ("bob", 15, 18, 26, bob, -1),
	("side_cap", 15, 18, 28, side_cap, 1), ("flower_hat", 15, 18, 26, flower_hat, -1),
	("big_ears", 17, 20, 30, big_ears, 1), ("bunny", 12, 15, 20, bunny, -1), ("tiara", 15, 18, 26, tiara, 1),
	("big_bow", 13, 16, 22, big_bow, -1),
]
# a pleasant left-to-right order (tall/short and big/small alternate so the strip reads as a crowd)
LAYOUT = ["bowler", "pigtails", "beehive", "bald", "cowlick", "feather", "flat_cap", "toddler", "bob", "top_hat",
		  "bunny", "curlers", "afro", "big_bow", "sunhat", "spiky", "tiara", "big_ears", "beanie", "ponytail",
		  "mohawk", "flower_hat", "topknot", "side_cap"]

SH_H = 15      # shoulder bump height
NECK = 6


def _laugh_head(rx, ry, d):
	"""head outline with a profile face on side d (+1 right / -1 left): nose, upper lip, OPEN jaw."""
	face = [(0, -ry), (d * rx * 0.78, -ry * 0.62), (d * rx * 0.98, -ry * 0.25), (d * (rx + 7), ry * 0.0),
			(d * rx * 0.94, ry * 0.14), (d * (rx + 1), ry * 0.26), (d * rx * 0.35, ry * 0.42),
			(d * (rx + 5), ry * 0.92), (d * rx * 0.72, ry * 1.18), (d * rx * 0.2, ry * 1.12)]
	back = [(-d * rx * abs(math.cos(math.radians(90 + k * 15))), ry * math.sin(math.radians(90 + k * 15))) for k in range(1, 12)]
	return pts_path(face + back)


SCALE = 1.25


def head_frame(spec, frame):
	hid, rx, ry, sw, hair, d = spec
	return [g(_head_frame(spec, frame), transform="scale(%s)" % SCALE)]


def _head_frame(spec, frame):
	hid, rx, ry, sw, hair, d = spec
	neck_y = -SH_H - NECK + 2
	hc = (0, neck_y - ry + 4)           # head centre
	shapes = []
	# shoulders + neck (never move)
	shapes.append(smooth_closed([(-sw, 0), (-sw, -SH_H * 0.5), (-sw * 0.7, -SH_H), (sw * 0.7, -SH_H), (sw, -SH_H * 0.5),
								 (sw, 0)], 0.3))
	shapes.append(rect_d(-6, neck_y - 6, 12, 12 + NECK))
	head = [E(0, 0, rx, ry)] + hair(rx, ry)
	if frame == "laugh":
		head = [_laugh_head(rx, ry, d)] + hair(rx, ry)
		tr = "translate(%s %s) rotate(%s)" % (f(hc[0] - d * 3), f(hc[1] - 10), f(-d * 22))
	elif frame == "lean":
		tr = "translate(%s %s) rotate(%s %s %s)" % (f(hc[0] + d * 7), f(hc[1] + 2), f(d * 13), 0, f(ry))
	else:
		tr = "translate(%s %s)" % (f(hc[0]), f(hc[1]))
	items = [path(s, fill=FILL) for s in shapes]
	items.append(g([path(s, fill=FILL) for s in head], transform=tr))
	if frame == "point":
		sx = d * sw * 0.55
		hx, hy = d * (sw * 0.55 + 12), neck_y - ry * 2 - 14
		items += [path(CAP(sx, -SH_H + 4, hx, hy, 10), fill=FILL), path(C(hx, hy, 7), fill=FILL),
				  path(CAP(hx, hy, hx + d * 4, hy - 13, 5.5), fill=FILL)]
	return items


def head_box(spec):
	hid, rx, ry, sw, hair, d = spec
	w = (max(sw, rx * 2.2) + 34) * SCALE
	return (-math.ceil(w), -int(150 * SCALE), math.ceil(w), 0)


# --- tumble: an audience member laughs himself out of his seat (4 frames) -------------------------------
def figure(ang, dy, legs, arms, head_laugh=True, legs_only=False):
	"""a simple person (bowler hat) around a hip point; ang rotates the body back (deg)."""
	hip = (0, -26 + dy)
	out = []
	def T(p):
		q = rot(p, -ang, (0, 0))
		return (q[0] + hip[0], q[1] + hip[1])
	if not legs_only:
		out.append(CAP(*T((0, 0)), *T((0, -38)), 26))                       # torso
		hc = T((0, -58))
		out.append(C(hc[0], hc[1], 15))
		b1 = T((0, -68)); b2 = T((0, -64))
		out.append(smooth_closed(ellipse_pts(b1[0], b1[1], 15, 9, n=12, ang=-ang), 0.5))
		out.append(smooth_closed(ellipse_pts(b2[0], b2[1], 21, 4, n=12, ang=-ang), 0.5))
		if head_laugh:
			j = T((10, -48))
			out.append(C(j[0], j[1], 7))
		for (a1, a2) in arms:
			s = T((0, -32)); e = T(a1); h = T(a2)
			out += [CAP(s[0], s[1], e[0], e[1], 9), CAP(e[0], e[1], h[0], h[1], 8), C(h[0], h[1], 6)]
	for (k1, k2) in legs:
		s = T((0, 0)); k = T(k1); e = T(k2)
		out += [CAP(s[0], s[1], k[0], k[1], 11), CAP(k[0], k[1], e[0], e[1], 10)]
		fe = rot((e[0] - k[0], e[1] - k[1]), 0)
		out.append(smooth_closed(ellipse_pts(e[0] + 3, e[1], 9, 5, n=10, ang=-ang), 0.5))
	return out


TUMBLE = [
	dict(ang=24, dy=0, legs=[((18, 8), (30, -14)), ((12, 10), (24, -6))], arms=[((10, -52), (4, -72)), ((-10, -50), (-18, -70))]),
	dict(ang=95, dy=-20, legs=[((16, -10), (22, -40)), ((10, -8), (26, -34))], arms=[((10, -52), (20, -64)), ((-12, -48), (-22, -60))]),
	dict(ang=165, dy=-50, legs=[((8, -30), (14, -62)), ((-8, -30), (-16, -60))], arms=[((12, -40), (22, -30)), ((-12, -40), (-22, -30))]),
	dict(ang=180, dy=-30, legs=[((10, -34), (22, -62)), ((-8, -34), (-4, -66))], arms=[], legs_only=True),
]
TUMBLE_BOX = (-86, -150, 72, 0)


def tumble_frame(i):
	fr = TUMBLE[i]
	items = [path(s, fill=FILL) for s in figure(fr["ang"], fr["dy"], fr["legs"], fr["arms"],
												legs_only=fr.get("legs_only", False))]
	# the seat back he tips over (stays put)
	items.append(path(smooth_closed([(-34, 0), (-34, -22), (-28, -30), (28, -30), (34, -22), (34, 0)], 0.3), fill=FILL))
	return Part("tumble_%d" % (i + 1), items, TUMBLE_BOX)


FRAMES = ["rest", "laugh", "lean", "point"]


def _extent(spec):
	"""rest-frame silhouette size (w, h) estimated from the head + hair shapes."""
	hid, rx, ry, sw, hair, d = spec
	import re
	neck_y = -SH_H - NECK + 2
	hc_y = neck_y - ry + 4
	xs, ys = [-sw, sw], [0, hc_y - ry]
	for dstr in hair(rx, ry):
		nums = [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", dstr)]
		for k in range(0, len(nums) - 1, 2):
			xs.append(nums[k]); ys.append(nums[k + 1] + hc_y)
	return int(round((max(xs) - min(xs)) * SCALE)), int(round(-min(ys) * SCALE))


def build():
	files = OrderedDict()
	heads = []
	for spec in HEADS:
		hid = spec[0]
		box = head_box(spec)
		fr = OrderedDict()
		for frame in FRAMES:
			p = Part("%s_%s" % (hid, frame), head_frame(spec, frame), box)
			files[p.name + ".svg"] = p.svg()
			fr[frame] = ART + p.name + ".svg"
		w, h = _extent(spec)
		heads.append(OrderedDict([("id", hid), ("w", w), ("h", h), ("face_dir", spec[5]),
								  ("size", [box[2] - box[0], box[3] - box[1]]), ("pivot", [-box[0], -box[1]]),
								  ("frames", fr)]))
	tumble = []
	for i in range(len(TUMBLE)):
		p = tumble_frame(i)
		files[p.name + ".svg"] = p.svg()
		tumble.append(OrderedDict([("file", ART + p.name + ".svg"), ("size", [p.w, p.h]), ("pivot", list(p.pivot)),
								   ("frames", 8)]))
	meta = OrderedDict([
		("version", 1),
		("doc", "The Stalls (GDD 6.5, TECH 5.10): audience silhouettes seen from behind. One flat fill; apply alpha "
				"at runtime (0.6 at rest, 1.0 in reaction holds). pivot = bottom centre = the shoulder line. Frames: "
				"rest, laugh (head back, profile, jaw open), lean (toward face_dir), point (arm up for BEHIND YOU!). "
				"`tumble` = one head's T4 fall, 4 frames (8 f each), drawn in its seat slot. `layout` = suggested "
				"left-to-right order; `w`/`h` = rest silhouette size."),
		("fill", FILL), ("alpha_rest", 0.6), ("alpha_hold", 1.0),
		("heads", heads), ("tumble", tumble), ("layout", LAYOUT),
	])
	return files, meta
