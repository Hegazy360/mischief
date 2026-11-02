"""Wave-0 Bellows clips (docs/LEVELS.md §5, wave 0 — the slice's Night-1 / Prologue set), authored through
clips_spec.py's K / E / clip helpers and written by its main():

  reactions   rx_drench_a (TAP DANCE), rx_sing_crack_a (KETTLE DRUM), rx_strain_slip_a (IN A PICKLE),
              rx_launch_ceiling_a (LIFT-OFF), rx_dizzy_spin_a (ALLEGRO-GO-GO!)
  activities  act_pickles (300 f loop), act_rinse (300 f loop), act_paper (480 f loop)
  micro-gags  mg_sniff_jar, mg_gargle_hum, mg_tut, mg_chuckle_at_own_photo (upper-body overlays)
  squeak bits bit_tea (100 f), bit_paper (80 f), bit_warmup (90 f)

Every reaction's beats and length come from reactions.json (lint A19); its sounds are s2-sound's rows
(docs/review/s2-sound/clip_events.md) on the clip's contact frames. Standing clips pin a stance: the anim lint's
A12 (a planted sole drifts ≤ 2 px) means the absolute leg angles must not change while a foot is on the floor,
so `pin()` writes each key's leg channels from one stance (upper = absolute − that key's torso rotation) and a
stance only changes across an airborne key (a hop, the slip, the catapult).
"""
import json
import math
import sys

# clips_spec runs as __main__: author into ITS clip table, not a second import's
_main = sys.modules.get("__main__")
C = _main if (_main is not None and hasattr(_main, "CLIPS") and hasattr(_main, "RIG")) else __import__("clips_spec")
K, E, clip = C.K, C.E, C.clip

LEG_PARTS = ("leg_upper_r", "leg_lower_r", "foot_r", "leg_upper_l", "leg_lower_l", "foot_l")


def _rx(name):
	return json.load(open(C.REACTIONS))["archetypes"][name]


def _bone_rot(pose, part, over=None):
	if over and part in over and "rot" in over[part]:
		return float(over[part]["rot"])
	return float(pose.get("bones", {}).get(part, {}).get("rot", 0.0))


def stance(pose_name):
	"""A planted stance: the pose's absolute leg angles (upper = torso + upper), lower legs and feet raw, and the
	root x / y its planting gave it (the feet land exactly there when the stance is pinned)."""
	p = C.RIG.pose(pose_name)
	t = _bone_rot(p, "torso")
	r = p.get("root", {})
	return {"leg_upper_r": t + _bone_rot(p, "leg_upper_r"), "leg_upper_l": t + _bone_rot(p, "leg_upper_l"),
			"leg_lower_r": _bone_rot(p, "leg_lower_r"), "leg_lower_l": _bone_rot(p, "leg_lower_l"),
			"foot_r": _bone_rot(p, "foot_r"), "foot_l": _bone_rot(p, "foot_l"),
			"_x": float(r.get("x", 0.0)), "_y": float(r.get("y", 0.0))}


def pin(keys, st, free=(), parts=LEG_PARTS, root=True, flat=False):
	"""Write stance `st` into every key's `set`: the leg channels in `parts` (upper = absolute − that key's torso
	rotation) and, with `root`, the stance's root x / y (keeping the key's own sx / sy / rot). Frames in `free` are
	left alone (airborne keys: a hop, the slip, the catapult)."""
	for k in keys:
		if k["f"] in free:
			continue
		p = C.RIG.pose(k["pose"])
		over = k.get("set", {})
		t = _bone_rot(p, "torso", over)
		s = dict(over)
		for part in parts:
			v = st[part] - t if part.startswith("leg_upper") else st[part]
			s[part] = dict(s.get(part, {}))
			s[part]["rot"] = round(v, 1)
		if root:
			# the hips sit 4 px ahead of the torso joint (rig leg offset (4, 0)): a torso lean moves them by
			# (4 cos t - 4, 4 sin t); the root is moved back so the pinned feet stay put, a hair above the floor
			tr = math.radians(t)
			r = dict(over["root"]) if "root" in over else dict(p.get("root", {}))
			r["x"] = round(st["_x"] - 4.0 * (math.cos(tr) - 1.0), 1)
			r["y"] = round(st["_y"] - 0.8 - 4.0 * math.sin(tr), 1)
			if flat:
				# a root squash scales the whole body about the feet origin, so it drags both soles off their
				# stance: a key with both feet down keeps the scale neutral and squashes on belly / torso instead
				r["sx"] = 1.0
				r["sy"] = 1.0
				r["rot"] = 0.0
			s["root"] = r
		k["set"] = s
	return keys


def hover(key, dy):
	"""After pin(): lift a key straight up by `dy` px (legs unchanged), so the next key lands the feet vertically on
	their pinned spot instead of sliding into it along the floor."""
	key["set"]["root"]["y"] = round(key["set"]["root"]["y"] + dy, 1)
	return key


def root_of(pose_name, dx=0.0, dy=0.0, **over):
	"""The pose's own root (planted x / y included) moved by dx / dy, with absolute overrides (sx, sy, rot, or x / y
	for the unplanted flight poses)."""
	r = C.pose_root(pose_name)
	r["x"] = float(r.get("x", 0.0)) + dx
	r["y"] = float(r.get("y", 0.0)) + dy
	r.update(over)
	return r


def beats_of(rx):
	m = rx["marks"]
	b = {"anticipation": [m["antic"], m["accent"]], "accent": [m["accent"], m["hold"][0]],
		 "hold": [m["hold"][0], m["hold"][1]], "settle": [m["hold"][1], rx["frames"]]}
	for bn, v in rx.get("beats", {}).items():
		b[bn] = list(v)
	return b


