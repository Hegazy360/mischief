"""act1_set — model Gus Thudd's front room from scratch in Blender and render it as game layers.

    blender -b --factory-startup --python-exit-code 1 -P tools/stage/act1_set.py -- --out <dir>

Everything here is built from primitives in this file (plus tools/bakery/props.py for the HUD
icons): no imported scenes, no hand-painted art. One orthographic camera, tilted 10 degrees down so
the floorboards read, at exactly the cast's on-screen scale (1 Hush model unit = 128 logical px; the
baked sheets are drawn at 1.6x), so the actors stand in the room at the right size.

Output (raw, full-frame RGBA PNGs; tools/stage/build.py crops them and writes the json):
  bg.png         the room, everything static behind the actors
  fg_*.png       things in front of the actors (the plant Hush hides behind)
  prop_*.png     things that move or change (door, trophy stand, trophy, butter, glove, spring,
                 dumbbells, the rig stamp) -- each rendered alone, pivot recorded in pixels
  frame.png      the proscenium (gold arch + velvet valance), drawn over everything
  curtain_l/r    the house curtains, closed (the game slides them)
  audience.png   the front row of the Stalls in silhouette
  icon_*.png     HUD icons on their own camera
  marks.json     named positions in pixels (where things are, where actors stand)
"""
from __future__ import annotations

import json
import math
import os
import sys

import bmesh  # type: ignore
import bpy  # type: ignore
from bpy_extras.object_utils import world_to_camera_view  # type: ignore
from mathutils import Euler, Matrix, Vector  # type: ignore

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "bakery"))
sys.path.insert(0, os.path.join(HERE, "..", "art3d", "look-toy"))

W, H = 2400, 1080
PX = 128.0                   # px per unit (Hush model units)
TILT = math.radians(10.0)
STAGE_Y = 1.3                # depth of the line the actors walk on
FLOOR_PX = 880.0             # where that line lands on screen
WALL_Y = 4.0                 # back wall face

# ---------------------------------------------------------------------------------------------
# palette: warm, saturated, and kept clear of the cast (Hush navy/white/cherry, Gus green/orange)
C = {
	"paper": "#F1DDB0", "paper2": "#E7CC95", "panel": "#7A4A33", "panel_dk": "#5E3826",
	"trim": "#F7EBD0", "plank": "#B97A4B", "plank2": "#A86A3E", "plank_gap": "#6E4127",
	"rug": "#B7354A", "rug2": "#E6A93A", "rug3": "#7B2034",
	"gold": "#E2AE3A", "gold_dk": "#A97A1E", "brass": "#D6A13A",
	"wood": "#8A5534", "wood_dk": "#5C3620", "wood_lt": "#B07A4E",
	"velvet": "#C0283A", "velvet_dk": "#8C1828", "plum": "#6C3A73", "plum_dk": "#4E2654",
	"teal": "#2E7C86", "teal_dk": "#1F5A63", "cream": "#FFF4DE", "ink": "#2A2036",
	"sky": "#8FD3F2", "sky2": "#CBEFFF", "lawn": "#62B84A", "lawn2": "#55A641", "hedge": "#2F8A3E",
	"white": "#FFFFFF", "steel": "#B9C2CC", "steel_dk": "#6F7884", "iron": "#3C3F4A",
	"glove": "#D7263D", "glove_dk": "#A51A2E", "butter": "#FFD84A", "butter_hi": "#FFF0A0",
	"pot": "#C9643A", "pot_dk": "#A54F2C", "leaf": "#3E9A4B", "leaf2": "#2F7E3D",
	"marble": "#E9E4F2", "marble_dk": "#C7C0D6", "black": "#1E1A24", "lamp": "#FFE3A3",
	"crowd": "#2A1730", "crowd2": "#3A2142", "ice": "#9FE3FF", "ice_dk": "#4FB4E6",
	"stage": "#3B2318", "stage_lip": "#5A3624", "bulb": "#FFE7A8", "skin": "#D99A6C",
	"paper_dot": "#D8B474", "tracksuit": "#3FA34D", "paper_w": "#FBF6EA", "rosette": "#2F8A3E",
}


def lin(h: str) -> tuple[float, float, float, float]:
	h = h.lstrip("#")

	def f(c: float) -> float:
		return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
	return (f(int(h[0:2], 16) / 255), f(int(h[2:4], 16) / 255), f(int(h[4:6], 16) / 255), 1.0)


_M: dict = {}


def mat(key: str, rough: float = 0.8, emit: float = 0.0, metal: float = 0.0):
	name = f"{key}_{rough}_{emit}_{metal}"
	if name in _M:
		return _M[name]
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = m.node_tree.nodes["Principled BSDF"]
	col = lin(C.get(key, key))
	b.inputs["Base Color"].default_value = col
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metal
	if emit > 0:
		b.inputs["Emission Color"].default_value = col
		b.inputs["Emission Strength"].default_value = emit
	_M[name] = m
	return m


def mat_bands(a: str, b: str, freq: float, axis: int = 0, name: str = "bands", emit: float = 0.0):
	"""Two-colour stripes in OBJECT space, `freq` stripes per unit along `axis`."""
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	bs = nt.nodes["Principled BSDF"]
	bs.inputs["Roughness"].default_value = 0.85
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	mul = nt.nodes.new("ShaderNodeMath")
	mul.operation = "MULTIPLY"
	mul.inputs[1].default_value = freq
	mod = nt.nodes.new("ShaderNodeMath")
	mod.operation = "FLOORED_MODULO"
	mod.inputs[1].default_value = 1.0
	gt = nt.nodes.new("ShaderNodeMath")
	gt.operation = "GREATER_THAN"
	gt.inputs[1].default_value = 0.5
	mix = nt.nodes.new("ShaderNodeMix")
	mix.data_type = "RGBA"
	mix.inputs[6].default_value = lin(C[a])
	mix.inputs[7].default_value = lin(C[b])
	nt.links.new(tc.outputs["Object"], sep.inputs[0])
	nt.links.new(sep.outputs[axis], mul.inputs[0])
	nt.links.new(mul.outputs[0], mod.inputs[0])
	nt.links.new(mod.outputs[0], gt.inputs[0])
	nt.links.new(gt.outputs[0], mix.inputs[0])
	nt.links.new(mix.outputs[2], bs.inputs["Base Color"])
	if emit:
		nt.links.new(mix.outputs[2], bs.inputs["Emission Color"])
		bs.inputs["Emission Strength"].default_value = emit
	return m


def mat_wallpaper():
	"""Regency stripes with a small diamond motif in the light stripe, in OBJECT space."""
	m = bpy.data.materials.new("wallpaper")
	m.use_nodes = True
	nt = m.node_tree
	bs = nt.nodes["Principled BSDF"]
	bs.inputs["Roughness"].default_value = 0.85
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["Object"], sep.inputs[0])

	def math_node(op, a, b=None):
		n = nt.nodes.new("ShaderNodeMath")
		n.operation = op
		for i, v in enumerate((a, b)):
			if v is None:
				continue
			if isinstance(v, (int, float)):
				n.inputs[i].default_value = float(v)
			else:
				nt.links.new(v, n.inputs[i])
		return n.outputs[0]
	x, z = sep.outputs[0], sep.outputs[2]
	stripe = math_node("GREATER_THAN", math_node("FLOORED_MODULO", math_node("MULTIPLY", x, 1.6), 1.0), 0.5)
	# motif: a diamond (|u| + |v| < r) centred in every light stripe, staggered rows
	u = math_node("SUBTRACT", math_node("FLOORED_MODULO", math_node("MULTIPLY", x, 1.6), 1.0), 0.25)
	row = math_node("FLOORED_MODULO", math_node("MULTIPLY", z, 1.25), 1.0)
	v = math_node("SUBTRACT", row, 0.5)
	dia = math_node("LESS_THAN", math_node("ADD", math_node("ABSOLUTE", math_node("MULTIPLY", u, 1.0)),
										 math_node("ABSOLUTE", math_node("MULTIPLY", v, 0.55))), 0.09)
	dot = math_node("MULTIPLY", dia, math_node("SUBTRACT", 1.0, stripe))
	mix1 = nt.nodes.new("ShaderNodeMix")
	mix1.data_type = "RGBA"
	mix1.inputs[6].default_value = lin(C["paper"])
	mix1.inputs[7].default_value = lin(C["paper2"])
	nt.links.new(stripe, mix1.inputs[0])
	mix2 = nt.nodes.new("ShaderNodeMix")
	mix2.data_type = "RGBA"
	nt.links.new(mix1.outputs[2], mix2.inputs[6])
	mix2.inputs[7].default_value = lin(C["paper_dot"])
	nt.links.new(dot, mix2.inputs[0])
	nt.links.new(mix2.outputs[2], bs.inputs["Base Color"])
	return m


