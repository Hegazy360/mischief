"""Hush's remaining slice clips (docs/LEVELS.md §5, wave 0) — everything `SliceClips.build()` still listed after
the Phase-G set: the bow, the four flavours (glance at the Stalls, pick-up, shrug, wheeze), the rummage and
mid-job freeze loops, the door, the wink, and the caught chain (yanked, busted, dangled through the Lecture,
plonked on the doorstep, tomato).

Lengths come from the manifest (the sim's clocks): act_wink 30, lec_dangled 132 (the Lecture's own length),
st_busted 60, st_near_miss 15, st_shrug 20, st_yanked 36, st_doorstep / st_tomato ≤ 36; the rest are loops.
Conventions are `clips_hush.py`'s: Clarence starts home, flavours put the joke in the first 20 frames and keep
both feet on the floor, and takes carry anticipation / accent / hold / settle beats.
"""
import copy

import clipkit as K
from clipkit import clip, sfx, clarence_home


def _plant(kit, p, ref):
	kit.plant_like(p, ref)
	return p


def _set(p, **parts):
	"""Absolute bone rotations on a pose copy (Seq.key takes a pose, not an override dict)."""
	for part, v in parts.items():
		p.setdefault("bones", {}).setdefault(part, {})["rot"] = float(v)
	return p


# ================================================================================================ the bow
def bow(kit):
	"""Take a bow (loops while the curtain call holds her on the apron): a deep theatrical bow, a bounce back up,
	a smaller second bow — the curtain can fall on any frame."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_bow")
	seq.key(0, _plant(kit, kit.pose("h_stand"), ref), "linear", "grin")
	seq.key(14, _plant(kit, kit.pose("h_bow_a"), ref), "out_quad", "happy")
	seq.key(30, _plant(kit, kit.pose("h_bow_b"), ref), "in_out_sine", "happy")
	seq.key(46, _plant(kit, kit.pose("h_bow_a"), ref), "in_out_sine", "happy")
	seq.key(62, _plant(kit, kit.pose("h_victory"), ref), "out_back", "grin")
	seq.key(84, _plant(kit, kit.pose("h_bow_b"), ref), "in_out_sine", "happy")
	seq.key(104, _plant(kit, kit.pose("h_bow_a"), ref), "in_out_sine", "happy")
	seq.key(120, _plant(kit, kit.pose("h_stand"), ref), "in_out_sine", "grin")
	return clip("act_bow", 120, seq.keys, loop=True, events=clarence_home() + [sfx(14, "bow_creak", vol_db=-8.0)],
				tags=["bow", "curtain"], blend_in=6, blend_out=6, plant=True,
				doc="Take a bow (120 f, loops): a deep bow, up on a bounce, a second smaller one — the curtain may "
					"fall on any frame.")


# ================================================================================================ flavours
def glance(kit):
	"""She glances out at the Stalls after a rig — the look that makes the player complicit (GDD §1.2)."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_glance")
	seq.key(0, _plant(kit, kit.pose("h_stand"), ref), "linear", "grin")
	seq.key(6, _plant(kit, kit.pose("h_glance_stalls"), ref), "out_quad", "smug")
	seq.key(14, _plant(kit, kit.pose("h_glance_stalls"), ref), "in_out_sine", "smug")
	seq.key(20, _plant(kit, kit.pose("h_stand"), ref), "in_out_sine", "smug")
	seq.key(28, _plant(kit, kit.pose("h_shush"), ref), "out_back", "smug")
	seq.key(36, _plant(kit, kit.pose("h_shush"), ref), "in_out_sine", "grin")
	seq.key(44, _plant(kit, kit.pose("h_stand"), ref), "in_out_sine", "grin")
	return clip("act_glance", 44, seq.keys, events=clarence_home(), tags=["flavour", "glance"],
				blend_in=4, blend_out=4, plant=True,
				doc="The glance at the Stalls (44 f): she catches the audience's eye and shushes them — the joke is "
					"in the first 20 f, so a cut on any frame still reads.")


