"""Wave-0 closing clips for Bellows (docs/LEVELS.md §5) — everything `SliceClips.build()` still listed as missing
after the Night-1 and Night-2 sets: the 15 state clips, the Lecture ×3, the three Meltdowns and Exhausted, the four
T3 last beats, the three fix-up detours and the hunt, the seven remaining micro-gags, `bit_livid`, the two cold
opens, the curtain-call wander-on, the picture-bonk cue, EYE-POPPING NEWS' B variant, TAP DANCE's knock-on entry,
and the Irked / Steaming walks, the chase run and the door.

Lengths come from the manifest (the sim's one-shot clocks, `reactions.json clip_timings`, `activities.json`), so
the anim lint's A29 checks them exactly. Same conventions as clips_w0 / clips_n2 (pinned stances, hover landings).
"""
import json
import math
import sys

_main = sys.modules.get("__main__")
C = _main if (_main is not None and hasattr(_main, "CLIPS") and hasattr(_main, "RIG")) else __import__("clips_spec")
K, E, clip = C.K, C.E, C.clip
import clips_w0 as W  # noqa: E402

stance, pin, hover, root_of, beats_of, accent_events = W.stance, W.pin, W.hover, W.root_of, W.beats_of, W.accent_events


def _rx(name):
	return json.load(open(C.REACTIONS))["archetypes"][name]


def _ct(name):
	return json.load(open(C.REACTIONS))["clip_timings"]["bellows/" + name]


def breathe(keys, st, every=24, amp=0.012):
	"""A long hold is never a dead hold (lint A09): ride a slow belly / torso breath over the pinned stance."""
	for i, k in enumerate(keys):
		s = k.setdefault("set", {})
		ph = math.sin(2.0 * math.pi * float(k["f"]) / float(every * 2))
		s["belly"] = {"sy": round(1.0 + amp * ph, 3)}
		r = dict(s.get("root", st and {} or {}))
		if "root" in s:
			r = dict(s["root"])
			r["sy"] = round(float(r.get("sy", 1.0)) + 0.006 * ph, 3)
			s["root"] = r
	return keys