def mat_planks():
	m = bpy.data.materials.new("planks")
	m.use_nodes = True
	nt = m.node_tree
	bs = nt.nodes["Principled BSDF"]
	bs.inputs["Roughness"].default_value = 0.32
	tc = nt.nodes.new("ShaderNodeTexCoord")
	br = nt.nodes.new("ShaderNodeTexBrick")
	br.inputs["Color1"].default_value = lin(C["plank"])
	br.inputs["Color2"].default_value = lin(C["plank2"])
	br.inputs["Mortar"].default_value = lin(C["plank_gap"])
	br.inputs["Scale"].default_value = 1.0
	br.inputs["Mortar Size"].default_value = 0.025
	br.inputs["Brick Width"].default_value = 3.1
	br.inputs["Row Height"].default_value = 0.42
	br.offset = 0.37
	nt.links.new(tc.outputs["Object"], br.inputs["Vector"])
	# grain: stretched noise darkens the planks a little along their length
	mp = nt.nodes.new("ShaderNodeMapping")
	mp.inputs["Scale"].default_value = (0.6, 9.0, 1.0)
	nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
	nz = nt.nodes.new("ShaderNodeTexNoise")
	nz.inputs["Scale"].default_value = 3.0
	nz.inputs["Detail"].default_value = 4.0
	nt.links.new(mp.outputs[0], nz.inputs["Vector"])
	mx = nt.nodes.new("ShaderNodeMix")
	mx.data_type = "RGBA"
	mx.blend_type = "MULTIPLY"
	mx.inputs[0].default_value = 0.35
	nt.links.new(br.outputs["Color"], mx.inputs[6])
	nt.links.new(nz.outputs["Color"], mx.inputs[7])
	nt.links.new(mx.outputs[2], bs.inputs["Base Color"])
	return m


# ---------------------------------------------------------------------------------------------
COLL: dict = {}


def coll(name: str):
	if name not in COLL:
		c = bpy.data.collections.new(name)
		bpy.context.scene.collection.children.link(c)
		COLL[name] = c
	return COLL[name]


def put(name: str, bm, m, where: str, loc=(0, 0, 0), rot=(0, 0, 0), bevel: float = 0.0,
		smooth: bool = False, sharp: float = 40.0):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	me.materials.append(m)
	if smooth:
		for p in me.polygons:
			p.use_smooth = True
		try:
			me.set_sharp_from_angle(angle=math.radians(sharp))
		except Exception:
			pass
	o = bpy.data.objects.new(name, me)
	coll(where).objects.link(o)
	o.location = Vector(loc)
	o.rotation_euler = Euler([math.radians(v) for v in rot], "XYZ")
	if bevel > 0:
		md = o.modifiers.new("bevel", "BEVEL")
		md.width = bevel
		md.segments = 3
		md.limit_method = "ANGLE"
	return o


def box(name, size, loc, m, where="bg", bevel=0.03, rot=(0, 0, 0)):
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
	return put(name, bm, m, where, loc, rot, bevel)


def cyl(name, r, h, loc, m, where="bg", r2=None, seg=28, rot=(0, 0, 0), smooth=True):
	"""Cylinder/cone standing on `loc` (its base), axis +Z before `rot`."""
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r,
						  radius2=r if r2 is None else r2, depth=h)
	bmesh.ops.translate(bm, vec=Vector((0, 0, h / 2)), verts=bm.verts)
	return put(name, bm, m, where, loc, rot, 0.0, smooth)


