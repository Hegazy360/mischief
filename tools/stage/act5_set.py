"""act5_set — Gus Thudd's bedroom at night, modelled from scratch in Blender (Act V · "Lights Out").

    python3 tools/stage/build.py --act act5 [--engine eevee]

Same camera, scale and theatre as the other Acts (act1_set primitives, stagekit render loop).
Stage left to right (x in units, px = 1200 + 128 x):
  -6.2  the light switch      "Lights out." (the game's "dark" verb)
  -4.6  wardrobe              a long mirror on one door: he admires himself in it
  -2.9  laundry basket + trophy shelf
  -2.0  coat stand            FREEZE: Hush makes a second one; he pats it ("…Sturdy.")
   0.6  the spring bed (seq)  RIG 2: the spring wound tight; it catapults him through the window
   2.4  bedside table         RIG 1: the alarm clock (prop) moved into his pillow, set to NOW
   4.8  the window            moon outside; the glass (prop) gets a Gus-shaped hole; a moon shaft
                              (fx_shaft, drawn after the darkness) pools on the floor by the chair
   6.4  armchair (fg)         Hush hides behind it (and peeks out)
   7.6  bedroom door (seq)    Hush's way in

Quality notes: Gus stands 3 units tall, so the bed is sized to him (mattress at 1.0, 3.6 long);
the paper carries a motif and a painted dado so the dark pass still has something to read.
"""
from __future__ import annotations

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bmesh  # type: ignore  # noqa: E402
import bpy  # type: ignore  # noqa: E402
from mathutils import Euler, Vector  # type: ignore  # noqa: E402

import act1_set as K  # noqa: E402
import act2_set as K2  # noqa: E402
import stagekit  # noqa: E402

box, cyl, sph, prism, mat, coll, put, torus = K.box, K.cyl, K.sph, K.prism, K.mat, K.coll, K.put, K.torus
group, child, text = K.group, K.child, K2.text
WALL_Y, STAGE_Y = K.WALL_Y, K.STAGE_Y

K.C.update({
	"night_wall": "#8A9AD0", "night_wall2": "#7D8EC6", "night_dot": "#A7B4E0", "night_lo": "#5E6FAE", "night_lo2": "#53639F",
	"carpet": "#6E4C7E", "carpet2": "#5E3F6B", "rug_a": "#8E3A5A", "rug_b": "#E0B04A", "rug_c": "#5A2340",
	"wardrobe": "#8A5A3C", "wardrobe_dk": "#6B4329", "wardrobe_lt": "#A9754F", "duvet": "#E8B04A", "duvet2": "#D99A33",
	"pillow": "#F7F1E6", "sheet": "#FFFFFF", "blanket": "#3F7F7A", "bedwood": "#5C3A28", "bedwood_lt": "#7A5038",
	"drape": "#C2185B", "drape_dk": "#8E1043", "moon": "#FFF6CF", "night": "#1C2350",
	"star": "#FFF3B0", "chair": "#3F7F7A", "chair_dk": "#2F625E", "chair_lt": "#4E948E", "lampshade": "#FFD98A",
	"clock": "#D7263D", "wicker": "#C9A26B", "wicker_dk": "#A8814C", "slipper": "#7A3E8E", "rosette": "#2F8A3E",
	"book1": "#B33A3A", "book2": "#2F6DB3", "book3": "#3E8E4F", "pennant": "#E23B4E", "glass_w": "#CFE8FF",
})

X_SWITCH, X_WARDROBE, X_STAND, X_BED, X_TABLE, X_WINDOW, X_CHAIR, X_DOOR = -6.2, -4.6, -2.0, 0.6, 2.4, 4.8, 6.4, 7.6
X_BASKET = -2.95
BED_Z = 1.0                     # mattress top (Gus is 3 units tall: a bed up to his knee)
BED_LEN, BED_W = 3.6, 1.5
WIN = (X_WINDOW, 2.85, 1.9, 2.3)  # x, z, w, h
TABLE_Z = 1.1


# --- materials --------------------------------------------------------------------------------
def mat_carpet():
	"""Fitted carpet: a soft pile (fine noise) over a gentle mottle so it is not one flat purple."""
	m = bpy.data.materials.new("carpet")
	m.use_nodes = True
	nt = m.node_tree
	bs = nt.nodes["Principled BSDF"]
	bs.inputs["Roughness"].default_value = 1.0
	try:
		bs.inputs["Sheen Weight"].default_value = 0.4
	except KeyError:
		pass
	tc = nt.nodes.new("ShaderNodeTexCoord")
	n1 = nt.nodes.new("ShaderNodeTexNoise")
	n1.inputs["Scale"].default_value = 2.0
	n1.inputs["Detail"].default_value = 3.0
	nt.links.new(tc.outputs["Object"], n1.inputs["Vector"])
	mix = nt.nodes.new("ShaderNodeMix")
	mix.data_type = "RGBA"
	nt.links.new(n1.outputs["Fac"], mix.inputs[0])
	mix.inputs[6].default_value = K.lin(K.C["carpet2"])
	mix.inputs[7].default_value = K.lin(K.C["carpet"])
	n2 = nt.nodes.new("ShaderNodeTexNoise")
	n2.inputs["Scale"].default_value = 60.0
	n2.inputs["Detail"].default_value = 2.0
	nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
	ov = nt.nodes.new("ShaderNodeMix")
	ov.data_type = "RGBA"
	ov.blend_type = "OVERLAY"
	ov.inputs[0].default_value = 0.22
	nt.links.new(mix.outputs[2], ov.inputs[6])
	nt.links.new(n2.outputs["Fac"], ov.inputs[7])
	nt.links.new(ov.outputs[2], bs.inputs["Base Color"])
	bp = nt.nodes.new("ShaderNodeBump")
	bp.inputs["Strength"].default_value = 0.25
	bp.inputs["Distance"].default_value = 0.01
	nt.links.new(n2.outputs["Fac"], bp.inputs["Height"])
	nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])
	return m


