"""neighbour — dress KayKit's blank Large mannequin (CC0) as the neighbour, Gus Thudd. Runs in Blender.

    blender -b --factory-startup --python-exit-code 1 --python neighbour.py -- \
        --src tools/bakery/cast/src/Mannequin_Large.glb --out tools/bakery/cast/out

Designed from scratch, not re-dressed from an earlier cast: the base is a featureless mannequin and
everything that makes him Gus is decided here, in one table (LOOK) and one function (dress).

Why paint by BONE, not by atlas cell: the mannequin's atlas shares cells across parts (the same
cell colours an arm, half the torso, a leg and part of the head), so repainting cells cannot give a
singlet on the chest and skin on the arms. Instead every face is assigned a colour by the bone that
carries most of its weight -- chest => singlet, wrist => wristband, lower leg => skin, foot =>
sneaker -- with height bands inside a part (sock tops, soles, waistband). Each face's UVs are pinned
to a flat cell of our own palette image. Skinning is untouched, so every KayKit clip, Large or
Medium, drives the costume exactly as it drove the mannequin.
"""
from __future__ import annotations

import math
import os
import sys

import bmesh  # type: ignore
import bpy  # type: ignore
from mathutils import Matrix, Vector  # type: ignore

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art3d", "look-toy"))
import facekit as FK  # noqa: E402
import toy_lib as T  # noqa: E402

