"""poses.json for Bellows (TECH §4.7): every P0 clip pose from GDD §9.4 plus reaction/costume extras.

Channels per bone: rot (deg, + = clockwise), x, y (px, in the parent frame), sx, sy, z, tex, vis, alpha.
Root = the character origin at the feet: {x, y, rot, sx, sy} (squash/stretch about the feet).
Angle cheat-sheet (rest = hanging down): arm forward = -90, arm straight up = -180, arm back = +90;
forearm bends forward with negative rot; leg forward = negative, knee bends with positive rot;
torso + = lean forward (bow), - = lean back (chest out); head + = chin down, - = chin up; foot + = toe down.

`plant: True` poses are grounded at build time: root y is set so the lowest slipper sole touches the floor
(y = 0). Takes and reactions carry `tags` + a one-line `silhouette` note (what reads at 50 px in solid black).
"""
import copy
import math

SHORT = {"T": "torso", "H": "head", "BF": "bouffant", "N": "nose", "CR": "cravat", "CT": "coat_tails", "BL": "belly",
		 "SR": "sideburn_r", "SL": "sideburn_l",
		 "AUR": "arm_upper_r", "ALR": "arm_lower_r", "HR": "hand_r", "AUL": "arm_upper_l", "ALL": "arm_lower_l",
		 "HL": "hand_l", "LUR": "leg_upper_r", "LLR": "leg_lower_r", "FR": "foot_r", "LUL": "leg_upper_l",
		 "LLL": "leg_lower_l", "FL": "foot_l"}

POSES = {}
PLANT = set()
RES = {}   # name -> resolved rot per bone (for absolute legs / hold angles)
LEGS = ("leg_upper_r", "leg_upper_l")


def P(name, base=None, root=None, face=None, tags=(), sil=None, plant=True, hold_r=None, hold_l=None, **bones):
	"""Author a pose. Leg-upper angles (LUR/LUL) are ABSOLUTE (from vertical, in the root frame): the helper subtracts
	the torso rotation so the legs stay where they are drawn when the barrel bends. `hold_r`/`hold_l` = the world
	angle of a prop held in that hand (0 = drawn upright); the hand rotation is solved from torso + arm."""
	e = {}
	if base:
		e["base"] = base
	if root:
		e["root"] = dict(root)
	b = {}
	for k, v in bones.items():
		part = SHORT.get(k, k)
		b.setdefault(part, {}).update({"rot": v} if isinstance(v, (int, float)) else dict(v))
	res = dict(RES[base]) if base else {}
	res.setdefault("_abs", {})
	res["_abs"] = dict(res["_abs"])
	if root and "rot" in root:
		res["_root_rot"] = root["rot"]
	for part, ch in b.items():
		if "rot" in ch:
			if part in LEGS:
				res["_abs"][part] = ch["rot"]
			else:
				res[part] = ch["rot"]
	t = res.get("torso", 0)
	for leg in LEGS:
		if leg in res["_abs"] and (leg in b or "torso" in b):
			b.setdefault(leg, {})["rot"] = round(res["_abs"][leg] - t, 1)
			res[leg] = b[leg]["rot"]
	for hold, (au, al, hand) in ((hold_r, ("arm_upper_r", "arm_lower_r", "hand_r")),
								 (hold_l, ("arm_upper_l", "arm_lower_l", "hand_l"))):
		if hold is not None:
			rot = hold - 90 - (res.get("_root_rot", 0) + t + res.get(au, 0) + res.get(al, 0))
			rot = (rot + 180) % 360 - 180
			b.setdefault(hand, {})["rot"] = round(rot, 1)
			res[hand] = b[hand]["rot"]
	if b:
		e["bones"] = b
	if face:
		e["face"] = face
	if tags:
		e["tags"] = list(tags)
	if sil:
		e["silhouette"] = sil
	POSES[name] = e
	RES[name] = res
	if plant:
		PLANT.add(name)


# sitting: the stubby legs stick out over the belly, so draw them in front of it
SIT_Z = {"leg_upper_r": {"z": 24}, "leg_lower_r": {"z": 24}, "foot_r": {"z": 25},
		 "leg_upper_l": {"z": 23}, "leg_lower_l": {"z": 23}, "foot_l": {"z": 24}}

# ============================================================================ idle
P("b_stand", root={"x": 0, "y": 0, "rot": 0, "sx": 1, "sy": 1}, face="pompous", tags=["idle", "rest"],
  sil="barrel on tiny legs under a dandelion bouffant, chest out, hands clasped behind his back",
  T=-4, H=-6, AUR=26, ALR=16, HR={"rot": 10, "tex": "fist"}, AUL=24, ALL=12, HL={"rot": 0, "tex": "fist"},
  LUR=7, LLR=0, FR=-6, LUL=-10, LLL=0, FL=8, CT=6)
P("b_breath_in", base="b_stand", root={"sx": 0.985, "sy": 1.02}, tags=["idle", "breath"],
  T=-7, H=-9, BL={"sy": 1.05}, CT=8)
P("b_breath_out", base="b_stand", root={"sx": 1.01, "sy": 0.99}, tags=["idle", "breath"],
  T=-3, H=-4, BL={"sy": 0.97}, CT=5)
P("b_fidget_admire", base="b_stand", face="admiring", tags=["idle", "fidget"],
  sil="one hand held out in front of his belly, admiring his fingernails",
  T=-2, H=12, AUR=-40, ALR=-30, HR={"rot": -34, "tex": "open"})

