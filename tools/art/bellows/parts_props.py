"""Props in the Bellows rig. Prop-local origin = its attach point (the grip / socket point) = the prop's pivot.
Hand-held props are drawn 'upright for a forward-pointing forearm': canvas +x = forward (along the fingers, since
the hand sockets turn props by 90 deg), canvas -y = up. Interactable-prop line weights: 5 px outline, 3 px detail."""
import math
import os
from svgk import (Part, path, circle, ellipse, rect, g, line, smooth_closed, smooth_open, shaded, highlight, bbox_pts,
				  union, xform, f, qcurve, sample_closed, clipped_lines, clip_convex, poly_path, ellipse_pts, INK)
import palette as P

PSW = 5.0
PDET = 3.0


# --- specs -------------------------------------------------------------------------------------
# Pivot = the bridge over his nose (head:specs = head (34, -72)). Near lens around the near eye at (-28, 2),
# far lens around the far eye at (20, 0). `dangling` hangs from torso:chain with the same pivot = the chain top.
LN = (-28, 2)
LF = (20, 0)


def _rim(cx, cy, rx, ry, lens=True, glare=True, thick=3.6):
	out = []
	if lens:
		out.append(ellipse(cx, cy, rx, ry, fill=P.LENS, fill_opacity="0.32"))
	out.append(ellipse(cx, cy, rx, ry, fill="none", stroke=INK, stroke_width=thick + 4))
	out.append(ellipse(cx, cy, rx, ry, fill="none", stroke=P.GOLD, stroke_width=thick))
	if glare:
		out.append(path(qcurve((cx - rx * 0.55, cy - ry * 0.2), (cx - rx * 0.45, cy - ry * 0.6), (cx - rx * 0.05, cy - ry * 0.7)),
						stroke=P.WHITE, stroke_width=3, stroke_linecap="round", stroke_opacity="0.8"))
	return out


def _bridge_and_arm(rn=(20, 21), rf=(15, 19)):
	out = []
	br = qcurve((LN[0] + rn[0] - 1, LN[1] - 6), (-4, -12), (LF[0] - rf[0] + 1, LF[1] - 6))
	arm = smooth_open([(LN[0] - rn[0], LN[1] - 4), (-66, -2), (-86, 8)], 0.6)
	for d in (br, arm):
		out.append(path(d, stroke=INK, stroke_width=7.5, stroke_linecap="round"))
		out.append(path(d, stroke=P.GOLD, stroke_width=3.5, stroke_linecap="round"))
	# a short loop of chain hanging off the arm (the chain it dangles on)
	for i in range(4):
		out.append(circle(-80 + i * 1.5, 14 + i * 7, 2.6, fill=P.GOLD, stroke=INK, stroke_width=1.8))
	return out