def mat_glass(name: str):
	"""Window glass: faintly blue and mostly see-through (the night sky shows behind it)."""
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = m.node_tree.nodes["Principled BSDF"]
	b.inputs["Base Color"].default_value = K.lin("#BFD9FF")
	b.inputs["Roughness"].default_value = 0.05
	b.inputs["Alpha"].default_value = 0.34
	try:
		m.blend_method = "BLEND"
	except Exception:
		pass
	return m


def bevel(o, w: float, seg: int = 3):
	md = o.modifiers.new("bevel", "BEVEL")
	md.width = w
	md.segments = seg
	md.limit_method = "ANGLE"
	return o


def rosette(name: str, x: float, z: float, key: str, where: str = "bg") -> None:
	prism(f"{name}_o", K.star_pts(14, 0.2, 0.15, 0.0), 0.02, (x, WALL_Y - 0.05, z), mat(key, 0.8), where)
	cyl(f"{name}_c", 0.09, 0.03, (x, WALL_Y - 0.08, z), mat("gold", 0.3, 0, 0.7), where, rot=(90, 0, 0), seg=16)
	for s in (-1, 1):
		box(f"{name}_r{s}", (0.07, 0.02, 0.3), (x + s * 0.06, WALL_Y - 0.05, z - 0.3), mat(key, 0.8), where, bevel=0, rot=(0, s * 10, 0))


