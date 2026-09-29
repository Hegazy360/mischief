"""Hush pose library (poses.json, TECH 4.7): every P0 Hush clip in GDD 9.4 has its key poses here.

Authoring shorthand (pose(...) kwargs): part=<number> -> rot (deg, clockwise +; limbs hang down at 0, negative
swings them FORWARD toward +x; torso/head/root positive leans forward); part="<tex>" -> texture variant;
part=(rot, "<tex>") -> both; part={...} -> raw channels (rot, x, y, sx, sy, z, tex, vis, alpha).

Solved at build time (baked into plain rotations/offsets in poses.json, so the runtime needs no IK):
* ik={"hand_r": (dx, dy[, bend])} puts the wrist at (dx, dy) from the shoulder (hip for feet) in WORLD axes;
  ik={"hand_r": {"to": ("head", (x, y)) | (dx, dy), "via": (x, y), "aim": deg, "bend": +-1}} puts the end part's
  local point `via` on the target with the end part at world angle `aim` (0 = fingers down, -90 forward,
  180 up). bend +1 = elbow below/behind the line (arms), -1 = knee forward (legs).
* aim={"head": deg} sets a part's WORLD angle; pin={"beret": ("hand_r", (x, y))} moves a part's joint onto a
  point of another part (the hat-stand gag).
Grounding: ground="feet" (default) solves root y so the lowest sole point touches y = 0; ground="pelvis"
rests the seat on the floor; ground=None keeps the authored root (jumps, dangles).

Gesture rule (readability at phone size): gloves work in FRONT of the face (x > 62), below the chin or behind
the head — never across the eyes; a raised near arm passes BEHIND the head (z override) when it must.
"""
import copy
import math
from collections import OrderedDict

import fk
import hush_art as A
import rig_hush

F = OrderedDict()      # name -> authoring dict
MIRROR = OrderedDict()
BEHIND_HEAD = 11       # z for a near arm/glove tucked behind the head (head is 12)


def pose(name, base="h_stand", root=None, face=None, tags=(), sil=None, props=None, ground="feet", residues=None,
		 ik=None, aim=None, pin=None, **bones):
	d = OrderedDict()
	if base and name != "h_stand":
		d["base"] = base
	if root:
		d["root"] = {k: (round(v * A.K, 1) if k in ("x", "y") else v) for k, v in root.items()}
	b = OrderedDict()
	for part, v in bones.items():
		if isinstance(v, dict):
			b[part] = {k: (round(c * A.K, 1) if k in ("x", "y") else c) for k, c in v.items()}
		elif isinstance(v, str):
			b[part] = {"tex": v}
		elif isinstance(v, tuple):
			b[part] = {"rot": v[0], "tex": v[1]}
		else:
			b[part] = {"rot": v}
	d["bones"] = b
	if face:
		d["face"] = face
	d["tags"] = list(tags)
	if sil:
		d["silhouette"] = sil
	if props:
		d["props"] = props
	if residues:
		d["residues"] = residues
	d["_ground"] = ground
	d["_ik"] = ik or {}
	d["_aim"] = aim or {}
	d["_pin"] = pin or {}
	F[name] = d


# ================================================================================================ IDLE
pose("h_stand", base=None, face="neutral", tags=["idle", "rest"],
	 sil="upright, beret slouched back, big gloves loose in front",
	 root={"x": 0, "y": 0, "rot": 0, "sx": 1, "sy": 1},
	 torso=-2, head=-3, braces_loop={"vis": 0},
	 hand_r="open", hand_l="open",
	 ik={"hand_r": {"to": (22, 96), "aim": -22, "bend": 1}, "hand_l": {"to": (-2, 98), "aim": -8, "bend": 1}},
	 leg_upper_r=-6, leg_lower_r=4, foot_r=(2, "flat"),
	 leg_upper_l=7, leg_lower_l=0, foot_l=(-7, "flat"))
pose("h_breath_in", tags=["idle", "breath"], torso={"rot": -3, "sy": 1.03}, head=-5,
	 ik={"hand_r": {"to": (25, 94), "aim": -24}, "hand_l": {"to": (0, 96), "aim": -10}})
pose("h_breath_out", tags=["idle", "breath"], torso={"rot": -1, "sy": 0.985}, head=-2,
	 ik={"hand_r": {"to": (20, 98), "aim": -20}, "hand_l": {"to": (-3, 99), "aim": -6}})
pose("h_fidget_look", face="worried", tags=["idle", "fidget"],
	 sil="leaning back, glove cupped behind her ear, eyes darting back",
	 torso=-8, head=-10, hand_r="wave", hand_l="fist",
	 ik={"hand_r": {"to": ("head", (-36, -46)), "via": (0, 24), "aim": 168, "bend": -1},
		 "hand_l": {"to": (6, 70), "aim": -30, "bend": 1}})
