"""Hush clips (TECH 4.8) + map.json (s2-view 4.1.1 schema), generated from the pose library.

    python3 tools/art/hush/build.py     # writes game/data/anim/hush/*.json (and everything else art-hush owns)

Phase G (Gate 0) set: loco_idle + 3 fidgets, loco_walk (tiptoe), loco_run, loco_turn, act_climb_in, act_tinker_q/s/b,
act_snicker, act_dive, act_pop, act_squeak, freeze_1..4. Lengths are the sim's (game/sim/core/sim_const.gd):
tiptoe 400 px/s at 10 f per step, run 720 px/s at 12 f per step, dive / pop 15, squeak arm 18, rig tiers Q 48 /
S 90 / B 150, the Prologue climb-in = episode hush.enter.busy_s (1.0 s = 60 f).

Rules baked in here (the review rubric checks them):
* every base clip starts by putting Clarence home (clipkit.clarence_home), so a flavour clip cut on any frame
  never strands him in her fist;
* flavour clips (fidgets, snicker) put the joke in the first 20 frames and never leave the floor, so a cut on
  any frame blends cleanly;
* sounds are clip events with sfx_map.json ids (ruling L12); laugh events use tier names.
"""
import math

import clipkit as K
from clipkit import clip, sfx, prop, clarence_home, sine, smooth

TIPTOE_PX_S = 400.0
RUN_PX_S = 720.0
DIVE_F, POP_F, SQUEAK_F = 15, 15, 18
PREP_Q, PREP_S, PREP_B = 48, 90, 150
ENTER_F = 60


def build(rig, poses_json, faces_json):
	kit = K.Kit(rig, poses_json, faces_json)
	clips = {}
	for fn in (walk, run, idle, fidget_look, fidget_proud, fidget_clarence, turn, climb_in, tinker_q, tinker_s,
			   tinker_b, snicker, dive, pop, squeak, freezes):
		out = fn(kit)
		if isinstance(out, dict) and "clip" in out:
			out = [out]
		for c in out:
			clips[c["clip"].split("/", 1)[1]] = c
	clips["map"] = map_json(clips)
	return clips


# ================================================================================================ LOCO
def _paws(kit, p, t, period, amp=6.0, bounce=0.0):
	"""the tiptoe 'paws': both gloves up in front of the chest, bobbing, counter-swinging the legs."""
	sw = math.cos(2 * math.pi * t / period)
	for side, sgn, to, aim in (("r", -1.0, (50.0, 30.0), 14.0), ("l", 1.0, (42.0, 35.0), 18.0)):
		sh = kit.shoulder(p, side)
		kit.arm(p, side, (sh[0] + to[0] + sgn * amp * sw, sh[1] + to[1] + bounce), aim)
	return p


