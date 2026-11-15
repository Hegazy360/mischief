"""act4_set — Gus Thudd's garage gym, modelled from scratch in Blender (Act IV · "Leg Day").

    python3 tools/stage/build.py --act act4 [--engine eevee]

Same camera, scale and theatre as the other Acts (act1_set primitives, stagekit render loop).
Stage left to right (x in units, px = 1200 + 128 x):
  -7.6  side door (seq)        Hush's way in
  -5.85 tool chest + calendar  (every leg day crossed out)
  -3.6  high window            morning sun: the light shaft falls across the treadmill
  -3.4  treadmill              RIG 1: console wound to MAX; it fires him off the back
   0.4  sectional garage door  banner over it: NO PAIN NO GAIN
   1.2  heavy bag (prop)       RIG 2: the strap sawn; it swings, then drops on him. FREEZE beside it
   3.4  the mat                push-ups ("…ninety-nine… ONE HUNDRED."), on rubber gym tiles
   3.7  poster                 Gus, 1998, flexing
   5.0  weight rack
   6.2  lockers (fg)           Hush hides behind them
   7.6  dressing-room mirror   ringed with bulbs (he is a star)

Quality notes: block wall and floors are procedural with grime + bump so nothing reads as a flat
colour; the hero props (treadmill, bag) carry the most detail because the camera pushes in on them.
"""
from __future__ import annotations

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # type: ignore  # noqa: E402
from mathutils import Euler, Vector  # type: ignore  # noqa: E402

import act1_set as K  # noqa: E402
import act2_set as K2  # noqa: E402  (text(), palette)
import stagekit  # noqa: E402

box, cyl, sph, prism, mat, coll, torus = K.box, K.cyl, K.sph, K.prism, K.mat, K.coll, K.torus
group, child, text = K.group, K.child, K2.text
WALL_Y, STAGE_Y = K.WALL_Y, K.STAGE_Y

K.C.update({
	"block": "#C9C1B0", "block2": "#BDB4A2", "block_lo": "#4F7A8A", "block_lo2": "#46707F", "mortar": "#A39C8E",
	"concrete": "#A8A397", "concrete2": "#9D988C", "joint": "#7D796F", "stain": "#8A867C",
	"rubber": "#2C2D33", "rubber2": "#33353C", "fleck": "#5C6470",
	"gdoor": "#DCE0E2", "gdoor_pn": "#E9ECEE", "gdoor_dk": "#9FA8B0", "peg": "#C7A57A", "bag": "#B8323C", "bag_dk": "#7E1B25",
	"mat_blue": "#2F5E9E", "mat_blue2": "#264E85", "tread": "#2B2B33", "tread_hi": "#4A4A55", "screen": "#5FE07A",
	"locker": "#4E8DA8", "locker_dk": "#3B6F86", "locker_in": "#447E97", "banner": "#F2C230", "hazard": "#1E1A24",
	"chalk": "#F7F4EE", "chest": "#C8343E", "chest_dk": "#9C2530", "poster": "#F08A3C", "poster2": "#FFC93C",
	"rope": "#D7263D", "band_g": "#4FA845", "band_p": "#8C4FBF", "bottle": "#3E8FD8", "sky_win": "#D9F1FF",
})

X_DOOR, X_TREAD, X_CONSOLE, X_BAG, X_MAT, X_RACK, X_LOCKER, X_MIRROR = -7.6, -3.4, -4.85, 1.2, 3.4, 5.0, 6.2, 7.6
BAG_TOP, BAG_BOT = 3.5, 1.6               # the bag hangs from a wall bracket; its bottom is above a lying Gus
WIN = (-3.6, 4.85, 2.6, 0.85)             # the high window: centre x, z, width, height


# --- materials --------------------------------------------------------------------------------
def _graph(name: str, rough: float):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	bs = nt.nodes["Principled BSDF"]
	bs.inputs["Roughness"].default_value = rough
	return m, nt, bs


def _ref():
	"""One empty every tiled material maps from, so bricks line up across separate objects."""
	if "texref" not in bpy.data.objects:
		o = bpy.data.objects.new("texref", None)
		bpy.context.scene.collection.objects.link(o)
	return bpy.data.objects["texref"]


def _grime(nt, colour_socket, coord_socket, scale: float, amount: float, detail: float = 6.0):
	"""Overlay low-frequency noise on a colour: stains, wear, uneven paint."""
	nz = nt.nodes.new("ShaderNodeTexNoise")
	nz.inputs["Scale"].default_value = scale
	nz.inputs["Detail"].default_value = detail
	nt.links.new(coord_socket, nz.inputs["Vector"])
	mx = nt.nodes.new("ShaderNodeMix")
	mx.data_type = "RGBA"
	mx.blend_type = "OVERLAY"
	mx.inputs[0].default_value = amount
	nt.links.new(colour_socket, mx.inputs[6])
	nt.links.new(nz.outputs["Fac"], mx.inputs[7])
	return mx.outputs[2]


def _bump(nt, bs, height_socket, strength: float, invert: bool = True) -> None:
	bp = nt.nodes.new("ShaderNodeBump")
	bp.invert = invert
	bp.inputs["Strength"].default_value = strength
	bp.inputs["Distance"].default_value = 0.02
	nt.links.new(height_socket, bp.inputs["Height"])
	nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])


def mat_blocks(c1: str = "block", c2: str = "block2", name: str = "blocks"):
	"""Painted breeze-block wall in the x-z plane: recessed mortar (bump) and patchy paint."""
	m, nt, bs = _graph(name, 0.9)
	tc = nt.nodes.new("ShaderNodeTexCoord")
	tc.object = _ref()
	mp = nt.nodes.new("ShaderNodeMapping")
	mp.inputs["Rotation"].default_value = (math.radians(90), 0, 0)
	nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
	br = nt.nodes.new("ShaderNodeTexBrick")
	br.inputs["Color1"].default_value = K.lin(K.C[c1])
	br.inputs["Color2"].default_value = K.lin(K.C[c2])
	br.inputs["Mortar"].default_value = K.lin(K.C["mortar"])
	br.inputs["Scale"].default_value = 1.0
	br.inputs["Mortar Size"].default_value = 0.022
	br.inputs["Mortar Smooth"].default_value = 0.3
	br.inputs["Brick Width"].default_value = 0.9
	br.inputs["Row Height"].default_value = 0.45
	nt.links.new(mp.outputs[0], br.inputs["Vector"])
	col = _grime(nt, br.outputs["Color"], tc.outputs["Object"], 0.9, 0.28)
	nt.links.new(col, bs.inputs["Base Color"])
	_bump(nt, bs, br.outputs["Fac"], 0.45)
	return m


