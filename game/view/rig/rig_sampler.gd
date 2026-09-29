## RigSampler — pure pose maths for clips (TECH §5.3). Every function writes into a caller-
## owned buffer and allocates nothing (the per-frame path of every character).
##
## * `sample(clip, frame, out)`: continuous channels (root x/y/rot/sx/sy; part rot, x, y, sx,
##   sy, alpha) interpolate between the surrounding keys with the INCOMING key's ease;
##   discrete channels (z, tex, vis — and so the face, baked into the face parts) step on
##   keys. Loops wrap (a last key before `length` interpolates back to the first key).
## * `blend(a, b, t, out)`: crossfade per part (`rot` by the shortest angle, like
##   lerp_angle; discrete channels switch at t = 0.5).
## * `apply_mask(out, over, mask, w)`: a masked overlay (upper-body clip over a walk).
## * `apply_additive(out, add, rest, w)`: an additive layer (add − rest; scales multiply).
## * `breathe`, `shiver`, `look`, `clamp_limits`: the procedural additive layers.
## * `solve(rig, pose, out)`: forward kinematics from the feet origin → one Transform2D per
##   part in character space (art faces right; the player mirrors it for facing −1).
class_name RigSampler
extends RefCounted

const RC := RigDef.ROOT_CH
const ST := RigDef.STRIDE


## Samples `clip` at `frame` (float, 60 fps) into `out` (size = rig.pose_size).
static func sample(clip: ClipDef, frame: float, out: PackedFloat32Array) -> void:
	var n := clip.key_f.size()
	if n == 0:
		_copy(clip.rig.rest, out)
		return
	var kf := clip.key_f
	var f := frame
	var ln := float(maxi(1, clip.length))
	if clip.loop:
		f = fposmod(f, ln)
		var first := float(kf[0])
		var last := float(kf[n - 1])
		if n == 1:
			_copy(clip.key_pose[0], out)
			return
		if f < first or f >= last:
			# Wrap segment: last key → first key (+ length).
			var span := first + ln - last
			var t := (f - last) / span if f >= last else (f + ln - last) / span
			if span <= 0.0:
				t = 1.0
			var ew := RigEase.apply(clip.key_ease[0], t)
			lerp_pose(clip.key_pose[n - 1], clip.key_pose[0], ew, out)
			if clip.plant:
				plant(clip, n - 1, 0, ew, out)
			return
	else:
		if f <= float(kf[0]):
			_copy(clip.key_pose[0], out)
			return
		if f >= float(kf[n - 1]):
			_copy(clip.key_pose[n - 1], out)
			return
	var k := kf.bsearch(int(floor(f)), false) - 1
	k = clampi(k, 0, n - 2)
	var f0 := float(kf[k])
	var f1 := float(kf[k + 1])
	var tt := (f - f0) / (f1 - f0) if f1 > f0 else 1.0
	var e := RigEase.apply(clip.key_ease[k + 1], tt)
	lerp_pose(clip.key_pose[k], clip.key_pose[k + 1], e, out)
	if clip.plant:
		plant(clip, k, k + 1, e, out)


