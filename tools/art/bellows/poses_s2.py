"""Stage-2 poses for Bellows (s2-anim-bellows, Phase G): ACHOO-RIA! on the kitchen stool, the tea and warm-up
loops, the strut and blind-shuffle walk cycles, the idle and the bonks.

Imported by poses_spec.py (which owns P(), POSES and the build). Three computed helpers run at build time on the
freshly written rig.json (fk.Rig), in this order, before the standing poses are planted:

  SEAT_AT  pose -> (x, y): root x / y are set so the barrel's lowest silhouette point sits exactly there (char
           space, art facing +x). The kitchen stool's cushion is (0, -150) -- st_tea stand_x 3000 facing -1, the
           house decor kitchen_stool seat pivot (s2-art contract) -- and the Belfast basin seat is (-28, -226)
           (world (3788, -226) with the sim's landing x 3760, facing -1). With root rot 0 and torso rot 0 the
           torso:seat socket then lands on the stool prop's pivot (0, -82), so the prop and the decor coincide.
  IK       pose -> [(side, target, hand_deg, tex)]: a 2-bone arm IK puts the hand's grip point on `target`
           (char px, or an anatomy anchor: ("mouth_cup", hold) = the teacup's back rim on the lips, ("nose_cup",
           hold) = the cup just under the nose, ("part", name, (x, y)) = a part-local point). hand_deg = the hand's
           world angle (0 = fingers down, -90 = fingers forward); a held prop's world angle is hand_deg + 90.
  WALK     the strut and blind-shuffle cycles: feet planted exactly on the floor while the body moves at the map
           speed (leg IK in the torso frame), the far half of each cycle mirrored.
"""
import math

# kitchen geometry in char space (st_tea: world x 3000, facing -1 -> char x = 3000 - world x)
STOOL_SEAT = (0.0, -150.0)
SINK_SEAT = (-28.0, -210.0)   # 16 px deeper than the s2-art seat (-226): wedged in the basin behind the lip
KETTLE_HANDLE = (62.0, -300.0)
COUNTER_REST = (96.0, -206.0)
HONEY_JAR = (72.0, -420.0)

SEAT_AT = {}
IK = {}
WALKS = {}          # name -> (cycle, key frames) for docs / tests

# anatomy anchors (part-local, joint-relative px)
MOUTH = ("head", (42.0, -6.0))
NOSE_UNDER = ("head", (62.0, -22.0))
CUP_BACK_RIM = (-38.0, -14.0)    # the `sip` teacup's rim point nearest the drinker (prop px, pivot = the handle grip)


