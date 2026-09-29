"""rig.json + faces.json for Hush (rig id `hush`, skin `pip`), built from hush_art's geometry.

TECH 4.7 format. Conventions written into the file's `doc` key (the runtime rig must agree):
* offsets are the child's JOINT position in the parent's joint-local frame (unrotated, px); the ROOT part's
  `offset` is its joint position relative to the FEET ORIGIN (character position) at rest;
* `pivot` and `sockets` are in the part's CANVAS px (the joint = pivot); socket = [x, y, rot_deg];
* world(part) = world(parent) * T(offset + pose.xy) * R(pose.rot) * S(pose.sx, pose.sy); the pose `root`
  channels form a transform about the feet origin applied first (squash & stretch around the feet);
* limbs: a round-capped hose through the joints' world positions, quadratic with control 2*mid - (a+b)/2
  (the curve passes through the elbow/knee at t = 0.5); outline = extra ink width on each side;
* face slots are placed with their canvas `pivot` on head * T(face.offset); `pupils` shift by look-at within
  `range` and are hidden while the eyes variant is in `pupils.hide_with`.
"""
from collections import OrderedDict
import hush_art as A
import pal

ART = "res://art/chars/hush/"
PIP_ART = "res://art/chars/hush/pip/"

# back -> front
Z = OrderedDict([
	("arm_l", 0), ("hand_l", 1), ("braces_loop", 2), ("hair_back", 3), ("leg_l", 4), ("foot_l", 5),
	("leg_r", 6), ("foot_r", 7), ("torso", 8), ("clarence_braces", 9), ("braces_front", 10), ("pelvis", 11),
	("head", 12), ("blush", 13), ("eyes", 13), ("pupils", 14), ("mouth", 14), ("brows", 15), ("sweat", 16),
	("tear", 16), ("residue_head", 17), ("beret", 18), ("arm_r", 19), ("clarence_hand", 20), ("hand_r", 21),
])

LIMB_W_ARM, LIMB_W_LEG = 22, 24
LIMBS = {
	"hush": {"arm_r": "#2B3566", "arm_l": "#222B55", "leg_r": "#2B3566", "leg_l": "#222B55"},
	"pip": {"arm_r": pal.PIP["jumper"], "arm_l": pal.PIP["jumper_s"], "leg_r": pal.PIP["denim"], "leg_l": pal.PIP["denim_s"]},
}


def _c(key):
	pv, sz = A.canvas(key)
	return {"pivot": pv, "size": sz}


def _hand(side):
	tex = OrderedDict((t, ART + "hand_%s_%s.svg" % (side, t)) for t in A.HAND_TEX)
	d = {"parent": "arm_lower_" + side, "offset": [0, round(A.ARM_LO * A.K, 1)]}
	d.update(_c("hand"))
	d.update({"z": Z["hand_" + side], "tex": tex, "default_tex": "open", "limits": {"rot": [-120, 120]},
			  "sockets": {"grip": A.cpt("hand", (12, 24)) + [90]}})
	return d


def _foot(side):
	tex = OrderedDict((t, ART + "foot_%s_%s.svg" % (side, t)) for t in ("flat", "tiptoe"))
	d = {"parent": "leg_lower_" + side, "offset": [0, round(A.LEG_LO * A.K, 1)]}
	d.update(_c("foot"))
	d.update({"z": Z["foot_" + side], "tex": tex, "default_tex": "flat", "limits": {"rot": [-60, 80]}})
	return d


def _p(parent, offset, file_key, z, **extra):
	d = OrderedDict()
	if parent:
		d["parent"] = parent
	d["offset"] = A.S(offset)
	d["file"] = ART + file_key + ".svg"
	d.update(_c(file_key))
	d["z"] = z
	d.update(extra)
	return d


def parts():
	P = OrderedDict()
	P["pelvis"] = _p(None, A.ROOT_OFFSET, "pelvis", Z["pelvis"])
	P["torso"] = _p("pelvis", A.TORSO_OFF, "torso", Z["torso"], limits={"rot": [-75, 75]},
					sockets={"braces": A.cpt("torso", A.BRACES_TUCK) + [14]})
	P["braces_front"] = _p("torso", (0, 0), "braces_front", Z["braces_front"])
	P["braces_loop"] = _p("torso", A.BRACES_LOOP_OFF, "braces_loop", Z["braces_loop"], visible=False,
						  sockets={"grab": A.cpt("braces_loop", (-2, -104)) + [0]})
	P["head"] = _p("torso", A.NECK, "head", Z["head"], limits={"rot": [-40, 40]},
				   sockets={"hat": A.cpt("head", A.BERET_OFF) + [0]})
	P["hair_back"] = _p("head", A.HAIR_BACK_OFF, "hair_back", Z["hair_back"],
						spring={"channel": "rot", "k": 150, "c": 8, "clamp": 14})
	P["beret"] = _p("head", A.BERET_OFF, "beret", Z["beret"], spring={"channel": "rot", "k": 180, "c": 9, "clamp": 25})
	for side, sho in (("r", A.SHO_R), ("l", A.SHO_L)):
		P["arm_upper_" + side] = {"parent": "torso", "offset": A.S(sho), "pivot": [0, 0], "z": Z["arm_" + side],
								  "draw": "limb:arm_" + side, "limits": {"rot": [-200, 200]}}
		P["arm_lower_" + side] = {"parent": "arm_upper_" + side, "offset": [0, round(A.ARM_UP * A.K, 1)],
								  "pivot": [0, 0], "z": Z["arm_" + side], "draw": "limb:arm_" + side,
								  "limits": {"rot": [-175, 175]}}
		P["hand_" + side] = _hand(side)
	for side, hip in (("r", A.HIP_R), ("l", A.HIP_L)):
		P["leg_upper_" + side] = {"parent": "pelvis", "offset": A.S(hip), "pivot": [0, 0], "z": Z["leg_" + side],
								  "draw": "limb:leg_" + side, "limits": {"rot": [-130, 90]}}
		P["leg_lower_" + side] = {"parent": "leg_upper_" + side, "offset": [0, round(A.LEG_UP * A.K, 1)],
								  "pivot": [0, 0], "z": Z["leg_" + side], "draw": "limb:leg_" + side,
								  "limits": {"rot": [-30, 170]}}
		P["foot_" + side] = _foot(side)
	return P