# ============================================================================ locomotion
# strut: 28 f/step, belly leads, chin up. Cycle: contact_r -> pass_l -> contact_l -> pass_r.
P("b_strut_contact_l", base="b_stand", face="pompous", tags=["loco", "strut", "contact"],
  sil="far slipper out front heel-first, near leg behind, chest thrust out",
  T=-8, H=-10, BL={"sy": 0.96}, AUR=-26, ALR=-20, HR={"rot": -6, "tex": "open"}, AUL=26, ALL=-6, HL={"tex": "open"},
  LUL=-30, LLL=4, FL=-14, LUR=22, LLR=16, FR=12, CT=14, CR=8)
P("b_strut_pass_l", base="b_stand", root={"sy": 1.02}, face="pompous", tags=["loco", "strut", "pass"],
  sil="near leg planted straight, far leg tucked up passing under the belly, up on the bounce",
  T=-10, H=-12, BL={"sy": 1.05}, AUR=-4, ALR=-18, HR={"rot": 0, "tex": "open"}, AUL=6, ALL=-8, HL={"tex": "open"},
  LUR=2, LLR=0, FR=0, LUL=-26, LLL=58, FL=18, CT=4, CR=-4)
P("b_irked_walk_a", base="b_stand", face="irked", tags=["loco", "walk", "irked"],
  sil="leaning into it, fists pumping, far leg forward",
  T=8, H=4, AUR=-36, ALR=-50, HR={"tex": "fist"}, AUL=34, ALL=-30, HL={"tex": "fist"},
  LUL=-32, LLL=8, FL=-10, LUR=26, LLR=20, FR=14, CT=20, CR=12, SR={"tex": "bristle"}, SL={"tex": "bristle"})
P("b_irked_walk_b", base="b_irked_walk_a", tags=["loco", "walk", "irked"],
  sil="leaning into it, fists pumping, near leg forward",
  AUR=30, ALR=-34, AUL=-30, ALL=-50, LUL=24, LLL=20, FL=14, LUR=-32, LLR=8, FR=-10)
P("b_stomp_a", base="b_stand", root={"sy": 1.03}, face="furious", tags=["loco", "stomp", "up"],
  sil="near knee hoisted up to the belly, fists clenched at his chest, leaning forward",
  T=10, H=6, AUR=-20, ALR=-90, HR={"tex": "fist"}, AUL=20, ALL=-70, HL={"tex": "fist"},
  LUR=-70, LLR=70, FR=10, LUL=4, LLL=0, FL=0, SR={"tex": "bristle"}, SL={"tex": "bristle"}, CT=-10)
P("b_stomp_b", base="b_stomp_a", root={"sx": 1.1, "sy": 0.9}, tags=["loco", "stomp", "down"],
  sil="squashed flat on the stomp, near slipper slammed down in front, fists punched down",
  T=16, H=12, AUR=16, ALR=-20, AUL=34, ALL=-10, LUR=-26, LLR=12, FR=-6, CT=24, BL={"sy": 0.92}, BF={"rot": 8})
P("b_turn_mid", base="b_stand", face="neutral", tags=["loco", "turn"],
  sil="upright and compact, arms tucked in (the 6 f squash-turn midpoint)",
  T=0, H=0, AUR=6, ALR=-10, HR={"rot": 0, "tex": "open"}, AUL=-6, ALL=-10, HL={"tex": "open"}, LUR=0, LUL=0, FR=0, FL=0)
P("b_door_reach", base="b_stand", face="neutral", tags=["loco", "door"],
  sil="near arm stretched forward to a door handle, leaning in",
  T=6, H=-2, AUR=-80, ALR=-12, HR={"rot": -14, "tex": "grip"}, LUR=6, LUL=-10, FL=4)
P("b_stairs_a", base="b_stand", face="pompous", tags=["loco", "stairs"],
  sil="near knee high on the next step, leaning into the climb",
  T=10, H=-4, AUR=-24, ALR=-30, HR={"tex": "open"}, AUL=24, ALL=-10,
  LUR=-64, LLR=64, FR=-6, LUL=10, LLL=6, FL=6)
P("b_stairs_b", base="b_stairs_a", tags=["loco", "stairs"],
  sil="far knee high on the next step",
  AUR=20, ALR=-16, AUL=-24, ALL=-30, LUR=10, LLR=6, FR=6, LUL=-64, LLL=64, FL=-6)

# ============================================================================ activities
P("b_sing_breath", base="b_stand", root={"sx": 0.97, "sy": 1.04}, face="inhale", tags=["activity", "sing", "warmup"],
  sil="leaning back on a huge inhale, chest ballooned, arms spread",
  T=-12, H=-14, BL={"sy": 1.07}, AUR=-50, ALR=-30, HR={"tex": "open", "rot": -10}, AUL=-40, ALL=-20, HL={"tex": "open"})
P("b_sing_small", base="b_stand", face="sing_small", tags=["activity", "sing", "warmup"],
  sil="hand on his heart, the other palm out front, chin up",
  T=-6, H=-10, AUR=-30, ALR=-120, HR={"rot": -40, "tex": "open"}, AUL=-60, ALL=-10, HL={"tex": "open"})
