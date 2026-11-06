## Meddle (GDD §5.6 "the house is a toybox"): a rig point with no prank tonight takes a Q hold and sits askew;
## Bellows stops to put it right when he walks toward it (a notice pause, +1 Applause the first time per prop,
## a little temper); tonight's props stay the Script's; `rules.meddle: false` turns it off; clone / hash cover it.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func test_meddle_hold_sets_a_free_prop_askew() -> void:
	var w := U.quiet_world()
	U.place_hush_at(w, "parlour_fan")
	var hs := w.hotspot_state("parlour_fan")
	assert_true(bool(hs["meddle"]), "a prop with no prank tonight can be fiddled with")
	assert_true(bool(hs["enabled"]))
	assert_false(bool(hs["meddled"]))
	assert_eq(str(w.action_context()["verb"]), "rig")
	assert_true(bool(w.action_context()["meddle"]))
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.rig(true)]))
	assert_false(U.first(log, SimEvents.MEDDLE_START, {"hotspot": "parlour_fan"}).is_empty())
	assert_eq(w.hush.state, SimHush.RIGGING)
	assert_eq(w.hush.rig_prank, -1)
	U.run(w, SimConst.PREP_Q / 2)
	assert_true(w.meddle_progress_pm() > 0 and w.meddle_progress_pm() < 1000)
	assert_eq(str(w.action_context()["verb"]), "rig", "the ring keeps the verb while she holds")
	log.append_array(U.run(w, SimConst.PREP_Q))
	assert_false(U.first(log, SimEvents.MEDDLED, {"hotspot": "parlour_fan"}).is_empty())
	assert_eq(w.hush.state, SimHush.IDLE)
	assert_eq(w.meddle_progress_pm(), 0)
	hs = w.hotspot_state("parlour_fan")
	assert_true(bool(hs["meddled"]))
	assert_false(bool(hs["meddle"]))
	assert_true(bool(hs["enabled"]))
	var e := U.step(w, [SimCmd.rig(true)])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"c": "rig", "why": "already_meddled"}).is_empty())
	U.step(w, [SimCmd.rig(false)])


func test_tonights_props_are_the_scripts_not_meddling() -> void:
	var w := U.quiet_world()
	# lift_off's second step lives at the newspaper; its first at the recliner: both are tonight's props
	U.place_hush_at(w, "parlour_newspaper")
	assert_false(bool(w.hotspot_state("parlour_newspaper")["meddle"]))
	var e := U.step(w, [SimCmd.rig(true)])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"c": "rig", "why": "nothing_to_rig"}).is_empty())
	U.step(w, [SimCmd.rig(false)])
	# a real rig clears any meddle bookkeeping
	U.place_hush_at(w, "parlour_recliner")
	U.step(w, [SimCmd.rig(true)])
	assert_eq(w.hush.meddle_hs, -1)
	assert_true(w.hush.rig_prank >= 0)
	U.step(w, [SimCmd.rig(false)])


func test_release_mid_hold_pauses_and_a_new_hold_restarts() -> void:
	var w := U.quiet_world()
	U.place_hush_at(w, "parlour_fan")
	U.step(w, [SimCmd.rig(true)])
	U.run(w, 10)
	var e := U.step(w, [SimCmd.rig(false)])
	assert_false(U.first(e, SimEvents.RIG_PAUSE, {"prank": ""}).is_empty(), "a meddle pause names no prank")
	assert_eq(w.hush.state, SimHush.IDLE)
	assert_false(w.meddle.is_askew(w.db.house.hotspot("parlour_fan").idx))
	var log: Array = U.step(w, [SimCmd.rig(true)])
	assert_false(U.first(log, SimEvents.MEDDLE_START).is_empty())
	log.append_array(U.run(w, SimConst.PREP_Q))
	assert_false(U.first(log, SimEvents.MEDDLED).is_empty())


func _fire_world() -> SimWorld:
	# warm-up at the gramophone (1640, facing left) then the fire (2330): he walks right past the chandelier (2400
	# sits 70 px beyond the fireplace, inside NOTICE_PX as he arrives). Hush starts behind his back at the chandelier.
	var w := U.world_patched("fx_act1", U.loop_patch(["warmup", "fire"], "parlour", 1640, "parlour", 2400))
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "warmup"}, 60)
	return w


