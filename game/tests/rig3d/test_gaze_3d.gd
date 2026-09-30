## The runtime audience gaze (lead ruling D8, sidecar `gaze` [{f0, f1, at: "camera", weight, blend}]) on the fixture
## rig: inside a window the face turns to the camera (placed left or right, both facings), weight 0 and frames outside
## the window leave the pose alone, the blend ramps in and out, a loop's seam window is continuous, an overlay's window
## counts with the overlay's weight, the keyed head pitch stays, the jiggle clamp still holds, pupils centre.
extends TestBase

const Env := preload("res://tests/rig3d/fixtures/fix_env.gd")

var _p: RigPlayer3D = null
var _cam: Camera3D = null


func before_each() -> void:
	Env.push()


func after_each() -> void:
	if _p != null and is_instance_valid(_p):
		_p.get_parent().remove_child(_p)
		_p.free()
	_p = null
	if _cam != null and is_instance_valid(_cam):
		_cam.get_parent().remove_child(_cam)
		_cam.free()
	_cam = null
	Env.pop()


## An in-memory clip on the fixture's rx_take motion (Head pitch keyed −20° at f33) with `gaze` windows.
func _gaze_clip(id: String, gaze: Array, length := 90, loop := false, layer := "base", mask: Variant = null) -> void:
	var d := {"version": 2, "format": "anim3d", "clip": id, "rig": "fix", "anim": "res://none.res", "length": length,
		"fps": 60, "loop": loop, "layer": layer, "mask": mask, "blend_in": 0, "gaze": gaze}
	var def := ClipDef3D.from_dict(id, d, "")
	assert_true(def.is_valid(), "fixture clip valid: %s" % [def.errors])
	var src := ClipLib3D.animation("fix/rx_take")
	var a := src.duplicate() as Animation
	a.length = float(length) / 60.0
	ClipLib3D.register(def, a)


func _setup(facing: int, cam_pos: Vector3) -> BoneAttachment3D:
	_p = Env.player(tree)
	_p.set_facing(facing, false)
	_p.set_cheat(35.0, 0.0)
	_cam = Camera3D.new()
	tree.root.add_child(_cam)
	_cam.global_position = cam_pos
	_p.set_gaze_camera(_cam)
	var ba := BoneAttachment3D.new()
	_p.skeleton.add_child(ba)
	ba.bone_name = "Head"
	return ba


## Shows timeline frame `f` (frame-locked) and lets the modifiers run.
func _show(f: float) -> void:
	_p.set_external_frame(f)
	_p.advance(0.0)
	await tree.process_frame


func _face(ba: BoneAttachment3D) -> Vector3:
	return ba.global_transform.basis.orthonormalized() * Vector3(0, 0, 1)


## Horizontal angle (°) between the face and the direction from the head to the camera.
func _off_camera(ba: BoneAttachment3D) -> float:
	var f := _face(ba)
	var to := _cam.global_position - ba.global_position
	return rad_to_deg(absf(Vector2(f.x, f.z).angle_to(Vector2(to.x, to.z))))


func _yaw(v: Vector3) -> float:
	return rad_to_deg(atan2(v.x, v.z))


func _pitch(v: Vector3) -> float:
	return rad_to_deg(atan2(v.y, Vector2(v.x, v.z).length()))


func test_window_turns_the_face_to_the_camera_both_facings() -> void:
	_gaze_clip("fix/st_gaze", [{"f0": 20, "f1": 70, "at": "camera", "weight": 1.0, "blend": 8}])
	for facing in [1, -1]:
		var ba := _setup(facing, Vector3(0.0, 1.5, 6.0))
		_p.play("fix/st_gaze")
		_p.gaze_enabled = false
		await _show(45.0)
		var off0 := _off_camera(ba)
		var pitch0 := _pitch(_face(ba))
		_p.gaze_enabled = true
		await _show(45.0)
		assert_almost_eq(_p.gaze_weight(), 1.0, 0.001, "full weight mid-window")
		assert_gt(off0, 40.0, "facing %d: without the gaze the face is %.1f° off the camera" % [facing, off0])
		assert_lt(_off_camera(ba), 2.0, "facing %d: the face comes round to the camera (%.1f° off)" % [facing, _off_camera(ba)])
		assert_almost_eq(_pitch(_face(ba)), pitch0, 0.5, "facing %d: the keyed head pitch is kept (yaw only)" % facing)
		var neck := _p.skeleton.find_bone("neck_01")
		var sp := _p.skeleton.find_bone("spine_02")
		assert_true(neck >= 0 and sp >= 0)
		after_each()
		Env.push()
		_gaze_clip("fix/st_gaze", [{"f0": 20, "f1": 70, "at": "camera", "weight": 1.0, "blend": 8}])


