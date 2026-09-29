## Mirror, Mirror: rounds 72 / 72 / 60 while Hush stands frozen in the frame; releasing in round n fires
## at tier n; still frozen after round 3 → face-to-face; an empty frame fizzles.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _mirror_world() -> SimWorld:
	var w := U.world_patched("fx_meltdown", U.loop_patch(["mirror", "warmup"], "hall", 1080, "hall", 1240))
	U.force_rig(w, "mirror_mirror")
	U.place_hush(w, "hall", 1240)
	U.step(w, [SimCmd.freeze(true)])
	return w


func test_rounds_and_invisibility() -> void:
	var w := _mirror_world()
	var log: Array = []
	var r1 := U.run_until(w, SimEvents.MIRROR_ROUND, {"round": 1}, 60, log)
	assert_false(r1.is_empty())
	var r2 := U.run_until(w, SimEvents.MIRROR_ROUND, {"round": 2}, 100, log)
	var r3 := U.run_until(w, SimEvents.MIRROR_ROUND, {"round": 3}, 100, log)
	assert_eq(int(r2["t"]) - int(r1["t"]), 72)
	assert_eq(int(r3["t"]) - int(r2["t"]), 72)
	assert_true(U.first(log, SimEvents.SPOT_START).is_empty(), "invisible in the frame (160 px in front of him)")
	var f2f := U.run_until(w, SimEvents.FACE_TO_FACE, {}, 100, log)
	assert_eq(int(f2f["t"]) - int(r3["t"]), 60, "specs land: he pokes the glass")
	var caught := U.run_until(w, SimEvents.CAUGHT, {}, 100, log)
	assert_eq(str(caught["cause"]), "face_to_face")


func test_release_in_round_n_fires_tier_n() -> void:
	for n in [1, 2, 3]:
		var w := _mirror_world()
		var log: Array = []
		U.run_until(w, SimEvents.MIRROR_ROUND, {"round": n}, 300, log)
		U.run(w, 10)
		log.append_array(U.step(w, [SimCmd.freeze(false)]))
		var fire := U.first(log, SimEvents.PRANK_FIRE, {"prank": "mirror_mirror"})
		assert_false(U.first(log, SimEvents.WINK, {"round": n}).is_empty())
		assert_eq(int(fire["tier"]), n, "round %d" % n)
		var rs := U.first(log, SimEvents.REACTION_START, {"prank": "mirror_mirror"})
		assert_eq(int(rs["len"]), w.db.reactions["sig_mirror_mirror"].length(n, false))


func test_bolt_after_round_3_is_a_near_miss() -> void:
	var w := _mirror_world()
	var log: Array = []
	U.run_until(w, SimEvents.FACE_TO_FACE, {}, 400, log)
	U.run(w, 20)
	log.append_array(U.step(w, [SimCmd.freeze(false)]))
	log.append_array(U.step(w, [SimCmd.move("parlour", 2400, true)]))
	log.append_array(U.run(w, 5))
	assert_false(U.first(log, SimEvents.NEAR_MISS).is_empty())
	assert_eq(w.prank_state("mirror_mirror"), Pranks.RIGGED, "no wink, no prank")


func test_mirror_fixup_starts_the_rounds_too() -> void:
	var w := U.world_patched("fx_meltdown", U.loop_patch(["warmup"], "parlour", 1700, "hall", 1240))
	U.force_rig(w, "mirror_mirror")
	U.run(w, 3)
	w.residue.add(w, "FRAZZLED", false)
	U.step(w, [SimCmd.freeze(true)])
	var log: Array = []
	var r1 := U.run_until(w, SimEvents.MIRROR_ROUND, {"round": 1}, 1500, log)
	assert_false(r1.is_empty())
	var fix := U.first(log, SimEvents.B_ACTIVITY, {"id": "fixup_mirror"})
	assert_eq(int(r1["t"]) - int(fix["t"]), SimConst.FIXUP_MARK_TICKS)
	log.append_array(U.step(w, [SimCmd.freeze(false)]))
	U.run_until(w, SimEvents.REACTION_END, {"prank": "mirror_mirror"}, 400, log)
	assert_false(w.residue.has("FRAZZLED"), "he fled: residue cleared")