def define(P, SIT_Z):
	"""Author every Stage-2 pose through poses_spec.P()."""
	def S(name, base=None, seat=STOOL_SEAT, ik=None, **kw):
		"""A seated pose: never planted (SEAT_AT places the barrel), legs drawn over the belly (SIT_Z)."""
		kw.setdefault("plant", False)
		if base is None:
			base = "b_stand"
			for part, ch in SIT_Z.items():
				kw.setdefault(part, dict(ch))
		P(name, base=base, **kw)
		SEAT_AT[name] = seat
		if ik:
			IK[name] = ik

	# ======================================================================== on the stool (tea, the sneeze)
	# Seated anatomy (root y -110): near shoulder (-14, -293), mouth (56, -311), nose tip ~(58, -340), belly front
	# (99, -243). His arms are 84 px: every tea gesture happens in front of his chin and belly. The teacup is in
	# its `sip` state (handle forward, the cup body toward his face) throughout the tea and the sneeze.
	# Thighs forward over the cushion, shins dangling, slippers pointing down.
	F_REST = ("l", (72.0, -246.0), -60, "open")          # far hand resting on his belly (mostly behind it)
	S("b_stool_sit", root={"rot": 0, "sx": 1, "sy": 1}, face="pompous", tags=["activity", "tea", "sit", "stool"],
	  sil="perched on a tall kitchen stool, little legs dangling, chest out, teacup held at his chest",
	  T=-3, H=-6, LUR=-78, LLR=86, FR=28, LUL=-70, LLL=92, FL=34, CT=-36,
	  ik=[("r", (84.0, -262.0), -94, "grip"), F_REST])
	S("b_stool_sit_b", base="b_stool_sit", root={"rot": 0, "sx": 1.01, "sy": 0.99}, tags=["activity", "tea", "sit", "breath"],
	  T=-1, H=-3, LUR=-72, LLR=94, FR=34, LUL=-76, LLL=84, FL=26, BL={"sy": 0.97},
	  ik=[("r", (84.0, -258.0), -92, "grip"), F_REST])
	# the pour: head bowed over the cup he holds out under the kettle, far hand tipping the kettle behind his belly
	S("b_stool_pour_a", base="b_stool_sit", face="smug", tags=["activity", "tea", "pour"],
	  sil="head bowed over the cup held out low in front of his belly (the kettle pouring)",
	  T=8, H=16, ik=[("r", (100.0, -236.0), -84, "grip"), ("l", (100.0, -262.0), -80, "grip")])
	S("b_stool_pour_b", base="b_stool_pour_a", tags=["activity", "tea", "pour"],
	  sil="the cup dips as it fills", T=9, H=19,
	  ik=[("r", (100.0, -229.0), -80, "grip"), ("l", (104.0, -254.0), -56, "grip")])
	# the spoon: a dainty far-hand pinch stirring over the cup, pinkie out
	S("b_stool_stir_a", base="b_stool_sit", face="smug", tags=["activity", "tea", "stir"],
	  sil="stirring the cup at his chest with a dainty pinch, pinkie out", T=2, H=12,
	  ik=[("r", (80.0, -258.0), -92, "grip"), ("l", (100.0, -280.0), -86, "conduct")])
	S("b_stool_stir_b", base="b_stool_stir_a", tags=["activity", "tea", "stir"], T=3, H=14,
	  ik=[("r", (80.0, -258.0), -92, "grip"), ("l", (92.0, -274.0), -72, "conduct")])
	# the sniff: nose down into the steam
	S("b_stool_sniff", base="b_stool_sit", face="sniff", tags=["activity", "tea", "sniff"],
	  sil="nose in the steam over the cup, head bowed", T=6, H=20, N={"rot": -6, "sx": 1.06},
	  ik=[("r", ("mouth_cup_off", 0.0, (10.0, 6.0)), -96, "grip"), F_REST])
	S("b_stool_sniff_b", base="b_stool_sniff", face="suspicious", tags=["activity", "tea", "sniff", "twitch"],
	  sil="the nose twitches (the pepper is in there)", H=16, N={"rot": -16, "sx": 1.14})
	S("b_stool_cup", base="b_stool_sit", face="smug", tags=["activity", "tea", "cup"],
	  sil="teacup held up at his chest, pinkie cocked", T=-2, H=-4,
	  ik=[("r", (80.0, -268.0), -94, "grip"), F_REST])
	S("b_stool_savour_a", base="b_stool_sit", face="hum", tags=["activity", "tea", "savour"], T=-4, H=-10, BF=-4,
	  ik=[("r", (82.0, -266.0), -96, "grip"), F_REST])
	S("b_stool_savour_b", base="b_stool_sit", face="hum", tags=["activity", "tea", "savour"], T=0, H=2, BF=4,
	  ik=[("r", (84.0, -260.0), -90, "grip"), F_REST])
	# the sip: torso and root dead upright so the stool socket sits on the house stool's pivot
	S("b_stool_sip", base="b_stool_sit", root={"rot": 0, "sx": 1, "sy": 1}, face="sip",
	  tags=["activity", "tea", "sip", "stool"],
	  sil="pinkie-up sip on the stool: the cup tipped to his lips, hand and pinkie out in front of his face",
	  T=0, H=-12, ik=[("r", ("mouth_cup", 0.0), -118, "grip"), F_REST])
	S("b_stool_sip_hold", base="b_stool_sip", root={"rot": 0, "sx": 1, "sy": 1}, tags=["activity", "tea", "sip"],
	  sil="the long slurp, chin tipping up", T=0, H=-15, ik=[("r", ("mouth_cup", 0.0), -126, "grip"), F_REST])
	S("b_stool_ahh_b", base="b_stool_sip", root={"rot": 0, "sx": 1, "sy": 1}, face="sip", tags=["activity", "tea", "savour"],
	  sil="savouring it, chin a touch higher", T=0, H=-17,
	  ik=[("r", ("mouth_cup_off", 0.0, (8.0, 20.0)), -100, "grip"), F_REST])
	# ...and the "Ahhh": the cup just off his lips, eyes shut (act_tea at 7.0 s == rx_sneeze_blast_a f0)
	S("b_stool_ahh", base="b_stool_sip", root={"rot": 0, "sx": 1, "sy": 1}, face="sip",
	  tags=["activity", "tea", "sip", "stool", "savour"],
	  sil="'Ahhh': the cup just off his lips, pinkie up, eyes shut, chin up", T=0, H=-14,
	  ik=[("r", ("mouth_cup_off", 0.0, (6.0, 16.0)), -104, "grip"), F_REST])

	# ---- ACHOO-RIA!: ah (20) -> ahh (24) -> AHHH (30), each rising and leaning further back
	S("b_stool_ah1", base="b_stool_sit", root={"rot": -2, "sx": 0.99, "sy": 1.02}, face="sneeze_build",
	  tags=["reaction", "sneeze", "antic", "ah1"], sil="ah... head tipping back, nose up, the cup lowered to his chin",
	  T=-4, H=-18, N={"rot": -10, "sx": 1.08}, BL={"sy": 1.03},
	  ik=[("r", ("mouth_cup_off", 0.0, (12.0, 26.0)), -96, "grip"), ("l", (70.0, -250.0), -56, "open")])
	S("b_stool_ah2", base="b_stool_sit", root={"rot": -6, "sx": 0.97, "sy": 1.05}, face="sneeze_build2",
	  tags=["reaction", "sneeze", "antic", "ah2"], sil="ahh... rocking back on the stool, chest swelling, legs lifting",
	  T=-10, H=-25, N={"rot": -14, "sx": 1.12}, BL={"sy": 1.05}, LUR=-96, LLR=70, LUL=-88, LLL=76, FR=16, FL=22,
	  AUL=-110, ALL=-40, HL={"rot": -20, "tex": "open"},
	  ik=[("r", ("part", "torso", (84.0, -150.0)), -92, "grip")])
	S("b_stool_ah3", base="b_stool_sit", root={"rot": -12, "sx": 0.93, "sy": 1.09}, face="sneeze_build3",
	  tags=["reaction", "sneeze", "antic", "ah3"],
	  sil="AHHH... bent right back on the stool, nose to the ceiling, the cup held up high, legs kicked up",
	  T=-18, H=-30, N={"rot": -18, "sx": 1.18}, BL={"sy": 1.07}, BF=-10, LUR=-116, LLR=48, LUL=-108, LLL=56,
	  FR=-4, FL=0, AUL=136, ALL=-26, HL={"rot": 20, "tex": "open"}, CT=-10,
	  AUR=-132, ALR=-22, HR={"rot": 62, "tex": "grip"})
	S("b_stool_ah3_b", base="b_stool_ah3", root={"rot": -13, "sx": 0.925, "sy": 1.095},
	  tags=["reaction", "sneeze", "antic", "tremble"], sil="AHHH trembling at the top",
	  H=-31, N={"rot": -19, "sx": 1.2}, AUL=139, LUR=-114, LUL=-110,
	  AUR=-136, ALR=-19, HR={"rot": 64, "tex": "grip"})
	# the false stop: it's gone... he settles, relieved, and lifts the cup for another sip
	S("b_stool_relief", base="b_stool_sit", root={"rot": 1, "sx": 1.03, "sy": 0.97}, face="relief",
	  tags=["reaction", "sneeze", "false_stop"], sil="phew: slumped back down on the stool, shoulders dropped, smiling",
	  T=4, H=2, N={"rot": 0, "sx": 1.0}, BL={"sy": 0.95}, LUR=-72, LLR=92, LUL=-66, LLL=98, FR=34, FL=40,
	  ik=[("r", (82.0, -254.0), -94, "grip"), ("l", (70.0, -244.0), -60, "open")])
	S("b_stool_resip", base="b_stool_relief", root={"rot": 2, "sx": 1.02, "sy": 0.98}, face="smug",
	  tags=["reaction", "sneeze", "false_stop"], sil="smugly raising the cup again", T=2, H=-6,
	  ik=[("r", ("mouth_cup_off", 0.0, (6.0, 14.0)), -104, "grip"), ("l", (70.0, -244.0), -60, "open")])
	# the "hup!": one sharp inhale -- head snaps back past the AHHH, eyes pop (the wind-up against the CHOO)
	S("b_stool_hup", base="b_stool_relief", root={"rot": 3, "sx": 0.98, "sy": 1.03}, face="sneeze_gasp",
	  tags=["reaction", "sneeze", "antic", "hup"], sil="HUP: a last gasp, head snapped back, chin up",
	  T=-4, H=-33, N={"rot": -20, "sx": 1.2}, BL={"sy": 1.04}, LUR=-66, LLR=100, LUL=-60, LLL=104,
	  ik=[("r", ("mouth_cup_off", 0.0, (16.0, 24.0)), -96, "grip"), ("l", (68.0, -248.0), -60, "open")])
	# CHOO! -- head and nose snap DOWN-FORWARD, the barrel recoils BACK, the cup arm flings up over his head, the
	# far arm flings back, legs kick out straight ahead, the stool tips back under him
	S("b_stool_choo", base="b_stool_sit", root={"rot": -18, "sx": 1.14, "sy": 0.86}, face="sneeze_choo",
	  tags=["reaction", "sneeze", "accent", "pop"],
	  sil="CHOO: head whipped down to his chest, nose jabbing forward, the barrel blown back, arms streaming back "
		  "and up, slippers kicked out ahead",
	  T=-10, H=35, N={"rot": 20, "sx": 1.24}, BF={"rot": 30}, CR={"rot": -120}, CT=64,
	  AUR=96, ALR=-12, HR={"rot": 10, "tex": "grip"}, AUL=104, ALL=-8, HL={"rot": 40, "tex": "open"},
	  LUR=-118, LLR=0, FR=-30, LUL=-110, LLL=-2, FL=-26,
	  SR={"tex": "bristle"}, SL={"tex": "bristle"})
	# the flight: blown backwards on the stool, head whipped forward, bouffant flipped over the face, arms and
	# slippers trailing forward, the teacup still in his fist, pinkie up
	S("b_fly_a", base="b_stool_sit", root={"rot": -46, "sx": 0.92, "sy": 1.08}, face="wild_take",
	  tags=["reaction", "sneeze", "launch", "flight"],
	  sil="rocketing backwards on the stool, slippers first up in the air, arms streaming",
	  T=-8, H=26, N={"rot": 10, "sx": 1.1}, BF={"tex": "flipped", "rot": 14}, CR={"rot": -150}, CT=70,
	  AUR=116, ALR=-6, HR={"rot": 20, "tex": "grip"}, AUL=134, ALL=-4, HL={"rot": 20, "tex": "open"},
	  LUR=-112, LLR=0, FR=-30, LUL=-100, LLL=4, FL=-24,
	  SR={"tex": "puffed"}, SL={"tex": "puffed"})
	S("b_fly_b", base="b_fly_a", root={"rot": -52, "sx": 0.96, "sy": 1.04}, tags=["reaction", "sneeze", "launch", "flight"],
	  sil="still flying, tipping further back, arms flailing",
	  T=-12, H=22, BF={"tex": "flipped", "rot": 20}, AUR=40, ALR=-30, HR={"rot": 10, "tex": "grip"},
	  AUL=60, ALL=-20, LUR=-110, LLR=6, LUL=-98, LLL=22)
	# in the sink: wedged bottom-first in the basin behind the lip, tipped back, tiny slippers poking up over the
	# front edge, bouffant flipped over the face, the teacup still aloft
	S("b_sink_land", base="b_stool_sit", seat=SINK_SEAT, root={"rot": -32, "sx": 1.16, "sy": 0.84}, face="dazed_open",
	  tags=["reaction", "sneeze", "sink", "land", "squash"],
	  sil="SPLASH: jammed bottom-first into the sink, squashed, slippers poking up over the basin",
	  T=-6, H=-6, BF={"tex": "flipped", "rot": 6}, CR={"rot": -40}, CT=56,
	  AUR=-150, ALR=-16, HR={"rot": 40, "tex": "grip"}, AUL=-80, ALL=-20, HL={"rot": -20, "tex": "open"},
	  LUR=-104, LLR=16, FR=-24, LUL=-92, LLL=22, FL=-18, SR={"tex": "puffed"}, SL={"tex": "puffed"})
	S("b_sink_sit", base="b_sink_land", seat=SINK_SEAT, root={"rot": -26, "sx": 0.98, "sy": 1.02},
	  tags=["reaction", "sneeze", "sink", "hold"],
	  sil="stuck in the sink, tipped back, tiny slippers poking up, the teacup still held high",
	  T=-6, H=-10, AUR=-146, ALR=-20, LUR=-100, LLR=20, LUL=-86, LLL=28, SR={"tex": "bristle"}, SL={"tex": "bristle"})
	S("b_sink_kick_a", base="b_sink_sit", seat=SINK_SEAT, tags=["reaction", "sneeze", "sink", "kick"],
	  sil="slippers kicking over the basin", LUR=-116, LLR=40, FR=-40, LUL=-80, LLL=10, FL=0, H=-8)
	S("b_sink_kick_b", base="b_sink_sit", seat=SINK_SEAT, tags=["reaction", "sneeze", "sink", "kick"],
	  sil="kicking the other way", LUR=-86, LLR=8, FR=0, LUL=-112, LLL=44, FL=-40, H=-12)
	# ...and, blind, he takes a dignified sip -- into his hair -- then rinses the cup in the basin
	S("b_sink_sip", base="b_sink_sit", seat=SINK_SEAT, root={"rot": -24, "sx": 1.0, "sy": 1.0}, face="sip",
	  tags=["reaction", "sneeze", "sink", "sip"], sil="stuck in the sink, pinkie up, sipping tea through his fringe",
	  H=-4, ik=[("r", ("mouth_cup", 0.0), -118, "grip")])
	S("b_sink_sip_b", base="b_sink_sip", seat=SINK_SEAT, tags=["reaction", "sneeze", "sink", "sip"],
	  sil="tipping the cup right up into his hair", H=-8, ik=[("r", ("mouth_cup", 0.0), -140, "grip")])
	S("b_sink_dunk", base="b_sink_sit", seat=SINK_SEAT, root={"rot": -22, "sx": 1.0, "sy": 1.0}, face="dazed",
	  tags=["reaction", "sneeze", "sink", "dunk"], sil="dunking the teacup in the basin to rinse it",
	  T=6, H=10, ik=[("r", (16.0, -226.0), -30, "grip")])
	# the exit: springs up out of the basin like a cork, then drops onto his feet in front of the sink
	S("b_sink_pop", base="b_sink_sit", seat=(-10.0, -300.0), root={"rot": -8, "sx": 0.9, "sy": 1.12}, face="dazed_open",
	  tags=["reaction", "sneeze", "sink", "pop", "exit"], sil="popping up out of the sink like a cork, arms out",
	  T=0, H=6, AUR=-100, ALR=-10, HR={"rot": -10, "tex": "open"}, AUL=-92, ALL=-10, HL={"rot": -10, "tex": "open"},
	  LUR=-40, LLR=40, FR=10, LUL=-30, LLL=50, FL=16, CT=10)
	P("b_blind_land", base="b_blind_arms_out", root={"sx": 1.04, "sy": 0.96}, face="dazed",
	  tags=["reaction", "sneeze", "land", "squash"], sil="plonked onto his feet, squashed, zombie arms out",
	  T=-2, H=12, BL={"sy": 0.92}, LUR=-12, LLR=8, LUL=8, LLL=6, FR=0, FL=0, BF={"tex": "flipped"})
	P("b_blind_stand", base="b_blind_arms_out", face="dazed", tags=["reaction", "sneeze", "settle", "blind"],
	  sil="dazed, hair over his eyes, zombie arms groping ahead", T=-2, H=-6, BF={"tex": "flipped"},
	  LUR=-12, LLR=8, LUL=8, LLL=6, FR=0, FL=0)