def accent_events(rx, f, trauma=0.45, hold=36):
	cam = rx.get("cam", {})
	return [E(f, "mark", name="accent"), E(f, "hitstop", frames=int(cam.get("hitstop", 5))),
			E(f, "cam", op="punch", zoom=float(cam.get("zoom", 1.3)), **{"in": 6, "hold": hold, "out": 20}),
			E(f, "shake", trauma=trauma)]


# ============================================================================ TAP DANCE — rx_drench_a (107 f)
def drench():
	"""At the sink facing +1 (st_sink): the tap sprays (0-12), he wrestles the hose like a python (12-40, a hop into
	a wide brace), rears up and peers down the nozzle like a cobra charmer (40-50, the anticipation), BLAST full in
	the face (50-53: knocked back on his heels, arms up, bouffant flattened), the drenched deadpan to the Stalls
	(53-93, dripping), a droop and a shudder (93-107). The sim adds SOAKED from f53."""
	rx = _rx("drench_a")
	a = stance("b_sink_hands")
	wide = stance("b_hose_wrestle")
	keys = [
		K(0, "b_sink_hands", "linear", face="neutral"),
		K(6, "b_drench_shield", "in_out_sine", face="shock"),
		K(12, "b_hose_wrestle", "in_out_sine", face="strain", set_={"root": root_of("b_hose_wrestle", dy=-16.0)}),
		K(15, "b_hose_wrestle", "in_quad"),
		K(21, "b_hose_wrestle_b", "in_out_sine"),
		K(27, "b_hose_wrestle", "in_out_sine"),
		K(33, "b_hose_wrestle_b", "in_out_sine"),
		K(40, "b_lean_in", "in_out_sine", face="suspicious"),
		K(47, "b_lean_in", "in_quad", set_={"head": {"rot": 16}, "nose": {"sx": 1.1}}),
		K(50, "b_drench_blast", "pop", face="shock", set_={"root": root_of("b_drench_blast", dy=-12.0)}),
		K(53, "b_drench_blast", "in_quad", face="slow_burn"),
		K(61, "b_drip_stand", "in_out_sine", face="slow_burn"),
		K(74, "b_drip_stand_b", "in_out_sine"),
		K(90, "b_drip_stand", "in_out_sine"),
		K(93, "b_drip_stand", "linear", set_={"head": {"rot": 8}}),
		K(100, "b_drip_stand_b", "in_out_sine", face="dazed", set_={"root": root_of("b_drip_stand_b", sx=1.02, sy=0.98)}),
		K(107, "b_drip_stand", "in_out_sine", face="slow_burn"),
	]
	# stance: the sink stance until the hose yanks him into the air at f12; the wide brace until the blast lifts
	# him at f50; then the blast stance from f53
	blast = stance("b_drench_blast")
	for k in keys:
		if k["f"] < 12:
			pin([k], a)
		elif 15 <= k["f"] < 50:
			pin([k], wide)
		elif k["f"] >= 53:
			pin([k], blast)
	events = [
		E(0, "sfx", id="tap_spray"),
		E(6, "voice", id="vo_bellows_yow"),
		E(6, "fx", id="drops", part="hand_r", dir=[0.6, -0.8], amount=10),
		E(12, "sfx", id="hose_wrestle"),
		E(21, "sfx", id="hose_wrestle", vol_db=-4.0),
		E(33, "sfx", id="hose_wrestle", vol_db=-6.0),
		E(50, "sfx", id="spray_blast"),
		E(50, "fx", id="drops", part="head", dir=[-0.4, -1.0], amount=30),
		E(50, "spring", part="bouffant", kick=-40.0),
		E(51, "smear", part="head", frames=2, stretch=1.5),
		E(53, "voice", id="vo_bellows_pff", vol_db=-2.0),
		E(74, "fx", id="drops", part="nose", dir=[0.0, 1.0], amount=8),
		E(100, "fx", id="drops", part="bouffant", dir=[0.0, 1.0], amount=12),
		E(107, "mark", name="release"),
	] + accent_events(rx, 50, trauma=0.4)
	return clip("rx_drench_a", rx["frames"], keys, events, beats=beats_of(rx), tags=["reaction", "take", "drench"],
				blend_in=0, blend_out=10, smear=True, plant=True, doc=drench.__doc__)


