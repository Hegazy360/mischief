"""Minimal forward-kinematics compositor for the Bellows rig (Python stand-in for the game's RigPlayer).

Reads game/data/rigs/bellows/{rig,poses,faces}.json, resolves poses (base inheritance, mirror_of), solves FK
from the feet origin and composes ONE SVG document (parts, rubber-hose limbs, face slots, props, residue
overlays) which rsvg-convert rasterises. Semantics (documented in rig.json "doc"):

  world(part) = world(parent) * T(offset + pose.xy) * R(pose.rot) * S(pose.sx, pose.sy)
  world(root) = T(root.x, root.y) * R(root.rot) * S(root.sx, root.sy) * T(offset + pose.xy) * R * S
  sprite      = world(part) * T(-pivot)
  face slot   = world(head) * T(face.offset) [* T(pupil offset)] * T(-slot pivot)
  prop        = world(part) * T(socket.xy - part pivot) * R(socket.angle) * T(-prop pivot)   (sockets in canvas px)
  z           = integers; props draw at their socket part's z + z_offset
  limb        = round-capped quadratic stroke through the limb bones' joint positions (through the elbow)
  tint        = per-channel multiply of every colour in the tinted parts (== Godot modulate)
"""
import copy
import json
import math
import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
GAME = os.path.join(REPO, "game")
DATA = os.path.join(GAME, "data", "rigs", "bellows")
INK = "#1B2340"

CHANNELS = ("rot", "x", "y", "sx", "sy", "z", "tex", "vis", "alpha")


def res_to_disk(p):
	if p.startswith("res://"):
		return os.path.join(GAME, p[len("res://"):])
	return p


# --- 2D affine (SVG matrix a b c d e f) ------------------------------------------------------

def mul(m, n):
	a, b, c, d, e, f = m
	A, B, C, D, E, F = n
	return (a * A + c * B, b * A + d * B, a * C + c * D, b * C + d * D, a * E + c * F + e, b * E + d * F + f)


def T(x, y):
	return (1.0, 0.0, 0.0, 1.0, float(x), float(y))


def Rm(deg):
	r = math.radians(deg)
	c, s = math.cos(r), math.sin(r)
	return (c, s, -s, c, 0.0, 0.0)


def S(sx, sy):
	return (float(sx), 0.0, 0.0, float(sy), 0.0, 0.0)


def apply(m, p):
	a, b, c, d, e, f = m
	return (a * p[0] + c * p[1] + e, b * p[0] + d * p[1] + f)


def mstr(m):
	return "matrix(%s)" % " ".join("%.4f" % v for v in m)


# --- loading ---------------------------------------------------------------------------------

_svg_cache = {}


def inner_svg(path):
	p = res_to_disk(path)
	if p not in _svg_cache:
		s = open(p).read()
		m = re.match(r'\s*<svg[^>]*>(.*)</svg>\s*$', s, re.S)
		_svg_cache[p] = m.group(1) if m else ""
	return _svg_cache[p]


def load(data_dir=DATA):
	rig = json.load(open(os.path.join(data_dir, "rig.json")))
	poses = json.load(open(os.path.join(data_dir, "poses.json")))
	faces = json.load(open(os.path.join(data_dir, "faces.json")))
	return Rig(rig, poses, faces)


def swap_lr(name, pairs):
	for a, b in pairs:
		if name.endswith(a):
			return name[: -len(a)] + b
		if name.endswith(b):
			return name[: -len(b)] + a
	return name


