"""scenery — reusable outdoor set pieces for every Act's set script (trees, clouds, sky, hedges, ...).

    import scenery as SC
    SC.tree("oak1", x=-6.0, y=8.0, s=1.0, kind="oak", seed=3)
    SC.cloud("c1", x=2.0, y=13.4, z=9.5, w=3.0, seed=1)

Catalogue (every piece in a row, for review):

    blender -b --factory-startup --python-exit-code 1 -P tools/stage/scenery.py -- --out DIR [--engine eevee]

Conventions (same as act1_set): positions in stage units (x across, y depth, z up; the walk line is
y = 1.3); every builder takes a unique `name` prefix (Blender object names must not collide), a scale
`s`, a `seed` (two trees differ, a re-render is identical) and `where` — the layer collection it lands
in ("bg", "fg_*", "prop_*", "seq_*", "fx_*"). The camera is orthographic: depth does not shrink
anything, so distance is sold by overlap and by the `haze` argument (pale, low-contrast far pieces).
Colours are palette keys in K.C (all prefixed `sc_` so an Act's own palette never clashes) or hex.
Builders return the list of objects they made, so an Act can parent them into a sequence.
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
from mathutils import Vector, noise  # type: ignore  # noqa: E402

import act1_set as K  # noqa: E402

K.C.update({
	# foliage: base / sunlit top / shaded underside, per family
	"sc_oak": "#4FA545", "sc_oak_lt": "#8ED06A", "sc_oak_dk": "#2C6E34",
	"sc_birch": "#86BE4A", "sc_birch_lt": "#C6E27A", "sc_birch_dk": "#4F8A33",
	"sc_pine": "#2F7A55", "sc_pine_lt": "#58A276", "sc_pine_dk": "#1B5240",
	"sc_hedge": "#3D8F40", "sc_hedge_lt": "#6DBB55", "sc_hedge_dk": "#24622D",
	"sc_bark": "#7A5236", "sc_bark_dk": "#4E3322", "sc_birch_bark": "#EEE9DF", "sc_birch_mark": "#3A3530",
	"sc_sky_top": "#4FA8E6", "sc_sky_hor": "#D6F0FF", "sc_cloud": "#FFFFFF", "sc_cloud_sh": "#C5D3EC",
	"sc_sun": "#FFF3B8", "sc_sun_halo": "#FFF9DC",
	"sc_hill1": "#6FB27E", "sc_hill2": "#8CC49A", "sc_hill3": "#A9D3B7",
	"sc_lawn_a": "#6CC24F", "sc_lawn_b": "#5AAE40", "sc_grass": "#4C9A37", "sc_grass_lt": "#7CC85A",
	"sc_soil": "#7A5B33", "sc_soil_dk": "#5C4224", "sc_stone": "#BDB6AA", "sc_stone_dk": "#958D80",
	"sc_fence": "#F3E9D6", "sc_fence_dk": "#D9CBB0",
	"sc_petal1": "#F27BB0", "sc_petal2": "#FFD84A", "sc_petal3": "#FFFFFF", "sc_petal4": "#D8323F",
	"sc_apple": "#D8323F",
})

LEAVES = {"oak": ("sc_oak", "sc_oak_lt", "sc_oak_dk"), "birch": ("sc_birch", "sc_birch_lt", "sc_birch_dk"),
		  "pine": ("sc_pine", "sc_pine_lt", "sc_pine_dk"), "hedge": ("sc_hedge", "sc_hedge_lt", "sc_hedge_dk")}


# --- materials --------------------------------------------------------------------------------------
_MAT: dict = {}


def _col(key: str):
	return K.lin(K.C.get(key, key))


def _graph(name: str, rough: float):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	bs = nt.nodes["Principled BSDF"]
	bs.inputs["Roughness"].default_value = rough
	return m, nt, bs


def _mix(nt, fac, a, b, blend: str = "MIX"):
	"""Mix two colours (sockets or RGBA tuples) by `fac` (socket or float)."""
	mx = nt.nodes.new("ShaderNodeMix")
	mx.data_type = "RGBA"
	mx.blend_type = blend
	for i, v in ((0, fac), (6, a), (7, b)):
		if isinstance(v, (int, float)):
			mx.inputs[i].default_value = float(v)
		elif isinstance(v, tuple):
			mx.inputs[i].default_value = v
		else:
			nt.links.new(v, mx.inputs[i])
	return mx.outputs[2]


def _haze(nt, bs, col_socket, haze: float, haze_col: str = "sc_sky_hor") -> None:
	"""Aerial perspective: pull a far piece toward the horizon colour and let it glow a little, so the
	sun's shading on it stays soft (far things are low-contrast)."""
	c = _mix(nt, haze, col_socket, _col(haze_col)) if haze > 0 else col_socket
	nt.links.new(c, bs.inputs["Base Color"])
	if haze > 0:
		nt.links.new(c, bs.inputs["Emission Color"])
		bs.inputs["Emission Strength"].default_value = 0.45 * haze


