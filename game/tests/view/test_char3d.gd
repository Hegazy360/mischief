## The 3D cast runtime (REDESIGN_3D §5.6/§5.7): the rig descriptor, the 2D → 3D pose retarget, the
## two-bone IK and the jiggle springs. These are the modules that carry the existing 236 authored
## poses and 34 lint-checked clips onto the 3D skeleton, so a silent regression here would quietly
## break every character's motion while every 2D test stayed green.
extends TestBase

const RIGS := ["hush", "bellows"]


# --- rig descriptor -------------------------------------------------------------------------------

func test_every_cast_rig_loads_with_its_budgets_met() -> void:
	for id in RIGS:
		var rig := CastRig3D.load_rig(id)
		assert_true(rig != null, "%s: rig3d descriptor loads" % id)
		if rig == null:
			continue
		# REDESIGN_3D §5.6 budgets, checked on the built asset rather than trusted.
		assert_le(rig.tris, 10000, "%s: ≤ 10k triangles (got %d)" % [id, rig.tris])
		assert_le(rig.bone_count, 50, "%s: ≤ 50 bones incl. jiggle (got %d)" % [id, rig.bone_count])
		assert_gt(rig.jiggle.size(), 0, "%s: has secondary-motion bones" % id)
		assert_gt(rig.height_m, 1.0, "%s: a sensible height" % id)
		assert_almost_eq(rig.fk_axis.length(), 1.0, 0.0001, "%s: fk_axis is normalised" % id)
		for chain in ["arm_l", "arm_r", "leg_l", "leg_r"]:
			assert_true(rig.ik.has(chain), "%s: has an IK chain '%s'" % [id, chain])


func test_face_atlas_ports_the_2d_expression_vocabulary() -> void:
	for id in RIGS:
		var rig := CastRig3D.load_rig(id)
		if rig == null:
			continue
		for layer in ["brows", "eyes", "mouth", "extra"]:
			assert_true(rig.face_layers.has(layer), "%s: face atlas has a '%s' layer" % [id, layer])
		assert_gt(rig.face_presets.size(), 0, "%s: named face presets exist" % id)
		# A preset must resolve to a real atlas cell on every layer it names, or the shader would
		# be handed a zero rect and the expression would silently vanish.
		for preset in rig.face_presets:
			var p: Dictionary = rig.face_presets[preset]
			for layer in p:
				# A preset also carries non-cell entries (a gaze vector); only check the layers.
				if not rig.face_layers.has(layer) or typeof(p[layer]) != TYPE_STRING:
					continue
				var cell := String(p[layer])
				if cell == "none" or cell == "":
					continue
				var rect := rig.face_cell(layer, cell)
				assert_gt(rect.z, 0.0, "%s/%s: '%s' is a real cell of layer %s" % [id, preset, cell, layer])


func test_unknown_face_cells_resolve_to_an_empty_rect() -> void:
	var rig := CastRig3D.load_rig("hush")
	assert_true(rig != null)
	if rig == null:
		return
	assert_eq(rig.face_cell("eyes", "no_such_cell"), Vector4.ZERO, "unknown cell = draw nothing")
	assert_eq(rig.face_cell("no_such_layer", "open"), Vector4.ZERO, "unknown layer = draw nothing")


# --- two-bone IK ----------------------------------------------------------------------------------

func test_ik_reaches_a_target_inside_its_range() -> void:
	var root := Vector3(0, 1, 0)
	for t in [Vector3(0.3, 0.7, 0.1), Vector3(-0.18, 0.62, 0.22), Vector3(0.0, 0.45, 0.0)]:
		var sol := Ik3D.solve_two_bone(root, 0.30, 0.27, t, Vector3(0, 0, 1))
		assert_false(sol.is_empty(), "solves for %s" % t)
		if sol.is_empty():
			continue
		var joint: Vector3 = sol["joint"]
		# The solved joint must honour both bone lengths exactly: that is what keeps a limb rigid.
		assert_almost_eq((joint - root).length(), 0.30, 0.002, "upper bone keeps its length")
		var tip: Vector3 = joint + (sol["lower_dir"] as Vector3) * 0.27
		assert_almost_eq(tip.distance_to(t), 0.0, 0.003, "the tip lands on the target %s" % t)


