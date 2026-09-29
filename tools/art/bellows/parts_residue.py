"""Residue, costume and combo looks (GDD §5.4, §9.2). Every overlay is authored in its PART's local coords and
written on that part's canvas (same size, same pivot), so it follows the part exactly. Overlays on invisible limb
bones use the bone pivot (the joint) as their canvas origin.

rig.json gets:
  "residues": {KIND: {"tex": {part: texture}, "overlays": {part: file | [files]}, "face_overlays": [slot],
                      "limb_fill": {limb: "#hex"}, "props": {prop: "part:socket"}, "blind": {...}},
               "COSTUME": {"default": v, "variants": {v: {...same keys...}}}}
  "combos":   {id: {"of": [KIND, KIND], "replaces": [KIND, KIND], ...same keys...}}
"""
import math
from svgk import (Part, path, circle, ellipse, rect, g, smooth_closed, smooth_open, shaded, highlight, bbox_pts, union,
				  xform, f, qcurve, sample_closed, clipped_lines, ellipse_pts, cloud_pts, point_in, INK, SW, DET)
import palette as P
import parts_head as H
import parts_body as B

KINDS = ["SOAKED", "FLOURY", "STICKY", "SQUEAKY", "FRAZZLED", "FEATHERED", "COSTUME"]
COSTUMES = ["jelly_helmet", "tutu_tulle", "tutu_chandelier", "trophy_helmet", "long_johns", "hedge_twigs",
			"umbrella_stand"]
COMBOS = ["dough_man", "poodle", "chicken", "mad_maestro"]


# --- helpers -----------------------------------------------------------------------------------

def goo_drip(x, y, length, w, col, col_l, sw=3.5):
	"""A thick drip hanging from (x, y): a tapering stalk ending in a round drop."""
	pts = [(x - w, y), (x + w, y), (x + w * 0.55, y + length * 0.6), (x + w * 0.9, y + length),
		   (x, y + length + w * 0.9), (x - w * 0.9, y + length), (x - w * 0.55, y + length * 0.6)]
	d = smooth_closed(pts, 0.6)
	return [path(d, fill=col, sw=sw), ellipse(x - w * 0.3, y + length * 0.9, w * 0.25, w * 0.4, fill=col_l, fill_opacity="0.8")]


def goo_blob(cx, cy, rx, ry, col, col_l, seed=1, sw=3.5, drips=()):
	pts = ellipse_pts(cx, cy, rx, ry, 14, wobble=0.14, seed=seed)
	out = [path(smooth_closed(pts, 0.6), fill=col, sw=sw)]
	for (dx, L, w) in drips:
		out += goo_drip(cx + dx, cy + ry * 0.6, L, w, col, col_l, sw)
	out.append(highlight(cx - rx * 0.35, cy - ry * 0.3, rx * 0.3, ry * 0.18, -20, 0.6))
	return out


def powder(cx, cy, rx, ry, seed=1, col=P.FLOUR, op="0.92"):
	pts = cloud_pts(cx, cy, rx, ry, 7, 0.18, 5, jitter=0.2, seed=seed)
	d = smooth_closed(pts, 0.6)
	return [path(d, fill=col, fill_opacity=op), path(d, stroke=P.FLOUR_S, stroke_width=2, fill="none")]


def specks(pts, col=P.FLOUR, r=2.2):
	return [circle(x, y, r, fill=col, stroke=P.FLOUR_S, stroke_width=1.2) for x, y in pts]


def inset_poly(sil, s, c):
	return [(c[0] + (x - c[0]) * s, c[1] + (y - c[1]) * s) for x, y in sil]


def wet_patch(pts, col, op="0.45"):
	return [path(smooth_closed(pts, 0.6), fill=col, fill_opacity=op)]


def feathers(lst, col=None, shade=None):
	out = []
	for (x, y, a, s) in lst:
		out += H.feather(x, y, a, s, col, shade)
	return out