def define_standing(P):
	"""Standing Stage-2 poses: the idle and its cravat tug, the warm-up conducting, the blind shuffle's bonk, the
	door-slam stun; then the two walk cycles. Returns the mirror_of entries of the walk halves."""
	# idle: thumb hooked in his lapel, chest out -- an arm in the silhouette (b_stand hides both behind his back)
	P("b_idle_lapel", base="b_stand", face="pompous", tags=["idle", "rest", "lapel"],
	  sil="barrel on tiny legs, chest out, near thumb hooked in his lapel, far hand behind his back",
	  T=-5, H=-7, BL={"sy": 1.01})
	IK["b_idle_lapel"] = [("r", ("part", "torso", (40.0, -118.0)), -176, "fist")]
	P("b_idle_lapel_b", base="b_idle_lapel", root={"sx": 1.008, "sy": 0.99}, tags=["idle", "breath"],
	  T=-3, H=-5, BL={"sy": 0.97}, CT=5)
	IK["b_idle_lapel_b"] = [("r", ("part", "torso", (40.0, -114.0)), -174, "fist")]
	P("b_idle_tug", base="b_idle_lapel", face="pompous", tags=["idle", "fidget", "tug"],
	  sil="chin up, both hands at his cravat, straightening it", T=-6, H=-14, CR=6,
	  AUL=-40, ALL=-110, HL={"rot": 30, "tex": "grip"})
	IK["b_idle_tug"] = [("r", ("part", "torso", (46.0, -128.0)), -168, "grip")]
	P("b_idle_tug_b", base="b_idle_tug", root={"sx": 0.99, "sy": 1.02}, tags=["idle", "fidget", "tug"],
	  sil="the tug: cravat yanked straight, chin jutting, belly out", T=-9, H=-18, CR=18, BL={"sy": 1.05})
	IK["b_idle_tug_b"] = [("r", ("part", "torso", (48.0, -116.0)), -172, "grip")]
	# warm-up: conducting his own scales (near hand leads, pinkie-pinch)
	P("b_conduct_up", base="b_sing_small", face="sing_mid", tags=["activity", "warmup", "conduct"],
	  sil="chin up, singing, near hand raised high conducting, far hand on his heart",
	  T=-8, H=-14, AUR=-150, ALR=-40, HR={"rot": -20, "tex": "conduct"}, AUL=-60, ALL=-100, HL={"tex": "open"})
	P("b_conduct_down", base="b_conduct_up", face="sing_small", tags=["activity", "warmup", "conduct"],
	  sil="the downbeat: conducting hand swept down in front, belly bounce",
	  T=-4, H=-8, AUR=-70, ALR=-30, HR={"rot": 10, "tex": "conduct"}, BL={"sy": 0.96})
	P("b_warm_hold", base="b_sing_big", face="sing_big", tags=["activity", "warmup", "hold"],
	  sil="the held top note: both arms spread wide, head back, belly out",
	  T=-12, H=-18, AUR=-120, ALR=-20, HR={"rot": -30, "tex": "open"}, AUL=-130, ALL=-20, HL={"tex": "open"})
	P("b_warm_hold_b", base="b_warm_hold", root={"sx": 0.985, "sy": 1.02}, tags=["activity", "warmup", "hold", "vibrato"],
	  T=-13, H=-20, AUR=-126, AUL=-136, BL={"sy": 1.07})
	P("b_warm_rest", base="b_stand", face="smug", tags=["activity", "warmup", "rest"],
	  sil="between phrases: hands clasped at his belly, smug, listening to himself",
	  T=-4, H=-6, BL={"sy": 1.02})
	IK["b_warm_rest"] = [("r", ("part", "torso", (60.0, -66.0)), -110, "open")]
	P("b_warm_rest_b", base="b_warm_rest", tags=["activity", "warmup", "rest", "sway"], T=-2, H=-2, root={"rot": 1.5})
	IK["b_warm_rest_b"] = [("r", ("part", "torso", (60.0, -63.0)), -108, "open")]
	# blind: the door-frame bonk (an upper-body overlay over the shuffle) and a rub
	P("b_blind_bonk", base="b_blind_stand", face="shock", tags=["reaction", "blind", "bonk", "accent"],
	  sil="BONK: head knocked back by the door frame, arms flung up", T=-14, H=-28, N={"sx": 0.84, "rot": 12},
	  AUR=-150, ALR=-40, HR={"rot": -20, "tex": "open"}, AUL=-160, ALL=-30, HL={"tex": "open"}, BF={"rot": -20},
	  SR={"tex": "puffed"}, SL={"tex": "puffed"})
	P("b_blind_rub", base="b_blind_stand", face="dazed", tags=["reaction", "blind", "rub"],
	  sil="rubbing his forehead, far arm still groping ahead", T=4, H=10,
	  AUL=-84, ALL=-6)
	IK["b_blind_rub"] = [("r", ("part", "head", (26.0, -80.0)), -150, "open")]
	# the door-slam stun: pancaked on the door, then reeling back with stars -- the slippers stay planted
	LEGS_DZ = dict(LUR=6, LLR=10, LUL=-4, LLL=8, FR=0, FL=0)
	P("b_bonk_flat", base="b_bonk_door", root={"sx": 0.97, "sy": 1.04, "rot": 0}, face="shock", tags=["state", "bonk", "accent"],
	  sil="SPLAT: pancaked face-first on the door, arms flung back", T=8, H={"rot": 10, "sx": 0.84, "sy": 1.1},
	  N={"sx": 0.7, "rot": 16}, AUR=80, AUL=70, BF={"rot": 14}, **LEGS_DZ)
	P("b_bonk_back", base="b_bonk_door", root={"rot": 0, "sx": 1.0, "sy": 1.0}, face="dazed", tags=["state", "bonk"],
	  sil="knocked back off the door, arms flung behind", **LEGS_DZ)
	P("b_reel_a", base="b_dazed", face="dazed", root={"rot": 0}, tags=["state", "bonk", "reel"],
	  sil="reeling, head lolling left, arms dangling", T=-12, H=-16, AUR=20, AUL=-20, **LEGS_DZ)
	P("b_reel_b", base="b_dazed", face="dazed", root={"rot": 0}, tags=["state", "bonk", "reel"],
	  sil="reeling, head lolling right", T=14, H=20, AUR=-16, AUL=26, **LEGS_DZ)
	P("b_reel_c", base="b_dazed", face="dazed", root={"rot": 0}, tags=["state", "bonk", "reel"],
	  sil="shaking it off", T=4, H=10, **LEGS_DZ)
	P("b_turn_hmph", base="b_idle_lapel", root={"sx": 0.95, "sy": 1.05}, face="irked", tags=["loco", "turn", "hmph"],
	  sil="HMPH: squashed tall mid-turn, chin jutting up", T=-8, H=-18, BF={"rot": -6}, BL={"sy": 1.04})
	IK["b_turn_hmph"] = [("r", ("part", "torso", (40.0, -118.0)), -176, "fist")]

	# ---- micro-gag overlay poses (only the `upper` mask -- head, arms, hands, cravat, face -- is used in game)
	P("b_mg_horn_lean", base="b_warm_rest", face="admiring", tags=["micro_gag", "warmup", "horn"],
	  sil="head dipped into the gramophone horn, admiring himself", H=24, BF=6)
	P("b_mg_horn_lean_b", base="b_mg_horn_lean", tags=["micro_gag", "warmup", "horn"],
	  sil="a vain little head waggle at his reflection", H=28, BF=10)
	P("b_mg_kiss", base="b_warm_rest", face="kiss", tags=["micro_gag", "warmup", "kiss"],
	  sil="fingertips to his puckered lips", H=8)
	IK["b_mg_kiss"] = [("r", ("part", "head", (48.0, -10.0)), -150, "conduct")]
	P("b_mg_kiss_throw", base="b_warm_rest", face="admiring", tags=["micro_gag", "warmup", "kiss"],
	  sil="the kiss flung out to the horn, arm high, fingers spread", H=-4,
	  AUR=-128, ALR=-12, HR={"rot": -30, "tex": "open"})
	P("b_mg_trill", base="b_warm_rest", face="trill", tags=["micro_gag", "warmup", "trill"],
	  sil="chin up, lips trilling brrrr", H=-16, N={"sx": 1.04})
	P("b_mg_trill_b", base="b_mg_trill", tags=["micro_gag", "warmup", "trill"], sil="the trill vibrating his head",
	  H=-19, N={"sx": 1.08, "rot": -3}, BF=-3)
	P("b_mg_throat_tap", base="b_warm_rest", face="admiring", tags=["micro_gag", "warmup", "trill"],
	  sil="delighted, tapping his throat with a fingertip", H=-10)
	IK["b_mg_throat_tap"] = [("r", ("part", "torso", (40.0, -126.0)), -168, "point")]
	P("b_mg_conduct_up", base="b_warm_rest", face="sing_small", tags=["micro_gag", "warmup", "conduct"],
	  sil="pinkie raised like a baton", H=-10, AUR=-150, ALR=-40, HR={"rot": -20, "tex": "conduct"})
	P("b_mg_conduct_down", base="b_mg_conduct_up", tags=["micro_gag", "warmup", "conduct"],
	  sil="the downbeat of the pinkie baton", H=-4, AUR=-86, ALR=-24, HR={"rot": 10, "tex": "conduct"})
	P("b_mg_conduct_flourish", base="b_mg_conduct_up", face="smug", tags=["micro_gag", "warmup", "conduct"],
	  sil="the final flourish, pinkie high", H=-14, AUR=-172, ALR=-8, HR={"rot": -40, "tex": "conduct"})
	P("b_mg_bow_head", base="b_warm_rest", face="pompous", tags=["micro_gag", "warmup", "bow"],
	  sil="bowing his head to his invisible orchestra, hand swept to his belly", H=32, BF=10,
	  AUR=-40, ALR=-96, HR={"rot": -30, "tex": "open"})
	P("b_mg_sway_a", base="b_warm_rest", face="hum", tags=["micro_gag", "warmup", "hum"],
	  sil="eyes shut, head swaying left, a finger keeping time", H=-12, BF=-6, AUR=-34, ALR=-100, HR={"rot": -30, "tex": "point"})
	P("b_mg_sway_b", base="b_mg_sway_a", tags=["micro_gag", "warmup", "hum"], sil="...and right",
	  H=10, BF=6, AUR=-26, ALR=-110, HR={"rot": -10, "tex": "point"})
	P("b_mg_kettle_peek", base="b_stool_cup", plant=False, face="admiring", tags=["micro_gag", "tea", "kettle"],
	  sil="peering down at his face in the kettle", H=26, BF=8)
	P("b_mg_kettle_pat", base="b_stool_cup", plant=False, face="admiring", tags=["micro_gag", "tea", "kettle"],
	  sil="patting his bouffant with the cup hand, pinkie out", H=20, BF=-4)
	IK["b_mg_kettle_pat"] = [("r", ("part", "head", (-24.0, -84.0)), -150, "grip")]
	P("b_mg_kettle_pat_b", base="b_mg_kettle_pat", plant=False, tags=["micro_gag", "tea", "kettle"],
	  sil="pat", H=22, BF=2)
	IK["b_mg_kettle_pat_b"] = [("r", ("part", "head", (-20.0, -74.0)), -146, "grip")]
	P("b_mg_kettle_wink", base="b_stool_cup", plant=False, face="sly_smile", tags=["micro_gag", "tea", "kettle"],
	  sil="a sly little nod to his reflection", H=16, BF=4)
	P("b_mg_pinkie", base="b_stool_ahh", plant=False, face="sip", tags=["micro_gag", "tea", "pinkie"],
	  sil="the cup at his lips, the pinkie cocked sky-high", H=-16)
	IK["b_mg_pinkie"] = [("r", ("mouth_cup", 0.0), -128, "grip")]
	P("b_mg_pinkie_b", base="b_mg_pinkie", plant=False, tags=["micro_gag", "tea", "pinkie"],
	  sil="the pinkie wobbling", H=-17)
	IK["b_mg_pinkie_b"] = [("r", ("mouth_cup", 0.0), -112, "grip")]
	# ---- blind: the door-frame bonk's lean-in and recoil, the rub's second key
	P("b_blind_lean", base="b_blind_stand", face="huh", tags=["reaction", "blind", "bonk", "antic"],
	  sil="head poking forward into the door frame", H=16, AUR=-80, AUL=-74)
	P("b_blind_bonk_b", base="b_blind_bonk", face="dazed", tags=["reaction", "blind", "bonk"],
	  sil="rocking back from the bonk, arms coming down", H=-18, AUR=-120, AUL=-130)
	P("b_blind_rub_b", base="b_blind_rub", tags=["reaction", "blind", "rub"], sil="rubbing the bump", H=14)
	IK["b_blind_rub_b"] = [("r", ("part", "head", (34.0, -90.0)), -140, "open")]

	mirror = {}
	# the strut: a pompous scurry -- knee lift, chin up, chest out, arms swinging stiffly, belly bouncing
	def strut_arms(f):
		s = math.cos(2 * math.pi * f / 32.0)
		return {"AUR": round(28 * s, 1), "ALR": round(-24 + 10 * s, 1), "HR": {"rot": -6, "tex": "open"},
				"AUL": round(-26 * s, 1), "ALL": round(-22 - 10 * s, 1), "HL": {"tex": "open"}}

	def strut_extra(f):
		c2 = math.cos(4 * math.pi * f / 32.0)
		return {"H": round(-10 - 3 * c2, 1), "BL": {"sy": round(1.0 - 0.035 * c2, 3)}, "CT": round(10 + 8 * c2, 1),
				"CR": round(4 * c2, 1)}
	_n, m = walk_cycle(P, "b_strut_", "b_stand", cycle=32, stance=16, lift=18.0, stride=128.0, knee_pct=0.985, toe=6.0,
					   lean=lambda f: -7.0 - 2.0 * math.cos(4 * math.pi * f / 32.0), arm_fn=strut_arms, face="pompous",
					   tags=["loco", "strut"], sil="pompous scurry: chin up, chest out, a knee hoisted high every step",
					   extra=strut_extra)
	mirror.update(m)

	# the blind shuffle: arms stiff out in front, groping; short quick steps, feet barely lifting
	def blind_arms(f):
		s = math.sin(2 * math.pi * f / 24.0)
		return {"AUR": round(-88 + 6 * s, 1), "ALR": round(-6 - 4 * s, 1), "HR": {"rot": round(-12 + 10 * s, 1), "tex": "open"},
				"AUL": round(-80 - 6 * s, 1), "ALL": round(-6 + 4 * s, 1), "HL": {"rot": round(-8 - 10 * s, 1), "tex": "open"}}

	def blind_extra(f):
		c2 = math.cos(4 * math.pi * f / 24.0)
		s1 = math.sin(2 * math.pi * f / 24.0)
		return {"H": round(4 + 5 * s1, 1), "BL": {"sy": round(1.0 - 0.02 * c2, 3)}, "CT": round(-6 + 4 * c2, 1),
				"N": {"rot": round(-4 * s1, 1)}}
	_n, m = walk_cycle(P, "b_shuffle_", "b_blind_arms_out", cycle=24, stance=14, lift=6.0, stride=96.0,
					   knee_pct=0.985, lean=lambda f: 6.0 + 1.5 * math.cos(4 * math.pi * f / 24.0), arm_fn=blind_arms,
					   face="huh", tags=["loco", "blind", "shuffle"], toe=0.0,
					   sil="blind shuffle: zombie arms out, head poking forward, little sliding steps",
					   extra=blind_extra)
	mirror.update(m)
	return mirror