def mat_foliage(family: str = "oak", haze: float = 0.0, clipped: bool = False, glow: float = 0.0):
	"""Leafy mass: shaded underside -> base -> sunlit top (by the object's own height), broken up by
	noise, with clumpy leaf bump (voronoi). `clipped` = a tight topiary/hedge surface (finer bump)."""
	key = f"sc_fol_{family}_{haze}_{clipped}_{glow}"
	if key in _MAT:
		return _MAT[key]
	base, lt, dk = LEAVES.get(family, LEAVES["oak"])
	m, nt, bs = _graph(key, 0.85)
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	nz = nt.nodes.new("ShaderNodeTexNoise")
	nz.inputs["Scale"].default_value = 3.5
	nz.inputs["Detail"].default_value = 4.0
	nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
	# height ramp with a noisy edge: low = shade, high = sun
	h = nt.nodes.new("ShaderNodeMath")
	h.operation = "MULTIPLY_ADD"
	nt.links.new(sep.outputs[2], h.inputs[0])
	h.inputs[1].default_value = 1.0
	nt.links.new(nz.outputs["Fac"], h.inputs[2])
	h2 = nt.nodes.new("ShaderNodeMath")
	h2.operation = "SUBTRACT"
	nt.links.new(h.outputs[0], h2.inputs[0])
	h2.inputs[1].default_value = 0.5
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	nt.links.new(h2.outputs[0], ramp.inputs[0])
	el = ramp.color_ramp.elements
	el[0].position, el[0].color = 0.2, _col(dk)
	el[1].position, el[1].color = 0.85, _col(lt)
	mid = el.new(0.5)
	mid.color = _col(base)
	_haze(nt, bs, ramp.outputs["Color"], haze)
	if glow > 0:
		nt.links.new(ramp.outputs["Color"], bs.inputs["Emission Color"])
		bs.inputs["Emission Strength"].default_value += glow
	vo = nt.nodes.new("ShaderNodeTexVoronoi")
	vo.inputs["Scale"].default_value = 26.0 if clipped else 9.0
	nt.links.new(tc.outputs["Object"], vo.inputs["Vector"])
	bp = nt.nodes.new("ShaderNodeBump")
	bp.inputs["Strength"].default_value = 0.35 if clipped else 0.6
	bp.inputs["Distance"].default_value = 0.05
	nt.links.new(vo.outputs["Distance"], bp.inputs["Height"])
	nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])
	_MAT[key] = m
	return m


def mat_cloud(haze: float = 0.0):
	"""A cumulus: bright white top, cool shaded belly, self-lit so it never greys out."""
	key = f"sc_cloud_{haze}"
	if key in _MAT:
		return _MAT[key]
	m, nt, bs = _graph(key, 1.0)
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	nt.links.new(sep.outputs[2], ramp.inputs[0])
	el = ramp.color_ramp.elements
	el[0].position, el[0].color = 0.15, _col("sc_cloud_sh")
	el[1].position, el[1].color = 0.6, _col("sc_cloud")
	c = _mix(nt, haze, ramp.outputs["Color"], _col("sc_sky_hor")) if haze else ramp.outputs["Color"]
	nt.links.new(c, bs.inputs["Base Color"])
	nt.links.new(c, bs.inputs["Emission Color"])
	bs.inputs["Emission Strength"].default_value = 0.75
	_MAT[key] = m
	return m


def mat_sky(top: str = "sc_sky_top", horizon: str = "sc_sky_hor", strength: float = 1.0):
	"""A vertical gradient backdrop (emission only: the sky lights itself)."""
	key = f"sc_sky_{top}_{horizon}_{strength}"
	if key in _MAT:
		return _MAT[key]
	m, nt, bs = _graph(key, 1.0)
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	nt.links.new(sep.outputs[2], ramp.inputs[0])
	el = ramp.color_ramp.elements
	el[0].position, el[0].color = 0.08, _col(horizon)
	el[1].position, el[1].color = 0.75, _col(top)
	bs.inputs["Base Color"].default_value = (0, 0, 0, 1)
	nt.links.new(ramp.outputs["Color"], bs.inputs["Emission Color"])
	bs.inputs["Emission Strength"].default_value = strength
	_MAT[key] = m
	return m


def mat_lawn(a: str = "sc_lawn_a", b: str = "sc_lawn_b", freq: float = 0.9, axis: int = 1, name: str = "sc_lawn", glow: float = 0.0):
	"""Mown lawn: two-tone stripes (`freq` per unit along `axis`), mottled, with a fine grass bump."""
	if name in _MAT:
		return _MAT[name]
	m, nt, bs = _graph(name, 0.9)
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["Object"], sep.inputs[0])
	mul = nt.nodes.new("ShaderNodeMath")
	mul.operation = "MULTIPLY"
	mul.inputs[1].default_value = freq
	nt.links.new(sep.outputs[axis], mul.inputs[0])
	mod = nt.nodes.new("ShaderNodeMath")
	mod.operation = "FLOORED_MODULO"
	mod.inputs[1].default_value = 1.0
	nt.links.new(mul.outputs[0], mod.inputs[0])
	gt = nt.nodes.new("ShaderNodeMath")
	gt.operation = "GREATER_THAN"
	gt.inputs[1].default_value = 0.5
	nt.links.new(mod.outputs[0], gt.inputs[0])
	stripes = _mix(nt, gt.outputs[0], _col(a), _col(b))
	nz = nt.nodes.new("ShaderNodeTexNoise")
	nz.inputs["Scale"].default_value = 1.4
	nz.inputs["Detail"].default_value = 3.0
	nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
	col = _mix(nt, 0.25, stripes, nz.outputs["Fac"], "OVERLAY")
	nt.links.new(col, bs.inputs["Base Color"])
	if glow > 0:
		nt.links.new(col, bs.inputs["Emission Color"])
		bs.inputs["Emission Strength"].default_value = glow
	fine = nt.nodes.new("ShaderNodeTexNoise")
	fine.inputs["Scale"].default_value = 120.0
	fine.inputs["Detail"].default_value = 1.0
	nt.links.new(tc.outputs["Object"], fine.inputs["Vector"])
	bp = nt.nodes.new("ShaderNodeBump")
	bp.inputs["Strength"].default_value = 0.3
	bp.inputs["Distance"].default_value = 0.01
	nt.links.new(fine.outputs["Fac"], bp.inputs["Height"])
	nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])
	_MAT[name] = m
	return m


