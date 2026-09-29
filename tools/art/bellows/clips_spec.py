#!/usr/bin/env python3
"""Bellows clips (TECH §4.8) + map.json (s2-view §4.1.1 schema) — the Phase-G set of s2-anim-bellows.

    python3 tools/art/bellows/clips_spec.py [--review-dir=<dir>]

Writes game/data/anim/bellows/<clip>.json and map.json (deterministic). Run after build.py (it reads the built
poses.json / rig.json for the computed flight arc and the stool's hop home). With --review-dir it also writes
`rx_sneeze_blast_a.json` there with the sim's reaction travel (reactions.json `travel`, x 3000 -> 3760) baked into
root x, for AnimViewer shots in the real kitchen (the game adds that travel from the sim; the clip must not).

Sound events are the rows of docs/review/s2-sound/clip_events.md (s2-sound's frame table, ruling L12) placed on
this clip's contact frames.
"""
import json
import math
import os
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fk  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(REPO, "game", "data", "anim", "bellows")
REACTIONS = os.path.join(REPO, "game", "data", "reactions.json")

CLIPS = {}
HOP_VY = 150.0     # the stool rebounds off the sink cabinet slightly downward: three quick hops home


def K(f, pose, ease="linear", face=None, set_=None):
	k = {"f": f, "pose": pose, "ease": ease}
	if face:
		k["face"] = face
	if set_:
		k["set"] = set_
	return k


def E(f, type_, **kw):
	e = {"f": f, "type": type_}
	e.update(kw)
	return e


def clip(name, length, keys, events=(), *, loop=False, layer="base", mask=None, blend_in=None, blend_out=None,
		 beats=None, tags=(), plant=False, stride=None, doc="", variation=None, smear=False, touch_legs=False):
	d = {"version": 1, "clip": "bellows/" + name, "rig": "bellows", "loop": loop, "length": length, "layer": layer,
		 "mask": mask}
	if doc:
		d["doc"] = doc
	if blend_in is not None:
		d["blend_in"] = blend_in
	if blend_out is not None:
		d["blend_out"] = blend_out
	if stride is not None:
		d["stride_px"] = stride
	if beats:
		d["beats"] = beats
	d["tags"] = list(tags)
	if plant:
		d["plant"] = True
	if touch_legs:
		d["touch_legs"] = True
	d["variation"] = variation or {"time_jitter": 0.0, "rot_jitter": 0.0}
	d["smear"] = {"auto": bool(smear)}
	d["keys"] = keys
	d["events"] = sorted(events, key=lambda e: e["f"])
	CLIPS[name] = d
	return d


# ============================================================================ geometry from the built rig
RIG = fk.load()
RIGJ = json.load(open(os.path.join(REPO, "game", "data", "rigs", "bellows", "rig.json")))


def pose_root(name):
	return dict(RIG.pose(name)["root"])


def seat_root(name, sx, sy):
	"""Root x / y so pose `name`'s barrel bottom (placed on the stool seat (0, -150) by poses_s2.SEAT_AT) sits at
	(sx, sy) instead: a pure translation of the pose."""
	r = pose_root(name)
	return {"x": round(r.get("x", 0) + sx, 1), "y": round(r.get("y", 0) + sy + 150.0, 1)}


# PropSim port (game/view/rig/prop_sim.gd): closed-form ballistic with floor bounces
G, REST, FRIC, SPIN_KEEP, MAXB, MINVY = 2600.0, 0.42, 0.6, 0.5, 2, 120.0


def ballistic(p, v, rot, spin, t, floor_y):
	pos, vel, r, sp, left = list(p), list(v), rot, spin, t
	for b in range(MAXB + 1):
		a = 0.5 * G
		bb, c = vel[1], pos[1] - floor_y
		disc = bb * bb - 4 * a * c
		tau = math.inf
		if disc >= 0:
			root = (-bb + math.sqrt(disc)) / (2 * a)
			if root > 1e-5:
				tau = root
		if left <= tau:
			return (pos[0] + vel[0] * left, pos[1] + vel[1] * left + a * left * left, r + sp * left, False)
		pos = [pos[0] + vel[0] * tau, floor_y]
		r += sp * tau
		vy = vel[1] + G * tau
		left -= tau
		if b >= MAXB or vy * REST < MINVY:
			return (pos[0], floor_y, r, True)
		vel = [vel[0] * FRIC, -vy * REST]
		sp *= SPIN_KEEP
	return (pos[0], floor_y, r, True)


def rest_time(p, v, floor_y):
	lo, hi = 0.0, 5.0
	for _ in range(60):
		m = (lo + hi) / 2
		if ballistic(p, v, 0, 0, m, floor_y)[3]:
			hi = m
		else:
			lo = m
	return hi