# ============================================================================ KETTLE DRUM — rx_sing_crack_a (151 f)
def sing_crack():
	"""On the stool at st_tea (facing -1), teacup in hand: the kettle squeaks its melody and he cocks an ear (0-24),
	he harmonises, conducting with the free hand (24-60), the big breath and the top note, bent right back, arms
	wide (60-78, the anticipation), CRACK (78-81: snapped forward, hand to throat) and the lid boinks onto his nose,
	cross-eyed at it, palms up, a shake to get it off (81-131), then he pours his tea anyway, lid and all
	(131-151)."""
	rx = _rx("sing_crack_a")
	keys = [
		K(0, "b_stool_sit", "linear", face="pompous"),
		K(10, "b_stool_listen", "out_quad", face="huh"),
		K(20, "b_stool_listen", "in_out_sine", set_={"head": {"rot": -20}}),
		K(24, "b_stool_sing_b", "out_quad", face="sing_small"),
		K(32, "b_stool_sing_a", "in_out_sine", face="sing_mid"),
		K(40, "b_stool_sing_b", "in_out_sine", face="sing_small"),
		K(48, "b_stool_sing_a", "in_out_sine", face="sing_mid"),
		K(54, "b_stool_sing_b", "in_out_sine", face="sing_small"),
		K(60, "b_stool_sing_a", "in_out_sine", face="inhale", set_={"head": {"rot": -16}}),
		K(66, "b_stool_big_note", "out_quad", face="sing_big"),
		K(70, "b_stool_big_note", "linear", set_={"root": root_of("b_stool_big_note", sy=1.02)}),
		K(74, "b_stool_big_note", "linear", set_={"root": root_of("b_stool_big_note", sy=0.99), "head": {"rot": -28}}),
		K(78, "b_stool_crack", "pop", face="shock"),
		K(81, "b_stool_crack", "linear", set_={"head": {"rot": 18}}),
		K(88, "b_stool_lid", "out_back", face="huh"),
		K(100, "b_stool_lid_b", "in_out_sine", face="dazed_open"),
		K(106, "b_stool_lid", "in_out_sine", face="huh"),
		K(112, "b_stool_lid_b", "in_out_sine", set_={"root": root_of("b_stool_lid_b", rot=-2)}),
		K(120, "b_stool_lid", "in_out_sine", face="magnified"),
		K(131, "b_stool_lid", "in_out_sine", face="pompous", set_={"head": {"rot": -8}}),
		K(140, "b_stool_pour_a", "in_out_sine", face="smug"),
		K(151, "b_stool_pour_b", "in_out_sine"),
	]
	events = [
		E(0, "prop", op="attach", prop="teacup", socket="hand_r:grip"),
		E(0, "prop", op="state", prop="teacup", state="held"),
		E(0, "sfx", id="kettle_melody"),
		E(24, "voice", id="vo_bellows_hum"),
		E(32, "voice", id="vo_bellows_warmup_2"),
		E(66, "voice", id="vo_bellows_warmup_3"),
		E(78, "voice", id="vo_bellows_warmup_crack"),
		E(78, "sfx", id="lid_boink"),
		E(78, "prop", op="attach", prop="kettle_lid", socket="head:specs"),
		E(78, "spring", part="bouffant", kick=30.0),
		E(79, "smear", part="head", frames=2, stretch=1.4),
		E(88, "voice", id="vo_bellows_huh", vol_db=-2.0),
		E(112, "sfx", id="lid", vol_db=-4.0),
		E(140, "sfx", id="kettle_pour"),
		E(150, "prop", op="hide", prop="kettle_lid"),
		E(150, "prop", op="hide", prop="teacup"),
		E(151, "mark", name="release"),
	] + accent_events(rx, 78, trauma=0.35)
	return clip("rx_sing_crack_a", rx["frames"], keys, events, beats=beats_of(rx), tags=["reaction", "take", "sing_crack", "stool"],
				blend_in=0, blend_out=10, smear=True, doc=sing_crack.__doc__)


# ============================================================================ IN A PICKLE — rx_strain_slip_a (159 f)
def strain_slip():
	"""At the pickle shelf facing +1: three heaves at the over-tightened lid, each bigger and purpler (0-48), POP
	(48): he springs tall as the onions pinball off the pans, ducks (48-60), steps on one and windmills, one slipper
	up then the other (60-78, the anticipation), THUD on his bottom (78-81), dazed on the floor with a pickled onion
	for a hat (81-135), and up with what dignity remains (135-159)."""
	rx = _rx("strain_slip_a")
	shelf = stance("b_shelf_twist_a")
	duck = stance("b_duck_cover")
	up = stance("b_dignity_straighten")
	keys = [
		K(0, "b_shelf_twist_a", "linear", face="pompous"),
		K(6, "b_shelf_strain_1", "out_quad", face="strain"),
		K(12, "b_shelf_twist_b", "in_out_sine", face="irked"),
		K(16, "b_shelf_twist_a", "in_out_sine"),
		K(22, "b_shelf_strain_1", "out_quad", face="strain", set_={"root": root_of("b_shelf_strain_1", sx=1.04, sy=0.95)}),
		K(28, "b_shelf_twist_b", "in_out_sine", face="furious"),
		K(32, "b_shelf_twist_a", "in_out_sine"),
		K(38, "b_shelf_strain_2", "out_quad", face="strain"),
		K(42, "b_shelf_strain_2", "linear", set_={"root": root_of("b_shelf_strain_2", sx=1.04, sy=0.91)}),
		K(45, "b_shelf_strain_2", "linear", set_={"root": root_of("b_shelf_strain_2", sx=1.03, sy=0.93), "head": {"rot": -28}}),
		K(48, "b_take_accent", "pop", face="wild_take", set_={"root": root_of("b_take_accent", dy=-30.0)}),
		K(51, "b_take_accent", "linear", set_={"root": root_of("b_take_accent", dy=-22.0)}),
		K(54, "b_duck_cover", "linear", face="terrified", set_={"root": root_of("b_duck_cover", sx=1.0, sy=0.94)}),
		K(60, "b_duck_cover", "linear", set_={"head": {"rot": 10}, "root": root_of("b_duck_cover", sx=1.0, sy=0.95)}),
		K(65, "b_slip_windmill", "in_out_sine", face="terrified", set_={"root": root_of("b_slip_windmill", rot=0)}),
		K(70, "b_slip_windmill_b", "linear", set_={"root": root_of("b_slip_windmill_b", rot=0)}),
		K(75, "b_slip_windmill", "linear", set_={"root": root_of("b_slip_windmill", rot=0)}),
		K(77, "b_slip_windmill_b", "linear", set_={"root": root_of("b_slip_windmill_b", rot=0)}),
		K(78, "b_fall_sit", "pop", face="shock", set_={"root": root_of("b_fall_sit", sx=1.1, sy=0.9)}),
		K(81, "b_fall_sit", "linear", set_={"root": root_of("b_fall_sit", sx=1.04, sy=0.96)}),
		K(90, "b_dazed_sit", "in_out_sine", face="dazed"),
		K(104, "b_dazed_sit_b", "in_out_sine"),
		K(118, "b_dazed_sit_c", "in_out_sine", face="dazed_open"),
		K(133, "b_dazed_sit", "in_out_sine", face="dazed"),
		K(139, "b_dazed_tuck", "in_out_sine", face="strain"),
		K(143, "b_getup", "in_out_sine"),
		K(147, "b_getup", "in_quad"),
		K(153, "b_dignity_straighten", "in_out_sine", face="pompous", set_={"head": {"rot": -18}}),
		K(159, "b_stand", "in_out_sine", face="irked"),
	]
	LEFT = ("leg_upper_l", "leg_lower_l", "foot_l")
	for k in keys:
		if k["f"] < 48:
			pin([k], shelf)
		elif 54 <= k["f"] <= 60:
			pin([k], duck)
		elif 65 <= k["f"] <= 77:
			pin([k], duck, parts=LEFT)       # the left slipper stays where the duck put it; the right one kicks
		elif k["f"] >= 143:
			pin([k], up)
			if k["f"] == 143:
				hover(k, -14.0)
	events = [
		E(0, "sfx", id="jar_strain"),
		E(6, "voice", id="vo_bellows_grr", vol_db=-4.0),
		E(22, "sfx", id="jar_strain", vol_db=-2.0),
		E(22, "voice", id="vo_bellows_grr", vol_db=-2.0),
		E(38, "sfx", id="jar_strain", vol_db=2.0),
		E(38, "voice", id="vo_bellows_grr"),
		E(48, "sfx", id="onion_pop"),
		E(48, "spring", part="bouffant", kick=40.0),
		E(49, "smear", part="head", frames=2, stretch=1.5),
		E(54, "sfx", id="pinball_bonk", sync=False),
		E(57, "sfx", id="pinball_bonk", vol_db=-2.0, sync=False),
		E(60, "sfx", id="pinball_bonk", vol_db=-3.0),
		E(65, "sfx", id="slip_whoosh"),
		E(70, "voice", id="vo_bellows_wha"),
	] + [E(f, "smear", part=part, frames=2, stretch=1.4) for f in (65, 70, 75, 77) for part in ("arm_upper_r", "arm_upper_l")] + [
		E(78, "sfx", id="slip_thud"),
		E(81, "voice", id="vo_bellows_oof"),
		E(81, "prop", op="attach", prop="pickled_onion", socket="head:hat"),
		E(81, "spring", part="belly", kick=0.08),
		E(104, "sfx", id="dizzy_tweets", vol_db=-6.0, sync=False),
		E(158, "prop", op="hide", prop="pickled_onion"),
		E(159, "mark", name="release"),
	] + accent_events(rx, 78, trauma=0.5)
	return clip("rx_strain_slip_a", rx["frames"], keys, events, beats=beats_of(rx), tags=["reaction", "take", "strain_slip"],
				blend_in=0, blend_out=10, smear=True, plant=True, doc=strain_slip.__doc__)