# Gus Thudd. Loud gym kit on purpose: it is the funniest thing a man this proud could wear, and it
# keeps him far from Hush's navy / white / cherry so the two never blur at 50 px.
LOOK = {
	"skin": "#D99A6C",
	"skin_dark": "#B87850",
	"singlet": "#3FA34D",
	"singlet_trim": "#2B7A38",
	"shorts": "#F28C28",
	"shorts_stripe": "#FFF4E0",
	"band": "#F28C28",
	"sock": "#FFFFFF",
	"shoe": "#F5F5F0",
	"sole": "#3A3A44",
	"hair": "#3B2A20",
	# face (round 6): eyes, mouth, white (teeth / eye whites), temper flush
	"eye": "#1A1418",
	"mouth": "#5A1E22",
	"white": "#FFFFFF",
	"blush": "#E0533D",
}
GRID = 4                                 # palette cells per side
CELLS = {name: (i % GRID, i // GRID) for i, name in enumerate(LOOK)}


def argv() -> dict:
	raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	return {raw[i][2:]: raw[i + 1] for i in range(0, len(raw) - 1, 2) if raw[i].startswith("--")}


def hex_rgba(h: str) -> tuple[float, float, float, float]:
	h = h.lstrip("#")
	# palette pixels are stored linear; the Standard view transform turns them back into these hexes
	def lin(c: float) -> float:
		return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
	return (lin(int(h[0:2], 16) / 255), lin(int(h[2:4], 16) / 255), lin(int(h[4:6], 16) / 255), 1.0)


def make_palette(path: str) -> "bpy.types.Image":
	"""A GRID x GRID image of flat colour cells, 16 px each."""
	px = 16
	size = GRID * px
	img = bpy.data.images.new("gus_palette", size, size, alpha=True, float_buffer=True)
	pixels = [0.0] * (size * size * 4)
	for name, (cx, cy) in CELLS.items():
		col = hex_rgba(LOOK[name])
		for y in range(px):
			for x in range(px):
				# image rows run bottom-up; cell (cx, cy) is counted from the top
				row = size - 1 - (cy * px + y)
				i = (row * size + cx * px + x) * 4
				pixels[i:i + 4] = col
	img.pixels = pixels
	img.filepath_raw = path
	img.file_format = "PNG"
	img.save()
	img.pack()
	return img


def cell_uv(name: str) -> tuple[float, float]:
	cx, cy = CELLS[name]
	return ((cx + 0.5) / GRID, 1.0 - (cy + 0.5) / GRID)


def make_material(img) -> "bpy.types.Material":
	m = bpy.data.materials.new("gus")
	m.use_nodes = True
	nt = m.node_tree
	bsdf = nt.nodes["Principled BSDF"]
	bsdf.inputs["Roughness"].default_value = 0.85
	tex = nt.nodes.new("ShaderNodeTexImage")
	tex.image = img
	tex.interpolation = "Closest"
	nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	return m


def dominant_bone(ob, poly, names: list[str]) -> str:
	score: dict[str, float] = {}
	for vi in poly.vertices:
		for g in ob.data.vertices[vi].groups:
			n = names[g.group]
			score[n] = score.get(n, 0.0) + g.weight
	return max(score, key=score.get) if score else ""


def colour_for(bone: str, z: float, ref: dict) -> str:
	"""The costume, as rules. `ref` holds rest-pose heights measured off this body."""
	b = bone.rsplit(".", 1)[0]
	if b == "head":
		return "skin"
	if b in ("chest", "spine"):
		# the singlet ends in a darker hem just above the shorts
		return "singlet_trim" if z < ref["hem"] else "singlet"
	if b == "hips":
		return "shorts"
	if b in ("upperarm", "lowerarm", "hand", "handslot"):
		return "skin"
	if b == "wrist":
		return "band"
	if b == "upperleg":
		# track shorts stop mid-thigh; a thin light band at the leg hole is the stripe that sells them
		if z < ref["leg_hole"]:
			return "skin"
		return "shorts_stripe" if z < ref["leg_hole"] + ref["stripe"] else "shorts"
	if b == "lowerleg":
		return "sock" if z < ref["sock_top"] else "skin"
	if b in ("foot", "toes"):
		return "sole" if z < ref["sole"] else "shoe"
	return "skin"


def pin(ob, poly, name: str) -> None:
	u, v = cell_uv(name)
	uv = ob.data.uv_layers[0]
	for li in poly.loop_indices:
		uv.data[li].uv = (u, v)


def add_hair(arm, head_ob, mat) -> "bpy.types.Object":
	"""A flat-top crew cut: one bevelled block on the crown, rigid on the head bone. The silhouette
	does the work -- a square head-top on a huge body reads as 'gym teacher' at any size."""
	vs = [head_ob.matrix_world @ v.co for v in head_ob.data.vertices]
	lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
	hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
	size = hi - lo
	c = (lo + hi) * 0.5
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	for v in bm.verts:
		v.co = Vector((v.co.x * size.x * 0.86, v.co.y * size.y * 0.84, v.co.z * size.z * 0.26))
		v.co += Vector((c.x, c.y + size.y * 0.04, hi.z - size.z * 0.07))
	bmesh.ops.bevel(bm, geom=list(bm.edges), offset=size.x * 0.06, segments=2, affect="EDGES")
	me = bpy.data.meshes.new("Gus_Hair")
	bm.to_mesh(me)
	bm.free()
	me.uv_layers.new(name="UVMap")
	me.materials.append(mat)
	ob = bpy.data.objects.new("Gus_Hair", me)
	bpy.context.scene.collection.objects.link(ob)
	u, v = cell_uv("hair")
	for lp in me.uv_layers[0].data:
		lp.uv = (u, v)
	g = ob.vertex_groups.new(name="head")
	g.add(list(range(len(me.vertices))), 1.0, "REPLACE")
	ob.parent = arm
	mod = ob.modifiers.new("Armature", "ARMATURE")
	mod.object = arm
	return ob


# --- the face (round 6) --------------------------------------------------------------------------
# The mannequin head is blank and small for the body, so a face that reads at ~50 px has to be made
# of a few BIG shapes that stand off the head and survive a three-quarter view: heavy brows, a bulb
# nose, a strongman's handlebar moustache. Each expression is its own set of meshes named
# "Gus_Face.<expr>.<part>" ("all" = every expression); the bake shows one set per frame (`face` in
# clips.json), so a clip can go neutral -> shock on the frame he hears something.
EXPRESSIONS = ("neutral", "angry", "shock", "daze", "suspicious")


def add_face(arm, head_ob, mat) -> list:
	ff = FK.FaceFrame(head_ob)
	out = []

	blob_on = FK.blob_on

	def put(expr: str, part: str, cell: str, bm) -> None:
		out.append(FK.face_part(arm, mat, bm, f"Gus_Face.{expr}.{part}", cell_uv(cell)))

	ex, ez = 0.125, 3.575          # eyes
	bz = 3.665                     # brows
	# shared: the nose and the moustache are Gus in every mood
	put("all", "nose", "skin_dark", blob_on(ff, 0.0, 3.48, 0.13, 0.12, 0.13, 0.05, p=2.0))
	pts, rad = [], []
	for k in range(-6, 7):
		t = k / 6.0
		x = 0.27 * t
		z = 3.405 + 0.06 * (abs(t) ** 3) - 0.025 * (1 - abs(t))   # droops in the middle, curls up
		pt, no = ff.at(x, z) if abs(x) < 0.25 else ff.at(math.copysign(0.25, x), z)
		if abs(x) >= 0.25:
			pt = pt + Vector((x - math.copysign(0.25, x), 0.0, 0.0))
		pts.append(pt + no * 0.035)
		rad.append(0.022 + 0.03 * (1 - abs(t)) ** 1.5)
	put("all", "moustache", "hair", T.capsule_chain(pts, rad, "beret", seg=8, cap_rings=2, samples_per_m=60))

	for expr in EXPRESSIONS:
		for side in (1, -1):
			sx = side * ex
			# brows: inner end down = angry, raised and arched = shock
			tilt = {"neutral": 6, "angry": 24, "shock": -14, "daze": -6}.get(expr, 0)
			lift = {"neutral": 0.0, "angry": -0.035, "shock": 0.06, "daze": 0.02}.get(expr, 0.0)
			if expr == "suspicious":
				# one brow up, one clamped down: the universal "hmm?"
				tilt, lift = (-12, 0.055) if side > 0 else (22, -0.03)
			put(expr, f"brow{side:+d}", "hair",
				blob_on(ff, side * 0.13, bz + lift, 0.19, 0.065, 0.05, 0.03, tilt=-side * tilt, p=2.2))
			if expr == "shock":
				put(expr, f"eyewhite{side:+d}", "white", blob_on(ff, sx, ez, 0.11, 0.12, 0.03, 0.012, p=2.0))
				put(expr, f"eye{side:+d}", "eye", blob_on(ff, sx, ez, 0.045, 0.05, 0.03, 0.026, p=2.0))
			elif expr == "daze":
				# squeezed shut: a short bar each side, tilted like a wince
				put(expr, f"eye{side:+d}", "eye", blob_on(ff, sx, ez, 0.10, 0.025, 0.03, 0.018, tilt=-side * 14, p=2.2))
			else:
				h = 0.045 if expr == "angry" else 0.035 if expr == "suspicious" else 0.065
				put(expr, f"eye{side:+d}", "eye", blob_on(ff, sx, ez - (0.01 if expr == "angry" else 0), 0.05, h, 0.03, 0.018, p=2.0))
			if expr == "angry":
				# the temper flush (GDD: his face reddens with temper)
				put(expr, f"blush{side:+d}", "blush", blob_on(ff, side * 0.2, 3.47, 0.12, 0.07, 0.02, 0.008, p=2.0))
		# mouth, under the moustache
		if expr == "neutral":
			put(expr, "mouth", "mouth", blob_on(ff, 0.03, 3.325, 0.12, 0.03, 0.03, 0.012, tilt=-8, p=2.4))
		elif expr == "angry":
			put(expr, "mouth", "mouth", blob_on(ff, 0.0, 3.32, 0.2, 0.075, 0.03, 0.012, p=3.0))
			put(expr, "teeth", "white", blob_on(ff, 0.0, 3.32, 0.17, 0.045, 0.03, 0.02, p=3.0))
		elif expr == "shock":
			put(expr, "mouth", "mouth", blob_on(ff, 0.0, 3.315, 0.085, 0.085, 0.03, 0.014, p=2.0))
		elif expr == "suspicious":
			put(expr, "mouth", "mouth", blob_on(ff, -0.04, 3.32, 0.1, 0.028, 0.03, 0.012, tilt=14, p=2.4))
		else:
			put(expr, "mouth", "mouth", blob_on(ff, 0.0, 3.325, 0.11, 0.05, 0.03, 0.012, tilt=10, p=2.0))
	return out


def export(arm, path: str) -> None:
	bpy.ops.object.select_all(action="DESELECT")
	arm.select_set(True)
	for o in bpy.data.objects:
		if o.type == "MESH":
			o.select_set(True)
	bpy.context.view_layer.objects.active = arm
	kw = dict(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
			  export_animations=False, export_skins=True, export_materials="EXPORT",
			  export_image_format="AUTO", export_texcoords=True, export_normals=True)
	props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
	bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props or k == "filepath"})