def walk(kit):
	"""Tiptoe scurry: 10 f per step at 400 px/s, 8 steps per loop so the pizzicato walks up the scale (step_pizz_1..8)
	and on the top notes she darts a paranoid glance back over her shoulder."""
	T, S, steps = 20, 10, 8
	L = T * steps // 2
	v = TIPTOE_PX_S / 60.0
	xc = 34.0                       # ankle x at toe-down (the toe lands ~ +10 px further)
	lift = 40.0                     # swing: knees high
	co = kit.contact_offset("tiptoe")
	keys, events = [], clarence_home()
	for f in range(0, L + 1, 2):
		t = f % L
		p = kit.pose("h_tip_contact_l")
		step_ph = (t % (T // 2)) / (T // 2)
		kit.root(p, x=0.0, y=-11.0 - 6.0 * math.sin(math.pi * step_ph), rot=0.0, sx=1.0, sy=1.0)
		glance = sine((t - 56) / 8.0) - sine((t - 70) / 8.0) if 56 <= t <= 78 else 0.0
		kit.set(p, "torso", rot=15.0 + 1.5 * math.sin(2 * math.pi * t / (T // 2)) - 4.0 * glance)
		kit.set(p, "head", rot=-13.0 - 1.5 * math.sin(2 * math.pi * t / (T // 2)) - 12.0 * glance)
		kit.set(p, "pelvis", rot=2.0 * math.sin(2 * math.pi * t / T))
		for side, tc in (("r", 0), ("l", T // 2)):
			tau = (t - tc) % T
			if tau <= S:
				ax, ay, ang = xc - v * tau, -co[1], 0.0
			else:
				u = (tau - S) / float(T - S)
				ax = (xc - v * S) + (v * S) * sine(u)
				ay = -co[1] - lift * math.sin(math.pi * u)
				ang = 16.0 * math.sin(math.pi * u)
			kit.leg(p, side, (ax, ay), ang, tex="tiptoe")
		_paws(kit, p, t, T, amp=5.0, bounce=2.5 * math.sin(math.pi * step_ph - 0.8))
		face = None
		if f in (0, L):
			face = "sneak"
		elif f == 58:
			face = "worried"
		elif f == 72:
			face = "sneak"
		keys.append(kit.key(f, p, "linear", face))
	for s in range(steps):
		events.append(sfx(s * (T // 2), "step_pizz_%d" % (s + 1), vol_db=-4.0))
	return clip("loco_walk", L, keys, loop=True, events=events, tags=["loco", "walk", "tiptoe"], blend_in=4,
				blend_out=4, plant=True, stride_px=v * L,
				doc="Tiptoe scurry, 10 f per step at 400 px/s (stride = 8 steps). Toes planted exactly (plant lock); "
					"the pizzicato walks up the scale; glance back on the top notes.")


def run(kit):
	"""Panic run: 12 f per step at 720 px/s with a flight phase; gloves flailing, eyes wide, beret flapping."""
	T, S = 24, 8
	v = RUN_PX_S / 60.0
	xc = 50.0
	co = kit.contact_offset("flat")
	keys, events = [], clarence_home()
	for f in range(0, T + 1, 2):
		t = f % T
		p = kit.pose("h_run_contact_l")
		# pelvis: compressed at mid-stance, high in the flight
		tau = t % (T // 2)
		if tau <= S:
			ry = 13.0 + 5.0 * math.sin(math.pi * tau / S)
		else:
			ry = 13.0 - 9.0 * math.sin(math.pi * (tau - S) / (T // 2 - S))
		kit.root(p, x=0.0, y=ry, rot=0.0, sx=1.0, sy=1.0)
		kit.set(p, "torso", rot=22.0 + 2.0 * math.sin(2 * math.pi * t / (T // 2)))
		kit.set(p, "head", rot=-20.0 - 2.0 * math.sin(2 * math.pi * t / (T // 2)))
		kit.set(p, "pelvis", rot=4.0 * math.sin(2 * math.pi * t / T))
		for side, tc in (("r", 0), ("l", T // 2)):
			tau2 = (t - tc) % T
			if tau2 <= S:
				ax, ay, ang = xc - v * tau2, -co[1], 0.0
			else:
				u = (tau2 - S) / float(T - S)
				x0 = xc - v * S
				ax = x0 + (xc - x0) * smooth(u) - 34.0 * math.sin(math.pi * u) * (1.0 - u)
				ay = -co[1] - 66.0 * math.sin(math.pi * min(1.0, u * 1.1))
				ang = 58.0 * math.sin(math.pi * u) * (1.0 - u) - 14.0 * math.sin(math.pi * u) * u
			kit.leg(p, side, (ax, ay), ang, tex="flat")
		# flailing gloves: up-front <-> down-back, opposite the legs
		for side, sgn in (("r", 1.0), ("l", -1.0)):
			ph = sgn * math.cos(2 * math.pi * t / T)      # +1: this glove back/down, -1: up/front
			sh = kit.shoulder(p, side)
			up = (1.0 - ph) * 0.5
			wx = -42.0 + 96.0 * up
			wy = 34.0 - 100.0 * up
			kit.arm(p, side, (sh[0] + wx, sh[1] + wy), 40.0 - 190.0 * up, tex="wave")
		keys.append(kit.key(f, p, "linear", "fear" if f in (0, T) else None))
	events += [sfx(0, "run_patter"), sfx(T // 2, "run_patter")]
	return clip("loco_run", T, keys, loop=True, events=events, tags=["loco", "run"], blend_in=3, blend_out=4,
				plant=True, stride_px=v * T,
				doc="Panic run, 12 f per step at 720 px/s with a 4-f flight phase between steps.")


def turn(kit):
	"""6 f: compact spin (gloves to the chest, a tiny hop) that the player's squash flip swaps at the midpoint."""
	a = kit.pose("h_stand")
	m = kit.pose("h_turn_mid")
	kit.root(m, y=m["root"].get("y", 0.0) - 5.0, sx=0.9, sy=1.08)
	b = kit.pose("h_stand")
	keys = [kit.key(0, a, "linear", "neutral"), kit.key(3, m, "out_quad", "grin"), kit.key(6, b, "in_out_sine", "neutral")]
	return clip("loco_turn", 6, keys, events=clarence_home(), tags=["loco", "turn"], blend_in=2, blend_out=3)


def idle(kit):
	"""A 4 s breathing loop: weight shifts, a curious head tilt, gloves drifting; feet planted."""
	ref = kit.pose("h_stand")
	seq = [(0, "h_stand", 0.0, 0.0, 0.0), (50, "h_breath_in", -2.5, 1.5, -1.0), (100, "h_breath_out", 1.0, -1.0, 0.5),
		   (150, "h_breath_in", 3.0, -4.0, 1.0), (200, "h_breath_out", -1.0, 2.0, -0.5), (240, "h_stand", 0.0, 0.0, 0.0)]
	keys = []
	for f, name, head, torso, rootx in seq:
		p = kit.pose(name)
		kit.add(p, "head", rot=head)
		kit.add(p, "torso", rot=torso)
		kit.add(p, "beret", rot=-head * 0.5)
		p["root"]["x"] = p["root"].get("x", 0.0) + rootx
		kit.plant_like(p, ref)
		keys.append(kit.key(f, p, "in_out_sine", "neutral" if f in (0, 240) else None))
	return clip("loco_idle", 240, keys, loop=True, events=clarence_home(), tags=["idle"], blend_in=8, blend_out=6,
				plant=True, rot_jitter=1.0,
				doc="Idle loop (4 s): breathing on top of the rig's procedural breath, weight shifts, head tilts.")


# ================================================================================================ FIDGETS (flavour)
def _stand_ref(kit):
	return kit.pose("h_stand")


def fidget_look(kit):
	"""'What was that?!' — snaps a glove behind her ear, eyes darting back, then a relieved sag. Joke by f12."""
	ref = _stand_ref(kit)
	k = []
	p0 = kit.pose("h_stand")
	a = kit.pose("h_breath_out")
	kit.add(a, "head", rot=6.0)
	kit.root(a, sx=1.03, sy=0.97)
	kit.plant_like(a, ref)
	b = kit.pose("h_fidget_look")
	kit.root(b, sx=0.97, sy=1.03)
	kit.plant_like(b, ref)
	c = kit.pose("h_fidget_look")
	kit.add(c, "head", rot=-4.0)
	kit.add(c, "torso", rot=-2.0)
	kit.plant_like(c, ref)
	d = kit.pose("h_fidget_look")
	kit.add(d, "head", rot=3.0)
	kit.plant_like(d, ref)
	e = kit.pose("h_breath_out")
	kit.add(e, "torso", rot=5.0)
	kit.add(e, "head", rot=8.0)
	kit.root(e, sx=1.04, sy=0.96)
	kit.plant_like(e, ref)
	k.append(kit.key(0, p0, "linear", "neutral"))
	k.append(kit.key(5, a, "in_quad", "shock"))
	k.append(kit.key(9, b, "out_back", "worried"))
	k.append(kit.key(24, c, "in_out_sine", "fear"))
	k.append(kit.key(40, d, "in_out_sine", "worried"))
	k.append(kit.key(52, e, "in_out_sine", "phew"))
	k.append(kit.key(80, kit.pose("h_stand"), "in_out_sine", "neutral"))
	ev = clarence_home()
	return clip("idle_fidget_look", 80, k, events=ev, tags=["idle", "fidget", "flavour"], blend_in=4, blend_out=6,
				plant=True, doc="Flavour (cut within 1 f by any state change): the ear-cup + eye dart by f9.")


def fidget_proud(kit):
	"""Chest out, fists on hips, chin up — a smug little bounce: so pleased with herself."""
	ref = _stand_ref(kit)
	a = kit.pose("h_breath_in")
	kit.root(a, sx=1.03, sy=0.97)
	kit.plant_like(a, ref)
	b = kit.pose("h_fidget_proud")
	kit.root(b, sx=0.96, sy=1.05)
	kit.plant_like(b, ref)
	c = kit.pose("h_fidget_proud")
	kit.add(c, "head", rot=-4.0)
	kit.add(c, "torso", rot=-2.0)
	kit.root(c, sx=1.0, sy=1.0)
	kit.plant_like(c, ref)
	d = kit.pose("h_fidget_proud")
	kit.add(d, "head", rot=2.0)
	kit.root(d, sx=1.02, sy=0.98)
	kit.plant_like(d, ref)
	k = [kit.key(0, kit.pose("h_stand"), "linear", "neutral"), kit.key(5, a, "in_quad", "grin"),
		 kit.key(10, b, "out_back", "smug"), kit.key(24, c, "in_out_sine", "proud"),
		 kit.key(34, d, "in_out_sine", "proud"), kit.key(44, c, "in_out_sine", "smug"),
		 kit.key(56, d, "in_out_sine", "smug"), kit.key(84, kit.pose("h_stand"), "in_out_sine", "neutral")]
	return clip("idle_fidget_proud", 84, k, events=clarence_home(), tags=["idle", "fidget", "flavour"], blend_in=4,
				blend_out=6, plant=True, doc="Flavour: fists on hips by f10, two smug chin bobs.")


def fidget_clarence(kit):
	"""Pulls Clarence out of her braces, gazes at him (smitten), a squeeze-hug, tucks him back."""
	ref = _stand_ref(kit)
	a = kit.pose("h_stand")
	sh = kit.shoulder(a, "r")
	kit.arm(a, "r", (sh[0] + 16.0, sh[1] + 30.0), -60.0, tex="fist")
	kit.plant_like(a, ref)
	b = kit.pose("h_fidget_clarence")
	kit.root(b, sx=0.97, sy=1.03)
	kit.plant_like(b, ref)
	c = kit.pose("h_fidget_clarence")
	kit.add(c, "head", rot=8.0)
	kit.add(c, "torso", rot=4.0)
	kit.plant_like(c, ref)
	d = kit.pose("h_fidget_clarence")
	kit.add(d, "head", rot=-2.0)
	kit.add(d, "torso", rot=-2.0)
	kit.plant_like(d, ref)
	e = kit.pose("h_stand")
	sh = kit.shoulder(e, "r")
	kit.arm(e, "r", (sh[0] + 16.0, sh[1] + 30.0), -60.0, tex="fist")
	kit.plant_like(e, ref)
	k = [kit.key(0, kit.pose("h_stand"), "linear", "neutral"), kit.key(5, a, "in_quad", "curious"),
		 kit.key(12, b, "out_back", "happy"), kit.key(22, c, "in_out_sine", "laugh"),
		 kit.key(34, d, "in_out_sine", "happy"), kit.key(46, c, "in_out_sine", "laugh"),
		 kit.key(60, e, "in_out_sine", "smug"), kit.key(80, kit.pose("h_stand"), "in_out_sine", "neutral")]
	ev = clarence_home() + [prop(5, "attach", socket="hand_r:grip"), prop(12, "state", state="smitten"),
							sfx(12, "clarence_smitten", vol_db=-6.0), prop(60, "state", state="limp"),
							prop(60, "attach", socket="torso:braces")]
	return clip("idle_fidget_clarence", 80, k, events=ev, tags=["idle", "fidget", "flavour"], blend_in=4,
				blend_out=6, plant=True, doc="Flavour: Clarence up and smitten by f12; he goes home at f60.")


# placeholders filled in below
def climb_in(kit):
	return []


def tinker_q(kit):
	return []


def tinker_s(kit):
	return []


def tinker_b(kit):
	return []


def snicker(kit):
	return []


def dive(kit):
	return []


def pop(kit):
	return []


def squeak(kit):
	return []


def freezes(kit):
	return []


# ================================================================================================ map.json
def map_json(clips):
	have = set("hush/" + k for k in clips)

	def c(cid):
		return cid if cid in have else None

	m = {"version": 1, "rig": "hush",
		 "doc": "Hush clip map (s2-view 4.1.1 schema). Keys whose clips are not authored yet are left out, so the view "
				"uses the schema fallback for them (door/stairs -> walk, state:* -> idle)."}
	m["idle"] = "hush/loco_idle"
	fid = [x for x in ("hush/idle_fidget_look", "hush/idle_fidget_proud", "hush/idle_fidget_clarence") if x in have]
	if fid:
		m["idle_fidgets"] = fid
	m["walk"] = {"clip": "hush/loco_walk", "stride_px": clips["loco_walk"]["stride_px"], "speed_px_s": TIPTOE_PX_S}
	if c("hush/loco_run"):
		m["run"] = {"clip": "hush/loco_run", "stride_px": clips["loco_run"]["stride_px"], "speed_px_s": RUN_PX_S}
	if c("hush/loco_turn"):
		m["turn"] = "hush/loco_turn"
	for key, cid in (("rigging@q", "hush/act_tinker_q"), ("rigging@s", "hush/act_tinker_s"),
					 ("rigging@b", "hush/act_tinker_b"), ("state:rigging", "hush/act_tinker_q"),
					 ("state:diving", "hush/act_dive"), ("state:popping", "hush/act_pop"),
					 ("state:squeaking", "hush/act_squeak"), ("oneshot:enter", "hush/act_climb_in"),
					 ("flavour:snicker", "hush/act_snicker")):
		if c(cid):
			m[key] = cid
	m["state:hidden"] = ""
	fz = ["hush/freeze_%d" % i for i in range(1, 9) if "hush/freeze_%d" % i in have]
	if fz:
		m["freeze"] = fz
	m["reaction_fallback"] = ""
	m["stand_in"] = "_mannequin"
	return m