# ============================================================================ states
def states():
	stand = stance("b_stand")
	# -- st_suspicious (60 f): stops, squints, a slow head turn
	ct = _ct("st_suspicious")
	clip("st_suspicious", ct["frames"], pin([
		K(0, "b_stand", "linear", face="pompous"),
		K(10, "b_suspicious", "in_out_sine", face="suspicious"),
		K(16, "b_suspicious", "in_out_sine", set_={"head": {"rot": 2}, "nose": {"sx": 1.04}}),
		K(30, "b_suspicious", "in_out_sine", set_={"head": {"rot": -10}}),
		K(46, "b_look_behind", "in_out_sine"),
		K(60, "b_look_behind", "in_out_sine", set_={"head": {"rot": 4}}),
	], stand), [E(10, "sfx", id="step_soft", vol_db=-10.0), E(16, "voice", id="vo_bellows_huh", vol_db=-6.0)],
		tags=["state", "suspicious"], blend_in=6, blend_out=6, plant=True,
		doc="Curious stop (60 f): he stops mid-stride, squints, and turns his head slowly — 'hmm?'")
	# -- st_double_take (18 f): the '!' snap back
	ct = _ct("st_double_take")
	clip("st_double_take", ct["frames"], pin([
		K(0, "b_dt_away", "linear", face="smug"),
		K(6, "b_dt_away", "linear", set_={"head": {"rot": -16}}),
		K(8, "b_dt_back", "pop", face="shock", set_={"root": root_of("b_dt_back", dy=-4.0)}),
		K(12, "b_dt_back", "linear", set_={"root": root_of("b_dt_back", dy=-4.0), "belly": {"sy": 1.06}}),
		K(18, "b_dt_back", "out_quad", set_={"root": root_of("b_dt_back", dy=-4.0)}),
	], stand, flat=True, free=(8, 12, 18)), [
		E(8, "sfx", id="sting_spot"), E(8, "spring", part="bouffant", kick=36.0),
		E(9, "smear", part="head", frames=2, stretch=1.5), E(8, "shake", trauma=0.3),
	], tags=["state", "spotted", "take"], blend_in=0, blend_out=4, smear=True,
		doc="SPOTTED (18 f): he looks away, then snaps back on the '!' sting — the 0.3 s double take.")
	# -- st_look (180 f loop, max 180): looks left, looks right, shrugs
	ct = _ct("st_look")
	clip("st_look", ct["frames"], breathe(pin([
		K(0, "b_specs_lift", "linear", face="suspicious"),
		K(6, "b_specs_lift", "linear"),
		K(20, "b_hunt_peer_l", "in_out_sine"),
		K(40, "b_hunt_peer_l", "in_out_sine", set_={"head": {"rot": -14}}),
		K(60, "b_hunt_peer_r", "in_out_sine"),
		K(84, "b_hunt_peer_r", "in_out_sine", set_={"head": {"rot": 6}}),
		K(110, "b_hunt_peer_l", "in_out_sine", set_={"head": {"rot": -8}}),
		K(132, "b_suspicious", "in_out_sine", face="huh"),
		K(150, "b_cc_shrug", "in_out_sine", face="huh"),
		K(164, "b_cc_shrug", "in_out_sine", set_={"head": {"rot": 8}}),
		K(174, "b_specs_lift", "in_out_sine", face="suspicious"),
		K(180, "b_specs_lift", "linear", face="suspicious"),
	], stand), stand, every=18), [E(60, "sfx", id="step_soft", vol_db=-12.0), E(150, "voice", id="vo_bellows_hmph", vol_db=-6.0)],
		loop=True, tags=["state", "curious", "look"], blend_in=6, blend_out=6,
		doc="Curious / search look (180 f, loops): specs on, he looks left, looks right, and shrugs it off.")
	# -- st_chase (16 f loop, 160 px stride at 600 px/s)
	run = [K(f, ("b_run_%d" % f) if f < 6 else ("b_run_m%d" % (f - 6)), "linear", face="furious" if f == 0 else None)
		   for f in range(12)]
	run.append(K(12, "b_run_0", "linear"))
	run_ev = [E(0, "sfx", id="bellows_step"), E(6, "sfx", id="bellows_step", vol_db=-1.0)]
	# at 600 px/s the knees snap through more than a frame's worth of rotation: that IS the blur (lint A10)
	for f in range(12):
		run_ev.append(E(f, "smear", part="leg_lower_l", frames=1, stretch=1.25))
		run_ev.append(E(f, "smear", part="leg_lower_r", frames=1, stretch=1.25))
	clip("st_chase", 12, run, run_ev,
		 loop=True, blend_in=4, blend_out=4, stride=120.0, tags=["state", "chase", "loco", "run"],
		 doc="The chase run (12 f, 60 px per step, 120 px per cycle = 600 px/s with the feet planted): leaning right "
			 "forward, knees high, fists pumping, bouffant streaming, the legs smeared at speed.")
	# -- st_wheeze (90 f)
	ct = _ct("st_wheeze")
	clip("st_wheeze", ct["frames"], breathe(pin([
		K(0, "b_wheeze", "linear", face="wheeze"),
		K(14, "b_wheeze", "in_out_sine", set_={"torso": {"rot": 56}, "head": {"rot": -24}}),
		K(30, "b_wheeze", "in_out_sine", set_={"torso": {"rot": 48}, "head": {"rot": -14}}),
		K(46, "b_wheeze", "in_out_sine", set_={"torso": {"rot": 58}, "head": {"rot": -26}}),
		K(62, "b_wheeze", "in_out_sine", set_={"torso": {"rot": 50}, "head": {"rot": -16}}),
		K(78, "b_wheeze", "in_out_sine", set_={"torso": {"rot": 56}, "head": {"rot": -22}}),
		K(90, "b_wheeze", "in_out_sine"),
	], stance("b_wheeze")), stance("b_wheeze"), every=16, amp=0.05),
		[E(0, "voice", id="vo_bellows_wheeze"), E(46, "voice", id="vo_bellows_wheeze", vol_db=-3.0)],
		tags=["state", "wheeze"], blend_in=6, blend_out=6, plant=True,
		doc="Chase wheeze (90 f): bent double, hands on knees, hauling air. Harmless — he always recovers.")
	# -- st_grab (60 f)
	ct = _ct("st_grab")
	clip("st_grab", ct["frames"], pin([
		K(0, "b_chase_a", "linear", face="furious"),
		K(4, "b_take_antic", "in_quad", face="furious", set_={"root": root_of("b_take_antic", sx=1.06, sy=0.94)}),
		K(8, "b_grab", "pop", face="livid"),
		K(12, "b_grab", "linear", set_={"root": root_of("b_grab", sx=1.0, sy=1.0)}),
		K(30, "b_lecture_hold", "out_back", face="furious"),
		K(44, "b_lecture_hold", "in_out_sine", set_={"head": {"rot": -14}}),
		K(60, "b_lecture_hold", "in_out_sine"),
	], stance("b_grab"), flat=True, free=(8,)), [
		E(8, "sfx", id="grab" if False else "crash_small"), E(8, "shake", trauma=0.4),
		E(9, "smear", part="arm_upper_r", frames=2, stretch=1.5),
		E(30, "voice", id="vo_bellows_hah"),
	], tags=["state", "caught", "grab"], blend_in=0, blend_out=6, smear=True, plant=True,
		doc="Caught (60 f, the Busted Cam re-stage plays over it): he lunges, grabs her by the braces and holds her "
			"up at arm's length, delighted with himself.")
	# -- st_search (360 f loop)
	clip("st_search", 360, breathe(pin([
		K(0, "b_specs_lift", "linear", face="suspicious"),
		K(40, "b_hunt_peer_l", "in_out_sine"),
		K(80, "b_peer_under", "in_out_sine", face="suspicious"),
		K(110, "b_peer_under", "in_out_sine", set_={"head": {"rot": -30}}),
		K(140, "b_hunt_peer_r", "in_out_sine"),
		K(180, "b_hunt_peer_r", "in_out_sine", set_={"head": {"rot": 2}}),
		K(220, "b_suspicious", "in_out_sine", face="irked"),
		K(260, "b_hunt_peer_l", "in_out_sine", face="suspicious"),
		K(300, "b_specs_lift", "in_out_sine"),
		K(330, "b_cc_shrug", "in_out_sine", face="huh"),
		K(360, "b_specs_lift", "in_out_sine", face="suspicious"),
	], stand), stand, every=30), [
		E(80, "sfx", id="rustle", vol_db=-10.0), E(220, "voice", id="vo_bellows_grr", vol_db=-8.0),
		E(330, "voice", id="vo_bellows_hmph", vol_db=-6.0),
	], loop=True, tags=["state", "search"], blend_in=6, blend_out=6,
		doc="Search (360 f, loops): specs on, he quarters the room — a look each way, a peer under the furniture, a "
			"shrug — until the sim gives up for him.")
	# -- st_bump (82 f: pat 30, walk on 40, turn 12 — the sim's clock, not clip_timings' old 72)
	clip("st_bump", 82, pin([
		K(0, "b_stand", "linear", face="pompous"),
		K(4, "b_pardon_pat", "in_out_sine", face="pardon"),
		K(14, "b_pardon_pat", "in_out_sine", set_={"head": {"rot": 10}}),
		K(24, "b_pardon_pat", "in_out_sine", set_={"head": {"rot": 2}}),
		K(30, "b_stand", "in_out_sine", face="pompous"),
		K(44, "b_stand", "in_out_sine", set_={"head": {"rot": -10}, "torso": {"rot": -6}}),
		K(58, "b_stand", "in_out_sine", set_={"head": {"rot": -4}}),
		K(70, "b_dt_away", "in_out_sine", face="huh"),
		K(76, "b_dt_back", "pop", face="shock"),
		K(82, "b_dt_back", "out_quad"),
	], stand, flat=True), [
		E(4, "voice", id="vo_bellows_pardon"), E(4, "sfx", id="step_soft", vol_db=-10.0),
		E(44, "sfx", id="bellows_step", vol_db=-6.0), E(58, "sfx", id="bellows_step", vol_db=-6.0),
		E(76, "sfx", id="sting_spot", vol_db=-3.0), E(76, "spring", part="bouffant", kick=30.0),
	], tags=["state", "bump"], blend_in=6, blend_out=4, smear=True, plant=True,
		doc="The first bump (82 f): he walks into the statue, says 'Pardon', pats it, walks on two steps — and "
			"double-takes. (Pat 30 + walk-on 40 + turn 12 = the sim's bump clock.)")
	# -- st_look_back (60 f)
	ct = _ct("st_look_back")
	clip("st_look_back", ct["frames"], pin([
		K(0, "b_stand", "linear", face="irked"),
		K(12, "b_look_behind", "in_out_sine", face="suspicious"),
		K(30, "b_look_behind", "in_out_sine", set_={"head": {"rot": 2}, "nose": {"sx": 1.03}}),
		K(44, "b_look_behind", "in_out_sine", set_={"head": {"rot": -10}}),
		K(60, "b_stand", "in_out_sine", face="irked"),
	], stand), [E(12, "sfx", id="step_soft", vol_db=-12.0), E(44, "voice", id="vo_bellows_hmph", vol_db=-6.0)],
		tags=["state", "look_back"], blend_in=6, blend_out=6, plant=True,
		doc="Steaming+ doorway look-back (60 f): he pauses in the doorway and glances behind him before going on.")
	# -- st_head_turn (60 f, overlay on the head: '...the pipes?')
	ct = _ct("st_head_turn")
	clip("st_head_turn", ct["frames"], [
		K(0, "b_stand", "linear", face="pompous"),
		K(10, "b_stand", "out_quad", face="huh", set_={"head": {"rot": -18}, "nose": {"rot": -4}}),
		K(24, "b_stand", "in_out_sine", face="suspicious", set_={"head": {"rot": -22}}),
		K(40, "b_stand", "in_out_sine", face="huh", set_={"head": {"rot": -12}}),
		K(60, "b_stand", "in_out_sine", face="pompous", set_={"head": {"rot": 0}}),
	], [E(10, "voice", id="vo_bellows_the_pipes")],
		layer="overlay", mask="head", blend_in=6, blend_out=8, tags=["state", "overlay", "head_turn"],
		doc="He hears a squeak (60 f, head overlay): a slow turn of the head and a muttered '…the pipes?' — it plays "
			"over whatever he is doing.")
	# -- st_smirk (30 f, overlay: a fizzle)
	ct = _ct("st_smirk")
	clip("st_smirk", ct["frames"], [
		K(0, "b_stand", "linear", face="pompous"),
		K(8, "b_smirk", "out_quad", face="sly_smile"),
		K(18, "b_smirk_b", "in_out_sine"),
		K(30, "b_stand", "in_out_sine", face="pompous"),
	], [E(8, "voice", id="vo_bellows_hmph"), E(8, "sfx", id="sting_fizzle", vol_db=-4.0)],
		layer="overlay", mask="upper", blend_in=4, blend_out=6, tags=["state", "overlay", "fizzle"],
		doc="A fizzle (30 f, upper overlay): the trap was there but the condition was not — a smug shrug and a "
			"'hmph'. The prank stays rigged.")
	# -- st_specs_on (12 f, overlay)
	ct = _ct("st_specs_on")
	clip("st_specs_on", ct["frames"], [
		K(0, "b_stand", "linear", face="irked"),
		K(4, "b_specs_lift", "pop", face="suspicious"),
		K(6, "b_specs_lift", "linear", set_={"arm_lower_r": {"rot": -150}}),
		K(12, "b_stand", "in_out_sine", face="suspicious"),
	], [E(6, "sfx", id="specs_tink")],
		layer="overlay", mask="upper", blend_in=4, blend_out=4, tags=["state", "overlay", "specs"],
		doc="Specs on (12 f, upper overlay): he jams them onto his nose — tink! The view swaps the prop state.")
	# -- st_door_slam (36 f)
	ct = _ct("st_door_slam")
	clip("st_door_slam", ct["frames"], pin([
		K(0, "b_lecture_plonk", "linear", face="irked"),
		K(6, "b_lecture_plonk", "in_out_sine", set_={"torso": {"rot": 34}}),
		K(9, "b_door_reach", "in_out_sine", face="furious"),
		K(12, "b_door_slam", "pop", face="furious"),
		K(16, "b_door_slam", "linear", set_={"root": root_of("b_door_slam", sx=1.04, sy=0.96)}),
		K(26, "b_dignity_straighten", "in_out_sine", face="smug"),
		K(36, "b_stand", "in_out_sine", face="pompous"),
	], stand), [
		E(6, "sfx", id="land_soft", vol_db=-6.0),
		E(12, "sfx", id="door_slam"), E(12, "shake", trauma=0.45), E(12, "spring", part="bouffant", kick=24.0),
		E(26, "sfx", id="cravat_tug", vol_db=-6.0),
	], tags=["state", "caught", "doorstep"], blend_in=4, blend_out=6, plant=True,
		doc="The doorstep (36 f): he plonks her down outside, slams the front door, and straightens his cravat.")
	# -- st_straighten_cravat (30 f loop: the doorway pause)
	clip("st_straighten_cravat", 30, breathe(pin([
		K(0, "b_dignity_straighten", "linear", face="pompous"),
		K(10, "b_dignity_straighten", "in_out_sine", set_={"cravat": {"rot": 12}, "head": {"rot": -16}}),
		K(20, "b_dignity_straighten", "in_out_sine", set_={"cravat": {"rot": 2}, "head": {"rot": -10}}),
		K(30, "b_dignity_straighten", "in_out_sine"),
	], stand), stand, every=15, amp=0.02), [E(10, "sfx", id="cravat_tug", vol_db=-8.0)],
		loop=True, tags=["state", "doorway_pause"], blend_in=6, blend_out=6,
		doc="The doorway pause (30 f, loops): the no-ambush rule holds him at the door, so he fills the time "
			"straightening his cravat.")
	# -- st_face_to_face (48 f)
	clip("st_face_to_face", 48, pin([
		K(0, "b_fridge_open", "linear", face="pompous"),
		K(5, "b_fridge_open", "linear", set_={"head": {"rot": 8}}),
		K(8, "b_shriek", "pop", face="terrified"),
		K(12, "b_shriek", "linear", set_={"root": root_of("b_shriek", sx=0.94, sy=1.1)}),
		K(22, "b_shriek", "in_out_sine", set_={"root": root_of("b_shriek", sx=0.92, sy=1.12), "head": {"rot": -14}}),
		K(34, "b_duck_cover", "in_out_sine", face="terrified"),
		K(42, "b_duck_cover", "in_out_sine", face="shock", set_={"head": {"rot": -14}}),
		K(48, "b_duck_cover", "in_out_sine", face="huh", set_={"head": {"rot": 6}}),
	], stand, flat=True), [
		E(8, "voice", id="vo_bellows_yow"), E(8, "sfx", id="sting_alert"),
		E(8, "spring", part="bouffant", kick=44.0), E(9, "smear", part="head", frames=2, stretch=1.6),
		E(8, "shake", trauma=0.5), E(34, "sfx", id="cupboard_door", vol_db=-4.0),
	], tags=["state", "face_to_face", "take"], blend_in=4, blend_out=6, smear=True, plant=True,
		doc="Face to face (48 f): he opens the cupboard she is hiding in and they shriek at each other — he leaps "
			"back, ducks, and stares.")


