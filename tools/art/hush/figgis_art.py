"""Old Figgis, the ancient prompter: a front-facing bust in his hooded prompt box for the 128 px HUD chip.

Rig id `figgis` (TECH 4.7 format). Chip-local coordinates: origin = the chip's bottom centre, y up is negative,
the whole bust fits x -64..64, y -128..0 at zoom 1.0. Outlines are 5 px (it is shown at HUD size).
Parts: hood (root: canopy + interior), box (the front lip), body, head, ear_l/ear_r (springs), specs,
hand_l/hand_r (textures hold, point, shh, cup); prop `card` (blank cue card; the UI draws item icons in
`icon_rect`). Face: eyes x3 (open, happy, wide), mouth x3 (psst, smile, shh).
"""
from collections import OrderedDict

from svgk import (INK, Part, Union, path, circle, ellipse, rect, g, line, smooth_closed, smooth_open, shaded,
				  capsule_d, highlight, f, polar)
import pal

C = pal.FIGGIS
SW = 5.0
DET = 3.0
ART = "res://art/chars/figgis/"

# joint layout (parent-joint relative)
BODY_OFF = (0, -24)       # from hood
HEAD_OFF = (0, -30)       # from body  -> head joint world (0, -54)
EAR_L_OFF, EAR_R_OFF = (-19, -30), (19, -30)   # from head
SPECS_OFF = (0, -18)      # from head (on the nose)
HAND_L_OFF, HAND_R_OFF = (-30, -6), (30, -6)   # from body
CARD_SOCKET = (0, 6)      # body local
FACE_OFF = (0, -30)       # from head

BOX = {
	"hood": (-72, -138, 72, 14),
	"box": (-74, -29, 74, 7),
	"body": (-46, -17, 46, 36),
	"head": (-34, -74, 34, 8),
	"ear_l": (-40, -30, 10, 30),
	"ear_r": (-10, -30, 40, 30),
	"specs": (-30, -14, 30, 10),
	"hand": (-24, -36, 24, 22),
	"face": (-24, -22, 24, 32),
	"card": (-40, -50, 40, 8),
}


def P(name, items, key=None):
	return Part(name, items, BOX[key or name])


def hood():
	it = []
	# dark interior of the box, then the scalloped canopy shell around it
	it += [path(smooth_closed([(-50, 0), (-52, -70), (-34, -104), (0, -114), (34, -104), (52, -70), (50, 0)], 0.55),
				fill=C["inside"])]
	shell_out = [(-62, 0), (-63, -64), (-50, -106), (-22, -126), (0, -128), (22, -126), (50, -106), (63, -64),
				 (62, 0), (50, 0), (51, -66), (34, -100), (0, -112), (-34, -100), (-51, -66), (-50, 0)]
	d = smooth_closed(shell_out, 0.35)
	it += [path(d, fill=C["hood_s"])]
	it += [path(smooth_closed([(-60, 0), (-60, -64), (-48, -103), (-21, -122), (0, -124), (21, -122), (48, -103),
							   (58, -64), (56, -4), (52, -4), (52, -66), (35, -102), (0, -114), (-35, -102),
							   (-53, -66), (-53, -4)], 0.35), fill=C["hood"])]
	# gold ribs across the shell band (inner arch -> outer edge)
	inner = [(-51, -66), (-34, -100), (0, -112), (34, -100), (51, -66)]
	outer = [(-61, -64), (-48, -104), (0, -124), (48, -104), (61, -64)]
	for (ix, iy), (ox, oy) in zip(inner, outer):
		it += [line(ix + (ox - ix) * 0.25, iy + (oy - iy) * 0.25, ix + (ox - ix) * 0.75, iy + (oy - iy) * 0.75, sw=DET,
					stroke=C["gold"])]
	it += [path(d, sw=SW)]
	it += [circle(0, -126, 6, fill=C["gold"], sw=DET)]
	return P("hood", it)


def box():
	it = []
	d = smooth_closed([(-62, -20), (0, -22), (62, -20), (63, -2), (0, 0), (-63, -2)], 0.3)
	it += shaded(d, C["gold"], C["gold_s"], (-10, -14), s=0.9, dx=-1, dy=-1, sw=SW)
	it += [path("M-54 -11 Q0 -8 54 -11", sw=DET)]
	for x in (-40, 0, 40):
		it += [circle(x, -11, 3, fill=C["gold_s"], sw=2)]
	return P("box", it)