def leaf(x, y, a, s=1.0):
	pts = xform([(0, -12), (6, -4), (5, 6), (0, 12), (-5, 6), (-6, -4)], dx=x, dy=y, sx=s, sy=s, ang=a)
	d = smooth_closed(pts, 0.7)
	mid = xform([(0, -10), (0, 10)], dx=x, dy=y, sx=s, sy=s, ang=a)
	return [path(d, fill=P.LEAF, sw=3), path("M%s %s L%s %s" % (f(mid[0][0]), f(mid[0][1]), f(mid[1][0]), f(mid[1][1])),
											 stroke=P.LEAF_S, stroke_width=2.2)]


def twig(x0, y0, x1, y1):
	d = "M%s %s L%s %s" % (f(x0), f(y0), f(x1), f(y1))
	mx, my = (x0 + x1) / 2, (y0 + y1) / 2
	br = "M%s %s L%s %s" % (f(mx), f(my), f(mx + (y1 - y0) * 0.3), f(my - (x1 - x0) * 0.3))
	return [path(d, stroke=INK, stroke_width=7, stroke_linecap="round"), path(d, stroke=P.TWIG, stroke_width=3.2, stroke_linecap="round"),
			path(br, stroke=INK, stroke_width=6, stroke_linecap="round"), path(br, stroke=P.TWIG, stroke_width=2.6, stroke_linecap="round")]


def P_(name, items, bb):
	return Part(name, items, bb)


# --- SOAKED ------------------------------------------------------------------------------------

def soaked():
	o = {}
	it = []
	for (x, y, s) in ((-40, -98, 1.0), (-14, -112, 0.8), (62, -96, 0.9), (68, -46, 1.0), (56, 6, 1.1), (18, 22, 0.9),
					  (-48, -24, 0.8)):
		it += H.drop(x, y, s)
	it.append(path(qcurve((-24, -60), (-28, -40), (-24, -24)), stroke=P.WHITE, stroke_width=3, stroke_linecap="round", stroke_opacity="0.6"))
	o["head"] = P_("soaked_head", it, (-60, -128, 80, 40))
	it = wet_patch([(-60, -124), (-20, -146), (30, -148), (40, -120), (0, -106), (-50, -96)], P.PLUM_D)
	it += wet_patch([(-78, -60), (-62, -80), (-50, -40), (-62, 0), (-78, -10)], P.PLUM_D)
	for (x, y, s) in ((-56, 36, 1.0), (-16, 40, 0.8), (18, 38, 1.1), (-70, 18, 0.7)):
		it += H.drop(x, y, s)
	o["torso"] = P_("soaked_torso", it, (-86, -152, 50, 56))
	it = wet_patch([(-24, -120), (10, -128), (30, -100), (4, -84), (-20, -96)], P.CREAM_S, "0.8")
	for (x, y, s) in ((20, 20, 1.0), (-4, 26, 0.8)):
		it += H.drop(x, y, s)
	o["belly"] = P_("soaked_belly", it, (-40, -134, 44, 44))
	return o


# --- FLOURY ------------------------------------------------------------------------------------

def floury():
	o = {}
	c = (6, -58)
	sil = inset_poly(H.HEAD_SIL, 0.9, c)
	it = [path(smooth_closed(sil, 0.6), fill=P.FLOUR, fill_opacity="0.82")]
	it += specks([(-50, -110), (74, -70), (70, 0), (-46, 8), (20, 24)])
	o["head"] = P_("floury_head", it, (-60, -126, 80, 30))
	it = powder(-26, -136, 52, 18, 3) + powder(34, -144, 30, 12, 5) + powder(-60, -104, 18, 12, 7)
	it += [path(smooth_open([(-74, -122), (-40, -148), (10, -152), (50, -146)], 0.6), stroke=P.FLOUR_S, stroke_width=2.5)]
	it += specks([(-80, -150), (10, -162), (60, -154), (-88, -118), (-40, -100), (20, -118), (-66, -60)])
	it += powder(-66, -40, 14, 22, 9) + powder(-50, 6, 18, 10, 13)
	o["torso"] = P_("floury_torso", it, (-96, -168, 76, 22))
	it = powder(24, -86, 22, 14, 9) + powder(34, -40, 16, 18, 11) + specks([(4, -110), (40, -120), (10, -20)])
	o["belly"] = P_("floury_belly", it, (-40, -140, 60, 0))
	o["arm_upper_r"] = P_("floury_arm_upper_r", powder(0, 18, 12, 14, 15), (-16, 0, 16, 36))
	o["arm_lower_r"] = P_("floury_arm_lower_r", powder(2, 16, 12, 12, 17), (-16, 0, 16, 32))
	for side in ("r", "l"):
		it = powder(-2, 14, 13, 9, 13) + specks([(10, 4), (-12, 22)])
		o["hand_" + side] = P_("floury_hand_" + side, it, (-20, 0, 18, 30))
	return o


