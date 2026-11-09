"""facekit — expression parts laid onto a character's face. Runs inside Blender.

Shared by the cast builders (neighbour.py dresses Gus, redress.py dresses Hush). A face that reads
at ~50 px is a few BIG shapes standing off the head; this module places them by ray-casting onto the
head mesh's front surface and skins them rigidly to the `head` bone.

Expression sets are meshes named "<Who>_Face.<expr>.<part>" ("all" = shown in every expression;
"neutral" may be absent — then neutral is the bare face). bake.py shows one set per frame, driven by
`face` in clips.json.
"""
from __future__ import annotations

import math
import os
import sys

import bmesh  # type: ignore
import bpy  # type: ignore
from mathutils import Matrix, Vector  # type: ignore

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art3d", "look-toy"))
import toy_lib as T  # noqa: E402

TAG = "beret"   # toy_lib vertex-colour tag; the real colour comes from the pinned palette cell


class FaceFrame:
	"""Points on the head's front surface, by (x across, z up) in metres, found by ray cast."""

	def __init__(self, head_ob):
		self.ob = head_ob
		self.inv = head_ob.matrix_world.inverted()

	def at(self, x: float, z: float) -> tuple[Vector, Vector]:
		o = self.inv @ Vector((x, -5.0, z))
		d = (self.inv.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
		ok, loc, no, _ = self.ob.ray_cast(o, d)
		if not ok:
			raise SystemExit(f"[facekit] face point ({x:.2f}, {z:.2f}) misses the head")
		mw = self.ob.matrix_world
		return mw @ loc, (mw.to_3x3() @ no).normalized()


def face_part(arm, mat, bm, name: str, uv: tuple[float, float], bone: str = "head"):
	"""One expression part: a mesh pinned to a flat palette cell, rigid on `bone`."""
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	me.uv_layers.new(name="UVMap")
	me.materials.append(mat)
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	for lp in me.uv_layers[0].data:
		lp.uv = uv
	g = ob.vertex_groups.new(name=bone)
	g.add(list(range(len(me.vertices))), 1.0, "REPLACE")
	ob.parent = arm
	mod = ob.modifiers.new("Armature", "ARMATURE")
	mod.object = arm
	return ob


def blob_on(ff: FaceFrame, x: float, z: float, w: float, h: float, depth: float, stand: float,
			tilt: float = 0.0, p: float = 2.4, n: int = 8):
	"""A flat superellipsoid lying on the face at (x, z): `w` x `h` across the surface, `depth`
	thick, its centre `stand` off the surface; `tilt` turns it in the face plane (degrees)."""
	pt, no = ff.at(x, z)
	c = pt + no * stand
	bm = T.se_blob(Vector((0, 0, 0)), w * 0.5, depth * 0.5, h * 0.5, p, TAG, n=n)
	yaw = math.atan2(no.x, -no.y)
	m = Matrix.Translation(c) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(math.radians(tilt), 4, "Y")
	bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
	return bm


def arc_on(ff: FaceFrame, x: float, z: float, w: float, rise: float, r: float,
		   stand: float = 0.02, n: int = 9):
	"""A curved tube on the face: a smile (`rise` < 0 ends up), a frown, a closed eyelid."""
	pts, rad = [], []
	for k in range(n):
		t = k / (n - 1) * 2.0 - 1.0
		px = x + t * w * 0.5
		pz = z + rise * (t * t)
		pt, no = ff.at(px, pz)
		pts.append(pt + no * stand)
		rad.append(r)
	return T.capsule_chain(pts, rad, TAG, seg=8, cap_rings=2, samples_per_m=60)