def body():
	it = []
	d = smooth_closed([(-34, 26), (-33, 4), (-22, -6), (0, -10), (22, -6), (33, 4), (34, 26)], 0.5)
	it += shaded(d, C["cardigan"], C["cardigan_s"], (-8, 6), s=0.88, sw=SW)
	it += [path("M-10 -8 L0 8 L10 -8", sw=DET, fill=C["card"])]   # shirt collar
	it += [circle(0, 16, 2.6, fill=C["gold"], sw=2)]
	return P("body", it)


def head():
	it = []
	d = smooth_closed([(0, -56), (18, -51), (24, -34), (22, -14), (13, -2), (0, 1), (-13, -2), (-22, -14), (-24, -34),
					   (-18, -51)], 0.6)
	it += shaded(d, C["skin"], C["skin_s"], (-4, -32), s=0.88, dx=-1, dy=-1, sw=SW)
	# wispy white hair tufts at the temples + two hairs on top
	for sx in (-1, 1):
		it += [path(smooth_closed([(sx * 20, -34), (sx * 27, -36), (sx * 28, -28), (sx * 24, -24), (sx * 21, -28)], 0.6),
					fill=C["hair"], sw=DET)]
	it += [path("M-3 -55 Q-7 -65 -1 -67", sw=2.5), path("M3 -55 Q5 -63 11 -63", sw=2.5)]
	# bushy white brows over the eyes
	it += [path(smooth_closed([(-17, -40), (-11, -45), (-3, -43), (-4, -39), (-11, -39)], 0.5), fill=C["hair"], sw=2.5),
		   path(smooth_closed([(17, -40), (11, -45), (3, -43), (4, -39), (11, -39)], 0.5), fill=C["hair"], sw=2.5)]
	# big round nose (the specs perch on it)
	it += [circle(0, -18, 7.5, fill=C["skin_s"], sw=DET), circle(-2, -20, 2.4, fill="#FFFFFF", fill_opacity=0.5)]
	it += [ellipse(-14, -12, 4.5, 3, fill="#F29A8E", fill_opacity=0.7), ellipse(14, -12, 4.5, 3, fill="#F29A8E",
																				 fill_opacity=0.7)]
	return P("head", it)


def ear(side):
	s = -1 if side == "l" else 1
	it = []
	pts = [(0, -16), (s * 18, -22), (s * 30, -10), (s * 31, 8), (s * 22, 22), (s * 8, 20), (0, 10)]
	d = smooth_closed(pts, 0.6)
	it += shaded(d, C["skin"], C["skin_s"], (s * 12, -4), s=0.86, dx=-1, dy=-1, sw=SW)
	it += [path(smooth_closed([(s * 8, -10), (s * 20, -12), (s * 24, 2), (s * 18, 14), (s * 10, 10)], 0.6),
				fill=C["ear_in"])]
	it += [path("M%s -6 Q%s 2 %s 10" % (f(s * 14), f(s * 19), f(s * 14)), sw=DET)]
	return P("ear_" + side, it)


def specs():
	"""little half-moon specs perched low on his nose (eyes peer OVER them)."""
	it = []
	for x in (-10, 10):
		it += [path("M%s -2 Q%s 8 %s -2 Z" % (f(x - 8), f(x), f(x + 8)), fill=C["glass"], fill_opacity=0.6, sw=DET),
			   path("M%s 0 L%s 2" % (f(x - 4), f(x - 2)), stroke="#FFFFFF", stroke_width=2, stroke_linecap="round")]
	it += [path("M-2 -2 Q0 -5 2 -2", sw=DET)]
	it += [line(-18, -2, -23, -6, sw=2.5), line(18, -2, 23, -6, sw=2.5)]
	return P("specs", it)


def hand(side, tex):
	"""knobbly little hands; joint = wrist at (0, 0), pointing UP (-y) at rest (he holds things up)."""
	s = -1 if side == "l" else 1
	u = Union(C["skin"], C["skin_s"], sw=SW, inset=2.5, shift=1.6)
	u.add_poly([(-9, 0), (-10, -10), (-6, -17), (6, -17), (10, -10), (9, 0), (0, 3)], 0.6)
	if tex == "hold":
		# fingers curled over a card edge (toward the centre of the chip)
		for k, y in enumerate((-18, -12, -6)):
			u.add_capsule(0, y, -s * 12, y - 1, 7)
		u.add_capsule(s * 6, -10, s * 12, -18, 7)
	elif tex == "point":
		u.add_capsule(0, -14, -s * 2, -28, 7)
		u.add_capsule(s * 7, -10, s * 12, -14, 7)
	elif tex == "shh":
		u.add_capsule(0, -14, 0, -29, 7)
		u.add_capsule(-s * 6, -12, -s * 8, -16, 7)
	elif tex == "cup":
		u.add_capsule(-s * 4, -16, -s * 12, -24, 7)
		u.add_capsule(s * 2, -16, -s * 4, -27, 7)
		u.add_capsule(s * 8, -12, s * 14, -18, 7)
	it = u.render()
	# cardigan cuff
	it += shaded(smooth_closed([(-10, -1), (10, -1), (10, 10), (-10, 10)], 0.4), C["cardigan"], C["cardigan_s"],
				 (-3, 4), s=0.86, sw=SW)
	return P("hand_%s_%s" % (side, tex), [g(it, transform="scale(0.82)")], "hand")