def pickup(kit):
	"""Scooping something off the floor and tucking it into the tray."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_pickup")
	seq.key(0, _plant(kit, kit.pose("h_stand"), ref), "linear", "determined")
	seq.key(8, _plant(kit, kit.pose("h_pickup"), ref), "out_quad", "determined")
	seq.key(16, _plant(kit, kit.pose("h_pickup"), ref), "in_out_sine", "grin")
	seq.key(26, _plant(kit, kit.pose("h_stand"), ref), "in_out_sine", "grin")
	seq.key(36, _plant(kit, kit.pose("h_fidget_proud"), ref), "out_back", "happy")
	seq.key(48, _plant(kit, kit.pose("h_stand"), ref), "in_out_sine", "grin")
	return clip("act_pickup", 48, seq.keys, events=clarence_home() + [sfx(8, "rustle", vol_db=-10.0)],
				tags=["flavour", "pickup"], blend_in=4, blend_out=4, plant=True,
				doc="Picking something up (48 f): a quick scoop, into the tray, and a proud little straighten.")


def shrug(kit):
	"""20 f: the fizzle shrug — gloves out, eyebrows up, 'well, I tried'."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_shrug")
	seq.key(0, _plant(kit, kit.pose("h_stand"), ref), "linear", "grin")
	nm = _set(kit.pose("h_near_miss"), hand_r=148.0)
	nm2 = _set(kit.pose("h_near_miss"), hand_r=144.0)
	seq.key(7, _plant(kit, nm, ref), "out_quad", "shock")
	seq.key(13, _plant(kit, nm2, ref), "in_out_sine", "smug")
	seq.key(20, _plant(kit, kit.pose("h_stand"), ref), "in_out_sine", "grin")
	return clip("st_shrug", 20, seq.keys, events=clarence_home(), tags=["flavour", "shrug"],
				blend_in=4, blend_out=4, plant=True,
				doc="The shrug (20 f): a prank fizzled — gloves out, a glance at the Stalls, on with the Night.")


def wheeze(kit):
	"""Her own wheeze after a long run (loops; the sim holds it)."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_wheeze")
	seq.key(0, _plant(kit, kit.pose("h_wheeze"), ref), "linear", "phew")
	seq.key(12, _plant(kit, kit.pose("h_breath_in"), ref), "in_out_sine", "phew")
	seq.key(24, _plant(kit, kit.pose("h_wheeze"), ref), "in_out_sine", "phew")
	seq.key(36, _plant(kit, kit.pose("h_breath_out"), ref), "in_out_sine", "phew")
	seq.key(48, _plant(kit, kit.pose("h_wheeze"), ref), "in_out_sine", "phew")
	seq.key(60, _plant(kit, kit.pose("h_brow_wipe"), ref), "in_out_sine", "phew")
	seq.key(72, _plant(kit, kit.pose("h_wheeze"), ref), "in_out_sine", "phew")
	return clip("act_wheeze", 72, seq.keys, loop=True, events=clarence_home(), tags=["flavour", "phew"],
				blend_in=6, blend_out=6, plant=True,
				doc="Hush's wheeze (72 f, loops, capped at 90 f by the sim): hands on knees, hauling air, one wipe "
					"of the brow.")


def rummage(kit):
	"""The container rummage and its pick window (one loop, the sim holds it as long as it needs)."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_rummage")
	seq.key(0, _plant(kit, kit.pose("h_rummage_a"), ref), "linear", "determined")
	seq.key(12, _plant(kit, kit.pose("h_rummage_b"), ref), "in_out_sine", "determined")
	seq.key(24, _plant(kit, kit.pose("h_rummage_a"), ref), "in_out_sine", "determined")
	seq.key(34, _plant(kit, kit.pose("h_rummage_b"), ref), "in_out_sine", "shock")
	seq.key(44, _plant(kit, kit.pose("h_rummage_a"), ref), "in_out_sine", "determined")
	seq.key(56, _plant(kit, kit.pose("h_rummage_b"), ref), "in_out_sine", "determined")
	seq.key(68, _plant(kit, kit.pose("h_rummage_a"), ref), "in_out_sine", "determined")
	return clip("act_rummage", 68, seq.keys, loop=True,
				events=clarence_home() + [sfx(12, "rustle", vol_db=-8.0), sfx(44, "rustle", vol_db=-10.0)],
				tags=["activity", "rummage"], blend_in=4, blend_out=4, plant=True,
				doc="Rummaging in a container (68 f, loops): both gloves deep in the box, elbows working — the "
					"pick window plays the same loop.")