func test_camera_left_and_right() -> void:
	_gaze_clip("fix/st_gaze", [{"f0": 20, "f1": 70, "at": "camera", "weight": 1.0, "blend": 8}])
	# Facing right with the idle cheat 35 the body looks along yaw +55°: a camera far to the left needs a −77° turn,
	# one to the right +17°.
	var yaws: Array[float] = []
	for cp in [Vector3(-2.0, 1.5, 5.0), Vector3(6.0, 1.5, 2.0)]:
		var ba := _setup(1, cp)
		_p.play("fix/st_gaze")
		await _show(45.0)
		assert_lt(_off_camera(ba), 2.0, "camera at x %.0f: the face points at it (%.1f° off)" % [cp.x, _off_camera(ba)])
		yaws.append(_yaw(_face(ba)))
		after_each()
		Env.push()
		_gaze_clip("fix/st_gaze", [{"f0": 20, "f1": 70, "at": "camera", "weight": 1.0, "blend": 8}])
	assert_lt(yaws[0], -15.0, "camera left: the face turns left past the front (yaw %.1f°)" % yaws[0])
	assert_gt(yaws[1], 65.0, "camera right: the face turns further right (yaw %.1f°)" % yaws[1])


func test_weight_zero_and_outside_the_window_change_nothing() -> void:
	_gaze_clip("fix/st_gaze0", [{"f0": 20, "f1": 70, "at": "camera", "weight": 0.0, "blend": 8}])
	_gaze_clip("fix/st_gaze", [{"f0": 20, "f1": 70, "at": "camera", "weight": 1.0, "blend": 8}])
	var ba := _setup(-1, Vector3(0.0, 1.5, 6.0))
	_p.play("fix/st_gaze0")
	_p.gaze_enabled = false
	await _show(45.0)
	var ref := _face(ba)
	_p.gaze_enabled = true
	await _show(45.0)
	assert_eq(_p.gaze_weight(), 0.0)
	assert_true(_face(ba).is_equal_approx(ref), "weight 0 = the clip's own pose")
	_p.play("fix/st_gaze")
	for f in [5.0, 19.0, 71.0, 85.0]:
		_p.gaze_enabled = false
		await _show(f)
		var r2 := _face(ba)
		_p.gaze_enabled = true
		await _show(f)
		assert_eq(_p.gaze_weight(), 0.0, "f %d: outside [20, 70]" % int(f))
		assert_true(_face(ba).is_equal_approx(r2), "f %d outside the window: no change" % int(f))


func test_blend_ramps_in_and_out() -> void:
	_gaze_clip("fix/st_gaze", [{"f0": 20, "f1": 70, "at": "camera", "weight": 0.8, "blend": 8}])
	var c := ClipLib3D.get_clip("fix/st_gaze")
	assert_almost_eq(c.gaze_weight(20.0), 0.0, 0.001, "starts at 0 on f0")
	assert_almost_eq(c.gaze_weight(24.0), 0.4, 0.001, "half way up the 8 f ramp")
	assert_almost_eq(c.gaze_weight(28.0), 0.8, 0.001, "full (the window's weight) after `blend` frames")
	assert_almost_eq(c.gaze_weight(45.0), 0.8, 0.001)
	assert_almost_eq(c.gaze_weight(66.0), 0.4, 0.001, "half way down")
	assert_almost_eq(c.gaze_weight(70.0), 0.0, 0.001, "0 on f1")
	var prev := -1.0
	for f in range(20, 29):
		var w := c.gaze_weight(float(f))
		assert_gt(w, prev - 0.0001, "monotonic ramp in (f %d)" % f)
		prev = w
	# On the player: the applied turn grows through the ramp.
	var ba := _setup(1, Vector3(0.0, 1.5, 6.0))
	_p.play("fix/st_gaze")
	await _show(22.0)
	var y1 := absf(_p.gaze_mod.applied_yaw)
	await _show(26.0)
	var y2 := absf(_p.gaze_mod.applied_yaw)
	await _show(45.0)
	var y3 := absf(_p.gaze_mod.applied_yaw)
	assert_true(y1 > 0.0 and y1 < y2 and y2 < y3, "turn eases in: %.3f < %.3f < %.3f rad" % [y1, y2, y3])
	assert_true(ba != null)


