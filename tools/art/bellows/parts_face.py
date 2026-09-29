"""Face slot art. Face-local origin = the face anchor (head (28, -44)); every slot canvas is centred on it
(pivot = canvas centre), so 'centered' and 'pivot' placement agree.
No skin-coloured fills here: face slots are NOT temper-tinted, so lids are drawn as ink, never as skin."""
import math
from svgk import (Part, path, circle, ellipse, rect, g, smooth_closed, smooth_open, highlight, bbox_pts, union,
				  xform, f, qcurve, sample_closed, clipped_lines, clip_convex, poly_path, ellipse_pts, INK, SW, DET)
import palette as P

EYE_N = (-26, -26)   # near (his right) eye centre
EYE_F = (22, -28)    # far eye centre
EYE_R = {"n": (15, 17), "f": (12, 15.5)}
PUPIL_N = (-23, -24)
PUPIL_F = (25, -26)
PUPIL_R = {"n": 8.5, "f": 7.5}
EYE_SW = 5.0

EYE_KINDS = ["open", "half", "closed", "wide", "pinpoint", "angry", "spiral", "balloon", "squint", "teary"]
NO_PUPILS = ["closed", "pinpoint", "spiral", "balloon", "squint"]
# eyes whose upper lid must cover the pupils: the `lids` slot (drawn ABOVE the pupils, skin-coloured and temper-tinted
# as the virtual part `face_lids`) carries the lid; presets pair them automatically.
LID_KINDS = ["half", "angry"]
EYE_LIDS = {"half": "half", "angry": "angry"}
LID_CUT = {"half": (-0.05, 0.0, 0.0), "angry": (0.25, 5.0, -5.0)}   # (cut, near tilt, far tilt)


def _eye(c, rx, ry, lid=True):
	out = [ellipse(c[0], c[1], rx, ry, fill=P.WHITE, sw=EYE_SW)]
	if lid:
		# a heavier upper-lid arc (character) — ink only
		a = [(c[0] - rx * 0.92, c[1] - ry * 0.3), (c[0] - rx * 0.4, c[1] - ry * 0.95), (c[0] + rx * 0.4, c[1] - ry * 0.95),
			 (c[0] + rx * 0.92, c[1] - ry * 0.3)]
		out.append(path(smooth_open(a, 0.6), sw=7))
	return out


def _half(c, rx, ry, cut, tilt=0.0):
	"""Eye white below a lid line at height `cut` (fraction of ry above centre, may be negative), lid tilted by
	`tilt` px (positive = the inner/nose side lower)."""
	n = 20
	yl = c[1] - ry * cut
	# lower half-ellipse points (angles 180..360 => y below centre)
	low = [(c[0] + rx * math.cos(a), c[1] + ry * math.sin(a)) for a in [math.pi - math.pi * i / n for i in range(n + 1)]]
	low = [(x, c[1] + abs(y - c[1])) for x, y in low]
	# upper part up to the lid line
	top = []
	for i in range(n + 1):
		a = math.pi * i / n
		x = c[0] - rx * math.cos(a)
		y = c[1] - ry * math.sin(a)
		t = (x - (c[0] - rx)) / (2 * rx)
		lid_y = yl + tilt * (t - 0.5) * 2
		top.append((x, max(y, lid_y)))
	poly = top + list(reversed(low))[1:-1]
	d = "M" + " L".join("%s %s" % (f(x), f(y)) for x, y in poly) + " Z"
	lid = "M%s %s L%s %s" % (f(c[0] - rx - 2), f(yl - tilt), f(c[0] + rx + 2), f(yl + tilt))
	return [path(d, fill=P.WHITE, sw=EYE_SW), path(lid, sw=7.5)]


