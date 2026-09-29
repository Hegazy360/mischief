"""Body parts: torso (jacket barrel), belly (shirt-front bulge), coat tails, cravat, hands, slippers.
All coordinates are part-local with the joint (pivot) at (0, 0); y down; the character faces +x.
Near-side parts end in `_r` (drawn over the torso), far-side parts in `_l` (behind, pre-darkened)."""
import math
from svgk import (Part, path, circle, ellipse, rect, g, line, smooth_closed, smooth_open, shaded, highlight,
				  bbox_pts, union, rot, xform, f, qcurve, INK, SW, DET, sample_closed, clipped_lines)
import palette as P

# ---------------------------------------------------------------------------------------------
# Torso: pivot = hip centre (world (0, -64) at rest). The whole egg-shaped barrel, so the belly
# spring can never reveal a hole. Local y: hem at ~+24, shoulders at ~-148.
TORSO_SIL = [(-10, -150), (-44, -138), (-68, -112), (-81, -72), (-80, -28), (-71, 8), (-42, 21), (0, 25),
			 (36, 19), (62, 7), (82, -12), (96, -40), (99, -68), (93, -98), (78, -124), (58, -142), (30, -152)]

# the belly (shirt-front bulge) lives on the lower front; its bottom-centre is the spring pivot
BELLY_PIVOT_T = (56, 10)   # in torso coords


def torso():
	it = []
	d = smooth_closed(TORSO_SIL, 0.55)
	# high stand-up collar behind the neck (drawn first: the head covers most of it)
	col = [(-22, -146), (-26, -168), (-8, -176), (14, -170), (22, -152)]
	it += shaded(smooth_closed(col, 0.6), P.PLUM_S, P.PLUM_D, (-14, -168), 0.8)
	it += shaded(d, P.PLUM, P.PLUM_S, (-38, -96), 0.87,
				 hl=(-52, -104, 16, 7, -52))
	# back seam and side-seam folds
	it.append(path(smooth_open([(-58, -120), (-70, -80), (-68, -30)], 0.6), sw=DET))
	it.append(path(qcurve((-40, 10), (-20, 18), (0, 19)), sw=DET))
	# lapel (near side): broad plum-shade lapel from the collar down the chest
	lap = [(10, -150), (34, -150), (50, -130), (46, -104), (34, -86), (26, -104), (14, -128)]
	it += shaded(smooth_closed(lap, 0.5), P.PLUM_S, P.PLUM_D, (20, -140), 0.78, sw=DET)
	# notch
	it.append(path("M36 -128 L46 -134", sw=DET))
	# boutonniere (a red carnation) on the lapel
	for (x, y, r) in ((30, -120, 5.5), (36, -124, 5), (34, -116, 5)):
		it.append(circle(x, y, r, fill=P.TARTAN, stroke=INK, stroke_width=3))
	it.append(circle(33, -121, 3.2, fill="#E8506A"))
	# back-waist buttons where the tails hang
	for x in (-58, -46):
		it.append(circle(x, -24, 4.2, fill=P.GOLD, stroke=INK, stroke_width=3))
	bb = bbox_pts(TORSO_SIL + col, SW / 2)
	return Part("torso", it, bb)


# ---------------------------------------------------------------------------------------------
BELLY_SIL_T = [(24, -118), (46, -128), (72, -128), (88, -112), (100, -84), (103, -60), (99, -36),
			   (84, -10), (62, 6), (36, 19), (22, 12), (18, -30), (18, -80)]