## Plant lock between keys `ka` → `kb` at eased progress `e`: every foot planted at both
## keys gets its leg re-solved (2-bone IK in its chain parent's space, so root squash is
## handled) to put the ankle at the lerp of the two keyed ankles and the foot at the lerp of
## their rotations. The knee bends the way the sampled lower bone does. Allocation-free.
static func plant(clip: ClipDef, ka: int, kb: int, e: float, out: PackedFloat32Array) -> void:
	var rig := clip.rig
	var nf := rig.feet.size()
	for j in nf:
		if clip.plant_on[ka * nf + j] == 0 or clip.plant_on[kb * nf + j] == 0:
			continue
		var up := rig.foot_upper[j]
		var lo := rig.foot_lower[j]
		var ft := rig.feet[j]
		var target := clip.plant_pos[ka * nf + j].lerp(clip.plant_pos[kb * nf + j], e)
		var rot := lerp_angle(clip.plant_rot[ka * nf + j], clip.plant_rot[kb * nf + j], e)
		var par := _world_of(rig, out, rig.parent[up])
		var inv := par.affine_inverse()
		var t := inv * target
		var bu := RC + up * ST
		var bl := RC + lo * ST
		var h := rig.offset[up] + Vector2(out[bu + RigDef.C_X], out[bu + RigDef.C_Y])
		var l1 := rig.offset[lo].length()
		var l2 := rig.offset[ft].length()
		var d := t - h
		var dist := clampf(d.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
		var base := atan2(-d.x, d.y)
		var a := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
		var g := acos(clampf((l1 * l1 + l2 * l2 - dist * dist) / (2.0 * l1 * l2), -1.0, 1.0))
		var bend := 1.0 if out[bl + RigDef.C_ROT] >= 0.0 else -1.0
		var upper := base - a * bend
		var lower := (PI - g) * bend
		var u0 := atan2(-rig.offset[lo].x, rig.offset[lo].y)
		var l0 := atan2(-rig.offset[ft].x, rig.offset[ft].y)
		var ur := upper - u0
		var lr := lower + u0 - l0
		out[bu + RigDef.C_ROT] = rad_to_deg(ur)
		out[bl + RigDef.C_ROT] = rad_to_deg(lr)
		var dirp := inv.basis_xform(Vector2(cos(rot), sin(rot)))
		out[RC + ft * ST + RigDef.C_ROT] = rad_to_deg(wrapf(dirp.angle() - ur - lr, -PI, PI))


## World (character-space) transform of part `p` in `pose` (recursive walk up the parent
## chain; no allocation). -1 = the root transform.
static func _world_of(rig: RigDef, pose: PackedFloat32Array, p: int) -> Transform2D:
	if p < 0:
		return Transform2D(deg_to_rad(pose[RigDef.R_ROT]), Vector2(pose[RigDef.R_SX], pose[RigDef.R_SY]), 0.0,
			Vector2(pose[RigDef.R_X], pose[RigDef.R_Y]))
	return _world_deep(rig, pose, p)


static func _world_deep(rig: RigDef, pose: PackedFloat32Array, p: int) -> Transform2D:
	var i := RC + p * ST
	var local := Transform2D(deg_to_rad(pose[i]), Vector2(pose[i + 3], pose[i + 4]), 0.0, rig.offset[p] + Vector2(pose[i + 1], pose[i + 2]))
	var par := rig.parent[p]
	if par < 0:
		return Transform2D(deg_to_rad(pose[RigDef.R_ROT]), Vector2(pose[RigDef.R_SX], pose[RigDef.R_SY]), 0.0,
			Vector2(pose[RigDef.R_X], pose[RigDef.R_Y])) * local
	return _world_deep(rig, pose, par) * local


## Key interpolation: continuous channels a → b by `e`; discrete channels keep `a` (they step
## ON the next key, which sample() reaches as the next segment's start). `e` may overshoot
## (back / elastic eases).
static func lerp_pose(a: PackedFloat32Array, b: PackedFloat32Array, e: float, out: PackedFloat32Array) -> void:
	var sz := out.size()
	for i in RC:
		out[i] = a[i] + (b[i] - a[i]) * e
	var i2 := RC
	while i2 < sz:
		out[i2] = a[i2] + (b[i2] - a[i2]) * e
		out[i2 + 1] = a[i2 + 1] + (b[i2 + 1] - a[i2 + 1]) * e
		out[i2 + 2] = a[i2 + 2] + (b[i2 + 2] - a[i2 + 2]) * e
		out[i2 + 3] = a[i2 + 3] + (b[i2 + 3] - a[i2 + 3]) * e
		out[i2 + 4] = a[i2 + 4] + (b[i2 + 4] - a[i2 + 4]) * e
		out[i2 + 5] = a[i2 + 5]
		out[i2 + 6] = a[i2 + 6]
		out[i2 + 7] = a[i2 + 7]
		out[i2 + 8] = a[i2 + 8] + (b[i2 + 8] - a[i2 + 8]) * e
		i2 += ST


## Crossfade a → b at t (0 = a, 1 = b): rotations take the shortest way round, discrete
## channels switch at t = 0.5.
static func blend(a: PackedFloat32Array, b: PackedFloat32Array, t: float, out: PackedFloat32Array) -> void:
	var sz := out.size()
	out[0] = a[0] + (b[0] - a[0]) * t
	out[1] = a[1] + (b[1] - a[1]) * t
	out[2] = a[2] + wrapf(b[2] - a[2], -180.0, 180.0) * t
	out[3] = a[3] + (b[3] - a[3]) * t
	out[4] = a[4] + (b[4] - a[4]) * t
	var disc_b := t >= 0.5
	var i := RC
	while i < sz:
		out[i] = a[i] + wrapf(b[i] - a[i], -180.0, 180.0) * t
		out[i + 1] = a[i + 1] + (b[i + 1] - a[i + 1]) * t
		out[i + 2] = a[i + 2] + (b[i + 2] - a[i + 2]) * t
		out[i + 3] = a[i + 3] + (b[i + 3] - a[i + 3]) * t
		out[i + 4] = a[i + 4] + (b[i + 4] - a[i + 4]) * t
		out[i + 5] = b[i + 5] if disc_b else a[i + 5]
		out[i + 6] = b[i + 6] if disc_b else a[i + 6]
		out[i + 7] = b[i + 7] if disc_b else a[i + 7]
		out[i + 8] = a[i + 8] + (b[i + 8] - a[i + 8]) * t
		i += ST


## Masked overlay: parts with mask[i] == 1 blend toward `over` by `w` (root untouched unless
## `with_root`).
static func apply_mask(out: PackedFloat32Array, over: PackedFloat32Array, mask: PackedByteArray, w: float, with_root: bool = false) -> void:
	if w <= 0.0:
		return
	if with_root:
		for r in RC:
			out[r] = out[r] + ((wrapf(over[r] - out[r], -180.0, 180.0)) if r == RigDef.R_ROT else (over[r] - out[r])) * w
	var disc_o := w >= 0.5
	var n := mini(mask.size(), (out.size() - RC) / ST)
	for p in n:
		if mask[p] == 0:
			continue
		var i := RC + p * ST
		out[i] = out[i] + wrapf(over[i] - out[i], -180.0, 180.0) * w
		out[i + 1] = out[i + 1] + (over[i + 1] - out[i + 1]) * w
		out[i + 2] = out[i + 2] + (over[i + 2] - out[i + 2]) * w
		out[i + 3] = out[i + 3] + (over[i + 3] - out[i + 3]) * w
		out[i + 4] = out[i + 4] + (over[i + 4] - out[i + 4]) * w
		if disc_o:
			out[i + 5] = over[i + 5]
			out[i + 6] = over[i + 6]
			out[i + 7] = over[i + 7]
		out[i + 8] = out[i + 8] + (over[i + 8] - out[i + 8]) * w


## Additive layer: out += (add − rest) · w for rot / x / y / alpha, out *= 1 + (add/rest − 1)·w
## for scales; discrete channels are untouched.
static func apply_additive(out: PackedFloat32Array, add: PackedFloat32Array, rest: PackedFloat32Array, w: float) -> void:
	if w == 0.0:
		return
	out[0] += (add[0] - rest[0]) * w
	out[1] += (add[1] - rest[1]) * w
	out[2] += (add[2] - rest[2]) * w
	out[3] *= 1.0 + (_ratio(add[3], rest[3]) - 1.0) * w
	out[4] *= 1.0 + (_ratio(add[4], rest[4]) - 1.0) * w
	var sz := out.size()
	var i := RC
	while i < sz:
		out[i] += (add[i] - rest[i]) * w
		out[i + 1] += (add[i + 1] - rest[i + 1]) * w
		out[i + 2] += (add[i + 2] - rest[i + 2]) * w
		out[i + 3] *= 1.0 + (_ratio(add[i + 3], rest[i + 3]) - 1.0) * w
		out[i + 4] *= 1.0 + (_ratio(add[i + 4], rest[i + 4]) - 1.0) * w
		out[i + 8] += (add[i + 8] - rest[i + 8]) * w
		i += ST


static func _ratio(a: float, b: float) -> float:
	return a / b if absf(b) > 0.0001 else 1.0


## Breathing: the rig's breath part `sy` × (1 + amp·sin(2πt / period)) (TECH §5.3: torso
## ±1.5 % over 3.2 s; Bellows' rig sets ±2.5 % over 4 s). `w` scales it (0 = off).
static func breathe(rig: RigDef, out: PackedFloat32Array, t_sec: float, w: float = 1.0) -> void:
	if rig.breath_part < 0 or w == 0.0:
		return
	var i := RC + rig.breath_part * ST + RigDef.C_SY
	out[i] *= 1.0 + rig.breath_amp * w * sin(TAU * t_sec / rig.breath_period)


## Shiver: ±amp° at `hz` on the breath part and the look part (a scared tremble).
static func shiver(rig: RigDef, out: PackedFloat32Array, t_sec: float, amp_deg: float = 2.0, hz: float = 12.0) -> void:
	if amp_deg == 0.0:
		return
	var s := sin(TAU * hz * t_sec) * amp_deg
	if rig.breath_part >= 0:
		out[RC + rig.breath_part * ST] += s
	if rig.look_part >= 0:
		out[RC + rig.look_part * ST] -= s * 0.7


## Look-at: adds `head_deg` (clamped to ±look_max_deg) to the look part and moves the pupils
## by `pupil` (−1..1 per axis, scaled by the slot range).
static func look(rig: RigDef, out: PackedFloat32Array, head_deg: float, pupil: Vector2) -> void:
	if rig.look_part >= 0:
		out[RC + rig.look_part * ST] += clampf(head_deg, -rig.look_max_deg, rig.look_max_deg)
	if rig.pupils_part >= 0:
		var b := RC + rig.pupils_part * ST
		out[b + RigDef.C_X] += clampf(pupil.x, -1.0, 1.0) * rig.pupil_range.x
		out[b + RigDef.C_Y] += clampf(pupil.y, -1.0, 1.0) * rig.pupil_range.y


## Clamp every part's rot to its limits.
static func clamp_limits(rig: RigDef, out: PackedFloat32Array) -> void:
	for p in rig.limited:
		var i := RC + p * ST
		out[i] = clampf(out[i], rig.rot_min[p], rig.rot_max[p])


## Forward kinematics: fills `out` (resized to the part count once) with each part's joint
## transform in character space (feet origin, y down). Root: T(x, y)·R(rot)·S(sx, sy) about
## the feet; part: parent · T(offset + (x, y)) · R(rot) · S(sx, sy).
static func solve(rig: RigDef, pose: PackedFloat32Array, out: Array[Transform2D]) -> void:
	var n := rig.names.size()
	if out.size() != n:
		out.resize(n)
	var root := Transform2D(deg_to_rad(pose[RigDef.R_ROT]), Vector2(pose[RigDef.R_SX], pose[RigDef.R_SY]), 0.0,
		Vector2(pose[RigDef.R_X], pose[RigDef.R_Y]))
	for p in n:
		var i := RC + p * ST
		var local := Transform2D(deg_to_rad(pose[i]), Vector2(pose[i + 3], pose[i + 4]), 0.0,
			rig.offset[p] + Vector2(pose[i + 1], pose[i + 2]))
		var par := rig.parent[p]
		out[p] = (out[par] if par >= 0 else root) * local


## Copy `src` into `dst` (same size).
static func _copy(src: PackedFloat32Array, dst: PackedFloat32Array) -> void:
	var n := mini(src.size(), dst.size())
	for i in n:
		dst[i] = src[i]


## Public copy helper (allocation-free).
static func copy(src: PackedFloat32Array, dst: PackedFloat32Array) -> void:
	_copy(src, dst)


## World-space rot of part `p` in degrees from a solved transform set.
static func world_rot(xf: Array[Transform2D], p: int) -> float:
	return rad_to_deg(xf[p].get_rotation())