def mat_bark(key: str = "sc_bark", dark: str = "sc_bark_dk", haze: float = 0.0):
	"""Bark: vertical streaks (noise stretched along z) and a ridged bump."""
	name = f"sc_barkm_{key}_{haze}"
	if name in _MAT:
		return _MAT[name]
	m, nt, bs = _graph(name, 0.95)
	tc = nt.nodes.new("ShaderNodeTexCoord")
	mp = nt.nodes.new("ShaderNodeMapping")
	mp.inputs["Scale"].default_value = (9.0, 9.0, 1.2)
	nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
	nz = nt.nodes.new("ShaderNodeTexNoise")
	nz.inputs["Scale"].default_value = 3.0
	nz.inputs["Detail"].default_value = 5.0
	nt.links.new(mp.outputs[0], nz.inputs["Vector"])
	col = _mix(nt, nz.outputs["Fac"], _col(dark), _col(key))
	_haze(nt, bs, col, haze)
	bp = nt.nodes.new("ShaderNodeBump")
	bp.inputs["Strength"].default_value = 0.5
	nt.links.new(nz.outputs["Fac"], bp.inputs["Height"])
	nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])
	_MAT[name] = m
	return m


def mat_birch_bark(haze: float = 0.0):
	"""White birch with dark dashes (thresholded stretched noise)."""
	name = f"sc_birchbark_{haze}"
	if name in _MAT:
		return _MAT[name]
	m, nt, bs = _graph(name, 0.8)
	tc = nt.nodes.new("ShaderNodeTexCoord")
	mp = nt.nodes.new("ShaderNodeMapping")
	mp.inputs["Scale"].default_value = (2.5, 2.5, 9.0)
	nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
	nz = nt.nodes.new("ShaderNodeTexNoise")
	nz.inputs["Scale"].default_value = 2.0
	nt.links.new(mp.outputs[0], nz.inputs["Vector"])
	gt = nt.nodes.new("ShaderNodeMath")
	gt.operation = "GREATER_THAN"
	gt.inputs[1].default_value = 0.62
	nt.links.new(nz.outputs["Fac"], gt.inputs[0])
	col = _mix(nt, gt.outputs[0], _col("sc_birch_bark"), _col("sc_birch_mark"))
	_haze(nt, bs, col, haze)
	_MAT[name] = m
	return m


def mat_boards(a: str, b: str, freq: float = 3.2, axis: int = 0, gap: str = "#3E2A1C", name: str = "sc_boards"):
	"""Timber boarding (sheds, fences, decks, cladding): boards `freq` per unit along `axis`, alternating
	a/b, with grain running along each board and a recessed dark gap between them."""
	key = f"{name}_{a}_{b}_{freq}_{axis}"
	if key in _MAT:
		return _MAT[key]
	m, nt, bs = _graph(key, 0.75)
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["Object"], sep.inputs[0])

	def op(o, x, y=None):
		n = nt.nodes.new("ShaderNodeMath")
		n.operation = o
		for i, v in enumerate((x, y)):
			if v is None:
				continue
			if isinstance(v, (int, float)):
				n.inputs[i].default_value = float(v)
			else:
				nt.links.new(v, n.inputs[i])
		return n.outputs[0]
	u = op("MULTIPLY", sep.outputs[axis], freq)
	t = op("FLOORED_MODULO", u, 1.0)
	alt = op("GREATER_THAN", op("FLOORED_MODULO", op("MULTIPLY", u, 0.5), 1.0), 0.5)
	base = _mix(nt, alt, _col(a), _col(b))
	mp = nt.nodes.new("ShaderNodeMapping")
	sc = [1.0, 1.0, 1.0]
	sc[axis] = 14.0                     # stretch the noise across the boards: grain runs along them
	mp.inputs["Scale"].default_value = sc
	nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
	nz = nt.nodes.new("ShaderNodeTexNoise")
	nz.inputs["Scale"].default_value = 2.5
	nz.inputs["Detail"].default_value = 6.0
	nt.links.new(mp.outputs[0], nz.inputs["Vector"])
	grain = _mix(nt, 0.3, base, nz.outputs["Fac"], "OVERLAY")
	g = op("LESS_THAN", t, 0.07)
	col = _mix(nt, op("MULTIPLY", g, 0.85), grain, _col(gap))
	nt.links.new(col, bs.inputs["Base Color"])
	bp = nt.nodes.new("ShaderNodeBump")
	bp.invert = True
	bp.inputs["Strength"].default_value = 0.6
	bp.inputs["Distance"].default_value = 0.02
	nt.links.new(g, bp.inputs["Height"])
	nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])
	_MAT[key] = m
	return m


