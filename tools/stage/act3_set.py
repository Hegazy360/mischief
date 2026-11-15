"""act3_set — model Gus Thudd's back garden on judging day from scratch in Blender (Act III).

    python3 tools/stage/build.py --act act3 [--engine eevee]

Same camera, scale and stage as Acts I and II (1 Hush model unit = 128 logical px, 10 degree tilt,
the walk line at y = 1.3 lands on 880 px); the proscenium, Stalls and icons come from act1_set and
the render loop from stagekit; the sky, hills, trees, bushes, hedge, topiary, fence, flower bed,
stepping stones and grass come from the shared outdoor kit scenery.py.

Stage left to right (x in units, px = 1200 + 128 x):
  -7.4  garden gate (seq)   Hush's way in, through the back fence
  -5.4  three garden gnomes  FREEZE: Hush makes a fourth at -4.2 ("I don't remember a tall one")
  -1.0  the mower (prop)     RIG 1: throttle jammed; it bolts and drags Gus into the hedge
   0.4  water butt (fg)      Hush hides behind it
   2.6  the shed (seqs)      RIG 2: corner posts sawn; the front wall falls flat around him, the roof
                             comes down on his head
   7.6  the hedge            prize topiary (a three-tier clipped stack); the mower ends up in it

Layers: bg, fg_butt, prop_mower, prop_track1..3, seq_gate, seq_shedbox (sides, back, inside; drawn
behind the cast), seq_shedfront (front wall, door, roof; behind the cast at rest, in front once it
falls), seq_curtain, fxs_dust, frame, audience, icon_*.
"""
from __future__ import annotations

import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bmesh  # type: ignore  # noqa: E402
import bpy  # type: ignore  # noqa: E402
from mathutils import Euler, Vector  # type: ignore  # noqa: E402

import act1_set as K  # noqa: E402
import act2_set as K2  # noqa: E402  (text(), the house curtains, the palette additions)
import scenery as SC  # noqa: E402  (shared outdoor pieces: trees, clouds, sky, hedges, fence, flowers)
import stagekit  # noqa: E402

box, cyl, sph, prism, mat, coll = K.box, K.cyl, K.sph, K.prism, K.mat, K.coll
group, child, clamp01, text = K.group, K.child, K.clamp01, K2.text
WALL_Y, STAGE_Y = K.WALL_Y, K.STAGE_Y

K.C.update({
	"sky_hi": "#7CC8F0", "lawn_a": "#6CC24F", "lawn_b": "#5AAE40", "fence": "#F3E9D6", "fence_dk": "#D9CBB0",
	"shed": "#B8794A", "shed_dk": "#8E5732", "shed_lt": "#D29A66", "roof": "#46536A", "roof_dk": "#333D4E", "roof_lt": "#5A6882",
	"gnome_hat": "#D8323F", "gnome_hat2": "#2F6FB3", "gnome_coat": "#3A7CC4", "gnome_coat2": "#E2A12E",
	"beard": "#F7F4EE", "butt": "#3E6B4A", "butt_dk": "#2C503A", "mud": "#7A5B33", "mud_dk": "#5C4224",
	"turf": "#4E8F36", "mower": "#2F5E9E", "mower_bag": "#A8DCC8", "bark": "#7A5236", "petal1": "#F27BB0",
	"petal2": "#FFD84A", "petal3": "#FFFFFF", "stone": "#BDB6AA", "stone_dk": "#958D80", "singlet": "#3FA34D",
	"shorts": "#F28C28",
})

X_GATE, X_GNOMES, X_HUSH_GNOME, X_MOWER, X_BUTT, X_SHED, X_HEDGE = -7.4, (-6.0, -5.4, -4.8), -4.2, -1.0, 0.4, 2.6, 7.6
FENCE_Y = 4.6
SHED_W, SHED_D, SHED_H = 3.0, 1.8, 3.6
SHED_Y0 = 2.0                          # the front wall's foot: it falls toward the Stalls about this edge
DOOR_W, DOOR_H = 1.9, 2.9              # wide and tall enough that Gus stands in the hole when it lands
HEAD_Z = 3.0                           # Gus's head top, in units: where the roof comes to rest


