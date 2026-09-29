## Planner on the MockWorld puzzle: predict, task templates, beam search finds the known solution,
## proofs (line alone, whole Script, soft-lock), `_auto/` output shape.
extends TestBase

const U := preload("res://tests/solver/solver_test_util.gd")


func _planner(opts: Dictionary = {}) -> Planner:
	var o := {"budget_ms": 40000}
	o.merge(opts, true)
	return Planner.new(U.data(), "mock_ep", Callable(), o)


func test_predict_reads_the_loop() -> void:
	var pl := _planner()
	var p := pl.predict(U.world())
	var ids := PackedStringArray()
	for a in p["activities"]:
		ids.append(String(a["id"]))
	assert_eq(ids.slice(0, 4), PackedStringArray(["warmup", "tea", "rinse", "warmup"]))
	# warmup 10 s + walk 5.25 s + tea 10 s + walk 3.25 s + rinse 5 s + walk 8.5 s ≈ 42 s.
	assert_between(int(p["loop_ticks"]), 60 * 40, 60 * 44)


func test_task_templates() -> void:
	var pl := _planner()
	var ts := pl.tasks_for(pl.all_lines())
	assert_eq(ts.size(), 4)
	var by := {}
	for t in ts:
		by[t["line"]] = t
	assert_eq(by["kettle"]["pranks"], PackedStringArray(["kettle_drum"]))
	assert_eq(by["bn"]["pranks"], PackedStringArray(["tap_dance", "achoo_ria"]), "double act: B before A")
	assert_true(bool(by["bn"]["big_number"]))
	assert_true(bool(by["kettle"]["req"]))
	assert_eq(pl.required_lines(), PackedStringArray(["kettle", "tap"]))


func test_macro_picks_then_rigs_then_hides() -> void:
	var pl := _planner()
	var w := U.world()
	var t: Dictionary = pl.tasks_for(PackedStringArray(["kettle"]))[0]
	var steps := pl.macro(t, SolverProbe.new(w, U.data()), "safe", PackedStringArray())
	var kinds := PackedStringArray()
	for s in steps:
		kinds.append(String(s["do"]))
	# Bellows is next door (parlour): she first gets out of sight; the kitchen → hall → kitchen trips
	# are staged through a parlour hiding spot, each leg behind its own window.
	assert_eq(kinds, PackedStringArray(["hide", "wait", "hide", "wait", "pick", "wait", "hide", "wait", "rig", "hide"]))
	assert_eq(String(U.data().hotspot_room(steps[2]["spot"])), "parlour", "staged in the room between")
	assert_eq(steps[4]["item"], "squeaker")
	assert_eq(steps[8]["prank"], "kettle_drum")
	assert_eq(String(U.data().hotspot_kind(steps[9]["spot"])), "hiding")
	for st in steps:
		if st["do"] == "wait":
			assert_true(bool(st.get("soft", false)), "timing windows are soft")
	var now := pl.macro(t, SolverProbe.new(w, U.data()), "now", PackedStringArray(["squeaker"]))
	assert_eq(String(now[0]["do"]), "rig", "carrying the item: no pick; 'now': no wait")


func test_plan_finds_the_whole_script() -> void:
	var pl := _planner()
	pl.predict(U.world())
	var p := pl.plan(U.world(), pl.all_lines())
	assert_true(bool(p["ok"]), "all lines: %s (notes %s)" % [p.get("lines", []), p.get("notes", [])])
	assert_eq(p["stars"].slice(0, 2), [true, true])
	assert_gt(int(pl.expanded), 3, "it searched")
	# The plan replays from a fresh world with the real executor.
	var ex := U.executor(U.world(), p["steps"])
	var r := ex.run(40000)
	assert_true(bool(r["ok"]), "replay: %s" % [r["fail"]])
	for l in ["kettle", "tap", "sneeze", "bn"]:
		assert_has(r["lines"], l)
	assert_true(ex.log.events_named("night_end").size() == 1, "bowed after ★")


