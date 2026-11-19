## RigIK + RigPlayer limb goals (docs/research/animation.md, phase 1): the grip lands on the
## target on every real rig, out-of-reach / stretch / joint limits / weight behave, the elbow
## never flips along a smooth target path, and the player's goal layer is exact in WORLD space
## (facing, lean, squash) and blends in and out cleanly. Every position is checked with an
## independent full-rig FK (RigSampler.solve), not with the solver's own error report.
extends TestBase

const RIGS: PackedStringArray = ["_mannequin", "hush", "bellows"]
const ARMS: PackedStringArray = ["r", "l"]
const DT := 1.0 / 60.0
## Accuracy bar for a reachable target (px in character space).
const TOL := 0.5

var _xf: Array[Transform2D] = []
var _p: RigPlayer = null


func after_each() -> void:
	if is_instance_valid(_p):
		_p.free()
	_p = null


# --- helpers ---------------------------------------------------------------------------------

func _rig(id: String) -> RigDef:
	return RigDef.for_id(id)


## Rest-ish pose of a rig: its first `stand` pose when it has one, else the rest pose.
func _stand(rig: RigDef) -> PackedFloat32Array:
	var lib := PoseLib.for_rig(rig.id)
	for pn in ["m_stand", "h_stand", "b_stand"]:
		if lib != null and lib.has_pose(pn):
			return lib.pose(pn).duplicate()
	return rig.rest.duplicate()


func _chain(rig: RigDef, side: String) -> Vector3i:
	return RigIK.chain_of(rig, rig.idx("hand_" + side))


func _tip(rig: RigDef, side: String) -> Vector2:
	return RigIK.socket_tip(rig, rig.socket_index("hand_%s:grip" % side))


## The grip in character space by full-rig FK (independent of RigIK).
func _grip(rig: RigDef, pose: PackedFloat32Array, side: String) -> Vector2:
	RigSampler.solve(rig, pose, _xf)
	return _xf[rig.idx("hand_" + side)] * _tip(rig, side)


func _shoulder(rig: RigDef, pose: PackedFloat32Array, side: String) -> Vector2:
	RigSampler.solve(rig, pose, _xf)
	return _xf[rig.idx("arm_upper_" + side)].origin


func _arm_len(rig: RigDef, side: String) -> float:
	var c := _chain(rig, side)
	return rig.offset[c.y].length() + rig.offset[c.z].length()


## The grip's reachable band [inner, outer] from the shoulder in `pose`: the grip sits past the
## wrist, so it lengthens the forearm (outer) and stops the hand folding onto the shoulder (inner).
func _band(rig: RigDef, pose: PackedFloat32Array, side: String) -> Vector2:
	var c := _chain(rig, side)
	var b2 := rig.offset[c.z] + _tip(rig, side).rotated(deg_to_rad(_rot(rig, pose, c.z)))
	var l1 := rig.offset[c.y].length()
	return Vector2(absf(l1 - b2.length()), l1 + b2.length())


func _rot(rig: RigDef, pose: PackedFloat32Array, part: int) -> float:
	return pose[RigDef.ch(part, RigDef.C_ROT)]


func _solve(rig: RigDef, pose: PackedFloat32Array, side: String, target: Vector2, stretch: float = 1.0,
		limits: bool = false, weight: float = 1.0, end_deg: float = NAN) -> Vector2:
	var c := _chain(rig, side)
	return RigIK.two_bone(rig, pose, c.x, c.y, c.z, target, end_deg, 0.0, weight, stretch, _tip(rig, side), limits)


# --- RigIK ------------------------------------------------------------------------------------

func test_every_rig_has_two_bone_arms_with_a_grip() -> void:
	for id in RIGS:
		var rig := _rig(id)
		if not assert_true(rig != null, id):
			continue
		for side in ARMS:
			var c := _chain(rig, side)
			assert_eq(c, Vector3i(rig.idx("arm_upper_" + side), rig.idx("arm_lower_" + side), rig.idx("hand_" + side)), "%s arm_%s chain" % [id, side])
			assert_true(rig.socket_index("hand_%s:grip" % side) >= 0, "%s hand_%s:grip" % [id, side])


