## WorldView3D on the real sim (brief r3d-view3d §5): the P00 ideal route through the full 3D view stack
## (SimDriver → WorldView3D → CameraDirector3D → PipView3D, fixed 1/60 s steps) — room light levels incl. the dark
## hall at 0.9 while Bellows fixes his hair in it, his stage_light ≥ 0.9, Hush at the reach depth with the body cheat
## ≤ 10° while rigging, the armed look after the rig, the hotspot rects at base framing, the window share; and the
## g0 sneeze travel: his pelvis inside house3d.json's kitchen.sink landing box on reaction frame 112.
## Other tasks' pieces (House3D, RigPlayer3D, the cast data) are soft: their in-flight engine errors are allowed.
extends TestBase

const DT := 1.0 / 60.0
const CMDS := "res://tests/view/fixtures/cmds"

var _root: Node3D = null
var _driver: SimDriver = null
var _cam: CameraDirector3D = null
var _wv: WorldView3D = null
var _pip: PipView3D = null
var _vt := 0.0


func before_each() -> void:
	allow_errors()


func after_each() -> void:
	if _root != null:
		_root.queue_free()
		_root = null
	await tree.process_frame


func _build(episode: String, window_mode: String = "") -> bool:
	var db := ContentDB.load_dir("res://data")
	var w := SimWorld.create(db, episode, {})
	if w == null:
		return false
	_root = Node3D.new()
	tree.root.add_child(_root)
	_driver = SimDriver.new()
	_root.add_child(_driver)
	_driver.setup(w)
	var cmds: Variant = load_json("%s/%s_ideal.cmds.json" % [CMDS, episode])
	if cmds is Dictionary:
		_driver.set_script_cmds(cmds)
	_cam = CameraDirector3D.new()
	_cam.time_source = _driver
	_cam.logical_size_override = View3DConst.logical_size("20x9")
	_root.add_child(_cam)
	_wv = WorldView3D.new()
	_wv.cam = _cam
	_root.add_child(_wv)
	_wv.setup(null, null, _driver)
	if window_mode != "":
		_wv.window_mode = window_mode
	_cam.follow(_wv.hush_view, func() -> float: return float(_driver.snapshot().hush.facing) if _driver.snapshot().hush.moving else 0.0)
	_cam.set_other(_wv.bellows_view)
	_pip = PipView3D.new()
	_root.add_child(_pip)
	_pip.setup(_wv, _cam)
	_wv.pip = _pip
	for n in [_driver, _driver.juice, _wv, _cam, _pip]:
		(n as Node).set_process(false)
	_vt = 0.0
	_driver.juice.test_now_us = 0
	_step()
	_cam.snap_now()
	return true


func _step() -> void:
	_vt += DT
	_driver.juice.test_now_us = int(_vt * 1000000.0)
	_driver.juice.advance()
	_driver.advance(DT)
	_wv.advance(DT)
	_cam.advance(_driver.view_delta(), DT)
	_pip.advance(DT)