func test_plan_required_only() -> void:
	var pl := _planner({"beam": 3})
	var p := pl.plan(U.world(), pl.required_lines())
	assert_true(bool(p["ok"]), str(p.get("lines", [])))
	assert_true(bool(p["stars"][0]))


func test_escape_steps_flee_away_from_him() -> void:
	var pl := _planner()
	var w := U.world()
	w.hush.room = "parlour"
	w.hush.x_sub = 2400 * 60   # right of Bellows (1700): flee right, into the kitchen
	var st := pl.escape_steps(SolverProbe.new(w, U.data()))
	assert_eq(st.size(), 1)
	assert_eq(String(U.data().hotspot_room(st[0]["spot"])), "kitchen")
	assert_true(bool(st[0]["run"]))
	w.hush.x_sub = 1550 * 60   # left of him: flee into the hall
	var st2 := pl.escape_steps(SolverProbe.new(w, U.data()))
	assert_eq(String(U.data().hotspot_room(st2[0]["spot"])), "hall")


func test_score_order() -> void:
	# lines > stars > applause ≥ 100 > shorter > fewer catches
	assert_true(Planner._better([2, 0, 0, 0, -9000, -3], [1, 5, 3, 1, -10, 0]))
	assert_true(Planner._better([2, 0, 1, 0, -900, 0], [2, 0, 0, 1, -10, 0]))
	assert_true(Planner._better([2, 0, 1, 0, -900, -1], [2, 0, 1, 0, -1000, 0]), "shorter beats fewer catches")
	assert_false(Planner._better([1, 0, 0, 0, 0, 0], [1, 0, 0, 0, 0, 0]))


func test_safe_cond_shape() -> void:
	var c := Planner.safe_cond("kitchen", 4.26)
	assert_eq(c["and"][0], {"bellows_not_in_room": "kitchen"})
	assert_eq(c["and"][1], {"bellows_eta_to_room_gt_s": ["kitchen", 4.3]})
	assert_eq((c["and"][2]["not"]["or"] as Array).size(), 4, "not while he hunts (spotted / chase / search / curious)")
	assert_eq(SolutionDef.validate_condition(c), PackedStringArray())


func test_prove_on_mock() -> void:
	var pl := _planner({"budget_ms": 60000})
	var proofs := pl.prove(func() -> Object: return U.world())
	assert_true(bool(proofs["script"]["ok"]), "whole Script: %s" % [proofs["script"]])
	for l in ["kettle", "tap", "sneeze", "bn"]:
		assert_true(bool(proofs["line_alone"][l]["ok"]), "line %s alone: %s" % [l, proofs["line_alone"][l]])
	var sl: Dictionary = proofs["softlock"]
	assert_true(bool(sl["ok"]), "soft-lock: %s" % [sl])
	assert_eq(int(sl["catches"]), 3, "three forced catches injected")
	assert_false(bool(proofs["three_stars"]), "the mock's applause tops out below 100")
	var sol := pl.to_solution({"steps": proofs["script"]["steps"], "stars": proofs["script"]["stars"], "applause": 70.0, "catches": 0})
	var sd := SolutionDef.from_dict(sol)
	assert_eq(sd.validate(U.data()), PackedStringArray(), "the _auto solution validates")
	assert_eq(sd.route_names(), PackedStringArray(["auto"]))


## Script order (lines proved "with the lines before them") only for the Prologue — not for every
## Night with a `director` block (s2-fix G #13: N01's lines-alone proof failed on tap / sneeze / bn).
func test_script_order_only_for_the_prologue() -> void:
	for id in ["p00_curtain_up", "n01_throat_tea", "n02_something_fishy"]:
		var ep: Variant = TestBase.load_json("res://data/episodes/%s.json" % id)
		assert_true(ep is Dictionary, id)
		var want := int((ep as Dictionary).get("act", 1)) == 0
		assert_eq(Planner.script_order(ep), want, "%s: Script order %s" % [id, want])
	assert_true(Planner.script_order({"act": 0, "director": {}}))
	assert_false(Planner.script_order({"act": 1, "director": {}}), "a director block is timing, not order")
	assert_false(Planner.script_order({"act": 0}), "no director: free order")