def build_room() -> dict:
	marks: dict = {}
	# sky: a gradient backdrop, the sun, clouds and two rows of hazy hills (scenery.py). With this camera
	# the sky band seen over the fence is z ~0.6..4 at y 13, so that is where the clouds sit.
	SC.sky("sky", y=14.0)
	SC.sun("sun", -4.6, 13.6, 3.4, 0.5)
	for i, (cx, cz, w) in enumerate(((-7.6, 2.7, 2.8), (-1.2, 3.3, 3.4), (4.4, 2.9, 2.4), (9.2, 3.5, 2.6))):
		SC.cloud(f"cloud{i}", cx, 13.2, cz, w, seed=10 + i)
	SC.hills("hills_far", y=12.6, colour="sc_hill3", haze=0.4, seed=21, h=2.2)
	SC.hills("hills", y=11.6, colour="sc_hill2", haze=0.2, seed=22, h=1.6)
	box("far_lawn", (40.0, 10.0, 0.2), (0, 9.0, -0.1), mat("lawn2", 0.9), bevel=0)
	# the neighbours' trees beyond the fence (a touch of haze sets them back), bushes peeking over it
	for i, (tx, s, kind, fruit) in enumerate(((-6.4, 1.0, "oak", None), (-2.8, 0.95, "poplar", None), (0.4, 0.85, "birch", None),
											   (4.0, 0.95, "oak", "sc_apple"), (8.4, 0.9, "pine", None))):
		SC.tree(f"tree{i}", tx, 8.2, s, kind, seed=30 + i, haze=0.15, fruit=fruit)
	for i, (bx, w) in enumerate(((-8.6, 2.2), (-4.5, 2.4), (-0.9, 2.0), (6.0, 2.4))):
		SC.bush(f"fbush{i}", bx, 5.6, w, 2.5, seed=40 + i, haze=0.08)
	# the lawn: mowing stripes running across the stage, mottled, with a fine grass bump
	box("lawn", (19.6, 7.2, 0.2), (0, 1.0, -0.1), SC.mat_lawn("lawn_a", "lawn_b", 0.9, 1, "stripes"), bevel=0)
	SC.grass_tufts("tufts_front", -9.4, 9.4, -0.95, n=46, seed=50, depth=0.12)
	SC.grass_tufts("tufts_fence", -9.4, 9.4, FENCE_Y - 0.9, n=34, seed=51, depth=0.1)
	# stage apron + footlights (the same theatre)
	box("apron", (19.6, 0.4, 3.0), (0, -1.7, -1.5), mat("stage", 0.6), bevel=0)
	box("apron_lip", (19.6, 0.5, 0.12), (0, -1.55, -0.06), mat("gold", 0.35, 0, 0.6), bevel=0.04)
	for i in range(11):
		x = -7.5 + i * 1.5
		sph(f"foot{i}", 0.13, (x, -1.82, -0.18), mat("bulb", 0.3, 4.0), scale=(1.3, 1, 0.8))
		box(f"foothood{i}", (0.42, 0.18, 0.12), (x, -1.9, -0.06), mat("gold_dk", 0.4, 0, 0.6), bevel=0.03)

	# --- the back fence: pickets, two rails, posts; a gap for the gate ---
	gw = 1.5
	SC.picket_fence("fence", -9.6, 9.6, FENCE_Y, gaps=((X_GATE, gw),), colour="fence", shade="fence_dk")
	for side in (-1, 1):
		box(f"gatepost{side}", (0.2, 0.2, 2.3), (X_GATE + side * (gw / 2 + 0.1), FENCE_Y - 0.05, 1.15), mat("fence_dk", 0.7), bevel=0.03)
		sph(f"gatecap{side}", 0.14, (X_GATE + side * (gw / 2 + 0.1), FENCE_Y - 0.05, 2.38), mat("fence", 0.7))
	SC.stepping_stones("gate_path", [(X_GATE + 0.12 * ((k % 2) * 2 - 1), 4.1 - k * 0.62) for k in range(5)], seed=60)
	marks["gate"] = (X_GATE + 0.3, STAGE_Y, 0)

	# flower bed along the fence (tulips, in regulation rows)
	SC.flower_bed("bed", -9.5, 9.6, FENCE_Y - 0.45, seed=70, skip=((X_GATE, 2.0), (X_SHED, SHED_W + 0.4)),
				  colours=("petal1", "petal2", "petal3", "gnome_hat"))

	# bird bath (left, behind the gnomes)
	bbx = -5.4
	cyl("bb_foot", 0.32, 0.12, (bbx, 2.9, 0), mat("stone_dk", 0.8), seg=20)
	cyl("bb_stem", 0.12, 1.0, (bbx, 2.9, 0.12), mat("stone", 0.8), r2=0.09, seg=16)
	cyl("bb_bowl", 0.18, 0.22, (bbx, 2.9, 1.1), mat("stone", 0.8), r2=0.62, seg=28)
	cyl("bb_water", 0.55, 0.02, (bbx, 2.9, 1.3), mat("sky2", 0.1, 0.3), seg=28)

	# --- the gnomes: three, all exactly the same height (he measured) ---
	for i, gx in enumerate(X_GNOMES):
		gy = 1.85
		hat = ("gnome_hat", "gnome_hat2", "gnome_hat")[i]
		coat = ("gnome_coat", "gnome_coat2", "lawn")[i]
		cyl(f"g{i}_base", 0.32, 0.1, (gx, gy, 0), mat("stone_dk", 0.8), seg=18)
		cyl(f"g{i}_body", 0.3, 0.6, (gx, gy, 0.1), mat(coat, 0.6), r2=0.24, seg=18)
		sph(f"g{i}_belly", 0.26, (gx, gy - 0.05, 0.42), mat(coat, 0.6), scale=(1, 0.9, 1))
		box(f"g{i}_belt", (0.56, 0.5, 0.07), (gx, gy, 0.45), mat("black", 0.5), bevel=0.02)
		sph(f"g{i}_face", 0.17, (gx, gy - 0.05, 0.86), mat("skin", 0.7))
		sph(f"g{i}_nose", 0.06, (gx, gy - 0.22, 0.85), mat("#E58A6A", 0.6))
		prism(f"g{i}_beard", [(-0.17, 0.12), (0.17, 0.12), (0.0, -0.32)], 0.1, (gx, gy - 0.12, 0.72), mat("beard", 0.8), bevel=0.03)
		cyl(f"g{i}_hat", 0.2, 0.62, (gx, gy, 0.98), mat(hat, 0.6), r2=0.01, seg=18, rot=(0, (-8, 6, -4)[i], 0))
		for side in (-1, 1):
			sph(f"g{i}_arm{side}", 0.08, (gx + side * 0.27, gy - 0.04, 0.48), mat(coat, 0.6), scale=(1, 1, 1.6))
	box("gnome_sign", (0.9, 0.05, 0.3), (X_GNOMES[1], 2.6, 1.55), mat("fence", 0.8), bevel=0.02)
	cyl("gnome_sign_post", 0.03, 1.4, (X_GNOMES[1], 2.62, 0), mat("bark", 0.8), seg=6)
	text("gnome_sign_t", "GNOMES ×3", 0.11, (X_GNOMES[1], 2.56, 1.55), "bg", "ink")
	marks["gnomes"] = (X_HUSH_GNOME, STAGE_Y, 0)

	# --- a sprinkler + the washing line (his singlets, drying) ---
	cyl("spr_base", 0.2, 0.08, (4.7, 2.3, 0), mat("tin_lbl3", 0.4), seg=16)
	cyl("spr_stem", 0.04, 0.35, (4.7, 2.3, 0.08), mat("chrome", 0.3, 0, 0.8), seg=8)
	box("spr_arm", (0.6, 0.05, 0.05), (4.7, 2.3, 0.43), mat("chrome", 0.3, 0, 0.8), bevel=0, rot=(0, 0, 30))
	for side in (-1, 1):
		cyl(f"line_pole{side}", 0.05, 3.4, (5.4 + side * 1.0, 3.6, 0), mat("chrome", 0.4, 0, 0.6), seg=8)
	cyl("line", 0.012, 2.0, (4.4, 3.6, 3.25), mat("white", 0.6), rot=(0, 90, 0), seg=6)
	for i, (lx, col) in enumerate(((4.85, "singlet"), (5.4, "shorts"), (5.95, "singlet"))):
		prism(f"wash{i}", [(-0.25, 0), (0.25, 0), (0.22, -0.7), (-0.22, -0.7)], 0.04, (lx, 3.58, 3.25), mat(col, 0.8))
		for side in (-1, 1):
			box(f"peg{i}{side}", (0.04, 0.06, 0.1), (lx + side * 0.18, 3.54, 3.25), mat("wood_lt", 0.7), bevel=0)

	# --- the hedge: prize topiary (a big round one and a cockerel) ---
	hx = X_HEDGE
	SC.hedge("prize", hx - 1.25, hx + 1.25, 2.5, h=2.2, depth=1.3, seed=80)
	SC.topiary_tiers("topi", hx + 0.15, 2.6, 2.05, 0.6, tiers=3, seed=81)
	marks["hedge"] = (hx, STAGE_Y, 0)
	marks["shed"] = (X_SHED, STAGE_Y, 0)
	return marks


