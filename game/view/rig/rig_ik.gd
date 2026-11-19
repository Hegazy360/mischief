## RigIK — analytic two-bone IK on the flat cutout rig (docs/research/animation.md). One solver
## for every 2-bone chain: the plant lock's legs (RigSampler.plant) and the limb goals
## (RigPlayer.set_goal: a hand reaching for a kettle, a foot on a step).
##
## * Works on a POSE BUFFER (RigDef layout), solving in the chain parent's local frame, so a
##   leaning torso, a squashed root or a mirrored character are all exact: the target is mapped
##   into that frame once and the chain is laid out there.
## * The effector is the end part's joint plus an optional `tip` (a vector in the end part's
##   frame, e.g. the `grip` socket: `socket_tip()`), so the HAND'S GRIP lands on the target, not
##   the wrist. With a free end the tip is rigid on the lower bone (the hand keeps its clip
##   angle to the forearm), so it folds into the second bone and the solve stays closed-form;
##   with a fixed end angle the wrist target is the target minus the rotated tip.
## * `weight` blends the EFFECTOR, not the angles: the target moves from where the incoming pose
##   has the effector toward the goal, and the chain is solved fully for that point. The hand
##   travels a clean path and there is no ±360° ambiguity to blend across (the elbow never
##   spins). At weight 0 the incoming pose comes back exactly.
## * `bend` picks the elbow / knee side (+1 / −1; 0 = auto: the side a one-sided joint's limits
##   allow, else the side the incoming pose already bends to), so it never flips between frames.
## * Out of reach: the chain points straight at the target, or — `stretch_max` > 1 — the
##   rubber-hose limb stretches up to that factor (the lower and end parts' x / y channels move
##   along their bones; the hand texture is never scaled).
## * Angles: each solved rotation takes the ±360° representative that is inside the part's
##   rig.json limits and nearest the incoming pose; `limits = true` also clamps when none is, and
##   the returned error says how far the clamp left the effector.
## Chain bones are assumed to carry no scale (true of all rig data: limb bones are invisible
## hose joints); the end part's own scale is honoured for the tip. Pure and allocation-free.
class_name RigIK
extends RefCounted

const RC := RigDef.ROOT_CH
const ST := RigDef.STRIDE
const EPS := 0.001
## Fixed-point passes for the stretch factor when a tip rides on the stretched bone.
const STRETCH_PASSES := 4


## [upper, lower, end] of the 2-bone chain ending at `end`; x = -1 when `end` does not end one
## (needs two bones with real length above it).
static func chain_of(rig: RigDef, end: int) -> Vector3i:
	if end < 0 or end >= rig.parent.size():
		return Vector3i(-1, -1, -1)
	var lo := rig.parent[end]
	var up := rig.parent[lo] if lo >= 0 else -1
	if lo < 0 or up < 0 or rig.offset[lo].length() <= 1.0 or rig.offset[end].length() <= 1.0:
		return Vector3i(-1, -1, -1)
	return Vector3i(up, lo, end)


## Vector from the end part's joint to socket `s` in the end part's frame (the IK `tip`).
static func socket_tip(rig: RigDef, s: int) -> Vector2:
	if s < 0:
		return Vector2.ZERO
	var so := rig.socket_xf[s]
	return Vector2(so.x, so.y) - rig.pivot[rig.socket_part[s]]


## Bend side for `lower` from its limits alone: −1 / +1 for a one-sided joint (an elbow limited
## to [-160, 20] bends negative), 0 when both sides are allowed (two_bone then keeps the side the
## incoming pose bends to).
static func limit_bend(rig: RigDef, lower: int) -> float:
	if rig.limited.has(lower):
		var lo := rig.rot_min[lower]
		var hi := rig.rot_max[lower]
		if hi <= 25.0 and -lo > hi:
			return -1.0
		if lo >= -25.0 and hi > -lo:
			return 1.0
	return 0.0