func test_ik_clamps_an_out_of_reach_target_instead_of_stretching() -> void:
	var root := Vector3.ZERO
	var far := Vector3(0, -5.0, 0)        # far beyond 0.30 + 0.27
	var sol := Ik3D.solve_two_bone(root, 0.30, 0.27, far, Vector3(0, 0, 1))
	assert_false(sol.is_empty(), "an unreachable target still solves")
	var joint: Vector3 = sol["joint"]
	var tip: Vector3 = joint + (sol["lower_dir"] as Vector3) * 0.27
	assert_le(tip.length(), 0.5701, "the chain never stretches past upper + lower")
	assert_gt(tip.length(), 0.56, "and does extend essentially straight at the limit")


func test_ik_rejects_a_degenerate_chain() -> void:
	assert_true(Ik3D.solve_two_bone(Vector3.ZERO, 0.3, 0.3, Vector3.ZERO, Vector3.FORWARD).is_empty(),
		"a target on the root is refused rather than producing NaNs")
	assert_true(Ik3D.solve_two_bone(Vector3.ZERO, 0.0, 0.3, Vector3(0, 1, 0), Vector3.FORWARD).is_empty(),
		"a zero-length bone is refused")


func test_ik_bend_hint_picks_the_side_the_joint_goes() -> void:
	var root := Vector3.ZERO
	var target := Vector3(0, -0.5, 0)
	var fwd := Ik3D.solve_two_bone(root, 0.3, 0.27, target, Vector3(0, 0, 1))
	var back := Ik3D.solve_two_bone(root, 0.3, 0.27, target, Vector3(0, 0, -1))
	assert_false(fwd.is_empty() and back.is_empty())
	var a: Vector3 = fwd["joint"]
	var b: Vector3 = back["joint"]
	assert_gt(a.z, 0.0, "a forward hint bends the knee forward")
	assert_lt(b.z, 0.0, "a backward hint bends it the other way")


func test_swing_between_opposed_directions_is_a_half_turn() -> void:
	var q := Ik3D.swing(Vector3(0, 1, 0), Vector3(0, -1, 0))
	assert_almost_eq(q.get_angle(), PI, 0.001, "opposed directions give a half turn, not a NaN")
	var r := (q * Vector3(0, 1, 0))
	assert_almost_eq(r.distance_to(Vector3(0, -1, 0)), 0.0, 0.001, "and it actually maps one to the other")
	assert_eq(Ik3D.swing(Vector3(1, 0, 0), Vector3(1, 0, 0)), Quaternion.IDENTITY, "identical dirs = no turn")


# --- pose retarget --------------------------------------------------------------------------------

func test_retarget_binds_the_2d_channels_of_every_rig() -> void:
	for id in RIGS:
		var rig3d := CastRig3D.load_rig(id)
		var rig2d := RigDef.for_id(id)
		assert_true(rig3d != null)
		assert_true(rig2d != null)
		if rig3d == null or rig2d == null:
			continue
		var skel := _skeleton_for(rig3d)
		assert_true(skel != null, "%s: the .glb carries a skeleton" % id)
		if skel == null:
			continue
		var rt := PoseRetarget3D.build(rig3d, rig2d, skel)
		assert_true(rt.is_valid(), "%s: the retarget binds at least one channel" % id)
		# The limbs are what carry a pose's silhouette: every one must be bound on both sides.
		var bound := {}
		for b in rt.bindings:
			bound[b.channel] = true
		for ch in ["arm_upper_l", "arm_lower_l", "arm_upper_r", "arm_lower_r",
				"leg_upper_l", "leg_lower_l", "leg_upper_r", "leg_lower_r", "head", "torso"]:
			assert_true(bound.has(ch), "%s: channel '%s' is bound to a bone" % [id, ch])
		skel.get_parent().free()


func test_a_split_channel_keeps_the_authored_total_angle() -> void:
	var rig3d := CastRig3D.load_rig("hush")
	assert_true(rig3d != null)
	if rig3d == null:
		return
	# A 2D "torso" hinge is spread over spine + chest so it bends like a spine, but the summed
	# angle has to stay exactly what the animator authored or every pose changes shape.
	for ch in ["torso", "head"]:
		var weights := rig3d.channel_bones(ch)
		assert_gt(weights.size(), 1, "'%s' is split over several bones" % ch)
		var total := 0.0
		for b in weights:
			total += float(weights[b])
		assert_almost_eq(total, 1.0, 0.0001, "'%s' split weights sum to 1" % ch)


