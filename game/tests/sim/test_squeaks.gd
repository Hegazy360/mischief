## Squeaks: hearing rooms, ear pips, bits 20/10/0 and ≤ 3 per visit, the third pip lures, fatigue,
## asleep and reacting behaviour.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _paper_world() -> SimWorld:
	# paper at the recliner (2080) for 12 s, bit_paper; Hush somewhere behind him
	var w := U.world_patched("fx_act1", U.loop_patch(["paper", "warmup"], "parlour", 2080, "parlour", 1600))
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "paper"}, 60)
	return w


func test_hearing_same_room_or_doorway() -> void:
	var w := _paper_world()
	assert_true(w.bits.hears(w, w.room_idx("parlour"), 1600 * 60))
	assert_true(w.bits.hears(w, w.room_idx("kitchen"), 3500 * 60), "joined by a doorway")
	assert_true(w.bits.hears(w, w.room_idx("hall"), 700 * 60))
	assert_false(w.bits.hears(w, w.room_idx("landing"), 1200 * 60), "not up the stairs")
	assert_false(w.bits.hears(w, w.room_idx("porch"), 300 * 60), "not through the front door")
	var w2 := U.world_patched("fx_act1", U.loop_patch(["pickles"], "kitchen", 3130, "hall", 700))
	U.run(w2, 3)
	assert_false(w2.bits.hears(w2, w2.room_idx("hall"), 700 * 60), "two rooms away")


func test_bits_score_20_10_0_and_max_3_per_visit() -> void:
	var w := _paper_world()
	var log: Array = []
	for i in 4:
		log.append_array(U.step(w, [SimCmd.squeak()]))
		log.append_array(U.run(w, 100))
	var bits := U.find(log, SimEvents.SQUEAK_BIT, {"bit": "bit_paper"})
	assert_eq(bits.size(), 3, "at most 3 per visit")
	assert_eq([int(bits[0]["score"]), int(bits[1]["score"]), int(bits[2]["score"])], [20, 10, 0])
	assert_true(SimEvents.is_laugh(bits[0]))
	assert_eq(w.bellows.temper_q > 0, true, "+5 temper per bit")


func test_ear_pips_and_fade() -> void:
	var w := _paper_world()
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.squeak()]))
	assert_eq(w.bellows.ear_pips, 1)
	log.append_array(U.run(w, 100))
	log.append_array(U.step(w, [SimCmd.squeak()]))
	assert_eq(w.bellows.ear_pips, 2)
	assert_eq(w.bubble()["ear_pips"], 2)
	log.append_array(U.run(w, SimConst.EAR_PIP_WINDOW))
	assert_eq(w.bellows.ear_pips, 0, "faded 8 s after the last squeak")


func test_third_pip_is_a_lure() -> void:
	# squeak from the kitchen (joined by a doorway, out of his sight), then hide under the table
	var w := _paper_world()
	U.place_hush(w, "kitchen", 3470)
	var log: Array = []
	for i in 3:
		log.append_array(U.step(w, [SimCmd.squeak()]))
		log.append_array(U.run(w, 100 if i < 2 else 1))
	log.append_array(U.step(w, [SimCmd.go("kitchen_table")]))
	var lure := U.first(log, SimEvents.LURE)
	assert_false(lure.is_empty())
	assert_eq(str(lure["room"]), "kitchen")
	assert_eq(int(lure["x"]), 3470)
	var det := U.first(log, SimEvents.B_DETOUR, {"kind": "curious"})
	assert_eq(str(det["why"]), "lure")
	assert_eq(int(U.first(log, SimEvents.B_NEXT, {"id": "curious"})["t"]), int(det["t"]), "shown in the bubble at once")
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "curious"}, 600, log)
	assert_eq(w.bellows.state, SimBellows.CURIOUS)
	assert_true(w.bellows.specs_on)
	assert_eq(w.bellows.x_sub, 3470 * 60, "at the squeak's spot")
	var end := U.run_until(w, SimEvents.B_ACTIVITY_END, {"id": "curious"}, 400, log)
	assert_false(end.is_empty(), "looks 3 s then shrugs")
	assert_true(U.first(log, SimEvents.CAUGHT).is_empty(), "she hid unseen")


func test_lure_fatigue_after_two_lures_in_60s() -> void:
	# tea at 2900 facing right; Hush squeaks from the parlour behind him (out of sight) in quick bursts
	var w := U.world_patched("fx_act1", U.loop_patch(["tea"], "kitchen", 2900, "parlour", 2000))
	U.run(w, 3)
	var log: Array = []
	for i in 9:
		log.append_array(U.step(w, [SimCmd.squeak()]))
		log.append_array(U.run(w, 4))
	assert_eq(U.find(log, SimEvents.LURE).size(), 2)
	assert_false(U.first(log, SimEvents.LURE_FATIGUE).is_empty())
	assert_false(w.bits.lure_ready(w))


func test_asleep_only_the_nap_bit() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["nap"], "parlour", 2080, "parlour", 1600))
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "nap"}, 60)
	U.run(w, 2)
	var log: Array = []
	for i in 3:
		log.append_array(U.step(w, [SimCmd.squeak()]))
		log.append_array(U.run(w, 70))
	assert_eq(U.find(log, SimEvents.SQUEAK_BIT, {"bit": "bit_nap"}).size(), 3)
	assert_eq(U.find(log, SimEvents.EAR_PIP).size(), 0)
	assert_true(U.first(log, SimEvents.LURE).is_empty(), "a sleeper can't be lured")


func test_reacting_ignores_squeaks() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["rinse", "tea"], "kitchen", 3740, "kitchen", 3300))
	U.force_rig(w, "tap_dance")
	U.run_until(w, SimEvents.REACTION_START, {}, 200)
	var e := U.step(w, [SimCmd.squeak()])
	var sq := U.first(e, SimEvents.SQUEAK)
	assert_false(bool(sq["heard"]))
	assert_true(U.first(e, SimEvents.EAR_PIP).is_empty())
