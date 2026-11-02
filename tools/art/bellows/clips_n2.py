"""Wave-0 Bellows clips for Night 2 (docs/LEVELS.md §5), authored through clips_spec.py's helpers and written by
its main() — the same conventions as clips_w0.py (pinned stances, hover landings, beats from reactions.json):

  reactions   rx_avalanche_helmet_a (COLD OPEN), rx_blind_bumble_a (EYE-POPPING NEWS), rx_fish_slap_a (SOMETHING
              FISHY), rx_jackhammer_cling_a (TIME'S UP), sig_mirror_mirror + sig_mirror_mirror_r1 / r2 / r3
  activities  act_fire, act_snack, act_mirror, act_clock (300 f loops), act_phone (480 f loop)
  micro-gags  mg_warm_hands, mg_lick_lips, mg_kiss_reflection, mg_pompous_laugh, mg_twirl_cord, mg_check_pocket_watch
  squeak bits bit_mirror (72 f), bit_phone (110 f)
"""
import json
import sys

_main = sys.modules.get("__main__")
C = _main if (_main is not None and hasattr(_main, "CLIPS") and hasattr(_main, "RIG")) else __import__("clips_spec")
K, E, clip = C.K, C.E, C.clip
import clips_w0 as W  # noqa: E402  (stance / pin / hover / root_of / beats_of / accent_events)

stance, pin, hover, root_of, beats_of, accent_events = W.stance, W.pin, W.hover, W.root_of, W.beats_of, W.accent_events


def _rx(name):
	return json.load(open(C.REACTIONS))["archetypes"][name]


# ============================================================================ COLD OPEN — rx_avalanche_helmet_a (125 f)
def avalanche():
	"""At the fridge facing +1: rummaging bent double (0-30), straightens and shades his eyes to peer up at the top
	shelf -- hm? (30-46, the anticipation), AVALANCHE (46-49: he ducks, the load lands), then stands rigid under a
	jelly-mould helmet with a sausage boa, the jelly wobbling (49-105), and a wobble-settle (105-125). The sim adds
	STICKY + COSTUME(jelly_helmet) from f49."""
	rx = _rx("avalanche_helmet_a")
	st = stance("b_stand")
	keys = [
		K(0, "b_fridge_reach", "linear", face="huh"),
		K(10, "b_fridge_reach_b", "in_out_sine"),
		K(22, "b_fridge_reach", "in_out_sine"),
		K(30, "b_fridge_reach", "in_out_sine", set_={"head": {"rot": -24}}),
		K(40, "b_fridge_peer_up", "in_out_sine", face="huh", set_={"root": root_of("b_fridge_peer_up", sy=1.04)}),
		K(45, "b_fridge_peer_up", "in_out_sine", set_={"root": root_of("b_fridge_peer_up", sy=1.05), "head": {"rot": -34}, "nose": {"sx": 1.06}}),
		K(46, "b_duck_cover", "pop", face="terrified", set_={"root": root_of("b_duck_cover", sx=1.0, sy=0.84)}),
		K(49, "b_duck_cover", "linear", set_={"root": root_of("b_duck_cover", sx=1.0, sy=0.8)}),
		K(59, "b_helmet_stand", "in_out_sine", face="dazed_open"),
		K(72, "b_helmet_stand_b", "in_out_sine"),
		K(88, "b_helmet_stand", "in_out_sine"),
		K(105, "b_helmet_stand_b", "in_out_sine", face="dazed"),
		K(118, "b_helmet_stand", "in_out_sine", face="pompous", set_={"head": {"rot": -8}}),
		K(125, "b_helmet_stand", "in_out_sine"),
	]
	pin(keys, st)
	events = [
		E(0, "sfx", id="cupboard_door", vol_db=-6.0),
		E(10, "sfx", id="rustle", vol_db=-6.0),
		E(30, "voice", id="vo_bellows_huh", vol_db=-3.0),
		E(46, "sfx", id="fridge_avalanche"),
		E(46, "spring", part="bouffant", kick=-30.0),
		E(47, "smear", part="head", frames=2, stretch=1.3),
		E(49, "sfx", id="jelly_splat"),
		E(49, "prop", op="attach", prop="jelly_helmet", socket="head:hat"),
		E(49, "prop", op="attach", prop="sausage_boa", socket="torso:neck"),
		E(49, "spring", part="belly", kick=0.08),
		E(59, "voice", id="vo_bellows_oof"),
		E(72, "sfx", id="boing_small", vol_db=-8.0, sync=False),
		E(105, "sfx", id="boing_small", vol_db=-10.0, sync=False),
		E(124, "prop", op="hide", prop="jelly_helmet"),
		E(124, "prop", op="hide", prop="sausage_boa"),
		E(125, "mark", name="release"),
	] + accent_events(rx, 46, trauma=0.45)
	return clip("rx_avalanche_helmet_a", rx["frames"], keys, events, beats=beats_of(rx),
				tags=["reaction", "take", "avalanche_helmet"], blend_in=0, blend_out=10, smear=True, plant=True, doc=avalanche.__doc__)