def specs(state):
	it = []
	if state in ("on", "buttered"):
		it += _bridge_and_arm()
		it += _rim(LN[0], LN[1], 20, 21) + _rim(LF[0], LF[1], 15, 19)
		if state == "buttered":
			for (cx, cy, rx, ry) in ((LN[0], LN[1], 20, 21), (LF[0], LF[1], 15, 19)):
				blob = ellipse_pts(cx + 1, cy, rx * 0.95, ry * 0.9, 18, wobble=0.12, seed=int(cx))
				d = smooth_closed(blob, 0.6)
				it.append(path(d, fill=P.BUTTER_S))
				it.append(path(d, fill=P.BUTTER, transform="translate(-1.5 -1.5)"))
				it.append(path(d, stroke=INK, stroke_width=2.5, fill="none"))
				# knife streaks
				it.append(path(qcurve((cx - rx * 0.6, cy - 4), (cx, cy + 4), (cx + rx * 0.6, cy - 2)), stroke=P.WHITE,
							   stroke_width=3, stroke_linecap="round", stroke_opacity="0.7"))
			it.append(ellipse(-4, 24, 7, 4, fill=P.BUTTER, stroke=INK, stroke_width=2.5))   # a dollop on his nose
	elif state == "magnifier":
		# bottle-bottom magnifying lenses: fat rims + concentric rings around the ballooned eyes
		it += _bridge_and_arm((30, 31), (26, 29))
		for (cx, cy, r) in ((LN[0], LN[1] - 2, 31), (LF[0], LF[1] - 4, 28)):
			it.append(circle(cx, cy, r, fill=P.LENS, fill_opacity="0.25"))
			it.append(circle(cx, cy, r * 0.72, fill="none", stroke=P.WHITE, stroke_width=2.5, stroke_opacity="0.6"))
			it.append(circle(cx, cy, r, fill="none", stroke=INK, stroke_width=11))
			it.append(circle(cx, cy, r, fill="none", stroke=P.GOLD, stroke_width=6))
			it.append(path(qcurve((cx - r * 0.6, cy - r * 0.1), (cx - r * 0.5, cy - r * 0.6), (cx - r * 0.1, cy - r * 0.72)),
						   stroke=P.WHITE, stroke_width=4, stroke_linecap="round", stroke_opacity="0.85"))
	elif state == "dangling":
		# hanging on its chain (pivot = chain top at the lapel), folded, lenses catching the light
		for i in range(6):
			it.append(circle(1 + i * 0.6, 3 + i * 5.2, 2.6, fill=P.GOLD, stroke=INK, stroke_width=1.8))
		it += _rim(-6, 44, 11, 12, glare=True, thick=3.2)
		it += _rim(12, 42, 10, 12, glare=False, thick=3.2)
		d = qcurve((4, 40), (3, 36), (2, 34))
		it.append(path(d, stroke=INK, stroke_width=6.5, stroke_linecap="round"))
		it.append(path(d, stroke=P.GOLD, stroke_width=3, stroke_linecap="round"))
	return Part("specs_" + state, it, (-96, -38, 60, 64))


# --- hand-held props (+x = forward along the fingers) --------------------------------------------

def teacup(state="held"):
	"""`held`: handle at the grip, cup body forward (+x). `sip`: the same cup mirrored -- handle forward, body back
	toward his face -- so a sip keeps the hand in front of the mouth and the pinkie clear (art-bellows weak spot)."""
	if state == "sip":
		p = teacup("held")
		return Part("teacup_sip", ['<g transform="scale(-1 1)">%s</g>' % "".join(p.items)], (-44, -22, 16, 24))
	it = []
	# handle loop at the grip (0, 0), cup body forward (+x)
	it.append(path("M-2 -8 C-12 -8 -12 10 -2 10", stroke=INK, stroke_width=9, stroke_linecap="round"))
	it.append(path("M-2 -8 C-12 -8 -12 10 -2 10", stroke=P.PORCELAIN, stroke_width=3.5, stroke_linecap="round"))
	body = [(-4, -14), (38, -14), (36, 2), (28, 14), (8, 14), (-2, 2)]
	d = smooth_closed(body, 0.4)
	it += shaded(d, P.PORCELAIN, P.PORCELAIN_S, (10, -8), 0.84, sw=PSW)
	it.append(path("M0 -4 Q17 2 35 -4", stroke=P.CHINA_BLUE, stroke_width=4, stroke_linecap="round"))
	for x in (8, 17, 26):
		it.append(circle(x, 3, 2.2, fill=P.CHINA_BLUE))
	it.append(ellipse(17, -14, 21, 4.5, fill=P.TEA, sw=4))
	it.append(ellipse(17, -14, 21, 4.5, fill="none", stroke=P.GOLD, stroke_width=2))
	it.append(path("M4 20 L32 20", stroke=INK, stroke_width=6, stroke_linecap="round"))   # little foot
	return Part("teacup", it, (-16, -22, 44, 24))