def mat_concrete():
	"""Garage slab: big pours with saw-cut joints, mottled and a little polished by use."""
	m, nt, bs = _graph("concrete", 0.55)
	tc = nt.nodes.new("ShaderNodeTexCoord")
	tc.object = _ref()
	br = nt.nodes.new("ShaderNodeTexBrick")
	br.offset = 0.0
	br.inputs["Color1"].default_value = K.lin(K.C["concrete"])
	br.inputs["Color2"].default_value = K.lin(K.C["concrete2"])
	br.inputs["Mortar"].default_value = K.lin(K.C["joint"])
	br.inputs["Scale"].default_value = 1.0
	br.inputs["Mortar Size"].default_value = 0.012
	br.inputs["Brick Width"].default_value = 2.4
	br.inputs["Row Height"].default_value = 1.2
	nt.links.new(tc.outputs["Object"], br.inputs["Vector"])
	col = _grime(nt, br.outputs["Color"], tc.outputs["Object"], 1.6, 0.35)
	nt.links.new(col, bs.inputs["Base Color"])
	_bump(nt, bs, br.outputs["Fac"], 0.3)
	return m


def mat_rubber():
	"""Interlocking rubber gym tiles: near-black squares, coloured EPDM flecks, matte."""
	m, nt, bs = _graph("rubber", 0.92)
	tc = nt.nodes.new("ShaderNodeTexCoord")
	tc.object = _ref()
	br = nt.nodes.new("ShaderNodeTexBrick")
	br.offset = 0.0
	br.inputs["Color1"].default_value = K.lin(K.C["rubber"])
	br.inputs["Color2"].default_value = K.lin(K.C["rubber2"])
	br.inputs["Mortar"].default_value = K.lin("#17171B")
	br.inputs["Scale"].default_value = 1.0
	br.inputs["Mortar Size"].default_value = 0.012
	br.inputs["Brick Width"].default_value = 0.8
	br.inputs["Row Height"].default_value = 0.8
	nt.links.new(tc.outputs["Object"], br.inputs["Vector"])
	nz = nt.nodes.new("ShaderNodeTexNoise")
	nz.inputs["Scale"].default_value = 90.0
	nz.inputs["Detail"].default_value = 1.0
	nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
	gt = nt.nodes.new("ShaderNodeMath")
	gt.operation = "GREATER_THAN"
	gt.inputs[1].default_value = 0.66
	nt.links.new(nz.outputs["Fac"], gt.inputs[0])
	mx = nt.nodes.new("ShaderNodeMix")
	mx.data_type = "RGBA"
	nt.links.new(gt.outputs[0], mx.inputs[0])
	nt.links.new(br.outputs["Color"], mx.inputs[6])
	mx.inputs[7].default_value = K.lin(K.C["fleck"])
	nt.links.new(mx.outputs[2], bs.inputs["Base Color"])
	_bump(nt, bs, br.outputs["Fac"], 0.5)
	return m


def mat_leather(key: str, name: str):
	"""Heavy-bag vinyl: a soft sheen and faint creasing."""
	m, nt, bs = _graph(name, 0.42)
	bs.inputs["Base Color"].default_value = K.lin(K.C[key])
	try:
		bs.inputs["Coat Weight"].default_value = 0.25
		bs.inputs["Coat Roughness"].default_value = 0.35
	except KeyError:
		pass
	tc = nt.nodes.new("ShaderNodeTexCoord")
	nz = nt.nodes.new("ShaderNodeTexNoise")
	nz.inputs["Scale"].default_value = 7.0
	nz.inputs["Detail"].default_value = 3.0
	nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
	_bump(nt, bs, nz.outputs["Fac"], 0.12, invert=False)
	return m


def mat_glass():
	"""Mirror glass: a cool vertical gradient so it reads as a reflection, not a blue card."""
	m, nt, bs = _graph("mirror_glass", 0.05)
	bs.inputs["Metallic"].default_value = 0.3
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	mx = nt.nodes.new("ShaderNodeMix")
	mx.data_type = "RGBA"
	nt.links.new(sep.outputs[2], mx.inputs[0])
	mx.inputs[6].default_value = K.lin("#6F9DB5")
	mx.inputs[7].default_value = K.lin("#C4E2EF")
	nt.links.new(mx.outputs[2], bs.inputs["Base Color"])
	nt.links.new(mx.outputs[2], bs.inputs["Emission Color"])
	bs.inputs["Emission Strength"].default_value = 0.06
	return m


def bevel(o, w: float, seg: int = 3):
	md = o.modifiers.new("bevel", "BEVEL")
	md.width = w
	md.segments = seg
	md.limit_method = "ANGLE"
	return o


# --- small furniture --------------------------------------------------------------------------
def kettlebell(name: str, x: float, y: float, r: float, key: str) -> None:
	sph(f"{name}_b", r, (x, y, r * 0.92), mat(key, 0.45, 0, 0.4), scale=(1, 1, 0.94))
	torus(f"{name}_h", r * 0.55, r * 0.14, (x, y, r * 1.85), mat(key, 0.45, 0, 0.4), rot=(90, 0, 0), seg=20, rseg=8)


def dumbbell(name: str, x: float, y: float, z: float, r: float) -> None:
	cyl(f"{name}_bar", 0.035, 0.5, (x - 0.25, y, z), mat("steel", 0.3, 0, 0.8), rot=(0, 90, 0), seg=10)
	for s in (-1, 1):
		cyl(f"{name}_hd{s}", r, 0.14, (x + s * 0.2 - 0.07, y, z), mat("black", 0.5), rot=(0, 90, 0), seg=6)


