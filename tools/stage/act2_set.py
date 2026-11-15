"""act2_set — model Gus Thudd's kitchen from scratch in Blender and render it as game layers (Act II).

    python3 tools/stage/build.py --act act2 [--engine eevee]

Same camera, scale and stage as Act I (1 Hush model unit = 128 logical px, 10 degree tilt, the walk
line at y = 1.3 lands on 880 px), and the same proscenium, Stalls and HUD icons: those, the
primitives and the materials are imported from act1_set. Everything in the kitchen is new.

Stage left to right (x in units, 0 = centre, px = 1200 + 128 x):
  -7.9  the back door      Hush's way in
  -5.4  toaster + counter  RIG 1: wound to MAX; the frying pan hangs on the rail above it
  -2.6  stove              Gus flips pancakes here
  -0.6  table (fg)         a long tablecloth (wide: it hides Gus when the chair goes), a plate stack of pancakes; the chair at +0.75
   4.0  fridge             Gus rummages for eggs (door is a baked sequence)
   6.0  pantry             RIG 3: shelves knocked loose; the tin avalanche is a baked sequence
   7.95 BULK boxes (fg)    Hush hides behind them

Layers (cropped and packed by build.py): bg, fx_shaft, fg_table, fg_boxes, prop_pancake,
prop_toast, prop_toast2, prop_pan, seq_backdoor, seq_fridge, seq_chair, seq_pantry, seq_curtain,
fxs_dust, frame, audience, icon_*. marks/pivots are written to marks.json.
"""
from __future__ import annotations

import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bmesh  # type: ignore  # noqa: E402
import bpy  # type: ignore  # noqa: E402
from mathutils import Euler, Vector  # type: ignore  # noqa: E402

import act1_set as K  # noqa: E402  (primitives, materials, frame, audience, icons, camera, render)
import scenery as SC  # noqa: E402  (shared outdoor kit: the window view)
import stagekit  # noqa: E402  (the shared render loop)

box, cyl, sph, torus, prism, mat, coll, put = K.box, K.cyl, K.sph, K.torus, K.prism, K.mat, K.coll, K.put
group, child, clamp01 = K.group, K.child, K.clamp01
WALL_Y, STAGE_Y = K.WALL_Y, K.STAGE_Y

# kitchen palette: lemon + mint, cobalt and copper; kept clear of the cast (navy/cherry, green/orange)
K.C.update({
	"lemon": "#F4E2A0", "lemon2": "#EBD283", "lemon_dot": "#FBF0C4", "mint": "#A8DCC8", "mint_dk": "#6FB8A0", "tile": "#F6F3EA",
	"grout": "#C9C3B4", "cobalt": "#2F5E9E", "cobalt_dk": "#22477A", "copper": "#C87B45", "copper_dk": "#8E4F27",
	"lino": "#F1E4C6", "lino2": "#3E7F86", "fridge": "#DDEFE7", "fridge_dk": "#B5D3C6", "fridge_hi": "#EEF9F4", "chrome": "#D5DCE3",
	"cloth": "#F4F0E6", "cloth_chk": "#D9475A", "pancake": "#E0A04A", "pancake_dk": "#B97830",
	"syrup": "#9A4E17", "toast": "#D9A05B", "toast_crust": "#9C6230", "tin": "#C9D2DA", "tin_lbl1": "#E2463F",
	"tin_lbl2": "#3C8D4F", "tin_lbl3": "#F2C230", "box": "#C79A5E", "box_dk": "#A47A43", "tape": "#E8D7A8",
	"hob": "#2C2A33", "flame": "#5FB8FF", "plate": "#FBFBF6", "egg": "#FFF6E2", "milk": "#F7F7F2",
	"cupboard": "#E9DDC4", "cupboard_dk": "#C9B994", "counter": "#7A5A44", "worktop": "#E7E2D8",
})


def mat_checker(a: str, b: str, scale: float, name: str):
	"""Lino: a checkerboard in OBJECT space, `scale` squares per unit."""
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	bs = nt.nodes["Principled BSDF"]
	bs.inputs["Roughness"].default_value = 0.35
	tc = nt.nodes.new("ShaderNodeTexCoord")
	ch = nt.nodes.new("ShaderNodeTexChecker")
	ch.inputs["Color1"].default_value = K.lin(K.C[a])
	ch.inputs["Color2"].default_value = K.lin(K.C[b])
	ch.inputs["Scale"].default_value = scale
	nt.links.new(tc.outputs["Object"], ch.inputs["Vector"])
	# a little wear: low-frequency mottle so the lino is not two flat inks
	nz = nt.nodes.new("ShaderNodeTexNoise")
	nz.inputs["Scale"].default_value = 1.8
	nz.inputs["Detail"].default_value = 3.0
	nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
	mx = nt.nodes.new("ShaderNodeMix")
	mx.data_type = "RGBA"
	mx.blend_type = "OVERLAY"
	mx.inputs[0].default_value = 0.18
	nt.links.new(ch.outputs["Color"], mx.inputs[6])
	nt.links.new(nz.outputs["Fac"], mx.inputs[7])
	nt.links.new(mx.outputs[2], bs.inputs["Base Color"])
	return m


def mat_enamel(lo: str, mid: str, hi: str, name: str):
	"""Retro appliance enamel: a soft vertical gradient (darker foot, lighter crown) with a glossy coat,
	so a big flat door still reads as a curved, shiny panel."""
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	bs = nt.nodes["Principled BSDF"]
	bs.inputs["Roughness"].default_value = 0.28
	bs.inputs["Metallic"].default_value = 0.08
	try:
		bs.inputs["Coat Weight"].default_value = 0.4
		bs.inputs["Coat Roughness"].default_value = 0.2
	except KeyError:
		pass
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	nt.links.new(sep.outputs[2], ramp.inputs[0])
	el = ramp.color_ramp.elements
	el[0].position, el[0].color = 0.0, K.lin(K.C[lo])
	el[1].position, el[1].color = 1.0, K.lin(K.C[hi])
	e = el.new(0.45)
	e.color = K.lin(K.C[mid])
	nt.links.new(ramp.outputs["Color"], bs.inputs["Base Color"])
	return m