pose("h_fidget_proud", face="smug", tags=["idle", "fidget"], sil="chest out, chin up, fists on hips, showing off",
	 torso=-10, head=-14, hand_r="fist", hand_l="fist",
	 ik={"hand_r": {"to": ("pelvis", (26, -8)), "via": (0, 30), "aim": 70, "bend": -1},
		 "hand_l": {"to": ("pelvis", (-24, -8)), "via": (0, 30), "aim": -70, "bend": 1}},
	 leg_upper_r=-12, leg_lower_r=4, foot_r=(-14, "flat"))
pose("h_fidget_clarence", face="happy", tags=["idle", "fidget"], sil="gazing lovingly at the chicken held up in her fist",
	 head=-4, hand_r="fist",
	 ik={"hand_r": {"to": (86, -24), "aim": -90, "bend": 1}},
	 props={"clarence": {"socket": "hand_r:grip", "state": "smitten"}})
pose("h_shush", face="shush", tags=["idle", "gesture"], sil="finger to the lips",
	 head=-4, hand_r="shush",
	 ik={"hand_r": {"to": ("head", (38, -18)), "via": (1, 80), "aim": 176, "bend": 1}})

# ================================================================================================ LOCO
# tiptoe scurry (10 f per step): hunched, knees high, gloves up like paws
pose("h_tip_contact_l", face="sneak", tags=["loco", "tiptoe", "contact"],
	 torso=16, head=-14, hand_r="open", hand_l="open",
	 ik={"hand_r": {"to": (58, 34), "aim": 12, "bend": 1}, "hand_l": {"to": (48, 40), "aim": 16, "bend": 1}},
	 leg_upper_l=-34, leg_lower_l=26, foot_l=(-6, "tiptoe"),
	 leg_upper_r=24, leg_lower_r=46, foot_r=(18, "tiptoe"))
pose("h_tip_pass_l", base="h_tip_contact_l", tags=["loco", "tiptoe", "pass"],
	 torso=14, head=-12,
	 ik={"hand_r": {"to": (60, 28), "aim": 16, "bend": 1}, "hand_l": {"to": (46, 44), "aim": 12, "bend": 1}},
	 leg_upper_l=4, leg_lower_l=6, foot_l=(0, "tiptoe"),
	 leg_upper_r=-74, leg_lower_r=104, foot_r=(28, "tiptoe"))
MIRROR["h_tip_contact_r"] = "h_tip_contact_l"
MIRROR["h_tip_pass_r"] = "h_tip_pass_l"
# run (12 f per step): leaning in, fists pumping, long stride
pose("h_run_contact_l", face="determined", tags=["loco", "run", "contact"],
	 torso=22, head=-16, hand_r="fist", hand_l="fist",
	 ik={"hand_r": {"to": (60, 34), "aim": -130, "bend": 1}, "hand_l": {"to": (-56, 50), "aim": -30, "bend": 1}},
	 leg_upper_l=-50, leg_lower_l=14, foot_l=(-14, "flat"),
	 leg_upper_r=36, leg_lower_r=58, foot_r=(34, "tiptoe"))
pose("h_run_pass_l", base="h_run_contact_l", tags=["loco", "run", "pass"],
	 ik={"hand_r": {"to": (22, 70), "aim": -60, "bend": 1}, "hand_l": {"to": (-14, 76), "aim": -40, "bend": 1}},
	 leg_upper_l=6, leg_lower_l=16, foot_l=(-4, "flat"),
	 leg_upper_r=-66, leg_lower_r=112, foot_r=(20, "flat"))
MIRROR["h_run_contact_r"] = "h_run_contact_l"
MIRROR["h_run_pass_r"] = "h_run_pass_l"
pose("h_turn_mid", tags=["loco", "turn"], sil="compact: gloves tucked at the chest, feet together",
	 torso=0, head=0, hand_r="fist", hand_l="fist",
	 ik={"hand_r": {"to": (20, 60), "aim": -60, "bend": 1}, "hand_l": {"to": (16, 62), "aim": -60, "bend": 1}},
	 leg_upper_r=-2, leg_lower_r=0, leg_upper_l=2, leg_lower_l=0, foot_l=(0, "flat"), foot_r=(0, "flat"))
pose("h_door_reach", face="sneak", tags=["loco", "door"], sil="stretched on tiptoe, pinch reaching for a handle",
	 torso=12, head=-6, hand_r="pinch", hand_l="open",
	 ik={"hand_r": {"to": (98, 26), "aim": -76, "bend": 1}, "hand_l": {"to": (-50, 70), "aim": 20, "bend": 1}},
	 leg_upper_r=-16, leg_lower_r=6, foot_r=(0, "tiptoe"), leg_upper_l=12, leg_lower_l=2, foot_l=(10, "tiptoe"))
