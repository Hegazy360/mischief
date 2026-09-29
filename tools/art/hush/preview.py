#!/usr/bin/env python3
"""preview — render the art-hush review sheets with our Python FK compositor (fk.py + rsvg-convert + Pillow).

    python3 tools/art/hush/preview.py --out <dir> [--only rest,poses,faces,pip,figgis,stalls,cast,warmth]

Writes (each also as a `_phone.png` copy 1200 px wide when larger):
  rest.png        Hush + Pip rest pose, exploded parts with pivot crosshairs
  poses.png       every pose labelled, with a solid black 50 px silhouette beside each
  faces.png       the head at 2x for every faces.json preset
  pip.png         Hush vs Pip on the same poses
  figgis.png      Figgis presets (bust at 2x and at the 128 px chip size)
  stalls.png      the Stalls strip at rest, laughing, leaning, pointing + the tumble sequence
  cast.png        the cast sheet to scale (Hush, Pip, Figgis chip, Clarence, the Stalls, Bellows or a placeholder)
  warmth.png      Hush as 50 px silhouettes + 96 px face crops (neutral / snicker / shock)
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fk  # noqa: E402

from PIL import Image, ImageDraw, ImageFont  # noqa: E402

BG = (217, 167, 160, 255)        # parlour dusty rose
BG2 = (242, 223, 166, 255)       # kitchen buttercream
INK = (27, 35, 64, 255)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONTB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(sz, bold=False):
	try:
		return ImageFont.truetype(FONTB if bold else FONT, sz)
	except OSError:
		return ImageFont.load_default()


def load_rig(rid):
	base = os.path.join(fk.GAME, "data", "rigs", rid)
	rig = json.load(open(os.path.join(base, "rig.json")))
	faces = json.load(open(os.path.join(base, "faces.json"))) if os.path.exists(os.path.join(base, "faces.json")) else {}
	poses = json.load(open(os.path.join(base, "poses.json"))) if os.path.exists(os.path.join(base, "poses.json")) else {}
	return rig, faces, poses


def raster(svg_text, zoom=1.0):
	fd, p = tempfile.mkstemp(suffix=".png")
	os.close(fd)
	fk.rasterise(svg_text, p, zoom)
	im = Image.open(p).convert("RGBA")
	im.load()
	os.remove(p)
	return im


def render(R, pose, face=None, W=460, H=470, ox=230, oy=440, zoom=1.0, bg=None, floor=True):
	return raster(R.compose(pose, face, W=W, H=H, ox=ox, oy=oy, bg=bg, floor=floor), zoom)


def silhouette(im, px_h=50, box_h=None):
	"""solid black silhouette of `im` (alpha > 40), scaled so the figure's frame height -> px_h."""
	a = im.split()[3].point(lambda v: 255 if v > 40 else 0)
	sil = Image.new("RGBA", im.size, (0, 0, 0, 0))
	sil.paste((0, 0, 0, 255), (0, 0), a)
	h = box_h or im.height
	k = px_h / float(h)
	return sil.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)


def phone_copy(path, width=1200):
	im = Image.open(path)
	if im.width > width:
		k = width / float(im.width)
		im.resize((width, int(im.height * k)), Image.LANCZOS).save(path[:-4] + "_phone.png")


def label(d, xy, text, sz=14, fill=INK, bold=False, anchor="la"):
	d.text(xy, text, fill=fill, font=font(sz, bold), anchor=anchor)


# ================================================================================================
def _tile(path, zoom, pivot=None, sockets=None):
	im = raster(open(fk.res_to_local(path)).read(), zoom)
	d = ImageDraw.Draw(im)
	if pivot:
		px, py = pivot[0] * zoom, pivot[1] * zoom
		d.line([(px - 8, py), (px + 8, py)], fill=(226, 59, 78, 255), width=2)
		d.line([(px, py - 8), (px, py + 8)], fill=(226, 59, 78, 255), width=2)
	for s in (sockets or {}).values():
		sx, sy = s[0] * zoom, s[1] * zoom
		d.ellipse([sx - 5, sy - 5, sx + 5, sy + 5], outline=(31, 163, 122, 255), width=2)
	return im


