## Fuzz bots on the MockWorld: deterministic per seed, invariants green, replay and soft-lock probe.
extends TestBase

const U := preload("res://tests/solver/solver_test_util.gd")


func _factory() -> Callable:
	return func() -> Object: return U.world()


func test_every_bot_runs_fair_on_the_mock() -> void:
	for bot in Fuzz.BOTS:
		var r := Fuzz.run_bot(_factory(), U.data(), "mock_ep", bot, 3, {"ticks": 3600, "probe": false, "replay": true})
		assert_true(bool(r["ok"]), "%s: %s" % [bot, "\n".join(PackedStringArray(r["invariants"]))])
		assert_gt(int(r["commands"]), 3, "%s issued commands" % bot)
		assert_eq((r["log"] as SolverLog).replay_hash, (r["log"] as SolverLog).final_hash, "%s replays deterministically" % bot)


func test_same_seed_same_run() -> void:
	var a := Fuzz.run_bot(_factory(), U.data(), "mock_ep", "random", 11, {"ticks": 2400, "probe": false})
	var b := Fuzz.run_bot(_factory(), U.data(), "mock_ep", "random", 11, {"ticks": 2400, "probe": false})
	var c := Fuzz.run_bot(_factory(), U.data(), "mock_ep", "random", 12, {"ticks": 2400, "probe": false})
	assert_eq(int(a["hash"]), int(b["hash"]))
	assert_eq(int(a["commands"]), int(b["commands"]))
	assert_ne(int(a["hash"]), int(c["hash"]), "another seed plays differently")


func test_bait_gets_caught_and_reckless_rigs() -> void:
	var bait := Fuzz.run_bot(_factory(), U.data(), "mock_ep", "bait", 1, {"ticks": 3600, "probe": false})
	assert_gt(int(bait["catches"]), 0, "bait gets itself caught")
	assert_true(bool(bait["ok"]), "\n".join(PackedStringArray(bait["invariants"])))
	var reck := Fuzz.run_bot(_factory(), U.data(), "mock_ep", "reckless", 1, {"ticks": 3600, "probe": false})
	var lg: SolverLog = reck["log"]
	assert_gt(lg.events_named("rig_step_done").size(), 0, "reckless rigs pranks")


func test_softlock_probe_runs_planner() -> void:
	var r := Fuzz.run_bot(_factory(), U.data(), "mock_ep", "hider", 5, {"ticks": 1200, "probe": true, "probe_budget_ms": 20000})
	var sl: Dictionary = r["softlock"]
	assert_false(bool(sl.get("skipped", true)), "probe ran")
	assert_true(bool(sl["ok"]), str(sl))
	assert_eq((r["log"] as SolverLog).softlock_probes.size(), 1)


func test_invariants_catch_an_unfair_world() -> void:
	# A world that ambushes: strip every entry_warning from the stream.
	var w: Object = U.world()
	var ex := U.executor(w, [{"do": "move", "room": "kitchen", "x": 3300}, {"do": "wait", "until": {"bellows_activity": "rinse"}, "max_s": 60}])
	ex.run(4000)
	var kept: Array = []
	for ev in ex.log.events:
		if String(ev["e"]) != "entry_warning":
			kept.append(ev)
	ex.log.events = kept
	var bad := Invariants.check(ex.log)
	var found := false
	for v in bad:
		if v.begins_with("rule 2"):
			found = true
	assert_true(found, "rule 2 flags the ambush: %s" % "\n".join(PackedStringArray(bad)))


func test_summary_line() -> void:
	var s := Fuzz.summary_line({"episode": "n01", "bot": "random", "seed": 3, "ok": false, "ticks": 600, "commands": 9,
		"catches": 1, "near_misses": 2, "laughs": 3, "invariants": ["rule 2: x", "rule 7: y"]})
	assert_eq(s, "[fuzz] n01 random seed=3 FAIL 10.0 s, 9 cmds, 1 catches, 2 near misses, 3 laughs — rule 2: x (+1)")