def build_room() -> dict:
	marks: dict = {}
	_ref()
	# --- walls: painted blocks, a darker painted band at the bottom, a hazard kick strip ---
	box("wall", (19.6, 0.3, 7.6), (0, WALL_Y + 0.15, 3.8), mat_blocks(), bevel=0)
	box("wall_lo", (19.6, 0.02, 1.35), (0, WALL_Y - 0.005, 0.675), mat_blocks("block_lo", "block_lo2", "blocks_lo"), bevel=0)
	box("wall_line", (19.6, 0.03, 0.08), (0, WALL_Y - 0.02, 1.37), mat("banner", 0.6), bevel=0)
	box("skirt", (19.6, 0.15, 0.25), (0, WALL_Y - 0.08, 0.12), mat("hazard", 0.6), bevel=0.02)
	for i in range(40):
		box(f"hz{i}", (0.22, 0.17, 0.25), (-9.6 + i * 0.5, WALL_Y - 0.09, 0.12), mat("banner", 0.6), bevel=0, rot=(0, 35, 0))
	# conduit along the top of the wall, dropping to the light switch by the side door
	cm = mat("steel_dk", 0.4, 0, 0.6)
	cyl("conduit", 0.045, 19.6, (-9.8, WALL_Y - 0.08, 5.95), cm, rot=(0, 90, 0), seg=10)
	cyl("conduit_v", 0.045, 3.75, (-6.45, WALL_Y - 0.08, 2.2), cm, seg=10)
	for z in (3.0, 4.2, 5.4):
		box(f"clip{z}", (0.14, 0.05, 0.05), (-6.45, WALL_Y - 0.1, z), cm, bevel=0.01)
	box("switch", (0.24, 0.08, 0.34), (-6.45, WALL_Y - 0.1, 2.15), mat("cream", 0.5), bevel=0.03)
	box("switch_t", (0.05, 0.04, 0.1), (-6.45, WALL_Y - 0.16, 2.17), mat("ink", 0.5), bevel=0.01)

	# --- floors: concrete slab, rubber gym tiles under the workout corner ---
	box("floor", (19.6, 6.0, 0.2), (0, 1.0, -0.1), mat_concrete(), bevel=0)
	box("rubber", (6.8, 2.9, 0.03), (5.2, 2.5, 0.0), mat_rubber(), bevel=0.01)
	# stage apron + footlights
	box("apron", (19.6, 0.4, 3.0), (0, -1.7, -1.5), mat("stage", 0.6), bevel=0)
	box("apron_lip", (19.6, 0.5, 0.12), (0, -1.55, -0.06), mat("gold", 0.35, 0, 0.6), bevel=0.04)
	for i in range(11):
		x = -7.5 + i * 1.5
		sph(f"foot{i}", 0.13, (x, -1.82, -0.18), mat("bulb", 0.3, 4.0), scale=(1.3, 1, 0.8))
		box(f"foothood{i}", (0.42, 0.18, 0.12), (x, -1.9, -0.06), mat("gold_dk", 0.4, 0, 0.6), bevel=0.03)

	# --- the sectional garage door, shut (the car lives on the drive: the garage is for HIM) ---
	gx, gw, gh = 0.4, 5.2, 4.2
	box("gdoor_frame", (gw + 0.4, 0.2, gh + 0.2), (gx, WALL_Y - 0.05, gh / 2), mat("hazard", 0.7), bevel=0.03)
	sec = gh / 4
	for k in range(4):
		z = sec * (k + 0.5)
		box(f"gsec{k}", (gw, 0.08, sec - 0.04), (gx, WALL_Y - 0.15, z), mat("gdoor", 0.55), bevel=0.02)
		for i in range(4):
			px = gx - gw / 2 + 0.65 + i * 1.3
			if k == 3:      # the top section is glazed: daylight from the drive
				box(f"gwin{k}{i}", (1.05, 0.04, 0.5), (px, WALL_Y - 0.2, z + 0.02), mat("sky_win", 0.4, 0.9), bevel=0.02)
				box(f"gwinf{k}{i}", (1.15, 0.03, 0.6), (px, WALL_Y - 0.18, z + 0.02), mat("gdoor_dk", 0.5), bevel=0.02)
			else:
				box(f"gpan{k}{i}", (1.1, 0.05, 0.62), (px, WALL_Y - 0.2, z), mat("gdoor_pn", 0.5), bevel=0.06)
	for side in (-1, 1):
		box(f"gtrack{side}", (0.1, 0.12, gh), (gx + side * (gw / 2 - 0.02), WALL_Y - 0.22, gh / 2), mat("iron", 0.5, 0, 0.5), bevel=0.01)
	box("gdoor_handle", (0.6, 0.08, 0.1), (gx, WALL_Y - 0.26, 0.6), mat("chrome", 0.3, 0, 0.8), bevel=0.02)
	box("gdoor_seal", (gw, 0.12, 0.06), (gx, WALL_Y - 0.17, 0.03), mat("black", 0.8), bevel=0.01)
	# banner on the wall over the door, tied at the corners
	bx, bz, bw = -0.55, 4.78, 3.4
	box("banner", (bw, 0.04, 0.72), (bx, WALL_Y - 0.1, bz), mat("banner", 0.85), bevel=0.01)
	box("banner_hem", (bw, 0.045, 0.06), (bx, WALL_Y - 0.11, bz - 0.33), mat("chest", 0.8), bevel=0)
	box("banner_top", (bw, 0.045, 0.06), (bx, WALL_Y - 0.11, bz + 0.33), mat("chest", 0.8), bevel=0)
	text("banner_t", "NO PAIN  NO GAIN", 0.32, (bx, WALL_Y - 0.13, bz - 0.01), "bg", "hazard")
	for side in (-1, 1):
		torus(f"grommet{side}", 0.05, 0.015, (bx + side * (bw / 2 - 0.12), WALL_Y - 0.13, bz + 0.24), mat("steel", 0.3, 0, 0.8), rot=(90, 0, 0), seg=12, rseg=6)

	# --- the high window: morning sun (its shaft is fx_shaft) ---
	wx, wz, ww, wh = WIN
	box("win_sky", (ww, 0.04, wh), (wx, WALL_Y - 0.02, wz), mat("#5FB3E6", 0.9, 0.2), bevel=0)
	for i, (cx, cz, r) in enumerate(((-0.7, 0.2, 0.2), (-0.45, 0.25, 0.16), (0.6, 0.28, 0.14))):
		sph(f"win_cloud{i}", r, (wx + cx, WALL_Y - 0.04, wz + cz), mat("white", 0.9, 0.3), scale=(1.5, 0.2, 0.7))
	for i in range(6):
		sph(f"win_hedge{i}", 0.3, (wx - ww / 2 + 0.2 + i * 0.45, WALL_Y - 0.05, wz - wh / 2 + 0.05), mat("hedge", 0.9, 0.1), scale=(1, 0.2, 0.7))
	fm = mat("chalk", 0.6)
	box("win_top", (ww + 0.24, 0.2, 0.12), (wx, WALL_Y - 0.12, wz + wh / 2 + 0.06), fm)
	box("win_bot", (ww + 0.4, 0.34, 0.12), (wx, WALL_Y - 0.17, wz - wh / 2 - 0.06), fm)
	for side in (-1, 1):
		box(f"win_side{side}", (0.12, 0.2, wh + 0.12), (wx + side * (ww / 2 + 0.06), WALL_Y - 0.12, wz), fm)
	for i in (1, 2, 3):
		box(f"win_m{i}", (0.06, 0.1, wh), (wx - ww / 2 + i * ww / 4, WALL_Y - 0.1, wz), fm)
	marks["window"] = (wx, WALL_Y, wz)

	# --- fluorescent tubes on chains ---
	for i, x in enumerate((-6.2, 4.7)):
		box(f"fl_house{i}", (2.0, 0.26, 0.1), (x, 2.6, 5.62), mat("steel_dk", 0.5, 0, 0.4), bevel=0.02)
		box(f"fl_tube{i}", (1.86, 0.14, 0.06), (x, 2.6, 5.55), mat("white", 0.4, 4.0), bevel=0.02)
		for s in (-1, 1):
			cyl(f"fl_chain{i}{s}", 0.012, 1.6, (x + s * 0.8, 2.6, 5.67), mat("steel", 0.3, 0, 0.8), seg=6)

	# --- stage left: side door frame, tool chest with a radio, the calendar ---
	dw, dh = 1.6, 4.3
	box("doorway", (dw, 0.1, dh), (X_DOOR, WALL_Y - 0.02, dh / 2), mat("#3A2433", 0.9), bevel=0)
	for side in (-1, 1):
		box(f"door_jamb{side}", (0.2, 0.3, dh + 0.1), (X_DOOR + side * (dw / 2 + 0.1), WALL_Y - 0.15, dh / 2), mat("cream", 0.6))
	box("door_head", (dw + 0.6, 0.34, 0.26), (X_DOOR, WALL_Y - 0.17, dh + 0.13), mat("cream", 0.6))
	marks["door"] = (X_DOOR + 0.3, STAGE_Y, 0)
	cx = -5.75
	box("chest_body", (1.2, 0.6, 1.55), (cx, WALL_Y - 0.4, 0.92), mat("chest", 0.35, 0, 0.15), bevel=0.04)
	box("chest_lid", (1.26, 0.64, 0.1), (cx, WALL_Y - 0.4, 1.73), mat("chest_dk", 0.4), bevel=0.03)
	for k in range(5):
		z = 0.38 + k * 0.29
		box(f"drawer{k}", (1.08, 0.04, 0.24), (cx, WALL_Y - 0.72, z), mat("chest_dk", 0.35, 0, 0.15), bevel=0.02)
		box(f"dhandle{k}", (0.6, 0.04, 0.035), (cx, WALL_Y - 0.75, z + 0.06), mat("chrome", 0.25, 0, 0.9), bevel=0.01)
	for s in (-1, 1):
		cyl(f"caster{s}", 0.07, 0.08, (cx + s * 0.45, WALL_Y - 0.6, 0.07), mat("black", 0.6), rot=(90, 0, 0), seg=12)
	# the radio on top
	box("radio", (0.9, 0.3, 0.42), (cx, WALL_Y - 0.4, 2.0), mat("ink", 0.5), bevel=0.05)
	for s in (-1, 1):
		cyl(f"spk{s}", 0.13, 0.04, (cx + s * 0.26, WALL_Y - 0.56, 1.98), mat("steel_dk", 0.6), rot=(90, 0, 0), seg=20)
		cyl(f"spkc{s}", 0.05, 0.05, (cx + s * 0.26, WALL_Y - 0.58, 1.98), mat("iron", 0.4), rot=(90, 0, 0), seg=12)
	box("radio_dial", (0.18, 0.04, 0.08), (cx, WALL_Y - 0.57, 2.08), mat("screen", 0.3, 1.2), bevel=0.01)
	box("radio_handle", (0.7, 0.05, 0.05), (cx, WALL_Y - 0.4, 2.3), mat("steel", 0.3, 0, 0.7), bevel=0.02)
	cyl("radio_aerial", 0.012, 0.6, (cx + 0.38, WALL_Y - 0.35, 2.2), mat("chrome", 0.3, 0, 0.9), rot=(0, 25, 0), seg=6)
	# calendar: a month of leg days, every one crossed out
	kz = 3.55
	box("cal_board", (0.95, 0.03, 1.15), (cx, WALL_Y - 0.03, kz), mat("chalk", 0.8), bevel=0.01)
	box("cal_head", (0.95, 0.035, 0.26), (cx, WALL_Y - 0.04, kz + 0.44), mat("chest", 0.7), bevel=0.01)
	text("cal_t", "LEG DAY", 0.13, (cx, WALL_Y - 0.065, kz + 0.44), "bg", "chalk")
	for r in range(4):
		for c in range(5):
			x, z = cx - 0.34 + c * 0.17, kz + 0.2 - r * 0.2
			box(f"cal_d{r}{c}", (0.13, 0.02, 0.15), (x, WALL_Y - 0.05, z), mat("#D9D3C7", 0.8), bevel=0)
			if (r * 5 + c) % 2 == 0:
				for a in (40, -40):
					box(f"cal_x{r}{c}{a}", (0.025, 0.02, 0.19), (x, WALL_Y - 0.065, z), mat("chest", 0.6), bevel=0, rot=(0, a, 0))
	cyl("cal_nail", 0.025, 0.05, (cx, WALL_Y - 0.03, kz + 0.66), mat("iron", 0.4), rot=(90, 0, 0), seg=8)

	# --- the pegboard over the treadmill: tools + skipping rope + bands ---
	box("peg", (3.0, 0.05, 1.8), (-3.6, WALL_Y - 0.05, 3.4), mat("peg", 0.8), bevel=0.01)
	box("peg_frame", (3.1, 0.04, 1.9), (-3.6, WALL_Y - 0.02, 3.4), mat("wood_dk", 0.7), bevel=0.01)
	for i in range(9):
		for k in range(5):
			cyl(f"hole{i}{k}", 0.025, 0.02, (-4.9 + i * 0.32, WALL_Y - 0.08, 2.75 + k * 0.32), mat("wood_dk", 0.9), rot=(90, 0, 0), seg=6)
	ty = WALL_Y - 0.12
	# hammer
	box("hammer_h", (0.07, 0.04, 0.72), (-4.7, ty, 3.45), mat("wood_lt", 0.6), bevel=0.02)
	box("hammer_hd", (0.34, 0.09, 0.11), (-4.7, ty - 0.01, 3.84), mat("iron", 0.4, 0, 0.6), bevel=0.02)
	# spanner
	box("spanner_s", (0.06, 0.03, 0.62), (-4.25, ty, 3.4), mat("steel", 0.3, 0, 0.8), bevel=0.01)
	for z in (3.1, 3.72):
		torus(f"spanner_e{z}", 0.07, 0.028, (-4.25, ty, z), mat("steel", 0.3, 0, 0.8), rot=(90, 0, 0), seg=14, rseg=6)
	# screwdrivers
	for i, (x, c) in enumerate(((-3.85, "tin_lbl1"), (-3.6, "banner"))):
		cyl(f"sd_s{i}", 0.014, 0.34, (x, ty, 3.12), mat("steel", 0.3, 0, 0.8), seg=6)
		cyl(f"sd_h{i}", 0.05, 0.24, (x, ty, 3.46), mat(c, 0.45), seg=10)
	# skipping rope (never used) and two resistance bands
	torus("rope", 0.34, 0.022, (-2.95, ty, 3.25), mat("rope", 0.6), rot=(90, 0, 0), seg=28, rseg=6)
	for s in (-1, 1):
		cyl(f"rope_h{s}", 0.04, 0.24, (-2.95 + s * 0.12, ty - 0.03, 3.6), mat("ink", 0.5), seg=10)
	torus("band_g", 0.2, 0.03, (-2.4, ty, 3.6), mat("band_g", 0.6), rot=(90, 0, 0), seg=20, rseg=6)
	torus("band_p", 0.17, 0.03, (-2.4, ty - 0.02, 3.2), mat("band_p", 0.6), rot=(90, 0, 0), seg=20, rseg=6)
	cyl("tape", 0.12, 0.07, (-3.35, ty, 3.85), mat("banner", 0.5), rot=(90, 0, 0), seg=20)

	# --- the treadmill: belt on the walk line, motor hood + console at its stage-left end ---
	tx = X_TREAD
	frame_m = mat("tread_hi", 0.45, 0, 0.2)
	box("tread_deck", (3.0, 1.0, 0.24), (tx, STAGE_Y + 0.1, 0.16), frame_m, bevel=0.06)
	box("tread_belt", (2.8, 0.8, 0.04), (tx, STAGE_Y + 0.1, 0.3), K.mat_bands("tread", "tread_hi", 3.0, 0, "belt"), bevel=0)
	for side in (-1, 1):
		box(f"tread_side{side}", (2.9, 0.1, 0.1), (tx + 0.05, STAGE_Y + 0.1 + side * 0.46, 0.33), mat("steel", 0.35, 0, 0.6), bevel=0.02)
	cyl("tread_roller", 0.13, 1.02, (tx + 1.45, STAGE_Y - 0.41, 0.17), mat("iron", 0.4, 0, 0.5), rot=(-90, 0, 0), seg=16)
	box("tread_hood", (0.7, 1.08, 0.42), (X_CONSOLE + 0.15, STAGE_Y + 0.1, 0.38), frame_m, bevel=0.1)
	box("tread_stripe", (0.72, 1.1, 0.07), (X_CONSOLE + 0.15, STAGE_Y + 0.1, 0.44), mat("chest", 0.4), bevel=0.02)
	for side in (-1, 1):
		box(f"tread_post{side}", (0.1, 0.1, 1.5), (X_CONSOLE + 0.1, STAGE_Y + 0.1 + side * 0.45, 0.95), mat("chrome", 0.3, 0, 0.8), bevel=0.02, rot=(0, -12, 0))
		box(f"tread_rail{side}", (0.9, 0.06, 0.06), (X_CONSOLE + 0.55, STAGE_Y + 0.1 + side * 0.45, 1.55), mat("chrome", 0.3, 0, 0.8), bevel=0.02)
		box(f"tread_grip{side}", (0.3, 0.075, 0.075), (X_CONSOLE + 0.85, STAGE_Y + 0.1 + side * 0.45, 1.55), mat("black", 0.7), bevel=0.03)
	box("console", (0.42, 1.0, 0.55), (X_CONSOLE - 0.05, STAGE_Y + 0.1, 1.85), mat("tread", 0.5), bevel=0.08, rot=(0, -20, 0))
	box("console_screen", (0.05, 0.6, 0.25), (X_CONSOLE + 0.18, STAGE_Y + 0.1, 1.92), mat("screen", 0.3, 2.0), bevel=0.01, rot=(0, -20, 0))
	cyl("console_dial", 0.09, 0.06, (X_CONSOLE + 0.21, STAGE_Y - 0.25, 1.7), mat("chest", 0.35), rot=(0, 70, 0), seg=16)
	cyl("console_key", 0.035, 0.06, (X_CONSOLE + 0.21, STAGE_Y + 0.45, 1.7), mat("banner", 0.4), rot=(0, 70, 0), seg=10)
	cyl("bottle", 0.07, 0.3, (X_CONSOLE + 0.28, STAGE_Y + 0.62, 1.42), mat("bottle", 0.3), seg=14)
	cyl("bottle_cap", 0.05, 0.06, (X_CONSOLE + 0.28, STAGE_Y + 0.62, 1.72), mat("white", 0.4), seg=12)
	marks["console"] = (X_CONSOLE, STAGE_Y, 1.9)
	marks["tread"] = (tx + 0.4, STAGE_Y, 0)

	# --- the bag's wall bracket (the bag itself is a prop) ---
	box("bracket", (0.12, 2.6, 0.12), (X_BAG, (WALL_Y + 2.7) / 2 - 0.4, 4.3), mat("iron", 0.5, 0, 0.5), bevel=0.02)
	box("bracket_brace", (0.08, 1.5, 0.08), (X_BAG, WALL_Y - 0.7, 3.95), mat("iron", 0.5, 0, 0.5), bevel=0.02, rot=(-24, 0, 0))
	box("bracket_plate", (0.5, 0.06, 0.8), (X_BAG, WALL_Y - 0.05, 4.1), mat("iron", 0.5, 0, 0.5), bevel=0.02)
	for z in (3.8, 4.4):
		sph(f"bolt{z}", 0.04, (X_BAG, WALL_Y - 0.1, z), mat("steel", 0.3, 0, 0.8))

	# --- workout corner: the mat, a poster of 1998, the weight rack, the dressing-room mirror ---
	box("mat", (2.6, 1.2, 0.05), (X_MAT, STAGE_Y + 0.15, 0.025), K.mat_bands("mat_blue", "mat_blue2", 1.0, 0, "mat"), bevel=0.02)
	ppx, ppz = 3.72, 3.2
	box("poster", (0.95, 0.03, 1.3), (ppx, WALL_Y - 0.03, ppz), mat("poster", 0.8), bevel=0)
	prism("poster_star", K.star_pts(12, 0.42, 0.3, 0.0), 0.01, (ppx, WALL_Y - 0.045, ppz + 0.12), mat("poster2", 0.8))
	sph("pg_body", 0.24, (ppx, WALL_Y - 0.06, ppz - 0.02), mat("tracksuit", 0.8), scale=(1.2, 0.15, 1.0))
	sph("pg_head", 0.12, (ppx, WALL_Y - 0.07, ppz + 0.3), mat("skin", 0.8), scale=(1, 0.15, 1.1))
	for s in (-1, 1):
		sph(f"pg_arm{s}", 0.09, (ppx + s * 0.3, WALL_Y - 0.07, ppz + 0.2), mat("skin", 0.8), scale=(1, 0.15, 1.5), rot=(0, s * -30, 0))
		sph(f"pg_fist{s}", 0.07, (ppx + s * 0.36, WALL_Y - 0.075, ppz + 0.38), mat("skin", 0.8), scale=(1, 0.15, 1))
	box("poster_band", (0.95, 0.035, 0.24), (ppx, WALL_Y - 0.05, ppz - 0.5), mat("ink", 0.8), bevel=0)
	text("poster_t", "1998", 0.18, (ppx, WALL_Y - 0.07, ppz - 0.5), "bg", "poster2")
	for s in (-1, 1):
		cyl(f"pin{s}", 0.03, 0.03, (ppx + s * 0.4, WALL_Y - 0.06, ppz + 0.58), mat("tin_lbl1", 0.4), rot=(90, 0, 0), seg=10)
	rx = X_RACK
	for side in (-1, 1):
		box(f"rack_post{side}", (0.14, 0.14, 2.6), (rx + side * 0.9, WALL_Y - 0.6, 1.3), mat("iron", 0.5, 0, 0.5), bevel=0.03)
		box(f"rack_foot{side}", (0.16, 0.9, 0.08), (rx + side * 0.9, WALL_Y - 0.6, 0.04), mat("iron", 0.5, 0, 0.5), bevel=0.02)
		box(f"rack_hook{side}", (0.1, 0.22, 0.06), (rx + side * 0.9, WALL_Y - 0.72, 1.82), mat("steel", 0.3, 0, 0.7), bevel=0.01)
	box("rack_top", (1.94, 0.14, 0.12), (rx, WALL_Y - 0.6, 2.6), mat("iron", 0.5, 0, 0.5), bevel=0.03)
	box("rack_bar", (2.4, 0.08, 0.08), (rx, WALL_Y - 0.75, 1.9), mat("steel", 0.3, 0, 0.8), bevel=0)
	for side in (-1, 1):
		for k in range(3):
			cyl(f"plate{side}{k}", 0.42 - k * 0.08, 0.08, (rx + side * (1.05 + k * 0.1), WALL_Y - 0.75, 1.9), mat("black" if k != 1 else "tin_lbl1", 0.45), rot=(0, 90, 0), seg=28)
	for i, (r, key) in enumerate(((0.2, "iron"), (0.24, "black"), (0.28, "tin_lbl1"))):
		kettlebell(f"kb{i}", rx - 0.7 + i * 0.6, WALL_Y - 1.05, r, key)
	# dumbbells on a low stand
	box("db_stand", (1.0, 0.36, 0.06), (rx + 0.1, WALL_Y - 0.3, 0.55), mat("iron", 0.5, 0, 0.5), bevel=0.02)
	for s in (-1, 1):
		box(f"db_leg{s}", (0.06, 0.3, 0.55), (rx + 0.1 + s * 0.45, WALL_Y - 0.3, 0.27), mat("iron", 0.5, 0, 0.5), bevel=0.01)
	for i in range(2):
		dumbbell(f"db{i}", rx - 0.15 + i * 0.5, WALL_Y - 0.3, 0.7, 0.1 + i * 0.02)
	# shelf of trophies and a protein tub over the rack
	box("shelf", (2.6, 0.35, 0.08), (X_RACK, WALL_Y - 0.2, 4.6), mat("wood", 0.6), bevel=0.02)
	for s in (-1, 1):
		box(f"shelf_br{s}", (0.06, 0.3, 0.3), (X_RACK + s * 1.0, WALL_Y - 0.17, 4.42), mat("iron", 0.5, 0, 0.5), bevel=0.01)
	for i in range(3):
		cyl(f"cupb{i}", 0.12, 0.1, (X_RACK - 0.7 + i * 0.6, WALL_Y - 0.25, 4.65), mat("wood_dk", 0.5), seg=16)
		cyl(f"cup{i}", 0.06, 0.35, (X_RACK - 0.7 + i * 0.6, WALL_Y - 0.25, 4.75), mat("gold", 0.3, 0, 0.8), r2=0.18, seg=20)
	cyl("tub", 0.22, 0.42, (X_RACK + 1.0, WALL_Y - 0.25, 4.65), mat("black", 0.4), seg=20)
	cyl("tub_lid", 0.23, 0.06, (X_RACK + 1.0, WALL_Y - 0.25, 5.07), mat("chest", 0.4), seg=20)
	box("tub_lbl", (0.3, 0.02, 0.16), (X_RACK + 1.0, WALL_Y - 0.48, 4.86), mat("banner", 0.6), bevel=0)
	# the mirror, ringed with dressing-room bulbs
	mz = 2.4
	box("mirror_frame", (1.9, 0.1, 3.4), (X_MIRROR, WALL_Y - 0.05, mz), mat("black", 0.4), bevel=0.05)
	box("mirror", (1.5, 0.05, 3.0), (X_MIRROR, WALL_Y - 0.12, mz), mat_glass(), bevel=0)
	for i, (dx, dz, s) in enumerate(((-0.35, 0.85, 1.3), (-0.12, 0.55, 0.6))):
		sph(f"mirror_glint{i}", 0.2 * s, (X_MIRROR + dx, WALL_Y - 0.16, mz + dz), mat("white", 0.5, 1.0), scale=(0.35, 0.1, 1.4), rot=(0, -25, 0))
	for k in range(6):
		z = mz - 1.4 + k * 0.56
		for s in (-1, 1):
			sph(f"mbulb{s}{k}", 0.07, (X_MIRROR + s * 0.85, WALL_Y - 0.14, z), mat("bulb", 0.3, 3.0))
	for k in range(3):
		sph(f"mbulbt{k}", 0.07, (X_MIRROR - 0.5 + k * 0.5, WALL_Y - 0.14, mz + 1.6), mat("bulb", 0.3, 3.0))
	text("mirror_note", "LOOKING GOOD", 0.17, (X_MIRROR, WALL_Y - 0.16, mz + 1.15), "bg", "tin_lbl1", rot=(90, 4, 0))
	marks["mat"] = (X_MAT, STAGE_Y, 0)
	marks["bag"] = (X_BAG, STAGE_Y, 0)
	return marks