pose("h_stairs_a", face="sneak", tags=["loco", "stairs"],
	 torso=14, head=-10, hand_r="open", hand_l="open",
	 ik={"hand_r": {"to": (50, 50), "aim": 0, "bend": 1}, "hand_l": {"to": (-30, 80), "aim": -10, "bend": 1}},
	 leg_upper_r=-84, leg_lower_r=86, foot_r=(0, "flat"),
	 leg_upper_l=14, leg_lower_l=8, foot_l=(20, "tiptoe"))
pose("h_stairs_b", base="h_stairs_a", tags=["loco", "stairs"],
	 ik={"hand_r": {"to": (-24, 84), "aim": -10, "bend": 1}, "hand_l": {"to": (46, 54), "aim": 0, "bend": 1}},
	 leg_upper_r=-26, leg_lower_r=30, foot_r=(0, "flat"),
	 leg_upper_l=-60, leg_lower_l=100, foot_l=(10, "tiptoe"))

# ================================================================================================ ACT
pose("h_rummage_a", face="determined", tags=["act", "rummage"], sil="bent double into a box, one leg kicked up",
	 torso=70, head=16, hand_r="open", hand_l="open",
	 ik={"hand_r": {"to": (40, 96), "aim": -10, "bend": 1}, "hand_l": {"to": (20, 100), "aim": 10, "bend": 1}},
	 leg_upper_r=-6, leg_lower_r=4, leg_upper_l=40, leg_lower_l=70, foot_l=(20, "tiptoe"))
pose("h_rummage_b", base="h_rummage_a", face="grin", tags=["act", "rummage"],
	 sil="bent double, flinging junk back over her head",
	 torso=58, head=6, hand_r="open",
	 ik={"hand_r": {"to": (-40, -90), "aim": 140, "bend": 1}},
	 hand_r_z=None, leg_upper_l=24, leg_lower_l=50)
pose("h_pickup", face="curious", tags=["act", "pickup"], sil="crouched, pinch held up to her eye",
	 torso=18, head=-8, hand_r="pinch", hand_l="open",
	 ik={"hand_r": {"to": ("head", (86, -60)), "via": (21, 57), "aim": 170, "bend": 1},
		 "hand_l": {"to": (30, 76), "aim": -20, "bend": 1}},
	 leg_upper_r=-62, leg_lower_r=96, foot_r=(-4, "flat"), leg_upper_l=-10, leg_lower_l=70, foot_l=(30, "tiptoe"))
# tinker Q (0.8 s): quick fiddle at chest height
pose("h_tinker_q_a", face="determined", tags=["tinker", "tinker_q"],
	 torso=12, head=8, hand_r="pinch", hand_l="pinch",
	 ik={"hand_r": {"to": (70, 20), "aim": -60, "bend": 1}, "hand_l": {"to": (56, 30), "aim": -40, "bend": 1}})
pose("h_tinker_q_b", base="h_tinker_q_a", tags=["tinker", "tinker_q"], head=10,
	 ik={"hand_r": {"to": (62, 36), "aim": -40, "bend": 1}, "hand_l": {"to": (64, 14), "aim": -70, "bend": 1}})
# tinker S (1.5 s): frantic, elbows flying, knees bent
pose("h_tinker_s_a", face="determined", tags=["tinker", "tinker_s"], sil="elbows flying, hunched over the job",
	 torso=26, head=12, hand_r="fist", hand_l="pinch",
	 ik={"hand_r": {"to": (84, 30), "aim": -100, "bend": 1}, "hand_l": {"to": (50, 56), "aim": -30, "bend": 1}},
	 leg_upper_r=-30, leg_lower_r=40, leg_upper_l=6, leg_lower_l=30)
pose("h_tinker_s_b", base="h_tinker_s_a", tags=["tinker", "tinker_s"], head=16, hand_r="pinch", hand_l="fist",
	 ik={"hand_r": {"to": (56, 50), "aim": -30, "bend": 1}, "hand_l": {"to": (72, 6), "aim": -110, "bend": -1}})
# tinker B (2.5 s): big job, crouched, hammering
pose("h_tinker_b_a", face="determined", tags=["tinker", "tinker_b", "antic"], sil="crouched, fist wound up behind her head",
	 torso=30, head=6, hand_r="fist", hand_l="pinch",
	 ik={"hand_r": {"to": (-40, -84), "aim": 150, "bend": 1}, "hand_l": {"to": (76, 50), "aim": -40, "bend": 1}},
	 arm_upper_r={"z": BEHIND_HEAD}, hand_r_z=BEHIND_HEAD,
	 leg_upper_r=-70, leg_lower_r=104, foot_r=(0, "flat"), leg_upper_l=-18, leg_lower_l=96, foot_l=(40, "tiptoe"))
