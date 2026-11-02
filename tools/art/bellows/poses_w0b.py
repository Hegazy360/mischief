"""Wave-0 closing poses for Bellows (docs/LEVELS.md §5): the states (suspicious, double take, look, chase, wheeze,
grab, search, bump, look-back, head turn, smirk, specs on, door slam, doorway pause, face to face), the Lecture, the
Meltdowns and Exhausted, the four T3 last beats, the detour fix-ups, the hunt, the cold opens, the curtain call, the
remaining micro-gags and the Irked / Steaming walks and the chase run.

Most of what these clips need was already authored for the slice (poses_spec / poses_s2); this module adds only the
gags that had no pose yet, plus three generated cycles (`b_irked_`, `b_stomp_`, `b_run_`) whose planted feet match
the map speeds (anim lint A27): Irked 264 px/s (30 f, 132 px), Steaming 276 px/s (30 f, 138 px), chase 600 px/s
(12 f, 120 px)."""
import math

import poses_s2


def define(P, SIT_Z):
	# ======================================================================== states
	P("b_smirk", base="b_stand", face="sly_smile", tags=["state", "fizzle", "smirk"],
	  sil="chin up, one shoulder shrugged, a smug little 'hmph'", T=-7, H=-13,
	  AUR=-14, ALR=-20, HR={"rot": -10, "tex": "open"}, BL={"sy": 1.02})
	P("b_smirk_b", base="b_smirk", root={"sx": 0.99, "sy": 1.02}, tags=["state", "fizzle", "smirk"],
	  sil="the shrug settles", T=-4, H=-8, AUR=-6)
	P("b_door_slam", base="b_door_reach", face="furious", tags=["state", "door", "slam"],
	  sil="arm swung right across his body, slamming the door shut", T=14, H=6,
	  AUR=30, ALR=-120, HR={"rot": 40, "tex": "fist"})
	P("b_shriek", base="b_stand", root={"sx": 0.88, "sy": 1.16}, face="terrified", tags=["state", "face_to_face"],
	  sil="SHRIEK: sprung tall, both hands flat to his cheeks, mouth a cavern",
	  T=-12, H=-18, N={"sx": 1.12}, BF={"rot": -18},
	  AUR=-104, ALR=-128, HR={"rot": -20, "tex": "open"}, AUL=-96, ALL=-132, HL={"rot": 20, "tex": "open"},
	  SR={"tex": "puffed"}, SL={"tex": "puffed"})
	P("b_sink_blast", base="b_sink_land", root={"sx": 1.14, "sy": 0.84}, face="shock",
	  tags=["reaction", "drench", "sink", "accent"],
	  sil="the tap finds him in the basin: squashed down into it, both arms flung wide, bouffant flattened back",
	  T=-18, H=-28, BF={"rot": -28}, N={"sx": 0.9},
	  AUR=-156, ALR=-20, HR={"rot": -20, "tex": "open"}, AUL=-148, ALL=-24, HL={"rot": 20, "tex": "open"},
	  SR={"tex": "puffed"}, SL={"tex": "puffed"})
	P("b_pant_a", base="b_exhausted_sit", face="wheeze", tags=["state", "exhausted", "pant"],
	  sil="slumped on the floor, chest heaving in", T=-6, H=-4, BL={"sy": 1.06})
	P("b_pant_b", base="b_exhausted_sit", face="wheeze", tags=["state", "exhausted", "pant"],
	  sil="the breath out, shoulders dropping", T=4, H=10, BL={"sy": 0.94})

	# ======================================================================== the Meltdown
	P("b_melt_roar", base="b_sing_big", face="livid", tags=["state", "meltdown", "roar"],
	  sil="MELTDOWN: bellowing at the ceiling, both fists shaken overhead, chest out",
	  T=-6, H=-34, AUR=-168, ALR=-30, HR={"rot": -10, "tex": "fist"}, AUL=-156, ALL=-34, HL={"tex": "fist"},
	  SR={"tex": "bristle"}, SL={"tex": "bristle"}, BL={"sy": 1.06})
	P("b_melt_hop", base="b_melt_stomp_up", root={"y": -40}, plant=False, face="livid", tags=["state", "meltdown", "hop"],
	  sil="hopping mad: both feet off the floor, knees tucked, fists down", T=-6, H=-10,
	  AUR=40, ALR=-30, HR={"tex": "fist"}, AUL=34, ALL=-26, HL={"tex": "fist"},
	  LUR=-54, LLR=70, FR=20, LUL=-48, LLL=66, FL=20)
	P("b_melt_fists", base="b_stand", root={"sy": 0.97}, face="livid", tags=["state", "meltdown", "fists"],
	  sil="fists clenched down at his sides, shaking with rage, head down", T=2, H=18,
	  AUR=18, ALR=-16, HR={"tex": "fist"}, AUL=-14, ALL=-16, HL={"tex": "fist"},
	  SR={"tex": "bristle"}, SL={"tex": "bristle"})

	# ======================================================================== the Lecture (he holds Hush out)
	P("b_lecture_shake", base="b_lecture_hold", face="furious", tags=["state", "lecture", "shake"],
	  sil="the holding arm shaken like a rug, the other fist up", T=8, H=10,
	  AUL=-70, ALL=-50, HL={"rot": 20, "tex": "fist"})
	P("b_lecture_high", base="b_lecture_hold", face="sing_big", tags=["state", "lecture", "high_note"],
	  sil="a high operatic note mid-scolding, chin right up, the free arm flung wide", T=-14, H=-26,
	  AUL=-140, ALL=-20, HL={"rot": -20, "tex": "open"})
	P("b_lecture_plonk", base="b_stand", face="irked", tags=["state", "lecture", "plonk"],
	  sil="bending to plonk her down on the doorstep, both hands low", T=30, H=-12,
	  AUR=-66, ALR=-20, HR={"rot": -20, "tex": "open"}, AUL=-58, ALL=-24, HL={"tex": "open"})

	# ======================================================================== T3 last beats
	P("b_tear_lip", base="b_slow_burn", face="teary", tags=["beat", "tear"],
	  sil="dead still, bottom lip wobbling", T=2, H=6)
	P("b_tear_sniff", base="b_slow_burn", face="teary", tags=["beat", "tear", "sniff"],
	  sil="a sniff: chin up, one knuckle to the nose", T=-4, H=-10,
	  AUR=-50, ALR=-120, HR={"rot": -20, "tex": "fist"})
	P("b_bow_deep", base="b_bow", root={"y": -34.0}, plant=False, tags=["beat", "bow", "deep"],
	  sil="the bow keeps going: folded right over, nose past his knees", T=58, H=24, AUL=110,
	  LUR=-56, LLR=14, LUL=-40, LLL=10)
	P("b_topple", base="b_bow", root={"rot": 26, "y": -46.0}, plant=False, face="shock", tags=["beat", "bow", "topple"],
	  sil="the bow tips past the point of no return, arms flailing", T=58, H=20,
	  AUR=-130, ALR=-20, AUL=140, ALL=-20, LUR=-20, LUL=-6)
	P("b_cravat_ping", base="b_dignity_straighten", face="huh", tags=["beat", "dignity", "ping"],
	  sil="the cravat springs out of his hands and stands straight up", T=-6, H=-16, CR={"rot": -100},
	  AUR=-80, ALR=-60, HR={"rot": -20, "tex": "open"}, AUL=-74, ALL=-56, HL={"tex": "open"})

	# ======================================================================== the fix-up detours
	P("b_steam_dry", base="b_stand", face="blissful", tags=["detour", "fixup_dry"],
	  sil="steaming gently at the fire, arms out from his sides, head back", T=-8, H=-18,
	  AUR=-56, ALR=-20, HR={"rot": -40, "tex": "open"}, AUL=-50, ALL=-18, HL={"rot": 40, "tex": "open"})
	P("b_steam_fluff", base="b_steam_dry", face="smug", tags=["mg", "fixup_dry", "fluff"],
	  sil="fluffing a dripping sideburn out into a poodle ear", T=-4, H=-10,
	  AUR=-120, ALR=-110, HR={"rot": -30, "tex": "open"}, SR={"tex": "puffed"}, SL={"tex": "puffed"})
	P("b_scrub_face", base="b_sink_hands", face="disdain", tags=["detour", "fixup_sink", "scrub"],
	  sil="scrubbing his own face with both hands over the basin", T=22, H=18,
	  AUR=-116, ALR=-110, HR={"rot": -20, "tex": "fist"}, AUL=-110, ALL=-114, HL={"rot": 20, "tex": "fist"})
	P("b_scrub_nose", base="b_scrub_face", face="disdain", tags=["mg", "fixup_sink", "nose"],
	  sil="both hands squeaking his nose between them", T=16, H=22, N={"sx": 0.86, "rot": -4},
	  AUR=-124, ALR=-124, AUL=-118, ALL=-126)
	P("b_comb_flourish", base="b_preen", face="smug", tags=["mg", "fixup_mirror", "comb"],
	  sil="a big comb flourish up through the bouffant, the other hand on his hip", T=-8, H=-14,
	  AUR=-166, ALR=-96, HR={"rot": -30, "tex": "grip"}, AUL=40, ALL=-70, HL={"tex": "fist"})
	P("b_comb_tuck", base="b_preen", face="sly_smile", tags=["mg", "fixup_mirror", "tuck"],
	  sil="tucking the comb behind his ear, chin up", T=-6, H=-10,
	  AUR=-150, ALR=-126, HR={"rot": -40, "tex": "grip"})
	P("b_peer_under", base="b_stand", face="suspicious", tags=["mg", "hunt", "peer"],
	  sil="bent right down with his bottom up, peering under a low piano", T=58, H=-34,
	  AUR=-40, ALR=-20, HR={"rot": -20, "tex": "open"}, AUL=40, ALL=-30, HL={"tex": "open"},
	  LUR=-18, LLR=30, LUL=-24, LLL=34, CT=-40)

	# ======================================================================== cold opens and the curtain call
	P("b_megaphone", base="b_sing_big", face="sing_big", tags=["cold", "megaphone"],
	  sil="a megaphone jammed to his mouth, the other arm flung wide, chest out", T=-14, H=-24,
	  AUR=-46, ALR=-116, HR={"rot": -30, "tex": "grip"}, AUL=-150, ALL=-20, HL={"tex": "open"})
	P("b_baton_up", base="b_stand", face="smug", tags=["cold", "baton"],
	  sil="a baton raised like a conductor about to strike", T=-6, H=-12,
	  AUR=-160, ALR=-30, HR={"rot": -20, "tex": "grip"}, AUL=30, ALL=-60, HL={"tex": "fist"})
	P("b_baton_stab", base="b_stand", root={"sx": 1.05, "sy": 0.95}, face="sly_smile", tags=["cold", "baton", "accent"],
	  sil="the baton stabbed forward at arm's length", T=8, H=10,
	  AUR=-96, ALR=-6, HR={"rot": -10, "tex": "grip"}, AUL=24, ALL=-50, HL={"tex": "fist"})
	P("b_cc_shrug", base="b_stand", face="huh", tags=["curtain", "shrug"],
	  sil="both palms turned up in a 'what?' shrug, shoulders high", T=-2, H=6,
	  AUR=-44, ALR=-60, HR={"rot": -50, "tex": "open"}, AUL=-40, ALL=-56, HL={"rot": 50, "tex": "open"})

	# ======================================================================== the picture-bonk cue (Prologue)
	P("b_picture_wear", base="b_blind_stand", face="dazed_open", tags=["cue", "picture"],
	  sil="a picture frame hung round his neck, arms limp, head poking through", T=4, H=8,
	  AUR=16, ALR=-10, HR={"tex": "open"}, AUL=-12, ALL=-10, HL={"tex": "open"})

	# ======================================================================== the livid rage aria (bit_livid)
	P("b_rage_aria", base="b_sing_big", face="livid", tags=["bit", "livid", "aria"],
	  sil="a rage aria at the ceiling: bent right back, both arms thrown out, bouffant bristling",
	  T=-22, H=-34, BF={"rot": -14}, AUR=-150, ALR=-26, HR={"rot": -20, "tex": "open"},
	  AUL=-142, ALL=-30, HL={"tex": "open"}, SR={"tex": "bristle"}, SL={"tex": "bristle"}, BL={"sy": 1.08})
	P("b_rage_point", base="b_stand", face="livid", tags=["bit", "livid", "point"],
	  sil="jabbing a finger straight up at the ceiling, glaring", T=-10, H=-24,
	  AUR=-172, ALR=-10, HR={"rot": -10, "tex": "point"}, AUL=20, ALL=-60, HL={"tex": "fist"},
	  SR={"tex": "bristle"}, SL={"tex": "bristle"})