# ============================================================================ EYE-POPPING NEWS — rx_blind_bumble_a (133 f)
def blind_bumble():
	"""In the recliner, specs on behind a magnifier: reads (0-30), leans right into the paper, squinting (30-46,
	the anticipation), his eyes BALLOON (46-49: snapped back in the chair, arms wide, paper gone), he gets up and
	bumbles blind, arms out (49-109), and bows to nothing in particular (109-133). The sim adds BLINDED 15 s."""
	rx = _rx("blind_bumble_a")
	blind = stance("b_blind_stand")
	keys = [
		K(0, "b_rec_sit", "linear", face="pompous"),
		K(14, "b_rec_sit", "in_out_sine", set_={"head": {"rot": 6}}),
		K(30, "b_rec_lean_in", "in_out_sine", face="suspicious"),
		K(40, "b_rec_lean_in", "in_out_sine", set_={"head": {"rot": 16}, "nose": {"sx": 1.06}}),
		K(45, "b_rec_lean_in", "in_out_sine", set_={"head": {"rot": 18}, "nose": {"sx": 1.08}}),
		K(46, "b_rec_eyes_pop", "pop", face="magnified"),
		K(49, "b_rec_eyes_pop", "linear", set_={"root": root_of("b_rec_eyes_pop", sx=1.0, sy=1.0)}),
		K(56, "b_blind_stand", "in_out_sine", face="magnified"),
		K(60, "b_blind_stand", "in_quad"),
		K(68, "b_blind_arms_out", "in_out_sine", face="huh"),
		K(78, "b_blind_lean", "in_out_sine"),
		K(88, "b_blind_arms_out", "in_out_sine", set_={"head": {"rot": -16}}),
		K(98, "b_blind_lean", "in_out_sine", set_={"head": {"rot": 20}}),
		K(109, "b_bow", "in_out_sine", face="smug"),
		K(120, "b_bow", "in_out_sine", set_={"head": {"rot": 24}}),
		K(133, "b_blind_stand", "in_out_sine", face="dazed"),
	]
	for k in keys:
		if k["f"] >= 56:
			pin([k], blind)
			if k["f"] == 56:
				hover(k, -12.0)
	events = [
		E(0, "prop", op="attach", prop="newspaper", socket="hand_r:grip"),
		E(0, "prop", op="state", prop="newspaper", state="open"),
		E(14, "sfx", id="paper_rustle", vol_db=-6.0),
		E(40, "voice", id="vo_bellows_huh", vol_db=-4.0),
		E(46, "sfx", id="eye_boing"),
		E(46, "prop", op="hide", prop="newspaper"),
		E(46, "spring", part="bouffant", kick=30.0),
		E(47, "smear", part="head", frames=2, stretch=1.4),
		E(60, "voice", id="vo_bellows_huh"),
		E(78, "sfx", id="slipper_scuff", vol_db=-6.0),
		E(98, "sfx", id="slipper_scuff", vol_db=-6.0),
		E(109, "sfx", id="bow_creak"),
		E(109, "voice", id="vo_bellows_pardon", vol_db=-2.0),
		E(133, "mark", name="release"),
	] + accent_events(rx, 46, trauma=0.3)
	return clip("rx_blind_bumble_a", rx["frames"], keys, events, beats=beats_of(rx),
				tags=["reaction", "take", "blind_bumble", "recliner"], blend_in=0, blend_out=10, smear=True, doc=blind_bumble.__doc__)


# ============================================================================ SOMETHING FISHY — rx_fish_slap_a (149 f)
def fish_slap():
	"""At the phone table: he answers pompously, speaking into a kipper (0-40), it flops -- hm? He holds it out at
	arm's length and peers at it (40-56, the anticipation), SLAP (56-59), he recovers, SLAP again (72), then the
	long slow burn out to the Stalls, kipper dangling (84-129), and he puts the 'receiver' down with dignity
	(129-149)."""
	rx = _rx("fish_slap_a")
	st = stance("b_phone_pompous")
	keys = [
		K(0, "b_phone_pompous", "linear", face="pompous"),
		K(14, "b_phone_pompous_b", "in_out_sine"),
		K(28, "b_phone_pompous", "in_out_sine", set_={"head": {"rot": -14}}),
		K(40, "b_fish_look", "in_out_sine", face="huh"),
		K(48, "b_fish_look", "in_out_sine", set_={"head": {"rot": 16}}),
		K(54, "b_fish_look", "in_out_sine", set_={"head": {"rot": 20}, "nose": {"sx": 1.04}}),
		K(56, "b_fish_recoil", "pop", face="shock"),
		K(59, "b_fish_recoil", "linear", set_={"root": root_of("b_fish_recoil", sx=1.0, sy=1.0)}),
		K(66, "b_fish_look", "in_out_sine", face="huh", set_={"head": {"rot": 8}}),
		K(72, "b_fish_recoil", "pop", face="shock", set_={"head": {"rot": -34}}),
		K(75, "b_fish_recoil", "linear", set_={"root": root_of("b_fish_recoil", sx=1.0, sy=1.0)}),
		K(84, "b_fish_burn", "out_quad", face="slow_burn"),
		K(100, "b_fish_burn_b", "in_out_sine"),
		K(116, "b_fish_burn", "in_out_sine"),
		K(129, "b_fish_burn", "in_out_sine", set_={"head": {"rot": 6}, "torso": {"rot": 2}}),
		K(138, "b_phone_pompous", "in_out_sine", face="irked"),
		K(149, "b_stand", "in_out_sine", face="irked"),
	]
	pin(keys, st)
	events = [
		E(0, "prop", op="attach", prop="kipper_held", socket="hand_r:grip"),
		E(0, "voice", id="vo_bellows_ahem", vol_db=-3.0),
		E(14, "voice", id="vo_bellows_smug", vol_db=-4.0),
		E(40, "sfx", id="fish_flop"),
		E(48, "voice", id="vo_bellows_huh", vol_db=-3.0),
		E(56, "sfx", id="fish_slap"),
		E(56, "spring", part="bouffant", kick=-30.0),
		E(57, "smear", part="head", frames=2, stretch=1.4),
		E(66, "sfx", id="fish_flop", vol_db=-4.0),
		E(72, "sfx", id="fish_slap"),
		E(72, "spring", part="bouffant", kick=-30.0),
		E(73, "smear", part="head", frames=2, stretch=1.4),
		E(75, "voice", id="vo_bellows_wha", vol_db=-4.0),
		E(138, "sfx", id="phone", vol_db=-6.0),
		E(138, "voice", id="vo_bellows_grr", vol_db=-3.0),
		E(148, "prop", op="hide", prop="kipper_held"),
		E(149, "mark", name="release"),
	] + accent_events(rx, 56, trauma=0.35)
	return clip("rx_fish_slap_a", rx["frames"], keys, events, beats=beats_of(rx),
				tags=["reaction", "take", "fish_slap"], blend_in=0, blend_out=10, smear=True, plant=True, doc=fish_slap.__doc__)