def mat_shingles(a: str, b: str, mortar: str = "#1E242E", width: float = 0.5, row: float = 0.22, name: str = "sc_shingles"):
	"""Roof shingles/slates in the object's x-y plane (a roof slope modelled in place): staggered rows,
	two tones with per-tile variation, dark gaps, a bump so each row catches the light."""
	key = f"{name}_{a}_{b}"
	if key in _MAT:
		return _MAT[key]
	m, nt, bs = _graph(key, 0.7)
	tc = nt.nodes.new("ShaderNodeTexCoord")
	br = nt.nodes.new("ShaderNodeTexBrick")
	br.inputs["Color1"].default_value = _col(a)
	br.inputs["Color2"].default_value = _col(b)
	br.inputs["Mortar"].default_value = _col(mortar)
	br.inputs["Scale"].default_value = 1.0
	br.inputs["Mortar Size"].default_value = 0.012
	br.inputs["Bias"].default_value = 0.0
	br.inputs["Brick Width"].default_value = width
	br.inputs["Row Height"].default_value = row
	nt.links.new(tc.outputs["Object"], br.inputs["Vector"])
	nt.links.new(br.outputs["Color"], bs.inputs["Base Color"])
	bp = nt.nodes.new("ShaderNodeBump")
	bp.invert = True
	bp.inputs["Strength"].default_value = 0.7
	bp.inputs["Distance"].default_value = 0.03
	nt.links.new(br.outputs["Fac"], bp.inputs["Height"])
	nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])
	_MAT[key] = m
	return m


def mat_flat(key: str, rough: float = 0.8, haze: float = 0.0, emit: float = 0.0):
	"""A plain colour that can still take aerial haze (K.mat cannot)."""
	name = f"sc_flat_{key}_{rough}_{haze}_{emit}"
	if name in _MAT:
		return _MAT[name]
	if haze <= 0:
		_MAT[name] = K.mat(K.C.get(key, key), rough, emit)
		return _MAT[name]
	m, nt, bs = _graph(name, rough)
	rgb = nt.nodes.new("ShaderNodeRGB")
	rgb.outputs[0].default_value = _col(key)
	_haze(nt, bs, rgb.outputs[0], haze)
	if emit:
		bs.inputs["Emission Strength"].default_value += emit
	_MAT[name] = m
	return m


# --- the organic primitive ---------------------------------------------------------------------------
def blob(name: str, r: float, loc, m, where: str = "bg", scale=(1.0, 1.0, 1.0), seed: int = 0,
		 lump: float = 0.18, subdiv: int = 3, flat_base: float | None = None):
	"""A lumpy sphere: an icosphere pushed in and out by Perlin noise, smooth-shaded. The building block
	of foliage, clouds, bushes and stones. `flat_base` clips everything below that local z (a cloud's
	flat belly, a bush sitting on the ground)."""
	bm = bmesh.new()
	bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
	off = Vector((seed * 7.13, seed * 3.71, seed * 1.93))
	f = 1.6 / max(r, 0.05)
	for v in bm.verts:
		n = noise.noise(v.co * f + off)
		v.co *= 1.0 + lump * n
		v.co.x *= scale[0]
		v.co.y *= scale[1]
		v.co.z *= scale[2]
		if flat_base is not None and v.co.z < flat_base:
			v.co.z = flat_base + (v.co.z - flat_base) * 0.15
	return K.put(name, bm, m, where, loc, (0, 0, 0), 0.0, True, sharp=180)


def _cluster(name: str, cx: float, y: float, cz: float, w: float, h: float, r: float, n: int, m, where: str,
			 rnd: random.Random, depth: float = 0.6, lump: float = 0.2) -> list:
	"""`n` blobs packed into a w x h ellipse: big ones in the middle, small ones on the rim; the front
	ones (lower y) are the smallest, so the mass reads as round rather than as a stack of balls."""
	out = []
	n = max(n, int(math.ceil(w * h / (r * r * 1.3))))
	for k in range(n):
		a = rnd.uniform(0, math.tau)
		d = math.sqrt(rnd.uniform(0.0, 1.0)) * (0.2 if k == 0 else 1.0)
		dx, dz = math.cos(a) * d * (w / 2 - r * 0.6), math.sin(a) * d * (h / 2 - r * 0.6)
		rr = r * (1.0 - 0.45 * d) * rnd.uniform(0.85, 1.1)
		dy = rnd.uniform(-depth, depth) * (1.0 - d)
		out.append(blob(f"{name}_b{k}", rr, (cx + dx, y + dy, cz + dz), m, where,
						scale=(1.0, 0.7, 0.92), seed=rnd.randint(0, 9999), lump=lump))
	return out


