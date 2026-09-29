"""clipkit — authoring helpers for the Hush clips (TECH 4.8 JSON), used by clips_hush.py.

Poses are plain dicts in the fk.resolve_poses() shape ({"root": {...}, "bones": {part: {channel: v}}, "face": ...});
the kit edits them in RIG px / degrees (no K scaling) and emits clip keys as {"f", "pose": <named base>, "set":
<only the channels that differ from that base>, "ease", "face"}. Everything the runtime needs is baked: IK is solved
here, so clips play on the plain FK sampler.

Conventions (identical to the runtime, see rig_hush.DOC): y down, the art faces +x, rot in degrees clockwise +,
0 = a limb hanging straight down; the feet origin is the character position and the floor is y = 0.

Floor contact mirrors the rig tools (RigBounds.sole_points): a foot's sole is the bottom edge of its CURRENT
texture's canvas minus the 3 px margin, sampled at 15 / 50 / 85 % of the width. Hush's flat shoe canvas is cut to
its sole (hush_art BOX foot_flat); the tiptoe canvas bottom is the toe tip (its 50 % point).
"""
import copy
import math

import fk

MARGIN = 3.0
# texture canvas sizes of the feet (px) — asserted against the SVGs by clips_hush.check_canvases()
FOOT_SIZE = {"flat": (71.0, 45.0), "tiptoe": (71.0, 69.0)}
CH_DEFAULT = {"rot": 0.0, "x": 0.0, "y": 0.0, "sx": 1.0, "sy": 1.0, "alpha": 1.0}
ROOT_DEFAULT = {"x": 0.0, "y": 0.0, "rot": 0.0, "sx": 1.0, "sy": 1.0}