def solve_hop(start, rot0, target_x, vy, floor_y, flips=1):
	"""vx and spin so a prop launched from `start` at rot0 comes to rest at target_x, upright (rot = 360 * flips)."""
	t_rest = rest_time(start, (0.0, vy), floor_y)
	x1 = ballistic(start, (1.0, vy), 0, 0, t_rest + 1, floor_y)[0] - start[0]      # distance per unit vx
	vx = (target_x - start[0]) / x1
	r1 = ballistic(start, (vx, vy), 0, 1.0, t_rest + 1, floor_y)[2]                  # rotation per unit spin
	spin = (360.0 * flips - rot0) / r1
	return vx, spin, t_rest


def socket_xf(pose_name, root_over, socket):
	"""(x, y, rot°) of a torso socket in char space for pose_name with root overrides."""
	import copy
	pose = copy.deepcopy(RIG.pose(pose_name))
	pose["root"].update(root_over or {})
	_M0, W = RIG.solve(pose)
	part, sk = socket.split(":")
	s = RIGJ["parts"][part]["sockets"][sk]
	pv = RIGJ["parts"][part]["pivot"]
	m = fk.mul(W[part], fk.T(s[0] - pv[0], s[1] - pv[1]))
	o = fk.apply(m, (0, 0))
	ang = math.degrees(math.atan2(m[1], m[0]))
	return o[0], o[1], ang