def define_cycles(P):
	"""The Irked / Steaming walks and the chase run; returns the mirror_of entries of their far halves."""
	mirror = {}

	def irked_arms(f):
		s = math.sin(2 * math.pi * f / 30.0)
		return {"AUR": round(34 - 26 * s, 1), "ALR": round(-26 - 10 * s, 1), "HR": {"rot": round(-6 + 6 * s, 1), "tex": "fist"},
				"AUL": round(34 + 26 * s, 1), "ALL": round(-26 + 10 * s, 1), "HL": {"rot": round(-6 - 6 * s, 1), "tex": "fist"}}

	def irked_extra(f):
		c2 = math.cos(4 * math.pi * f / 30.0)
		return {"H": round(-6 - 3 * c2, 1), "BL": {"sy": round(1.0 - 0.03 * c2, 3)}, "CT": round(8 + 7 * c2, 1),
				"SR": {"tex": "bristle"}, "SL": {"tex": "bristle"}}
	_n, m = poses_s2.walk_cycle(P, "b_irked_", "b_stand", cycle=30, stance=15, lift=16.0, stride=132.0,
								knee_pct=0.985, toe=6.0, lean=lambda f: -2.0 - 2.0 * math.cos(4 * math.pi * f / 30.0),
								arm_fn=irked_arms, face="irked", tags=["loco", "irked"],
								sil="Irked: head down, fists swinging, a quicker clipped march", extra=irked_extra)
	mirror.update(m)

	def stomp_arms(f):
		s = math.sin(2 * math.pi * f / 30.0)
		return {"AUR": round(50 - 34 * s, 1), "ALR": round(-40 - 14 * s, 1), "HR": {"rot": round(-4 + 8 * s, 1), "tex": "fist"},
				"AUL": round(50 + 34 * s, 1), "ALL": round(-40 + 14 * s, 1), "HL": {"rot": round(-4 - 8 * s, 1), "tex": "fist"}}

	def stomp_extra(f):
		c2 = math.cos(4 * math.pi * f / 30.0)
		return {"H": round(2 - 5 * c2, 1), "BL": {"sy": round(1.0 - 0.05 * c2, 3)}, "CT": round(14 + 10 * c2, 1),
				"N": {"rot": round(-2 * c2, 1)}, "SR": {"tex": "bristle"}, "SL": {"tex": "bristle"}}
	_n, m = poses_s2.walk_cycle(P, "b_stomp_", "b_stand", cycle=30, stance=15, lift=18.0, stride=138.0,
								knee_pct=0.985, toe=6.0, lean=lambda f: -6.0 - 2.0 * math.cos(4 * math.pi * f / 30.0),
								arm_fn=stomp_arms, face="furious", tags=["loco", "stomp"],
								sil="Steaming: a flat-footed stomp, knees high, fists pumping, leaning in", extra=stomp_extra)
	mirror.update(m)

	def run_arms(f):
		s = math.sin(2 * math.pi * f / 12.0)
		return {"AUR": round(-40 - 70 * s, 1), "ALR": round(-80 - 20 * s, 1), "HR": {"rot": 0, "tex": "fist"},
				"AUL": round(-40 + 70 * s, 1), "ALL": round(-80 + 20 * s, 1), "HL": {"rot": 0, "tex": "fist"}}

	def run_extra(f):
		c2 = math.cos(4 * math.pi * f / 12.0)
		return {"H": round(-14 - 4 * c2, 1), "BL": {"sy": round(1.0 - 0.04 * c2, 3)}, "CT": round(30 + 14 * c2, 1),
				"BF": {"rot": round(10 + 6 * c2, 1)}, "SR": {"tex": "bristle"}, "SL": {"tex": "bristle"}}
	_n, m = poses_s2.walk_cycle(P, "b_run_", "b_stand", cycle=12, stance=6, lift=16.0, stride=120.0,
								knee_pct=0.985, toe=6.0, lean=lambda f: 14.0 - 2.0 * math.cos(4 * math.pi * f / 12.0),
								arm_fn=run_arms, face="furious", tags=["loco", "chase", "run"],
								sil="the chase: leaning right forward, knees high, fists pumping", extra=run_extra)
	mirror.update(m)
	return mirror
