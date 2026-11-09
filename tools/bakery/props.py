"""props — the things the cast holds, built as chunky flat-colour low-poly meshes. Runs in Blender.

Every item is authored in its own PROP SPACE: the origin is where the hand grips it, +Z runs along the
handle (out of the thumb side of a fist), +X is across, sizes are in Hush-model units (her body is
2.2 tall). bake.py turns prop space into the holding bone's space and scales by character, so one
apple is one apple in either hand.

Each builder returns [(bmesh, colour name), ...]; one Blender object per part, one flat material per
colour. Shapes are big and simple on purpose: at ~50 px a prop is a dozen pixels, and only its
silhouette and its colour survive (a saw is a long grey blade on a brown grip, nothing finer).

Items come from the GDD's item list where they exist (apple, kipper, feather duster, Clarence) plus
a few the cast's own business needs (saw, mallet, spanner for rigging; Gus's stopwatch).
"""
from __future__ import annotations

import math
import os
import sys

import bmesh  # type: ignore
from mathutils import Matrix, Vector  # type: ignore

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art3d", "look-toy"))
import toy_lib as T  # noqa: E402

# Flat colours. The bake converts them to linear for the Standard view transform, so they land on
# the sprite as written.
PALETTE = {
	"wood": "#9A6638",
	"wood_dark": "#6E4424",
	"steel": "#B9C2CC",
	"steel_dark": "#7D8794",
	"apple": "#D8323C",
	"leaf": "#4FA845",
	"fish": "#C98A3E",
	"fish_belly": "#EAD7A8",
	"chicken": "#FFD23F",       # Clarence (GDD §2)
	"comb": "#E23B4E",          # Clarence's comb (GDD §2)
	"beak": "#F28C28",
	"ink": "#1A1418",
	"white": "#FFFFFF",
	"feather": "#F27BB0",
	"silver": "#D9DEE5",
	"debug_red": "#FF2A2A",
	"debug_blue": "#2A6BFF",
}
TAG = "beret"   # toy_lib's vertex-colour tag; unused here (colour comes from the part's material)


def _blob(c, a, b, cc, p=2.2, n=10):
	return T.se_blob(Vector(c), a, b, cc, p, TAG, n=n)


def _rod(pts, radii, seg=10):
	return T.capsule_chain([Vector(p) for p in pts], radii, TAG, seg=seg, cap_rings=2, samples_per_m=40)


def _cyl(r, h, base, rot=(0, 0, 0), seg=16, r2=None):
	return T.cylinder(r, r if r2 is None else r2, h, base, TAG, seg=seg, rot=rot)


def _box(size, centre, rot=(0, 0, 0)):
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.transform(bm, matrix=Matrix.Diagonal((*size, 1.0)), verts=bm.verts[:])
	T.rot_about(bm, (0, 0, 0), rot)
	bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(centre)), verts=bm.verts[:])
	return bm


def stick():
	"""Debug: shows where prop space lands in a hand (red = +Z tip, blue = +X)."""
	return [(_rod([(0, 0, -0.1), (0, 0, 0.5)], [0.025, 0.025]), "steel"),
			(_blob((0, 0, 0.5), 0.05, 0.05, 0.05), "debug_red"),
			(_blob((0.12, 0, 0), 0.04, 0.04, 0.04), "debug_blue")]


def apple():
	r = 0.10
	return [(_blob((0, 0, 0.02), r, r, r * 0.92, p=2.0), "apple"),
			(_rod([(0, 0, 0.02 + r * 0.8), (0.01, 0, 0.02 + r * 1.25)], [0.012, 0.01], seg=6), "wood_dark"),
			(_blob((0.04, 0, 0.02 + r * 1.15), 0.045, 0.012, 0.022), "leaf")]


def kipper():
	"""Held by the tail; the body hangs along +Z."""
	body = _blob((0, 0, 0.24), 0.07, 0.025, 0.2, p=2.0)
	return [(body, "fish"),
			(_blob((0, 0, 0.21), 0.05, 0.027, 0.13, p=2.0), "fish_belly"),
			(_box((0.16, 0.012, 0.09), (0, 0, 0.0), rot=(0, 0, 0)), "fish"),
			(_blob((0.035, -0.02, 0.38), 0.018, 0.01, 0.018), "ink")]


def saw():
	return [(_box((0.06, 0.07, 0.15), (0, 0, 0.0)), "wood"),
			(_box((0.16, 0.012, 0.55), (0.04, 0, 0.35)), "steel"),
			(_box((0.05, 0.014, 0.55), (-0.03, 0, 0.35)), "steel_dark")]


def mallet():
	return [(_rod([(0, 0, -0.08), (0, 0, 0.36)], [0.022, 0.022]), "wood"),
			(_cyl(0.075, 0.24, (-0.12, 0, 0.42), rot=(0, 90, 0)), "wood_dark")]


def spanner():
	return [(_rod([(0, 0, -0.06), (0, 0, 0.26)], [0.024, 0.024]), "steel"),
			(_cyl(0.06, 0.03, (0, -0.015, 0.31), rot=(90, 0, 0)), "steel"),
			(_box((0.05, 0.035, 0.07), (0, 0, 0.35)), "steel_dark")]


def duster():
	return [(_rod([(0, 0, -0.08), (0, 0, 0.32)], [0.018, 0.018]), "wood"),
			(_blob((0, 0, 0.44), 0.11, 0.11, 0.15, p=1.6), "feather"),
			(_blob((0, 0, 0.56), 0.06, 0.06, 0.06, p=1.6), "feather")]


def stopwatch():
	"""A big chrome stopwatch, face toward -Y of prop space."""
	return [(_cyl(0.085, 0.04, (0, 0.02, 0.09), rot=(90, 0, 0), seg=18), "silver"),
			(_cyl(0.068, 0.012, (0, -0.02, 0.09), rot=(90, 0, 0), seg=18), "white"),
			(_box((0.008, 0.008, 0.05), (0, -0.034, 0.105)), "ink"),
			(_cyl(0.018, 0.03, (0, 0, 0.175), seg=8), "silver")]


def clarence():
	"""Hush's rubber chicken (GDD §2): yellow, floppy, red comb. Held (or tucked) by the feet; the
	body rises along +Z, the long neck flops forward (+X) to the head."""
	return [(_blob((0, 0, 0.13), 0.09, 0.08, 0.12, p=2.0), "chicken"),
			(_rod([(0.0, 0, 0.22), (0.04, 0, 0.32), (0.10, 0, 0.36)], [0.035, 0.03, 0.03]), "chicken"),
			(_blob((0.12, 0, 0.37), 0.055, 0.05, 0.05, p=2.0), "chicken"),
			(_blob((0.115, 0, 0.43), 0.04, 0.012, 0.035, p=1.8), "comb"),
			(_blob((0.185, 0, 0.365), 0.04, 0.02, 0.015, p=2.0), "beak"),
			(_blob((0.14, -0.045, 0.385), 0.012, 0.008, 0.012), "ink"),
			(_rod([(0, 0, 0.02), (0, 0, -0.05)], [0.012, 0.012], seg=6), "beak")]


ITEMS = {f.__name__: f for f in (stick, apple, kipper, saw, mallet, spanner, duster, stopwatch, clarence)}


def build(item: str):
	if item not in ITEMS:
		raise SystemExit(f"[props] unknown item '{item}'; have {sorted(ITEMS)}")
	return ITEMS[item]()