def limbs(skin="hush"):
	L = OrderedDict()
	for side in ("r", "l"):
		L["arm_" + side] = {"joints": ["arm_upper_" + side, "arm_lower_" + side, "hand_" + side],
							"width": LIMB_W_ARM, "fill": LIMBS[skin]["arm_" + side], "outline": 6, "ink": pal.INK,
							"cap": "round"}
		L["leg_" + side] = {"joints": ["leg_upper_" + side, "leg_lower_" + side, "foot_" + side],
							"width": LIMB_W_LEG, "fill": LIMBS[skin]["leg_" + side], "outline": 6, "ink": pal.INK,
							"cap": "round"}
	return L


def face():
	pv, sz = A.canvas("face")
	slots = OrderedDict()
	slots["eyes"] = {"z": Z["eyes"], "pivot": pv, "size": sz, "default": "open",
					 "variants": OrderedDict((v, ART + "eyes_%s.svg" % v) for v in A.EYE_VARIANTS)}
	pup = OrderedDict((lk, ART + ("pupils.svg" if lk == "centre" else "pupils_%s.svg" % lk)) for lk, _ in A.LOOKS)
	slots["pupils"] = {"z": Z["pupils"], "pivot": pv, "size": sz, "default": "centre", "variants": pup,
					   "range": [6, 4], "hide_with": list(A.NO_PUPILS),
					   "doc": "look variants are baked offsets; look_at adds up to `range` on top. Presets set "
							  "pupils none whenever the eyes variant bakes its own pupils (hide_with)."}
	slots["brows"] = {"z": Z["brows"], "pivot": pv, "size": sz, "default": "neutral",
					  "variants": OrderedDict((v, ART + "brows_%s.svg" % v) for v in A.BROW_VARIANTS)}
	slots["mouth"] = {"z": Z["mouth"], "pivot": pv, "size": sz, "default": "smile",
					  "variants": OrderedDict((v, ART + "mouth_%s.svg" % v) for v in A.MOUTH_VARIANTS)}
	for k in A.OVERLAYS:
		slots[k] = {"z": Z[k], "pivot": pv, "size": sz, "default": "none", "overlay": True,
					"variants": {"on": ART + "fx_%s.svg" % k}}
	return {"anchor": "head", "offset": A.S(A.FACE_ANCHOR), "pivot": pv, "size": sz, "slots": slots}


def props():
	cb = A.BOX["clarence"]   # Clarence is drawn at 1x (90 px)
	tex = OrderedDict((s, ART + "clarence_%s.svg" % s) for s in A.CLARENCE_STATES)
	return {"clarence": {"file": tex["limp"], "pivot": [float(-cb[0]), float(-cb[1])],
						 "size": [cb[2] - cb[0], cb[3] - cb[1]], "socket": "torso:braces",
						 "sockets": ["torso:braces", "hand_r:grip"],
						 "z": Z["clarence_braces"], "z_by_socket": {"torso:braces": Z["clarence_braces"],
																	"hand_r:grip": Z["clarence_hand"]},
						 "states": list(A.CLARENCE_STATES), "default_state": "limp", "tex": tex}}


def hidden():
	hpv, hsz = A.canvas("hidden")
	return {"doc": "Hiding-spot look: drawn by the hotspot, not the rig. `file` is complete (eyes + pupils + gloved "
				   "fingertips in a dark gap); for tracking draw `whites` + `pupils` shifted within `pupil_range`; "
				   "`blink` for 6 frames every 2-6 s.",
			"file": ART + "hidden_eyes.svg", "whites": ART + "hidden_eyes_whites.svg",
			"blink": ART + "hidden_eyes_blink.svg", "pupils": ART + "hidden_pupils.svg",
			"pivot": hpv, "size": hsz, "pupil_range": [6, 3]}