# ============================================================================ ACHOO-RIA!
def sneeze():
	rx = json.load(open(REACTIONS))["archetypes"]["sneeze_blast_a"]
	tr = rx["travel"]
	f0, f1, arc = tr["from_f"], tr["to_f"], tr["arc_px"]
	seat0, seat1 = (0.0, -150.0), (-28.0, -214.0)

	def seat_at(f):
		s = (f - f0) / float(f1 - f0)
		x = seat0[0] + (seat1[0] - seat0[0]) * s
		y = seat0[1] + (seat1[1] - seat0[1]) * s - 4 * arc * s * (1 - s)
		return x, y

	keys = [
		# ah (0-20): the "Ahhh" after the sip, a nose twitch, the head tipping back
		K(0, "b_stool_ahh", "linear", face="sip"),
		K(8, "b_stool_ahh", "out_quad", face="sneeze_build", set_={"nose": {"rot": -8, "sx": 1.12}, "head": {"rot": -16}}),
		K(18, "b_stool_ah1", "in_out_sine"),
		# ahh (20-44): rocking back on the stool, chest swelling
		K(24, "b_stool_ah1", "in_out_sine", set_={"head": {"rot": -21}, "nose": {"rot": -12, "sx": 1.1}}),
		K(40, "b_stool_ah2", "in_out_sine", face="sneeze_build2"),
		K(46, "b_stool_ah2", "in_out_sine", set_={"head": {"rot": -27}, "nose": {"rot": -15, "sx": 1.15}}),
		# AHHH (44-74): right back, nose to the ceiling, trembling at the top
		K(64, "b_stool_ah3", "in_out_cubic", face="sneeze_build3"),
		K(67, "b_stool_ah3_b", "linear"),
		K(70, "b_stool_ah3", "linear"),
		K(72, "b_stool_ah3_b", "linear"),
		K(74, "b_stool_ah3", "linear"),
		# the false stop (74-94): phew... the cup goes back up for another sip -- HUP!
		K(82, "b_stool_relief", "out_quad", face="relief"),
		K(88, "b_stool_resip", "in_out_sine", face="smug"),
		K(93, "b_stool_hup", "out_quad", face="sneeze_gasp"),
		# CHOO (94-97)
		K(94, "b_stool_choo", "pop", face="sneeze_choo"),
	]
	# the flight (94-112): the sim carries x (reactions.json travel); the clip carries the arc and the tumble
	for f, pn, face in ((97, "b_fly_a", "wild_take"), (100, "b_fly_a", None), (103, "b_fly_b", None), (106, "b_fly_b", None),
						(109, "b_fly_b", None)):
		sx, sy = seat_at(f)
		keys.append(K(f, pn, "linear", face=face, set_={"root": seat_root(pn, sx, sy)}))
	keys += [
		# in the sink (97-145): SPLASH, stuck, slippers kicking, a dignified blind sip through the fringe, rinse
		K(112, "b_sink_land", "pop", face="dazed_open"),
		K(114, "b_sink_land", "linear"),
		K(119, "b_sink_sit", "out_quad"),
		K(124, "b_sink_kick_a", "in_out_sine"),
		K(128, "b_sink_kick_b", "in_out_sine"),
		K(132, "b_sink_kick_a", "in_out_sine"),
		K(137, "b_sink_sip", "in_out_sine", face="sip"),
		K(142, "b_sink_sip_b", "in_out_sine"),
		K(146, "b_sink_dunk", "in_quad", face="dazed"),
		# dazed (145-165): pops out like a cork, drops onto his feet, blind, arms out
		K(151, "b_sink_pop", "out_quad", face="dazed_open"),
		K(158, "b_blind_land", "in_quad", face="dazed"),
		K(165, "b_blind_stand", "out_back"),
	]
	# the stool hops home: launched off the sink cabinet at f113 (x no longer moves), lands upright on the decor's
	# pixels (world 3000 = char +760 from the landing x 3760), then the decor takes over
	sxy = socket_xf("b_sink_land", None, "torso:seat")
	stool = RIGJ["props"]["stool"]
	radius = max(stool["size"]) / 2.0
	home = 3760.0 - 3000.0
	vx, spin, t_rest = solve_hop((sxy[0], sxy[1]), sxy[2], home, HOP_VY, -radius, flips=1)
	land_f = 113 + int(math.ceil(t_rest * 60.0))
	cam = rx.get("cam", {})
	events = [
		E(0, "voice", id="vo_bellows_sneeze_ah1"),
		E(0, "prop", op="attach", prop="teacup", socket="hand_r:grip"),
		E(0, "prop", op="state", prop="teacup", state="sip"),
		E(0, "prop", op="state", prop="stool", state="under"),
		E(0, "decor", id="kitchen_stool", visible=False),
		E(1, "prop", op="detach", prop="stool"),
		E(20, "voice", id="vo_bellows_sneeze_ah2"),
		E(44, "voice", id="vo_bellows_sneeze_ah3"),
		E(76, "voice", id="vo_bellows_sneeze_hm"),
		E(94, "voice", id="vo_bellows_sneeze_choo"),
		E(94, "mark", name="accent"),
		E(94, "hitstop", frames=int(cam.get("hitstop", 5))),
		E(94, "cam", op="punch", zoom=float(cam.get("zoom", 1.4)), **{"in": 6, "hold": 40, "out": 20}),
		E(94, "shake", trauma=0.55),
		E(94, "fx", id="drops", part="nose", dir=[1.0, 0.25], amount=22),
		E(94, "prop", op="attach", prop="stool"),
		E(94, "prop", op="state", prop="stool", state="flying"),
		E(94, "spring", part="bouffant", kick=40.0),
		E(95, "sfx", id="stool_scrape"),
		E(96, "sfx", id="slide_up_flight"),
		E(96, "smear", part="head", frames=2, stretch=1.6),
		E(111, "decor", id="kitchen_sink_lip", visible=True),
		E(112, "sfx", id="sink_crash"),
		E(112, "mark", name="knock_on"),
		E(112, "shake", trauma=0.6),
		E(112, "fx", id="drops", part="torso", dir=[0.0, -1.0], amount=26),
		E(112, "spring", part="belly", kick=0.08),
		E(113, "prop", op="launch", prop="stool", vel=[round(vx, 1), HOP_VY], spin=round(spin, 1)),
		E(land_f, "prop", op="state", prop="stool", state="under"),
		E(142, "fx", id="drops", part="hand_r", dir=[0.0, 1.0], amount=10),
		E(147, "prop", op="hide", prop="teacup"),
		E(150, "decor", id="kitchen_sink_lip", visible=False),
		E(154, "sfx", id="ladle_spin", sync=False),
		E(max(land_f + 4, 158), "prop", op="hide", prop="stool"),
		E(max(land_f + 4, 158), "decor", id="kitchen_stool", visible=True),
		E(165, "mark", name="release"),
	]
	marks = rx["marks"]
	beats = {"anticipation": [marks["antic"], marks["accent"]], "accent": [marks["accent"], marks["hold"][0]],
			 "hold": [marks["hold"][0], marks["hold"][1]], "settle": [marks["hold"][1], rx["frames"]]}
	for bn, v in rx.get("beats", {}).items():
		beats[bn] = list(v)
	d = clip("rx_sneeze_blast_a", rx["frames"], keys, events, beats=beats, tags=["reaction", "take", "sneeze"],
			 blend_in=0, blend_out=10, smear=True, plant=True,
			 doc="ACHOO-RIA! (GDD §2.3, §5.7 #1). On the stool at st_tea facing -1: ah (0-20), ahh (20-44), AHHH "
				 "(44-74), the false stop and a smug re-sip (74-93), HUP, CHOO (94-97: head whipped down, barrel "
				 "blown back), rocketing backwards on the stool (the sim carries x 3000 -> 3760, the clip the %d px "
				 "arc) into the sink at 112 (knock_on: HOT & COLD's drench takes over from the in-sink pose), stuck "
				 "with slippers kicking, a blind dignified sip through the flipped fringe, rinses the cup, pops out "
				 "and lands dazed (145-165). The stool prop replaces the decor on the same pixels at f0/f1, rides "
				 "the flight, hops home from the sink at f113 and hands back to the decor at f%d." % (arc, max(land_f + 4, 158)))
	d["stool_hop"] = {"launch_f": 113, "vel": [round(vx, 1), HOP_VY], "spin": round(spin, 1), "rest_f": land_f,
					  "start": [round(sxy[0], 1), round(sxy[1], 1), round(sxy[2], 1)], "home_char_x": home}
	return d