class Rig:
	def __init__(self, rig, poses, faces):
		self.rig = rig
		self.parts = rig["parts"]
		self.order = self._parent_first()
		self.poses_src = poses
		self.faces = faces["presets"]
		self.gaze = faces.get("gaze", {})
		self._resolved = {}

	def _parent_first(self):
		out = []
		seen = set()

		def visit(n):
			if n in seen:
				return
			p = self.parts[n].get("parent")
			if p:
				visit(p)
			seen.add(n)
			out.append(n)

		for n in self.parts:
			visit(n)
		return out

	# poses ------------------------------------------------------------------------------------
	def pose_names(self):
		names = list(self.poses_src["poses"].keys())
		for k in self.poses_src.get("mirror_of", {}):
			if k not in names:
				names.append(k)
		return names

	def raw_pose(self, name, _depth=0):
		P = self.poses_src["poses"]
		mo = self.poses_src.get("mirror_of", {})
		if name in P:
			src = P[name]
		elif name in mo:
			base = self.raw_pose(mo[name], _depth + 1)
			pairs = self.rig.get("mirror_pairs", [["_l", "_r"]])
			out = copy.deepcopy(base)
			out["bones"] = {swap_lr(b, pairs): v for b, v in base["bones"].items()}
			out["tags"] = list(base.get("tags", []))
			return out
		else:
			raise KeyError(name)
		if _depth > 16:
			raise RecursionError(name)
		if "base" in src:
			out = copy.deepcopy(self.raw_pose(src["base"], _depth + 1))
		else:
			out = {"root": {}, "bones": {}, "face": None}
		out["root"].update(src.get("root", {}))
		for b, ch in src.get("bones", {}).items():
			out["bones"].setdefault(b, {}).update(ch)
		if "face" in src:
			out["face"] = src["face"]
		out["tags"] = list(src.get("tags", []))
		out["silhouette"] = src.get("silhouette", "")
		return out

	def pose(self, name):
		if name not in self._resolved:
			self._resolved[name] = self.raw_pose(name)
		return self._resolved[name]

	# FK ---------------------------------------------------------------------------------------
	def solve(self, pose):
		root = pose.get("root", {})
		M0 = mul(mul(T(root.get("x", 0), root.get("y", 0)), Rm(root.get("rot", 0))),
				 S(root.get("sx", 1), root.get("sy", 1)))
		W = {}
		for n in self.order:
			e = self.parts[n]
			ch = pose["bones"].get(n, {})
			ox, oy = e.get("offset", [0, 0])
			L = mul(mul(T(ox + ch.get("x", 0), oy + ch.get("y", 0)), Rm(ch.get("rot", 0))), S(ch.get("sx", 1), ch.get("sy", 1)))
			par = e.get("parent")
			W[n] = mul(W[par] if par else M0, L)
		return M0, W

	def tex_path(self, part, tex):
		e = self.parts[part]
		if tex and "tex" in e:
			return e["tex"][tex]
		return e.get("file")

	def compose(self, pose, *, face=None, residues=(), combo=None, costume=None, tint=0, props=None, extra_slots=None,
				ox=0.0, oy=0.0, scale=1.0, silhouette=False, show_pivots=False, tex_over=None, slot_over=None, gaze=None):
		"""Return SVG group markup (character at feet origin (ox, oy), `scale`)."""
		if isinstance(pose, str):
			pose = self.pose(pose)
		pose = copy.deepcopy(pose)
		explicit_tex = dict(tex_over or {})
		tex_over = {}
		overlay_list = []     # (part, file)
		face_ov = set()
		limb_fill = {}
		prop_list = dict(props or {})
		res_defs = self.rig.get("residues", {})
		combos = self.rig.get("combos", {})
		active = list(residues)
		looks = []
		if combo:
			cd = combos[combo]
			hidden = set(cd.get("replaces", []))
			active = [r for r in active if r not in hidden]
			looks.append(cd)
		for r in active:
			rd = res_defs[r]
			if r == "COSTUME":
				v = costume or rd.get("default")
				looks.append(rd["variants"][v])
			else:
				looks.append(rd)
		for lk in looks:
			for part, t in lk.get("tex", {}).items():
				tex_over[part] = t
			for part, fpath in lk.get("overlays", {}).items():
				if isinstance(fpath, list):
					for fp in fpath:
						overlay_list.append((part, fp))
				else:
					overlay_list.append((part, fpath))
			for fo in lk.get("face_overlays", []):
				face_ov.add(fo)
			for lid, col in lk.get("limb_fill", {}).items():
				limb_fill[lid] = col
			for pn, sock in lk.get("props", {}).items():
				prop_list[pn] = (sock, None)
		tex_over.update(explicit_tex)
		M0, W = self.solve(pose)
		rs = math.sqrt(abs(M0[0] * M0[3] - M0[1] * M0[2]))
		draw = []   # (z, seq, markup)
		seq = [0]

		def add(z, markup):
			seq[0] += 1
			draw.append((z, seq[0], markup))

		tint_col = self.rig["tint"]["tiers"][tint] if tint else "#FFFFFF"
		tint_parts = set(self.rig["tint"]["parts"]) if tint else set()
		# parts
		for n in self.order:
			e = self.parts[n]
			ch = pose["bones"].get(n, {})
			if ch.get("vis", 1) == 0:
				continue
			z = ch.get("z", e.get("z", 0))
			if e.get("draw", "").startswith("limb:"):
				continue
			t = tex_over.get(n, ch.get("tex"))
			fp = self.tex_path(n, t)
			if not fp:
				continue
			body = inner_svg(fp)
			if n in tint_parts:
				body = multiply_colours(body, tint_col)
			px, py = e["pivot"]
			op = ch.get("alpha", 1)
			add(z, '<g transform="%s"%s>%s</g>' % (mstr(mul(W[n], T(-px, -py))),
												   (' opacity="%.3f"' % op) if op < 1 else "", body))
			for (opart, ofile) in overlay_list:
				if opart == n:
					add(z + 0.1, '<g transform="%s">%s</g>' % (mstr(mul(W[n], T(-px, -py))), inner_svg(ofile)))
		# limbs
		for lid, L in self.rig.get("limbs", {}).items():
			j = L["joints"]
			pts = [apply(W[b], (0, 0)) for b in j]
			z = pose["bones"].get(j[0], {}).get("z", self.parts[j[0]].get("z", 0))
			w = L["width"] * rs
			ow = L.get("outline", 6) * rs
			c = (2 * pts[1][0] - (pts[0][0] + pts[2][0]) / 2, 2 * pts[1][1] - (pts[0][1] + pts[2][1]) / 2)
			d = "M%.2f %.2f Q%.2f %.2f %.2f %.2f" % (pts[0][0], pts[0][1], c[0], c[1], pts[2][0], pts[2][1])
			fill = limb_fill.get(lid, L["fill"])
			mk = ('<path d="%s" fill="none" stroke="%s" stroke-width="%.2f" stroke-linecap="round" stroke-linejoin="round"/>'
				  '<path d="%s" fill="none" stroke="%s" stroke-width="%.2f" stroke-linecap="round" stroke-linejoin="round"/>'
				  % (d, L.get("ink", INK), w + 2 * ow, d, fill, w))
			add(z, mk)
			for b in j[:2]:
				for (opart, ofile) in overlay_list:
					if opart == b:
						px, py = self.parts[b]["pivot"]
						add(z + 0.1, '<g transform="%s">%s</g>' % (mstr(mul(W[b], T(-px, -py))), inner_svg(ofile)))
		# face
		fr = self.rig["face"]
		fname = face or pose.get("face") or "neutral"
		preset = dict(self.faces.get(fname, self.faces["neutral"]))
		if slot_over:
			preset.update(slot_over)
		anchor = mul(W[fr["anchor"]], T(*fr["offset"]))
		slots = fr["slots"]
		on = face_ov | set(extra_slots or [])
		hw = pose["bones"].get(fr["anchor"], {})
		for sname, sd in slots.items():
			if sname in preset:
				v = preset[sname]
			elif sd.get("overlay"):
				v = "on" if sname in on else "none"
			else:
				v = sd.get("default", "none") if "variants" in sd and sd.get("default") else ("default" if "file" in sd else None)
			if sd.get("overlay") and sname in on:
				v = "on"
			if not v or v == "none":
				continue
			fp = sd["file"] if v == "default" and "file" in sd else sd["variants"][v]
			px, py = sd["pivot"]
			m = anchor
			if sname == "pupils":
				po = list(gaze if gaze is not None else self.gaze.get(fname, [0, 0]))
				m = mul(m, T(po[0], po[1]))
			body_s = inner_svg(fp)
			if ("face_" + sname) in tint_parts:
				body_s = multiply_colours(body_s, tint_col)
			add(sd["z"], '<g transform="%s">%s</g>' % (mstr(mul(m, T(-px, -py))), body_s))
		# props
		for pn, (sock, state) in prop_list.items():
			pd = self.rig["props"][pn]
			sock = sock or (pd.get("state_sockets", {}).get(state) if state else None) or pd["socket"]
			part, sname = sock.split(":")
			sk = self.parts[part]["sockets"][sname]
			ppx, ppy = self.parts[part]["pivot"]
			m = mul(mul(W[part], T(sk[0] - ppx, sk[1] - ppy)), Rm(sk[2] if len(sk) > 2 else 0))
			fp = pd["tex"][state] if (state and "tex" in pd) else pd["file"]
			px, py = pd["pivot"]
			zo = pd.get("state_z_offset", {}).get(state, pd.get("z_offset", 1)) if state else pd.get("z_offset", 1)
			zp = pose["bones"].get(part, {}).get("z", self.parts[part].get("z", 0)) + zo
			add(zp, '<g transform="%s">%s</g>' % (mstr(mul(m, T(-px, -py))), inner_svg(fp)))
		draw.sort(key=lambda t: (t[0], t[1]))
		body = "".join(t[2] for t in draw)
		if show_pivots:
			for n in self.order:
				p = apply(W[n], (0, 0))
				body += ('<circle cx="%.1f" cy="%.1f" r="3" fill="#E23B4E" stroke="#FFFFFF" stroke-width="1"/>' % p)
		if silhouette:
			body = re.sub(r'#[0-9A-Fa-f]{6}', "#000000", body)
			body = re.sub(r'(fill|stroke)-opacity="[0-9.]+"', "", body)
			body = re.sub(r' opacity="[0-9.]+"', "", body)
		return '<g transform="translate(%.2f %.2f) scale(%.4f)">%s</g>' % (ox, oy, scale, body)


