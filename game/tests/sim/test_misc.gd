## API coverage: path preview, bubble / hotspot_state / snapshot getters, wheeze, noises, knock_on_only,
## director gates, event_ago_ge_s, the Content autoload script.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func test_bellows_path_preview_samples_every_10_ticks() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["pickles"], "parlour", 1700, "hall", 600))
	U.run(w, 2)
	var pv := w.bellows_path_preview(90)
	assert_eq(pv.size(), 18, "9 samples of [room, x_sub]")
	assert_eq(pv[0], w.room_idx("parlour"))
	assert_eq(pv[1] - w.bellows.x_sub, 10 * 240, "10 ticks of walking")
	var still := U.world_patched("fx_act1", U.loop_patch(["tea"], "kitchen", 2900, "hall", 600))
	U.run(still, 5)
	var ps := still.bellows_path_preview(30)
	assert_eq(ps[1], still.bellows.x_sub, "performing: stays put")


func test_bubble_and_snapshot_getters() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "hall", 600))
	U.run(w, 5)
	var b := w.bubble()
	for k in ["next", "icon", "ring_ticks", "glyph", "ear_pips"]:
		assert_true(b.has(k), k)
	assert_eq(b["next"], "pickles")
	assert_eq(b["icon"], "res://art/icons/activities/pickles.svg")
	assert_eq(b["glyph"], "specs_off")
	assert_eq(w.bellows.detour, {})
	assert_eq(w.bellows.reacting, {})
	w.residue.add(w, "SOAKED", false)
	w.bellows.interrupt(w, false)
	w.bellows._start_next(w)
	assert_eq(w.bellows.detour, {"kind": "fixup_dry", "station": "st_fireplace"})
	assert_eq(w.hush.pin, {})


func test_hotspot_state_fields() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["clock", "tea"], "hall", 900, "kitchen", 3800))
	var hs := w.hotspot_state("kitchen_honey")
	for k in ["kind", "enabled", "stock", "occupant", "in_use_next", "spent", "rigged", "needs_item", "seen"]:
		assert_true(hs.has(k), k)
	assert_eq(hs["kind"], "rig_point")
	assert_true(hs["enabled"])
	assert_true(hs["seen"], "Hush starts in the kitchen")
	assert_false(w.hotspot_state("hall_mirror")["seen"], "never been to the hall")
	assert_false(w.hush_can_see("hall_mirror"))
	assert_true(w.hotspot_state("hall_clock_case")["in_use_next"])
	assert_eq(w.hotspot_state("hall_confiscated_box")["stock"], ["magnifier", "squeaker"], "sorted ids, this Night's items")
	U.force_rig(w, "achoo_ria")
	assert_true(w.hotspot_state("kitchen_honey")["rigged"])
	w.pranks.state[w.db.prank_idx("achoo_ria")] = Pranks.LANDED
	assert_true(w.hotspot_state("kitchen_honey")["spent"])
	assert_eq(w.hotspot_state("nope"), {})


func test_wheeze_counts_as_one_squeak_and_moves_while_held() -> void:
	var w := U.quiet_world()
	U.step(w, [SimCmd.freeze(true)])
	var e := U.step(w, [SimCmd.wheeze(true)])
	assert_eq(U.find(e, SimEvents.SQUEAK).size(), 1)
	U.run(w, 60)
	assert_true(w.hush.is_moving(w.tick), "wheezing: the arm moves")
	U.step(w, [SimCmd.wheeze(false)])
	U.run(w, SimConst.SQUEAK_ARM_TICKS)
	assert_false(w.hush.is_moving(w.tick))


func test_b_rig_noise_makes_him_curious() -> void:
	# tea turned to face the parlour; Hush rigs a B-tier pickle jar 230 px behind him
	var w := U.world_patched("fx_act1", U.loop_patch(["tea"], "kitchen", 2900, "kitchen", 3700), {}, func(f: Dictionary) -> void:
		f["pranks"]["pranks"]["in_a_pickle"]["steps"] = [{"prep": "B", "needs": null}]
		f["activities"]["activities"]["tea"]["facing"] = -1)
	U.run(w, 5)
	U.place_hush_at(w, "kitchen_pickle_jar")
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.rig(true)]))
	log.append_array(U.run(w, 3))
	assert_false(U.first(log, SimEvents.NOISE, {"kind": "rig"}).is_empty())
	var det := U.first(log, SimEvents.B_DETOUR, {"kind": "curious"})
	assert_false(det.is_empty(), "a big rig within 500 px")
	assert_eq(str(det.get("why", "")), "noise")


