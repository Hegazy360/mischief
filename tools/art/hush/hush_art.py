"""Hush (the mime) and her Pip fallback skin: every part SVG, drawn in joint-local coordinates.

Conventions (shared with rig_hush.py / fk.py / the runtime rig, TECH 4.7):
* every part is authored around its JOINT at (0, 0), y down, character facing +x (right);
* limbs hang along +y at rest (rotation 0), so arms/legs/hands point down in their canvases;
* every part has a FIXED canvas box (BOX[name]) shared by Hush and Pip -> identical sizes and pivots;
* `_r` = near side (toward the audience, drawn in front), `_l` = far side (behind, one step darker).

`build(skin)` returns {relative_file_name: svg_text} for one skin ("hush" or "pip").
"""
import math
from svgk import (INK, SW, DET, Part, Union, path, circle, ellipse, rect, g, line, smooth_closed, smooth_open,
				  sample_closed, clip_convex, band, shaded, capsule_d, highlight, xform, rot, f, pts_path,
				  ellipse_pts, heart_path, polar)
import pal

import svgk

H = pal.HUSH
P = pal.PIP

# Hush is authored large and drawn at K so her full height (beret stalk to soles) is ~340 px at zoom 1.0.
# Strokes are authored at 1/K so they land on exactly 6 px (outline) / 3.5 px (detail) after scaling.
K = 0.87
SW = svgk.SW / K
DET = svgk.DET / K


def S(v):
	"""authored joint vector -> rig px (1 decimal)."""
	return [round(v[0] * K, 1), round(v[1] * K, 1)]


def sbox(key):
	b = BOX[key]
	return (math.floor(b[0] * K), math.floor(b[1] * K), math.ceil(b[2] * K), math.ceil(b[3] * K))


def canvas(key):
	"""(pivot, size) of a part canvas in rig px."""
	b = sbox(key)
	return [float(-b[0]), float(-b[1])], [b[2] - b[0], b[3] - b[1]]


def cpt(key, p):
	"""authored joint-local point -> canvas px of that part."""
	b = sbox(key)
	return [round(p[0] * K - b[0], 1), round(p[1] * K - b[1], 1)]

# ---------------------------------------------------------------------------------------------------
# Skeleton geometry (px at zoom 1.0). Joint offsets are parent-joint relative; see rig_hush.py.
ROOT_OFFSET = (0, -136)          # pelvis joint above the feet origin
TORSO_OFF = (0, -10)             # waist joint (from pelvis)
HIP_L, HIP_R = (-7, 6), (7, 6)   # from pelvis
LEG_UP, LEG_LO = 58, 57          # thigh, shin lengths
SHO_L, SHO_R = (-10, -70), (9, -68)   # shoulders from the waist joint
ARM_UP, ARM_LO = 53, 51
NECK = (5, -76)                  # head joint from the waist joint
BERET_OFF = (4, -106)            # beret joint (its base centre) from the head joint
HAIR_BACK_OFF = (-24, -58)       # bob back from the head joint
BRACES_TUCK = (20, -44)          # where Clarence tucks in (torso local)
BRACES_LOOP_OFF = (-14, -62)     # back strap loop anchor (torso local)
FACE_ANCHOR = (24, -58)          # face slot pivot, head local

# Fixed canvas boxes (joint-local): (minx, miny, maxx, maxy)
BOX = {
	"pelvis": (-38, -23, 40, 30),
	"torso": (-38, -103, 42, 20),
	"braces_front": (-10, -80, 32, 12),
	"braces_loop": (-24, -120, 22, 12),
	"hair_back": (-36, -34, 32, 58),
	"head": (-66, -134, 70, 8),
	"beret": (-72, -78, 70, 24),
	"hand": (-46, -24, 60, 94),
	"foot": (-28, -28, 52, 50),
	"face": (-46, -62, 58, 62),
	"clarence": (-46, -132, 60, 32),
	"hidden": (-88, -50, 90, 58),
	"head_tomato": (-66, -134, 70, 8),
}


def part(name, items, box_key=None):
	return Part(name, items, BOX[box_key or name], K)


# ===================================================================================================
# BODY
def torso_outline():
	return [(-24, 8), (-27, -18), (-29, -44), (-27, -62), (-18, -73), (-2, -78), (14, -77), (26, -69),
			(31, -50), (30, -24), (26, 8)]


def pelvis(skin):
	it = []
	if skin == "hush":
		base, shade = H["navy"], H["navy_s"]
	else:
		base, shade = P["denim"], P["denim_s"]
	# high-waisted trouser top: waistband at the torso's width, hips a touch wider, soft crotch curve
	pts = [(-25, -13), (0, -15), (27, -13), (29, 0), (26, 12), (12, 17), (0, 15), (-12, 17), (-25, 12), (-28, 0)]
	d = smooth_closed(pts, 0.5)
	it += shaded(d, base, shade, (-4, -4), s=0.88, dx=-1, dy=-2, outline=False)
	if skin == "hush":
		it += [path("M-25 -4 Q1 -1 28 -4", sw=DET)]
		it += [circle(15, -8, 3.2, fill=H["red"], sw=2.5), circle(-14, -8.5, 3, fill=H["red_s"], sw=2.5)]
	else:
		it += [path("M-25 -4 Q1 -1 28 -4", sw=DET)]
		it += [circle(15, -8, 3.2, fill="#E8B33A", sw=2.5)]
	it += [path("M4 4 Q6 10 3 15", sw=DET)]
	it += [highlight(-13, -8, 7, 2.4, ang=-6, op=0.3)]
	it += [path(d, sw=SW)]
	return part("pelvis", it)


def _stripes(poly, lit_poly, y_from, y_to, pitch, width, dark, dark_s, tilt=0.0):
	"""Breton stripes clipped to the torso polygon: shade copies over `poly`, lit copies over `lit_poly`."""
	out = []
	y = y_from
	bands = []
	while y < y_to:
		bands.append(band(y, y + width, tilt=tilt))
		y += pitch
	for b in bands:
		c = clip_convex(poly, b)
		if len(c) >= 3:
			out.append(path(pts_path(c), fill=dark_s))
	for b in bands:
		c = clip_convex(lit_poly, b)
		if len(c) >= 3:
			out.append(path(pts_path(c), fill=dark))
	return out