def eyes(kind):
	it = []
	rn, rf = EYE_R["n"], EYE_R["f"]
	if kind == "open":
		it += _eye(EYE_N, *rn) + _eye(EYE_F, *rf)
	elif kind == "half":
		cut, tn, tf = LID_CUT["half"]
		it += _half(EYE_N, rn[0], rn[1], cut, tn) + _half(EYE_F, rf[0], rf[1], cut, tf)
	elif kind == "closed":
		for c, (rx, ry) in ((EYE_N, rn), (EYE_F, rf)):
			it.append(path(qcurve((c[0] - rx, c[1] + 2), (c[0], c[1] + ry * 0.9), (c[0] + rx, c[1] + 2)), sw=7))
			it.append(path("M%s %s L%s %s" % (f(c[0] - rx - 1), f(c[1] + 2), f(c[0] - rx - 6), f(c[1] - 2)), sw=4))
	elif kind == "wide":
		it += _eye((EYE_N[0] - 1, EYE_N[1] - 3), rn[0] + 4, rn[1] + 5, lid=False)
		it += _eye((EYE_F[0] + 1, EYE_F[1] - 3), rf[0] + 3, rf[1] + 5, lid=False)
	elif kind == "pinpoint":
		for c, (rx, ry), dx in ((EYE_N, rn, 0), (EYE_F, rf, 0)):
			it += _eye((c[0], c[1] - 3), rx + 4, ry + 5, lid=False)
			it.append(circle(c[0] + 2, c[1] - 1, 3.2, fill=INK))
	elif kind == "angry":
		cut, tn, tf = LID_CUT["angry"]
		it += _half(EYE_N, rn[0], rn[1], cut, tn) + _half(EYE_F, rf[0], rf[1], cut, tf)
	elif kind == "spiral":
		for c, (rx, ry) in ((EYE_N, rn), (EYE_F, rf)):
			it.append(ellipse(c[0], c[1], rx, ry, fill=P.WHITE, sw=EYE_SW))
			pts = []
			for i in range(40):
				a = i * 0.42
				r = 0.8 + i * 0.30
				pts.append((c[0] + r * math.cos(a) * rx / ry, c[1] + r * math.sin(a)))
			it.append(path(smooth_open(pts, 0.5), sw=3.2))
	elif kind == "balloon":
		# magnified x4 behind the magnifier: huge, jostling, pupils swimming
		for c, r, pr, dx in ((EYE_N, 28, 13, 3), (EYE_F, 25, 11.5, -2)):
			it.append(ellipse(c[0], c[1] - 4, r, r * 1.08, fill=P.WHITE, sw=EYE_SW))
			it.append(path(qcurve((c[0] - r * 0.7, c[1] + r * 0.5), (c[0], c[1] + r * 0.95), (c[0] + r * 0.7, c[1] + r * 0.5)),
						   stroke="#E23B4E", stroke_width=2, stroke_opacity="0.6"))
			it.append(circle(c[0] + dx, c[1] - 2, pr, fill=INK))
			it.append(circle(c[0] + dx - pr * 0.4, c[1] - 2 - pr * 0.45, pr * 0.32, fill=P.WHITE))
	elif kind == "squint":
		for c, (rx, ry), sgn in ((EYE_N, rn, 1), (EYE_F, rf, -1)):
			pts = [(c[0] - rx, c[1] + 1), (c[0] - rx * 0.4, c[1] - 6), (c[0] + rx * 0.5, c[1] - 6), (c[0] + rx, c[1] - 1),
				   (c[0] + rx * 0.4, c[1] + 6), (c[0] - rx * 0.5, c[1] + 6)]
			it.append(path(smooth_closed(pts, 0.6), fill=P.WHITE, sw=EYE_SW))
			it.append(circle(c[0] + 3, c[1], 4.6, fill=INK))
			it.append(path("M%s %s L%s %s" % (f(c[0] - rx - 3), f(c[1] - 5 + sgn * 2), f(c[0] + rx + 3), f(c[1] - 7 - sgn * 2)), sw=7))
	elif kind == "teary":
		for c, (rx, ry) in ((EYE_N, rn), (EYE_F, rf)):
			it += _eye(c, rx, ry)
			# welling tear along the lower lid + a drop
			it.append(path(qcurve((c[0] - rx + 3, c[1] + ry * 0.55), (c[0], c[1] + ry + 4), (c[0] + rx - 3, c[1] + ry * 0.55)),
						   stroke=P.TEAR, stroke_width=5, stroke_linecap="round"))
		dx, dy = EYE_N[0] + 4, EYE_N[1] + 30
		tear = [(dx, dy - 9), (dx + 5, dy), (dx + 3, dy + 6), (dx - 3, dy + 6), (dx - 5, dy)]
		it.append(path(smooth_closed(tear, 0.6), fill=P.TEAR, sw=3))
		it.append(circle(dx - 1.5, dy + 1, 1.5, fill=P.WHITE))
	return Part("eyes_" + kind, it, (-62, -66, 58, 16))


