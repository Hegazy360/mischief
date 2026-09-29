"""Head parts: head (skin, ear, jowls), nose, bouffant x7, sideburns x4 per side.
Head-local coords: pivot = neck base (world (16, -206) at rest). Eyes sit around y -72, the chin at +14.
Bouffant-local: pivot = scalp top (head (-2, -110)). Sideburn-local: pivot = the top (temple) of the chop."""
import math
from svgk import (Part, path, circle, ellipse, rect, g, smooth_closed, smooth_open, shaded, highlight, bbox_pts,
				  union, rot, xform, f, qcurve, cloud_pts, spiky_pts, sample_closed, clipped_lines, INK, SW, DET)
import palette as P

HEAD_SIL = [(2, -128), (34, -124), (56, -108), (66, -84), (69, -58), (67, -32), (58, -8), (40, 9), (16, 15),
			(-8, 13), (-30, 3), (-46, -16), (-56, -46), (-58, -80), (-48, -108), (-26, -124)]
EAR = (-60, -54)


def head():
	it = []
	# near ear (behind the chop, sticking out of the back of the skull)
	ex, ey = EAR
	ear = [(ex + 4, ey - 20), (ex - 9, ey - 16), (ex - 14, ey), (ex - 9, ey + 15), (ex + 4, ey + 19), (ex + 10, ey)]
	it += shaded(smooth_closed(ear, 0.7), P.SKIN, P.SKIN_S, (ex - 4, ey - 6), 0.78)
	it.append(path(qcurve((ex - 2, ey - 9), (ex - 7, ey + 1), (ex - 1, ey + 9)), sw=DET))
	d = smooth_closed(HEAD_SIL, 0.6)
	it += shaded(d, P.SKIN, P.SKIN_S, (-16, -76), 0.9, sw=0)
	# jowl shade crescent under the chin + cheek highlight
	it.append(path(smooth_open([(-20, 4), (6, 12), (34, 8), (52, -6)], 0.6), stroke=P.SKIN_S, stroke_width=7))
	it.append(highlight(-18, -98, 14, 7, -30, 0.5))
	it.append(path(d, sw=SW))
	# double chin fold
	it.append(path(smooth_open([(-4, 2), (14, 7), (34, 2)], 0.6), sw=DET))
	# back-of-skull wrinkle (age) — hidden by the chop mostly
	return Part("head", it, union(bbox_pts(HEAD_SIL, SW / 2), bbox_pts(ear, SW / 2)))


def nose():
	"""Bulbous pompous nose pointing forward-down. Pivot = top of the bridge between the eyes (head (34, -72))."""
	it = []
	sil = [(-6, -2), (6, -2), (15, 10), (30, 14), (43, 23), (45, 35), (38, 45), (23, 47), (10, 44), (2, 34),
		   (-2, 20)]
	d = smooth_closed(sil, 0.6)
	it += shaded(d, P.SKIN, P.SKIN_S, (8, 14), 0.84, sw=0)
	bulb = [(17, 16), (32, 16), (43, 25), (44, 37), (36, 45), (23, 46), (14, 40), (12, 28)]
	it += shaded(smooth_closed(bulb, 0.8), P.NOSE_TIP, P.SKIN_S, (24, 24), 0.82, sw=0, hl=(26, 24, 6, 3.5, -25))
	# nostril wing (ala)
	ala = [(2, 30), (10, 26), (18, 32), (17, 42), (8, 46), (0, 40)]
	it += shaded(smooth_closed(ala, 0.8), P.SKIN, P.SKIN_S, (6, 32), 0.8)
	it.append(path(d, sw=SW))
	it.append(path(qcurve((14, 42), (19, 45), (24, 42)), sw=DET))   # nostril
	return Part("nose", it, union(bbox_pts(sil, SW / 2), bbox_pts(ala, SW / 2)))


# ---------------------------------------------------------------------------------------------
# Bouffant. Local pivot = scalp top (head (-2, -110)). The head crown (skin) is at local (2, -16).
# Hairline rule: for local x >= -24 the hair's bottom edge stays above y -6 (head -116), so the brows
# (head -98 neutral, -108 raised) are never covered. Behind (x < -30) the cloud drops over the back of
# the skull to the ear top. The cloud is 'a dandelion clock': big, round, swept up and back.