func test_running_noise_heard_within_500px() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["pickles"], "kitchen", 3130, "kitchen", 3400))
	U.run(w, 5)
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.move("kitchen", 3600, true)]))
	log.append_array(U.run(w, 3))
	assert_false(U.first(log, SimEvents.NOISE, {"kind": "run"}).is_empty())
	assert_false(U.first(log, SimEvents.B_DETOUR, {"kind": "curious", "why": "noise"}).is_empty())
	var w2 := U.world_patched("fx_act1", U.loop_patch(["pickles"], "kitchen", 3130, "parlour", 1600))
	U.run(w2, 5)
	var log2: Array = []
	log2.append_array(U.step(w2, [SimCmd.move("parlour", 1520, true)]))
	log2.append_array(U.run(w2, 20))
	assert_true(U.first(log2, SimEvents.B_DETOUR).is_empty(), "1500 px away: not heard")


func test_knock_on_only_prank_fires_via_its_double_act() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["pickles", "tea"], "kitchen", 3130, "hall", 600), {}, func(f: Dictionary) -> void:
		(f["episodes"]["fx_act1"]["script"] as Array).append({"id": "cold", "kind": "prank", "prank": "cold_open", "req": false}))
	U.force_rig(w, "in_a_pickle")
	U.force_rig(w, "cold_open")
	var log := U.run(w, 800)
	var f := U.first(log, SimEvents.PRANK_FIRE, {"prank": "cold_open"})
	assert_eq(str(f.get("trigger", "")), "knock_on")
	assert_eq(w.pranks.da_done[w.db.double_acts["encore"].idx], 1)
	var w2 := U.world_patched("fx_act1", U.loop_patch(["pickles", "tea"], "kitchen", 3130, "hall", 600), {}, func(f2: Dictionary) -> void:
		(f2["episodes"]["fx_act1"]["script"] as Array).append({"id": "cold", "kind": "prank", "prank": "cold_open", "req": false}))
	U.force_rig(w2, "cold_open")
	var log2 := U.run(w2, 3000)
	assert_true(U.first(log2, SimEvents.PRANK_FIRE, {"prank": "cold_open"}).is_empty(), "never on its own")


func test_director_gates_merge_into_the_loop() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		ep["bellows"]["loop"] = [{"a": "tea"}, {"a": "pickles"}]
		ep["bellows"]["start"] = {"room": "kitchen", "x": 2900}
		ep["hush"]["start"] = {"room": "hall", "x": 600}
		ep["director"] = {"gates": [{"loop": 0, "until": "first_squeak", "max_s": 3}]})
	assert_true(w.episode.loop[0].has_gate)
	var log := U.run(w, 400)
	var st := U.first(log, SimEvents.B_ACTIVITY, {"id": "tea"})
	var en := U.first(log, SimEvents.B_ACTIVITY_END, {"id": "tea"})
	assert_eq(int(en["t"]) - int(st["t"]), 180, "gated by the director: 3 s cap")


func test_event_ago_condition() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea"], "kitchen", 2900, "hall", 600))
	U.run(w, 10)
	var c := {"event_ago_ge_s": ["b_activity", {"id": "tea"}, 1]}
	assert_false(Conditions.eval(w, c))
	U.run(w, 60)
	assert_true(Conditions.eval(w, c))
	assert_eq(Conditions.validate(c), PackedStringArray())


func test_content_autoload_script() -> void:
	var s: Script = load("res://autoload/content.gd")
	var node: Node = s.new()
	var db: ContentDB = node.load_db(SimTestUtil.FIXTURES)
	assert_true(db.ok())
	assert_true(node.ok())
	node.free()