def build_room() -> dict:
	marks: dict = {}
	# --- walls: striped paper with a motif above, painted panelling below a dado rail ---
	box("wall", (19.6, 0.3, 7.6), (0, WALL_Y + 0.15, 3.8), K.mat_wallpaper("night_wall", "night_wall2", "night_dot", "nightpaper", 1.4), bevel=0)
	box("wall_lo", (19.6, 0.06, 1.5), (0, WALL_Y - 0.03, 0.75), mat("night_lo", 0.7), bevel=0)
	for i in range(17):
		box(f"wpanel{i}", (0.85, 0.05, 1.0), (-9.3 + i * 1.16, WALL_Y - 0.08, 0.78), mat("night_lo2", 0.7), bevel=0.02)
	box("dado", (19.6, 0.16, 0.1), (0, WALL_Y - 0.1, 1.55), mat("trim", 0.6), bevel=0.03)
	box("picture_rail", (19.6, 0.12, 0.07), (0, WALL_Y - 0.06, 5.9), mat("trim", 0.6), bevel=0.02)
	box("cornice", (19.6, 0.36, 0.28), (0, WALL_Y - 0.1, 7.15), mat("trim", 0.6), bevel=0.06)
	box("skirting", (19.6, 0.22, 0.22), (0, WALL_Y - 0.13, 0.11), mat("trim", 0.6), bevel=0.03)
	# --- floor: carpet + an oval rug under the bed ---
	box("floor", (19.6, 6.0, 0.2), (0, 1.0, -0.1), mat_carpet(), bevel=0)
	for name, r, h, key in (("rug", 2.6, 0.03, "rug_b"), ("rug_in", 2.42, 0.04, "rug_a"), ("rug_core", 1.5, 0.05, "rug_c"), ("rug_dot", 0.5, 0.06, "rug_b")):
		cyl(name, r, h, (X_BED, 1.5, 0.0), mat(key, 0.95), seg=64)
		bpy.data.objects[name].scale = (1.25, 0.42, 1.0)
	box("apron", (19.6, 0.4, 3.0), (0, -1.7, -1.5), mat("stage", 0.6), bevel=0)
	box("apron_lip", (19.6, 0.5, 0.12), (0, -1.55, -0.06), mat("gold", 0.35, 0, 0.6), bevel=0.04)
	for i in range(11):
		x = -7.5 + i * 1.5
		sph(f"foot{i}", 0.13, (x, -1.82, -0.18), mat("bulb", 0.3, 4.0), scale=(1.3, 1, 0.8))
		box(f"foothood{i}", (0.42, 0.18, 0.12), (x, -1.9, -0.06), mat("gold_dk", 0.4, 0, 0.6), bevel=0.03)
	# --- the ceiling pendant (lit; the dark pass puts it out) ---
	px_ = -0.6
	cyl("pend_cord", 0.015, 1.4, (px_, 2.4, 5.75), mat("ink", 0.6), seg=6)
	cyl("pend_shade", 0.62, 0.55, (px_, 2.4, 5.2), mat("lampshade", 0.8, 1.2), r2=0.4, seg=32)
	cyl("pend_rim", 0.63, 0.05, (px_, 2.4, 5.18), mat("gold", 0.35, 0, 0.6), seg=32)
	sph("pend_bulb", 0.14, (px_, 2.4, 5.3), mat("bulb", 0.3, 5.0))
	# light switch
	box("switch", (0.24, 0.06, 0.36), (X_SWITCH, WALL_Y - 0.05, 2.3), mat("white", 0.5), bevel=0.02)
	box("switch_t", (0.07, 0.05, 0.14), (X_SWITCH, WALL_Y - 0.1, 2.33), mat("trim", 0.5), bevel=0.01)
	marks["switch"] = (X_SWITCH + 0.5, STAGE_Y, 0)
	# --- wardrobe: panelled doors, a long mirror on one, crown + feet, a hat box on top ---
	wx = X_WARDROBE
	box("wardrobe", (2.0, 1.0, 4.4), (wx, WALL_Y - 0.55, 2.2), mat("wardrobe", 0.6), bevel=0.05)
	for side in (-1, 1):
		box(f"ward_door{side}", (0.92, 0.05, 3.8), (wx + side * 0.48, WALL_Y - 1.07, 2.25), mat("wardrobe_dk", 0.6), bevel=0.03)
		sph(f"ward_knob{side}", 0.06, (wx + side * 0.12, WALL_Y - 1.12, 2.2), mat("brass", 0.3, 0, 0.8))
		cyl(f"ward_foot{side}", 0.08, 0.12, (wx + side * 0.85, WALL_Y - 0.95, 0.0), mat("wardrobe_dk", 0.6), seg=10)
	box("ward_panel_lo", (0.7, 0.03, 1.2), (wx - 0.48, WALL_Y - 1.1, 1.1), mat("wardrobe_lt", 0.6), bevel=0.03)
	box("ward_panel_hi", (0.7, 0.03, 1.9), (wx - 0.48, WALL_Y - 1.1, 3.0), mat("wardrobe_lt", 0.6), bevel=0.03)
	box("ward_mirror", (0.62, 0.02, 3.1), (wx + 0.48, WALL_Y - 1.11, 2.2), mat("#9DBAD0", 0.1, 0.15, 0.3), bevel=0.01)
	sph("ward_glint", 0.16, (wx + 0.3, WALL_Y - 1.13, 3.2), mat("white", 0.5, 0.8), scale=(0.35, 0.1, 1.4), rot=(0, -25, 0))
	box("ward_crown", (2.2, 1.1, 0.2), (wx, WALL_Y - 0.55, 4.45), mat("wardrobe_dk", 0.6), bevel=0.04)
	cyl("hatbox", 0.38, 0.3, (wx - 0.4, WALL_Y - 0.5, 4.55), K.mat_bands("rug_a", "rug_b", 3.0, 0, "hatbox"), seg=28)
	cyl("hatbox_lid", 0.4, 0.05, (wx - 0.4, WALL_Y - 0.5, 4.85), mat("rug_c", 0.7), seg=28)
	sph("ward_hook", 0.07, (wx + 0.55, WALL_Y - 1.12, 3.55), mat("brass", 0.3, 0, 0.8))
	marks["wardrobe"] = (wx + 0.7, STAGE_Y, 0)
	# --- laundry basket and a trophy shelf between the wardrobe and the stand ---
	bxk = X_BASKET
	cyl("basket", 0.42, 0.9, (bxk, 3.1, 0.0), K.mat_bands("wicker", "wicker_dk", 8.0, 2, "wicker"), seg=28)
	cyl("basket_lid", 0.46, 0.08, (bxk, 3.1, 0.9), mat("wicker_dk", 0.8), seg=28)
	box("sock", (0.2, 0.1, 0.3), (bxk + 0.3, 2.95, 0.85), mat("tracksuit", 0.9), bevel=0.05, rot=(0, 0, 30))
	box("tshelf", (1.3, 0.3, 0.07), (bxk, WALL_Y - 0.17, 3.7), mat("wood", 0.6), bevel=0.02)
	for s in (-1, 1):
		box(f"tshelf_br{s}", (0.05, 0.26, 0.26), (bxk + s * 0.5, WALL_Y - 0.15, 3.53), mat("wood_dk", 0.6), bevel=0.01)
	for i, (dx, h) in enumerate(((-0.4, 0.4), (0.0, 0.52), (0.4, 0.36))):
		cyl(f"tcup{i}b", 0.1, 0.06, (bxk + dx, WALL_Y - 0.2, 3.74), mat("wood_dk", 0.5), seg=14)
		cyl(f"tcup{i}", 0.05, h, (bxk + dx, WALL_Y - 0.2, 3.8), mat("gold", 0.3, 0, 0.8), r2=0.15, seg=18)
	# --- coat stand (the real one): hats and a scarf ---
	cx = X_STAND
	cyl("stand_base", 0.34, 0.06, (cx, 2.0, 0), mat("bedwood", 0.6), seg=20)
	for a in range(3):
		box(f"stand_foot{a}", (0.1, 0.5, 0.05), (cx, 2.0, 0.03), mat("bedwood", 0.6), bevel=0.01, rot=(0, 0, a * 60))
	cyl("stand_pole", 0.05, 3.3, (cx, 2.0, 0.06), mat("bedwood", 0.6), seg=10)
	for a in (-45, 45, 180):
		cyl(f"stand_hook{a}", 0.025, 0.4, (cx, 2.0, 3.0), mat("bedwood", 0.6), rot=(0, 50 if a > 0 else -50, 0), seg=6)
	cyl("stand_hat", 0.28, 0.06, (cx + 0.15, 2.0, 3.25), mat("black", 0.6), seg=18)
	cyl("stand_hat_top", 0.18, 0.3, (cx + 0.15, 2.0, 3.31), mat("black", 0.6), seg=18)
	box("stand_band", (0.38, 0.38, 0.06), (cx + 0.15, 2.0, 3.36), mat("rug_a", 0.6), bevel=0.02)
	box("scarf", (0.16, 0.08, 1.5), (cx - 0.3, 1.95, 2.0), K.mat_bands("rosette", "chalk" if "chalk" in K.C else "cream", 4.0, 2, "scarf"), bevel=0.03, rot=(0, 3, 0))
	marks["stand"] = (cx, STAGE_Y, 0)
	# --- bedside table + lamp, books, a glass of water ---
	tx = X_TABLE
	box("btable", (0.95, 0.7, TABLE_Z), (tx, 2.6, TABLE_Z / 2), mat("bedwood", 0.6), bevel=0.04)
	box("btable_top", (1.02, 0.76, 0.06), (tx, 2.6, TABLE_Z), mat("bedwood_lt", 0.5), bevel=0.02)
	box("btable_drawer", (0.72, 0.04, 0.26), (tx, 2.23, 0.72), mat("wardrobe", 0.6), bevel=0.02)
	sph("btable_knob", 0.04, (tx, 2.2, 0.72), mat("brass", 0.3, 0, 0.8))
	cyl("lamp_base", 0.16, 0.5, (tx + 0.25, 2.7, TABLE_Z + 0.06), mat("brass", 0.3, 0, 0.8), r2=0.06, seg=16)
	cyl("lamp_shade", 0.34, 0.38, (tx + 0.25, 2.7, TABLE_Z + 0.5), mat("lampshade", 0.7, 0.9), r2=0.22, seg=24)
	for i, key in enumerate(("book1", "book2")):
		box(f"book{i}", (0.34, 0.26, 0.05), (tx - 0.28, 2.55, TABLE_Z + 0.06 + i * 0.05), mat(key, 0.7), bevel=0.01, rot=(0, 0, i * 12))
	cyl("glass_w", 0.06, 0.18, (tx - 0.3, 2.35, TABLE_Z + 0.16), mat("glass_w", 0.1, 0.1), seg=12)
	marks["table"] = (tx, STAGE_Y, 0)
	# --- the window: frame, sill, pelmet, drapes; the sky + moon is its own glowing layer (fx_moon) ---
	wxw, wz, ww, wh = WIN
	fm = mat("cream", 0.6)
	box("win_top", (ww + 0.36, 0.26, 0.18), (wxw, WALL_Y - 0.18, wz + wh / 2 + 0.09), fm)
	box("win_bot", (ww + 0.7, 0.46, 0.16), (wxw, WALL_Y - 0.27, wz - wh / 2 - 0.08), fm)
	box("win_l", (0.18, 0.26, wh + 0.2), (wxw - ww / 2 - 0.09, WALL_Y - 0.18, wz), fm)
	box("win_r", (0.18, 0.26, wh + 0.2), (wxw + ww / 2 + 0.09, WALL_Y - 0.18, wz), fm)
	for side in (-1, 1):
		for k in range(5):
			cyl(f"drape{side}{k}", 0.13, 3.1, (wxw + side * (ww / 2 + 0.25 + k * 0.12), WALL_Y - 0.42 - (k % 2) * 0.05, wz - 1.65),
				mat("drape_dk" if k % 2 else "drape", 0.9), seg=12)
		box(f"tie{side}", (0.7, 0.2, 0.1), (wxw + side * (ww / 2 + 0.5), WALL_Y - 0.6, wz - 0.5), mat("gold", 0.4, 0, 0.5), bevel=0.03)
	box("pelmet", (ww + 1.8, 0.5, 0.42), (wxw, WALL_Y - 0.4, wz + wh / 2 + 0.4), mat("drape_dk", 0.85), bevel=0.06)
	box("pelmet_trim", (ww + 1.85, 0.52, 0.07), (wxw, WALL_Y - 0.42, wz + wh / 2 + 0.2), mat("gold", 0.4, 0, 0.5), bevel=0.02)
	# a cactus on the sill (he has one in every room)
	cyl("sill_pot", 0.12, 0.16, (wxw - 0.55, WALL_Y - 0.3, wz - wh / 2), mat("pot", 0.8), r2=0.09, seg=14)
	sph("sill_cactus", 0.09, (wxw - 0.55, WALL_Y - 0.3, wz - wh / 2 + 0.28), mat("hedge", 0.9), scale=(1, 1, 1.6))
	marks["window"] = (wxw, STAGE_Y, wz)
	# --- over the bed: the photo, rosettes and a pennant ---
	fx = X_BED + 0.2
	box("photo_f", (1.3, 0.08, 1.0), (fx, WALL_Y - 0.05, 3.9), mat("gold", 0.35, 0, 0.7), bevel=0.04)
	box("photo", (1.1, 0.04, 0.8), (fx, WALL_Y - 0.1, 3.9), mat("night", 0.8), bevel=0)
	sph("photo_gus", 0.24, (fx, WALL_Y - 0.13, 3.92), mat("lawn2", 0.8), scale=(1.4, 0.2, 1.0))
	sph("photo_head", 0.12, (fx, WALL_Y - 0.14, 4.18), mat("skin", 0.8), scale=(1, 0.2, 1.1))
	for s in (-1, 1):
		sph(f"photo_arm{s}", 0.08, (fx + s * 0.38, WALL_Y - 0.14, 4.08), mat("skin", 0.8), scale=(1, 0.2, 1.4), rot=(0, s * -35, 0))
	text("photo_t", "MR. LAWN", 0.13, (fx, WALL_Y - 0.15, 3.6), "bg", "star")
	rosette("ros0", fx - 1.0, 3.9, "rosette")
	rosette("ros1", fx + 1.0, 3.9, "book1")
	prism("pennant", [(-0.5, 0.2), (0.5, 0.2), (0.5, -0.2)], 0.02, (fx + 0.1, WALL_Y - 0.05, 4.95), mat("pennant", 0.8), rot=(90, 0, 0))
	text("pennant_t", "CHAMP", 0.11, (fx + 0.22, WALL_Y - 0.07, 5.05), "bg", "star")
	# slippers by the bed, a dumbbell under it
	for i, dx in enumerate((-0.24, 0.24)):
		sx = X_BED - 1.1 + dx
		box(f"slipper_sole{i}", (0.26, 0.6, 0.06), (sx, 0.75, 0.03), mat("slipper", 0.9), bevel=0.03, rot=(0, 0, dx * 30))
		sph(f"slipper{i}", 0.14, (sx, 0.62, 0.1), mat("slipper", 0.9), scale=(0.9, 1.3, 0.7), rot=(0, 0, dx * 30))
		torus(f"slipper_fur{i}", 0.11, 0.05, (sx, 0.7, 0.14), mat("pillow", 0.95), rot=(0, 0, dx * 30), seg=16, rseg=6)
	cyl("db_bar", 0.03, 0.6, (X_BED - 0.9, 1.25, 0.1), mat("steel", 0.3, 0, 0.8), rot=(0, 90, 0), seg=8)
	for s in (0, 0.5):
		cyl(f"db_hd{s}", 0.1, 0.1, (X_BED - 0.9 + s, 1.25, 0.1), mat("black", 0.5), rot=(0, 90, 0), seg=6)
	# --- door frame (stage right) ---
	dw, dh = 1.6, 4.3
	box("doorway", (dw, 0.1, dh), (X_DOOR, WALL_Y - 0.02, dh / 2), mat("#2A1E2E", 0.9), bevel=0)
	for side in (-1, 1):
		box(f"door_jamb{side}", (0.2, 0.3, dh + 0.1), (X_DOOR + side * (dw / 2 + 0.1), WALL_Y - 0.15, dh / 2), fm)
	box("door_head", (dw + 0.6, 0.34, 0.26), (X_DOOR, WALL_Y - 0.17, dh + 0.13), fm)
	marks["door"] = (X_DOOR - 0.3, STAGE_Y, 0)
	return marks