# ============================================================================ LIFT-OFF — rx_launch_ceiling_a (119 f)
def launch_ceiling():
	"""In the recliner at st_recliner (facing +1), paper up: he reaches down and pulls the lever (0-12), the seat
	sinks under him, knees up, gripping the armrests (12-30, the anticipation), CATAPULT (30-33: spread-eagle, the
	paper flung away; the sim carries x 2080 -> 2236 over 30-44, the clip the 220 px rise), his cravat snags the
	chandelier and he swings, pawing at it, slippers kicking (33-93), the cravat gives and he drops bottom-first
	into the log basket (93-119; knock_on at 103: UP IN SMOKE's BELLOWS BLOWS takes over from the basket)."""
	rx = _rx("launch_ceiling_a")
	arc = float(rx["travel"]["arc_px"])
	hang = -150.0 - (arc - 150.0)   # the dangle poses sit at root y -150; the arc asks for 220
	keys = [
		K(0, "b_rec_sit", "linear", face="pompous"),
		K(8, "b_rec_lever", "in_out_sine", face="smug"),
		K(12, "b_rec_lever", "linear", set_={"arm_upper_r": {"rot": 44}}),
		K(18, "b_rec_sink", "out_quad", face="antic"),
		K(24, "b_rec_sink", "in_out_sine", set_={"root": root_of("b_rec_sink", sy=0.84, sx=1.1)}),
		K(30, "b_rec_sink", "in_quad", face="terrified", set_={"root": root_of("b_rec_sink", sy=0.78, sx=1.14), "head": {"rot": 8}}),
		K(31, "b_launched", "pop", face="wild_take", set_={"root": root_of("b_launched", y=-60.0, rot=-10)}),
		K(33, "b_launched", "linear", set_={"root": root_of("b_launched", y=-130.0, rot=-24), "cravat": {"rot": 30}}),
		K(38, "b_launched", "out_quad", set_={"root": root_of("b_launched", y=hang - 10.0, rot=-6), "cravat": {"rot": 120}}),
		K(44, "b_dangle", "in_out_sine", face="terrified", set_={"root": root_of("b_dangle", y=hang, rot=14)}),
		K(54, "b_dangle_b", "in_out_sine", set_={"root": root_of("b_dangle_b", y=hang, rot=-12)}),
		K(64, "b_dangle", "in_out_sine", set_={"root": root_of("b_dangle", y=hang, rot=10)}),
		K(74, "b_dangle_c", "in_out_sine", face="dazed_open", set_={"root": root_of("b_dangle_c", y=hang, rot=-7)}),
		K(84, "b_dangle_b", "in_out_sine", face="terrified", set_={"root": root_of("b_dangle_b", y=hang, rot=4)}),
		K(93, "b_dangle_c", "in_out_sine", face="shock", set_={"root": root_of("b_dangle_c", y=hang + 6.0, rot=-2)}),
		K(98, "b_launched", "linear", face="terrified", set_={"root": root_of("b_launched", y=hang + 70.0, rot=12), "cravat": {"rot": 110}}),
		K(101, "b_basket_sit", "pop", face="dazed_open"),
		K(104, "b_basket_sit", "linear", set_={"root": root_of("b_basket_sit", sx=1.1, sy=0.9)}),
		K(109, "b_basket_sit_b", "out_back", face="dazed"),
		K(119, "b_basket_sit", "in_out_sine"),
	]
	events = [
		E(0, "prop", op="attach", prop="newspaper", socket="hand_r:grip"),
		E(0, "prop", op="state", prop="newspaper", state="open"),
		E(8, "sfx", id="recliner_twang", vol_db=-6.0),
		E(18, "sfx", id="creak"),
		E(30, "sfx", id="catapult_whoosh"),
		E(31, "voice", id="vo_bellows_wha"),
		E(31, "prop", op="hide", prop="newspaper"),   # flung out of frame (a PropSim launch drifted in review)
		E(32, "smear", part="torso", frames=3, stretch=1.7),
		E(44, "sfx", id="chandelier_jingle"),
		E(44, "spring", part="bouffant", kick=30.0),
		E(54, "sfx", id="chandelier_jingle", vol_db=-6.0),
		E(64, "sfx", id="creak", vol_db=-4.0),
		E(74, "sfx", id="chandelier_jingle", vol_db=-8.0),
		E(84, "voice", id="vo_bellows_ooh", vol_db=-2.0),
		E(93, "sfx", id="cravat_ping"),
		E(101, "sfx", id="logbasket_crash"),
		E(101, "shake", trauma=0.5),
		E(101, "spring", part="belly", kick=0.1),
		E(103, "mark", name="knock_on"),
		E(109, "voice", id="vo_bellows_oof", vol_db=-3.0),
		E(119, "mark", name="release"),
	] + accent_events(rx, 30, trauma=0.45, hold=50)
	return clip("rx_launch_ceiling_a", rx["frames"], keys, events, beats=beats_of(rx), tags=["reaction", "take", "launch_ceiling"],
				blend_in=0, blend_out=10, smear=True, doc=launch_ceiling.__doc__)