def review_sneeze(d, out_dir):
	"""The sneeze with the sim's travel baked into root x (AnimViewer shots only)."""
	import copy
	rx = json.load(open(REACTIONS))["archetypes"]["sneeze_blast_a"]
	tr = rx["travel"]
	f0, f1 = tr["from_f"], tr["to_f"]
	dx = -(3760.0 - 3000.0)       # char space (facing -1): world +x = char -x
	ease = tr.get("ease", "linear")

	def e(s):
		if ease == "out_cubic":
			return 1 - (1 - s) ** 3
		if ease == "out_quad":
			return 1 - (1 - s) ** 2
		return s
	r = copy.deepcopy(d)
	for k in r["keys"]:
		f = k["f"]
		if f <= f0:
			continue
		s = min(1.0, (f - f0) / float(f1 - f0))
		base = k.get("set", {}).get("root", {})
		x = base.get("x", pose_root(k["pose"]).get("x", 0))
		y = base.get("y", pose_root(k["pose"]).get("y", 0))
		k.setdefault("set", {})["root"] = {"x": round(x + dx * e(s), 1), "y": y}
	r["doc"] = "REVIEW COPY (AnimViewer only): the sim's travel baked into root x. " + r["doc"]
	os.makedirs(out_dir, exist_ok=True)
	p = os.path.join(out_dir, "rx_sneeze_blast_a.json")
	with open(p, "w") as fh:
		fh.write(dumps(r))
	return p


# ============================================================================ the tea (act_tea)
def tea():
	"""480 f loop on the stool at st_tea (facing -1, on the house decor stool): the pour, the spoon, the sniff, the
	sip. The sip's lip contact at f388 (tea_slurp over by 7.0 s); at f420 (= 7.0 s = the ACHOO-RIA! trigger) he
	holds `b_stool_ahh`, the pose the sneeze starts from, so the sim-locked reaction never pops."""
	keys = [
		K(0, "b_stool_sit", "linear", face="pompous"),
		K(24, "b_stool_sit_b", "in_out_sine"),
		K(40, "b_stool_pour_a", "in_out_sine", face="smug"),
		K(62, "b_stool_pour_b", "in_out_sine"),
		K(84, "b_stool_pour_a", "in_out_sine"),
		K(100, "b_stool_pour_b", "in_out_sine"),
		K(118, "b_stool_sit", "in_out_sine", face="pompous"),
		K(148, "b_stool_sit_b", "in_out_sine"),
		K(170, "b_stool_stir_a", "in_out_sine", face="smug"),
		K(182, "b_stool_stir_b", "in_out_sine"),
		K(194, "b_stool_stir_a", "in_out_sine"),
		K(206, "b_stool_stir_b", "in_out_sine"),
		K(218, "b_stool_stir_a", "in_out_sine"),
		K(230, "b_stool_stir_b", "in_out_sine"),
		K(242, "b_stool_stir_a", "out_back"),
		K(254, "b_stool_cup", "in_out_sine"),
		K(270, "b_stool_sniff", "in_out_sine", face="sniff"),
		K(284, "b_stool_sniff_b", "out_quad", face="suspicious"),
		K(292, "b_stool_sniff", "in_out_sine", face="sniff"),
		K(306, "b_stool_savour_a", "in_out_sine", face="hum"),
		K(330, "b_stool_savour_b", "in_out_sine"),
		K(354, "b_stool_savour_a", "in_out_sine"),
		K(374, "b_stool_cup", "in_out_sine", face="smug"),
		K(388, "b_stool_sip", "out_quad", face="sip"),
		K(399, "b_stool_sip_hold", "in_out_sine"),
		K(410, "b_stool_sip", "in_out_sine"),
		K(420, "b_stool_ahh", "in_out_sine"),
		K(431, "b_stool_ahh_b", "in_out_sine"),
		K(442, "b_stool_ahh", "in_out_sine"),
		K(462, "b_stool_cup", "in_out_sine", face="pompous"),
		K(480, "b_stool_sit", "in_out_sine"),
	]
	events = [
		E(0, "prop", op="attach", prop="teacup", socket="hand_r:grip"),
		E(0, "prop", op="state", prop="teacup", state="sip"),
		E(40, "sfx", id="kettle_pour"),
		E(169, "sfx", id="spoon_clink"),
		E(182, "sfx", id="tea_stir"),
		E(243, "sfx", id="spoon_clink", vol_db=-3.0),
		E(270, "sfx", id="tea_sniff"),
		E(388, "sfx", id="tea_slurp"),
		E(462, "sfx", id="teacup_clink"),
		E(472, "sfx", id="stool_creak", vol_db=-2.0, sync=False),
	]
	return clip("act_tea", 480, keys, events, loop=True, blend_in=6, blend_out=6, tags=["activity", "tea", "stool"],
				doc=tea.__doc__)


