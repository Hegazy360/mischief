## Jiggle, look-at and the modifier stack on the fixture rig: a sudden move swings the beret spring, it settles, the
## clamp holds it inside clamp_deg, reset_jiggle() snaps it home; look-at turns the head within ±35°; hidden bones
## and prop sockets reach the posed skeleton (read through BoneAttachment3D, which sees the modified pose).
extends TestBase

const Env := preload("res://tests/rig3d/fixtures/fix_env.gd")

var _p: RigPlayer3D = null


func before_each() -> void:
	Env.push()


func after_each() -> void:
	if _p != null and is_instance_valid(_p):
		_p.get_parent().remove_child(_p)
		_p.free()
	_p = null
	Env.pop()


func _probe(bone: String) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	_p.skeleton.add_child(ba)
	ba.bone_name = bone
	return ba


## One game frame: the player advances, then the skeleton's deferred update runs the modifiers and moves the probes.
func _frame() -> void:
	_p.advance(1.0 / 60.0)
	await tree.process_frame


## The angle (°) between the modified (post-modifier) and the animated local rotation of `bone`.
func _swing(ba: BoneAttachment3D, bone: String) -> float:
	var bi := _p.skeleton.find_bone(bone)
	var parent_g := _p.skeleton.global_transform * _p.skeleton.get_bone_global_pose(_p.skeleton.get_bone_parent(bi))
	var animated_g := parent_g * _p.skeleton.get_bone_pose(bi)
	return rad_to_deg(animated_g.basis.get_rotation_quaternion().angle_to(ba.global_transform.basis.get_rotation_quaternion()))


func test_spring_swings_settles_and_clamps() -> void:
	_p = Env.player(tree)
	_p.play("fix/loco_idle")
	var ba := _probe("beret")
	for i in 60:
		await _frame()
	var rest_swing := _swing(ba, "beret")
	# A sudden lurch: 0.6 m in one frame, then hold still.
	_p.position.x += 0.6
	var peak := 0.0
	for i in 20:
		await _frame()
		peak = maxf(peak, _swing(ba, "beret"))
	assert_gt(peak, rest_swing + 1.0, "the beret swings after a lurch (peak %.1f°)" % peak)
	assert_le(peak, 30.0 + 0.5, "clamped to the group's clamp_deg 30°")
	for i in 240:
		await _frame()
	assert_lt(_swing(ba, "beret"), maxf(rest_swing, 0.5) + 0.5, "settled after 4 s")
	_p.position.x += 3.0
	_p.reset_jiggle()
	await _frame()
	assert_lt(_swing(ba, "beret"), 3.0, "reset_jiggle: no whip after a teleport")


func test_look_at_turns_the_head_within_limits() -> void:
	_p = Env.player(tree)
	_p.set_facing(1, false)
	_p.set_cheat(90.0, 0.0)   # facing the camera (+z)
	var ba := _probe("Head")
	_p.look_at_point(Vector3(10.0, 1.4, 0.0), 1.0)
	for i in 30:
		await _frame()
	var fwd := ba.global_transform.basis * Vector3(0, 0, 1)
	var yaw := rad_to_deg(atan2(fwd.x, fwd.z))
	assert_between(yaw, 20.0, 36.0, "the head turns toward +x, clamped at 35° (%.1f°)" % yaw)
	assert_gt(_p.face.look.x, 0.5, "pupils follow (look %s)" % [_p.face.look])
	_p.look_at_point(Vector3(10.0, 1.4, 0.0), 0.0)
	for i in 30:
		await _frame()
	fwd = ba.global_transform.basis * Vector3(0, 0, 1)
	assert_lt(absf(rad_to_deg(atan2(fwd.x, fwd.z))), 1.0, "weight eased back to 0")
	assert_eq(_p.face.look, Vector2.ZERO)


func test_modifiers_reach_the_pose() -> void:
	_p = Env.player(tree)
	var beret := _probe("beret")
	var cup := _probe("prop_r")
	await _frame()
	assert_gt(beret.global_transform.basis.get_scale().x, 0.9, "beret shown")
	_p.set_look("BALD", true)
	await _frame()
	assert_lt(beret.global_transform.basis.get_scale().x, 0.01, "hide_bones scales it away")
	_p.set_prop("cup", "brace")
	await _frame()
	var brace := _p.socket_global("brace_r").origin
	assert_lt(cup.global_transform.origin.distance_to(brace), 0.12, "the cup rides the brace socket (%.3f m)" % cup.global_transform.origin.distance_to(brace))
	_p.set_prop("cup", "hidden")
	await _frame()
	assert_lt(cup.global_transform.basis.get_scale().x, 0.01, "hidden = scale ≈ 0")