# ============================================================================ ALLEGRO-GO-GO! — rx_dizzy_spin_a (169 f)
def dizzy_spin():
	"""At the gramophone facing -1: the needle screeches and he glares at it (0-12), babbles his scales at triple
	speed, conducting in a blur (12-40), spins like a top, up on his toes, the barrel squashing edge-on (40-70),
	wobbles to a halt (70-86, the anticipation), COLLAPSES on his bottom (86-89), sits dizzy under orbiting notes,
	head lolling (89-149), then up with a cravat tug (149-169)."""
	rx = _rx("dizzy_spin_a")
	sing = stance("b_sing_small")
	reel = stance("b_reel_a")
	up = stance("b_dignity_straighten")
	keys = [
		K(0, "b_sing_small", "linear", face="sing_small"),
		K(6, "b_suspicious", "out_quad", face="suspicious"),
		K(12, "b_conduct_down", "out_quad", face="sing_mid"),
	]
	f = 12
	i = 0
	while f + 3 < 40:
		f += 3
		keys.append(K(f, "b_conduct_up" if i % 2 == 0 else "b_conduct_down", "linear", face="sing_mid" if i % 4 == 0 else None))
		i += 1
	keys += [K(40, "b_spin_wide", "out_quad", face="wild_take")]
	f = 40
	i = 0
	while f + 3 <= 70:
		f += 3
		keys.append(K(f, "b_spin_thin" if i % 2 == 0 else "b_spin_wide", "linear"))
		i += 1
	keys += [
		K(74, "b_reel_a", "linear", face="dazed_open"),
		K(77, "b_reel_a", "in_quad"),
		K(80, "b_reel_b", "in_out_sine"),
		# the wind-up: he pitches FORWARD, arms grabbing at nothing, before he goes down backwards
		K(85, "b_pitch_forward", "linear", face="shock"),
		K(86, "b_fall_sit", "pop", face="shock", set_={"root": root_of("b_fall_sit", sx=1.12, sy=0.9)}),
		K(89, "b_fall_sit", "linear", set_={"root": root_of("b_fall_sit", sx=1.04, sy=0.96)}),
		K(98, "b_dazed_sit", "in_out_sine", face="dazed"),
		K(112, "b_dazed_sit_b", "in_out_sine"),
		K(126, "b_dazed_sit_c", "in_out_sine", face="dazed_open"),
		K(140, "b_dazed_sit_b", "in_out_sine", face="dazed"),
		K(147, "b_dazed_sit", "in_out_sine"),
		K(151, "b_dazed_tuck", "in_out_sine", face="strain"),
		K(155, "b_getup", "in_out_sine"),
		K(159, "b_getup", "in_quad"),
		K(164, "b_dignity_straighten", "in_out_sine", face="pompous", set_={"head": {"rot": -18}}),
		K(169, "b_stand", "in_out_sine", face="irked"),
	]
	for k in keys:
		if k["f"] < 40:
			pin([k], sing)
		elif 74 <= k["f"] <= 85:
			pin([k], reel)
			if k["f"] == 74:
				hover(k, -10.0)
		elif k["f"] >= 155:
			pin([k], up)
			if k["f"] == 155:
				hover(k, -14.0)
	events = [
		E(0, "sfx", id="record_scratch"),
		E(12, "sfx", id="gramophone_babble"),
		E(12, "voice", id="vo_bellows_dizzy_babble"),
		E(40, "sfx", id="coatstand_spin"),
		E(41, "smear", part="torso", frames=2, stretch=1.3),
		E(55, "sfx", id="coatstand_spin", vol_db=-4.0),
		E(77, "sfx", id="slide_whistle_down", vol_db=-4.0),
		E(86, "sfx", id="slip_thud"),
		E(86, "spring", part="bouffant", kick=36.0),
		E(89, "sfx", id="dizzy_tweets", vol_db=-3.0),
		E(98, "voice", id="vo_bellows_ooh", vol_db=-4.0),
		E(169, "mark", name="release"),
	] + accent_events(rx, 86, trauma=0.45)
	return clip("rx_dizzy_spin_a", rx["frames"], keys, events, beats=beats_of(rx), tags=["reaction", "take", "dizzy_spin"],
				blend_in=0, blend_out=10, smear=True, plant=True, doc=dizzy_spin.__doc__)