# ============================================================================ TIME'S UP — rx_jackhammer_cling_a (127 f)
def jackhammer():
	"""At the grandfather clock: the over-wound clock shudders under his key (0-16), the chimes go off in his face and
	he recoils, arms up (16-32, the anticipation), he GRABS ON (32-35: knees up, slippers off the floor) and the
	clock pogoes across the hall with him clinging, 'a-a-a-a' (35-101; the sim carries x 1200 -> 1150), it stops,
	he slides down bent double against the case (101-110), and the pendulum door SMACKS his bum (110-127)."""
	rx = _rx("jackhammer_cling_a")
	st = stance("b_clock_wind")
	keys = [
		K(0, "b_clock_wind", "linear", face="pompous"),
		K(3, "b_clock_wind", "linear", set_={"root": root_of("b_clock_wind", sx=1.02, sy=0.98)}),
		K(6, "b_clock_wind_b", "linear", face="huh", set_={"root": root_of("b_clock_wind_b", sx=0.98, sy=1.02)}),
		K(9, "b_clock_wind", "linear", set_={"root": root_of("b_clock_wind", sx=1.02, sy=0.98)}),
		K(16, "b_clock_recoil", "in_out_sine", face="shock"),
		K(24, "b_clock_recoil", "in_out_sine", set_={"head": {"rot": -26}}),
		K(30, "b_clock_recoil", "in_quad", set_={"root": root_of("b_clock_recoil", sx=0.98, sy=1.06)}),
		K(32, "b_cling", "pop", face="terrified"),
		K(35, "b_cling", "linear", set_={"root": root_of("b_cling", y=-30.0)}),
	]
	f = 35
	i = 0
	for lift in (-62, -60, -58, -56, -54):
		f += 6
		keys.append(K(f, "b_cling_b", "out_quad", set_={"root": root_of("b_cling_b", y=float(lift))}))
		f += 6
		keys.append(K(f, "b_cling", "in_quad", face="terrified" if i % 2 == 0 else "wheeze", set_={"root": root_of("b_cling", y=-26.0)}))
		i += 1
	keys += [
		K(101, "b_cling", "in_out_sine", face="dazed_open", set_={"root": root_of("b_cling", y=-24.0)}),
		K(104, "b_clock_land", "in_out_sine", face="dazed_open"),
		K(107, "b_clock_land", "in_quad"),
		K(110, "b_bum_smack", "pop", face="shock", set_={"root": root_of("b_bum_smack", sx=0.98, sy=1.06)}),
		K(113, "b_bum_smack", "linear", set_={"root": root_of("b_bum_smack", sx=1.0, sy=1.0)}),
		K(120, "b_dignity_straighten", "in_out_sine", face="irked"),
		K(127, "b_stand", "in_out_sine", face="irked"),
	]
	for k in keys:
		if k["f"] <= 30 or k["f"] >= 104:
			pin([k], st)
			if k["f"] == 104:
				hover(k, -10.0)
	bounce_f = [47, 59, 71, 83, 95]
	events = [
		E(0, "sfx", id="clock", vol_db=-4.0),
		E(3, "sfx", id="creak", vol_db=-8.0),
		E(9, "sfx", id="creak", vol_db=-6.0),
		E(16, "sfx", id="chimes", vol_db=-4.0),
		E(16, "spring", part="bouffant", kick=-24.0),
		E(16, "voice", id="vo_bellows_wha"),
		E(32, "sfx", id="boing_big"),
		E(33, "smear", part="torso", frames=2, stretch=1.4),
		E(35, "voice", id="vo_bellows_dizzy_babble"),
		E(101, "sfx", id="clock", vol_db=-8.0),
		E(107, "voice", id="vo_bellows_wheeze", vol_db=-3.0),
		E(110, "sfx", id="pendulum_smack"),
		E(110, "spring", part="bouffant", kick=36.0),
		E(111, "smear", part="torso", frames=2, stretch=1.3),
		E(113, "voice", id="vo_bellows_yow"),
		E(127, "mark", name="release"),
	] + accent_events(rx, 32, trauma=0.4, hold=60)
	for bf in bounce_f:
		events.append(E(bf, "sfx", id="boing_med", vol_db=-6.0))
		events.append(E(bf, "spring", part="bouffant", kick=20.0))
		events.append(E(bf, "shake", trauma=0.15))
	return clip("rx_jackhammer_cling_a", rx["frames"], keys, events, beats=beats_of(rx),
				tags=["reaction", "take", "jackhammer_cling"], blend_in=0, blend_out=10, smear=True, plant=True, doc=jackhammer.__doc__)