def main() -> int:
	a = argv()
	out = a.get("out", "out")
	os.makedirs(out, exist_ok=True)
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=a["src"])
	arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
	for o in [o for o in bpy.data.objects if o.type == "MESH"]:
		if not any(m.type == "ARMATURE" for m in o.modifiers):
			bpy.data.objects.remove(o, do_unlink=True)     # KayKit's stray unskinned Icosphere
	meshes = [o for o in bpy.data.objects if o.type == "MESH"]

	def bone_z(name: str) -> float:
		return (arm.matrix_world @ arm.data.bones[name].head_local).z

	ref = {
		"hem": bone_z("hips") + (bone_z("spine") - bone_z("hips")) * 0.55,
		"leg_hole": bone_z("lowerleg.l") + (bone_z("upperleg.l") - bone_z("lowerleg.l")) * 0.45,
		"stripe": (bone_z("upperleg.l") - bone_z("lowerleg.l")) * 0.10,
		"sock_top": bone_z("foot.l") + (bone_z("lowerleg.l") - bone_z("foot.l")) * 0.42,
		"sole": bone_z("foot.l") * 0.30,
	}
	img = make_palette(os.path.join(out, "gus_palette.png"))
	mat = make_material(img)
	counts: dict[str, int] = {}
	for ob in meshes:
		names = [g.name for g in ob.vertex_groups]
		ob.data.materials.clear()
		ob.data.materials.append(mat)
		for poly in ob.data.polygons:
			poly.material_index = 0
			z = sum((ob.matrix_world @ ob.data.vertices[vi].co).z for vi in poly.vertices) / len(poly.vertices)
			col = colour_for(dominant_bone(ob, poly, names), z, ref)
			pin(ob, poly, col)
			counts[col] = counts.get(col, 0) + 1
	head = next(o for o in meshes if o.name.endswith("Head"))
	add_hair(arm, head, mat)
	parts = add_face(arm, head, mat)
	print(f"[neighbour] face: {len(parts)} parts over {len(EXPRESSIONS)} expressions")
	print("[neighbour] faces by colour: " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))
	glb = os.path.join(out, "gus.glb")
	export(arm, glb)
	print(f"[neighbour] gus -> {glb}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
