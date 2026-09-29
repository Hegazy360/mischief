## Persona transforms (TECH §8.3) and SolutionDef parsing / route resolution (TECH §8.2).
extends TestBase

const U := preload("res://tests/solver/solver_test_util.gd")


func test_make_known_personas() -> void:
	var slow := Persona.make("slow")
	assert_eq(slow.latency_ticks, 36, "0.6 s latency")
	assert_eq(slow.dawdle_ticks, 180, "3 s dawdle")
	assert_true(slow.wrong_tap and slow.tiptoe_only and slow.hide_on_warning)
	assert_false(slow.use_pins or slow.use_queue)
	var ideal := Persona.make("ideal")
	assert_eq(ideal.latency_ticks, 0)
	assert_true(ideal.use_pins and ideal.use_queue and ideal.run_when_safe)
	assert_true(Persona.make("required").required_only)
	assert_eq(Persona.make("").name, "ideal")


func test_required_filter_drops_optional_prank_steps() -> void:
	var steps: Array = U.solution().route("ideal")["steps"]
	var out := Persona.filter_required(steps, U.data(), "mock_ep")
	var pranks := PackedStringArray()
	for s in out:
		if s["do"] == "rig":
			pranks.append(s["prank"])
	assert_eq(pranks, PackedStringArray(["tap_dance", "kettle_drum"]), "achoo_ria (optional + BN) rig dropped")
	var picks := 0
	for s in out:
		if s["do"] == "pick":
			picks += 1
	assert_eq(picks, 1, "the squeaker pick serves a required prank")
	assert_eq(String(out[out.size() - 1]["do"]), "bow", "neutral steps kept")


func test_required_filter_drops_waits_on_dropped_pranks() -> void:
	var steps := [{"do": "wait", "until": {"prank_state": ["achoo_ria", "rigged"]}},
		{"do": "wait_event", "event": "reaction_end", "match": {"prank": "achoo_ria"}},
		{"do": "wait", "until": {"and": [{"bellows_activity": "tea"}, {"event_seen": {"e": "rigged", "prank": "achoo_ria"}}]}},
		{"do": "wait", "until": {"bellows_activity": "tea"}}]
	var out := Persona.filter_required(steps, U.data(), "mock_ep")
	assert_eq(out.size(), 1)
	assert_eq(out[0]["until"], {"bellows_activity": "tea"})


func test_slow_transform_tiptoes_and_inserts_one_wrong_tap() -> void:
	var steps := [{"do": "idle", "s": 1}, {"do": "go", "to": "kitchen_sink_tap", "run": true},
		{"do": "rig", "prank": "tap_dance", "run": true}]
	var out := Persona.make("slow").transform(steps, U.data(), "mock_ep")
	assert_eq(out.size(), 4, "one wrong tap inserted")
	assert_true(bool(out[1].get("wrong_tap", false)), "before the first action step")
	for s in out:
		if s.has("run"):
			assert_false(bool(s["run"]), "tiptoe only")
	var tap := String(out[1]["to"])
	assert_ne(tap, "kitchen_sink_tap", "not a hotspot the route uses")
	assert_true(U.data().hotspot_kind(tap) in ["rig_point", "container", "hiding"], "a glowing hotspot")
	assert_eq(U.data().hotspot_room(tap), "kitchen", "nearest to Hush's start")
	assert_eq(steps[1]["run"], true, "the input route is not mutated")


func test_slow_route_runs_with_latency_dawdle_and_evasion() -> void:
	var sol := U.solution()
	var r := sol.resolve("slow")
	assert_eq(String(r["derived_from"]), "ideal")
	assert_true(bool(r["filter_required"]))
	var ex := U.executor(U.world(), r, "slow")
	var rep := ex.run(30000)
	assert_true(bool(rep["ok"]), "slow first-timer still earns ★: %s" % [rep["fail"]])
	assert_true(bool(rep["stars"][0]))
	# 3 s dawdle: no command before tick 180.
	assert_gt(int(ex.log.cmds[0][0]), 180, "dawdled 3 s")
	# One wrong tap.
	var wrong := 0
	for s in ex.steps:
		if bool(s.get("wrong_tap", false)):
			wrong += 1
	assert_eq(wrong, 1)
	for c in ex.log.cmds:
		assert_ne(String(c[1]["c"]), "pin", "never pins")
		if c[1].has("run"):
			assert_false(bool(c[1]["run"]), "never runs")


func test_slow_hides_on_entry_warning() -> void:
	# Stand in the kitchen while Bellows comes for tea: the slow persona dives into the nearest spot.
	var steps := [{"do": "move", "room": "kitchen", "x": 3300}, {"do": "wait", "until": {"bellows_activity": "rinse"}, "max_s": 60}]
	var ex := U.executor(U.world(), steps, "slow", {"no_dawdle": true})
	var rep := ex.run(6000)
	assert_true(bool(rep["ok"]), str(rep["fail"]))
	assert_true(ex.log.events_named("entry_warning", {"room": "kitchen"}).size() >= 1, "warned")
	assert_true(ex.log.events_named("hide").size() >= 1, "hid on the warning")
	assert_eq((rep["catches"] as Array).size(), 0)


func test_solution_def_validate_catches_bad_steps() -> void:
	var sol := SolutionDef.from_dict({"episode": "mock_ep", "routes": {"ideal": {"steps": [
		{"do": "teleport"}, {"do": "rig"}, {"do": "go", "to": "the_moon"}, {"do": "pick", "item": "squeaker", "from": "kitchen_pantry_curtain"},
		{"do": "hide", "spot": "kitchen_sink_tap"}, {"do": "wait", "until": {"bellows_is_happy": true}}],
		"expect": {"stars": [true], "nonsense": 1}}, "weird": {"persona": "speedrunner", "steps": []}}})
	var errs := sol.validate(U.data())
	var all := "\n".join(errs)
	for needle in ["unknown 'do' 'teleport'", "rig needs 'prank'", "'the_moon' not in house.json",
			"comes from 'hall_confiscated_box', not 'kitchen_pantry_curtain'", "not a hiding spot",
			"unknown condition 'bellows_is_happy'", "unknown key 'nonsense'", "stars must be", "persona 'speedrunner'"]:
		assert_has(all, needle)


func test_solution_resolve_derivations() -> void:
	var sol := U.solution()
	assert_eq(sol.route_names(), PackedStringArray(["ideal", "required", "slow"]))
	var req := sol.resolve("required")
	assert_eq(String(req["derived_from"]), "ideal")
	assert_true(bool(req["filter_required"]))
	assert_eq(String(req["persona"]), "ideal")
	assert_eq(sol.resolve("nope"), {})
	var ideal := sol.resolve("ideal")
	assert_false(bool(ideal["filter_required"]))
	assert_eq(String(ideal["derived_from"]), "")


func test_required_route_runs_mock() -> void:
	var r := U.solution().resolve("required")
	var ex := U.executor(U.world(), r, r["persona"])
	var rep := ex.run(30000)
	assert_true(bool(rep["ok"]), str(rep["fail"]))
	assert_eq(rep["stars"][0], true)
	assert_false((rep["lines"] as Array).has("sneeze"), "optional line not played")
	assert_eq(Metrics.check_expect(rep, r["expect"]), PackedStringArray())


func test_step_label() -> void:
	assert_eq(SolutionDef.step_label({"do": "rig", "prank": "kettle_drum"}, 2), "3 (rig kettle_drum)")
	assert_eq(SolutionDef.step_label({"do": "bow"}, 0), "1 (bow)")