# ============================================================================ activities
def pickles():
	"""300 f loop at the pickle shelf (facing +1): reaches up to the jar, twists the lid both ways, peers at it,
	screws it back and stands admiring his own thrift. mg_sniff_jar plays over the twist at 2 s."""
	keys = [
		K(0, "b_stand", "linear", face="pompous"),
		K(30, "b_shelf_reach", "in_out_sine"),
		K(60, "b_shelf_twist_a", "in_out_sine", face="smug"),
		K(84, "b_shelf_twist_b", "in_out_sine"),
		K(108, "b_shelf_twist_a", "in_out_sine"),
		K(132, "b_shelf_twist_b", "in_out_sine", face="irked"),
		K(150, "b_shelf_twist_a", "out_back", face="smug", set_={"head": {"rot": -14}}),
		K(170, "b_shelf_twist_b", "in_out_sine", face="pompous"),
		K(200, "b_shelf_reach", "in_out_sine"),
		K(236, "b_stand", "in_out_sine", face="smug"),
		K(268, "b_stand", "in_out_sine", set_={"head": {"rot": -8}, "torso": {"rot": -3}}),
		K(300, "b_stand", "in_out_sine", face="pompous"),
	]
	pin(keys, stance("b_stand"))
	events = [E(60, "sfx", id="jar"), E(84, "sfx", id="lid", vol_db=-4.0), E(108, "sfx", id="lid", vol_db=-6.0),
			  E(170, "sfx", id="lid", vol_db=-4.0), E(200, "sfx", id="jar", vol_db=-3.0)]
	return clip("act_pickles", 300, keys, events, loop=True, blend_in=6, blend_out=6, tags=["activity", "pickles"],
				doc=pickles.__doc__)


def rinse():
	"""300 f loop at the sink (facing +1): hands in the basin scrubbing the cup, the cup held up to the window and
	inspected, shaken dry, back in for another go. mg_gargle_hum plays over the scrub at 2 s."""
	keys = [
		K(0, "b_sink_hands", "linear", face="neutral"),
		K(36, "b_sink_scrub", "in_out_sine"),
		K(72, "b_sink_hands", "in_out_sine"),
		K(108, "b_sink_scrub", "in_out_sine", face="pompous"),
		K(150, "b_rinse_lift", "in_out_sine", face="smug"),
		K(186, "b_rinse_lift", "in_out_sine", set_={"head": {"rot": -16}}, face="suspicious"),
		K(206, "b_rinse_shake", "out_quad", face="smug"),
		K(214, "b_rinse_lift", "in_out_sine", set_={"root": root_of("b_rinse_lift", rot=-2)}),
		K(222, "b_rinse_shake", "in_out_sine"),
		K(260, "b_sink_hands", "in_out_sine", face="neutral"),
		K(280, "b_sink_hands", "in_out_sine", set_={"head": {"rot": 22}, "torso": {"rot": 16}}),
		K(300, "b_sink_hands", "in_out_sine"),
	]
	pin(keys, stance("b_sink_hands"))
	events = [
		E(0, "prop", op="attach", prop="teacup", socket="hand_r:grip"),
		E(0, "prop", op="state", prop="teacup", state="held"),
		E(36, "sfx", id="splash", vol_db=-6.0), E(108, "sfx", id="splash", vol_db=-8.0),
		E(206, "fx", id="drops", part="hand_r", dir=[0.5, 1.0], amount=8), E(206, "sfx", id="splash", vol_db=-12.0),
		E(260, "sfx", id="teacup_clink", vol_db=-4.0),
	]
	return clip("act_rinse", 300, keys, events, loop=True, blend_in=6, blend_out=6, tags=["activity", "rinse"],
				doc=rinse.__doc__)


def paper():
	"""480 f loop reclined at st_recliner (facing +1), specs on, the paper held up: reads, flicks a page, peers over
	his specs at a review, reads on, flicks again, a breath. mg_tut at 2 s and mg_chuckle_at_own_photo at 7 s play
	over it; LIFT-OFF's lever pull starts from b_rec_sit."""
	keys = [
		K(0, "b_rec_sit", "linear", face="pompous"),
		K(48, "b_rec_sit", "in_out_sine", set_={"head": {"rot": 6}}),
		K(70, "b_rec_sit_b", "in_out_sine"),
		K(90, "b_rec_sit", "in_out_sine"),
		K(180, "b_rec_peer", "in_out_sine", face="suspicious"),
		K(200, "b_rec_peer", "in_out_sine", set_={"head": {"rot": 18}}),
		K(230, "b_rec_sit", "in_out_sine", face="pompous"),
		K(300, "b_rec_sit_b", "in_out_sine"),
		K(320, "b_rec_sit", "in_out_sine"),
		K(400, "b_rec_sit", "in_out_sine", face="smug", set_={"root": root_of("b_rec_sit", sy=1.01), "head": {"rot": -2}}),
		K(480, "b_rec_sit", "in_out_sine", face="pompous"),
	]
	events = [
		E(0, "prop", op="attach", prop="newspaper", socket="hand_r:grip"),
		E(0, "prop", op="state", prop="newspaper", state="open"),
		E(70, "sfx", id="paper_rustle"), E(300, "sfx", id="paper_rustle", vol_db=-3.0),
		E(180, "sfx", id="specs_tink", vol_db=-8.0),
	]
	return clip("act_paper", 480, keys, events, loop=True, blend_in=6, blend_out=6, tags=["activity", "paper", "recliner"],
				doc=paper.__doc__)