def belly():
	"""Cream shirt front bursting out of the cut-away tailcoat, three straining buttons.
	Local coords: pivot at its bottom-centre (the waistband), so a sy spring bobs the top."""
	px, py = BELLY_PIVOT_T
	L = lambda pts: [(x - px, y - py) for x, y in pts]
	sil = L(BELLY_SIL_T)
	it = []
	# plum jacket strip (near front panel) behind/left of the shirt: same plum as the torso, no outline on the
	# inner edge so the seam is invisible; its front edge is an ink detail line
	strip = L([(18, -118), (40, -122), (44, -96), (46, -60), (42, -24), (34, 4), (24, 14), (16, -30), (14, -80)])
	it.append(path(smooth_closed(strip, 0.5), fill=P.PLUM))
	shirt = L([(40, -122), (62, -128), (80, -124), (92, -108), (101, -84), (104, -60), (99, -36), (84, -10),
			   (62, 6), (40, 14), (44, -24), (48, -60), (46, -96)])
	ds = smooth_closed(shirt, 0.5)
	it += shaded(ds, P.CREAM, P.CREAM_S, L([(52, -96)])[0], 0.84, sw=0,
				 hl=(66 - px, -100 - py, 10, 5, -40))
	# jacket front edge over the shirt (the cut-away curve)
	it.append(path(smooth_open(L([(40, -124), (46, -96), (48, -60), (44, -24), (34, 6)]), 0.6), sw=DET))
	# the silhouette outline: front + bottom only (top/left merge into the torso)
	it.append(path(smooth_open(L([(80, -124), (92, -108), (101, -84), (104, -60), (99, -36), (84, -10),
								  (62, 6), (36, 19)]), 0.55), sw=SW))
	# straining buttons with stress creases
	for (bx, by) in ((70, -96), (78, -64), (76, -32)):
		x, y = bx - px, by - py
		it.append(path("M%s %s L%s %s L%s %s" % (f(x - 12), f(y - 7), f(x - 4), f(y), f(x - 12), f(y + 7)),
					   sw=2.5, stroke=P.CREAM_S))
		it.append(path("M%s %s L%s %s L%s %s" % (f(x + 12), f(y - 7), f(x + 4), f(y), f(x + 12), f(y + 7)),
					   sw=2.5, stroke=P.CREAM_S))
		it.append(circle(x, y, 5.2, fill=P.GOLD, stroke=INK, stroke_width=3))
		it.append(circle(x - 1.5, y - 1.5, 1.4, fill=P.WHITE))
	return Part("belly", it, bbox_pts(sil + strip, SW / 2))


# ---------------------------------------------------------------------------------------------
def coat_tails():
	"""Swallowtails hanging from the back waist (pivot) down the back of his calves; behind the legs."""
	it = []
	back = [(-2, -6), (8, -2), (8, 30), (4, 56), (-6, 68), (-14, 56), (-14, 24), (-10, -2)]
	front = [(-10, -4), (-2, 4), (-6, 34), (-12, 60), (-22, 72), (-32, 62), (-30, 30), (-22, 0)]
	it += shaded(smooth_closed(back, 0.5), PLUM_D2, P.PLUM_D, (-4, 10), 0.84)
	it += shaded(smooth_closed(front, 0.5), P.PLUM_S, P.PLUM_D, (-18, 12), 0.84)
	it.append(path(qcurve((-14, 10), (-18, 36), (-22, 60)), sw=DET))
	return Part("coat_tails", it, bbox_pts(back + front, SW / 2))


PLUM_D2 = "#57296B"


# ---------------------------------------------------------------------------------------------
def cravat():
	"""Puffed gold cravat (an opera-singer's ascot): a fat knot (pivot), a ruffled fall and a pearl pin."""
	it = []
	fall = [(-16, 2), (-26, 22), (-24, 40), (-12, 50), (4, 46), (16, 52), (28, 40), (26, 20), (14, 2)]
	it += shaded(smooth_closed(fall, 0.6), P.GOLD, P.GOLD_S, (-6, 12), 0.84)
	it += [path(qcurve((-10, 14), (-14, 30), (-8, 44)), sw=DET), path(qcurve((10, 14), (8, 32), (14, 46)), sw=DET)]
	knot = [(-26, -8), (-14, -18), (4, -20), (22, -14), (28, 0), (18, 12), (0, 14), (-18, 10), (-28, 4)]
	it += shaded(smooth_closed(knot, 0.6), P.GOLD, P.GOLD_S, (-8, -8), 0.84, hl=(-8, -10, 9, 3.5, -12))
	it.append(path(qcurve((-14, -12), (-6, -2), (-12, 8)), sw=DET))
	it.append(path(qcurve((14, -14), (8, -2), (16, 8)), sw=DET))
	it.append(circle(2, 0, 5, fill=P.WHITE, stroke=INK, stroke_width=3))
	return Part("cravat", it, bbox_pts(fall + knot, SW / 2))


# ---------------------------------------------------------------------------------------------
# Hands: bare, pudgy, four fingers, a frilly cream cuff. Local: wrist (pivot) at (0,0), hand hangs
# along +y at rot 0; the thumb is on the +x (front) side. `far` = hand_l (pre-darkened).
HAND_KINDS = ["open", "fist", "point", "grip", "wag", "conduct"]
HAND_EXTRA = (-34, -12, 36, 66)  # common canvas for all six shapes


def _cols(far):
	return (P.SKIN_S, P.SKIN_D) if far else (P.SKIN, P.SKIN_S)


