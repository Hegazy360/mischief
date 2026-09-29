"""fk — a minimal forward-kinematics compositor for our TECH 4.7 rigs (preview only; mirrors the runtime rules).

compose(rig, pose, face) builds ONE SVG in which every part's SVG body is placed with its FK matrix and the
rubber-hose limbs are drawn as round-capped quadratic strokes (ink width + fill width), then rsvg-convert
rasterises it. Pose resolution (base inheritance, mirror_of) follows TECH 4.7.
"""
import copy
import json
import math
import os
import re
import subprocess

GAME = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "game"))
CHANNELS = ("rot", "x", "y", "sx", "sy", "z", "tex", "vis", "alpha")
ROOT_CH = ("x", "y", "rot", "sx", "sy")


def res_to_local(p):
	return os.path.join(GAME, p[len("res://"):]) if p.startswith("res://") else p


def load_json(p):
	with open(res_to_local(p)) as fh:
		return json.load(fh)


# --- 2D affine as (a, b, c, d, e, f) = [[a c e], [b d f]] -------------------------------------------
def mul(A, B):
	a1, b1, c1, d1, e1, f1 = A
	a2, b2, c2, d2, e2, f2 = B
	return (a1 * a2 + c1 * b2, b1 * a2 + d1 * b2, a1 * c2 + c1 * d2, b1 * c2 + d1 * d2,
			a1 * e2 + c1 * f2 + e1, b1 * e2 + d1 * f2 + f1)


def T(x, y):
	return (1.0, 0.0, 0.0, 1.0, float(x), float(y))


def R(deg):
	a = math.radians(deg)
	return (math.cos(a), math.sin(a), -math.sin(a), math.cos(a), 0.0, 0.0)


def S(sx, sy):
	return (float(sx), 0.0, 0.0, float(sy), 0.0, 0.0)


def apply(M, p):
	a, b, c, d, e, f = M
	return (a * p[0] + c * p[1] + e, b * p[0] + d * p[1] + f)


def inv(M):
	a, b, c, d, e, f = M
	det = a * d - b * c
	ia, ib, ic, id_ = d / det, -b / det, -c / det, a / det
	return (ia, ib, ic, id_, -(ia * e + ic * f), -(ib * e + id_ * f))


def angle(M):
	"""world rotation (deg) of an affine."""
	return math.degrees(math.atan2(M[1], M[0]))


def mstr(M):
	return "matrix(%s)" % " ".join(("%.4f" % v).rstrip("0").rstrip(".") if v != 0 else "0" for v in M)


# --- SVG bodies -------------------------------------------------------------------------------------
_BODY = {}


def svg_body(path):
	lp = res_to_local(path)
	if lp not in _BODY:
		with open(lp) as fh:
			s = fh.read()
		m = re.search(r"<svg[^>]*>(.*)</svg>", s, re.S)
		_BODY[lp] = m.group(1) if m else ""
	return _BODY[lp]


def clear_cache():
	_BODY.clear()


# --- poses ------------------------------------------------------------------------------------------
def resolve_poses(poses_json, rig):
	raw = poses_json["poses"]
	mirror = poses_json.get("mirror_of", {})
	pairs = rig.get("mirror_pairs", [["_l", "_r"]])
	out = {}

	def swap_name(n):
		for a, b in pairs:
			if n.endswith(a):
				return n[:-len(a)] + b
			if n.endswith(b):
				return n[:-len(b)] + a
		return n

	def res(name, stack=()):
		if name in out:
			return out[name]
		if name in stack:
			raise ValueError("pose base cycle at %s" % name)
		if name in mirror and name not in raw:
			src = res(mirror[name], stack + (name,))
			p = copy.deepcopy(src)
			p["bones"] = {swap_name(k): v for k, v in src["bones"].items()}
			if "props" in p:
				p["props"] = copy.deepcopy(src.get("props", {}))
			out[name] = p
			return p
		d = raw[name]
		if "base" in d:
			p = copy.deepcopy(res(d["base"], stack + (name,)))
		else:
			p = {"root": {"x": 0, "y": 0, "rot": 0, "sx": 1, "sy": 1}, "bones": {}, "face": "neutral", "props": {}}
		for k, v in d.get("root", {}).items():
			p["root"][k] = v
		for bn, ch in d.get("bones", {}).items():
			p["bones"].setdefault(bn, {}).update(ch)
		for k in ("face", "tags", "silhouette", "residues"):
			if k in d:
				p[k] = copy.deepcopy(d[k])
		if "props" in d:
			for pn, pv in d["props"].items():
				p.setdefault("props", {}).setdefault(pn, {}).update(pv)
		out[name] = p
		return p

	for n in list(raw.keys()) + list(mirror.keys()):
		res(n)
	return out