def _rot(v, deg):
	r = math.radians(deg)
	c, s = math.cos(r), math.sin(r)
	return (c * v[0] - s * v[1], s * v[0] + c * v[1])


def _inv(m):
	a, b, c, d, e, f = m
	det = a * d - b * c
	ia, ib, ic, id_ = d / det, -b / det, -c / det, a / det
	return (ia, ib, ic, id_, -(ia * e + ic * f), -(ib * e + id_ * f))


def _resolve(rig, poses_out, name):
	rig.poses_src = {"poses": poses_out, "mirror_of": rig.poses_src.get("mirror_of", {})}
	rig._resolved = {}
	return rig.raw_pose(name)


def seat(rig, poses_out, torso_sil):
	"""SEAT_AT: move the root so the barrel's lowest silhouette point sits on the target (see module doc)."""
	import fk
	for name, (tx, ty) in SEAT_AT.items():
		for _ in range(3):
			pose = _resolve(rig, poses_out, name)
			_M0, W = rig.solve(pose)
			low = None
			for p in torso_sil:
				q = fk.apply(W["torso"], p)
				if low is None or q[1] > low[1] + 1e-6:
					low = q
			r = poses_out[name].setdefault("root", {})
			r["x"] = round(pose["root"].get("x", 0) + tx - low[0], 1)
			r["y"] = round(pose["root"].get("y", 0) + ty - low[1], 1)
	return poses_out