def _cuff(far):
	b, s = (P.CREAM_S, "#CDB791") if far else (P.CREAM, P.CREAM_S)
	pts = [(-17, -6), (-10, -10), (0, -8), (10, -10), (17, -6), (16, 6), (8, 9), (0, 7), (-8, 9), (-16, 6)]
	return shaded(smooth_closed(pts, 0.7), b, s, (-6, -4), 0.8, sw=4.5)


def _finger(x0, y0, x1, y1, w, far, detail=True):
	"""A capsule finger with shade on the +x/+y side; returns (items, pts for bbox)."""
	b, s = _cols(far)
	d = "M%s %s L%s %s" % (f(x0), f(y0), f(x1), f(y1))
	out = [path(d, stroke=INK, stroke_width=w + SW, stroke_linecap="round"),
		   path(d, stroke=s, stroke_width=w, stroke_linecap="round"),
		   path("M%s %s L%s %s" % (f(x0 - w * 0.12), f(y0 - w * 0.05), f(x1 - w * 0.12), f(y1 - w * 0.08)),
				stroke=b, stroke_width=w * 0.6, stroke_linecap="round")]
	return out


def _blob(pts, far, c, s=0.82, t=0.7):
	b, sh = _cols(far)
	return shaded(smooth_closed(pts, t), b, sh, c, s)


def hand(kind, far=False):
	it = []
	b, s = _cols(far)
	if kind == "open":
		# palm toward the viewer, fingers spread in a fan, thumb out front
		fingers = [(-13, 30, -21, 54), (-4, 34, -6, 60), (5, 34, 8, 59), (13, 30, 20, 50)]
		for x0, y0, x1, y1 in fingers:
			it += _finger(x0, y0, x1, y1, 11.5, far)
		it += _finger(14, 14, 28, 26, 11.5, far)
		palm = [(-15, 4), (0, 1), (15, 4), (19, 20), (15, 36), (0, 40), (-15, 36), (-19, 20)]
		it += _blob(palm, far, (-6, 14), 0.8)
		it.append(path(qcurve((-6, 26), (0, 30), (8, 24)), sw=2.8))
	elif kind == "fist":
		for i, x in enumerate((-12, -4, 4)):
			it += _finger(x, 36, x + 1, 38, 11.5, far)
		fist = [(-18, 6), (0, 2), (16, 6), (20, 22), (17, 38), (4, 44), (-12, 43), (-20, 30)]
		it += _blob(fist, far, (-7, 16), 0.8)
		it += [path("M-12 33 Q-10 38 -6 38", sw=2.8), path("M-3 34 Q-1 39 3 39", sw=2.8), path("M6 33 Q8 38 11 37", sw=2.8)]
		# thumb wrapped across the front
		it += _finger(15, 18, 6, 28, 11, far)
	elif kind == "point":
		it += _finger(8, 30, 10, 62, 11, far)       # index finger straight along the axis
		fist = [(-17, 6), (0, 2), (15, 6), (19, 22), (16, 36), (4, 41), (-12, 40), (-19, 28)]
		it += _blob(fist, far, (-7, 16), 0.8)
		it += [path("M-12 32 Q-10 37 -6 37", sw=2.8), path("M-3 33 Q-1 38 3 38", sw=2.8)]
		it += _finger(16, 16, 22, 30, 10.5, far)     # thumb tucked up front
	elif kind == "grip":
		# fingers curled round a handle (hole centre at (4, 34)), pinky out -- pompous
		it += _finger(-12, 34, -24, 52, 10, far)      # extended pinky
		palm = [(-16, 6), (0, 2), (15, 6), (18, 20), (12, 30), (-2, 30), (-16, 26)]
		it += _blob(palm, far, (-6, 12), 0.8)
		for (x0, y0, x1, y1) in ((-4, 28, -8, 44), (4, 29, 2, 46), (12, 27, 14, 42)):
			it += _finger(x0, y0, x1, y1, 10.5, far)
		it += _finger(14, 14, 22, 32, 10.5, far)      # thumb over the handle
	elif kind == "wag":
		# palm to the viewer, index finger up the axis, others curled, thumb pinning them
		it += _finger(8, 30, 14, 64, 11, far)
		palm = [(-15, 5), (0, 1), (15, 5), (18, 22), (14, 38), (0, 42), (-14, 38), (-18, 22)]
		it += _blob(palm, far, (-6, 14), 0.8)
		it += [path("M-11 30 Q-6 36 0 32", sw=2.8), path("M-12 22 Q-6 26 -1 24", sw=2.8)]
		it += _finger(-14, 16, -4, 30, 10, far)
		it.append(path("M24 50 Q28 56 26 62", sw=2.8))   # a little 'tut-tut' tick mark
	elif kind == "conduct":
		# delicate pinch (thumb + index) at (10, 36); middle/ring/pinky fanned out elegantly
		for (x0, y0, x1, y1) in ((-4, 30, -12, 54), (-12, 28, -24, 48), (-16, 22, -30, 36)):
			it += _finger(x0, y0, x1, y1, 9.5, far)
		palm = [(-16, 5), (0, 1), (15, 5), (18, 20), (12, 32), (-4, 32), (-16, 24)]
		it += _blob(palm, far, (-6, 12), 0.8)
		it += _finger(4, 28, 10, 40, 10, far)          # index curling to the pinch
		it += _finger(16, 16, 14, 36, 10, far)         # thumb meeting it
	it = _cuff(far) + it
	return Part("hand_%s_%s" % ("l" if far else "r", kind), it, HAND_EXTRA)


