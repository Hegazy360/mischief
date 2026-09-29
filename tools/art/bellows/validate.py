#!/usr/bin/env python3
"""Validate the Bellows rig: SVG rules (GDD §9.1), rig/poses/faces schema (TECH §4.7), file references, pose parts,
mirror pairs, residue/costume/combo completeness, and FK checks (rest height, planted feet, take bbox >= 15 %).

    python3 tools/art/bellows/validate.py [--no-render]

Exit code 0 = clean, 1 = errors (each printed with its file / key).
"""
import argparse
import json
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True  # keep tools/art/bellows free of __pycache__
import tempfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fk  # noqa: E402
import faces_spec  # noqa: E402
import poses_spec  # noqa: E402

GAME = fk.GAME
ART = os.path.join(GAME, "art", "chars", "bellows")
DATA = os.path.join(GAME, "data", "rigs", "bellows")
SVGNS = "{http://www.w3.org/2000/svg}"
ALLOWED = {"svg", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon"}
BANNED_ATTR = {"style", "class", "filter", "mask", "clip-path", "href", "{http://www.w3.org/1999/xlink}href"}
CHANNELS = {"rot", "x", "y", "sx", "sy", "z", "tex", "vis", "alpha"}
ROOT_CH = {"x", "y", "rot", "sx", "sy"}
BOUFFANT = ["neat", "flipped", "frazzled", "wet", "floured", "feathered", "poodle"]
HANDS = ["open", "fist", "point", "grip", "wag", "conduct"]
SIDEBURNS = ["flat", "bristle", "puffed", "wet"]
EYES = ["open", "half", "closed", "wide", "pinpoint", "angry", "spiral", "balloon", "squint", "teary"]
BROWS = ["neutral", "up", "angry", "worried", "sly", "one_up"]
MOUTHS = ["closed", "smile", "smug", "O_small", "O_mid", "O_big", "scream", "grit", "wavy", "open"]
OVERLAYS = ["sweat", "vein", "steam_l", "steam_r", "blush"]
PARTS_REQ = ["torso", "belly", "coat_tails", "cravat", "head", "bouffant", "sideburn_l", "sideburn_r", "hand_l", "hand_r",
			 "foot_l", "foot_r", "arm_upper_l", "arm_upper_r", "arm_lower_l", "arm_lower_r", "leg_upper_l", "leg_upper_r",
			 "leg_lower_l", "leg_lower_r"]
PROPS_REQ = ["specs", "teacup", "newspaper", "comb", "baton", "phone_handset", "kipper_held", "pickled_onion", "kettle_lid",
			 "jelly_helmet", "sausage_boa", "megaphone"]
SOCKETS_REQ = ["hand_l:grip", "hand_r:grip", "head:specs", "head:hat", "torso:chain"]
RESIDUES = ["SOAKED", "FLOURY", "STICKY", "SQUEAKY", "FRAZZLED", "FEATHERED", "COSTUME"]
COSTUMES = ["jelly_helmet", "tutu_tulle", "tutu_chandelier", "trophy_helmet", "long_johns", "hedge_twigs", "umbrella_stand"]
COMBOS = {"dough_man": ["SOAKED", "FLOURY"], "poodle": ["SOAKED", "FRAZZLED"], "chicken": ["STICKY", "FEATHERED"],
		  "mad_maestro": ["FRAZZLED", "SQUEAKY"]}
HEX = re.compile(r"#[0-9A-Fa-f]{6}\b")
NUM2 = re.compile(r"-?\d+\.\d{2,}")

errors = []
warnings = []


def err(where, msg):
	errors.append("%s: %s" % (where, msg))


def warn(where, msg):
	warnings.append("%s: %s" % (where, msg))


def res_path(p):
	return fk.res_to_disk(p)


# --- SVG rules -------------------------------------------------------------------------------
def check_svg(path, render_margin=True):
	rel = os.path.relpath(path, GAME)
	try:
		tree = ET.parse(path)
	except ET.ParseError as ex:
		err(rel, "XML parse error %s" % ex)
		return None
	root = tree.getroot()
	if root.tag != SVGNS + "svg":
		err(rel, "root is not <svg>")
		return None
	try:
		w, h = int(root.get("width")), int(root.get("height"))
	except (TypeError, ValueError):
		err(rel, "width/height must be integer pixels")
		return None
	if root.get("viewBox") != "0 0 %d %d" % (w, h):
		err(rel, "viewBox must be '0 0 %d %d'" % (w, h))
	colours = set()
	for el in root.iter():
		tag = el.tag.replace(SVGNS, "")
		if tag not in ALLOWED:
			err(rel, "element <%s> not allowed" % tag)
		for k, v in el.attrib.items():
			if k in BANNED_ATTR:
				err(rel, "attribute %s not allowed" % k)
			if k in ("fill", "stroke"):
				if v != "none" and not HEX.fullmatch(v):
					err(rel, "%s=%r must be #RRGGBB or none" % (k, v))
				elif v != "none":
					colours.add(v.upper())
			if k == "transform":
				vv = re.sub(r"scale\([^)]*\)", "", v)
				if NUM2.search(vv):
					err(rel, "transform numbers must have <= 1 decimal: %s" % v[:60])
			elif k in ("d", "x", "y", "cx", "cy", "r", "rx", "ry", "width", "height", "x1", "y1", "x2", "y2", "points"):
				if NUM2.search(v):
					err(rel, "coordinates must have <= 1 decimal (%s)" % k)
	if len(colours) > 10:
		err(rel, "%d colours (max 10)" % len(colours))
	size = os.path.getsize(path)
	if size > 24 * 1024:
		warn(rel, "large file %d KB" % (size // 1024))
	if render_margin:
		from PIL import Image
		fd, png = tempfile.mkstemp(suffix=".png")
		os.close(fd)
		subprocess.check_call(["rsvg-convert", path, "-o", png])
		im = Image.open(png).convert("RGBA")
		a = im.split()[-1]
		W, H = im.size
		m = 3
		bad = 0
		px = a.load()
		for x in range(W):
			for y in list(range(0, m)) + list(range(H - m, H)):
				if px[x, y] > 10:
					bad += 1
		for y in range(m, H - m):
			for x in list(range(0, m)) + list(range(W - m, W)):
				if px[x, y] > 10:
					bad += 1
		os.remove(png)
		if bad:
			err(rel, "content inside the 3 px margin (%d px)" % bad)
		if a.getbbox() is None:
			err(rel, "empty SVG")
	return (w, h, colours)


def svg_size(path):
	r = ET.parse(path).getroot()
	return int(r.get("width")), int(r.get("height"))


# --- rig.json ---------------------------------------------------------------------------------
def check_rig(rig):
	W = "rig.json"
	for k in ("version", "rig", "height_px", "root_part", "origin", "parts", "limbs", "face", "residues", "tint", "props",
			  "mirror_pairs"):
		if k not in rig:
			err(W, "missing key %s" % k)
	if rig.get("rig") != "bellows":
		err(W, "rig id must be 'bellows'")
	if rig.get("origin") != "feet":
		err(W, "origin must be 'feet'")
	parts = rig.get("parts", {})
	if len(parts) < 20:
		err(W, "only %d parts (>= 20)" % len(parts))
	for p in PARTS_REQ:
		if p not in parts:
			err(W, "missing part %s" % p)
	if rig.get("root_part") not in parts:
		err(W, "root_part not a part")
	# parent chain
	for n, e in parts.items():
		seen = set()
		cur = n
		while cur:
			if cur in seen:
				err(W, "parent cycle at %s" % n)
				break
			seen.add(cur)
			par = parts.get(cur, {}).get("parent")
			if par and par not in parts:
				err(W, "%s: parent %s missing" % (cur, par))
				break
			cur = par
		if n != rig.get("root_part") and not e.get("parent"):
			err(W, "%s has no parent" % n)
		for k in ("offset", "pivot"):
			v = e.get(k)
			if not (isinstance(v, list) and len(v) == 2 and all(isinstance(x, (int, float)) for x in v)):
				err(W, "%s.%s must be [x, y]" % (n, k))
		if not isinstance(e.get("z"), int):
			err(W, "%s.z must be an integer" % n)
		d = e.get("draw", "")
		if d:
			if not d.startswith("limb:") or d[5:] not in rig.get("limbs", {}):
				err(W, "%s.draw %s does not name a limb" % (n, d))
			continue
		files = []
		if "file" in e:
			files.append(e["file"])
		else:
			err(W, "%s has no file" % n)
		files += list(e.get("tex", {}).values())
		for fp in files:
			if not os.path.exists(res_path(fp)):
				err(W, "%s: missing file %s" % (n, fp))
				continue
			w, h = svg_size(res_path(fp))
			if [w, h] != e.get("size", [w, h]):
				err(W, "%s: %s canvas %dx%d != part size %s" % (n, fp, w, h, e.get("size")))
			px, py = e["pivot"]
			if not (0 <= px <= w and 0 <= py <= h):
				err(W, "%s: pivot %s outside the canvas" % (n, e["pivot"]))
		sp = e.get("spring")
		if sp:
			if sp.get("channel") not in ("rot", "sy", "sx", "x", "y") or not all(k in sp for k in ("k", "c", "clamp")):
				err(W, "%s: bad spring %s" % (n, sp))
		for sn, sv in e.get("sockets", {}).items():
			if not (isinstance(sv, list) and len(sv) == 3):
				err(W, "%s socket %s must be [x, y, angle]" % (n, sn))
		lim = e.get("limits", {}).get("rot")
		if lim and not (len(lim) == 2 and lim[0] < lim[1]):
			err(W, "%s: bad limits %s" % (n, lim))
	# binding textures
	bt = parts.get("bouffant", {}).get("tex", {})
	for t in BOUFFANT:
		if t not in bt:
			err(W, "bouffant texture %s missing" % t)
	for side in ("l", "r"):
		ht = parts.get("hand_" + side, {}).get("tex", {})
		for t in HANDS:
			if t not in ht:
				err(W, "hand_%s texture %s missing" % (side, t))
		for t in ("flat", "tiptoe"):
			if t not in parts.get("foot_" + side, {}).get("tex", {}):
				err(W, "foot_%s texture %s missing" % (side, t))
		for t in SIDEBURNS:
			if t not in parts.get("sideburn_" + side, {}).get("tex", {}):
				err(W, "sideburn_%s texture %s missing" % (side, t))
	for s in SOCKETS_REQ:
		pn, sn = s.split(":")
		if sn not in parts.get(pn, {}).get("sockets", {}):
			err(W, "socket %s missing" % s)
	# limbs
	for lid, L in rig.get("limbs", {}).items():
		j = L.get("joints", [])
		if len(j) != 3 or any(x not in parts for x in j):
			err(W, "limb %s joints %s" % (lid, j))
		else:
			if parts[j[1]].get("parent") != j[0] or parts[j[2]].get("parent") != j[1]:
				err(W, "limb %s joints are not a parent chain" % lid)
		if not (26 <= L.get("width", 0) <= 30):
			err(W, "limb %s width %s (26-30)" % (lid, L.get("width")))
		if L.get("outline") != 6:
			err(W, "limb %s outline must be 6" % lid)
		if not HEX.fullmatch(L.get("fill", "")):
			err(W, "limb %s fill" % lid)
	# mirror pairs
	for a, b in rig.get("mirror_pairs", []):
		for n in parts:
			for x, y in ((a, b), (b, a)):
				if n.endswith(x):
					m = n[: -len(x)] + y
					if m not in parts:
						err(W, "mirror pair: %s has no %s" % (n, m))
					elif set(parts[n].get("tex", {})) != set(parts[m].get("tex", {})):
						err(W, "mirror pair %s/%s texture sets differ" % (n, m))
	# face
	face = rig.get("face", {})
	if face.get("anchor") not in parts:
		err(W, "face.anchor not a part")
	slots = face.get("slots", {})
	for slot, req in (("eyes", EYES), ("brows", BROWS), ("mouth", MOUTHS)):
		v = slots.get(slot, {}).get("variants", {})
		for k in req:
			if k not in v:
				err(W, "face %s variant %s missing" % (slot, k))
		for k, fp in v.items():
			if not os.path.exists(res_path(fp)):
				err(W, "face %s/%s missing file" % (slot, k))
	pu = slots.get("pupils", {})
	if pu.get("range") != [6, 4] or not os.path.exists(res_path(pu.get("file", "?"))):
		err(W, "face pupils must have file + range [6, 4]")
	for ov in OVERLAYS:
		sd = slots.get(ov)
		if not sd or not sd.get("overlay") or not os.path.exists(res_path(sd.get("variants", {}).get("on", "?"))):
			err(W, "face overlay %s missing" % ov)
	for k in slots.get("eyes", {}).get("no_pupils", []):
		if k not in slots.get("eyes", {}).get("variants", {}):
			err(W, "no_pupils names unknown eyes %s" % k)
	for slot, sd in slots.items():
		if "pivot" in sd and "size" in sd and sd["pivot"] != [sd["size"][0] / 2, sd["size"][1] / 2]:
			err(W, "face slot %s pivot must be the canvas centre" % slot)
		if not isinstance(sd.get("z"), int):
			err(W, "face slot %s z must be an integer" % slot)
		if sd.get("overlay") and sd.get("default") != "none":
			err(W, "face overlay %s must default to none" % slot)
	# tint
	t = rig.get("tint", {})
	for p in ("head", "hand_l", "hand_r"):
		if p not in t.get("parts", []):
			err(W, "tint.parts must include %s" % p)
	for p in t.get("parts", []):
		if p not in parts and not (p.startswith("face_") and p[5:] in slots):
			err(W, "tint part %s unknown (a part or face_<slot>)" % p)
	if len(t.get("tiers", [])) != 4 or not all(HEX.fullmatch(c) for c in t.get("tiers", [])):
		err(W, "tint.tiers must be 4 #RRGGBB")
	# props
	props = rig.get("props", {})
	for p in PROPS_REQ:
		if p not in props:
			err(W, "prop %s missing" % p)
	for pn, pd in props.items():
		if not isinstance(pd.get("z_offset"), int):
			err(W, "prop %s needs an integer z_offset" % pn)
		fps = [pd.get("file")] + list(pd.get("tex", {}).values())
		for fp in fps:
			if not fp or not os.path.exists(res_path(fp)):
				err(W, "prop %s missing file %s" % (pn, fp))
		if pd.get("states") and set(pd["states"]) != set(pd.get("tex", {})):
			err(W, "prop %s states != tex keys" % pn)
		for s in [pd.get("socket")] + list(pd.get("state_sockets", {}).values()):
			part, _, sn = (s or "").partition(":")
			if sn not in parts.get(part, {}).get("sockets", {}):
				err(W, "prop %s socket %s does not resolve" % (pn, s))
	spec = props.get("specs", {})
	for st in ("dangling", "on", "buttered", "magnifier"):
		if st not in spec.get("tex", {}):
			err(W, "specs state %s missing" % st)
	for st in ("closed", "open"):
		if st not in props.get("newspaper", {}).get("tex", {}):
			err(W, "newspaper state %s missing" % st)
	# residues + combos
	resd = rig.get("residues", {})
	for k in RESIDUES:
		if k not in resd:
			err(W, "residue %s missing" % k)
	for v in COSTUMES:
		if "COSTUME:" + v not in resd:
			err(W, "flat residue key COSTUME:%s missing" % v)
	for c in COMBOS:
		if "COMBO:" + c not in resd:
			err(W, "flat residue key COMBO:%s missing" % c)
	cost = resd.get("COSTUME", {})
	for v in COSTUMES:
		if v not in cost.get("variants", {}):
			err(W, "COSTUME variant %s missing" % v)
	if cost.get("default") not in cost.get("variants", {}):
		err(W, "COSTUME default must be a variant")
	looks = [(k, v) for k, v in resd.items()] + [("COSTUME/" + k, v) for k, v in cost.get("variants", {}).items()]
	combos = rig.get("combos", {})
	for c, of in COMBOS.items():
		if c not in combos:
			err(W, "combo %s missing" % c)
		elif sorted(combos[c].get("of", [])) != sorted(of):
			err(W, "combo %s must be of %s" % (c, of))
	looks += [("combo/" + k, v) for k, v in combos.items()]
	for key, lk in looks:
		for pn, tx in lk.get("tex", {}).items():
			if tx not in parts.get(pn, {}).get("tex", {}):
				err(W, "%s: tex %s.%s unknown" % (key, pn, tx))
		for pn, fps in lk.get("overlays", {}).items():
			if pn not in parts:
				err(W, "%s: overlay on unknown part %s" % (key, pn))
				continue
			for fp in (fps if isinstance(fps, list) else [fps]):
				if not os.path.exists(res_path(fp)):
					err(W, "%s: overlay file %s missing" % (key, fp))
					continue
				w, h = svg_size(res_path(fp))
				e = parts[pn]
				if "size" in e and [w, h] != e["size"]:
					err(W, "%s: overlay %s canvas %dx%d != %s canvas %s (must share the pivot)" % (key, fp, w, h, pn, e["size"]))
				px, py = e["pivot"]
				if not (0 <= px <= w and 0 <= py <= h):
					err(W, "%s: overlay %s: pivot outside canvas" % (key, fp))
		for fo in lk.get("face_overlays", []):
			if not slots.get(fo, {}).get("overlay"):
				err(W, "%s: face overlay %s unknown" % (key, fo))
		for prn, sock in lk.get("props", {}).items():
			part, _, sn = sock.partition(":")
			if prn not in props or sn not in parts.get(part, {}).get("sockets", {}):
				err(W, "%s: prop %s @ %s does not resolve" % (key, prn, sock))
		for lid in lk.get("limb_fill", {}):
			if lid not in rig.get("limbs", {}):
				err(W, "%s: limb_fill %s unknown" % (key, lid))
		if not any(lk.get(k) for k in ("tex", "overlays", "face_overlays", "props", "limb_fill")):
			err(W, "%s has no look" % key)


def check_faces(rig, faces):
	W = "faces.json"
	pr = faces.get("presets", {})
	if len(pr) < 16:
		err(W, "%d presets (>= 16)" % len(pr))
	for k in faces_spec.REQUIRED:
		if k not in pr:
			err(W, "preset %s missing" % k)
	slots = rig["face"]["slots"]
	for n, p in pr.items():
		for s in ("eyes", "brows", "mouth"):
			if p.get(s) not in slots[s]["variants"]:
				err(W, "%s.%s = %s unknown" % (n, s, p.get(s)))
		for s, val in p.items():
			sd = slots.get(s)
			if sd is None:
				err(W, "%s: %s is not a face slot" % (n, s))
			elif val != "none" and val not in sd.get("variants", {}) and not (val == "default" and "file" in sd):
				err(W, "%s.%s = %s is not a variant" % (n, s, val))
		if p.get("eyes") in slots["eyes"].get("no_pupils", []) and p.get("pupils") != "none":
			err(W, "%s: eyes %s draw their own pupils; pupils must be none" % (n, p.get("eyes")))
		lid = slots["eyes"].get("lids", {}).get(p.get("eyes"), "none")
		if p.get("lids", "none") != lid:
			err(W, "%s: eyes %s need lids %s" % (n, p.get("eyes"), lid))
	for n, gz in faces.get("gaze", {}).items():
		if n not in pr:
			err(W, "gaze for unknown preset %s" % n)
		if abs(gz[0]) > 6 or abs(gz[1]) > 4:
			err(W, "gaze %s %s outside the pupils range [6, 4]" % (n, gz))


def check_poses(rig, poses, faces):
	W = "poses.json"
	P = poses.get("poses", {})
	mo = poses.get("mirror_of", {})
	names = set(P) | set(mo)
	if len(names) < 50:
		err(W, "%d poses (>= 50)" % len(names))
	for n in poses_spec.REQUIRED:
		if n not in names:
			err(W, "pose %s missing" % n)
	parts = rig["parts"]
	for n, p in P.items():
		if "base" in p and p["base"] not in names:
			err(W, "%s base %s unknown" % (n, p["base"]))
		for k in p.get("root", {}):
			if k not in ROOT_CH:
				err(W, "%s root channel %s" % (n, k))
		for b, ch in p.get("bones", {}).items():
			if b not in parts:
				err(W, "%s: bone %s unknown" % (n, b))
				continue
			for c, v in ch.items():
				if c not in CHANNELS:
					err(W, "%s.%s channel %s" % (n, b, c))
				if c == "tex" and v not in parts[b].get("tex", {}):
					err(W, "%s.%s tex %s unknown" % (n, b, v))
				if c == "z" and not isinstance(v, int):
					err(W, "%s.%s z must be an integer" % (n, b))
		if "face" in p and p["face"] not in faces["presets"]:
			err(W, "%s face %s unknown" % (n, p["face"]))
		tags = p.get("tags", [])
		if not tags:
			err(W, "%s has no tags" % n)
		if any(t in tags for t in ("take", "reaction", "state")) and not p.get("silhouette"):
			err(W, "%s (take/reaction/state) needs a silhouette note" % n)
	for k, v in mo.items():
		if v not in P:
			err(W, "mirror_of %s -> %s unknown" % (k, v))
	# base cycles
	for n in P:
		seen = set()
		cur = n
		while cur in P and "base" in P[cur]:
			if cur in seen:
				err(W, "base cycle at %s" % n)
				break
			seen.add(cur)
			cur = P[cur]["base"]


def check_fk(rigobj, render=True):
	W = "fk"
	import parts_body as B
	names = rigobj.pose_names()
	for n in names:
		pose = rigobj.pose(n)
		for b, ch in pose["bones"].items():
			lim = rigobj.parts[b].get("limits", {}).get("rot")
			if lim and "rot" in ch and not (lim[0] - 0.01 <= ch["rot"] <= lim[1] + 0.01):
				err(W, "%s.%s rot %.1f outside limits %s" % (n, b, ch["rot"], lim))
		if n in poses_spec.PLANT and "sit" not in poses_spec.POSES.get(n, {}).get("tags", []):
			M0, Wm = rigobj.solve(pose)
			low = max(fk.apply(Wm[f], p)[1] for f in ("foot_r", "foot_l")
					  for p in B.FOOT_SOLE[pose["bones"].get(f, {}).get("tex", "flat")])
			if abs(low) > 1.5:
				err(W, "%s: planted sole at y %.1f (must touch the floor)" % (n, low))
	if not render:
		return
	bb = fk.bbox(rigobj, rigobj.pose("b_stand"))
	h = bb[3] - bb[1]
	hp = rigobj.rig["height_px"]
	if abs(h - hp) > 0.2 * hp:
		err(W, "rest height %.0f px not within 20%% of %d" % (h, hp))
	elif abs(h - hp) > 0.05 * hp:
		warn(W, "rest height %.0f px vs height_px %d" % (h, hp))
	print("rest pose: %.0f x %.0f px (height_px %d)" % (bb[2] - bb[0], h, hp))
	for a, b in poses_spec.TAKE_PAIRS:
		ba = fk.bbox(rigobj, rigobj.pose(a))
		bb2 = fk.bbox(rigobj, rigobj.pose(b))
		wa, ha = ba[2] - ba[0], ba[3] - ba[1]
		wb, hb = bb2[2] - bb2[0], bb2[3] - bb2[1]
		d = max(abs(wb - wa) / wa, abs(hb - ha) / ha)
		line = "take %s -> %s: bbox %.0fx%.0f -> %.0fx%.0f (%.0f%%)" % (a, b, wa, ha, wb, hb, 100 * d)
		print(line)
		if d < 0.15:
			err(W, line + " < 15 %")


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--no-render", action="store_true")
	a = ap.parse_args()
	n = 0
	for root, _d, files in os.walk(ART):
		if "_src" in root:
			continue
		for fn in sorted(files):
			if fn.endswith(".svg"):
				check_svg(os.path.join(root, fn), not a.no_render)
				n += 1
	rig = json.load(open(os.path.join(DATA, "rig.json")))
	poses = json.load(open(os.path.join(DATA, "poses.json")))
	faces = json.load(open(os.path.join(DATA, "faces.json")))
	check_rig(rig)
	check_faces(rig, faces)
	check_poses(rig, poses, faces)
	check_fk(fk.Rig(rig, poses, faces), not a.no_render)
	for w in warnings:
		print("warning:", w)
	for e in errors:
		print("ERROR:", e)
	print("%d SVGs, %d parts, %d poses, %d presets: %s" % (n, len(rig["parts"]), len(fk.Rig(rig, poses, faces).pose_names()),
														  len(faces["presets"]), "OK" if not errors else "%d errors" % len(errors)))
	sys.exit(1 if errors else 0)


if __name__ == "__main__":
	main()