func test_bellows_notices_an_askew_prop_on_his_way() -> void:
	var w := _fire_world()
	U.place_hush_at(w, "parlour_chandelier")
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.rig(true)]))
	log.append_array(U.run(w, SimConst.PREP_Q))
	assert_false(U.first(log, SimEvents.MEDDLED, {"hotspot": "parlour_chandelier"}).is_empty())
	assert_true(U.first(log, SimEvents.SPOT_START).is_empty(), "she fiddled behind his back")
	U.place_hush(w, "kitchen", 3500)
	var a0 := w.scoring.applause
	var t0 := w.bellows.temper_q
	var ev := U.run_until(w, SimEvents.NOTICE, {}, 1500, log)
	assert_false(ev.is_empty(), "he walks toward the fireplace and spots the askew chandelier")
	assert_eq(str(ev["hotspot"]), "parlour_chandelier")
	assert_eq(int(ev["variant"]), 0)
	assert_eq(int(ev["len"]), SimConst.NOTICE_TICKS)
	assert_eq(int(ev["score"]), SimConst.NOTICE_SCORE)
	assert_true(SimEvents.is_visible_beat(ev) or str(ev["vis"]) == "", "carries a beat visibility")
	assert_eq(w.bellows.path.current_kind(), NavPath.PAUSE)
	assert_eq(w.bellows.path.current_pause_aux(), NavPath.AUX_NOTICE)
	assert_eq(w.bellows.facing, 1, "he faces the prop")
	var os: Dictionary = w.bellows_oneshot()
	assert_eq(str(os["id"]), "notice")
	assert_eq(int(os["len"]), SimConst.NOTICE_TICKS)
	assert_eq(w.scoring.applause, a0 + SimConst.NOTICE_SCORE)
	assert_false(U.first(log, SimEvents.APPLAUSE, {"kind": "bit", "label": "notice"}).is_empty())
	assert_eq(w.bellows.temper_q, t0 + SimConst.GAIN_NOTICE * SimConst.TEMPER_Q)
	assert_false(bool(w.hotspot_state("parlour_chandelier")["meddled"]), "put right at once")
	assert_true(bool(w.hotspot_state("parlour_chandelier")["meddle"]), "and open to mischief again")
	# the stop lasts NOTICE_TICKS, then the walk resumes and the fire starts as usual
	U.run(w, SimConst.NOTICE_TICKS)
	U.run(w, 2)
	assert_ne(str(w.bellows_oneshot()["id"]), "notice")
	assert_false(U.run_until(w, SimEvents.B_ACTIVITY, {"id": "fire"}, 600, log).is_empty())
	assert_eq(U.find(log, SimEvents.NOTICE).size(), 1)


func test_second_notice_of_a_prop_pays_nothing_and_rotates_the_flavour() -> void:
	var w := _fire_world()
	U.place_hush(w, "kitchen", 3500)   # out of his sight: a chase would end the walk
	var idx := w.db.house.hotspot("parlour_chandelier").idx
	w.meddle.set_askew(w, idx)
	var log: Array = []
	var ev := U.run_until(w, SimEvents.NOTICE, {}, 1500, log)
	assert_eq(int(ev["score"]), SimConst.NOTICE_SCORE)
	assert_eq(int(ev["variant"]), 0)
	# back round the loop: warm-up again, then the walk to the fire
	U.run_until(w, SimEvents.B_ACTIVITY, {"id": "warmup"}, 3000, log)
	w.meddle.set_askew(w, idx)
	var a1 := w.scoring.applause
	ev = U.run_until(w, SimEvents.NOTICE, {}, 1500, log)
	assert_false(ev.is_empty())
	assert_eq(int(ev["score"]), 0, "a prop pays once per Night")
	assert_eq(int(ev["variant"]), 1, "the flavour rotates")
	assert_eq(w.scoring.applause, a1)


func test_rules_meddle_false_turns_it_off() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["radiator"], "landing", 1420).call(ep)
		ep["rules"]["meddle"] = false)
	assert_false(w.ctx.meddle)
	U.place_hush_at(w, "parlour_fan")
	assert_false(bool(w.hotspot_state("parlour_fan")["meddle"]))
	assert_false(bool(w.hotspot_state("parlour_fan")["enabled"]), "an inert prop again")
	var e := U.step(w, [SimCmd.rig(true)])
	assert_false(U.first(e, SimEvents.CMD_REJECTED, {"c": "rig", "why": "nothing_to_rig"}).is_empty())
	U.step(w, [SimCmd.rig(false)])


func test_clone_and_hash_cover_meddling() -> void:
	var w := U.quiet_world()
	U.place_hush_at(w, "parlour_fan")
	U.step(w, [SimCmd.rig(true)])
	U.run(w, 10)
	var c := w.clone()
	assert_eq(c.state_hash(), w.state_hash())
	U.run(w, SimConst.PREP_Q)
	assert_ne(c.state_hash(), w.state_hash(), "the askew prop is state")
	U.run(c, SimConst.PREP_Q)
	assert_eq(c.state_hash(), w.state_hash(), "the clone follows")
	assert_true(c.meddle.is_askew(w.db.house.hotspot("parlour_fan").idx))
