## Episode rules and content formats beyond the §4 core: Bellows' scripted exit (`bellows.exit`,
## `director.end`), `loop_repeat: false`, Hush's climb-in (`hush.enter`), `curtain_calls: false`,
## `nerves_temper`, nested `director.gates`, `safety_net.room / once`, `event_seen` with `after_s` /
## `count_ge`, the required-key prefilter and the event-only cue cache, `rearm_on_unseal` (scores once), `stand_in.rounds_f`,
## STEP `at` lists with `fire_at`, headbutt Double Act warnings.
extends TestBase

const U = preload("res://tests/sim/sim_test_util.gd")


func _acts(log: Array) -> Array:
	var out: Array = []
	for ev in U.find(log, SimEvents.B_ACTIVITY):
		out.append(str(ev["id"]))
	return out


func test_exit_after_an_activity_ends_the_night_at_the_door() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["paper", "rinse"], "parlour", 2080, "kitchen", 3850).call(ep)
		ep["bellows"]["exit"] = {"after": "paper", "to": {"room": "hall", "x": 1450}}
		ep["director"] = {"end": {"reason": "walked_out"}})
	assert_eq(w.ctx.exit_after, "paper")
	assert_eq(w.ctx.exit_room, w.room_idx("hall"))
	var log := U.run(w, 3000)
	assert_true(w.ended, "he walks out after the paper")
	assert_eq(w.end_reason, "walked_out")
	assert_eq(_acts(log), ["paper", "exit"], str(_acts(log)))
	var nxt := U.first(log, SimEvents.B_NEXT, {"id": "exit"})
	var end_paper := U.first(log, SimEvents.B_ACTIVITY_END, {"id": "paper"})
	assert_false(nxt.is_empty(), "the bubble shows the exit")
	assert_le(int(nxt["t"]), int(end_paper["t"]) + 1)
	assert_eq(w.room_id(w.bellows.room), "hall")
	assert_eq(w.bellows.x_sub, 1450 * SimConst.SUB)
	assert_eq(str(U.first(log, SimEvents.NIGHT_END)["reason"]), "walked_out")


func test_loop_repeat_false_exits_after_the_last_activity() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["paper", "clock"], "parlour", 2080, "kitchen", 3850).call(ep)
		ep["rules"]["loop_repeat"] = false
		ep["bellows"]["exit"] = {"to": {"room": "hall", "x": 700}})
	assert_false(w.ctx.loop_repeat)
	var log := U.run(w, 4000)
	assert_true(w.ended)
	assert_eq(_acts(log), ["paper", "clock", "exit"], str(_acts(log)))
	assert_eq(w.bellows.x_sub, 700 * SimConst.SUB)


func test_director_end_when_waits_for_its_condition_after_the_exit() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["paper", "rinse"], "parlour", 2080, "kitchen", 3850).call(ep)
		ep["bellows"]["exit"] = {"after": "paper", "to": {"room": "hall", "x": 1450}}
		ep["director"] = {"end": {"when": {"event_seen": {"event": "b_activity", "match": {"id": "exit"}, "after_s": 1.0}},
			"reason": "curtain"}})
	var log: Array = []
	var arrive := U.run_until(w, SimEvents.B_ACTIVITY, {"id": "exit"}, 3000, log)
	assert_false(arrive.is_empty())
	assert_false(w.ended, "end_when owns the end")
	var end := U.run_until(w, SimEvents.NIGHT_END, {}, 200, log)
	assert_eq(int(end["t"]) - int(arrive["t"]), 60, "after_s 1.0")
	assert_eq(str(end["reason"]), "curtain")


func test_hush_enter_is_busy_and_unseen_until_she_is_in() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["tea"], "kitchen", 2900, "kitchen", 3300).call(ep)
		ep["hush"]["enter"] = {"clip": "hush/act_climb_in", "at_s": 1.0, "busy_s": 0.5})
	assert_eq(w.ctx.hush_enter_ticks, 90)
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.squeak()]))
	assert_false(U.first(log, SimEvents.CMD_REJECTED, {"c": "squeak", "why": "entering"}).is_empty())
	assert_true(w.hush.is_busy())
	log.append_array(U.step(w, [SimCmd.move("kitchen", 3500)]))
	assert_true(U.first(log, SimEvents.CMD_REJECTED, {"c": "move"}).is_empty(), "go / move queue up")
	var x0 := w.hush.x_sub
	log.append_array(U.run(w, 80))
	assert_eq(w.hush.x_sub, x0, "she doesn't move while climbing in")
	assert_true(U.first(log, SimEvents.SPOT_START).is_empty(), "unseen while climbing in, facing him")
	U.run_until_pred(w, func(x: SimWorld) -> bool: return x.tick >= 90, 20, log)
	log.append_array(U.run(w, 30))
	assert_false(w.hush.entering)
	assert_gt(w.hush.x_sub, x0, "the queued move runs once she is in")