def newspaper(state):
	it = []
	if state == "closed":
		# a folded broadsheet: held at one end
		pts = [(-6, -9), (58, -11), (62, 8), (-4, 10)]
		d = smooth_closed(pts, 0.15)
		it += shaded(d, P.PAPER, P.PAPER_S, (20, -4), 0.8, sw=PSW)
		it.append(path("M4 -2 L50 -4", stroke=P.PAPER_INK, stroke_width=3))
		it.append(path("M4 4 L44 3", stroke=P.PAPER_INK, stroke_width=3))
		it.append(path("M56 -10 L60 8", sw=PDET))
		bb = (-16, -18, 70, 16)
	else:
		# spread open, held up at its near-left edge (the grip at (0, 0))
		sheet = [(-6, -70), (70, -76), (148, -70), (150, 36), (72, 42), (-4, 36)]
		d = smooth_closed(sheet, 0.08)
		it += shaded(d, P.PAPER, P.PAPER_S, (40, -40), 0.9, sw=PSW)
		it.append(path("M72 -74 L72 40", sw=PDET))   # the fold
		# headline blocks + columns (no text)
		it.append(rect(6, -60, 56, 12, rx=2, fill=P.PAPER_INK))
		it.append(rect(82, -62, 56, 12, rx=2, fill=P.PAPER_INK))
		it.append(rect(84, -40, 30, 26, rx=2, fill=P.PAPER_S, stroke=P.PAPER_INK, stroke_width=2.5))
		for x0, x1, ys in ((6, 62, range(-40, 30, 8)), (118, 140, range(-40, 0, 8)), (84, 140, range(0, 30, 8))):
			for y in ys:
				it.append(path("M%d %d L%d %d" % (x0, y, x1, y), stroke=P.PAPER_INK, stroke_width=2.4, stroke_opacity="0.7"))
		bb = (-14, -84, 158, 50)
	return Part("newspaper_" + state, it, bb)


def comb():
	it = []
	spine = [(-6, -6), (54, -8), (56, 0), (-6, 2)]
	it.append(path(smooth_closed(spine, 0.2), fill=P.TORT, sw=4))
	it.append(path("M2 -3 L44 -4", stroke=P.TORT_L, stroke_width=2.5, stroke_linecap="round"))
	segs = [((x, 0), (x, 14)) for x in range(4, 54, 5)]
	for (a, b) in segs:
		it.append(path("M%s %s L%s %s" % (f(a[0]), f(a[1]), f(b[0]), f(b[1])), stroke=INK, stroke_width=4.5, stroke_linecap="round"))
		it.append(path("M%s %s L%s %s" % (f(a[0]), f(a[1] + 1), f(b[0]), f(b[1] - 1)), stroke=P.TORT, stroke_width=1.8, stroke_linecap="round"))
	return Part("comb", it, (-12, -14, 62, 20))


def baton():
	it = []
	d = "M-6 0 L70 -4"
	it.append(path(d, stroke=INK, stroke_width=8, stroke_linecap="round"))
	it.append(path(d, stroke=P.WHITE, stroke_width=3.5, stroke_linecap="round"))
	it.append(ellipse(-4, 0.2, 9, 6.5, fill=P.WOOD, sw=3.5))   # cork grip
	return Part("baton", it, (-18, -12, 78, 10))


def phone_handset():
	"""Bakelite dog-bone handset gripped round its middle in a fist: earpiece up (-y), mouthpiece down (+y),
	cups facing forward (+x). In a thumb-up fist the long axis runs across the fingers, as a real grip does."""
	it = []
	d = smooth_open([(8, -44), (-2, -20), (-2, 20), (8, 44)], 0.5)
	it.append(path(d, stroke=INK, stroke_width=17, stroke_linecap="round"))
	it.append(path(d, stroke=P.BAKELITE, stroke_width=10, stroke_linecap="round"))
	it.append(path(smooth_open([(4, -30), (-2, 0), (4, 30)], 0.5), stroke=P.BAKELITE_L, stroke_width=3, stroke_linecap="round"))
	for (cy, ang) in ((-46, -20), (46, 20)):
		cup = xform([(-2, -13), (-2, 13), (12, 10), (12, -10)], dx=10, dy=cy, ang=ang)
		it.append(path(smooth_closed(cup, 0.3), fill=P.BAKELITE, sw=4.5))
		dots = xform([(8, -5), (8, 0), (8, 5)], dx=10, dy=cy, ang=ang)
		it += [circle(x, y, 1.6, fill=P.BAKELITE_L) for x, y in dots]
	cord = [(-8, 10), (-18, 14), (-24, 6), (-32, 12), (-38, 4), (-46, 10)]
	it.append(path(smooth_open(cord, 0.8), stroke=P.BAKELITE, stroke_width=3.5, stroke_linecap="round"))
	return Part("phone_handset", it, (-54, -64, 30, 64))