# ============================================================================ micro-gags (overlays, mask `upper`)
def micro_gags():
	C.mg("sniff_jar", 48, pin([
		K(0, "b_shelf_twist_a", "linear", face="smug"),
		K(10, "b_shelf_twist_b", "out_quad", face="sniff", set_={"head": {"rot": 14}}),
		K(20, "b_shelf_twist_b", "in_out_sine", face="sniff", set_={"head": {"rot": 18}, "nose": {"sx": 1.12}}),
		K(26, "b_shelf_strain_1", "pop", face="teary", set_={"head": {"rot": -22}}),
		K(36, "b_shelf_twist_a", "in_out_sine", face="disdain"),
		K(48, "b_shelf_twist_a", "in_out_sine", face="smug"),
	], stance("b_shelf_twist_a")), [E(10, "sfx", id="tea_sniff", vol_db=-3.0), E(26, "sfx", id="lid", vol_db=-6.0), E(26, "voice", id="vo_bellows_ugh", vol_db=-4.0)],
		doc="Unscrews the jar an inch, sniffs, his eyes water, screws it back tight.")
	C.mg("gargle_hum", 60, [
		K(0, "b_sink_scrub", "linear", face="neutral"),
		K(10, "b_rinse_lift", "out_quad", face="sip", set_={"head": {"rot": -26}}),
		K(20, "b_rinse_lift", "in_out_sine", face="hum", set_={"head": {"rot": -30}}),
		K(30, "b_rinse_lift", "in_out_sine", face="hum", set_={"head": {"rot": -26}, "nose": {"sx": 1.06}}),
		K(40, "b_rinse_lift", "in_out_sine", face="sing_small", set_={"head": {"rot": -32}}),
		K(46, "b_sink_scrub", "pop", face="disdain", set_={"head": {"rot": 22}}),
		K(60, "b_sink_scrub", "in_out_sine", face="pompous"),
	], [E(20, "voice", id="vo_bellows_hum"), E(46, "sfx", id="splash", vol_db=-6.0), E(46, "voice", id="vo_bellows_pff", vol_db=-3.0)],
		doc="Gargles a tune with the rinse water: a bubbly high note, then spits it out proudly.")
	C.mg("tut", 48, [
		K(0, "b_rec_sit", "linear", face="pompous"),
		K(8, "b_rec_sit", "out_quad", face="disdain", set_={"head": {"rot": 8}}),
		K(16, "b_rec_sit", "in_out_sine", face="disdain", set_={"head": {"rot": 4}}),
		K(24, "b_rec_sit", "in_out_sine", face="irked", set_={"head": {"rot": 10}}),
		K(32, "b_rec_sit_b", "out_back", face="furious"),
		K(48, "b_rec_sit", "in_out_sine", face="pompous"),
	], [E(8, "voice", id="vo_bellows_tut", vol_db=-2.0), E(16, "voice", id="vo_bellows_tut", vol_db=-1.0), E(24, "voice", id="vo_bellows_tut"),
		E(32, "sfx", id="paper_rustle")],
		doc="Reads a bad review: 'Tut. Tut. TUT!' and flicks the page at it.")
	C.mg("chuckle_at_own_photo", 48, [
		K(0, "b_rec_sit", "linear", face="pompous"),
		K(10, "b_rec_peer", "out_quad", face="admiring"),
		K(20, "b_rec_peer", "in_out_sine", face="kiss", set_={"head": {"rot": 20}}),
		K(28, "b_rec_sit", "out_back", face="sly_smile"),
		K(36, "b_rec_sit", "in_out_sine", face="sly_smile", set_={"root": root_of("b_rec_sit", sy=0.985)}),
		K(48, "b_rec_sit", "in_out_sine", face="smug"),
	], [E(20, "sfx", id="kiss_smack", vol_db=-4.0), E(28, "voice", id="vo_bellows_hah", vol_db=-3.0)],
		doc="Finds his own photo, kisses it, and chuckles behind the paper.")