def face_slot(kind, variant):
	it = []
	if kind == "eyes":
		for x in (-11, 11):
			if variant == "open":
				it += [ellipse(x, 0, 5, 5.5, fill="#FFFFFF", sw=2.5), circle(x + 1, 1, 3, fill=INK),
					   circle(x, 0, 1, fill="#FFFFFF")]
			elif variant == "wide":
				it += [ellipse(x, -1, 6.5, 7.5, fill="#FFFFFF", sw=2.5), circle(x, -1, 2.8, fill=INK),
					   circle(x - 1, -2, 1, fill="#FFFFFF")]
			elif variant == "happy":
				it += [path("M%s 2 Q%s -5 %s 2" % (f(x - 5), f(x), f(x + 5)), sw=3)]
	else:
		cy = 22
		if variant == "psst":
			it += [ellipse(5, cy, 4.5, 3.5, fill=pal.HUSH["mouth"], sw=2.5)]
		elif variant == "smile":
			it += [path("M-8 %s Q0 %s 8 %s" % (f(cy - 2), f(cy + 5), f(cy - 2)), sw=3)]
		elif variant == "shh":
			it += [path("M-5 %s L5 %s" % (f(cy), f(cy)), sw=3), path("M-6 %s Q0 %s 6 %s" % (f(cy - 3), f(cy - 5), f(cy - 3)), sw=2)]
	return P("%s_%s" % (kind, variant), it, "face")


def card(state="up"):
	it = []
	d = smooth_closed([(-30, -2), (-31, -40), (0, -42), (31, -40), (30, -2), (0, 0)], 0.25)
	it += shaded(d, C["card"], C["card_s"], (-6, -24), s=0.92, dx=-1, dy=-1, sw=SW)
	it += [path("M-24 -38 L24 -38", sw=1.5, stroke_opacity=0.25)]
	return P("card_" + state, it, "card")


HAND_TEX = ["hold", "point", "shh", "cup"]


def build():
	parts = [hood(), box(), body(), head(), ear("l"), ear("r"), specs(), card("up")]
	for side in ("l", "r"):
		for t in HAND_TEX:
			parts.append(hand(side, t))
	for v in ("open", "happy", "wide"):
		parts.append(face_slot("eyes", v))
	for v in ("psst", "smile", "shh"):
		parts.append(face_slot("mouth", v))
	return {p.name + ".svg": p.svg() for p in parts}


def _pv(key):
	b = BOX[key]
	return [round(-b[0], 1), round(-b[1], 1)]