def torso(skin):
	it = []
	outline_pts = torso_outline()
	d = smooth_closed(outline_pts, 0.55)
	poly = sample_closed(outline_pts, 0.55, 10)
	# lit copy: scaled about an up-left point, as in shaded()
	piv = (-10, -52); s = 0.86
	lit = [(piv[0] + (x - piv[0]) * s - 1.5, piv[1] + (y - piv[1]) * s - 2) for x, y in poly]
	if skin == "hush":
		light, light_s, dark, dark_s = H["stripe"], H["stripe_s"], H["navy"], H["navy_s"]
		neck_c, neck_s = H["paint"], H["paint_s"]
	else:
		light, light_s, dark, dark_s = P["cream"], P["cream_s"], P["jumper"], P["jumper_s"]
		neck_c, neck_s = P["skin"], P["skin_s"]
	# neck (behind the collar)
	it += [rect(-5, -96, 20, 30, rx=8, fill=neck_s, sw=SW), rect(-3, -95, 12, 26, rx=6, fill=neck_c)]
	it += [path(d, fill=light_s), path(pts_path(lit), fill=light)]
	if skin == "hush":
		it += _stripes(poly, lit, -63, 14, 13.5, 7.0, dark, dark_s)
	else:
		# chunky jumper: wide teal bands + a ribbed hem
		it += _stripes(poly, lit, -60, 14, 18, 10.0, dark, dark_s)
	# boat neck / crew neck
	if skin == "hush":
		it += [path("M-16 -72 Q3 -64 24 -71", sw=DET)]
	else:
		it += [path("M-12 -73 Q3 -63 20 -72 Q4 -70 -12 -73 Z", fill=P["jumper_s"], sw=DET)]
		it += [path("M-24 0 Q2 4 27 0", sw=DET)]
	# braces (hush: red straps; pip: denim dungaree straps)
	if skin == "hush":
		sc, ss = H["red"], H["red_s"]
	else:
		sc, ss = P["denim"], P["denim_s"]
	it += _strap((-13, -75), (-16, 10), 8.5, ss, ss)                     # far strap (one flat tone)
	it += _strap((15, -76), (13, 10), 9.5, sc, ss)                    # near strap
	if skin == "pip":
		# bib pocket where Clarence rides
		it += [path("M6 -46 L24 -46 L23 -30 Q15 -26 7 -30 Z", fill=P["denim"], sw=DET)]
	it += [highlight(-16, -58, 8, 3, ang=-20, op=0.4)]
	it += [path(d, sw=SW)]
	return part("torso", it)


def _strap(a, b, w, base, shade):
	d = capsule_d(a[0], a[1], b[0], b[1], w)
	return [path(d, fill=shade, sw=DET),
			path("M%s %s L%s %s" % (f(a[0] - w * 0.18), f(a[1] + 2), f(b[0] - w * 0.18), f(b[1])), stroke=base,
				 stroke_width=w * 0.5, stroke_linecap="round")]


def braces_front(skin):
	"""Front strap segment drawn OVER Clarence so he reads as tucked into the braces."""
	sc, ss = (H["red"], H["red_s"]) if skin == "hush" else (P["denim"], P["denim_s"])
	it = _strap((15, -60), (14.4, -28), 9.5, sc, ss)
	if skin == "pip":
		it = [path("M6 -46 L24 -46 L23 -30 Q15 -26 7 -30 Z", fill=P["denim"], sw=DET),
			  path("M8 -42 L22 -42", sw=2.5)]
	return part("braces_front", it)


def braces_loop(skin):
	"""The back strap loop Bellows grabs to dangle her (hidden unless a pose sets vis=1).
	Drawn from the anchor (0, 0) upward; scale sy to stretch it."""
	sc, ss = (H["red"], H["red_s"]) if skin == "hush" else (P["denim"], P["denim_s"])
	it = []
	it += [path("M-10 0 C-14 -40 -12 -90 -2 -108 C6 -92 10 -40 8 0", fill="none", stroke=INK, stroke_width=15,
				stroke_linecap="round", stroke_linejoin="round")]
	it += [path("M-10 0 C-14 -40 -12 -90 -2 -108 C6 -92 10 -40 8 0", fill="none", stroke=ss, stroke_width=8,
				stroke_linecap="round", stroke_linejoin="round")]
	it += [path("M-11 -6 C-14 -44 -12 -86 -3 -102", fill="none", stroke=sc, stroke_width=3.5, stroke_linecap="round")]
	return part("braces_loop", it)


# ===================================================================================================
# HEAD
SKULL = [(30, -5), (6, -3), (-18, -12), (-38, -34), (-45, -62), (-40, -92), (-18, -113), (12, -118),
		 (40, -106), (55, -82), (59, -56), (55, -30), (45, -13)]


def head(skin):
	it = []
	d = smooth_closed(SKULL, 0.62)
	if skin == "hush":
		base, shade = H["paint"], H["paint_s"]
		hair, hair_s = H["hair"], H["hair_s"]
	else:
		base, shade = P["skin"], P["skin_s"]
		hair, hair_s = P["hair"], P["hair_s"]
	if skin == "pip":
		# ear (kids' ears stick out a bit), behind the hair tufts
		it += [ellipse(-26, -56, 11, 14, fill=P["skin_s"], sw=SW), ellipse(-25, -56, 5, 7, sw=DET)]
	it += shaded(d, base, shade, (8, -80), s=0.9, dx=-2, dy=-3, outline=False)
	if skin == "hush":
		# bob: back mass + a short fringe under the beret
		hp = [(-47, -24), (-52, -60), (-46, -96), (-22, -121), (14, -125), (42, -114), (58, -96), (60, -84),
			  (52, -88), (40, -96), (26, -99), (12, -100), (0, -97), (-10, -88), (-15, -70), (-20, -48),
			  (-28, -30), (-37, -20)]
		hd = smooth_closed(hp, 0.5)
		it += shaded(hd, hair, hair_s, (-10, -100), s=0.88, dx=-2, dy=-2, outline=False)
		it += [path(hd, sw=SW)]
		# fringe strands + a shine
		it += [path("M26 -96 Q30 -104 38 -106", sw=DET), path("M4 -98 Q8 -107 16 -110", sw=DET)]
		it += [path("M-32 -88 Q-26 -104 -10 -112", stroke="#FFFFFF", stroke_width=4, stroke_linecap="round",
					stroke_opacity=0.35)]
	else:
		# ginger tufts poking out under the beanie + one at the nape
		tufts = [(-40, -72, 13, -110), (-44, -44, 11, -150), (48, -90, 10, -40), (30, -96, 9, -70)]
		for (x, y, r, a) in tufts:
			pts = [polar((x, y), r * 1.3, a), polar((x, y), r, a + 70), polar((x, y), r * 0.6, a + 180),
				   polar((x, y), r, a - 70)]
			it += [path(smooth_closed(pts, 0.7), fill=hair, sw=SW)]
			it += [path(smooth_closed(xform(pts, sx=0.6, sy=0.6, c=(x, y), dx=-1, dy=-1), 0.7), fill=pal.PIP["hair"])]
	# face outline on top of the skin but under the hair edge (hair already outlined)
	it += [path(d, sw=SW)]
	if skin == "hush":
		# re-draw the hair over the face outline where they meet (keeps the fringe crisp)
		it += [path(smooth_closed(hp, 0.5), fill=hair)]
		it += [path(smooth_closed(xform(hp, sx=0.88, sy=0.88, c=(-10, -100), dx=-2, dy=-2), 0.5), fill=hair)]
		it += [path(smooth_closed(hp, 0.5), sw=SW)]
		it += [path("M26 -96 Q30 -104 38 -106", sw=DET), path("M4 -98 Q8 -107 16 -110", sw=DET)]
		it += [path("M-34 -84 Q-28 -102 -12 -112", stroke="#FFFFFF", stroke_width=4, stroke_linecap="round",
					stroke_opacity=0.3)]
	# cheeks (always rosy), nose, painted teardrop / freckles
	it += [ellipse(-4, -30, 11, 7, fill=pal.HUSH["cheek"], fill_opacity=0.85),
		   ellipse(51, -31, 5, 6.5, fill=pal.HUSH["cheek"], fill_opacity=0.85)]
	if skin == "hush":
		it += [path("M40 -48 Q48 -44 42 -38", sw=DET)]                        # little nose
		it += [path("M-4 -46 Q-8 -38 -4 -35 Q0 -38 -4 -46 Z", fill=H["tear"], stroke=H["tear"],
					stroke_width=1.5, stroke_linejoin="round")]               # painted teardrop
	else:
		it += [path("M39 -50 Q50 -45 42 -37", sw=DET)]
		for (x, y) in [(-10, -34), (-2, -37), (4, -31), (48, -36), (54, -33)]:
			it += [circle(x, y, 1.6, fill=P["freckle"])]
	it += [highlight(-24, -86, 8, 3.5, ang=-50, op=0.35)] if skin == "pip" else []
	return part("head", it)