# ============================================================================ squeak bits (base layer, sim-locked)
def bits():
	bits_db = json.load(open(C.os.path.join(C.REPO, "game", "data", "activities.json")))["squeak_bits"]
	# bit_tea (100 f): a squeak mid-sip -- tea goes up his nose: SNORT, splutter, dab, dignity
	n = bits_db["bit_tea"]["len_f"]
	clip("bit_tea", n, [
		K(0, "b_stool_sip", "linear", face="sip"),
		K(6, "b_stool_sip_hold", "in_out_sine"),
		K(10, "b_stool_snort", "pop", face="sneeze_gasp"),
		K(14, "b_stool_snort", "linear", set_={"root": root_of("b_stool_snort", sx=1.0, sy=1.0)}),
		K(24, "b_stool_splutter", "out_quad", face="disdain"),
		K(34, "b_stool_splutter", "in_out_sine", set_={"head": {"rot": 24}}),
		K(44, "b_stool_splutter", "in_out_sine", set_={"head": {"rot": 14}, "nose": {"sx": 1.08}}),
		K(60, "b_stool_sit", "in_out_sine", face="irked"),
		K(78, "b_stool_sit_b", "in_out_sine", face="pompous", set_={"head": {"rot": -14}}),
		K(n, "b_stool_sit", "in_out_sine"),
	], [
		E(0, "prop", op="attach", prop="teacup", socket="hand_r:grip"), E(0, "prop", op="state", prop="teacup", state="sip"),
		E(10, "sfx", id="spray_blast", vol_db=-10.0), E(10, "fx", id="drops", part="nose", dir=[1.0, 0.3], amount=12),
		E(14, "voice", id="vo_bellows_ugh"), E(24, "sfx", id="sniffle", vol_db=-4.0), E(44, "sfx", id="sniffle", vol_db=-6.0),
	], tags=["bit", "tea", "stool"], blend_in=4, blend_out=8, smear=True,
		doc="Squeak bit (tea): a squeak mid-sip sends the tea up his nose: SNORT (f10), a splutter and a dab (24-44), "
			"back to pompous. 100 f = squeak_bits.bit_tea.len_f.")
	# bit_paper (80 f): the squeak makes him rip the newspaper clean in half
	n = bits_db["bit_paper"]["len_f"]
	clip("bit_paper", n, [
		K(0, "b_rec_sit", "linear", face="pompous"),
		K(8, "b_rec_sit", "out_quad", face="irked", set_={"head": {"rot": -6}}),
		K(16, "b_rec_rip_a", "in_out_sine", face="furious"),
		K(22, "b_rec_rip_a", "linear", set_={"root": root_of("b_rec_rip_a", sx=0.98, sy=1.02)}),
		K(24, "b_rec_rip_b", "pop", face="furious"),
		K(28, "b_rec_rip_b", "linear", set_={"root": root_of("b_rec_rip_b", sx=1.0, sy=1.0)}),
		K(40, "b_rec_rip_b", "in_out_sine", face="huh", set_={"head": {"rot": 16}}),
		K(52, "b_rec_rip_b", "in_out_sine", face="huh", set_={"head": {"rot": -10}}),
		K(66, "b_rec_sit", "in_out_sine", face="disdain"),
		K(n, "b_rec_sit", "in_out_sine", face="pompous"),
	], [
		E(0, "prop", op="attach", prop="newspaper", socket="hand_r:grip"), E(0, "prop", op="state", prop="newspaper", state="open"),
		E(16, "sfx", id="paper_rustle", vol_db=-4.0),
		E(24, "sfx", id="paper_rip"), E(24, "prop", op="hide", prop="newspaper"), E(25, "smear", part="arm_upper_r", frames=2, stretch=1.4),
		E(40, "voice", id="vo_bellows_huh", vol_db=-3.0),
		E(66, "prop", op="attach", prop="newspaper", socket="hand_r:grip"), E(66, "prop", op="state", prop="newspaper", state="open"),
	], tags=["bit", "paper", "recliner"], blend_in=4, blend_out=8, smear=True,
		doc="Squeak bit (paper): the squeak makes him rip the newspaper clean in half (f24), stare at the halves, "
			"and pretend it was deliberate. 80 f = squeak_bits.bit_paper.len_f.")
	# bit_warmup (90 f): the high note cracks into a yodel; he clutches his throat: '...the pipes.'
	n = bits_db["bit_warmup"]["len_f"]
	keys = [
		K(0, "b_warm_hold", "linear", face="sing_big"),
		K(6, "b_warm_hold_b", "in_out_sine"),
		K(12, "b_warm_hold", "in_out_sine", set_={"head": {"rot": -24}}),
		K(16, "b_sing_crack", "pop", face="shock"),
		K(20, "b_sing_crack", "linear", set_={"root": root_of("b_sing_crack", sx=1.0, sy=1.0)}),
		K(32, "b_sing_crack", "in_out_sine", face="huh", set_={"head": {"rot": 10}}),
		K(44, "b_look_behind", "in_out_sine", face="suspicious"),
		K(58, "b_look_behind", "in_out_sine", set_={"head": {"rot": 4}}),
		K(70, "b_warm_rest", "in_out_sine", face="smug"),
		K(n, "b_warm_rest", "in_out_sine", face="pompous", set_={"head": {"rot": -8}}),
	]
	pin(keys, stance("b_warm_hold"))
	clip("bit_warmup", n, keys, [
		E(0, "voice", id="vo_bellows_warmup_3"), E(16, "voice", id="vo_bellows_warmup_crack"),
		E(16, "spring", part="bouffant", kick=24.0), E(17, "smear", part="head", frames=2, stretch=1.3),
		E(44, "voice", id="vo_bellows_the_pipes"),
	], tags=["bit", "warmup"], blend_in=4, blend_out=8, smear=True, plant=True,
		doc="Squeak bit (warm-up): his top note cracks into a yodel (f16), he clutches his throat, looks round "
			"('...the pipes.'), and resumes as if nothing happened. 90 f = squeak_bits.bit_warmup.len_f.")


MAP_KEYS = {
	"activity:pickles": "bellows/act_pickles", "activity:rinse": "bellows/act_rinse", "activity:paper": "bellows/act_paper",
	"mg:sniff_jar": "bellows/mg_sniff_jar", "mg:gargle_hum": "bellows/mg_gargle_hum", "mg:tut": "bellows/mg_tut",
	"mg:chuckle_at_own_photo": "bellows/mg_chuckle_at_own_photo",
	"bit:bit_tea": "bellows/bit_tea", "bit:bit_paper": "bellows/bit_paper", "bit:bit_warmup": "bellows/bit_warmup",
}


def build():
	drench()
	sing_crack()
	strain_slip()
	launch_ceiling()
	dizzy_spin()
	pickles()
	rinse()
	paper()
	micro_gags()
	bits()
