## RigBounds — geometric queries on a solved pose (character space), shared by the lints,
## the sheet renderer and the player: the pose's bounding box, a part's rect corners, feet
## soles and limb stroke extents. Pure; uses the rig's authored texture sizes.
class_name RigBounds
extends RefCounted

## Canvas margin of authored SVGs (GDD §9.1: 3 px) — soles sit this far above a foot
## canvas' bottom edge.
const MARGIN := 3.0


## Size of the texture part `p` currently shows in `pose`.
static func part_size(rig: RigDef, pose: PackedFloat32Array, p: int) -> Vector2:
	var sizes: PackedVector2Array = rig.tex_sizes[p]
	if sizes.is_empty():
		return Vector2.ZERO
	var v := clampi(int(pose[RigDef.ROOT_CH + p * RigDef.STRIDE + RigDef.C_TEX]), 0, sizes.size() - 1)
	return sizes[v]


## True when part `p` draws something in `pose`.
static func part_visible(rig: RigDef, pose: PackedFloat32Array, p: int) -> bool:
	var b := RigDef.ROOT_CH + p * RigDef.STRIDE
	return rig.is_textured(p) and pose[b + RigDef.C_VIS] > 0.5 and pose[b + RigDef.C_ALPHA] > 0.01


## Bounding box (character space) of every visible part rect and limb stroke.
static func bbox(rig: RigDef, pose: PackedFloat32Array, xf: Array[Transform2D], inset: float = MARGIN) -> Rect2:
	var have := false
	var r := Rect2()
	for p in rig.names.size():
		if not part_visible(rig, pose, p):
			continue
		var s := part_size(rig, pose, p)
		var loc := Rect2(-rig.pivot[p] + Vector2(inset, inset), s - Vector2(inset, inset) * 2.0)
		for c in [loc.position, Vector2(loc.end.x, loc.position.y), loc.end, Vector2(loc.position.x, loc.end.y)]:
			var w: Vector2 = xf[p] * c
			if not have:
				r = Rect2(w, Vector2.ZERO)
				have = true
			else:
				r = r.expand(w)
	var pts := PackedVector2Array()
	pts.resize(LineLimb.SAMPLES)
	var joints := PackedVector2Array()
	for l in rig.limbs:
		var lb: RigDef.RigLimb = l
		joints.resize(lb.joints.size())
		for k in lb.joints.size():
			joints[k] = xf[lb.joints[k]].origin
		LineLimb.curve(joints, lb.joints.size(), pts)
		var hw := lb.width * 0.5 + lb.outline
		for q in pts:
			var e := Rect2(q - Vector2(hw, hw), Vector2(hw, hw) * 2.0)
			if not have:
				r = e
				have = true
			else:
				r = r.merge(e)
	return r


## The sole point (bottom centre, inset by the canvas margin) of foot part `p`.
static func sole(rig: RigDef, pose: PackedFloat32Array, xf: Array[Transform2D], p: int) -> Vector2:
	var s := part_size(rig, pose, p)
	var local := Vector2(s.x * 0.5, s.y - MARGIN) - rig.pivot[p]
	return xf[p] * local


## Lowest point (largest y) of the limb strokes (knees on the floor…).
static func limb_lowest(rig: RigDef, xf: Array[Transform2D]) -> float:
	var lo := -INF
	var pts := PackedVector2Array()
	pts.resize(LineLimb.SAMPLES)
	var joints := PackedVector2Array()
	for l in rig.limbs:
		var lb: RigDef.RigLimb = l
		joints.resize(lb.joints.size())
		for k in lb.joints.size():
			joints[k] = xf[lb.joints[k]].origin
		LineLimb.curve(joints, lb.joints.size(), pts)
		for q in pts:
			lo = maxf(lo, q.y + lb.width * 0.5 + lb.outline)
	return lo


## Rect corners (character space) of part `p`'s current texture.
static func corners(rig: RigDef, pose: PackedFloat32Array, xf: Array[Transform2D], p: int) -> PackedVector2Array:
	var s := part_size(rig, pose, p)
	var loc := Rect2(-rig.pivot[p], s)
	return PackedVector2Array([xf[p] * loc.position, xf[p] * Vector2(loc.end.x, loc.position.y), xf[p] * loc.end, xf[p] * Vector2(loc.position.x, loc.end.y)])


## Top of the head: the highest point of the look part's (head) rect.
static func head_top(rig: RigDef, pose: PackedFloat32Array, xf: Array[Transform2D]) -> Vector2:
	var h := rig.look_part if rig.look_part >= 0 else rig.root_index
	var s := part_size(rig, pose, h)
	return xf[h] * (Vector2(s.x * 0.5, MARGIN) - rig.pivot[h])
