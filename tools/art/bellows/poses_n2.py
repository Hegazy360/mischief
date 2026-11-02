"""Wave-0 poses for Night 2 (docs/LEVELS.md §5): COLD OPEN (the fridge avalanche), EYE-POPPING NEWS (blind bumble
from the recliner), SOMETHING FISHY (the kipper phone), TIME'S UP (clinging to the pogoing clock), MIRROR, MIRROR
(the signature and its three stand-in rounds), the fire / snack / mirror / phone / clock activities and their
micro-gags and squeak bits. Same shorthand as poses_spec.P(); seated poses go through poses_s2's helpers."""
import poses_s2
import poses_w0

RECLINER_SEAT = poses_w0.RECLINER_SEAT


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

	# ======================================================================== the fridge (snack, COLD OPEN)
	P("b_fridge_open", base="b_stand", face="pompous", tags=["activity", "snack", "open"],
	  sil="one arm out to a fridge door handle, leaning in to peer", T=10, H=4,
	  AUR=-76, ALR=-16, HR={"rot": -20, "tex": "grip"}, AUL=-10, ALL=-10)
	P("b_fridge_reach_b", base="b_fridge_reach", tags=["activity", "snack", "rummage"],
	  sil="bent double, rummaging deeper, the far arm in too", T=40, H=-22,
	  AUR=-70, ALR=-20, AUL=-56, ALL=-16, HL={"tex": "open"})
	P("b_fridge_trifle", base="b_stand", face="admiring", tags=["activity", "snack", "trifle"],
	  sil="holding something up to eye level in both hands, head tipped back to admire it", T=-6, H=-16,
	  AUR=-110, ALR=-70, HR={"rot": 10, "tex": "grip"}, AUL=-100, ALL=-80, HL={"rot": -10, "tex": "grip"})
	P("b_fridge_peer_up", base="b_stand", face="huh", tags=["reaction", "avalanche", "antic"],
	  sil="straightened up, a hand shading his eyes, peering up into the top shelf", T=-8, H=-30,
	  AUR=-124, ALR=-126, HR={"rot": -40, "tex": "open"}, AUL=-20, ALL=-10)
	P("b_helmet_stand", base="b_stand", root={"sx": 1.02, "sy": 0.98}, face="dazed_open", tags=["reaction", "avalanche", "hold"],
	  sil="standing stiff under a jelly, arms held out from his sides, not daring to move", T=2, H=6,
	  AUR=-50, ALR=-10, HR={"rot": -30, "tex": "open"}, AUL=-46, ALL=-8, HL={"rot": 30, "tex": "open"})
	P("b_helmet_stand_b", base="b_helmet_stand", root={"sx": 0.99, "sy": 1.015}, tags=["reaction", "avalanche", "hold", "wobble"],
	  sil="the jelly wobbles: a tiny sway, eyes rolled up at it", T=-2, H=-4, AUR=-56, AUL=-40)

	# ======================================================================== the recliner (EYE-POPPING NEWS)
	S("b_rec_lean_in", base="b_rec_sit", root={"rot": 0}, face="suspicious", tags=["reaction", "blind_bumble", "antic"],
	  sil="leaning right into the paper, nose almost on it, elbows tucked", T=14, H=12,
	  AUR=-50, ALR=-76, HR={"rot": 30, "tex": "grip"}, AUL=-52, ALL=-60, HL={"rot": 14, "tex": "grip"})
	S("b_rec_eyes_pop", base="b_rec_sit", root={"rot": 0, "sx": 0.96, "sy": 1.05}, face="magnified",
	  tags=["reaction", "blind_bumble", "accent"],
	  sil="snapped back in the chair, eyes ballooned, arms flung wide, the paper gone", T=-26, H=-22,
	  AUR=-124, ALR=-14, HR={"rot": -20, "tex": "open"}, AUL=-116, ALL=-18, HL={"rot": 20, "tex": "open"})

	# ======================================================================== the phone table (SOMETHING FISHY, phone)
	P("b_phone_pompous_b", base="b_phone_pompous", tags=["activity", "phone", "gesture"],
	  sil="handset at his cheek, the far hand waving a point in the air", T=-4, H=-14,
	  AUL=-80, ALL=-70, HL={"rot": -20, "tex": "point"})
	P("b_phone_laugh", base="b_phone_pompous", root={"sx": 0.98, "sy": 1.03}, face="sly_smile", tags=["activity", "phone", "laugh"],
	  sil="head thrown back laughing, the receiver held out at arm's length", T=-14, H=-30,
	  AUR=-96, ALR=-4, HR={"rot": 20, "tex": "grip"}, AUL=30, ALL=-70)
	P("b_phone_argue", base="b_phone_pompous", face="furious", tags=["bit", "phone", "argue"],
	  sil="hunched into the receiver, the far fist shaking", T=8, H=6,
	  AUR=-30, ALR=-140, HR={"rot": 20, "tex": "grip"}, AUL=-100, ALL=-110, HL={"rot": 10, "tex": "fist"})
	P("b_phone_argue_b", base="b_phone_argue", root={"sx": 1.02, "sy": 0.98}, tags=["bit", "phone", "argue"],
	  sil="the fist punched forward on the word", T=12, H=10, AUL=-70, ALL=-40, HL={"rot": 0, "tex": "fist"})
	P("b_phone_cord", base="b_phone_pompous", face="smug", tags=["activity", "phone", "cord"],
	  sil="the far hand up at chest height, twirling the cord round a finger", T=-4, H=-8,
	  AUL=-60, ALL=-100, HL={"rot": -30, "tex": "point"})
	P("b_fish_look", base="b_stand", face="huh", tags=["reaction", "fish_slap", "antic"],
	  sil="the kipper held out at arm's length, head cocked at it", T=6, H=12,
	  AUR=-88, ALR=-12, HR={"rot": 10, "tex": "grip"}, AUL=30, ALL=-60, HL={"tex": "fist"})
	P("b_fish_recoil", base="b_stand", root={"sx": 0.97, "sy": 1.03}, face="shock", tags=["reaction", "fish_slap", "accent"],
	  sil="SLAP: head snapped back and sideways, the kipper arm pulled in, the far arm flung up",
	  T=-14, H=-32, N={"sx": 0.9, "rot": 10}, BF={"rot": -16},
	  AUR=-60, ALR=-44, HR={"rot": 30, "tex": "grip"}, AUL=-150, ALL=-20, HL={"tex": "open"},
	  SR={"tex": "puffed"}, SL={"tex": "puffed"})
	P("b_fish_burn", base="b_slow_burn", tags=["reaction", "fish_slap", "hold"],
	  sil="the slow burn to the Stalls, a kipper dangling from one hand", T=0, H=2,
	  AUR=-30, ALR=-10, HR={"rot": 20, "tex": "grip"}, AUL=-4)
	P("b_fish_burn_b", base="b_fish_burn", tags=["reaction", "fish_slap", "hold"],
	  sil="the burn: a slow glance down at the fish, then back out front", T=2, H=14, AUR=-36)

	# ======================================================================== the clock (TIME'S UP, clock)
	P("b_clock_wind_b", base="b_clock_wind", tags=["activity", "clock", "wind"],
	  sil="the key turned the other way", T=-2, H=-10, AUR=-104, ALR=-6, HR={"rot": -30, "tex": "grip"})
	P("b_clock_listen", base="b_stand", face="suspicious", tags=["activity", "clock", "listen"],
	  sil="ear to the clock, a hand cupped behind it", T=10, H=24,
	  AUR=-120, ALR=-130, HR={"rot": -20, "tex": "open"}, AUL=20, ALL=-20)
	P("b_watch_out", base="b_stand", face="pompous", tags=["mg", "clock", "watch"],
	  sil="a pocket watch drawn out on its chain and held up to his nose", T=0, H=10,
	  AUL=-40, ALL=-124, HL={"rot": 10, "tex": "grip"}, AUR=-20, ALR=-10)
	P("b_watch_shake", base="b_watch_out", face="irked", tags=["mg", "clock", "watch"],
	  sil="shaking the watch at his ear", T=-2, H=-6, AUL=-100, ALL=-130, HL={"rot": 30, "tex": "grip"})
	P("b_clock_recoil", base="b_stand", root={"sx": 0.96, "sy": 1.04}, face="shock", tags=["reaction", "jackhammer", "antic"],
	  sil="recoiling from the chimes going off in his face: leaning back, arms up", T=-20, H=-22,
	  AUR=-150, ALR=-30, HR={"rot": -10, "tex": "open"}, AUL=-140, ALL=-24, HL={"tex": "open"})
	P("b_cling_b", base="b_cling", root={"y": -24}, face="terrified", tags=["reaction", "jackhammer", "cling"],
	  sil="clinging on, cheek squashed against the clock, slippers kicked out behind", T=12, H=20,
	  AUR=-110, ALR=-30, AUL=-100, ALL=-36, LUR=-40, LLR=60, FR=30, LUL=-30, LLL=50, FL=30)
	P("b_clock_land", base="b_stand", face="dazed_open", tags=["reaction", "jackhammer", "land"],
	  sil="bent forward, both hands on the clock case, bum out, catching his breath", T=30, H=-18,
	  AUR=-90, ALR=-20, HR={"rot": -10, "tex": "open"}, AUL=-84, ALL=-24, HL={"tex": "open"}, CT=-20)
	P("b_bum_smack", base="b_clock_land", root={"sx": 0.96, "sy": 1.06}, face="shock", tags=["reaction", "jackhammer", "smack"],
	  sil="SMACK: jolted upright off the clock, bum tucked, hands flying up", T=-6, H=-16,
	  AUR=-140, ALR=-30, AUL=-130, ALL=-26, CT=40, BF={"rot": -12})

	# ======================================================================== the hall mirror (mirror, MIRROR, MIRROR)
	P("b_preen_b", base="b_preen", tags=["activity", "mirror", "preen"],
	  sil="stroking the other mutton chop, chin higher", T=-8, H=-14,
	  AUR=20, ALR=-20, HR={"rot": 0, "tex": "open"}, AUL=-10, ALL=-150, HL={"rot": 12, "tex": "open"})
	P("b_comb_a", base="b_preen", tags=["bit", "mirror", "comb"],
	  sil="combing the bouffant up with a flourish", T=-6, H=-8,
	  AUR=-150, ALR=-110, HR={"rot": -30, "tex": "grip"})
	P("b_comb_b", base="b_comb_a", tags=["bit", "mirror", "comb"],
	  sil="the comb drawn back through the bouffant", T=-6, H=-12, AUR=-170, ALR=-80, HR={"rot": -10, "tex": "grip"})
	P("b_polish_mirror", base="b_stand", face="irked", tags=["mg", "mirror", "polish"],
	  sil="one sleeve up rubbing at the glass in front of his face", T=8, H=2,
	  AUR=-120, ALR=-70, HR={"rot": -20, "tex": "fist"}, AUL=20, ALL=-20)
	P("b_polish_mirror_b", base="b_polish_mirror", tags=["mg", "mirror", "polish"],
	  sil="the rub, other way", T=6, H=6, AUR=-100, ALR=-90, HR={"rot": 10, "tex": "fist"})
	P("b_squint_in", base="b_lean_in", face="suspicious", tags=["reaction", "mirror_mirror", "round2"],
	  sil="leaning right in, squinting, a hand cupped over his brow", T=24, H=10,
	  AUR=-130, ALR=-120, HR={"rot": -40, "tex": "open"})
	P("b_wink_see", base="b_preen", face="sly_smile", tags=["reaction", "mirror_mirror", "wink"],
	  sil="head tipped, admiring the 'reflection' that just winked at him", T=-4, H=-6, N={"sx": 1.02})
	P("b_horror", base="b_stand", root={"sx": 0.97, "sy": 1.03}, face="terrified", tags=["reaction", "mirror_mirror", "horror"],
	  sil="leaning back from the glass, both hands up to his cheeks", T=-14, H=-12,
	  AUR=-100, ALR=-124, HR={"rot": -20, "tex": "open"}, AUL=-90, ALL=-128, HL={"rot": 20, "tex": "open"})
	P("b_scream_inhale", base="b_breath_in", face="inhale", tags=["reaction", "mirror_mirror", "antic"],
	  sil="the huge inhale before the scream: bent back, chest ballooned, arms spread high", T=-18, H=-20,
	  AUR=-150, ALR=-30, HR={"rot": -20, "tex": "open"}, AUL=-140, ALL=-26, HL={"tex": "open"}, BL={"sy": 1.08})
	P("b_scream_fly", base="b_fly_back", root={"x": -20, "y": -40, "rot": -20}, face="wild_take", plant=False,
	  tags=["reaction", "mirror_mirror", "accent", "flight"],
	  sil="SCREAM: blown backwards off his feet, arms clawing forward, mouth a cavern", T=6, H=10,
	  AUR=-60, ALR=-10, HR={"tex": "open"}, AUL=-50, ALL=-14, HL={"tex": "open"}, N={"sx": 1.08})
	P("b_revolve_a", base="b_cling", root={"y": -70}, plant=False, tags=["reaction", "mirror_mirror", "revolve"],
	  sil="wrapped round the coat stand like a revolving door, legs trailing out straight", T=4, H=-10,
	  AUR=-100, ALR=-50, AUL=-96, ALL=-46, LUR=-96, LLR=6, FR=20, LUL=-88, LLL=10, FL=20, CT=70)
	P("b_revolve_b", base="b_revolve_a", root={"y": -70, "sx": 0.4}, plant=False, tags=["reaction", "mirror_mirror", "revolve"],
	  sil="the revolving door seen edge-on", T=0, H=-6, LUR=-92, LUL=-92, CT=80)
	P("b_revolve_c", base="b_revolve_a", root={"y": -70, "sx": 0.75}, plant=False, tags=["reaction", "mirror_mirror", "revolve"],
	  sil="three-quarter, slowing, hair streaming", T=6, H=-14, BF={"rot": -20}, LUR=-100, LUL=-84)

	# ======================================================================== the fire (fire activity)
	P("b_bellows_pump_b", base="b_bellows_pump", root={"sx": 1.0, "sy": 1.0}, tags=["activity", "fire", "pump"],
	  sil="the bellows opened wide, elbows out", T=20, H=-8,
	  AUR=-70, ALR=-10, HR={"rot": 10, "tex": "fist"}, AUL=0, ALL=-20, HL={"tex": "fist"})
	P("b_warm_hands", base="b_stand", face="blissful", tags=["activity", "fire", "warm"],
	  sil="both palms held out flat to the fire, chin up, eyes shut", T=4, H=-8,
	  AUR=-70, ALR=-30, HR={"rot": -60, "tex": "open"}, AUL=-64, ALL=-34, HL={"rot": 60, "tex": "open"})
	P("b_warm_bum", base="b_stand", face="blissful", tags=["mg", "fire", "warm"],
	  sil="hands clasped behind his back, bum pushed back toward the fire, eyes rolled up", T=-10, H=-16,
	  AUR=50, ALR=-60, HR={"rot": 20, "tex": "open"}, AUL=46, ALL=-56, HL={"tex": "open"}, CT=-30)