def build_fx_moon() -> None:
	"""The night sky in the window, a moon and stars: drawn AFTER the darkness, so it stays bright."""
	wxw, wz, ww, wh = WIN
	box("sky", (ww, 0.04, wh), (wxw, WALL_Y - 0.02, wz), mat("night", 0.9, 0.8), "fx_moon", bevel=0)
	sph("moon", 0.34, (wxw + 0.35, WALL_Y - 0.05, wz + 0.55), mat("moon", 0.9, 2.5), "fx_moon", scale=(1, 0.2, 1))
	sph("moon_bite", 0.29, (wxw + 0.5, WALL_Y - 0.07, wz + 0.63), mat("night", 0.9, 0.8), "fx_moon", scale=(1, 0.2, 1))
	for i, (sx, sz) in enumerate(((-0.6, 0.7), (-0.2, 0.3), (0.6, -0.2), (-0.5, -0.5), (0.1, 0.85), (0.7, 0.95), (-0.75, 0.05))):
		sph(f"star{i}", 0.035, (wxw + sx, WALL_Y - 0.05, wz + sz), mat("star", 0.9, 3.0), "fx_moon", scale=(1, 0.2, 1))
	# rooftops across the road
	for i, (sx, h) in enumerate(((-0.7, 0.5), (-0.2, 0.7), (0.4, 0.45), (0.8, 0.6))):
		box(f"roof{i}", (0.5, 0.04, h), (wxw + sx, WALL_Y - 0.04, wz - wh / 2 + h / 2), mat("#121733", 0.9, 0.1), "fx_moon", bevel=0)
	box("win_mv", (0.09, 0.14, wh), (wxw, WALL_Y - 0.15, wz), mat("cream", 0.6), "fx_moon")
	box("win_mh", (ww, 0.14, 0.09), (wxw, WALL_Y - 0.15, wz + 0.2), mat("cream", 0.6), "fx_moon")
	# moonlight pooling on the floor by the chair (the Act's fx_shaft; the game draws it after the dark pass)
	K.build_shaft(win=WIN, dx=0.9, y1=1.2, colour="#B9D4FF", alpha=0.85)