class Kit:
	def __init__(self, rig, poses_json, faces_json):
		self.rig = rig
		self.parts = rig["parts"]
		self.R = fk.Rig(rig, faces_json)
		self.named = fk.resolve_poses(poses_json, rig)
		self.presets = faces_json.get("presets", {})

	# ------------------------------------------------------------------ poses
	def pose(self, name):
		p = copy.deepcopy(self.named[name])
		p["_base"] = name
		p.setdefault("root", dict(ROOT_DEFAULT))
		return p

	def ch(self, p, part, c):
		b = p["bones"].get(part, {})
		if c in b:
			return b[c]
		if c == "vis":
			return 0 if self.parts[part].get("visible", True) is False else 1
		if c == "z":
			return self.parts[part].get("z", 0)
		return CH_DEFAULT.get(c, 0)

	def set(self, p, part, **chans):
		b = p["bones"].setdefault(part, {})
		for k, v in chans.items():
			b[k] = v
		return p

	def add(self, p, part, **chans):
		"""add to continuous channels (rot / x / y) and multiply scales."""
		b = p["bones"].setdefault(part, {})
		for k, v in chans.items():
			if k in ("sx", "sy"):
				b[k] = self.ch(p, part, k) * v
			else:
				b[k] = self.ch(p, part, k) + v
		return p

	def root(self, p, **chans):
		for k, v in chans.items():
			p["root"][k] = v
		return p

	def blend(self, a, b, t, base=None):
		"""continuous channels lerped a -> b (discrete from a); `base` names the result's base pose."""
		out = copy.deepcopy(a)
		for k in ROOT_DEFAULT:
			out["root"][k] = a["root"].get(k, ROOT_DEFAULT[k]) * (1 - t) + b["root"].get(k, ROOT_DEFAULT[k]) * t
		for part in self.parts:
			for c in ("rot", "x", "y", "sx", "sy", "alpha"):
				va, vb = self.ch(a, part, c), self.ch(b, part, c)
				if va != vb or c in a["bones"].get(part, {}) or c in b["bones"].get(part, {}):
					if c == "rot":
						d = (vb - va + 180.0) % 360.0 - 180.0
						v = va + d * t
					else:
						v = va * (1 - t) + vb * t
					out["bones"].setdefault(part, {})[c] = v
		if base:
			out["_base"] = base
		return out

	# ------------------------------------------------------------------ FK
	def solve(self, p):
		return self.R.solve(p)

	def joint(self, p, part, W=None):
		W = W or self.solve(p)
		return fk.apply(W[part], (0.0, 0.0))

	def world_angle(self, p, part, W=None):
		W = W or self.solve(p)
		return fk.angle(W[part])

	def tex(self, p, part):
		t = p["bones"].get(part, {}).get("tex")
		return t or self.parts[part].get("default_tex", "flat")

	def sole_points(self, p, foot, W=None):
		W = W or self.solve(p)
		sx, sy = FOOT_SIZE[self.tex(p, foot)]
		pv = self.parts[foot]["pivot"]
		y = sy - MARGIN
		return [fk.apply(W[foot], (sx * f - pv[0], y - pv[1])) for f in (0.15, 0.5, 0.85)]

	def sole_low(self, p, foot, W=None):
		return max(q[1] for q in self.sole_points(p, foot, W))

	def contact_offset(self, tex):
		"""ankle -> sole-centre offset for a foot at world angle 0."""
		sx, sy = FOOT_SIZE[tex]
		pv = (25.0, 25.0)
		return (sx * 0.5 - pv[0], sy - MARGIN - pv[1])

	# ------------------------------------------------------------------ IK (2-bone, same maths as RigSampler.plant)
	def ik(self, p, upper, lower, end, target, end_world_deg=None, bend=1.0):
		"""put the joint of `end` on `target` (character space); bend +1 = knee forward (+x), -1 = elbow down/back.
		`end_world_deg` sets the end part's world angle."""
		parts = self.parts
		par = parts[upper]["parent"]
		W = self.solve(p)
		Pm = W[par]
		inv = fk.inv(Pm)
		t = fk.apply(inv, target)
		off_u = parts[upper]["offset"]
		bu = p["bones"].get(upper, {})
		h = (off_u[0] + bu.get("x", 0.0), off_u[1] + bu.get("y", 0.0))
		l1 = math.hypot(*parts[lower]["offset"])
		l2 = math.hypot(*parts[end]["offset"])
		d = (t[0] - h[0], t[1] - h[1])
		dist = max(abs(l1 - l2) + 0.001, min(math.hypot(*d), l1 + l2 - 0.001))
		base = math.atan2(-d[0], d[1])
		a = math.acos(max(-1.0, min(1.0, (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist))))
		g = math.acos(max(-1.0, min(1.0, (l1 * l1 + l2 * l2 - dist * dist) / (2 * l1 * l2))))
		ur = base - a * bend
		lr = (math.pi - g) * bend
		self.set(p, upper, rot=math.degrees(ur))
		self.set(p, lower, rot=math.degrees(lr))
		if end_world_deg is not None:
			W2 = self.solve(p)
			pa = fk.angle(W2[lower])
			self.set(p, end, rot=_wrap(end_world_deg - pa))
		return p

	def leg(self, p, side, ankle, foot_deg=0.0, tex=None, bend=1.0):
		if tex:
			self.set(p, "foot_" + side, tex=tex)
		return self.ik(p, "leg_upper_" + side, "leg_lower_" + side, "foot_" + side, ankle, foot_deg, bend)

	def arm(self, p, side, wrist, hand_deg=None, bend=-1.0, tex=None):
		if tex:
			self.set(p, "hand_" + side, tex=tex)
		return self.ik(p, "arm_upper_" + side, "arm_lower_" + side, "hand_" + side, wrist, hand_deg, bend)

	def shoulder(self, p, side):
		return self.joint(p, "arm_upper_" + side)

	def hip(self, p, side):
		return self.joint(p, "leg_upper_" + side)

	def place(self, p, part, target):
		"""shift the root so `part`'s joint lands on `target` (character space)."""
		j = self.joint(p, part)
		p["root"]["x"] = p["root"].get("x", 0.0) + target[0] - j[0]
		p["root"]["y"] = p["root"].get("y", 0.0) + target[1] - j[1]
		return p

	def settle_feet(self, p, near=24.0):
		"""re-solve each leg whose lowest sole point (the rig tools' canvas rule) is within `near` px of the floor so
		that point sits exactly on it (world foot angle kept): poses grounded on the art's own sole outline can dip a
		rotated tiptoe canvas corner below the floor line the lint measures."""
		W = self.solve(p)
		for s in ("l", "r"):
			f = "foot_" + s
			low = self.sole_low(p, f, W)
			if abs(low) <= 0.3 or abs(low) > near:
				continue
			a = fk.apply(W[f], (0.0, 0.0))
			ang = fk.angle(W[f])
			bend = 1.0 if self.ch(p, "leg_lower_" + s, "rot") >= 0 else -1.0
			self.leg(p, s, (a[0], a[1] - low), ang, bend=bend)
			W = self.solve(p)
		return p

	def plant_like(self, p, ref, sides=("l", "r")):
		"""re-solve the legs of `p` so each foot's ankle, world angle and texture match `ref` (feet stay put while
		the body above moves)."""
		Wr = self.solve(ref)
		for s in sides:
			f = "foot_" + s
			a = fk.apply(Wr[f], (0.0, 0.0))
			ang = fk.angle(Wr[f])
			bend = 1.0 if self.ch(ref, "leg_lower_" + s, "rot") >= 0 else -1.0
			self.set(p, f, tex=self.tex(ref, f))
			self.leg(p, s, a, ang, bend=bend)
		return p

	def ground(self, p, feet=("foot_l", "foot_r")):
		"""shift root y so the lowest sole point of `feet` sits on the floor."""
		low = max(self.sole_low(p, f) for f in feet)
		p["root"]["y"] = p["root"].get("y", 0.0) - low
		return p

	# ------------------------------------------------------------------ emission
	def diff(self, p):
		base = self.named[p["_base"]]
		out = {}
		rd = {}
		for k in ROOT_DEFAULT:
			v = p["root"].get(k, ROOT_DEFAULT[k])
			bv = base.get("root", {}).get(k, ROOT_DEFAULT[k])
			if abs(v - bv) > 0.004:
				rd[k] = _r(v, k)
		if rd:
			out["root"] = rd
		for part in self.parts:
			pb = p["bones"].get(part, {})
			bb = base["bones"].get(part, {})
			cd = {}
			for c, v in pb.items():
				if c in ("tex",):
					bv = bb.get("tex", self.parts[part].get("default_tex"))
					if v != bv:
						cd[c] = v
					continue
				if c in ("vis", "z"):
					bv = bb.get(c, self.ch({"bones": {}}, part, c))
					if v != bv:
						cd[c] = v
					continue
				bv = bb.get(c, CH_DEFAULT.get(c, 0.0))
				if c == "rot":
					# absolute compare: Seq unwraps rotations against the previous key (the sampler lerps
					# them linearly), so a value 360 away from the base's must still be written
					if abs(v - bv) > 0.04:
						cd[c] = _r(v, c)
				elif abs(v - bv) > 0.004:
					cd[c] = _r(v, c)
			if cd:
				out[part] = cd
		return out

	def key(self, f, p, ease="linear", face=None):
		k = {"f": int(f), "pose": p["_base"]}
		if ease != "linear":
			k["ease"] = ease
		else:
			k["ease"] = "linear"
		if face:
			k["face"] = face
		s = self.diff(p)
		if s:
			k["set"] = s
		return k


