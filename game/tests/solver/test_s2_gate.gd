## s2-sim §4.2–§4.5 on the solver side: the D1 dead-air gate (visible micro-gag beats keep a hidden wait alive,
## invisible ones don't), the ⏩ persona model (a drop mid-wait, the re-press delay, the slow persona before / after
## `ghost_ff`), `alive_by` / `beats.edge_share`, expect-key semantics (aliases, `warn_` keys, `events_min/max`),
## `--baseline` (new failure / still failing / fixed), invariant 9 with `cmd_queued`, invariant 2's exemptions, the
## no-combo invariant 12, the `scenario` persona, and `--dump-cmds` round trips (solver and fuzz dumps replay to
## the same hash through SimReplay, the code sim_run uses).
extends TestBase

const SIM_FIX := "res://tests/sim/fixtures"


## A log of `n` ticks: `hidden_from` (tick, 0 = never) on, input at the given ticks, the given events.
func _log(n: int, events: Array, hidden_from: int = 0, input_ticks: Array = [1], reacting: Array = []) -> SolverLog:
	var lg := SolverLog.new()
	lg.start_tick = 0
	var inp := {}
	for t in input_ticks:
		inp[int(t)] = true
	var rea := {}
	for pair in reacting:
		for t in range(int(pair[0]), int(pair[1]) + 1):
			rea[t] = true
	for t in range(1, n + 1):
		lg.add_sample(t, {"input": inp.has(t), "reacting": rea.has(t), "hidden": "kitchen_pantry_curtain" if hidden_from > 0 and t >= hidden_from else "",
			"hush_room": "kitchen"})
	lg.events = events
	return lg


func _beats(every: int, n: int, vis: String) -> Array:
	var out: Array = []
	var t := every
	while t <= n:
		out.append({"e": "micro_gag", "t": t, "id": "hum", "activity": "tea", "room": "kitchen", "x": 2900, "len": 48,
			"emote": "hum", "vis": vis})
		t += every
	return out


# --- the dead-air mask -------------------------------------------------------------------------------------

func test_visible_beats_keep_a_wait_alive_and_invisible_ones_do_not() -> void:
	var n := 1800
	var quiet := Metrics.compute(_log(n, []), SolverHooks.fallback_is_laugh)
	assert_almost_eq(float(quiet["dead_air_sim_pct"]), 100.0 * (n - 300) / n, 0.1, "input at 1, then nothing")
	for vis in ["room", "pip", "edge"]:
		var r := Metrics.compute(_log(n, _beats(300, n, vis)), SolverHooks.fallback_is_laugh)
		assert_eq(float(r["dead_air_sim_pct"]), 0.0, "a %s beat every 5 s keeps it alive" % vis)
		assert_eq(int(r["beats"][vis]), 6)
	var hid := Metrics.compute(_log(n, _beats(300, n, "")), SolverHooks.fallback_is_laugh)
	assert_almost_eq(float(hid["dead_air_sim_pct"]), float(quiet["dead_air_sim_pct"]), 0.01, "an invisible beat does not count")
	assert_eq(int(hid["beats"]["hidden"]), 6)
	assert_eq(int(hid["beats"]["total"]), 6)
	# a beat every 6 s leaves 1 s dead per gap after the 5 s window
	var sparse := Metrics.compute(_log(n, _beats(360, n, "room")), SolverHooks.fallback_is_laugh)
	assert_gt(float(sparse["dead_air_sim_pct"]), 0.0)
	var mask := Metrics.dead_air_mask(_log(n, _beats(300, n, "pip")), SolverHooks.fallback_is_laugh)
	assert_eq(Array(mask).count(1), 0)
	assert_false(SolverHooks.fallback_is_laugh({"e": "micro_gag", "vis": "room"}), "never a laugh")


func test_gap_resets_on_visible_beats_only() -> void:
	var r := Metrics.compute(_log(1200, _beats(240, 1200, "edge")), SolverHooks.fallback_is_laugh)
	assert_almost_eq(float(r["max_gap_sim_s"]), 239 / 60.0, 0.02)
	var r2 := Metrics.compute(_log(1200, _beats(240, 1200, "")), SolverHooks.fallback_is_laugh)
	assert_almost_eq(float(r2["max_gap_sim_s"]), 1199 / 60.0, 0.02)