def multiply_colours(markup, col):
	mr, mg, mb = int(col[1:3], 16), int(col[3:5], 16), int(col[5:7], 16)

	def rep(m):
		h = m.group(0)
		r, g, b = int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)
		return "#%02X%02X%02X" % (round(r * mr / 255), round(g * mg / 255), round(b * mb / 255))

	return re.sub(r'#[0-9A-Fa-f]{6}', rep, markup)


def svg_doc(w, h, body, bg=None):
	b = '<rect x="0" y="0" width="%d" height="%d" fill="%s"/>' % (w, h, bg) if bg else ""
	return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s%s</svg>\n'
			% (w, h, w, h, b, body))


def render(svg_text, png, zoom=1.0, tmp_dir="/tmp"):
	os.makedirs(os.path.dirname(png), exist_ok=True)
	sp = png[:-4] + ".svg"
	with open(sp, "w") as fh:
		fh.write(svg_text)
	cmd = ["rsvg-convert", sp, "-o", png]
	if zoom != 1.0:
		cmd += ["-z", "%.4f" % zoom]
	subprocess.check_call(cmd)
	os.remove(sp)
	return png


def bbox(rig, pose, zoom=0.5, **kw):
	"""Tight bounding box (x0, y0, x1, y1) in world px of the composed pose (rendered silhouette alpha)."""
	import tempfile
	from PIL import Image
	W, H, ox, oy = 1600, 1400, 800, 1000
	body = rig.compose(pose, ox=ox, oy=oy, silhouette=True, **kw)
	fd, png = tempfile.mkstemp(suffix=".png")
	os.close(fd)
	render(svg_doc(W, H, body), png, zoom)
	im = Image.open(png)
	a = im.split()[-1]
	bb = a.point(lambda v: 255 if v > 40 else 0).getbbox()
	os.remove(png)
	if not bb:
		return None
	x0, y0, x1, y1 = bb
	return (x0 / zoom - ox, y0 / zoom - oy, x1 / zoom - ox, y1 / zoom - oy)


def silhouette_image(rig, pose, height_px=50, **kw):
	"""Solid-black silhouette scaled so 380 world px = `height_px`; returns a PIL RGBA image cropped to content."""
	import tempfile
	from PIL import Image
	z = height_px / 380.0
	W, H, ox, oy = 1600, 1400, 800, 1000
	body = rig.compose(pose, ox=ox, oy=oy, silhouette=True, **kw)
	fd, png = tempfile.mkstemp(suffix=".png")
	os.close(fd)
	render(svg_doc(W, H, body), png, z)
	im = Image.open(png).convert("RGBA")
	os.remove(png)
	bb = im.getbbox()
	return im.crop(bb) if bb else im
