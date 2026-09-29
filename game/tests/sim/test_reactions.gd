## Reactions: tier by temper, length per tier, travel end position, variants, knock-on Double Acts.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _rinse_world() -> SimWorld:
	return U.world_patched("fx_act1", U.loop_patch(["rinse", "tea"], "kitchen", 3740, "hall", 600))


func test_tier_by_temper_and_length_formula() -> void:
	# drench_a: 120 frames, hold [23, 90] (67): T1 120, T2 120 + 13, T3 120 + 33
	for row in [[0, 1, 120], [30, 1, 120], [50, 2, 133], [80, 3, 153]]:
		var w := _rinse_world()
		U.force_rig(w, "tap_dance")
		U.set_temper(w, row[0])
		var log: Array = []
		var rs := U.run_until(w, SimEvents.REACTION_START, {"prank": "tap_dance"}, 200, log)
		assert_eq(int(rs["tier"]), row[1], "temper %d" % row[0])
		assert_eq(int(rs["len"]), row[2])
		assert_false(bool(rs["suppressed"]))
		var end := U.run_until(w, SimEvents.REACTION_END, {}, 300, log)
		assert_eq(int(end["t"]) - int(rs["t"]), row[2])


func test_accent_frame_and_blindness() -> void:
	var w := _rinse_world()
	U.force_rig(w, "tap_dance")
	var log := U.run(w, 300)
	var rs := U.first(log, SimEvents.REACTION_START)
	var ac := U.first(log, SimEvents.REACTION_ACCENT)
	assert_eq(int(ac["t"]) - int(rs["t"]), 20, "drench accent at frame 20")
	assert_true(SimEvents.is_laugh(ac))


func test_travel_end_position() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "hall", 600))
	U.force_rig(w, "achoo_ria")
	var log: Array = []
	var rs := U.run_until(w, SimEvents.REACTION_START, {"prank": "achoo_ria"}, 900, log)
	var rx: Dictionary = w.bellows.reacting
	assert_eq(str(rx["prank"]), "achoo_ria")
	var def: ReactionDef = w.db.reactions["sneeze_blast_" + str(rs["variant"])]
	var x0 := w.bellows.x_sub
	U.run(w, def.travel_from + (def.travel_to - def.travel_from) / 2)
	assert_between(w.bellows.x_sub, x0 + 1, 3760 * 60 - 1, "mid-flight")
	U.run(w, def.travel_to - (def.travel_from + (def.travel_to - def.travel_from) / 2))
	assert_eq(w.bellows.x_sub, 3760 * SimConst.SUB, "into the sink")
	U.run_until(w, SimEvents.REACTION_END, {}, 300)
	assert_eq(w.bellows.x_sub, 3760 * SimConst.SUB)


func test_variant_pick_is_deterministic_hash() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "hall", 600))
	U.force_rig(w, "achoo_ria")
	var rs := U.run_until(w, SimEvents.REACTION_START, {}, 900)
	var p := w.db.prank_idx("achoo_ria")
	var hv := StateHash.mix(StateHash.mix(StateHash.mix(StateHash.OFFSET, 101), p), 0)
	assert_eq(str(rs["variant"]), ["a", "b"][hv % 2])


func test_knock_on_double_act() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "hall", 600))
	U.force_rig(w, "achoo_ria")
	U.force_rig(w, "tap_dance")
	var log := U.run(w, 1400)
	var ko := U.first(log, SimEvents.KNOCK_ON)
	assert_eq(str(ko["a"]), "achoo_ria")
	assert_eq(str(ko["b"]), "tap_dance")
	var a_start := U.first(log, SimEvents.REACTION_START, {"prank": "achoo_ria"})
	var def: ReactionDef = w.db.reactions["sneeze_blast_" + str(a_start["variant"])]
	assert_eq(int(ko["t"]) - int(a_start["t"]), def.remap(110, int(a_start["tier"])), "A truncated at its knock-on frame")
	var a_end := U.first(log, SimEvents.REACTION_END, {"prank": "achoo_ria"})
	assert_eq(int(a_end["t"]), int(ko["t"]))
	var b_fire := U.first(log, SimEvents.PRANK_FIRE, {"prank": "tap_dance"})
	assert_eq(str(b_fire["trigger"]), "knock_on")
	assert_eq(int(b_fire["link"]), 2, "B is the next Running Gag link")
	var b_start := U.first(log, SimEvents.REACTION_START, {"prank": "tap_dance"})
	assert_eq(int(b_start["entry"]), 18, "B starts at its accent − 2")
	var b_acc := U.first(log, SimEvents.REACTION_ACCENT, {"prank": "tap_dance"})
	assert_eq(int(b_acc["t"]) - int(b_start["t"]), 2, "anticipation skipped")
	var b_end := U.first(log, SimEvents.REACTION_END, {"prank": "tap_dance"})
	assert_eq(int(b_end["t"]) - int(b_start["t"]), int(b_start["len"]) - 18)
	U.run(w, 1)
	var bn: Dictionary = w.line_states()[5]
	assert_eq(bn["id"], "bn")
	assert_eq(w.pranks.da_done[w.db.double_acts["hot_and_cold"].idx], 1)
	assert_false(U.first(log, SimEvents.COMBO, {"id": "poodle"}).is_empty(), "FRAZZLED + SOAKED")


func test_knock_on_needs_b_rigged() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "hall", 600))
	U.force_rig(w, "achoo_ria")
	var log := U.run(w, 1200)
	assert_true(U.first(log, SimEvents.KNOCK_ON).is_empty())
	var a_start := U.first(log, SimEvents.REACTION_START, {"prank": "achoo_ria"})
	var a_end := U.first(log, SimEvents.REACTION_END, {"prank": "achoo_ria"})
	assert_eq(int(a_end["t"]) - int(a_start["t"]), int(a_start["len"]), "full length")


func test_headbutt_knock_on_is_inactive_in_stage_1() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["phone", "tea"], "hall", 960, "kitchen", 3800), {}, func(f: Dictionary) -> void:
		(f["episodes"]["fx_act1"]["script"] as Array).append({"id": "fish", "kind": "prank", "prank": "something_fishy", "req": false}))
	U.force_rig(w, "something_fishy")
	var log := U.run(w, 600)
	assert_false(U.first(log, SimEvents.REACTION_END, {"prank": "something_fishy"}).is_empty())
	assert_true(U.first(log, SimEvents.KNOCK_ON).is_empty())
	assert_true(U.first(log, SimEvents.HEADBUTT).is_empty())