class Seq:
	"""The keys of one clip. Every key's rotations are unwrapped against the previous key's (RigSampler lerps rot
	linearly, so an IK solution that wrapped through +-180 would spin the limb the long way) and checked against
	the rig's joint limits at build time (a violation raises: the lint would fail anyway)."""

	def __init__(self, kit, name):
		self.kit = kit
		self.name = name
		self.keys = []
		self.prev = None
		self.poses = []

	def key(self, f, p, ease="linear", face=None):
		kit = self.kit
		p = copy.deepcopy(p)
		if self.prev is not None:
			for part in kit.parts:
				if "rot" in p["bones"].get(part, {}) or "rot" in self.prev["bones"].get(part, {}):
					v = kit.ch(p, part, "rot")
					pv = kit.ch(self.prev, part, "rot")
					v2 = pv + _wrap(v - pv)
					if abs(v2 - v) > 1e-6:
						kit.set(p, part, rot=v2)
		for part, d in kit.parts.items():
			lim = d.get("limits", {}).get("rot")
			if not lim:
				continue
			v = kit.ch(p, part, "rot")
			if v < lim[0] - 0.05 or v > lim[1] + 0.05:
				for alt in (v - 360.0, v + 360.0):
					if lim[0] <= alt <= lim[1] and self.prev is None:
						kit.set(p, part, rot=alt)
						break
				else:
					raise ValueError("%s f%d: %s rot %.1f outside %s" % (self.name, f, part, v, lim))
		self.prev = p
		self.poses.append((int(f), p))
		self.keys.append(kit.key(f, p, ease, face))
		return p


def clamp_rot(kit, p, part, margin=1.0):
	"""clamp a part's rot into its joint limits (minus a margin)."""
	lim = kit.parts[part].get("limits", {}).get("rot")
	if lim:
		v = kit.ch(p, part, "rot")
		kit.set(p, part, rot=max(lim[0] + margin, min(lim[1] - margin, v)))
	return p


def _r(v, c):
	if c in ("sx", "sy", "alpha"):
		return round(v, 3)
	return round(v, 2)


def _wrap(a):
	return (a + 180.0) % 360.0 - 180.0


def smooth(u):
	u = max(0.0, min(1.0, u))
	return u * u * (3 - 2 * u)


def sine(u):
	return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, u)))