# ============================================================================ the Lecture (3 × 132 f)
def lecture():
	st = stance("b_lecture_hold")

	def base(wags, shake_at=None, high_at=None):
		keys = [K(0, "b_stand", "linear", face="furious"),
				K(14, "b_lecture_hold", "out_quad", face="lecture")]
		for i, w in enumerate(wags):
			pose = "b_lecture_wag_a" if i % 2 == 0 else "b_lecture_wag_b"
			if high_at is not None and w == high_at:
				pose = "b_lecture_high"
			elif shake_at is not None and w == shake_at:
				pose = "b_lecture_shake"
			keys.append(K(w, pose, "out_quad", face="sing_big" if pose == "b_lecture_high" else "lecture"))
			keys.append(K(w + 8, "b_lecture_hold", "in_out_sine"))
		keys.append(K(122, "b_lecture_plonk", "in_out_sine", face="irked"))
		keys.append(K(132, "b_lecture_hold", "in_out_sine", face="furious"))
		return pin(keys, st)
	ct = _ct("lec_a")
	wags = ct["marks"]["wag"]
	clip("lec_a", ct["frames"], base(wags), [E(0, "voice", id="vo_bellows_lecture_a")]
		 + [E(w, "sfx", id="step_pizz", vol_db=-8.0) for w in wags] + [E(122, "sfx", id="land_soft", vol_db=-6.0)],
		 tags=["state", "lecture"], blend_in=4, blend_out=6, plant=True,
		 doc="The Lecture, variant A (132 f): a sung scolding with a finger wag on every beat, then he plonks her "
			 "down. Hush dangles from her braces throughout (hush/lec_dangled).")
	ct = _ct("lec_b")
	wags = ct["marks"]["wag"]
	clip("lec_b", ct["frames"], base(wags, shake_at=wags[-1]), [E(0, "voice", id="vo_bellows_lecture_b")]
		 + [E(w, "sfx", id="step_pizz", vol_db=-9.0) for w in wags]
		 + [E(wags[-1], "sfx", id="rustle", vol_db=-4.0), E(122, "sfx", id="land_soft", vol_db=-6.0)],
		 tags=["state", "lecture"], blend_in=4, blend_out=6, plant=True,
		 doc="The Lecture, variant B (132 f): faster patter scolding, six quick wags, and on the last beat he shakes "
			 "her like a rug.")
	ct = _ct("lec_c")
	wags = ct["marks"]["wag"]
	clip("lec_c", ct["frames"], base(wags, high_at=wags[-1]), [E(0, "voice", id="vo_bellows_lecture_c")]
		 + [E(w, "sfx", id="step_pizz", vol_db=-8.0) for w in wags] + [E(122, "sfx", id="land_soft", vol_db=-6.0)],
		 tags=["state", "lecture"], blend_in=4, blend_out=6, plant=True,
		 doc="The Lecture, variant C (132 f): slow operatic scolding — three huge wags and a held high note.")