pose("h_tinker_b_b", base="h_tinker_b_a", tags=["tinker", "tinker_b", "accent"], sil="crouched, fist slammed down",
	 torso=40, head=18, root={"sx": 1.05, "sy": 0.95},
	 arm_upper_r={"z": 19}, hand_r_z=21,
	 ik={"hand_r": {"to": (84, 64), "aim": -50, "bend": 1}, "hand_l": {"to": (60, 74), "aim": -20, "bend": 1}})
pose("h_brow_wipe", face="phew", tags=["tinker", "after"], sil="glove swept across the brow, fist on hip",
	 torso=-6, head=-12, hand_r="open", hand_l="fist",
	 ik={"hand_r": {"to": ("head", (74, -94)), "aim": 100, "bend": 1}, "hand_l": {"to": (8, 72), "aim": -20, "bend": 1}})
pose("h_snicker_a", face="snicker", tags=["take", "snicker"], sil="hunched, glove clamped over the mouth",
	 torso={"rot": 10, "sy": 0.95}, head=12, hand_r="open", hand_l="open",
	 ik={"hand_r": {"to": ("head", (40, -24)), "via": (0, 22), "aim": 96, "bend": 1},
		 "hand_l": {"to": (40, 56), "aim": -90, "bend": 1}})
pose("h_snicker_b", base="h_snicker_a", tags=["take", "snicker"], sil="shoulders jerked up, glove over the mouth",
	 torso={"rot": 6, "sy": 1.0, "y": -5}, head=4,
	 ik={"hand_r": {"to": ("head", (40, -24)), "via": (0, 22), "aim": 100, "bend": 1}})
pose("h_glance_stalls", face="glance", tags=["take", "glance"], sil="upright, gloves clasped behind her back",
	 torso=-4, head=-4, hand_r="fist", hand_l="fist",
	 ik={"hand_r": {"to": (-34, 78), "aim": 40, "bend": 1}, "hand_l": {"to": (-30, 80), "aim": 40, "bend": 1}},
	 foot_r=(-6, "flat"))

# ================================================================================================ HIDE
pose("h_dive_antic", face="determined", tags=["take", "dive", "antic"], sil="deep crouch, arms swung back",
	 root={"sx": 1.1, "sy": 0.9}, torso=34, head=-18, hand_r="open", hand_l="open",
	 ik={"hand_r": {"to": (-80, 40), "aim": 70, "bend": 1}, "hand_l": {"to": (-72, 46), "aim": 70, "bend": 1}},
	 leg_upper_r=-76, leg_lower_r=116, foot_r=(0, "flat"), leg_upper_l=-44, leg_lower_l=100, foot_l=(10, "tiptoe"))
pose("h_dive", face="shock", tags=["take", "dive", "accent"], sil="flat superman dive, gloves first",
	 ground=None, root={"x": -200, "y": -110, "rot": 80, "sx": 0.92, "sy": 1.12}, torso=4, head=-30,
	 hand_r="wall", hand_l="wall",
	 ik={"hand_r": {"to": (100, 16), "aim": -92, "bend": 1}, "hand_l": {"to": (96, 24), "aim": -92, "bend": 1}},
	 leg_upper_r=10, leg_lower_r=10, foot_r=(40, "tiptoe"), leg_upper_l=18, leg_lower_l=16, foot_l=(40, "tiptoe"),
	 hair_back={"rot": 14})
pose("h_pop_out", face="grin", tags=["take", "pop"], sil="ta-da: jazz gloves up in a V, one leg kicked",
	 root={"sx": 0.94, "sy": 1.07}, torso=-8, head=-10, hand_r="wave", hand_l="wave",
	 ik={"hand_r": {"to": (76, -64), "aim": -140, "bend": 1}, "hand_l": {"to": (-70, -70), "aim": 140, "bend": -1}},
	 leg_upper_r=-40, leg_lower_r=10, foot_r=(-20, "tiptoe"), leg_upper_l=4, leg_lower_l=0, foot_l=(0, "tiptoe"))
pose("h_hold_breath", face="hold_breath", tags=["take", "hold"], sil="rigid as a post, cheeks puffed, gloves flat",
	 root={"sx": 0.97, "sy": 1.03}, torso=-3, head=-2, hand_r="wall", hand_l="wall",
	 ik={"hand_r": {"to": (6, 100), "aim": 0, "bend": 1}, "hand_l": {"to": (-4, 100), "aim": 0, "bend": 1}},
	 leg_upper_r=0, leg_lower_r=0, leg_upper_l=0, leg_lower_l=0, foot_r=(0, "tiptoe"), foot_l=(0, "tiptoe"))
pose("h_near_miss", face="fear", tags=["take", "near_miss"], sil="flattened back against the wall, gloves splayed",
	 root={"sx": 0.95, "sy": 1.04}, torso=-10, head=-12, hand_r="wall", hand_l="wall",
	 ik={"hand_r": {"to": (-40, 30), "aim": 150, "bend": 1}, "hand_l": {"to": (-50, 10), "aim": 150, "bend": 1}},
	 foot_r=(0, "tiptoe"), foot_l=(0, "tiptoe"))