def sheet_rest(out):
	rig, faces, poses = load_rig("hush")
	res = fk.resolve_poses(poses, rig)
	W = 1800
	sheet = Image.new("RGBA", (W, 1960), BG)
	d = ImageDraw.Draw(sheet)
	label(d, (20, 12), "Hush — rest pose (1.2x), the Pip skin on the same rig, and every part texture", 22, bold=True)
	for j, skin in enumerate((None, "pip")):
		im = render(fk.Rig(rig, faces, skin), res["h_stand"], zoom=1.2)
		sheet.alpha_composite(im, (20 + j * 560, 44))
		label(d, (60 + j * 560, 44 + im.height - 22), "hush" if not skin else "pip (fallback skin)", 18, bold=True)
	info = ["340 px tall at zoom 1.0, head ~130 px incl. beret",
			"feet origin; pelvis = root (joint 136 px up)",
			"19 parts: 12 textured + 8 limb bones (hose limbs)",
			"red cross = pivot (joint), green ring = socket",
			"sockets: hand_r:grip, hand_l:grip, torso:braces,",
			"         head:hat, braces_loop:grab",
			"Pip: identical names, canvases, pivots, sockets"]
	for k, t in enumerate(info):
		label(d, (1150, 70 + k * 26), t, 16)
	parts = rig["parts"]
	y = 640
	label(d, (20, y), "body parts (1.5x)", 18, bold=True)
	x = 20
	y += 28
	for n in ("pelvis", "torso", "braces_front", "braces_loop", "head", "hair_back", "beret"):
		p = parts[n]
		t = _tile(p["file"], 1.5, p["pivot"], p.get("sockets"))
		t.thumbnail((230, 230))
		sheet.alpha_composite(t, (x, y))
		label(d, (x, y + 232), n, 13)
		x += 250
	y += 262
	for side in ("r", "l"):
		label(d, (20, y), "hand_%s — the 8 gloves (1.5x): %s" % (side, ", ".join(parts["hand_" + side]["tex"])), 18, bold=True)
		y += 28
		x = 20
		for tn, fp in parts["hand_" + side]["tex"].items():
			t = _tile(fp, 1.5, parts["hand_" + side]["pivot"], parts["hand_" + side].get("sockets") if tn == "fist" else None)
			sheet.alpha_composite(t, (x, y))
			label(d, (x, y + t.height + 2), tn, 13)
			x += 220
		y += 206
	label(d, (20, y), "feet (flat / tiptoe), Clarence (limp, squeezed, stretched, smitten), hidden look", 18, bold=True)
	y += 28
	x = 20
	for side in ("r", "l"):
		for tn, fp in parts["foot_" + side]["tex"].items():
			t = _tile(fp, 1.5, parts["foot_" + side]["pivot"])
			sheet.alpha_composite(t, (x, y))
			label(d, (x, y + t.height + 2), "foot_%s %s" % (side, tn), 13)
			x += 130
	cl = rig["props"]["clarence"]
	for st, fp in cl["tex"].items():
		t = _tile(fp, 1.2, cl["pivot"])
		sheet.alpha_composite(t, (x, y))
		label(d, (x, y + t.height + 2), st, 13)
		x += 125
	hid = rig["hidden"]
	for k in ("file", "blink"):
		t = _tile(hid[k], 1.2)
		sheet.alpha_composite(t, (x, y))
		label(d, (x, y + t.height + 2), hid[k].split("/")[-1], 13)
		x += 225
	t = _tile(rig["residues"]["TOMATO"]["overlays"]["head"], 1.0)
	sheet.alpha_composite(t, (x, y))
	label(d, (x, y + t.height + 2), "TOMATO overlay (head)", 13)
	bb = sheet.getbbox()
	sheet = sheet.crop((0, 0, W, min(1960, y + 240)))
	p = os.path.join(out, "rest.png")
	sheet.save(p)
	return p


