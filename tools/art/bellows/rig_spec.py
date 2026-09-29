"""Rig layout for Horace Bellows (rig id `bellows`): parent chain, joint offsets, z order, springs, limits,
sockets, limbs, face anchor, tint, mirror pairs. Consumed by build.py -> game/data/rigs/bellows/rig.json.

Conventions (TECH §2, §4.7):
- px at zoom 1.0, y down, the character faces +x (art faces right; the view mirrors with scale.x = -1).
- `offset` = the child's joint (its pivot) relative to the parent's joint, in the parent's unrotated frame.
  The root part's `offset` = its joint relative to the feet origin in the rest pose.
- `pivot` = the joint pixel inside the part's own canvas (Sprite2D centered=false, offset=-pivot).
- rot in degrees, positive = clockwise on screen; at rot 0 limbs and hands hang straight down (+y).
- sockets = [x, y, angle] in the part's CANVAS px (like `pivot`); angle in degrees (a hand's grip turns props 90
  so a prop drawn upright stands upright on a forward-pointing forearm).
- z = integer draw order (face slots share the scale); props draw at their socket part's z + `z_offset`.
- `_r` = his right = the near side (drawn over the torso); `_l` = far side (behind, pre-darkened).
"""

RIG_ID = "bellows"
HEIGHT_PX = 380
ART_DIR = "res://art/chars/bellows/"

# name: (parent, offset, z, extra); SOCKETS below are joint-relative here and converted to canvas px by build.py
PARTS = {
	"torso": (None, (0, -65), 20, {"limits": {"rot": [-60, 60]}}),
	"coat_tails": ("torso", (-62, -28), 0, {"spring": {"channel": "rot", "k": 160, "c": 8, "clamp": 25}}),
	"belly": ("torso", (56, 10), 22, {"spring": {"channel": "sy", "k": 300, "c": 12, "clamp": 0.08}}),
	"cravat": ("torso", (42, -108), 26, {"spring": {"channel": "rot", "k": 220, "c": 10, "clamp": 25}}),
	"head": ("torso", (16, -123), 32, {"limits": {"rot": [-35, 35]}}),
	"sideburn_l": ("head", (58, -30), 30, {"spring": {"channel": "rot", "k": 260, "c": 11, "clamp": 20}}),
	"sideburn_r": ("head", (-30, -100), 34, {"spring": {"channel": "rot", "k": 260, "c": 11, "clamp": 20}}),
	"nose": ("head", (34, -72), 44, {"limits": {"rot": [-20, 20]}}),
	"bouffant": ("head", (-2, -110), 50, {"spring": {"channel": "rot", "k": 220, "c": 10, "clamp": 30}}),
	"arm_upper_l": ("torso", (30, -122), 6, {"draw": "limb:arm_l"}),
	"arm_lower_l": ("arm_upper_l", (0, 42), 6, {"draw": "limb:arm_l"}),
	"hand_l": ("arm_lower_l", (0, 42), 8, {}),
	"leg_upper_l": ("torso", (4, 0), 10, {"draw": "limb:leg_l"}),
	"leg_lower_l": ("leg_upper_l", (0, 24), 10, {"draw": "limb:leg_l"}),
	"foot_l": ("leg_lower_l", (0, 24), 12, {}),
	"leg_upper_r": ("torso", (4, 0), 14, {"draw": "limb:leg_r"}),
	"leg_lower_r": ("leg_upper_r", (0, 24), 14, {"draw": "limb:leg_r"}),
	"foot_r": ("leg_lower_r", (0, 24), 16, {}),
	"arm_upper_r": ("torso", (-14, -118), 60, {"draw": "limb:arm_r"}),
	"arm_lower_r": ("arm_upper_r", (0, 42), 60, {"draw": "limb:arm_r"}),
	"hand_r": ("arm_lower_r", (0, 42), 64, {}),
}