## The chain's interior turn at the elbow / knee in `pose`, degrees (signed: the side it bends to; ~0 =
## straight), with the tip folded into the second bone as two_bone does. Callers keep the last clear sign
## across frames so an arm passing through straight never flips the solution (RigPlayer).
static func bend_turn(rig: RigDef, pose: PackedFloat32Array, up: int, lo: int, end: int, tip: Vector2) -> float:
	var bl := RC + lo * ST
	var be := RC + end * ST
	var v1 := rig.offset[lo] + Vector2(pose[bl + RigDef.C_X], pose[bl + RigDef.C_Y])
	var v2 := rig.offset[end] + Vector2(pose[be + RigDef.C_X], pose[be + RigDef.C_Y])
	var tip_s := tip * Vector2(pose[be + RigDef.C_SX], pose[be + RigDef.C_SY])
	var b2 := v2 + _rot(tip_s, deg_to_rad(pose[be + RigDef.C_ROT]))
	var u0 := atan2(-v1.x, v1.y)
	var l0 := atan2(-b2.x, b2.y)
	return rad_to_deg(wrapf(deg_to_rad(pose[bl + RigDef.C_ROT]) + l0 - u0, -PI, PI))


## Solve the chain `up` → `lo` → `end` so its effector (end joint + `tip`) reaches `target`
## (character space), writing the rotations (and stretch offsets) into `pose`.
##   end_deg     NAN = the end part keeps its local rotation; else its CHARACTER-SPACE rotation
##               in degrees (Transform2D.get_rotation()) — a foot flat on a step, a palm up.
##   bend        +1 / −1, 0 = auto (see the class doc).
##   weight      0..1: the effector's blend from the incoming pose to the target.
##   stretch_max ≥ 1: how far the limb may stretch past its length (1 = rigid).
##   limits      clamp to rig.json limits when no in-limit representative exists.
##   soft        0 = hard clamps; else the last `soft` fraction of the reach near full extension and near
##               the fold is eased (the arm approaches straight / folded asymptotically), which bounds how
##               fast the joints turn when a target sweeps past arm's length or past the shoulder.
## Returns Vector2(distance px from the effector to `target` in character space, stretch used),
## measured on what was written: a clamp, an out-of-reach target or a partial weight shows.
static func two_bone(rig: RigDef, pose: PackedFloat32Array, up: int, lo: int, end: int, target: Vector2,
		end_deg: float, bend: float, weight: float, stretch_max: float, tip: Vector2, limits: bool, soft: float = 0.0) -> Vector2:
	var par := RigSampler._world_of(rig, pose, rig.parent[up])
	var inv := par.affine_inverse()
	var goal := inv * target
	var bu := RC + up * ST
	var bl := RC + lo * ST
	var be := RC + end * ST
	var h := rig.offset[up] + Vector2(pose[bu + RigDef.C_X], pose[bu + RigDef.C_Y])
	var v1 := rig.offset[lo] + Vector2(pose[bl + RigDef.C_X], pose[bl + RigDef.C_Y])
	var v2 := rig.offset[end] + Vector2(pose[be + RigDef.C_X], pose[be + RigDef.C_Y])
	var ur0 := deg_to_rad(pose[bu + RigDef.C_ROT])
	var lr0 := deg_to_rad(pose[bl + RigDef.C_ROT])
	var er0 := deg_to_rad(pose[be + RigDef.C_ROT])
	var tip_s := tip * Vector2(pose[be + RigDef.C_SX], pose[be + RigDef.C_SY])
	var tip_l := _rot(tip_s, er0)      # the tip in the lower bone's frame (free end)
	var fixed_end := not is_nan(end_deg)
	var ew := 0.0                      # end angle in the parent frame (fixed end)
	if fixed_end:
		var dr := deg_to_rad(end_deg)
		ew = inv.basis_xform(Vector2(cos(dr), sin(dr))).angle()
	# Weight: blend the effector (and a fixed end's angle) from the incoming pose.
	var w := clampf(weight, 0.0, 1.0)
	var t := goal
	if w < 1.0:
		var cur := h + _rot(v1, ur0) + _rot(v2 + tip_l, ur0 + lr0)
		t = cur.lerp(goal, w)
		if fixed_end:
			ew = lerp_angle(ur0 + lr0 + er0, ew, w)
	var wrist := t - _rot(tip_s, ew) if fixed_end else t
	var tipb := Vector2.ZERO if fixed_end else tip_l
	var len1 := v1.length()
	var d := wrist - h
	var dist := d.length()
	# Stretch: grow both bones (not the tip) until the chain spans `dist`, up to the cap.
	var s := 1.0
	if stretch_max > 1.0 and dist > len1 + (v2 + tipb).length():
		for _k in STRETCH_PASSES:
			var span := len1 * s + (v2 * s + tipb).length()
			s = clampf(s * dist / maxf(span, EPS), 1.0, stretch_max)
	var b1 := v1 * s
	var b2 := v2 * s + tipb
	var l1 := b1.length()
	var l2 := b2.length()
	var u0 := atan2(-b1.x, b1.y)
	var l0 := atan2(-b2.x, b2.y)
	if bend == 0.0:
		bend = limit_bend(rig, lo)
		if bend == 0.0:
			bend = 1.0 if wrapf(lr0 + l0 - u0, -PI, PI) >= 0.0 else -1.0
	var reach_len := l1 + l2
	var fold := absf(l1 - l2)
	if soft > 0.0:
		var room := reach_len * soft
		if dist > reach_len - room:
			var knee := reach_len - room
			dist = knee + room * (1.0 - exp(-(dist - knee) / room))
		elif dist < fold + room:
			# ...and the same ease near the fold (the hand passing the shoulder), the other singularity.
			var knee2 := fold + room
			dist = knee2 - room * (1.0 - exp(-(knee2 - dist) / room))
	var dc := clampf(dist, fold + EPS, reach_len - EPS)
	var base := atan2(-d.x, d.y)
	var a := acos(clampf((l1 * l1 + dc * dc - l2 * l2) / (2.0 * l1 * dc), -1.0, 1.0))
	var g := acos(clampf((l1 * l1 + l2 * l2 - dc * dc) / (2.0 * l1 * l2), -1.0, 1.0))
	var urd := _pick(rig, up, rad_to_deg(base - a * bend - u0), pose[bu + RigDef.C_ROT], limits)
	var lrd := _pick(rig, lo, rad_to_deg((PI - g) * bend + u0 - l0), pose[bl + RigDef.C_ROT], limits)
	pose[bu + RigDef.C_ROT] = urd
	pose[bl + RigDef.C_ROT] = lrd
	var erd := pose[be + RigDef.C_ROT]
	if fixed_end:
		erd = _pick(rig, end, rad_to_deg(ew) - urd - lrd, erd, limits)
		pose[be + RigDef.C_ROT] = erd
	if s != 1.0:
		var nv1 := v1 * s - rig.offset[lo]
		var nv2 := v2 * s - rig.offset[end]
		pose[bl + RigDef.C_X] = nv1.x
		pose[bl + RigDef.C_Y] = nv1.y
		pose[be + RigDef.C_X] = nv2.x
		pose[be + RigDef.C_Y] = nv2.y
	# Distance on what was written (FK of the chain in the parent frame) to the real goal.
	var a1 := deg_to_rad(urd)
	var a2 := a1 + deg_to_rad(lrd)
	var p := h + _rot(b1, a1) + _rot(v2 * s, a2) + _rot(tip_s, a2 + deg_to_rad(erd))
	return Vector2(par.basis_xform(p - goal).length(), s)