func test_retarget_turns_a_clockwise_2d_angle_into_a_negative_sagittal_turn() -> void:
	var rig3d := CastRig3D.load_rig("hush")
	var rig2d := RigDef.for_id("hush")
	if rig3d == null or rig2d == null:
		return
	var skel := _skeleton_for(rig3d)
	if skel == null:
		return
	var rt := PoseRetarget3D.build(rig3d, rig2d, skel)
	var pose := rig2d.rest.duplicate()
	var part := rig2d.names.find("arm_upper_r")
	assert_ge(part, 0)
	pose[RigDef.ROOT_CH + part * RigDef.STRIDE + RigDef.C_ROT] = 30.0
	rt.apply(skel, pose)
	var bone := skel.find_bone("arm_upper_r")
	assert_ge(bone, 0)
	var rest := skel.get_bone_rest(bone).basis.get_rotation_quaternion()
	var delta := rest.inverse() * skel.get_bone_pose_rotation(bone)
	# 2D degrees are clockwise-positive on screen; 3D is a right-handed turn about the rig's
	# sagittal axis, so the sign flips. 30° in must come out as 30° of turn, negative sense.
	assert_almost_eq(absf(delta.get_angle()), deg_to_rad(30.0), 0.01, "the authored 30° survives")
	assert_lt(delta.get_axis().dot(rig3d.fk_axis) * delta.get_angle(), 0.0,
		"a clockwise 2D angle is a negative turn about the sagittal axis")
	skel.get_parent().free()


func test_root_offset_scales_from_pose_px_into_metres() -> void:
	var rig3d := CastRig3D.load_rig("hush")
	var rig2d := RigDef.for_id("hush")
	if rig3d == null or rig2d == null:
		return
	var skel := _skeleton_for(rig3d)
	if skel == null:
		return
	var rt := PoseRetarget3D.build(rig3d, rig2d, skel)
	var pose := rig2d.rest.duplicate()
	pose[RigDef.R_Y] = -rig2d.height_px     # a full body height "up" in 2D screen terms
	var off := rt.apply(skel, pose)
	assert_almost_eq(off.y, rig3d.height_m, 0.01, "a body height of 2D bob is a body height in metres")
	assert_gt(off.y, 0.0, "2D screen y grows downward; 3D y grows up")
	skel.get_parent().free()


func test_root_scale_keeps_volume_by_following_width_in_depth() -> void:
	var pose := PackedFloat32Array()
	pose.resize(RigDef.ROOT_CH)
	pose[RigDef.R_SX] = 1.3
	pose[RigDef.R_SY] = 0.7
	var s := PoseRetarget3D.root_scale(pose)
	assert_almost_eq(s.x, 1.3, 0.0001)
	assert_almost_eq(s.y, 0.7, 0.0001)
	assert_almost_eq(s.z, 1.3, 0.0001, "depth follows width, so a squash keeps its volume")
	# A pose that never set the scale channels must not collapse the character.
	var zero := PackedFloat32Array()
	zero.resize(RigDef.ROOT_CH)
	assert_eq(PoseRetarget3D.root_scale(zero), Vector3.ONE, "unset scale channels read as 1")


# --- jiggle ---------------------------------------------------------------------------------------

func test_jiggle_binds_and_settles_when_nothing_moves() -> void:
	var rig3d := CastRig3D.load_rig("bellows")
	if rig3d == null:
		return
	var skel := _skeleton_for(rig3d)
	if skel == null:
		return
	var j := Jiggle3D.new()
	j.configure(rig3d, skel)
	assert_eq(j.bone_count(), rig3d.jiggle.size(), "every jiggle bone of the rig is bound")
	# Settle, then confirm a still character produces a still pose: a spring that never comes to
	# rest would make a frozen Hush shimmer, which is the one thing FREEZE must not do.
	for i in 120:
		j.step(skel, 1.0 / 60.0)
	var idx := skel.find_bone(rig3d.jiggle[0]["bone"])
	var a := skel.get_bone_pose_rotation(idx)
	for i in 30:
		j.step(skel, 1.0 / 60.0)
	var b := skel.get_bone_pose_rotation(idx)
	assert_almost_eq(a.angle_to(b), 0.0, 0.002, "a still character's jiggle is at rest")
	skel.get_parent().free()


