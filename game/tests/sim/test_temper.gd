## Temper: gains at the accent, hold, decay, pauses, tiers, speeds, specs at Livid, look-back at Steaming+.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func test_gains_by_size_at_the_accent() -> void:
	for row in [["tap_dance", 25, ["rinse", "tea"], 3740], ["achoo_ria", 35, ["tea", "pickles"], 2900],
			["in_a_pickle", 45, ["pickles", "tea"], 3130]]:
		var w := U.world_patched("fx_act1", U.loop_patch(row[2], "kitchen", row[3], "hall", 600))
		U.force_rig(w, row[0])
		var log: Array = []
		U.run_until(w, SimEvents.REACTION_START, {"prank": row[0]}, 1000, log)
		assert_eq(w.bellows.temper_q, 0, "nothing before the accent")
		U.run_until(w, SimEvents.REACTION_ACCENT, {}, 200, log)
		assert_eq(w.bellows.temper_q, int(row[1]) * SimConst.TEMPER_Q, str(row[0]))
	assert_eq(SimConst.gain_for_size(PrankDef.SIZE_SIG), 55)


func test_hold_then_decay_2_per_tick() -> void:
	var w := U.quiet_world()
	w.temper.gain(w, 30 * SimConst.TEMPER_Q)
	U.run(w, SimConst.HOLD_TICKS)
	assert_eq(w.bellows.temper_q, 1800, "held for 6 s")
	U.run(w, 60)
	assert_eq(w.bellows.temper_q, 1800 - 120, "then −2 points per second")


func test_hold_and_decay_pause_while_reacting_and_on_fixups() -> void:
	var w := U.quiet_world()
	w.temper.gain(w, 30 * SimConst.TEMPER_Q)
	w.temper.hold_left = 0
	w.bellows.state = SimBellows.REACTING
	w.bellows.rx_prank = 0
	w.bellows.rx_len = 100000
	w.bellows.rx_t = 0
	w.bellows.rx_accent = 99999
	w.bellows.rx_accented = true
	U.run(w, 100)
	assert_eq(w.bellows.temper_q, 1800, "paused while reacting")
	w2_fixup_pause()


func w2_fixup_pause() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "pickles"], "kitchen", 2900, "hall", 600))
	U.run(w, 3)
	w.temper.gain(w, 40 * SimConst.TEMPER_Q)
	w.residue.add(w, "SOAKED", false)
	w.bellows.interrupt(w, false)
	w.bellows._start_next(w)
	assert_eq(w.bellows.state, SimBellows.DETOUR)
	var q := w.bellows.temper_q
	U.run(w, 600)
	assert_eq(w.bellows.temper_q, q, "the fuse pauses during fix-up detours")


func test_tiers_and_events() -> void:
	var w := U.quiet_world()
	var log: Array = []
	for pts in [10, 20, 45, 70, 99]:
		w.bellows.temper_q = pts * SimConst.TEMPER_Q
		log.append_array(U.run(w, 1))
	var tiers := []
	for ev in U.find(log, SimEvents.TEMPER_TIER):
		tiers.append(str(ev["tier"]))
	assert_eq(tiers, ["irked", "steaming", "livid"])
	assert_eq(w.bellows.tier, SimConst.TIER_LIVID_ID)


func test_speed_by_tier_never_above_15_pct() -> void:
	assert_eq([SimConst.b_walk_speed(0), SimConst.b_walk_speed(1), SimConst.b_walk_speed(2), SimConst.b_walk_speed(3)],
		[240, 252, 264, 276])
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "warmup"], "kitchen", 2900, "hall", 600))
	U.set_temper(w, 80)
	U.run_until(w, SimEvents.B_ACTIVITY_END, {"id": "tea"}, 800)
	U.run(w, 3)
	var x := w.bellows.x_sub
	U.run(w, 1)
	assert_eq(absi(w.bellows.x_sub - x), 276, "Livid walk")


func test_specs_jam_on_at_livid() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea"], "kitchen", 2900, "hall", 600))
	U.run(w, 5)
	assert_false(w.bellows.specs_on)
	U.set_temper(w, 75)
	var e := U.run(w, 1)
	assert_true(w.bellows.specs_on)
	assert_false(U.first(e, SimEvents.SPECS, {"on": true}).is_empty())


func test_look_back_at_steaming_crossing_a_doorway() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["tea", "warmup"], "kitchen", 2900, "hall", 600))
	U.set_temper(w, 65)
	var log: Array = []
	var lb := U.run_until(w, SimEvents.LOOK_BACK, {}, 900, log)
	assert_false(lb.is_empty())
	var room_ev := U.find(log, SimEvents.B_ROOM, {"room": "parlour"})
	assert_eq(int(room_ev[0]["t"]), int(lb["t"]), "at the doorway")
	var f := w.bellows.facing
	assert_eq(f, 1, "facing back into the kitchen")
	var x := w.bellows.x_sub
	U.run(w, SimConst.LOOK_BACK_TICKS - 1)
	assert_eq(w.bellows.x_sub, x, "paused 1 s")
	var w2 := U.world_patched("fx_act1", U.loop_patch(["tea", "warmup"], "kitchen", 2900, "hall", 600))
	U.set_temper(w2, 30)
	var log2 := U.run(w2, 900)
	assert_true(U.first(log2, SimEvents.LOOK_BACK).is_empty(), "Irked: no look-back")
