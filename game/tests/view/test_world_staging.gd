## WorldView staging on the FakeWorld timeline with the real rigs + fixture clips (s2-view brief
## §4.1.6–§4.2.15): fallback counts, hotspot rects with stacks, the entry-warning lead, clip
## `decor` events (never two stools), director-cue staging + `cue_staged`, the vase creep and
## smash, the caught phases (Lecture attach, wipe, doorstep), tap feedback (queued → path,
## rejected → grey), pre-roll leaves the sim at tick 0, the MomentRecorder ring and pool.
extends TestBase

const DT := 1.0 / 60.0
const FIX := preload("res://tests/view/view_fixtures.gd")

var _sb: ViewSandbox = null
var _staged: Array = []


func before_each() -> void:
	FIX.install(true)
	_staged.clear()
	_sb = ViewSandbox.new()
	_sb.scenario = "full"
	tree.root.add_child(_sb)
	await tree.process_frame
	_sb.set_process(false)
	_sb.world_view.cue_staged.connect(func(id: String, kind: String) -> void: _staged.append([id, kind]))


func after_each() -> void:
	_sb.queue_free()
	FIX.uninstall()
	await tree.process_frame


func _until_tick(t: int, max_frames: int = 6000) -> void:
	var n := 0
	while _sb.driver.snapshot().tick < t and n < max_frames:
		_sb._process(DT)
		n += 1


func _frames(n: int) -> void:
	for i in n:
		_sb._process(DT)


func test_fallback_counts_shape_and_real_rigs() -> void:
	_frames(5)
	var c := _sb.world_view.fallback_counts()
	for k in ["clip_fallbacks", "puppets", "greybox_props", "by_clip"]:
		assert_has(c, k)
	assert_eq(int(c["puppets"]), 0, "both rigs load: no puppets")
	assert_true(_sb.world_view.hush_view.uses_rig and _sb.world_view.bellows_view.uses_rig)
	assert_eq(int(c["greybox_props"]), 0, "every slice-room prop has art")


func test_hotspot_rects_carry_enabled_and_stack() -> void:
	_frames(3)
	var rects := _sb.world_view.hotspot_rects_in_view()
	assert_gt(rects.size(), 0)
	var stacked := 0
	for r in rects:
		assert_has(r, "enabled")
		assert_has(r, "stack")
		if String(r["stack"]) != "":
			stacked += 1
	assert_gt(stacked, 0, "kitchen hotspots in a house.json stack carry its ids")
	assert_eq(_sb.world_view.layout.stack_of("kitchen_fridge"), "kitchen_fridge+kitchen_fridge_shelf")


func test_entry_warning_lead_is_eta_plus_the_doorway_pause() -> void:
	assert_eq(WorldView.entry_lead(90, {}), 90)
	assert_eq(WorldView.entry_lead(40, {}), 90, "eta 40 + a 50-tick doorway pause")
	assert_eq(WorldView.entry_lead(40, {"pause": 50}), 90)
	assert_eq(WorldView.entry_lead(30, {"doorway_pause": 60}), 90)


func test_decor_event_hides_the_stool_until_the_clip_is_over() -> void:
	_frames(2)
	var wv := _sb.world_view
	assert_true(wv.decor.is_visible("kitchen_stool"))
	wv._on_clip_event({"type": "decor", "id": "kitchen_stool", "visible": false, "actor": "bellows", "clip": wv.bellows_view.current_clip()})
	assert_false(wv.decor.is_visible("kitchen_stool"), "the clip carries the stool: the house stool hides")
	# The forcing clip stays current while he performs the same activity; once his clip changes
	# (and he is not reacting) the house stool comes back.
	wv.bellows_view._clip = "bellows/some_other_clip"
	wv.decor.release_clip_overrides(wv._still_forcing)
	assert_true(wv.decor.is_visible("kitchen_stool"), "restored: never zero, never two stools")


func test_sink_lip_decor_is_drawn_over_the_characters() -> void:
	var wv := _sb.world_view
	var s := wv.decor.sprite("kitchen_sink_lip")
	assert_true(s != null)
	assert_false(s.visible, "hidden until an event shows it")
	assert_gt(s.get_parent().z_index, wv.chars_node.z_index, "z 2 → over the characters")
	var back := wv.decor.sprite("parlour_fire")
	if back != null:
		assert_lt(back.get_parent().z_index, wv.props_node.z_index, "z −1 → behind the props")


func test_decor_frames_animate() -> void:
	var wv := _sb.world_view
	var s := wv.decor.sprite("parlour_fire")
	if s == null:
		skip("no parlour_fire decor")
		return
	var seen := {}
	for i in 40:
		wv.decor.advance(1.0 / 60.0)
		seen[s.texture] = true
	assert_ge(seen.size(), 2, "frames + fps animate")


