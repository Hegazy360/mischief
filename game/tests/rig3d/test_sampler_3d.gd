## RigSampler3D (r3d-rig §4.3): the headless sample matches the live player's bone globals within 1 mm, local
## rotations equal the Animation tracks, helpers (angle speed, height, bounds) and the budget (≤ 5 ms / 100 frames).
extends TestBase

const Env := preload("res://tests/rig3d/fixtures/fix_env.gd")

var _p: RigPlayer3D = null


func before_each() -> void:
	Env.push()
	RigSampler3D.clear_cache()


func after_each() -> void:
	if _p != null and is_instance_valid(_p):
		_p.get_parent().remove_child(_p)
		_p.free()
	_p = null
	RigSampler3D.clear_cache()
	Env.pop()


func test_matches_the_live_player_within_a_millimetre() -> void:
	var s := RigSampler3D.for_rig("fix")
	if not assert_true(s.ok, "sampler set up"):
		return
	_p = Env.player(tree)
	_p.set_facing(1, false)
	_p.set_cheat(90.0, 0.0)   # yaw 0: the player's world frame = the rig's model frame
	_p.play("fix/rx_take")
	var worst := 0.0
	for f in [0.0, 17.0, 31.5, 40.0, 68.0, 90.0]:
		_p.set_external_frame(f)
		s.pose_at("fix/rx_take", f)
		for bone in ["pelvis", "Head", "hand_r", "hand_l", "foot_l", "upperarm_r", "beret"]:
			var bi := _p.skeleton.find_bone(bone)
			var live := _p.skeleton.global_transform * _p.skeleton.get_bone_global_pose(bi).origin
			worst = maxf(worst, live.distance_to(s.global_pos(bone)))
	assert_lt(worst, 0.001, "worst bone distance %.5f m" % worst)


func test_local_rotations_are_the_tracks() -> void:
	var s := RigSampler3D.for_rig("fix")
	s.pose_at("fix/rx_take", 31.0)
	var a := ClipLib3D.animation("fix/rx_take")
	var t := a.find_track(NodePath("Armature/Skeleton3D:upperarm_r"), Animation.TYPE_ROTATION_3D)
	var want := a.rotation_track_interpolate(t, 31.0 / 60.0)
	assert_gt(absf(s.local_rot("upperarm_r").dot(want)), 0.99999)
	assert_eq(s.local_rot("thigh_l"), Quaternion.IDENTITY, "an untracked bone sits at rest")
	var d := RigSampler3D.sample("fix", "fix/rx_take", 31.0)
	assert_has(d, "global_pos")
	assert_eq((d["global_pos"] as Dictionary).size(), 27)
	assert_eq(RigSampler3D.sample("fix", "fix/nope", 1.0), {}, "a missing clip samples to {}")


func test_helpers() -> void:
	var s := RigSampler3D.for_rig("fix")
	s.pose_at("fix/rx_take", 0.0)
	# The accent snap: 180° in 3 frames on the right arm (−20° → 160°).
	var spd := s.angle_delta_deg("upperarm_r", 30.0, 31.0)
	assert_between(spd, 55.0, 65.0, "≈ 60°/f through the accent")
	assert_almost_eq(s.angle_delta_deg("upperarm_r", 40.0, 41.0), 10.0 / 36.0, 0.05, "the slow hold drift")
	assert_almost_eq(s.height("pelvis", 30.0), 0.72, 0.001, "the anticipation crouch")
	assert_almost_eq(s.height("foot_l", 0.0), 0.06, 0.001)
	var b := s.aabb(0.0)
	assert_between(b.size.y, 1.3, 1.7, "bone bounds at rest")


func test_budget_100_frames() -> void:
	var s := RigSampler3D.for_rig("fix")
	s.pose_at("fix/rx_take", 0.0)
	var best := INF
	for block in 3:
		var t0 := Time.get_ticks_usec()
		for f in 100:
			s.pose_at("fix/rx_take", float(f % 90) + 0.5)
			s.global_pos("foot_l")
			s.global_pos("hand_r")
		best = minf(best, float(Time.get_ticks_usec() - t0) / 1000.0)
	assert_lt(best, 5.0 * cpu_load_scale(), "100 sampled frames in %.2f ms" % best)