# --- STICKY ------------------------------------------------------------------------------------

def sticky():
	o = {}
	col, cl = P.TREACLE, P.TREACLE_L
	it = []
	it += goo_drip(-36, -112, 26, 6, col, cl)
	it += goo_drip(-8, -120, 12, 5, col, cl)
	it += goo_drip(64, -100, 30, 5.5, col, cl)
	it += goo_drip(58, -20, 18, 5, col, cl)
	o["head"] = P_("sticky_head", it, (-48, -126, 76, 8))
	it = goo_blob(-8, -150, 26, 12, col, cl, 3, drips=((-14, 20, 5), (10, 30, 6))) + goo_blob(70, -120, 14, 9, col, cl, 5, drips=((0, 22, 5),))
	o["torso"] = P_("sticky_torso", it, (-40, -168, 90, -70))
	it = goo_blob(-10, -34, 18, 10, col, cl, 7, drips=((4, 34, 7),)) + goo_blob(40, 20, 14, 8, col, cl, 9, drips=((0, 16, 5),))
	o["bouffant"] = P_("sticky_bouffant", it, (-34, -50, 60, 64))
	# a teaspoon stuck to the back of his right hand (+ a gob of treacle)
	it = []
	sp = "M-4 18 L-36 -6"
	it.append(path(sp, stroke=INK, stroke_width=8.5, stroke_linecap="round"))
	it.append(path(sp, stroke=P.METAL, stroke_width=4, stroke_linecap="round"))
	bowl = xform([(-8, -6), (0, -9), (8, -6), (8, 6), (0, 10), (-8, 6)], dx=-40, dy=-9, ang=-54)
	it.append(path(smooth_closed(bowl, 0.7), fill=P.METAL, sw=4))
	it += goo_blob(-2, 18, 10, 7, col, cl, 11, drips=((2, 12, 4),))
	o["hand_r"] = P_("sticky_spoon", it, (-56, -24, 16, 44))
	return o


# --- FEATHERED -------------------------------------------------------------------------------

BONE_FEATHERS = {"arm_upper_r": [(-8, 14, -60, 0.8), (10, 28, 70, 0.75)],
				 "arm_lower_r": [(-10, 12, -80, 0.75), (8, 26, 60, 0.8)],
				 "leg_lower_r": [(-10, 10, -70, 0.7), (10, 16, 80, 0.7)],
				 "arm_upper_l": [(10, 20, 60, 0.7)]}


def feathered():
	o = {}
	o["head"] = P_("feathered_head", feathers([(-46, -40, -50, 0.9), (70, -28, 60, 0.8), (-30, -118, -30, 0.8)]), (-76, -148, 98, -2))
	o["nose"] = P_("feathered_nose", feathers([(40, 44, 110, 0.7)]), (20, 22, 66, 66))
	o["torso"] = P_("feathered_torso", feathers([(-60, -110, -40, 1.0), (-20, -140, 10, 0.9), (-76, -40, -80, 0.9),
												 (-30, -60, 20, 0.9), (20, -130, 40, 0.8), (-50, 10, -120, 0.8)]),
					(-104, -170, 50, 34))
	o["belly"] = P_("feathered_belly", feathers([(20, -90, 50, 0.9), (30, -30, 80, 0.9)]), (-8, -120, 64, -6))
	for bone, fl in BONE_FEATHERS.items():
		o[bone] = P_("feathered_" + bone, feathers(fl), (-30, -14, 34, 48))
	return o