func test_curtain_calls_false_awards_no_stars() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["pickles", "tea", "paper", "rinse"], "kitchen", 3130, "hall", 600).call(ep)
		ep["rules"]["curtain_calls"] = false)
	assert_true(w.ctx.no_stars)
	for p in ["in_a_pickle", "kettle_drum", "achoo_ria", "tap_dance", "lift_off"]:
		U.force_rig(w, p)
	var log := U.run(w, 4000)
	assert_false(U.first(log, SimEvents.ALL_LINES_DONE).is_empty())
	assert_true(U.first(log, SimEvents.STAR).is_empty())
	assert_eq(w.stars(), [false, false, false])


func test_nerves_temper_sets_each_loops_start() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		ep["rules"]["nerves"] = true
		ep["rules"]["nerves_temper"] = 30
		ep["hush"]["start"] = {"room": "hall", "x": 600}
		ep["bellows"]["loop"] = [{"a": "tea"}, {"a": "pickles"}])
	assert_eq(w.ctx.nerves_q, 30 * SimConst.TEMPER_Q)
	assert_eq(w.bellows.temper_q, 30 * SimConst.TEMPER_Q, "each loop starts at the floor")
	var wraps := 0
	for i in 6000:
		var lc := w.routine.loop_count
		w.step([])
		w.drain_events()
		if w.routine.loop_count != lc:
			wraps += 1
			assert_eq(w.bellows.temper_q, 30 * SimConst.TEMPER_Q, "raised back to 30 at the wrap")
	assert_ge(wraps, 1)


func test_director_gates_merge_into_the_loop() -> void:
	var files := U.raw()
	var ep: Dictionary = files["episodes"]["fx_act1"]
	var gate: Dictionary = ep["bellows"]["loop"][0]["gate"]
	(ep["bellows"]["loop"][0] as Dictionary).erase("gate")
	ep["director"] = {"gates": [{"loop": 0, "gate": gate}, {"loop": 2, "until": "first_squeak", "max_s": 5}]}
	var db := U.db_from(files)
	assert_eq(db.errors, PackedStringArray())
	var e: EpisodeDef = db.episodes["fx_act1"]
	var ref: EpisodeDef = U.db().episodes["fx_act1"]
	assert_true(e.loop[0].has_gate)
	assert_eq(e.loop[0].until, ref.loop[0].until)
	assert_eq(e.loop[0].plus_ticks, ref.loop[0].plus_ticks)
	assert_eq(e.loop[0].max_ticks, ref.loop[0].max_ticks)
	assert_eq(e.loop[0].first_loop_only, ref.loop[0].first_loop_only)
	assert_false(e.loop[1].has_gate)
	assert_true(e.loop[2].has_gate)
	assert_eq(e.loop[2].max_ticks, 300)


func test_safety_net_room_and_once() -> void:
	# limited to the parlour: no net for the kitchen entry
	var w := U.world_patched("fx_prologue", func(ep: Dictionary) -> void:
		ep["director"]["safety_net"]["room"] = "parlour")
	var log: Array = []
	log.append_array(U.step(w, [SimCmd.squeak()]))
	U.walk_to(w, "kitchen_honey", 600, log)
	U.rig_hold(w, 100, log)
	log.append_array(U.run(w, 800))
	assert_true(U.first(log, SimEvents.SAFETY_NET).is_empty(), "room-limited")
	# once: on → off, then never again
	w = U.world_patched("fx_prologue", func(ep: Dictionary) -> void:
		ep["director"]["safety_net"]["once"] = true)
	log = []
	log.append_array(U.step(w, [SimCmd.squeak()]))
	U.walk_to(w, "kitchen_honey", 600, log)
	U.rig_hold(w, 100, log)
	assert_false(U.run_until(w, SimEvents.SAFETY_NET, {"on": true}, 800, log).is_empty())
	log.append_array(U.step(w, [SimCmd.go("kitchen_pantry_curtain", true)]))
	assert_false(U.run_until(w, SimEvents.SAFETY_NET, {"on": false}, 200, log).is_empty())
	assert_true(w.director.safety_used)
	log.append_array(U.step(w, [SimCmd.pop_out(false)]))
	log.append_array(U.run(w, 3000))
	assert_eq(U.find(log, SimEvents.SAFETY_NET).size(), 2, "one use only")