def mat_tiles():
	"""Square white splash-back tiles with grey grout (the wall is in x-z)."""
	m = bpy.data.materials.new("tiles")
	m.use_nodes = True
	nt = m.node_tree
	bs = nt.nodes["Principled BSDF"]
	bs.inputs["Roughness"].default_value = 0.25
	tc = nt.nodes.new("ShaderNodeTexCoord")
	mp = nt.nodes.new("ShaderNodeMapping")
	mp.inputs["Rotation"].default_value = (math.radians(90), 0, 0)   # wall x-z -> texture x-y
	nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
	br = nt.nodes.new("ShaderNodeTexBrick")
	br.inputs["Color1"].default_value = K.lin(K.C["tile"])
	br.inputs["Color2"].default_value = K.lin(K.C["tile"])
	br.inputs["Mortar"].default_value = K.lin(K.C["grout"])
	br.inputs["Scale"].default_value = 1.0
	br.inputs["Mortar Size"].default_value = 0.02
	br.inputs["Brick Width"].default_value = 0.42
	br.inputs["Row Height"].default_value = 0.42
	br.offset = 0.0
	nt.links.new(mp.outputs[0], br.inputs["Vector"])
	nt.links.new(br.outputs["Color"], bs.inputs["Base Color"])
	return m


def text(name: str, body: str, size: float, loc, where: str, colour: str = "ink", rot=(90, 0, 0)):
	cu = bpy.data.curves.new(name, "FONT")
	cu.body = body
	cu.size = size
	cu.align_x = "CENTER"
	cu.align_y = "CENTER"
	cu.extrude = 0.006
	ob = bpy.data.objects.new(name, cu)
	coll(where).objects.link(ob)
	ob.data.materials.append(mat(colour, 0.8))
	ob.location = loc
	ob.rotation_euler = Euler([math.radians(v) for v in rot])
	return ob


# ---------------------------------------------------------------------------------------------
X_DOOR, X_TOAST, X_STOVE, X_TABLE, X_CHAIR, X_FRIDGE, X_PANTRY, X_BOXES = -7.9, -5.4, -2.6, -0.6, 0.75, 4.0, 6.0, 7.95
TABLE_Z = 1.35
RAIL_Z = 4.9                       # the utensil rail; the frying pan hangs 1.2 below it
WIN = (-0.4, 4.15, 2.9, 2.2)       # window centre x, z, width, height (over the table)