def clip(cid, length, keys, loop=False, events=None, tags=None, blend_in=None, blend_out=None, plant=False,
		 stride_px=None, beats=None, layer="base", mask=None, doc=None, jitter=0.0, rot_jitter=0.0, smear=False):
	d = {"version": 1, "clip": "hush/" + cid, "rig": "hush", "loop": bool(loop), "length": int(length),
		 "layer": layer, "mask": mask}
	if doc:
		d["doc"] = doc
	if blend_in is not None:
		d["blend_in"] = blend_in
	if blend_out is not None:
		d["blend_out"] = blend_out
	if stride_px is not None:
		d["stride_px"] = round(stride_px, 2)
	d["tags"] = list(tags or [])
	if beats:
		d["beats"] = beats
	d["keys"] = keys
	d["events"] = sorted(events or [], key=lambda e: e["f"])
	d["variation"] = {"time_jitter": jitter, "rot_jitter": rot_jitter}
	d["smear"] = {"auto": bool(smear)}
	if plant:
		d["plant"] = True
	return d


def sfx(f, sid, **kw):
	e = {"f": int(f), "type": "sfx", "id": sid}
	e.update(kw)
	return e


def prop(f, op, **kw):
	e = {"f": int(f), "type": "prop", "op": op, "prop": "clarence"}
	e.update(kw)
	return e


def clarence_home(f=0):
	"""Clarence back in the braces, limp — every Hush base clip starts with this, so a flavour clip cut on any
	frame (s2-view 4.1.9) never leaves him in her fist."""
	return [prop(f, "attach", socket="torso:braces"), prop(f, "state", state="limp")]


# ================================================================================================ sampling (previews, smears)
CONT = ("rot", "x", "y", "sx", "sy", "alpha")
ROOT = ("x", "y", "rot", "sx", "sy")
ROOT_DEF = ROOT_DEFAULT
CH_DEF = CH_DEFAULT


# ------------------------------------------------------------------------------------------ eases (RigEase)
def _bounce_out(t):
	if t < 1 / 2.75:
		return 7.5625 * t * t
	if t < 2 / 2.75:
		t -= 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	if t < 2.5 / 2.75:
		t -= 2.25 / 2.75
		return 7.5625 * t * t + 0.9375
	t -= 2.625 / 2.75
	return 7.5625 * t * t + 0.984375


def _in(fam, t):
	if fam == "quad":
		return t * t
	if fam == "cubic":
		return t ** 3
	if fam == "quart":
		return t ** 4
	if fam == "expo":
		return 0.0 if t == 0 else 2 ** (10 * (t - 1)) - 0.001
	if fam == "sine":
		return 1 - math.cos(t * math.pi / 2)
	if fam == "back":
		s = 1.70158
		return t * t * ((s + 1) * t - s)
	if fam == "elastic":
		if t in (0.0, 1.0):
			return t
		t1 = t - 1
		return -(2 ** (10 * t1) * math.sin((t1 - 0.075) * 2 * math.pi / 0.3))
	if fam == "bounce":
		return 1 - _bounce_out(1 - t)
	return t


def _out(fam, t):
	return 1 - _in(fam, 1 - t) if fam not in ("expo", "elastic", "bounce") else {
		"expo": lambda: 1.0 if t == 1 else 1.001 * (1 - 2 ** (-10 * t)),
		"elastic": lambda: t if t in (0.0, 1.0) else 2 ** (-10 * t) * math.sin((t - 0.075) * 2 * math.pi / 0.3) + 1,
		"bounce": lambda: _bounce_out(t)}[fam]()


def ease(name, t):
	t = max(0.0, min(1.0, t))
	if name in ("", "linear", None):
		return t
	if name in ("hold", "pop"):
		return 1.0 if t >= 1.0 else 0.0
	if name.startswith("in_out_"):
		kind, fam = "in_out", name[7:]
	else:
		kind, fam = name.split("_", 1)
	if kind == "in":
		return _in(fam, t)
	if kind == "out":
		return _out(fam, t)
	if t < 0.5:
		return 0.5 * _in(fam, 2 * t)
	return 0.5 + 0.5 * _out(fam, 2 * t - 1)


