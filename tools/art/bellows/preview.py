#!/usr/bin/env python3
"""Render Bellows review sheets with the Python FK compositor (rsvg-convert + Pillow).

    python3 tools/art/bellows/preview.py --out <dir> [--only poses,expressions,...]

Sheets (each also written as a phone-scale copy `<name>_phone.png`, 1200 px wide):
  rest.png         rest pose at 2x with joint markers + every part texture with its pivot
  poses.png        every pose, labelled, with a solid-black 50 px silhouette beside it
  expressions.png  the head at 2x for every faces.json preset
  residues.png     rest pose x the 7 residues, the blind flip, the 7 COSTUME variants and the 4 combos
  temper.png       the same take at the 4 temper tints (Calm, Irked, Steaming, Livid)
  props.png        every prop state + the poses that hold props
  scale.png        Bellows beside Hush (her rig if present, else a 340 px grey placeholder)
"""
import argparse
import json
import math
import os
import sys

sys.dont_write_bytecode = True  # keep tools/art/bellows free of __pycache__

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fk  # noqa: E402
import faces_spec  # noqa: E402
import poses_spec  # noqa: E402

BG = "#EDE3D0"
FLOOR = "#C98B55"
LABEL = "#1B2340"


def text(x, y, s, size=14, anchor="middle", col=LABEL, weight="bold"):
	s = s.replace("&", "&amp;").replace("<", "&lt;")
	return ('<text x="%.1f" y="%.1f" font-family="DejaVu Sans" font-size="%d" font-weight="%s" fill="%s" '
			'text-anchor="%s">%s</text>' % (x, y, size, weight, col, anchor, s))


def floor_line(x0, x1, y):
	return '<rect x="%.1f" y="%.1f" width="%.1f" height="6" fill="%s"/>' % (x0, y, x1 - x0, FLOOR)


def save(svg, out, name, zoom=1.0, phone=True):
	png = os.path.join(out, name + ".png")
	fk.render(svg, png, zoom)
	if phone:
		from PIL import Image
		im = Image.open(png)
		w = 1200
		h = int(im.height * w / im.width)
		im.convert("RGB").resize((w, h), Image.LANCZOS).save(os.path.join(out, name + "_phone.png"))
	return png


def pose_props(name):
	return dict(poses_spec.PREVIEW_PROPS.get(name, {}))


# ---------------------------------------------------------------------------------------------
def sheet_rest(rig, out):
	W, H = 1500, 560
	body = [floor_line(0, 460, 470)]
	p = rig.pose("b_stand")
	body.append(rig.compose(p, ox=230, oy=470, props=pose_props("b_stand")))
	body.append(text(230, 520, "b_stand (rest)", 18))
	body.append(floor_line(470, 930, 470))
	body.append(rig.compose(p, ox=700, oy=470, show_pivots=True))
	body.append(text(700, 520, "joints (red dots)", 18))
	# parts, each with its pivot crosshair
	x, y = 960, 20
	rowh = 0
	for n in rig.order:
		e = rig.parts[n]
		if "size" not in e:
			continue
		w, h = e["size"]
		s = min(1.0, 110.0 / max(w, h))
		if x + w * s > W - 10:
			x = 960
			y += rowh + 26
			rowh = 0
		inner = fk.inner_svg(e["file"])
		px, py = e["pivot"]
		body.append('<g transform="translate(%.1f %.1f) scale(%.3f)"><rect x="0" y="0" width="%d" height="%d" fill="none" '
					'stroke="#B8A888" stroke-width="2"/>%s<path d="M%.1f %.1f h-10 h20 M%.1f %.1f v-10 v20" stroke="#E23B4E" '
					'stroke-width="3"/></g>' % (x, y, s, w, h, inner, px, py, px, py))
		body.append(text(x + w * s / 2, y + h * s + 14, n, 10))
		x += w * s + 14
		rowh = max(rowh, h * s)
	svg = fk.svg_doc(W, max(H, int(y + rowh + 40)), "".join(body), bg=BG)
	return save(svg, out, "rest", 1.0)