# Joint limits for limb bones (degrees, rest = hanging down).
LIMITS = {
	"arm_upper_r": [-220, 200], "arm_upper_l": [-220, 200],
	"arm_lower_r": [-160, 20], "arm_lower_l": [-160, 20],
	"hand_r": [-90, 90], "hand_l": [-90, 90],
	"leg_upper_r": [-120, 80], "leg_upper_l": [-120, 80],
	"leg_lower_r": [-10, 150], "leg_lower_l": [-10, 150],
	"foot_r": [-60, 70], "foot_l": [-60, 70],
	"coat_tails": [-80, 80], "cravat": [-190, 190], "belly": [-10, 10],
	"bouffant": [-40, 40], "sideburn_r": [-45, 45], "sideburn_l": [-45, 45],
}

# Invisible limb bones still carry a pivot: it is the joint pixel of residue overlays drawn on that bone
# (feathers, long-john spots). It never moves the FK.
BONE_PIVOT = (26, 10)

LIMBS = {
	"arm_r": {"joints": ["arm_upper_r", "arm_lower_r", "hand_r"], "width": 28, "fill": "#7B3F8C"},
	"arm_l": {"joints": ["arm_upper_l", "arm_lower_l", "hand_l"], "width": 28, "fill": "#633178"},
	"leg_r": {"joints": ["leg_upper_r", "leg_lower_r", "foot_r"], "width": 30, "fill": "#7B3F8C"},
	"leg_l": {"joints": ["leg_upper_l", "leg_lower_l", "foot_l"], "width": 30, "fill": "#633178"},
}
LIMB_COMMON = {"outline": 6, "ink": "#1B2340", "cap": "round"}

SOCKETS = {
	"hand_r": {"grip": None},   # filled from parts_body.GRIP per texture (default: grip texture)
	"hand_l": {"grip": None},
	"head": {"specs": [34, -72, 0], "hat": [-8, -188, 0]},
	"torso": {"chain": [22, -112, 0], "neck": [18, -140, 0], "seat": None},   # seat: filled by build.py from the stool
}

# The seat point on the barrel (joint-relative, torso frame): the lowest point of the barrel outline (TORSO_SIL
# (0, 25)), directly below the hip joint. The stool prop's seat pivot sits here (socket `torso:seat`).
SEAT_POINT = (0, 25)
# House stool: seat height above the floor (house.json decor kitchen_stool pivots.seat, s2-art contract).
STOOL_SEAT_H = 150

# Rig requests (rig report): breathing on the belly (+-2.5 % over 4 s), the additive look on the head, and the
# overlay masks micro-gags use (`upper` never touches the feet, the root or the torso).
BREATH = {"part": "belly", "amp": 0.025, "period_s": 4.0}
LOOK = {"part": "head", "max_deg": 20}
FACE_SLOT_PARTS = ["face_eyes", "face_pupils", "face_lids", "face_brows", "face_mouth", "face_blush", "face_sweat",
				   "face_vein", "face_steam_l", "face_steam_r", "face_singe", "face_pinch", "face_hiccup"]
ARMS = ["arm_upper_r", "arm_lower_r", "hand_r", "arm_upper_l", "arm_lower_l", "hand_l"]
HEAD = ["head", "nose", "bouffant", "sideburn_r", "sideburn_l"]
MASKS = {
	"upper": HEAD + ["cravat"] + ARMS + FACE_SLOT_PARTS,
	"arms": list(ARMS),
	"head": HEAD + FACE_SLOT_PARTS,
}

FACE_ANCHOR = "head"
FACE_OFFSET = (32, -44)   # face-local origin in head coords (between the eyes and the mouth)

FACE_Z = {"blush": 36, "mouth": 38, "pinch": 39, "eyes": 40, "pupils": 42, "lids": 43, "brows": 48, "singe": 49,
		  "sweat": 52, "vein": 52, "steam_r": 52, "steam_l": 28, "hiccup": 52}

# Temper: modulate colours for head / nose / hands (tier 0 Calm .. 3 Livid). Tuned by rendering:
# peach #F4C9A8 -> pink -> red -> beetroot #B8324B.
TINT_PARTS = ["head", "nose", "hand_l", "hand_r", "face_lids"]
TINT_TIERS = ["#FFFFFF", "#FFD7EA", "#F6979C", "#C03F72"]

MIRROR_PAIRS = [["_l", "_r"]]