func test_p00_route_lights_reach_tags_and_hit_rects() -> void:
	if not _build("p00_curtain_up"):
		skip("p00_curtain_up did not load")
		return
	var hall_run := 0
	var hall_min := 9.0
	var bellows_min := 9.0
	var rig_frames := 0
	var rig_run := 0
	var rig_z_of := {}
	var rig_z_max := -9.0
	var rig_z_min := 9.0
	var rig_cheat_max := 0.0
	var armed_seen := false
	var staged: Array = []
	_wv.cue_staged.connect(func(id: String, kind: String) -> void: staged.append("%s:%s" % [id, kind]))
	var rects_checked := false
	var rect_min := 9999.0
	var rect_ids := PackedStringArray()
	var frames := 0
	var obj0 := -1
	var node0 := -1
	var obj1 := -1
	var node1 := -1
	var shot_kinds := PackedStringArray()
	var pin_max := 0.0
	while not _driver.snapshot().ended and frames < 4200:
		_step()
		frames += 1
		var s := _driver.snapshot()
		# r3d-fix-gags: the cue shots that put each small gag on screen, and the door-frame knock-back
		var sk := _wv.cues.shot_kind()
		if sk != "" and not shot_kinds.has(sk):
			shot_kinds.append(sk)
		pin_max = maxf(pin_max, absf(_wv.bellows_view.pin_offset()))
		# no per-frame allocation: object / node counts flat over 10 s of PLAY (ticks 2400…3000: the second rig,
		# the piano hide, his exits and entries)
		if s.tick == 2400:
			obj0 = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			node0 = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		elif s.tick == 3000:
			obj1 = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			node1 = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		bellows_min = minf(bellows_min, _wv.bellows_view.stage_level)
		# the dark hall with Bellows in it (his FRAZZLED mirror fix-up) — after the 0.4 s ease
		if s.bellows.present and s.bellows.room == "hall" and s.hush.room != "hall":
			hall_run += 1
			if hall_run > 30:
				hall_min = minf(hall_min, _wv.room_level("hall"))
		else:
			hall_run = 0
		if s.hush.state == "RIGGING":
			rig_frames += 1
			rig_run += 1
			if rig_run > 20:   # after the 0.3 s ease to reach_pos
				rig_z_max = maxf(rig_z_max, _wv.hush_view.lane_z())
				rig_z_min = minf(rig_z_min, _wv.hush_view.lane_z())
				rig_cheat_max = maxf(rig_cheat_max, _wv.hush_view.cheat_deg())
				rig_z_of[s.hush.rig_prank] = _wv.hush_view.lane_z()
		else:
			rig_run = 0
		var honey := _wv.prop("kitchen_honey")
		if honey != null and honey.get_meta("mnd_state", &"") == &"armed":
			armed_seen = true
		# hit rects at base framing while she sneaks the kitchen (before the first rig)
		if not rects_checked and s.tick >= 300 and s.hush.room == "kitchen" and not (_wv.set3d is GreyboxSet3D):
			rects_checked = true
			for r in _wv.hotspot_rects_in_view():
				if str(r["room"]) == "kitchen" and str(r["kind"]) != "floor" and int(r["priority"]) == 2 and bool(r["enabled"]):
					var rr: Rect2 = r["rect"]
					rect_min = minf(rect_min, minf(rr.size.x, rr.size.y))
					rect_ids.append("%s %.0fx%.0f" % [r["id"], rr.size.x, rr.size.y])
	assert_true(_driver.snapshot().ended, "the Night ends (%d frames)" % frames)
	print("[test_world_view3d] P00 objects %d -> %d, nodes %d -> %d (ticks 2400 -> 3000)" % [obj0, obj1, node0, node1])
	if obj0 >= 0 and obj1 >= 0:
		assert_eq(node1, node0, "no nodes created during PLAY")
		assert_le(obj1 - obj0, 16, "objects flat during PLAY (pools)")
	assert_ge(bellows_min, 0.9, "his stage_light never below 0.9")
	if hall_min < 9.0:
		assert_ge(hall_min, 0.89, "the backstage hall is lit 0.9 while Bellows is in it")
	else:
		skip("P00's route never put Bellows alone in the hall")
	print("[test_world_view3d] P00 reach z per rig %s" % JSON.stringify(rig_z_of))
	assert_gt(rig_frames, 0, "she rigs")
	assert_le(rig_z_max, View3DConst.LANE_Z - 0.2, "rigging: deeper than the lane (reach_pos)")
	assert_ge(rig_z_min, View3DConst.REACH_Z_MIN - 1e-4, "never deeper than −1.6")
	assert_le(rig_cheat_max, View3DConst.CHEAT_REACH_MAX + 1e-4, "body cheat ≤ 10° while reaching")
	if _wv.prop("kitchen_honey") != null:
		assert_true(armed_seen, "the honey jar takes the armed look after the rig")
	if rects_checked:
		print("[test_world_view3d] P00 kitchen hit rects: %s" % ", ".join(rect_ids))
		assert_gt(rect_ids.size(), 0, "kitchen props on screen")
		assert_ge(rect_min, 144.0, "every kitchen prop's hit rect ≥ 144 px at base framing")
	# the Prologue's director cues are staged in the set; the ring kept recording
	print("[test_world_view3d] P00 cues staged: %s" % ", ".join(PackedStringArray(staged)))
	var ids := PackedStringArray()
	for e in staged:
		ids.append(str(e).get_slice(":", 0))
	assert_has(ids, "laugh_vase", "the vase cue is staged")
	if _wv.set3d != null and _wv.set3d.has_method("decor") and _wv.set3d.call("decor", "parlour_vase") != null:
		assert_has(staged, "laugh_vase:prop")
		assert_eq(_wv.cues.vase_phase(), "smashed", "the vase ended on the floor")
		assert_gt(_wv.cues.nudges, 0, "it crept along the mantel first")
	print("[test_world_view3d] P00 cue shots %s, door-frame knock-back %.2f m" % [", ".join(shot_kinds), pin_max])
	for k in ["establish", "bonk", "relief", "picture"]:
		assert_has(shot_kinds, k, "the %s cue shot framed its gag" % k)
	assert_gt(pin_max, 0.2, "he stops dead at the door frame (the view pins him off it)")
	assert_almost_eq(_wv.bellows_view.pin_offset(), 0.0, 0.01, "and catches up with the sim afterwards")
	assert_eq(_wv.recorder.count(), MomentRecorder3D.CAP, "the ring is full after a Night")
	assert_eq(_wv.recorder.last_tick(), _driver.snapshot().tick, "the ring records every frame")
	var fc := _wv.fallback_counts()
	print("[test_world_view3d] P00 fallbacks %s | window share %s" % [JSON.stringify(fc), JSON.stringify(_pip.share())])
	if _wv.hush_view.uses_rig and _wv.bellows_view.uses_rig:
		assert_eq(int(fc["puppets"]), 0, "both rigs: no puppets")