func test_alive_by_sums_to_the_live_share_and_edge_share() -> void:
	var evs := _beats(300, 2400, "edge")
	for ev in _beats(600, 2400, "room"):
		ev["t"] = int(ev["t"]) + 150
		evs.append(ev)
	evs.append({"e": "reaction_accent", "t": 1000, "prank": "x"})
	evs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["t"]) < int(b["t"]))
	var r := Metrics.compute(_log(2400, evs, 0, [1, 50], [[1500, 1560]]), SolverHooks.fallback_is_laugh)
	var ab: Dictionary = r["alive_by"]
	var sum := 0.0
	for k in Metrics.ALIVE_REASONS:
		sum += float(ab[k])
	assert_almost_eq(sum, 100.0 - float(r["dead_air_ff_pct"]), 0.35, "alive_by + dead = 100 %%: %s" % [ab])
	assert_gt(float(ab["input"]), 0.0)
	assert_gt(float(ab["laugh"]), 0.0)
	assert_gt(float(ab["reacting"]), 0.0)
	assert_gt(float(ab["beat_room"]), 0.0)
	assert_gt(float(ab["beat_edge"]), 0.0)
	var es := float(r["beats"]["edge_share"])
	var credit := float(ab["beat_room"]) + float(ab["beat_pip"]) + float(ab["beat_edge"])
	assert_almost_eq(es, float(ab["beat_edge"]) / credit, 0.01)
	var pf := Metrics.pregate_fail({"beats": {"edge_share": 0.5}, "persona": "ideal"}, {})
	assert_has(pf[0], "edge beats carry 50 %")
	assert_eq(Metrics.pregate_fail({"beats": {"edge_share": 0.33}, "persona": "ideal"}, {}), PackedStringArray())
	assert_eq(Metrics.pregate_fail({"beats": {"edge_share": 0.9}, "persona": "scenario"}, {}), PackedStringArray(), "scenarios exempt")
	assert_has(Metrics.pregate_fail({}, {"warn_dead_air_pct_max": 20})[0], "still a warn_ key")
	var line := Metrics.summary_line({"episode": "e", "route": "ideal", "ok": true, "beats": {"edge_share": 0.5}})
	assert_has(line, "\u001b[31m0.50\u001b[0m", "edge share printed red above 1/3")


# --- the ⏩ persona model -------------------------------------------------------------------------------------

func test_ff_latches_after_the_repress_delay_and_drops_on_ff_events() -> void:
	# hidden the whole time, nothing happening: every tick is dead; the latch decides the weights
	var n := 600
	var lg := _log(n, [], 1)
	lg.ff_repress_ticks = 30
	var r := Metrics.compute(lg, SolverHooks.fallback_is_laugh)
	# ×1 for ticks 1..30 (the press delay), then ×1/3: 30 + 570/3 = 220 real ticks
	assert_almost_eq(float(r["real_time_ff_s"]), (30 * 3 + 570) / 3 / 60.0, 0.02)
	assert_almost_eq(float(r["ff_s"]), 570 / 60.0, 0.02, "latched ticks")
	assert_almost_eq(float(r["real_time_ff_naive_s"]), 200 / 60.0, 0.02, "naive: every hidden tick 1/3")
	# a prank_fire at 300 drops it: ×1 again for 300..329
	var lg2 := _log(n, [{"e": "prank_fire", "t": 300, "prank": "x", "trigger": "use"}], 1)
	lg2.ff_repress_ticks = 30
	var m := Metrics.ff_mask(lg2, SolverHooks.fallback_is_laugh)
	assert_eq(int(m[28]), 0, "tick 29: still pressing")
	assert_eq(int(m[30]), 1, "tick 31: latched")
	assert_eq(int(m[299]), 0, "tick 300: dropped")
	assert_eq(int(m[328]), 0, "tick 329: re-pressing")
	assert_eq(int(m[330]), 1, "tick 331: latched again")
	# an entry warning into another room does not drop; into hers does
	var lg3 := _log(n, [{"e": "entry_warning", "t": 300, "room": "hall", "eta": 90}], 1)
	lg3.ff_repress_ticks = 30
	assert_eq(int(Metrics.ff_mask(lg3, SolverHooks.fallback_is_laugh)[310]), 1)
	var lg4 := _log(n, [{"e": "entry_warning", "t": 300, "room": "kitchen", "eta": 90}], 1)
	lg4.ff_repress_ticks = 30
	assert_eq(int(Metrics.ff_mask(lg4, SolverHooks.fallback_is_laugh)[310]), 0)
	# a punchline is watched at ×1
	var lg5 := _log(n, [], 1, [1], [[400, 460]])
	lg5.ff_repress_ticks = 30
	var m5 := Metrics.ff_mask(lg5, SolverHooks.fallback_is_laugh)
	assert_eq(int(m5[430]), 0)
	assert_eq(int(m5[480]), 0, "re-press after the reaction")
	assert_eq(int(m5[495]), 1)