def freeze_midjob(kit):
	"""FREEZE caught her mid-rig: the statue still holding the tinkering pose, trembling."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_freeze_midjob")
	a = _plant(kit, kit.pose("h_tinker_q_a"), ref)
	b = copy.deepcopy(a)
	kit.root(b, sx=1.004, sy=0.996)
	seq.key(0, a, "linear", "hold_breath")
	seq.key(18, b, "in_out_sine", "hold_breath")
	seq.key(36, a, "in_out_sine", "hold_breath")
	seq.key(54, b, "in_out_sine", "hold_breath")
	seq.key(72, a, "in_out_sine", "hold_breath")
	return clip("freeze_midjob", 72, seq.keys, loop=True, events=clarence_home(), tags=["freeze", "midjob"],
				blend_in=2, blend_out=2, plant=True,
				doc="FREEZE mid-rig (72 f, loops): she holds the tinkering pose exactly where it was, breathing as "
					"little as she dares.")


def door(kit):
	"""Through a door: a hand on the frame, a slip through, a silent pull to."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_door")
	seq.key(0, _plant(kit, kit.pose("h_stand"), ref), "linear", "determined")
	seq.key(6, _plant(kit, kit.pose("h_door_reach"), ref), "out_quad", "determined")
	seq.key(14, _plant(kit, kit.pose("h_door_reach"), ref), "in_out_sine", "determined")
	seq.key(21, _plant(kit, kit.pose("h_stand"), ref), "in_out_sine", "determined")
	return clip("loco_door", 21, seq.keys, events=clarence_home() + [sfx(6, "door_jiggle", vol_db=-12.0)],
				tags=["loco", "door"], blend_in=4, blend_out=4, plant=True,
				doc="Through a door (21 f, 0.35 s = SimConst's Hush door time): a glove on the frame and she is "
					"through without a sound.")


def wink(kit):
	"""30 f: the MIRROR, MIRROR wink — the moment she drops the act in his 'reflection'."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_wink")
	fz = kit.pose("h_freeze_1")
	seq.key(0, fz, "linear", "statue")
	seq.key(6, kit.pose("h_freeze_1"), "linear", "smug")
	seq.key(10, _plant(kit, kit.pose("h_wink"), fz), "out_back", "wink")
	seq.key(16, _set(_plant(kit, kit.pose("h_wink"), fz), head=-4.0), "in_out_sine", "wink")
	seq.key(22, _set(_plant(kit, kit.pose("h_wink"), fz), head=2.0), "in_out_sine", "smug")
	seq.key(26, _set(_plant(kit, kit.pose("h_wink"), fz), head=-2.0), "in_out_sine", "smug")
	seq.key(30, _plant(kit, kit.pose("h_wink"), fz), "in_out_sine", "statue")
	return clip("act_wink", 30, seq.keys, events=clarence_home() + [sfx(10, "glint", sync=False)],
				tags=["take", "wink", "mirror"], blend_in=0, blend_out=4, plant=True, smear=True,
				beats={"anticipation": [0, 6], "accent": [6, 10], "hold": [10, 24], "settle": [24, 30]},
				doc="The wink (30 f): frozen in the mirror frame she lets the mask slip for one frame — and that is "
					"what he screams at.")


# ================================================================================================ the caught chain
def yanked(kit):
	"""36 f: the Prologue / Gate 0 yank — something hauls her out of frame by the braces."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_yanked")
	seq.key(0, _plant(kit, kit.pose("h_stand"), ref), "linear", "determined")
	seq.key(4, _plant(kit, kit.pose("h_busted_antic"), ref), "out_quad", "shock")
	b = kit.pose("h_busted")
	kit.root(b, sx=0.84, sy=1.2, y=-40.0)
	seq.key(8, b, "pop", "shock")
	b2 = kit.pose("h_busted")
	kit.root(b2, sx=0.9, sy=1.14, y=-120.0)
	seq.key(16, b2, "out_quad", "shock")
	b3 = kit.pose("h_busted")
	kit.root(b3, sx=0.94, sy=1.1, y=-260.0, rot=-8.0)
	seq.key(26, b3, "in_quad", "shock")
	b4 = kit.pose("h_busted")
	kit.root(b4, sx=0.96, sy=1.08, y=-420.0, rot=-12.0)
	seq.key(36, b4, "linear", "shock")
	return clip("st_yanked", 36, seq.keys, events=clarence_home() + [sfx(8, "zip")],
				tags=["take", "caught", "yanked"], blend_in=0, blend_out=0, smear=True,
				beats={"anticipation": [0, 4], "accent": [4, 8], "hold": [8, 26], "settle": [26, 36]},
				doc="Yanked out of frame (36 f): she is hauled up and away by the braces — the Prologue's and Gate "
					"0's end-of-scene exit.")