# --- trees, bushes, hedges -------------------------------------------------------------------------
def tree(name: str, x: float, y: float, s: float = 1.0, kind: str = "oak", seed: int = 0, where: str = "bg",
		 haze: float = 0.0, fruit: str | None = None) -> list:
	"""A tree standing on (x, y, 0). kinds: "oak" (broad round crown, a couple of limbs), "poplar"
	(tall flame shape), "pine" (stacked tiers), "birch" (white trunk, light airy crown). An oak is
	about 6 s tall and 3.4 s wide. `fruit` = a colour key for apples/oranges dotted on the crown."""
	rnd = random.Random(seed)
	out: list = []
	# trunks take half the haze: thin and dark, they lose their colour long before the crown does
	if kind == "birch":
		bark = mat_birch_bark(haze * 0.5)
	else:
		bark = mat_bark(haze=haze * 0.5)
	fam = {"poplar": "oak", "pine": "pine", "birch": "birch"}.get(kind, "oak")
	fol = mat_foliage(fam, haze)
	if kind == "pine":
		out.append(K.cyl(f"{name}_trunk", 0.2 * s, 1.6 * s, (x, y, 0), bark, where, r2=0.12 * s, seg=12))
		tiers = 4
		for k in range(tiers):
			t = k / (tiers - 1)
			r = (1.5 - 0.95 * t) * s
			z = (1.0 + k * 1.05) * s
			out.append(K.cyl(f"{name}_tier{k}", r, 1.7 * s, (x + rnd.uniform(-0.06, 0.06) * s, y, z), fol, where,
							 r2=0.05 * s, seg=14, rot=(0, rnd.uniform(-3, 3), 0)))
			# a ragged skirt so each tier is not a perfect cone
			for j in range(6):
				a = j / 6 * math.tau + rnd.uniform(-0.3, 0.3)
				out.append(blob(f"{name}_sk{k}{j}", 0.28 * s * (1 - 0.4 * t), (x + math.cos(a) * r * 0.8, y + math.sin(a) * r * 0.5, z + 0.15 * s),
								fol, where, scale=(1.2, 1.0, 0.6), seed=rnd.randint(0, 9999), subdiv=2))
		return out
	trunk_h = {"oak": 2.8, "poplar": 1.6, "birch": 3.0}.get(kind, 2.8) * s
	r0 = {"oak": 0.3, "poplar": 0.2, "birch": 0.16}.get(kind, 0.3) * s
	out.append(K.cyl(f"{name}_trunk", r0, trunk_h + 0.6 * s, (x, y, 0), bark, where, r2=r0 * 0.55, seg=14))
	out.append(K.cyl(f"{name}_flare", r0 * 1.7, 0.35 * s, (x, y, 0), bark, where, r2=r0, seg=14))
	if kind in ("oak", "birch"):
		for side in (-1, 1):
			ang = side * rnd.uniform(28, 42)
			ln = rnd.uniform(1.0, 1.4) * s if kind == "oak" else rnd.uniform(0.6, 0.8) * s
			out.append(K.cyl(f"{name}_limb{side}", r0 * 0.45, ln, (x, y, trunk_h * (rnd.uniform(0.6, 0.75) if kind == "oak" else 0.8)), bark, where,
							 r2=r0 * 0.2, seg=10, rot=(0, ang, 0)))
	if kind == "oak":
		w, h, r, n, cz = 3.6 * s, 3.0 * s, 1.05 * s, 11, trunk_h + 1.1 * s
	elif kind == "poplar":
		w, h, r, n, cz = 1.7 * s, 4.4 * s, 0.85 * s, 14, trunk_h + 2.0 * s
	else:
		w, h, r, n, cz = 2.6 * s, 2.6 * s, 0.8 * s, 12, trunk_h + 0.6 * s
	out += _cluster(name, x, y, cz, w, h, r, n, fol, where, rnd)
	if fruit:
		fm = mat_flat(fruit, 0.45, haze)
		for k in range(9):
			a = rnd.uniform(0, math.tau)
			d = rnd.uniform(0.35, 0.8)
			out.append(K.sph(f"{name}_fruit{k}", 0.12 * s, (x + math.cos(a) * d * w / 2, y - 0.9 * s, cz + math.sin(a) * d * h / 2),
							 fm, where, seg=12))
	return out


def bush(name: str, x: float, y: float, w: float = 1.6, h: float = 1.2, seed: int = 0, where: str = "bg",
		 family: str = "hedge", haze: float = 0.0, flowers: tuple | None = None, depth: float = 0.3, glow: float = 0.0,
		 z0: float = 0.0) -> list:
	"""A loose shrub sitting on the ground (z0) at (x, y), w wide and h tall; `flowers` = colour keys
	dotted over its front."""
	rnd = random.Random(seed)
	fol = mat_foliage(family, haze, glow=glow)
	n = max(4, int(w * h * 3))
	out = _cluster(name, x, y, z0 + h * 0.5, w, h * 0.9, min(w, h) * 0.42, n, fol, where, rnd, depth=depth)
	r = min(w, h) * 0.34
	for k in range(max(2, int(w / r))):
		bx = x - w / 2 + r + k * (w - 2 * r) / max(1, int(w / r) - 1)
		out.append(blob(f"{name}_foot{k}", r, (bx, y, z0 + r * 0.75), fol, where, scale=(1.1, min(0.8, depth / r + 0.1), 0.85),
						seed=rnd.randint(0, 9999), lump=0.18, flat_base=-r * 0.7))
	if flowers:
		for k in range(int(w * 6)):
			a = rnd.uniform(0.15, math.pi - 0.15)
			fx = x + math.cos(a) * w * 0.42 * rnd.uniform(0.4, 1.0)
			fz = z0 + h * 0.48 + math.sin(a) * h * 0.42 * rnd.uniform(0.2, 1.0)
			out.append(K.sph(f"{name}_fl{k}", 0.07, (fx, y - min(w, h) * 0.45, fz), mat_flat(flowers[k % len(flowers)], 0.6, haze), where, seg=10))
	return out


def hedge(name: str, x0: float, x1: float, y: float, h: float = 1.6, depth: float = 0.9, seed: int = 0,
		  where: str = "bg", haze: float = 0.0) -> list:
	"""A clipped box hedge from x0 to x1: a rounded slab with a lumpy crown along its top."""
	rnd = random.Random(seed)
	fol = mat_foliage("hedge", haze, clipped=True)
	out = [K.box(f"{name}_slab", (x1 - x0, depth, h - 0.2), ((x0 + x1) / 2, y, (h - 0.2) / 2), fol, where, bevel=0.18)]
	n = max(2, int((x1 - x0) / 0.7))
	for k in range(n):
		bx = x0 + (k + 0.5) * (x1 - x0) / n
		out.append(blob(f"{name}_top{k}", 0.45, (bx, y, h - 0.35), fol, where, scale=(1.3, depth / 0.9, 0.6),
						seed=rnd.randint(0, 9999), lump=0.1))
	return out