func test_grip_lands_on_reachable_targets_on_every_rig() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7341
	for id in RIGS:
		var rig := _rig(id)
		for side in ARMS:
			var worst := 0.0
			var reported := 0.0
			var band := _band(rig, _stand(rig), side)
			for i in 200:
				var pose := _stand(rig)
				var sh := _shoulder(rig, pose, side)
				var ang := rng.randf_range(-PI, PI)
				var t := sh + Vector2(cos(ang), sin(ang)) * lerpf(band.x, band.y, rng.randf_range(0.1, 0.9))
				var res := _solve(rig, pose, side, t)
				worst = maxf(worst, _grip(rig, pose, side).distance_to(t))
				reported = maxf(reported, res.x)
			assert_lt(worst, TOL, "%s arm_%s: worst grip error %.3f px over 200 targets" % [id, side, worst])
			assert_lt(reported, TOL, "%s arm_%s: the solver reports what FK measures (%.3f)" % [id, side, reported])


func test_lean_and_squash_are_exact() -> void:
	var rig := _rig("hush")
	var pose := _stand(rig)
	pose[RigDef.ch(rig.idx("torso"), RigDef.C_ROT)] = 35.0
	pose[RigDef.R_SX] = 1.15
	pose[RigDef.R_SY] = 0.85
	pose[RigDef.R_ROT] = -8.0
	var t := _shoulder(rig, pose, "r") + Vector2(40, -30)
	_solve(rig, pose, "r", t)
	assert_lt(_grip(rig, pose, "r").distance_to(t), TOL, "a leaning, squashed body still reaches exactly")


func test_out_of_reach_points_straight_at_the_target() -> void:
	for id in RIGS:
		var rig := _rig(id)
		var pose := _stand(rig)
		var sh := _shoulder(rig, pose, "r")
		var t := sh + Vector2(1, -1).normalized() * _arm_len(rig, "r") * 2.0
		var res := _solve(rig, pose, "r", t)
		assert_almost_eq(res.y, 1.0, 0.0001, "%s: rigid by default" % id)
		var wrist := RigIK.effector(rig, pose, rig.idx("hand_r"), Vector2.ZERO)
		var dir_err := absf(rad_to_deg((wrist - sh).angle_to(t - sh)))
		assert_lt(dir_err, 12.0, "%s: the straight arm aims at the target (%.1f°; the grip offset bends it a little)" % [id, dir_err])
		assert_gt(res.x, _arm_len(rig, "r") * 0.5, "%s: the error says the target was missed (%.1f px)" % [id, res.x])
		var c := _chain(rig, "r")
		assert_almost_eq(pose[RigDef.ch(c.y, RigDef.C_Y)], 0.0, 0.0001, "%s: no stretch offset written" % id)


func test_stretch_reaches_past_the_arm_up_to_its_cap() -> void:
	var rig := _rig("hush")
	var c := _chain(rig, "r")
	var hand_s := Vector2(_stand(rig)[RigDef.ch(c.z, RigDef.C_SX)], _stand(rig)[RigDef.ch(c.z, RigDef.C_SY)])
	var pose := _stand(rig)
	var sh := _shoulder(rig, pose, "r")
	var t := sh + Vector2(0.3, -1).normalized() * _arm_len(rig, "r") * 1.15
	var res := _solve(rig, pose, "r", t, 1.3)
	assert_lt(_grip(rig, pose, "r").distance_to(t), TOL, "1.15× away with a 1.3 cap: reached (%.3f px)" % _grip(rig, pose, "r").distance_to(t))
	assert_between(res.y, 1.0, 1.3, "stretch used %.3f" % res.y)
	assert_eq(Vector2(pose[RigDef.ch(c.z, RigDef.C_SX)], pose[RigDef.ch(c.z, RigDef.C_SY)]), hand_s, "the hand texture is never scaled")
	pose = _stand(rig)
	var far := sh + Vector2(0.3, -1).normalized() * _arm_len(rig, "r") * 1.8
	res = _solve(rig, pose, "r", far, 1.3)
	assert_almost_eq(res.y, 1.3, 0.0001, "capped at 1.3")
	assert_gt(res.x, 10.0, "and reports the miss")