def build_props() -> dict:
	piv: dict = {}
	# the heavy bag on its chain; pivot at the bracket (it swings about it)
	top = Vector((X_BAG, STAGE_Y + 0.15, 4.25))
	by = STAGE_Y + 0.15
	for k in range(3):
		K.torus(f"link{k}", 0.07, 0.022, top + Vector((0, 0, -0.15 * k)), mat("steel", 0.3, 0, 0.8), "prop_bag",
				rot=(90, 0, 90 * (k % 2)), seg=12, rseg=6)
	K.torus("bag_ring", 0.1, 0.03, (X_BAG, by, 3.82), mat("steel", 0.3, 0, 0.8), "prop_bag", rot=(90, 0, 0), seg=16, rseg=8)
	for a in (-1, 1):      # straps from the ring to the rim
		box(f"strap{a}", (0.07, 0.05, 0.5), (X_BAG + a * 0.2, by - 0.25, 3.62), mat("ink", 0.6), "prop_bag", bevel=0.01, rot=(0, a * -42, 0))
	body = cyl("bag_body", 0.48, BAG_TOP - BAG_BOT, (X_BAG, by, BAG_BOT), mat_leather("bag", "bag_vinyl"), "prop_bag", seg=40)
	bevel(body, 0.14, 4)
	dk = mat_leather("bag_dk", "bag_vinyl_dk")
	for z in (BAG_BOT + 0.22, BAG_TOP - 0.22):
		o = cyl(f"bag_band{z}", 0.495, 0.12, (X_BAG, by, z - 0.06), dk, "prop_bag", seg=40)
	for s in (-1, 1):       # vertical seams
		box(f"bag_seam{s}", (0.025, 0.02, BAG_TOP - BAG_BOT - 0.3), (X_BAG + s * 0.34, by - 0.345, (BAG_TOP + BAG_BOT) / 2),
			dk, "prop_bag", bevel=0, rot=(0, 0, s * -45))
	# the THUDD patch
	pz = (BAG_TOP + BAG_BOT) / 2 + 0.05
	box("bag_patch", (0.62, 0.04, 0.3), (X_BAG, by - 0.49, pz), mat("chalk", 0.6), "prop_bag", bevel=0.04)
	text("bag_t", "THUDD", 0.17, (X_BAG, by - 0.52, pz), "prop_bag", "bag_dk")
	piv["bag"] = tuple(top)
	piv["bag_c"] = (X_BAG, by, (BAG_TOP + BAG_BOT) / 2)
	# the lockers, in front of the walk line: Hush hides behind them
	lx, ly = X_LOCKER, 0.6
	for i in range(2):
		x = lx - 0.4 + i * 0.8
		box(f"locker{i}", (0.78, 0.7, 2.75), (x, ly, 1.375), mat("locker", 0.4, 0, 0.3), "fg_lockers", bevel=0.03)
		box(f"lpanel{i}", (0.6, 0.02, 1.0), (x, ly - 0.355, 0.85), mat("locker_in", 0.45, 0, 0.3), "fg_lockers", bevel=0.02)
		for k in range(5):
			box(f"vent{i}{k}", (0.42, 0.02, 0.035), (x, ly - 0.36, 2.25 + k * 0.08), mat("locker_dk", 0.5), "fg_lockers", bevel=0)
		box(f"lhandle{i}", (0.05, 0.04, 0.3), (x + 0.28, ly - 0.37, 1.55), mat("chrome", 0.3, 0, 0.8), "fg_lockers", bevel=0.01)
		box(f"lnum{i}", (0.18, 0.02, 0.1), (x, ly - 0.36, 2.6), mat("chrome", 0.3, 0, 0.8), "fg_lockers", bevel=0.01)
		box(f"lkick{i}", (0.78, 0.71, 0.12), (x, ly, 0.06), mat("locker_dk", 0.5), "fg_lockers", bevel=0.02)
	text("locker_t", "G.T.", 0.16, (lx - 0.4, ly - 0.37, 1.9), "fg_lockers", "chalk")
	# padlock on his, a gold star sticker on the other (both his)
	torus("lock_shackle", 0.05, 0.012, (lx - 0.12, ly - 0.39, 1.62), mat("steel", 0.3, 0, 0.8), "fg_lockers", rot=(90, 0, 0), seg=12, rseg=6)
	box("lock_body", (0.1, 0.04, 0.1), (lx - 0.12, ly - 0.39, 1.54), mat("brass", 0.3, 0, 0.8), "fg_lockers", bevel=0.015)
	prism("lstar", K.star_pts(5, 0.11, 0.05), 0.01, (lx + 0.4, ly - 0.37, 2.0), mat("gold", 0.4, 0, 0.6), "fg_lockers")
	# towel over the door, a gym bag on top
	box("towel", (0.48, 0.06, 0.8), (lx + 0.4, ly - 0.39, 1.0), mat("white", 0.95), "fg_lockers", bevel=0.05)
	box("towel_fold", (0.5, 0.75, 0.08), (lx + 0.4, ly, 1.41), mat("white", 0.95), "fg_lockers", bevel=0.04)
	box("towel_stripe", (0.49, 0.065, 0.06), (lx + 0.4, ly - 0.4, 0.75), mat("chest", 0.8), "fg_lockers", bevel=0.01)
	sph("gymbag", 0.42, (lx - 0.1, ly, 2.95), mat("mat_blue2", 0.7), "fg_lockers", scale=(1.3, 0.75, 0.55))
	cyl("gymbag_strap", 0.03, 0.9, (lx - 0.55, ly - 0.25, 2.98), mat("ink", 0.7), "fg_lockers", rot=(0, 90, 0), seg=8)
	piv["lockers"] = (lx, STAGE_Y, 0)
	sph("stamp_b", 0.28, (0, 0, 0), mat("velvet", 0.6), "icon_stamp", scale=(1.2, 1.0, 0.35), rot=(0, -12, 0))
	sph("stamp_s", 0.05, (0.02, 0, 0.1), mat("velvet", 0.6), "icon_stamp")
	K.build_shaft(win=WIN, dx=1.7, y1=1.3, colour="#FFDDA0", alpha=0.5)
	return piv