# ============================================================================ the warm-up (act_warmup)
def warmup():
	"""1200 f loop (20 s = the warm-up's mg_cycle_s, phase-locked to the activity start) at the gramophone (facing
	-1, his back to the kitchen): phrase 1 'mi-mi-mi-mi-MIIII' at f0 (a conducting bounce on each note: the vase
	nudges), the held top note with vibrato, a smug listening rest; phrase 2 'la-la-LAAA' at f600 (10 s apart, clear
	of the micro-gags at 2 / 7 / 12 / 17 s -- s2-sound's clip_events.md), rest, and the big inhale back into f0."""
	keys = [K(0, "b_sing_small", "linear", face="sing_small")]
	for i, f in enumerate((5, 15, 25, 35)):
		keys.append(K(f, "b_conduct_down" if i % 2 == 0 else "b_conduct_up", "out_quad", face="sing_mid" if i % 2 else "sing_small"))
		keys.append(K(f + 5, "b_conduct_up" if i % 2 == 0 else "b_conduct_down", "in_out_sine"))
	keys += [
		K(46, "b_warm_hold", "out_quad", face="sing_big"),
		K(54, "b_warm_hold_b", "in_out_sine"), K(62, "b_warm_hold", "in_out_sine"), K(70, "b_warm_hold_b", "in_out_sine"),
		K(78, "b_warm_hold", "in_out_sine"), K(86, "b_warm_hold_b", "in_out_sine"), K(94, "b_warm_hold", "in_out_sine"),
		K(112, "b_warm_rest", "out_back", face="smug"),
	]
	f = 112
	i = 0
	while f + 50 <= 560:
		f += 50
		keys.append(K(f, "b_warm_rest_b" if i % 2 == 0 else "b_warm_rest", "in_out_sine",
					  face=("admiring" if i % 3 == 1 else "smug") if i % 2 == 0 else None))
		i += 1
	keys += [
		K(586, "b_sing_breath", "in_out_sine", face="inhale"),
		K(600, "b_sing_small", "out_quad", face="sing_small"),
	]
	for f2 in (604, 616):
		keys.append(K(f2, "b_conduct_down", "out_quad", face="sing_mid"))
		keys.append(K(f2 + 6, "b_conduct_up", "in_out_sine"))
	keys += [
		K(628, "b_warm_hold", "out_quad", face="sing_big"),
		K(636, "b_warm_hold_b", "in_out_sine"), K(644, "b_warm_hold", "in_out_sine"), K(652, "b_warm_hold_b", "in_out_sine"),
		K(660, "b_warm_hold", "in_out_sine"), K(668, "b_warm_hold_b", "in_out_sine"), K(676, "b_warm_hold", "in_out_sine"),
		K(696, "b_warm_rest", "out_back", face="smug"),
	]
	f = 696
	i = 0
	while f + 50 <= 1150:
		f += 50
		keys.append(K(f, "b_warm_rest_b" if i % 2 == 0 else "b_warm_rest", "in_out_sine",
					  face=("admiring" if i % 3 == 1 else "smug") if i % 2 == 0 else None))
		i += 1
	keys += [
		K(1186, "b_sing_breath", "in_out_sine", face="inhale"),
		K(1200, "b_sing_small", "out_quad", face="sing_small"),
	]
	events = [E(0, "voice", id="vo_bellows_warmup_1")]
	for f3 in (5, 15, 25, 35, 46):
		events.append(E(f3, "sfx", id="vase_nudge"))
	events.append(E(600, "voice", id="vo_bellows_warmup_3"))
	for f3 in (604, 616, 628):
		events.append(E(f3, "sfx", id="vase_nudge"))
	return clip("act_warmup", 1200, keys, events, loop=True, blend_in=8, blend_out=8, tags=["activity", "warmup"],
				doc=warmup.__doc__)