def hair_back(skin):
	"""Back of the bob (spring): a soft rounded chunk behind the head/neck."""
	it = []
	if skin == "hush":
		pts = [(-6, -26), (14, -18), (22, 6), (18, 34), (4, 48), (-16, 44), (-26, 22), (-24, -6)]
		d = smooth_closed(pts, 0.7)
		it += shaded(d, H["hair"], H["hair_s"], (-8, 6), s=0.86, dx=-2, dy=-2, sw=SW)
		it += [path("M-8 8 Q-2 28 -8 40", sw=DET)]
	else:
		# Pip: beanie pompom-free nape tuft (small), keeps the silhouette related
		pts = [(-6, -10), (10, -4), (14, 14), (4, 26), (-12, 22), (-16, 6)]
		d = smooth_closed(pts, 0.7)
		it += shaded(d, P["hair"], P["hair_s"], (-4, 8), s=0.86, sw=SW)
	return part("hair_back", it)


def beret(skin):
	"""Beret (spring part), joint = where it sits on the crown. Tilted back and slouched to the rear."""
	it = []
	if skin == "hush":
		base, shade = H["red"], H["red_s"]
		# slouch disc
		pts = [(-62, -10), (-58, -30), (-36, -46), (-2, -52), (34, -46), (54, -30), (52, -14), (30, -2),
			   (-10, 2), (-44, 0)]
		d = smooth_closed(pts, 0.6)
		it += shaded(d, base, shade, (-6, -30), s=0.86, dx=-1, dy=-3, sw=SW)
		# head band (the rim that grips the head)
		it += [path("M-40 -2 Q6 10 50 -12", sw=DET)]
		# stalk
		it += [path("M-4 -50 Q-2 -60 6 -60", fill="none", stroke=INK, stroke_width=11, stroke_linecap="round"),
			   path("M-4 -50 Q-2 -60 6 -60", fill="none", stroke=base, stroke_width=4.5, stroke_linecap="round")]
		it += [highlight(-24, -36, 13, 4, ang=-12, op=0.5)]
	else:
		base, shade, lite = P["knit"], P["knit_s"], P["knit_l"]
		# beanie dome
		dome = [(-50, -2), (-48, -30), (-28, -48), (4, -52), (34, -42), (50, -20), (50, -2)]
		d = smooth_closed(dome, 0.6)
		it += shaded(d, base, shade, (-6, -28), s=0.86, dx=-1, dy=-3, sw=SW)
		for x in (-30, -12, 8, 28):
			it += [path("M%s -4 Q%s -26 %s -44" % (x, x + 2, x + 6), sw=2.5)]
		# folded cuff
		cd = smooth_closed([(-54, -12), (0, -8), (54, -14), (56, 6), (0, 12), (-54, 8)], 0.4)
		it += shaded(cd, lite, base, (-10, -2), s=0.9, sw=SW)
		for x in range(-44, 50, 10):
			it += [line(x, -6, x + 0.5, 6, sw=2.5)]
		# pompom
		it += [circle(8, -58, 11, fill=P["cream"], sw=SW), circle(5, -61, 5, fill="#FFFFFF", fill_opacity=0.6)]
	return part("beret", it)


# ===================================================================================================
# HANDS (8 shapes). Wrist = (0, 0); fingers point +y; thumb side +x (front). ~1.6x a plain hand.
PALM_OPEN = [(-19, 2), (-22, 20), (-17, 37), (0, 42), (17, 37), (22, 20), (19, 2), (0, -1)]
PALM_FIST = [(-19, 2), (-22, 18), (-18, 33), (0, 38), (18, 33), (22, 18), (19, 2), (0, -1)]

GESTURES = {
	# name: (palm, fingers[(x1,y1,x2,y2,w)], thumb(x1,y1,x2,y2,w), knuckles[(x,y,r)], side ('back'|'palm'))
	"open": (PALM_OPEN, [(-12, 32, -18, 62, 14), (0, 34, 0, 68, 15), (12, 32, 18, 61, 14)],
			 (15, 14, 32, 32, 14), [], "back"),
	"wave": (PALM_OPEN, [(-12, 30, -29, 55, 14), (-1, 34, -5, 69, 15), (10, 32, 23, 60, 14)],
			 (16, 16, 39, 17, 14), [], "palm"),
	"wall": (PALM_OPEN, [(-12, 34, -13, 64, 14), (0, 36, 0, 71, 15), (12, 34, 13, 64, 14)],
			 (17, 12, 31, 25, 14), [], "palm"),
	"point": (PALM_FIST, [(6, 30, 8, 76, 14)], (18, 14, 12, 30, 13), [(-12, 34, 10), (-2, 39, 10)], "back"),
	"pinch": (PALM_FIST, [(5, 30, 17, 50, 13)], (18, 14, 23, 45, 13), [(-12, 34, 10), (-3, 39, 10)], "back"),
	"fist": (PALM_FIST, [], (19, 13, 8, 28, 13), [(-12, 35, 10.5), (0, 40, 10.5), (12, 36, 10)], "back"),
	"thumbs_up": (PALM_FIST, [], (14, 12, 41, 3, 15), [(-12, 35, 10.5), (0, 40, 10.5), (12, 36, 10)], "back"),
	"shush": (PALM_FIST, [(1, 30, 1, 76, 15)], (18, 16, 12, 30, 13), [(-13, 35, 10), (13, 36, 9)], "back"),
}
HAND_TEX = ["open", "wall", "point", "pinch", "fist", "thumbs_up", "shush", "wave"]   # first = default