# --- COSTUMES ----------------------------------------------------------------------------------

def tutu_tulle():
	it = []
	# tiers of pink tulle round his waist (torso y ~ 0), wider than the barrel
	for (cy, rx, ry, col, sh, seed) in ((6, 128, 30, P.TULLE_S, P.TULLE_S, 1), (-4, 118, 26, P.TULLE, P.TULLE_S, 3)):
		pts = cloud_pts(10, cy, rx, ry, 16, 0.12, 5, jitter=0.1, seed=seed)
		d = smooth_closed(pts, 0.6)
		it.append(path(d, fill=col, sw=5))
	it.append(ellipse(10, -12, 96, 12, fill=P.TULLE_S))
	it.append(path(smooth_open([(-84, -14), (10, -6), (102, -14)], 0.6), sw=DET))
	for x in (-90, -50, -10, 30, 70, 110):
		it.append(path("M%d %d L%d %d" % (x, -4, x + 6, 20), stroke=P.WHITE, stroke_width=2.5, stroke_opacity="0.6", stroke_linecap="round"))
	return P_("tutu_tulle", it, (-122, -34, 142, 40))


def tutu_chandelier():
	it = []
	# the brass ring round his waist, crystal drops hanging, candles standing
	for x in range(-86, 110, 22):
		d = "M%d 8 L%d 26" % (x, x)
		it.append(path(d, stroke=INK, stroke_width=4))
		it.append(path(smooth_closed([(x, 22), (x + 5, 30), (x, 40), (x - 5, 30)], 0.6), fill=P.CRYSTAL, sw=3))
	for (x, h) in ((-80, 34), (-40, 40), (4, 44), (48, 40), (90, 34)):
		it.append(rect(x - 6, -h - 4, 12, h, rx=3, fill=P.CREAM, sw=4))
		it.append(path(smooth_closed([(x, -h - 24), (x + 7, -h - 12), (x, -h - 4), (x - 7, -h - 12)], 0.6), fill=P.FLAME, sw=3))
		it.append(path(smooth_closed([(x, -h - 18), (x + 3, -h - 11), (x, -h - 7), (x - 3, -h - 11)], 0.6), fill=P.FLAME_C))
		it.append(ellipse(x, -4, 12, 5, fill=P.BRASS, sw=3))
	d = smooth_closed(ellipse_pts(4, 2, 108, 14, 24), 0.6)
	it.append(path(d, fill="none", stroke=INK, stroke_width=16))
	it.append(path(d, fill="none", stroke=P.BRASS, stroke_width=9))
	it.append(path(smooth_open([(-90, -2), (4, 12), (96, -2)], 0.6), stroke=P.BRASS_S, stroke_width=4))
	return P_("tutu_chandelier", it, (-122, -74, 132, 48))


def trophy_helmet():
	"""'Best Baritone 1987' upturned over his head. Bouffant-local; the rim sits on his brow line (y ~ +4)."""
	it = []
	cup = [(-84, 8), (-80, -30), (-60, -62), (-26, -76), (16, -76), (50, -62), (70, -30), (74, 8)]
	d = smooth_closed(cup, 0.45)
	# handles (ears of the cup)
	for sgn, x0 in ((-1, -80), (1, 70)):
		hd = "M%d -40 C%d -44 %d -4 %d 0" % (x0, x0 + sgn * 34, x0 + sgn * 34, x0 + sgn * 2)
		it.append(path(hd, stroke=INK, stroke_width=14, stroke_linecap="round"))
		it.append(path(hd, stroke=P.GOLD, stroke_width=7, stroke_linecap="round"))
	it += shaded(d, P.GOLD, P.GOLD_S, (-30, -40), 0.86, sw=6, hl=(-44, -40, 14, 22, 10))
	it.append(rect(-90, 0, 170, 14, rx=6, fill=P.GOLD_S, sw=5))   # rim band on his brow
	# the foot/stem sticking up
	it.append(rect(-18, -96, 28, 22, rx=5, fill=P.GOLD_S, sw=5))
	it.append(rect(-34, -110, 60, 16, rx=6, fill=P.GOLD, sw=5))
	it.append(rect(-26, -50, 44, 20, rx=3, fill=P.CREAM, stroke=INK, stroke_width=3.5))   # the plaque (no text)
	it.append(path("M-18 -40 L10 -40", stroke=P.GOLD_S, stroke_width=3))
	return P_("trophy_helmet", it, (-122, -118, 112, 20))