# ============================================================================ MIRROR, MIRROR — the signature and its rounds
def mirror_mirror():
	"""The signature (GDD §5.7 #15): his 'reflection' winks (0-12), dawning horror -- a lean in, a double take, hands
	to his cheeks (12-40), the huge trembling inhale (40-64, the anticipation), the SCREAM (64-67) blows him
	backwards off his feet into the coat stand (the sim carries x 952 -> 862 over 64-84; the clip the rise), which
	spins him like a revolving door, slowing (67-147; the view's paper-bordered freeze-frame sits at 75-123), and he
	staggers out and straightens his cravat (147-177). He fled: the sim clears FRAZZLED / FEATHERED / COSTUME."""
	rx = _rx("sig_mirror_mirror")
	st = stance("b_preen")
	reel = stance("b_reel_a")
	keys = [
		K(0, "b_preen", "linear", face="admiring"),
		K(6, "b_wink_see", "in_out_sine", face="sly_smile"),
		K(12, "b_wink_see", "in_out_sine", set_={"head": {"rot": -10}}),
		K(20, "b_lean_in", "in_out_sine", face="suspicious"),
		K(26, "b_lean_in", "in_out_sine", set_={"head": {"rot": 14}, "nose": {"sx": 1.06}}),
		K(28, "b_dt_back", "pop", face="shock", set_={"root": root_of("b_dt_back", dy=-14.0)}),
		K(33, "b_horror", "in_out_sine", face="terrified"),
		K(36, "b_horror", "in_quad"),
		K(40, "b_horror", "in_out_sine", set_={"head": {"rot": -16}}),
		K(48, "b_scream_inhale", "in_out_sine", face="inhale"),
		K(54, "b_scream_inhale", "linear", set_={"root": root_of("b_scream_inhale", sy=1.04)}),
		K(58, "b_scream_inhale", "linear", set_={"root": root_of("b_scream_inhale", sy=1.0), "head": {"rot": -24}}),
		K(62, "b_scream_inhale", "linear", set_={"root": root_of("b_scream_inhale", sy=1.05), "head": {"rot": -26}}),
		K(64, "b_scream_fly", "pop", face="wild_take"),
		K(67, "b_scream_fly", "linear", set_={"root": root_of("b_scream_fly", x=-30.0, y=-56.0, rot=-30)}),
		K(72, "b_revolve_a", "out_quad", face="terrified"),
	]
	f = 72
	i = 0
	for gap in (3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 5, 5, 6, 6, 7, 8):
		f += gap
		keys.append(K(f, "b_revolve_b" if i % 2 == 0 else "b_revolve_a", "linear", face="wild_take" if i == 0 else None))
		i += 1
	# f is now 168 > 147? -- the table above sums to 95: 72 + 95 = 167. Trim: the revolve ends at 147.
	keys = [k for k in keys if k["f"] <= 141]
	keys += [
		K(145, "b_revolve_c", "in_out_sine", face="dazed_open"),
		K(151, "b_reel_a", "in_out_sine", face="dazed"),
		K(154, "b_reel_a", "in_quad"),
		K(161, "b_reel_b", "in_out_sine"),
		K(168, "b_dignity_straighten", "in_out_sine", face="mortified"),
		K(177, "b_stand", "in_out_sine", face="irked"),
	]
	for k in keys:
		if k["f"] <= 62 and k["f"] != 28:
			pin([k], st)
			if k["f"] == 33:
				hover(k, -6.0)
		elif k["f"] >= 151:
			pin([k], reel)
			if k["f"] == 151:
				hover(k, -10.0)
	events = [
		E(6, "sfx", id="glint", sync=False),
		E(20, "voice", id="vo_bellows_huh", vol_db=-4.0),
		E(28, "sfx", id="boing_small", vol_db=-4.0),
		E(28, "voice", id="vo_bellows_wha", vol_db=-2.0),
		E(28, "spring", part="bouffant", kick=24.0),
		E(48, "sfx", id="slide_whistle_up", vol_db=-6.0),
		E(64, "voice", id="vo_bellows_yow"),
		E(64, "sfx", id="slide_up_flight", vol_db=-4.0),
		E(64, "spring", part="bouffant", kick=-40.0),
		E(65, "smear", part="head", frames=3, stretch=1.7),
		E(78, "sfx", id="coatstand_spin"),
		E(78, "shake", trauma=0.35),
		E(104, "sfx", id="coatstand_spin", vol_db=-4.0),
		E(136, "sfx", id="crash_tail", vol_db=-3.0),
		E(151, "sfx", id="land_soft", vol_db=-4.0),
		E(168, "sfx", id="cravat_tug", vol_db=-4.0),
		E(177, "mark", name="release"),
	] + accent_events(rx, 64, trauma=0.6, hold=60)
	d = clip("sig_mirror_mirror", rx["frames"], keys, events, beats=beats_of(rx),
			 tags=["reaction", "signature", "mirror_mirror"], blend_in=0, blend_out=10, smear=True, plant=True, doc=mirror_mirror.__doc__)
	d["freeze_frame"] = list(rx.get("freeze_frame", []))
	# the three stand-in rounds (reactions.json mirror_rounds: 72 / 72 / 60 f, sim-locked, no loop)
	rounds = json.load(open(C.REACTIONS))["mirror_rounds"]["rounds_f"]
	r1 = pin([
		K(0, "b_preen", "linear", face="admiring"),
		K(18, "b_preen_b", "in_out_sine"),
		K(36, "b_fidget_admire", "in_out_sine", face="smug"),
		K(54, "b_preen", "in_out_sine", face="admiring", set_={"head": {"rot": -14}}),
		K(rounds[0], "b_preen", "in_out_sine"),
	], st)
	clip("sig_mirror_mirror_r1", rounds[0], r1, [E(18, "sfx", id="glint", sync=False), E(36, "voice", id="vo_bellows_smug", vol_db=-4.0)],
		 tags=["mirror_mirror", "round"], blend_in=4, blend_out=4,
		 doc="MIRROR, MIRROR round 1 (72 f): he preens at his 'reflection' -- a mutton chop each side, a nail check.")
	r2 = pin([
		K(0, "b_preen", "linear", face="admiring"),
		K(14, "b_lean_in", "in_out_sine", face="suspicious"),
		K(30, "b_squint_in", "in_out_sine"),
		K(44, "b_squint_in", "in_out_sine", set_={"head": {"rot": 14}, "nose": {"sx": 1.06}}),
		K(58, "b_squint_in", "in_out_sine", set_={"head": {"rot": 6}}),
		K(rounds[1], "b_lean_in", "in_out_sine"),
	], st)
	clip("sig_mirror_mirror_r2", rounds[1], r2, [E(14, "voice", id="vo_bellows_huh", vol_db=-6.0), E(30, "sfx", id="creak", vol_db=-10.0)],
		 tags=["mirror_mirror", "round"], blend_in=4, blend_out=4,
		 doc="MIRROR, MIRROR round 2 (72 f): he leans right in and squints, a hand cupped over his brow.")
	r3 = pin([
		K(0, "b_lean_in", "linear", face="suspicious"),
		K(12, "b_dt_away", "in_out_sine", face="huh"),
		K(24, "b_specs_lift", "in_out_sine", face="suspicious"),
		K(40, "b_specs_lift", "in_out_sine", set_={"arm_lower_r": {"rot": -135}, "head": {"rot": 0}}),
		K(52, "b_specs_lift", "in_out_sine", set_={"arm_lower_r": {"rot": -145}, "head": {"rot": 2}}),
		K(rounds[2], "b_specs_lift", "linear", set_={"arm_lower_r": {"rot": -150}, "head": {"rot": 3}}),
	], st)
	clip("sig_mirror_mirror_r3", rounds[2], r3, [E(24, "sfx", id="specs_tink", vol_db=-6.0), E(40, "voice", id="vo_bellows_hmph", vol_db=-6.0)],
		 tags=["mirror_mirror", "round", "tell"], blend_in=4, blend_out=4,
		 doc="MIRROR, MIRROR round 3 (60 f, the tell): he lifts his specs slowly toward his nose; release FREEZE before "
			 "they land or the sim opens the 0.8 s poke window.")
	return d