# ------------------------------------------------------------------------------------------ clip sampling
class Clip:
	"""Samples a clip dict the way RigSampler does (no plant lock / springs / breath)."""

	def __init__(self, rig, named, faces, data):
		self.rig = rig
		self.parts = rig["parts"]
		self.d = data
		self.length = int(data["length"])
		self.loop = bool(data.get("loop"))
		self.keys = []
		prev_face = "neutral"
		for k in data["keys"]:
			p = copy.deepcopy(named[k["pose"]]) if k.get("pose") else copy.deepcopy(self.keys[-1]["pose"])
			p.setdefault("root", dict(ROOT_DEF))
			for part, ch in (k.get("set") or {}).items():
				if part == "root":
					p["root"].update(ch)
				else:
					p["bones"].setdefault(part, {}).update(ch)
			face = k.get("face") or (named[k["pose"]].get("face") if k.get("pose") else None) or prev_face
			prev_face = face
			self.keys.append({"f": int(k["f"]), "pose": p, "ease": k.get("ease", "linear"), "face": face})
		self.events = sorted(data.get("events", []), key=lambda e: e["f"])

	def _ch(self, p, part, c):
		return p["bones"].get(part, {}).get(c, CH_DEF[c])

	def _lerp(self, a, b, e):
		out = copy.deepcopy(a)
		for c in ROOT:
			va, vb = a["root"].get(c, ROOT_DEF[c]), b["root"].get(c, ROOT_DEF[c])
			out["root"][c] = va + (vb - va) * e
		for part in self.parts:
			for c in CONT:
				va, vb = self._ch(a, part, c), self._ch(b, part, c)
				if va != vb:
					out["bones"].setdefault(part, {})[c] = va + (vb - va) * e
		return out

	def sample(self, f):
		ks = self.keys
		if self.loop:
			f = f % self.length
			if f >= ks[-1]["f"] or f < ks[0]["f"]:
				span = ks[0]["f"] + self.length - ks[-1]["f"]
				t = (f - ks[-1]["f"]) / span if f >= ks[-1]["f"] else (f + self.length - ks[-1]["f"]) / span
				return self._lerp(ks[-1]["pose"], ks[0]["pose"], ease(ks[0]["ease"], t)), ks[-1]["face"]
		if f <= ks[0]["f"]:
			return ks[0]["pose"], ks[0]["face"]
		if f >= ks[-1]["f"]:
			return ks[-1]["pose"], ks[-1]["face"]
		for i in range(len(ks) - 1):
			if ks[i]["f"] <= f < ks[i + 1]["f"]:
				t = (f - ks[i]["f"]) / float(ks[i + 1]["f"] - ks[i]["f"])
				return self._lerp(ks[i]["pose"], ks[i + 1]["pose"], ease(ks[i + 1]["ease"], t)), ks[i]["face"]
		return ks[-1]["pose"], ks[-1]["face"]

	def props_at(self, f):
		st = {"socket": "torso:braces", "state": "limp", "vis": 1}
		for e in self.events:
			if e["f"] > f:
				break
			if e.get("type") == "prop" and e.get("prop") == "clarence":
				if e.get("op") == "attach":
					st["socket"] = e.get("socket", "torso:braces")
				elif e.get("op") == "state":
					st["state"] = e.get("state", "limp")
				elif e.get("op") == "hide":
					st["vis"] = 0
				elif e.get("op") == "show":
					st["vis"] = 1
		return st

	def face_events_at(self, f):
		face = None
		for e in self.events:
			if e["f"] > f:
				break
			if e.get("type") == "face":
				face = e.get("preset") or e.get("id")
		return face



def auto_smears(data, rig, named, faces, thresh=40.0, parts_prefix=None):
	"""add a `smear` event on every frame where some part turns > thresh deg/f (the lint's A10 accepts a jump only
	into a pop key or next to a smear; the player smears those frames anyway). Returns the frames added."""
	c = Clip(rig, named, faces, data)
	have = set(e["f"] for e in data.get("events", []) if e.get("type") == "smear")
	prev = None
	added = []
	n = c.length
	for f in range(0, n + 1):
		p, _ = c.sample(float(f))
		if prev is not None:
			best, bp = 0.0, ""
			for part in rig["parts"]:
				d = abs(c._ch(p, part, "rot") - c._ch(prev, part, "rot"))
				if d > best:
					best, bp = d, part
			if best > thresh and not any(abs(h - f) <= 1 for h in have):
				# smear the textured end of a limb chain (the glove / shoe), never an invisible limb bone
				tp = bp
				for pre, end in (("arm_upper_", "hand_"), ("arm_lower_", "hand_"), ("leg_upper_", "foot_"),
								 ("leg_lower_", "foot_")):
					if bp.startswith(pre):
						tp = end + bp[len(pre):]
				data.setdefault("events", []).append({"f": f, "type": "smear", "part": tp, "frames": 2})
				have.add(f)
				added.append(f)
		prev = p
	data["events"] = sorted(data.get("events", []), key=lambda e: e["f"])
	return added
