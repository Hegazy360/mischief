#!/usr/bin/env python3
"""cast_sheet — composite the Gate-0 cast sheet (docs/review/s2-anim-hush/cast_sheet.png, 1200 x 540 = a 20:9 phone)
from IN-ENGINE shots (RigPlayer in the real kitchen via AnimViewer, the Stalls via ViewSandbox's StallsView) plus the
50 px silhouettes of the warmth rule (GDD 9.2) from the Python compositor (same art, alpha needed).

    python3 tools/art/hush/cast_sheet.py --shots DIR --out docs/review/s2-anim-hush/cast_sheet.png

DIR holds (shot with tools/scripts/shot.sh res://scenes/dev/AnimViewer.tscn <png> 20 <sandbox> -- ...; the exact
command lines are in docs/review/s2-anim-hush/index.md):
  idle.png snicker.png statue.png   --rig=hush --pose=<h_stand|h_snicker_a|h_freeze_3> --room=kitchen --x=3000 --clean
                                    --rig2=hush --skin2=pip --pose2=<same> --x2=300 --facing2=1
  bellows.png                       --rig=bellows --pose=b_stand ... --rig2=bellows --pose2=b_sneeze_choo --x2=340
  figgis.png figgis_card.png        --rig=figgis --pose=<f_psst|f_point> --clean --zoom=2   (the chip at 128 px)
  face_h_stand.png face_h_glance_stalls.png   the idle pair at --zoom=2 --x2=160 (96 px face crops)
  vs_rest.png seq/frame_003.png     res://view/sandbox/ViewSandbox.tscn --scenario=walk / gag_punch (--shot-seq)
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fk  # noqa: E402
import preview  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

W, H = 1200, 540
BG = (34, 26, 48)
GOLD = (232, 179, 58)
CREAM = (244, 239, 227)
DIM = (185, 178, 207)


def crop(path, box, size=None):
	im = Image.open(path).convert("RGB").crop(box)
	return im.resize(size, Image.LANCZOS) if size else im


def framed(sheet, im, xy, label, sub=None):
	x, y = xy
	sheet.paste(im, (x, y))
	d = ImageDraw.Draw(sheet)
	d.rectangle([x - 1, y - 1, x + im.width, y + im.height], outline=GOLD, width=2)
	d.rectangle([x, y, x + im.width - 1, y + 22], fill=(34, 26, 48))
	preview.label(d, (x + 6, y + 3), label, 14, fill=CREAM, bold=True)
	if sub:
		preview.label(d, (x + im.width - 6, y + 5), sub, 11, fill=DIM, anchor="ra")


def silhouettes(skin, poses, px=50):
	rig, faces, prs = preview.load_rig("hush")
	R = fk.Rig(rig, faces, skin)
	named = fk.resolve_poses(prs, rig)
	out = []
	for pn in poses:
		im = preview.render(R, named[pn], None, W=460, H=470, ox=230, oy=440, floor=False)
		out.append(preview.silhouette(im, px_h=px * 470 // 360))
	return out


def warmth(shots, out):
	"""GDD 9.2 warmth rule check: 96 px face crops (engine) and 50 px silhouettes (Hush row, Pip row)."""
	poses = ("h_stand", "h_snicker_a", "h_freeze_3", "h_freeze_1", "h_dive_antic", "h_pop_out", "h_squeak")
	img = Image.new("RGB", (760, 300), BG)
	d = ImageDraw.Draw(img)
	preview.label(d, (10, 8), "WARMTH RULE — 96 px face crops (in engine) · 50 px silhouettes", 15, fill=GOLD, bold=True)
	x = 10
	for fn, box in (("face_h_stand.png", (532, 96, 668, 232)), ("face_h_stand.png", (692, 88, 828, 224)),
					("face_h_glance_stalls.png", (532, 96, 668, 232)), ("face_h_glance_stalls.png", (692, 88, 828, 224))):
		img.paste(crop(os.path.join(shots, fn), box, (96, 96)), (x, 34))
		x += 104
	preview.label(d, (430, 40), "Hush · Pip, neutral", 12, fill=CREAM)
	preview.label(d, (430, 58), "Hush · Pip, the glance (grin)", 12, fill=CREAM)
	preview.label(d, (430, 84), "big pupils, blush, smiling default,", 12, fill=DIM)
	preview.label(d, (430, 100), "thin eye paint, no black lips", 12, fill=DIM)
	for row, skin in enumerate((None, "pip")):
		y = 140 + row * 70
		preview.label(d, (10, y + 20), "Hush" if skin is None else "Pip", 13, fill=CREAM, bold=True)
		sx = 60
		for sil in silhouettes(skin, poses):
			cell = Image.new("RGBA", (sil.width + 10, 62), (232, 223, 200, 255))
			cell.alpha_composite(sil, (5, 6))
			img.paste(cell.convert("RGB"), (sx, y))
			sx += sil.width + 16
	preview.label(d, (10, 292 - 14), "silhouettes: stand, snicker, flamingo, thinker, dive antic, pop, squeak", 11, fill=DIM)
	img.save(out)
	print(out)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--shots", required=True)
	ap.add_argument("--out", required=True)
	ap.add_argument("--warmth", default="")
	a = ap.parse_args()
	if a.warmth:
		warmth(a.shots, a.warmth)
	S = lambda n: os.path.join(a.shots, n)  # noqa: E731
	sheet = Image.new("RGB", (W, H), BG)
	d = ImageDraw.Draw(sheet)
	preview.label(d, (12, 8), "CAST SHEET — Gate 0: the mime (Hush) or Pip?", 18, fill=GOLD, bold=True)
	preview.label(d, (W - 12, 12), "in engine, the real kitchen, phone scale (1200×540)", 12, fill=DIM, anchor="ra")
	# row 1: Hush | Pip pairs + Bellows (kitchen crops at 1:1 = in-game size)
	y0 = 38
	cw, chh = 276, 292
	pairs = [("idle.png", "IDLE", "Hush · Pip"), ("snicker.png", "SNICKER", "Hush · Pip"),
			 ("statue.png", "STATUE: the flamingo", "Hush · Pip")]
	x = 8
	for fn, lab, sub in pairs:
		framed(sheet, crop(S(fn), (537, 162, 537 + cw, 162 + chh)), (x, y0), lab, sub)
		x += cw + 8
	bw = W - x - 8
	framed(sheet, crop(S("bellows.png"), (480, 162, 480 + bw, 162 + chh)), (x, y0), "BELLOWS", "idle · CHOO!")
	# row 2
	y1 = y0 + chh + 10
	hh = H - y1 - 8
	# Figgis chip: 128 px (true HUD size on a 1080-tall phone) + the card pose
	fg = crop(S("figgis.png"), (526, 310, 674, 458), (128, 128))
	fc = crop(S("figgis_card.png"), (526, 310, 674, 458), (128, 128))
	box = Image.new("RGB", (272, hh), (46, 36, 64))
	box.paste(fg, (6, 24))
	box.paste(fc, (138, 24))
	framed(sheet, box, (8, y1), "FIGGIS chip", "128 px: psst · point")
	# the Stalls band (StallsView): rest / laughing
	rest = crop(S("vs_rest.png"), (300, 474, 1100, 540), (520, 43))
	t3 = crop(os.path.join(a.shots, "seq", "frame_003.png"), (300, 474, 1100, 540), (520, 43))
	st = Image.new("RGB", (532, hh), (46, 36, 64))
	dd = ImageDraw.Draw(st)
	preview.label(dd, (8, 26), "at rest (40 px heads, 0.6 alpha)", 11, fill=DIM)
	st.paste(rest, (6, 42))
	preview.label(dd, (8, 92), "laughing: the sneeze's big laugh (heads rise)", 11, fill=DIM)
	st.paste(t3, (6, 108))
	framed(sheet, st, (288, y1), "THE STALLS", "rest · laugh")
	# warmth: 96 px face crops + 50 px silhouettes, Hush vs Pip
	wx = 288 + 532 + 8
	ww = W - wx - 8
	wb = Image.new("RGB", (ww, hh), (46, 36, 64))
	faces = [crop(S("face_h_stand.png"), (532, 96, 668, 232), (82, 82)),
			 crop(S("face_h_stand.png"), (692, 88, 828, 224), (82, 82)),
			 crop(S("face_h_glance_stalls.png"), (532, 96, 668, 232), (82, 82)),
			 crop(S("face_h_glance_stalls.png"), (692, 88, 828, 224), (82, 82))]
	for i, im in enumerate(faces):
		wb.paste(im, (6 + i * 88, 26))
	sx = 6
	for skin in (None, "pip"):
		for sil in silhouettes(skin, ("h_stand", "h_snicker_a", "h_freeze_3")):
			bgc = Image.new("RGBA", sil.size, (232, 223, 200, 255))
			bgc.alpha_composite(sil)
			wb.paste(bgc.convert("RGB"), (sx, 26 + 88))
			sx += sil.width + 2
		sx += 10
	framed(sheet, wb, (wx, y1), "WARMTH", "faces 82 px · silhouettes 50 px (H | P)")
	os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
	sheet.save(a.out)
	print(a.out)


if __name__ == "__main__":
	main()