func test_event_seen_after_s_and_count_ge() -> void:
	var w := U.quiet_world()
	var twice := {"event_seen": {"event": "b_detour", "match": {"kind": "fixup_dry"}, "count_ge": 2}}
	var later := {"event_seen": {"event": "b_detour", "match": {"kind": "fixup_dry"}, "after_s": 1.0}}
	var legacy := {"event_seen": {"e": "b_detour", "kind": "fixup_dry"}}
	assert_false(Conditions.eval(w, twice))
	w.emit(SimEvents.B_DETOUR, {"kind": "fixup_dry", "station": "st_fireplace", "why": "SOAKED"})
	assert_true(Conditions.eval(w, legacy), "extra fields match like `match`")
	assert_false(Conditions.eval(w, later))
	assert_false(Conditions.eval(w, twice))
	U.run(w, 59)
	assert_false(Conditions.eval(w, later))
	U.run(w, 1)
	assert_true(Conditions.eval(w, later), "60 ticks after the first")
	w.emit(SimEvents.B_DETOUR, {"kind": "fixup_sink", "station": "st_sink", "why": "SOAKED"})
	assert_false(Conditions.eval(w, twice), "a different kind doesn't count")
	w.emit(SimEvents.B_DETOUR, {"kind": "fixup_dry", "station": "st_fireplace", "why": "SOAKED"})
	assert_true(Conditions.eval(w, twice))
	assert_eq(Conditions.validate(twice), PackedStringArray())
	assert_eq(Conditions.validate(later), PackedStringArray())
	assert_false(legacy["event_seen"].has("match"), "evaluation never mutates content")


func test_required_seen_keys_prefilter() -> void:
	var c := {"and": [{"event_seen": {"event": "b_activity_end", "match": {"id": "hunt"}}},
		{"not": {"event_seen": {"event": "spotted", "match": {}}}}, {"bellows_in_room": "hall"}]}
	assert_eq(Conditions.required_seen_keys(c), PackedStringArray(["b_activity_end", "b_activity_end|id=hunt"]))
	assert_eq(Conditions.required_seen_keys({"or": [{"event_seen": "squeak"}, {"first_rig": true}]}), PackedStringArray())
	assert_eq(Conditions.required_seen_keys({"event_ago_ge_s": ["rigged", {"prank": "achoo_ria"}, 2.0]}),
		PackedStringArray(["rigged", "rigged|prank=achoo_ria"]))
	assert_eq(Conditions.required_seen_keys({"event_seen": ["squeak", {"n": 2.0}]}), PackedStringArray(["squeak", "squeak|n=2"]))
	assert_false(Conditions.is_event_only(c), "bellows_in_room reads state")
	assert_true(Conditions.is_event_only({"and": [{"event_seen": {"event": "b_activity_end", "match": {"id": "warmup"}, "count_ge": 2}},
		{"not": {"event_seen": "spotted"}}]}))
	assert_false(Conditions.is_event_only({"event_seen": {"event": "director_cue", "after_s": 4.0}}), "after_s reads the tick")
	assert_false(Conditions.is_event_only("first_squeak"))
	var w := U.world("fx_prologue")
	assert_eq(w.ctx.cue_req.size(), w.ctx.cues.size())
	assert_eq(w.ctx.cue_event_only.size(), w.ctx.cues.size())
	var saw := false
	for i in w.ctx.cues.size():
		if (w.ctx.cues[i] as Dictionary).get("id", "") == "ghost_honey":
			assert_eq(w.ctx.cue_req[i], PackedStringArray(["squeak"]))
			saw = true
	assert_true(saw)