GRIP = {"open": (6, 30), "fist": (2, 26), "point": (2, 26), "grip": (4, 36), "wag": (2, 24), "conduct": (12, 38)}


# ---------------------------------------------------------------------------------------------
# Tartan slippers. Local: ankle (pivot) at (0,0); the sole sits 12 px below; toe to +x.
FOOT_EXTRA = (-24, -12, 56, 38)


def _tartan(pts, far, t=0.55):
	"""Tartan checks clipped inside the slipper outline `pts` (green bands + a thin gold line)."""
	poly = sample_closed(pts, t)
	x0, y0, x1, y1 = bbox_pts(pts)
	g_col = "#24533D" if far else P.TARTAN_G
	segs = [((x, y0 - 4), (x - 6, y1 + 4)) for x in range(int(x0) + 8, int(x1) + 6, 13)]
	out = clipped_lines(poly, segs, 3.0, stroke=g_col, stroke_width=4, stroke_opacity="0.55")
	ym = (y0 + y1) / 2
	out += clipped_lines(poly, [((x0 - 2, ym), (x1 + 2, ym - 2))], 3.0, stroke=g_col, stroke_width=4,
						 stroke_opacity="0.55")
	out += clipped_lines(poly, [((x0 - 2, ym + 5), (x1 + 2, ym + 3)), ((x0 + 14, y0 - 4), (x0 + 8, y1 + 4))], 3.0,
						 stroke=P.TARTAN_Y, stroke_width=1.8)
	return out


def foot(kind, far=False):
	b, s = (P.TARTAN_S, "#7E1F2B") if far else (P.TARTAN, P.TARTAN_S)
	sock = (P.CREAM_S if far else P.CREAM)
	pom = P.GOLD_S if far else P.GOLD
	it = []
	it.append(rect(-9, -9, 18, 13, rx=5, fill=sock, stroke=INK, stroke_width=4.5))   # sock / ankle
	if kind == "flat":
		up = [(-18, 4), (-12, -4), (6, -5), (26, -2), (42, 3), (50, 10), (48, 14), (-14, 14), (-20, 10)]
		d = smooth_closed(up, 0.55)
		it.append(path(d, fill=b))
		it += _tartan(up, far)
		it.append(path(d, sw=5))
		it.append(path("M-18 14 L48 14", sw=5.5))     # sole line
		it.append(circle(28, -3, 7, fill=pom, stroke=INK, stroke_width=3.5))  # pom-pom on the instep
	else:  # tiptoe: on pointe, heel lifted -- a pointed slipper whose tip reaches exactly the flat sole's depth, so
		# swapping flat <-> tiptoe (the tutu costumes) never dips the foot below the floor (rig request RIG-13)
		up = [(-11, 1), (1, -6), (16, -4), (30, 2), (41, 9), (46, 13), (40, 15), (24, 12), (8, 10), (-7, 8)]
		d = smooth_closed(up, 0.55)
		it.append(path(d, fill=b))
		it += _tartan(up, far)
		it.append(path(d, sw=5))
		it.append(circle(16, 1, 6.5, fill=pom, stroke=INK, stroke_width=3.5))
	return Part("foot_%s_%s" % ("l" if far else "r", kind), it, FOOT_EXTRA)


# Lowest sole points (foot-local, ink included) used to plant poses on the floor line.
FOOT_SOLE = {"flat": [(-18, 16.8), (15, 16.8), (48, 16.8)], "tiptoe": [(40, 17.5), (46, 15.5)]}
