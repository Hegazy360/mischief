## Hooks at marks, `resume`, fix-up hooks at fix-up tick 60, fizzles (stay RIGGED), one punchline at a time.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _tea_world(extra: Callable = Callable()) -> SimWorld:
	return U.world_patched("fx_act1", U.loop_patch(["tea", "pickles", "rinse"], "kitchen", 2900, "hall", 600), {}, extra)


func test_use_hooks_fire_at_their_marks() -> void:
	var w := _tea_world()
	U.force_rig(w, "achoo_ria")
	var log := U.run(w, 1000)
	var start := U.first(log, SimEvents.B_ACTIVITY, {"id": "tea"})
	var fire := U.first(log, SimEvents.PRANK_FIRE, {"prank": "achoo_ria"})
	assert_eq(int(fire["t"]) - int(start["t"]), 420, "ACHOO-RIA! @7 s into tea")
	assert_eq(str(fire["trigger"]), "use")


func test_resume_hook_continues_the_activity() -> void:
	var w := _tea_world()
	U.force_rig(w, "kettle_drum")
	U.force_rig(w, "achoo_ria")
	var log := U.run(w, 1600)
	var start := int(U.first(log, SimEvents.B_ACTIVITY, {"id": "tea"})["t"])
	var k := U.first(log, SimEvents.PRANK_FIRE, {"prank": "kettle_drum"})
	assert_eq(int(k["t"]) - start, 180, "KETTLE DRUM @3 s")
	var k_len := int(U.first(log, SimEvents.REACTION_START, {"prank": "kettle_drum"})["len"])
	var a := U.first(log, SimEvents.PRANK_FIRE, {"prank": "achoo_ria"})
	assert_eq(int(a["t"]) - start, 420 + k_len, "the tea clock paused during the reaction, then resumed")


func test_fixup_hook_fires_at_fixup_tick_60() -> void:
	var w := _tea_world()
	U.force_rig(w, "tap_dance")
	U.run(w, 5)
	w.residue.add(w, "FLOURY", false)
	var log := U.run(w, 3000)
	var fix := U.first(log, SimEvents.B_ACTIVITY, {"id": "fixup_sink"})
	assert_false(fix.is_empty())
	var fire := U.first(log, SimEvents.PRANK_FIRE, {"prank": "tap_dance"})
	assert_eq(str(fire["trigger"]), "fixup")
	assert_eq(int(fire["t"]) - int(fix["t"]), SimConst.FIXUP_MARK_TICKS)


func test_condition_false_fizzles_and_stays_rigged() -> void:
	var w := U.world_patched("fx_meltdown", U.loop_patch(["mirror", "warmup"], "hall", 1080, "kitchen", 3800))
	U.force_rig(w, "mirror_mirror")
	var log := U.run(w, 200)
	assert_false(U.first(log, SimEvents.FIZZLE, {"prank": "mirror_mirror"}).is_empty(), "no Hush in the frame")
	assert_eq(w.prank_state("mirror_mirror"), Pranks.RIGGED)
	assert_true(U.first(log, SimEvents.PRANK_FIRE).is_empty())


func test_unrigged_hooks_do_nothing() -> void:
	var w := _tea_world()
	var log := U.run(w, 1000)
	assert_true(U.first(log, SimEvents.PRANK_FIRE).is_empty())
	assert_true(U.first(log, SimEvents.FIZZLE).is_empty())


func test_same_mark_trigger_waits_for_the_reaction() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["rinse", "tea"], "kitchen", 3740, "hall", 600), {}, func(f: Dictionary) -> void:
		f["pranks"]["pranks"]["in_a_pickle"]["trigger"] = {"type": "use", "activity": "rinse", "mark_s": 1.0}
		f["pranks"]["pranks"]["in_a_pickle"]["knock_on"] = null
		(f["pranks"]["double_acts"] as Dictionary).erase("encore"))
	U.force_rig(w, "tap_dance")
	U.force_rig(w, "in_a_pickle")
	var log := U.run(w, 800)
	var fires := U.find(log, SimEvents.PRANK_FIRE)
	assert_eq(fires.size(), 2)
	assert_eq(str(fires[0]["prank"]), "in_a_pickle", "sorted by mark then prank id")
	var end1 := U.first(log, SimEvents.REACTION_END, {"prank": "in_a_pickle"})
	assert_eq(int(fires[1]["t"]), int(end1["t"]), "the second waited for the first punchline to end")
	assert_eq(str(fires[1]["prank"]), "tap_dance")
	assert_eq(int(fires[1]["link"]), 2)