def _lobes(circles, base, shade, c, s=0.84, sw=SW, polys=()):
	"""Union of round lobes (+ optional smooth polygons): ink under-layer, shade, one inset lit copy about `c`
	-> a soft cloud with only an OUTER outline."""
	it = [circle(x, y, r + sw / 2, fill=INK) for x, y, r in circles]
	it += [path(smooth_closed(pp, 0.6), fill=INK, stroke=INK, stroke_width=sw, stroke_linejoin="round") for pp in polys]
	it += [circle(x, y, r - sw / 2 + 0.5, fill=shade) for x, y, r in circles]
	it += [path(smooth_closed(pp, 0.6), fill=shade) for pp in polys]
	tr = "translate(%s %s) scale(%s) translate(%s %s)" % (f(c[0]), f(c[1]), s, f(-c[0]), f(-c[1]))
	it += [circle(c[0] + (x - c[0]) * s, c[1] + (y - c[1]) * s, (r - sw / 2) * s, fill=base) for x, y, r in circles]
	it += [path(smooth_closed(pp, 0.6), fill=base, transform=tr) for pp in polys]
	return it


def _bbox_circles(circles, pad=SW / 2):
	return (min(x - r for x, y, r in circles) - pad, min(y - r for x, y, r in circles) - pad,
			max(x + r for x, y, r in circles) + pad, max(y + r for x, y, r in circles) + pad)


def union_radius(circles, c, a):
	"""Distance from `c` along direction angle `a` (radians) to the far edge of the union of `circles`."""
	dx, dy = math.cos(a), math.sin(a)
	best = 0.0
	for x, y, r in circles:
		ox, oy = x - c[0], y - c[1]
		b = ox * dx + oy * dy
		q = ox * ox + oy * oy - r * r
		disc = b * b - q
		if disc >= 0:
			best = max(best, b + math.sqrt(disc))
	return best


NEAT = [(-14, -40, 34), (26, -37, 31), (56, -28, 23), (76, -20, 14), (-54, -33, 31), (-84, -6, 26),
		(-66, 16, 22), (-38, -8, 18), (4, -28, 24), (36, -21, 16), (-36, -54, 22), (12, -56, 20), (58, -46, 18),
		(-92, -28, 16)]
NEAT_C = (-10, -30)


def _neat_details():
	return [path(smooth_open([(-50, -58), (-28, -74), (-2, -76)], 0.6), sw=DET),
			path(smooth_open([(16, -70), (38, -68), (56, -56)], 0.6), sw=DET),
			path(smooth_open([(-94, -12), (-84, -32), (-64, -44)], 0.6), sw=DET),
			path(smooth_open([(-76, 22), (-64, 8), (-50, 8)], 0.6), sw=DET),
			# the front wave curl (the pompadour's pride)
			path("M62 -34 C72 -46 90 -38 88 -24 C86 -12 72 -12 74 -24", sw=DET),
			path(smooth_open([(-20, -40), (4, -50), (28, -46)], 0.6), sw=DET),
			path(smooth_open([(-40, -20), (-28, -30), (-12, -30)], 0.6), sw=DET)]


def _frizz_pts(circles, c, spikes=18, push=1.3, add=10, seed=2):
	pts = []
	n = spikes * 2
	for i in range(n):
		a = -math.pi + 2 * math.pi * i / n
		r0 = union_radius(circles, c, a)
		deg = math.degrees(a)
		# never push spikes down over the face (the front-bottom quadrant)
		face = 5 < deg < 115
		if i % 2 == 0:
			k = 1.0 + 0.12 * math.sin(i * 1.9 + seed)
			r = r0 if face else (r0 * push + add) * k
		else:
			r = r0 * (0.98 if face else 1.02)
		pts.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a)))
	return pts


BOUF_EXTRA = (-118, -104, 104, 104)   # common canvas for all seven (flipped hangs down over the face)