func test_slow_persona_uses_ff_only_after_ghost_ff() -> void:
	var lg := _log(900, [{"e": "director_cue", "t": 450, "id": "ghost_ff"}], 1)
	lg.ff_repress_ticks = 120
	lg.ff_needs_cue = true
	var m := Metrics.ff_mask(lg, SolverHooks.fallback_is_laugh)
	assert_eq(Array(m.slice(0, 449)).count(1), 0, "never before the cue")
	assert_eq(int(m[460]), 1, "held since the start of the hide: latched once taught")
	var never := _log(900, [], 1)
	never.ff_needs_cue = true
	assert_eq(Array(Metrics.ff_mask(never, SolverHooks.fallback_is_laugh)).count(1), 0)
	var rn := Metrics.compute(never, SolverHooks.fallback_is_laugh)
	assert_almost_eq(float(rn["dead_air_ff_pct"]), float(rn["dead_air_sim_pct"]), 0.1, "no ⏩: real time = sim time")
	assert_lt(float(rn["real_time_ff_naive_s"]), float(rn["real_time_ff_s"]), "the naive clock assumes ⏩ anyway")
	for p in [["ideal", 30, false], ["required", 60, false], ["slow", 120, true], ["scenario", 30, false]]:
		var ps := Persona.make(p[0])
		assert_eq(ps.ff_repress_ticks, p[1], "%s re-press" % p[0])
		assert_eq(ps.ff_needs_cue, p[2], "%s needs the cue" % p[0])


# --- expect keys -----------------------------------------------------------------------------------------------

func test_dead_air_keys_check_the_gate_and_aliases_and_warn_keys() -> void:
	var rep := {"dead_air_ff_pct": 22.0, "dead_air_sim_pct": 40.0, "max_gap_ff_s": 9.0, "max_gap_sim_s": 20.0,
		"event_counts": {"caught": 1, "lecture": 1}}
	assert_eq(Metrics.check_expect(rep, {"dead_air_pct_max": 25, "max_gap_s_max": 12}), PackedStringArray(), "⏩ numbers")
	assert_has(Metrics.check_expect(rep, {"dead_air_pct_max": 20})[0], "dead air ⏩ 22.0 % > max 20 % (sim 40.0 %)")
	assert_has(Metrics.check_expect(rep, {"dead_air_ff_pct_max": 20})[0], "dead air ⏩ 22.0", "alias")
	assert_has(Metrics.check_expect(rep, {"max_gap_ff_s_max": 8})[0], "longest gap ⏩ 9.0 s > max 8 s")
	var ex := {"warn_dead_air_pct_max": 20, "warn_max_gap_s_max": 12}
	assert_eq(Metrics.check_expect(rep, ex), PackedStringArray(), "warn_ keys never fail")
	var w := Metrics.check_warn(rep, ex)
	assert_eq(w.size(), 1)
	assert_has(w[0], "warn_dead_air_pct_max: dead air ⏩ 22.0")
	var er := Metrics.expect_results(rep, ex)
	assert_false(bool(er["warn_dead_air_pct_max"]["ok"]))
	assert_true(bool(er["warn_max_gap_s_max"]["ok"]))
	assert_true(Metrics.known_key("warn_events_min") and Metrics.known_key("dead_air_ff_pct_max") and not Metrics.known_key("nope"))
	assert_eq(Metrics.check_expect(rep, {"events_min": {"caught": 1, "lecture": 1}, "events_max": {"caught": 1}}), PackedStringArray())
	assert_has(Metrics.check_expect(rep, {"events_min": {"doorstep": 1}})[0], "0 'doorstep' event(s) < min 1")
	assert_has(Metrics.check_expect(rep, {"events_max": {"caught": 0}})[0], "1 'caught' event(s) > max 0")
	var sd := SolutionDef.from_dict({"episode": "x", "routes": {"s": {"persona": "scenario", "steps": [{"do": "idle", "s": 1}],
		"expect": {"events_min": {"caught": 1}, "warn_dead_air_pct_max": 20, "bogus": 1, "events_max": 3}}}})
	var errs := "\n".join(sd.validate())
	assert_has(errs, "unknown key 'bogus'")
	assert_has(errs, "events_max must be {event: n}")
	assert_false(errs.contains("warn_dead_air_pct_max"), "warn_ keys are known")
	assert_false(errs.contains("persona"), "scenario is a persona")


