#!/usr/bin/env python3
"""Build every Bellows SVG + game/data/rigs/bellows/{rig,poses,faces}.json from the generators.

    python3 tools/art/bellows/build.py

Deterministic: rerunning produces byte-identical files.
"""
import json
import os
import sys

sys.dont_write_bytecode = True  # keep tools/art/bellows free of __pycache__

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import svgk
from svgk import shared_canvas, centered_canvas, union, write
import rig_spec as R
import parts_body as B
import parts_head as H
import parts_face as F
import parts_props as PR
import parts_residue as RS
import poses_spec
import faces_spec

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
GAME = os.path.join(REPO, "game")
ART = os.path.join(GAME, "art", "chars", "bellows")
DATA = os.path.join(GAME, "data", "rigs", "bellows")


def res(rel):
	return R.ART_DIR + rel


def disk(rel):
	return os.path.join(ART, rel)


def part_variants():
	"""name -> (default_tex, {tex: Part}, extra_bbox)"""
	V = {}
	V["torso"] = (None, {"_": B.torso()}, None)
	V["belly"] = (None, {"_": B.belly()}, None)
	V["coat_tails"] = (None, {"_": B.coat_tails()}, None)
	V["cravat"] = (None, {"_": B.cravat()}, None)
	V["head"] = (None, {"_": H.head()}, None)
	V["nose"] = (None, {"_": H.nose()}, None)
	V["bouffant"] = ("neat", {k: H.bouffant(k) for k in ["neat", "flipped", "frazzled", "wet", "floured", "feathered",
														 "poodle"]}, H.BOUF_EXTRA)
	for side, far in (("r", False), ("l", True)):
		V["sideburn_" + side] = ("flat", {k: H.sideburn(k, far) for k in ["flat", "bristle", "puffed", "wet"]},
								 H.SB_L_EXTRA if far else H.SB_R_EXTRA)
		V["hand_" + side] = ("open", {k: B.hand(k, far) for k in B.HAND_KINDS}, B.HAND_EXTRA)
		V["foot_" + side] = ("flat", {k: B.foot(k, far) for k in ["flat", "tiptoe"]}, B.FOOT_EXTRA)
	return V


