"""Hush clips (TECH 4.8) + map.json (s2-view 4.1.1 schema), generated from the pose library.

    python3 tools/art/hush/build.py     # writes game/data/anim/hush/*.json (and everything else s2-anim-hush owns)
    python3 tools/art/hush/clip_preview.py <clip> --out DIR   # fast frame strips while authoring

Phase G (Gate 0) set: loco_idle + 3 fidgets, loco_walk (tiptoe), loco_run, loco_turn, act_climb_in, act_tinker_q/s/b,
act_snicker, act_dive, act_pop, act_squeak, freeze_1..4. Lengths are the sim's (game/sim/core/sim_const.gd):
tiptoe 400 px/s at 10 f per step, run 720 px/s at 12 f per step, dive / pop 15, squeak arm 18, rig tiers Q 48 /
S 90 / B 150, the Prologue climb-in = episode hush.enter.busy_s (1.0 s = 60 f).

Rules baked in here (the review rubric checks them):
* every clip starts by putting Clarence home (clipkit.clarence_home) unless it moves him itself, so a flavour clip
  cut on any frame never strands him in her fist;
* flavour clips (fidgets, snicker) put the joke in the first 20 frames and never leave the floor, so a cut on any
  frame blends cleanly (s2-view 4.1.9: they yield within 1 f to any state change);
* sounds are clip events with sfx_map.json ids at the frames of docs/review/s2-sound/clip_events.md (ruling L12);
* takes carry beats (anticipation -> accent pop -> moving hold -> settle, GDD 9.3) that the anim lint checks.
"""
import copy
import math

import clipkit as K
import fk
from clipkit import clip, sfx, prop, clarence_home, sine, smooth

TIPTOE_PX_S = 400.0
RUN_PX_S = 720.0
DIVE_F, POP_F, SQUEAK_F = 15, 15, 18
PREP_Q, PREP_S, PREP_B = 48, 90, 150
ENTER_F = 60
FREEZE_F = 150
BEHIND_HEAD = 11       # z for a raised near arm tucked behind the head (head 12): gloves never cross her eyes


def build(rig, poses_json, faces_json):
	kit = K.Kit(rig, poses_json, faces_json)
	clips = {}
	for fn in (walk, run, idle, fidget_look, fidget_proud, fidget_clarence, turn, climb_in, tinker_q, tinker_s,
			   tinker_b, snicker, dive, pop, squeak, freezes):
		out = fn(kit)
		if isinstance(out, dict) and "clip" in out:
			out = [out]
		for c in out:
			K.auto_smears(c, rig, kit.named, faces_json)
			clips[c["clip"].split("/", 1)[1]] = c
	clips["map"] = map_json(clips)
	return clips


def _foot_ok(kit, p):
	for s in ("l", "r"):
		K.clamp_rot(kit, p, "foot_" + s, 2.0)
	return p


def _copy(kit, dst, src, parts, chans=("rot", "tex", "z")):
	for part in parts:
		for c in chans:
			if c in src["bones"].get(part, {}):
				kit.set(dst, part, **{c: src["bones"][part][c]})
	return dst


def _add_rot(kit, p, **parts):
	for part, d in parts.items():
		kit.add(p, part, rot=d)
	return p


# ================================================================================================ LOCO
def _paws(kit, p, t, period, amp=5.0, bounce=0.0):
	"""the tiptoe 'paws': both gloves up at the chest, fingers dangling, bobbing against the legs."""
	sw = math.cos(2 * math.pi * t / period)
	for side, sgn, to, aim in (("r", -1.0, (40.0, 10.0), 6.0), ("l", 1.0, (32.0, 16.0), 10.0)):
		sh = kit.shoulder(p, side)
		kit.arm(p, side, (sh[0] + to[0] + sgn * amp * sw, sh[1] + to[1] + bounce), aim)
	return p