def hand(skin, gesture, far):
	palm, fingers, thumb, knuckles, side = GESTURES[gesture]
	if skin == "hush":
		base, shade = (H["glove_far"], H["glove_far_s"]) if far else (H["glove"], H["glove_s"])
		cb, cs = base, shade
	else:
		base, shade = (P["mitten_far"], P["mitten_far_s"]) if far else (P["mitten"], P["mitten_s"])
		cb, cs = (P["cuff_s"], "#96202F") if far else (P["cuff"], P["cuff_s"])
	u = Union(base, shade, sw=SW, inset=3.4, shift=2.4)
	u.add_poly(palm, 0.7)
	tx1, ty1, tx2, ty2, tw = thumb
	thumb_first = gesture in ("fist", "point", "pinch", "shush")   # thumb wraps OVER the curled fingers
	if not thumb_first:
		u.add_capsule(tx1, ty1, tx2, ty2, tw)
	for (x, y, r) in knuckles:
		u.add_circle(x, y, r)
	for (x1, y1, x2, y2, w) in fingers:
		u.add_capsule(x1, y1, x2, y2, w)
	if thumb_first:
		u.add_capsule(tx1, ty1, tx2, ty2, tw)
	det = []
	if side == "back":
		if skin == "hush":
			det += [path("M-8 7 L-8.5 19", sw=DET), path("M0 7 L0 21", sw=DET), path("M8 7 L8.5 19", sw=DET)]
		else:
			det += [path("M-13 16 Q-2 21 11 16", sw=2.5)]
	else:
		det += [path("M-12 24 Q-2 30 10 22", sw=DET)]
	if gesture == "wall":
		det += [path("M-6 42 L-6.5 58", sw=DET), path("M6 42 L6.5 58", sw=DET)]
	if not far:
		det += [highlight(-11, 12, 6, 2.8, ang=-60, op=0.55)]
	items = u.render(det)
	# cuff: a short flared band, wider toward the arm, with a rolled rim
	cd = smooth_closed([(-24, -14), (0, -16), (24, -14), (22, -4), (17, 4), (0, 6), (-17, 4), (-22, -4)], 0.5)
	items += shaded(cd, cb, cs, (-6, -6), s=0.86, dx=-1, dy=-1, sw=SW)
	if skin == "hush":
		items += [path("M-21 -6 Q0 -1 21 -6", sw=DET)]
	else:
		for x in (-14, -7, 0, 7, 14):
			items += [line(x, -11, x * 0.9, 3, sw=2.5)]
	return part("hand_%s_%s" % ("l" if far else "r", gesture), items, "hand")


# ===================================================================================================
# FEET: flat shoes; `tiptoe` = the same shoe rolled onto its toe about the ankle.
SHOE = [(-14, 2), (-12, -6), (0, -8), (12, -4), (26, -1), (38, 3), (43, 9), (38, 15), (12, 16), (-11, 15), (-16, 9)]
TIPTOE_ANG = 58.0


def foot(skin, style, far):
	if skin == "hush":
		base, shade = (H["shoe_far"], H["shoe_far_s"]) if far else (H["shoe"], H["shoe_s"])
	else:
		base, shade = (P["shoe_far"], P["shoe_far_s"]) if far else (P["shoe"], P["shoe_s"])
	it = []
	d = smooth_closed(SHOE, 0.55)
	it += shaded(d, base, shade, (4, 0), s=0.86, dx=-1, dy=-2, sw=SW)
	if skin == "hush":
		# white sock band at the ankle, the shoe mouth + a small bow
		sk, sks = (H["stripe"], H["stripe_s"]) if not far else (H["stripe_s"], "#B7BED3")
		it = [rect(-15, -18, 30, 14, rx=6, fill=sks, sw=SW), rect(-14, -17, 24, 10, rx=5, fill=sk)] + it
		it += [path("M-10 -3 Q2 1 14 -2", sw=DET)]
		bow_c = H["red"] if not far else H["red_s"]
		it += [path("M18 -1 L10 -8 L10 5 Z", fill=bow_c, sw=3), path("M18 -1 L26 -8 L26 5 Z", fill=bow_c, sw=3),
			   circle(18, -1, 3.2, fill=bow_c, sw=3)]
		it += [highlight(0, -3, 6, 2, ang=-10, op=0.45)]
	else:
		# sneaker: white rubber sole + toe cap + laces
		sole = P["sole"] if not far else P["sole_s"]
		it += [path("M-14 8 L37 8 Q41 10 38 15 L-10 15 Q-16 14 -14 8 Z", fill=sole, sw=DET)]
		it += [path("M22 8 Q24 -1 33 3", sw=2.5)]
		it += [line(0, -5, 5, -3, sw=2.5, stroke=sole), line(6, -3, 11, -1, sw=2.5, stroke=sole)]
	it += [path(d, sw=SW)]
	if style == "tiptoe":
		it = [g(it, transform="rotate(%s)" % f(TIPTOE_ANG))]
	return part("foot_%s_%s" % ("l" if far else "r", style), it, "foot")


# ===================================================================================================
# FACE SLOTS — canvas = BOX['face'] around FACE_ANCHOR (head-local (24, -58)).
# Face-local coordinates: head-local minus FACE_ANCHOR.
E1 = (-17, -4)    # near eye centre (head (7, -62))
E2 = (18, -2)     # far eye centre  (head (42, -60))
R1 = (15.0, 18.0)
R2 = (14.0, 16.5)
PUP1, PUP2 = 8.4, 8.2
MOUTH = (9, 33)   # head (33, -25)


def fpart(name, items):
	return Part(name, items, BOX["face"], K)


def _eye_white(c, r, sx=1.0, sy=1.0, sw=DET + 0.5):
	return ellipse(c[0], c[1], r[0] * sx, r[1] * sy, fill=pal.HUSH["eye"], sw=sw)


def _pupil(c, r, dx=0.0, dy=0.0):
	x, y = c[0] + dx, c[1] + dy
	return [circle(x, y, r, fill=INK), circle(x - r * 0.35, y - r * 0.4, r * 0.34, fill="#FFFFFF"),
			circle(x + r * 0.35, y + r * 0.35, r * 0.14, fill="#FFFFFF")]


def _lash(c, r, far=False):
	"""thin painted flick at the outer-upper corner (warm 'eye paint', never heavy)."""
	if not far:
		x, y = c[0] - r[0] * 0.8, c[1] - r[1] * 0.62
		return [path("M%s %s L%s %s" % (f(x), f(y), f(x - 6), f(y - 5)), sw=3)]
	x, y = c[0] + r[0] * 0.8, c[1] - r[1] * 0.62
	return [path("M%s %s L%s %s" % (f(x), f(y), f(x + 5), f(y - 5)), sw=3)]


def _lid(c, r, cover, slant=0.0, color=None, pupil=None, pr=8.0, pdx=0.0, pdy=0.0):
	"""An eye white with its upper part covered by a skin-coloured lid: cover in [0,1] (fraction of
	height), slant (deg) tips the lid line. Pupil baked in (under the lid) when given."""
	color = color or pal.HUSH["paint"]
	out = [ellipse(c[0], c[1], r[0], r[1], fill=pal.HUSH["eye"])]
	if pupil:
		out += _pupil(c, pr, pdx, pdy)
	# lid polygon: ellipse points above the lid line
	ly = c[1] - r[1] + 2 * r[1] * cover
	pts = ellipse_pts(c[0], c[1], r[0] + 0.5, r[1] + 0.5, n=48)
	lidp = [p for p in pts if (p[1] - c[1]) < (ly - c[1]) + math.tan(math.radians(slant)) * (p[0] - c[0])]
	if len(lidp) >= 3:
		# order by angle to keep a clean polygon, then close along the lid line
		lidp.sort(key=lambda p: math.atan2(p[1] - c[1], p[0] - c[0]))
		xl = c[0] - r[0] - 1; xr = c[0] + r[0] + 1
		tl = (xl, ly + math.tan(math.radians(slant)) * (xl - c[0]))
		tr = (xr, ly + math.tan(math.radians(slant)) * (xr - c[0]))
		poly = [tl] + lidp + [tr]
		out += [path(pts_path(poly), fill=color)]
		out += [path("M%s %s L%s %s" % (f(tl[0] + 3), f(tl[1]), f(tr[0] - 3), f(tr[1])), sw=DET + 0.5)]
	out += [ellipse(c[0], c[1], r[0], r[1], sw=DET + 0.5)]
	return out