def build_props() -> dict:
	piv: dict = {}
	# the armchair, in front of the walk line: Hush hides behind it
	ax, ay = X_CHAIR, 0.6
	box("chair_seat", (1.7, 1.15, 0.6), (ax, ay, 0.5), mat("chair", 0.9), "fg_chair", bevel=0.15)
	box("chair_back", (1.7, 0.42, 2.6), (ax, ay + 0.45, 1.35), mat("chair", 0.9), "fg_chair", bevel=0.2)
	for r in range(2):
		for c in range(3):
			sph(f"tuft{r}{c}", 0.04, (ax - 0.45 + c * 0.45, ay + 0.23, 1.5 + r * 0.6), mat("chair_dk", 0.9), "fg_chair")
	for side in (-1, 1):
		box(f"chair_arm{side}", (0.42, 1.2, 1.15), (ax + side * 0.85, ay, 0.85), mat("chair_dk", 0.9), "fg_chair", bevel=0.15)
		cyl(f"chair_arm_roll{side}", 0.2, 1.15, (ax + side * 0.85, ay - 0.55, 1.4), mat("chair_lt", 0.9), "fg_chair", rot=(-90, 0, 0), seg=18)
	box("chair_cushion", (1.15, 0.95, 0.28), (ax, ay - 0.05, 0.9), mat("chair_lt", 0.9), "fg_chair", bevel=0.1)
	box("chair_skirt", (1.7, 1.15, 0.22), (ax, ay, 0.11), mat("chair_dk", 0.9), "fg_chair", bevel=0.04)
	box("chair_blanket", (0.7, 0.5, 0.12), (ax + 0.45, ay + 0.45, 2.66), K.mat_bands("rug_b", "rug_a", 3.0, 0, "throw"), "fg_chair", bevel=0.04)
	box("chair_blanket_f", (0.7, 0.08, 0.9), (ax + 0.45, ay + 0.2, 2.2), K.mat_bands("rug_b", "rug_a", 3.0, 2, "throw2"), "fg_chair", bevel=0.03)
	box("chair_mag", (0.5, 0.35, 0.04), (ax - 0.15, ay - 0.1, 1.06), mat("tin_lbl3", 0.6), "fg_chair", bevel=0.01, rot=(0, 0, 14))
	piv["chair"] = (ax, STAGE_Y, 0)
	# the alarm clock on the bedside table (pivot: its middle)
	c = Vector((X_TABLE - 0.15, 2.3, TABLE_Z + 0.26))
	cyl("clock_body", 0.2, 0.12, c, mat("clock", 0.4), "prop_clock", rot=(90, 0, 0), seg=24)
	cyl("clock_face", 0.16, 0.13, c + Vector((0, -0.01, 0)), mat("cream", 0.5), "prop_clock", rot=(90, 0, 0), seg=24)
	for side in (-1, 1):
		sph(f"clock_bell{side}", 0.09, c + Vector((side * 0.14, 0, 0.2)), mat("brass", 0.3, 0, 0.8), "prop_clock")
		cyl(f"clock_leg{side}", 0.02, 0.14, c + Vector((side * 0.12, 0, -0.32)), mat("brass", 0.3, 0, 0.8), "prop_clock", seg=6)
	cyl("clock_hammer", 0.02, 0.12, c + Vector((0, 0, 0.18)), mat("brass", 0.3, 0, 0.8), "prop_clock", seg=6)
	sph("clock_hammer_h", 0.035, c + Vector((0, 0, 0.3)), mat("brass", 0.3, 0, 0.8), "prop_clock")
	box("clock_hand", (0.02, 0.02, 0.12), c + Vector((0.0, -0.08, 0.05)), mat("ink", 0.5), "prop_clock", bevel=0)
	box("clock_hand2", (0.02, 0.02, 0.09), c + Vector((0.03, -0.08, 0.03)), mat("ink", 0.5), "prop_clock", bevel=0, rot=(0, 70, 0))
	piv["clock"] = tuple(c)
	piv["pillow"] = (X_BED + BED_LEN / 2 - 0.45, STAGE_Y + 0.1, BED_Z + 0.15)
	# the window glass: intact, and with a Gus-shaped hole (swapped when he goes through it)
	wxw, wz, ww, wh = WIN
	box("glass", (ww, 0.03, wh), (wxw, WALL_Y - 0.3, wz), mat_glass("glass"), "prop_glass", bevel=0)
	bm = bmesh.new()
	outer = [(-ww / 2, -wh / 2), (ww / 2, -wh / 2), (ww / 2, wh / 2), (-ww / 2, wh / 2)]
	# a cartoon silhouette: spread-eagled body, head, arms out
	hole = [(-0.15, -0.95), (0.15, -0.95), (0.25, -0.35), (0.75, -0.1), (0.8, 0.12), (0.28, 0.1), (0.22, 0.45),
			(0.32, 0.75), (0.0, 0.95), (-0.32, 0.75), (-0.22, 0.45), (-0.28, 0.1), (-0.8, 0.12), (-0.75, -0.1), (-0.25, -0.35)]
	vo = [bm.verts.new((x, 0, z)) for x, z in outer]
	vh = [bm.verts.new((x * 0.9, 0, z * 0.95)) for x, z in hole]
	e_o = [bm.edges.new((vo[i], vo[(i + 1) % 4])) for i in range(4)]
	e_h = [bm.edges.new((vh[i], vh[(i + 1) % len(vh)])) for i in range(len(vh))]
	bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=e_o + e_h)
	inside = []
	for f in bm.faces:
		cxz = f.calc_center_median()
		if _in_poly((cxz.x, cxz.z), [(x * 0.9, z * 0.95) for x, z in hole]):
			inside.append(f)
	bmesh.ops.delete(bm, geom=inside, context="FACES_ONLY")
	put("glass_hole", bm, mat_glass("glass_h"), "prop_glasshole", (wxw, WALL_Y - 0.3, wz), (0, 0, 0))
	for i, (x, r) in enumerate(((-0.6, 20), (0.5, -30), (0.1, 60), (-0.2, 110))):
		prism(f"shard{i}", [(0, 0), (0.16, 0.02), (0.05, 0.22)], 0.02, (wxw + x, WALL_Y - 0.6, 0.02), mat("#BFD9FF", 0.05, 0.2), "prop_glasshole", rot=(0, 0, r))
	piv["glass"] = (wxw, WALL_Y - 0.3, wz)
	piv["glasshole"] = (wxw, WALL_Y - 0.3, wz)
	sph("stamp_b", 0.28, (0, 0, 0), mat("velvet", 0.6), "icon_stamp", scale=(1.2, 1.0, 0.35), rot=(0, -12, 0))
	sph("stamp_s", 0.05, (0.02, 0, 0.1), mat("velvet", 0.6), "icon_stamp")
	return piv


