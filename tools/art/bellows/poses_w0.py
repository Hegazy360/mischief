"""Wave-0 poses for Bellows (docs/LEVELS.md §5 wave 0): the slice's remaining Night-1 / Prologue clips —
TAP DANCE (drench), KETTLE DRUM (sing crack on the stool), IN A PICKLE (strain + slip at the shelf), LIFT-OFF
(the recliner catapult), ALLEGRO-GO-GO! (the top spin), the pickles / rinse / paper activities, their micro-gags and
the three squeak bits. Same shorthand as poses_spec.P(); seated poses go through the SEAT_AT / IK helpers of
poses_s2 (the recliner cushion, the log basket rim).

Kitchen / parlour geometry in char space (art facing +x; the view mirrors for facing -1):
  recliner: st_recliner stand_x 2080 facing +1; the cushion (house prop recliner.svg rect y 196..288 of a 318 px
            image placed at world y -316) tops out at world y -120, x 2008..2158 -> seat (12, -120).
  log basket: house decor parlour_log_basket at world (2184, -119), 104 x 121; LIFT-OFF's sim landing x is 2236,
            the basket's centre -> his bottom sits 20 px below the rim: seat (0, -99).
"""
import poses_s2

RECLINER_SEAT = (12.0, -120.0)
BASKET_SEAT = (0.0, -99.0)