func test_rearm_on_unseal_and_a_gag_scores_once() -> void:
	var w := U.world_patched("fx_act1", func(ep: Dictionary) -> void:
		U.loop_patch(["tea", "pickles", "rinse"], "kitchen", 2900, "hall", 600).call(ep)
		for l in ep["script"]:
			if l["id"] == "bn":
				l["rearm_on_unseal"] = ["achoo_ria", "tap_dance"])
	var ach := w.db.prank_idx("achoo_ria")
	U.force_rig(w, "achoo_ria")
	U.force_rig(w, "tap_dance")
	var log := U.run(w, 1200)
	assert_eq(w.pranks.state[ach], Pranks.LANDED)
	assert_eq(U.find(log, SimEvents.APPLAUSE, {"label": "ACHOO-RIA!"}).size(), 1)
	U.force_rig(w, "kettle_drum")
	U.force_rig(w, "in_a_pickle")
	var un := U.run_until(w, SimEvents.BIG_NUMBER_UNSEALED, {}, 6000, log)
	assert_false(un.is_empty())
	assert_eq(w.pranks.state[ach], Pranks.AVAILABLE, "re-armed for the Big Number")
	assert_eq(w.pranks.step[ach], 0)
	assert_eq(w.prank_state("tap_dance"), Pranks.AVAILABLE)
	assert_eq(w.prank_state("kettle_drum"), Pranks.LANDED, "only the listed pranks")
	U.force_rig(w, "achoo_ria")
	var again := U.run_until(w, SimEvents.REACTION_ACCENT, {"prank": "achoo_ria"}, 6000, log)
	assert_false(again.is_empty(), "fires again")
	U.run(w, 2)
	assert_eq(U.find(log, SimEvents.APPLAUSE, {"label": "ACHOO-RIA!"}).size(), 1, "the gag scores once a Night")


func test_stand_in_rounds_from_content() -> void:
	var w := U.world_patched("fx_meltdown", U.loop_patch(["mirror", "warmup"], "hall", 1080, "hall", 1240), {},
		func(files: Dictionary) -> void:
			files["pranks"]["pranks"]["mirror_mirror"]["stand_in"] = {"rounds_f": [30, 40, 50], "poke_window_f": 20})
	assert_eq(w.db.prank_list[w.db.prank_idx("mirror_mirror")].stand_rounds, PackedInt32Array([30, 40, 50]))
	U.force_rig(w, "mirror_mirror")
	U.place_hush(w, "hall", 1240)
	U.step(w, [SimCmd.freeze(true)])
	var log: Array = []
	var r1 := U.run_until(w, SimEvents.MIRROR_ROUND, {"round": 1}, 60, log)
	var r2 := U.run_until(w, SimEvents.MIRROR_ROUND, {"round": 2}, 100, log)
	var r3 := U.run_until(w, SimEvents.MIRROR_ROUND, {"round": 3}, 100, log)
	var f2f := U.run_until(w, SimEvents.FACE_TO_FACE, {}, 100, log)
	assert_eq(int(r2["t"]) - int(r1["t"]), 30)
	assert_eq(int(r3["t"]) - int(r2["t"]), 40)
	assert_eq(int(f2f["t"]) - int(r3["t"]), 50)


func test_step_trigger_at_list_fires_at_fire_at() -> void:
	var files := U.raw()
	var rug: Dictionary = files["pranks"]["pranks"]["rug_burn"]
	rug["trigger"]["at"] = ["hall_clock", "stairs_foot"]
	rug["trigger"]["fire_at"] = "stairs_foot"
	var db := U.db_from(files)
	assert_eq(db.errors, PackedStringArray())
	var pd := db.prank_list[db.prank_idx("rug_burn")]
	assert_eq(pd.trig_at_list, PackedStringArray(["hall_clock", "stairs_foot"]))
	assert_eq(pd.trig_at, "stairs_foot")
	rug["trigger"]["at"] = ["hall_clock", "nowhere"]
	rug["trigger"].erase("fire_at")
	db = U.db_from(files)
	assert_eq(db.errors, PackedStringArray(["pranks.json: rug_burn.trigger.at 'nowhere' not in house.json"]))


func test_headbutt_double_act_is_a_warning() -> void:
	var files := U.raw()
	files["pranks"]["double_acts"]["up_in_smoke"]["headbutt"] = true
	var db := U.db_from(files)
	assert_eq(db.errors, PackedStringArray())
	assert_true(_has_msg(db.warnings, "double_acts.up_in_smoke is a Stage-3 headbutt Double Act"), str(db.warnings))


func _has_msg(msgs: PackedStringArray, part: String) -> bool:
	for m in msgs:
		if m.contains(part):
			return true
	return false