def kipper_held():
	"""A smoked kipper held exactly like the handset: head up (-y), tail down (+y), gripped round the middle."""
	it = []
	body = [(-2, -50), (-12, -40), (-16, -10), (-12, 24), (-4, 40), (4, 40), (10, 24), (12, -10), (8, -40)]
	d = smooth_closed(body, 0.55)
	it += shaded(d, P.KIPPER, P.KIPPER_S, (-8, -10), 0.84, sw=PSW, hl=(-8, -18, 3, 14, 4))
	tail = [(0, 38), (-16, 58), (0, 54), (16, 58)]
	it.append(path(smooth_closed(tail, 0.3), fill=P.KIPPER_S, sw=4.5))
	it.append(path(smooth_open([(-2, -30), (0, 0), (-1, 30)], 0.5), stroke=P.KIPPER_B, stroke_width=3, stroke_linecap="round"))
	for y in (-20, -6, 8, 22):
		it.append(path("M-9 %d Q-2 %d 6 %d" % (y, y + 4, y), sw=2.4))
	it.append(circle(-3, -38, 4.2, fill=P.WHITE, stroke=INK, stroke_width=2.5))
	it.append(circle(-2.5, -37.5, 1.8, fill=INK))
	it.append(path("M2 -50 Q5 -46 4 -42", sw=2.4))   # mouth
	return Part("kipper_held", it, (-24, -58, 24, 66))


def pickled_onion():
	it = []
	pts = [(0, -30), (6, -22), (14, -14), (16, -4), (10, 0), (-10, 0), (-16, -4), (-14, -14), (-6, -22)]
	d = smooth_closed(pts, 0.6)
	it += shaded(d, P.ONION, P.ONION_S, (-4, -16), 0.82, sw=PSW, hl=(-6, -14, 3, 5, 20))
	it.append(path("M0 -28 Q2 -36 -2 -40", sw=PDET))
	it.append(path("M-6 -20 Q-10 -10 -6 -2", stroke=P.ONION_S, stroke_width=2.5))
	it.append(path("M6 -20 Q10 -10 6 -2", stroke=P.ONION_S, stroke_width=2.5))
	return Part("pickled_onion", it, (-20, -44, 20, 4))


def kettle_lid():
	"""Pops onto his nose: pivot = head:specs (the bridge); the lid cups the nose tip at (34, 30)."""
	it = []
	cx, cy = 34, 30
	lid = xform([(-20, 6), (-18, -4), (-8, -10), (8, -10), (18, -4), (20, 6)], ang=-75)
	lid = [(x + cx, y + cy) for x, y in lid]
	d = smooth_closed(lid, 0.5)
	it += shaded(d, P.METAL, P.METAL_S, (cx - 4, cy - 6), 0.84, sw=PSW)
	rim = xform([(-22, 6), (22, 6)], ang=-75)
	rim = [(x + cx, y + cy) for x, y in rim]
	it.append(path("M%s %s L%s %s" % (f(rim[0][0]), f(rim[0][1]), f(rim[1][0]), f(rim[1][1])), sw=6.5))
	kn = xform([(0, -16)], ang=-75)[0]
	it.append(circle(cx + kn[0], cy + kn[1], 6, fill=INK))
	it.append(circle(cx + kn[0], cy + kn[1], 3.5, fill=P.BAKELITE_L))
	return Part("kettle_lid", it, (4, -2, 64, 62))


def jelly_helmet():
	"""A red jelly mould upturned over the bouffant. Pivot = head:hat (top of the bouffant)."""
	it = []
	dome = [(-96, 78), (-92, 40), (-70, 8), (-36, -8), (0, -12), (36, -8), (70, 8), (92, 40), (96, 78), (70, 88),
			(36, 80), (0, 90), (-36, 80), (-70, 88)]
	d = smooth_closed(dome, 0.55)
	it += shaded(d, P.JELLY, P.JELLY_S, (-30, 20), 0.86, sw=6, hl=(-44, 14, 20, 8, -25))
	# mould ridges
	for x in (-58, -20, 20, 58):
		it.append(path(qcurve((x * 0.5, -2), (x * 1.06, 30), (x, 82)), stroke=P.JELLY_S, stroke_width=5, stroke_linecap="round"))
	it.append(ellipse(-16, 30, 5, 9, fill=P.WHITE, fill_opacity="0.55"))
	# a wobble line + drips
	for (x, y) in ((-52, 88), (10, 94), (60, 90)):
		it.append(path(smooth_closed([(x, y - 4), (x + 5, y + 4), (x, y + 14), (x - 5, y + 4)], 0.7), fill=P.JELLY, sw=3.5))
	return Part("jelly_helmet", it, (-104, -20, 104, 112))