# ============================================================================ Meltdowns (3 × 330 f) and Exhausted
def meltdowns():
	st = stance("b_stand")

	LEFT = ("leg_upper_l", "leg_lower_l", "foot_l")
	RIGHT = ("leg_upper_r", "leg_lower_r", "foot_r")

	def stomp_keys(stomps, hops=(), explode=None):
		"""Three stomps on the sim's marks, a roar between each, and he runs out of puff at the end. Keys stay ≥ 6 f
		apart (lint A10). He stomps with his near foot, so the far one is the support leg: it and the root are
		pinned through the whole clip and only the stomping leg is free to hoist and slam (lint A12). The hops leave
		the floor altogether, so those keys are not pinned at all."""
		ks = {0: ("b_melt_fists", "linear", "livid", None)}
		stomp_window = set()
		breath = set()
		for s_f in stomps:
			ks[s_f - 22] = ("b_melt_fists", "in_out_sine", "livid", None)
			ks[s_f - 10] = ("b_melt_stomp_up", "pop", "livid", None)
			ks[s_f - 6] = ("b_melt_stomp_up", "in_quad", None, root_of("b_melt_stomp_up", dy=-20.0))
			ks[s_f] = ("b_melt_stomp_down", "pop", "livid", None)
			ks[s_f + 6] = ("b_melt_stomp_down", "linear", None, None)
			ks[s_f + 16] = ("b_melt_fists", "out_back", "livid", None)
			stomp_window.update(range(s_f - 10, s_f + 17))
		# a roar in each gap, well clear of the stomps
		for a, b in ((16, stomps[0] - 22), (stomps[0] + 16, stomps[1] - 22), (stomps[1] + 16, stomps[2] - 22)):
			mid = (a + b) // 2
			if b - a >= 20:
				ks[mid - 10] = ("b_melt_roar", "in_out_sine", "livid", None)
				ks[mid + 10] = ("b_melt_fists", "in_out_sine", "livid", None)
		for h in hops:
			ks[h - 8] = ("b_melt_fists", "in_quad", "livid", None)
			ks[h] = ("b_melt_hop", "pop", "livid", root_of("b_melt_hop", sx=1.0))
			ks[h + 8] = ("b_melt_fists", "in_quad", "livid", None)
		if explode is not None:
			explode = min(ks, key=lambda f: abs(f - explode))   # ride a stomp key, never squeeze one in beside it
		ks[272] = ("b_melt_roar", "in_out_sine", "livid", None)
		ks[290] = ("b_melt_fists", "in_out_sine", "livid", None)
		ks[306] = ("b_melt_fists", "in_out_sine", "livid", None)
		ks[318] = ("b_wheeze", "in_out_sine", "wheeze", None)
		ks[330] = ("b_wheeze", "in_out_sine", None, None)
		# no gap longer than 24 f: a rage that stops dead is a dead hold (lint A09)
		fs = sorted(ks)
		for a2, b2 in zip(fs, fs[1:]):
			if b2 - a2 > 24 or (b2 - a2 >= 10 and ks[a2][0] == ks[b2][0]):
				ks[(a2 + b2) // 2] = (ks[a2][0], "in_out_sine", None, "BREATH")
		out = []
		for f in sorted(ks):
			pose, ease, face, root = ks[f]
			if root == "BREATH":
				root = None
				breath.add(f)
			st_d = {"root": root} if root else None
			if f in breath:
				st_d = {"head": {"rot": -8}, "belly": {"sy": 1.04}, "cravat": {"rot": 6}}
			if explode is not None and f >= explode:
				st_d = dict(st_d or {})
				st_d["bouffant"] = {"sx": 1.5, "sy": 1.5, "rot": -14} if f == explode else {"sx": 1.3, "sy": 1.35}
			if pose == "b_melt_stomp_down":
				st_d = dict(st_d or {})
				st_d["belly"] = {"sy": 0.9}       # the impact squash, off the root so the support foot stays put
			out.append(K(f, pose, ease, face=face, set_=st_d))
		# only the frames where the stomping foot is genuinely in the air keep their own right leg
		air = {k["f"] for k in out if k["pose"] == "b_melt_stomp_up"} | set(hops)
		pin(out, st, parts=LEFT, flat=True, free=tuple(hops))
		pin([k for k in out if k["f"] not in air], st, parts=RIGHT, root=False)
		return out

	for name, ct_name, kw, doc in (
		("melt_a", "melt_a", {}, "Meltdown A (330 f): the classic tantrum — three house-shaking stomps, a kettle "
							"whistle out of both ears, then he runs out of puff."),
		("melt_b", "melt_b", {"hops": (100, 200)}, "Meltdown B (330 f): hopping mad — he bounces on the spot between "
							"the stomps, sideburns boinging."),
		("melt_c", "melt_c", {"explode": 244}, "Meltdown C (330 f): the rage aria — he bellows at the ceiling and his "
							"bouffant explodes on the last stomp."),
	):
		ct = _ct(ct_name)
		stomps = ct["marks"]["stomps"]
		keys = stomp_keys(stomps, **kw)
		kf = {k["f"] for k in keys}
		ev = [E(0, "voice", id=ct.get("voice", "vo_bellows_grr"))]
		for s_f in stomps:
			ev += [E(s_f, "sfx", id="meltdown_stomp"), E(s_f, "shake", trauma=0.6), E(s_f, "hitstop", frames=4),
				   E(s_f, "spring", part="bouffant", kick=40.0), E(s_f + 1, "smear", part="torso", frames=2, stretch=1.3)]
		if ct_name == "melt_a":
			w = ct["marks"]["kettle_whistle"][0]
			near = min(kf, key=lambda f: abs(f - w))
			ev += [E(near, "sfx", id="kettle_squeak"),
				   E(near, "fx", id="steam", part="head", dir=[0.0, -1.0], amount=16)]
		if ct_name == "melt_b":
			for h in (100, 200):
				ev += [E(h, "sfx", id="boing_med", vol_db=-4.0), E(h, "spring", part="sideburn_r", kick=30.0)]
		if ct_name == "melt_c":
			boom = min(kf, key=lambda f: abs(f - 244))
			ev += [E(boom, "sfx", id="poof"), E(boom, "spring", part="bouffant", kick=60.0), E(boom, "shake", trauma=0.5)]
		ev.append(E(318, "voice", id="vo_bellows_wheeze", vol_db=-4.0))
		clip(name, ct["frames"], keys, ev, tags=["state", "meltdown"], blend_in=4, blend_out=8, smear=True, doc=doc)

	# -- Exhausted (480 f loop): sits, pants, stands
	ct = _ct("melt_exhausted")
	m = ct["marks"]
	keys = [K(0, "b_melt_fists", "linear", face="wheeze"),
			K(m["sit"][1], "b_exhausted_sit", "in_quad", face="wheeze")]
	f = m["pant_loop"][0]
	i = 0
	while f + 22 <= m["pant_loop"][1] - 22:
		f += 22
		keys.append(K(f, "b_pant_a" if i % 2 == 0 else "b_pant_b", "in_out_sine",
					  face="wheeze" if i % 4 else "dazed"))
		i += 1
	keys += [K(m["stand"][0], "b_exhausted_sit", "in_out_sine", face="wheeze"),
			 K(m["stand"][0] + 12, "b_getup", "in_out_sine", face="strain"),
			 K(ct["frames"], "b_melt_fists", "in_out_sine", face="wheeze")]
	keys = pin(keys, stance("b_stand"), flat=True)
	ev = [E(m["sit"][1], "sfx", id="land_soft", vol_db=-4.0),
		  E(m["stand"][0] + 12, "voice", id="vo_bellows_wheeze", vol_db=-6.0)]
	for k in keys:
		if k["f"] % 88 == 20 and 0 < k["f"] < m["pant_loop"][1]:
			ev.append(E(k["f"], "voice", id="vo_bellows_wheeze", vol_db=-8.0))
	clip("melt_exhausted", ct["frames"], keys, ev, loop=True, tags=["state", "exhausted"], blend_in=6, blend_out=6,
		 doc="Exhausted (480 f, loops): after a Meltdown he sits down where he stands and pants for eight seconds — "
			 "sight 150 px, specs off — then hauls himself up.")


# ============================================================================ T3 last beats
def last_beats():
	st = stance("b_stand")
	ct = _ct("beat_slow_burn")
	clip("beat_slow_burn", ct["frames"], breathe(pin([
		K(0, "b_slow_burn", "linear", face="slow_burn"),
		K(20, "b_slow_burn", "in_out_sine", set_={"head": {"rot": 6}}),
		K(ct["marks"]["blink"], "b_slow_burn", "linear", face="dazed"),
		K(ct["marks"]["blink"] + 4, "b_slow_burn", "linear", face="slow_burn"),
		K(56, "b_slow_burn", "in_out_sine", set_={"head": {"rot": 2}}),
		K(ct["frames"], "b_slow_burn", "in_out_sine"),
	], st), st, every=18, amp=0.02), [E(0, "sfx", id="bassoon_burn")],
		tags=["beat", "last_beat", "slow_burn"], blend_in=6, blend_out=6, plant=True,
		doc="T3 last beat (70 f): a long flat stare out at the Stalls and one slow blink.")
	ct = _ct("beat_dignity_fail")
	m = ct["marks"]
	clip("beat_dignity_fail", ct["frames"], pin([
		K(0, "b_stand", "linear", face="irked"),
		K(2, "b_stand", "linear", face="pompous"),
		K(16, "b_dignity_straighten", "in_out_sine"),
		K(m["straighten"][1], "b_dignity_straighten", "in_out_sine", set_={"cravat": {"rot": 4}, "head": {"rot": -18}}),
		K(44, "b_look_behind", "in_out_sine", face="suspicious"),
		K(m["cravat_pings"], "b_cravat_ping", "pop", face="huh"),
		K(m["cravat_pings"] + 6, "b_cravat_ping", "out_quad", set_={"cravat": {"rot": -80}}),
		K(ct["frames"], "b_slow_burn", "in_out_sine", face="slow_burn"),
	], st), [E(2, "sfx", id="cravat_tug"), E(34, "voice", id="vo_bellows_ahem", vol_db=-3.0),
			 E(m["cravat_pings"], "sfx", id="cravat_ping"), E(m["cravat_pings"], "spring", part="cravat", kick=60.0)],
		tags=["beat", "last_beat", "dignity"], blend_in=6, blend_out=6, plant=True,
		doc="T3 last beat (70 f): he straightens his cravat, looks round to check nobody saw — and it pings straight "
			"up again.")
	ct = _ct("beat_bow_topple")
	m = ct["marks"]
	clip("beat_bow_topple", ct["frames"], pin([
		K(0, "b_stand", "linear", face="pompous"),
		K(4, "b_bow", "out_quad", face="smug"),
		K(16, "b_bow", "in_out_sine"),
		K(24, "b_bow_deep", "in_out_sine", face="strain"),
		K(m["topple"], "b_topple", "in_quad", face="shock"),
		K(m["floor"][0], "b_fall_sit", "pop", face="shock", set_={"root": root_of("b_fall_sit", sx=1.1, sy=0.9)}),
		K(m["floor"][0] + 4, "b_fall_sit", "linear", set_={"root": root_of("b_fall_sit", sx=1.02, sy=0.98)}),
		K(ct["frames"], "b_dazed_sit", "in_out_sine", face="dazed"),
	], st, flat=True, free=(m["topple"], m["floor"][0], m["floor"][0] + 4, ct["frames"])),
		[E(4, "sfx", id="bow_creak"), E(m["topple"], "sfx", id="slide_down_short"),
		 E(m["floor"][0], "sfx", id="slip_thud"), E(m["floor"][0], "shake", trauma=0.4)],
		tags=["beat", "last_beat", "bow"], blend_in=6, blend_out=6, smear=True,
		doc="T3 last beat (60 f): a dignified bow that keeps going, and going, until he topples onto his bottom.")
	ct = _ct("beat_tear")
	m = ct["marks"]
	clip("beat_tear", ct["frames"], breathe(pin([
		K(0, "b_slow_burn", "linear", face="slow_burn"),
		K(10, "b_tear_lip", "in_out_sine", face="teary"),
		K(m["tear"], "b_tear_lip", "in_out_sine", set_={"head": {"rot": 8}}),
		K(42, "b_tear_sniff", "out_quad", face="teary"),
		K(50, "b_tear_sniff", "in_out_sine", set_={"head": {"rot": -14}, "nose": {"sx": 1.06}}),
		K(ct["frames"], "b_slow_burn", "in_out_sine", face="slow_burn"),
	], st), st, every=15, amp=0.015),
		[E(0, "sfx", id="sad_violin"), E(m["tear"], "sfx", id="tear_plink"), E(42, "sfx", id="sniffle")],
		tags=["beat", "last_beat", "tear"], blend_in=6, blend_out=6, plant=True,
		doc="T3 last beat (60 f): one single tear rolls down — and he sniffs it straight back in.")


# ============================================================================ detours, the hunt and the door
def detours():
	ct_stand = stance("b_stand")
	clip("act_fixup_dry", 240, breathe(pin([
		K(0, "b_stand", "linear", face="irked"),
		K(24, "b_steam_dry", "in_out_sine", face="blissful"),
		K(70, "b_steam_dry", "in_out_sine", set_={"head": {"rot": -22}}),
		K(116, "b_steam_dry", "in_out_sine", set_={"torso": {"rot": -4}, "head": {"rot": -12}}),
		K(162, "b_steam_dry", "in_out_sine", set_={"head": {"rot": -20}}),
		K(206, "b_dignity_straighten", "in_out_sine", face="smug"),
		K(240, "b_stand", "in_out_sine", face="irked"),
	], ct_stand), ct_stand, every=30), [
		E(24, "sfx", id="fire_crackle", vol_db=-8.0, sync=False),
		E(70, "fx", id="steam", part="torso", dir=[0.0, -1.0], amount=10),
		E(162, "fx", id="steam", part="bouffant", dir=[0.0, -1.0], amount=8),
	], loop=True, tags=["detour", "fixup_dry"], blend_in=6, blend_out=6,
		doc="Fix-up DRY (240 f, loops): he steams himself dry at the nearest fire or radiator, arms out, blissful.")
	clip("act_fixup_sink", 240, breathe(pin([
		K(0, "b_sink_hands", "linear", face="disdain"),
		K(30, "b_scrub_face", "in_out_sine"),
		K(60, "b_scrub_face", "in_out_sine", set_={"head": {"rot": 22}, "arm_lower_r": {"rot": -120}}),
		K(90, "b_scrub_face", "in_out_sine", set_={"head": {"rot": 14}}),
		K(120, "b_sink_hands", "in_out_sine", face="neutral"),
		K(150, "b_scrub_face", "in_out_sine", face="disdain"),
		K(186, "b_rinse_lift", "in_out_sine", face="suspicious"),
		K(214, "b_rinse_lift", "in_out_sine", set_={"head": {"rot": -20}}),
		K(240, "b_sink_hands", "in_out_sine", face="disdain"),
	], stance("b_sink_hands")), stance("b_sink_hands"), every=24), [
		E(30, "sfx", id="splash", vol_db=-8.0), E(120, "sfx", id="splash", vol_db=-10.0),
		E(186, "fx", id="drops", part="head", dir=[0.0, 1.0], amount=6),
	], loop=True, tags=["detour", "fixup_sink"], blend_in=6, blend_out=6,
		doc="Fix-up SINK (240 f, loops): he scrubs the flour or treacle off his face at the nearest sink or basin.")
	clip("act_fixup_mirror", 240, breathe(pin([
		K(0, "b_preen", "linear", face="irked"),
		K(26, "b_comb_flourish", "in_out_sine", face="smug"),
		K(56, "b_comb_flourish", "in_out_sine", set_={"arm_lower_r": {"rot": -80}, "head": {"rot": -18}}),
		K(86, "b_comb_flourish", "in_out_sine", set_={"arm_lower_r": {"rot": -100}}),
		K(118, "b_comb_tuck", "in_out_sine", face="sly_smile"),
		K(150, "b_lean_in", "in_out_sine", face="suspicious"),
		K(182, "b_preen_b", "in_out_sine", face="admiring"),
		K(214, "b_dignity_straighten", "in_out_sine", face="pompous"),
		K(240, "b_preen", "in_out_sine", face="irked"),
	], stance("b_preen")), stance("b_preen"), every=30), [
		E(0, "prop", op="attach", prop="comb", socket="hand_r:grip"),
		E(26, "sfx", id="rustle", vol_db=-10.0), E(118, "sfx", id="clack", vol_db=-10.0),
		E(214, "sfx", id="cravat_tug", vol_db=-8.0), E(239, "prop", op="hide", prop="comb"),
	], loop=True, tags=["detour", "fixup_mirror"], blend_in=6, blend_out=6,
		doc="Fix-up MIRROR (240 f, loops): bouffant, feathers or costume put right at the nearest mirror, with a "
			"comb flourish and a last admiring look.")
	clip("act_hunt", 360, breathe(pin([
		K(0, "b_specs_lift", "linear", face="suspicious"),
		K(30, "b_hunt_peer_l", "in_out_sine"),
		K(80, "b_hunt_peer_l", "in_out_sine", set_={"head": {"rot": -16}}),
		K(130, "b_hunt_peer_r", "in_out_sine"),
		K(180, "b_hunt_peer_r", "in_out_sine", set_={"head": {"rot": 4}}),
		K(230, "b_suspicious", "in_out_sine", face="irked"),
		K(280, "b_hunt_peer_l", "in_out_sine", face="suspicious"),
		K(330, "b_specs_lift", "in_out_sine"),
		K(344, "b_specs_lift", "in_out_sine", set_={"head": {"rot": -10}, "torso": {"rot": 8}}),
		K(360, "b_specs_lift", "in_out_sine"),
	], ct_stand), ct_stand, every=30), [E(130, "voice", id="vo_bellows_grr", vol_db=-10.0)],
		loop=True, tags=["activity", "hunt"], blend_in=6, blend_out=6,
		doc="The hunt (360 f, loops; Prologue only): specs on, he sweeps the parlour for whatever squeaked, peering "
			"left and right as he walks the room.")
	clip("loco_door", 30, pin([
		K(0, "b_stand", "linear", face="pompous"),
		K(8, "b_door_reach", "out_quad"),
		K(14, "b_door_reach", "in_out_sine", set_={"arm_lower_r": {"rot": -40}}),
		K(22, "b_door_reach", "in_out_sine", set_={"arm_lower_r": {"rot": -8}, "torso": {"rot": 4}}),
		K(30, "b_stand", "in_out_sine", face="pompous"),
	], ct_stand), [E(14, "sfx", id="door_jiggle", vol_db=-6.0), E(22, "sfx", id="creak", vol_db=-8.0)],
		tags=["loco", "door"], blend_in=4, blend_out=4, plant=True,
		doc="Through a door (30 f): he reaches for the handle, swings it and steps through.")


# ============================================================================ the remaining micro-gags
def micro_gags():
	stand = stance("b_stand")
	C.mg("steam_sideburns", 48, pin([
		K(0, "b_steam_dry", "linear", face="blissful"),
		K(12, "b_steam_fluff", "in_out_sine", face="smug"),
		K(24, "b_steam_fluff", "in_out_sine", set_={"arm_lower_r": {"rot": -90}, "head": {"rot": -16}}),
		K(34, "b_steam_fluff", "in_out_sine", set_={"arm_lower_r": {"rot": -116}}),
		K(48, "b_steam_dry", "in_out_sine", face="blissful"),
	], stand), [E(12, "sfx", id="rustle", vol_db=-10.0), E(34, "sfx", id="boing_small", vol_db=-12.0)],
		doc="Fluffs his dripping sideburns in the heat; they spring out like poodle ears.")
	C.mg("scrub_nose", 48, pin([
		K(0, "b_scrub_face", "linear", face="disdain"),
		K(12, "b_scrub_nose", "in_out_sine", face="disdain"),
		K(22, "b_scrub_nose", "in_out_sine", set_={"nose": {"sx": 0.8}, "head": {"rot": 26}}),
		K(32, "b_scrub_nose", "in_out_sine", set_={"nose": {"sx": 0.9}, "head": {"rot": 18}}),
		K(48, "b_scrub_face", "in_out_sine", face="disdain"),
	], stance("b_sink_hands")), [E(22, "sfx", id="kettle_squeak", vol_db=-10.0), E(32, "sfx", id="kettle_squeak", vol_db=-12.0)],
		doc="Scrubs his face so hard his nose squeaks like a balloon.")
	C.mg("comb_flourish", 48, pin([
		K(0, "b_preen", "linear", face="irked"),
		K(12, "b_comb_flourish", "out_quad", face="smug"),
		K(24, "b_comb_flourish", "in_out_sine", set_={"arm_lower_r": {"rot": -70}, "head": {"rot": -18}}),
		K(34, "b_comb_tuck", "in_out_sine", face="sly_smile"),
		K(48, "b_preen", "in_out_sine", face="admiring"),
	], stance("b_preen")), [E(12, "sfx", id="rustle", vol_db=-8.0), E(34, "sfx", id="clack", vol_db=-10.0)],
		doc="Combs the bouffant back up with a flourish and tucks the comb behind his ear.")
	C.mg("peer_under_piano", 60, pin([
		K(0, "b_specs_lift", "linear", face="suspicious"),
		K(14, "b_peer_under", "in_out_sine", face="suspicious"),
		K(30, "b_peer_under", "in_out_sine", set_={"head": {"rot": -34}}),
		K(44, "b_peer_under", "in_out_sine", set_={"head": {"rot": -28}}),
		K(60, "b_specs_lift", "in_out_sine", face="huh"),
	], stand), [E(14, "sfx", id="creak", vol_db=-12.0)],
		doc="Specs on, he bends to peer under the piano as he passes - nose an inch from Hush's hiding spot - and straightens: nothing.")
	# walk beats: overlays on the strut (the legs keep walking underneath)
	C.mg("walk_hum", 48, [
		K(0, "b_stand", "linear", face="hum"),
		K(12, "b_stand", "in_out_sine", face="hum", set_={"head": {"rot": -14}}),
		K(24, "b_stand", "in_out_sine", face="hum", set_={"head": {"rot": -6}, "cravat": {"rot": 8}}),
		K(36, "b_stand", "in_out_sine", face="hum", set_={"head": {"rot": -14}}),
		K(48, "b_stand", "in_out_sine", face="pompous", set_={"head": {"rot": -8}}),
	], [E(0, "voice", id="vo_bellows_hum", vol_db=-4.0)],
		doc="Hums a march in time with his strut, chin up, arms swinging.")
	C.mg("cravat_tug", 48, [
		K(0, "b_stand", "linear", face="pompous"),
		K(10, "b_idle_tug", "out_quad", face="smug"),
		K(18, "b_idle_tug_b", "out_back"),
		K(28, "b_idle_tug", "in_out_sine"),
		K(36, "b_idle_tug_b", "out_back", set_={"belly": {"sy": 1.05}}),
		K(48, "b_stand", "in_out_sine", face="pompous"),
	], [E(18, "sfx", id="cravat_tug", vol_db=-6.0)],
		doc="Tugs his cravat and puffs his chest out mid-stride.")
	C.mg("walk_scale", 48, [
		K(0, "b_stand", "linear", face="sing_small"),
		K(10, "b_stand", "in_out_sine", face="sing_mid", set_={"head": {"rot": -12}}),
		K(22, "b_stand", "in_out_sine", face="sing_big", set_={"head": {"rot": -20}, "cravat": {"rot": -8}}),
		K(34, "b_stand", "in_out_sine", face="sing_mid", set_={"head": {"rot": -12}}),
		K(48, "b_stand", "in_out_sine", face="pompous", set_={"head": {"rot": -6}}),
	], [E(0, "voice", id="vo_bellows_warmup_2", vol_db=-4.0)],
		doc="Sings 'do-re-mi' a note per footfall, stepping on the beat.")


# ============================================================================ the livid rage aria
def livid_bit():
	bits_db = json.load(open(C.os.path.join(C.REPO, "game", "data", "activities.json")))["squeak_bits"]
	n = bits_db["bit_livid"]["len_f"]
	st = stance("b_stand")
	keys = pin([
		K(0, "b_stand", "linear", face="livid"),
		K(10, "b_melt_fists", "in_out_sine", face="livid"),
		K(22, "b_rage_point", "in_out_sine", face="livid"),
		K(32, "b_rage_aria", "in_out_sine", face="livid"),
		K(44, "b_rage_aria", "in_out_sine", set_={"root": root_of("b_rage_aria", sy=1.03), "head": {"rot": -33}}),
		K(54, "b_rage_aria", "in_out_sine", set_={"root": root_of("b_rage_aria", sy=1.0), "head": {"rot": -30}}),
		K(68, "b_rage_aria", "in_out_sine", set_={"root": root_of("b_rage_aria", sy=1.03), "head": {"rot": -34}}),
		K(84, "b_rage_point", "in_out_sine", face="livid"),
		K(96, "b_melt_fists", "in_out_sine", face="furious"),
		K(108, "b_dignity_straighten", "in_out_sine", face="irked"),
		K(n, "b_stand", "in_out_sine", face="irked"),
	], st)
	clip("bit_livid", n, keys, [
		E(22, "voice", id="vo_bellows_who_squeaked"),
		E(22, "spring", part="bouffant", kick=30.0), E(32, "shake", trauma=0.25),
		E(68, "fx", id="steam", part="head", dir=[0.0, -1.0], amount=10),
		E(108, "sfx", id="cravat_tug", vol_db=-8.0),
	], tags=["bit", "livid"], blend_in=4, blend_out=8, plant=True,
		doc="Squeak bit (Livid, once per Night, 120 f): 'WHO SQUEAKED?!' — a full rage aria at the ceiling, a "
			"jabbed finger, then he collects himself.")


# ============================================================================ reactions: the B variant and the knock-on entry
def extra_reactions():
	# EYE-POPPING NEWS variant B (135 f): he wakes / looks up with the specs already on and smeared
	rx = _rx("blind_bumble_b")
	blind = stance("b_blind_stand")
	keys = [
		K(0, "b_rec_sit", "linear", face="pompous"),
		K(12, "b_rec_peer", "in_out_sine", face="suspicious"),
		K(30, "b_rec_lean_in", "in_out_sine", face="suspicious"),
		K(38, "b_rec_lean_in", "linear", face="huh", set_={"head": {"rot": 16}}),
		K(44, "b_rec_lean_in", "linear", set_={"head": {"rot": 18}, "nose": {"sx": 1.06}}),
		K(46, "b_rec_eyes_pop", "pop", face="magnified"),
		K(49, "b_rec_eyes_pop", "linear", set_={"root": root_of("b_rec_eyes_pop", sx=1.0, sy=1.0)}),
		K(58, "b_blind_stand", "in_out_sine", face="magnified"),
		K(62, "b_blind_stand", "in_quad"),
		K(72, "b_blind_arms_out", "in_out_sine", face="huh"),
		K(84, "b_blind_lean", "in_out_sine"),
		K(96, "b_blind_arms_out", "in_out_sine", set_={"head": {"rot": -16}}),
		K(105, "b_blind_lean", "in_out_sine", set_={"head": {"rot": 18}}),
		K(116, "b_mg_kiss", "in_out_sine", face="kiss"),
		K(126, "b_bow", "in_out_sine", face="smug"),
		K(135, "b_blind_stand", "in_out_sine", face="dazed"),
	]
	for k in keys:
		if k["f"] >= 58:
			pin([k], blind)
			if k["f"] == 58:
				hover(k, -12.0)
	events = [
		E(0, "prop", op="attach", prop="newspaper", socket="hand_r:grip"),
		E(0, "prop", op="state", prop="newspaper", state="open"),
		E(12, "sfx", id="specs_tink", vol_db=-8.0),
		E(46, "sfx", id="eye_boing"), E(46, "prop", op="hide", prop="newspaper"),
		E(46, "spring", part="bouffant", kick=30.0), E(47, "smear", part="head", frames=2, stretch=1.4),
		E(62, "voice", id="vo_bellows_huh"),
		E(116, "sfx", id="kiss_smack", vol_db=-4.0),
		E(126, "sfx", id="bow_creak"), E(126, "voice", id="vo_bellows_pardon", vol_db=-2.0),
		E(135, "mark", name="release"),
	] + accent_events(rx, 46, trauma=0.3)
	clip("rx_blind_bumble_b", rx["frames"], keys, events, beats=beats_of(rx),
		 tags=["reaction", "take", "blind_bumble"], blend_in=0, blend_out=10, smear=True,
		 doc="EYE-POPPING NEWS / BUTTER-FINGERS variant B (135 f): the lenses are smeared, his eyes balloon, and he "
			 "bumbles off blind — this time he kisses the hat stand's hand and bows to it.")
	# TAP DANCE's knock-on entry (107 f): HOT & COLD drops him in the sink first, so the drench starts in the basin
	rxd = _rx("drench_a")
	st_sink = stance("b_sink_hands")
	keys = [
		K(0, "b_sink_sit", "linear", face="dazed_open"),
		K(8, "b_sink_kick_a", "in_out_sine"),
		K(16, "b_sink_kick_b", "in_out_sine", face="huh"),
		K(26, "b_sink_sit", "in_out_sine", set_={"head": {"rot": -14}}),
		K(40, "b_sink_sit", "in_out_sine", face="suspicious", set_={"head": {"rot": -24}}),
		K(47, "b_sink_sit", "in_out_sine", set_={"head": {"rot": -28}, "nose": {"sx": 1.06}}),
		K(50, "b_sink_blast", "pop", face="shock", set_={"root": root_of("b_sink_land"), "belly": {"sy": 0.88}}),
		K(53, "b_sink_blast", "linear", set_={"root": root_of("b_sink_land"), "belly": {"sy": 0.96}}),
		K(61, "b_sink_sit", "in_out_sine", face="slow_burn"),
		K(76, "b_sink_sit", "in_out_sine", set_={"head": {"rot": -6}}),
		K(93, "b_sink_sit", "in_out_sine", set_={"head": {"rot": 4}}),
		K(100, "b_sink_pop", "out_quad", face="dazed_open"),
		K(107, "b_blind_land", "in_quad", face="dazed"),
	]
	events = [
		E(0, "decor", id="kitchen_sink_lip", visible=True),
		E(16, "sfx", id="splash", vol_db=-8.0),
		E(40, "voice", id="vo_bellows_huh", vol_db=-4.0),
		E(50, "sfx", id="spray_blast"), E(50, "fx", id="drops", part="head", dir=[0.0, -1.0], amount=30),
		E(50, "spring", part="bouffant", kick=-40.0), E(51, "smear", part="head", frames=2, stretch=1.5),
		E(53, "voice", id="vo_bellows_pff", vol_db=-2.0),
		E(93, "fx", id="drops", part="nose", dir=[0.0, 1.0], amount=8),
		E(100, "sfx", id="pop_out", vol_db=-4.0), E(106, "decor", id="kitchen_sink_lip", visible=False),
		E(107, "mark", name="release"),
	] + accent_events(rxd, 50, trauma=0.4)
	clip("rx_drench_a_ko", rxd["frames"], keys, events, beats=beats_of(rxd),
		 tags=["reaction", "take", "drench", "knock_on"], blend_in=0, blend_out=10, smear=True,
		 doc="TAP DANCE entered as a knock-on (107 f): HOT & COLD has already rocketed him into the sink, so the "
			 "drench starts from the basin — he reaches up, the tap finds his face, and he takes it sitting down.")


# ============================================================================ cold opens, the curtain call, the cue
def set_pieces():
	stand = stance("b_stand")
	# N01 cold open: dawn scales through a megaphone out of the window
	keys = pin([
		K(0, "b_breath_in", "linear", face="inhale"),
		K(20, "b_megaphone", "out_quad", face="sing_small"),
		K(50, "b_megaphone", "in_out_sine", face="sing_mid", set_={"head": {"rot": -22}}),
		K(80, "b_megaphone", "in_out_sine", face="sing_big", set_={"head": {"rot": -32}, "belly": {"sy": 1.06}}),
		K(110, "b_megaphone", "in_out_sine", face="sing_mid", set_={"head": {"rot": -24}}),
		K(140, "b_megaphone", "in_out_sine", face="sing_big", set_={"head": {"rot": -34}, "belly": {"sy": 1.08}}),
		K(180, "b_megaphone", "in_out_sine", face="sing_big", set_={"head": {"rot": -30}}),
		K(210, "b_preen", "in_out_sine", face="admiring"),
		K(240, "b_preen", "in_out_sine", face="smug", set_={"head": {"rot": -14}}),
		K(270, "b_dignity_straighten", "in_out_sine", face="pompous"),
		K(300, "b_stand", "in_out_sine", face="smug"),
	], stand)
	clip("cold_n01_megaphone", 300, keys, [
		E(0, "prop", op="attach", prop="megaphone", socket="hand_r:grip"),
		E(20, "voice", id="vo_bellows_warmup_1"), E(80, "voice", id="vo_bellows_warmup_3"),
		E(140, "voice", id="vo_bellows_warmup_4"), E(140, "shake", trauma=0.2),
		E(210, "sfx", id="window_creak", vol_db=-6.0), E(299, "prop", op="hide", prop="megaphone"),
	], tags=["cold", "megaphone"], blend_in=0, blend_out=8, plant=True,
		doc="Cold open N01 (300 f): at dawn he sings his scales out of the window through a megaphone, louder and "
			"louder, then admires himself — while the street's windows crack.")
	# N02 cold open: pops a child's balloon with his baton, drops the string in the box
	keys = pin([
		K(0, "b_stand", "linear", face="pompous"),
		K(24, "b_baton_up", "in_out_sine", face="smug"),
		K(44, "b_baton_up", "in_out_sine", set_={"arm_upper_r": {"rot": -172}, "head": {"rot": -16}}),
		K(54, "b_baton_up", "in_quad", set_={"arm_upper_r": {"rot": -178}}),
		K(58, "b_baton_stab", "pop", face="sly_smile"),
		K(62, "b_baton_stab", "linear", set_={"root": root_of("b_baton_stab", sx=1.0, sy=1.0)}),
		K(86, "b_baton_stab", "in_out_sine", face="disdain", set_={"arm_upper_r": {"rot": -70}}),
		K(120, "b_stand", "in_out_sine", face="smug"),
		K(150, "b_fridge_reach", "in_out_sine", face="disdain"),
		K(176, "b_fridge_reach", "in_out_sine", set_={"head": {"rot": -24}}),
		K(206, "b_stand", "in_out_sine", face="pompous"),
		K(236, "b_dignity_straighten", "in_out_sine", face="smug"),
		K(260, "b_stand", "in_out_sine", face="pompous"),
	], stand, free=(58, 62))
	clip("cold_n02_balloon", 260, keys, [
		E(0, "prop", op="attach", prop="baton", socket="hand_r:grip"),
		E(24, "sfx", id="baton_swish", vol_db=-6.0),
		E(58, "sfx", id="pop"), E(58, "shake", trauma=0.35), E(58, "spring", part="bouffant", kick=20.0),
		E(59, "smear", part="arm_upper_r", frames=2, stretch=1.4),
		E(86, "voice", id="vo_bellows_hmph"),
		E(176, "sfx", id="cupboard_door", vol_db=-6.0), E(236, "sfx", id="cravat_tug", vol_db=-8.0),
		E(259, "prop", op="hide", prop="baton"),
	], tags=["cold", "baton"], blend_in=0, blend_out=8, smear=True, plant=True,
		doc="Cold open N02 (260 f): he lines up a child's balloon, pops it with his conductor's baton, and drops the "
			"string into the CONFISCATED box with great satisfaction.")
	# the curtain call: he wanders on in his residue, sees the audience, slow-burns
	keys = pin([
		K(0, "b_stand", "linear", face="pompous"),
		K(20, "b_idle_lapel", "in_out_sine", face="dazed"),
		K(44, "b_idle_lapel_b", "in_out_sine", face="pompous"),
		K(70, "b_dt_away", "in_out_sine", face="smug"),
		K(96, "b_dt_away", "in_out_sine", set_={"head": {"rot": -16}}),
		K(118, "b_lean_in", "in_out_sine", face="huh"),
		K(132, "b_dt_back", "pop", face="shock"),
		K(138, "b_dt_back", "linear", set_={"belly": {"sy": 1.06}}),
		K(144, "b_cc_shrug", "in_out_sine", face="huh"),
		K(150, "b_cc_shrug", "in_quad"),
		K(168, "b_slow_burn", "in_out_sine", face="slow_burn"),
		K(180, "b_slow_burn", "in_out_sine", set_={"head": {"rot": 4}}),
	], stand, flat=True)
	clip("cc_wander_on", 180, keys, [
		E(20, "sfx", id="bellows_step", vol_db=-8.0), E(70, "sfx", id="bellows_step", vol_db=-8.0),
		E(132, "sfx", id="sting_spot"), E(132, "spring", part="bouffant", kick=36.0),
		E(133, "smear", part="head", frames=2, stretch=1.5),
		E(150, "voice", id="vo_bellows_huh"),
	], tags=["curtain", "wander_on"], blend_in=6, blend_out=6, smear=True,
		doc="The curtain call (180 f): still wearing whatever happened to him, he wanders on behind the results "
			"panel, notices the audience for the first time, shrugs — and slow-burns at them.")
	# the Prologue's picture-bonk cue (48 f, upper overlay)
	clip("cue_picture_bonk", 48, pin([
		K(0, "b_blind_stand", "linear", face="huh"),
		K(4, "b_blind_lean", "in_quad"),
		K(6, "b_bonk_flat", "pop", face="shock"),
		K(12, "b_picture_wear", "out_quad", face="dazed_open"),
		K(24, "b_picture_wear", "in_out_sine", face="dazed", set_={"head": {"rot": 12}}),
		K(36, "b_picture_wear", "in_out_sine", set_={"head": {"rot": -6}}),
		K(48, "b_blind_stand", "in_out_sine", face="huh"),
	], stance("b_blind_stand"), flat=True), [E(6, "sfx", id="picture_fall"), E(6, "spring", part="bouffant", kick=34.0),
		E(7, "smear", part="head", frames=2, stretch=1.4), E(12, "voice", id="vo_bellows_oof", vol_db=-3.0)],
		layer="overlay", mask="upper", blend_in=4, blend_out=6, smear=True,
		tags=["cue", "overlay", "picture"],
		doc="The Prologue's laugh_picture cue (48 f, upper overlay): a picture drops off the wall onto his head and "
			"hangs round his neck like a collar.")


# ============================================================================ the Irked / Steaming walks
def walks():
	irked = [K(f, ("b_irked_%d" % f) if f < 15 else ("b_irked_m%d" % (f - 15)), "linear", face="irked" if f == 0 else None)
			 for f in range(30)]
	irked.append(K(30, "b_irked_0", "linear"))
	clip("loco_irked", 30, irked, [E(0, "sfx", id="bellows_step", vol_db=-1.0), E(15, "sfx", id="bellows_step", vol_db=-1.0)],
		 loop=True, blend_in=6, blend_out=6, stride=132.0, tags=["loco", "walk", "irked"],
		 doc="Irked walk (30 f, 66 px per step, 132 px per cycle = 264 px/s with the feet planted): head down, fists "
			 "swinging, a clipped quicker march. Map key walk@tier2.")
	stomp = [K(f, ("b_stomp_%d" % f) if f < 15 else ("b_stomp_m%d" % (f - 15)), "linear", face="furious" if f == 0 else None)
			 for f in range(30)]
	stomp.append(K(30, "b_stomp_0", "linear"))
	clip("loco_stomp", 30, stomp, [
		E(0, "sfx", id="stomp", vol_db=-4.0), E(0, "shake", trauma=0.12),
		E(15, "sfx", id="stomp", vol_db=-4.0), E(15, "shake", trauma=0.12),
	], loop=True, blend_in=6, blend_out=6, stride=138.0, tags=["loco", "walk", "stomp"],
		doc="Steaming stomp (30 f, 69 px per step, 138 px per cycle = 276 px/s with the feet planted): flat-footed, "
			"knees high, leaning in, the floor shaking a little on each step. Map keys walk@tier3 and the "
			"Prologue's scripted exit.")


# `curtain:*` and `cold:*` are not clip-map families (ClipMap.SCHEMA_KEYS): the view resolves those rows straight
# from data/anim/clip_rules.json, which already names these clips.
MAP_KEYS = {
	"activity:fixup_dry": "bellows/act_fixup_dry", "activity:fixup_sink": "bellows/act_fixup_sink",
	"activity:fixup_mirror": "bellows/act_fixup_mirror", "activity:hunt": "bellows/act_hunt",
	"activity:curious": "bellows/st_look", "activity:search": "bellows/st_search",
	"walk@tier2": {"clip": "bellows/loco_irked", "stride_px": 132, "speed_px_s": 264},
	"walk@tier3": {"clip": "bellows/loco_stomp", "stride_px": 138, "speed_px_s": 276},
	"run": {"clip": "bellows/st_chase", "stride_px": 120, "speed_px_s": 600},
	"state:chase": {"clip": "bellows/st_chase", "stride_px": 120, "speed_px_s": 600},
	"door": "bellows/loco_door",
	"state:search": {"clip": "bellows/st_search", "loop": True},
	"state:spotted": "bellows/st_double_take",
	"state:meltdown": ["bellows/melt_a", "bellows/melt_b", "bellows/melt_c"],
	"state:exhausted": {"clip": "bellows/melt_exhausted", "loop": True},
	"oneshot:head_turn": "bellows/st_head_turn", "oneshot:specs_on": "bellows/st_specs_on",
	"oneshot:doorway_pause": {"clip": "bellows/st_straighten_cravat", "loop": True},
	"oneshot:look_back": "bellows/st_look_back", "oneshot:bump": "bellows/st_bump",
	"oneshot:bump_look": {"clip": "bellows/st_look", "loop": True},
	"oneshot:curious_stop": "bellows/st_suspicious",
	"oneshot:curious_look": {"clip": "bellows/st_look", "loop": True},
	"oneshot:chase_wheeze": "bellows/st_wheeze", "oneshot:face_to_face": "bellows/st_face_to_face",
	"oneshot:fizzle": "bellows/st_smirk",
	"oneshot:caught:grab": "bellows/st_grab",
	"oneshot:caught:lecture": ["bellows/lec_a", "bellows/lec_b", "bellows/lec_c"],
	"oneshot:caught:doorstep": "bellows/st_door_slam",
	"cue:laugh_picture": "bellows/cue_picture_bonk",
	"mg:steam_sideburns": "bellows/mg_steam_sideburns", "mg:scrub_nose": "bellows/mg_scrub_nose",
	"mg:comb_flourish": "bellows/mg_comb_flourish", "mg:peer_under_piano": "bellows/mg_peer_under_piano",
	"mg:walk_hum": "bellows/mg_walk_hum", "mg:cravat_tug": "bellows/mg_cravat_tug",
	"mg:walk_scale": "bellows/mg_walk_scale",
	"bit:bit_livid": "bellows/bit_livid",
}


def build():
	states()
	lecture()
	meltdowns()
	last_beats()
	detours()
	micro_gags()
	livid_bit()
	extra_reactions()
	set_pieces()
	walks()