def define(P, SIT_Z):
	def S(name, base=None, seat=RECLINER_SEAT, ik=None, **kw):
		kw.setdefault("plant", False)
		if base is None:
			base = "b_stand"
			for part, ch in SIT_Z.items():
				kw.setdefault(part, dict(ch))
		P(name, base=base, **kw)
		poses_s2.SEAT_AT[name] = seat
		if ik:
			poses_s2.IK[name] = ik

	# ======================================================================== the pickle shelf (facing +1)
	# The jar sits on its shelf at world y -507..-330 (kitchen_pickle_jar art), i.e. from his chin to above his
	# bouffant: every pickle gesture is up in front of his face, both hands on the lid.
	P("b_shelf_reach", base="b_stand", face="pompous", tags=["activity", "pickles", "reach"],
	  sil="reaching up and forward to a jar on a high shelf, chin up", T=4, H=-12,
	  AUR=-132, ALR=-18, HR={"rot": -20, "tex": "open"}, AUL=-24, ALL=-10, HL={"tex": "open"})
	P("b_shelf_twist_a", base="b_stand", face="pompous", tags=["activity", "pickles", "twist"],
	  sil="both hands up on a jar lid at face height, elbows out", T=2, H=-8,
	  AUR=-118, ALR=-56, HR={"rot": 24, "tex": "fist"}, AUL=-106, ALL=-64, HL={"rot": -18, "tex": "fist"})
	P("b_shelf_twist_b", base="b_shelf_twist_a", root={"sx": 1.02, "sy": 0.99}, tags=["activity", "pickles", "twist"],
	  sil="the twist: hands turned the other way, head cocked", T=5, H=-3,
	  AUR=-112, ALR=-50, HR={"rot": -22, "tex": "fist"}, AUL=-112, ALL=-70, HL={"rot": 20, "tex": "fist"})
	P("b_shelf_strain_1", base="b_shelf_twist_a", root={"sx": 1.04, "sy": 0.96}, face="strain",
	  tags=["reaction", "strain_slip", "strain"],
	  sil="heaving at a stuck lid up at his face, leaning back, knees bent", T=-6, H=-14,
	  LUR=-14, LLR=22, LUL=10, LLL=18, SR={"tex": "bristle"}, SL={"tex": "bristle"}, BL={"sy": 0.96})
	P("b_shelf_strain_2", base="b_shelf_strain_1", root={"sx": 1.04, "sy": 0.94}, face="strain",
	  tags=["reaction", "strain_slip", "strain"],
	  sil="purple: bent right back off the jar, sideburns bristling, cheeks ballooned", T=-16, H=-24,
	  N={"sx": 1.12, "rot": -6}, BF={"rot": -10}, LUR=-20, LLR=30, LUL=16, LLL=24, BL={"sy": 0.92},
	  SR={"tex": "puffed"}, SL={"tex": "puffed"})
	P("b_slip_windmill_b", base="b_slip_windmill", root={"y": -8, "rot": -10}, face="terrified",
	  tags=["reaction", "slip", "strain_slip"],
	  sil="the kicked slipper tucked up, arms windmilling the other way, tipping further", T=-34, H=-18,
	  AUR=-30, ALR=-30, AUL=60, ALL=-20, LUR=-36, LLR=74, FR=-10, CT=40)
	# getting up off the floor: a straight-legged crouch, bum up, pushing on his knees (feet planted where he stands)
	P("b_getup", base="b_stand", face="strain", tags=["reaction", "getup"],
	  sil="bent double getting up, bum in the air, hands pushing on his knees", T=38, H=-30,
	  AUR=-72, ALR=-26, HR={"rot": -20, "tex": "open"}, AUL=-62, ALL=-22, HL={"tex": "open"}, LUR=13, LUL=-4, CT=-30)

	# ======================================================================== the sink (facing +1)
	P("b_sink_scrub", base="b_sink_hands", root={"sx": 1.02, "sy": 0.99}, tags=["activity", "rinse", "scrub"],
	  sil="scrubbing: hunched a little lower over the basin, elbows pumping", T=18, H=14,
	  AUR=-66, ALR=-30, HR={"rot": -20, "tex": "fist"}, AUL=-50, ALL=-34, HL={"tex": "open"})
	P("b_rinse_lift", base="b_stand", face="smug", tags=["activity", "rinse", "inspect"],
	  sil="holding a cup up to the window, inspecting it, chin up", T=-4, H=-10,
	  AUR=-104, ALR=-66, HR={"rot": 12, "tex": "grip"}, AUL=-46, ALL=-30, HL={"tex": "open"})
	P("b_rinse_shake", base="b_rinse_lift", root={"rot": 2}, tags=["activity", "rinse", "shake"],
	  sil="shaking the drips off the cup", T=-2, H=-6, AUR=-84, ALR=-40, HR={"rot": 30, "tex": "grip"})
	P("b_hose_wrestle_b", base="b_hose_wrestle", root={"sx": 1.03, "sy": 0.98}, face="strain",
	  tags=["reaction", "drench", "wrestle"],
	  sil="the python has him the other way: pitched forward, fists high, far leg braced back", T=8, H=10,
	  AUR=-50, ALR=-70, HR={"rot": -10, "tex": "fist"}, AUL=-84, ALL=-24, HL={"tex": "fist"},
	  LUR=-30, LLR=14, LUL=24, LLL=10)
	P("b_drench_blast", base="b_stand", root={"sx": 0.94, "sy": 1.06}, face="shock",
	  tags=["reaction", "drench", "accent"],
	  sil="BLAST: knocked back on his heels, arms flung up, bouffant flattened back", T=-24, H=-32,
	  BF={"rot": -26}, N={"sx": 0.9}, CR={"rot": -40},
	  AUR=-168, ALR=-24, HR={"rot": -10, "tex": "open"}, AUL=-156, ALL=-34, HL={"tex": "open"},
	  LUR=-6, LLR=4, LUL=22, LLL=6, FR=-10)
	P("b_drip_stand", base="b_slow_burn", tags=["reaction", "drench", "hold", "drip"],
	  sil="dead still and dripping, everything sagging a touch", T=3, H=6, BF={"rot": 8},
	  AUR=8, ALR=2, AUL=-8, ALL=2)
	P("b_drip_stand_b", base="b_drip_stand", tags=["reaction", "drench", "hold", "drip"],
	  sil="a blink and a shudder", T=1, H=3, BF={"rot": 10}, AUR=10, AUL=-10, BL={"sy": 0.98})

	# ======================================================================== the gramophone spin (facing -1)
	P("b_spin_wide", base="b_stand", root={"y": -10}, plant=False, face="wild_take", tags=["reaction", "dizzy_spin", "spin"],
	  sil="a spinning top: arms straight out sideways, lifted clear off the floor", T=-2, H=-6,
	  AUR=-92, ALR=-4, HR={"rot": -10, "tex": "open"}, AUL=-84, ALL=-2, HL={"rot": 6, "tex": "open"},
	  LUR=2, LLR=0, FR=0, LUL=-4, LLL=0, FL=0, CT=60)
	P("b_spin_thin", base="b_spin_wide", root={"y": -10, "sx": 0.36}, plant=False, tags=["reaction", "dizzy_spin", "spin"],
	  sil="the top seen edge-on: a thin wobbling pillar", T=0, H=-4, AUR=-100, AUL=-74, CT=70)
	P("b_pitch_forward", base="b_reel_b", face="shock", tags=["reaction", "dizzy_spin", "antic"],
	  sil="pitching forward off balance, both arms flung up and ahead, grabbing at nothing", T=26, H=12,
	  AUR=-150, ALR=-20, HR={"tex": "open"}, AUL=-140, ALL=-24, HL={"tex": "open"})
	P("b_dazed_tuck", base="b_dazed_sit", root={"rot": 0, "y": 15.4}, plant=False, tags=["reaction", "dazed", "sit", "tuck"],
	  sil="sat on the floor, knees drawn up, slippers off the ground, about to get up", T=-2, H=4,
	  AUR=30, AUL=40, LUR=-100, LLR=96, FR=0, LUL=-96, LLL=92, FL=0)
	P("b_dazed_sit_b", base="b_dazed_sit", root={"rot": -3, "y": 15.4}, tags=["reaction", "dazed", "sit"],
	  sil="sat splat, head lolling the other way", T=-4, H=-14, AUR=34, AUL=56)
	P("b_dazed_sit_c", base="b_dazed_sit", root={"rot": 2, "y": 15.4}, tags=["reaction", "dazed", "sit"],
	  sil="sat splat, chin on his chest", T=-10, H=26, AUR=44, AUL=46)

	# ======================================================================== LIFT-OFF: the chandelier dangle
	P("b_dangle_b", base="b_dangle", root={"y": -150}, tags=["reaction", "dangle", "launch_ceiling"],
	  sil="dangling, one slipper kicking, hands pawing at the cravat", T=6, H=-14,
	  AUR=-40, ALR=-110, HR={"rot": 20, "tex": "grip"}, AUL=-30, ALL=-100, HL={"rot": -20, "tex": "grip"},
	  LUR=-20, LLR=30, FR=40, LUL=6, LLL=2, FL=40)
	P("b_dangle_c", base="b_dangle", root={"y": -150}, tags=["reaction", "dangle", "launch_ceiling"],
	  sil="dangling limp, head hung, the other slipper twitching", T=2, H=18,
	  AUR=14, ALR=-2, AUL=-10, ALL=-2, LUR=4, LLR=2, FR=44, LUL=-16, LLL=26, FL=40)

	# ======================================================================== seated: the recliner (paper)
	# Reclined on the cushion, thighs forward, shins dangling, the newspaper held up in both hands.
	S("b_rec_sit", root={"rot": 0, "sx": 1, "sy": 1}, face="pompous", tags=["activity", "paper", "sit", "recliner"],
	  sil="reclined in an armchair, a newspaper held up in front of his chest, little legs dangling",
	  T=-14, H=2, AUR=-62, ALR=-56, HR={"rot": 26, "tex": "grip"}, AUL=-66, ALL=-30, HL={"rot": 10, "tex": "grip"},
	  LUR=-70, LLR=44, FR=12, LUL=-64, LLL=40, FL=16, CT=-40)
	S("b_rec_sit_b", base="b_rec_sit", root={"rot": 0, "sx": 1.01, "sy": 0.995}, tags=["activity", "paper", "sit", "page"],
	  sil="a page flicked over: the near arm out to the side", T=-13, H=4,
	  AUR=-32, ALR=-24, HR={"rot": 40, "tex": "grip"}, LUR=-66, LLR=40)
	S("b_rec_peer", base="b_rec_sit", root={"rot": 0}, face="suspicious", tags=["activity", "paper", "sit", "peer"],
	  sil="the paper lowered to his belly, peering over his specs", T=-8, H=14,
	  AUR=-40, ALR=-74, HR={"rot": 30, "tex": "grip"}, AUL=-44, ALL=-50, HL={"rot": 14, "tex": "grip"})
	S("b_rec_lever", base="b_rec_sit", root={"rot": 0}, face="smug", tags=["reaction", "launch_ceiling", "lever"],
	  sil="reclined, the near arm reaching down to a lever beside the seat", T=-18, H=-6,
	  AUR=34, ALR=-16, HR={"rot": -20, "tex": "grip"}, AUL=-60, ALL=-40, HL={"rot": 10, "tex": "grip"})
	S("b_rec_sink", base="b_rec_sit", root={"rot": 0, "sx": 1.06, "sy": 0.9}, face="antic",
	  tags=["reaction", "launch_ceiling", "antic"],
	  sil="the seat sinks under him: knees up, squashed, gripping the armrests", T=-28, H=-2,
	  AUR=-16, ALR=-84, HR={"rot": 10, "tex": "fist"}, AUL=-24, ALL=-80, HL={"tex": "fist"},
	  LUR=-108, LLR=66, FR=-10, LUL=-100, LLL=60, FL=-6, CT=-60)
	S("b_rec_rip_a", base="b_rec_sit", root={"rot": 0}, face="irked", tags=["bit", "paper", "rip"],
	  sil="both fists gripping the paper high, elbows out, about to tear", T=-10, H=6,
	  AUR=-96, ALR=-70, HR={"rot": 20, "tex": "fist"}, AUL=-92, ALL=-66, HL={"rot": -16, "tex": "fist"})
	S("b_rec_rip_b", base="b_rec_sit", root={"rot": 0, "sx": 1.03, "sy": 0.98}, face="furious", tags=["bit", "paper", "rip", "accent"],
	  sil="RIP: arms flung wide, a half of the paper in each fist", T=-16, H=-8,
	  AUR=-130, ALR=-10, HR={"rot": -30, "tex": "fist"}, AUL=-10, ALL=-10, HL={"rot": 20, "tex": "fist"})

	# ======================================================================== seated: the stool (KETTLE DRUM, bit_tea)
	STOOL = poses_s2.STOOL_SEAT
	S("b_stool_listen", base="b_stool_sit", seat=STOOL, root={"rot": 0}, face="huh", tags=["reaction", "sing_crack", "listen"],
	  sil="on the stool, head cocked toward the kettle, ear first", T=-2, H=-16, N={"rot": -4})
	S("b_stool_sing_a", base="b_stool_cup", seat=STOOL, root={"rot": 0}, face="sing_mid", tags=["reaction", "sing_crack", "sing"],
	  sil="singing along on the stool: chin up, the far hand conducting high", T=-6, H=-12,
	  AUL=-126, ALL=-30, HL={"rot": -10, "tex": "conduct"})
	S("b_stool_sing_b", base="b_stool_sing_a", seat=STOOL, root={"rot": 0}, face="sing_small", tags=["reaction", "sing_crack", "sing"],
	  sil="the downbeat on the stool", T=-3, H=-6, AUL=-56, ALL=-44, HL={"rot": 10, "tex": "conduct"}, BL={"sy": 0.97})
	S("b_stool_big_note", base="b_stool_ah3", seat=STOOL, root={"rot": 0}, face="sing_big", tags=["reaction", "sing_crack", "antic"],
	  sil="the high note: bent right back on the stool, both arms flung straight up, chest ballooned",
	  T=-18, H=-26, AUR=-172, ALR=-10, HR={"rot": -10, "tex": "grip"}, AUL=-164, ALL=-12, HL={"rot": -20, "tex": "open"},
	  BL={"sy": 1.06})
	S("b_stool_crack", base="b_stool_sit", seat=STOOL, root={"rot": 0, "sx": 1.2, "sy": 0.8}, face="shock",
	  tags=["reaction", "sing_crack", "accent"],
	  sil="CRACK: snapped forward and squashed, shoulders up round his ears, hand clutching his throat",
	  T=14, H=24, N={"sx": 0.92}, AUL=-50, ALL=-130, HL={"rot": 30, "tex": "grip"}, SR={"tex": "puffed"}, SL={"tex": "puffed"})
	S("b_stool_lid", base="b_stool_sit", seat=STOOL, root={"rot": 0}, face="huh", tags=["reaction", "sing_crack", "hold"],
	  sil="a kettle lid on his nose: cross-eyed at it, both palms up in surprise", T=-4, H=-4,
	  AUR=-96, ALR=-64, HR={"rot": -30, "tex": "open"}, AUL=-100, ALL=-60, HL={"rot": 26, "tex": "open"})
	S("b_stool_lid_b", base="b_stool_lid", seat=STOOL, root={"rot": 2}, face="dazed_open", tags=["reaction", "sing_crack", "hold"],
	  sil="trying to shake the lid off: head tipped, palms wagging", T=-2, H=-14,
	  AUR=-104, ALR=-54, HR={"rot": 10, "tex": "open"}, AUL=-92, ALL=-70, HL={"rot": -10, "tex": "open"})
	S("b_stool_snort", base="b_stool_sip", seat=STOOL, root={"rot": 0, "sx": 1.04, "sy": 0.97}, face="sneeze_gasp",
	  tags=["bit", "tea", "snort"],
	  sil="SNORT: the cup jerked away from his face, head snapped back, eyes popped", T=-10, H=-28,
	  AUR=-60, ALR=-70, HR={"rot": -20, "tex": "grip"}, N={"sx": 1.1, "rot": -8})
	S("b_stool_splutter", base="b_stool_sit", seat=STOOL, root={"rot": 0}, face="disdain", tags=["bit", "tea", "splutter"],
	  sil="spluttering forward, the far hand dabbing his nose, cup held out of harm's way", T=12, H=18,
	  AUR=-20, ALR=-40, HR={"rot": 10, "tex": "grip"}, AUL=-70, ALL=-130, HL={"rot": 20, "tex": "open"}, N={"sx": 1.04})

	# ======================================================================== seated: the log basket
	S("b_basket_sit", seat=BASKET_SEAT, root={"rot": 0, "sx": 1.04, "sy": 0.96}, face="dazed_open",
	  tags=["reaction", "launch_ceiling", "land"],
	  sil="wedged bottom-first in a log basket, slippers poking up over the rim, arms hooked over the sides",
	  T=-12, H=-8, AUR=36, ALR=-30, HR={"tex": "open"}, AUL=-44, ALL=-30, HL={"tex": "open"},
	  LUR=-118, LLR=16, FR=-30, LUL=-104, LLL=10, FL=-24, CT=-70)
	S("b_basket_sit_b", base="b_basket_sit", seat=BASKET_SEAT, root={"rot": 0}, face="dazed",
	  tags=["reaction", "launch_ceiling", "land"],
	  sil="in the basket, head lolling, one slipper twitching", T=-8, H=16, LUR=-110, LLR=28, FR=-20, LUL=-108, LLL=8)