def sph(name, r, loc, m, where="bg", scale=(1, 1, 1), seg=24, rot=(0, 0, 0)):
	bm = bmesh.new()
	bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(8, seg // 2), radius=r)
	bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
	return put(name, bm, m, where, loc, rot, 0.0, True, sharp=180)


def torus(name, R, r, loc, m, where="bg", rot=(0, 0, 0), seg=24, rseg=10):
	bm = bmesh.new()
	for i in range(seg):
		a = 2 * math.pi * i / seg
		for j in range(rseg):
			b = 2 * math.pi * j / rseg
			bm.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
	bm.verts.ensure_lookup_table()
	for i in range(seg):
		for j in range(rseg):
			a = i * rseg + j
			b = ((i + 1) % seg) * rseg + j
			c = ((i + 1) % seg) * rseg + (j + 1) % rseg
			d = i * rseg + (j + 1) % rseg
			bm.faces.new((bm.verts[a], bm.verts[b], bm.verts[c], bm.verts[d]))
	return put(name, bm, m, where, loc, rot, 0.0, True, sharp=180)


def prism(name, pts2d, depth, loc, m, where="bg", rot=(90, 0, 0), bevel=0.0):
	"""Extrude a 2D outline (x, y) by `depth`; default rot stands it up facing the camera."""
	bm = bmesh.new()
	vs = [bm.verts.new((x, y, 0)) for x, y in pts2d]
	f = bm.faces.new(vs)
	ext = bmesh.ops.extrude_face_region(bm, geom=[f])
	bmesh.ops.translate(bm, vec=Vector((0, 0, depth)),
						verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	return put(name, bm, m, where, loc, rot, bevel)


def star_pts(n, r1, r2, phase=math.pi / 2):
	out = []
	for i in range(n * 2):
		r = r1 if i % 2 == 0 else r2
		a = phase + math.pi * i / n
		out.append((r * math.cos(a), r * math.sin(a)))
	return out


# ---------------------------------------------------------------------------------------------
# the room
def build_room() -> dict:
	marks: dict = {}
	# back wall: wallpaper above, wood wainscot below, a dado rail between
	wall = box("wall", (19.6, 0.3, 7.6), (0, WALL_Y + 0.15, 3.8), mat_wallpaper(), bevel=0)
	box("picture_rail", (19.6, 0.12, 0.07), (0, WALL_Y - 0.06, 6.15), mat("trim", 0.6), bevel=0.02)
	box("wainscot", (19.6, 0.12, 1.55), (0, WALL_Y - 0.05, 0.78), mat("panel", 0.7), bevel=0.01)
	for i in range(16):
		x = -9.0 + i * 1.22
		box(f"wpanel{i}", (0.95, 0.06, 1.05), (x, WALL_Y - 0.13, 0.78), mat("panel_dk", 0.7), bevel=0.02)
	box("dado", (19.6, 0.2, 0.12), (0, WALL_Y - 0.12, 1.58), mat("trim", 0.6), bevel=0.03)
	box("skirting", (19.6, 0.22, 0.22), (0, WALL_Y - 0.13, 0.11), mat("trim", 0.6), bevel=0.03)
	box("cornice", (19.6, 0.4, 0.3), (0, WALL_Y - 0.1, 7.15), mat("trim", 0.6), bevel=0.06)
	# floor + rug
	floor = box("floor", (19.6, 6.0, 0.2), (0, 1.0, -0.1), mat_planks(), bevel=0)
	cyl("rug", 2.0, 0.03, (0.4, 2.0, 0.0), mat("rug2", 0.9), seg=64)
	cyl("rug_in", 1.82, 0.04, (0.4, 2.0, 0.0), mat("rug", 0.9), seg=64)
	cyl("rug_core", 1.0, 0.05, (0.4, 2.0, 0.0), mat("rug3", 0.9), seg=48)
	for o in ("rug", "rug_in", "rug_core"):
		bpy.data.objects[o].scale = (1.0, 0.42, 1.0)
	# stage apron (the house is a set on a stage): front face + gold lip + footlights
	box("apron", (19.6, 0.4, 3.0), (0, -1.7, -1.5), mat("stage", 0.6), bevel=0)
	box("apron_lip", (19.6, 0.5, 0.12), (0, -1.55, -0.06), mat("gold", 0.35, 0, 0.6), bevel=0.04)
	for i in range(11):
		x = -7.5 + i * 1.5
		sph(f"foot{i}", 0.13, (x, -1.82, -0.18), mat("bulb", 0.3, 4.0), scale=(1.3, 1, 0.8))
		box(f"foothood{i}", (0.42, 0.18, 0.12), (x, -1.9, -0.06), mat("gold_dk", 0.4, 0, 0.6), bevel=0.03)

	# --- window with the lawn outside (he inspects it; it is immaculate) ---
	wx, wz, ww, wh = 2.5, 3.6, 3.2, 2.6
	box("win_sky", (ww, 0.04, wh), (wx, WALL_Y - 0.02, wz), mat("sky", 0.9, 0.55), bevel=0)
	sph("win_sun", 0.32, (wx + 0.9, WALL_Y - 0.05, wz + 0.8), mat("butter_hi", 0.9, 1.4), scale=(1, 0.2, 1))
	for i, (cx, cz, s) in enumerate([(-0.9, 0.85, 0.36), (-0.55, 0.9, 0.3), (-1.15, 0.8, 0.26), (0.3, 1.05, 0.24)]):
		sph(f"cloud{i}", s, (wx + cx, WALL_Y - 0.05, wz + cz), mat("white", 0.9, 0.7), scale=(1.4, 0.2, 0.8))
	box("win_lawn", (ww, 0.06, 0.9), (wx, WALL_Y - 0.06, wz - wh / 2 + 0.45), mat_bands("lawn", "lawn2", 2.2, 0, "lawn", 0.3), bevel=0)
	for i in range(7):
		sph(f"hedge{i}", 0.36, (wx - 1.4 + i * 0.47, WALL_Y - 0.08, wz - 0.25), mat("hedge", 0.9, 0.25), scale=(1, 0.25, 0.85))
	for i in range(11):
		x = wx - 1.5 + i * 0.3
		prism(f"picket{i}", [(-0.06, 0), (0.06, 0), (0.06, 0.42), (0, 0.5), (-0.06, 0.42)], 0.03,
			  (x, WALL_Y - 0.1, wz - wh / 2 + 0.55), mat("white", 0.8, 0.3))
	box("fence_rail", (ww, 0.03, 0.06), (wx, WALL_Y - 0.12, wz - wh / 2 + 0.78), mat("white", 0.8, 0.3), bevel=0)
	# frame, mullions, sill
	fm = mat("cream", 0.6)
	box("win_top", (ww + 0.36, 0.26, 0.18), (wx, WALL_Y - 0.18, wz + wh / 2 + 0.09), fm)
	box("win_bot", (ww + 0.6, 0.42, 0.16), (wx, WALL_Y - 0.25, wz - wh / 2 - 0.08), fm)
	box("win_l", (0.18, 0.26, wh + 0.2), (wx - ww / 2 - 0.09, WALL_Y - 0.18, wz), fm)
	box("win_r", (0.18, 0.26, wh + 0.2), (wx + ww / 2 + 0.09, WALL_Y - 0.18, wz), fm)
	box("win_mv", (0.09, 0.14, wh), (wx, WALL_Y - 0.15, wz), fm)
	box("win_mh", (ww, 0.14, 0.09), (wx, WALL_Y - 0.15, wz + 0.25), fm)
	# drapes, tied back, and a pelmet
	for side in (-1, 1):
		for k in range(5):
			x = wx + side * (ww / 2 + 0.25 + k * 0.13)
			cyl(f"drape{side}{k}", 0.13, 3.4, (x, WALL_Y - 0.42 - (k % 2) * 0.05, wz - 1.75), mat("teal" if k % 2 else "teal_dk", 0.9), seg=12)
		box(f"tie{side}", (0.75, 0.2, 0.1), (wx + side * (ww / 2 + 0.5), WALL_Y - 0.6, wz - 0.4), mat("gold", 0.4, 0, 0.5), bevel=0.03)
	box("pelmet", (ww + 1.9, 0.5, 0.45), (wx, WALL_Y - 0.4, wz + wh / 2 + 0.42), mat("teal_dk", 0.85), bevel=0.06)
	box("pelmet_trim", (ww + 1.95, 0.52, 0.08), (wx, WALL_Y - 0.42, wz + wh / 2 + 0.2), mat("gold", 0.4, 0, 0.5), bevel=0.02)
	marks["window"] = (wx, WALL_Y, wz)

	# --- door (stage left): Hush's way in ---
	dx, dw, dh = -7.6, 1.7, 4.4
	box("doorway", (dw, 0.1, dh), (dx, WALL_Y - 0.02, dh / 2), mat("#3A2433", 0.9), bevel=0)
	for side in (-1, 1):
		box(f"door_jamb{side}", (0.2, 0.3, dh + 0.1), (dx + side * (dw / 2 + 0.1), WALL_Y - 0.15, dh / 2), fm)
	box("door_head", (dw + 0.6, 0.34, 0.26), (dx, WALL_Y - 0.17, dh + 0.13), fm)
	marks["door"] = (dx, STAGE_Y, 0)

	# --- portrait of Gus (painted by himself, probably) ---
	px_, pz = -4.3, 4.4
	box("portrait_frame", (1.5, 0.12, 1.9), (px_, WALL_Y - 0.08, pz), mat("gold", 0.35, 0, 0.7), bevel=0.06)
	box("portrait_bg", (1.2, 0.04, 1.6), (px_, WALL_Y - 0.15, pz), mat("plum", 0.9), bevel=0)
	sph("p_body", 0.42, (px_, WALL_Y - 0.18, pz - 0.45), mat("lawn2", 0.9), scale=(1.25, 0.2, 0.9))
	sph("p_head", 0.22, (px_, WALL_Y - 0.2, pz + 0.18), mat("skin", 0.9), scale=(1, 0.2, 1.1))
	box("p_hair", (0.42, 0.04, 0.12), (px_, WALL_Y - 0.22, pz + 0.4), mat("#3B2A20", 0.9), bevel=0)
	for side in (-1, 1):
		sph(f"p_arm{side}", 0.15, (px_ + side * 0.48, WALL_Y - 0.2, pz - 0.05), mat("skin", 0.9), scale=(1, 0.2, 1.3))
	box("p_tache", (0.26, 0.04, 0.05), (px_, WALL_Y - 0.22, pz + 0.1), mat("#3B2A20", 0.9), bevel=0)

	# --- wall clock ---
	cyl("clock", 0.5, 0.12, (-1.0, WALL_Y - 0.05, 5.4), mat("wood", 0.6), rot=(90, 0, 0), seg=40)
	cyl("clock_face", 0.42, 0.06, (-1.0, WALL_Y - 0.13, 5.4), mat("cream", 0.6), rot=(90, 0, 0), seg=40)
	box("clock_h1", (0.05, 0.03, 0.28), (-1.0, WALL_Y - 0.2, 5.5), mat("ink"), bevel=0, rot=(0, 30, 0))
	box("clock_h2", (0.04, 0.03, 0.36), (-0.92, WALL_Y - 0.21, 5.38), mat("ink"), bevel=0, rot=(0, 120, 0))

	# --- armchair + floor lamp (decor, upstage) ---
	ax, ay = -1.2, 3.1
	box("chair_seat", (1.8, 1.2, 0.5), (ax, ay, 0.55), mat("plum", 0.9), bevel=0.15)
	box("chair_back", (1.8, 0.45, 1.6), (ax, ay + 0.5, 1.3), mat("plum", 0.9), bevel=0.2)
	for side in (-1, 1):
		box(f"chair_arm{side}", (0.4, 1.25, 0.95), (ax + side * 0.95, ay - 0.02, 0.85), mat("plum_dk", 0.9), bevel=0.15)
		for fy in (-0.45, 0.45):
			cyl(f"chair_leg{side}{fy}", 0.07, 0.3, (ax + side * 0.8, ay + fy, 0.0), mat("wood_dk", 0.6), seg=10)
	box("chair_cushion", (1.2, 1.0, 0.25), (ax, ay - 0.05, 0.88), mat("plum", 0.9), bevel=0.1)
	lx, ly = -2.65, 3.2
	cyl("lamp_base", 0.3, 0.08, (lx, ly, 0.0), mat("brass", 0.35, 0, 0.7))
	cyl("lamp_pole", 0.04, 3.3, (lx, ly, 0.08), mat("brass", 0.35, 0, 0.7), seg=10)
	cyl("lamp_shade", 0.55, 0.65, (lx, ly, 3.2), mat("lamp", 0.8, 1.5), r2=0.32, seg=32)
	marks["lamp"] = (lx, ly, 3.5)

	# --- gramophone on its table (the finale) ---
	gx, gy = -4.3, 2.5
	cyl("gtable_top", 0.75, 0.1, (gx, gy, 1.3), mat("wood", 0.6), seg=36)
	cyl("gtable_leg", 0.09, 1.3, (gx, gy, 0.0), mat("wood_dk", 0.6), seg=12)
	cyl("gtable_foot", 0.45, 0.08, (gx, gy, 0.0), mat("wood_dk", 0.6), seg=24)
	box("gram_box", (0.95, 0.75, 0.5), (gx, gy, 1.65), mat("wood_lt", 0.5), bevel=0.05)
	cyl("gram_disc", 0.38, 0.04, (gx, gy, 1.9), mat("black", 0.3), seg=36)
	cyl("gram_arm", 0.05, 0.55, (gx + 0.2, gy + 0.1, 1.95), mat("brass", 0.35, 0, 0.7), rot=(0, 70, 0), seg=10)
	cyl("gram_crank", 0.035, 0.35, (gx - 0.47, gy - 0.1, 1.6), mat("brass", 0.35, 0, 0.7), rot=(0, -90, 0), seg=8)
	sph("gram_knob", 0.07, (gx - 0.84, gy - 0.1, 1.6), mat("wood_dk", 0.5))
	# the horn rises and opens toward stage right
	cyl("gram_neck", 0.09, 0.9, (gx + 0.15, gy, 1.85), mat("brass", 0.3, 0, 0.8), r2=0.16, rot=(0, 40, 0), seg=20)
	horn = cyl("gram_horn", 0.16, 0.9, (gx + 0.73, gy, 2.55), mat("brass", 0.3, 0, 0.8), r2=0.85, rot=(0, 55, 0), seg=40)
	mouth = Vector((gx + 0.73, gy, 2.55)) + Euler((0, math.radians(55), 0)).to_matrix() @ Vector((0, 0, 0.9))
	marks["horn"] = tuple(mouth)
	marks["gramophone"] = (gx, STAGE_Y, 0)

	# --- mirror on a stand (he lives here) ---
	mx, my = 5.0, 2.7
	torus("mirror_frame", 0.95, 0.12, (mx, my, 2.75), mat("gold", 0.3, 0, 0.8), rot=(90, 0, 0), seg=48)
	bpy.data.objects["mirror_frame"].scale = (0.78, 1.0, 1.3)
	cyl("mirror_glass", 0.95, 0.05, (mx, my + 0.02, 2.75), mat("#CDE8F5", 0.05, 0.25, 0.3), rot=(90, 0, 0), seg=48)
	bpy.data.objects["mirror_glass"].scale = (0.78, 1.3, 1.0)
	sph("mirror_glint", 0.18, (mx - 0.3, my - 0.08, 3.3), mat("white", 0.5, 1.0), scale=(0.6, 0.1, 1.2), rot=(0, -25, 0))
	for side in (-1, 1):
		box(f"mirror_leg{side}", (0.12, 0.12, 1.6), (mx + side * 0.45, my + 0.2, 0.75), mat("gold_dk", 0.4, 0, 0.6), rot=(0, side * -14, 0), bevel=0.02)
	marks["mirror"] = (mx, STAGE_Y, 0)

	# --- weight rack (the finale's landing) ---
	rx, ry = 7.6, 2.9
	for side in (-1, 1):
		box(f"rack_post{side}", (0.16, 0.16, 2.2), (rx + side * 0.8, ry, 1.1), mat("iron", 0.5, 0, 0.5), bevel=0.03)
		box(f"rack_foot{side}", (0.2, 0.9, 0.1), (rx + side * 0.8, ry, 0.05), mat("iron", 0.5, 0, 0.5), bevel=0.03)
	for z in (0.7, 1.35, 2.0):
		box(f"rack_bar{z}", (1.8, 0.5, 0.08), (rx, ry - 0.05, z), mat("iron", 0.5, 0, 0.5), bevel=0.02)
	marks["rack"] = (rx, STAGE_Y, 0)
	# trophy shelf on the wall above the rack: the man's whole personality
	box("shelf", (2.4, 0.4, 0.1), (rx, WALL_Y - 0.2, 4.6), mat("wood", 0.6), bevel=0.02)
	for i, x in enumerate((-0.8, 0.0, 0.8)):
		h = (0.55, 0.8, 0.55)[i]
		cyl(f"stro_base{i}", 0.15, 0.12, (rx + x, WALL_Y - 0.25, 4.65), mat("wood_dk", 0.6), seg=16)
		cyl(f"stro_cup{i}", 0.08, h, (rx + x, WALL_Y - 0.25, 4.77), mat("gold", 0.3, 0, 0.8), r2=0.2, seg=20)
	box("plaque", (1.6, 0.06, 0.55), (rx, WALL_Y - 0.08, 5.55), mat("wood_dk", 0.6), bevel=0.03)
	box("plaque_g", (1.3, 0.04, 0.32), (rx, WALL_Y - 0.12, 5.55), mat("gold", 0.35, 0, 0.7), bevel=0.01)
	# kettlebells on the floor
	for i, x in enumerate((6.4, 8.7)):
		sph(f"kb{i}", 0.32, (x, 2.3, 0.3), mat("iron", 0.45, 0, 0.5))
		torus(f"kbh{i}", 0.2, 0.05, (x, 2.3, 0.65), mat("iron", 0.45, 0, 0.5), rot=(90, 0, 0))

	# --- dressing: the details that make it a home (and a very specific man's home) ---
	# ceiling lamp hanging into the room, centre
	cyl("pend_rod", 0.03, 1.6, (0.4, 2.6, 5.4), mat("brass", 0.35, 0, 0.7), seg=8)
	cyl("pend_shade", 0.7, 0.45, (0.4, 2.6, 5.0), mat("lamp", 0.7, 1.2), r2=0.18, seg=32)
	sph("pend_bulb", 0.16, (0.4, 2.6, 4.97), mat("bulb", 0.3, 6.0))
	marks["pendant"] = (0.4, 2.6, 4.95)
	# wall sconces either side of the portrait
	for i, x in enumerate((-5.55, -3.05)):
		box(f"sconce_plate{i}", (0.16, 0.06, 0.34), (x, WALL_Y - 0.05, 4.35), mat("brass", 0.35, 0, 0.7), bevel=0.02)
		cyl(f"sconce_arm{i}", 0.025, 0.32, (x, WALL_Y - 0.08, 4.3), mat("brass", 0.35, 0, 0.7), rot=(90, 0, 0), seg=8)
		cyl(f"sconce_shade{i}", 0.1, 0.24, (x, WALL_Y - 0.38, 4.3), mat("lamp", 0.7, 2.0), r2=0.17, seg=16)
	# coat stand by the door, his tracksuit top on it
	csx, csy = -6.15, 3.3
	cyl("coat_base", 0.32, 0.06, (csx, csy, 0), mat("wood_dk", 0.6), seg=20)
	cyl("coat_pole", 0.05, 3.6, (csx, csy, 0.06), mat("wood_dk", 0.6), seg=10)
	sph("coat_knob", 0.09, (csx, csy, 3.7), mat("wood_dk", 0.6))
	for a in (-40, 40):
		cyl(f"coat_hook{a}", 0.025, 0.35, (csx, csy, 3.35), mat("wood_dk", 0.6), rot=(0, a, 0), seg=6)
	box("coat_top", (0.75, 0.25, 1.2), (csx + 0.08, csy - 0.12, 2.75), mat("tracksuit", 0.8), bevel=0.12, rot=(0, -4, 0))
	box("coat_stripe", (0.06, 0.27, 1.15), (csx + 0.32, csy - 0.13, 2.75), mat("white", 0.8), bevel=0.02, rot=(0, -4, 0))
	cyl("coat_cap", 0.27, 0.18, (csx - 0.05, csy - 0.05, 3.55), mat("teal_dk", 0.8), seg=20, rot=(0, -10, 0))
	# side table by the armchair: protein shaker and a stopwatch on a doily
	tx, ty = 0.15, 3.0
	cyl("stab_top", 0.4, 0.06, (tx, ty, 1.0), mat("wood", 0.5), seg=24)
	cyl("stab_leg", 0.05, 1.0, (tx, ty, 0.0), mat("wood_dk", 0.6), seg=10)
	cyl("stab_doily", 0.3, 0.01, (tx, ty, 1.06), mat("white", 0.9), seg=24)
	cyl("shaker", 0.11, 0.42, (tx - 0.08, ty, 1.07), mat("tracksuit", 0.35), r2=0.13, seg=16)
	cyl("shaker_lid", 0.13, 0.08, (tx - 0.08, ty, 1.49), mat("white", 0.5), seg=16)
	# certificate on the wall: he framed it
	cfx, cfz = 5.0, 4.85
	box("cert_frame", (1.5, 0.08, 1.05), (cfx, WALL_Y - 0.05, cfz), mat("wood_dk", 0.5), bevel=0.04)
	box("cert_paper", (1.3, 0.04, 0.85), (cfx, WALL_Y - 0.1, cfz), mat("paper_w", 0.9), bevel=0)
	for i, (txt, sz, dz) in enumerate((("LAWN INSPECTOR", 0.13, 0.2), ("OF THE YEAR", 0.13, 0.03), ("G. THUDD", 0.1, -0.2))):
		cu = bpy.data.curves.new(f"cert_t{i}", "FONT")
		cu.body = txt
		cu.size = sz
		cu.align_x = "CENTER"
		cu.extrude = 0.005
		ob = bpy.data.objects.new(f"cert_t{i}", cu)
		coll("bg").objects.link(ob)
		ob.data.materials.append(mat("ink", 0.8))
		ob.location = (cfx, WALL_Y - 0.13, cfz + dz)
		ob.rotation_euler = Euler((math.radians(90), 0, 0))
	cyl("rosette", 0.13, 0.03, (cfx + 0.48, WALL_Y - 0.13, cfz - 0.25), mat("rosette", 0.6), rot=(90, 0, 0), seg=16)
	# a cactus on the window sill (a lawn man's idea of a joke)
	cyl("cact_pot", 0.13, 0.18, (3.6, WALL_Y - 0.3, 2.3), mat("pot", 0.7), r2=0.16, seg=14)
	sph("cact", 0.12, (3.6, WALL_Y - 0.3, 2.62), mat("leaf2", 0.7), scale=(1, 1, 1.9))
	# socket + switch: scale cues
	box("socket", (0.22, 0.04, 0.16), (-2.0, WALL_Y - 0.18, 0.45), mat("white", 0.5), bevel=0.02)
	box("switch", (0.14, 0.04, 0.2), (-6.5, WALL_Y - 0.06, 2.3), mat("white", 0.5), bevel=0.02)
	return marks



def build_props() -> dict:
	"""Things that move or change state, each in its own collection (rendered alone)."""
	piv: dict = {}
	# butter: a pat and a long glossy smear on the walking line
	bx = 3.9
	sph("butter_smear", 0.6, (bx, STAGE_Y, 0.0), mat("butter", 0.12), "prop_butter", scale=(1.6, 0.6, 0.06))
	sph("butter_hi", 0.25, (bx - 0.3, STAGE_Y - 0.1, 0.03), mat("butter_hi", 0.1, 0.4), "prop_butter", scale=(1.4, 0.5, 0.05))
	box("butter_pat", (0.42, 0.28, 0.22), (bx + 0.7, STAGE_Y + 0.1, 0.11), mat("butter", 0.3), "prop_butter", bevel=0.05)
	piv["butter"] = (bx, STAGE_Y, 0)

	# the plant Hush hides behind (in FRONT of the walking line)
	px_, py = -6.0, 0.55
	cyl("pot", 0.55, 1.0, (px_, py, 0), mat("pot", 0.7), "fg_plant", r2=0.7, seg=28)
	cyl("pot_rim", 0.76, 0.18, (px_, py, 1.0), mat("pot_dk", 0.7), "fg_plant", seg=28)
	import random
	rnd = random.Random(4)
	for i in range(26):
		a = rnd.uniform(-1.15, 1.15)
		ln = rnd.uniform(1.2, 2.3)
		cx = px_ + math.sin(a) * ln * 0.55
		cz = 1.15 + math.cos(a) * ln * 0.8 + 0.4
		sph(f"leaf{i}", 0.42, (cx, py + rnd.uniform(-0.25, 0.25), cz), mat("leaf" if i % 3 else "leaf2", 0.7),
			"fg_plant", scale=(0.45, 0.25, 1.15), rot=(rnd.uniform(-15, 15), math.degrees(a), 0))
	piv["plant"] = (px_, STAGE_Y, 0)

	# Hush's beret stamp: the GDD mark on an armed prank
	sph("stamp_b", 0.28, (0, 0, 0), mat("velvet", 0.6), "icon_stamp", scale=(1.2, 1.0, 0.35), rot=(0, -12, 0))
	sph("stamp_s", 0.05, (0.02, 0, 0.1), mat("velvet", 0.6), "icon_stamp")
	return piv


# ---------------------------------------------------------------------------------------------
# sequences: props that MOVE, animated in 3D here and rendered frame by frame, so a topple, a
# tumble or a swing is lit and foreshortened correctly instead of being a flat sprite turned in 2D.
def group(name: str, where: str, loc) -> "bpy.types.Object":
	e = bpy.data.objects.new(name, None)
	coll(where).objects.link(e)
	e.location = Vector(loc)
	return e


def child(o, parent) -> None:
	mw = o.matrix_world.copy()
	o.parent = parent
	o.matrix_parent_inverse = parent.matrix_world.inverted()
	o.matrix_world = mw


def ease_in(s: float) -> float:
	return s * s


def build_seqs(piv: dict, marks: dict) -> dict:
	seqs: dict = {}
	bpy.context.view_layer.update()

	# --- the door swings open on its stage-left hinge ---
	dx, dw, dh = -7.6, 1.7, 4.4
	hinge = group("door_hinge", "seq_door", (dx - dw / 2, WALL_Y - 0.1, 0))
	bpy.context.view_layer.update()
	panel = box("door_panel", (dw, 0.12, dh), (dx, WALL_Y - 0.1, dh / 2), mat("teal_dk", 0.7), "seq_door", bevel=0.03)
	parts = [panel]
	for (px_, pz) in ((-0.4, 3.0), (0.4, 3.0), (-0.4, 1.1), (0.4, 1.1)):
		parts.append(box(f"door_p{px_}{pz}", (0.55, 0.05, 1.3 if pz < 2 else 1.6), (dx + px_, WALL_Y - 0.18, pz), mat("teal", 0.7), "seq_door", bevel=0.02))
	parts.append(sph("door_knob", 0.08, (dx + 0.65, WALL_Y - 0.24, 2.0), mat("brass", 0.3, 0, 0.8), "seq_door"))
	bpy.context.view_layer.update()
	for o in parts:
		child(o, hinge)
	angles = [0, -14, -30, -46, -62, -78]
	seqs["door"] = (len(angles), lambda k: setattr(hinge, "rotation_euler", Euler((0, 0, math.radians(angles[k])))))
	piv["door"] = (dx, WALL_Y, 0)

	# --- the trophy pedestal topples stage left about its base edge ---
	sx, sy = 2.3, 2.0
	ped = group("ped_pivot", "seq_pedestal", (sx - 0.42, sy, 0))
	bpy.context.view_layer.update()
	pp = [cyl("ped_base", 0.42, 0.18, (sx, sy, 0), mat("marble_dk", 0.4), "seq_pedestal", seg=8),
		  cyl("ped_col", 0.24, 1.7, (sx, sy, 0.18), mat("marble", 0.35), "seq_pedestal", r2=0.2, seg=8),
		  cyl("ped_top", 0.42, 0.16, (sx, sy, 1.88), mat("marble_dk", 0.4), "seq_pedestal", seg=8)]
	bpy.context.view_layer.update()
	for o in pp:
		child(o, ped)
	ped_ang = [0, -4, -12, -26, -46, -70, -90, -84, -90]
	seqs["pedestal"] = (len(ped_ang), lambda k: setattr(ped, "rotation_euler", Euler((0, math.radians(ped_ang[k]), 0))))
	piv["pedestal"] = (sx, sy, 0)

	# --- the trophy: flung up, spins, lands on his head, hops to the floor on its side ---
	tz = 2.04
	tro = group("tro_pivot", "seq_trophy", (sx, sy, tz + 0.6))
	bpy.context.view_layer.update()
	tp = [cyl("tro_base", 0.28, 0.22, (sx, sy, tz), mat("wood_dk", 0.5), "seq_trophy", seg=20),
		  cyl("tro_stem", 0.07, 0.35, (sx, sy, tz + 0.22), mat("gold", 0.25, 0, 0.85), "seq_trophy", seg=16),
		  cyl("tro_cup", 0.12, 0.7, (sx, sy, tz + 0.55), mat("gold", 0.25, 0, 0.85), "seq_trophy", r2=0.46, seg=32),
		  sph("tro_star", 0.1, (sx, sy - 0.25, tz + 0.9), mat("white", 0.3, 0.6), "seq_trophy", scale=(1, 0.3, 1))]
	for side in (-1, 1):
		tp.append(torus(f"tro_h{side}", 0.2, 0.045, (sx + side * 0.48, sy, tz + 0.95), mat("gold", 0.25, 0, 0.85), "seq_trophy", rot=(90, 0, 0)))
	bpy.context.view_layer.update()
	for o in tp:
		child(o, tro)
	start = Vector((sx, sy, tz + 0.6))
	head = Vector((3.62, 1.25, 1.0))
	floor_ = Vector((4.05, 1.15, 0.47))

	def tro_frame(k: int) -> None:
		if k <= 8:
			s_ = k / 8.0
			p = start.lerp(head, s_) + Vector((0, 0, 1.7 * 4 * s_ * (1 - s_)))
			r = -400.0 * s_
		else:
			s_ = (k - 8) / 3.0
			p = head.lerp(floor_, s_) + Vector((0, 0, 0.55 * 4 * s_ * (1 - s_)))
			r = -400.0 - 50.0 * s_
		tro.location = p
		tro.rotation_euler = Euler((0, math.radians(r), 0))
	seqs["trophy"] = (12, tro_frame)
	piv["trophy"] = tuple(start)
	piv["trophy_head"] = tuple(head)

	# --- three dumbbells: knocked off the rack, they rain down and roll ---
	rx, ry = 7.6, 2.9
	dbs = []
	for i, (x, z) in enumerate(((-0.45, 0.82), (0.45, 0.82), (0.0, 1.47))):
		g = group(f"db{i}", "seq_dumbbells", (rx + x, ry - 0.1, z + 0.16))
		bpy.context.view_layer.update()
		ps = [cyl(f"db{i}_bar", 0.05, 0.9, (rx + x - 0.45, ry - 0.1, z + 0.16), mat("steel", 0.3, 0, 0.8), "seq_dumbbells", rot=(0, 90, 0), seg=10)]
		for sd in (-1, 1):
			ps.append(cyl(f"db{i}_w{sd}", 0.17, 0.2, (rx + x + sd * 0.32 - 0.1, ry - 0.1, z + 0.16), mat("black", 0.45), "seq_dumbbells", rot=(0, 90, 0), seg=8))
		bpy.context.view_layer.update()
		for o in ps:
			child(o, g)
		dbs.append((g, Vector(g.location), Vector(((5.55, 6.15, 6.75)[i], (1.1, 0.95, 1.15)[i], 0.17)), (0, 2, 3)[i]))

	def db_frame(k: int) -> None:
		for g, a, b, delay in dbs:
			s_ = clamp01((k - delay) / 5.0)
			if s_ < 1.0:
				p = a.lerp(b, s_)
				p.z = a.z + (b.z - a.z) * ease_in(s_) + 0.6 * 4 * s_ * (1 - s_)
				r = 260.0 * s_
			else:
				h = clamp01((k - delay - 5) / 3.0)
				p = b + Vector((0.35 * h, 0, 0.3 * 4 * h * (1 - h)))
				r = 260.0 + 140.0 * h
			g.location = p
			g.rotation_euler = Euler((0, math.radians(r), 0))
	seqs["dumbbells"] = (12, db_frame)

	# --- the boxing glove on its spring, out of the horn ---
	horn = Vector(marks["horn"])
	d = Vector((math.cos(math.radians(-8)), 0, math.sin(math.radians(-8))))
	glove = group("glove", "seq_glove", horn)
	bpy.context.view_layer.update()
	gp = [sph("glove_fist", 0.42, horn + Vector((0.55, 0, 0)), mat("glove", 0.4), "seq_glove", scale=(1.15, 0.95, 0.95)),
		  sph("glove_thumb", 0.16, horn + Vector((0.55, -0.32, 0.22)), mat("glove", 0.4), "seq_glove", scale=(1.3, 1, 0.9)),
		  cyl("glove_cuff", 0.3, 0.35, horn + Vector((-0.1, 0, 0)), mat("white", 0.6), "seq_glove", rot=(0, 90, 0), seg=24),
		  sph("glove_hi", 0.12, horn + Vector((0.72, -0.3, 0.22)), mat("white", 0.5, 0.4), "seq_glove", scale=(1.2, 0.4, 0.8))]
	bpy.context.view_layer.update()
	for o in gp:
		child(o, glove)
	glove.rotation_euler = Euler((0, math.radians(8), 0))
	lens = [0.08, 0.4, 0.8, 1.2, 1.55, 1.72, 1.62]
	sm = mat("steel", 0.3, 0, 0.8)

	def glove_frame(k: int) -> None:
		L = lens[k]
		old = bpy.data.objects.get("spring")
		if old is not None:
			bpy.data.objects.remove(old, do_unlink=True)
		pts = []
		turns = 7
		for i in range(turns * 12 + 1):
			t = i / (turns * 12)
			a = 2 * math.pi * turns * t
			pts.append(horn + d * (L * t) + Vector((0, math.cos(a) * 0.13, math.sin(a) * 0.13)))
		import toy_lib as T  # noqa: E402
		bm = T.capsule_chain(pts, [0.028] * len(pts), "beret", seg=6, cap_rings=1, samples_per_m=160)
		put("spring", bm, sm, "seq_glove", (0, 0, 0), (0, 0, 0), 0, True)
		glove.location = horn + d * L
	seqs["glove"] = (len(lens), glove_frame)
	piv["glove_reach"] = [round(v, 3) for v in lens]

	# --- the house curtains, gathering toward the pillars as they open ---
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
			# gathered velvet bunches: pleats get fatter as they crowd together
			f = 1.0 + 0.35 * (1.0 - g)
			o.scale = (f, f, 1)
	seqs["curtain"] = (len(gs), curtain_frame)
	return seqs


def clamp01(v: float) -> float:
	return max(0.0, min(1.0, v))


def build_fx_local():
	"""Effects drawn wherever they happen (dust puffs): rendered on the icon camera, fixed frame."""
	dm = bpy.data.materials.new("dust")
	dm.use_nodes = True
	b = dm.node_tree.nodes["Principled BSDF"]
	b.inputs["Base Color"].default_value = lin("#D9C7AE")
	b.inputs["Roughness"].default_value = 1.0
	import random
	rnd = random.Random(3)
	puffs = []
	for i in range(9):
		a = math.pi * (i / 8.0)
		puffs.append((sph(f"dust{i}", 0.42, (0, 0, 0), dm, "fxs_dust", seg=16), math.cos(a), math.sin(a) * 0.6, rnd.uniform(0.8, 1.2)))

	def dust_frame(k: int) -> None:
		s_ = k / 5.0
		for o, cx, cz, r in puffs:
			o.location = (cx * (0.4 + 1.2 * s_), -0.2 * cz, cz * (0.3 + 0.7 * s_) + 0.3 + 0.25 * s_)
			sc = r * (0.6 + 0.9 * s_) * (1.0 - 0.35 * s_ * s_)
			o.scale = (sc, sc, sc)
		b.inputs["Alpha"].default_value = 0.5 * (1.0 - 0.85 * s_ * s_)
	return {"dust": (6, dust_frame)}


def build_shaft():
	"""Window daylight falling into the room: a soft emissive wedge, rendered as its own layer."""
	m = bpy.data.materials.new("shaft")
	m.use_nodes = True
	nt = m.node_tree
	for n in list(nt.nodes):
		nt.nodes.remove(n)
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	mix = nt.nodes.new("ShaderNodeMixShader")
	tr = nt.nodes.new("ShaderNodeBsdfTransparent")
	em = nt.nodes.new("ShaderNodeEmission")
	em.inputs["Color"].default_value = lin("#FFF1C8")
	em.inputs["Strength"].default_value = 1.0
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["UV"], sep.inputs[0])
	# fade along the beam and toward its edges
	m1 = nt.nodes.new("ShaderNodeMath")
	m1.operation = "PINGPONG"
	m1.inputs[1].default_value = 0.5
	nt.links.new(sep.outputs[0], m1.inputs[0])
	m2 = nt.nodes.new("ShaderNodeMath")
	m2.operation = "MULTIPLY"
	nt.links.new(m1.outputs[0], m2.inputs[0])
	nt.links.new(sep.outputs[1], m2.inputs[1])
	m3 = nt.nodes.new("ShaderNodeMath")
	m3.operation = "MULTIPLY"
	m3.inputs[1].default_value = 0.42
	nt.links.new(m2.outputs[0], m3.inputs[0])
	nt.links.new(m3.outputs[0], mix.inputs[0])
	nt.links.new(tr.outputs[0], mix.inputs[1])
	nt.links.new(em.outputs[0], mix.inputs[2])
	nt.links.new(mix.outputs[0], out.inputs["Surface"])
	# the beam: a quad from the window (top) down and forward onto the floor
	wx, wz, ww, wh = 2.5, 3.6, 3.2, 2.6
	bm = bmesh.new()
	vs = [bm.verts.new(v) for v in ((wx - ww / 2 + 0.1, WALL_Y - 0.5, wz + wh / 2), (wx + ww / 2 - 0.1, WALL_Y - 0.5, wz + wh / 2),
									 (wx + ww / 2 - 0.9, 1.4, 0.02), (wx - ww / 2 - 0.9, 1.4, 0.02))]
	f = bm.faces.new(vs)
	uvl = bm.loops.layers.uv.new("UVMap")
	for loop, uv in zip(f.loops, ((0, 1), (1, 1), (1, 0), (0, 0))):
		loop[uvl].uv = uv
	put("shaft", bm, m, "fx_shaft")


def build_frame():
	"""Proscenium: gold pillars + header, a velvet valance with swags, and the house curtains."""
	fy = -2.2
	for side in (-1, 1):
		box(f"pillar{side}", (0.75, 0.6, 12.0), (side * 9.15, fy, 2.5), mat("gold", 0.35, 0, 0.7), "frame", bevel=0.08)
		for k in range(4):
			box(f"flute{side}{k}", (0.08, 0.05, 11.5), (side * 9.15 - 0.24 + k * 0.16, fy - 0.31, 2.5), mat("gold_dk", 0.4, 0, 0.6), "frame", bevel=0.02)
	box("header", (19.6, 0.6, 0.55), (0, fy, 7.45), mat("gold", 0.35, 0, 0.7), "frame", bevel=0.08)
	for i in range(13):
		x = -9.0 + i * 1.5
		sph(f"swag{i}", 0.85, (x, fy + 0.3, 7.05), mat("velvet", 0.85), "frame", scale=(0.95, 0.35, 0.42))
		cyl(f"tassel{i}", 0.06, 0.4, (x + 0.75, fy + 0.1, 6.45), mat("gold", 0.4, 0, 0.6), "frame", seg=8)
	box("valance", (19.6, 0.3, 0.8), (0, fy + 0.45, 7.45), mat("velvet_dk", 0.85), "frame", bevel=0)
	sph("crest", 0.55, (0, fy - 0.3, 7.5), mat("gold", 0.3, 0, 0.8), "frame", scale=(1.3, 0.3, 0.9))
	sph("crest_mask", 0.28, (0, fy - 0.45, 7.5), mat("cream", 0.6), "frame", scale=(0.8, 0.3, 1.0))


def build_audience():
	import random
	rnd = random.Random(11)
	for i in range(17):
		x = -6.4 + i * 0.8 + rnd.uniform(-0.15, 0.15)
		y = -3.6 + (i % 2) * 0.25
		z = -0.3 + rnd.uniform(-0.12, 0.1)
		cm = mat("crowd" if i % 2 else "crowd2", 0.9)
		sph(f"head{i}", 0.3, (x, y, z), cm, "audience", scale=(0.95, 0.9, 1.05))
		sph(f"shoulders{i}", 0.5, (x, y + 0.05, z - 0.7), cm, "audience", scale=(1.1, 0.7, 0.75))
		if i % 5 == 2:          # a top hat in the Stalls
			cyl(f"hat{i}", 0.2, 0.42, (x, y, z + 0.2), mat("black", 0.6), "audience", seg=16)
			cyl(f"brim{i}", 0.33, 0.04, (x, y, z + 0.2), mat("black", 0.6), "audience", seg=16)


def build_icons():
	import props as P  # noqa: E402  (tools/bakery/props.py)
	for item, cname in (("spanner", "icon_rig"), ("clarence", "icon_clarence")):
		for k, (bm, colour) in enumerate(P.build(item)):
			put(f"{cname}{k}", bm, mat(P.PALETTE[colour], 0.5), cname, (0, 0, 0),
				(0, -35 if item == "spanner" else 0, 0), 0, True)
	# FREEZE: an ice crystal
	for k in range(3):
		box(f"ice_arm{k}", (0.13, 0.13, 1.3), (0, 0, 0), mat("ice", 0.15, 0.3), "icon_freeze", bevel=0.04, rot=(0, k * 60, 0))
		for s in (-1, 1):
			a = math.radians(k * 60)
			sph(f"ice_tip{k}{s}", 0.13, (s * 0.65 * math.sin(a), -0.05, s * 0.65 * math.cos(a)), mat("white", 0.2, 0.4), "icon_freeze")
	sph("ice_core", 0.22, (0, -0.05, 0), mat("ice_dk", 0.2, 0.2), "icon_freeze")
	prism("star", star_pts(5, 0.62, 0.27), 0.18, (0, 0, 0), mat("gold", 0.25, 0.15, 0.8), "icon_star", bevel=0.04)
	prism("burst_o", star_pts(12, 0.95, 0.68, 0.0), 0.06, (0, 0.06, 0), mat("velvet", 0.5, 0.3), "icon_burst")
	prism("burst_i", star_pts(12, 0.82, 0.58, 0.0), 0.06, (0, 0.0, 0), mat("butter", 0.5, 0.5), "icon_burst")


# ---------------------------------------------------------------------------------------------
ENGINE = {"name": "cycles", "samples": 96}


def use_cycles(scene, samples: int) -> None:
	"""Cycles on the GPU (Metal on Apple silicon), denoised: real bounce light and soft contact
	shadows are most of what separates a set from a diagram."""
	scene.render.engine = "CYCLES"
	try:
		prefs = bpy.context.preferences.addons["cycles"].preferences
		for kind in ("METAL", "OPTIX", "CUDA", "HIP", "ONEAPI"):
			try:
				prefs.compute_device_type = kind
				prefs.get_devices()
				devs = [d for d in prefs.devices if d.type == kind]
				if devs:
					for d in prefs.devices:
						d.use = d.type == kind
					scene.cycles.device = "GPU"
					break
			except Exception:
				continue
	except Exception:
		pass
	scene.cycles.samples = samples
	scene.cycles.use_denoising = True
	scene.cycles.max_bounces = 6
	scene.cycles.transparent_max_bounces = 8
	scene.cycles.caustics_reflective = False
	scene.cycles.caustics_refractive = False
	scene.cycles.blur_glossy = 1.0


def setup_render(scene, cam):
	scene.render.engine = "BLENDER_EEVEE_NEXT"
	scene.render.resolution_x, scene.render.resolution_y = W, H
	scene.render.resolution_percentage = 100
	scene.render.film_transparent = True
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGBA"
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	for k, v in (("taa_render_samples", 32), ("use_shadows", True), ("use_raytracing", True)):
		try:
			setattr(scene.eevee, k, v)
		except Exception:
			pass
	if ENGINE["name"] == "cycles":
		use_cycles(scene, ENGINE["samples"])
	world = bpy.data.worlds.new("w")
	world.use_nodes = True
	world.node_tree.nodes["Background"].inputs[0].default_value = (1.0, 0.9, 0.82, 1)
	world.node_tree.nodes["Background"].inputs[1].default_value = 0.55 if ENGINE["name"] != "cycles" else 0.32
	scene.world = world
	cyc = ENGINE["name"] == "cycles"
	lights = coll("lights")
	key = bpy.data.lights.new("key", "SUN")
	key.energy = 2.6 if not cyc else 3.2
	key.angle = math.radians(12 if not cyc else 5)
	key.color = (1.0, 0.94, 0.84)
	ko = bpy.data.objects.new("key", key)
	ko.rotation_euler = Euler((math.radians(50), 0, math.radians(30)))
	lights.objects.link(ko)
	rigs = [("lamp", (-2.65, 3.0, 3.3), 260 if not cyc else 160, (1.0, 0.72, 0.4), 0.4),
			("window", (2.5, 3.2, 3.6), 380 if not cyc else 220, (0.75, 0.9, 1.0), 1.4),
			("foot", (0.0, -2.5, 2.2), 600 if not cyc else 380, (1.0, 0.82, 0.55), 5.0)]
	if cyc:
		rigs += [("pendant", (0.4, 2.6, 4.8), 120, (1.0, 0.78, 0.5), 0.3),
				 ("sconce0", (-5.55, 3.55, 4.4), 25, (1.0, 0.72, 0.4), 0.1),
				 ("sconce1", (-3.05, 3.55, 4.4), 25, (1.0, 0.72, 0.4), 0.1)]
	for name, loc, energy, colr, rad in rigs:
		ld = bpy.data.lights.new(name, "POINT")
		ld.energy = energy
		ld.color = colr
		ld.shadow_soft_size = rad
		lo = bpy.data.objects.new(name, ld)
		lo.location = loc
		lights.objects.link(lo)


def make_camera(scene):
	cd = bpy.data.cameras.new("cam")
	cd.type = "ORTHO"
	cd.ortho_scale = W / PX
	cam = bpy.data.objects.new("cam", cd)
	scene.collection.objects.link(cam)
	# look along +Y, tilted down; the stage line at depth STAGE_Y lands on FLOOR_PX
	cam.rotation_euler = Euler((math.radians(90) - TILT, 0, 0))
	up = Vector((0, math.sin(TILT), math.cos(TILT)))
	fwd = Vector((0, math.cos(TILT), -math.sin(TILT)))
	v_floor = (H / 2 - FLOOR_PX) / PX
	zt = -v_floor / math.cos(TILT)
	target = Vector((0, STAGE_Y, zt))
	cam.location = target - fwd * 40.0
	scene.camera = cam
	return cam


def to_px(scene, cam, p) -> list[float]:
	co = world_to_camera_view(scene, cam, Vector(p))
	return [round(co.x * W, 1), round((1.0 - co.y) * H, 1)]


def render_layer(scene, names: list[str], path: str, samples: int = 0, border=None) -> None:
	for n, c in COLL.items():
		c.hide_render = not (n in names or n == "lights")
	if scene.render.engine == "CYCLES":
		scene.cycles.samples = samples or ENGINE["samples"]
	# a border keeps the full frame (positions stay exact) but only traces the pixels that matter
	scene.render.use_border = border is not None
	scene.render.use_crop_to_border = False
	if border is not None:
		scene.render.border_min_x, scene.render.border_min_y, scene.render.border_max_x, scene.render.border_max_y = border
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	scene.render.use_border = False


def screen_box(scene, cam, names: list[str], box=None, pad: float = 0.02):
	"""Union of the camera-space boxes of every object in `names` (0..1, y up), padded."""
	dg = bpy.context.evaluated_depsgraph_get()
	lo_x, lo_y, hi_x, hi_y = (1.0, 1.0, 0.0, 0.0) if box is None else box
	for n in names:
		for o in COLL[n].all_objects:
			if o.type not in ("MESH", "FONT", "CURVE"):
				continue
			ev = o.evaluated_get(dg)
			for c in ev.bound_box:
				co = world_to_camera_view(scene, cam, ev.matrix_world @ Vector(c))
				lo_x, lo_y, hi_x, hi_y = min(lo_x, co.x), min(lo_y, co.y), max(hi_x, co.x), max(hi_y, co.y)
	return (max(0.0, lo_x - pad), max(0.0, lo_y - pad), min(1.0, hi_x + pad), min(1.0, hi_y + pad))


def main() -> int:
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(HERE, "out")
	only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else []
	if "--engine" in argv:
		ENGINE["name"] = argv[argv.index("--engine") + 1]
	if "--samples" in argv:
		ENGINE["samples"] = int(argv[argv.index("--samples") + 1])
	os.makedirs(out, exist_ok=True)
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	marks = build_room()
	piv = build_props()
	seqs = build_seqs(piv, marks)
	fx_local = build_fx_local()
	build_shaft()
	build_frame()
	build_audience()
	build_icons()
	cam = make_camera(scene)
	setup_render(scene, cam)
	bpy.context.view_layer.update()

	room = [n for n in COLL if not n.startswith(("prop_", "fg_", "icon_", "frame", "seq_", "fxs_", "fx_", "audience", "lights"))]
	layers = {"bg": room, "frame": ["frame"], "audience": ["audience"], "fx_shaft": ["fx_shaft"]}
	for n in COLL:
		if n.startswith(("prop_", "fg_")):
			layers[n] = [n]
	for name, cols in layers.items():
		if only and name not in only:
			continue
		small = name.startswith(("prop_", "fg_", "fx_"))
		render_layer(scene, cols, os.path.join(out, f"{name}.png"),
					 samples=max(32, ENGINE["samples"] // 2) if small else 0,
					 border=screen_box(scene, cam, cols) if small else None)
		print(f"[set] {name}")
	for name, (n, fn) in seqs.items():
		if only and f"seq_{name}" not in only:
			continue
		bx = None
		for k in range(n):
			fn(k)
			bpy.context.view_layer.update()
			bx = screen_box(scene, cam, [f"seq_{name}"], bx)
		for k in range(n):
			fn(k)
			bpy.context.view_layer.update()
			render_layer(scene, [f"seq_{name}"], os.path.join(out, f"seq_{name}_{k:02d}.png"),
						 samples=max(24, ENGINE["samples"] // 3), border=bx)
		fn(0)
		print(f"[set] seq_{name} x{n}")

	# icons: own square camera, looking at the origin
	icons = [n for n in COLL if n.startswith("icon_")]
	scene.render.resolution_x = scene.render.resolution_y = 256
	cd = bpy.data.cameras.new("icam")
	cd.type = "ORTHO"
	cd.ortho_scale = 2.1
	ic = bpy.data.objects.new("icam", cd)
	scene.collection.objects.link(ic)
	ic.rotation_euler = Euler((math.radians(90), 0, 0))
	ic.location = (0, -20, 0)
	for n in icons:
		if only and n not in only:
			continue
		# frame each icon on its own bounding box
		dg = bpy.context.evaluated_depsgraph_get()
		pts = []
		for o in COLL[n].objects:
			ev = o.evaluated_get(dg)
			pts += [ev.matrix_world @ Vector(c) for c in ev.bound_box]
		lo = Vector((min(p.x for p in pts), 0, min(p.z for p in pts)))
		hi = Vector((max(p.x for p in pts), 0, max(p.z for p in pts)))
		ic.location = ((lo.x + hi.x) / 2, -20, (lo.z + hi.z) / 2)
		cd.ortho_scale = max(hi.x - lo.x, hi.z - lo.z) * 1.12
		scene.camera = ic
		render_layer(scene, [n], os.path.join(out, f"{n}.png"), samples=48)
		print(f"[set] {n}")
	# local effects: one fixed square frame per effect (anchored bottom-centre in the game)
	for name, (n, fn) in fx_local.items():
		if only and f"fxs_{name}" not in only:
			continue
		ic.location = (0, -20, 1.0)
		cd.ortho_scale = 4.0
		scene.camera = ic
		for k in range(n):
			fn(k)
			bpy.context.view_layer.update()
			render_layer(scene, [f"fxs_{name}"], os.path.join(out, f"fxs_{name}_{k:02d}.png"), samples=32)
		print(f"[set] fxs_{name} x{n}")
	scene.camera = cam
	scene.render.resolution_x, scene.render.resolution_y = W, H

	data = {
		"size": [W, H], "px_per_unit": PX, "floor_px": FLOOR_PX, "tilt_deg": math.degrees(TILT),
		"marks": {k: to_px(scene, cam, v) for k, v in marks.items()},
		"pivots": {k: (to_px(scene, cam, v) if isinstance(v, tuple) else v) for k, v in piv.items()},
		"fx_canvas": {"size": 256, "units": 4.0, "anchor_units": [0.0, -1.0]},
	}
	with open(os.path.join(out, "marks.json"), "w") as fh:
		json.dump(data, fh, indent=1)
	print("[set] marks written")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
