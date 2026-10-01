## RigPlayer3D (r3d-index §7.1) on the fixture rig: setup + the stand-in, frame-lock exactness, facing / cheat yaw
## math and the 6-frame turn, clip events through the player, the face driver on the material, looks and body slots
## (the sneeze sequence), props (states, sockets, launch, reset, resolution order, `set:` pieces emitted only),
## tint / stone uniforms, the masked overlay.
extends TestBase

const Env := preload("res://tests/rig3d/fixtures/fix_env.gd")

var _p: RigPlayer3D = null
var _events: Array = []


func before_each() -> void:
	Env.push()
	_events = []


func after_each() -> void:
	if _p != null and is_instance_valid(_p):
		_p.get_parent().remove_child(_p)
		_p.free()
	_p = null
	Env.pop()


func _player() -> RigPlayer3D:
	_p = Env.player(tree)
	_p.clip_event.connect(func(e: Dictionary) -> void: _events.append(e))
	return _p


func _track_rot(clip_id: String, bone: String, frame: float) -> Quaternion:
	var a := ClipLib3D.animation(clip_id)
	var t := a.find_track(NodePath("Armature/Skeleton3D:%s" % bone), Animation.TYPE_ROTATION_3D)
	return a.rotation_track_interpolate(t, frame / 60.0)


func _pose_rot(bone: String) -> Quaternion:
	return _p.skeleton.get_bone_pose_rotation(_p.skeleton.find_bone(bone))


func _qeq(a: Quaternion, b: Quaternion, eps := 0.0005) -> bool:
	return absf(a.dot(b)) > 1.0 - eps


func test_setup_on_the_fixture() -> void:
	var p := _player()
	assert_true(p.ok)
	assert_true(p.skeleton != null and p.mesh != null)
	assert_true(p.stand_in == null)
	assert_true(p.tree != null and p.tree.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
		"the tree is advanced by the player")
	assert_eq(p.mesh.layers, RigPlayer3D.CHAR_LAYER_BITS, "the character is on visual layer 2 (CHAR)")
	if ResourceLoader.exists(RigPlayer3D.CHAR_SHADER):
		assert_true(p.material() != null, "char_toon material built")
		assert_true(p.material().next_pass != null, "outline next pass")
		assert_eq(p.material().next_pass.get_shader_parameter("outline_px"), 3.5)
		p.set_outline_scale(1.5)
		assert_almost_eq(float(p.material().next_pass.get_shader_parameter("outline_px")), 3.5, 0.0001,
			"one path: Settings scales the global mnd_outline_scale, never outline_px (no 1.5 × 1.5)")
		assert_almost_eq(p.outline_scale(), 1.5)
		p.set_outline_scale(1.0)


func test_stand_in_on_a_broken_descriptor() -> void:
	allow_errors()
	_p = RigPlayer3D.new()
	tree.root.add_child(_p)
	assert_false(_p.setup("nobody"), "setup fails")
	assert_true(_p.stand_in != null, "a counted stand-in capsule shows instead")
	_p.play("nobody/loco_idle")
	assert_eq(int(_p.counts()["missing_clips"].get("nobody/loco_idle", 0)), 1, "plays on a stand-in are counted")
	assert_true(_p.screen_aabb().size.y > 1.0, "the stand-in still has bounds")


func test_frame_lock_is_exact_and_never_drifts() -> void:
	var p := _player()
	p.play("fix/rx_take")
	p.set_external_frame(40.0)
	var want := _track_rot("fix/rx_take", "upperarm_r", 40.0)
	assert_true(_qeq(_pose_rot("upperarm_r"), want), "frame 40 exactly: %s vs %s" % [_pose_rot("upperarm_r"), want])
	for i in 300:
		p.set_external_frame(40.0)
		p.advance(1.0 / 60.0)
	assert_true(_qeq(_pose_rot("upperarm_r"), want), "no drift after 300 frames")
	assert_true(p.is_external())
	assert_eq(p.current_frame(), 40.0)
	p.set_external_frame(92.0)
	assert_eq(p.current_frame(), 90.0, "clamped to the clip")
	p.release_external()
	assert_false(p.is_external())