# ================================================================================================ FREEZE (statues)
pose("h_freeze_1", face="statue", tags=["freeze", "statue"],
	 sil="THE THINKER: sitting on thin air, chin on fist, elbow on knee",
	 torso=34, head=18, hand_r="fist", hand_l="open",
	 ik={"hand_r": {"to": ("head", (34, 2)), "via": (0, 36), "aim": 176, "bend": 1},
		 "hand_l": {"to": (40, 70), "aim": -40, "bend": 1}},
	 leg_upper_r=-86, leg_lower_r=88, foot_r=(0, "flat"), leg_upper_l=-78, leg_lower_l=96, foot_l=(-10, "flat"))
pose("h_freeze_2", face="statue", tags=["freeze", "statue"],
	 sil="THE TEAPOT: tipped over, glove spout out front, elbow handle behind",
	 root={"rot": 12}, torso=8, head=-12, hand_r="wall", hand_l="fist",
	 ik={"hand_r": {"to": (92, 16), "aim": -140, "bend": 1}, "hand_l": {"to": (-12, 72), "aim": -10, "bend": 1}},
	 leg_upper_r=-30, leg_lower_r=20, foot_r=(-20, "tiptoe"), leg_upper_l=6, leg_lower_l=4)
pose("h_freeze_3", face="statue", tags=["freeze", "statue"],
	 sil="THE FLAMINGO: one leg, knee folded up behind, gloves back as wings",
	 root={"sx": 0.96, "sy": 1.04}, torso=-4, head=-16, hand_r="wave", hand_l="wave",
	 ik={"hand_r": {"to": (-92, 14), "aim": 100, "bend": 1}, "hand_l": {"to": (-86, 4), "aim": 106, "bend": 1}},
	 leg_upper_r=-36, leg_lower_r=156, foot_r=(40, "tiptoe"), leg_upper_l=0, leg_lower_l=0, foot_l=(0, "flat"))
pose("h_freeze_4", face="determined", tags=["freeze", "statue"],
	 sil="THE DISCUS THROWER: coiled lunge, glove flung far back and up",
	 torso=30, head=-4, hand_r="wall", hand_l="fist",
	 ik={"hand_r": {"to": (-96, -34), "aim": 116, "bend": 1}, "hand_l": {"to": (64, 70), "aim": -30, "bend": 1}},
	 leg_upper_r=-62, leg_lower_r=72, foot_r=(0, "flat"), leg_upper_l=44, leg_lower_l=10, foot_l=(30, "tiptoe"))
pose("h_freeze_5", face="statue", tags=["freeze", "statue"],
	 sil="THE HAT STAND: a stiff pole, arms out as pegs with the gloves hooked up, her beret hung on one",
	 root={"sx": 0.97, "sy": 1.04}, torso=0, head=4, hand_r="fist", hand_l="fist",
	 arm_upper_r=-90, arm_lower_r=0, arm_upper_l=90, arm_lower_l=0,
	 aim={"hand_r": 180, "hand_l": 180},
	 leg_upper_r=0, leg_lower_r=0, leg_upper_l=0, leg_lower_l=0, foot_r=(0, "flat"), foot_l=(0, "flat"),
	 pin={"beret": ("hand_r", (10, 56))}, beret={"rot": 20})
pose("h_freeze_6", face="proud", tags=["freeze", "statue"],
	 sil="THE BALLERINA: arabesque on one pointed toe, leg straight out behind",
	 torso=26, head=-22, hand_r="wave", hand_l="wave",
	 ik={"hand_r": {"to": (86, -50), "aim": -130, "bend": 1}, "hand_l": {"to": (-92, -10), "aim": 110, "bend": -1}},
	 leg_upper_r=84, leg_lower_r=4, foot_r=(40, "tiptoe"), leg_upper_l=-4, leg_lower_l=0, foot_l=(0, "tiptoe"))
pose("h_freeze_7", face="statue", tags=["freeze", "statue"],
	 sil="THE LAMP: stiff as a pole, one glove held high over the beret, fingers spread like a lit bulb",
	 torso=0, head=4, hand_r="wave", hand_l="wall",
	 ik={"hand_r": {"to": (4, -102), "aim": 180, "bend": 1}, "hand_l": {"to": (-4, 102), "aim": 0, "bend": 1}},
	 arm_upper_r={"z": BEHIND_HEAD},
	 leg_upper_r=0, leg_lower_r=0, leg_upper_l=0, leg_lower_l=0, foot_r=(0, "flat"), foot_l=(0, "flat"))