def ik(rig, poses_out, grip, limits):
	"""IK: solve every arm target (see module doc). Returns warnings for joints the runtime would clamp."""
	import fk
	warn = []
	for name, specs in IK.items():
		for side, target, hand_deg, tex in specs:
			pose = _resolve(rig, poses_out, name)
			_M0, W = rig.solve(pose)
			if isinstance(target, tuple) and isinstance(target[0], str):
				kind = target[0]
				if kind in ("mouth_cup", "nose_cup", "mouth_cup_off"):
					anchor = MOUTH if kind != "nose_cup" else NOSE_UNDER
					base = fk.apply(W[anchor[0]], anchor[1])
					if kind == "mouth_cup_off":
						off = target[2]
						base = (base[0] + off[0], base[1] + off[1])
					rim = _rot(CUP_BACK_RIM, hand_deg + 90.0)   # the cup's world angle = the hand's + 90
					tw = (base[0] - rim[0], base[1] - rim[1])
				elif kind == "part":
					tw = fk.apply(W[target[1]], target[2])
				else:
					raise ValueError(target)
			else:
				tw = target
			Wt = W["torso"]
			tl = fk.apply(_inv(Wt), tw)
			tor = math.degrees(math.atan2(Wt[1], Wt[0]))
			hl = hand_deg - tor
			g = grip[tex]
			gw = _rot(g, hl)
			wrist = (tl[0] - gw[0], tl[1] - gw[1])
			au, al, hd = "arm_upper_" + side, "arm_lower_" + side, "hand_" + side
			sh = rig.parts[au]["offset"]
			l1 = rig.parts[al]["offset"][1]
			l2 = rig.parts[hd]["offset"][1]
			dx, dy = wrist[0] - sh[0], wrist[1] - sh[1]
			d = math.hypot(dx, dy)
			dmax = (l1 + l2) * 0.999
			if d > dmax:
				warn.append("%s: %s arm target out of reach by %.0f px" % (name, side, d - dmax))
				d = dmax
			d = max(d, abs(l1 - l2) + 1.0)
			phi = math.degrees(math.atan2(dy, dx))
			alpha = math.degrees(math.acos(max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)))))
			beta = math.degrees(math.acos(max(-1.0, min(1.0, (l1 * l1 + l2 * l2 - d * d) / (2 * l1 * l2)))))
			ru = phi - 90.0 + alpha
			b = -(180.0 - beta)
			rl = ru + b
			c = (hl - rl + 180.0) % 360.0 - 180.0
			a = (ru + 180.0) % 360.0 - 180.0
			if a < limits[au][0]:
				a += 360.0
			bones = poses_out[name].setdefault("bones", {})
			bones.setdefault(au, {})["rot"] = round(a, 1)
			bones.setdefault(al, {})["rot"] = round(b, 1)
			hb = bones.setdefault(hd, {})
			hb["rot"] = round(c, 1)
			hb["tex"] = tex
			for part, v in ((au, a), (al, b), (hd, c)):
				lo, hi = limits[part]
				if v < lo - 0.05 or v > hi + 0.05:
					warn.append("%s: %s rot %.1f outside [%s, %s]" % (name, part, v, lo, hi))
	return warn