def _lid(c, rx, ry, cut, tilt):
	"""Skin upper lid: the part of the eye ellipse above the lid line (covers pupils that stray up)."""
	n = 24
	yl = c[1] - ry * cut
	top = []
	for i in range(n + 1):
		a = math.pi * i / n
		x = c[0] - rx * math.cos(a)
		y = c[1] - ry * math.sin(a)
		t = (x - (c[0] - rx)) / (2 * rx)
		lid_y = yl + tilt * (t - 0.5) * 2
		top.append((x, min(y, lid_y)))
	lidline = [(c[0] + rx, yl + tilt), (c[0] - rx, yl - tilt)]
	poly = top + lidline
	d = "M" + " L".join("%s %s" % (f(x), f(y)) for x, y in poly) + " Z"
	arc = "M" + " L".join("%s %s" % (f(x), f(y)) for x, y in top)
	lid = "M%s %s L%s %s" % (f(c[0] - rx - 2), f(yl - tilt), f(c[0] + rx + 2), f(yl + tilt))
	return [path(d, fill=P.SKIN), path(arc, sw=EYE_SW), path(lid, sw=7.5)]


def lids(kind):
	rn, rf = EYE_R["n"], EYE_R["f"]
	cut, tn, tf = LID_CUT[kind]
	it = _lid(EYE_N, rn[0], rn[1], cut, tn) + _lid(EYE_F, rf[0], rf[1], cut, tf)
	return Part("lids_" + kind, it, (-46, -50, 40, -20))


def pupils():
	it = []
	for c, r in ((PUPIL_N, PUPIL_R["n"]), (PUPIL_F, PUPIL_R["f"])):
		it.append(circle(c[0], c[1], r, fill=INK))
		it.append(circle(c[0] - r * 0.38, c[1] - r * 0.42, r * 0.34, fill=P.WHITE))
	return Part("pupils", it, (-34, -35, 34, -15))


# --- brows: thick tapered ink strokes (they carry the emotion) -------------------------------

BROW_KINDS = ["neutral", "up", "angry", "worried", "sly", "one_up"]


def _brow(p0, p1, bend, w0=9.5, w1=6.5):
	"""Tapered brow from p0 (inner, nose side) to p1 (outer), bowed up by `bend` px."""
	n = 12
	pts_top = []
	pts_bot = []
	for i in range(n + 1):
		t = i / n
		x = p0[0] + (p1[0] - p0[0]) * t
		y = p0[1] + (p1[1] - p0[1]) * t - bend * 4 * t * (1 - t)
		w = (w0 + (w1 - w0) * t) / 2
		# normal
		dx = p1[0] - p0[0]
		dy = (p1[1] - p0[1]) - bend * 4 * (1 - 2 * t)
		L = math.hypot(dx, dy) or 1
		nx, ny = -dy / L, dx / L
		pts_top.append((x + nx * w, y + ny * w))
		pts_bot.append((x - nx * w, y - ny * w))
	poly = pts_top + list(reversed(pts_bot))
	d = "M" + " L".join("%s %s" % (f(x), f(y)) for x, y in poly) + " Z"
	return [path(d, fill=INK, stroke=INK, stroke_width=2, stroke_linejoin="round")]


def brows(kind):
	it = []
	# near brow inner end (nose side) is on the right; far brow inner end is on the left
	if kind == "neutral":
		it += _brow((-12, -54), (-44, -52), 4) + _brow((8, -56), (34, -54), 4, 8.5, 6)
	elif kind == "up":
		it += _brow((-12, -66), (-44, -62), 7) + _brow((8, -68), (34, -64), 7, 8.5, 6)
	elif kind == "angry":
		it += _brow((-10, -46), (-44, -60), -2) + _brow((6, -48), (34, -62), -2, 8.5, 6)
	elif kind == "worried":
		it += _brow((-12, -62), (-44, -50), -3) + _brow((8, -64), (34, -52), -3, 8.5, 6)
	elif kind == "sly":
		it += _brow((-12, -52), (-44, -54), 1) + _brow((8, -62), (36, -58), 6, 8.5, 6)
	elif kind == "one_up":
		it += _brow((-12, -52), (-44, -50), 2) + _brow((8, -70), (34, -66), 9, 8.5, 6)
	return Part("brows_" + kind, it, (-50, -78, 42, -40))


# --- mouths -------------------------------------------------------------------------------------

MOUTH_KINDS = ["closed", "smile", "smug", "O_small", "O_mid", "O_big", "scream", "grit", "wavy", "open"]
MX, MY = 10, 38   # closed-mouth centre (face coords); the nose bottom is at ~ +22