pose("h_freeze_8", face="shock", tags=["freeze", "statue"],
	 sil="THE STARTLED VASE: squat pot, elbows as handles, knees together, eyes popping",
	 root={"sx": 1.08, "sy": 0.93}, torso=0, head=-4, hand_r="fist", hand_l="fist",
	 ik={"hand_r": {"to": (18, 66), "aim": 60, "bend": -1}, "hand_l": {"to": (-10, 66), "aim": -60, "bend": 1}},
	 leg_upper_r=-18, leg_lower_r=34, foot_r=(-10, "tiptoe"), leg_upper_l=12, leg_lower_l=16, foot_l=(20, "tiptoe"))

# ================================================================================================ TAKES
pose("h_squeak", face="grin", tags=["take", "squeak"], sil="chicken thrust out front, squeezed in her fist",
	 torso=4, head=-6, hand_r="fist", hand_l="fist",
	 ik={"hand_r": {"to": (84, -4), "aim": -90, "bend": 1}, "hand_l": {"to": (10, 72), "aim": -20, "bend": 1}},
	 props={"clarence": {"socket": "hand_r:grip", "state": "squeezed"}})
pose("h_wheeze", base="h_squeak", face="snicker", tags=["take", "squeak"], sil="chicken held up high, stretched thin",
	 ik={"hand_r": {"to": (70, -60), "aim": -90, "bend": 1}},
	 props={"clarence": {"state": "stretched"}})
pose("h_climb_a", face="sneak", tags=["take", "climb"], sil="miming a ladder: glove high on a rung, knee up",
	 torso=4, head=-10, hand_r="fist", hand_l="fist",
	 ik={"hand_r": {"to": (80, -62), "aim": -90, "bend": 1}, "hand_l": {"to": (82, 6), "aim": -90, "bend": 1}},
	 leg_upper_r=-92, leg_lower_r=94, foot_r=(0, "flat"), leg_upper_l=4, leg_lower_l=0, foot_l=(10, "tiptoe"))
pose("h_climb_b", base="h_climb_a", tags=["take", "climb"], sil="miming a ladder: the other glove up, other knee up",
	 ik={"hand_r": {"to": (82, 4), "aim": -90, "bend": 1}, "hand_l": {"to": (78, -64), "aim": -90, "bend": 1}},
	 leg_upper_r=-6, leg_lower_r=4, foot_r=(10, "tiptoe"), leg_upper_l=-90, leg_lower_l=96, foot_l=(0, "flat"))
pose("h_busted_antic", face="shock", tags=["take", "busted", "antic"], sil="frozen mid-step, shoulders up to her ears",
	 root={"sx": 1.05, "sy": 0.94}, torso={"rot": -2, "sy": 0.94}, head={"rot": 0, "y": 8}, hand_r="wall",
	 hand_l="wall",
	 ik={"hand_r": {"to": (14, 88), "aim": -10, "bend": 1}, "hand_l": {"to": (-10, 88), "aim": 10, "bend": 1}})
pose("h_busted", face="busted", tags=["take", "busted", "accent"], ground=None,
	 sil="EYES POP: starfish leap, gloves splayed, beret flying off",
	 root={"y": -64, "sx": 0.9, "sy": 1.12}, torso=-12, head=-16, hand_r="wave", hand_l="wave",
	 ik={"hand_r": {"to": (84, -56), "aim": -140, "bend": 1}, "hand_l": {"to": (-80, -60), "aim": 140, "bend": -1}},
	 leg_upper_r=-34, leg_lower_r=44, foot_r=(10, "tiptoe"), leg_upper_l=34, leg_lower_l=56, foot_l=(20, "tiptoe"),
	 beret={"rot": -24, "y": -22}, hair_back={"rot": -12})
pose("h_dangled_a", face="fear", tags=["lecture", "dangled"], ground=None,
	 sil="hoisted by the braces, legs pedalling in the air",
	 root={"y": -96}, torso=-6, head=16, braces_loop={"vis": 1, "sy": 1.35}, hand_r="open", hand_l="open",
	 ik={"hand_r": {"to": (12, 100), "aim": 0, "bend": 1}, "hand_l": {"to": (-2, 100), "aim": 4, "bend": 1}},
	 leg_upper_r=-46, leg_lower_r=70, foot_r=(20, "flat"), leg_upper_l=24, leg_lower_l=40, foot_l=(30, "flat"))
pose("h_dangled_b", base="h_dangled_a", face="worried", tags=["lecture", "dangled"],
	 leg_upper_r=20, leg_lower_r=44, foot_r=(30, "flat"), leg_upper_l=-44, leg_lower_l=74, foot_l=(20, "flat"),
	 head=10, ik={"hand_r": {"to": (18, 98), "aim": -6, "bend": 1}})
pose("h_doorstep_sit", face="sad", tags=["lecture", "doorstep"], ground="feet",
	 sil="hunched on the doorstep hugging her knees (feet on the pavement, seat ~50 px up on the step)",
	 torso=20, head=22, hand_r="open", hand_l="open",
	 leg_upper_r=-70, leg_lower_r=128, foot_r=(-10, "flat"), leg_upper_l=-62, leg_lower_l=122, foot_l=(-10, "flat"),
	 ik={"hand_r": {"to": ("leg_lower_r", (8, 10)), "via": (0, 24), "aim": -20, "bend": 1},
		 "hand_l": {"to": ("leg_lower_l", (8, 14)), "via": (0, 24), "aim": -20, "bend": 1}})
