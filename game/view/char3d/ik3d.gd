## Ik3D — analytic two-bone IK, foot grounding and hand reach for the cast.
##
## The other half of "the movements feel too basic". Two specific complaints in the audit come
## straight from having no IK at all:
##
## * **Feet slide and float.** The 2D clips carry a `plant` lock and a `stride_px` so the artist
##   could match the walk speed by hand, but the moment the sim moves a character at any other
##   speed — a detour, a +15 % hurry, a chase — the planted foot skates. `ground()` pins the stance
##   foot to the floor it is actually standing on and lets the knee take up the slack.
## * **Hands never land on anything.** REDESIGN_3D §1.3 called out `act_tinker_q`: 49 frames of
##   gloves moving ±10 px in front of the chest, identical for pepper→honey, lever→gramophone and
##   squeaker→kettle, with the prop never touching the hand. `reach()` puts the glove on the prop,
##   so one rig clip reads correctly at every one of §5.6's three reach bands.
##
## The solver is the closed-form one: with two fixed bone lengths and a target distance there is a
## single knee/elbow angle (law of cosines), and the remaining freedom is a roll about the
## root→target axis, fixed here by the chain's `bend` hint. No iteration, no convergence check,
## ~40 float ops per chain — it holds the §5.6 budget of ≤ 0.25 ms CPU for skinning plus jiggle.
class_name Ik3D
extends RefCounted

## A target closer than this to the root is treated as fully folded (avoids a divide by ~0).
const MIN_REACH := 0.001
## Depth of floor penetration over which a foot plant fades from 0 to full (metres).
const PLANT_BAND := 0.02
## How far past the chain's length a target may sit before the chain simply points at it.
const STRETCH_EPS := 0.0001


## Solve a two-bone chain so `tip` lands on `target` (both world space).
##
## Returns {upper: Quaternion, lower: Quaternion} as LOCAL rotations for the two bones, or an empty
## Dictionary when the chain is unusable. `bend_world` is the direction the joint should point
## (knee forward, elbow back); it only has to be roughly right — it is projected onto the plane
## perpendicular to root→target.
static func solve_two_bone(root_pos: Vector3, upper_len: float, lower_len: float,
		target: Vector3, bend_world: Vector3) -> Dictionary:
	var to_target := target - root_pos
	var dist := to_target.length()
	if dist < MIN_REACH or upper_len <= 0.0 or lower_len <= 0.0:
		return {}
	var dir := to_target / dist
	var reach := upper_len + lower_len
	# Clamp into the annulus the chain can actually cover.
	var d := clampf(dist, absf(upper_len - lower_len) + STRETCH_EPS, reach - STRETCH_EPS)

	# Law of cosines: the angle at the root between root→target and root→joint.
	var cos_a := clampf((upper_len * upper_len + d * d - lower_len * lower_len) / (2.0 * upper_len * d), -1.0, 1.0)
	var a := acos(cos_a)

	# The bend axis: perpendicular to the chain, in the half-plane the hint points at.
	var bend := bend_world - dir * bend_world.dot(dir)
	if bend.length_squared() < 1e-10:
		# Degenerate hint (parallel to the chain): pick any stable perpendicular.
		bend = dir.cross(Vector3.UP)
		if bend.length_squared() < 1e-10:
			bend = dir.cross(Vector3.RIGHT)
	bend = bend.normalized()
	var axis := dir.cross(bend)
	if axis.length_squared() < 1e-10:
		return {}
	axis = axis.normalized()

	# +a rotates `dir` TOWARD the bend hint (axis = dir x bend); -a would bend the joint the
	# wrong way, which reads as a backwards knee.
	var joint := root_pos + dir.rotated(axis, a) * upper_len
	return {
		"joint": joint,
		"upper_dir": (joint - root_pos).normalized(),
		"lower_dir": (target - joint).normalized(),
	}


## Rotation taking `from_dir` to `to_dir` (both unit, world space), as a Quaternion.
static func swing(from_dir: Vector3, to_dir: Vector3) -> Quaternion:
	var d := clampf(from_dir.dot(to_dir), -1.0, 1.0)
	if d > 0.99999:
		return Quaternion.IDENTITY
	if d < -0.99999:
		# Opposed: spin a half turn about any perpendicular.
		var perp := from_dir.cross(Vector3.UP)
		if perp.length_squared() < 1e-10:
			perp = from_dir.cross(Vector3.RIGHT)
		return Quaternion(perp.normalized(), PI)
	var axis := from_dir.cross(to_dir).normalized()
	return Quaternion(axis, acos(d))