func test_scenario_persona() -> void:
	var p := Persona.make("scenario")
	assert_eq(p.name, "scenario")
	assert_false(p.catch_restarts, "a catch is what the route wants")
	assert_false(p.run_when_safe)
	assert_true(Persona.make("ideal").catch_restarts)
	assert_has(SolutionDef.PERSONAS, "scenario")


# --- --baseline ----------------------------------------------------------------------------------------------------

func test_baseline_new_still_fixed() -> void:
	var solve: Script = load("res://tools/solve.gd")
	var base := {"runs": [
		{"episode": "e", "route": "a", "ok": true, "expect_results": {"stars": {"ok": true}}},
		{"episode": "e", "route": "b", "ok": false, "expect_results": {"stars": {"ok": false}}},
		{"episode": "e", "route": "c", "ok": true, "expect_results": {"k1": {"ok": true}, "k2": {"ok": false}}},
		{"episode": "e", "route": "f", "ok": false, "expect_results": {"stars": {"ok": false}}}]}
	var now := [
		{"episode": "e", "route": "a", "ok": false, "expect_results": {"stars": {"ok": false}}},
		{"episode": "e", "route": "b", "ok": false, "expect_results": {"stars": {"ok": false}}},
		{"episode": "e", "route": "c", "ok": false, "expect_results": {"k1": {"ok": false}, "k2": {"ok": true}, "k3": {"ok": false},
			"warn_x": {"ok": false}}},
		{"episode": "e", "route": "d", "ok": false, "expect_results": {}},
		{"episode": "e", "route": "g", "ok": true, "expect_results": {}},
		{"episode": "e", "route": "f", "ok": true, "expect_results": {"stars": {"ok": true}}}]
	var cmp: Dictionary = solve.compare_baseline(base, now)
	var nw := PackedStringArray(cmp["new"])
	assert_has(nw, "e/a", "passed → fails: new")
	assert_has(nw, "e/a: stars")
	assert_has(nw, "e/c")
	assert_has(nw, "e/c: k1")
	assert_has(nw, "e/c: k3 (new key)", "new keys are checked absolutely")
	assert_has(nw, "e/d (new route)")
	assert_false(nw.has("e/c: warn_x"), "warn_ keys never fail")
	assert_false(nw.has("e/g (new route)"), "a new passing route is fine")
	assert_has(cmp["still"], "e/b")
	assert_has(cmp["fixed"], "e/c: k2")
	assert_has(cmp["fixed"], "e/f")
	assert_eq(int(cmp["checked"]), 6)
	# an old-format baseline (no per-key results): route granularity
	var old := {"runs": [{"episode": "e", "route": "a", "ok": true}, {"episode": "e", "route": "b", "ok": false}]}
	var cmp2: Dictionary = solve.compare_baseline(old, [
		{"episode": "e", "route": "a", "ok": true, "expect_results": {"stars": {"ok": true}}},
		{"episode": "e", "route": "b", "ok": false, "expect_results": {"stars": {"ok": false}}}])
	assert_eq((cmp2["new"] as Array).size(), 0, str(cmp2))
	assert_has(cmp2["still"], "e/b: stars")
	var cmp3: Dictionary = solve.compare_baseline(null, [{"episode": "e", "route": "a", "ok": false}])
	assert_has(cmp3["new"], "e/a (new route)", "no baseline: everything absolute")


# --- invariants ----------------------------------------------------------------------------------------------------