func test_view_clock_plays_and_finishes_once() -> void:
	var p := _player()
	var done: Array = []
	p.clip_finished.connect(func(id: String) -> void: done.append(id))
	p.play("fix/rx_take")
	for i in 100:
		p.advance(1.0 / 60.0)
	assert_eq(done, ["fix/rx_take"], "finished once")
	assert_eq(p.current_frame(), 90.0)
	assert_true(_qeq(_pose_rot("upperarm_r"), _track_rot("fix/rx_take", "upperarm_r", 90.0)), "holds the last frame")


func test_facing_and_cheat_yaw_math() -> void:
	assert_eq(RigPlayer3D.yaw_for(1, 35.0), 55.0, "right: 90° − cheat")
	assert_eq(RigPlayer3D.yaw_for(-1, 35.0), -55.0, "left: −90° + cheat")
	var p := _player()
	p.set_cheat(20.0, 0.0)
	p.set_facing(1, false)
	assert_almost_eq(p.body.rotation_degrees.y, 70.0, 0.001)
	p.set_facing(-1, true)
	var ys: Array[float] = []
	for i in 7:
		p.advance(1.0 / 60.0)
		ys.append(p.body.rotation_degrees.y)
	assert_almost_eq(ys[5], -70.0, 0.001, "the turn lands on frame 6")
	for i in 5:
		assert_lt(ys[i + 1], ys[i] + 0.0001, "monotonic (no pop)")
	assert_gt(ys[0], -70.0 + 1.0, "eased, not a snap")
	p.set_cheat(0.0, 0.2)
	for i in 15:
		p.advance(1.0 / 60.0)
	assert_almost_eq(p.body.rotation_degrees.y, -90.0, 0.01, "the cheat eases out over 0.2 s")


func test_events_through_the_player() -> void:
	var p := _player()
	p.play("fix/loco_walk")
	for i in 170:
		p.advance(1.0 / 60.0)
	var steps := 0
	for e in _events:
		if String(e.get("type", "")) == "sfx":
			steps += 1
			assert_has(e, "clip")
			assert_has(e, "rig")
			assert_has(e, "f")
	# 170 frames of an 80 f loop = steps at 0, 40, 80, 120, 160.
	assert_eq(steps, 5, "every step once, incl. the frame-0 step and across the wrap")
	_events.clear()
	p.play("fix/rx_take")
	for f in [0.0, 20.0, 45.0, 45.0, 60.0, 90.0]:
		p.set_external_frame(f)
	var types: Array = []
	for e2 in _events:
		types.append("%s@%d" % [e2["type"], e2["f"]])
	assert_has(types, "sfx@30")
	assert_has(types, "prop@40")
	assert_has(types, "prop@50")
	assert_has(types, "mark@90")
	var n30 := 0
	for t in types:
		if t == "sfx@30":
			n30 += 1
	assert_eq(n30, 1, "a repeated locked frame fires nothing twice")


func test_set_pieces_are_emitted_only() -> void:
	var p := _player()
	p.play("fix/rx_take")
	p.set_external_frame(55.0)
	var lend := {}
	for e in _events:
		if String(e.get("prop", "")) == "set:kitchen_kettle":
			lend = e
	assert_eq(String(lend.get("op", "")), "lend", "the lend event reaches the view untouched")
	assert_eq(p.counts()["missing_clips"], {}, "no error for a set piece")