def bouffant(kind):
	it = []
	if kind == "neat":
		it += _lobes(NEAT, P.HAIR, P.HAIR_S, (-24, -46), 0.84)
		it += _neat_details()
		it.append(highlight(-40, -66, 22, 8, -20, 0.6))
		bb = _bbox_circles(NEAT)
	elif kind == "floured":
		it += _lobes(NEAT, P.FLOUR, P.FLOUR_S, (-24, -46), 0.84)
		it += _neat_details()
		puffs = [(-98, -30, 7), (-92, -48, 5), (86, -40, 6), (94, -24, 4.5), (-8, -90, 7), (16, -86, 5), (-34, -84, 4.5),
				 (60, -64, 5)]
		it += [circle(x, y, r, fill=P.FLOUR, stroke=P.FLOUR_S, stroke_width=2.5) for x, y, r in puffs]
		it += [circle(x, y, r * 0.35, fill=P.FLOUR_S) for x, y, r in puffs[:4]]
		bb = union(_bbox_circles(NEAT), _bbox_circles(puffs, 2))
	elif kind == "feathered":
		it += _lobes(NEAT, P.HAIR, P.HAIR_S, (-24, -46), 0.84)
		it += _neat_details()[:4]
		feathers = [(-74, -48, -40, 1.0), (-22, -84, -10, 1.1), (30, -74, 25, 1.0), (72, -46, 60, 0.9),
					(-92, 4, -85, 0.9), (0, -48, 5, 0.8), (-50, -16, -30, 0.8)]
		for x, y, a, s in feathers:
			it += feather(x, y, a, s)
		bb = union(_bbox_circles(NEAT), (-114, -106, 96, 26))
	elif kind == "frazzled":
		pts = _frizz_pts(NEAT, NEAT_C, 17, 1.3, 12)
		d = smooth_closed(pts, 0.1)
		it += shaded(d, P.HAIR, P.HAIR_S, (-30, -50), 0.84)
		for i in range(0, len(pts), 6):
			x, y = pts[i]
			deg = math.degrees(math.atan2(y - NEAT_C[1], x - NEAT_C[0]))
			if 5 < deg < 115:
				continue
			cx, cy = (NEAT_C[0] + (x - NEAT_C[0]) * 0.9, NEAT_C[1] + (y - NEAT_C[1]) * 0.9)
			it.append(circle(cx, cy, 5, fill=P.HAIR_SINGE))
		it += [path(smooth_open([(-56, -36), (-36, -56), (-14, -46), (8, -64)], 0.3), sw=DET),
			   path(smooth_open([(18, -40), (38, -54), (54, -40)], 0.3), sw=DET),
			   path(smooth_open([(-76, 0), (-60, -14), (-44, -4)], 0.3), sw=DET)]
		it.append(path("M-24 -108 C-34 -116 -22 -124 -14 -118 C-6 -112 -14 -102 -6 -100", stroke=P.HAIR_S,
					   stroke_width=5, stroke_linecap="round"))
		bb = union(bbox_pts(pts, SW / 2), (-38, -128, 0, -96))
	elif kind == "wet":
		# plastered down: the volume is GONE -- a sad comb-over across a shiny dome + drippy hanks
		cap = [(-62, 40), (-62, 18), (-50, -4), (-26, -16), (2, -20), (30, -16), (50, -8), (58, 2), (46, 2),
			   (26, -6), (4, -8), (-18, -4), (-36, 6), (-46, 24), (-48, 44)]
		d = smooth_closed(cap, 0.5)
		it += shaded(d, P.HAIR_S, P.HAIR_D, (-24, -6), 0.84)
		it += [path(smooth_open([(-50, 26), (-32, 4), (0, -12), (30, -10), (50, -2)], 0.5), sw=DET)]
		hank = [(-62, 24), (-50, 30), (-52, 70), (-60, 96), (-70, 72)]
		it += shaded(smooth_closed(hank, 0.5), P.HAIR_S, P.HAIR_D, (-58, 40), 0.8)
		for (x0, y0, x1, y1) in ((40, -2, 46, 12), (52, 0, 60, 10), (28, -6, 30, 8)):
			dd = "M%s %s Q%s %s %s %s" % (f(x0), f(y0), f(x0 + 4), f(y0 + 8), f(x1), f(y1))
			it.append(path(dd, stroke=INK, stroke_width=10, stroke_linecap="round"))
			it.append(path(dd, stroke=P.HAIR_S, stroke_width=4, stroke_linecap="round"))
		for (x, y, s) in ((47, 22, 0.9), (61, 20, 0.75), (-62, 106, 1.1), (-42, 60, 0.8), (-70, 50, 0.7)):
			it += drop(x, y, s)
		bb = (-80, -26, 70, 120)
	elif kind == "poodle":
		# balled into a tight pom-pom (small curls) + a pink bow
		c0 = (-14, -40)
		ring = []
		for i in range(14):
			a = -math.pi / 2 + 2 * math.pi * i / 14
			ring.append((c0[0] + 34 * math.cos(a), c0[1] + 30 * math.sin(a), 14))
		inner = [(c0[0] + 16 * math.cos(a), c0[1] + 14 * math.sin(a), 16) for a in [i * 2 * math.pi / 5 for i in range(5)]]
		inner.append((c0[0], c0[1], 18))
		cl = ring + inner
		it += _lobes(cl, P.HAIR, P.HAIR_S, (c0[0] - 14, c0[1] - 16), 0.86)
		for x, y, r in ring[1::2]:
			it.append(path("M%s %s a5 5 0 1 1 7 4" % (f(x - 4), f(y - 1)), sw=2.8))
		bx, by = c0[0] - 40, c0[1] - 30
		bow = [(bx, by), (bx - 18, by - 14), (bx - 22, by + 6), (bx - 4, by + 10)]
		bow2 = [(bx, by), (bx + 16, by - 18), (bx + 22, by), (bx + 6, by + 10)]
		it += shaded(smooth_closed(bow, 0.5), P.POODLE_BOW, "#E0619A", (bx - 10, by - 4), 0.8, sw=4.5)
		it += shaded(smooth_closed(bow2, 0.5), P.POODLE_BOW, "#E0619A", (bx + 12, by - 8), 0.8, sw=4.5)
		it.append(circle(bx, by + 4, 6, fill=P.POODLE_BOW, stroke=INK, stroke_width=4.5))
		bb = union(_bbox_circles(cl), (bx - 26, by - 22, bx + 26, by + 16))
	elif kind == "flipped":
		# the whole bouffant has flopped forward over his face like a mop -> BLINDED
		mop = [(-72, 10), (-70, -18), (-46, -40), (-8, -48), (34, -40), (68, -18), (86, 12), (92, 44),
			   (90, 70), (82, 86), (72, 70), (62, 90), (50, 72), (38, 92), (26, 72), (12, 86), (4, 62),
			   (-10, 66), (-14, 44), (-34, 34), (-56, 34)]
		d = smooth_closed(mop, 0.4)
		it += shaded(d, P.HAIR, P.HAIR_S, (0, -14), 0.86, hl=(4, -32, 22, 7, -8))
		it += [path(smooth_open([(20, -20), (48, 2), (64, 40), (70, 70)], 0.5), sw=DET),
			   path(smooth_open([(0, -12), (24, 20), (38, 56), (40, 78)], 0.5), sw=DET),
			   path(smooth_open([(-30, -22), (-6, 0), (10, 30), (14, 54)], 0.5), sw=DET)]
		bb = bbox_pts(mop, SW / 2)
	else:
		raise ValueError(kind)
	return Part("bouffant_" + kind, it, bb)