def eyes(skin, variant):
	lid_c = pal.HUSH["paint"] if skin == "hush" else pal.PIP["skin"]
	it = []
	lash = skin == "hush"
	if variant == "open":
		it += [_eye_white(E1, R1), _eye_white(E2, R2)]
		if lash:
			it += _lash(E1, R1) + _lash(E2, R2, far=True)
	elif variant == "wide":
		it += [_eye_white(E1, R1, 1.2, 1.18), _eye_white(E2, R2, 1.2, 1.16)]
		if lash:
			it += _lash(E1, (R1[0] * 1.2, R1[1] * 1.18)) + _lash(E2, (R2[0] * 1.2, R2[1] * 1.16), far=True)
	elif variant == "half":
		it += _lid(E1, R1, 0.5, 0, lid_c, True, PUP1, 0, 0) + _lid(E2, R2, 0.5, 0, lid_c, True, PUP2, 0, 0)
		if lash:
			it += _lash(E1, R1) + _lash(E2, R2, far=True)
	elif variant == "worried":
		# inner corners raised: near lid slopes down to the outside (left), far to the right
		it += _lid(E1, R1, 0.32, 16, lid_c, True, PUP1, 1, -2) + _lid(E2, R2, 0.32, -16, lid_c, True, PUP2, -1, -2)
	elif variant == "squint":
		it += _lid(E1, R1, 0.42, -6, lid_c, True, PUP1, 2, 2) + _lid(E2, R2, 0.42, 6, lid_c, True, PUP2, 2, 2)
		it += [path("M%s %s Q%s %s %s %s" % (f(E1[0] - 11), f(E1[1] + 12), f(E1[0]), f(E1[1] + 16), f(E1[0] + 11),
												f(E1[1] + 12)), sw=3)]
		it += [path("M%s %s Q%s %s %s %s" % (f(E2[0] - 9), f(E2[1] + 11), f(E2[0]), f(E2[1] + 14), f(E2[0] + 9),
												f(E2[1] + 11)), sw=3)]
	elif variant == "closed":
		for c, r, far in ((E1, R1, False), (E2, R2, True)):
			it += [path("M%s %s Q%s %s %s %s" % (f(c[0] - r[0]), f(c[1] + 1), f(c[0]), f(c[1] + r[1] * 0.75),
													f(c[0] + r[0]), f(c[1] + 1)), sw=DET + 1)]
			if lash:
				x = c[0] - r[0] * 0.9 if not far else c[0] + r[0] * 0.9
				it += [path("M%s %s L%s %s" % (f(x), f(c[1] + 3), f(x + (-5 if not far else 5)), f(c[1] + 1)), sw=3)]
	elif variant == "happy":
		for c, r in ((E1, R1), (E2, R2)):
			it += [path("M%s %s Q%s %s %s %s" % (f(c[0] - r[0]), f(c[1] + 5), f(c[0]), f(c[1] - r[1] * 1.0),
													f(c[0] + r[0]), f(c[1] + 5)), sw=DET + 1.5)]
	elif variant == "wink":
		# near eye winks shut (a happy arc), far eye open with its pupil baked in
		it += [path("M%s %s Q%s %s %s %s" % (f(E1[0] - R1[0]), f(E1[1] + 4), f(E1[0]), f(E1[1] - R1[1] * 0.9),
												f(E1[0] + R1[0]), f(E1[1] + 4)), sw=DET + 1.5)]
		it += [path("M%s %s L%s %s" % (f(E1[0] - R1[0] - 1), f(E1[1] + 4), f(E1[0] - R1[0] - 6), f(E1[1] + 8)), sw=3)]
		it += [_eye_white(E2, R2)] + _pupil(E2, PUP2, -1, 1)
		if lash:
			it += _lash(E2, R2, far=True)
	return fpart("eyes_" + variant, it)


EYE_VARIANTS = ["open", "half", "closed", "wide", "happy", "worried", "squint", "wink"]
NO_PUPILS = ["half", "closed", "happy", "worried", "squint", "wink"]   # pupils baked or hidden


LOOKS = [("centre", (0, 0)), ("left", (-5, 0)), ("right", (5, 0)), ("up", (0, -4)), ("down", (0, 3)),
		 ("down_left", (-4, 3)), ("up_right", (4, -3))]


def pupils(skin, look="centre"):
	dx, dy = dict(LOOKS)[look]
	it = _pupil(E1, PUP1, dx, dy) + _pupil(E2, PUP2, dx, dy)
	return fpart("pupils" if look == "centre" else "pupils_" + look, it)


def brows(skin, variant):
	col = INK if skin == "hush" else pal.PIP["brow"]
	w = 4.0 if skin == "hush" else 6.0
	sw_kw = dict(stroke=col, stroke_width=w, stroke_linecap="round", stroke_linejoin="round", fill="none")
	# (near brow pts, far brow pts) in face coords
	b1y, b2y = E1[1] - 27, E2[1] - 25
	V = {
		"neutral": ([(E1[0] - 13, b1y + 3), (E1[0], b1y - 2), (E1[0] + 12, b1y + 1)],
					[(E2[0] - 9, b2y + 1), (E2[0] + 1, b2y - 2), (E2[0] + 11, b2y + 3)]),
		"up": ([(E1[0] - 13, b1y - 3), (E1[0], b1y - 11), (E1[0] + 12, b1y - 6)],
			   [(E2[0] - 9, b2y - 6), (E2[0] + 1, b2y - 11), (E2[0] + 11, b2y - 4)]),
		"worried": ([(E1[0] - 13, b1y + 4), (E1[0], b1y - 2), (E1[0] + 12, b1y - 9)],
					[(E2[0] - 10, b2y - 9), (E2[0] + 1, b2y - 2), (E2[0] + 11, b2y + 3)]),
		"sly": ([(E1[0] - 13, b1y - 2), (E1[0], b1y + 2), (E1[0] + 12, b1y + 6)],
				[(E2[0] - 9, b2y - 4), (E2[0] + 1, b2y - 10), (E2[0] + 11, b2y - 7)]),
		"determined": ([(E1[0] - 13, b1y - 5), (E1[0], b1y + 1), (E1[0] + 12, b1y + 7)],
					   [(E2[0] - 10, b2y + 6), (E2[0] + 1, b2y + 1), (E2[0] + 11, b2y - 4)]),
	}
	a, b = V[variant]
	it = [path(smooth_open(a, 0.6), **sw_kw), path(smooth_open(b, 0.6), **sw_kw)]
	return fpart("brows_" + variant, it)


BROW_VARIANTS = ["neutral", "up", "worried", "sly", "determined"]