func test_face_preset_timeline_and_mirror() -> void:
	var p := _player()
	var f := p.face
	var neutral := f.preset_cells("neutral")
	assert_eq(neutral[FaceCards3D.L_EYES], 8)
	assert_eq(neutral[FaceCards3D.L_MOUTH], 32)
	var happy := f.preset_cells("happy")
	assert_eq(happy[FaceCards3D.L_EXTRA_A], 40, "'blush': 'on' lands in extra_a")
	p.set_face("shock")
	p.advance(1.0 / 60.0)
	assert_eq(p.material().get_shader_parameter("face_cell_a"), Vector4i(1, 9, 24, 33), "brows up, eyes wide, pupils centre, mouth O")
	p.play("fix/rx_take")
	p.set_external_frame(10.0)
	p.advance(0.0)
	assert_eq(f.active_preset, "neutral", "the clip's timeline wins")
	p.set_external_frame(31.0)
	p.advance(0.0)
	assert_eq(f.cell_a.y, 9, "shock from f 30")
	p.set_external_frame(82.0)
	p.advance(0.0)
	assert_eq(f.cell_a.w, 33, "a slots-only entry changes just the mouth")
	assert_eq(f.cell_a.x, 2, "... over the previous entry's preset (sly brows)")
	assert_eq(f.cell_b.x, 41, "sly's tear")
	p.set_facing(-1, false)
	p.advance(0.0)
	assert_eq(f.cell_a.x, 3, "facing −1: sly → sly_m")
	assert_eq(f.cell_b.x, 42, "facing −1: tear → tear_m")
	assert_lt(f.pupil.x, 0.0001, "pupil offset mirrored too")


func test_blinks_are_seeded_and_suppressed() -> void:
	var def := RigDef3D.load("fix")
	var a := FaceCards3D.new()
	var b := FaceCards3D.new()
	a.setup(def, 7)
	b.setup(def, 7)
	var frames_a: Array = []
	var frames_b: Array = []
	for i in 1200:
		a.update(1.0)
		b.update(1.0)
		if a.blink_t == 0.0:
			frames_a.append(i)
		if b.blink_t == 0.0:
			frames_b.append(i)
	assert_eq(frames_a, frames_b, "same seed → same blink frames")
	assert_gt(frames_a.size(), 2, "blinks every 2–6 s")
	var gaps_ok := true
	for i in range(1, frames_a.size()):
		var gap: int = frames_a[i] - frames_a[i - 1]
		gaps_ok = gaps_ok and (gap <= 360 + 6 or gap < 12)
	assert_true(gaps_ok, "gaps within 2–6 s (or a double)")
	# Closed eyes during a blink, then open again.
	var c := FaceCards3D.new()
	c.setup(def, 7)
	var saw_closed := false
	for i in 400:
		c.update(1.0)
		saw_closed = saw_closed or c.cell_a.y == 10
	assert_true(saw_closed, "a blink shows the closed cell")
	# Suppressed (a take's hold): never closed.
	var s := FaceCards3D.new()
	s.setup(def, 7)
	s.suppressed = true
	var closed := false
	for i in 1200:
		s.update(1.0)
		closed = closed or s.cell_a.y == 10 or s.cell_a.y == 11
	assert_false(closed, "no blinks while suppressed")
	# Squint eyes are not blinkable.
	var q := FaceCards3D.new()
	q.setup(def, 7)
	q.set_face("sly")
	var shut := false
	for i in 1200:
		q.update(1.0)
		shut = shut or q.cell_a.y == 10
	assert_false(shut, "only blinkable eyes blink")


func test_body_slots_sneeze_sequence() -> void:
	var p := _player()
	assert_eq(p.body_slot("bouffant"), "neat")
	p.play("fix/rx_sneeze")
	p.set_external_frame(93.0)
	assert_eq(p.body_slot("bouffant"), "neat")
	p.set_external_frame(94.0)
	assert_eq(p.body_slot("bouffant"), "flipped", "the clip's look event at f 94")
	assert_eq(p.body_slot_owner("bouffant"), &"clip")
	assert_true((p._att_nodes["bouffant_flipped"] as Node3D).visible, "the flipped attachment shows")
	# A residue set during the clip does not override the clip's slot before its release.
	p.set_look("FRAZZLED", true)
	p.set_external_frame(120.0)
	assert_eq(p.body_slot("bouffant"), "flipped", "clip-owned until release")
	p.set_look("FRAZZLED", false)
	p.set_look("BLINDED", true)
	p.set_external_frame(165.0)
	assert_eq(p.body_slot("bouffant"), "flipped", "BLINDED keeps it flipped after release")
	assert_eq(p.body_slot_owner("bouffant"), &"residue", "now residue-owned")
	p.reset()
	p.set_look("BLINDED", false)
	assert_eq(p.body_slot("bouffant"), "neat", "reset + no residue → neat")
	assert_false((p._att_nodes["bouffant_flipped"] as Node3D).visible)
	allow_errors()
	p.set_body_slot("hat", "tall")
	p.set_body_slot("bouffant", "mohawk")