func _inv_log(n: int, events: Array, over: Dictionary = {}) -> SolverLog:
	var lg := SolverLog.new()
	lg.fill_ticks = 60
	for t in range(1, n + 1):
		var s := {"hush_room": "kitchen", "b_room": "parlour", "b_state": "ROUTINE", "hush_x": 3500, "hush_state": "IDLE"}
		if over.has(t):
			s.merge(over[t], true)
		lg.add_sample(t, s)
	lg.events = events
	return lg


func test_rule9_answers_within_a_tick_and_queued_runs_when_busy_ends() -> void:
	var go := {"c": "go", "hotspot": "kitchen_sink_tap", "run": false}
	var ok := _inv_log(300, [{"e": "hush_go", "t": 10, "target": "kitchen_sink_tap", "run": false}])
	ok.cmds = [[10, go]]
	assert_eq(Invariants.rule9_progress(ok), [] as Array[String])
	var late := _inv_log(300, [{"e": "hush_go", "t": 12, "target": "kitchen_sink_tap", "run": false}])
	late.cmds = [[10, go]]
	assert_has(Invariants.rule9_progress(late)[0], "within 1 tick(s)", "2 ticks late is silent")
	# queued behind a rummage (10..60): must run at 61, the tick it ends
	var over := {}
	for t in range(1, 61):
		over[t] = {"hush_state": "RUMMAGE"}
	var ran := _inv_log(300, [{"e": "cmd_queued", "t": 10, "c": "go", "why": "busy", "target": "kitchen_sink_tap"},
		{"e": "hush_go", "t": 61, "target": "kitchen_sink_tap", "run": false}], over)
	ran.cmds = [[10, go]]
	assert_eq(Invariants.rule9_progress(ran), [] as Array[String])
	var lost := _inv_log(300, [{"e": "cmd_queued", "t": 10, "c": "go", "why": "busy", "target": "kitchen_sink_tap"},
		{"e": "hush_go", "t": 90, "target": "kitchen_sink_tap", "run": false}], over)
	lost.cmds = [[10, go]]
	assert_has(Invariants.rule9_progress(lost)[0], "did not run when her busy action ended at t=61")
	var replaced := _inv_log(300, [{"e": "cmd_queued", "t": 10, "c": "go", "why": "busy", "target": "kitchen_sink_tap"},
		{"e": "cmd_queued", "t": 30, "c": "move", "why": "busy", "target": "kitchen:3000"},
		{"e": "hush_go", "t": 61, "target": "kitchen", "run": false}], over)
	replaced.cmds = [[10, go], [30, {"c": "move", "room": "kitchen", "x": 3000, "run": false}]]
	assert_eq(Invariants.rule9_progress(replaced), [] as Array[String], "a newer tap replaced it")
	# the climb-in: queued "entering" runs at log.enter_ticks
	var ent := _inv_log(400, [{"e": "cmd_queued", "t": 1, "c": "go", "why": "entering", "target": "kitchen_sink_tap"},
		{"e": "hush_go", "t": 222, "target": "kitchen_sink_tap", "run": false}])
	ent.enter_ticks = 222
	ent.cmds = [[1, go]]
	assert_eq(Invariants.rule9_progress(ent), [] as Array[String])
	ent.enter_ticks = 150
	assert_has(Invariants.rule9_progress(ent)[0], "did not run", "not run at the end of the climb-in")


func test_rule2_exempts_chases_and_reaction_travel() -> void:
	var chase := _inv_log(300, [{"e": "b_room", "t": 190, "room": "kitchen", "chase": true}])
	assert_eq(Invariants.rule2_entry_warning(chase), [] as Array[String], "b_room.chase")
	var not_chase := _inv_log(300, [{"e": "b_room", "t": 190, "room": "kitchen", "chase": false}], {190: {"b_state": "CHASE"}})
	assert_has(Invariants.rule2_entry_warning(not_chase)[0], "no entry_warning", "the event's own flag wins")
	var travel := _inv_log(300, [{"e": "b_room", "t": 190, "room": "kitchen", "chase": false}], {189: {"b_state": "REACTING"},
		190: {"b_state": "REACTING"}})
	assert_eq(Invariants.rule2_entry_warning(travel), [] as Array[String], "a punchline carried him in")