# ============================================================================ activities
def fire():
	"""300 f loop at the hearth (facing -1): pumps the bellows at the fire, stands and warms his palms, eyes shut,
	pumps again. mg_warm_hands plays over it at 2 s."""
	keys = [
		K(0, "b_bellows_pump", "linear", face="irked"),
		K(20, "b_bellows_pump_b", "in_out_sine"),
		K(40, "b_bellows_pump", "in_out_sine"),
		K(60, "b_bellows_pump_b", "in_out_sine"),
		K(80, "b_bellows_pump", "in_out_sine", face="smug"),
		K(110, "b_warm_hands", "in_out_sine", face="blissful"),
		K(150, "b_warm_hands", "in_out_sine", set_={"head": {"rot": -14}}),
		K(190, "b_warm_hands", "in_out_sine", set_={"torso": {"rot": 8}, "head": {"rot": -4}}),
		K(230, "b_bellows_pump", "in_out_sine", face="irked"),
		K(250, "b_bellows_pump_b", "in_out_sine"),
		K(270, "b_bellows_pump", "in_out_sine"),
		K(285, "b_bellows_pump", "in_out_sine", set_={"head": {"rot": -10}, "torso": {"rot": 20}}),
		K(300, "b_bellows_pump", "in_out_sine"),
	]
	pin(keys, stance("b_stand"))
	events = [E(20, "sfx", id="bellows_pump"), E(60, "sfx", id="bellows_pump", vol_db=-2.0), E(110, "sfx", id="fire_crackle", vol_db=-6.0, sync=False),
			  E(250, "sfx", id="bellows_pump", vol_db=-2.0)]
	return clip("act_fire", 300, keys, events, loop=True, blend_in=6, blend_out=6, tags=["activity", "fire"], doc=fire.__doc__)