def build_seqs(piv: dict) -> dict:
	seqs: dict = {}
	bpy.context.view_layer.update()
	dw, dh = 1.6, 4.3
	hinge = group("door_hinge", "seq_sdoor", (X_DOOR - dw / 2, WALL_Y - 0.1, 0))
	bpy.context.view_layer.update()
	parts = [box("door_panel", (dw, 0.12, dh), (X_DOOR, WALL_Y - 0.1, dh / 2), mat("gdoor_dk", 0.6), "seq_sdoor", bevel=0.03),
			 box("door_sign", (0.9, 0.04, 0.5), (X_DOOR, WALL_Y - 0.18, 3.0), mat("banner", 0.7), "seq_sdoor", bevel=0.02),
			 box("door_kick", (dw - 0.1, 0.04, 0.4), (X_DOOR, WALL_Y - 0.18, 0.25), mat("steel", 0.3, 0, 0.7), "seq_sdoor", bevel=0.02),
			 box("door_pn", (dw - 0.5, 0.04, 1.3), (X_DOOR, WALL_Y - 0.18, 1.35), mat("steel_dk", 0.6), "seq_sdoor", bevel=0.05),
			 box("door_plate", (0.1, 0.04, 0.45), (X_DOOR + 0.6, WALL_Y - 0.18, 2.0), mat("steel", 0.3, 0, 0.7), "seq_sdoor", bevel=0.02),
			 sph("door_knob", 0.08, (X_DOOR + 0.6, WALL_Y - 0.24, 2.0), mat("brass", 0.3, 0, 0.8), "seq_sdoor")]
	parts.append(text("door_sign_t", "GYM", 0.24, (X_DOOR, WALL_Y - 0.21, 3.0), "seq_sdoor", "hazard"))
	bpy.context.view_layer.update()
	for o in parts:
		child(o, hinge)
	angles = [0, -16, -32, -48, -64, -80]
	seqs["sdoor"] = (len(angles), lambda k: setattr(hinge, "rotation_euler", Euler((0, 0, math.radians(angles[k])))))
	seqs["curtain"] = stagekit.curtain(mat, cyl, box)
	return seqs


def setup_lights(scene, cam) -> None:
	stagekit.lights(scene, cam, [
		("tube0", (-6.2, 2.4, 5.3), 240, (0.88, 0.95, 1.0), 1.0),
		("tube1", (4.7, 2.4, 5.3), 260, (0.88, 0.95, 1.0), 1.0),
		("window", (-3.6, 3.3, 4.6), 260, (1.0, 0.82, 0.58), 1.2),
		("sunpool", (-1.6, 1.6, 1.2), 90, (1.0, 0.8, 0.55), 1.5),
		("mirror", (X_MIRROR, 3.0, 2.4), 40, (1.0, 0.78, 0.5), 0.8),
		("foot", (0.0, -2.5, 2.2), 380, (1.0, 0.84, 0.6), 5.0)],
		sun=(2.2, 6, (1.0, 0.9, 0.76), (52, 0, 24)), world=((0.86, 0.9, 0.96, 1), 0.3))


def main() -> int:
	def build():
		marks = build_room()
		piv = build_props()
		return marks, piv, build_seqs(piv)
	return stagekit.run(build, setup_lights, os.path.join(HERE, "out_act4"))


if __name__ == "__main__":
	raise SystemExit(main())
