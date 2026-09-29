## LineLimb — rubber-hose limb geometry (TECH §4.7, comedy.md §1.3): a round-capped stroke
## (fill + ink outline) through a limb's joint positions. With 3 joints it is the quadratic
## curve that passes THROUGH the elbow / knee at its midpoint; 2 joints = a straight hose;
## 4+ = a Catmull-Rom spline through every joint.
##
## The stroke is written as textured triangles (for one batched triangle-array command per
## run of limbs, see RigPlayer): each strip maps u across its width onto the atlas' `@line`
## profile (soft 1-texel edges = anti-aliasing for free) and each end gets a `@disc` quad as
## its round cap. Per limb: ink strip, ink caps, fill strip, fill caps — VERTS vertices, TRIS
## triangles, a static topology (indices / uvs / colours are written once per layout).
## Pure and allocation-free (callers own every buffer).
class_name LineLimb
extends RefCounted

const SAMPLES := 8
const STRIP := SAMPLES * 2
const VERTS := STRIP * 2 + 16
const TRIS := (SAMPLES - 1) * 4 + 8
## A textured part drawn inside a triangle run: ghost 2, ghost 1, main (smears).
const QUAD_VERTS := 12
const QUAD_TRIS := 6


## Samples the limb curve through `joints[0..jn)` into `out[0..SAMPLES)`.
static func curve(joints: PackedVector2Array, jn: int, out: PackedVector2Array) -> void:
	if jn <= 1:
		for s in SAMPLES:
			out[s] = joints[0] if jn == 1 else Vector2.ZERO
		return
	if jn == 2:
		for s in SAMPLES:
			out[s] = joints[0].lerp(joints[1], float(s) / float(SAMPLES - 1))
		return
	if jn == 3:
		var p0 := joints[0]
		var p2 := joints[2]
		var c := joints[1] * 2.0 - (p0 + p2) * 0.5
		for s in SAMPLES:
			var t := float(s) / float(SAMPLES - 1)
			var u := 1.0 - t
			out[s] = p0 * (u * u) + c * (2.0 * u * t) + p2 * (t * t)
		return
	var segs := jn - 1
	for s in SAMPLES:
		var gt := float(s) / float(SAMPLES - 1) * float(segs)
		var k := mini(int(gt), segs - 1)
		var t2 := gt - float(k)
		var a := joints[maxi(k - 1, 0)]
		var b := joints[k]
		var c2 := joints[k + 1]
		var d := joints[mini(k + 2, jn - 1)]
		var t3 := t2 * t2
		out[s] = 0.5 * ((2.0 * b) + (-a + c2) * t2 + (2.0 * a - 5.0 * b + 4.0 * c2 - d) * t3 + (-a + 3.0 * b - 3.0 * c2 + d) * t3 * t2)


## The whole limb in one pass (the hot path): samples the curve through `joints[0..jn)` and
## writes its VERTS positions at `at` (character space). 3 joints (arm / leg through the elbow
## or knee) use the quadratic's analytic tangent for the normals; 2 joints a straight hose;
## 4+ joints fall back to curve() + write_positions() through `tmp` (SAMPLES points).
static func write_limb(joints: PackedVector2Array, jn: int, half_ink: float, half_fill: float, out: PackedVector2Array, at: int, tmp: PackedVector2Array) -> void:
	if jn != 3 and jn != 2:
		curve(joints, jn, tmp)
		write_positions(tmp, half_ink, half_fill, Transform2D.IDENTITY, out, at)
		return
	var p0 := joints[0]
	var p2 := joints[jn - 1]
	var c := joints[1] * 2.0 - (p0 + p2) * 0.5 if jn == 3 else (p0 + p2) * 0.5
	var d0 := c - p0
	var d1 := p2 - c
	var last := Vector2(1, 0)
	var fb := at + STRIP + 8
	var inv := 1.0 / float(SAMPLES - 1)
	for s in SAMPLES:
		var t := float(s) * inv
		var u := 1.0 - t
		var pt := p0 * (u * u) + c * (2.0 * u * t) + p2 * (t * t)
		var d := d0 * u + d1 * t
		var n := Vector2(-d.y, d.x)
		var ln := n.length()
		if ln > 0.0001:
			n /= ln
			last = n
		else:
			n = last
		var ni := n * half_ink
		var nf := n * half_fill
		var i := at + 2 * s
		out[i] = pt + ni
		out[i + 1] = pt - ni
		var j := fb + 2 * s
		out[j] = pt + nf
		out[j + 1] = pt - nf
	var ki := Vector2(half_ink, half_ink)
	var kj := Vector2(half_ink, -half_ink)
	var fi := Vector2(half_fill, half_fill)
	var fj := Vector2(half_fill, -half_fill)
	var a := at + STRIP
	out[a] = p0 - ki
	out[a + 1] = p0 + kj
	out[a + 2] = p0 + ki
	out[a + 3] = p0 - kj
	out[a + 4] = p2 - ki
	out[a + 5] = p2 + kj
	out[a + 6] = p2 + ki
	out[a + 7] = p2 - kj
	var f := at + 2 * STRIP + 8
	out[f] = p0 - fi
	out[f + 1] = p0 + fj
	out[f + 2] = p0 + fi
	out[f + 3] = p0 - fj
	out[f + 4] = p2 - fi
	out[f + 5] = p2 + fj
	out[f + 6] = p2 + fi
	out[f + 7] = p2 - fj