def feather(x, y, ang, s=1.0, col=None, shade=None):
	"""A small white feather (quill + vane) at (x, y) rotated by `ang` degrees; ~34 px long at s=1."""
	col = col or P.FEATHER
	shade = shade or P.FEATHER_S
	vane = [(0, -18), (7, -10), (8, 4), (4, 14), (0, 16), (-4, 12), (-6, 0), (-5, -12)]
	vane = xform(vane, dx=x, dy=y, sx=s, sy=s, ang=ang)
	quill = xform([(0, -14), (1, 22)], dx=x, dy=y, sx=s, sy=s, ang=ang)
	d = smooth_closed(vane, 0.6)
	out = [path(d, fill=shade), path(d, fill=col, transform="translate(%s %s)" % (f(-1.2 * s), f(-1.2 * s)))]
	out.append(path(d, sw=3.5))
	out.append(path("M%s %s L%s %s" % (f(quill[0][0]), f(quill[0][1]), f(quill[1][0]), f(quill[1][1])), sw=2.5))
	return out


def drop(x, y, s=1.0, col=None, shade=None):
	"""A water drop (teardrop, point up) centred at (x, y)."""
	col = col or P.WATER
	shade = shade or P.WATER_S
	pts = xform([(0, -12), (6, -2), (7, 5), (3, 10), (-3, 10), (-7, 5), (-6, -2)], dx=x, dy=y, sx=s, sy=s)
	d = smooth_closed(pts, 0.6)
	return [path(d, fill=shade), path(d, fill=col, transform="translate(%s %s)" % (f(-1 * s), f(-1 * s))),
			path(d, sw=3), circle(x - 2 * s, y + 2 * s, 1.6 * s, fill=P.WHITE)]