def snack():
	"""300 f loop at the fridge (facing +1): opens the door, bends double to rummage, comes up with a trifle he holds
	to the light, puts it back, shuts the door. COLD OPEN fires at 1 s; mg_lick_lips at 2 s."""
	keys = [
		K(0, "b_stand", "linear", face="pompous"),
		K(24, "b_fridge_open", "in_out_sine"),
		K(50, "b_fridge_reach", "in_out_sine", face="huh"),
		K(80, "b_fridge_reach_b", "in_out_sine"),
		K(110, "b_fridge_reach", "in_out_sine"),
		K(140, "b_fridge_trifle", "in_out_sine", face="admiring"),
		K(180, "b_fridge_trifle", "in_out_sine", face="blissful", set_={"head": {"rot": -22}}),
		K(210, "b_fridge_reach", "in_out_sine", face="pompous"),
		K(240, "b_fridge_open", "in_out_sine"),
		K(270, "b_stand", "in_out_sine", face="smug"),
		K(285, "b_stand", "in_out_sine", set_={"head": {"rot": -10}, "torso": {"rot": -7}}),
		K(300, "b_stand", "in_out_sine", face="pompous"),
	]
	pin(keys, stance("b_stand"))
	events = [E(24, "sfx", id="cupboard_door", vol_db=-4.0), E(80, "sfx", id="rustle", vol_db=-6.0), E(140, "sfx", id="jelly", vol_db=-8.0),
			  E(240, "sfx", id="cupboard_door", vol_db=-6.0)]
	return clip("act_snack", 300, keys, events, loop=True, blend_in=6, blend_out=6, tags=["activity", "snack"], doc=snack.__doc__)


def mirror():
	"""300 f loop at the hall mirror (facing +1): preens a mutton chop each side, leans in, checks his nails, tugs the
	cravat straight. MIRROR, MIRROR starts from b_preen; mg_kiss_reflection at 2 s."""
	keys = [
		K(0, "b_preen", "linear", face="admiring"),
		K(30, "b_preen_b", "in_out_sine"),
		K(60, "b_lean_in", "in_out_sine", face="suspicious"),
		K(90, "b_lean_in", "in_out_sine", set_={"head": {"rot": 14}}),
		K(120, "b_fidget_admire", "in_out_sine", face="admiring"),
		K(160, "b_preen", "in_out_sine"),
		K(190, "b_dignity_straighten", "in_out_sine", face="pompous"),
		K(220, "b_preen_b", "in_out_sine", face="admiring"),
		K(260, "b_preen", "in_out_sine"),
		K(280, "b_preen", "in_out_sine", set_={"head": {"rot": -16}, "torso": {"rot": -9}}),
		K(300, "b_preen", "in_out_sine"),
	]
	pin(keys, stance("b_preen"))
	events = [E(30, "sfx", id="glint", sync=False), E(190, "sfx", id="cravat_tug", vol_db=-4.0)]
	return clip("act_mirror", 300, keys, events, loop=True, blend_in=6, blend_out=6, tags=["activity", "mirror"], doc=mirror.__doc__)


def phone():
	"""480 f loop at the phone table (facing +1), handset at his cheek: pompous talk, a gesture, the cord twirled, a
	hmph. SOMETHING FISHY starts from b_phone_pompous; mg_pompous_laugh at 2 s, mg_twirl_cord at 7 s."""
	keys = [
		K(0, "b_phone_pompous", "linear", face="pompous"),
		K(40, "b_phone_pompous_b", "in_out_sine"),
		K(80, "b_phone_pompous", "in_out_sine"),
		K(120, "b_phone_pompous", "in_out_sine", set_={"head": {"rot": -16}}, face="smug"),
		K(170, "b_phone_pompous_b", "in_out_sine", face="pompous"),
		K(220, "b_phone_cord", "in_out_sine", face="smug"),
		K(280, "b_phone_pompous", "in_out_sine"),
		K(330, "b_phone_pompous_b", "in_out_sine", face="irked"),
		K(380, "b_phone_pompous", "in_out_sine", face="pompous"),
		K(420, "b_phone_pompous", "in_out_sine", set_={"torso": {"rot": -9}, "head": {"rot": -12}}),
		K(480, "b_phone_pompous", "in_out_sine"),
	]
	pin(keys, stance("b_phone_pompous"))
	events = [
		E(0, "prop", op="attach", prop="phone_handset", socket="hand_r:grip"),
		E(40, "voice", id="vo_bellows_hmph", vol_db=-6.0), E(170, "voice", id="vo_bellows_smug", vol_db=-6.0),
		E(330, "voice", id="vo_bellows_tut", vol_db=-6.0),
	]
	return clip("act_phone", 480, keys, events, loop=True, blend_in=6, blend_out=6, tags=["activity", "phone"], doc=phone.__doc__)


def clock():
	"""300 f loop at the grandfather clock (facing +1): winds it with the key, an ear to the case, winds again, a
	smug step back. TIME'S UP starts from b_clock_wind; mg_check_pocket_watch at 2 s."""
	keys = [
		K(0, "b_clock_wind", "linear", face="pompous"),
		K(20, "b_clock_wind_b", "in_out_sine"),
		K(40, "b_clock_wind", "in_out_sine"),
		K(60, "b_clock_wind_b", "in_out_sine"),
		K(80, "b_clock_wind", "in_out_sine"),
		K(110, "b_clock_listen", "in_out_sine", face="suspicious"),
		K(150, "b_clock_listen", "in_out_sine", set_={"head": {"rot": 28}}),
		K(180, "b_clock_wind", "in_out_sine", face="pompous"),
		K(200, "b_clock_wind_b", "in_out_sine"),
		K(220, "b_clock_wind", "in_out_sine"),
		K(250, "b_dt_away", "in_out_sine", face="smug"),
		K(300, "b_clock_wind", "in_out_sine", face="pompous"),
	]
	pin(keys, stance("b_clock_wind"))
	events = [E(20, "sfx", id="clock", vol_db=-8.0), E(60, "sfx", id="clock", vol_db=-8.0), E(200, "sfx", id="clock", vol_db=-8.0)]
	return clip("act_clock", 300, keys, events, loop=True, blend_in=6, blend_out=6, tags=["activity", "clock"], doc=clock.__doc__)