def busted(kit):
	"""60 f: caught — the Busted Cam plays over this. Hands up, caught red-gloved, a sheepish little wave."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_busted")
	seq.key(0, _plant(kit, kit.pose("h_stand"), ref), "linear", "determined")
	an = kit.pose("h_busted_antic")
	kit.root(an, sx=1.08, sy=0.9)
	kit.plant_like(an, ref)
	seq.key(6, an, "out_quad", "worried")
	bb = kit.pose("h_busted")
	kit.root(bb, sx=0.88, sy=1.16)
	kit.plant_like(bb, ref)
	seq.key(10, bb, "pop", "shock")
	seq.key(16, _plant(kit, kit.pose("h_busted"), ref), "out_quad", "shock")
	seq.key(26, _set(_plant(kit, kit.pose("h_busted"), ref), head=4.0), "in_out_sine", "busted")
	seq.key(38, _plant(kit, kit.pose("h_busted"), ref), "in_out_sine", "smug")
	seq.key(50, _plant(kit, kit.pose("h_fidget_look"), ref), "in_out_sine", "smug")
	seq.key(60, _plant(kit, kit.pose("h_busted"), ref), "in_out_sine", "shock")
	return clip("st_busted", 60, seq.keys, events=clarence_home() + [sfx(10, "sting_caught")],
				tags=["take", "caught", "busted"], blend_in=0, blend_out=4, plant=True, smear=True,
				beats={"anticipation": [0, 10], "accent": [10, 14], "hold": [14, 38], "settle": [38, 60]},
				doc="Caught (60 f, the Busted Cam re-stages it): gloves up, frozen mid-mischief, then a tiny "
					"sheepish wave at the Stalls.")


def dangled(kit):
	"""132 f: dangling from his fist through the Lecture (the three lec_* variants are all this long)."""
	seq = K.Seq(kit, "act_dangled")
	a = kit.pose("h_dangled_a")
	b = kit.pose("h_dangled_b")
	for q in (a, b):
		kit.root(q, y=-96.0)
	seq.key(0, a, "linear", "shock")
	f = 0
	i = 0
	while f + 22 <= 110:
		f += 22
		seq.key(f, b if i % 2 == 0 else a, "in_out_sine", "sad" if i % 2 else "shock")
		i += 1
	seq.key(122, a, "in_out_sine", "sad")
	seq.key(132, a, "in_out_sine", "determined")
	return clip("lec_dangled", 132, seq.keys, events=clarence_home(),
				tags=["caught", "lecture", "dangle"], blend_in=4, blend_out=4,
				doc="Dangled through the Lecture (132 f, the length of lec_a / lec_b / lec_c): she hangs from her "
					"braces, swinging gently, rolling her eyes at every wag of his finger.")


def doorstep(kit):
	"""36 f: plonked on the doorstep as the front door slams."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_doorstep")
	d = kit.pose("h_dangled_a")
	kit.root(d, y=-90.0)
	seq.key(0, d, "linear", "sad")
	seq.key(8, _plant(kit, kit.pose("h_doorstep_sit"), ref), "in_quad", "sad")
	seq.key(12, _plant(kit, kit.pose("h_doorstep_sit"), ref), "out_quad", "shock")
	seq.key(20, _set(_plant(kit, kit.pose("h_doorstep_sit"), ref), head=8.0), "in_out_sine", "sad")
	seq.key(28, _set(_plant(kit, kit.pose("h_doorstep_sit"), ref), head=-2.0), "in_out_sine", "sad")
	seq.key(36, _plant(kit, kit.pose("h_doorstep_sit"), ref), "in_out_sine", "determined")
	return clip("st_doorstep", 36, seq.keys, events=clarence_home() + [sfx(8, "land_soft")],
				tags=["caught", "doorstep"], blend_in=0, blend_out=4, plant=True,
				doc="On the doorstep (36 f): set down outside, the door slams behind her, and she is already "
					"planning the next way in.")