P("b_sing_big", base="b_stand", root={"sy": 1.03, "sx": 0.98}, face="sing_big", tags=["activity", "sing", "warmup"],
  sil="near arm flung high and back, far arm out front, head thrown back, belly first",
  T=-14, H=-18, BL={"sy": 1.06}, AUR=176, ALR=-6, HR={"rot": -10, "tex": "open"}, AUL=-70, ALL=-16, HL={"tex": "open"},
  BF=-6, CR=-10, CT=10)
P("b_tea_pour", base="b_stand", face="smug", hold_r=30, tags=["activity", "tea"],
  sil="near arm out front tipping a pot, head bowed to watch",
  T=6, H=12, AUR=-62, ALR=-40, HR={"tex": "grip"}, AUL=-40, ALL=-50, HL={"tex": "grip"})
P("b_tea_spoon", base="b_stand", face="smug", tags=["activity", "tea"],
  sil="stirring daintily in front of his belly, pinky out",
  T=4, H=16, AUR=-30, ALR=-44, HR={"rot": 40, "tex": "conduct"}, AUL=-40, ALL=-44, HL={"tex": "grip"})
P("b_tea_sip", base="b_stand", face="blissful", hold_r=-35, tags=["activity", "tea"],
  sil="cup raised to his lips on a folded arm, pinky out, chin tilted up",
  T=-6, H=-10, AUR=-30, ALR=-138, HR={"tex": "grip"}, AUL=-30, ALL=-70, HL={"tex": "open"})
P("b_tea_sniff", base="b_stand", face="disdain", hold_r=0, tags=["activity", "tea", "sniff"],
  sil="cup held under his nose, head bowed to the steam",
  T=4, H=14, N={"rot": -8, "sx": 1.06}, AUR=-50, ALR=-104, HR={"tex": "grip"}, AUL=-30, ALL=-70, HL={"tex": "open"})
P("b_jar_strain", base="b_stand", root={"sx": 1.05, "sy": 0.95}, face="strain", tags=["activity", "pickles", "strain"],
  sil="hunched over a jar at his belly, elbows out, knees bent",
  T=12, H=12, AUR=-30, ALR=-54, HR={"rot": 50, "tex": "fist"}, AUL=-40, ALL=-50, HL={"tex": "fist"},
  LUR=-14, LLR=24, LUL=-18, LLL=26, SR={"tex": "bristle"}, SL={"tex": "bristle"}, BL={"sy": 0.94})
P("b_fridge_reach", base="b_stand", face="huh", tags=["activity", "snack"],
  sil="bent double into the fridge, bum out, near arm reaching low",
  T=34, H=-18, AUR=-50, ALR=-10, HR={"rot": -10, "tex": "open"}, AUL=-30, ALL=-10, HL={"tex": "open"},
  LUR=-10, LLR=14, LUL=-16, LLL=16, CT=-30)
P("b_sink_hands", base="b_stand", face="neutral", tags=["activity", "rinse"],
  sil="both hands forward and down in the basin, head bowed",
  T=14, H=16, AUR=-60, ALR=-20, HR={"rot": -30, "tex": "open"}, AUL=-56, ALL=-24, HL={"tex": "open"}, CT=-14)
P("b_sit_read", base="b_stand", hold_r=0, face="smug", tags=["activity", "paper", "sit"],
  sil="sat in the recliner, newspaper held up, little legs dangling off the seat",
  T=-12, H=-6, AUR=-56, ALR=-50, HR={"tex": "grip"}, AUL=-60, ALL=-30, HL={"tex": "grip"},
  LUR=-86, LLR=84, FR=-6, LUL=-82, LLL=80, FL=-4, CT=-60,
  **SIT_Z)

P("b_lever_pull", base="b_stand", face="strain", tags=["activity", "paper", "lever"],
  sil="leaning back hard, near arm yanking a lever down at his side",
  T=-16, H=-6, AUR=18, ALR=-20, HR={"rot": -10, "tex": "grip"}, AUL=-30, ALL=-40, HL={"tex": "fist"},
  LUR=-14, LLR=6, LUL=10, LLL=8)
P("b_bellows_pump", base="b_stand", root={"sx": 1.04, "sy": 0.96}, face="irked", tags=["activity", "fire"],
  sil="stooped at the hearth, fists squeezing a bellows at his knees",
  T=24, H=-4, AUR=-40, ALR=-30, HR={"rot": 10, "tex": "fist"}, AUL=-30, ALL=-36, HL={"tex": "fist"},
  LUR=-20, LLR=30, LUL=-24, LLL=34, CT=-20)
P("b_preen", base="b_stand", face="admiring", tags=["activity", "mirror", "preen"],
  sil="chin up, near hand stroking his magnificent mutton chop",
  T=-6, H=-10, AUR=-10, ALR=-150, HR={"rot": -12, "tex": "open"}, BF=4)
P("b_lean_in", base="b_stand", face="suspicious", tags=["activity", "mirror", "lean"],
  sil="leaning right in to the glass, hands behind his back, nose first",
  T=20, H=8, N={"sx": 1.04}, LUR=-6, LUL=-12, CT=-18)
P("b_specs_lift", base="b_stand", face="suspicious", tags=["activity", "mirror", "specs"],
  sil="near hand lifting his specs up to his eyes",
  T=4, H=-2, AUR=-60, ALR=-120, HR={"rot": -10, "tex": "conduct"})