def topiary_ball(name: str, x: float, y: float, z: float, r: float, seed: int = 0, where: str = "bg",
				 scale=(1.0, 0.85, 1.0)) -> object:
	"""A clipped ball (or egg, via `scale`): tight surface, barely lumpy."""
	return blob(name, r, (x, y, z), mat_foliage("hedge", clipped=True), where, scale=scale, seed=seed, lump=0.06)


def topiary_tiers(name: str, x: float, y: float, z: float, r: float = 0.6, tiers: int = 3, seed: int = 0,
				  where: str = "bg") -> list:
	"""The classic clipped stack: `tiers` balls shrinking upward on a bare stem, standing on z (the
	top of a hedge or a pot)."""
	out = [K.cyl(f"{name}_stem", 0.07 * r / 0.6, r * (2.6 + 1.2 * (tiers - 2)), (x, y, z), mat_bark(), where, seg=8)]
	zz = z + r * 0.9
	for k in range(tiers):
		rk = r * (1.0 - 0.27 * k)
		out.append(topiary_ball(f"{name}_t{k}", x, y, zz + rk, rk, seed=seed + k, where=where))
		zz += rk * 2 + r * 0.32
	return out


# --- sky ----------------------------------------------------------------------------------------------
def sky(name: str = "sky", y: float = 14.0, z0: float = -2.0, z1: float = 16.0, width: float = 44.0,
		where: str = "bg", top: str = "sc_sky_top", horizon: str = "sc_sky_hor") -> list:
	"""A gradient backdrop, horizon colour at the bottom (z0) to deep blue at the top (z1)."""
	return [K.box(name, (width, 0.2, z1 - z0), (0, y, (z0 + z1) / 2), mat_sky(top, horizon), where, bevel=0)]


def sun(name: str, x: float, y: float, z: float, r: float = 0.9, where: str = "bg", spread: float = 0.1) -> list:
	"""A sun disc with two soft halo rings behind it (`spread` = how far back each ring sits)."""
	out = [K.sph(f"{name}_disc", r, (x, y, z), K.mat(K.C["sc_sun"], 0.9, 2.5), where, scale=(1, 0.1, 1))]
	for k, (f, e) in enumerate(((1.45, 0.9), (1.9, 0.45))):
		out.append(K.sph(f"{name}_halo{k}", r * f, (x, y + spread * (k + 1), z), K.mat(K.C["sc_sun_halo"], 0.9, e), where, scale=(1, 0.04, 1)))
	return out


def cloud(name: str, x: float, y: float, z: float, w: float = 3.0, seed: int = 0, where: str = "bg",
		  haze: float = 0.0) -> list:
	"""A cumulus `w` wide: a row of puffs, tallest in the middle, on a flat belly at z."""
	rnd = random.Random(seed)
	m = mat_cloud(haze)
	n = max(3, int(w / 0.7))
	out = []
	for k in range(n):
		t = (k + 0.5) / n
		px = x - w / 2 + t * w + rnd.uniform(-0.15, 0.15)
		r = (0.45 + 0.55 * math.sin(t * math.pi)) * w * 0.2 * rnd.uniform(0.85, 1.15)
		out.append(blob(f"{name}_p{k}", r, (px, y + rnd.uniform(-0.1, 0.1), z + r * 0.55), m, where,
						scale=(1.15, 0.35, 0.9), seed=rnd.randint(0, 9999), lump=0.12, flat_base=-r * 0.5))
	return out


def hills(name: str, y: float = 12.0, x0: float = -22.0, x1: float = 22.0, h: float = 2.4, seed: int = 0,
		  where: str = "bg", colour: str = "sc_hill1", haze: float = 0.25) -> list:
	"""A row of rolling hills on the horizon (big, flattened, pale)."""
	rnd = random.Random(seed)
	m = mat_flat(colour, 0.95, haze)
	out = []
	x = x0
	k = 0
	while x < x1:
		r = rnd.uniform(3.0, 5.0)
		out.append(blob(f"{name}_{k}", r, (x + r * 0.7, y + rnd.uniform(-0.2, 0.2), 0.0), m, where,
						scale=(1.3, 0.2, h / r * rnd.uniform(0.8, 1.2)), seed=rnd.randint(0, 9999), lump=0.05, subdiv=3))
		x += r * 1.5
		k += 1
	return out