def rig():
	parts = OrderedDict()
	parts["hood"] = {"file": ART + "hood.svg", "offset": [0, 0], "pivot": _pv("hood"), "z": 0}
	parts["box"] = {"parent": "hood", "offset": [0, 0], "file": ART + "box.svg", "pivot": _pv("box"), "z": 7}
	parts["body"] = {"parent": "hood", "offset": list(BODY_OFF), "file": ART + "body.svg", "pivot": _pv("body"), "z": 2,
					 "sockets": {"card": [round(CARD_SOCKET[0] - BOX["body"][0], 1), round(CARD_SOCKET[1] - BOX["body"][1], 1), 0]}}
	parts["head"] = {"parent": "body", "offset": list(HEAD_OFF), "file": ART + "head.svg", "pivot": _pv("head"), "z": 3,
					 "limits": {"rot": [-25, 25]}}
	parts["ear_l"] = {"parent": "head", "offset": list(EAR_L_OFF), "file": ART + "ear_l.svg", "pivot": _pv("ear_l"),
					  "z": 1, "spring": {"channel": "rot", "k": 160, "c": 6, "clamp": 20}}
	parts["ear_r"] = {"parent": "head", "offset": list(EAR_R_OFF), "file": ART + "ear_r.svg", "pivot": _pv("ear_r"),
					  "z": 1, "spring": {"channel": "rot", "k": 160, "c": 6, "clamp": 20}}
	parts["specs"] = {"parent": "head", "offset": list(SPECS_OFF), "file": ART + "specs.svg", "pivot": _pv("specs"),
					  "z": 6, "spring": {"channel": "rot", "k": 200, "c": 10, "clamp": 6}}
	for side, off in (("l", HAND_L_OFF), ("r", HAND_R_OFF)):
		tex = OrderedDict((t, ART + "hand_%s_%s.svg" % (side, t)) for t in HAND_TEX)
		parts["hand_" + side] = {"parent": "body", "offset": list(off), "tex": tex,
								 "default_tex": "hold", "pivot": _pv("hand"), "z": 9}
	fb = BOX["face"]
	pv = _pv("face")
	face = {"anchor": "head", "offset": list(FACE_OFF), "pivot": pv,
			"slots": OrderedDict([
				("eyes", {"z": 4, "pivot": pv, "default": "open",
						  "variants": OrderedDict((v, ART + "eyes_%s.svg" % v) for v in ("open", "happy", "wide"))}),
				("mouth", {"z": 5, "pivot": pv, "default": "smile",
						   "variants": OrderedDict((v, ART + "mouth_%s.svg" % v) for v in ("psst", "smile", "shh"))})]),
			"overlays": {}}
	cb = BOX["card"]
	r = OrderedDict()
	r["version"] = 1
	r["rig"] = "figgis"
	r["doc"] = ("Old Figgis HUD bust (TECH 4.7 conventions as rigs/hush/rig.json). Origin = the chip's bottom centre; "
				"the bust fits a 128 x 128 chip at zoom 1.0 (x -64..64, y -128..0). Hands point UP at rest. The card "
				"prop is blank: draw item icons inside props.card.icon_rect (card canvas px).")
	r["height_px"] = 128
	r["root_part"] = "hood"
	r["origin"] = "chip_bottom_centre"
	r["facing"] = 0
	r["parts"] = parts
	r["limbs"] = {}
	r["face"] = face
	r["props"] = {"card": {"file": ART + "card_up.svg", "pivot": _pv("card"), "socket": "body:card", "z": 8,
						   "z_offset": 6, "hidden": True, "default": "up",
						   "states": ["up"], "default_state": "up", "tex": {"up": ART + "card_up.svg"},
						   "icon_rect": [round(-24 - cb[0], 1), round(-37 - cb[1], 1), 48, 32]}}
	r["residues"] = {}
	r["mirror_pairs"] = [["_l", "_r"]]
	r["no_mirror"] = []
	return r


def faces():
	return OrderedDict([("version", 1), ("rig", "figgis"), ("presets", OrderedDict([
		("psst", {"eyes": "open", "mouth": "psst"}),
		("point", {"eyes": "wide", "mouth": "smile"}),
		("shh", {"eyes": "open", "mouth": "shh"}),
		("proud", {"eyes": "happy", "mouth": "smile"}),
	]))])


def poses():
	P_ = OrderedDict()
	P_["f_rest"] = {"root": {"x": 0, "y": 0, "rot": 0, "sx": 1, "sy": 1}, "face": "proud", "tags": ["idle"],
					"bones": {"hand_r": {"rot": 0, "tex": "hold"}, "hand_l": {"rot": 0, "tex": "hold"},
							  "body": {"y": 10}}, "props": {"card": {"vis": 0}},
					"silhouette": "sunk low in the box, only head and ears showing"}
	P_["f_psst"] = {"base": "f_rest", "face": "psst", "tags": ["cue", "psst"],
					"bones": {"body": {"y": 0, "rot": 6}, "head": {"rot": 8}, "hand_r": {"tex": "cup", "x": -14, "y": -30,
																						  "rot": -20}},
					"silhouette": "leaning out, hand cupped at his mouth"}
	P_["f_point"] = {"base": "f_rest", "face": "point", "tags": ["cue", "card"],
					 "bones": {"body": {"y": 0}, "hand_l": {"tex": "hold", "x": 2}, "hand_r": {"tex": "point", "x": 4, "y": -12, "rot": -30}},
					 "props": {"card": {"vis": 1}}, "silhouette": "card held up, finger jabbing at it"}
	P_["f_shh"] = {"base": "f_rest", "face": "shh", "tags": ["cue", "shh"],
				   "bones": {"body": {"y": 0}, "hand_r": {"tex": "shh", "x": -22, "y": -28, "rot": 0}},
				   "silhouette": "finger to his lips"}
	P_["f_proud"] = {"base": "f_rest", "face": "proud", "tags": ["cue", "card", "proud"],
					 "bones": {"body": {"y": -2}, "head": {"rot": -6, "y": -2}},
					 "props": {"card": {"vis": 1}}, "silhouette": "card held high in both hands, chin up"}
	return OrderedDict([("version", 1), ("rig", "figgis"), ("poses", P_), ("mirror_of", {})])