def skin_files(base_files, pip_files):
	"""map of base res:// path -> pip res:// path for every file the Pip skin redraws."""
	m = OrderedDict()
	for name in sorted(pip_files):
		if name in base_files:
			m[ART + name] = PIP_ART + name
	return m


DOC = ("Hush cutout rig (TECH 4.7). px at zoom 1.0, y down, faces +x; `_r` = near side. offset = child joint in the "
	   "parent's joint frame (root: joint above the FEET ORIGIN); pivot/sockets = canvas px of the part texture "
	   "(joint = pivot; socket [x, y, rot]); world = parent * T(offset + pose.xy) * R(rot) * S(sx, sy); pose root "
	   "channels = a transform about the feet origin applied first. Limb bones (`draw: limb:<id>`) are invisible; each "
	   "limb is a round-capped hose through its joints' world positions (quadratic, control = 2*mid - (a+b)/2), "
	   "`width` fill + `outline` ink each side. Parts with `visible: false` are hidden unless a pose sets vis 1. "
	   "Face slots: canvas `pivot` placed on head * T(face.offset); pupils shift within `range` and hide while eyes "
	   "is one of `hide_with`. Skins swap textures by path (skins.<id>.files) and limb fills; pivots are identical.")


def rig(base_files, pip_files):
	r = OrderedDict()
	r["version"] = 1
	r["rig"] = "hush"
	r["doc"] = DOC
	r["height_px"] = 340
	r["root_part"] = "pelvis"
	r["origin"] = "feet"
	r["facing"] = 1
	r["parts"] = parts()
	r["limbs"] = limbs("hush")
	r["face"] = face()
	r["props"] = props()
	r["residues"] = OrderedDict([("TOMATO", {"overlays": {"head": ART + "head_tomato.svg"},
											 "doc": "view-only: the Stalls' tomato after a catch (GDD 6.3)"})])
	r["hidden"] = hidden()
	r["skins"] = OrderedDict([("pip", {"doc": "Pip fallback (GDD 1.2 R4): an 11-year-old Statues champion. Same part "
											  "names, canvases, pivots, sockets; only textures and limb fills change.",
									   "dir": PIP_ART, "files": skin_files(base_files, pip_files),
									   "limbs": {k: {"fill": v} for k, v in LIMBS["pip"].items()}})])
	r["feet"] = ["foot_l", "foot_r"]
	r["breath"] = {"part": "torso", "amp": 0.015, "period_s": 3.2}
	r["look"] = {"part": "head", "max_deg": 20}
	r["masks"] = {"upper": ["torso*"], "arms": ["arm_upper_l*", "arm_upper_r*"], "arm_r": ["arm_upper_r*"],
				  "legs": ["leg_upper_l*", "leg_upper_r*"], "head": ["head*"]}
	r["mirror_pairs"] = [["_l", "_r"]]
	r["no_mirror"] = []
	return r


# -------------------------------------------------------------------------------------------------
_F = [
	("neutral", "open", "neutral", "smile", None, ()),
	("grin", "open", "up", "grin", None, ()),
	("snicker", "squint", "sly", "grin", None, ()),
	("shock", "wide", "up", "O", "centre", ()),
	("fear", "wide", "worried", "grimace", None, ("sweat",)),
	("hold_breath", "wide", "worried", "puffed", "left", ("sweat",)),
	("smug", "half", "sly", "smile", None, ()),
	("wince", "closed", "worried", "grimace", None, ()),
	("determined", "squint", "determined", "tongue", None, ()),
	("sad", "worried", "worried", "wavy", None, ("tear",)),
	("busted", "wide", "up", "grimace", "up_right", ("sweat",)),
	("wink", "wink", "sly", "grin", None, ()),
	("statue", "half", "neutral", "smile", None, ()),
	("happy", "happy", "up", "laugh", None, ()),
	("laugh", "happy", "worried", "laugh", None, ("blush",)),
	("worried", "open", "worried", "wavy", "left", ()),
	("shush", "open", "up", "shh", "right", ()),
	("glance", "open", "sly", "grin", "down_left", ()),
	("proud", "happy", "up", "grin", None, ("blush",)),
	("dazed", "half", "worried", "wavy", None, ()),
	("sneak", "open", "sly", "shh", "right", ()),
	("curious", "open", "up", "O", "up_right", ()),
	("phew", "closed", "worried", "smile", None, ("sweat",)),
]


def _preset(eyes, brows, mouth, look, ov):
	d = OrderedDict([("eyes", eyes), ("brows", brows), ("mouth", mouth)])
	d["pupils"] = "none" if eyes in A.NO_PUPILS else (look or "centre")
	for k in A.OVERLAYS:
		d[k] = "on" if k in ov else "none"
	return d


FACES = OrderedDict((n, _preset(e, b, m, lk, ov)) for n, e, b, m, lk, ov in _F)


def faces():
	return OrderedDict([("version", 1), ("rig", "hush"),
						("doc", "Face presets: a variant (or none) for every face slot: eyes, pupils (baked look), "
								"brows, mouth and the overlay slots blush / sweat / tear (on / none)."),
						("presets", FACES)])
