## PoseRetarget3D — replays a 2D cutout pose on the 3D cast skeleton (REDESIGN_3D §5.7).
##
## This is why the 3D pivot does not throw away the animation work. `game/data/rigs/**` holds 236
## authored poses and `game/data/anim/**` 34 lint-checked clips, with their beats, events, eases,
## plant locks and tier timings already reviewed against `reactions.json`. All of it is plain
## humanoid FK: one clockwise screen-space rotation per joint, plus a root offset in px. So the
## entire 2D pipeline upstream of the draw — `ClipLib`, `RigSampler.sample/blend/apply_mask/
## apply_additive`, `ClipEvents`, `PlayPlan` — is reused unchanged, and only the last step swaps:
## instead of `RigSampler.solve()` producing Transform2D per cutout, this produces bone rotations.
##
## **Angle convention.** 2D poses are degrees, clockwise-positive, on art that faces right (screen
## +x, screen +y DOWN). The 3D cast faces +X with +Y up, so the sagittal plane is XY and the
## screen's clockwise is a NEGATIVE rotation about +Z. The axis itself comes from the rig
## descriptor (`fk_axis`, written by the Blender build) so the sign is never hardcoded twice.
##
## **Splits.** A 2D "torso" is one hinge. Driving a single 3D spine bone with it reads as a hinge
## too, which is exactly the stiffness the owner complained about; the descriptor therefore spreads
## one channel over several bones (`spine` 0.55 + `chest` 0.45, `neck` 0.35 + `head` 0.65). The
## summed angle is identical, so a pose keeps its authored silhouette while bending like a spine.
class_name PoseRetarget3D
extends RefCounted

const RC := RigDef.ROOT_CH
const ST := RigDef.STRIDE


## One resolved channel → bone binding, built once per (2D rig, 3D rig) pair.
class Binding extends RefCounted:
	var channel := ""
	var part_index := -1      # index into the 2D rig's parts, -1 for the root
	var bone_index := -1
	var weight := 1.0
	var rest := Quaternion.IDENTITY


var bindings: Array[Binding] = []
var root_bone := -1
## Metres per 2D pose pixel, so the root's vertical bob keeps its authored proportion.
var px_to_m := 1.0 / 200.0
var _axis := Vector3(0, 0, 1)
var _missing: PackedStringArray = []


## Resolve `rig3d.fk_map` against a live skeleton and the 2D rig that the clips are authored on.
static func build(rig3d: CastRig3D, rig2d: RigDef, skel: Skeleton3D) -> PoseRetarget3D:
	var r := PoseRetarget3D.new()
	if rig3d == null or rig2d == null or skel == null:
		return r
	r._axis = rig3d.fk_axis
	# The 2D rig's height in px maps to the 3D rig's height in metres: a 12 px root bob authored on
	# a 340 px tall Hush stays the same fraction of her height at 1.60 m.
	if rig2d.height_px > 1.0:
		r.px_to_m = rig3d.height_m / rig2d.height_px
	r.root_bone = skel.find_bone("root")

	for channel in rig3d.fk_map:
		var part_index := rig2d.names.find(channel)
		if part_index < 0:
			# Rigs differ in which parts they carry (Bellows roots at `torso` and has no pelvis
			# part at all). A channel the 2D rig does not have leaves its bones at rest.
			continue
		var weights := rig3d.channel_bones(channel)
		for bone_name in weights:
			var bi := skel.find_bone(bone_name)
			if bi < 0:
				r._missing.append("skeleton has no bone '%s' (channel %s)" % [bone_name, channel])
				continue
			var b := Binding.new()
			b.channel = channel
			b.part_index = part_index
			b.bone_index = bi
			b.weight = float(weights[bone_name])
			b.rest = skel.get_bone_rest(bi).basis.get_rotation_quaternion()
			r.bindings.append(b)
	return r


## Override the sagittal axis (review tooling only: the shipped value comes from the descriptor,
## which the Blender build writes, so the convention is never stated in two places).
func set_axis(axis: Vector3) -> void:
	_axis = axis.normalized()


func missing() -> PackedStringArray:
	return _missing


func is_valid() -> bool:
	return not bindings.is_empty()


## Write `pose` (a RigSampler pose array for the 2D rig) onto the skeleton as bone rotations.
## Returns the root offset in metres, for the caller to apply to the character's own transform —
## never to the skeleton, so that foot grounding and the camera see a consistent position.
func apply(skel: Skeleton3D, pose: PackedFloat32Array) -> Vector3:
	if skel == null or pose.is_empty():
		return Vector3.ZERO
	for b in bindings:
		if b.part_index < 0:
			continue
		var i := RC + b.part_index * ST + RigDef.C_ROT
		if i >= pose.size():
			continue
		# Screen clockwise-positive -> a negative turn about the sagittal axis.
		var ang := -deg_to_rad(pose[i] * b.weight)
		skel.set_bone_pose_rotation(b.bone_index, b.rest * Quaternion(_axis, ang))

	var rx := pose[RigDef.R_X] if pose.size() > RigDef.R_X else 0.0
	var ry := pose[RigDef.R_Y] if pose.size() > RigDef.R_Y else 0.0
	# 2D screen y grows downward; the 3D stage's y grows up.
	return Vector3(rx * px_to_m, -ry * px_to_m, 0.0)


## The root's authored scale channels, as a 3D squash/stretch factor (see Squash3D).
## 2D `sx`/`sy` are a cutout's width/height multipliers; in 3D the depth follows the width so the
## character keeps its volume instead of turning into a cardboard sheet when it squashes.
static func root_scale(pose: PackedFloat32Array) -> Vector3:
	if pose.size() <= RigDef.R_SY:
		return Vector3.ONE
	var sx := pose[RigDef.R_SX]
	var sy := pose[RigDef.R_SY]
	if sx <= 0.0:
		sx = 1.0
	if sy <= 0.0:
		sy = 1.0
	return Vector3(sx, sy, sx)