def long_johns():
	o = {}
	for side in ("r", "l"):
		for seg in ("upper", "lower"):
			bone = "leg_%s_%s" % (seg, side)
			pts = [(-6, 6), (7, 16), (-4, 24)] if seg == "upper" else [(5, 6), (-6, 14), (4, 22)]
			o[bone] = P_("lj_" + bone, [circle(x, y, 4.2, fill=P.SPOT) for x, y in pts], (-12, 0, 12, 30))
	# the split seat: a ripped jacket back revealing red spotty long johns
	it = []
	rip = [(-78, -30), (-66, -40), (-58, -26), (-48, -38), (-40, -22), (-30, -30), (-26, 6), (-52, 16), (-74, 6)]
	d = smooth_closed(rip, 0.15)
	it.append(path(d, fill=P.LONGJOHN, sw=4.5))
	for (x, y) in ((-64, -18), (-44, -10), (-58, 2), (-36, 0)):
		it.append(circle(x, y, 4.5, fill=P.SPOT))
	o["torso"] = P_("lj_seat", it, (-84, -46, -20, 22))
	o["coat_tails"] = P_("lj_tails_rip", [path("M-20 20 L-12 30 L-22 40 L-12 50", sw=4)], (-28, 12, -6, 58))
	return o


def hedge_twigs():
	o = {}
	it = twig(-60, -40, -100, -70) + twig(30, -60, 50, -100) + twig(-20, -70, -30, -104) + twig(70, -30, 100, -50)
	for (x, y, a) in ((-96, -60, -30), (44, -90, 30), (-26, -96, 0), (92, -46, 60), (-70, 10, -80), (10, -50, 20)):
		it += leaf(x, y, a)
	o["bouffant"] = P_("hedge_bouffant", it, (-114, -114, 110, 24))
	it = twig(-70, -90, -100, -110) + twig(40, -140, 60, -160)
	for (x, y, a) in ((-96, -104, -40), (58, -154, 30), (-40, -130, 10), (-74, -30, -70), (-20, -20, 20), (-60, 10, -100),
					  (-84, -70, -60), (-50, -90, 30), (-30, -50, -20), (-72, -120, 20), (-86, -10, -90)):
		it += leaf(x, y, a, 1.1)
	o["torso"] = P_("hedge_torso", it, (-112, -170, 72, 28))
	it = []
	for (x, y, a) in ((20, -100, 40), (36, -50, 80), (14, -20, 120)):
		it += leaf(x, y, a, 1.1)
	it += twig(30, -80, 60, -96)
	o["belly"] = P_("hedge_belly", it, (-10, -120, 70, 0))
	o["head"] = P_("hedge_head", leaf(-44, -30, -60, 0.9) + leaf(66, -10, 70, 0.8), (-60, -46, 84, 8))
	return o