def walk(kit):
	"""Tiptoe scurry: 10 f per step at 400 px/s, 8 steps per loop (the pizzicato cycle walks up the scale); on the
	top notes she darts a paranoid glance back over her shoulder."""
	T, S, steps = 20, 10, 8
	L = T * steps // 2
	v = TIPTOE_PX_S / 60.0
	xc = 34.0                       # ankle x at toe-down
	lift = 62.0                     # swing: knees high
	co = kit.contact_offset("tiptoe")
	seq = K.Seq(kit, "loco_walk")
	for f in range(0, L + 1, 2):
		t = f % L
		p = kit.pose("h_tip_contact_l")
		step_ph = (t % (T // 2)) / (T // 2)
		kit.root(p, x=0.0, y=-12.0 - 8.0 * math.sin(math.pi * step_ph), rot=0.0, sx=1.0, sy=1.0)
		glance = sine((t - 56) / 8.0) - sine((t - 70) / 8.0) if 56 <= t <= 78 else 0.0
		kit.set(p, "torso", rot=17.0 + 2.0 * math.sin(2 * math.pi * t / (T // 2)) - 5.0 * glance)
		kit.set(p, "head", rot=-12.0 - 2.0 * math.sin(2 * math.pi * t / (T // 2)) - 14.0 * glance)
		kit.set(p, "pelvis", rot=2.0 * math.sin(2 * math.pi * t / T))
		for side, tc in (("r", 0), ("l", T // 2)):
			tau = (t - tc) % T
			if tau <= S:
				ax, ay, ang = xc - v * tau, -co[1], 0.0
			else:
				u = (tau - S) / float(T - S)
				# the swing: the knee comes up high IN FRONT (the cartoon tiptoe), toe pointed down
				ax = (xc - v * S) + (v * S) * sine(u) + 22.0 * math.sin(math.pi * u)
				ay = -co[1] - lift * math.sin(math.pi * min(1.0, u * 1.15))
				ang = 24.0 * math.sin(math.pi * u)
			kit.leg(p, side, (ax, ay), ang, tex="tiptoe")
		_paws(kit, p, t, T, amp=5.0, bounce=3.0 * math.sin(math.pi * step_ph - 0.8))
		_foot_ok(kit, p)
		face = None
		if f in (0, L):
			face = "sneak"
		elif f == 58:
			face = "worried"
		elif f == 72:
			face = "sneak"
		seq.key(f, p, "linear", face)
	events = clarence_home() + [sfx(s * (T // 2), "step_pizz_up") for s in range(steps)]
	return clip("loco_walk", L, seq.keys, loop=True, events=events, tags=["loco", "walk", "tiptoe"], blend_in=4,
				blend_out=4, plant=True, stride_px=v * L,
				doc="Tiptoe scurry, 10 f per step at 400 px/s (stride = 8 steps). Toes planted exactly (plant lock); "
					"gloves up as paws; the pizzicato cycle (step_pizz_up) on every toe-down; glance back on the top "
					"notes.")


def run(kit):
	"""Panic run: 12 f per step at 720 px/s with a flight phase; gloves windmilling, eyes wide."""
	T, S = 24, 8
	v = RUN_PX_S / 60.0
	xc = 50.0
	co = kit.contact_offset("flat")
	seq = K.Seq(kit, "loco_run")
	for f in range(0, T + 1, 2):
		t = f % T
		p = kit.pose("h_run_contact_l")
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
				ang = 40.0 * math.sin(math.pi * u) * (1.0 - u) - 14.0 * math.sin(math.pi * u) * u
			kit.leg(p, side, (ax, ay), ang, tex="flat")
		# windmilling gloves: back-down <-> up-front, opposite the legs
		for side, sgn in (("r", 1.0), ("l", -1.0)):
			ph = sgn * math.cos(2 * math.pi * t / T)      # +1: this glove back/down, -1: up/front
			sh = kit.shoulder(p, side)
			up = (1.0 - ph) * 0.5
			th = math.radians(50.0 - 185.0 * up)          # arc: 0 = hanging down, negative = forward
			r = 80.0 - 12.0 * math.sin(math.pi * up)
			kit.arm(p, side, (sh[0] - r * math.sin(th), sh[1] + r * math.cos(th)), math.degrees(th) + 25.0,
					tex="wave")
			K.clamp_rot(kit, p, "hand_" + side, 2.0)
		_foot_ok(kit, p)
		seq.key(f, p, "linear", "fear" if f in (0, T) else None)
	events = clarence_home() + [sfx(0, "step_pizz_up", vol_db=2.0), sfx(T // 2, "step_pizz_up", vol_db=2.0)]
	return clip("loco_run", T, seq.keys, loop=True, events=events, tags=["loco", "run"], blend_in=3, blend_out=4,
				plant=True, stride_px=v * T,
				doc="Panic run, 12 f per step at 720 px/s with a flight phase between steps; the pizzicato runs up.")


def turn(kit):
	"""6 f: squash, a tiny hop with the gloves tucked (the player's facing flip swaps her at the top), land."""
	a = kit.pose("h_stand")
	b = kit.pose("h_stand")
	kit.root(b, sx=1.07, sy=0.93)
	kit.plant_like(b, a)
	m = kit.pose("h_turn_mid")
	kit.root(m, y=m["root"].get("y", 0.0) - 12.0, sx=0.9, sy=1.08)
	c = kit.pose("h_stand")
	seq = K.Seq(kit, "loco_turn")
	seq.key(0, a, "linear", "neutral")
	seq.key(2, b, "out_quad", "grin")
	seq.key(4, m, "out_quad", "grin")
	seq.key(6, c, "in_quad", "neutral")
	return clip("loco_turn", 6, seq.keys, events=clarence_home(), tags=["loco", "turn"], blend_in=2, blend_out=3,
				plant=True, doc="Squash, hop (gloves tucked), land: 6 f.")


def idle(kit):
	"""A 4 s breathing loop: weight shifts, a curious head tilt, gloves drifting; feet planted."""
	ref = kit.pose("h_stand")
	rows = [(0, "h_stand", 0.0, 0.0, 0.0), (50, "h_breath_in", -2.5, 1.5, -1.0), (100, "h_breath_out", 1.0, -1.0, 0.5),
			(150, "h_breath_in", 3.0, -4.0, 1.0), (200, "h_breath_out", -1.0, 2.0, -0.5), (240, "h_stand", 0.0, 0.0, 0.0)]
	seq = K.Seq(kit, "loco_idle")
	for f, name, head, torso, rootx in rows:
		p = kit.pose(name)
		kit.add(p, "head", rot=head)
		kit.add(p, "torso", rot=torso)
		kit.add(p, "beret", rot=-head * 0.5)
		p["root"]["x"] = p["root"].get("x", 0.0) + rootx
		kit.plant_like(p, ref)
		seq.key(f, p, "in_out_sine", "neutral" if f in (0, 240) else None)
	return clip("loco_idle", 240, seq.keys, loop=True, events=clarence_home(), tags=["idle"], blend_in=8,
				blend_out=6, plant=True, rot_jitter=1.0,
				doc="Idle loop (4 s): breathing on top of the rig's procedural breath, weight shifts, head tilts.")


# ================================================================================================ FIDGETS (flavour)
def fidget_look(kit):
	"""'What was that?!' — snaps a glove behind her ear, eyes darting back, then a relieved sag. Joke by f9."""
	ref = kit.pose("h_stand")
	a = kit.pose("h_breath_out")
	kit.add(a, "head", rot=6.0)
	kit.root(a, sx=1.03, sy=0.97)
	kit.plant_like(a, ref)
	b = kit.pose("h_fidget_look")
	kit.root(b, sx=0.97, sy=1.03)
	kit.plant_like(b, ref)
	c = kit.pose("h_fidget_look")
	_add_rot(kit, c, head=-4.0, torso=-2.0)
	kit.plant_like(c, ref)
	d = kit.pose("h_fidget_look")
	_add_rot(kit, d, head=3.0)
	kit.plant_like(d, ref)
	e = kit.pose("h_breath_out")
	_add_rot(kit, e, torso=5.0, head=8.0)
	kit.root(e, sx=1.04, sy=0.96)
	kit.plant_like(e, ref)
	seq = K.Seq(kit, "idle_fidget_look")
	seq.key(0, kit.pose("h_stand"), "linear", "neutral")
	seq.key(5, a, "in_quad", "shock")
	seq.key(9, b, "out_back", "worried")
	seq.key(24, c, "in_out_sine", "fear")
	seq.key(40, d, "in_out_sine", "worried")
	seq.key(52, e, "in_out_sine", "phew")
	seq.key(80, kit.pose("h_stand"), "in_out_sine", "neutral")
	return clip("idle_fidget_look", 80, seq.keys, events=clarence_home(), tags=["idle", "fidget", "flavour"],
				blend_in=4, blend_out=6, plant=True,
				doc="Flavour (cut within 1 f by any state change): the ear-cup + eye dart by f9.")


def fidget_proud(kit):
	"""Chest out, fists on hips, chin up — a smug little bounce: so pleased with herself."""
	ref = kit.pose("h_stand")
	a = kit.pose("h_breath_in")
	kit.root(a, sx=1.03, sy=0.97)
	kit.plant_like(a, ref)
	b = kit.pose("h_fidget_proud")
	kit.root(b, sx=0.96, sy=1.05)
	kit.plant_like(b, ref)
	c = kit.pose("h_fidget_proud")
	_add_rot(kit, c, head=-4.0, torso=-2.0)
	kit.plant_like(c, ref)
	d = kit.pose("h_fidget_proud")
	kit.add(d, "head", rot=2.0)
	kit.root(d, sx=1.02, sy=0.98)
	kit.plant_like(d, ref)
	seq = K.Seq(kit, "idle_fidget_proud")
	seq.key(0, kit.pose("h_stand"), "linear", "neutral")
	seq.key(5, a, "in_quad", "grin")
	seq.key(10, b, "out_back", "smug")
	seq.key(24, c, "in_out_sine", "proud")
	seq.key(34, d, "in_out_sine", "proud")
	seq.key(44, c, "in_out_sine", "smug")
	seq.key(56, d, "in_out_sine", "smug")
	seq.key(84, kit.pose("h_stand"), "in_out_sine", "neutral")
	return clip("idle_fidget_proud", 84, seq.keys, events=clarence_home(), tags=["idle", "fidget", "flavour"],
				blend_in=4, blend_out=6, plant=True, doc="Flavour: fists on hips by f10, two smug chin bobs.")


def fidget_clarence(kit):
	"""Pulls Clarence out of her braces, gazes at him (smitten), a squeeze-hug, tucks him back."""
	ref = kit.pose("h_stand")
	a = kit.pose("h_stand")
	sh = kit.shoulder(a, "r")
	kit.arm(a, "r", (sh[0] + 16.0, sh[1] + 30.0), -60.0, tex="fist")
	kit.plant_like(a, ref)
	b = kit.pose("h_fidget_clarence")
	kit.root(b, sx=0.97, sy=1.03)
	kit.plant_like(b, ref)
	c = kit.pose("h_fidget_clarence")
	_add_rot(kit, c, head=8.0, torso=4.0)
	kit.plant_like(c, ref)
	d = kit.pose("h_fidget_clarence")
	_add_rot(kit, d, head=-2.0, torso=-2.0)
	kit.plant_like(d, ref)
	e = kit.pose("h_stand")
	sh = kit.shoulder(e, "r")
	kit.arm(e, "r", (sh[0] + 16.0, sh[1] + 30.0), -60.0, tex="fist")
	kit.plant_like(e, ref)
	seq = K.Seq(kit, "idle_fidget_clarence")
	seq.key(0, kit.pose("h_stand"), "linear", "neutral")
	seq.key(5, a, "in_quad", "curious")
	seq.key(12, b, "out_back", "happy")
	seq.key(22, c, "in_out_sine", "laugh")
	seq.key(34, d, "in_out_sine", "happy")
	seq.key(46, c, "in_out_sine", "laugh")
	seq.key(60, e, "in_out_sine", "smug")
	seq.key(80, kit.pose("h_stand"), "in_out_sine", "neutral")
	ev = clarence_home() + [prop(5, "attach", socket="hand_r:grip"), prop(12, "state", state="smitten"),
							sfx(12, "clarence_smitten", vol_db=-6.0), prop(60, "state", state="limp"),
							prop(60, "attach", socket="torso:braces")]
	return clip("idle_fidget_clarence", 80, seq.keys, events=ev, tags=["idle", "fidget", "flavour"], blend_in=4,
				blend_out=6, plant=True, doc="Flavour: Clarence up and smitten by f12; he goes home at f60.")


# ================================================================================================ CLIMB-IN (Prologue)
LADDER_X = 100.0       # the invisible ladder (character space, in front of her: she faces the wall/window)
GRIP_UP = 285.0        # the far glove grips the rail this far above her support foot (above the eyes, reaching)
RUNGS = (-245.0, -170.0, -95.0)


def _on_rung(kit, root_y, support, grip_y, scale=1.0, reach=1.0):
	"""Hush on the invisible ladder: the `support` foot on the rung at root_y (knee bent), the other leg reaching
	down for the next rung (reach 0..1), the far glove fisted round the rail at grip_y, the near glove shushing."""
	p = kit.pose("h_climb_a")
	kit.root(p, x=0.0, y=root_y, rot=0.0, sx=scale, sy=scale)
	shp = kit.pose("h_shush")
	kit.set(p, "torso", rot=shp["bones"].get("torso", {}).get("rot", -2.0) + 6.0)
	kit.set(p, "head", rot=shp["bones"]["head"].get("rot", -4.0) - 4.0)
	_copy(kit, p, shp, ("arm_upper_r", "arm_lower_r", "hand_r"))
	co = kit.contact_offset("tiptoe")
	free = "l" if support == "r" else "r"
	kit.leg(p, support, (36.0 * scale, root_y - co[1] * scale), 6.0, tex="tiptoe")
	kit.leg(p, free, ((20.0 - 12.0 * reach) * scale, root_y + (-co[1] + 62.0 * reach) * scale), 30.0 * reach,
			tex="tiptoe", bend=1.0)
	kit.arm(p, "l", (LADDER_X * scale, grip_y), 175.0, tex="fist")
	return p


def climb_in(kit):
	"""The Prologue entry (60 f = hush.enter.busy_s 1.0): over the sill and down an invisible mime ladder, rung by
	rung — the far glove clamped on the rail (it stays put while she drops, then re-grips lower: the mime's trick),
	the near glove's finger to her lips the whole way — shh! — then a soft tiptoe landing."""
	seq = K.Seq(kit, "act_climb_in")
	sill = -330.0
	co = kit.contact_offset("tiptoe")
	# f0: crouched on the sill, both gloves on the frame, a little smaller (still outside the window)
	p0 = kit.pose("h_climb_a")
	kit.root(p0, x=-6.0, y=sill, sx=0.86, sy=0.86)
	kit.set(p0, "torso", rot=24.0)
	kit.set(p0, "head", rot=-16.0)
	kit.leg(p0, "r", (16.0 * 0.86, sill - co[1] * 0.86), 0.0, tex="tiptoe")
	kit.leg(p0, "l", (4.0 * 0.86, sill - co[1] * 0.86), 0.0, tex="tiptoe")
	for side, dx in (("r", 50.0), ("l", 40.0)):
		sh = kit.shoulder(p0, side)
		kit.arm(p0, side, (sh[0] + dx * 0.86, sh[1] + 40.0), -60.0, tex="fist")
	_foot_ok(kit, p0)
	seq.key(0, p0, "linear", "sneak")
	# f8: up on the sill, the far glove up on the rail, the shush arrives
	y0 = sill + 10.0
	g0 = y0 - GRIP_UP * 0.92
	p1 = _on_rung(kit, y0, "r", g0, scale=0.92, reach=0.2)
	_foot_ok(kit, p1)
	seq.key(8, p1, "out_back", "shush")
	prev_y, prev_g, support = y0, g0, "r"
	for k, (f, ry) in enumerate(zip((18, 28, 38), RUNGS)):
		sc = min(1.0, 0.94 + 0.03 * k)
		# reach: the free leg stretches down for the rung (body still, glove still)
		pr = _on_rung(kit, prev_y, support, prev_g, scale=sc, reach=1.0)
		_foot_ok(kit, pr)
		seq.key(f - 5, pr, "in_out_sine", None)
		# drop: the body falls a rung onto the other foot; the glove stays clamped where it was
		support = "l" if support == "r" else "r"
		pd = _on_rung(kit, ry, support, prev_g, scale=sc, reach=0.0)
		kit.add(pd, "head", rot=3.0)
		_foot_ok(kit, pd)
		seq.key(f, pd, "in_cubic", "shush")
		# re-grip lower (a quick hand-over-hand), a little bob
		g = ry - GRIP_UP * sc
		pg = _on_rung(kit, ry - 3.0, support, g, scale=sc, reach=0.15)
		_foot_ok(kit, pg)
		seq.key(f + 3, pg, "out_quad", None)
		prev_y, prev_g = ry, g
	# f46: let go and hop down the last bit (toes pointed, both legs down)
	pd = _on_rung(kit, -64.0, support, -330.0, scale=1.0, reach=0.45)
	_foot_ok(kit, pd)
	seq.key(46, pd, "in_quad", "shush")
	# f50: tiptoe landing (squash), f54 recover, f60 the shush stand
	pl = kit.pose("h_shush")
	kit.root(pl, sx=1.07, sy=0.92)
	kit.leg(pl, "r", (18.0, -co[1]), 0.0, tex="tiptoe")
	kit.leg(pl, "l", (-6.0, -co[1]), 0.0, tex="tiptoe")
	kit.ground(pl)
	_foot_ok(kit, pl)
	seq.key(50, pl, "in_quad", "shush")
	pu = copy.deepcopy(pl)
	kit.root(pu, sx=0.98, sy=1.03)
	kit.plant_like(pu, pl)
	kit.ground(pu)
	seq.key(54, pu, "out_quad", None)
	pe = copy.deepcopy(pu)
	kit.root(pe, sx=1.0, sy=1.0)
	kit.add(pe, "head", rot=-2.0)
	kit.plant_like(pe, pl)
	kit.ground(pe)
	seq.key(60, pe, "in_out_sine", "shush")
	ev = clarence_home() + [sfx(0, "window_creak"), sfx(18, "step_pizz_up", vol_db=-2.0),
							sfx(28, "step_pizz_up", vol_db=-2.0), sfx(38, "step_pizz_up", vol_db=-2.0),
							sfx(50, "step_pizz_up")]
	return clip("act_climb_in", ENTER_F, seq.keys, events=ev, tags=["act", "climb", "enter"], blend_in=0,
				blend_out=8, plant=True,
				doc="Prologue climb-in (oneshot:enter, frame-locked, 60 f): the window creaks, she comes over the sill "
					"and down three invisible rungs (f18/28/38) with one glove on the rail, finger to her lips all the "
					"way, and lands on tiptoe (f50). Authored facing the window (the sim's start facing +1).")


# ================================================================================================ TINKER
def tinker_q(kit):
	"""Quick fiddle (Q, 48 f loop): pinching and twisting at chest height, tongue out, three tiny tiks."""
	ref = kit.pose("h_tinker_q_a")
	seq = K.Seq(kit, "act_tinker_q")
	rows = [(0, "h_tinker_q_a", 0.0, 0.0), (6, "h_tinker_q_b", 2.0, 1.0), (14, "h_tinker_q_a", -2.0, 0.0),
			(22, "h_tinker_q_b", 4.0, 2.0), (30, "h_tinker_q_a", 1.0, -1.0), (38, "h_tinker_q_b", -3.0, 1.0),
			(48, "h_tinker_q_a", 0.0, 0.0)]
	for f, name, dh, dt in rows:
		p = kit.pose(name)
		_add_rot(kit, p, head=dh, torso=dt)
		kit.plant_like(p, ref)
		seq.key(f, p, "in_out_sine", "determined" if f == 0 else None)
	ev = clarence_home() + [sfx(6, "tinker"), sfx(22, "tinker"), sfx(38, "tinker")]
	return clip("act_tinker_q", PREP_Q, seq.keys, loop=True, events=ev, tags=["act", "tinker", "rig"], blend_in=4,
				blend_out=4, plant=True, doc="Rig tier Q (0.8 s): a quick fiddle, 48 f loop.")


def tinker_s(kit):
	"""Frantic (S, 90 f loop): elbows flying, a paranoid glance over the shoulder mid-job, sweat."""
	ref = kit.pose("h_tinker_s_a")
	frames = [0, 4, 9, 13, 18, 22, 27, 31, 36, 40, 44, 48, 53, 57, 62, 66, 71, 75, 80, 85, 90]
	jit = [0, 3, -2, 4, -3, 2, -4, 3, 0, 0, 0, -2, 3, -3, 4, -2, 3, -4, 2, -1, 0]
	seq = K.Seq(kit, "act_tinker_s")
	for i, f in enumerate(frames):
		name = "h_tinker_s_a" if i % 2 == 0 else "h_tinker_s_b"
		if f in (40, 44):
			# the glance back over her shoulder (is he coming?!)
			p = kit.pose("h_tinker_s_a")
			_add_rot(kit, p, head=-26.0, torso=-10.0)
		else:
			p = kit.pose(name)
			_add_rot(kit, p, head=float(jit[i]), torso=float(jit[i]) * 0.5)
		kit.plant_like(p, ref)
		face = {0: "frantic", 40: "worried", 48: "frantic"}.get(f)
		seq.key(f, p, "out_quad" if i % 2 else "in_out_sine", face)
	ev = clarence_home() + [sfx(4, "tinker_frantic"), sfx(48, "tinker_frantic", vol_db=-2.0)]
	return clip("act_tinker_s", PREP_S, seq.keys, loop=True, events=ev, tags=["act", "tinker", "rig"], blend_in=4,
				blend_out=4, plant=True, doc="Rig tier S (1.5 s): frantic, 90 f loop, a glance back at f40.")


def _wipe(kit, head_pt, aim, head=-12.0):
	"""the brow-wipe pose with the near glove's wrist on a point of the head (head-local px), world aim `aim`."""
	p = kit.pose("h_brow_wipe")
	kit.set(p, "head", rot=head)
	t = fk.apply(kit.solve(p)["head"], head_pt)
	kit.arm(p, "r", t, aim, tex="open")
	# the sleeve passes behind her head, the glove stays in front ON the brim, above the eyes (gesture rule)
	kit.set(p, "arm_upper_r", z=BEHIND_HEAD)
	kit.set(p, "arm_lower_r", z=BEHIND_HEAD)
	return p


def tinker_b(kit):
	"""The big job (B, 150 f loop): six hammer slams, a flurry, a last tik, then the brow wipe (phew!) and back
	to the wind-up."""
	ref = kit.pose("h_tinker_b_a")
	rows = [(0, kit.pose("h_tinker_b_a"), "linear", "frantic"),
			(4, kit.blend(kit.pose("h_tinker_b_a"), kit.pose("h_tinker_b_b"), -0.08), "in_out_sine", None)]
	# slams every 14 f: wind-up (slow, out) then SLAM (fast, in)
	for i, fs in enumerate((14, 28, 42, 56, 70, 84)):
		if i > 0:
			w = kit.pose("h_tinker_b_a")
			_add_rot(kit, w, head=(-3.0 if i % 2 else 2.0), torso=-2.0)
			rows.append((fs - 8 if fs != 56 else 48, w, "out_quad", None))
		sl = kit.pose("h_tinker_b_b")
		_add_rot(kit, sl, head=(3.0 if i % 2 else -2.0))
		rows.append((fs, sl, "in_cubic", None))
	# the flurry: quick small taps, the last tik at 92
	for f, t in ((88, 0.6), (92, 1.0), (96, 0.5)):
		rows.append((f, kit.blend(kit.pose("h_tinker_b_a"), kit.pose("h_tinker_b_b"), t), "out_quad", None))
	# straighten up, the brow wipe (hush_phew at 118): the back of the glove swept across the top of her brow,
	# ABOVE the eyes (gesture rule), then flicked out to the side; a satisfied puff; back down to work
	st = _wipe(kit, (86.0, -106.0), 100.0, head=-14.0)
	pre = kit.blend(kit.pose("h_tinker_b_a"), st, 0.5, base="h_tinker_b_a")
	rows.append((104, pre, "in_out_sine", "frantic"))
	rows.append((112, st, "out_quad", "phew"))
	rows.append((118, _wipe(kit, (30.0, -118.0), 96.0, head=-16.0), "in_out_sine", None))
	fl = kit.pose("h_brow_wipe")
	_add_rot(kit, fl, head=-6.0)
	sh = kit.shoulder(fl, "r")
	kit.arm(fl, "r", (sh[0] - 70.0, sh[1] + 20.0), 60.0, tex="open")
	rows.append((124, fl, "out_quad", None))
	w2 = kit.pose("h_brow_wipe")
	_add_rot(kit, w2, head=2.0, torso=2.0)
	sh = kit.shoulder(w2, "r")
	kit.arm(w2, "r", (sh[0] + 14.0, sh[1] + 70.0), 40.0, tex="fist")
	rows.append((132, w2, "in_out_sine", "smug"))
	rows.append((141, kit.blend(kit.pose("h_tinker_b_a"), w2, 0.25, base="h_tinker_b_a"), "in_out_sine",
				 "determined"))
	rows.append((150, kit.pose("h_tinker_b_a"), "in_out_sine", "frantic"))
	rows.sort(key=lambda r: r[0])
	seq = K.Seq(kit, "act_tinker_b")
	for f, p, e, face in rows:
		kit.plant_like(p, ref)
		seq.key(f, p, e, face)
	ev = clarence_home() + [sfx(4, "tinker_frantic"), sfx(48, "tinker_frantic"), sfx(92, "tinker"),
							sfx(118, "hush_phew")]
	return clip("act_tinker_b", PREP_B, seq.keys, loop=True, events=ev, tags=["act", "tinker", "rig"], blend_in=4,
				blend_out=4, plant=True,
				doc="Rig tier B (2.5 s): hammering (6 slams), a flurry, the brow wipe at f112-128, 150 f loop.")


# ================================================================================================ SNICKER (flavour take)
def snicker(kit):
	"""The rig is done: a sly look to the Stalls, then she clamps a glove over her mouth and her shoulders shake at
	8 Hz for 40 f (GDD 9.3) — 'hff-hff-hff'. Joke by f9; ends grounded (flavour: cut on any frame)."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_snicker")
	seq.key(0, kit.pose("h_stand"), "linear", "glance")
	# antic: rises, chin up, gloves drop back a touch (a tiny inhale 'heh')
	a = kit.pose("h_breath_in")
	kit.root(a, sx=0.95, sy=1.06)
	_add_rot(kit, a, torso=-7.0, head=-10.0, arm_upper_r=8.0, arm_upper_l=6.0)
	kit.plant_like(a, ref)
	seq.key(5, a, "out_quad", "glance")
	# accent: hunched, glove clamped over the mouth (out_back: a snap with one overshoot)
	h = kit.pose("h_snicker_a")
	kit.root(h, sx=1.06, sy=0.9)
	kit.plant_like(h, ref)
	seq.key(9, h, "out_back", "snicker")
	# the shake: shoulders up (b) / down (a) at 8 Hz (7.5 f per cycle), the head tipping further each time
	fr = [9, 13, 17, 20, 24, 28, 32, 35, 39, 43, 47]
	for i, f in enumerate(fr[1:], 1):
		p = kit.pose("h_snicker_b" if i % 2 else "h_snicker_a")
		kit.root(p, sx=1.06 - 0.01 * (i % 2), sy=0.9 + 0.02 * (i % 2))
		_add_rot(kit, p, head=0.6 * i + (2.0 if i % 2 else 0.0), torso=0.4 * i)
		kit.plant_like(p, ref)
		seq.key(f, p, "in_out_sine", {24: "laugh", 35: "snicker"}.get(f))
	# settle: the glove drops, a smug grin, one overshoot, stand
	s1 = kit.pose("h_breath_in")
	kit.root(s1, sx=0.98, sy=1.03)
	_add_rot(kit, s1, head=-6.0)
	kit.plant_like(s1, ref)
	seq.key(53, s1, "out_quad", "smug")
	s2 = kit.pose("h_stand")
	kit.plant_like(s2, ref)
	seq.key(60, s2, "in_out_sine", "smug")
	ev = clarence_home() + [sfx(0, "hush_snicker")]
	return clip("act_snicker", 60, seq.keys, events=ev, tags=["take", "snicker", "flavour"], blend_in=4,
				blend_out=6, plant=True,
				beats={"anticipation": [0, 6], "accent": [6, 9], "hold": [9, 47], "settle": [47, 60]},
				doc="Flavour take after `rigged` (the glance at the Stalls, act_glance, follows): glove over the mouth "
					"by f9, shoulders at 8 Hz f9-47.")


# ================================================================================================ DIVE / POP
def _place_mid(kit, p, target):
	"""shift the root so the midpoint of her pelvis and head joints lands on `target` (the body's centre)."""
	a = kit.joint(p, "pelvis")
	b = kit.joint(p, "head")
	m = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
	p["root"]["x"] = p["root"].get("x", 0.0) + target[0] - m[0]
	p["root"]["y"] = p["root"].get("y", 0.0) + target[1] - m[1]
	return p


def dive(kit):
	"""15 f: crouch, spring up and over, head first into the spot — sucked in (scale -> 0) as the thump lands."""
	seq = K.Seq(kit, "act_dive")
	seq.key(0, kit.pose("h_stand"), "linear", "determined")
	an = kit.pose("h_dive_antic")
	kit.plant_like(an, kit.pose("h_stand"))
	seq.key(3, an, "out_quad", "determined")
	# launch: stretched diagonal, gloves reaching forward-up
	l = kit.pose("h_dive")
	kit.root(l, rot=35.0, sx=0.88, sy=1.18)
	_place_mid(kit, l, (18.0, -250.0))
	seq.key(6, l, "out_quad", "shock")
	# flat over the top
	t = kit.pose("h_dive")
	kit.root(t, rot=90.0, sx=0.92, sy=1.12)
	_place_mid(kit, t, (14.0, -285.0))
	seq.key(9, t, "out_sine", "shock")
	# head first, plunging (stretched), then sucked in
	d = kit.pose("h_dive")
	kit.root(d, rot=160.0, sx=0.8, sy=1.26)
	_place_mid(kit, d, (10.0, -200.0))
	seq.key(12, d, "in_quad", "shock")
	g = kit.pose("h_dive")
	kit.root(g, rot=170.0, sx=0.08, sy=0.1)
	_place_mid(kit, g, (0.0, -120.0))
	seq.key(15, g, "in_cubic", "shock")
	ev = clarence_home() + [sfx(0, "dive")]
	return clip("act_dive", DIVE_F, seq.keys, events=ev, tags=["take", "dive", "hide"], blend_in=2, blend_out=0,
				plant=True,
				beats={"anticipation": [0, 3], "accent": [3, 6], "hold": [6, 12], "settle": [12, 15]}, smear=True,
				doc="Dive into a hiding spot (state:diving, 15 f = SimConst.DIVE_TICKS): she vanishes into the spot's "
					"centre at f15 (then the view stops drawing her: hidden).")


def pop(kit):
	"""15 f: bursts out of the spot (from a speck) into a jazz-hands TA-DA, lands, one overshoot."""
	seq = K.Seq(kit, "act_pop")
	g = kit.pose("h_pop_out")
	_copy(kit, g, kit.pose("h_turn_mid"), ("arm_upper_r", "arm_lower_r", "hand_r", "arm_upper_l", "arm_lower_l",
										   "hand_l"))
	kit.root(g, sx=0.1, sy=0.12)
	_place_mid(kit, g, (0.0, -120.0))
	seq.key(0, g, "linear", "grin")
	b = kit.pose("h_pop_out")
	kit.root(b, sx=0.82, sy=1.22)
	_place_mid(kit, b, (0.0, -250.0))
	seq.key(3, b, "out_cubic", "grin")
	t = kit.pose("h_pop_out")
	kit.root(t, sx=0.96, sy=1.06)
	_place_mid(kit, t, (0.0, -215.0))
	seq.key(6, t, "out_quad", "happy")
	stand = kit.pose("h_stand")
	ld = kit.pose("h_pop_out")
	kit.root(ld, sx=1.1, sy=0.9)
	kit.plant_like(ld, stand)
	seq.key(9, ld, "in_quad", "happy")
	o = kit.pose("h_pop_out")
	kit.root(o, sx=0.98, sy=1.03)
	kit.plant_like(o, stand)
	seq.key(12, o, "out_quad", None)
	e = kit.pose("h_stand")
	kit.plant_like(e, stand)
	seq.key(15, e, "in_out_sine", "grin")
	ev = clarence_home() + [sfx(0, "pop_out")]
	return clip("act_pop", POP_F, seq.keys, events=ev, tags=["take", "pop", "hide"], blend_in=0, blend_out=4,
				plant=True,
				beats={"accent": [0, 3], "hold": [3, 9], "settle": [9, 15]}, smear=True,
				doc="Pop out of a hiding spot (state:popping, 15 f = SimConst.POP_TICKS): from a speck at the spot "
					"centre to TA-DA, landing at f9.")


# ================================================================================================ SQUEAK
def squeak(kit):
	"""18 f: the arm that counts as moving (GDD 3.3) — Clarence yanked out of the braces, thrust out and SQUEEZED by
	f3 (the squeak itself is event-level, on the tap), a jiggle, then tucked home."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_squeak")
	p0 = kit.pose("h_stand")
	sh = kit.shoulder(p0, "r")
	seq.key(0, p0, "linear", "grin")
	g = kit.pose("h_stand")
	kit.arm(g, "r", (sh[0] + 20.0, sh[1] + 34.0), -60.0, tex="fist")
	kit.plant_like(g, ref)
	seq.key(1, g, "out_quad", "grin")
	s = kit.pose("h_squeak")
	kit.root(s, sx=1.03, sy=0.97)
	kit.plant_like(s, ref)
	seq.key(4, s, "out_back", "grin")
	j = kit.pose("h_squeak")
	_add_rot(kit, j, arm_lower_r=-6.0, head=-3.0)
	kit.plant_like(j, ref)
	seq.key(8, j, "in_out_sine", "happy")
	k = kit.pose("h_squeak")
	_add_rot(kit, k, arm_lower_r=3.0, head=1.0)
	kit.plant_like(k, ref)
	seq.key(11, k, "in_out_sine", None)
	t = kit.pose("h_stand")
	kit.arm(t, "r", (sh[0] + 20.0, sh[1] + 34.0), -60.0, tex="fist")
	kit.plant_like(t, ref)
	seq.key(15, t, "in_out_sine", "grin")
	seq.key(18, kit.pose("h_stand"), "out_quad", "neutral")
	ev = [prop(0, "attach", socket="torso:braces"), prop(0, "state", state="limp"),
		  prop(1, "attach", socket="hand_r:grip"), prop(3, "state", state="squeezed"), prop(11, "state", state="limp"),
		  prop(15, "attach", socket="torso:braces")]
	return clip("act_squeak", SQUEAK_F, seq.keys, events=ev, tags=["act", "squeak"], blend_in=2, blend_out=4,
				plant=True,
				doc="state:squeaking (18 f = SimConst.SQUEAK_ARM_TICKS): Clarence out and squeezed by f3-4, home at "
					"f15. No sound: the squeak is event-level (the tap answers at once).")


# ================================================================================================ FREEZES (statues)
STATUES = [
	(1, "h_freeze_1", "statue", "statue_blink", "THE THINKER"),
	(2, "h_freeze_2", "statue", "statue_blink", "THE TEAPOT"),
	(3, "h_freeze_3", "statue", "statue_blink", "THE FLAMINGO"),
	(4, "h_freeze_4", "determined", "determined_blink", "THE DISCUS THROWER"),
]
BLINK_F = 78


def _statue(kit, n, pose_name, face, blink, title):
	stand = kit.pose("h_stand")
	st = kit.settle_feet(kit.pose(pose_name))
	seq = K.Seq(kit, "freeze_%d" % n)
	seq.key(0, stand, "linear", "neutral")
	# antic: a squash away from the statue (the pose extrapolated backwards), feet still planted
	an = kit.blend(stand, st, -0.18, base="h_stand")
	kit.root(an, sx=1.06, sy=0.93)
	kit.plant_like(an, stand)
	seq.key(2, an, "out_quad", "shock")
	# the pop: a hop into the pose (feet off the floor for 2 f, so nothing slides), overshoot, settle
	mid = kit.blend(st, stand, 0.3, base=pose_name)
	kit.root(mid, sx=0.95, sy=1.06)
	kit.ground(mid)
	mid["root"]["y"] -= 14.0
	seq.key(4, mid, "out_quad", face)
	ov = kit.blend(st, stand, -0.1, base=pose_name)
	kit.root(ov, sx=1.03, sy=0.97)
	kit.plant_like(ov, st)
	seq.key(5, ov, "in_quad", face)
	seq.key(9, st, "out_quad", face)
	# the hold: a tiny strained tremble (+-0.5 deg, ~7 Hz) and one blink (auto blinks are off: take)
	hold = list(range(13, BLINK_F - 2, 4)) + [BLINK_F, BLINK_F + 6] + list(range(BLINK_F + 10, FREEZE_F, 4))
	for i, f in enumerate(hold):
		p = kit.pose(pose_name)
		s = 1.0 if i % 2 == 0 else -1.0
		_add_rot(kit, p, torso=0.4 * s, head=-0.5 * s, arm_lower_r=0.6 * s, arm_lower_l=-0.5 * s)
		kit.plant_like(p, st)
		seq.key(f, p, "in_out_sine", blink if f == BLINK_F else (face if f == BLINK_F + 6 else None))
	seq.key(FREEZE_F, st, "in_out_sine", face)
	ev = clarence_home() + [sfx(5, "freeze_clack")]
	return clip("freeze_%d" % n, FREEZE_F, seq.keys, events=ev, tags=["take", "freeze", "statue"], blend_in=2,
				blend_out=4, plant=True,
				beats={"anticipation": [0, 2], "accent": [2, 5], "hold": [9, FREEZE_F]},
				doc="FREEZE statue %d (%s): a 5-f hop-pop into the pose landing with the woodblock CLACK at f5, then a held "
					"pose with a strained tremble and one blink (f78). Plays once and holds its last frame while the "
					"button stays down (map entry loop: false)." % (n, title))


def freezes(kit):
	return [_statue(kit, *s) for s in STATUES]


# ================================================================================================ map.json
def map_json(clips):
	have = set("hush/" + k for k in clips)

	def c(cid):
		return cid if cid in have else None

	m = {"version": 1, "rig": "hush",
		 "doc": "Hush clip map (s2-view 4.1.1 schema, generated by tools/art/hush/clips_hush.py). Keys left out "
				"fall back to view/world/default_maps/hush.json key by key (door, stairs, the caught one-shots, the "
				"other flavours: Phase M clips)."}
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
					 ("rigging@b", "hush/act_tinker_b"), ("state:rigging", "hush/act_tinker_q")):
		if c(cid):
			m[key] = {"clip": cid, "loop": True}
	for key, cid in (("state:diving", "hush/act_dive"), ("state:popping", "hush/act_pop"),
					 ("state:squeaking", "hush/act_squeak"), ("oneshot:enter", "hush/act_climb_in"),
					 ("flavour:snicker", "hush/act_snicker")):
		if c(cid):
			m[key] = cid
	m["state:hidden"] = ""
	fz = ["hush/freeze_%d" % i for i in range(1, 9) if "hush/freeze_%d" % i in have]
	if fz:
		m["freeze"] = {"clip": fz, "loop": False}
	m["reaction_fallback"] = ""
	m["stand_in"] = "_mannequin"
	return m