## Apply a solved chain to a skeleton. `chain` is one entry of CastRig3D.ik.
## `weight` blends the IK result over whatever the FK pose already wrote (0 = pure FK).
static func apply(skel: Skeleton3D, chain: Dictionary, target_world: Vector3,
		weight := 1.0, bend_override := Vector3.ZERO) -> bool:
	if skel == null or weight <= 0.0:
		return false
	var ui := skel.find_bone(String(chain.get("upper", "")))
	var li := skel.find_bone(String(chain.get("lower", "")))
	var ti := skel.find_bone(String(chain.get("tip", "")))
	if ui < 0 or li < 0 or ti < 0:
		return false

	var sk_xform := skel.global_transform
	var upper_w := sk_xform * skel.get_bone_global_pose(ui)
	var lower_w := sk_xform * skel.get_bone_global_pose(li)
	var tip_w := sk_xform * skel.get_bone_global_pose(ti)

	var upper_len := (lower_w.origin - upper_w.origin).length()
	var lower_len := (tip_w.origin - lower_w.origin).length()
	var bend: Vector3 = bend_override if bend_override.length_squared() > 1e-10 \
		else sk_xform.basis * (chain.get("bend", Vector3.FORWARD) as Vector3)

	var sol := solve_two_bone(upper_w.origin, upper_len, lower_len, target_world, bend)
	if sol.is_empty():
		return false

	# Current directions, so the solve becomes a delta on top of the FK pose.
	var cur_upper := (lower_w.origin - upper_w.origin).normalized()
	var cur_lower := (tip_w.origin - lower_w.origin).normalized()
	var w := clampf(weight, 0.0, 1.0)

	var q_up := swing(cur_upper, sol["upper_dir"])
	_blend_world_rotation(skel, ui, q_up, w)
	# The lower bone has to be re-read: rotating the upper one moved it.
	lower_w = sk_xform * skel.get_bone_global_pose(li)
	tip_w = sk_xform * skel.get_bone_global_pose(ti)
	cur_lower = (tip_w.origin - lower_w.origin).normalized()
	var q_lo := swing(cur_lower, sol["lower_dir"])
	_blend_world_rotation(skel, li, q_lo, w)
	return true


## Pre-multiply a WORLD-space rotation onto a bone's current local pose, blended by `w`.
static func _blend_world_rotation(skel: Skeleton3D, idx: int, q_world: Quaternion, w: float) -> void:
	if w <= 0.0:
		return
	var q := Quaternion.IDENTITY.slerp(q_world, w)
	var parent := skel.get_bone_parent(idx)
	var parent_basis := skel.global_transform.basis
	if parent >= 0:
		parent_basis = (skel.global_transform * skel.get_bone_global_pose(parent)).basis
	parent_basis = parent_basis.orthonormalized()
	# World rotation -> the bone's parent space, where bone poses live.
	var local_axis := parent_basis.inverse() * q.get_axis()
	var ang := q.get_angle()
	if absf(ang) < 1e-6 or local_axis.length_squared() < 1e-12:
		return
	var local_q := Quaternion(local_axis.normalized(), ang)
	skel.set_bone_pose_rotation(idx, local_q * skel.get_bone_pose_rotation(idx))


## How far the character must move vertically for its lowest foot to rest on `floor_y`.
##
## Grounding is deliberately two steps, because a leg can only reach so far: the BODY moves first
## (this function; the caller applies it to the character's own transform) and only the residual
## per-foot correction is left to IK (`plant_feet`). Doing it with IK alone — which is what the
## first cut of this did — leaves a character whose clip lifts the root hanging in the air on two
## fully-extended legs, because the target is simply out of reach.
##
## `floor_y` is the stage floor in world space; the cast walks a single lane (REDESIGN_3D §5.1), so
## one height per character is enough and no raycast is needed.
static func ground_offset(skel: Skeleton3D, rig: CastRig3D, floor_y: float, weight := 1.0) -> float:
	if skel == null or rig == null or weight <= 0.0:
		return 0.0
	var lowest := INF
	for name in rig.feet:
		lowest = minf(lowest, sole_y(skel, name))
	if is_inf(lowest):
		return 0.0
	return (floor_y - lowest) * clampf(weight, 0.0, 1.0)


## World Y of a foot's SOLE, not its bone origin.
##
## The foot bone sits at the ankle, 5 cm up on Hush, so grounding the bone origin would bury the
## character to the ankles. The cast is modelled standing on z = 0, so the bone's height above the
## skeleton in the REST pose is exactly that ankle height, and no per-rig constant is needed.
static func sole_y(skel: Skeleton3D, bone_name: String) -> float:
	var i := skel.find_bone(bone_name)
	if i < 0:
		return INF
	var sk := skel.global_transform
	var cur := (sk * skel.get_bone_global_pose(i)).origin.y
	var ankle := (sk * skel.get_bone_global_rest(i)).origin.y - sk.origin.y
	return cur - ankle


## Plant any foot that is still below the floor after the body moved. A foot ABOVE the floor is
## left alone: that is a step, and dragging it down would destroy the walk.
static func plant_feet(skel: Skeleton3D, rig: CastRig3D, floor_y: float, weight := 1.0) -> int:
	if skel == null or rig == null or weight <= 0.0:
		return 0
	var planted := 0
	var sk := skel.global_transform
	for name in rig.feet:
		var i := skel.find_bone(name)
		if i < 0:
			continue
		var sole := sole_y(skel, name)
		if is_inf(sole):
			continue
		# Fade the correction in over a band instead of switching it on at a hard threshold. A foot
		# that hovers either side of the floor for a frame at a time would otherwise flick the leg
		# IK on and off every frame -- a 2-frame oscillation that reads as a vibrating ankle.
		var depth := floor_y - sole
		if depth <= 0.0:
			continue
		var fade := clampf(depth / PLANT_BAND, 0.0, 1.0)
		var p := (sk * skel.get_bone_global_pose(i)).origin
		var chain_name := "leg_l" if name.ends_with("_l") else "leg_r"
		if not rig.ik.has(chain_name):
			continue
		# Raise the bone by exactly the amount the sole is through the floor.
		var target := Vector3(p.x, p.y + depth, p.z)
		if Ik3D.apply(skel, rig.ik[chain_name], target, clampf(weight, 0.0, 1.0) * fade):
			planted += 1
	return planted