P("b_phone_pompous", base="b_stand", face="pompous", hold_r=-55, tags=["activity", "phone"],
  sil="folded arm, handset across his cheek, far fist on his hip, nose in the air",
  T=-6, H=-10, AUR=-16, ALR=-150, HR={"tex": "grip"}, AUL=40, ALL=-80, HL={"tex": "fist"})
P("b_clock_wind", base="b_stand", face="pompous", hold_r=0, tags=["activity", "clock"],
  sil="near arm raised straight out to the clock face, winding a key",
  T=-4, H=-12, AUR=-100, ALR=-10, HR={"tex": "grip"}, LUR=-4, LUL=-10)
P("b_hunt_peer_r", base="b_stand", face="suspicious", tags=["activity", "hunt", "peer"],
  sil="leaning far forward on his toes, hands behind, nose first, peering ahead",
  T=22, H=-16, N={"sx": 1.06}, LUR=12, LUL=-26, LLL=4, FL=-6, FR={"rot": 20, "tex": "tiptoe"}, CT=-24)
P("b_hunt_peer_l", base="b_stand", face="look_back", tags=["activity", "hunt", "peer"],
  sil="leaning back, peering over his shoulder behind him",
  T=-14, H={"rot": -14, "sx": 0.95}, AUR=30, ALR=-10, AUL=-40, ALL=-60, HL={"tex": "fist"}, LUR=-8, LUL=6)

# ============================================================================ states
P("b_suspicious", base="b_stand", face="suspicious", tags=["state", "suspicious"],
  sil="hunched forward, near hand on his chin, far hand behind",
  T=12, H=6, AUR=-26, ALR=-136, HR={"rot": -20, "tex": "fist"})
P("b_dt_away", base="b_stand", face="smug", tags=["state", "double_take", "away"],
  sil="chin up, looking away obliviously",
  T=-6, H=-14)
P("b_dt_back", base="b_stand", root={"sy": 1.1, "sx": 0.92}, face="shock", tags=["state", "double_take", "back"],
  sil="snapped back up tall, head jutting forward, both arms flicked out wide",
  T=8, H=12, AUR=-86, ALR=-20, HR={"rot": -30, "tex": "open"}, AUL=-70, ALL=-20, HL={"tex": "open"}, BF={"rot": -8, "y": -12},
  FR={"rot": 14, "tex": "tiptoe"}, FL={"rot": 14, "tex": "tiptoe"}, SR={"tex": "bristle"}, SL={"tex": "bristle"})
P("b_take_antic", base="b_stand", root={"sx": 1.12, "sy": 0.88}, face="antic", tags=["take", "antic"],
  sil="crouched and squashed, fists tucked to his chest, head ducked",
  T=14, H=12, AUR=-30, ALR=-110, HR={"rot": 10, "tex": "fist"}, AUL=-30, ALL=-100, HL={"tex": "fist"},
  LUR=-18, LLR=34, FR=0, LUL=-22, LLL=38, FL=0, BL={"sy": 0.93}, CT=-10, BF=6)
P("b_take_accent", base="b_stand", plant=False, root={"y": -34, "sx": 0.86, "sy": 1.24}, face="wild_take",
  tags=["take", "accent", "pop"],
  sil="WILD TAKE: sprung tall off the floor, arms up in a V, the bouffant leaping clean off his bald dome",
  T=-10, H={"rot": -12, "sy": 1.15}, AUR=170, ALR=-8, HR={"rot": -10, "tex": "open"}, AUL=-150, ALL=-14, HL={"tex": "open"},
  LUR=-10, LLR=10, FR=30, LUL=14, LLL=10, FL=30, BF={"y": -40, "rot": -6}, SR={"tex": "puffed"}, SL={"tex": "puffed"},
  CT=40, CR=-30)
P("b_look_behind", base="b_stand", face="look_back", tags=["state", "look"],
  sil="twisted, peering back over his shoulder",
  T=-10, H={"rot": -12, "sx": 0.95}, AUR=20, ALR=-4)
P("b_chase_a", base="b_stand", face="furious", tags=["state", "chase", "run"],
  sil="pitched forward, arms grabbing ahead, near leg flung forward",
  T=22, H=-14, AUR=-96, ALR=-10, HR={"tex": "open"}, AUL=-60, ALL=-20, HL={"tex": "open"},
  LUR=-50, LLR=20, FR=-10, LUL=40, LLL=40, FL=20, CT=-40, CR=20, SR={"tex": "bristle"}, SL={"tex": "bristle"})
P("b_chase_b", base="b_chase_a", root={"y": -8}, plant=False, tags=["state", "chase", "run"],
  sil="pitched forward, airborne, far leg flung forward",
  AUR=-60, ALR=-30, AUL=-100, ALL=-10, LUR=40, LLR=44, FR=20, LUL=-50, LLL=20, FL=-10, CT=-50)
P("b_wheeze", base="b_stand", face="wheeze", tags=["state", "wheeze"],
  sil="bent double, hands braced on his knees, head up gasping",
  T=40, H=-28, AUR=-40, ALR=10, HR={"rot": -10, "tex": "open"}, AUL=-36, ALL=12, HL={"tex": "open"},
  LUR=-14, LLR=16, LUL=-8, LLL=12, CT=-30)