def build_room() -> dict:
	marks: dict = {}
	fm = mat("cream", 0.6)
	# wall: lemon paint above a tiled splash-back, a cobalt dado tile line between
	box("wall", (19.6, 0.3, 7.6), (0, WALL_Y + 0.15, 3.8), K.mat_wallpaper("lemon", "lemon2", "lemon_dot", "lemonpaper", 1.2), bevel=0)
	box("splash", (19.6, 0.06, 2.4), (0, WALL_Y - 0.03, 1.2), mat_tiles(), bevel=0)
	box("dado", (19.6, 0.12, 0.14), (0, WALL_Y - 0.06, 2.45), mat("cobalt", 0.3), bevel=0.02)
	box("skirting", (19.6, 0.2, 0.2), (0, WALL_Y - 0.12, 0.1), mat("cobalt_dk", 0.5), bevel=0.03)
	box("cornice", (19.6, 0.4, 0.3), (0, WALL_Y - 0.1, 7.15), mat("trim", 0.6), bevel=0.06)
	box("floor", (19.6, 6.0, 0.2), (0, 1.0, -0.1), mat_checker("lino", "lino2", 1.1, "lino"), bevel=0)
	# stage apron + footlights (same theatre as Act I)
	box("apron", (19.6, 0.4, 3.0), (0, -1.7, -1.5), mat("stage", 0.6), bevel=0)
	box("apron_lip", (19.6, 0.5, 0.12), (0, -1.55, -0.06), mat("gold", 0.35, 0, 0.6), bevel=0.04)
	for i in range(11):
		x = -7.5 + i * 1.5
		sph(f"foot{i}", 0.13, (x, -1.82, -0.18), mat("bulb", 0.3, 4.0), scale=(1.3, 1, 0.8))
		box(f"foothood{i}", (0.42, 0.18, 0.12), (x, -1.9, -0.06), mat("gold_dk", 0.4, 0, 0.6), bevel=0.03)

	# --- back door (stage left), with a little window ---
	dw, dh = 1.6, 4.3
	box("doorway", (dw, 0.1, dh), (X_DOOR, WALL_Y - 0.02, dh / 2), mat("#3A2433", 0.9), bevel=0)
	for side in (-1, 1):
		box(f"door_jamb{side}", (0.2, 0.3, dh + 0.1), (X_DOOR + side * (dw / 2 + 0.1), WALL_Y - 0.15, dh / 2), fm)
	box("door_head", (dw + 0.6, 0.34, 0.26), (X_DOOR, WALL_Y - 0.17, dh + 0.13), fm)
	box("doormat", (1.5, 0.8, 0.04), (X_DOOR + 0.2, 2.2, 0.02), mat("box_dk", 0.95), bevel=0.02)
	marks["door"] = (X_DOOR + 0.3, STAGE_Y, 0)

	# --- window over the table: the immaculate lawn again, and a sun ---
	wx, wz, ww, wh = WIN
	# the garden outside, from the shared kit (no fence: the cafe curtain covers the lower half anyway)
	SC.window_view("winview", (wx, wz, ww, wh), seed=2, sun_at=(-0.3, 0.3), lawn=0.26,
				   clouds=((0.25, 0.3, 0.3), (0.05, 0.18, 0.18)))
	box("win_top", (ww + 0.36, 0.26, 0.18), (wx, WALL_Y - 0.18, wz + wh / 2 + 0.09), fm)
	box("win_bot", (ww + 0.6, 0.42, 0.16), (wx, WALL_Y - 0.25, wz - wh / 2 - 0.08), fm)
	box("win_l", (0.18, 0.26, wh + 0.2), (wx - ww / 2 - 0.09, WALL_Y - 0.18, wz), fm)
	box("win_r", (0.18, 0.26, wh + 0.2), (wx + ww / 2 + 0.09, WALL_Y - 0.18, wz), fm)
	box("win_mv", (0.09, 0.14, wh), (wx, WALL_Y - 0.15, wz), fm)
	# gingham cafe curtain on a rod across the bottom half
	box("cafe_rod", (ww + 0.2, 0.05, 0.05), (wx, WALL_Y - 0.34, wz - 0.05), mat("brass", 0.35, 0, 0.7), bevel=0)
	for side in (-1, 1):
		box(f"cafe{side}", (ww / 2 - 0.15, 0.04, 1.0), (wx + side * (ww / 4 + 0.05), WALL_Y - 0.36, wz - 0.58),
			K.mat_bands("cloth", "cloth_chk", 5.0, 0, f"gingham{side}"), bevel=0.01)
	# herbs on the sill
	for i, x in enumerate((-1.0, -0.45, 0.6)):
		cyl(f"herb_pot{i}", 0.13, 0.2, (wx + x, WALL_Y - 0.35, wz - wh / 2 + 0.02), mat("pot", 0.7), r2=0.16, seg=14)
		for k in range(4):
			sph(f"herb{i}{k}", 0.1, (wx + x + (k - 1.5) * 0.06, WALL_Y - 0.35, wz - wh / 2 + 0.32 + (k % 2) * 0.08), mat("leaf", 0.7), scale=(0.8, 0.8, 1.3))
	marks["window"] = (wx, WALL_Y, wz)

	# --- counter run, stage left: cupboards, worktop, toaster, the utensil rail + frying pan ---
	cx0, cx1 = -6.75, -4.05
	cxm, cw = (cx0 + cx1) / 2, cx1 - cx0
	box("counter", (cw, 0.9, 1.45), (cxm, WALL_Y - 0.5, 0.72), mat("cobalt", 0.6), bevel=0.04)
	for i in range(2):
		x = cx0 + cw * (i + 0.5) / 2
		box(f"counter_door{i}", (cw / 2 - 0.15, 0.04, 1.05), (x, WALL_Y - 0.97, 0.72), mat("cobalt_dk", 0.6), bevel=0.03)
		box(f"counter_knob{i}", (0.22, 0.06, 0.06), (x + (0.4 if i == 0 else -0.4), WALL_Y - 1.01, 1.0), mat("chrome", 0.3, 0, 0.8), bevel=0.02)
	box("worktop", (cw + 0.1, 1.0, 0.1), (cxm, WALL_Y - 0.52, 1.5), mat("worktop", 0.35), bevel=0.02)
	tx = X_TOAST
	box("toaster", (0.8, 0.5, 0.55), (tx, WALL_Y - 0.6, 1.83), mat("chrome", 0.2, 0, 0.9), bevel=0.12)
	for k in (-0.15, 0.15):
		box(f"toaster_slot{k}", (0.5, 0.06, 0.03), (tx, WALL_Y - 0.6 + k, 2.11), mat("black", 0.6), bevel=0)
	box("toaster_lever", (0.06, 0.12, 0.18), (tx + 0.43, WALL_Y - 0.75, 1.85), mat("black", 0.5), bevel=0.02)
	cyl("toaster_dial", 0.07, 0.04, (tx - 0.2, WALL_Y - 0.86, 1.72), mat("cherry" if "cherry" in K.C else "tin_lbl1", 0.4), rot=(90, 0, 0), seg=16)
	marks["toaster"] = (tx, WALL_Y - 0.6, 2.1)
	# kettle + bread bin
	cyl("kettle", 0.26, 0.42, (cx0 + 0.45, WALL_Y - 0.5, 1.55), mat("tin_lbl1", 0.3, 0, 0.3), r2=0.2, seg=24)
	cyl("kettle_lid", 0.12, 0.08, (cx0 + 0.45, WALL_Y - 0.5, 1.97), mat("black", 0.4), seg=16)
	box("breadbin", (0.7, 0.45, 0.45), (cx1 - 0.55, WALL_Y - 0.55, 1.78), mat("mint", 0.5), bevel=0.12)
	# utensil rail: ladle, whisk, spatula hang; the pan's hook is empty (the pan is a prop)
	box("rail", (2.4, 0.06, 0.06), (cxm + 0.3, WALL_Y - 0.12, RAIL_Z), mat("chrome", 0.3, 0, 0.8), bevel=0)
	for i, (x, ln) in enumerate(((-0.8, 0.8), (-0.35, 0.7), (0.9, 0.75))):
		cyl(f"utensil{i}", 0.025, ln, (cxm + 0.3 + x, WALL_Y - 0.15, RAIL_Z - 0.03 - ln), mat("chrome", 0.3, 0, 0.8), seg=8)
	sph("ladle", 0.12, (cxm + 0.3 - 0.8, WALL_Y - 0.17, RAIL_Z - 0.85), mat("chrome", 0.3, 0, 0.8), scale=(1, 1, 0.6))
	sph("whisk", 0.1, (cxm + 0.3 - 0.35, WALL_Y - 0.17, RAIL_Z - 0.8), mat("chrome", 0.3, 0, 0.8), scale=(0.8, 0.8, 1.6))
	box("spatula", (0.2, 0.03, 0.25), (cxm + 0.3 + 0.9, WALL_Y - 0.17, RAIL_Z - 0.85), mat("black", 0.5), bevel=0.02)
	marks["pan_hook"] = (cxm + 0.3 + 0.35, WALL_Y - 0.15, RAIL_Z)
	# calendar: one event a month and it is always the lawn
	calx, calz = -3.72, 3.3
	box("cal", (0.58, 0.04, 1.0), (calx, WALL_Y - 0.04, calz), mat("paper_w", 0.9), bevel=0.01)
	box("cal_pic", (0.46, 0.03, 0.36), (calx, WALL_Y - 0.07, calz + 0.3), mat("lawn", 0.9), bevel=0)
	text("cal_t", "MOW", 0.14, (calx, WALL_Y - 0.08, calz - 0.12), "bg", "tin_lbl1")
	text("cal_t2", "MOW", 0.1, (calx, WALL_Y - 0.08, calz - 0.32), "bg", "ink")

	# --- stove + extractor hood ---
	sx = X_STOVE
	box("stove", (1.5, 0.95, 1.45), (sx, WALL_Y - 0.55, 0.72), mat("white", 0.35), bevel=0.06)
	box("oven_door", (1.2, 0.05, 0.85), (sx, WALL_Y - 1.04, 0.62), mat("black", 0.15), bevel=0.03)
	box("oven_handle", (1.0, 0.08, 0.06), (sx, WALL_Y - 1.1, 1.12), mat("chrome", 0.3, 0, 0.8), bevel=0.02)
	for i in range(4):
		cyl(f"knob{i}", 0.06, 0.06, (sx - 0.45 + i * 0.3, WALL_Y - 1.05, 1.3), mat("black", 0.4), rot=(90, 0, 0), seg=12)
	box("hob", (1.5, 0.95, 0.06), (sx, WALL_Y - 0.55, 1.48), mat("hob", 0.3), bevel=0.02)
	for x in (-0.38, 0.38):
		torus(f"burner{x}", 0.18, 0.025, (sx + x, WALL_Y - 0.75, 1.52), mat("flame", 0.5, 2.0 if x > 0 else 0.0))
	box("hood", (1.6, 0.9, 0.5), (sx, WALL_Y - 0.45, 4.25), mat("chrome", 0.3, 0, 0.8), bevel=0.06)
	prism("hood_skirt", [(-0.85, 0), (0.85, 0), (0.6, 0.45), (-0.6, 0.45)], 0.85, (sx, WALL_Y - 0.03, 3.55),
		  mat("chrome", 0.3, 0, 0.8))
	box("hood_flue", (0.6, 0.5, 2.6), (sx, WALL_Y - 0.25, 5.8), mat("chrome", 0.3, 0, 0.8), bevel=0.03)
	# the pancake pan on the right burner, the batter jug beside it
	cyl("fry_pan", 0.42, 0.1, (sx + 0.38, WALL_Y - 0.75, 1.55), mat("black", 0.35), r2=0.48, seg=28)
	cyl("fry_handle", 0.04, 0.6, (sx + 0.8, WALL_Y - 0.75, 1.62), mat("black", 0.4), rot=(0, 80, 0), seg=10)
	cyl("jug", 0.16, 0.38, (sx - 0.4, WALL_Y - 0.65, 1.52), mat("cream", 0.4), r2=0.13, seg=16)
	marks["stove"] = (sx, STAGE_Y, 0)
	# spice shelf with jars over the stove's left side
	shx = 2.0
	box("spice_shelf", (1.3, 0.3, 0.07), (shx, WALL_Y - 0.15, 3.4), mat("wood", 0.6), bevel=0.02)
	for i in range(4):
		cyl(f"jar{i}", 0.1, 0.28, (shx - 0.45 + i * 0.3, WALL_Y - 0.18, 3.44), mat(("tin_lbl1", "tin_lbl3", "mint_dk", "copper")[i], 0.4), seg=12)
		cyl(f"jar_lid{i}", 0.1, 0.05, (shx - 0.45 + i * 0.3, WALL_Y - 0.18, 3.72), mat("chrome", 0.3, 0, 0.8), seg=12)

	# --- clock (over the table, left of the window) ---
	clx, clz = 2.0, 5.2
	cyl("clock", 0.4, 0.1, (clx, WALL_Y - 0.05, clz), mat("cobalt", 0.5), rot=(90, 0, 0), seg=40)
	cyl("clock_face", 0.33, 0.05, (clx, WALL_Y - 0.11, clz), mat("cream", 0.6), rot=(90, 0, 0), seg=40)
	box("clock_h1", (0.04, 0.03, 0.22), (clx, WALL_Y - 0.16, clz + 0.08), mat("ink"), bevel=0, rot=(0, 0, 0))
	box("clock_h2", (0.035, 0.03, 0.28), (clx + 0.08, WALL_Y - 0.17, clz - 0.02), mat("ink"), bevel=0, rot=(0, 110, 0))
	# pendant lamp over the table
	cyl("pend_rod", 0.03, 1.4, (X_TABLE, 2.2, 5.6), mat("brass", 0.35, 0, 0.7), seg=8)
	cyl("pend_shade", 0.6, 0.4, (X_TABLE, 2.2, 5.25), mat("mint_dk", 0.6, 0.0), r2=0.16, seg=32)
	sph("pend_bulb", 0.14, (X_TABLE, 2.2, 5.22), mat("bulb", 0.3, 6.0))
	marks["pendant"] = (X_TABLE, 2.2, 5.2)

	# --- fridge: tall, rounded, retro mint; magnets and a note on the door are on the door sequence ---
	fx = X_FRIDGE
	# a hollow shell (back, sides, top, plinth) so the inside shows when the door swings open
	fy0, fy1 = WALL_Y - 1.1, WALL_Y - 0.1          # front, back
	fyc, fd = (fy0 + fy1) / 2, fy1 - fy0
	box("fridge_back", (1.5, 0.2, 3.7), (fx, fy1 - 0.1, 1.85), mat_enamel("fridge_dk", "fridge", "fridge_hi", "enamel_shell"), bevel=0.05)
	for side in (-1, 1):
		box(f"fridge_side{side}", (0.12, fd, 3.7), (fx + side * 0.69, fyc, 1.85), mat_enamel("fridge_dk", "fridge", "fridge_hi", "enamel_shell"), bevel=0.05)
	box("fridge_top", (1.5, fd, 0.25), (fx, fyc, 3.6), mat_enamel("fridge_dk", "fridge", "fridge_hi", "enamel_shell"), bevel=0.12)
	box("fridge_plinth", (1.5, fd, 0.3), (fx, fyc, 0.15), mat("chrome", 0.3, 0, 0.8), bevel=0.04)
	# the inside: a cold glow, glass shelves, milk, eggs, a single lettuce
	box("fridge_in", (1.26, 0.05, 3.15), (fx, fy1 - 0.23, 1.9), mat("#9FD8F0", 0.6, 0.7), bevel=0)
	for side in (-1, 1):
		box(f"fridge_wall{side}", (0.03, fd - 0.2, 3.15), (fx + side * 0.62, fyc, 1.9), mat("#C6E9F7", 0.6, 0.4), bevel=0)
	for z in (0.95, 1.8, 2.65):
		box(f"fshelf{z}", (1.26, fd - 0.3, 0.04), (fx, fyc + 0.05, z), mat("white", 0.2, 0.4), bevel=0)
	cyl("milk", 0.13, 0.5, (fx - 0.35, fyc - 0.2, 1.82), mat("milk", 0.5), seg=14)
	cyl("milk_cap", 0.06, 0.08, (fx - 0.35, fyc - 0.2, 2.32), mat("cobalt", 0.5), seg=10)
	for i in range(3):
		sph(f"egg{i}", 0.09, (fx + 0.05 + i * 0.18, fyc - 0.2, 2.78), mat("egg", 0.5), scale=(1, 1, 1.25))
	sph("lettuce", 0.22, (fx + 0.25, fyc - 0.15, 1.2), mat("leaf", 0.7))
	cyl("jelly", 0.18, 0.22, (fx - 0.25, fyc - 0.2, 0.97), mat("tin_lbl1", 0.15), r2=0.12, seg=16)
	marks["fridge"] = (fx, STAGE_Y, 0)

	# --- pantry: tall cupboard (its doors and the avalanche are the pantry sequence) ---
	px_ = X_PANTRY
	# a hollow cupboard: back, sides, top, plinth; the doors sit across its front
	py0, py1 = WALL_Y - 0.96, WALL_Y - 0.05
	pyc, pd = (py0 + py1) / 2, py1 - py0
	box("pantry_back", (1.9, 0.12, 4.9), (px_, py1 - 0.06, 2.45), mat("#4A3A2C", 0.9), bevel=0)
	for side in (-1, 1):
		box(f"pantry_side{side}", (0.1, pd, 4.9), (px_ + side * 0.9, pyc, 2.45), mat("cupboard_dk", 0.6), bevel=0.03)
	box("pantry_plinth", (1.9, pd, 0.2), (px_, pyc, 0.1), mat("cupboard_dk", 0.6), bevel=0.03)
	box("pantry_crown", (2.1, pd + 0.1, 0.18), (px_, pyc, 4.95), mat("cupboard", 0.6), bevel=0.04)
	for z in (1.05, 2.15, 3.25, 4.25):
		box(f"pshelf{z}", (1.7, pd - 0.1, 0.05), (px_, pyc, z - 0.03), mat("wood_lt", 0.6), bevel=0)
	marks["pantry"] = (px_, STAGE_Y, 0)
	# a framed motto on the wall beside the fridge
	mox, moz = X_FRIDGE, 4.6
	box("motto_f", (1.0, 0.06, 0.7), (mox, WALL_Y - 0.05, moz), mat("wood_dk", 0.5), bevel=0.03)
	box("motto_p", (0.85, 0.03, 0.55), (mox, WALL_Y - 0.08, moz), mat("paper_w", 0.9), bevel=0)
	text("motto_t1", "NO", 0.13, (mox, WALL_Y - 0.1, moz + 0.1), "bg", "ink")
	text("motto_t2", "CARBS", 0.13, (mox, WALL_Y - 0.1, moz - 0.1), "bg", "tin_lbl1")
	return marks


