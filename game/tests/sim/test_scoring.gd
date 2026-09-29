## Scoring + Script goals: gag bases × multiplier, bits, bonuses, lines, Big Number unseal, all lines,
## stars (★★★ at ≥ 100.0), candles, applause never negative.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func test_prank_lines_big_number_stars() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["pickles", "tea", "rinse"], "kitchen", 3130, "hall", 600))
	var ls := w.line_states()
	assert_eq(ls[5]["id"], "bn")
	assert_true(ls[5]["sealed"])
	assert_eq(w.stars(), [false, false, false])
	for p in ["in_a_pickle", "kettle_drum", "achoo_ria", "tap_dance"]:
		U.force_rig(w, p)
	var log := U.run(w, 2600)
	assert_false(U.first(log, SimEvents.LINE_DONE, {"line": "pickle"}).is_empty())
	assert_false(U.first(log, SimEvents.LINE_DONE, {"line": "kettle"}).is_empty())
	assert_false(U.first(log, SimEvents.LINE_DONE, {"line": "tap"}).is_empty())
	var un := U.first(log, SimEvents.BIG_NUMBER_UNSEALED)
	assert_false(un.is_empty())
	assert_false(U.first(log, SimEvents.STAR, {"n": 1}).is_empty())
	assert_true(w.stars()[0])
	assert_false(w.stars()[1], "lift + bn missing")
	assert_false(w.line_states()[5]["sealed"])


func test_big_number_done_while_sealed_counts_at_unseal() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles", "rinse"], "kitchen", 2900, "hall", 600))
	U.force_rig(w, "achoo_ria")
	U.force_rig(w, "tap_dance")
	var log := U.run(w, 1200)
	assert_eq(w.pranks.da_done[w.db.double_acts["hot_and_cold"].idx], 1)
	assert_true(U.first(log, SimEvents.LINE_DONE, {"line": "bn"}).is_empty(), "still sealed")
	U.force_rig(w, "kettle_drum")
	U.force_rig(w, "in_a_pickle")
	log = U.run(w, 6000)
	var un := U.first(log, SimEvents.BIG_NUMBER_UNSEALED)
	var bn := U.first(log, SimEvents.LINE_DONE, {"line": "bn"})
	assert_false(bn.is_empty())
	assert_eq(int(bn["t"]), int(un["t"]))


func test_all_lines_done_and_three_stars() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["pickles", "tea", "paper", "rinse"], "kitchen", 3130, "hall", 600))
	for p in ["in_a_pickle", "kettle_drum", "achoo_ria", "tap_dance", "lift_off"]:
		U.force_rig(w, p)
	var log := U.run(w, 4000)
	assert_false(U.first(log, SimEvents.ALL_LINES_DONE).is_empty(), str(w.line_states()))
	assert_true(w.stars()[1])
	w.scoring.add(w, 1000, "test", "x")
	U.run(w, 1)
	assert_eq(w.stars(), [true, true, true])


func test_prologue_awards_no_stars() -> void:
	var w := U.world("fx_prologue")
	U.force_rig(w, "achoo_ria")
	w.pranks.state[w.db.prank_idx("achoo_ria")] = Pranks.LANDED
	w.pranks.state[w.db.prank_idx("allegro_go_go")] = Pranks.LANDED
	w.goals.dirty = true
	var log := U.run(w, 2)
	assert_false(U.first(log, SimEvents.ALL_LINES_DONE).is_empty())
	assert_eq(w.stars(), [false, false, false])
	var e := U.step(w, [SimCmd.bow()])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"c": "bow", "why": "no_star"}).is_empty())


func test_chain_and_meltdown_lines() -> void:
	var w := U.world("fx_meltdown")
	w.temper.set_link(w, 3)
	w.bellows.start_meltdown(w)
	var log := U.run(w, 2)
	assert_false(U.first(log, SimEvents.LINE_DONE, {"line": "melt"}).is_empty())
	# the chain Big Number (link 3) is sealed until rug + spin + melt are done
	assert_true(U.first(log, SimEvents.LINE_DONE, {"line": "bn"}).is_empty())


func test_candle_after_step3_hint() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["rinse", "tea"], "kitchen", 3740, "hall", 600))
	var e := U.step(w, [SimCmd.hint_used("tap", 3), SimCmd.hint_used("pickle", 2), SimCmd.hint_used("nope", 3)])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"c": "hint_used"}).is_empty())
	U.force_rig(w, "tap_dance")
	U.run(w, 400)
	var tap: Dictionary = w.line_states()[1]
	assert_true(tap["done"])
	assert_true(tap["candle"])
	assert_false(w.line_states()[2]["candle"])


func test_bow_after_star_ends_the_night() -> void:
	var w := U.quiet_world()
	for id in ["kettle_drum", "tap_dance", "in_a_pickle"]:
		w.pranks.state[w.db.prank_idx(id)] = Pranks.LANDED
	w.goals.dirty = true
	U.run(w, 1)
	assert_true(w.stars()[0])
	var e := U.step(w, [SimCmd.bow()])
	assert_true(w.ended)
	assert_eq(w.end_reason, "bow")
	assert_false(U.first(e, SimEvents.NIGHT_END, {"reason": "bow"}).is_empty())
	# arriving at the front door after ★ also bows
	var w2 := U.quiet_world()
	for id in ["kettle_drum", "tap_dance", "in_a_pickle"]:
		w2.pranks.state[w2.db.prank_idx(id)] = Pranks.LANDED
	w2.goals.dirty = true
	U.run(w2, 1)
	U.place_hush(w2, "hall", 900)
	w2.step([SimCmd.go("hall_front_door")])
	U.run(w2, 200)
	assert_eq(w2.end_reason, "bow")


func test_applause_events_and_floor() -> void:
	var w := U.quiet_world()
	w.scoring.add(w, 30, "gag", "x")
	w.scoring.add(w, -50, "catch", "caught")
	var log := w.drain_events()
	var a := U.find(log, SimEvents.APPLAUSE)
	assert_eq(int(a[0]["total"]), 30)
	assert_eq(int(a[1]["delta"]), -30)
	assert_eq(w.applause_tenths(), 0)