# ============================================================================ micro-gags (overlays, mask `upper`)
def micro_gags():
	st_stand = stance("b_stand")
	C.mg("warm_hands", 48, pin([
		K(0, "b_warm_hands", "linear", face="blissful"),
		K(12, "b_warm_hands", "in_out_sine", set_={"head": {"rot": -14}}),
		K(24, "b_warm_bum", "out_back", face="blissful"),
		K(36, "b_warm_bum", "in_out_sine", set_={"head": {"rot": -22}}),
		K(48, "b_warm_hands", "in_out_sine"),
	], st_stand), [E(24, "sfx", id="fire_crackle", vol_db=-6.0), E(36, "voice", id="vo_bellows_bliss", vol_db=-4.0)],
		doc="Warms his hands, then turns and warms his bottom, eyes rolling in bliss.")
	C.mg("lick_lips", 48, pin([
		K(0, "b_fridge_trifle", "linear", face="admiring"),
		K(12, "b_fridge_trifle", "in_out_sine", face="blissful", set_={"head": {"rot": -20}}),
		K(24, "b_fridge_trifle", "in_out_sine", face="kiss", set_={"head": {"rot": -14}}),
		K(30, "b_fridge_trifle", "in_out_sine", face="blissful", set_={"nose": {"sx": 1.04}}),
		K(40, "b_fridge_trifle", "in_out_sine", set_={"head": {"rot": -18}}),
		K(48, "b_fridge_trifle", "in_out_sine", face="admiring"),
	], st_stand), [E(24, "sfx", id="kiss_smack", vol_db=-6.0), E(30, "fx", id="drops", part="nose", dir=[0.3, 1.0], amount=2), E(40, "sfx", id="gulp", vol_db=-4.0)],
		doc="Holds a wobbling trifle up to the fridge light and licks his lips; a drool drop falls.")
	st_lean = stance("b_lean_in")
	C.mg("kiss_reflection", 48, pin([
		K(0, "b_lean_in", "linear", face="admiring"),
		K(10, "b_lean_in", "in_out_sine", face="kiss", set_={"head": {"rot": 14}}),
		K(16, "b_lean_in", "in_out_sine", face="kiss", set_={"head": {"rot": 16}, "nose": {"sx": 1.04}}),
		K(26, "b_polish_mirror", "in_out_sine", face="irked"),
		K(32, "b_polish_mirror_b", "in_out_sine"),
		K(38, "b_polish_mirror", "in_out_sine"),
		K(43, "b_polish_mirror_b", "in_out_sine"),
		K(48, "b_lean_in", "in_out_sine", face="smug"),
	], st_lean), [E(16, "sfx", id="kiss_smack"), E(26, "sfx", id="rustle", vol_db=-6.0), E(38, "sfx", id="rustle", vol_db=-8.0)],
		doc="Kisses his reflection, then jealously polishes the lip mark off with his sleeve.")
	st_phone = stance("b_phone_pompous")
	C.mg("pompous_laugh", 60, pin([
		K(0, "b_phone_pompous", "linear", face="pompous"),
		K(12, "b_phone_laugh", "in_out_sine", face="sly_smile"),
		K(20, "b_phone_laugh", "in_out_sine", set_={"head": {"rot": -33}}),
		K(30, "b_phone_laugh", "in_out_sine", set_={"head": {"rot": -24}}),
		K(40, "b_phone_laugh", "in_out_sine", set_={"head": {"rot": -33}}),
		K(50, "b_phone_pompous", "in_out_sine", face="smug"),
		K(60, "b_phone_pompous", "in_out_sine", face="pompous"),
	], st_phone), [E(12, "voice", id="vo_bellows_hah"), E(20, "voice", id="vo_bellows_hah", vol_db=-2.0), E(40, "voice", id="vo_bellows_hah", vol_db=-1.0)],
		doc="Throws his head back at his agent's joke: 'HA-ha-HAAA!' - the receiver at arm's length.")
	C.mg("twirl_cord", 48, pin([
		K(0, "b_phone_pompous", "linear", face="pompous"),
		K(8, "b_phone_cord", "in_out_sine", face="smug"),
		K(16, "b_phone_cord", "in_out_sine", set_={"hand_l": {"rot": 30}}),
		K(24, "b_phone_cord", "in_out_sine", set_={"hand_l": {"rot": -40}, "arm_lower_l": {"rot": -110}}),
		K(32, "b_phone_cord", "in_out_sine", set_={"hand_l": {"rot": 20}}),
		K(40, "b_phone_cord", "in_out_sine", face="irked", set_={"arm_lower_l": {"rot": -120}, "hand_l": {"rot": -10}}),
		K(48, "b_phone_pompous", "in_out_sine", face="irked"),
	], st_phone), [E(40, "voice", id="vo_bellows_hmph", vol_db=-4.0)],
		doc="Twirls the phone cord round his finger and gets it knotted round his wrist.")
	st_clock = stance("b_clock_wind")
	C.mg("check_pocket_watch", 48, pin([
		K(0, "b_clock_wind", "linear", face="pompous"),
		K(10, "b_watch_out", "in_out_sine", face="pompous"),
		K(20, "b_watch_out", "in_out_sine", face="disdain", set_={"head": {"rot": 14}}),
		K(28, "b_watch_shake", "out_quad", face="irked"),
		K(34, "b_watch_shake", "in_out_sine", set_={"arm_lower_l": {"rot": -120}}),
		K(40, "b_watch_shake", "in_out_sine", set_={"arm_lower_l": {"rot": -135}}),
		K(48, "b_clock_wind", "in_out_sine", face="pompous"),
	], st_clock), [E(10, "sfx", id="specs_tink", vol_db=-8.0), E(20, "voice", id="vo_bellows_tut", vol_db=-3.0), E(34, "sfx", id="clack", vol_db=-6.0)],
		doc="Checks his pocket watch against the clock, tuts, and shakes the watch.")