func test_rule12_no_combo_where_the_night_allows_none() -> void:
	var lg := _inv_log(100, [{"e": "combo", "t": 50, "id": "poodle"}])
	assert_eq(Invariants.rule12_combos(lg), [] as Array[String], "absent rule: every combo")
	lg.combos_allowed = PackedStringArray()
	assert_has(Invariants.rule12_combos(lg)[0], "rule 12: combo 'poodle'")
	lg.combos_allowed = PackedStringArray(["poodle"])
	assert_eq(Invariants.rule12_combos(lg), [] as Array[String])
	assert_has(SolverData.DETOUR_IDS, "exit")
	for d in ActivityDef.DETOUR_IDS:
		assert_true(SolverData.is_detour(d), "the sim's detour ids: %s" % d)


# --- --dump-cmds round trips ----------------------------------------------------------------------------------------

func _fixture() -> Array:
	var db := ContentDB.load_dir(SIM_FIX)
	return [db, SolverData.load_dir(SIM_FIX)]


func test_fuzz_dump_replays_to_the_same_hash() -> void:
	var f := _fixture()
	var db: ContentDB = f[0]
	var data: SolverData = f[1]
	var factory := SolverHooks.factory_for("sim", db, data, "fx_act1", {"invariants": true})
	var r := Fuzz.run_bot(factory, data, "fx_act1", "random", 3, {"ticks": 1800, "probe": false})
	var lg: SolverLog = r["log"]
	var dir := OS.get_user_data_dir().path_join("s2sim_dump")
	var tool: Script = load("res://tools/fuzz.gd")
	var done := {}
	var wrote: PackedStringArray = tool.dump_events(lg, dir, "fx_act1", "random", 3, done)
	var path := dir.path_join("fx_act1_random_all.cmds.json")
	assert_eq(lg.write_cmds(path, {"episode": "fx_act1", "bot": "random"}), OK)
	var c := SimReplay.load_file(path)
	assert_eq(str(c["episode"]), "fx_act1")
	assert_eq(int(c["ticks"]), lg.last_tick())
	assert_eq((c["cmds"] as Array).size(), lg.cmds.size())
	var w := SimReplay.run(SimWorld.create(db, "fx_act1", {}), c["cmds"], int(c["ticks"]))
	assert_eq(w.state_hash(), int(c["hash"]), "the dump replays to the run's final hash")
	assert_eq(int(c["hash"]), lg.final_hash)
	for p in wrote:
		var d := SimReplay.load_file(p)
		assert_true(str(d["meta"].get("event", "")) in Fuzz.BOTS or str(d["meta"].get("event", "")) in ["caught", "face_to_face",
			"meltdown_start", "chase_start"])
		var w2 := SimReplay.run(SimWorld.create(db, "fx_act1", {}), d["cmds"], int(d["ticks"]))
		assert_eq(w2.state_hash(), int(d["hash"]), "%s replays" % p.get_file())


func test_solver_dump_replays_to_the_same_hash() -> void:
	var f := _fixture()
	var db: ContentDB = f[0]
	var data: SolverData = f[1]
	var sol := SolutionDef.load_file("res://tests/solver/fixtures/sim_fx_solutions/fx_act1.json")
	var r := sol.resolve("ideal")
	var w := SimWorld.create(db, "fx_act1", {"invariants": true})
	var ex := Executor.new(w, r, r["persona"], Callable(), data, {"episode": "fx_act1"})
	ex.run(60 * 300)
	var path := OS.get_user_data_dir().path_join("s2sim_dump/fx_act1_ideal.cmds.json")
	var solve: Script = load("res://tools/solve.gd")
	assert_eq(int(solve.write_cmds(path, ex.log, "fx_act1", "ideal")), OK)
	var c := SimReplay.load_file(path)
	assert_eq(str(c["meta"]["route"]), "ideal")
	assert_gt((c["cmds"] as Array).size(), 0)
	var w2 := SimReplay.run(SimWorld.create(db, "fx_act1", {}), c["cmds"], int(c["ticks"]))
	assert_eq(w2.state_hash(), ex.log.final_hash, "replaying the dump gives the run's hash")


# --- timeline ----------------------------------------------------------------------------------------------------

