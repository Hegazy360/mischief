"""faces.json presets for Bellows (TECH §4.7). A preset sets eyes / brows / mouth; optional `pupils` = [dx, dy]
gaze offset (px, within the pupils range [6, 4]; negative x = toward the viewer/the Stalls in the 3/4 view) and
`overlays` = face overlay slots switched on (others are off)."""

PRESETS = {
	# routine
	"neutral": {"eyes": "open", "brows": "neutral", "mouth": "closed"},
	"smug": {"eyes": "half", "brows": "sly", "mouth": "smug"},
	"pompous": {"eyes": "half", "brows": "up", "mouth": "closed", "pupils": [2, -1]},
	"admiring": {"eyes": "half", "brows": "up", "mouth": "smile", "overlays": ["blush"]},
	"disdain": {"eyes": "half", "brows": "one_up", "mouth": "smug", "pupils": [3, 2]},
	# singing (the O in three sizes)
	"sing_small": {"eyes": "half", "brows": "up", "mouth": "O_small"},
	"inhale": {"eyes": "closed", "brows": "up", "mouth": "O_small", "pupils": [0, -2]},
	"sing_mid": {"eyes": "closed", "brows": "up", "mouth": "O_mid"},
	"sing_big": {"eyes": "closed", "brows": "up", "mouth": "O_big", "overlays": ["blush"]},
	# notice / danger
	"suspicious": {"eyes": "squint", "brows": "one_up", "mouth": "closed"},
	"huh": {"eyes": "open", "brows": "one_up", "mouth": "open", "pupils": [4, 0]},
	"look_back": {"eyes": "half", "brows": "one_up", "mouth": "closed", "pupils": [-6, 0]},
	"shock": {"eyes": "wide", "brows": "up", "mouth": "O_mid"},
	"wild_take": {"eyes": "wide", "brows": "up", "mouth": "scream"},
	"terrified": {"eyes": "pinpoint", "brows": "worried", "mouth": "scream", "overlays": ["sweat"]},
	"antic": {"eyes": "closed", "brows": "angry", "mouth": "wavy"},
	# temper
	"irked": {"eyes": "half", "brows": "angry", "mouth": "closed"},
	"furious": {"eyes": "angry", "brows": "angry", "mouth": "grit", "overlays": ["vein"]},
	"livid": {"eyes": "angry", "brows": "angry", "mouth": "scream", "overlays": ["vein", "steam_l", "steam_r"]},
	"lecture": {"eyes": "angry", "brows": "angry", "mouth": "open"},
	"strain": {"eyes": "squint", "brows": "angry", "mouth": "grit", "overlays": ["vein", "sweat"]},
	# the sneeze (rule of three)
	"sneeze_build": {"eyes": "half", "brows": "worried", "mouth": "O_small", "pupils": [0, -3]},
	"sneeze_build2": {"eyes": "squint", "brows": "worried", "mouth": "open"},
	"sneeze_choo": {"eyes": "closed", "brows": "angry", "mouth": "scream"},
	# after the hit
	"dazed": {"eyes": "spiral", "brows": "worried", "mouth": "wavy"},
	"slow_burn": {"eyes": "half", "brows": "neutral", "mouth": "closed", "pupils": [-5, 2]},
	"strained_grin": {"eyes": "wide", "brows": "worried", "mouth": "grit", "overlays": ["sweat"]},
	"sulk": {"eyes": "half", "brows": "angry", "mouth": "wavy", "pupils": [0, 3]},
	"mortified": {"eyes": "wide", "brows": "worried", "mouth": "wavy", "overlays": ["blush", "sweat"]},
	"teary": {"eyes": "teary", "brows": "worried", "mouth": "wavy"},
	"wheeze": {"eyes": "half", "brows": "worried", "mouth": "open", "overlays": ["sweat"]},
	"magnified": {"eyes": "balloon", "brows": "up", "mouth": "O_mid"},
	"pardon": {"eyes": "open", "brows": "up", "mouth": "smile", "pupils": [-3, 0]},
	"relief": {"eyes": "half", "brows": "up", "mouth": "smile"},
	# rest
	"asleep": {"eyes": "closed", "brows": "neutral", "mouth": "O_small"},
	"blissful": {"eyes": "closed", "brows": "up", "mouth": "smile", "overlays": ["blush"]},
}

REQUIRED = ["neutral", "smug", "sing_small", "sing_mid", "sing_big", "suspicious", "shock", "wild_take", "furious",
			"sneeze_build", "sneeze_choo", "dazed", "slow_burn", "strained_grin", "sulk", "terrified", "asleep",
			"blissful"]


# face overlays a preset owns (switched on/off explicitly); residue overlays (singe, pinch, hiccup) are left alone
EXPRESSION_OVERLAYS = ["blush", "sweat", "vein", "steam_l", "steam_r"]


def expand(p, F):
	"""A preset as RigPlayer/FaceState applies it: every slot it owns is explicit ('none' hides a slot)."""
	out = {"eyes": p["eyes"], "brows": p["brows"], "mouth": p["mouth"],
		   "pupils": "none" if p["eyes"] in F.NO_PUPILS else "default",
		   "lids": F.EYE_LIDS.get(p["eyes"], "none")}
	for ov in EXPRESSION_OVERLAYS:
		out[ov] = "on" if ov in p.get("overlays", []) else "none"
	return out


def faces_json(F):
	return {"version": 1, "rig": "bellows",
			"doc": ("presets set every face slot they own; 'none' hides a slot, 'default' is a single-file slot. "
					"gaze = suggested pupil offset in px (pupils range [6, 4]; negative x looks at the viewer/Stalls)."),
			"presets": {k: expand(v, F) for k, v in PRESETS.items()},
			"gaze": {k: v["pupils"] for k, v in PRESETS.items() if "pupils" in v}}