# ============================================================================ squeak bits
def bits():
	bits_db = json.load(open(C.os.path.join(C.REPO, "game", "data", "activities.json")))["squeak_bits"]
	n = bits_db["bit_mirror"]["len_f"]
	st = stance("b_preen")
	keys = [
		K(0, "b_comb_a", "linear", face="admiring"),
		K(8, "b_comb_b", "in_out_sine"),
		K(12, "b_comb_a", "in_out_sine"),
		K(18, "b_take_antic", "linear", face="shock", set_={"root": root_of("b_take_antic", sx=1.0)}),
		K(22, "b_take_accent", "pop", face="wild_take", set_={"root": root_of("b_take_accent", dy=-30.0)}),
		K(28, "b_take_accent", "linear", set_={"root": root_of("b_take_accent", dy=-10.0)}),
		K(34, "b_look_behind", "in_out_sine", face="suspicious"),
		K(37, "b_look_behind", "in_quad"),
		K(44, "b_look_behind", "in_out_sine", set_={"head": {"rot": 8}}),
		K(52, "b_preen", "in_out_sine", face="irked"),
		K(62, "b_preen", "in_out_sine", face="smug", set_={"head": {"rot": -8}}),
		K(n, "b_preen", "in_out_sine", face="admiring"),
	]
	for k in keys:
		if k["f"] not in (22, 28):
			pin([k], st)
			if k["f"] == 34:
				hover(k, -8.0)
	clip("bit_mirror", n, keys, [
		E(0, "prop", op="attach", prop="comb", socket="hand_r:grip"),
		E(8, "sfx", id="rustle", vol_db=-8.0),
		E(22, "sfx", id="zip"), E(22, "prop", op="launch", prop="comb", vel=[-800.0, -1500.0], spin=1080.0),
		E(22, "spring", part="bouffant", kick=30.0), E(23, "smear", part="arm_upper_r", frames=2, stretch=1.4),
		E(28, "voice", id="vo_bellows_wha"),
		E(70, "prop", op="hide", prop="comb"),
	], tags=["bit", "mirror"], blend_in=4, blend_out=8, smear=True, plant=True,
		doc="Squeak bit (mirror): mid-comb the squeak startles him and the comb flies off over his shoulder (f22); "
			"he looks round, then preens as if nothing happened. 72 f = squeak_bits.bit_mirror.len_f.")
	n = bits_db["bit_phone"]["len_f"]
	keys = pin([
		K(0, "b_phone_pompous", "linear", face="pompous"),
		K(10, "b_phone_argue", "out_quad", face="furious"),
		K(16, "b_phone_argue_b", "in_out_sine"),
		K(22, "b_phone_argue", "in_out_sine"),
		K(28, "b_phone_argue_b", "in_out_sine"),
		K(36, "b_phone_argue", "in_out_sine"),
		K(48, "b_phone_argue", "in_out_sine", face="livid", set_={"head": {"rot": 10}}),
		K(54, "b_phone_argue_b", "in_out_sine"),
		K(62, "b_phone_argue", "in_out_sine"),
		K(80, "b_phone_pompous", "in_out_sine", face="irked", set_={"head": {"rot": -6}}),
		K(96, "b_phone_pompous_b", "in_out_sine", face="smug"),
		K(n, "b_phone_pompous", "in_out_sine", face="pompous"),
	], stance("b_phone_pompous"))
	clip("bit_phone", n, keys, [
		E(0, "prop", op="attach", prop="phone_handset", socket="hand_r:grip"),
		E(10, "voice", id="vo_bellows_did_not_squeak"),
		E(16, "spring", part="bouffant", kick=12.0),
		E(54, "voice", id="vo_bellows_grr"),
		E(80, "voice", id="vo_bellows_hmph", vol_db=-4.0),
	], tags=["bit", "phone"], blend_in=4, blend_out=8, plant=True,
		doc="Squeak bit (phone): he argues with the caller -- 'I did NOT squeak!' -- fist shaking, then recomposes. "
			"110 f = squeak_bits.bit_phone.len_f.")


MAP_KEYS = {
	"activity:fire": "bellows/act_fire", "activity:snack": "bellows/act_snack", "activity:mirror": "bellows/act_mirror",
	"activity:phone": "bellows/act_phone", "activity:clock": "bellows/act_clock",
	"mg:warm_hands": "bellows/mg_warm_hands", "mg:lick_lips": "bellows/mg_lick_lips", "mg:kiss_reflection": "bellows/mg_kiss_reflection",
	"mg:pompous_laugh": "bellows/mg_pompous_laugh", "mg:twirl_cord": "bellows/mg_twirl_cord",
	"mg:check_pocket_watch": "bellows/mg_check_pocket_watch",
	"bit:bit_mirror": "bellows/bit_mirror", "bit:bit_phone": "bellows/bit_phone",
}


def build():
	avalanche()
	blind_bumble()
	fish_slap()
	jackhammer()
	mirror_mirror()
	fire()
	snack()
	mirror()
	phone()
	clock()
	micro_gags()
	bits()