def umbrella_stand():
	it = []
	# a blue-and-white ceramic stand swallowing him from the waist down (torso y -10 .. +54 -> world -74 .. -10)
	body = [(-58, -14), (60, -14), (56, 50), (46, 58), (-44, 58), (-54, 50)]
	d = smooth_closed(body, 0.2)
	# an umbrella and a walking stick sticking out behind him
	st = "M-40 -20 L-66 -120"
	it.append(path(st, stroke=INK, stroke_width=10, stroke_linecap="round"))
	it.append(path(st, stroke=P.WOOD, stroke_width=5, stroke_linecap="round"))
	it.append(path("M-66 -120 C-70 -138 -90 -136 -88 -122", stroke=INK, stroke_width=10, stroke_linecap="round"))
	it.append(path("M-66 -120 C-70 -138 -90 -136 -88 -122", stroke=P.WOOD, stroke_width=5, stroke_linecap="round"))
	br = [(-28, -18), (-50, -70), (-38, -90), (-16, -70), (-10, -18)]
	it.append(path(smooth_closed(br, 0.4), fill=P.BROLLY, sw=4.5))
	it.append(path("M-38 -88 L-40 -104", sw=4))
	it += shaded(d, P.CERAMIC, P.CERAMIC_S, (-10, 10), 0.86, sw=6, hl=(-36, 14, 6, 16, 0))
	it.append(ellipse(1, -14, 60, 10, fill=P.CERAMIC_S, sw=6))
	it.append(ellipse(1, -16, 50, 6, fill=INK, fill_opacity="0.6"))
	for y in (10, 36):
		it.append(path("M-54 %d Q2 %d 58 %d" % (y, y + 8, y), stroke=P.WHITE, stroke_width=4))
	for x in (-30, 0, 30):
		it.append(circle(x, 23, 5, fill=P.WHITE, stroke=INK, stroke_width=2))
	return P_("umbrella_stand", it, (-96, -146, 70, 66))


# --- COMBOS ------------------------------------------------------------------------------------

DOUGH_S2 = "#C9A866"


def dough_man():
	o = {}
	col, sh = P.DOUGH, P.DOUGH_S

	def lumps(cl, seed):
		out = []
		for i, (x, y, r) in enumerate(cl):
			pts = ellipse_pts(x, y, r, r * 0.84, 16, wobble=0.05, seed=seed + i)
			d = smooth_closed(pts, 0.8)
			out.append(path(d, fill=sh))
			out.append(path(d, fill=col, transform="translate(%s %s) scale(0.86) translate(%s %s)" % (
				f(x - r * 0.2), f(y - r * 0.2), f(-(x - r * 0.2)), f(-(y - r * 0.2)))))
			out.append(path(d, stroke=INK, stroke_width=3.5, fill="none"))
			out.append(circle(x - r * 0.35, y - r * 0.35, max(2.0, r * 0.12), fill=P.FLOUR, fill_opacity="0.8"))
		return out

	sil = inset_poly(H.HEAD_SIL, 0.9, (6, -58))
	it = [path(smooth_closed(sil, 0.6), fill=col, fill_opacity="0.9")]
	it += lumps([(-40, -100, 14), (58, -104, 12), (-44, -10, 12), (62, -18, 10)], 1)
	o["head"] = P_("dough_head", it, (-60, -126, 80, 12))
	o["torso"] = P_("dough_torso", lumps([(-50, -120, 26), (0, -136, 20), (-70, -60, 18), (-50, 0, 20), (-10, -60, 22)], 11),
					(-92, -164, 26, 26))
	o["belly"] = P_("dough_belly", lumps([(10, -100, 20), (30, -40, 18), (0, -10, 14)], 21), (-16, -126, 54, 12))
	ball = ellipse_pts(-10, -24, 88, 52, 24, wobble=0.04, seed=31)
	d = smooth_closed(ball, 0.8)
	it = [path(d, fill=sh), path(d, fill=col, transform="translate(-30 -40) scale(0.9) translate(30 40)"),
		  path(d, sw=SW), highlight(-40, -52, 26, 9, -15, 0.5)]
	it += [path("M20 -40 q8 6 16 0", sw=DET), path("M-50 -10 q8 6 16 0", sw=DET), circle(40, -10, 3, fill=DOUGH_S2)]
	o["bouffant"] = P_("dough_bouffant", it, (-104, -82, 84, 34))
	for side in ("r", "l"):
		o["hand_" + side] = P_("dough_hand_" + side, lumps([(0, 16, 14)], 41), (-20, -4, 20, 34))
	return o