pose("h_tomato_splat", face="wince", tags=["take", "tomato", "accent"], residues=["TOMATO"],
	 sil="SPLAT: head snapped back, gloves flung out behind, one leg up",
	 root={"rot": -8}, torso=-14, head=-26, hand_r="open", hand_l="open",
	 ik={"hand_r": {"to": (-92, 14), "aim": 100, "bend": 1}, "hand_l": {"to": (-86, 26), "aim": 90, "bend": 1}},
	 leg_upper_r=-42, leg_lower_r=20, foot_r=(-20, "flat"), leg_upper_l=6, leg_lower_l=0)
pose("h_bow_a", face="grin", tags=["take", "bow", "antic"], sil="flourish: glove swept out high, toe pointed",
	 torso=-8, head=-10, hand_r="wave", hand_l="open",
	 ik={"hand_r": {"to": (96, -34), "aim": -120, "bend": 1}, "hand_l": {"to": (-56, 70), "aim": 30, "bend": 1}},
	 leg_upper_r=-24, leg_lower_r=4, foot_r=(30, "tiptoe"))
pose("h_bow_b", face="proud", tags=["take", "bow", "hold"], sil="deep bow, glove on the belly, other swept back",
	 torso=74, head=10, hand_r="open", hand_l="wave",
	 ik={"hand_r": {"to": ("torso", (30, -26)), "via": (0, 24), "aim": -170, "bend": -1},
		 "hand_l": {"to": (-90, -40), "aim": 120, "bend": -1}},
	 leg_upper_r=-10, leg_lower_r=4, foot_r=(0, "flat"), leg_upper_l=14, leg_lower_l=2, foot_l=(20, "tiptoe"))
pose("h_wink", face="wink", tags=["take", "wink"], sil="thumbs up at the audience, hip cocked",
	 root={"rot": -3}, torso=-6, head=-10, hand_r="thumbs_up", hand_l="fist",
	 ik={"hand_r": {"to": (82, 0), "aim": -90, "bend": 1}, "hand_l": {"to": (8, 70), "aim": -20, "bend": 1}},
	 leg_upper_r=-14, leg_lower_r=6, foot_r=(-10, "flat"))
pose("h_victory", face="happy", tags=["take", "victory", "accent"], ground=None,
	 sil="leaping fist pump, knees tucked",
	 root={"y": -56, "sx": 0.94, "sy": 1.07}, torso=-6, head=-14, hand_r="fist", hand_l="fist",
	 ik={"hand_r": {"to": (-68, -78), "aim": 148, "bend": 1}, "hand_l": {"to": (30, 60), "aim": -60, "bend": 1}},
	 arm_upper_r={"z": BEHIND_HEAD},
	 leg_upper_r=-72, leg_lower_r=104, foot_r=(20, "tiptoe"), leg_upper_l=-26, leg_lower_l=92, foot_l=(30, "tiptoe"),
	 beret={"rot": -14})


# ---------------------------------------------------------------------------------------------------
K = A.K
SOLE = {"flat": [(x * K, y * K) for x, y in [(-16, 9), (-11, 15), (12, 16), (38, 15), (43, 9)]]}
SOLE["tiptoe"] = [fk.apply(fk.R(A.TIPTOE_ANG), p) for p in SOLE["flat"]]
PELVIS_SEAT = [(x * K, y * K) for x, y in [(-24, 14), (0, 17), (24, 14)]]
CHAINS = {"hand_r": ("arm_upper_r", "arm_lower_r", A.ARM_UP * K, A.ARM_LO * K, 1),
		  "hand_l": ("arm_upper_l", "arm_lower_l", A.ARM_UP * K, A.ARM_LO * K, 1),
		  "foot_r": ("leg_upper_r", "leg_lower_r", A.LEG_UP * K, A.LEG_LO * K, -1),
		  "foot_l": ("leg_upper_l", "leg_lower_l", A.LEG_UP * K, A.LEG_LO * K, -1)}


def _dir_angle(v):
	"""world angle whose 'down' direction (-sin, cos) points along v."""
	return math.degrees(math.atan2(-v[0], v[1]))