def mouth(skin, variant):
	lip = pal.HUSH["lip"] if skin == "hush" else None
	M = pal.HUSH["mouth"]; T = pal.HUSH["tongue"]; W = "#FFFFFF"
	cx, cy = MOUTH
	it = []
	if variant == "smile":
		d = "M%s %s Q%s %s %s %s" % (f(cx - 13), f(cy - 3), f(cx), f(cy + 8), f(cx + 12), f(cy - 5))
		if lip:
			it += [path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % (f(cx - 12), f(cy - 3), f(cx), f(cy + 10), f(cx + 11),
																f(cy - 5), f(cx), f(cy + 3), f(cx - 12), f(cy - 3)),
						fill=lip)]
		it += [path(d, sw=DET + 0.5)]
		it += [path("M%s %s L%s %s" % (f(cx + 12), f(cy - 5), f(cx + 14), f(cy - 8)), sw=3)]   # dimple
	elif variant == "grin":
		cx, cy = MOUTH[0] - 4, MOUTH[1]
		d = smooth_closed([(cx - 23, cy - 7), (cx, cy - 3), (cx + 22, cy - 10), (cx + 14, cy + 9), (cx, cy + 13),
						   (cx - 15, cy + 8)], 0.5)
		it += [path(d, fill=M)]
		it += [path(smooth_closed([(cx - 19, cy - 6), (cx, cy - 2), (cx + 18, cy - 9), (cx + 15, cy - 2),
								   (cx, cy + 2), (cx - 15, cy)], 0.5), fill=W)]
		it += [ellipse(cx + 1, cy + 9, 8, 3.5, fill=T)]
		it += [path(d, sw=DET + 0.5)]
	elif variant == "O":
		it += [ellipse(cx + 1, cy + 3, 8, 10, fill=M, sw=DET + 0.5), ellipse(cx + 1, cy + 8, 4.5, 3, fill=T)]
	elif variant == "shh":
		# pursed, pushed to the side (the finger goes to the lips)
		if lip:
			it += [ellipse(cx + 2, cy + 1, 7, 5, fill=lip, sw=DET)]
		else:
			it += [ellipse(cx + 2, cy + 1, 6, 4.5, fill=M, sw=DET)]
		it += [path("M%s %s L%s %s" % (f(cx - 1), f(cy + 1), f(cx + 5), f(cy + 1)), sw=2.5)]
	elif variant == "grimace":
		cx, cy = MOUTH[0] - 4, MOUTH[1]
		d = smooth_closed([(cx - 24, cy - 2), (cx, cy - 6), (cx + 23, cy - 4), (cx + 22, cy + 8), (cx, cy + 10),
						   (cx - 23, cy + 7)], 0.4)
		it += [path(d, fill=W)]
		it += [path("M%s %s L%s %s" % (f(cx - 22), f(cy + 2), f(cx + 22), f(cy + 2)), sw=2.8)]
		for x in (-14, -5, 4, 13):
			it += [path("M%s %s L%s %s" % (f(cx + x), f(cy - 4), f(cx + x), f(cy + 8)), sw=2.8)]
		it += [path(d, sw=DET + 0.5)]
	elif variant == "wavy":
		it += [path("M%s %s Q%s %s %s %s T%s %s T%s %s" % (f(cx - 14), f(cy + 2), f(cx - 9), f(cy - 4), f(cx - 4),
														   f(cy + 1), f(cx + 6), f(cy + 1), f(cx + 14), f(cy - 1)),
					sw=DET + 0.5)]
	elif variant == "laugh":
		cx, cy = MOUTH[0] - 4, MOUTH[1]
		d = smooth_closed([(cx - 23, cy - 8), (cx, cy - 5), (cx + 23, cy - 11), (cx + 16, cy + 14), (cx, cy + 22),
						   (cx - 16, cy + 13)], 0.55)
		it += [path(d, fill=M)]
		it += [path(smooth_closed([(cx - 19, cy - 7), (cx, cy - 4), (cx + 19, cy - 10), (cx + 16, cy - 3),
								   (cx, cy), (cx - 16, cy - 1)], 0.5), fill=W)]
		it += [ellipse(cx, cy + 15, 10, 5, fill=T)]
		it += [path(d, sw=DET + 0.5)]
	elif variant == "puffed":
		# held breath: cheeks bulge past the face outline, lips pressed tight
		col = pal.HUSH["paint"] if skin == "hush" else pal.PIP["skin"]
		cs = pal.HUSH["paint_s"] if skin == "hush" else pal.PIP["skin_s"]
		for (x, y, rx, ry) in ((cx + 26, cy - 6, 13, 15), (cx - 26, cy - 3, 12, 13)):
			it += [ellipse(x, y, rx, ry, fill=cs, sw=DET + 0.5), ellipse(x - 2, y - 2, rx * 0.8, ry * 0.8, fill=col)]
			it += [ellipse(x - 1, y + 2, rx * 0.55, ry * 0.4, fill=pal.HUSH["cheek"], fill_opacity=0.85)]
		if lip:
			it += [ellipse(cx + 1, cy, 7, 4, fill=lip, sw=DET)]
		else:
			it += [ellipse(cx + 1, cy, 5, 3.5, fill=M, sw=DET)]
	elif variant == "tongue":
		# concentration: tongue poking out of the corner
		it += [path("M%s %s Q%s %s %s %s" % (f(cx - 12), f(cy - 1), f(cx - 2), f(cy + 4), f(cx + 10), f(cy - 3)),
					sw=DET + 0.5)]
		it += [path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % (f(cx + 3), f(cy + 1), f(cx + 9), f(cy + 14), f(cx + 14),
															f(cy + 7), f(cx + 13), f(cy - 1), f(cx + 3), f(cy + 1)),
					fill=T, sw=DET)]
	return fpart("mouth_" + variant, it)


MOUTH_VARIANTS = ["smile", "grin", "O", "shh", "grimace", "wavy", "laugh", "puffed", "tongue"]


def overlay(skin, kind):
	it = []
	if kind == "blush":
		for (x, y, rx, ry) in ((E1[0] - 4, 29, 15, 9), (E2[0] + 12, 28, 7, 8)):
			it += [ellipse(x, y, rx, ry, fill="#FF6F86", fill_opacity=0.55)]
			for k in (-1, 0, 1):
				it += [path("M%s %s L%s %s" % (f(x + k * rx * 0.45 - 2), f(y + 3), f(x + k * rx * 0.45 + 2),
											   f(y - 3)), stroke="#E2405E", stroke_width=2.5, stroke_linecap="round")]
	elif kind == "sweat":
		c = pal.HUSH["sweat"]; s = pal.HUSH["sweat_s"]
		for (x, y, k) in ((36, -40, 1.0), (44, -20, 0.7)):
			d = "M%s %s Q%s %s %s %s A%s %s 0 1 1 %s %s Q%s %s %s %s Z" % (
				f(x), f(y - 12 * k), f(x + 7 * k), f(y - 2 * k), f(x + 6 * k), f(y + 3 * k), f(6 * k), f(6 * k),
				f(x - 6 * k), f(y + 3 * k), f(x - 7 * k), f(y - 2 * k), f(x), f(y - 12 * k))
			it += [path(d, fill=s, sw=3), circle(x - 2 * k, y + 1 * k, 2 * k, fill="#FFFFFF", fill_opacity=0.8)]
	elif kind == "tear":
		c = pal.HUSH["sweat"]
		x, y = E1[0] - 4, E1[1] + 16
		it += [path("M%s %s Q%s %s %s %s" % (f(x), f(y), f(x - 3), f(y + 10), f(x - 1), f(y + 20)), fill="none",
					stroke=INK, stroke_width=9, stroke_linecap="round"),
			   path("M%s %s Q%s %s %s %s" % (f(x), f(y), f(x - 3), f(y + 10), f(x - 1), f(y + 20)), fill="none",
					stroke=c, stroke_width=4, stroke_linecap="round")]
		it += [path("M%s %s Q%s %s %s %s A6 6 0 1 1 %s %s Q%s %s %s %s Z" % (
			f(x - 1), f(y + 18), f(x + 5), f(y + 26), f(x + 5), f(y + 29), f(x - 7), f(y + 29), f(x - 7), f(y + 26),
			f(x - 1), f(y + 18)), fill=c, sw=3)]
	return fpart("fx_" + kind, it)