def chicken():
	o = {}
	fc, fs = P.FEATHER, P.FEATHER_S
	# a red rooster comb on top of the bouffant
	comb = [(-40, -70), (-34, -100), (-22, -80), (-10, -112), (2, -84), (16, -108), (22, -76), (34, -94), (36, -66)]
	it = [path(smooth_closed(comb, 0.35), fill=P.COMB_RED, sw=5)]
	it.append(path(smooth_open([(-30, -80), (0, -88), (28, -80)], 0.6), stroke="#B8243A", stroke_width=3))
	o["bouffant"] = P_("chicken_comb", it, (-46, -118, 42, -60))
	# a wattle under his chin
	wat = [(20, 6), (34, 4), (40, 20), (34, 36), (24, 34), (18, 20)]
	o["head"] = P_("chicken_wattle", [path(smooth_closed(wat, 0.7), fill=P.COMB_RED, sw=4.5),
									  ellipse(26, 18, 3, 6, fill=P.WHITE, fill_opacity="0.5")], (12, -2, 46, 42))
	dense = []
	for yy in range(-140, 20, 34):
		for xx in range(-76, 60, 36):
			if point_in(B.TORSO_SIL, (xx, yy)):
				dense.append((xx + (yy % 3) * 4, yy, -30 + ((xx + yy) % 60), 0.95))
	o["torso"] = P_("chicken_torso", feathers(dense, fc, fs), (-104, -172, 86, 44))
	o["belly"] = P_("chicken_belly", feathers([(10, -110, 30, 0.9), (30, -70, 60, 0.9), (20, -30, 80, 0.9), (0, -10, 100, 0.8)], fc, fs),
					(-20, -134, 58, 14))
	for bone, fl in BONE_FEATHERS.items():
		more = fl + [(0, 40, 10, 0.7)] if "leg" not in bone else fl
		o[bone] = P_("chicken_" + bone, feathers(more, fc, fs), (-30, -14, 34, 64))
	return o


def mad_maestro():
	# extra electric frizz spikes shooting out of the frazzled bouffant
	it = []
	for (x0, y0, x1, y1) in ((-60, -60, -110, -106), (0, -78, 4, -130), (50, -64, 92, -110), (-90, -10, -136, -20),
							 (80, -26, 124, -40)):
		d = "M%s %s L%s %s L%s %s L%s %s" % (f(x0), f(y0), f((x0 * 2 + x1) / 3 + 8), f((y0 * 2 + y1) / 3), f((x0 + x1 * 2) / 3 - 8),
											  f((y0 + y1 * 2) / 3), f(x1), f(y1))
		it.append(path(d, stroke=INK, stroke_width=11, stroke_linecap="round", stroke_linejoin="round"))
		it.append(path(d, stroke=P.HAIR, stroke_width=5, stroke_linecap="round", stroke_linejoin="round"))
	return {"bouffant": P_("maestro_frizz", it, (-142, -136, 130, -4))}


# --- assembly ----------------------------------------------------------------------------------

def _looks():
	"""key -> {part: Part}"""
	L = {"SOAKED": soaked(), "FLOURY": floury(), "STICKY": sticky(), "FEATHERED": feathered(),
		 "COSTUME/tutu_tulle": {"torso": tutu_tulle()}, "COSTUME/tutu_chandelier": {"torso": tutu_chandelier()},
		 "COSTUME/trophy_helmet": {"bouffant": trophy_helmet()}, "COSTUME/long_johns": long_johns(),
		 "COSTUME/hedge_twigs": hedge_twigs(), "COSTUME/umbrella_stand": {"torso": umbrella_stand()},
		 "combo/dough_man": dough_man(), "combo/chicken": chicken(), "combo/mad_maestro": mad_maestro()}
	return L


def overlays():
	out = {}
	for key, parts in _looks().items():
		for part, p in parts.items():
			out[(key, part)] = p
	return out