# ============================================================================ micro-gags (overlays, mask `upper`)
def mg(name, length, keys, events=(), doc=""):
	return clip("mg_" + name, length, keys, events, layer="overlay", mask="upper", blend_in=6, blend_out=6,
				tags=["micro_gag", "overlay"], doc=doc)


def micro_gags():
	# the warm-up (standing at the gramophone)
	mg("admire_reflection_horn", 60, [
		K(0, "b_warm_rest", "linear", face="smug"),
		K(10, "b_mg_horn_lean", "out_back", face="admiring"),
		K(22, "b_mg_horn_lean_b", "in_out_sine"),
		K(34, "b_mg_kiss", "out_quad", face="kiss"),
		K(42, "b_mg_kiss_throw", "out_back", face="admiring"),
		K(60, "b_warm_rest", "in_out_sine", face="smug"),
	], [E(6, "sfx", id="glint", sync=False), E(14, "voice", id="vo_bellows_smug"), E(42, "sfx", id="kiss_smack")],
		doc="Leans his head into the gramophone horn, admires himself in the brass, blows it a kiss.")
	trill = [K(0, "b_warm_rest", "linear", face="smug"), K(6, "b_mg_trill", "out_quad", face="trill")]
	for i, f in enumerate(range(9, 36, 3)):
		trill.append(K(f, "b_mg_trill_b" if i % 2 == 0 else "b_mg_trill", "linear"))
	trill += [K(38, "b_mg_throat_tap", "out_quad", face="admiring"), K(48, "b_warm_rest", "in_out_sine", face="smug")]
	mg("trill", 48, trill, [E(0, "voice", id="vo_bellows_trill"), E(30, "sfx", id="teacups_rattle")],
	   doc="A motorboat lip-trill, head vibrating, then taps his throat, delighted.")
	mg("conduct_air", 60, [
		K(0, "b_mg_conduct_up", "linear", face="sing_small"),
		K(5, "b_mg_conduct_down", "out_quad"), K(15, "b_mg_conduct_up", "in_out_sine"),
		K(20, "b_mg_conduct_down", "out_quad"), K(30, "b_mg_conduct_flourish", "out_back", face="smug"),
		K(42, "b_mg_bow_head", "in_out_sine", face="pompous"),
		K(52, "b_mg_bow_head", "linear"),
		K(60, "b_warm_rest", "in_out_sine", face="smug"),
	], [E(5, "sfx", id="baton_swish"), E(20, "sfx", id="baton_swish", vol_db=-2.0), E(30, "sfx", id="baton_swish"),
		E(42, "sfx", id="bow_creak", vol_db=-4.0)],
		doc="Conducts an invisible orchestra with his pinkie as a baton, then bows his head to it.")
	hum = [K(0, "b_warm_rest", "linear", face="hum")]
	for i, f in enumerate(range(6, 46, 10)):
		hum.append(K(f, "b_mg_sway_a" if i % 2 == 0 else "b_mg_sway_b", "in_out_sine"))
	hum.append(K(48, "b_warm_rest", "in_out_sine", face="smug"))
	mg("hum", 48, hum, [E(0, "voice", id="vo_bellows_hum")],
	   doc="Hums along, eyes shut, head swaying like a metronome, a finger keeping time.")
	# the tea (seated; the overlay drives head, arms and face only)
	mg("admire_in_kettle", 48, [
		K(0, "b_stool_cup", "linear", face="smug"),
		K(8, "b_mg_kettle_peek", "out_quad", face="admiring"),
		K(16, "b_mg_kettle_pat", "in_out_sine"),
		K(21, "b_mg_kettle_pat_b", "out_quad"),
		K(26, "b_mg_kettle_pat", "in_out_sine"),
		K(31, "b_mg_kettle_pat_b", "out_quad"),
		K(38, "b_mg_kettle_wink", "in_out_sine", face="sly_smile"),
		K(48, "b_stool_cup", "in_out_sine", face="smug"),
	], [E(6, "sfx", id="glint", sync=False), E(14, "voice", id="vo_bellows_smug")],
		doc="Catches his reflection in the kettle, pats his bouffant with his cup hand, winks at it.")
	pk = [K(0, "b_stool_ahh", "linear", face="sip"), K(10, "b_mg_pinkie", "out_back", face="sip")]
	for i, f in enumerate(range(14, 38, 4)):
		pk.append(K(f, "b_mg_pinkie_b" if i % 2 == 0 else "b_mg_pinkie", "linear"))
	pk += [K(40, "b_mg_pinkie", "in_out_sine", face="blissful"), K(48, "b_stool_ahh", "in_out_sine", face="sip")]
	mg("pinkie_up", 48, pk, [E(10, "sfx", id="teacup_clink"), E(14, "sfx", id="pinkie_wobble"), E(30, "voice", id="vo_bellows_bliss")],
	   doc="The cup at his lips, the pinkie cocked so high it wobbles; eyes shut: 'Ahhh.'")