P("b_grab", base="b_stand", face="furious", tags=["state", "grab"],
  sil="lunging forward, both arms shot out straight to grab",
  T=24, H=-16, AUR=-96, ALR=-4, HR={"rot": -10, "tex": "grip"}, AUL=-90, ALL=-4, HL={"tex": "grip"},
  LUR=-40, LLR=20, LUL=24, LLL=10, CT=-30)
P("b_lecture_hold", base="b_stand", face="lecture", tags=["state", "lecture", "hold"],
  sil="far arm held out stiff at shoulder height (holding Hush up), near finger wagging out in front",
  T=-8, H=-6, AUL=-100, ALL=-6, HL={"rot": -10, "tex": "grip"}, AUR=-70, ALR=-20, HR={"rot": -60, "tex": "wag"})
P("b_lecture_wag_a", base="b_lecture_hold", tags=["state", "lecture", "wag"],
  sil="scolding finger tipped forward on the beat", ALR=-6, HR={"rot": -50, "tex": "wag"}, H=-2)
P("b_lecture_wag_b", base="b_lecture_hold", tags=["state", "lecture", "wag"],
  sil="scolding finger tipped back on the beat", ALR=-44, HR={"rot": -76, "tex": "wag"}, H=-10)
P("b_melt_stomp_up", base="b_stand", root={"sy": 1.04}, face="livid", tags=["state", "meltdown", "up"],
  sil="MELTDOWN: knee hoisted high, both fists up over his head",
  T=-6, H=-10, AUR=172, ALR=-40, HR={"tex": "fist"}, AUL=-160, ALL=-30, HL={"tex": "fist"},
  LUR=-80, LLR=80, FR=10, LUL=2, LLL=0, SR={"tex": "puffed"}, SL={"tex": "puffed"}, BF=-10, CT=20)
P("b_melt_stomp_down", base="b_melt_stomp_up", root={"sx": 1.16, "sy": 0.86}, tags=["state", "meltdown", "down"],
  sil="MELTDOWN: squashed into the floor on the stomp, fists punched down",
  T=16, H=14, AUR=20, ALR=-20, AUL=40, ALL=-20, LUR=-24, LLR=10, FR=-4, BF=12, BL={"sy": 0.92}, CT=-20)
P("b_exhausted_sit", base="b_stand", root={"sy": 0.97}, face="wheeze", tags=["state", "exhausted", "sit"],
  sil="slumped on the floor, legs out straight, arms limp, head hung",
  T=18, H=24, AUR=-10, ALR=-10, HR={"tex": "open"}, AUL=-20, ALL=-10, HL={"tex": "open"},
  LUR=-86, LLR=0, FR=-10, LUL=-80, LLL=0, FL=-10, CT=-80, BF=10,
  **SIT_Z)

P("b_slow_burn", base="b_stand", face="slow_burn", tags=["state", "slow_burn", "hold"],
  sil="dead still, arms limp at his sides, a flat stare out at the Stalls",
  T=0, H=4, AUR=4, ALR=0, HR={"rot": 0, "tex": "open"}, AUL=-4, ALL=0, HL={"tex": "open"}, LUR=0, LUL=0, FR=0, FL=0, CT=0)
P("b_dignity_straighten", base="b_stand", face="pompous", tags=["state", "dignity"],
  sil="chin up, both hands tugging his cravat straight",
  T=-6, H=-14, AUR=-30, ALR=-100, HR={"rot": 40, "tex": "grip"}, AUL=-36, ALL=-100, HL={"rot": 40, "tex": "grip"})
P("b_pardon_pat", base="b_stand", face="pardon", tags=["state", "pardon", "bump"],
  sil="patting his belly, a little bow of the head",
  T=4, H=10, AUR=-30, ALR=-66, HR={"rot": -40, "tex": "open"})
P("b_bonk_door", base="b_stand", root={"sx": 0.92, "sy": 1.06}, face="dazed", tags=["state", "bonk", "reaction"],
  sil="knocked back by the door, flattened face-first, arms flung behind",
  T=-18, H={"rot": -14, "sx": 0.9, "sy": 1.08}, N={"sx": 0.8, "rot": 10}, AUR=70, ALR=-10, HR={"tex": "open"}, AUL=60, ALL=-10,
  HL={"tex": "open"}, LUR=-14, LUL=10, BF=-10)

# ============================================================================ reactions
P("b_sneeze_ah1", base="b_tea_sniff", face="sneeze_build", hold_r=-8, tags=["reaction", "sneeze", "antic"],
  sil="ah... head tipping back, nose up, cup still in hand",
  T=-4, H=-10, N={"rot": -10, "sx": 1.08}, AUR=-40, ALR=-110)
P("b_sneeze_ah2", base="b_sneeze_ah1", root={"sx": 0.97, "sy": 1.04}, face="sneeze_build2", hold_r=-14,
  tags=["reaction", "sneeze", "antic"],
  sil="ahh... leaning back, chest swelling, far arm lifting",
  T=-10, H=-18, BL={"sy": 1.05}, AUL=-50, ALL=-40, N={"rot": -14, "sx": 1.12})
P("b_sneeze_ah3", base="b_stand", root={"sx": 0.93, "sy": 1.09}, face="sneeze_build2", tags=["reaction", "sneeze", "antic"],
  sil="AHHH... bent right back on tiptoe, head thrown back, arms winding up behind",
  T=-20, H=-26, AUR=150, ALR=-40, HR={"rot": 20, "tex": "open"}, AUL=130, ALL=-30, HL={"tex": "open"},
  FR={"rot": 26, "tex": "tiptoe"}, FL={"rot": 26, "tex": "tiptoe"}, LUR=-4, LUL=4, BL={"sy": 1.07},
  N={"rot": -18, "sx": 1.16}, BF=-8)