func test_doorframe_cue_is_staged_with_stars_and_his_overlay() -> void:
	_until_tick(967)
	_until_tick(970)
	var ids := []
	for s in _staged:
		ids.append(s[0])
	assert_has(ids, "laugh_doorframe")
	assert_gt(_sb.world_view.fx.stars.active_count(), 0, "stars at the parlour_kitchen frame")
	assert_eq(_sb.world_view.bellows_view.ctx.cue, "laugh_doorframe", "his cue overlay is staged")
	assert_eq(_sb.world_view.bellows_view.pick().ov_key, "cue:laugh_doorframe")


func test_vase_creeps_on_warmup_notes_then_tips_and_smashes() -> void:
	var cs := _sb.world_view.cues
	assert_eq(CueStager.creep_step(0), 10.0)
	assert_eq(CueStager.creep_step(1), 14.0)
	var before := cs.vase_px
	cs.on_clip_event({"type": "voice", "actor": "bellows", "clip": "bellows/act_warmup"})
	assert_gt(cs.vase_px, before, "a warm-up note nudges the vase")
	var snap := _sb.driver.snapshot()
	cs.on_event({"e": "director_cue", "id": "laugh_vase"}, snap)
	assert_eq(cs.vase_phase(), "tip")
	for i in 20:
		cs.advance(snap, 1.0 / 60.0)
	assert_eq(cs.vase_phase(), "smashed")
	assert_false(_sb.world_view.decor.is_visible("parlour_vase"))
	assert_true(_sb.world_view.decor.is_visible("parlour_vase_smashed"), "shards on the floor")
	assert_eq(_staged[_staged.size() - 1], ["laugh_vase", "prop"])


func test_picture_drops_hangs_and_falls_off() -> void:
	var cs := _sb.world_view.cues
	var snap := _sb.driver.snapshot()
	cs.on_event({"e": "director_cue", "id": "laugh_picture"}, snap)
	assert_eq(cs.picture_phase(), "drop")
	assert_eq(_sb.world_view.decor.state_of("parlour_picture_frame"), "falling")
	for i in 14:
		cs.advance(snap, 1.0 / 60.0)
	assert_eq(cs.picture_phase(), "hang", "12 f onto his head, then round his neck")
	for i2 in 90:
		cs.advance(snap, 1.0 / 60.0)
	assert_eq(cs.picture_phase(), "gone")


func test_caught_phases_attach_wipe_and_doorstep() -> void:
	_until_tick(2552)
	assert_eq(_sb.world_view.caught.phase, "grab")
	assert_true(_sb.world_view.is_replaying(), "0–60: the Busted Cam re-stage")
	_until_tick(2640)
	var cs := _sb.world_view.caught
	assert_eq(cs.phase, "lecture")
	var hv := _sb.world_view.hush_view
	var bv := _sb.world_view.bellows_view
	assert_true(hv.pick().attach, "Hush's lecture row attaches her")
	assert_eq(hv.current_clip(), "hush/fx_dangled")
	assert_eq(bv.current_clip(), "bellows/fx_lec_a", "variant 0 → lec_a")
	var grip := bv.socket_transform("hand_r:grip").origin
	var braces := hv.socket_transform("torso:braces").origin
	assert_lt(grip.distance_to(braces), 2.0, "her braces hang from his grip socket")
	_until_tick(2745)
	assert_eq(cs.phase, "wipe")
	_until_tick(2760)
	assert_eq(cs.phase, "doorstep")
	assert_eq(hv.current_clip(), "hush/fx_doorstep")


func test_queued_tap_marker_then_path() -> void:
	var wv := _sb.world_view
	wv.tap_feedback(Vector2(2950, -40))
	wv.on_ticked([{"e": "cmd_queued", "c": "go", "why": "entering", "target": "kitchen_honey"}])
	assert_true(wv.fx.is_queued(), "a held tap shows the pulsing … marker")
	wv.on_ticked([{"e": "hush_go", "target": "kitchen_honey", "run": false}])
	assert_false(wv.fx.is_queued(), "the command ran: the marker settles and the path draws")
	assert_eq(wv.target_point("kitchen:1200"), Vector2(1200, 0))


func test_rejected_tap_is_a_grey_ripple_and_a_shrug_without_haptics() -> void:
	var wv := _sb.world_view
	wv.tap_feedback(Vector2(2950, -40))
	wv.on_ticked([{"e": "cmd_rejected", "c": "go", "why": "locked"}])
	assert_eq(wv.hush_view._ov_flavour_pending, "shrug")
	assert_eq(HapticsDirector.pulse_for({"e": "cmd_rejected"}), &"")


func test_preroll_moves_clips_but_never_the_sim() -> void:
	var sb := ViewSandbox.new()
	sb.scenario = "full"
	tree.root.add_child(sb)
	await tree.process_frame
	sb.set_process(false)
	var wv := sb.world_view
	var t0 := int(sb.world.get("tick"))
	wv.preroll(0.0)
	var f0 := wv.bellows_view.current_frame()
	for i in 30:
		wv.preroll(1.0 / 60.0)
	assert_eq(int(sb.world.get("tick")), t0, "pre-roll never steps the sim")
	assert_ne(wv.bellows_view.current_frame(), f0, "his warm-up clip advanced")
	assert_almost_eq(wv.cues.vase_px, 0.0, 0.001, "never the vase")
	sb.queue_free()