func test_jiggle_swing_stays_inside_its_max_angle() -> void:
	var rig3d := CastRig3D.load_rig("hush")
	if rig3d == null:
		return
	var skel := _skeleton_for(rig3d)
	if skel == null:
		return
	var j := Jiggle3D.new()
	j.configure(rig3d, skel)
	j.step(skel, 1.0 / 60.0)
	# Yank the character sideways every frame; the springs must lag but never fold through the head.
	var max_deg := 0.0
	for i in 90:
		skel.global_position = Vector3(sin(i * 0.9) * 2.0, 0, 0)
		j.step(skel, 1.0 / 60.0)
		for spec in rig3d.jiggle:
			var idx := skel.find_bone(spec["bone"])
			if idx < 0:
				continue
			var rest := skel.get_bone_rest(idx).basis.get_rotation_quaternion()
			var swing := rad_to_deg((rest.inverse() * skel.get_bone_pose_rotation(idx)).get_angle())
			assert_le(swing, float(spec["max_deg"]) + 1.0,
				"%s stays inside its %s° limit" % [spec["bone"], spec["max_deg"]])
			max_deg = maxf(max_deg, swing)
	assert_gt(max_deg, 0.5, "the springs actually reacted to being thrown about")
	skel.get_parent().free()


func test_jiggle_can_be_switched_off_for_a_frozen_pose() -> void:
	var rig3d := CastRig3D.load_rig("hush")
	if rig3d == null:
		return
	var skel := _skeleton_for(rig3d)
	if skel == null:
		return
	var j := Jiggle3D.new()
	j.configure(rig3d, skel)
	j.set_enabled(false)
	var idx := skel.find_bone(rig3d.jiggle[0]["bone"])
	var before := skel.get_bone_pose_rotation(idx)
	for i in 20:
		skel.global_position = Vector3(sin(i) * 3.0, 0, 0)
		j.step(skel, 1.0 / 60.0)
	assert_almost_eq(before.angle_to(skel.get_bone_pose_rotation(idx)), 0.0, 0.0001,
		"disabled jiggle writes nothing")
	skel.get_parent().free()


# --- helpers ---------------------------------------------------------------------------------------

## Instance a cast .glb and return its Skeleton3D, parented into the tree so global transforms are
## real. The caller frees `skel.get_parent()`.
func _skeleton_for(rig: CastRig3D) -> Skeleton3D:
	if not ResourceLoader.exists(rig.mesh_path):
		return null
	var packed: PackedScene = load(rig.mesh_path)
	if packed == null:
		return null
	var inst := packed.instantiate()
	tree.root.add_child(inst)
	var skel := _find_skel(inst)
	return skel


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var s := _find_skel(c)
		if s != null:
			return s
	return null


# --- foot grounding ---------------------------------------------------------------------------------

func test_ground_offset_reports_the_lift_that_plants_the_lowest_foot() -> void:
	var rig3d := CastRig3D.load_rig("hush")
	if rig3d == null:
		return
	var skel := _skeleton_for(rig3d)
	if skel == null:
		return
	# Hold the character a clear 40 cm above the stage: the reported lift must bring it back down.
	skel.get_parent().position = Vector3(0, 0.4, 0)
	var lift := Ik3D.ground_offset(skel, rig3d, 0.0, 1.0)
	assert_almost_eq(lift, -0.4, 0.02, "a character 0.4 m up is asked to drop 0.4 m")
	skel.get_parent().position = Vector3(0, -0.15, 0)
	assert_almost_eq(Ik3D.ground_offset(skel, rig3d, 0.0, 1.0), 0.15, 0.02, "and sunk feet are lifted")
	skel.get_parent().free()


func test_ground_offset_is_zero_once_the_character_stands_on_the_floor() -> void:
	var rig3d := CastRig3D.load_rig("hush")
	if rig3d == null:
		return
	var skel := _skeleton_for(rig3d)
	if skel == null:
		return
	var root := skel.get_parent() as Node3D
	root.position.y += Ik3D.ground_offset(skel, rig3d, 0.0, 1.0)
	assert_almost_eq(Ik3D.ground_offset(skel, rig3d, 0.0, 1.0), 0.0, 0.003,
		"grounding converges in one step rather than oscillating")
	root.free()


func test_plant_feet_leaves_a_raised_foot_alone() -> void:
	var rig3d := CastRig3D.load_rig("hush")
	if rig3d == null:
		return
	var skel := _skeleton_for(rig3d)
	if skel == null:
		return
	# Well above the floor: nothing is below it, so a step must not be dragged down.
	skel.get_parent().position = Vector3(0, 1.0, 0)
	assert_eq(Ik3D.plant_feet(skel, rig3d, 0.0, 1.0), 0, "feet above the floor are not touched")
	skel.get_parent().free()