def window_view(name: str, win, wall_y: float = K.WALL_Y, where: str = "bg", seed: int = 0, sun_at=(-0.3, 0.3),
				clouds=((0.3, 0.28, 0.32), (-0.15, 0.12, 0.22)), hills: bool = True, bushes: bool = True,
				lawn: float = 0.3, fence: bool = False, glow: float = 0.3) -> list:
	"""The garden seen through a window in the back wall: sky, sun, hazy hills, a row of bushes, a
	striped lawn, clouds and (optionally) a picket fence — all inside `win` = (centre x, centre z,
	width, height) and within the ~0.3 units between the wall and the window frame, so a frame 0.18
	wide hides the edges. `sun_at` / cloud entries are fractions of the window (x, z[, width]).
	Pieces glow a little (`glow`) because a window is brighter than the room looking out of it."""
	cx, cz, w, h = win
	x0, x1, z0, z1 = cx - w / 2, cx + w / 2, cz - h / 2, cz + h / 2
	rnd = random.Random(seed)
	out = [K.box(f"{name}_sky", (w, 0.02, h), (cx, wall_y - 0.02, cz), mat_sky(), where, bevel=0)]
	if sun_at:
		out += sun(f"{name}_sun", cx + sun_at[0] * w, wall_y - 0.05, cz + sun_at[1] * h, 0.085 * h, where, spread=0.012)
	lawn_h = lawn * h
	if hills:
		hm = mat_flat("sc_hill2", 0.95, 0.35, 0.3)
		x = x0 + 0.2
		k = 0
		while x < x1 - 0.2:
			r = rnd.uniform(0.35, 0.55) * (h / 2.2)
			out.append(blob(f"{name}_hill{k}", r, (min(max(x + r * 0.6, x0 + 0.1), x1 - 0.1), wall_y - 0.08, z0 + lawn_h - r * 0.55),
							hm, where, scale=(1.4, 0.05 / r, 0.9), seed=rnd.randint(0, 9999), lump=0.05, subdiv=2))
			x += r * 1.5
			k += 1
	if bushes:
		bw = 0.52 * (h / 2.2)
		n = max(2, int((w - 0.3) / (bw * 0.95)))
		for k in range(n):
			bx = x0 + 0.2 + bw / 2 + k * (w - 0.4 - bw) / max(1, n - 1)
			out += bush(f"{name}_bush{k}", bx, wall_y - 0.13, bw, bw * 0.7, seed=rnd.randint(0, 9999), where=where, depth=0.03, glow=glow,
						z0=z0 + lawn_h * 0.75)
	if lawn > 0:
		out.append(K.box(f"{name}_lawn", (w, 0.03, lawn_h), (cx, wall_y - 0.06, z0 + lawn_h / 2),
						 mat_lawn("sc_lawn_a", "sc_lawn_b", 2.2 / (w / 3.2), 0, f"sc_winlawn_{name}", glow=glow), where, bevel=0))
	for k, c in enumerate(clouds or ()):
		fx, fz = c[0], c[1]
		cw = (c[2] if len(c) > 2 else 0.3) * w
		out += cloud(f"{name}_cloud{k}", cx + fx * w, wall_y - 0.1, cz + fz * h, cw, seed=rnd.randint(0, 9999), where=where)
	if fence:
		out += picket_fence(f"{name}_fence", x0 + 0.12, x1 - 0.12, wall_y - 0.14, h=0.42 * (h / 2.6), spacing=0.3, where=where, z0=z0 + 0.04)
	return out


# --- garden ground ------------------------------------------------------------------------------------
def picket_fence(name: str, x0: float, x1: float, y: float, h: float = 1.9, gaps: tuple = (), spacing: float = 0.3,
				 where: str = "bg", colour: str = "sc_fence", shade: str = "sc_fence_dk", z0: float = 0.0) -> list:
	"""Pointed pickets on two rails from x0 to x1, standing on z0, leaving `gaps` = ((centre, width), ...) open."""
	out = []
	n = int((x1 - x0) / spacing) + 1
	for i in range(n):
		x = x0 + i * spacing
		if any(abs(x - gc) < gw / 2 + 0.05 for gc, gw in gaps):
			continue
		out.append(K.prism(f"{name}_p{i}", [(-0.11, 0), (0.11, 0), (0.11, h), (0, h + 0.15), (-0.11, h)], 0.06,
						   (x, y, z0), K.mat(K.C[colour if i % 2 else shade], 0.8), where))
	for z in (0.29 * h, 0.79 * h):
		out.append(K.box(f"{name}_rail{z:.2f}", (x1 - x0, 0.06, 0.12 * h / 1.9), ((x0 + x1) / 2, y + 0.08, z0 + z), K.mat(K.C[shade], 0.8), where, bevel=0.02))
	return out


def flower_bed(name: str, x0: float, x1: float, y: float, seed: int = 0, skip: tuple = (), where: str = "bg",
			   colours: tuple = ("sc_petal1", "sc_petal2", "sc_petal3", "sc_petal4"), spacing: float = 0.33) -> list:
	"""A soil strip with tulips in rows, each with a pair of leaves; `skip` = ((centre, width), ...)."""
	rnd = random.Random(seed)
	out = [K.box(f"{name}_soil", (x1 - x0, 0.7, 0.12), ((x0 + x1) / 2, y, 0.06), mat_flat("sc_soil", 0.95), where, bevel=0.03)]
	stem = mat_flat("sc_grass", 0.8)
	n = int((x1 - x0) / spacing)
	for i in range(n):
		x = x0 + (i + 0.5) * spacing
		if any(abs(x - c) < w / 2 for c, w in skip):
			continue
		hh = 0.55 + 0.12 * ((i * 7) % 3)
		out.append(K.cyl(f"{name}_st{i}", 0.025, hh, (x, y, 0.1), stem, where, seg=6))
		for side in (-1, 1):
			out.append(K.prism(f"{name}_lf{i}{side}", [(0, 0), (0.06, 0.05), (0.02, 0.38)], 0.02, (x, y - 0.02, 0.12),
							   stem, where, rot=(90, 0, side * 25)))
		c = mat_flat(colours[(i + rnd.randint(0, 1)) % len(colours)], 0.55)
		out.append(K.cyl(f"{name}_cup{i}", 0.08, 0.16, (x, y, 0.1 + hh), c, where, r2=0.12, seg=12))
		for k in range(3):
			a = k / 3 * math.tau
			out.append(K.prism(f"{name}_pt{i}{k}", [(-0.05, 0), (0.05, 0), (0.0, 0.1)], 0.02,
							   (x + math.cos(a) * 0.07, y + math.sin(a) * 0.07 - 0.02, 0.24 + hh), c, where, rot=(90, 0, math.degrees(a))))
	return out