# ============================================================================ walk cycles
# The strut: 32 f per cycle, 16 f per step (lead ruling L3: his feet plant at the map speed with 48 px legs),
# 64 px per step, stride 128 px per loop at 240 px/s. The blind shuffle: 24 f per cycle, 12 f per step, 48 px per
# step (short, quick shuffling steps at the same speed). Keys every 2 f; the first half of each cycle is authored,
# the second half is its mirror (`<prefix>m<k>` = mirror_of `<prefix><k>`: the far leg's turn).
HIP_Y = -65.0                 # torso joint above the feet origin at rest
HIP_X = 4.0                   # both hips at torso (4, 0)
SOLE_D = 18.0                 # ankle height above the sole line the anim lint measures (foot canvas bottom)
LEG = 24.0                    # thigh = shin


SOLE_PTS = [(-14.6, 18.0), (16.5, 18.0), (47.7, 18.0)]   # the lint's sole points (foot canvas bottom, ankle-relative)


def _sole_depth(r):
	"""How far below the ankle the lowest sole point sits with the foot turned r degrees (toe down = +)."""
	c, s_ = math.cos(math.radians(r)), math.sin(math.radians(r))
	return max(s_ * x + c * y for x, y in SOLE_PTS)


def _foot_track(f, cycle, stance, lift, x_contact, v, toe=22.0):
	"""Ankle (x, y) and foot world rot of a foot whose flat contact starts at f = 0 of its own phase. Stance: flat on
	the floor sliding back at `v` px/f (planted in the world); swing: toe down, lifted `lift` px clear of the floor
	(the ankle rises so the turned sole never dips below it), swung forward to the next contact."""
	f = f % cycle
	if f <= stance:
		return (x_contact - v * f, -SOLE_D, 0.0)
	t = (f - stance) / float(cycle - stance)
	x0 = x_contact - v * stance
	e = t * t * (3 - 2 * t)
	x = x0 + (x_contact - x0) * e
	r = toe * math.sin(math.pi * t) ** 2
	y = -_sole_depth(r) - max(4.0, lift * math.sin(math.pi * t))
	return (x, y, r)


