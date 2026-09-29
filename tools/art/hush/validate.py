#!/usr/bin/env python3
"""validate — checks every art-hush deliverable. Exit code 1 on any error (warnings don't fail).

    python3 tools/art/hush/validate.py [--no-raster]

* SVG rules (GDD 9.1): root <svg> with width/height = viewBox, allowed elements only, presentation attributes
  only (no style/class), no text/image/use/filter/mask/clipPath/gradients, <= 10 colours, 1-decimal numbers,
  3 px clear margin (rasterised; the Stalls may touch the bottom edge), size warning above 12 KB.
* rig.json / poses.json / faces.json schema (TECH 4.7) for `hush` and `figgis`; every referenced file exists;
  binding part/texture/socket/slot/preset/pose names; mirror pairs resolve; every pose's parts/channels exist.
* Pip skin parity: every skin file exists and has the same canvas size as the file it replaces.
* stalls.json: 24 heads x rest/laugh/lean(/point), 40-110 px tall, one flat fill, 4 tumble frames.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "..", "game"))
ERR, WARN = [], []

ALLOWED = {"svg", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "g"}
BANNED_ATTR = {"style", "class", "filter", "mask", "clip-path"}
NUM_ATTRS = {"d", "x", "y", "width", "height", "cx", "cy", "r", "rx", "ry", "x1", "y1", "x2", "y2", "points",
			 "transform", "stroke-width"}
INK = "#1B2340"

HUSH_PARTS = ["pelvis", "torso", "head", "beret", "hand_l", "hand_r", "foot_l", "foot_r", "arm_upper_l", "arm_upper_r",
			  "arm_lower_l", "arm_lower_r", "leg_upper_l", "leg_upper_r", "leg_lower_l", "leg_lower_r"]
HAND_TEX = ["wall", "point", "pinch", "fist", "open", "thumbs_up", "shush", "wave"]
EYES = ["open", "half", "closed", "wide", "happy", "worried", "squint", "wink"]
BROWS = ["neutral", "up", "worried", "sly", "determined"]
MOUTHS = ["smile", "grin", "O", "shh", "grimace", "wavy", "laugh", "puffed"]
OVERLAYS = ["blush", "sweat", "tear"]
PRESETS = ["neutral", "grin", "snicker", "shock", "fear", "hold_breath", "smug", "wince", "determined", "sad", "busted",
		   "wink", "statue"]
POSES = ["h_stand", "h_breath_in", "h_breath_out", "h_fidget_look", "h_tip_contact_l", "h_tip_pass_l",
		 "h_tip_contact_r", "h_tip_pass_r", "h_run_contact_l", "h_run_pass_l", "h_run_contact_r", "h_run_pass_r",
		 "h_turn_mid", "h_door_reach", "h_stairs_a", "h_stairs_b", "h_rummage_a", "h_rummage_b", "h_pickup",
		 "h_tinker_q_a", "h_tinker_q_b", "h_tinker_s_a", "h_tinker_s_b", "h_tinker_b_a", "h_tinker_b_b", "h_brow_wipe",
		 "h_snicker_a", "h_snicker_b", "h_glance_stalls", "h_dive_antic", "h_dive", "h_pop_out"] + \
		["h_freeze_%d" % i for i in range(1, 9)] + \
		["h_squeak", "h_climb_a", "h_climb_b", "h_busted", "h_dangled_a", "h_dangled_b", "h_doorstep_sit",
		 "h_tomato_splat", "h_bow_a", "h_bow_b", "h_wink", "h_victory"]
CHANNELS = {"rot", "x", "y", "sx", "sy", "z", "tex", "vis", "alpha"}
ROOT_CH = {"x", "y", "rot", "sx", "sy"}


def err(m):
	ERR.append(m)


def warn(m):
	WARN.append(m)


def local(p):
	return os.path.join(GAME, p[len("res://"):]) if p.startswith("res://") else p


def load(p):
	try:
		with open(local(p)) as fh:
			return json.load(fh)
	except Exception as e:  # noqa: BLE001
		err("%s: cannot parse (%s)" % (p, e))
		return None


def exists(p, where):
	if not isinstance(p, str) or not p.startswith("res://"):
		err("%s: path must be res://… (got %r)" % (where, p))
		return False
	if not os.path.isfile(local(p)):
		err("%s: missing file %s" % (where, p))
		return False
	return True


# --- SVG rules ---------------------------------------------------------------------------------------
def svg_size(path):
	root = ET.parse(path).getroot()
	return int(float(root.get("width"))), int(float(root.get("height")))


def check_svg(path, raster=True, bottom_ok=False, single_fill=None):
	rel = os.path.relpath(path, GAME)
	try:
		root = ET.parse(path).getroot()
	except ET.ParseError as e:
		err("%s: XML error %s" % (rel, e))
		return
	tag = root.tag.split("}")[-1]
	if tag != "svg":
		err("%s: root is not <svg>" % rel)
		return
	w, h, vb = root.get("width"), root.get("height"), root.get("viewBox")
	try:
		wi, hi = int(w), int(h)
		if vb.split() != ["0", "0", str(wi), str(hi)]:
			err("%s: viewBox %r != 0 0 %s %s" % (rel, vb, w, h))
	except (TypeError, ValueError, AttributeError):
		err("%s: width/height must be integer px with a matching viewBox" % rel)
		return
	colours = set()
	for el in root.iter():
		t = el.tag.split("}")[-1]
		if t not in ALLOWED:
			err("%s: element <%s> not allowed" % (rel, t))
		for k, v in el.attrib.items():
			if k in BANNED_ATTR:
				err("%s: attribute %s not allowed" % (rel, k))
			if k in ("fill", "stroke") and v.startswith("#"):
				colours.add(v.upper())
			if k in ("fill", "stroke") and v.startswith("url("):
				err("%s: gradients/paint servers not allowed on characters" % rel)
			if k in NUM_ATTRS:
				if re.search(r"\d\.\d\d", v) and k != "transform":
					err("%s: %s has more than 1 decimal (%s)" % (rel, k, v[:40]))
			if k == "transform" and re.search(r"matrix|skew", v):
				err("%s: use translate/rotate/scale transforms only" % rel)
	if len(colours) > 10:
		err("%s: %d colours (max 10)" % (rel, len(colours)))
	if single_fill:
		if colours - {single_fill.upper()}:
			err("%s: must use the single fill %s (found %s)" % (rel, single_fill, sorted(colours)))
		if any(el.get("stroke") for el in root.iter()):
			err("%s: silhouettes have no outline" % rel)
	size = os.path.getsize(path)
	if size > 12 * 1024:
		warn("%s: %.1f KB (> 12 KB typical)" % (rel, size / 1024.0))
	if raster:
		check_margin(path, rel, wi, hi, bottom_ok)


def check_margin(path, rel, w, h, bottom_ok):
	try:
		from PIL import Image
	except ImportError:
		return
	fd, png = tempfile.mkstemp(suffix=".png")
	os.close(fd)
	try:
		subprocess.check_call(["rsvg-convert", path, "-o", png], stderr=subprocess.DEVNULL)
		im = Image.open(png).convert("RGBA")
		a = im.split()[3]
		W, H = im.size
		m = 3
		boxes = [(0, 0, W, m), (0, 0, m, H), (W - m, 0, W, H)]
		if not bottom_ok:
			boxes.append((0, H - m, W, H))
		for bx in boxes:
			if a.crop(bx).getextrema()[1] > 24:
				err("%s: paint inside the 3 px canvas margin (%s edge)" % (rel, {0: "top", 1: "left", 2: "right", 3: "bottom"}[boxes.index(bx)]))
				break
		if a.getextrema()[1] == 0:
			err("%s: renders empty" % rel)
	finally:
		os.remove(png)


# --- rigs ----------------------------------------------------------------------------------------
def check_rig(rig, rid, need_parts=()):
	where = "rigs/%s/rig.json" % rid
	for k in ("version", "rig", "height_px", "root_part", "origin", "parts"):
		if k not in rig:
			err("%s: missing key %s" % (where, k))
	if rig.get("rig") != rid:
		err("%s: rig id %r != %r" % (where, rig.get("rig"), rid))
	parts = rig.get("parts", {})
	for n in need_parts:
		if n not in parts:
			err("%s: binding part %s missing" % (where, n))
	root = rig.get("root_part")
	if root not in parts:
		err("%s: root_part %s is not a part" % (where, root))
	for n, p in parts.items():
		pw = "%s parts.%s" % (where, n)
		par = p.get("parent")
		if n == root:
			if par:
				err("%s: root has a parent" % pw)
		elif par not in parts:
			err("%s: parent %r missing" % (pw, par))
		for k in ("pivot", "offset"):
			v = p.get(k, [0, 0] if k == "offset" and n != root else None)
			if not (isinstance(v, list) and len(v) == 2 and all(isinstance(c, (int, float)) for c in v)):
				err("%s: %s must be [x, y]" % (pw, k))
		if not isinstance(p.get("z"), int):
			err("%s: z must be an int" % pw)
		if "draw" in p:
			if not str(p["draw"]).startswith("limb:") or p["draw"][5:] not in rig.get("limbs", {}):
				err("%s: draw %r names no limb" % (pw, p["draw"]))
		else:
			if "file" not in p and not p.get("tex"):
				err("%s: needs `file` or `tex` (or draw: limb:…)" % pw)
			elif "file" in p:
				exists(p["file"], pw)
		for t, fp in p.get("tex", {}).items():
			exists(fp, "%s tex.%s" % (pw, t))
		if "default_tex" in p and p["default_tex"] not in p.get("tex", {}):
			err("%s: default_tex not in tex" % pw)
		sp = p.get("spring")
		if sp:
			if sp.get("channel") not in ("rot", "sy", "sx", "x", "y") or not all(k in sp for k in ("k", "c", "clamp")):
				err("%s: spring needs channel/k/c/clamp" % pw)
		for sn, s in p.get("sockets", {}).items():
			if not (isinstance(s, list) and len(s) in (2, 3)):
				err("%s: socket %s must be [x, y(, rot)]" % (pw, sn))
	# parent cycles
	for n in parts:
		seen, c = set(), n
		while c:
			if c in seen:
				err("%s: parent cycle at %s" % (where, n))
				break
			seen.add(c)
			c = parts.get(c, {}).get("parent")
	for lid, L in rig.get("limbs", {}).items():
		for j in L.get("joints", []):
			if j not in parts:
				err("%s limbs.%s: joint %s missing" % (where, lid, j))
		if len(L.get("joints", [])) != 3:
			err("%s limbs.%s: needs 3 joints" % (where, lid))
		for k in ("width", "fill", "outline"):
			if k not in L:
				err("%s limbs.%s: missing %s" % (where, lid, k))
	face = rig.get("face")
	if face:
		if face.get("anchor") not in parts:
			err("%s face: anchor %r missing" % (where, face.get("anchor")))
		for sn, s in face.get("slots", {}).items():
			if "z" not in s:
				err("%s face.%s: missing z" % (where, sn))
			for v, fp in s.get("variants", {}).items():
				exists(fp, "%s face.%s.%s" % (where, sn, v))
			if "file" in s:
				exists(s["file"], "%s face.%s" % (where, sn))
		for sn, s in face.get("slots", {}).items():
			d = s.get("default")
			if d and d != "none" and d not in s.get("variants", {}) and not ("file" in s and d == "default"):
				err("%s face.%s: default %r is not a variant" % (where, sn, d))
	for pn, pr in rig.get("props", {}).items():
		for fp in [pr.get("file")] + list(pr.get("tex", {}).values()):
			if fp:
				exists(fp, "%s props.%s" % (where, pn))
		for sock in [pr.get("socket")] + list(pr.get("sockets", [])):
			if not sock:
				continue
			sp, _, sn = sock.partition(":")
			if sn not in parts.get(sp, {}).get("sockets", {}):
				err("%s props.%s: socket %s missing" % (where, pn, sock))
	for rn, r in rig.get("residues", {}).items():
		for pn, fp in r.get("overlays", {}).items():
			if pn not in parts:
				err("%s residues.%s: part %s missing" % (where, rn, pn))
			exists(fp, "%s residues.%s" % (where, rn))
	# mirror pairs
	for a, b in rig.get("mirror_pairs", []):
		for n in parts:
			if n in rig.get("no_mirror", []):
				continue
			if n.endswith(a) and n[:-len(a)] + b not in parts:
				err("%s: mirror pair of %s missing" % (where, n))
			if n.endswith(b) and n[:-len(b)] + a not in parts:
				err("%s: mirror pair of %s missing" % (where, n))
	return parts


def check_poses(poses, rig, faces, rid, need=()):
	where = "rigs/%s/poses.json" % rid
	parts = rig["parts"]
	P = poses.get("poses", {})
	M = poses.get("mirror_of", {})
	presets = faces.get("presets", {})
	for n in need:
		if n not in P and n not in M:
			err("%s: required pose %s missing" % (where, n))
	for n, p in P.items():
		pw = "%s %s" % (where, n)
		if "base" in p and p["base"] not in P and p["base"] not in M:
			err("%s: base %s missing" % (pw, p["base"]))
		for k in p.get("root", {}):
			if k not in ROOT_CH:
				err("%s: root channel %s unknown" % (pw, k))
		for bn, ch in p.get("bones", {}).items():
			if bn not in parts:
				err("%s: part %s missing" % (pw, bn))
				continue
			for c, v in ch.items():
				if c not in CHANNELS:
					err("%s: %s.%s unknown channel" % (pw, bn, c))
				if c == "tex" and v not in parts[bn].get("tex", {}):
					err("%s: %s tex %r unknown" % (pw, bn, v))
		f = p.get("face")
		if isinstance(f, str) and f not in presets:
			err("%s: face preset %s missing" % (pw, f))
		if not p.get("tags"):
			err("%s: needs tags" % pw)
		tags = set(p.get("tags", []))
		if tags & {"take", "freeze"} and not p.get("silhouette"):
			err("%s: take/freeze poses need a silhouette note" % pw)
		for pn, ps in p.get("props", {}).items():
			if pn not in rig.get("props", {}):
				err("%s: prop %s missing" % (pw, pn))
		for rn in p.get("residues", []):
			if rn not in rig.get("residues", {}):
				err("%s: residue %s missing" % (pw, rn))
	for n, src in M.items():
		if src not in P:
			err("%s: mirror_of %s -> %s missing" % (where, n, src))
	return len(P) + len(M)


def check_faces(faces, rig, rid, need=()):
	where = "rigs/%s/faces.json" % rid
	slots = rig["face"]["slots"]
	pr = faces.get("presets", {})
	for n in need:
		if n not in pr:
			err("%s: required preset %s missing" % (where, n))
	for n, fd in pr.items():
		for sn, vn in fd.items():
			if sn not in slots:
				err("%s %s: %r is not a face slot (presets may only name slots)" % (where, n, sn))
				continue
			if vn in ("none", ""):
				continue
			if vn not in slots[sn].get("variants", {}) and not ("file" in slots[sn] and vn == "default"):
				err("%s %s: %s %r unknown" % (where, n, sn, vn))
		hw = slots.get("pupils", {}).get("hide_with", [])
		if fd.get("eyes") in hw and fd.get("pupils", "x") != "none":
			err("%s %s: eyes %s bake their pupils -> pupils must be none" % (where, n, fd.get("eyes")))
	return len(pr)


def check_hush(raster):
	rig = load("res://data/rigs/hush/rig.json")
	poses = load("res://data/rigs/hush/poses.json")
	faces = load("res://data/rigs/hush/faces.json")
	if not (rig and poses and faces):
		return
	parts = check_rig(rig, "hush", HUSH_PARTS)
	if len(parts) < 18:
		err("hush: %d parts (need >= 18)" % len(parts))
	for side in ("l", "r"):
		tex = parts.get("hand_" + side, {}).get("tex", {})
		if sorted(tex) != sorted(HAND_TEX):
			err("hush hand_%s: textures %s != the 8 binding shapes" % (side, sorted(tex)))
		if sorted(parts.get("foot_" + side, {}).get("tex", {})) != ["flat", "tiptoe"]:
			err("hush foot_%s: textures must be flat, tiptoe" % side)
		for n in ("arm_upper_", "arm_lower_", "leg_upper_", "leg_lower_"):
			if not str(parts.get(n + side, {}).get("draw", "")).startswith("limb:"):
				err("hush %s%s must be a limb bone" % (n, side))
	sp = parts.get("beret", {}).get("spring", {})
	if (sp.get("channel"), sp.get("k"), sp.get("c"), sp.get("clamp")) != ("rot", 180, 9, 25):
		err("hush beret spring must be rot k180 c9 clamp25 (got %s)" % sp)
	for sock in ("hand_r:grip", "hand_l:grip", "torso:braces", "head:hat"):
		pn, _, sn = sock.partition(":")
		if sn not in parts.get(pn, {}).get("sockets", {}):
			err("hush: socket %s missing" % sock)
	for lid in ("arm_l", "arm_r", "leg_l", "leg_r"):
		L = rig.get("limbs", {}).get(lid, {})
		if not (22 <= L.get("width", 0) + 2 <= 28) or L.get("outline") != 6:
			err("hush limbs.%s: width 20-26 and outline 6 expected (got %s/%s)" % (lid, L.get("width"), L.get("outline")))
	sl = rig["face"]["slots"]
	for sn, need in (("eyes", EYES), ("brows", BROWS), ("mouth", MOUTHS)):
		have = sl.get(sn, {}).get("variants", {})
		for v in need:
			if v not in have:
				err("hush face.%s: variant %s missing" % (sn, v))
	if sl.get("pupils", {}).get("range") != [6, 4]:
		err("hush face.pupils: range must be [6, 4]")
	for o in OVERLAYS:
		if "on" not in sl.get(o, {}).get("variants", {}) or sl.get(o, {}).get("default") != "none":
			err("hush face: overlay slot %s (variant on, default none) missing" % o)
	cl = rig.get("props", {}).get("clarence")
	if not cl or sorted(cl.get("states", [])) != sorted(["limp", "squeezed", "stretched", "smitten"]):
		err("hush: prop clarence with states limp/squeezed/stretched/smitten required")
	elif sorted(cl.get("sockets", [])) != sorted(["torso:braces", "hand_r:grip"]):
		err("hush clarence: sockets torso:braces + hand_r:grip")
	hid = rig.get("hidden", {})
	for k in ("file", "whites", "blink", "pupils"):
		if k in hid:
			exists(hid[k], "hush hidden.%s" % k)
	if "file" not in hid or not hid["file"].endswith("hidden_eyes.svg"):
		err("hush: hidden look hidden_eyes.svg required")
	nf = check_faces(faces, rig, "hush", PRESETS)
	if nf < 12:
		err("hush faces: %d presets (need >= 12)" % nf)
	npz = check_poses(poses, rig, faces, "hush", POSES)
	if npz < 40:
		err("hush poses: %d (need >= 40)" % npz)
	freeze = [n for n, p in poses["poses"].items() if "freeze" in p.get("tags", [])]
	if len([n for n in freeze if n.startswith("h_freeze_")]) < 8:
		err("hush: 8 freeze statues h_freeze_1..8 required")
	# Pip skin parity
	pip = rig.get("skins", {}).get("pip")
	if not pip:
		err("hush: skins.pip missing")
	else:
		for base, sk in pip.get("files", {}).items():
			if not (exists(base, "pip base") and exists(sk, "pip skin")):
				continue
			if svg_size(local(base)) != svg_size(local(sk)):
				err("pip: canvas of %s differs from %s" % (sk, base))
		for need in ("head.svg", "torso.svg", "beret.svg", "pelvis.svg", "hand_r_point.svg", "foot_r_flat.svg"):
			if not any(k.endswith("/" + need) for k in pip.get("files", {})):
				err("pip: skin must redraw %s" % need)
		for lid in ("arm_l", "arm_r", "leg_l", "leg_r"):
			if lid not in pip.get("limbs", {}):
				err("pip: limb colour %s missing" % lid)
	return nf, npz, len(parts)


def check_figgis():
	rig = load("res://data/rigs/figgis/rig.json")
	poses = load("res://data/rigs/figgis/poses.json")
	faces = load("res://data/rigs/figgis/faces.json")
	if not (rig and poses and faces):
		return
	check_rig(rig, "figgis", ["hood", "head", "ear_l", "ear_r", "specs", "hand_l", "hand_r"])
	for n in ("ear_l", "ear_r"):
		if "spring" not in rig["parts"].get(n, {}):
			err("figgis %s: ears are springs" % n)
	sl = rig["face"]["slots"]
	if len(sl["eyes"]["variants"]) < 3 or len(sl["mouth"]["variants"]) < 3:
		err("figgis: eyes x3 and mouth x3 required")
	check_faces(faces, rig, "figgis", ["psst", "point", "shh", "proud"])
	check_poses(poses, rig, faces, "figgis")
	if "card" not in rig.get("props", {}) or "icon_rect" not in rig["props"]["card"]:
		err("figgis: blank cue-card prop with icon_rect required")


def check_stalls():
	meta = load("res://data/rigs/stalls/stalls.json")
	if not meta:
		return
	heads = meta.get("heads", [])
	if len(heads) != 24:
		err("stalls: %d heads (need 24)" % len(heads))
	ids = set()
	for h in heads:
		for k in ("id", "w", "h", "frames"):
			if k not in h:
				err("stalls head: missing %s" % k)
		if h.get("id") in ids:
			err("stalls: duplicate id %s" % h.get("id"))
		ids.add(h.get("id"))
		if not (40 <= h.get("h", 0) <= 110):
			err("stalls %s: rest height %s outside 40-110" % (h.get("id"), h.get("h")))
		for fr in ("rest", "laugh", "lean"):
			if fr not in h.get("frames", {}):
				err("stalls %s: frame %s missing" % (h.get("id"), fr))
		for fr, fp in h.get("frames", {}).items():
			if exists(fp, "stalls %s.%s" % (h.get("id"), fr)):
				check_svg(local(fp), raster=False, single_fill=meta.get("fill", "#2A1E3A"))
	if len(meta.get("tumble", [])) != 4:
		err("stalls: tumble needs 4 frames")
	for t in meta.get("tumble", []):
		if exists(t.get("file", ""), "stalls tumble"):
			check_svg(local(t["file"]), raster=False, single_fill=meta.get("fill", "#2A1E3A"))
	if set(meta.get("layout", [])) != ids:
		err("stalls: layout must list every head id once")


def main():
	raster = "--no-raster" not in sys.argv
	for folder, bottom_ok in (("art/chars/hush", False), ("art/chars/hush/pip", False), ("art/chars/figgis", False),
							  ("art/chars/stalls", True)):
		d = os.path.join(GAME, folder)
		if not os.path.isdir(d):
			err("missing folder %s" % folder)
			continue
		for fn in sorted(os.listdir(d)):
			if fn.endswith(".svg"):
				check_svg(os.path.join(d, fn), raster=raster, bottom_ok=bottom_ok)
	stats = check_hush(raster)
	check_figgis()
	check_stalls()
	for w in WARN:
		print("WARN  " + w)
	for e in ERR:
		print("ERROR " + e)
	if stats:
		print("hush: %d parts, %d face presets, %d poses" % (stats[2], stats[0], stats[1]))
	print("validate: %d error(s), %d warning(s)" % (len(ERR), len(WARN)))
	sys.exit(1 if ERR else 0)


if __name__ == "__main__":
	main()