def tomato(kit):
	"""36 f: the Stalls' tomato arrives — she wears it, and takes it in good part."""
	ref = kit.pose("h_doorstep_sit")
	seq = K.Seq(kit, "act_tomato")
	seq.key(0, _plant(kit, kit.pose("h_doorstep_sit"), ref), "linear", "sad")
	seq.key(6, _set(_plant(kit, kit.pose("h_doorstep_sit"), ref), head=18.0, torso=14.0,
					arm_upper_r=-20.0, arm_lower_r=-70.0, arm_upper_l=-16.0, arm_lower_l=-66.0),
			"out_quad", "worried")
	t = _plant(kit, kit.pose("h_tomato_splat"), ref)
	seq.key(10, t, "pop", "shock")
	seq.key(14, _plant(kit, kit.pose("h_tomato_splat"), ref), "out_quad", "shock")
	seq.key(24, _plant(kit, kit.pose("h_tomato_splat"), ref), "in_out_sine", "sad")
	seq.key(36, _plant(kit, kit.pose("h_doorstep_sit"), ref), "in_out_sine", "grin")
	return clip("st_tomato", 36, seq.keys, events=clarence_home() + [sfx(10, "tomato_splat")],
				tags=["caught", "tomato"], blend_in=4, blend_out=4, plant=True, smear=True,
				beats={"anticipation": [0, 10], "accent": [10, 14], "hold": [14, 24], "settle": [24, 36]},
				doc="The tomato (36 f): the Stalls' verdict lands on her beret; she wipes one eye and grins "
					"anyway.")


def near_miss(kit):
	"""15 f: the near miss — a held breath let out all at once."""
	ref = kit.pose("h_stand")
	seq = K.Seq(kit, "act_near_miss")
	seq.key(0, _plant(kit, kit.pose("h_hold_breath"), ref), "linear", "hold_breath")
	seq.key(5, _plant(kit, kit.pose("h_near_miss"), ref), "out_quad", "phew")
	seq.key(10, _plant(kit, kit.pose("h_near_miss"), ref), "in_out_sine", "phew")
	seq.key(15, _plant(kit, kit.pose("h_stand"), ref), "in_out_sine", "grin")
	return clip("st_near_miss", 15, seq.keys, events=clarence_home() + [sfx(5, "hush_phew")],
				tags=["flavour", "near_miss"], blend_in=2, blend_out=2, plant=True,
				doc="The near miss (15 f): he looked straight at her and moved on — she lets the breath go.")


CLIPS = (bow, glance, pickup, shrug, wheeze, rummage, freeze_midjob, door, wink, yanked, busted, dangled,
		 doorstep, tomato, near_miss)

MAP_KEYS = {
	"state:bowing": "hush/act_bow",
	"flavour:glance": "hush/act_glance", "flavour:pickup": "hush/act_pickup", "flavour:shrug": "hush/st_shrug",
	"state:rummage": {"clip": "hush/act_rummage", "loop": True},
	"state:pick_window": {"clip": "hush/act_rummage", "loop": True},
	"freeze_midjob": {"clip": "hush/freeze_midjob", "loop": True},
	"door": "hush/loco_door",
	"oneshot:wink": "hush/act_wink", "oneshot:wheeze": {"clip": "hush/act_wheeze", "loop": True},
	"oneshot:near_miss": "hush/st_near_miss", "oneshot:yanked": "hush/st_yanked",
	"state:caught": "hush/st_busted", "oneshot:caught:busted": "hush/st_busted",
	"oneshot:caught:lecture": "hush/lec_dangled", "oneshot:caught:doorstep": "hush/st_doorstep",
}