def sheet_poses(out, skin=None, name="poses.png"):
	rig, faces, poses = load_rig("hush")
	res = fk.resolve_poses(poses, rig)
	R = fk.Rig(rig, faces, skin)
	names = list(poses["poses"].keys()) + list(poses.get("mirror_of", {}).keys())
	cw, ch = 250, 330
	cols = 7
	rows = (len(names) + cols - 1) // cols
	sheet = Image.new("RGBA", (cols * cw + 20, rows * ch + 60), BG)
	d = ImageDraw.Draw(sheet)
	label(d, (14, 12), "Hush poses (%d) — 0.5x with the 50 px silhouette test (black, right)" % len(names), 22, bold=True)
	for i, n in enumerate(names):
		im = render(R, res[n], W=520, H=600, ox=260, oy=560, zoom=1.0)
		sil_src = render(R, res[n], W=520, H=600, ox=260, oy=560, zoom=1.0, floor=False)
		cx = 10 + (i % cols) * cw
		cy = 50 + (i // cols) * ch
		t = im.resize((int(im.width * 0.44), int(im.height * 0.44)), Image.LANCZOS)
		sheet.alpha_composite(t, (cx, cy))
		# the silhouette is scaled so a 340 px tall Hush is 50 px
		s = silhouette(sil_src, int(600 * 50 / 340.0))
		sheet.alpha_composite(s, (cx + cw - s.width - 4, cy + 264 - s.height))
		tags = res[n].get("tags", [])
		label(d, (cx + 4, cy + 266), n, 14, bold=True)
		label(d, (cx + 4, cy + 284), ",".join(tags)[:34], 11)
		sil = res[n].get("silhouette", "")
		if sil:
			label(d, (cx + 4, cy + 299), sil[:40], 10)
			if len(sil) > 40:
				label(d, (cx + 4, cy + 312), sil[40:80], 10)
	p = os.path.join(out, name)
	sheet.save(p)
	return p


def head_crop(R, pose, face, zoom=2.0, size=None):
	"""render just around the head (world box above the neck)."""
	W = fk.Rig.solve(R, pose)
	hx, hy = fk.apply(W["head"], (3, -60))
	svg = R.compose(pose, face, W=156, H=156, ox=78 - hx, oy=78 - hy, floor=False)
	im = raster(svg, zoom)
	if size:
		im = im.resize((size, size), Image.LANCZOS)
	return im


def sheet_faces(out):
	rig, faces, poses = load_rig("hush")
	res = fk.resolve_poses(poses, rig)
	names = list(faces["presets"].keys())
	cols = 6
	cw, ch = 280, 310
	rows = (len(names) + cols - 1) // cols
	sheet = Image.new("RGBA", (cols * cw + 20, rows * ch + 60), BG)
	d = ImageDraw.Draw(sheet)
	label(d, (14, 12), "Hush expressions — head at 2x (every faces.json preset)", 22, bold=True)
	R = fk.Rig(rig, faces)
	base = dict(res["h_stand"])
	for i, n in enumerate(names):
		im = head_crop(R, base, n, 1.67)
		cx = 10 + (i % cols) * cw
		cy = 50 + (i // cols) * ch
		d.rectangle([cx, cy, cx + 262, cy + 262], fill=(233, 200, 190, 255))
		sheet.alpha_composite(im, (cx + 1, cy + 1))
		fdef = faces["presets"][n]
		label(d, (cx + 4, cy + 266), n, 16, bold=True)
		ov = [k for k in ("blush", "sweat", "tear") if fdef.get(k) == "on"]
		label(d, (cx + 4, cy + 286), "%s / %s / %s%s" % (fdef.get("eyes"), fdef.get("brows"), fdef.get("mouth"),
														 (" +" + "+".join(ov)) if ov else ""), 11)
	p = os.path.join(out, "faces.png")
	sheet.save(p)
	return p


def sheet_pip(out):
	rig, faces, poses = load_rig("hush")
	res = fk.resolve_poses(poses, rig)
	pick = ["h_stand", "h_tip_pass_l", "h_run_contact_l", "h_tinker_s_a", "h_snicker_a", "h_squeak", "h_busted",
			"h_freeze_1", "h_freeze_3", "h_freeze_6", "h_freeze_8", "h_dangled_a", "h_bow_b", "h_wink"]
	Rh = fk.Rig(rig, faces)
	Rp = fk.Rig(rig, faces, "pip")
	cw = 250
	sheet = Image.new("RGBA", (7 * cw + 20, 2 * 600 + 60), BG2)
	d = ImageDraw.Draw(sheet)
	label(d, (14, 12), "Hush vs Pip (skin 'pip') — same rig, same poses, same pivots", 22, bold=True)
	for i, n in enumerate(pick):
		for j, R in enumerate((Rh, Rp)):
			im = render(R, res[n], W=520, H=600, ox=260, oy=560)
			t = im.resize((int(im.width * 0.44), int(im.height * 0.44)), Image.LANCZOS)
			row, col = divmod(i, 7)
			cx = 10 + col * cw
			cy = 50 + row * 600 + j * 268
			sheet.alpha_composite(t, (cx, cy))
		row, col = divmod(i, 7)
		label(d, (10 + col * cw + 4, 50 + row * 600 + 536), n, 14, bold=True)
	p = os.path.join(out, "pip.png")
	sheet.save(p)
	return p


def sheet_warmth(out):
	rig, faces, poses = load_rig("hush")
	res = fk.resolve_poses(poses, rig)
	R = fk.Rig(rig, faces)
	sheet = Image.new("RGBA", (1200, 470), (255, 255, 255, 255))
	d = ImageDraw.Draw(sheet)
	label(d, (16, 12), "Warmth check (GDD 9.2): 50 px silhouettes + 96 px face crops", 22, bold=True)
	x = 20
	for n in ("h_stand", "h_tip_pass_l", "h_snicker_a", "h_busted", "h_freeze_3", "h_wink"):
		im = render(R, res[n], W=520, H=520, ox=260, oy=470, floor=False)
		s = silhouette(im, int(520 * 50 / 340.0))
		bb = s.getbbox()
		s = s.crop(bb) if bb else s
		sheet.alpha_composite(s, (x, 110 - s.height // 2 + 10))
		label(d, (x, 150), n[2:], 11)
		col = im.resize((int(im.width * 50 / 340.0), int(im.height * 50 / 340.0)), Image.LANCZOS)
		bb = col.getbbox()
		col = col.crop(bb) if bb else col
		sheet.alpha_composite(col, (x + 60, 110 - col.height // 2 + 10))
		x += 150
	x = 20
	for n in ("neutral", "snicker", "shock", "grin", "sad", "busted"):
		im = head_crop(R, res["h_stand"], n, 1.0)
		im = im.resize((96, 96), Image.LANCZOS)
		bgc = Image.new("RGBA", (96, 96), BG)
		bgc.alpha_composite(im)
		sheet.alpha_composite(bgc, (x, 210))
		big = head_crop(R, res["h_stand"], n, 1.0).resize((150, 150), Image.LANCZOS)
		bgb = Image.new("RGBA", (150, 150), BG)
		bgb.alpha_composite(big)
		sheet.alpha_composite(bgb, (x + 20, 316 - 6)) if False else None
		label(d, (x, 312), n, 13, bold=True)
		x += 190
	label(d, (20, 350), "Reads as a smiling person at 96 px: big round pupils (16 px), rosy cheeks, a red smile,", 14)
	label(d, (20, 372), "thin eye paint, a small painted tear — no black lips, no clown nose, no fixed grin.", 14)
	label(d, (20, 404), "Silhouette signature at 50 px: slouched beret + bob, lanky legs, oversized gloves.", 14)
	p = os.path.join(out, "warmth.png")
	sheet.save(p)
	return p


def sheet_figgis(out):
	rig, faces, poses = load_rig("figgis")
	res = fk.resolve_poses(poses, rig)
	R = fk.Rig(rig, faces)
	names = list(poses["poses"].keys())
	cw = 330
	sheet = Image.new("RGBA", (len(names) * cw + 20, 470), BG)
	d = ImageDraw.Draw(sheet)
	label(d, (14, 12), "Old Figgis — HUD bust presets at 2x (left) and at the real 128 px chip size (right)", 22, bold=True)
	for i, n in enumerate(names):
		svg = R.compose(res[n], W=136, H=136, ox=68, oy=132, floor=False)
		big = raster(svg, 2.0)
		small = raster(svg, 1.0)
		cx = 14 + i * cw
		chip = Image.new("RGBA", (big.width, big.height), (58, 48, 80, 255))
		chip.alpha_composite(big)
		sheet.alpha_composite(chip, (cx, 60))
		c2 = Image.new("RGBA", (small.width, small.height), (58, 48, 80, 255))
		c2.alpha_composite(small)
		sheet.alpha_composite(c2, (cx + 60, 60 + big.height + 14))
		label(d, (cx, 60 + big.height + 14 + small.height + 6), n, 16, bold=True)
		label(d, (cx + 70, 60 + big.height + 14 + small.height + 8), res[n].get("silhouette", "")[:36], 11)
	p = os.path.join(out, "figgis.png")
	sheet.save(p)
	return p


def stalls_strip(meta, frame, scale=1.0, alpha=0.6, width=None, seed=0, tumble=None):
	heads = {h["id"]: h for h in meta["heads"]}
	ims = []
	for k, hid in enumerate(meta["layout"]):
		h = heads[hid]
		fr = frame if isinstance(frame, str) else frame[k % len(frame)]
		if tumble is not None and k == tumble[0]:
			t = meta["tumble"][tumble[1]]
			im = raster(open(fk.res_to_local(t["file"])).read(), scale)
			ims.append((im, t["pivot"]))
			continue
		im = raster(open(fk.res_to_local(h["frames"][fr])).read(), scale)
		ims.append((im, h["pivot"]))
	W = width or (int(58 * scale) * len(ims) + int(120 * scale))
	gap = (W - int(100 * scale)) / float(max(1, len(ims) - 1)) if width else int(58 * scale)
	Hh = int(160 * scale)
	strip = Image.new("RGBA", (W, Hh), (0, 0, 0, 0))
	x = int(50 * scale)
	for k, (im, pv) in enumerate(ims):
		yoff = int((8 if k % 2 else 0) * scale)
		a = im.split()[3].point(lambda v: int(v * alpha))
		im.putalpha(a)
		strip.alpha_composite(im, (int(x - pv[0] * scale), int(Hh - pv[1] * scale + yoff)))
		x += gap
	return strip


def sheet_stalls(out):
	meta = json.load(open(os.path.join(fk.GAME, "data", "rigs", "stalls", "stalls.json")))
	rows = [("rest (alpha 0.6)", "rest", 0.6), ("laugh (T2-T3, alpha 1.0)", "laugh", 1.0),
			("lean (shush / nudge)", "lean", 1.0), ("point (BEHIND YOU!)", ["rest", "point", "rest", "rest", "point"], 1.0),
			("mixed T4 roar + tumble", ["laugh", "point", "laugh", "lean"], 1.0)]
	strip_w = 58 * 24 + 120
	sheet = Image.new("RGBA", (strip_w + 40, 60 + len(rows) * 200 + 260), (242, 206, 150, 255))
	d = ImageDraw.Draw(sheet)
	label(d, (14, 12), "The Stalls — 24 heads x rest / laugh / lean / point + the tumble (1x)", 22, bold=True)
	for i, (lab, fr, al) in enumerate(rows):
		y = 50 + i * 200
		d.rectangle([20, y + 20, 20 + strip_w, y + 180], fill=(179, 18, 46, 255))
		st = stalls_strip(meta, fr, 1.0, al, strip_w, tumble=(7, 1) if i == 4 else None)
		sheet.alpha_composite(st, (20, y + 180 - st.height))
		label(d, (26, y + 22), lab, 16, bold=True, fill=(255, 246, 234, 255))
	y = 50 + len(rows) * 200
	label(d, (20, y), "tumble (T4): 4 frames", 16, bold=True)
	for k, t in enumerate(meta["tumble"]):
		im = raster(open(fk.res_to_local(t["file"])).read(), 1.3)
		sheet.alpha_composite(im, (30 + k * 190, y + 24))
	x = 30 + 4 * 190 + 30
	for k, hid in enumerate(meta["layout"][:6]):
		h = {hh["id"]: hh for hh in meta["heads"]}[hid]
		for j, fr in enumerate(("rest", "laugh", "lean", "point")):
			im = raster(open(fk.res_to_local(h["frames"][fr])).read(), 0.8)
			sheet.alpha_composite(im, (x + j * 110, y + 24 + (k % 2) * 0))
		break
	p = os.path.join(out, "stalls.png")
	sheet.save(p)
	return p


def _bellows_or_placeholder(zoom):
	"""Bellows' rest pose via his rig if art-bellows has delivered, else a grey 380 px placeholder."""
	base = os.path.join(fk.GAME, "data", "rigs", "bellows")
	try:
		rig = json.load(open(os.path.join(base, "rig.json")))
		faces = json.load(open(os.path.join(base, "faces.json")))
		poses = json.load(open(os.path.join(base, "poses.json")))
		res = fk.resolve_poses(poses, rig)
		pn = "b_stand" if "b_stand" in res else list(res.keys())[0]
		pose = dict(res[pn])
		props = dict(pose.get("props", {}))
		for prn in rig.get("props", {}):
			if prn not in props and prn != "specs":
				props[prn] = {"vis": 0}
		pose["props"] = props
		im = render(fk.Rig(rig, faces), pose, W=520, H=520, ox=260, oy=470, zoom=zoom, floor=False)
		bb = im.getbbox()
		if bb and (bb[3] - bb[1]) > 200 * zoom:
			return im, "Bellows (art-bellows rig, %s)" % pn
	except Exception:
		pass
	im = Image.new("RGBA", (int(520 * zoom), int(520 * zoom)), (0, 0, 0, 0))
	dd = ImageDraw.Draw(im)
	z = zoom
	cx, fy = 260 * z, 470 * z
	dd.ellipse([cx - 100 * z, fy - 300 * z, cx + 100 * z, fy - 90 * z], fill=(150, 150, 160, 255))
	dd.ellipse([cx - 70 * z, fy - 380 * z, cx + 70 * z, fy - 250 * z], fill=(170, 170, 180, 255))
	dd.rectangle([cx - 50 * z, fy - 100 * z, cx - 20 * z, fy], fill=(150, 150, 160, 255))
	dd.rectangle([cx + 20 * z, fy - 100 * z, cx + 50 * z, fy], fill=(150, 150, 160, 255))
	return im, "Bellows placeholder (380 px grey)"


def sheet_cast(out):
	"""the owner's cast sheet: a 1200 x 540 phone screen (2400 x 1080 logical at 0.5x), everything to scale."""
	rig, faces, poses = load_rig("hush")
	res = fk.resolve_poses(poses, rig)
	Rh = fk.Rig(rig, faces)
	Rp = fk.Rig(rig, faces, "pip")
	k = 0.5
	sheet = Image.new("RGBA", (1200, 540), (242, 223, 166, 255))
	d = ImageDraw.Draw(sheet)
	# a stage: wall, floor, footlight glow, curtain edges
	d.rectangle([0, 0, 1200, 400], fill=(242, 223, 166, 255))
	d.rectangle([0, 400, 1200, 540], fill=(201, 139, 85, 255))
	d.rectangle([0, 396, 1200, 404], fill=(169, 108, 60, 255))
	d.rectangle([0, 0, 40, 540], fill=(179, 18, 46, 255))
	d.rectangle([1160, 0, 1200, 540], fill=(179, 18, 46, 255))
	d.rectangle([0, 0, 1200, 26], fill=(179, 18, 46, 255))
	d.rectangle([0, 24, 1200, 30], fill=(232, 179, 58, 255))
	floor = 400
	def place(im, x, lab):
		sheet.alpha_composite(im, (int(x - 260 * k), int(floor - 470 * k)))
		label(d, (int(x), floor + 8), lab, 14, bold=True, anchor="ma")
	place(render(Rh, res["h_stand"], W=520, H=520, ox=260, oy=470, zoom=k, floor=True), 300, "HUSH")
	place(render(Rh, res["h_snicker_a"], W=520, H=520, ox=260, oy=470, zoom=k, floor=True), 440, "")
	place(render(Rh, res["h_freeze_5"], W=520, H=520, ox=260, oy=470, zoom=k, floor=True), 580, "(a freeze)")
	b, blab = _bellows_or_placeholder(k)
	sheet.alpha_composite(b, (int(780 - 260 * k), int(floor - 470 * k)))
	label(d, (780, floor + 8), "BELLOWS" if "rig" in blab else "BELLOWS (placeholder)", 14, bold=True, anchor="ma")
	place(render(Rp, res["h_stand"], W=520, H=520, ox=260, oy=470, zoom=k, floor=True), 980, "PIP (fallback)")
	# Clarence close-up (1x, inset) and Figgis chip at the HUD size (128 -> 64 at 0.5x)
	fr, ff, fp = load_rig("figgis")
	fres = fk.resolve_poses(fp, fr)
	fsvg = fk.Rig(fr, ff).compose(fres["f_point"], W=136, H=136, ox=68, oy=132, floor=False)
	chip = raster(fsvg, k)
	d.rounded_rectangle([60, 40, 60 + 68, 40 + 68], radius=10, fill=(58, 48, 80, 255), outline=(27, 35, 64, 255), width=3)
	sheet.alpha_composite(chip, (62, 40))
	label(d, (136, 50), "FIGGIS (HUD chip, 128 px)", 13, bold=True)
	cl = raster(open(fk.res_to_local(rig["props"]["clarence"]["tex"]["smitten"])).read(), k)
	sheet.alpha_composite(cl, (1080, floor - cl.height + 6))
	label(d, (1105, floor + 8), "CLARENCE", 13, bold=True, anchor="ma")
	# the Stalls along the bottom band (heads mid-laugh)
	meta = json.load(open(os.path.join(fk.GAME, "data", "rigs", "stalls", "stalls.json")))
	st = stalls_strip(meta, ["rest", "laugh", "rest", "lean", "laugh"], k, 0.85, 1200)
	sheet.alpha_composite(st, (0, 540 - st.height + 6))
	label(d, (1150, 440), "THE STALLS (bottom band, 40 px at rest)", 13, bold=True, anchor="ra")
	label(d, (600, 36), "Mischief Next Door — the cast at true phone scale (1200 x 540 = a 20:9 phone, zoom 1.0)", 15,
		  bold=True, anchor="ma", fill=(27, 35, 64, 255))
	p = os.path.join(out, "cast.png")
	sheet.save(p)
	return p


SHEETS = {"rest": sheet_rest, "poses": sheet_poses, "faces": sheet_faces, "pip": sheet_pip, "warmth": sheet_warmth,
		  "figgis": sheet_figgis, "stalls": sheet_stalls, "cast": sheet_cast}


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--out", required=True)
	ap.add_argument("--only", default="")
	a = ap.parse_args()
	os.makedirs(a.out, exist_ok=True)
	only = [s for s in a.only.split(",") if s] or list(SHEETS.keys())
	for k in only:
		p = SHEETS[k](a.out)
		phone_copy(p)
		print(p)


if __name__ == "__main__":
	main()