# ============================================================================ locomotion, idle, bonks
def loco():
	idle = [
		K(0, "b_idle_lapel", "linear", face="pompous"),
		K(40, "b_idle_lapel_b", "in_out_sine"), K(80, "b_idle_lapel", "in_out_sine"),
		K(120, "b_idle_lapel_b", "in_out_sine", face="smug"),
		K(150, "b_idle_lapel", "in_out_sine", face="pompous"),
		K(162, "b_idle_tug", "in_out_sine"),
		K(170, "b_idle_tug_b", "out_back"),
		K(178, "b_idle_tug", "in_out_sine"),
		K(186, "b_idle_tug_b", "out_back"),
		K(200, "b_idle_lapel_b", "in_out_sine", face="smug"),
		K(240, "b_idle_lapel", "in_out_sine", face="pompous"),
	]
	clip("loco_idle", 240, idle, [E(170, "sfx", id="cravat_tug", vol_db=-4.0)], loop=True, blend_in=8, blend_out=8,
		 tags=["loco", "idle"],
		 doc="Pompous idle: thumb in his lapel, belly breathing, a smug look; the cravat-tug fidget (two tugs).")
	strut = []
	for f in range(32):
		strut.append(K(f, ("b_strut_%d" % f) if f < 16 else ("b_strut_m%d" % (f - 16)), "linear", face="pompous" if f == 0 else None))
	strut.append(K(32, "b_strut_0", "linear"))
	clip("loco_strut", 32, strut, [E(0, "sfx", id="bellows_step", vol_db=-2.0), E(16, "sfx", id="bellows_step", vol_db=-2.0)],
		 loop=True, blend_in=6, blend_out=6, stride=128.0, tags=["loco", "walk", "strut"],
		 doc="The strut (lead ruling L3): a pompous scurry, 16 f per step, 64 px per step, 128 px per loop = 240 "
			 "px/s with the feet planted; knee hoisted high, chin up, chest out, belly bouncing twice per loop.")
	sh = []
	for f in range(24):
		sh.append(K(f, ("b_shuffle_%d" % f) if f < 12 else ("b_shuffle_m%d" % (f - 12)), "linear", face="huh" if f == 0 else None))
	sh.append(K(24, "b_shuffle_0", "linear"))
	clip("loco_blind_shuffle", 24, sh, [E(0, "sfx", id="slipper_scuff"), E(12, "sfx", id="slipper_scuff", vol_db=-2.0)],
		 loop=True, blend_in=6, blend_out=6, stride=96.0, tags=["loco", "walk", "blind"],
		 doc="FRAZZLED and blind: zombie arms out groping, head poking ahead, short quick shuffling steps (12 f, "
			 "48 px each, 96 px per loop = 240 px/s), slippers barely lifting. The bouffant flip is the residue's.")
	clip("loco_turn", 6, [K(0, "b_idle_lapel", "linear", face="irked"), K(3, "b_turn_hmph", "out_quad"),
						  K(6, "b_idle_lapel", "out_back", face="pompous")],
		 tags=["loco", "turn"], blend_in=2, blend_out=4,
		 doc="A 6-f harrumph turn over RigPlayer.set_facing: squashes tall, chin up, 'hmph'.")
	clip("cue_doorframe_bonk", 36, [
		K(0, "b_blind_stand", "linear", face="huh"),
		K(3, "b_blind_lean", "in_quad"),
		K(4, "b_blind_bonk", "pop", face="shock"),
		K(10, "b_blind_bonk_b", "out_quad"),
		K(18, "b_blind_rub", "in_out_sine", face="dazed"),
		K(24, "b_blind_rub_b", "in_out_sine"),
		K(30, "b_blind_rub", "in_out_sine"),
		K(36, "b_blind_stand", "in_out_sine", face="huh"),
	], [E(4, "sfx", id="woodblock_bonk"), E(7, "voice", id="vo_bellows_oof", vol_db=-2.0), E(4, "spring", part="bouffant", kick=30.0)],
		layer="overlay", mask="upper", blend_in=4, blend_out=6, tags=["cue", "overlay", "blind"],
		doc="The laugh_doorframe director cue (GDD §2.3 ~29 s): over the blind shuffle his head meets the door "
			"frame -- BONK -- he rocks back, rubs his forehead, gropes on.")
	clip("st_bonk", 60, [
		K(0, "b_bonk_flat", "pop", face="shock"),
		K(6, "b_bonk_back", "out_quad", face="dazed"),
		K(16, "b_reel_a", "in_out_sine"),
		K(28, "b_reel_b", "in_out_sine"),
		K(40, "b_reel_a", "in_out_sine"),
		K(52, "b_reel_c", "in_out_sine"),
		K(60, "b_reel_c", "linear"),
	], [E(0, "sfx", id="woodblock_bonk"), E(0, "shake", trauma=0.35), E(6, "sfx", id="dizzy_tweets", vol_db=-3.0, sync=False),
		E(0, "spring", part="bouffant", kick=36.0)],
		tags=["state", "bonk", "take"], blend_in=0, blend_out=8, plant=True,
		doc="The door-slam bonk (1 s stun; also the curtain-call bonk): pancaked on the door at f0, knocked back, "
			"reels with stars (6-60), shakes it off.")