def sheet_poses(rig, out, cols=9, names=None, zoom=0.5, name="poses"):
	names = names or rig.pose_names()
	cw, ch = 400, 520
	cols = min(cols, len(names))
	rows = (len(names) + cols - 1) // cols
	body = []
	sil_scale = 50.0 / 380.0
	floor_y = 440
	for i, n in enumerate(names):
		cx, cy = (i % cols) * cw, (i // cols) * ch
		pose = rig.pose(n)
		props = pose_props(n)
		bb = fk.bbox(rig, pose, props=props) or (-100, -380, 100, 0)
		# fit: centre horizontally; grounded poses stand on the floor line, airborne ones are lifted into view
		sc = min(1.0, (ch - 96) / max(1.0, bb[3] - bb[1]), (cw - 84) / max(1.0, bb[2] - bb[0]))
		dx = cx + (cw - 70) / 2 - (bb[0] + bb[2]) / 2 * sc
		air = bb[3] < -6
		dy = cy + floor_y if not air else cy + floor_y - 30 - bb[3] * sc
		if bb[1] * sc + dy < cy + 6:
			dy = cy + 6 - bb[1] * sc
		body.append('<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="#D2C4A6" stroke-width="2"/>' % (cx, cy, cw, ch))
		if not air:
			body.append(floor_line(cx + 4, cx + cw - 70, cy + floor_y))
		body.append('<svg x="%d" y="%d" width="%d" height="%d" viewBox="%d %d %d %d">%s</svg>' % (
			cx, cy, cw - 66, ch - 70, cx, cy, cw - 66, ch - 70, rig.compose(pose, ox=dx, oy=dy, scale=sc, props=props)))
		body.append(floor_line(cx + cw - 64, cx + cw - 6, cy + floor_y))
		body.append(rig.compose(pose, ox=cx + cw - 36 - (bb[0] + bb[2]) / 2 * sil_scale,
								oy=cy + floor_y - (0 if not air else bb[3] * sil_scale + 2), scale=sil_scale,
								silhouette=True, props=props))
		body.append(text(cx + cw / 2, cy + 478, n + ("  (airborne)" if air else ""), 20))
		tags = ",".join(pose.get("tags", [])[:3])
		body.append(text(cx + cw / 2, cy + 502, tags, 14, weight="normal"))
	svg = fk.svg_doc(cols * cw, rows * ch, "".join(body), bg=BG)
	return save(svg, out, name, zoom)


def head_cell(rig, preset, x, y, w, h, zoom=2.0, pose="b_slow_burn", **kw):
	"""A nested <svg> viewport cropping the head at `zoom`."""
	p = rig.pose(pose)
	M0, W = rig.solve(p)
	hx, hy = fk.apply(W["head"], (22, -46))
	vw, vh = w / zoom, h / zoom
	inner = rig.compose(p, face=preset, **kw)
	return ('<svg x="%d" y="%d" width="%d" height="%d" viewBox="%.1f %.1f %.1f %.1f">%s</svg>'
			% (x, y, w, h, hx - vw / 2, hy - vh / 2 - 6, vw, vh, inner))


def sheet_expressions(rig, out, cols=8):
	names = list(faces_spec.PRESETS)
	cw, ch = 300, 330
	rows = (len(names) + cols - 1) // cols
	body = []
	for i, n in enumerate(names):
		cx, cy = (i % cols) * cw, (i // cols) * ch
		body.append('<rect x="%d" y="%d" width="%d" height="%d" fill="#F6EFE2" stroke="#D2C4A6" stroke-width="2"/>' % (cx, cy, cw, ch))
		body.append(head_cell(rig, n, cx + 4, cy + 4, cw - 8, ch - 44, 1.55))
		body.append(text(cx + cw / 2, cy + ch - 14, n, 20))
	svg = fk.svg_doc(cols * cw, rows * ch, "".join(body), bg=BG)
	return save(svg, out, "expressions", 0.5)


LOOKS = [("clean", {}), ("SOAKED", dict(residues=["SOAKED"])), ("FLOURY", dict(residues=["FLOURY"])),
		 ("STICKY", dict(residues=["STICKY"])), ("SQUEAKY", dict(residues=["SQUEAKY"])),
		 ("FRAZZLED", dict(residues=["FRAZZLED"])), ("FEATHERED", dict(residues=["FEATHERED"])),
		 ("FRAZZLED blind", dict(residues=["FRAZZLED"], tex_over={"bouffant": "flipped"}))]
COST = [("COSTUME " + c, dict(residues=["COSTUME"], costume=c)) for c in
		["jelly_helmet", "tutu_tulle", "tutu_chandelier", "trophy_helmet", "long_johns", "hedge_twigs", "umbrella_stand"]]
COMB = [("combo dough_man", dict(residues=["SOAKED", "FLOURY"], combo="dough_man")),
		("combo poodle", dict(residues=["SOAKED", "FRAZZLED"], combo="poodle")),
		("combo chicken", dict(residues=["STICKY", "FEATHERED"], combo="chicken")),
		("combo mad_maestro", dict(residues=["FRAZZLED", "SQUEAKY"], combo="mad_maestro"))]


def sheet_residues(rig, out, cols=7):
	items = LOOKS + COST + COMB
	cw, ch = 330, 520
	rows = (len(items) + cols - 1) // cols
	body = []
	for i, (n, kw) in enumerate(items):
		cx, cy = (i % cols) * cw, (i // cols) * ch
		body.append('<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="#D2C4A6" stroke-width="2"/>' % (cx, cy, cw, ch))
		body.append(floor_line(cx + 4, cx + cw - 4, cy + 460))
		pose = "b_tiptoe_mortified" if "tutu" in n else "b_slow_burn"
		props = {"specs": (None, "dangling")}
		body.append(rig.compose(rig.pose(pose), ox=cx + 160, oy=cy + 460, props=props, **kw))
		body.append(text(cx + cw / 2, cy + 500, n, 20))
	svg = fk.svg_doc(cols * cw, rows * ch, "".join(body), bg=BG)
	return save(svg, out, "residues", 0.5)


def sheet_temper(rig, out):
	tiers = [("Calm", 0, "neutral", {"sideburn_r": "flat", "sideburn_l": "flat"}),
			 ("Irked", 1, "irked", {"sideburn_r": "bristle", "sideburn_l": "bristle"}),
			 ("Steaming", 2, "furious", {"sideburn_r": "bristle", "sideburn_l": "bristle"}),
			 ("Livid", 3, "livid", {"sideburn_r": "puffed", "sideburn_l": "puffed"})]
	cw, ch = 380, 900
	body = []
	for i, (n, t, face, tex) in enumerate(tiers):
		cx = i * cw
		body.append(floor_line(cx + 4, cx + cw - 4, 460))
		props = {"specs": (None, "on" if t == 3 else "dangling")}
		body.append(rig.compose(rig.pose("b_stomp_a" if t >= 2 else "b_stand"), ox=cx + 180, oy=460, tint=t, face=face,
								tex_over=tex, props=props))
		body.append(text(cx + cw / 2, 500, "%s (tier %d)" % (n, t), 22))
		body.append(head_cell(rig, face, cx + 10, 520, cw - 20, 330, 1.8, tint=t, tex_over=tex, props=props))
	body.append(text(2 * cw, 880, "same poses, tint tiers %s on head/nose/hands; face slots untinted" %
					 " ".join(rig.rig["tint"]["tiers"]), 18, weight="normal"))
	svg = fk.svg_doc(4 * cw, ch, "".join(body), bg=BG)
	return save(svg, out, "temper", 0.6)


def sheet_props(rig, out):
	body = []
	x, y = 20, 20
	rowh = 0
	W = 1500
	for pn, pd in rig.rig["props"].items():
		states = pd.get("states") or [None]
		for st in states:
			fp = pd["tex"][st] if st else pd["file"]
			w, h = pd["size"]
			s = min(1.0, 170.0 / max(w, h))
			if x + w * s > W - 20:
				x = 20
				y += rowh + 40
				rowh = 0
			px, py = pd["pivot"]
			body.append('<g transform="translate(%.1f %.1f) scale(%.3f)"><rect width="%d" height="%d" fill="none" stroke="#B8A888" '
						'stroke-width="2"/>%s<path d="M%.1f %.1f h-8 h16 M%.1f %.1f v-8 v16" stroke="#E23B4E" stroke-width="3"/></g>'
						% (x, y, s, w, h, fk.inner_svg(fp), px, py, px, py))
			body.append(text(x + w * s / 2, y + h * s + 18, pn + ("/" + st if st else ""), 13))
			x += w * s + 24
			rowh = max(rowh, h * s)
	y += rowh + 60
	demo = [("b_tea_sip", {"teacup": (None, None)}), ("b_sit_read", {"newspaper": (None, "open")}),
			("b_phone_pompous", {"phone_handset": (None, None)}), ("b_fish_slap_recoil", {"kipper_held": (None, None)}),
			("b_suspicious", {"specs": (None, "on")}), ("b_door_reach", {"specs": (None, "dangling"), "megaphone": (None, None)}),
			("b_preen", {"comb": (None, None)}), ("b_stand", {"pickled_onion": (None, None)}),
			("b_dt_back", {"kettle_lid": (None, None)}), ("b_blind_arms_out", {"specs": (None, "buttered")}),
			("b_stand", {"specs": (None, "magnifier")}), ("b_tiptoe_mortified", {"baton": (None, None)})]
	cw = 250
	for i, (pn, props) in enumerate(demo):
		cx = 10 + (i % 6) * cw
		cy = y + (i // 6) * 500
		body.append(floor_line(cx, cx + cw - 10, cy + 440))
		face = "magnified" if "specs" in props and props["specs"][1] == "magnifier" else None
		body.append(rig.compose(rig.pose(pn), ox=cx + 120, oy=cy + 440, props=props, face=face))
		body.append(text(cx + cw / 2, cy + 476, pn + " + " + ",".join(props), 14))
	svg = fk.svg_doc(W, int(y + 1010), "".join(body), bg=BG)
	return save(svg, out, "props", 0.8)


def sheet_scale(rig, out):
	body = [floor_line(0, 900, 460)]
	# rulers
	for yy in range(0, 400, 20):
		body.append('<path d="M10 %d h%d" stroke="#1B2340" stroke-opacity="0.25" stroke-width="%d"/>' % (460 - yy, 16 if yy % 100 == 0 else 8, 2))
	body.append(text(40, 460 - 380 - 6, "380", 14, anchor="start"))
	body.append(text(40, 460 - 340 - 6, "340", 14, anchor="start"))
	body.append('<path d="M30 %d h840 M30 %d h840" stroke="#E23B4E" stroke-width="1.5" stroke-dasharray="6 6"/>' % (460 - 380, 460 - 340))
	hush = os.path.join(fk.GAME, "data", "rigs", "hush", "rig.json")
	drew = False
	if os.path.exists(hush):
		try:
			hr = fk.Rig(json.load(open(hush)), json.load(open(os.path.join(os.path.dirname(hush), "poses.json"))),
						json.load(open(os.path.join(os.path.dirname(hush), "faces.json"))))
			first = hr.pose_names()[0]
			for cand in ("h_stand", first):
				if cand in hr.pose_names():
					first = cand
					break
			body.append(hr.compose(hr.pose(first), ox=640, oy=460))
			body.append(text(640, 500, "Hush (%s)" % first, 18))
			drew = True
		except Exception as ex:  # her rig may use conventions this compositor does not know
			body.append(text(640, 530, "Hush rig present but not composable here: %s" % str(ex)[:60], 12, weight="normal"))
	if not drew:
		body.append('<rect x="580" y="%d" width="120" height="340" rx="50" fill="#8E96A8"/>' % (460 - 340))
		body.append(text(640, 500, "Hush placeholder 340 px", 18))
	body.append(rig.compose(rig.pose("b_stand"), ox=300, oy=460, props=pose_props("b_stand")))
	body.append(text(300, 500, "Bellows 380 px", 18))
	svg = fk.svg_doc(900, 540, "".join(body), bg=BG)
	return save(svg, out, "scale", 1.0)


def sheet_phone_scene(rig, out):
	"""True phone scale: a 2400 x 1080 logical frame (20:9) shown at 1200 x 540, characters at zoom 1.0."""
	W, H, s = 2400, 1080, 0.5
	floor = 900
	body = ['<rect x="0" y="0" width="%d" height="%d" fill="#D9A7A0"/>' % (W, floor),
			'<rect x="0" y="%d" width="%d" height="%d" fill="#C98B55"/>' % (floor, W, H - floor),
			'<rect x="0" y="%d" width="%d" height="14" fill="#A96C3C"/>' % (floor, W)]
	shots = [("b_stand", {}, {"specs": (None, "dangling")}), ("b_take_accent", {}, {}),
			 ("b_slow_burn", {"residues": ["SOAKED"]}, {}), ("b_sneeze_choo", {"tint": 2}, {}),
			 ("b_tiptoe_mortified", {"residues": ["COSTUME"], "costume": "tutu_tulle"}, {}),
			 ("b_blind_arms_out", {"residues": ["FRAZZLED"]}, {}),
			 ("b_melt_stomp_down", {"tint": 3, "face": "livid"}, {"specs": (None, "on")})]
	x = 220
	for pn, kw, props in shots:
		pose = rig.pose(pn)
		body.append(rig.compose(pose, ox=x, oy=floor, props=props, **kw))
		x += 300
	hush = os.path.join(fk.GAME, "data", "rigs", "hush")
	if os.path.exists(os.path.join(hush, "rig.json")):
		try:
			hr = fk.Rig(json.load(open(os.path.join(hush, "rig.json"))), json.load(open(os.path.join(hush, "poses.json"))),
						json.load(open(os.path.join(hush, "faces.json"))))
			nm = "h_stand" if "h_stand" in hr.pose_names() else hr.pose_names()[0]
			body.append(hr.compose(hr.pose(nm), ox=x - 40, oy=floor))
		except Exception:
			pass
	svg = fk.svg_doc(int(W * s), int(H * s), '<g transform="scale(%s)">%s</g>' % (s, "".join(body)))
	return save(svg, out, "phone_scene", 1.0, phone=False)


SHEETS = {"rest": sheet_rest, "poses": sheet_poses, "expressions": sheet_expressions, "residues": sheet_residues,
		  "temper": sheet_temper, "props": sheet_props, "scale": sheet_scale, "phone_scene": sheet_phone_scene}


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--out", required=True)
	ap.add_argument("--only", default="")
	ap.add_argument("--poses", default="", help="comma list: render only these poses (poses_pick.png)")
	ap.add_argument("--zoom", type=float, default=0.8)
	a = ap.parse_args()
	os.makedirs(a.out, exist_ok=True)
	rig = fk.load()
	only = [s for s in a.only.split(",") if s]
	if a.poses:
		print("wrote", sheet_poses(rig, a.out, 6, [p for p in a.poses.split(",") if p], a.zoom, "poses_pick"))
		return
	for name, fn in SHEETS.items():
		if only and name not in only:
			continue
		p = fn(rig, a.out)
		print("wrote", p)


if __name__ == "__main__":
	main()
