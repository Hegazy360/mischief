## RigJiggleClamp3D — runs after the SpringBoneSimulator3D: each jiggle bone's spring rotation is kept within its
## group's `clamp_deg` of the animated pose (captured by RigMods3D before the springs), so a fast move or a launch
## never whips the beret / bouffant through the head. Packed arrays, no allocation per frame.
class_name RigJiggleClamp3D
extends SkeletonModifier3D

var bones := PackedInt32Array()
var clamp_rad := PackedFloat32Array()
## Filled by RigMods3D each frame: the animated local rotation of each bone before the springs.
var pre := PackedVector4Array()


func setup(p_bones: PackedInt32Array, p_clamp_deg: PackedFloat32Array) -> void:
	bones = p_bones
	clamp_rad.resize(p_clamp_deg.size())
	for i in p_clamp_deg.size():
		clamp_rad[i] = deg_to_rad(p_clamp_deg[i])
	pre.resize(bones.size())


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for i in bones.size():
		var b := bones[i]
		var p4 := pre[i]
		var q0 := Quaternion(p4.x, p4.y, p4.z, p4.w)
		var q1 := sk.get_bone_pose_rotation(b)
		var ang := q0.angle_to(q1)
		if ang > clamp_rad[i] and ang > 0.0001:
			sk.set_bone_pose_rotation(b, q0.slerp(q1, clamp_rad[i] / ang))