def _open_mouth(pts, t=0.6, tongue=True, teeth_top=0, teeth_bot=0):
	d = smooth_closed(pts, t)
	poly = sample_closed(pts, t)
	x0, y0, x1, y1 = bbox_pts(pts)
	cx = (x0 + x1) / 2
	it = [path(d, fill=P.MOUTH)]
	if tongue:
		# a tongue hump in the bottom of the mouth, clipped to the (convex) mouth polygon
		tw = (x1 - x0) * 0.36
		th = (y1 - y0) * 0.42
		hump = ellipse_pts(cx + 1, y1 + th * 0.25, tw, th, 24)
		tp = clip_convex(hump, poly)
		if len(tp) > 2:
			it.append(path(poly_path(tp), fill=P.TONGUE))
			it.append(path(qcurve((cx - tw * 0.1, y1 - th * 0.55), (cx + 1, y1 - th * 0.2), (cx + 2, y1 - th * 0.05)),
						   stroke=P.MOUTH, stroke_width=2.2, stroke_linecap="round"))
	if teeth_top:
		band = [(x0 - 2, y0 - 2), (x1 + 2, y0 - 2), (x1 + 2, y0 + teeth_top), (x0 - 2, y0 + teeth_top)]
		tp = clip_convex(band, poly)
		if len(tp) > 2:
			it.append(path(poly_path(tp), fill=P.TEETH))
	if teeth_bot:
		band = [(x0 - 2, y1 - teeth_bot), (x1 + 2, y1 - teeth_bot), (x1 + 2, y1 + 2), (x0 - 2, y1 + 2)]
		tp = clip_convex(band, poly)
		if len(tp) > 2:
			it.append(path(poly_path(tp), fill=P.TEETH))
	it.append(path(d, sw=5))
	return it


def mouth(kind):
	it = []
	x, y = MX, MY
	if kind == "closed":
		# pompous resting 'harrumph': a short line, corners a touch down
		it.append(path(smooth_open([(x - 17, y + 3), (x - 8, y - 1), (x + 8, y - 1), (x + 17, y + 3)], 0.6), sw=5.5))
	elif kind == "smile":
		it.append(path(smooth_open([(x - 20, y - 4), (x - 8, y + 5), (x + 8, y + 5), (x + 20, y - 4)], 0.6), sw=5.5))
		it.append(path("M%s %s l-4 -3" % (f(x - 20), f(y - 4)), sw=4))
		it.append(path("M%s %s l4 -3" % (f(x + 20), f(y - 4)), sw=4))
	elif kind == "smug":
		it.append(path(smooth_open([(x - 16, y + 2), (x - 4, y + 3), (x + 10, y), (x + 20, y - 8)], 0.6), sw=5.5))
		it.append(path("M%s %s q4 1 5 -4" % (f(x + 21), f(y - 6)), sw=3.5))
	elif kind == "O_small":
		it += _open_mouth([(x, y - 9), (x + 9, y), (x, y + 10), (x - 9, y)], 0.9, tongue=False)
	elif kind == "O_mid":
		it += _open_mouth([(x, y - 14), (x + 20, y + 2), (x, y + 24), (x - 20, y + 2)], 0.9)
	elif kind == "O_big":
		it += _open_mouth([(x, y - 18), (x + 25, y + 8), (x, y + 40), (x - 25, y + 8)], 0.9, teeth_top=7)
	elif kind == "scream":
		pts = [(x - 32, y - 10), (x, y - 14), (x + 32, y - 10), (x + 28, y + 18), (x, y + 34), (x - 28, y + 18)]
		it += _open_mouth(pts, 0.5, teeth_top=8, teeth_bot=6)
	elif kind == "grit":
		pts = [(x - 29, y - 9), (x, y - 11), (x + 29, y - 9), (x + 30, y + 3), (x + 26, y + 11), (x, y + 13),
			   (x - 26, y + 11), (x - 30, y + 3)]
		d = smooth_closed(pts, 0.5)
		it.append(path(d, fill=P.TEETH))
		poly = sample_closed(pts, 0.5)
		segs = [((xx, y - 16), (xx, y + 18)) for xx in range(int(x - 20), int(x + 24), 10)]
		it += clipped_lines(poly, segs, 1.0, stroke=INK, stroke_width=2.8)
		it += clipped_lines(poly, [((x - 34, y + 1), (x + 34, y + 1))], 1.0, stroke=INK, stroke_width=3)
		it.append(path(d, sw=5))
	elif kind == "wavy":
		pts = [(x - 20, y), (x - 13, y - 5), (x - 6, y + 3), (x + 1, y - 5), (x + 8, y + 3), (x + 15, y - 5), (x + 21, y + 1)]
		it.append(path(smooth_open(pts, 0.6), sw=5.5))
	elif kind == "open":
		pts = [(x - 21, y - 5), (x, y - 7), (x + 21, y - 5), (x + 15, y + 12), (x, y + 18), (x - 15, y + 12)]
		it += _open_mouth(pts, 0.6)
	return Part("mouth_" + kind, it, (-30, 16, 50, 84))