## Writes the limb's VERTS positions at `at` from the curve points `pts` (character space),
## mapped by `xf` (facing flip / shake). `half_ink` = width/2 + outline, `half_fill` = width/2.
## (RigPlayer passes IDENTITY and sets the character transform on the canvas instead: no
## per-vertex transform on the hot path.)
static func write_positions(pts: PackedVector2Array, half_ink: float, half_fill: float, xf: Transform2D, out: PackedVector2Array, at: int) -> void:
	var last := Vector2(1, 0)
	var ident := xf == Transform2D.IDENTITY
	var fb := at + STRIP + 8
	for s in SAMPLES:
		var d := pts[mini(s + 1, SAMPLES - 1)] - pts[maxi(s - 1, 0)]
		var n := Vector2(-d.y, d.x)
		var ln := n.length()
		if ln > 0.0001:
			n /= ln
			last = n
		else:
			n = last
		var p := pts[s]
		var ni := n * half_ink
		var nf := n * half_fill
		if ident:
			out[at + 2 * s] = p + ni
			out[at + 2 * s + 1] = p - ni
			out[fb + 2 * s] = p + nf
			out[fb + 2 * s + 1] = p - nf
		else:
			out[at + 2 * s] = xf * (p + ni)
			out[at + 2 * s + 1] = xf * (p - ni)
			out[fb + 2 * s] = xf * (p + nf)
			out[fb + 2 * s + 1] = xf * (p - nf)
	_cap(pts[0], half_ink, xf, out, at + STRIP, ident)
	_cap(pts[SAMPLES - 1], half_ink, xf, out, at + STRIP + 4, ident)
	_cap(pts[0], half_fill, xf, out, at + 2 * STRIP + 8, ident)
	_cap(pts[SAMPLES - 1], half_fill, xf, out, at + 2 * STRIP + 12, ident)


static func _cap(c: Vector2, r: float, xf: Transform2D, out: PackedVector2Array, at: int, ident: bool) -> void:
	if ident:
		out[at] = c + Vector2(-r, -r)
		out[at + 1] = c + Vector2(r, -r)
		out[at + 2] = c + Vector2(r, r)
		out[at + 3] = c + Vector2(-r, r)
		return
	out[at] = xf * (c + Vector2(-r, -r))
	out[at + 1] = xf * (c + Vector2(r, -r))
	out[at + 2] = xf * (c + Vector2(r, r))
	out[at + 3] = xf * (c + Vector2(-r, r))


## Collapses a limb's vertices (hidden limb): zero-area triangles.
static func collapse(out: PackedVector2Array, at: int, count: int) -> void:
	for i in count:
		out[at + i] = Vector2.ZERO