func test_looks_toggle_attachments_bones_and_params() -> void:
	var p := _player()
	var stool: Node3D = p._att_nodes["stool"]
	assert_false(stool.visible)
	# An attachment on a socket (Hush's carry_1 / carry_2) hangs on that socket's node from setup.
	if assert_true(p._att_nodes.has("badge"), "a socket attachment is built at setup"):
		var badge: Node3D = p._att_nodes["badge"]
		assert_true(badge.get_parent() == p.socket_node("brace_r"), "parented to the socket node")
		p.advance(0.0)
		await tree.process_frame
		var want := p.socket_global("brace_r").origin
		assert_true(badge.global_position.distance_to(want) < 0.03, "at the socket (%s vs %s)" % [badge.global_position, want])
	p.set_look("RIDE", true)
	assert_true(stool.visible)
	p.set_look("RIDE", false)
	assert_false(stool.visible)
	p.set_look("BALD", true)
	assert_has(p.mods.hidden_bones, p.skeleton.find_bone("beret"), "hide_bones scale the beret to 0")
	p.set_look("BALD", false)
	assert_eq(p.mods.hidden_bones.size(), 0)
	p.set_look("FRAZZLED", true)
	assert_has(p.mods.hidden_bones, p.skeleton.find_bone("sideburn_l"), "a slot variant's hide_bones")
	if p.material() != null:
		p.set_look("GREEN", true)
		assert_eq(p.material().get_shader_parameter("albedo_color"), Color("#80FF80"), "params set the uniform")
		p.set_look("GREEN", false)
		assert_ne(p.material().get_shader_parameter("albedo_color"), Color("#80FF80"), "and restore it")


func test_props_states_resolution_and_reset() -> void:
	var p := _player()
	var i: int = p._prop_index["cup"]
	assert_eq(p.prop_state("cup"), "held")
	assert_eq(p.mods.prop_mode[i], RigMods3D.MODE_HOME, "home socket: the clip drives the bone")
	p.set_prop("cup", "brace")
	assert_eq(p.mods.prop_mode[i], RigMods3D.MODE_SOCKET)
	assert_eq(p.mods.prop_sock_bone[i], p.skeleton.find_bone("spine_02"))
	p.set_prop("cup", "hidden")
	assert_eq(p.mods.prop_mode[i], RigMods3D.MODE_HIDDEN)
	assert_eq(p.prop_state("pepper_pot"), "hidden", "default hidden")
	# props first, then attachments: "stool" is an attachment.
	p.set_prop("stool", "shown")
	assert_true((p._att_nodes["stool"] as Node3D).visible)
	assert_eq(p.prop_state("stool"), "shown")
	p.reset()
	assert_eq(p.prop_state("cup"), "held", "reset restores the default state")
	assert_false((p._att_nodes["stool"] as Node3D).visible, "and drops forced attachments")
	allow_errors()
	p.set_prop("banana", "held")


## A prop moved to another socket keeps the clip's baked bone scale (Clarence's squeeze swell, r3d-fix-perf); a
## scale keyed at ≈ 0 (a hidden extra) still shows at 1, and the socket placement is unchanged.
func test_socket_mode_keeps_the_clips_baked_prop_scale() -> void:
	var p := _player()
	var sk := p.skeleton
	var i: int = p._prop_index["cup"]
	var b := sk.find_bone("prop_r")
	p.set_prop("cup", "brace")
	assert_eq(p.mods.prop_mode[i], RigMods3D.MODE_SOCKET)
	p.advance(0.0)
	var want := sk.get_bone_global_pose(p.mods.prop_sock_bone[i]) * p.mods.prop_sock_xf[i]
	sk.set_bone_pose_scale(b, Vector3(1.4, 1.25, 1.4))
	p.mods._process_modification_with_delta(0.0)
	var got := sk.get_bone_pose_scale(b)
	assert_true(got.is_equal_approx(Vector3(1.4, 1.25, 1.4)), "the keyed swell survives the socket move (%s)" % got)
	assert_true(sk.get_bone_global_pose(b).origin.distance_to(want.origin) < 0.001, "still on the brace socket")
	sk.set_bone_pose_scale(b, RigMods3D.TINY)
	p.mods._process_modification_with_delta(0.0)
	assert_true(sk.get_bone_pose_scale(b).is_equal_approx(Vector3.ONE), "a hidden-extra key (≈ 0) shows at 1")
	sk.set_bone_pose_scale(b, Vector3.ONE)
	p.mods._process_modification_with_delta(0.0)
	assert_true(sk.get_bone_pose_scale(b).is_equal_approx(Vector3.ONE), "an unkeyed bone stays at 1")