func test_joint_limits_hold_and_the_miss_is_reported() -> void:
	var rig := _rig("_mannequin")
	var c := _chain(rig, "r")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 300:
		var pose := _stand(rig)
		var sh := _shoulder(rig, pose, "r")
		var ang := rng.randf_range(-PI, PI)
		var t := sh + Vector2(cos(ang), sin(ang)) * _arm_len(rig, "r") * rng.randf_range(0.3, 0.95)
		var res := _solve(rig, pose, "r", t, 1.0, true)
		for part in [c.x, c.y]:
			assert_between(_rot(rig, pose, part), rig.rot_min[part] - 0.001, rig.rot_max[part] + 0.001,
				"%s within its limits (target %s)" % [rig.names[part], t])
		assert_almost_eq(res.x, _grip(rig, pose, "r").distance_to(t), 0.05, "reported error = FK error")


func test_elbow_never_flips_along_a_smooth_path() -> void:
	for id in RIGS:
		var rig := _rig(id)
		var c := _chain(rig, "r")
		var pose0 := _stand(rig)
		var sh := _shoulder(rig, pose0, "r")
		var band := _band(rig, pose0, "r")
		var mid := (band.x + band.y) * 0.5
		var rad := (band.y - band.x) * 0.3
		var prev_u := NAN
		var prev_l := NAN
		var worst := 0.0
		var sign0 := 0.0
		# 360 steps round a circle in front of the shoulder, inside the reach band (< 1 px a step).
		for i in 361:
			var a := TAU * float(i) / 360.0
			var t := sh + Vector2(mid, 0) + Vector2(cos(a), sin(a)) * rad
			var pose := pose0.duplicate()
			_solve(rig, pose, "r", t, 1.0, true)
			var u := _rot(rig, pose, c.x)
			var l := _rot(rig, pose, c.y)
			# The elbow side = the sign of the turn from the upper bone to the wrist.
			RigSampler.solve(rig, pose, _xf)
			var e1 := _xf[c.y].origin - _xf[c.x].origin
			var e2 := _xf[c.z].origin - _xf[c.y].origin
			var side_now := signf(e1.cross(e2))
			if sign0 == 0.0:
				sign0 = side_now
			assert_eq(side_now, sign0, "%s: elbow side constant (step %d)" % [id, i])
			if not is_nan(prev_u):
				worst = maxf(worst, maxf(absf(wrapf(u - prev_u, -180.0, 180.0)), absf(wrapf(l - prev_l, -180.0, 180.0))))
			prev_u = u
			prev_l = l
		assert_lt(worst, 4.0, "%s: no joint jumps more than 4° for a < 1 px target step (worst %.2f°)" % [id, worst])


func test_weight_blends_the_hand_along_a_straight_line() -> void:
	var rig := _rig("hush")
	var base := _stand(rig)
	var from := _grip(rig, base, "r")
	var t := _shoulder(rig, base, "r") + Vector2(50, -40)
	var p0 := base.duplicate()
	_solve(rig, p0, "r", t, 1.0, true, 0.0)
	for i in base.size():
		assert_almost_eq(p0[i], base[i], 0.0001, "weight 0 gives the incoming pose back (channel %d)" % i)
	for w in [0.25, 0.5, 0.75, 1.0]:
		var pw := base.duplicate()
		var res := _solve(rig, pw, "r", t, 1.0, true, w)
		var want := from.lerp(t, w)
		assert_lt(_grip(rig, pw, "r").distance_to(want), TOL, "weight %.2f: the grip is %.0f %% of the way along the line" % [w, w * 100.0])
		assert_almost_eq(res.x, _grip(rig, pw, "r").distance_to(t), 0.05, "the error is the distance still to go")


func test_fixed_end_rotation() -> void:
	var rig := _rig("bellows")
	var pose := _stand(rig)
	var t := _shoulder(rig, pose, "r") + Vector2(45, 10)
	_solve(rig, pose, "r", t, 1.0, false, 1.0, -30.0)
	RigSampler.solve(rig, pose, _xf)
	assert_almost_eq(rad_to_deg(_xf[rig.idx("hand_r")].get_rotation()), -30.0, 0.01, "hand at the asked world angle")
	assert_lt(_grip(rig, pose, "r").distance_to(t), TOL, "and the grip still on target")


# --- RigPlayer limb goals -------------------------------------------------------------------

func _player(id: String) -> RigPlayer:
	_p = RigPlayer.new()
	_p.configure_for_tools()
	_p.springs_enabled = false
	tree.root.add_child(_p)
	_p.setup(id)
	_p.position = Vector2(400, 600)
	_p.set_static_pose(_stand(_p.rig))
	_p.advance(0.0)
	return _p