OVERLAYS = ["blush", "sweat", "tear"]


def head_tomato(skin):
	"""TOMATO residue overlay on the head canvas (same pivot): a splat on the brow + drips + a seed or two."""
	it = []
	blob = [(-10, -104), (8, -110), (30, -104), (48, -92), (56, -76), (44, -70), (52, -58), (36, -60), (30, -48),
			(20, -60), (6, -52), (2, -66), (-14, -62), (-10, -76), (-24, -84)]
	d = smooth_closed(blob, 0.6)
	it += shaded(d, H["tomato"], H["tomato_s"], (10, -90), s=0.86, dx=-2, dy=-2, sw=SW)
	for (x, y, L) in ((30, -48, 12), (6, -52, 16), (46, -64, 10)):
		it += [path("M%s %s L%s %s" % (f(x), f(y), f(x), f(y + L)), stroke=INK, stroke_width=10, stroke_linecap="round"),
			   path("M%s %s L%s %s" % (f(x), f(y), f(x), f(y + L)), stroke=H["tomato"], stroke_width=4.5,
					stroke_linecap="round")]
	it += [ellipse(18, -86, 3, 2, fill=H["seed"], transform="rotate(30 18 -86)"),
		   ellipse(34, -80, 3, 2, fill=H["seed"], transform="rotate(-20 34 -80)"),
		   ellipse(4, -78, 2.6, 1.8, fill=H["seed"])]
	it += [path("M20 -112 L24 -120 M20 -112 L14 -118 M20 -112 L28 -114", stroke=H["stalk"], stroke_width=4,
				stroke_linecap="round")]
	it += [highlight(0, -96, 7, 3, ang=-20, op=0.55)]
	return part("head_tomato", it)


# ===================================================================================================
# HIDDEN LOOK: eyes + gloved fingertips in a dark gap (hiding spots). Centre = (0, 0).
def hidden(skin, variant):
	it = []
	dark = "#120E1E"
	it += [path(smooth_closed([(-80, -8), (-70, -38), (-30, -44), (20, -42), (70, -40), (82, -8), (76, 30),
								(30, 42), (-30, 40), (-74, 32)], 0.6), fill=dark, fill_opacity=0.92)]
	e1, e2 = (-22, -8), (20, -8)
	r = (15, 18)
	if variant in ("eyes", "whites"):
		it += [ellipse(e1[0], e1[1], r[0], r[1], fill="#FFFFFF", sw=DET), ellipse(e2[0], e2[1], r[0], r[1], fill="#FFFFFF", sw=DET)]
		if variant == "eyes":
			it += _pupil(e1, 8.5) + _pupil(e2, 8.5)
	elif variant == "blink":
		for c in (e1, e2):
			it += [path("M%s %s Q%s %s %s %s" % (f(c[0] - 14), f(c[1]), f(c[0]), f(c[1] + 10), f(c[0] + 14), f(c[1])),
						stroke="#FFFFFF", stroke_width=5, stroke_linecap="round", fill="none")]
	elif variant == "pupils":
		it = _pupil(e1, 8.5) + _pupil(e2, 8.5)
		return Part("hidden_pupils", it, BOX["hidden"], K)
	if variant != "pupils":
		# four gloved fingertips curled over the bottom edge of the gap (the gloves act, even hidden)
		gb = pal.HUSH["glove"] if skin == "hush" else pal.PIP["mitten"]
		gs = pal.HUSH["glove_s"] if skin == "hush" else pal.PIP["mitten_s"]
		u = Union(gb, gs, sw=SW, inset=3.4, shift=2.4)
		for x in (-50, -38, 36, 48):
			u.add_capsule(x, 30, x + (2 if x > 0 else -2), 42, 12)
		it += u.render()
	name = {"eyes": "hidden_eyes", "whites": "hidden_eyes_whites", "blink": "hidden_eyes_blink"}[variant]
	return Part(name, it, BOX["hidden"], K)