def sausage_boa():
	"""A string of sausages draped round his neck (pivot = torso:neck), hanging down his chest."""
	it = []
	links = [(-30, 6), (-18, 30), (-6, 54), (6, 74), (26, 80), (44, 70), (54, 48), (58, 22), (48, 2)]
	for i in range(len(links) - 1):
		a, b = links[i], links[i + 1]
		d = "M%s %s L%s %s" % (f(a[0] + (b[0] - a[0]) * 0.18), f(a[1] + (b[1] - a[1]) * 0.18),
							   f(b[0] - (b[0] - a[0]) * 0.18), f(b[1] - (b[1] - a[1]) * 0.18))
		it.append(path(d, stroke=INK, stroke_width=20, stroke_linecap="round"))
		it.append(path(d, stroke=P.SAUSAGE_S, stroke_width=13, stroke_linecap="round"))
		it.append(path("M%s %s L%s %s" % (f(a[0] + (b[0] - a[0]) * 0.22 - 2), f(a[1] + (b[1] - a[1]) * 0.22 - 2),
										   f(b[0] - (b[0] - a[0]) * 0.3 - 2), f(b[1] - (b[1] - a[1]) * 0.3 - 2)),
					   stroke=P.SAUSAGE, stroke_width=7, stroke_linecap="round"))
	for (x, y) in links[1:-1]:
		it.append(circle(x, y, 3.5, fill=P.CREAM, stroke=INK, stroke_width=2.5))   # twist ties
	# the dangling end
	d = "M-30 6 L-40 34"
	it.append(path(d, stroke=INK, stroke_width=20, stroke_linecap="round"))
	it.append(path(d, stroke=P.SAUSAGE_S, stroke_width=13, stroke_linecap="round"))
	it.append(path("M-32 10 L-39 28", stroke=P.SAUSAGE, stroke_width=7, stroke_linecap="round"))
	return Part("sausage_boa", it, (-54, -8, 72, 94))


def megaphone():
	it = []
	cone = [(-4, -8), (70, -26), (74, 0), (70, 26), (-4, 8)]
	d = smooth_closed(cone, 0.1)
	it += shaded(d, P.CREAM, P.CREAM_S, (20, -8), 0.84, sw=PSW)
	it.append(ellipse(72, 0, 7, 27, fill=P.MOUTH, sw=PSW))
	for x in (20, 44):
		it.append(path("M%d %s L%d %s" % (x, f(-8 - 18 * x / 74), x, f(8 + 18 * x / 74)), stroke=P.TARTAN, stroke_width=5))
	it.append(rect(-8, -8, 12, 16, rx=4, fill=P.WOOD, sw=4))
	it.append(path("M2 8 L6 26 L-4 26", stroke=INK, stroke_width=9, stroke_linecap="round", stroke_linejoin="round"))
	it.append(path("M2 8 L6 26 L-4 26", stroke=P.WOOD, stroke_width=4, stroke_linecap="round", stroke_linejoin="round"))
	return Part("megaphone", it, (-16, -34, 84, 34))


# --- the kitchen stool (s2-art's house decor, ridden through ACHOO-RIA!) -------------------------
# The SAME art as the house decor `kitchen_stool` (res://art/house/props/kitchen_stool.svg, s2-art contract: canvas
# 94 x 163, seat pivot [47, 6], floor contact [47, 156]), read at build time so a change to the house stool flows
# into the prop. It is PRE-MIRRORED: Bellows only uses it at st_tea facing -1, where the rig mirrors its props, so the
# prop drawn by a facing -1 rig is pixel-identical to the unmirrored house decor (the decor swap is invisible).
# Prop pivot = the stool's centre line at PropSim's rest height: PropSim rests a launched prop when its pivot is
# `radius` = max(canvas w, h) / 2 above the floor, so the pivot sits `radius` above the floor contact -- a stool that
# hops home lands with its feet exactly on the floor line, where the house decor stands.
HOUSE_STOOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "game", "art", "house",
						   "props", "kitchen_stool.svg")