# ---------------------------------------------------------------------------------------------
def build_props() -> dict:
	"""Static foreground layers (in front of the cast) and the 2D props, each in its own collection."""
	piv: dict = {}
	# --- the table: long gingham tablecloth to the floor, plate with a pancake stack, syrup ---
	tx, ty = X_TABLE, 0.95
	tw, td = 3.3, 1.1                # right edge at +1.05: covers a seated Gus, chair back sticks out
	box("cloth_top", (tw + 0.1, td + 0.1, 0.06), (tx, ty, TABLE_Z), mat("cloth", 0.9), "fg_table", bevel=0.03)
	box("cloth_drop", (tw + 0.14, 0.05, TABLE_Z), (tx, ty - td / 2 - 0.04, TABLE_Z / 2), K.mat_bands("cloth", "cloth_chk", 4.0, 0, "cloth_front"), "fg_table", bevel=0.02)
	box("cloth_hem", (tw + 0.16, 0.07, 0.1), (tx, ty - td / 2 - 0.05, 0.06), mat("cloth_chk", 0.9), "fg_table", bevel=0.02)
	for side in (-1, 1):
		box(f"cloth_side{side}", (0.05, td + 0.1, TABLE_Z), (tx + side * (tw / 2 + 0.06), ty, TABLE_Z / 2), mat("cloth", 0.9), "fg_table", bevel=0.02)
	plx = tx - 0.85
	cyl("plate", 0.45, 0.04, (plx, ty - 0.05, TABLE_Z + 0.03), mat("plate", 0.3), "fg_table", r2=0.5, seg=32)
	for i in range(3):
		cyl(f"stack{i}", 0.36, 0.07, (plx + (i - 1) * 0.02, ty - 0.05, TABLE_Z + 0.07 + i * 0.075), mat("pancake" if i % 2 else "pancake_dk", 0.6), "fg_table", seg=28)
	box("stack_butter", (0.16, 0.12, 0.08), (plx, ty - 0.05, TABLE_Z + 0.33), mat("butter", 0.3), "fg_table", bevel=0.02)
	# syrup and milk at the far end: the near end is where Gus's face comes back up over the edge
	cyl("syrup_bottle", 0.12, 0.42, (plx + 0.62, ty + 0.1, TABLE_Z + 0.03), mat("syrup", 0.2), "fg_table", r2=0.08, seg=16)
	cyl("syrup_cap", 0.07, 0.08, (plx + 0.62, ty + 0.1, TABLE_Z + 0.45), mat("tin_lbl1", 0.4), "fg_table", seg=12)
	cyl("glass", 0.1, 0.28, (tx - 1.4, ty - 0.1, TABLE_Z + 0.03), mat("milk", 0.3), "fg_table", r2=0.11, seg=16)
	box("fork", (0.04, 0.3, 0.02), (plx + 1.0, ty - 0.2, TABLE_Z + 0.04), mat("chrome", 0.3, 0, 0.8), "fg_table", bevel=0)
	piv["stack_top"] = (plx, ty - 0.05, TABLE_Z + 0.33)
	piv["table"] = (tx, STAGE_Y, TABLE_Z)

	# --- BULK protein boxes stacked in front of the walking line: Hush's hiding place ---
	bx, by = X_BOXES, 0.6
	rnd = random.Random(7)
	for i, (dx, z, w, h, r) in enumerate(((-0.05, 0.0, 1.35, 1.05, 0), (0.08, 1.05, 1.15, 0.95, 3), (-0.08, 2.0, 1.0, 0.85, -4))):
		b = box(f"box{i}", (w, 0.9, h), (bx + dx, by, z + h / 2), mat("box", 0.85), "fg_boxes", bevel=0.03, rot=(0, r, 0))
		box(f"tape{i}", (w + 0.01, 0.92, 0.1), (bx + dx, by, z + h - 0.05), mat("tape", 0.6), "fg_boxes", bevel=0.01, rot=(0, r, 0))
		text(f"bulk{i}", ("BULK", "WHEY", "BULK")[i], 0.28, (bx + dx, by - 0.47, z + h / 2 - 0.05), "fg_boxes", "box_dk", rot=(90, -r, 0))
		_ = (b, rnd)
	text("bulk_kg", "25 kg", 0.14, (bx - 0.05, by - 0.47, 0.25), "fg_boxes", "ink")
	piv["boxes"] = (bx, STAGE_Y, 0)

	# --- pancake: the one Gus flips (starts in the pan on the stove) ---
	pz = 1.64
	pan_c = (X_STOVE + 0.38, WALL_Y - 0.75, pz)
	cyl("pancake", 0.34, 0.07, pan_c, mat("pancake", 0.6), "prop_pancake", seg=28)
	cyl("pancake_top", 0.3, 0.02, (pan_c[0], pan_c[1], pz + 0.07), mat("pancake_dk", 0.7), "prop_pancake", seg=28)
	piv["pancake"] = pan_c

	# --- two slices of toast, down in the toaster slots (shown only when they launch) ---
	for k, (name, dy) in enumerate((("prop_toast", -0.15), ("prop_toast2", 0.15))):
		c = (X_TOAST + (k - 0.5) * 0.12, WALL_Y - 0.6 + dy - 0.35, 2.3)
		box(f"{name}_slice", (0.46, 0.06, 0.48), c, mat("toast", 0.8), name, bevel=0.06)
		box(f"{name}_crust", (0.5, 0.05, 0.08), (c[0], c[1] - 0.01, c[2] + 0.24), mat("toast_crust", 0.8), name, bevel=0.03)
		piv[name[5:]] = c

	# --- the frying pan, hanging from its hook on the rail (handle up) ---
	hk = Vector((-6.75 + 2.7 / 2 + 0.3 + 0.35, WALL_Y - 0.4, RAIL_Z))
	cyl("pan_handle", 0.045, 0.75, hk + Vector((0, 0, -0.75)), mat("black", 0.4), "prop_pan", seg=10)
	torus("pan_ring", 0.07, 0.02, hk + Vector((0, 0, 0.0)), mat("chrome", 0.3, 0, 0.8), "prop_pan", rot=(90, 0, 0), seg=12, rseg=6)
	cyl("pan_body", 0.5, 0.12, hk + Vector((0, 0.06, -1.2)), mat("copper", 0.3, 0, 0.6), "prop_pan", rot=(90, 0, 0), r2=0.44, seg=32)
	cyl("pan_base", 0.4, 0.03, hk + Vector((0, -0.07, -1.2)), mat("copper_dk", 0.35, 0, 0.6), "prop_pan", rot=(90, 0, 0), seg=28)
	piv["pan"] = tuple(hk)
	piv["pan_c"] = tuple(hk + Vector((0, 0, -1.2)))

	# Hush's beret stamp (the armed-prank mark), same as Act I
	sph("stamp_b", 0.28, (0, 0, 0), mat("velvet", 0.6), "icon_stamp", scale=(1.2, 1.0, 0.35), rot=(0, -12, 0))
	sph("stamp_s", 0.05, (0.02, 0, 0.1), mat("velvet", 0.6), "icon_stamp")
	return piv