# ============================================================================ map.json
def map_json():
	return {
		"version": 1, "rig": "bellows",
		"doc": ("s2-anim-bellows' clip map in the s2-view §4.1.1 schema: wins key by key over "
				"view/world/default_maps/bellows.json (every key left out falls back to it). Phase G set."),
		"cadence": {"walk": {"clip": "bellows/loco_strut", "f_per_step": 16, "step_px": 64, "stride_px": 128,
							 "speed_px_s": 240, "note": "lead ruling L3: feet planted at 240 px/s"},
					"walk@blind": {"clip": "bellows/loco_blind_shuffle", "f_per_step": 12, "step_px": 48, "stride_px": 96,
								   "speed_px_s": 240}},
		"idle": "bellows/loco_idle",
		"walk": {"clip": "bellows/loco_strut", "stride_px": 128, "speed_px_s": 240},
		"walk@blind": {"clip": "bellows/loco_blind_shuffle", "stride_px": 96, "speed_px_s": 240},
		"turn": "bellows/loco_turn",
		"activity:warmup": "bellows/act_warmup",
		"activity:tea": "bellows/act_tea",
		"mg:admire_reflection_horn": "bellows/mg_admire_reflection_horn",
		"mg:trill": "bellows/mg_trill",
		"mg:conduct_air": "bellows/mg_conduct_air",
		"mg:hum": "bellows/mg_hum",
		"mg:admire_in_kettle": "bellows/mg_admire_in_kettle",
		"mg:pinkie_up": "bellows/mg_pinkie_up",
		"oneshot:stun": "bellows/st_bonk",
		"cue:laugh_doorframe": "bellows/cue_doorframe_bonk",
		"reaction": "<from sim>",
		"reaction_fallback": "bellows/st_bonk",
	}


def dumps(d):
	"""Compact, one key / event per line (diff-friendly, small)."""
	head = {k: v for k, v in d.items() if k not in ("keys", "events")}
	s = json.dumps(head, separators=(",", ":"), ensure_ascii=False)[:-1]
	if "keys" in d:
		s += ',\n"keys":[\n' + ",\n".join(json.dumps(k, separators=(",", ":")) for k in d["keys"]) + "\n]"
	if "events" in d:
		s += ',\n"events":[\n' + ",\n".join(json.dumps(e, separators=(",", ":")) for e in d["events"]) + "\n]"
	return s + "}\n"


def main():
	review = None
	for a in sys.argv[1:]:
		if a.startswith("--review-dir="):
			review = a.split("=", 1)[1]
	d = sneeze()
	tea()
	warmup()
	micro_gags()
	loco()
	os.makedirs(OUT, exist_ok=True)
	for name, c in sorted(CLIPS.items()):
		with open(os.path.join(OUT, name + ".json"), "w") as fh:
			fh.write(dumps(c))
	with open(os.path.join(OUT, "map.json"), "w") as fh:
		json.dump(map_json(), fh, indent=1)
		fh.write("\n")
	print("wrote %d clips + map.json to %s" % (len(CLIPS), OUT))
	print("stool hop: %s" % json.dumps(d["stool_hop"]))
	if review:
		print("review copy: " + review_sneeze(d, review))


if __name__ == "__main__":
	main()