def _leg_ik(hip, ankle):
	"""Absolute thigh angle (from vertical; - = forward) and knee bend (+ = the shin folds back), root frame."""
	dx, dy = ankle[0] - hip[0], ankle[1] - hip[1]
	d = min(math.hypot(dx, dy), 2 * LEG * 0.9995)
	phi = math.degrees(math.atan2(dy, dx))
	alpha = math.degrees(math.acos(max(-1.0, min(1.0, d / (2 * LEG)))))
	thigh = (phi - 90.0) - alpha      # the knee points forward of the hip->ankle line
	knee = 2 * alpha
	return thigh, knee


def walk_cycle(P, prefix, base, *, cycle, stance, lift, stride, knee_pct, lean, arm_fn, face, tags, sil,
			   extra=None, bob_extra=None, toe=22.0):
	"""Author `prefix`0..(half - 1) at f = 0, 1, .. (near foot contact at f0; one pose per frame). The hip height follows the stance
	foot (the leg straightens to `knee_pct` of its length over the planted foot: highest at mid-stance, lowest at
	contact), plus `bob_extra(f)`. Returns (names, mirror_of dict)."""
	half = cycle // 2
	v = stride / cycle
	x_contact = HIP_X + v * stance / 2.0
	names = []
	mirror = {}
	for k in range(half):
		f = k
		an = _foot_track(f, cycle, stance, lift, x_contact, v, toe)
		bn = _foot_track(f + half, cycle, stance, lift, x_contact, v, toe)
		reach = 2 * LEG * knee_pct
		hy = -1e9
		for ph, ft in ((f, an), (f + half, bn)):
			if (ph % cycle) <= stance:      # every foot on the floor constrains the hip (double support: both)
				dx = ft[0] - HIP_X
				hy = max(hy, -(math.sqrt(max(1.0, reach * reach - dx * dx)) + SOLE_D) - HIP_Y)
		if bob_extra:
			hy += bob_extra(f)
		lr = lean(f)
		hip = (HIP_X * math.cos(math.radians(lr)), HIP_Y + hy + HIP_X * math.sin(math.radians(lr)))
		an_r = (an[0], an[1])
		bn_r = (bn[0], bn[1])
		tr, kr = _leg_ik(hip, an_r)
		tl, kl = _leg_ik(hip, bn_r)
		clamp = lambda v_: max(-59.5, min(69.5, v_))
		bones = {"LUR": round(tr, 1), "LLR": round(kr, 1), "FR": {"rot": round(clamp(an[2] - (tr + kr)), 1), "tex": "flat"},
				 "LUL": round(tl, 1), "LLL": round(kl, 1), "FL": {"rot": round(clamp(bn[2] - (tl + kl)), 1), "tex": "flat"},
				 "T": round(lr, 1)}
		bones.update(arm_fn(f))
		if extra:
			bones.update(extra(f))
		name = "%s%d" % (prefix, k)
		P(name, base=base, root={"x": 0, "y": round(hy, 2), "rot": 0, "sx": 1, "sy": 1}, face=face, plant=False,
		  tags=list(tags) + (["contact"] if k == 0 else ["pass"] if k == half // 2 else []),
		  sil=sil if k == 0 else None, **bones)
		names.append(name)
		mirror["%sm%d" % (prefix, k)] = name
	WALKS[prefix] = {"cycle": cycle, "stride_px": stride, "keys": names}
	return names, mirror