func test_launch_is_deterministic_and_reset_reattaches() -> void:
	var p := _player()
	p.play("fix/rx_take")
	var paths: Array = []
	for run in 2:
		p.reset()
		p.play("fix/rx_take")
		var pts: Array = []
		for f in [40.0, 50.0, 60.0, 80.0]:
			p.set_external_frame(f)
			p.advance(0.0)
			pts.append(p.mods.prop_world_xf[p._prop_index["cup"]].origin)
		paths.append(pts)
	assert_eq(p.prop_state("cup"), "flying")
	assert_eq(paths[0], paths[1], "same launch → same path (closed form, frame-locked)")
	var a: Vector3 = paths[0][1]
	var b: Vector3 = paths[0][2]
	assert_ne(a, b, "it moves")
	var land := PropSim3D.ballistic(Vector3(0, 1, 0), Vector3(1, 2, 0), 90.0, 10.0, 0.0)
	assert_almost_eq(land.y, 0.0, 0.0001, "comes to rest on the floor")
	p.reset()
	assert_eq(p.prop_state("cup"), "held", "reset re-attaches the launched prop")


func test_attach_detach_keep_world() -> void:
	var p := _player()
	p.global_position = Vector3(3, 0, -1)
	p.advance(0.0)
	var tag := Node3D.new()
	tree.root.add_child(tag)
	tag.global_position = Vector3(5, 1, 0)
	p.attach(tag, "grip_r")
	assert_true(tag.global_transform.origin.distance_to(p.socket_global("grip_r").origin) < 0.001, "snapped to the socket")
	var before := tag.global_transform
	p.detach(tag)
	assert_true(tag.global_transform.origin.distance_to(before.origin) < 0.0001, "detach keeps the world transform")
	assert_true(tag.get_parent() == p.get_parent())
	var t2 := Node3D.new()
	tree.root.add_child(t2)
	t2.global_position = Vector3(7, 2, 1)
	p.attach(t2, "grip_l", true)
	assert_true(t2.global_position.distance_to(Vector3(7, 2, 1)) < 0.0001, "keep_world")
	assert_true(p.socket_node("nope") == null)
	tag.queue_free()
	t2.queue_free()


func test_tint_and_stone_set_the_uniforms() -> void:
	var p := _player()
	if p.material() == null:
		skip("char_toon not built yet — r3d-view3d")
		return
	p.set_tint_tier(0)
	assert_eq((p.material().get_shader_parameter("tint_color") as Color).a, 0.0, "tier 0: no tint")
	p.set_tint_tier(3)
	var c: Color = p.material().get_shader_parameter("tint_color")
	assert_eq(c.a, 1.0)
	assert_almost_eq(c.r, Color("#E9B79A").r * Color("#F59A94").r, 0.002, "skin × the tier's multiply colour")
	assert_almost_eq(p.mods.scale_factor, 1.35, 0.0001, "sideburn bristle per tier")
	p.set_tint_tier(4)
	assert_eq(p.material().get_shader_parameter("tint_color"), Color("#B8324B"), "livid")
	p.set_stone(true, 0.1)
	for i in 3:
		p.advance(1.0 / 60.0)
	var mid := float(p.material().get_shader_parameter("stone"))
	assert_between(mid, 0.2, 0.8, "eased")
	for i in 6:
		p.advance(1.0 / 60.0)
	assert_eq(float(p.material().get_shader_parameter("stone")), 1.0, "marble in 0.1 s")
	p.set_stone(false, 0.0)
	assert_eq(float(p.material().get_shader_parameter("stone")), 0.0)