func test_default_blend_and_a_loop_seam() -> void:
	_gaze_clip("fix/gz_default", [{"f0": 10, "f1": 50, "at": "camera"}], 60)
	var c := ClipLib3D.get_clip("fix/gz_default")
	assert_almost_eq(c.gaze_weight(13.0), 0.5, 0.001, "blend defaults to %d frames" % ClipDef3D.DEFAULT_GAZE_BLEND)
	assert_almost_eq(c.gaze_weight(30.0), 1.0, 0.001, "weight defaults to 1")
	_gaze_clip("fix/gz_loop", [{"f0": 0, "f1": 12, "at": "camera", "weight": 1.0, "blend": 8},
		{"f0": 100, "f1": 120, "at": "camera", "weight": 1.0, "blend": 8}], 120, true)
	var l := ClipLib3D.get_clip("fix/gz_loop")
	assert_almost_eq(l.gaze_weight(0.0), 1.0, 0.001, "a loop's seam window does not dip at f 0")
	assert_almost_eq(l.gaze_weight(120.0), 1.0, 0.001, "nor at the end")
	assert_almost_eq(l.gaze_weight(104.0), 0.5, 0.001, "the inner edge still ramps")
	assert_almost_eq(l.gaze_weight(8.0), 0.5, 0.001, "the inner edge still ramps (out)")
	var bad := ClipDef3D.from_dict("fix/gz_bad", {"version": 2, "format": "anim3d", "anim": "res://x.res", "length": 30,
		"gaze": [{"f0": 10, "f1": 40, "at": "camera"}, {"f0": 2, "f1": 8, "at": "hush"}]}, "")
	assert_false(bad.is_valid(), "a window outside the clip is an error")
	assert_eq(bad.warnings.size(), 1, "an unsupported `at` is a warning (ignored)")


func test_overlay_window_counts_with_the_overlay_weight() -> void:
	_gaze_clip("fix/gz_ov", [{"f0": 0, "f1": 40, "at": "camera", "weight": 1.0, "blend": 0}], 48, false, "overlay", "head")
	var ba := _setup(-1, Vector3(0.0, 1.5, 6.0))
	_p.play("fix/loco_idle")
	await _show(10.0)
	_p.release_external()
	assert_eq(_p.gaze_weight(), 0.0, "the idle has no window")
	_p.play_overlay("fix/gz_ov", "head", 6)
	_p.advance(3.0 / 60.0)
	assert_between(_p.gaze_weight(), 0.3, 0.7, "half way through the overlay's 6 f blend (%.2f)" % _p.gaze_weight())
	for i in 10:
		_p.advance(1.0 / 60.0)
		await tree.process_frame
	assert_almost_eq(_p.gaze_weight(), 1.0, 0.001)
	assert_lt(_off_camera(ba), 2.0, "an overlay's window turns the face too (%.1f° off)" % _off_camera(ba))


func test_viewport_camera_pupils_and_clamp() -> void:
	_gaze_clip("fix/st_gaze", [{"f0": 0, "f1": 90, "at": "camera", "weight": 1.0, "blend": 0}])
	var ba := _setup(1, Vector3(0.0, 1.5, 6.0))
	_p.set_gaze_camera(null)
	_cam.current = true
	assert_eq(_p.gaze_camera(), _cam, "no explicit camera: the viewport's active camera")
	_p.play("fix/st_gaze")
	_p.look_at_point(Vector3(10.0, 1.4, 0.0), 1.0)
	var beret := BoneAttachment3D.new()
	_p.skeleton.add_child(beret)
	beret.bone_name = "beret"
	var bi := _p.skeleton.find_bone("beret")
	var worst := 0.0
	for i in 40:
		_p.set_external_frame(float(i))
		_p.advance(1.0 / 60.0)
		await tree.process_frame
		# The spring's local rotation (modified pose, under the gazed head) vs the animated local rotation.
		var local := (ba.global_transform.affine_inverse() * beret.global_transform).basis.get_rotation_quaternion()
		worst = maxf(worst, rad_to_deg(_p.skeleton.get_bone_pose_rotation(bi).angle_to(local)))
	assert_lt(_off_camera(ba), 2.0, "the gaze wins over a look-at elsewhere (%.1f° off)" % _off_camera(ba))
	assert_lt(_p.face.look.length(), 0.05, "pupils centre on the camera while the gaze is full (%s)" % [_p.face.look])
	assert_le(worst, 30.5, "the beret spring stays inside its clamp_deg 30° through the gaze (%.1f°)" % worst)