STOOL_SEAT = (47, 6)      # house canvas px
STOOL_FOOT = (47, 156)    # house canvas px (floor contact)


def _stool_src():
	import re as _re
	src = open(os.path.normpath(HOUSE_STOOL)).read()
	m = _re.match(r"\s*<svg[^>]*>(.*)</svg>\s*$", src, _re.S)
	body = m.group(1)
	shadow = _re.match(r"(<ellipse[^>]*/>)", body)
	no_shadow = body[len(shadow.group(1)):] if shadow else body
	return body, no_shadow


def stool(state, pivot_y):
	"""`under` (on the floor, with its contact shadow) or `flying` (no shadow). Local origin = (47, pivot_y) of the
	house canvas, mirrored in x."""
	body, no_shadow = _stool_src()
	markup = body if state == "under" else no_shadow
	it = ['<g transform="translate(%s %s) scale(-1 1)">%s</g>' % (f(STOOL_SEAT[0]), f(-pivot_y), markup)]
	x0, y0 = -STOOL_SEAT[0], -pivot_y
	return Part("stool_" + state, it, (x0 - 1, y0 - 1, x0 + 95, y0 + 164))


def stool_pivot_y():
	"""The stool's pivot row in house canvas px: `radius` above the floor contact (see above)."""
	import svgk
	py = 80.0
	for _ in range(4):
		cv = svgk.shared_canvas([stool("under", py), stool("flying", py)])
		r = max(cv[0], cv[1]) / 2.0
		ny = STOOL_FOOT[1] - r
		if abs(ny - py) < 0.01:
			break
		py = ny
	return py


def props():
	"""name -> {states: {state|'_': Part}, default, socket, state_sockets, z}"""
	spy = stool_pivot_y()
	return {
		"specs": {"states": {s: specs(s) for s in ["dangling", "on", "buttered", "magnifier"]}, "default": "dangling",
				  "socket": "torso:chain", "z": 34, "visible": True,
				  "state_sockets": {"dangling": "torso:chain", "on": "head:specs", "buttered": "head:specs",
									"magnifier": "head:specs"},
				  "state_z_offset": {"on": 14, "buttered": 14, "magnifier": 14},
				  "note": "dangling hangs on its chain from torso:chain (default, visible); on/buttered/magnifier sit on "
						  "head:specs at head z + 14 (re-attach the prop to head:specs when switching state)"},
		"teacup": {"states": {"held": teacup("held"), "sip": teacup("sip")}, "default": "held", "socket": "hand_r:grip",
				   "z": 66},
		"newspaper": {"states": {"closed": newspaper("closed"), "open": newspaper("open")}, "default": "closed",
					  "socket": "hand_r:grip", "z": 62},
		"comb": {"states": {"_": comb()}, "socket": "hand_r:grip", "z": 66},
		"baton": {"states": {"_": baton()}, "socket": "hand_r:grip", "z": 62},
		"phone_handset": {"states": {"_": phone_handset()}, "socket": "hand_r:grip", "z": 58},
		"kipper_held": {"states": {"_": kipper_held()}, "socket": "hand_r:grip", "z": 58},
		"pickled_onion": {"states": {"_": pickled_onion()}, "socket": "head:hat", "z": 54},
		"kettle_lid": {"states": {"_": kettle_lid()}, "socket": "head:specs", "z": 53},
		"jelly_helmet": {"states": {"_": jelly_helmet()}, "socket": "head:hat", "z": 54},
		"sausage_boa": {"states": {"_": sausage_boa()}, "socket": "torso:neck", "z": 28},
		"megaphone": {"states": {"_": megaphone()}, "socket": "hand_r:grip", "z": 66},
		"stool": {"states": {"under": stool("under", spy), "flying": stool("flying", spy)}, "default": "under",
				  "socket": "torso:seat", "z": -1, "pivot_y": spy,
				  "note": "the kitchen stool (house decor kitchen_stool, pre-mirrored for facing -1): torso:seat puts its "
						  "cushion under the barrel; rides ACHOO-RIA! and hops home (PropSim launch) where the decor "
						  "reappears on the same pixels. Hidden by default; the sneeze shows it while the decor is hidden."},
	}