def _ik(R, rig, p, end, spec):
	up, lo, L1, L2, bend = CHAINS[end]
	if not isinstance(spec, dict):
		spec = {"to": (spec[0], spec[1]), "bend": spec[2] if len(spec) > 2 else bend}
	bend = spec.get("bend", bend)
	W = R.solve(p)
	parts = rig["parts"]
	root_j = fk.apply(W[up], (0, 0))
	to = spec["to"]
	if isinstance(to[0], str):
		tgt = fk.apply(W[to[0]], (to[1][0] * K, to[1][1] * K))
	else:
		tgt = (root_j[0] + to[0] * K, root_j[1] + to[1] * K)
	aim = spec.get("aim")
	via = spec.get("via")
	if via and aim is not None:
		off = fk.apply(fk.R(aim), (via[0] * K, via[1] * K))
		tgt = (tgt[0] - off[0], tgt[1] - off[1])
	v = (tgt[0] - root_j[0], tgt[1] - root_j[1])
	d = max(abs(L1 - L2) + 1.0, min(math.hypot(*v), L1 + L2 - 0.5))
	tv = _dir_angle(v)
	a = math.degrees(math.acos(max(-1, min(1, (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d)))))
	b = math.degrees(math.acos(max(-1, min(1, (L2 * L2 + d * d - L1 * L1) / (2 * L2 * d)))))
	t1 = tv + a * bend
	t2 = tv - b * bend
	par = fk.angle(W[parts[up]["parent"]])
	out = {up: _wrap(t1 - par), lo: _wrap(t2 - t1)}
	if aim is not None:
		out[end] = _wrap(aim - t2)
	return out


def _wrap(a):
	a = (a + 180.0) % 360.0 - 180.0
	return round(a, 1)


def _ground(rig, p, mode):
	if not mode:
		return None
	R = fk.Rig(rig)
	p = copy.deepcopy(p)
	p["root"]["y"] = 0
	W = R.solve(p)
	lowest = -1e9
	if mode == "feet":
		for side in ("l", "r"):
			tex = p["bones"].get("foot_" + side, {}).get("tex", "flat")
			for pt in SOLE[tex]:
				lowest = max(lowest, fk.apply(W["foot_" + side], pt)[1])
	elif mode == "pelvis":
		for pt in PELVIS_SEAT:
			lowest = max(lowest, fk.apply(W["pelvis"], pt)[1])
	# the sole's ink outline (half of 6 px) sits ON the floor line
	return round(-(lowest + 3.0), 1)


def poses():
	rig = rig_hush.rig({}, {})
	R = fk.Rig(rig)
	clean = OrderedDict()
	for n, d in F.items():
		c = OrderedDict()
		for k, v in d.items():
			if k.startswith("_"):
				continue
			if k == "bones":
				bb = OrderedDict()
				for part, ch in v.items():
					if part.endswith("_z"):
						if ch.get("rot") is not None:
							bb.setdefault(part[:-2], {})["z"] = ch["rot"]
						continue
					bb.setdefault(part, {}).update(ch)
				c[k] = bb
			else:
				c[k] = copy.deepcopy(v)
		clean[n] = c
	doc = {"poses": clean, "mirror_of": dict(MIRROR)}
	for n, d in F.items():
		if d["_ik"] or d["_aim"] or d["_pin"]:
			for end, spec in d["_ik"].items():
				p = fk.resolve_poses(doc, rig)[n]
				for part, rot in _ik(R, rig, p, end, spec).items():
					clean[n]["bones"].setdefault(part, {})["rot"] = rot
			for part, deg in d["_aim"].items():
				p = fk.resolve_poses(doc, rig)[n]
				W = R.solve(p)
				par = rig["parts"][part]["parent"]
				clean[n]["bones"].setdefault(part, {})["rot"] = _wrap(deg - fk.angle(W[par]))
			for part, (ref, pt) in d["_pin"].items():
				p = fk.resolve_poses(doc, rig)[n]
				W = R.solve(p)
				par = rig["parts"][part]["parent"]
				tgt = fk.apply(W[ref], (pt[0] * K, pt[1] * K))
				loc = fk.apply(fk.inv(W[par]), tgt)
				off = rig["parts"][part]["offset"]
				ch = clean[n]["bones"].setdefault(part, {})
				ch["x"] = round(loc[0] - off[0], 1)
				ch["y"] = round(loc[1] - off[1], 1)
		p = fk.resolve_poses(doc, rig)[n]
		y = _ground(rig, p, d["_ground"])
		if y is not None:
			clean[n].setdefault("root", {})["y"] = y
		if not clean[n]["bones"]:
			del clean[n]["bones"]
	out = OrderedDict()
	out["version"] = 1
	out["rig"] = "hush"
	out["doc"] = ("Hush key poses. Channels per TECH 4.7 (rot deg clockwise +, limbs hang down at 0, negative swings "
				  "forward). `base` inherits, `mirror_of` swaps _l/_r. `props` (art-hush extension) places a prop on a "
				  "socket with a state for previews; clips set the same with prop events. `residues` = overlays shown. "
				  "Every grounded pose has its lowest sole point on y = 0. IK/aim/pin were solved at build time.")
	out["poses"] = clean
	out["mirror_of"] = dict(MIRROR)
	return out