P("b_sneeze_false_stop", base="b_stand", face="relief", tags=["reaction", "sneeze", "false_stop"],
  sil="relief: settles back down, shoulders dropped, smug",
  T=-2, H=-2, N={"rot": 0}, AUR=-20, ALR=-40, HR={"tex": "open"})
P("b_sneeze_choo", base="b_stand", root={"sx": 1.16, "sy": 0.86}, face="sneeze_choo", tags=["reaction", "sneeze", "accent", "pop"],
  sil="CHOO: snapped forward and squashed low, arms flung back, head and nose thrust out",
  T=24, H=12, N={"sx": 1.12}, AUR=80, ALR=-10, HR={"tex": "open"}, AUL=90, ALL=-10, HL={"tex": "open"},
  BF={"rot": 16}, LUR=-24, LLR=24, LUL=-28, LLL=28, CT=-50, CR=40, SR={"tex": "bristle"}, SL={"tex": "bristle"})
P("b_sneeze_recoil", base="b_stand", plant=False, root={"y": -36, "rot": -24, "x": -24}, face="shock",
  tags=["reaction", "sneeze", "recoil", "launch"],
  sil="rocketing backwards off his feet, bouffant flipped over his face, slippers kicked up",
  T=-20, H=-10, AUR=-110, ALR=-40, HR={"tex": "open"}, AUL=-130, ALL=-30, HL={"tex": "open"},
  LUR=-70, LLR=10, FR=-20, LUL=-60, LLL=20, FL=-20, BF={"tex": "flipped"}, CT=40)
P("b_dazed", base="b_stand", face="dazed", tags=["reaction", "dazed", "settle"],
  sil="wobbly and slack, head lolling, arms hanging",
  root={"rot": 3}, T=6, H=16, AUR=6, ALR=-4, HR={"tex": "open"}, AUL=-6, ALL=-4, HL={"tex": "open"}, LUR=6, LLR=10, LUL=-4, LLL=8)
P("b_dazed_sit", base="b_stand", root={"rot": 4}, face="dazed", tags=["reaction", "dazed", "sit"],
  sil="sat splat on the floor, legs splayed, propped on his hands",
  T=-8, H=18, AUR=40, ALR=-10, HR={"tex": "open"}, AUL=50, ALL=-6, HL={"tex": "open"},
  LUR=-70, LLR=20, FR=-20, LUL=-96, LLL=10, FL=-10, CT=-70,
  **SIT_Z)

P("b_dizzy_a", base="b_stand", face="dazed", root={"rot": -6}, tags=["reaction", "dizzy"],
  sil="reeling back, arms out for balance",
  T=-10, H=-16, AUR=-100, ALR=-20, HR={"tex": "open"}, AUL=90, ALL=-20, HL={"tex": "open"}, LUR=-10, LUL=14)
P("b_dizzy_b", base="b_stand", face="dazed", root={"rot": 6}, tags=["reaction", "dizzy"],
  sil="reeling forward, arms out for balance",
  T=12, H=18, AUR=80, ALR=-30, HR={"tex": "open"}, AUL=-100, ALL=-20, HL={"tex": "open"}, LUR=14, LUL=-12)
P("b_launched", base="b_stand", plant=False, root={"y": -120, "rot": -30}, face="wild_take", tags=["reaction", "launch", "air"],
  sil="spread-eagle in mid-air, all four limbs flung out",
  T=-10, H=-10, AUR=170, ALR=-10, HR={"tex": "open"}, AUL=-140, ALL=-10, HL={"tex": "open"},
  LUR=-50, LLR=10, FR=20, LUL=40, LLL=10, FL=20, BF={"rot": 20, "y": -12}, CT=70, CR=-40, SR={"tex": "puffed"}, SL={"tex": "puffed"})
P("b_dangle", base="b_stand", plant=False, root={"y": -150}, face="terrified", tags=["reaction", "dangle", "launch_ceiling"],
  sil="hanging from his cravat, arms and slippers dangling limp",
  T=4, H=-20, CR={"rot": 180}, AUR=10, ALR=-4, HR={"tex": "open"}, AUL=-6, ALL=-4, HL={"tex": "open"},
  LUR=6, LLR=4, FR=40, LUL=-4, LLL=4, FL=40, CT=0)
P("b_slip_windmill", base="b_stand", plant=False, root={"y": -8, "rot": -10}, face="terrified", tags=["reaction", "slip", "strain_slip"],
  sil="one slipper kicked up high, arms windmilling, tipping back",
  T=-24, H=-10, AUR=170, ALR=-20, HR={"tex": "open"}, AUL=-60, ALL=-30, HL={"tex": "open"},
  LUR=-96, LLR=10, FR=-20, LUL=10, LLL=20, FL=10, CT=30)
P("b_fall_sit", base="b_stand", root={"sx": 1.08, "sy": 0.92}, face="shock", tags=["reaction", "fall", "sit"],
  sil="landed on his bottom, slippers up in the air, arms out behind",
  T=-14, H=-6, AUR=50, ALR=-10, HR={"tex": "open"}, AUL=60, ALL=-10, HL={"tex": "open"},
  LUR=-110, LLR=0, FR=-20, LUL=-100, LLL=10, FL=-20, CT=-80,
  **SIT_Z)