def _in_poly(p, poly) -> bool:
	x, y = p
	inside = False
	j = len(poly) - 1
	for i in range(len(poly)):
		xi, yi = poly[i]
		xj, yj = poly[j]
		if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
			inside = not inside
		j = i
	return inside


def build_seqs(piv: dict) -> dict:
	seqs: dict = {}
	bpy.context.view_layer.update()
	# bedroom door (stage right, hinge on its right post)
	dw, dh = 1.6, 4.3
	hinge = group("door_hinge", "seq_door", (X_DOOR + dw / 2, WALL_Y - 0.1, 0))
	bpy.context.view_layer.update()
	parts = [box("door_panel", (dw, 0.12, dh), (X_DOOR, WALL_Y - 0.1, dh / 2), mat("wardrobe", 0.6), "seq_door", bevel=0.03)]
	for (px_, pz) in ((-0.4, 3.0), (0.4, 3.0), (-0.4, 1.1), (0.4, 1.1)):
		parts.append(box(f"door_p{px_}{pz}", (0.55, 0.05, 1.3 if pz < 2 else 1.6), (X_DOOR + px_, WALL_Y - 0.18, pz), mat("wardrobe_dk", 0.6), "seq_door", bevel=0.02))
	parts.append(sph("door_knob", 0.08, (X_DOOR - 0.6, WALL_Y - 0.24, 2.0), mat("brass", 0.3, 0, 0.8), "seq_door"))
	parts.append(box("door_plate", (0.12, 0.03, 0.4), (X_DOOR - 0.6, WALL_Y - 0.19, 2.0), mat("brass", 0.3, 0, 0.8), "seq_door", bevel=0.01))
	parts.append(box("door_hook", (0.06, 0.1, 0.06), (X_DOOR + 0.3, WALL_Y - 0.2, 3.9), mat("brass", 0.3, 0, 0.8), "seq_door", bevel=0.01))
	parts.append(box("door_towel", (0.4, 0.06, 0.9), (X_DOOR + 0.3, WALL_Y - 0.2, 3.4), K.mat_bands("blanket", "white", 5.0, 2, "doortowel"), "seq_door", bevel=0.04))
	bpy.context.view_layer.update()
	for o in parts:
		child(o, hinge)
	angles = [0, 16, 32, 48, 64, 80]
	seqs["door"] = (len(angles), lambda k: setattr(hinge, "rotation_euler", Euler((0, 0, math.radians(angles[k])))))

	# the spring bed: base + headboard stay; the mattress platform is hinged at the foot and SPRINGS
	bx = X_BED
	x0, x1 = bx - BED_LEN / 2, bx + BED_LEN / 2          # foot (stage left) .. head (stage right)
	by = STAGE_Y + 0.35
	box("bed_base", (BED_LEN, BED_W, 0.4), (bx, by, 0.4), mat("bedwood", 0.6), "seq_bed", bevel=0.04)
	box("bed_rail", (BED_LEN + 0.1, BED_W + 0.08, 0.1), (bx, by, 0.62), mat("bedwood_lt", 0.5), "seq_bed", bevel=0.03)
	for side in (-1, 1):
		cyl(f"bed_leg{side}", 0.08, 0.22, (bx + side * (BED_LEN / 2 - 0.1), by - BED_W / 2 + 0.1, 0.0), mat("bedwood", 0.6), "seq_bed", seg=10)
	box("headboard", (0.2, BED_W + 0.1, 2.1), (x1 + 0.12, by, 1.05), mat("bedwood", 0.6), "seq_bed", bevel=0.06)
	box("headboard_pad", (0.1, BED_W - 0.2, 0.9), (x1 + 0.03, by, 1.45), mat("rug_a", 0.9), "seq_bed", bevel=0.05)
	for k in range(3):
		sph(f"hb_tuft{k}", 0.035, (x1 - 0.02, by - 0.45 + k * 0.45, 1.45), mat("rug_c", 0.9), "seq_bed")
	for side in (-1, 1):
		sph(f"headboard_knob{side}", 0.11, (x1 + 0.12, by + side * (BED_W / 2 + 0.02), 2.18), mat("brass", 0.3, 0, 0.8), "seq_bed")
	box("footboard", (0.18, BED_W + 0.1, 1.3), (x0 - 0.09, by, 0.65), mat("bedwood", 0.6), "seq_bed", bevel=0.05)
	for side in (-1, 1):
		sph(f"footboard_knob{side}", 0.09, (x0 - 0.09, by + side * (BED_W / 2 + 0.02), 1.36), mat("brass", 0.3, 0, 0.8), "seq_bed")
	plat = group("platform", "seq_bed", (x0, by, 0.66))
	bpy.context.view_layer.update()
	mz = BED_Z - 0.17
	pp = [box("mattress", (BED_LEN - 0.15, BED_W - 0.05, 0.34), (bx, by, mz), mat("sheet", 0.85), "seq_bed", bevel=0.1),
		  box("mattress_seam", (BED_LEN - 0.14, BED_W - 0.04, 0.03), (bx, by, mz), mat("#D9D2C6", 0.85), "seq_bed", bevel=0),
		  box("duvet", (BED_LEN - 1.1, BED_W + 0.1, 0.18), (bx - 0.45, by, BED_Z + 0.05), K.mat_bands("duvet", "duvet2", 2.5, 0, "duvet"), "seq_bed", bevel=0.08),
		  box("duvet_fold", (0.5, BED_W + 0.1, 0.1), (bx - 0.45 + (BED_LEN - 1.1) / 2 - 0.2, by, BED_Z + 0.16), mat("sheet", 0.85), "seq_bed", bevel=0.04),
		  box("blanket", (0.7, BED_W + 0.12, 0.1), (x0 + 0.5, by, BED_Z + 0.2), K.mat_bands("blanket", "chair_dk", 4.0, 1, "blanket"), "seq_bed", bevel=0.04),
		  box("pillow", (0.7, BED_W - 0.5, 0.26), (x1 - 0.45, by - 0.1, BED_Z + 0.12), mat("pillow", 0.8), "seq_bed", bevel=0.1),
		  box("pillow2", (0.6, BED_W - 0.6, 0.22), (x1 - 0.5, by + 0.35, BED_Z + 0.1), mat("pillow", 0.8), "seq_bed", bevel=0.1, rot=(0, 0, -8))]
	bpy.context.view_layer.update()
	for o in pp:
		child(o, plat)
	springs = []
	for i in range(4):
		sx = x1 - 0.4 - i * 0.6
		s = cyl(f"spring{i}", 0.09, 0.05, (sx, by - 0.55, 0.62), mat("steel", 0.3, 0, 0.8), "seq_bed", seg=10)
		springs.append((s, sx))
	ang = [0, -24, -52, -62, -38, -14, 4, 0]

	def bed_frame(k: int) -> None:
		a = ang[k]
		plat.rotation_euler = Euler((0, math.radians(a), 0))
		for s, sx in springs:
			# the spring stretches up to the lifted platform's underside
			h = max(0.05, (sx - x0) * math.sin(math.radians(-a)) + 0.05)
			s.scale = (1, 1, h / 0.05)
	seqs["bed"] = (len(ang), bed_frame)
	piv["bed_head"] = (x1 - 0.45, STAGE_Y, BED_Z)
	seqs["curtain"] = stagekit.curtain(mat, cyl, box)
	return seqs


def setup_lights(scene, cam) -> None:
	# rendered LIT (the pendant and the lamp on); the game's "dark" pass turns them off
	stagekit.lights(scene, cam, [
		("pendant", (-0.6, 2.4, 5.0), 320, (1.0, 0.86, 0.66), 0.6),
		("lamp", (X_TABLE + 0.25, 2.5, TABLE_Z + 0.6), 90, (1.0, 0.8, 0.5), 0.3),
		("moon", (X_WINDOW, 3.0, 3.0), 90, (0.7, 0.8, 1.0), 1.0),
		("foot", (0.0, -2.5, 2.2), 380, (1.0, 0.84, 0.6), 5.0)],
		sun=(1.3, 8, (1.0, 0.93, 0.85), (50, 0, 20)), world=((0.8, 0.82, 1.0, 1), 0.3))


def main() -> int:
	def build():
		marks = build_room()
		build_fx_moon()
		piv = build_props()
		return marks, piv, build_seqs(piv)
	return stagekit.run(build, setup_lights, os.path.join(HERE, "out_act5"))


if __name__ == "__main__":
	raise SystemExit(main())
