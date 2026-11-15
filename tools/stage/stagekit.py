"""stagekit — the render loop every Act's set shares (tools/stage/act2_set.py, act3_set.py).

An Act's set script models its room, props and sequences, then calls run(): the proscenium, Stalls,
HUD icons and dust come from act1_set, every layer is rendered to its own PNG (props/fg with a
border, sequences frame by frame, icons and local effects on their own square camera) and the
named marks/pivots are projected into marks.json. build.py crops and packs the result.
"""
from __future__ import annotations

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # type: ignore  # noqa: E402
from mathutils import Euler, Vector  # type: ignore  # noqa: E402

import act1_set as K  # noqa: E402


def run(build, lights, default_out: str) -> int:
	"""Build a set and render every layer. `build()` returns (marks, pivots, seqs) after modelling the
	Act's own room, props and sequences; `lights(scene, cam)` sets the render up and lights it."""
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	out = argv[argv.index("--out") + 1] if "--out" in argv else default_out
	only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else []
	if "--engine" in argv:
		K.ENGINE["name"] = argv[argv.index("--engine") + 1]
	if "--samples" in argv:
		K.ENGINE["samples"] = int(argv[argv.index("--samples") + 1])
	os.makedirs(out, exist_ok=True)
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	marks, piv, seqs = build()
	fx_local = K.build_fx_local()
	K.build_frame()
	K.build_audience()
	K.build_icons()
	cam = K.make_camera(scene)
	lights(scene, cam)
	bpy.context.view_layer.update()

	COLL = K.COLL
	room = [n for n in COLL if not n.startswith(("prop_", "fg_", "icon_", "frame", "seq_", "fxs_", "fx_", "audience", "lights"))]
	layers = {"bg": room, "frame": ["frame"], "audience": ["audience"]}
	for n in COLL:                   # glow layers (a light shaft, a moonlit window), each on its own
		if n.startswith("fx_"):
			layers[n] = [n]
	for n in COLL:
		if n.startswith(("prop_", "fg_")):
			layers[n] = [n]
	for name, cols in layers.items():
		if only and name not in only:
			continue
		small = name.startswith(("prop_", "fg_", "fx_"))
		K.render_layer(scene, cols, os.path.join(out, f"{name}.png"),
					   samples=max(32, K.ENGINE["samples"] // 2) if small else 0,
					   border=K.screen_box(scene, cam, cols) if small else None)
		print(f"[set] {name}")
	for name, (n, fn) in seqs.items():
		if only and f"seq_{name}" not in only:
			continue
		bx = None
		for k in range(n):
			fn(k)
			bpy.context.view_layer.update()
			bx = K.screen_box(scene, cam, [f"seq_{name}"], bx)
		for k in range(n):
			fn(k)
			bpy.context.view_layer.update()
			K.render_layer(scene, [f"seq_{name}"], os.path.join(out, f"seq_{name}_{k:02d}.png"),
						   samples=max(24, K.ENGINE["samples"] // 3), border=bx)
		fn(0)
		print(f"[set] seq_{name} x{n}")

	icons = [n for n in COLL if n.startswith("icon_")]
	scene.render.resolution_x = scene.render.resolution_y = 256
	cd = bpy.data.cameras.new("icam")
	cd.type = "ORTHO"
	ic = bpy.data.objects.new("icam", cd)
	scene.collection.objects.link(ic)
	ic.rotation_euler = Euler((math.radians(90), 0, 0))
	for n in icons:
		if only and n not in only:
			continue
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
		K.render_layer(scene, [n], os.path.join(out, f"{n}.png"), samples=48)
		print(f"[set] {n}")
	for name, (n, fn) in fx_local.items():
		if only and f"fxs_{name}" not in only:
			continue
		ic.location = (0, -20, 1.0)
		cd.ortho_scale = 4.0
		scene.camera = ic
		for k in range(n):
			fn(k)
			bpy.context.view_layer.update()
			K.render_layer(scene, [f"fxs_{name}"], os.path.join(out, f"fxs_{name}_{k:02d}.png"), samples=32)
		print(f"[set] fxs_{name} x{n}")
	scene.camera = cam
	scene.render.resolution_x, scene.render.resolution_y = K.W, K.H

	data = {
		"size": [K.W, K.H], "px_per_unit": K.PX, "floor_px": K.FLOOR_PX, "tilt_deg": math.degrees(K.TILT),
		"marks": {k: K.to_px(scene, cam, v) for k, v in marks.items()},
		"pivots": {k: (K.to_px(scene, cam, v) if isinstance(v, tuple) else v) for k, v in piv.items()},
		"fx_canvas": {"size": 256, "units": 4.0, "anchor_units": [0.0, -1.0]},
	}
	with open(os.path.join(out, "marks.json"), "w") as fh:
		json.dump(data, fh, indent=1)
	print("[set] marks written")
	return 0



def curtain(mat, cyl, box):
	"""The house curtains as a baked sequence (only the closed frame 0 is drawn now; the game gathers it)."""
	fy = -2.2
	pleats = []
	for side in (-1, 1):
		for k in range(16):
			o = cyl(f"cur{side}_{k}", 0.34, 9.0, (0, fy + 0.7 + (k % 2) * 0.12, -1.6),
					mat("velvet" if k % 2 else "velvet_dk", 0.85), "seq_curtain", seg=16)
			pleats.append((o, side, k))
		hem = box(f"cur_hem{side}", (9.8, 0.5, 0.25), (side * 4.9, fy + 0.5, -0.4), mat("gold", 0.4, 0, 0.6), "seq_curtain", bevel=0.05)
		pleats.append((hem, side, -1))
	gs = [1.0]

	def frame(k: int) -> None:
		g = gs[k]
		for o, side, i in pleats:
			if i < 0:
				o.scale = (g, 1, 1)
				o.location.x = side * (9.0 - 4.9 * g)
				continue
			o.location.x = side * (9.0 - (15.5 - i) * 0.6 * g)
	return (len(gs), frame)


def lights(scene, cam, points, sun=None, world=None) -> None:
	"""Replace act1's lights: `points` = [(name, loc, energy_cycles, colour, radius)], `sun` = (energy,
	angle_deg, colour, rot_deg), `world` = (colour, strength)."""
	K.setup_render(scene, cam)
	for o in list(K.coll("lights").objects):
		bpy.data.objects.remove(o, do_unlink=True)
	cyc = K.ENGINE["name"] == "cycles"
	if world:
		scene.world.node_tree.nodes["Background"].inputs[0].default_value = world[0]
		scene.world.node_tree.nodes["Background"].inputs[1].default_value = world[1] if cyc else world[1] * 1.4
	lc = K.coll("lights")
	if sun:
		ld = bpy.data.lights.new("sun", "SUN")
		ld.energy = sun[0] if cyc else sun[0] * 0.85
		ld.angle = math.radians(sun[1])
		ld.color = sun[2]
		o = bpy.data.objects.new("sun", ld)
		o.rotation_euler = Euler([math.radians(v) for v in sun[3]])
		lc.objects.link(o)
	for name, loc, energy, colr, rad in points:
		ld = bpy.data.lights.new(name, "POINT")
		ld.energy = energy if cyc else energy * 1.6
		ld.color = colr
		ld.shadow_soft_size = rad
		o = bpy.data.objects.new(name, ld)
		o.location = loc
		lc.objects.link(o)