P("b_blind_arms_out", base="b_stand", face="huh", tags=["reaction", "blind", "blind_bumble"],
  sil="stiff zombie arms groping straight ahead, hair over his eyes",
  T=-4, H=-10, AUR=-90, ALR=-4, HR={"rot": -10, "tex": "open"}, AUL=-84, ALL=-4, HL={"tex": "open"}, BF={"tex": "flipped"},
  LUR=-18, LLR=8, LUL=10, LLL=6)
P("b_fish_slap_recoil", base="b_phone_pompous", face="shock", hold_r=-20, tags=["reaction", "fish_slap", "accent"],
  sil="head snapped back from a kipper slap, kipper held out, far arm flung up",
  T=-14, H={"rot": -26, "sx": 0.94}, AUR=-60, ALR=-70, AUL=-150, ALL=-20, HL={"tex": "open"},
  BF={"rot": 10}, SR={"tex": "bristle"}, SL={"tex": "bristle"}, LUR=-14, LUL=12)
P("b_cling", base="b_stand", plant=False, root={"y": -24}, face="terrified", tags=["reaction", "cling", "jackhammer_cling"],
  sil="hugging something tall, knees drawn up, slippers off the floor",
  T=6, H=-6, AUR=-96, ALR=-40, HR={"rot": -20, "tex": "grip"}, AUL=-90, ALL=-44, HL={"tex": "grip"},
  LUR=-70, LLR=90, FR=10, LUL=-60, LLL=86, FL=10, CT=-20)
P("b_drench_shield", base="b_stand", face="antic", tags=["reaction", "drench"],
  sil="leaning away from a face-full of water, palm thrown up in front of his chin",
  T=-16, H=-18, AUR=-40, ALR=-120, HR={"rot": -60, "tex": "open"}, AUL=-60, ALL=-20, HL={"tex": "open"},
  LUR=-20, LUL=12, BF={"rot": -14})
P("b_hose_wrestle", base="b_stand", face="strain", tags=["reaction", "drench", "wrestle"],
  sil="braced wide, leaning back, both fists wrestling a hose like a python",
  T=-12, H=-6, AUR=-70, ALR=-30, HR={"rot": 20, "tex": "fist"}, AUL=-40, ALL=-60, HL={"tex": "fist"},
  LUR=-30, LLR=10, LUL=30, LLL=6)
P("b_sing_crack", base="b_stand", face="shock", tags=["reaction", "sing_crack"],
  sil="clutching his throat on a folded arm, eyes popped, hunched",
  T=10, H=4, AUR=-20, ALR=-146, HR={"rot": -40, "tex": "grip"}, AUL=-20, ALL=-60, HL={"tex": "open"})
P("b_duck_cover", base="b_stand", root={"sx": 1.06, "sy": 0.94}, face="terrified", tags=["reaction", "avalanche", "antic"],
  sil="ducking, arms clamped over his bouffant, knees bent",
  T=18, H=16, AUR=176, ALR=-90, HR={"rot": -20, "tex": "open"}, AUL=-170, ALL=-60, HL={"tex": "open"},
  LUR=-20, LLR=30, LUL=-24, LLL=32)
P("b_fly_back", base="b_stand", plant=False, root={"x": -30, "y": -40, "rot": -26}, face="wild_take",
  tags=["reaction", "mirror", "launch"],
  sil="flying backwards, slippers leading, arms flung forward",
  T=-16, H=-6, AUR=-100, ALR=-30, HR={"tex": "open"}, AUL=-120, ALL=-20, HL={"tex": "open"},
  LUR=-60, LLR=10, FR=-10, LUL=-50, LLL=16, FL=-10, BF={"rot": 20}, CT=60)
P("b_bow", base="b_stand", face="smug", tags=["state", "bow", "t3_beat"],
  sil="a grand opera bow: bent double, near arm swept across the belly, far arm flung back",
  T=46, H=16, AUR=-60, ALR=-80, HR={"rot": -20, "tex": "open"}, AUL=90, ALL=-10, HL={"tex": "open"},
  LUR=-10, LUL=16, LLL=6, CT=-60, BF=10)
P("b_tiptoe_mortified", base="b_stand", root={"y": -6}, face="mortified", tags=["reaction", "costume", "tiptoe"],
  sil="up on pointe in a tutu, near arm curved up over his head, mortified",
  T=-4, H=4, AUR=176, ALR=-50, HR={"rot": -30, "tex": "conduct"}, AUL=-80, ALL=-20, HL={"tex": "conduct"},
  FR={"rot": 30, "tex": "tiptoe"}, FL={"rot": 30, "tex": "tiptoe"}, LUR=-4, LUL=4)

SEAT = {"b_sit_read": 46}   # px above the floor (the recliner seat)

MIRROR_OF = {"b_strut_contact_r": "b_strut_contact_l", "b_strut_pass_r": "b_strut_pass_l"}

# ============================================================================ Stage 2 (s2-anim-bellows)
# the stool, the sneeze, the tea / warm-up / idle poses and the generated walk cycles live in poses_s2.py
import poses_s2  # noqa: E402
poses_s2.define(P, SIT_Z)
MIRROR_OF.update(poses_s2.define_standing(P))