# ---------------------------------------------------------------------------------------------
def build_seqs(piv: dict) -> dict:
	seqs: dict = {}
	bpy.context.view_layer.update()

	# --- the back door swings open on its stage-left hinge ---
	dw, dh = 1.6, 4.3
	hinge = group("bdoor_hinge", "seq_backdoor", (X_DOOR - dw / 2, WALL_Y - 0.1, 0))
	bpy.context.view_layer.update()
	parts = [box("bdoor_panel", (dw, 0.12, dh), (X_DOOR, WALL_Y - 0.1, dh / 2), mat("mint_dk", 0.7), "seq_backdoor", bevel=0.03)]
	parts.append(box("bdoor_glass", (0.9, 0.05, 1.0), (X_DOOR, WALL_Y - 0.18, 3.2), mat("sky2", 0.2, 0.5), "seq_backdoor", bevel=0.03))
	parts.append(box("bdoor_low", (1.1, 0.05, 1.5), (X_DOOR, WALL_Y - 0.18, 1.1), mat("fridge_dk", 0.7), "seq_backdoor", bevel=0.03))
	parts.append(box("bdoor_flap", (0.5, 0.05, 0.4), (X_DOOR, WALL_Y - 0.21, 0.4), mat("cobalt_dk", 0.6), "seq_backdoor", bevel=0.03))
	parts.append(sph("bdoor_knob", 0.08, (X_DOOR + 0.6, WALL_Y - 0.24, 2.0), mat("brass", 0.3, 0, 0.8), "seq_backdoor"))
	bpy.context.view_layer.update()
	for o in parts:
		child(o, hinge)
	angles = [0, -14, -30, -46, -62, -78]
	seqs["backdoor"] = (len(angles), lambda k: setattr(hinge, "rotation_euler", Euler((0, 0, math.radians(angles[k])))))

	# --- the fridge door: swings toward the audience on its stage-right hinge ---
	fx, fw, fh = X_FRIDGE, 1.5, 3.7
	fhinge = group("fdoor_hinge", "seq_fridge", (fx + fw / 2, WALL_Y - 1.12, 0))
	bpy.context.view_layer.update()
	en = mat_enamel("fridge_dk", "fridge", "fridge_hi", "enamel_door")
	fp = [box("fdoor", (fw, 0.16, fh - 0.15), (fx, WALL_Y - 1.18, fh / 2), en, "seq_fridge", bevel=0.2),
		  box("fdoor_split", (fw - 0.3, 0.03, 0.035), (fx, WALL_Y - 1.265, 2.72), mat("fridge_dk", 0.4), "seq_fridge", bevel=0),
		  box("fdoor_kick", (fw - 0.2, 0.03, 0.1), (fx, WALL_Y - 1.265, 0.42), mat("chrome", 0.2, 0, 0.9), "seq_fridge", bevel=0.01),
		  box("fdoor_handle", (0.1, 0.12, 1.1), (fx - 0.55, WALL_Y - 1.31, 2.1), mat("chrome", 0.2, 0, 0.9), "seq_fridge", bevel=0.04),
		  box("fdoor_handle2", (0.1, 0.12, 0.5), (fx - 0.55, WALL_Y - 1.31, 3.05), mat("chrome", 0.2, 0, 0.9), "seq_fridge", bevel=0.04),
		  box("fdoor_badge", (0.56, 0.03, 0.14), (fx, WALL_Y - 1.27, 3.38), mat("chrome", 0.2, 0, 0.9), "seq_fridge", bevel=0.03),
		  text("fdoor_badge_t", "FROSTEE", 0.085, (fx, WALL_Y - 1.29, 3.38), "seq_fridge", "cobalt_dk"),
		  box("fdoor_note", (0.5, 0.02, 0.38), (fx + 0.1, WALL_Y - 1.27, 2.2), mat("paper_w", 0.9), "seq_fridge", bevel=0, rot=(0, 4, 0))]
	fp.append(text("fdoor_note_t", "EGGS:", 0.1, (fx + 0.1, WALL_Y - 1.29, 2.3), "seq_fridge", "ink"))
	fp.append(text("fdoor_note_t2", "MINE", 0.13, (fx + 0.1, WALL_Y - 1.29, 2.15), "seq_fridge", "tin_lbl1"))
	for i, (x, z, c) in enumerate(((-0.35, 2.85, "tin_lbl1"), (0.4, 2.95, "tin_lbl3"), (-0.2, 1.6, "cobalt"), (0.35, 1.3, "lawn"))):
		fp.append(sph(f"magnet{i}", 0.08, (fx + x, WALL_Y - 1.28, z), mat(c, 0.4), "seq_fridge", scale=(1, 0.4, 1)))
	bpy.context.view_layer.update()
	for o in fp:
		child(o, fhinge)
	fang = [0, -22, -48, -74, -96, -112]
	seqs["fridge"] = (len(fang), lambda k: setattr(fhinge, "rotation_euler", Euler((0, 0, math.radians(-fang[k])))))

	# --- the kitchen chair: the legs splay, the seat drops, the back falls away ---
	cx, cy = X_CHAIR, 1.55
	seat_z = 0.95
	chair = group("chair", "seq_chair", (cx, cy, 0))
	legs = []
	for i, (lx, ly) in enumerate(((-0.4, -0.35), (0.4, -0.35), (-0.4, 0.35), (0.4, 0.35))):
		g = group(f"leg{i}", "seq_chair", (cx + lx, cy + ly, seat_z))
		bpy.context.view_layer.update()
		leg = cyl(f"chair_leg{i}", 0.06, seat_z, (cx + lx, cy + ly, 0.0), mat("wood", 0.6), "seq_chair", r2=0.05, seg=10)
		bpy.context.view_layer.update()
		child(leg, g)
		legs.append((g, lx))
	seat = group("seat", "seq_chair", (cx, cy, seat_z))
	bpy.context.view_layer.update()
	sp = [box("chair_seat", (1.0, 0.95, 0.12), (cx, cy, seat_z + 0.06), mat("wood_lt", 0.6), "seq_chair", bevel=0.04),
		  box("chair_cushion", (0.85, 0.8, 0.1), (cx, cy, seat_z + 0.16), mat("cloth_chk", 0.9), "seq_chair", bevel=0.04)]
	bpy.context.view_layer.update()
	for o in sp:
		child(o, seat)
	back = group("back", "seq_chair", (cx + 0.45, cy, seat_z + 0.1))
	bpy.context.view_layer.update()
	bp = []
	for side in (-1, 1):
		bp.append(box(f"chair_post{side}", (0.09, 0.09, 1.25), (cx + 0.45, cy + side * 0.38, seat_z + 0.7), mat("wood", 0.6), "seq_chair", bevel=0.02))
	for z in (1.0, 1.25):
		bp.append(box(f"chair_rail{z}", (0.06, 0.8, 0.09), (cx + 0.45, cy, seat_z + z * 0.9), mat("wood", 0.6), "seq_chair", bevel=0.02))
	bp.append(box("chair_top", (0.12, 0.92, 0.18), (cx + 0.45, cy, seat_z + 1.32), mat("wood_lt", 0.6), "seq_chair", bevel=0.04))
	bpy.context.view_layer.update()
	for o in bp:
		child(o, back)
	_ = chair

	def chair_frame(k: int) -> None:
		s_ = clamp01(k / 4.0)          # 0..4: the collapse; 5..6: the back settles
		e = s_ * s_
		for g, lx in legs:
			g.rotation_euler = Euler((0, math.radians((1 if lx > 0 else -1) * 85 * e), 0))
			g.location.z = seat_z * (1 - e) + 0.06 * e
			g.location.x = cx + lx * (1 + 1.6 * e)
		seat.location.z = seat_z * (1 - e) + 0.08 * e
		seat.rotation_euler = Euler((0, math.radians(-8 * math.sin(s_ * math.pi)), 0))
		b = clamp01((k - 1) / 5.0)
		back.location.z = (seat_z + 0.1) * (1 - e) + 0.1 * e
		back.rotation_euler = Euler((0, math.radians(86 * b * b + (6 * math.sin(b * math.pi) if k == 6 else 0)), 0))
	seqs["chair"] = (7, chair_frame)
	piv["chair"] = (cx, cy, 0)

	# --- the pantry: both doors burst open and a whole shelf of tins avalanches out onto Gus ---
	px_, pw = X_PANTRY, 1.9
	lh = group("pdoor_l", "seq_pantry", (px_ - pw / 2, WALL_Y - 0.98, 0))
	rh = group("pdoor_r", "seq_pantry", (px_ + pw / 2, WALL_Y - 0.98, 0))
	bpy.context.view_layer.update()
	for side, h in ((-1, lh), (1, rh)):
		dx_ = px_ + side * pw / 4
		ps = [box(f"pdoor{side}", (pw / 2 - 0.03, 0.08, 4.75), (dx_, WALL_Y - 1.0, 2.45), mat("cupboard", 0.6), "seq_pantry", bevel=0.03),
			  box(f"pdoor_in{side}", (pw / 2 - 0.35, 0.03, 1.7), (dx_, WALL_Y - 1.05, 3.4), mat("cupboard_dk", 0.6), "seq_pantry", bevel=0.02),
			  box(f"pdoor_in2{side}", (pw / 2 - 0.35, 0.03, 1.7), (dx_, WALL_Y - 1.05, 1.3), mat("cupboard_dk", 0.6), "seq_pantry", bevel=0.02),
			  sph(f"pdoor_knob{side}", 0.07, (px_ - side * 0.12, WALL_Y - 1.1, 2.4), mat("brass", 0.3, 0, 0.8), "seq_pantry")]
		bpy.context.view_layer.update()
		for o in ps:
			child(o, h)
	# tins: start on the shelves, fly out in arcs, land in a heap over the spot Gus falls on
	rnd = random.Random(12)
	labels = ("tin_lbl1", "tin_lbl2", "tin_lbl3")
	tins = []
	land_x0, land_x1 = 1.35, 4.1         # Gus lies from ~1.3 (feet) to ~3.9; his head near 2.45
	for i in range(16):
		shelf = (1.05, 2.15, 3.25, 4.25)[i % 4]
		a = Vector((px_ - 0.6 + (i // 4) * 0.4, WALL_Y - 0.6, shelf + 0.21))
		col = (i * 7) % 3
		# the heap: two layers over his body, a few rolling off the sides
		lay = 0 if i < 9 else 1
		x = land_x0 + (land_x1 - land_x0) * ((i * 0.37 + lay * 0.19) % 1.0)
		b = Vector((x, STAGE_Y - 0.2 + rnd.uniform(-0.25, 0.25), 0.2 + lay * 0.45 + (0.45 if 1.9 < x < 3.6 else 0.0)))
		g = group(f"tin{i}", "seq_pantry", a)
		bpy.context.view_layer.update()
		parts = [cyl(f"tin{i}_can", 0.2, 0.42, a + Vector((0, 0, -0.21)), mat("tin", 0.25, 0, 0.8), "seq_pantry", seg=16),
				 cyl(f"tin{i}_lbl", 0.205, 0.26, a + Vector((0, 0, -0.13)), mat(labels[col], 0.6), "seq_pantry", seg=16)]
		bpy.context.view_layer.update()
		for o in parts:
			child(o, g)
		tins.append((g, a, b, 2 + (i * 5) % 7 * 0.6 + lay * 2.0, rnd.uniform(-1, 1)))
	# the last word: a giant BULK tub
	ta = Vector((px_, WALL_Y - 0.55, 3.75))
	tub = group("tub", "seq_pantry", ta)
	bpy.context.view_layer.update()
	tp = [cyl("tub_body", 0.36, 0.75, ta + Vector((0, 0, -0.42)), mat("black", 0.4), "seq_pantry", seg=24),
		  cyl("tub_lid", 0.39, 0.12, ta + Vector((0, 0, 0.33)), mat("tin_lbl1", 0.4), "seq_pantry", seg=24),
		  text("tub_t", "BULK", 0.2, ta + Vector((0, -0.38, -0.05)), "seq_pantry", "tin_lbl3")]
	bpy.context.view_layer.update()
	for o in tp:
		child(o, tub)
	tub_b = Vector((2.45, STAGE_Y - 0.3, 1.45))        # the last word lands on his head
	N = 18

	def pantry_frame(k: int) -> None:
		d = clamp01(k / 2.0)
		lh.rotation_euler = Euler((0, 0, math.radians(-118 * (1 - (1 - d) ** 2))))
		rh.rotation_euler = Euler((0, 0, math.radians(118 * (1 - (1 - d) ** 2))))
		for g, a, b, delay, spin in tins:
			s_ = clamp01((k - delay) / 4.5)
			p = a.lerp(b, s_)
			p.z = a.z + (b.z - a.z) * s_ * s_ + 1.1 * 4 * s_ * (1 - s_)
			g.location = p
			g.rotation_euler = Euler((math.radians(70 * spin * s_), math.radians(300 * s_ * (1 if spin > 0 else -1) + (90 if s_ >= 1 and spin > 0.3 else 0)), 0))
		s_ = clamp01((k - 11) / 5.0)
		p = ta.lerp(tub_b, s_)
		p.z = ta.z + (tub_b.z - ta.z) * s_ * s_ + 1.4 * 4 * s_ * (1 - s_)
		tub.location = p
		tub.rotation_euler = Euler((0, math.radians(-360 * s_ + (8 if k == N - 1 else 0)), 0))
	seqs["pantry"] = (N, pantry_frame)
	piv["heap"] = tuple(tub_b + Vector((0, 0, 0.45)))

	# --- the house curtains (as Act I) ---
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


def build_shaft():
	"""Morning light through the window over the table: an emissive wedge on its own layer."""
	wx, wz, ww, wh = WIN
	K.build_shaft(win=(wx, wz, ww, wh), dx=0.7, y1=1.2)


def setup_lights(scene, cam) -> None:
	K.setup_render(scene, cam)
	for o in list(K.coll("lights").objects):
		bpy.data.objects.remove(o, do_unlink=True)
	cyc = K.ENGINE["name"] == "cycles"
	lights = K.coll("lights")
	key = bpy.data.lights.new("key", "SUN")
	key.energy = 3.0 if cyc else 2.6
	key.angle = math.radians(6)
	key.color = (1.0, 0.96, 0.88)
	ko = bpy.data.objects.new("key", key)
	ko.rotation_euler = Euler((math.radians(50), 0, math.radians(-25)))
	lights.objects.link(ko)
	rigs = [("window", (WIN[0], 3.2, WIN[1]), 260 if cyc else 420, (0.85, 0.95, 1.0), 1.4),
			("pendant", (X_TABLE, 2.2, 5.0), 120 if cyc else 200, (1.0, 0.85, 0.6), 0.3),
			("hood", (X_STOVE, 3.2, 3.4), 60 if cyc else 90, (1.0, 0.85, 0.6), 0.2),
			("fridge", (X_FRIDGE, 2.4, 2.0), 40 if cyc else 60, (0.85, 0.95, 1.0), 0.4),
			("foot", (0.0, -2.5, 2.2), 380 if cyc else 600, (1.0, 0.84, 0.6), 5.0)]
	for name, loc, energy, colr, rad in rigs:
		ld = bpy.data.lights.new(name, "POINT")
		ld.energy = energy
		ld.color = colr
		ld.shadow_soft_size = rad
		lo = bpy.data.objects.new(name, ld)
		lo.location = loc
		lights.objects.link(lo)


# ---------------------------------------------------------------------------------------------
def main() -> int:
	def build():
		marks = build_room()
		piv = build_props()
		seqs = build_seqs(piv)
		build_shaft()
		return marks, piv, seqs
	return stagekit.run(build, setup_lights, os.path.join(HERE, "out_act2"))


if __name__ == "__main__":
	raise SystemExit(main())