def main():
	V = part_variants()
	overlays = RS.overlays()          # {(residue_key, part): Part}
	# canvases: union of all textures + overlays on that part
	canvases = {}
	for name, (dflt, tex, extra) in V.items():
		ov = [p for (k, pn), p in overlays.items() if pn == name]
		bb = union(*([svgk.measure(p) for p in tex.values()] + [svgk.measure(p) for p in ov]))
		canvases[name] = list(tex.values())[0].canvas(bb)
	# limb bones: overlay canvases around the bone joint
	for bone in R.PARTS:
		if R.PARTS[bone][3].get("draw", "").startswith("limb:"):
			ov = [p for (k, pn), p in overlays.items() if pn == bone]
			if ov:
				bb = union(*[svgk.measure(p) for p in ov])
				bb = union(bb, (-2, -2, 2, 2))
				canvases[bone] = ov[0].canvas(bb)

	prop_specs = PR.props()
	# torso:seat = the barrel's seat point + the stool's pivot offset below its cushion (the stool prop's pivot)
	seat_dy = prop_specs["stool"]["pivot_y"] - PR.STOOL_SEAT[1]
	R.SOCKETS["torso"]["seat"] = [R.SEAT_POINT[0], round(R.SEAT_POINT[1] + seat_dy, 1), 0]

	rig = {"version": 1, "rig": R.RIG_ID, "height_px": R.HEIGHT_PX, "root_part": "torso", "origin": "feet",
		   "doc": ("Conventions" + R.__doc__.split("Conventions")[1]).strip(),
		   "parts": {}}
	written = []
	for name, (parent, offset, z, extra) in R.PARTS.items():
		e = {}
		if parent:
			e["parent"] = parent
		e["offset"] = [offset[0], offset[1]]
		if extra.get("draw"):
			e["draw"] = extra["draw"]
			cv = canvases.get(name)
			e["pivot"] = list(cv[2]) if cv else list(R.BONE_PIVOT)
		else:
			dflt, tex, _ = V[name]
			cv = canvases[name]
			e["pivot"] = list(cv[2])
			e["size"] = [cv[0], cv[1]]
			if dflt is None:
				rel = "parts/%s.svg" % name
				written.append(write(disk(rel), tex["_"].svg(cv)))
				e["file"] = res(rel)
			else:
				e["file"] = res("parts/%s_%s.svg" % (name, dflt))
				e["tex"] = {}
				for k, p in tex.items():
					rel = "parts/%s_%s.svg" % (name, k)
					written.append(write(disk(rel), p.svg(cv)))
					e["tex"][k] = res(rel)
		e["z"] = z
		if "spring" in extra:
			e["spring"] = extra["spring"]
		lim = extra.get("limits") or ({"rot": R.LIMITS[name]} if name in R.LIMITS else None)
		if lim:
			e["limits"] = lim
		socks = {}
		if name in ("hand_r", "hand_l"):
			gx, gy = B.GRIP["grip"]
			socks["grip"] = [gx, gy, 90]
		elif name in R.SOCKETS:
			socks = {k: v for k, v in R.SOCKETS[name].items() if v}
		if socks:
			# joint-relative -> part canvas px (TECH §4.7 example; RigDef subtracts the pivot)
			px, py = e["pivot"]
			e["sockets"] = {k: [round(v[0] + px, 1), round(v[1] + py, 1), v[2]] for k, v in socks.items()}
		rig["parts"][name] = e

	rig["limbs"] = {}
	for lid, L in R.LIMBS.items():
		d = dict(L)
		d.update(R.LIMB_COMMON)
		rig["limbs"][lid] = d

	# face
	face_slots = {}
	slot_parts = {
		"eyes": {k: F.eyes(k) for k in F.EYE_KINDS},
		"brows": {k: F.brows(k) for k in F.BROW_KINDS},
		"mouth": {k: F.mouth(k) for k in F.MOUTH_KINDS},
	}
	for slot, parts in slot_parts.items():
		cv = centered_canvas(list(parts.values()))
		sd = {"z": R.FACE_Z[slot], "pivot": list(cv[2]), "size": [cv[0], cv[1]], "variants": {}}
		for k, p in parts.items():
			rel = "face/%s_%s.svg" % (slot, k)
			written.append(write(disk(rel), p.svg(cv)))
			sd["variants"][k] = res(rel)
		face_slots[slot] = sd
	face_slots["eyes"]["no_pupils"] = list(F.NO_PUPILS)
	face_slots["eyes"]["lids"] = dict(F.EYE_LIDS)
	pp = F.pupils()
	cv = centered_canvas([pp])
	written.append(write(disk("face/pupils.svg"), pp.svg(cv)))
	face_slots["pupils"] = {"z": R.FACE_Z["pupils"], "pivot": list(cv[2]), "size": [cv[0], cv[1]],
							"file": res("face/pupils.svg"), "range": [6, 4]}
	lids = {k: F.lids(k) for k in F.LID_KINDS}
	cv = centered_canvas(list(lids.values()))
	face_slots["lids"] = {"z": R.FACE_Z["lids"], "pivot": list(cv[2]), "size": [cv[0], cv[1]], "default": "none",
						  "variants": {}}
	for k, p in lids.items():
		rel = "face/lids_%s.svg" % k
		written.append(write(disk(rel), p.svg(cv)))
		face_slots["lids"]["variants"][k] = res(rel)
	for ov in F.OVERLAYS:
		p = F.overlay(ov)
		cv = centered_canvas([p])
		rel = "face/%s.svg" % ov
		written.append(write(disk(rel), p.svg(cv)))
		face_slots[ov] = {"z": R.FACE_Z[ov], "pivot": list(cv[2]), "size": [cv[0], cv[1]], "overlay": True,
						  "default": "none", "variants": {"on": res(rel)}}
	rig["face"] = {"anchor": R.FACE_ANCHOR, "offset": list(R.FACE_OFFSET), "slots": face_slots,
				   "overlays": list(F.OVERLAYS)}

	# residues + combos
	res_map, combos, extra_written = RS.residue_map(canvases, disk, res)
	written += extra_written
	rig["residues"] = res_map
	rig["combos"] = combos
	rig["tint"] = {"parts": list(R.TINT_PARTS), "tiers": list(R.TINT_TIERS)}

	# props
	props = {}
	for name, spec in prop_specs.items():
		states = spec["states"]
		cv = shared_canvas(list(states.values()))
		sock_part = spec["socket"].split(":")[0]
		e = {"pivot": list(cv[2]), "size": [cv[0], cv[1]], "socket": spec["socket"],
			 "z_offset": int(spec["z"] - R.PARTS[sock_part][2])}
		if len(states) == 1 and "_" in states:
			rel = "props/%s.svg" % name
			written.append(write(disk(rel), states["_"].svg(cv)))
			e["file"] = res(rel)
		else:
			e["states"] = list(states.keys())
			e["tex"] = {}
			for k, p in states.items():
				rel = "props/%s_%s.svg" % (name, k)
				written.append(write(disk(rel), p.svg(cv)))
				e["tex"][k] = res(rel)
			e["file"] = e["tex"][spec["default"]]
			e["default"] = spec["default"]
		e["hidden"] = not spec.get("visible", False)
		if spec.get("state_sockets"):
			e["state_sockets"] = spec["state_sockets"]
		if spec.get("state_z_offset"):
			e["state_z_offset"] = spec["state_z_offset"]
		if spec.get("note"):
			e["note"] = spec["note"]
		props[name] = e
	rig["props"] = props
	rig["mirror_pairs"] = R.MIRROR_PAIRS
	rig["no_mirror"] = []
	rig["breath"] = dict(R.BREATH)
	rig["look"] = dict(R.LOOK)
	rig["masks"] = {k: list(v) for k, v in R.MASKS.items()}

	os.makedirs(DATA, exist_ok=True)
	with open(os.path.join(DATA, "rig.json"), "w") as fh:
		json.dump(rig, fh, indent=2)
		fh.write("\n")
	faces = faces_spec.faces_json(F)
	with open(os.path.join(DATA, "faces.json"), "w") as fh:
		json.dump(faces, fh, indent=2)
		fh.write("\n")
	poses = poses_spec.poses_json()
	with open(os.path.join(DATA, "poses.json"), "w") as fh:
		json.dump(poses, fh, indent=2)
		fh.write("\n")
	# remove stale SVGs this build no longer writes
	keep = set(os.path.abspath(p) for p in written)
	for root, _dirs, files in os.walk(ART):
		if "_src" in root:
			continue
		for fn in files:
			if fn.endswith(".svg") and os.path.abspath(os.path.join(root, fn)) not in keep:
				os.remove(os.path.join(root, fn))
	print("wrote %d SVGs + rig/poses/faces.json" % len(written))


if __name__ == "__main__":
	main()