REQUIRED = ["b_stand", "b_breath_in", "b_breath_out", "b_fidget_admire", "b_strut_contact_l", "b_strut_pass_l",
			"b_strut_contact_r", "b_strut_pass_r", "b_irked_walk_a", "b_irked_walk_b", "b_stomp_a", "b_stomp_b",
			"b_turn_mid", "b_door_reach", "b_stairs_a", "b_stairs_b", "b_sing_breath", "b_sing_small", "b_sing_big",
			"b_tea_pour", "b_tea_spoon", "b_tea_sip", "b_tea_sniff", "b_jar_strain", "b_fridge_reach", "b_sink_hands",
			"b_sit_read", "b_lever_pull", "b_bellows_pump", "b_preen", "b_lean_in", "b_specs_lift", "b_phone_pompous",
			"b_clock_wind", "b_hunt_peer_l", "b_hunt_peer_r", "b_suspicious", "b_dt_away", "b_dt_back",
			"b_take_antic", "b_take_accent", "b_look_behind", "b_chase_a", "b_chase_b", "b_wheeze", "b_grab",
			"b_lecture_hold", "b_lecture_wag_a", "b_lecture_wag_b", "b_melt_stomp_up", "b_melt_stomp_down",
			"b_exhausted_sit", "b_slow_burn", "b_dignity_straighten", "b_pardon_pat", "b_bonk_door",
			"b_sneeze_ah1", "b_sneeze_ah2", "b_sneeze_ah3", "b_sneeze_false_stop", "b_sneeze_choo",
			"b_sneeze_recoil", "b_dazed_sit", "b_dizzy_a", "b_dizzy_b", "b_launched", "b_dangle",
			"b_slip_windmill", "b_fall_sit", "b_blind_arms_out", "b_fish_slap_recoil", "b_cling"]

# take pairs whose bounding boxes must differ >= 15 % (GDD §9.3 / TECH §10.5)
TAKE_PAIRS = [("b_take_antic", "b_take_accent"), ("b_sneeze_ah3", "b_sneeze_choo"), ("b_stomp_a", "b_stomp_b"),
			  ("b_melt_stomp_up", "b_melt_stomp_down"), ("b_duck_cover", "b_take_accent"), ("b_dt_away", "b_dt_back"),
			  ("b_stool_hup", "b_stool_choo")]

# preview-only prop hints (which prop a pose is drawn holding on the sheets)
PREVIEW_PROPS = {
	"b_tea_pour": {}, "b_tea_spoon": {}, "b_tea_sip": {"teacup": (None, None)}, "b_tea_sniff": {"teacup": (None, None)},
	"b_sneeze_ah1": {"teacup": (None, None)}, "b_sneeze_ah2": {"teacup": (None, None)},
	"b_sit_read": {"newspaper": (None, "open")}, "b_phone_pompous": {"phone_handset": (None, None)},
	"b_sneeze_ah3": {}, "b_clock_wind": {},
	"b_fish_slap_recoil": {"kipper_held": (None, None)}, "b_preen": {}, "b_specs_lift": {"specs": ("hand_r:grip", "on")},
	"b_suspicious": {"specs": (None, "on")}, "b_lean_in": {"specs": (None, "dangling")},
	"b_stand": {"specs": (None, "dangling")},
}


def _plant(poses_out):
	"""Ground the `plant` poses: the lowest slipper sole -- or, for sitting poses (`sit` tag), the lowest point of
	the barrel -- touches the floor (y = 0)."""
	import fk
	import parts_body as B
	rig = fk.load()
	src = {"poses": poses_out, "mirror_of": MIRROR_OF}
	rig.poses_src = src
	rig._resolved = {}
	for name in POSES:
		if name not in PLANT:
			continue
		pose = rig.raw_pose(name)
		M0, W = rig.solve(pose)
		low = -1e9
		for foot in ("foot_r", "foot_l"):
			tex = pose["bones"].get(foot, {}).get("tex", "flat")
			for p in B.FOOT_SOLE[tex]:
				low = max(low, fk.apply(W[foot], p)[1])
		if "sit" in POSES[name].get("tags", []):
			for p in B.TORSO_SIL:
				low = max(low, fk.apply(W["torso"], (p[0], p[1] + 3))[1])
			low += SEAT.get(name, 0)
		cur = pose["root"].get("y", 0)
		poses_out[name].setdefault("root", {})["y"] = round(cur - low, 1)
		rig._resolved = {}
	return poses_out


def _stage2(poses_out):
	"""poses_s2 build steps: seated roots (SEAT_AT), then planting, then the arm IK (targets in char space)."""
	import fk
	import parts_body as B
	rig = fk.load()
	rig.poses_src = {"poses": poses_out, "mirror_of": MIRROR_OF}
	poses_s2.seat(rig, poses_out, B.TORSO_SIL)
	return rig


def poses_json():
	out = copy.deepcopy(POSES)
	rig = _stage2(out)
	out = _plant(out)
	import parts_body as B
	import rig_spec as R
	lim = {p: R.LIMITS.get(p, [-360, 360]) for p in R.PARTS}
	for w in poses_s2.ik(rig, out, B.GRIP, lim):
		print("[poses] IK: " + w)
	return {"version": 1, "rig": "bellows", "poses": out, "mirror_of": dict(MIRROR_OF)}