# --- FK ---------------------------------------------------------------------------------------------
class Rig:
	def __init__(self, rig, faces=None, skin=None):
		self.rig = rig
		self.faces = (faces or {}).get("presets", {})
		self.skin = skin
		self.swap = {}
		self.limb_fill = {}
		if skin:
			sk = rig.get("skins", {}).get(skin, {})
			self.swap = dict(sk.get("files", {}))
			self.limb_fill = {k: v.get("fill") for k, v in sk.get("limbs", {}).items()}
		parts = rig["parts"]
		order, pending = [], list(parts.keys())
		while pending:
			for n in list(pending):
				par = parts[n].get("parent")
				if par is None or par in order:
					order.append(n)
					pending.remove(n)
		self.order = order

	def tex_path(self, p):
		return self.swap.get(p, p)

	def solve(self, pose):
		parts = self.rig["parts"]
		r = pose.get("root", {})
		root = mul(mul(T(r.get("x", 0), r.get("y", 0)), R(r.get("rot", 0))), S(r.get("sx", 1), r.get("sy", 1)))
		W = {}
		for n in self.order:
			p = parts[n]
			b = pose.get("bones", {}).get(n, {})
			off = p.get("offset", [0, 0])
			local = mul(mul(T(off[0] + b.get("x", 0), off[1] + b.get("y", 0)), R(b.get("rot", 0))),
						S(b.get("sx", 1), b.get("sy", 1)))
			W[n] = mul(W[p["parent"]] if p.get("parent") else root, local)
		return W

	def joint(self, W, n):
		return apply(W[n], (0, 0))

	def face_dict(self, face):
		if isinstance(face, dict):
			return face
		return self.faces.get(face or "neutral", {})

	def items(self, pose, face=None):
		"""-> list of (z, order, svg_snippet) for this pose."""
		rig = self.rig
		parts = rig["parts"]
		W = self.solve(pose)
		out = []
		k = 0
		bones = pose.get("bones", {})
		for n in self.order:
			p = parts[n]
			b = bones.get(n, {})
			vis = b.get("vis", 0 if p.get("visible", True) is False else 1)
			if not vis or "draw" in p:
				continue
			tex = b.get("tex")
			texs = p.get("tex", {})
			fp = texs.get(tex) if tex else None
			fp = fp or p.get("file") or (texs.get(p.get("default_tex")) if texs else None) or \
				(next(iter(texs.values())) if texs else None)
			if not fp:
				continue
			fp = self.tex_path(fp)
			pv = p["pivot"]
			M = mul(W[n], T(-pv[0], -pv[1]))
			op = b.get("alpha", 1)
			out.append((b.get("z", p.get("z", 0)), k, '<g transform="%s"%s>%s</g>' % (
				mstr(M), (' opacity="%s"' % op) if op != 1 else "", svg_body(fp))))
			k += 1
		# limbs
		for lid, L in rig.get("limbs", {}).items():
			j = L["joints"]
			pts = [self.joint(W, n) for n in j]
			if not all(bones.get(n, {}).get("vis", 1) for n in j[:2]):
				continue
			a, m, c = pts[0], pts[1], pts[2]
			ctrl = (2 * m[0] - (a[0] + c[0]) / 2, 2 * m[1] - (a[1] + c[1]) / 2)
			d = "M%.1f %.1f Q%.1f %.1f %.1f %.1f" % (a[0], a[1], ctrl[0], ctrl[1], c[0], c[1])
			fill = self.limb_fill.get(lid) or L["fill"]
			w, o = L["width"], L.get("outline", 6)
			z = bones.get(j[0], {}).get("z", parts[j[0]].get("z", 0))
			s = ('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>'
				 '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>'
				 % (d, L.get("ink", "#1B2340"), w + 2 * o, d, fill, w))
			out.append((z, k, s))
			k += 1
		# face (TECH 4.7 slots; presets name a variant or "none" per slot)
		fc = rig.get("face")
		if fc:
			fd = self.face_dict(face if face is not None else pose.get("face"))
			head = fc["anchor"]
			if bones.get(head, {}).get("vis", 1):
				base = mul(W[head], T(*fc["offset"]))
				slots = fc["slots"]
				ev = fd.get("eyes", slots.get("eyes", {}).get("default"))
				for sn, s in slots.items():
					v = fd.get(sn, s.get("default", "default"))
					if v in ("none", "", None):
						continue
					if sn == "pupils" and ev in s.get("hide_with", []):
						continue
					fp = s.get("variants", {}).get(v) or s.get("file")
					if not fp:
						continue
					pv = s.get("pivot", fc.get("pivot", [0, 0]))
					so = s.get("offset", [0, 0])
					M = mul(base, T(so[0] - pv[0], so[1] - pv[1]))
					out.append((s.get("z", 8), k, '<g transform="%s">%s</g>' % (mstr(M), svg_body(self.tex_path(fp)))))
					k += 1
		# props
		for pn, pr in rig.get("props", {}).items():
			ps = pose.get("props", {}).get(pn, {})
			if not ps.get("vis", 0 if pr.get("hidden") else 1):
				continue
			sock = ps.get("socket", pr.get("socket"))
			if not sock:
				continue
			sp, sn = sock.split(":")
			sdef = parts[sp].get("sockets", {}).get(sn)
			if sdef is None:
				continue
			ppv = parts[sp].get("pivot", [0, 0])
			state = ps.get("state", pr.get("default_state"))
			fp = pr.get("tex", {}).get(state, pr.get("file"))
			z = ps.get("z", pr.get("z_by_socket", {}).get(sock, pr.get("z", 0)))
			M = mul(mul(mul(W[sp], T(sdef[0] - ppv[0], sdef[1] - ppv[1])), R(sdef[2] if len(sdef) > 2 else 0)),
					mul(R(ps.get("rot", 0)), T(-pr["pivot"][0], -pr["pivot"][1])))
			out.append((z, k, '<g transform="%s">%s</g>' % (mstr(M), svg_body(self.tex_path(fp)))))
			k += 1
		# residue overlays on parts
		for rn in pose.get("residues", []):
			rd = rig.get("residues", {}).get(rn, {})
			for pn, fp in rd.get("overlays", {}).items():
				pv = parts[pn]["pivot"]
				M = mul(W[pn], T(-pv[0], -pv[1]))
				out.append((17, k, '<g transform="%s">%s</g>' % (mstr(M), svg_body(self.tex_path(fp)))))
				k += 1
		out.sort(key=lambda t: (t[0], t[1]))
		return out

	def compose(self, pose, face=None, W=440, H=440, ox=220, oy=410, scale=1.0, bg=None, floor=True, extra=None):
		body = "".join(s for _, _, s in self.items(pose, face))
		pre = []
		if bg:
			pre.append('<rect x="0" y="0" width="%d" height="%d" fill="%s"/>' % (W, H, bg))
		if floor:
			pre.append('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#1B2340" fill-opacity="0.18"/>' % (
				ox, oy, 70 * scale, 9 * scale))
		return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s'
				'<g transform="translate(%.1f %.1f) scale(%s)">%s</g>%s</svg>' % (
					W, H, W, H, "".join(pre), ox, oy, scale, body, extra or ""))


def rasterise(svg_text, png_path, zoom=1.0):
	tmp = png_path + ".svg"
	with open(tmp, "w") as fh:
		fh.write(svg_text)
	subprocess.check_call(["rsvg-convert", "-z", str(zoom), tmp, "-o", png_path])
	os.remove(tmp)
	return png_path