# ---------------------------------------------------------------------------------------------
# Sideburns (mutton chops). Near (r): pivot at the temple (head (-30, -100)), a narrow sideburn in front of the
# ear that broadens into a chop sweeping forward along the jaw. Far (l): a tuft behind the far jowl.
SB_R_EXTRA = (-46, -12, 58, 150)
SB_L_EXTRA = (-14, -14, 50, 100)


def _chop_curls(it, pts):
	for (x, y, a) in pts:
		it.append(path("M%s %s a6 6 0 0 1 %s %s" % (f(x), f(y), f(6 * math.cos(math.radians(a))), f(6 * math.sin(math.radians(a)))),
					   sw=DET))


def sideburn(kind, far=False):
	it = []
	b, s = (P.HAIR, P.HAIR_S)
	if not far:
		if kind == "flat":
			strip = [(-7, -2), (7, -2), (8, 20), (6, 46), (-8, 50), (-12, 24)]
			cl = [(-6, 52, 13), (-2, 66, 15), (10, 78, 16), (25, 83, 13), (37, 80, 9.5), (8, 62, 12)]
			it += _lobes(cl, b, s, (-10, 38), 0.82, polys=[strip])
			_chop_curls(it, [(-8, 50, 60), (6, 72, 40), (20, 78, 0)])
			bb = _bbox_circles(cl)
		elif kind == "bristle":
			pts = [(-6, 0), (7, 1), (10, 20), (22, 26), (14, 40), (32, 50), (24, 60), (46, 68), (34, 80), (44, 96),
				   (24, 92), (16, 108), (2, 96), (-12, 106), (-12, 88), (-30, 84), (-20, 68), (-32, 54), (-16, 46),
				   (-22, 28), (-10, 20)]
			d = smooth_closed(pts, 0.1)
			it += shaded(d, b, s, (0, 40), 0.8)
			it += [path("M0 52 L8 66", sw=DET), path("M-4 74 L6 86", sw=DET)]
			bb = bbox_pts(pts, SW / 2)
		elif kind == "puffed":
			strip = [(-7, -2), (7, -2), (8, 20), (6, 40), (-8, 42), (-12, 20)]
			cl = [(-4, 36, 20), (10, 64, 27), (-14, 72, 23), (2, 96, 24), (30, 90, 22)]
			it += _lobes(cl, b, s, (-6, 50), 0.84, polys=[strip])
			_chop_curls(it, [(-12, 58, 40), (6, 86, 20), (26, 84, 0)])
			bb = _bbox_circles(cl)
		elif kind == "wet":
			# drooping like wet spaniel ears
			pts = [(-6, 0), (7, 1), (10, 40), (12, 80), (8, 108), (-2, 124), (-12, 110), (-16, 80), (-14, 40)]
			d = smooth_closed(pts, 0.6)
			it += shaded(d, P.HAIR_S, P.HAIR_D, (-4, 30), 0.82)
			it += [path(smooth_open([(-2, 30), (0, 70), (-2, 104)], 0.6), sw=DET)]
			it += drop(0, 132, 0.9)
			it += drop(-20, 98, 0.7)
			bb = (-28, -4, 18, 146)
	else:
		b, s = (P.HAIR_S, P.HAIR_D)
		if kind == "flat":
			cl = [(2, 6, 7), (8, 18, 10), (14, 30, 9)]
			it += _lobes(cl, b, s, (4, 12), 0.82)
			bb = _bbox_circles(cl)
		elif kind == "bristle":
			pts = [(-4, 0), (10, 2), (20, 10), (36, 6), (28, 22), (44, 30), (26, 38), (28, 54), (12, 46), (0, 52),
				   (-4, 36), (-8, 16)]
			d = smooth_closed(pts, 0.1)
			it += shaded(d, b, s, (4, 18), 0.82)
			bb = bbox_pts(pts, SW / 2)
		elif kind == "puffed":
			cl = [(6, 10, 12), (18, 28, 18), (6, 42, 16), (28, 48, 14)]
			it += _lobes(cl, b, s, (4, 24), 0.84)
			bb = _bbox_circles(cl)
		elif kind == "wet":
			pts = [(-4, 0), (10, 2), (14, 30), (14, 62), (8, 78), (0, 68), (-4, 34)]
			d = smooth_closed(pts, 0.6)
			it += shaded(d, P.HAIR_D, "#767C94", (4, 20), 0.82)
			it += drop(8, 86, 0.8)
			bb = (-10, -4, 20, 98)
	return Part("sideburn_%s_%s" % ("l" if far else "r", kind), it, bb)
