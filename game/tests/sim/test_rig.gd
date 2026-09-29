## Rigging: per-mille progress per prep tier, release keeps progress, resume, multi-step, B-rig noise,
## the ring pausing (and Hush freezing) when a "?" starts.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _ticks_to_rig(w: SimWorld, hotspot: String) -> int:
	U.place_hush_at(w, hotspot)
	var t0 := w.tick
	var log: Array = []
	assert_true(U.rig_hold(w, 400, log))
	var ev := U.first(log, SimEvents.RIG_STEP_DONE)
	return int(ev["t"]) - t0


func test_prep_tiers_q_s_b() -> void:
	var w := U.quiet_world("fx_meltdown")
	assert_eq(_ticks_to_rig(w, "parlour_gramophone"), SimConst.PREP_Q, "Q = 0.8 s")
	w = U.quiet_world("fx_meltdown")
	assert_eq(_ticks_to_rig(w, "stairs_rods"), SimConst.PREP_S, "S = 1.5 s")
	w = U.quiet_world("fx_meltdown")
	assert_eq(_ticks_to_rig(w, "parlour_chandelier"), SimConst.PREP_B, "B = 2.5 s")


func test_per_mille_progress() -> void:
	var w := U.quiet_world("fx_meltdown")
	U.place_hush_at(w, "stairs_rods")
	U.step(w, [SimCmd.rig(true)])
	assert_eq(w.rig_progress_pm("rug_burn"), Fx.div(1000, 90))
	U.run(w, 44)
	assert_eq(w.rig_progress_pm("rug_burn"), 500)
	assert_eq(w.prank_state("rug_burn"), Pranks.IN_PROGRESS)


func test_release_keeps_progress_and_resume_later() -> void:
	var w := U.quiet_world("fx_meltdown")
	U.place_hush_at(w, "parlour_chandelier")
	U.step(w, [SimCmd.rig(true)])
	U.run(w, 99)
	U.step(w, [SimCmd.rig(false)])
	assert_eq(w.rig_progress_pm("prima_ballerina"), Fx.div(100 * 1000, 150))
	U.step(w, [SimCmd.move("parlour", 1900)])
	U.run(w, 200)
	assert_eq(w.rig_progress_pm("prima_ballerina"), Fx.div(100 * 1000, 150), "kept while away")
	U.walk_to(w, "parlour_chandelier")
	var log: Array = []
	U.step(w, [SimCmd.rig(true)])
	var ev := U.run_until(w, SimEvents.RIGGED, {}, 100, log)
	assert_false(ev.is_empty())
	assert_eq(U.find(log, SimEvents.RIGGED).size() + 0, 1)
	assert_eq(w.prank_state("prima_ballerina"), Pranks.RIGGED)
	assert_eq(w.rig_progress_pm("prima_ballerina"), 1000)


func test_multi_step_prank_with_per_step_rig_points() -> void:
	var w := U.quiet_world("fx_act1")
	U.place_hush_at(w, "parlour_recliner")
	assert_true(U.rig_hold(w, 300))
	assert_eq(w.prank_state("lift_off"), Pranks.IN_PROGRESS)
	assert_eq(w.pranks.step[w.db.prank_idx("lift_off")], 1)
	var e := U.step(w, [SimCmd.rig(true)])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"why": "nothing_to_rig"}).is_empty(), "step 2 is at the newspaper")
	U.step(w, [SimCmd.rig(false)])
	U.place_hush_at(w, "parlour_newspaper")
	e = U.step(w, [SimCmd.rig(true)])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"why": "needs_item"}).is_empty())
	U.step(w, [SimCmd.rig(false)])
	U.place_hush_at(w, "hall_confiscated_box")
	U.step(w, [SimCmd.pick("magnifier")])
	U.place_hush_at(w, "parlour_newspaper")
	var log: Array = []
	assert_true(U.rig_hold(w, 100, log))
	assert_false(U.first(log, SimEvents.RIGGED, {"prank": "lift_off"}).is_empty())
	assert_false(U.first(log, SimEvents.RIG_STEP_DONE, {"prank": "lift_off", "step": 1}).is_empty())


func test_b_rig_emits_noise_every_30_ticks() -> void:
	var w := U.quiet_world("fx_meltdown")
	U.place_hush_at(w, "parlour_chandelier")
	var log: Array = []
	U.rig_hold(w, 300, log)
	var noises := U.find(log, SimEvents.NOISE, {"kind": "rig"})
	assert_eq(noises.size(), 5, "150 ticks / 30")
	assert_eq(int(noises[1]["t"]) - int(noises[0]["t"]), 30)
	assert_eq(int(noises[0]["r"]), 500)
	w = U.quiet_world("fx_meltdown")
	U.place_hush_at(w, "stairs_rods")
	log = []
	U.rig_hold(w, 300, log)
	assert_eq(U.find(log, SimEvents.NOISE).size(), 0, "Q/S rigs are silent")


func test_step_conditions_block_rigging() -> void:
	var w := U.quiet_world("fx_act1", {}, func(f: Dictionary) -> void:
		(f["episodes"]["fx_act1"]["script"] as Array).append({"id": "fan", "kind": "prank", "prank": "fan_mail", "req": false}))
	U.place_hush_at(w, "parlour_fan")
	var e := U.step(w, [SimCmd.rig(true)])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"why": "step_condition"}).is_empty(), "beryl_within is false without Beryl")


func test_spotted_while_rigging_pauses_ring_and_freezes() -> void:
	# Bellows brews tea at 2900 facing right; Hush rigs the honey at 2990 in front of him.
	var w := U.world_patched("fx_act1", U.loop_patch(["tea"], "kitchen", 2900))
	U.run(w, 3)
	U.place_hush_at(w, "kitchen_honey")
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.rig(true)]))
	log.append_array(U.run(w, 3))
	assert_false(U.first(log, SimEvents.RIG_PAUSE).is_empty(), "ring paused")
	assert_eq(w.hush.state, SimHush.FROZEN, "frozen mid-task")
	assert_true(w.hush.rig_held, "rig stays on")
	var pm := w.rig_progress_pm("achoo_ria")
	U.run(w, 10)
	assert_eq(w.rig_progress_pm("achoo_ria"), pm, "the ring does not fill while frozen")
	var e := U.step(w, [SimCmd.rig(false)])
	assert_false(U.first(e, SimEvents.FREEZE, {"on": false}).is_empty(), "releasing unfreezes")
	assert_eq(w.hush.state, SimHush.IDLE)
