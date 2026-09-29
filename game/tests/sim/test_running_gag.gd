## Running Gag links + multipliers, ending below 20; Meltdown (timings, stomps, quake prank, Exhausted,
## temper 60, bonus cap, counts as a link).
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func test_links_and_multipliers() -> void:
	# pickles (L) → tea: kettle (M, resume) → achoo (M) → rinse: tap (S)
	var w := U.world_patched("fx_act1", U.loop_patch(["pickles", "tea", "rinse"], "kitchen", 3130, "hall", 600))
	for p in ["in_a_pickle", "kettle_drum", "achoo_ria", "tap_dance"]:
		U.force_rig(w, p)
	w.pranks.state[w.db.prank_idx("in_a_pickle")] = Pranks.RIGGED
	var log := U.run(w, 3000)
	var gags := U.find(log, SimEvents.RUNNING_GAG)
	var links := []
	var mults := []
	for g in gags:
		links.append(int(g["link"]))
		mults.append(int(g["mult"]))
	assert_eq(links.slice(0, 4), [1, 2, 3, 4], str(links))
	assert_eq(mults.slice(0, 4), [100, 150, 200, 300])
	var ap := U.find(log, SimEvents.APPLAUSE, {"kind": "gag"})
	assert_eq(int(ap[0]["delta"]), 179, "IN A PICKLE base 179 × 1")
	assert_eq(int(ap[1]["delta"]), 189, "KETTLE DRUM 126 × 1.5")
	assert_eq(int(ap[2]["delta"]), 252, "ACHOO-RIA! 126 × 2")
	assert_eq(int(ap[3]["delta"]), 270, "TAP DANCE 90 × 3")


func test_running_gag_ends_below_20() -> void:
	var w := U.world_patched("fx_act1", U.loop_patch(["rinse", "tea"], "kitchen", 3740, "hall", 600))
	U.force_rig(w, "tap_dance")
	var log: Array = []
	U.run_until(w, SimEvents.RUNNING_GAG, {}, 300, log)
	assert_eq(w.link(), 1)
	assert_gt(w.fuse_ticks(), 0)
	var end := U.run_until(w, SimEvents.RUNNING_GAG_END, {}, 3000, log)
	assert_false(end.is_empty())
	assert_lt(w.bellows.temper_q, 20 * SimConst.TEMPER_Q)
	assert_eq(w.link(), 0)
	assert_eq(w.fuse_ticks(), 0)


func test_fuse_is_hold_plus_temper_over_20() -> void:
	var w := U.quiet_world()
	w.temper.gain(w, 35 * SimConst.TEMPER_Q)
	w.temper.set_link(w, 1)
	assert_eq(w.fuse_ticks(), 360 + (35 - 20) * 60 / 2, "6 s + 7.5 s = 13.5 s for a medium from Calm")


func _meltdown_world() -> SimWorld:
	var w := U.world_patched("fx_meltdown", U.loop_patch(["warmup", "paper"], "parlour", 1700, "kitchen", 3800))
	U.force_rig(w, "allegro_go_go")
	U.set_temper(w, 80)
	return w


func test_meltdown_timeline() -> void:
	var w := _meltdown_world()
	var log: Array = []
	var md := U.run_until(w, SimEvents.MELTDOWN_START, {}, 800, log)
	assert_false(md.is_empty())
	var end := U.first(log, SimEvents.REACTION_END, {"prank": "allegro_go_go"})
	assert_eq(int(md["t"]), int(end["t"]), "at the reaction end, temper ≥ 100")
	assert_true(SimEvents.is_laugh(md))
	var ex := U.run_until(w, SimEvents.EXHAUSTED, {}, 400, log)
	assert_eq(int(ex["t"]) - int(md["t"]), SimConst.MELTDOWN_TICKS)
	var stomps := U.find(log, SimEvents.MELTDOWN_STOMP)
	assert_eq(stomps.size(), 3)
	for i in 3:
		assert_eq(int(stomps[i]["t"]) - int(md["t"]), SimConst.MELTDOWN_STOMPS[i])
	assert_eq(w.bellows.temper_q, 60 * SimConst.TEMPER_Q, "temper resets to 60")
	assert_eq(w.senses.sight_ranges(w), [150, 150], "Exhausted: 150 px")
	assert_false(U.first(log, SimEvents.BONUS, {"kind": "meltdown", "amount": 80}).is_empty())
	var links := U.find(log, SimEvents.RUNNING_GAG)
	assert_eq(int(links[links.size() - 1]["link"]), 2, "the Meltdown is a link")
	U.run_until(w, SimEvents.B_ACTIVITY, {}, 600, log)
	assert_ge(w.tick - int(ex["t"]), SimConst.EXHAUSTED_TICKS)


func test_quake_prank_queues_as_the_next_reaction() -> void:
	var w := _meltdown_world()
	U.force_rig(w, "prima_ballerina")
	var log := U.run(w, 1500)
	var ex_t := int(U.first(log, SimEvents.MELTDOWN_START)["t"]) + SimConst.MELTDOWN_TICKS
	var q := U.first(log, SimEvents.PRANK_FIRE, {"prank": "prima_ballerina"})
	assert_false(q.is_empty())
	assert_eq(str(q["trigger"]), "quake")
	assert_eq(int(q["t"]), ex_t, "fires when the tantrum ends")
	var ex := U.first(log, SimEvents.EXHAUSTED)
	var qe := U.first(log, SimEvents.REACTION_END, {"prank": "prima_ballerina"})
	assert_false(ex.is_empty())
	assert_ge(int(ex["t"]), int(qe["t"]), "then Exhausted")


func test_meltdown_bonus_capped_at_2() -> void:
	var w := U.quiet_world()
	for i in 3:
		w.bellows.start_meltdown(w)
	var log := w.drain_events()
	assert_eq(U.find(log, SimEvents.BONUS, {"kind": "meltdown"}).size(), 2)
	assert_eq(w.bellows.meltdowns, 3)