def grass_tufts(name: str, x0: float, x1: float, y: float, n: int = 30, seed: int = 0, where: str = "bg",
				depth: float = 0.3) -> list:
	"""Little tufts of blades scattered along a line (lawn edges, fence feet, path sides)."""
	rnd = random.Random(seed)
	ms = (mat_flat("sc_grass", 0.8), mat_flat("sc_grass_lt", 0.8))
	out = []
	for k in range(n):
		x = rnd.uniform(x0, x1)
		yy = y + rnd.uniform(-depth, depth)
		for b in range(3):
			h = rnd.uniform(0.15, 0.3)
			out.append(K.prism(f"{name}_{k}_{b}", [(-0.025, 0), (0.025, 0), (0.0, h)], 0.01, (x + (b - 1) * 0.04, yy, 0),
							   ms[(k + b) % 2], where, rot=(90, 0, (b - 1) * 22 + rnd.uniform(-8, 8))))
	return out


def stepping_stones(name: str, pts, r: float = 0.32, seed: int = 0, where: str = "bg") -> list:
	"""Flat, slightly irregular paving stones at the (x, y) points."""
	rnd = random.Random(seed)
	out = []
	for k, (x, y) in enumerate(pts):
		m = mat_flat("sc_stone" if k % 2 else "sc_stone_dk", 0.9)
		out.append(blob(f"{name}_{k}", r * rnd.uniform(0.85, 1.1), (x, y, 0.0), m, where, scale=(1.25, 0.95, 0.12),
						seed=rnd.randint(0, 9999), lump=0.12, subdiv=2))
	return out


# --- catalogue ---------------------------------------------------------------------------------------
def catalogue() -> None:
	"""Every piece in a row on a lawn under a sky, for review."""
	sky("cat_sky")
	sun("cat_sun", -1.8, 13.5, 3.6, 0.6)
	hills("cat_hills_far", y=12.5, colour="sc_hill3", haze=0.4, seed=2)
	hills("cat_hills", y=11.5, colour="sc_hill2", haze=0.2, seed=3, h=1.8)
	for i, (cx, cz, w) in enumerate(((-5.0, 3.0, 3.4), (2.8, 3.4, 2.6), (8.0, 2.6, 3.0))):
		cloud(f"cat_cloud{i}", cx, 13.0, cz, w, seed=i)
	K.box("cat_lawn", (40.0, 16.0, 0.2), (0, 6.0, -0.1), mat_lawn(), bevel=0)
	tree("cat_oak", -7.5, 3.0, 1.0, "oak", seed=1)
	tree("cat_apple", -3.6, 3.0, 0.8, "oak", seed=2, fruit="sc_apple")
	tree("cat_poplar", -0.8, 3.0, 1.0, "poplar", seed=3)
	tree("cat_pine", 1.6, 3.0, 1.0, "pine", seed=4)
	tree("cat_birch", 4.2, 3.0, 1.0, "birch", seed=5)
	tree("cat_far", 7.6, 6.0, 0.9, "oak", seed=6, haze=0.45)
	bush("cat_bush", -6.0, 1.6, 1.8, 1.2, seed=7)
	bush("cat_rose", -3.8, 1.6, 1.4, 1.0, seed=8, flowers=("sc_petal1", "sc_petal3"))
	hedge("cat_hedge", -1.8, 1.0, 1.8, 1.4, seed=9)
	topiary_ball("cat_ball", 2.2, 1.8, 0.65, 0.6)
	topiary_tiers("cat_tiers", 0.0, 1.9, 1.3, 0.45, seed=11)
	flower_bed("cat_bed", 3.0, 6.5, 1.6)
	picket_fence("cat_fence", 6.8, 9.4, 2.4)
	grass_tufts("cat_tufts", -9.0, 9.0, 0.5, n=40)
	stepping_stones("cat_stones", [(-1.5 + k * 0.8, 0.7) for k in range(5)])
	K.box("cat_boards", (1.4, 0.2, 1.2), (5.6, 0.6, 0.6), mat_boards("#B8794A", "#A86A3E"), bevel=0.02)
	K.box("cat_wall", (3.4, 0.3, 2.9), (-7.0, 2.65, 5.4), K.mat("#E7CC95", 0.85), bevel=0)
	window_view("cat_win", (-7.0, 5.4, 2.6, 2.0), wall_y=2.5, fence=True)
	for side in (-1, 1):
		K.box(f"cat_winf{side}", (0.18, 0.26, 2.2), (-7.0 + side * 1.39, 2.32, 5.4), K.mat("#FFF4DE", 0.6))
	K.box("cat_winf_t", (2.96, 0.26, 0.18), (-7.0, 2.32, 6.49), K.mat("#FFF4DE", 0.6))
	K.box("cat_winf_b", (2.96, 0.26, 0.18), (-7.0, 2.32, 4.31), K.mat("#FFF4DE", 0.6))
	K.box("cat_slates", (1.4, 0.2, 0.7), (8.4, 0.6, 0.4), mat_shingles("#3F4A5A", "#566273"), bevel=0.02, rot=(-80, 0, 0))


def main() -> int:
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(HERE, "out_scenery")
	if "--engine" in argv:
		K.ENGINE["name"] = argv[argv.index("--engine") + 1]
	K.ENGINE["samples"] = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 48
	os.makedirs(out, exist_ok=True)
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	catalogue()
	cam = K.make_camera(scene)
	K.setup_render(scene, cam)
	bpy.context.view_layer.update()
	K.render_layer(scene, ["bg"], os.path.join(out, "scenery.png"))
	print("[scenery] catalogue ->", os.path.join(out, "scenery.png"))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