# --- overlays (single texture, off unless a preset or residue turns them on) -----------------

OVERLAYS = ["blush", "sweat", "vein", "steam_l", "steam_r", "singe", "pinch", "hiccup"]


def _puff(cx, cy, r, col=P.STEAM, sh=P.STEAM_S, sw=4):
	return [circle(cx, cy, r, fill=sh, stroke=INK, stroke_width=sw), circle(cx - r * 0.2, cy - r * 0.2, r * 0.75, fill=col)]


def overlay(kind):
	it = []
	if kind == "blush":
		it.append(ellipse(-34, 10, 13, 7, fill=P.CHEEK, fill_opacity="0.7"))
		it.append(ellipse(34, 8, 9, 6, fill=P.CHEEK, fill_opacity="0.7"))
		bb = (-48, 2, 44, 16)
	elif kind == "sweat":
		for (x, y, s) in ((-52, -56, 1.3), (-58, -30, 0.8)):
			pts = xform([(0, -12), (6, -2), (7, 5), (3, 10), (-3, 10), (-7, 5), (-6, -2)], dx=x, dy=y, sx=s, sy=s)
			d = smooth_closed(pts, 0.6)
			it += [path(d, fill=P.SWEAT), path(d, sw=3.5), circle(x - 2 * s, y + 2 * s, 1.8 * s, fill=P.WHITE)]
		bb = (-70, -76, -44, -14)
	elif kind == "vein":
		# the cartoon anger vein on the temple (four curved ticks)
		cx, cy = -2, -76
		for a in (0, 90, 180, 270):
			p = xform([(3, -4), (8, -10), (13, -6)], dx=cx, dy=cy, ang=a)
			dd = smooth_open(p, 0.6)
			it.append(path(dd, stroke=INK, stroke_width=8.5, stroke_linecap="round"))
			it.append(path(dd, stroke=P.VEIN, stroke_width=4, stroke_linecap="round"))
		bb = (-22, -96, 18, -56)
	elif kind == "steam_r":
		# out of the near ear (face (-80, -14)), jetting back and up
		for (x, y, r) in ((-92, -22, 8), (-106, -36, 11), (-116, -56, 14)):
			it += _puff(x, y, r)
		bb = (-134, -74, -80, -10)
	elif kind == "steam_l":
		# from behind the far side of the head, jetting forward/up (drawn behind the head)
		for (x, y, r) in ((50, -58, 8), (64, -72, 11), (74, -92, 14)):
			it += _puff(x, y, r)
		bb = (38, -110, 92, -46)
	elif kind == "singe":
		# FRAZZLED: little smoke wisps rising off the brows (never soot on the face)
		for (x, y) in ((-44, -62), (-14, -64), (32, -66)):
			it.append(path("M%s %s c-5 -6 5 -9 0 -15 c-4 -5 3 -8 1 -12" % (f(x), f(y)), stroke=P.HAIR_S,
						   stroke_width=4, stroke_linecap="round"))
		bb = (-52, -96, 40, -58)
	elif kind == "pinch":
		# SQUEAKY: helium-pinched lips (pucker creases at the corners)
		for sgn in (-1, 1):
			x0 = MX + sgn * 24
			it.append(path("M%s %s q%s 4 0 8" % (f(x0), f(MY - 6), f(sgn * 4)), sw=3.2))
		it.append(path("M%s %s q4 -3 8 0" % (f(MX - 4), f(MY + 10)), sw=3))
		bb = (-20, 26, 40, 54)
	elif kind == "hiccup":
		# SQUEAKY: a helium hiccup puff floating up from the mouth
		for (x, y, r) in ((42, 34, 5), (52, 22, 7.5), (64, 6, 10)):
			it.append(circle(x, y, r, fill=P.WHITE, stroke=INK, stroke_width=3.5))
			it.append(circle(x - r * 0.3, y - r * 0.3, r * 0.3, fill="#CDE7F2"))
		bb = (34, -6, 78, 42)
	return Part(kind, it, bb)