def build_props() -> dict:
	piv: dict = {}
	# --- the water butt (in front of the walking line): Hush's hiding place ---
	bx, by = X_BUTT, 0.55
	cyl("butt", 0.62, 2.65, (bx, by, 0), mat("butt", 0.5), "fg_butt", r2=0.66, seg=32)
	for z in (0.5, 1.9):
		cyl(f"butt_hoop{z}", 0.66, 0.08, (bx, by, z), mat("butt_dk", 0.5), "fg_butt", r2=0.67, seg=32)
	cyl("butt_lid", 0.72, 0.1, (bx, by, 2.65), mat("butt_dk", 0.5), "fg_butt", seg=32)
	cyl("butt_tap", 0.05, 0.22, (bx + 0.1, by - 0.62, 0.35), mat("brass", 0.3, 0, 0.8), "fg_butt", rot=(90, 0, 0), seg=8)
	box("watering_can", (0.5, 0.3, 0.38), (bx - 0.85, by - 0.2, 0.19), mat("tin_lbl2", 0.4, 0, 0.3), "fg_butt", bevel=0.08)
	cyl("can_spout", 0.04, 0.55, (bx - 0.6, by - 0.2, 0.3), mat("tin_lbl2", 0.4, 0, 0.3), "fg_butt", rot=(0, 55, 0), seg=8)
	piv["butt"] = (bx, STAGE_Y, 0)

	# --- the mower, nose to stage right, on the walk line (pivot: on the ground under its middle) ---
	mx = X_MOWER
	m = "prop_mower"
	box("mw_deck", (1.0, 0.75, 0.22), (mx, STAGE_Y, 0.3), mat("mower", 0.4), m, bevel=0.07)
	box("mw_hood", (0.7, 0.6, 0.25), (mx + 0.05, STAGE_Y, 0.52), mat("mower", 0.35), m, bevel=0.1)
	cyl("mw_engine", 0.18, 0.2, (mx + 0.05, STAGE_Y, 0.62), mat("black", 0.5), m, seg=16)
	cyl("mw_cap", 0.1, 0.08, (mx + 0.05, STAGE_Y, 0.82), mat("tin_lbl1", 0.4), m, seg=12)
	for wx in (-0.36, 0.36):
		cyl(f"mw_wheel{wx}", 0.17, 0.1, (mx + wx, STAGE_Y - 0.4, 0.17), mat("black", 0.6), m, rot=(90, 0, 0), seg=18)
		cyl(f"mw_hub{wx}", 0.07, 0.11, (mx + wx, STAGE_Y - 0.41, 0.17), mat("chrome", 0.3, 0, 0.8), m, rot=(90, 0, 0), seg=12)
	box("mw_bag", (0.55, 0.55, 0.45), (mx - 0.75, STAGE_Y, 0.42), mat("mower_bag", 0.8), m, bevel=0.12)
	for side in (-1, 1):
		K.cyl(f"mw_bar{side}", 0.03, 1.45, (mx - 0.4, STAGE_Y + side * 0.25, 0.45), mat("chrome", 0.3, 0, 0.8), m, rot=(0, -55, 0), seg=8)
	cyl("mw_grip", 0.05, 0.6, (mx - 1.6, STAGE_Y, 1.28), mat("black", 0.5), m, rot=(90, 0, 0), seg=10)
	piv["mower"] = (mx, STAGE_Y, 0)

	# --- the churned track the runaway leaves in his stripes (three lengths, shown as it passes) ---
	rnd = random.Random(9)
	segs = ((X_MOWER + 0.3, 1.9), (1.9, 4.8), (4.8, 7.0))
	for s_i, (x0, x1) in enumerate(segs):
		name = f"prop_track{s_i + 1}"
		n = int((x1 - x0) / 0.22)
		for k in range(n):
			x = x0 + (x1 - x0) * k / n
			y = STAGE_Y - 0.1 + 0.28 * math.sin(x * 2.3)
			box(f"{name}_{k}", (0.32, 0.5, 0.02), (x, y, 0.005), mat("mud" if k % 3 else "mud_dk", 0.95), name,
				bevel=0.01, rot=(0, 0, math.degrees(math.cos(x * 2.3) * 0.6)))
			if k % 2 == 0:
				sph(f"{name}_clod{k}", 0.08, (x + rnd.uniform(-0.2, 0.2), y + rnd.uniform(-0.45, 0.45), 0.04),
					mat("turf", 0.9), name, scale=(1.3, 1, 0.6))
		piv[f"track{s_i + 1}"] = (x0, STAGE_Y, 0)

	# Hush's beret stamp (the armed-prank mark)
	sph("stamp_b", 0.28, (0, 0, 0), mat("velvet", 0.6), "icon_stamp", scale=(1.2, 1.0, 0.35), rot=(0, -12, 0))
	sph("stamp_s", 0.05, (0.02, 0, 0.1), mat("velvet", 0.6), "icon_stamp")
	return piv