## Character-space position of the effector (end joint + tip) in `pose` (full FK up the chain;
## tests and tools).
static func effector(rig: RigDef, pose: PackedFloat32Array, end: int, tip: Vector2) -> Vector2:
	return RigSampler._world_of(rig, pose, end) * tip


static func _rot(v: Vector2, a: float) -> Vector2:
	var c := cos(a)
	var sn := sin(a)
	return Vector2(v.x * c - v.y * sn, v.x * sn + v.y * c)


## The ±360° representative of `deg` for part `p`: inside its limits and nearest `ref` (the
## incoming pose); with no in-limit one, the nearest to the limits — clamped when `limits`.
static func _pick(rig: RigDef, p: int, deg: float, ref: float, limits: bool) -> float:
	var near := ref + wrapf(deg - ref, -180.0, 180.0)
	if not rig.limited.has(p):
		return near
	var lo := rig.rot_min[p]
	var hi := rig.rot_max[p]
	var best := near
	var best_out := INF
	var best_ref := INF
	for k in 3:
		var c := near + 360.0 * float(k - 1)
		var out := maxf(lo - c, 0.0) + maxf(c - hi, 0.0)
		var dref := absf(c - ref)
		if out < best_out - 0.0001 or (absf(out - best_out) <= 0.0001 and dref < best_ref):
			best = c
			best_out = out
			best_ref = dref
	return clampf(best, lo, hi) if limits else best
