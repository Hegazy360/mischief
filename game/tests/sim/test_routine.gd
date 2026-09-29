## Routine: loop order, gates, detours before the next activity, bubble ring, b_next timing, nerves.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _acts(log: Array) -> Array:
	var out: Array = []
	for ev in U.find(log, SimEvents.B_ACTIVITY):
		out.append(str(ev["id"]))
	return out


func test_loop_order_and_wrap() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles", "rinse"], "kitchen", 2900, "hall", 600))
	var log := U.run(w, 6000)
	var acts := _acts(log)
	assert_eq(acts.slice(0, 7), ["tea", "pickles", "rinse", "tea", "pickles", "rinse", "tea"])
	assert_gt(w.routine.loop_count, 1)


func test_first_loop_gate_max_25s_without_a_rig() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		ep["hush"]["start"] = {"room": "hall", "x": 600})
	var log := U.run(w, 3000)
	var start: int = U.first(log, SimEvents.B_ACTIVITY, {"id": "warmup"})["t"]
	var end: int = U.first(log, SimEvents.B_ACTIVITY_END, {"id": "warmup"})["t"]
	assert_eq(end - start, 1500)


func test_first_loop_gate_ends_2s_after_first_rig() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		ep["hush"]["start"] = {"room": "kitchen", "x": 3800})
	var log: Array = []
	U.walk_to(w, "kitchen_honey", 600, log)
	U.rig_hold(w, 100, log)
	var rigged: int = U.first(log, SimEvents.RIGGED)["t"]
	var ev := U.run_until(w, SimEvents.B_ACTIVITY_END, {"id": "warmup"}, 400, log)
	assert_eq(int(ev["t"]) - rigged, 120, "the gate is met the tick of the rig (Hush updates before Bellows), +2 s")


func test_gate_applies_to_first_loop_only() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch([{"a": "warmup", "gate": {"until": "first_rig", "plus_s": 2, "max_s": 25, "first_loop_only": true}}, "tea"], "parlour", 1700, "hall", 600))
	var log := U.run(w, 6000)
	var starts := U.find(log, SimEvents.B_ACTIVITY, {"id": "warmup"})
	var ends := U.find(log, SimEvents.B_ACTIVITY_END, {"id": "warmup"})
	assert_eq(int(ends[0]["t"]) - int(starts[0]["t"]), 1500)
	assert_eq(int(ends[1]["t"]) - int(starts[1]["t"]), 600, "second loop: the activity's own 10 s")


func test_gate_first_squeak_plus_1s() -> void:
	var w := U.world("fx_prologue")
	U.run(w, 100)
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.squeak()]))
	var sq: int = w.tick
	var ev := U.run_until(w, SimEvents.B_ACTIVITY_END, {"id": "warmup"}, 400, log)
	assert_eq(int(ev["t"]) - sq, 90, "gate: +1 s after the squeak, but he finishes the 90 f squeak bit first")


func test_detour_runs_before_the_next_activity() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "hall", 600))
	U.force_rig(w, "achoo_ria")
	var log := U.run(w, 3000)
	var acts := _acts(log)
	assert_eq(acts.slice(0, 3), ["tea", "fixup_mirror", "pickles"], str(acts))
	var det := U.first(log, SimEvents.B_DETOUR)
	assert_eq(str(det["kind"]), "fixup_mirror")
	assert_eq(str(det["station"]), "st_hall_mirror")
	assert_eq(str(det["why"]), "FRAZZLED")


func test_b_next_same_tick_as_b_detour() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "hall", 600))
	U.force_rig(w, "achoo_ria")
	var log := U.run(w, 2000)
	var det := U.first(log, SimEvents.B_DETOUR)
	var nexts := U.find(log, SimEvents.B_NEXT, {"t": det["t"]})
	assert_eq(nexts.size(), 1)
	assert_eq(str(nexts[0]["id"]), "fixup_mirror")
	assert_true(bool(nexts[0]["detour"]))


func test_bubble_ring_starts_240_ticks_before_leaving() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "hall", 600))
	var log: Array = []
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "tea"}, 100, log)
	var start := w.tick
	var first_ring := -1
	for i in 700:
		w.step([])
		var ev := w.drain_events()
		if first_ring < 0 and int(w.bubble()["ring_ticks"]) >= 0:
			first_ring = w.tick
			assert_eq(int(w.bubble()["ring_ticks"]), 240)
			assert_eq(str(w.bubble()["next"]), "pickles")
		if not U.first(ev, SimEvents.B_ACTIVITY_END).is_empty():
			assert_eq(w.tick - first_ring, 240, "ring shown for 4 s")
			break
	assert_eq(first_ring - start, 600 - 240)


func test_next_activity_shown_240_ticks_before_it_starts() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		ep["hush"]["start"] = {"room": "hall", "x": 600})
	var log := U.run(w, 8000)
	var acts := U.find(log, SimEvents.B_ACTIVITY)
	for i in range(1, acts.size()):
		var id := str(acts[i]["id"])
		var t := int(acts[i]["t"])
		var shown := -1
		for ev in log:
			if str(ev["e"]) == SimEvents.B_NEXT and int(ev["t"]) <= t and str(ev["id"]) == id:
				shown = int(ev["t"])
		assert_true(shown >= 0 and t - shown >= 240, "%s shown at %d, starts %d" % [id, shown, t])


func test_nerves_floor_each_loop() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		ep["rules"]["nerves"] = true
		ep["hush"]["start"] = {"room": "hall", "x": 600}
		ep["bellows"]["loop"] = [{"a": "tea"}, {"a": "pickles"}])
	assert_eq(w.bellows.temper_q, 20 * SimConst.TEMPER_Q, "starts Irked")
	U.run(w, 2500)
	var saw_wrap := false
	for i in 3000:
		var lc := w.routine.loop_count
		w.step([])
		w.drain_events()
		if w.routine.loop_count != lc:
			saw_wrap = true
			assert_ge(w.bellows.temper_q, 20 * SimConst.TEMPER_Q)
			break
	assert_true(saw_wrap)


func test_prank_during_perform_ends_activity_resume_continues() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "hall", 600))
	U.force_rig(w, "kettle_drum")
	U.force_rig(w, "achoo_ria")
	var log := U.run(w, 2400)
	var kettle := U.first(log, SimEvents.PRANK_FIRE, {"prank": "kettle_drum"})
	var achoo := U.first(log, SimEvents.PRANK_FIRE, {"prank": "achoo_ria"})
	assert_false(kettle.is_empty())
	assert_false(achoo.is_empty(), "KETTLE DRUM resumes the tea, so ACHOO-RIA! still fires at 7 s")
	assert_eq(U.find(log, SimEvents.B_ACTIVITY, {"id": "tea"}).size(), 1, "resuming is not a new visit")
	var tea_end := U.first(log, SimEvents.B_ACTIVITY_END, {"id": "tea"})
	assert_le(int(tea_end["t"]), int(achoo["t"]), "ACHOO-RIA! ends the tea")