func _world_grip(p: RigPlayer, side: String) -> Vector2:
	return p.socket_global_transform("hand_%s:grip" % side).origin


func test_player_goal_is_exact_in_world_space_both_facings() -> void:
	for id in RIGS:
		for facing in [1, -1]:
			var p := _player(id)
			p.set_facing(facing, false)
			p.advance(0.0)
			var sh := p.part_global_position("arm_upper_r")
			var t := sh + Vector2(55.0 * facing, -45.0)
			assert_true(p.set_goal("arm_r", t, {"blend_f": 0}), "%s has arm_r" % id)
			p.advance(DT)
			var e := _world_grip(p, "r").distance_to(t)
			assert_lt(e, 1.0, "%s facing %d: grip on the world target (%.3f px)" % [id, facing, e])
			assert_lt(p.goal_error("arm_r"), 1.0, "%s: goal_error agrees" % id)
			_p.free()
			_p = null


func test_player_goal_tracks_a_moving_target_and_survives_a_turn() -> void:
	var p := _player("hush")
	var sh := p.part_global_position("arm_upper_r")
	p.set_goal("arm_r", sh + Vector2(60, 0), {"blend_f": 0})
	for i in 60:
		var t := sh + Vector2(60, 0).rotated(-float(i) * 0.02)
		p.move_goal("arm_r", t)
		p.advance(DT)
		assert_lt(_world_grip(p, "r").distance_to(t), 1.0, "frame %d tracks" % i)
	p.set_facing(-1, true)
	var t2 := p.part_global_position("arm_upper_r") + Vector2(-50, -20)
	p.move_goal("arm_r", t2)
	for i in 8:
		p.advance(DT)
	assert_lt(_world_grip(p, "r").distance_to(t2), 1.0, "after the 6-frame turn the grip is still on target")


func test_player_goal_blends_in_and_out() -> void:
	var p := _player("hush")
	var rest := _world_grip(p, "r")
	var t := p.part_global_position("arm_upper_r") + Vector2(60, -50)
	p.set_goal("arm_r", t, {"blend_f": 8})
	var total := rest.distance_to(t)
	var last := total
	var prev := rest
	var steps := PackedFloat32Array()
	for i in 8:
		p.advance(DT)
		var g := _world_grip(p, "r")
		var d := g.distance_to(t)
		assert_le(d, last + 0.01, "frame %d: moving toward the target" % i)
		steps.append(g.distance_to(prev))
		prev = g
		last = d
	# No snap: a smoothstep blend starts slow and never moves faster than 1.5× the average step.
	assert_lt(steps[0], total / 8.0 * 0.5, "first frame eases out of the pose (%.2f of %.1f px)" % [steps[0], total])
	for i in steps.size():
		assert_le(steps[i], total / 8.0 * 1.6, "frame %d: hand speed %.2f px/f within the smoothstep peak" % [i, steps[i]])
	assert_almost_eq(p.goal_weight("arm_r"), 1.0, 0.0001, "fully in after blend_f frames")
	assert_lt(last, 1.0, "on target")
	p.clear_goal("arm_r", 8)
	for i in 8:
		p.advance(DT)
	assert_false(p.has_goal("arm_r"), "gone after blending out")
	assert_lt(_world_grip(p, "r").distance_to(rest), 0.01, "the hand is back where the pose had it")


func test_player_goal_on_a_playing_clip_and_stretch() -> void:
	var p := _player("hush")
	p.play("hush/loco_idle")
	p.advance(DT)
	var sh := p.part_global_position("arm_upper_r")
	var t := sh + Vector2(0.2, -1).normalized() * _arm_len(p.rig, "r") * 1.2
	p.set_goal("arm_r", t, {"blend_f": 0, "stretch": 1.3})
	for i in 30:
		p.advance(DT)
		assert_lt(_world_grip(p, "r").distance_to(t), 1.0, "frame %d: idle + stretch reach holds" % i)
	assert_between(p.goal_stretch("arm_r"), 1.0, 1.3, "stretched %.3f" % p.goal_stretch("arm_r"))


func test_unknown_limb_is_refused() -> void:
	var p := _player("_mannequin")
	assert_false(p.set_goal("tail", Vector2.ZERO), "no such limb")
	assert_false(p.has_goal("tail"))
	assert_true(p.goal_limbs().has("arm_l") and p.goal_limbs().has("leg_r"), "arms and legs take goals: %s" % p.goal_limbs())
