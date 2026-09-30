## RigGaze3D — the runtime audience look (lead ruling D8, sidecar `gaze`): turns the face to a point (the active
## camera) about the VERTICAL only, the way r3d-anim's baked `face_cam` does it — the yaw is shared along the chain
## (upper spine → neck → head, `share` per bone, the head taking what is left, so with weight 1 the face ends up on the
## target), the keyed pitch and roll stay (a head tipped back on the "AHHH" stays tipped). The turn is absolute, not
## additive: it measures where the face points NOW (the pose after the clip and the look-at) and turns the rest of the
## way, so a clip that already baked the look for its staged facing gets ~0 extra and the mirrored facing gets the
## whole turn. Clamped to ±`max_deg` of total yaw.
##
## Runs after RigMods3D and the LookAtModifier3D, before the springs and the jiggle clamp (they work on the gazed
## pose; the clamp compares local rotations of the jiggle bones, which the gaze never touches). RigPlayer3D sets
## `weight`, `target` and `up` (both in skeleton space) every frame; weight 0 = the modifier is skipped. No per-frame
## allocation.
class_name RigGaze3D
extends SkeletonModifier3D

## The model-space forward of the face at rest (the rigs face +z).
const FWD := Vector3(0.0, 0.0, 1.0)

## Chain bones, root first (e.g. spine_02, spine_03, neck_01, Head); the last one is the head.
var bones := PackedInt32Array()
## Share of the remaining yaw per bone (same order).
var share := PackedFloat32Array()
## Inverse of the head's global rest basis (carries the rest forward into the posed head).
var head_rest_inv: Basis = Basis.IDENTITY
## 0..1 (the window's weight × its ramps).
var weight: float = 0.0
## The look target in skeleton space.
var target: Vector3 = Vector3.ZERO
## The world vertical in skeleton space (unit).
var up: Vector3 = Vector3.UP
## Eye height above the head bone (skeleton units).
var eye_up: float = 0.1
## Total yaw limit, degrees.
var max_deg: float = 85.0
## The yaw applied last pass (radians, signed about `up`) — for tests and the viewer.
var applied_yaw: float = 0.0


## Sets the chain (bone indices root → head) and the shares; `head_rest` = the head's global rest transform.
func setup(p_bones: PackedInt32Array, p_share: PackedFloat32Array, head_rest: Transform3D) -> void:
	bones = p_bones
	share = p_share
	head_rest_inv = head_rest.basis.orthonormalized().inverse()


## The face's forward (skeleton space) of the current pose.
func face_dir(sk: Skeleton3D) -> Vector3:
	if bones.is_empty():
		return FWD
	var hg := sk.get_bone_global_pose(bones[bones.size() - 1])
	return (hg.basis.orthonormalized() * head_rest_inv) * FWD


## The signed yaw (radians about `up`) from the face's current forward to the target, in the horizontal plane.
func yaw_to_target(sk: Skeleton3D) -> float:
	if bones.is_empty():
		return 0.0
	var hg := sk.get_bone_global_pose(bones[bones.size() - 1])
	var fd := (hg.basis.orthonormalized() * head_rest_inv) * FWD
	var want := target - (hg.origin + up * eye_up)
	var fdh := fd - up * fd.dot(up)
	var wh := want - up * want.dot(up)
	if fdh.length_squared() < 1e-8 or wh.length_squared() < 1e-8:
		return 0.0
	return fdh.signed_angle_to(wh, up)


func _process_modification_with_delta(_delta: float) -> void:
	applied_yaw = 0.0
	if weight <= 0.0001 or bones.is_empty():
		return
	var sk := get_skeleton()
	if sk == null:
		return
	var lim := deg_to_rad(max_deg)
	var tail := 0.0
	for k in share:
		tail += k
	var total := 0.0
	for i in bones.size():
		var d := clampf(yaw_to_target(sk), -lim - total, lim - total)
		var rel := minf(1.0, share[i] / maxf(1e-6, tail)) * weight
		tail -= share[i]
		var a := d * rel
		if absf(a) < 1e-6:
			continue
		var b := bones[i]
		var g := sk.get_bone_global_pose(b)
		sk.set_bone_global_pose(b, Transform3D(Basis(up, a) * g.basis, g.origin))
		total += a
	applied_yaw = total