func test_timeline_draws_visible_beats_under_the_laughs() -> void:
	var lg := _log(1200, [{"e": "micro_gag", "t": 240, "vis": "room", "id": "a"}, {"e": "micro_gag", "t": 600, "vis": "edge", "id": "b"},
		{"e": "micro_gag", "t": 960, "vis": "", "id": "c"}], 1)
	var img := SolverTimeline.render(lg, Metrics.compute(lg, SolverHooks.fallback_is_laugh))
	var y := SolverTimeline.TOP + (SolverTimeline.ROW_BEATS + 1) * SolverTimeline.ROW_H - 4
	var xa := SolverTimeline.LABEL_W + (240 - 1) / SolverTimeline.TICKS_PER_PX
	var xb := SolverTimeline.LABEL_W + (600 - 1) / SolverTimeline.TICKS_PER_PX
	var xc := SolverTimeline.LABEL_W + (960 - 1) / SolverTimeline.TICKS_PER_PX
	assert_eq(img.get_pixel(xa, y).to_html(false), "2e9e4f", "room beat green")
	assert_eq(img.get_pixel(xb, y).to_html(false), "f08a24", "edge beat orange")
	assert_eq(img.get_pixel(xc, y).to_html(false), "c9c2b6", "an invisible beat: a short grey tick")
	var top := SolverTimeline.TOP + SolverTimeline.ROW_BEATS * SolverTimeline.ROW_H + 4
	assert_eq(img.get_pixel(xc, top).to_html(false), SolverTimeline.BG.to_html(false), "short: it does not reach the top")
	var ffy := SolverTimeline.TOP + SolverTimeline.ROW_FF * SolverTimeline.ROW_H + 10
	assert_eq(img.get_pixel(SolverTimeline.LABEL_W + 50, ffy).to_html(false), "6b8fb8", "the ⏩ latch row")


func test_rule4_notice_restarts_after_a_replan() -> void:
	# tea 100..700 (next = paper shown at 100), KETTLE DRUM at 400 (the bubble says tea: it will resume), then a
	# Meltdown at the reaction's end cancels the resume and the bubble flips to paper as he leaves: fair
	var evs := [{"e": "b_activity", "t": 100, "id": "tea"}, {"e": "b_next", "t": 100, "id": "paper", "detour": false},
		{"e": "reaction_start", "t": 400, "prank": "kettle_drum"}, {"e": "b_next", "t": 400, "id": "tea", "detour": false},
		{"e": "reaction_end", "t": 560, "prank": "kettle_drum"}, {"e": "b_activity_end", "t": 560, "id": "tea"},
		{"e": "meltdown_start", "t": 560}, {"e": "b_next", "t": 560, "id": "paper", "detour": false},
		{"e": "b_activity", "t": 1400, "id": "paper"}]
	assert_eq(Invariants.rule4_bubble(_inv_log(1500, evs)), [] as Array[String])
	# the same late flip with no disturbance is unfair
	var bad := [{"e": "b_activity", "t": 100, "id": "tea"}, {"e": "b_next", "t": 100, "id": "tea", "detour": false},
		{"e": "b_next", "t": 560, "id": "paper", "detour": false}, {"e": "b_activity_end", "t": 560, "id": "tea"},
		{"e": "b_activity", "t": 800, "id": "paper"}]
	assert_has(Invariants.rule4_bubble(_inv_log(1000, bad))[0], "'paper' shown only 0 ticks before he left tea")


func test_rule9_queued_run_on_a_tick_that_is_busy_again() -> void:
	# the fuzz n01 hider seed-11 case: POP OUT, a go queued behind the pop, it runs as the pop ends — and the same
	# tick he grabs her (CAUGHT). The queue did its job; the next free tick (after the Lecture) owes nothing.
	var over := {}
	for t in range(194, 208):
		over[t] = {"hush_state": "POPPING"}
	for t in range(208, 448):
		over[t] = {"hush_state": "CAUGHT"}
	var lg := _inv_log(600, [{"e": "cmd_queued", "t": 196, "c": "go", "why": "busy", "target": "kitchen_table"},
		{"e": "hush_go", "t": 208, "target": "kitchen_table", "run": true}, {"e": "caught", "t": 208, "cause": "grab"}], over)
	lg.cmds = [[196, {"c": "go", "hotspot": "kitchen_table", "run": true}]]
	assert_eq(Invariants.rule9_progress(lg), [] as Array[String])