func test_g0_sneeze_lands_his_pelvis_in_the_sink_on_frame_112() -> void:
	if not _build("g0_sneeze"):
		skip("g0_sneeze did not load")
		return
	var h3: Variant = load_json("res://data/house/house3d.json")
	var land: Variant = (((h3 as Dictionary).get("landings", {}) as Dictionary).get("kitchen", {}) as Dictionary).get("sink", null) \
			if h3 is Dictionary else null
	if not (land is Dictionary) or not (land as Dictionary).has("box"):
		skip("house3d.json has no kitchen.sink landing box")
		return
	var bx: Array = (land as Dictionary)["box"]
	var box := AABB(Vector3(float(bx[0]), float(bx[1]), float(bx[2])),
		Vector3(float(bx[3]) - float(bx[0]), float(bx[4]) - float(bx[1]), float(bx[5]) - float(bx[2])))
	var frames := 0
	var found := false
	while not _driver.snapshot().ended and frames < 3000:
		_step()
		frames += 1
		var b := _driver.snapshot().bellows
		if b.reacting and b.react_prank == "achoo_ria" and b.react_t >= 112:
			found = true
			break
	if not found:
		skip("no achoo_ria reaction reached frame 112 on the g0 route")
		return
	var bv := _wv.bellows_view
	var pelvis := bv.socket_world("seat").origin if bv.uses_rig else bv.feet_world() + Vector3(0.0, 0.35, 0.0)
	if bv.uses_rig and pelvis.distance_to(bv.feet_world()) < 0.05:
		pelvis = bv.feet_world() + Vector3(0.0, 0.35, 0.0)   # no "seat" socket on this rig version
	print("[test_world_view3d] sneeze f112 at tick %d (reaction from tick %d): pelvis %s landing box %s" % [
		_driver.snapshot().tick, _driver.snapshot().tick - _driver.snapshot().bellows.react_t, pelvis, box])
	assert_true(box.grow(0.05).has_point(pelvis), "pelvis %s inside kitchen.sink %s on f112" % [pelvis, box])
	assert_almost_eq(bv.lane_z(), float((land as Dictionary).get("z", -2.1)), 0.05, "landed at the sink's depth")


func test_c8_on_every_tick_of_the_g0_and_p00_routes_in_both_window_modes() -> void:
	# C8: never while he is on screen; open at once when the sim may show him off screen (lean: not for adjacency
	# alone unless he is busy — the edge badge instead); closed within the 1.5 s hide delay after the want clears.
	var hide_frames := int(ceil(PipView3D.HIDE_DELAY_S * 60.0)) + 1
	var report := PackedStringArray()
	for ep in ["g0_sneeze", "p00_curtain_up"]:
		for mode in ["sim", "lean"]:
			if _root != null:
				_root.free()
				_root = null
			if not _build(ep, mode):
				skip("%s did not load" % ep)
				return
			_pip.reset_share()
			var on_screen_open := 0
			var missed := 0
			var late_close := 0
			var badge_frames := 0
			var since_want := 9999
			var frames := 0
			while not _driver.snapshot().ended and frames < 9000:
				_step()
				frames += 1
				var v := _wv.visibility_sample()
				var s := _driver.snapshot()
				var reason: StringName = v["reason"]
				var want := PipView3D.want_window(bool(v["on_screen"]), reason != &"", reason, mode == "lean",
					PipView3D.is_busy(s, _wv.bellows_view))
				since_want = 0 if want else since_want + 1
				if bool(v["window"]) and bool(v["on_screen"]) and not _pip.is_escalated():
					on_screen_open += 1
				if want and not bool(v["window"]):
					missed += 1
				if bool(v["window"]) and since_want > hide_frames and not _pip.is_escalated():
					late_close += 1
				if bool(v["badge"]):
					badge_frames += 1
					if mode == "sim":
						late_close += 1000   # the badge belongs to the lean mode only
			var sh := _pip.share()
			report.append("%s %s: %d ticks, window %.1f %% (longest %.1f s), badge %d frames" % [ep, mode, frames,
				100.0 * float(sh["pip_on_share"]), float(sh["pip_longest_s"]), badge_frames])
			assert_eq(on_screen_open, 0, "%s %s: never while he is on screen" % [ep, mode])
			assert_eq(missed, 0, "%s %s: opens at once when C8 wants it" % [ep, mode])
			assert_eq(late_close, 0, "%s %s: closes within the hide delay" % [ep, mode])
	for line in report:
		print("[test_world_view3d] C8 / pip_on_share: " + line)