def residue_map(canvases, disk, res):
	written = []
	files = {}
	for key, parts in _looks().items():
		for part, p in parts.items():
			cv = canvases[part]
			rel = "residue/%s.svg" % p.name
			written.append(disk_write(disk(rel), p.svg(cv)))
			files.setdefault(key, {})[part] = res(rel)
	R = {
		"SOAKED": {"tex": {"bouffant": "wet", "sideburn_l": "wet", "sideburn_r": "wet"}, "overlays": files["SOAKED"]},
		"FLOURY": {"tex": {"bouffant": "floured"}, "overlays": files["FLOURY"]},
		"STICKY": {"overlays": files["STICKY"]},
		"SQUEAKY": {"face_overlays": ["pinch", "hiccup"]},
		"FRAZZLED": {"tex": {"bouffant": "frazzled"}, "face_overlays": ["singe"],
					 "blind": {"tex": {"bouffant": "flipped"}}},
		"FEATHERED": {"tex": {"bouffant": "feathered"}, "overlays": files["FEATHERED"]},
		"COSTUME": {"default": "tutu_tulle", "variants": {
			"jelly_helmet": {"props": {"jelly_helmet": "head:hat", "sausage_boa": "torso:neck"}},
			"tutu_tulle": {"overlays": files["COSTUME/tutu_tulle"], "tex": {"foot_l": "tiptoe", "foot_r": "tiptoe"}},
			"tutu_chandelier": {"overlays": files["COSTUME/tutu_chandelier"], "tex": {"foot_l": "tiptoe", "foot_r": "tiptoe"}},
			"trophy_helmet": {"overlays": files["COSTUME/trophy_helmet"]},
			"long_johns": {"overlays": files["COSTUME/long_johns"], "limb_fill": {"leg_r": P.LONGJOHN, "leg_l": P.LONGJOHN_S}},
			"hedge_twigs": {"overlays": files["COSTUME/hedge_twigs"]},
			"umbrella_stand": {"overlays": files["COSTUME/umbrella_stand"]},
		}},
	}
	C = {
		"dough_man": {"of": ["SOAKED", "FLOURY"], "replaces": ["SOAKED", "FLOURY"],
					  "tex": {"bouffant": "wet", "sideburn_l": "wet", "sideburn_r": "wet"}, "overlays": files["combo/dough_man"]},
		"poodle": {"of": ["SOAKED", "FRAZZLED"], "replaces": ["SOAKED", "FRAZZLED"],
				   "tex": {"bouffant": "poodle", "sideburn_l": "puffed", "sideburn_r": "puffed"}},
		"chicken": {"of": ["STICKY", "FEATHERED"], "replaces": ["STICKY", "FEATHERED"],
					"tex": {"bouffant": "feathered"}, "overlays": files["combo/chicken"]},
		"mad_maestro": {"of": ["FRAZZLED", "SQUEAKY"], "replaces": ["FRAZZLED", "SQUEAKY"],
						"tex": {"bouffant": "frazzled"}, "overlays": files["combo/mad_maestro"],
						"face_overlays": ["singe", "hiccup"], "props": {"baton": "hand_r:grip"}},
	}
	# Flat keys, one per look, so RigPlayer.set_residue(key, on) can show a costume variant or a combo with the
	# plain residue parser (tex + overlays): "COSTUME:<variant>", "COMBO:<id>". "COSTUME" itself = its default.
	for v, lk in R["COSTUME"]["variants"].items():
		R["COSTUME:" + v] = dict(lk)
	dflt = R["COSTUME"]["variants"][R["COSTUME"]["default"]]
	R["COSTUME"].update({k: v for k, v in dflt.items() if k in ("tex", "overlays")})
	for c, lk in C.items():
		R["COMBO:" + c] = {k: v for k, v in lk.items() if k in ("tex", "overlays", "face_overlays", "props", "limb_fill")}
	return R, C, written


def disk_write(p, s):
	from svgk import write
	return write(p, s)
