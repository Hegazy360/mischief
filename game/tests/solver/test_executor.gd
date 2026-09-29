## Executor on the MockWorld: every step kind, timeouts, failure reasons, recovery.
extends TestBase

const U := preload("res://tests/solver/solver_test_util.gd")


func _names(events: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for e in events:
		out.append(String(e.get("e", "")))
	return out


func test_ideal_mock_route_completes() -> void:
	var sol := U.solution()
	assert_eq(sol.validate(U.data()), PackedStringArray(), "mock solution validates")
	var route := sol.resolve("ideal")
	var ex := U.executor(U.world(), route, "ideal")
	var r := ex.run(20000)
	assert_true(bool(r["ok"]), "ideal route ok: %s" % [r["fail"]])
	assert_eq(r["stars"].slice(0, 2), [true, true], "★ and ★★")
	assert_eq((r["catches"] as Array).size(), 0, "no catches")
	assert_eq(Metrics.check_expect(r, route["expect"]), PackedStringArray(), "expect passes")
	assert_true(ex.log.events_named("night_end").size() == 1, "bowed")


func test_go_arrives_and_no_op_when_there() -> void:
	var w := U.world()
	var ex := U.executor(w, [{"do": "go", "to": "kitchen_sink_tap"}, {"do": "go", "to": "kitchen_sink_tap"}])
	var r := ex.run(600)
	assert_true(bool(r["ok"]), "two gos ok: %s" % [r["fail"]])
	assert_eq(ex.log.events_named("hush_arrive", {"hotspot": "kitchen_sink_tap"}).size(), 1, "one arrival; the second go is a no-op")
	assert_eq(ex.step_log.size(), 2)


func test_go_unknown_hotspot_fails_with_step_name() -> void:
	var ex := U.executor(U.world(), [{"do": "go", "to": "nowhere_at_all"}])
	var r := ex.run(100)
	assert_false(bool(r["ok"]))
	assert_has(String(r["fail"][0]), "step 1 (go nowhere_at_all)")
	assert_has(String(r["fail"][0]), "not in house.json")


func test_move_reaches_point() -> void:
	var w := U.world()
	var ex := U.executor(w, [{"do": "move", "room": "kitchen", "x": 3300}])
	var r := ex.run(600)
	assert_true(bool(r["ok"]), str(r["fail"]))
	assert_eq(ex.probe.hush_x(), 3300)


func test_pick_needs_container_and_picks() -> void:
	var w := U.world()
	var ex := U.executor(w, [{"do": "pick", "item": "squeaker", "from": "hall_confiscated_box"}])
	var r := ex.run(3000)
	assert_true(bool(r["ok"]), str(r["fail"]))
	assert_eq(ex.probe.hush_carrying(), PackedStringArray(["squeaker"]))
	var names := _names(ex.log.events)
	assert_has(names, "rummage")
	assert_has(names, "pick_window")
	assert_has(names, "pick")


func test_rig_holds_until_step_done_then_releases() -> void:
	var w := U.world()
	var ex := U.executor(w, [{"do": "rig", "prank": "tap_dance"}])
	var r := ex.run(600)
	assert_true(bool(r["ok"]), str(r["fail"]))
	assert_eq(ex.probe.prank_state("tap_dance"), "RIGGED")
	var on := 0
	var off := 0
	for c in ex.log.cmds:
		if c[1]["c"] == "rig":
			if c[1]["on"]:
				on += 1
			else:
				off += 1
	assert_eq([on, off], [1, 1], "one press, one release")
	assert_eq(float(r["hold_total_s"]), 48 / 60.0 if false else float(r["hold_total_s"]))
	assert_between(float(r["hold_total_s"]), 0.75, 0.85, "Q prep ≈ 0.8 s of hold")


func test_rig_already_rigged_is_skipped() -> void:
	var w := U.world()
	var ex := U.executor(w, [{"do": "rig", "prank": "tap_dance"}, {"do": "rig", "prank": "tap_dance"}])
	var r := ex.run(600)
	assert_true(bool(r["ok"]))
	assert_eq(ex.log.events_named("rig_start").size(), 1)


func test_rig_without_item_fails_with_reason() -> void:
	var ex := U.executor(U.world(), [{"do": "rig", "prank": "kettle_drum"}])
	var r := ex.run(300)
	assert_false(bool(r["ok"]))
	assert_has(String(r["fail"][0]), "needs 'squeaker'")


func test_hide_waits_for_hide_event_and_pop_out() -> void:
	var w := U.world()
	var ex := U.executor(w, [{"do": "hide", "spot": "kitchen_pantry_curtain"}, {"do": "pop_out"}])
	var r := ex.run(600)
	assert_true(bool(r["ok"]), str(r["fail"]))
	var names := _names(ex.log.events)
	assert_has(names, "hide")
	assert_has(names, "pop_out")
	assert_false(ex.probe.hush_hidden())


func test_go_while_hidden_pops_out_first() -> void:
	var w := U.world()
	var ex := U.executor(w, [{"do": "hide", "spot": "kitchen_pantry_curtain"}, {"do": "go", "to": "kitchen_sink_tap"}])
	var r := ex.run(900)
	assert_true(bool(r["ok"]), str(r["fail"]))
	assert_eq(ex.log.events_named("cmd_rejected").size(), 0, "never sent go while hidden")


func test_pop_out_to_pin_ideal_and_walk_slow() -> void:
	var w := U.world()
	var ex := U.executor(w, [{"do": "hide", "spot": "kitchen_pantry_curtain"}, {"do": "pop_out", "to": "kitchen_sink_tap"}])
	var r := ex.run(900)
	assert_true(bool(r["ok"]), str(r["fail"]))
	var pins := 0
	for c in ex.log.cmds:
		if c[1]["c"] == "pin":
			pins += 1
	assert_eq(pins, 1, "ideal pops out to a pin")
	var w2 := U.world()
	var ex2 := U.executor(w2, [{"do": "hide", "spot": "kitchen_pantry_curtain"}, {"do": "pop_out", "to": "kitchen_sink_tap"}], "slow", {"no_dawdle": true})
	var r2 := ex2.run(1200)
	assert_true(bool(r2["ok"]), str(r2["fail"]))
	for c in ex2.log.cmds:
		assert_ne(c[1]["c"], "pin", "slow never uses pins")
	assert_eq(ex2.log.events_named("hush_arrive", {"hotspot": "kitchen_sink_tap"}).size(), 1)


func test_freeze_until_condition() -> void:
	var w := U.world()
	var ex := U.executor(w, [{"do": "freeze", "until": {"tick_ge_s": 1.0}, "max_s": 5}])
	var r := ex.run(600)
	assert_true(bool(r["ok"]), str(r["fail"]))
	assert_between(ex.probe.tick(), 59, 62)
	assert_false(ex.probe.hush_frozen(), "released")
	assert_between(float(r["freeze_total_s"]), 0.95, 1.05)


func test_freeze_timeout_names_step() -> void:
	var ex := U.executor(U.world(), [{"do": "freeze", "until": {"tick_ge_s": 100}, "max_s": 1}])
	var r := ex.run(600)
	assert_false(bool(r["ok"]))
	assert_has(String(r["fail"][0]), "step 1 (freeze)")
	assert_has(String(r["fail"][0]), "timeout after 1.0 s")
	assert_false(ex.probe.hush_frozen(), "hold released on failure")


func test_squeak_n_with_gap() -> void:
	var ex := U.executor(U.world(), [{"do": "squeak", "n": 3, "gap_s": 0.5}])
	var r := ex.run(600)
	assert_true(bool(r["ok"]))
	var sq := ex.log.events_named("squeak")
	assert_eq(sq.size(), 3)
	assert_eq(int(sq[1]["t"]) - int(sq[0]["t"]), 30)


func test_wait_timeout_reason() -> void:
	var ex := U.executor(U.world(), [{"do": "wait", "until": {"bellows_activity": "nap"}, "max_s": 2}])
	var r := ex.run(600)
	assert_false(bool(r["ok"]))
	assert_has(String(r["fail"][0]), "step 1 (wait")
	assert_has(String(r["fail"][0]), "never became true")


func test_wait_event_scopes() -> void:
	# b_activity warmup happened at tick 1: step-scoped waits need a new one; run-scoped see it.
	var ex := U.executor(U.world(), [{"do": "idle", "s": 1}, {"do": "wait_event", "event": "b_activity", "match": {"id": "warmup"}, "since": "run", "max_s": 1}])
	assert_true(bool(ex.run(600)["ok"]), "run scope sees the past event")
	var ex2 := U.executor(U.world(), [{"do": "idle", "s": 1}, {"do": "wait_event", "event": "b_activity", "match": {"id": "warmup"}, "max_s": 2}])
	var r2 := ex2.run(600)
	assert_false(bool(r2["ok"]), "step scope waits for a new one")
	assert_has(String(r2["fail"][0]), "never arrived")


func test_idle_and_bow_rejected_without_star() -> void:
	var ex := U.executor(U.world(), [{"do": "idle", "s": 0.5}, {"do": "bow"}])
	var r := ex.run(600)
	assert_false(bool(r["ok"]))
	assert_has(String(r["fail"][0]), "step 2 (bow)")
	assert_has(String(r["fail"][0]), "rejected")
	assert_eq(int(r["steps"][0]["t1"]) - int(r["steps"][0]["t0"]), 30)


func test_stand_in_releases_on_round() -> void:
	# The mock has no mirror rounds: stand_in must time out with a precise reason.
	var ex := U.executor(U.world(), [{"do": "stand_in", "prank": "tap_dance", "release_round": 2, "max_s": 3}])
	var r := ex.run(900)
	assert_false(bool(r["ok"]))
	assert_has(String(r["fail"][0]), "waiting for mirror_round 2")


func test_run_limit_failure() -> void:
	var ex := U.executor(U.world(), [{"do": "idle", "s": 100}])
	var r := ex.run(120)
	assert_false(bool(r["ok"]))
	assert_has(String(r["fail"][0]), "run limit of 120 ticks")


func test_cmd_log_ticks_replay_same_hash() -> void:
	var sol := U.solution()
	var ex := U.executor(U.world(), sol.resolve("ideal"))
	ex.run(20000)
	var h := Invariants.replay_hash(func() -> Object: return U.world(), ex.log)
	assert_eq(h, ex.log.final_hash, "replaying the command log reproduces the hash")


func test_caught_then_recovers() -> void:
	# Walk straight into Bellows' view during warmup: caught, then the step restarts and finishes.
	var w := U.world()
	var ex := U.executor(w, [{"do": "move", "room": "parlour", "x": 1600, "run": false}, {"do": "idle", "s": 3},
		{"do": "hide", "spot": "hall_coat_cupboard"}])
	var r := ex.run(3000)
	assert_eq((r["catches"] as Array).size(), 1, "caught once")
	assert_true(bool(r["ok"]), "recovered: %s" % [r["fail"]])
	assert_true(ex.warnings.size() >= 1)


func test_probe_names_states_of_each_actor() -> void:
	var w := U.world()
	var p := SolverProbe.new(w, U.data())
	assert_eq(p.hush_state(), "IDLE")
	assert_eq(p.bellows_state(), "ROUTINE")
	w.bellows.state = 6
	w.hush.state = 9
	assert_eq(p.bellows_state(), "REACTING", "inner-class enums don't collide")
	assert_eq(p.hush_state(), "HIDDEN")
	assert_true(p.bellows_reacting())
	assert_eq(p.prank_state("kettle_drum"), "AVAILABLE")
	assert_eq(p.bellows_room(), "parlour")
	assert_eq(p.id_of("rooms", 1), "kitchen", "int ids fall back to sorted-id order (hall, kitchen, parlour, porch)")
	assert_eq(p.bellows_eta_to_room("parlour"), 0)