# ===================================================================================================
# CLARENCE — rubber chicken prop, pivot = the grip point (mid body). 90 px tall at rest.
def clarence(state):
	C = pal.CLARENCE
	it = []
	Y, Ys = C["yellow"], C["yellow_s"]
	if state == "limp":
		body = dict(c=(0, 6), rx=14, ry=21, ang=8)
		neck = [(2, -12), (10, -24), (20, -26), (26, -18)]
		headc, head_r, head_ang = (28, -10), 12, 110
		eyes_k, beak_open = "droopy", 0.25
	elif state == "squeezed":
		body = dict(c=(0, 8), rx=21, ry=13, ang=0)
		neck = [(0, -2), (1, -14), (2, -24)]
		headc, head_r, head_ang = (3, -36), 14, -8
		eyes_k, beak_open = "bulge", 1.0
	elif state == "stretched":
		body = dict(c=(0, 8), rx=11, ry=24, ang=0)
		neck = [(0, -12), (-2, -34), (2, -56), (6, -66)]
		headc, head_r, head_ang = (8, -74), 11, -24
		eyes_k, beak_open = "squint", 0.8
	else:  # smitten
		body = dict(c=(0, 6), rx=14, ry=20, ang=0)
		neck = [(0, -12), (0, -24), (2, -32)]
		headc, head_r, head_ang = (3, -42), 13, 0
		eyes_k, beak_open = "hearts", 0.0
	# legs + feet (behind the body)
	for (x, ang) in ((-6, 8), (6, -8)):
		a = (x, body["c"][1] + body["ry"] - 4)
		b = (x + math.sin(math.radians(ang)) * 16, a[1] + 16)
		it += [path("M%s %s L%s %s" % (f(a[0]), f(a[1]), f(b[0]), f(b[1])), stroke=INK, stroke_width=9, stroke_linecap="round"),
			   path("M%s %s L%s %s" % (f(a[0]), f(a[1]), f(b[0]), f(b[1])), stroke=C["beak"], stroke_width=3.5, stroke_linecap="round")]
		for t in (-35, 0, 35):
			tip = polar(b, 7, 90 + t)
			it += [path("M%s %s L%s %s" % (f(b[0]), f(b[1]), f(tip[0]), f(tip[1])), stroke=INK, stroke_width=4, stroke_linecap="round")]
	# neck: a thick yellow hose
	nd = smooth_open(neck, 0.6)
	it += [path(nd, stroke=INK, stroke_width=17, stroke_linecap="round", stroke_linejoin="round", fill="none"),
		   path(nd, stroke=Ys, stroke_width=8, stroke_linecap="round", fill="none"),
		   path(nd, stroke=Y, stroke_width=5, stroke_linecap="round", fill="none", transform="translate(-1.5 -0.5)")]
	# body
	bc = body["c"]
	bpts = ellipse_pts(bc[0], bc[1], body["rx"], body["ry"], n=14, ang=body["ang"])
	bd = smooth_closed(bpts, 0.5)
	it += shaded(bd, Y, Ys, (bc[0] - 4, bc[1] - 6), s=0.84, dx=-1, dy=-2)
	# wing flap
	wx, wy = bc[0] + body["rx"] * 0.35, bc[1] - body["ry"] * 0.1
	it += [path("M%s %s Q%s %s %s %s Q%s %s %s %s" % (f(wx - 6), f(wy - 6), f(wx + 10), f(wy - 2), f(wx + 6), f(wy + 12),
													   f(wx - 2), f(wy + 6), f(wx - 6), f(wy - 6)), fill=Ys, sw=svgk.DET)]
	# pimply "rubber" dots
	it += [circle(bc[0] - body["rx"] * 0.4, bc[1] + body["ry"] * 0.35, 1.8, fill=Ys),
		   circle(bc[0] - body["rx"] * 0.1, bc[1] + body["ry"] * 0.55, 1.6, fill=Ys)]
	it += [highlight(bc[0] - body["rx"] * 0.45, bc[1] - body["ry"] * 0.45, 3.5, 6, ang=20, op=0.55)]
	# head group (rotated about the head centre)
	hx, hy = headc
	hitems = []
	# comb (3 bumps) and wattle
	comb = [(hx - 9, hy - 9), (hx - 10, hy - 19), (hx - 4, hy - 17), (hx - 1, hy - 25), (hx + 4, hy - 17),
			(hx + 10, hy - 21), (hx + 9, hy - 10)]
	hitems += [path(smooth_closed(comb, 0.4), fill=C["comb"], sw=svgk.DET + 0.5)]
	hitems += [circle(hx, hy, head_r, fill=Ys, sw=svgk.DET + 0.5), circle(hx - 1.5, hy - 1.5, head_r * 0.82, fill=Y)]
	# beak: upper + lower jaw (open amount), pointing +x
	bo = beak_open
	bx = hx + head_r - 3
	up = "M%s %s L%s %s L%s %s Z" % (f(bx), f(hy - 6), f(bx + 18), f(hy - 1 - bo * 4), f(bx), f(hy + 1))
	lo = "M%s %s L%s %s L%s %s Z" % (f(bx), f(hy + 1), f(bx + 14), f(hy + 3 + bo * 9), f(bx), f(hy + 6 + bo * 2))
	if bo > 0.05:
		hitems += [path("M%s %s L%s %s L%s %s Z" % (f(bx), f(hy - 2), f(bx + 16), f(hy + 1 + bo * 3), f(bx), f(hy + 4)),
						fill=pal.HUSH["mouth"])]
	hitems += [path(lo, fill=C["beak_s"], sw=svgk.DET), path(up, fill=C["beak"], sw=svgk.DET)]
	# wattle
	hitems += [path("M%s %s Q%s %s %s %s Q%s %s %s %s Z" % (f(bx - 1), f(hy + 6), f(bx + 4), f(hy + 16), f(bx - 3),
															f(hy + 16), f(bx - 7), f(hy + 11), f(bx - 1), f(hy + 6)),
					fill=C["comb"], sw=svgk.DET)]
	ex, ey = hx + 1, hy - 3
	if eyes_k == "bulge":
		hitems += [circle(ex - 5, ey - 2, 7.5, fill="#FFFFFF", sw=svgk.DET), circle(ex + 5, ey - 3, 6.5, fill="#FFFFFF", sw=svgk.DET),
				   circle(ex - 4, ey - 1, 2.5, fill=INK), circle(ex + 6, ey - 2, 2.2, fill=INK)]
	elif eyes_k == "droopy":
		hitems += [circle(ex - 3, ey, 5.5, fill="#FFFFFF", sw=svgk.DET),
				   path("M%s %s L%s %s" % (f(ex - 8.5), f(ey), f(ex + 2.5), f(ey)), sw=3),
				   circle(ex - 3, ey + 2.5, 2, fill=INK)]
	elif eyes_k == "squint":
		hitems += [path("M%s %s L%s %s L%s %s" % (f(ex - 8), f(ey - 5), f(ex - 1), f(ey - 1), f(ex - 8), f(ey + 3)), sw=3),
				   path("M%s %s L%s %s L%s %s" % (f(ex + 7), f(ey - 5), f(ex + 1), f(ey - 1), f(ex + 7), f(ey + 3)), sw=3)]
	elif eyes_k == "hearts":
		hitems += [path(heart_path(ex - 4, ey - 1, 4.2), fill=C["comb"], sw=2.5),
				   path(heart_path(ex + 6, ey - 2, 3.6), fill=C["comb"], sw=2.5),
				   ellipse(ex - 2, ey + 8, 4, 2.5, fill=pal.HUSH["cheek"], fill_opacity=0.9)]
	it += [g(hitems, transform="rotate(%s %s %s)" % (f(head_ang), f(hx), f(hy)))] if head_ang else hitems
	return Part("clarence_" + state, [g(it, transform="translate(0 -26)")], BOX["clarence"])


CLARENCE_STATES = ["limp", "squeezed", "stretched", "smitten"]


# ===================================================================================================
def build(skin):
	"""-> {relative file name: svg text} for one skin. Hush-only assets (hidden look, Clarence, tomato) are
	emitted for skin 'hush'; Pip re-emits every part whose look differs (incl. the hidden look)."""
	out = {}
	parts = [pelvis(skin), torso(skin), braces_front(skin), braces_loop(skin), head(skin), hair_back(skin),
			 beret(skin)]
	for far in (False, True):
		for gname in HAND_TEX:
			parts.append(hand(skin, gname, far))
		for st in ("flat", "tiptoe"):
			parts.append(foot(skin, st, far))
	for v in EYE_VARIANTS:
		parts.append(eyes(skin, v))
	for look, _ in LOOKS:
		parts.append(pupils(skin, look))
	for v in BROW_VARIANTS:
		parts.append(brows(skin, v))
	for v in MOUTH_VARIANTS:
		parts.append(mouth(skin, v))
	for k in OVERLAYS:
		parts.append(overlay(skin, k))
	parts.append(head_tomato(skin))
	for v in ("eyes", "whites", "blink", "pupils"):
		parts.append(hidden(skin, v))
	if skin == "hush":
		for st in CLARENCE_STATES:
			parts.append(clarence(st))
	for p in parts:
		out[p.name + ".svg"] = p.svg()
	return out