## Static part of a limb: uvs (`line_uv` / `disc_uv` normalised rects) and colours.
static func write_static(out_uv: PackedVector2Array, out_c: PackedColorArray, at: int, line_uv: Rect2, disc_uv: Rect2, ink: Color, fill: Color) -> void:
	var vmid := line_uv.position.y + line_uv.size.y * 0.5
	var u0 := line_uv.position.x
	var u1 := line_uv.position.x + line_uv.size.x
	for s in SAMPLES:
		out_uv[at + 2 * s] = Vector2(u0, vmid)
		out_uv[at + 2 * s + 1] = Vector2(u1, vmid)
		out_uv[at + STRIP + 8 + 2 * s] = Vector2(u0, vmid)
		out_uv[at + STRIP + 8 + 2 * s + 1] = Vector2(u1, vmid)
		out_c[at + 2 * s] = ink
		out_c[at + 2 * s + 1] = ink
		out_c[at + STRIP + 8 + 2 * s] = fill
		out_c[at + STRIP + 8 + 2 * s + 1] = fill
	for q in 4:
		var base := at + STRIP + q * 4 if q < 2 else at + 2 * STRIP + 8 + (q - 2) * 4
		out_uv[base] = disc_uv.position
		out_uv[base + 1] = disc_uv.position + Vector2(disc_uv.size.x, 0)
		out_uv[base + 2] = disc_uv.end
		out_uv[base + 3] = disc_uv.position + Vector2(0, disc_uv.size.y)
		var col := ink if q < 2 else fill
		for k in 4:
			out_c[base + k] = col


## Indices of one limb whose first vertex is `vb`, written at `at` (TRIS × 3 ints).
static func write_indices(out: PackedInt32Array, at: int, vb: int) -> void:
	var w := at
	for strip in 2:
		var sb := vb + (0 if strip == 0 else STRIP + 8)
		for s in SAMPLES - 1:
			var a := sb + 2 * s
			out[w] = a
			out[w + 1] = a + 1
			out[w + 2] = a + 2
			out[w + 3] = a + 1
			out[w + 4] = a + 3
			out[w + 5] = a + 2
			w += 6
		var cb := vb + (STRIP if strip == 0 else 2 * STRIP + 8)
		for q in 2:
			var c := cb + q * 4
			out[w] = c
			out[w + 1] = c + 1
			out[w + 2] = c + 2
			out[w + 3] = c
			out[w + 4] = c + 2
			out[w + 5] = c + 3
			w += 6
	# Draw order: ink strip + ink caps first, then fill strip + fill caps (above).


## Indices of one 3-quad part (ghost 2, ghost 1, main) at vertex `vb`.
static func write_quad_indices(out: PackedInt32Array, at: int, vb: int) -> void:
	for q in 3:
		var c := vb + q * 4
		var w := at + q * 6
		out[w] = c
		out[w + 1] = c + 1
		out[w + 2] = c + 2
		out[w + 3] = c
		out[w + 4] = c + 2
		out[w + 5] = c + 3


## One textured quad (4 vertices at `at`): rect `r` (part-local) through `xf`.
static func write_quad(xf: Transform2D, r: Rect2, uv: Rect2, col: Color, out_p: PackedVector2Array, out_uv: PackedVector2Array, out_c: PackedColorArray, at: int) -> void:
	out_p[at] = xf * r.position
	out_p[at + 1] = xf * Vector2(r.end.x, r.position.y)
	out_p[at + 2] = xf * r.end
	out_p[at + 3] = xf * Vector2(r.position.x, r.end.y)
	out_uv[at] = uv.position
	out_uv[at + 1] = Vector2(uv.end.x, uv.position.y)
	out_uv[at + 2] = uv.end
	out_uv[at + 3] = Vector2(uv.position.x, uv.end.y)
	out_c[at] = col
	out_c[at + 1] = col
	out_c[at + 2] = col
	out_c[at + 3] = col


## Positions only of a textured quad (its uvs / colours already written and unchanged).
static func write_quad_pos(xf: Transform2D, r: Rect2, out_p: PackedVector2Array, at: int) -> void:
	out_p[at] = xf * r.position
	out_p[at + 1] = xf * Vector2(r.end.x, r.position.y)
	out_p[at + 2] = xf * r.end
	out_p[at + 3] = xf * Vector2(r.position.x, r.end.y)