def _planks(where: str, name: str, size, loc, colour: str = "shed"):
	"""A plank panel: vertical boards in two tones (object-space bands along x)."""
	other = "shed_dk" if colour == "shed" else ("shed" if colour == "shed_lt" else "shed_lt")
	return box(name, size, loc, SC.mat_boards(colour, other, 3.2, 0), where, bevel=0.02)


def build_seqs(piv: dict) -> dict:
	seqs: dict = {}
	bpy.context.view_layer.update()

	# --- the garden gate swings open on its stage-left post ---
	gw, gh = 1.5, 1.9
	hinge = group("gate_hinge", "seq_gate", (X_GATE - gw / 2, FENCE_Y - 0.1, 0))
	bpy.context.view_layer.update()
	parts = []
	for i in range(5):
		x = X_GATE - gw / 2 + 0.15 + i * 0.3
		parts.append(prism(f"gpick{i}", [(-0.11, 0), (0.11, 0), (0.11, gh), (0, gh + 0.15), (-0.11, gh)], 0.06,
						   (x, FENCE_Y - 0.1, 0.05), mat("fence", 0.8), "seq_gate"))
	for z in (0.45, 1.45):
		parts.append(box(f"grail{z}", (gw, 0.06, 0.12), (X_GATE, FENCE_Y - 0.16, z), mat("fence_dk", 0.8), "seq_gate", bevel=0.02))
	parts.append(box("gdiag", (0.1, 0.05, 1.3), (X_GATE, FENCE_Y - 0.18, 0.95), mat("fence_dk", 0.8), "seq_gate", bevel=0.02, rot=(0, 50, 0)))
	bpy.context.view_layer.update()
	for o in parts:
		child(o, hinge)
	angles = [0, -16, -34, -52, -70, -86]
	seqs["gate"] = (len(angles), lambda k: setattr(hinge, "rotation_euler", Euler((0, 0, math.radians(angles[k])))))

	# --- the shed: two sequences on one timeline (13 frames) ---
	#   0       intact
	#   1       the door swings open
	#   2..6    the front wall falls toward the Stalls, flat around him (the door hole lands on him)
	#   7..9    the side walls and back fall away
	#   10..12  the roof comes straight down onto his head and settles
	sx, x0, x1 = X_SHED, X_SHED - SHED_W / 2, X_SHED + SHED_W / 2
	y0, y1 = SHED_Y0, SHED_Y0 + SHED_D
	F, B = "seq_shedfront", "seq_shedbox"
	# box: back wall (with his tools and a trophy shelf), side walls, a floor
	back = group("shed_back", B, (sx, y1, 0))
	left = group("shed_left", B, (x0, (y0 + y1) / 2, 0))
	right = group("shed_right", B, (x1, (y0 + y1) / 2, 0))
	bpy.context.view_layer.update()
	bp = [_planks(B, "shed_backwall", (SHED_W, 0.1, SHED_H), (sx, y1, SHED_H / 2), "shed_dk"),
		  box("tool_rack", (2.0, 0.08, 0.08), (sx, y1 - 0.08, 2.4), mat("wood_dk", 0.7), B, bevel=0.01)]
	for i, (tx, ln, head) in enumerate(((-0.7, 1.7, "rake"), (-0.2, 1.5, "spade"), (0.35, 1.6, "fork"), (0.8, 1.2, "shears"))):
		bp.append(cyl(f"tool{i}", 0.035, ln, (sx + tx, y1 - 0.14, 2.4 - ln), mat("bark", 0.8), B, seg=8))
		bp.append(box(f"tool{i}_h", (0.45 if head == "rake" else 0.25, 0.04, 0.12 if head == "rake" else 0.3),
					  (sx + tx, y1 - 0.15, 2.4 - ln), mat("steel", 0.3, 0, 0.8), B, bevel=0.02))
	bp.append(box("shed_shelf", (1.3, 0.3, 0.06), (sx, y1 - 0.18, 3.0), mat("wood", 0.7), B, bevel=0.01))
	for i in range(3):
		bp.append(cyl(f"shed_cup{i}", 0.07, 0.3, (sx - 0.4 + i * 0.4, y1 - 0.2, 3.04), mat("gold", 0.3, 0, 0.8), B, r2=0.14, seg=14))
	bpy.context.view_layer.update()
	for o in bp:
		child(o, back)
	lp = [_planks(B, "shed_leftwall", (0.1, SHED_D, SHED_H), (x0, (y0 + y1) / 2, SHED_H / 2))]
	rp = [_planks(B, "shed_rightwall", (0.1, SHED_D, SHED_H), (x1, (y0 + y1) / 2, SHED_H / 2))]
	rp.append(box("shed_window", (0.04, 0.8, 0.6), (x1 + 0.06, (y0 + y1) / 2, 2.4), mat("sky2", 0.2, 0.4), B, bevel=0.02))
	bpy.context.view_layer.update()
	for o in lp:
		child(o, left)
	for o in rp:
		child(o, right)
	box("shed_floor", (SHED_W, SHED_D, 0.06), (sx, (y0 + y1) / 2, 0.03), mat("wood_dk", 0.8), B, bevel=0)

	# front: the wall with its door hole, the door on its left jamb, a sign; the roof rides separately
	front = group("shed_front", F, (sx, y0, 0))
	bpy.context.view_layer.update()
	jw = (SHED_W - DOOR_W) / 2
	fp = [_planks(F, "front_l", (jw, 0.12, SHED_H), (x0 + jw / 2, y0, SHED_H / 2)),
		  _planks(F, "front_r", (jw, 0.12, SHED_H), (x1 - jw / 2, y0, SHED_H / 2)),
		  _planks(F, "front_top", (DOOR_W, 0.12, SHED_H - DOOR_H), (sx, y0, (SHED_H + DOOR_H) / 2))]
	for side in (-1, 1):
		fp.append(box(f"front_trim{side}", (0.1, 0.16, DOOR_H), (sx + side * DOOR_W / 2, y0 - 0.02, DOOR_H / 2), mat("fence", 0.7), F, bevel=0.02))
	fp.append(box("front_trim_top", (DOOR_W + 0.2, 0.16, 0.1), (sx, y0 - 0.02, DOOR_H), mat("fence", 0.7), F, bevel=0.02))
	fp.append(box("shed_sign", (1.7, 0.05, 0.42), (sx, y0 - 0.1, (SHED_H + DOOR_H) / 2), mat("fence", 0.8), F, bevel=0.02))
	fp.append(text("shed_sign_t", "BEST LAWN · 9 YEARS", 0.13, (sx, y0 - 0.13, (SHED_H + DOOR_H) / 2), F, "ink"))
	door = group("shed_door", F, (sx - DOOR_W / 2, y0 - 0.06, 0))
	bpy.context.view_layer.update()
	dp = [_planks(F, "door", (DOOR_W - 0.06, 0.08, DOOR_H - 0.04), (sx, y0 - 0.06, DOOR_H / 2), "shed_lt")]
	dp.append(box("door_z", (0.12, 0.04, 2.6), (sx, y0 - 0.11, DOOR_H / 2), mat("shed_dk", 0.7), F, bevel=0.01, rot=(0, 33, 0)))
	dp.append(sph("door_knob", 0.08, (sx + DOOR_W / 2 - 0.25, y0 - 0.15, 1.45), mat("brass", 0.3, 0, 0.8), F))
	bpy.context.view_layer.update()
	for o in dp:
		child(o, door)
	bpy.context.view_layer.update()
	for o in fp + [door]:
		child(o, front)
	roof = group("shed_roof", F, (sx, (y0 + y1) / 2, SHED_H))
	bpy.context.view_layer.update()
	ov = 0.25
	rf = []
	for side, yy in ((-1, y0 - ov), (1, y1 + ov)):
		# one slope: from the eave (y0-ov / y1+ov, z = SHED_H) up to the ridge (centre, z = SHED_H + 0.9)
		bm = bmesh.new()
		ym = (y0 + y1) / 2
		pts = [(x0 - ov, yy, SHED_H), (x1 + ov, yy, SHED_H), (x1 + ov, ym, SHED_H + 0.9), (x0 - ov, ym, SHED_H + 0.9)]
		vs = [bm.verts.new(p) for p in pts]
		f = bm.faces.new(vs)
		ext = bmesh.ops.extrude_face_region(bm, geom=[f])
		bmesh.ops.translate(bm, vec=Vector((0, 0, 0.12)), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		rf.append(K.put(f"roof{side}", bm, SC.mat_shingles("roof", "roof_lt") if side < 0 else SC.mat_shingles("roof_dk", "roof"), F))
	rf.append(box("ridge", (SHED_W + 2 * ov + 0.1, 0.22, 0.14), (sx, (y0 + y1) / 2, SHED_H + 0.98), mat("roof_dk", 0.8), F, bevel=0.03))
	for side in (-1, 1):
		rf.append(prism(f"gable{side}", [(-SHED_D / 2, 0), (SHED_D / 2, 0), (0, 0.9)], 0.1,
						(sx + side * SHED_W / 2, (y0 + y1) / 2, SHED_H), mat("shed_dk", 0.8), F, rot=(90, 0, 90)))
	bpy.context.view_layer.update()
	for o in rf:
		child(o, roof)

	def shed_frame(k: int) -> None:
		# open on frame 1; as the wall falls the door folds flat against its face (so it lands flat too)
		door.rotation_euler = Euler((0, 0, math.radians(-105 * clamp01(k / 1.0) - 72 * clamp01((k - 2) / 3.0))))
		f_ = clamp01((k - 1) / 5.0)
		front.rotation_euler = Euler((math.radians(90 * f_ * f_ - (4 if k == 6 else 0)), 0, 0))
		s_ = clamp01((k - 6) / 3.0)
		left.rotation_euler = Euler((0, math.radians(-90 * s_ * s_), 0))
		right.rotation_euler = Euler((0, math.radians(90 * s_ * s_), 0))
		back.rotation_euler = Euler((math.radians(-90 * s_ * s_), 0, 0))
		r_ = clamp01((k - 9) / 2.0)
		roof.location.z = SHED_H - (SHED_H - HEAD_Z) * r_ * r_ + (0.08 if k == 11 else 0.0)
		roof.rotation_euler = Euler((0, math.radians(-7 * r_), 0))
	seqs["shedbox"] = (13, shed_frame)
	seqs["shedfront"] = (13, shed_frame)
	piv["shed_door"] = (sx, STAGE_Y, 0)
	piv["shed_roof"] = (sx, y0, HEAD_Z + 0.5)

	# --- the house curtains (as before) ---
	fy = -2.2
	pleats = []
	for side in (-1, 1):
		for k in range(16):
			o = cyl(f"cur{side}_{k}", 0.34, 9.0, (0, fy + 0.7 + (k % 2) * 0.12, -1.6),
					mat("velvet" if k % 2 else "velvet_dk", 0.85), "seq_curtain", seg=16)
			pleats.append((o, side, k))
		hem = box(f"cur_hem{side}", (9.8, 0.5, 0.25), (side * 4.9, fy + 0.5, -0.4), mat("gold", 0.4, 0, 0.6), "seq_curtain", bevel=0.05)
		pleats.append((hem, side, -1))
	gs = [1.0, 0.94, 0.82, 0.68, 0.54, 0.42, 0.32, 0.24, 0.18]

	def curtain_frame(k: int) -> None:
		g = gs[k]
		for o, side, i in pleats:
			if i < 0:
				o.scale = (g, 1, 1)
				o.location.x = side * (9.0 - 4.9 * g)
				continue
			o.location.x = side * (9.0 - (15.5 - i) * 0.6 * g)
			f = 1.0 + 0.35 * (1.0 - g)
			o.scale = (f, f, 1)
	seqs["curtain"] = (len(gs), curtain_frame)
	return seqs


def setup_lights(scene, cam) -> None:
	"""A bright morning: a warm sun, a cool sky fill, the footlights."""
	K.setup_render(scene, cam)
	for o in list(coll("lights").objects):
		bpy.data.objects.remove(o, do_unlink=True)
	cyc = K.ENGINE["name"] == "cycles"
	scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.93, 1.0, 1)
	scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.6 if cyc else 0.8
	lights = coll("lights")
	sun = bpy.data.lights.new("sun", "SUN")
	sun.energy = 4.2 if cyc else 3.4
	sun.angle = math.radians(4)
	sun.color = (1.0, 0.95, 0.85)
	so = bpy.data.objects.new("sun", sun)
	so.rotation_euler = Euler((math.radians(48), 0, math.radians(28)))
	lights.objects.link(so)
	ld = bpy.data.lights.new("foot", "POINT")
	ld.energy = 300 if cyc else 500
	ld.color = (1.0, 0.86, 0.62)
	ld.shadow_soft_size = 5.0
	lo = bpy.data.objects.new("foot", ld)
	lo.location = (0.0, -2.5, 2.2)
	lights.objects.link(lo)


def main() -> int:
	def build():
		marks = build_room()
		piv = build_props()
		seqs = build_seqs(piv)
		return marks, piv, seqs
	return stagekit.run(build, setup_lights, os.path.join(HERE, "out_act3"))


if __name__ == "__main__":
	raise SystemExit(main())