func test_moment_recorder_ring_windows_and_pool() -> void:
	var rec := _sb.world_view.recorder
	_until_tick(500)
	assert_eq(rec.count(), MomentRecorder.CAP, "the ring is full (≥ 6 s)")
	var last := rec.last_tick()
	var id := rec.keep(last - 100, last - 40, "gag:test", 50)
	var m := rec.moment(id)
	assert_true(m != null)
	assert_ge(m.count(), 61, "one frame per drawn frame (≥ one per tick)")
	assert_eq(m.frame(0).tick, last - 100)
	assert_eq(m.frame(m.count() - 1).tick, last - 40)
	assert_false(m.open)
	assert_true(m.frame(0).bellows.clip != "", "clips recorded per frame")
	# An open window keeps filling.
	var id2 := rec.keep(last - 10, last + 20, "open", 10)
	assert_true(rec.moment(id2).open)
	_frames(40)
	assert_false(rec.moment(id2).open)
	assert_ge(rec.moment(id2).count(), 31)
	assert_eq(rec.moment(id2).frame_at_tick(last + 20).tick, last + 20)
	# Pool of 8: the lowest applause is evicted.
	for k in 8:
		rec.keep(last - 50, last - 40, "k%d" % k, 100 + k)
	assert_eq(rec.kept(), 8)
	var lowest_gone := true
	for j in 8:
		var mm := rec.moment(j)
		if mm != null and mm.tag == "open":
			lowest_gone = false
	assert_true(lowest_gone, "the lowest-applause moment was evicted")


func test_moment_restages_the_same_pose_as_live() -> void:
	_until_tick(700)
	var rec := _sb.world_view.recorder
	var bv := _sb.world_view.bellows_view
	var live_clip := bv.current_clip()
	var live_frame := bv.current_frame()
	var t := rec.last_tick()
	var id := rec.keep(t, t, "now", 1)
	var f := rec.moment(id).frame(0)
	assert_eq(f.bellows.clip, live_clip)
	assert_almost_eq(f.bellows.frame, live_frame, 0.001)
	var cv := CharacterView.new()
	cv.layout = _sb.world_view.layout
	tree.root.add_child(cv)
	cv.setup("bellows")
	cv.show_explicit(f.bellows.pos, f.bellows.facing, f.bellows.clip, f.bellows.frame, true, f.bellows.looks, f.bellows.tint)
	assert_eq(cv.current_clip(), live_clip, "the reel's frame 0 is the live clip")
	assert_almost_eq(cv.current_frame(), live_frame, 0.001, "on the live frame")
	cv.queue_free()


func test_backdrop_builds_a_room_with_its_props() -> void:
	var bd := RoomView.build_backdrop(_sb.world_view.layout, "kitchen", {"kitchen_honey": "rigged"}, {"kitchen_stool": false})
	assert_gt(bd.get_child_count(), 3)
	var found := false
	for c in bd.get_children():
		for g in (c as Node).get_children():
			if g is PropView and (g as PropView).hotspot.id == "kitchen_honey":
				found = (g as PropView).state == "rigged"
	assert_true(found, "the honey jar in its moment state")
	bd.free()


func test_reveal_sparkle_glow_and_cane() -> void:
	var wv := _sb.world_view
	wv.reveal_badges(true)
	assert_true(wv.fx.badges.revealing(), "long-press reveal shows every badge in view")
	wv.reveal_badges(false)
	assert_false(wv.fx.badges.revealing())
	wv.sparkle("parlour_gramophone", 1.0)
	wv.fx.particles.clear()
	for i in 30:
		wv.advance(1.0 / 60.0)
	assert_gt(wv.fx.particles.active_emitters(), 0, "FTUE sparkles on the hotspot")
	assert_false(wv.decor.is_visible("hall_front_door_glow"))
	wv.on_ticked([{"e": "all_lines_done"}])
	assert_true(wv.decor.is_visible("hall_front_door_glow"), "the front door glows once every line is done")
	wv.on_ticked([{"e": "figgis_hook"}])
	assert_true(wv.fx.cane_fx.active(), "Figgis's cane sweeps in")


func test_clip_events_route_prop_fall_and_spring() -> void:
	var wv := _sb.world_view
	var before := wv.fx.props.active_count() if wv.fx.props.has_method("active_count") else -1
	wv._on_clip_event({"type": "prop", "op": "fall", "tier": 3, "prop": "vase", "actor": "bellows"})
	if before >= 0:
		assert_gt(wv.fx.props.active_count(), before, "the T3 prop falls on his head")
	wv._on_clip_event({"type": "spring", "id": "kitchen_stool", "actor": "bellows"})
	wv.decor.advance(0.1)
	assert_ne(wv.decor.sprite("kitchen_stool").rotation, 0.0, "a spring event rocks the decor")