func test_overlay_masks_the_upper_body() -> void:
	var p := _player()
	p.play("fix/loco_walk")
	p.advance(1.0 / 60.0)
	p.play_overlay("fix/mg_wave", "upper", 0)
	for i in 12:
		p.advance(1.0 / 60.0)
	var arm := _pose_rot("upperarm_r")
	assert_true(_qeq(arm, _track_rot("fix/mg_wave", "upperarm_r", 12.0), 0.01), "the arm follows the overlay")
	var thigh := _pose_rot("thigh_l")
	var walk_thigh := _track_rot("fix/loco_walk", "thigh_l", 13.0)
	assert_true(_qeq(thigh, walk_thigh, 0.01), "the legs keep walking (the overlay's thigh key is masked out)")
	for i in 60:
		p.advance(1.0 / 60.0)
	assert_true(p._ov_clip == null, "a one-shot overlay ends and fades out")


func test_overlay_frame_lock() -> void:
	var p := _player()
	p.play("fix/loco_idle")
	p.play_overlay("fix/mg_wave", "upper", 6)
	p.set_overlay_frame(30.0)
	for i in 20:
		p.advance(1.0 / 60.0)
	assert_eq(p.current_overlay(), "fix/mg_wave")
	assert_almost_eq(p.current_overlay_frame(), 30.0, 0.0001, "a locked overlay does not run on the view clock")
	assert_true(_qeq(_pose_rot("upperarm_r"), _track_rot("fix/mg_wave", "upperarm_r", 30.0), 0.01),
		"frame 30 of the overlay, at full weight")
	p.set_overlay_frame(12.0)
	assert_true(_qeq(_pose_rot("upperarm_r"), _track_rot("fix/mg_wave", "upperarm_r", 12.0), 0.01), "seek back to 12")
	p.stop_overlay(0)
	assert_eq(p.current_overlay(), "", "stop unlocks and ends it")


func test_tier3_appends_the_last_beat_and_suppressed_plays_the_tail() -> void:
	var p := _player()
	var done: Array = []
	p.clip_finished.connect(func(id: String) -> void: done.append(id))
	p.play("fix/rx_take", {"tier": 3, "seed": 1})
	assert_eq(p.plan().length, 108)
	for i in 112:
		p.advance(1.0 / 60.0)
	assert_eq(done, ["fix/rx_take"])
	assert_eq(p.current_clip(), "fix/beat_slow_burn", "the T3 last beat follows the reaction")
	p.play("fix/rx_take", {"suppressed": true})
	p.set_external_frame(100.0)
	assert_eq(p.plan().clip_at(100.0).id, "fix/beat_suppressed")
	var want := _track_rot("fix/beat_suppressed", "Head", 31.0)
	for i in 12:
		p.set_external_frame(100.0)
		p.advance(1.0 / 60.0)
	assert_true(_qeq(_pose_rot("Head"), want, 0.001), "the suppressed tail's own frame (31) after its cross-fade")


func test_variant_warm_speed_and_face_overlay() -> void:
	var hb := RigPlayer3D.new()
	hb.auto_advance = false
	tree.root.add_child(hb)
	assert_true(hb.setup("fix", "head_b"), "the head_b variant sets up")
	assert_eq(hb.variant, "head_b")
	hb.get_parent().remove_child(hb)
	hb.free()
	var p := _player()
	p.warm()
	p.advance(1.0 / 60.0)
	assert_true((p._att_nodes["stool"] as Node3D).visible, "warm() shows every attachment for its frames")
	for i in 3:
		p.advance(1.0 / 60.0)
	assert_false((p._att_nodes["stool"] as Node3D).visible, "then restores them")
	p.play("fix/loco_walk")
	p.set_speed(2.4)
	var f0 := p.current_frame()
	p.advance(1.0)
	assert_almost_eq(fmod(p.current_frame() - f0 + 80.0, 80.0), fmod(120.0, 80.0), 0.01, "rate = 2.4 / 1.2 m/s")
	p.play_overlay("fix/mg_wave", "face", 0)
	p.advance(1.0 / 60.0)
	assert_eq(p.face.active_preset, "happy", "a face-mask overlay drives the face from its timeline")
