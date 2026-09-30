## RigMods3D — the player's own SkeletonModifier3D (runs after the AnimationTree applied the clip, before look-at
## and jiggle): bone-driven prop states (hidden = scale ≈ 0, on another socket = the prop bone placed on that socket,
## flying = the PropSim3D world path), bones hidden by looks / body slots, and the temper tier's bone scale
## (Bellows' sideburn bristle). Everything is precomputed into packed arrays by RigPlayer3D; the per-frame pass
## allocates nothing. The skeleton restores the animated poses after skinning, so nothing accumulates.
class_name RigMods3D
extends SkeletonModifier3D

const TINY := Vector3(0.0001, 0.0001, 0.0001)
const MODE_HOME := 0
const MODE_HIDDEN := 1
const MODE_SOCKET := 2
const MODE_FLYING := 3
const MODE_LOOSE := 4

## Bones scaled to ≈ 0 (looks' `hide_bones`, body-slot variants).
var hidden_bones := PackedInt32Array()
## Bones scaled by `scale_factor` (tint tier bone scale).
var scale_bones := PackedInt32Array()
var scale_factor: float = 1.0
## Bone-driven props: bone index, mode, socket bone, socket local transform, world transform while flying / loose.
var prop_bone := PackedInt32Array()
var prop_mode := PackedInt32Array()
var prop_sock_bone := PackedInt32Array()
var prop_sock_xf: Array[Transform3D] = []
var prop_world_xf: Array[Transform3D] = []
## 1 = a visible prop at home whose bone scale the playing clip keys (the bake keys hidden extras at scale 0): the
## state wins, scale forced to 1.
var prop_fix_scale := PackedByteArray()
## The jiggle clamp that wants the animated (pre-spring) rotations of its bones (null = none).
var jiggle_clamp: RigJiggleClamp3D = null


## Sizes the prop arrays (all props at home).
func setup_props(bones: PackedInt32Array) -> void:
	prop_bone = bones.duplicate()
	var n := bones.size()
	prop_mode.resize(n)
	prop_mode.fill(MODE_HOME)
	prop_sock_bone.resize(n)
	prop_sock_bone.fill(-1)
	prop_sock_xf.resize(n)
	prop_world_xf.resize(n)
	prop_fix_scale.resize(n)
	prop_fix_scale.fill(0)
	for i in n:
		prop_sock_xf[i] = Transform3D.IDENTITY
		prop_world_xf[i] = Transform3D.IDENTITY


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if jiggle_clamp != null:
		for i in jiggle_clamp.bones.size():
			var q := sk.get_bone_pose_rotation(jiggle_clamp.bones[i])
			jiggle_clamp.pre[i] = Vector4(q.x, q.y, q.z, q.w)
	for b in hidden_bones:
		sk.set_bone_pose_scale(b, TINY)
	if scale_factor != 1.0:
		for b in scale_bones:
			sk.set_bone_pose_scale(b, sk.get_bone_pose_scale(b) * scale_factor)
	var inv := Transform3D.IDENTITY
	var have_inv := false
	for i in prop_bone.size():
		var m := prop_mode[i]
		if m == MODE_HOME:
			if prop_fix_scale[i] != 0:
				sk.set_bone_pose_scale(prop_bone[i], Vector3.ONE)
			continue
		var b := prop_bone[i]
		if b < 0:
			continue
		if m == MODE_HIDDEN:
			sk.set_bone_pose_scale(b, TINY)
		elif m == MODE_SOCKET and prop_sock_bone[i] >= 0:
			if not _parent_ok(sk, b):
				continue
			var g := sk.get_bone_global_pose(prop_sock_bone[i]) * prop_sock_xf[i]
			sk.set_bone_global_pose(b, g.orthonormalized())
			sk.set_bone_pose_scale(b, Vector3.ONE)
		elif m == MODE_FLYING or m == MODE_LOOSE:
			if not _parent_ok(sk, b):
				continue
			if not have_inv:
				inv = sk.global_transform.affine_inverse()
				have_inv = true
			sk.set_bone_global_pose(b, inv * prop_world_xf[i])
			sk.set_bone_pose_scale(b, Vector3.ONE)


## False when the bone's parent is scaled to ≈ 0 (a clip hiding a grip bone): its global pose cannot be inverted.
static func _parent_ok(sk: Skeleton3D, b: int) -> bool:
	var pb := sk.get_bone_parent(b)
	return pb < 0 or absf(sk.get_bone_global_pose(pb).basis.determinant()) > 1e-9
