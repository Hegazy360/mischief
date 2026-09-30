## R3D (REDESIGN_3D §6.2 C1/C2, ruling R15) on the solver side: SolverData's JSON-level live mask equals the sim's
## `SimCtx.live_hotspots()` on every episode; the executor / planner helpers never pick a struck hiding spot; invariant
## rule 13 (no command on a struck hotspot accepted) fires on a purpose-built bad log and stays quiet on a good one;
## the `d1_lean` recount (adjacency-only PiP beats visible only with an emote) on a synthetic log; the retired N02
## routes are gone.
extends TestBase

var _db: ContentDB = null
var _data: SolverData = null


func before_each() -> void:
	if _db == null:
		_db = ContentDB.load_dir("res://data")
		_data = SolverData.load_dir("res://data")


func test_the_solver_twin_equals_the_sim_mask_on_every_episode() -> void:
	if not _db.errors.is_empty():
		skip("real content invalid: %s" % _db.errors[0])
		return
	var n := 0
	for ep_id in ContentUtil.sorted_keys(_db.episodes):
		var sim := SimCtx.live_hotspots(_db, _db.episodes[ep_id])
		var twin := _data.live_hotspots(ep_id)
		assert_eq(twin, sim, "%s: SolverData.live_hotspots = SimCtx.live_hotspots" % ep_id)
		n += 1
	assert_ge(n, 13, "every episode checked (finals + drafts)")
	assert_eq(_data.live_hides("n01_throat_tea"), PackedStringArray(["hall_coat_cupboard", "kitchen_pantry_curtain", "parlour_piano_back"]))
	var struck := _data.struck_hotspots("n01_throat_tea")
	for id in ["kitchen_table", "parlour_chaise_back", "parlour_gramophone", "hall_clock_case"]:
		assert_true(struck.has(id), "N1 struck: %s" % id)
	assert_false(struck.has("landing_airing_cupboard"), "a locked room's spot is refused as 'locked', not counted as struck")
	assert_false(struck.has("kitchen_window"), "untappable is not struck")


func test_nearest_hiding_skips_struck_spots() -> void:
	# at the kitchen table's x the nearest spot is the table itself — unless the Night strikes it
	assert_eq(_data.nearest_hiding("kitchen", 3450), "kitchen_table")
	assert_eq(_data.nearest_hiding("kitchen", 3450, PackedStringArray(), PackedStringArray(), "n01_throat_tea"), "kitchen_pantry_curtain")
	assert_eq(_data.nearest_hiding("parlour", 2554, PackedStringArray(), PackedStringArray(["parlour"]), "p00_curtain_up"), "parlour_piano_back")
	assert_eq(_data.nearest_hiding("hall", 1280, PackedStringArray(), PackedStringArray(["hall"]), "n02_something_fishy"), "hall_coat_cupboard",
		"N2: the clock case is struck")


func test_the_slow_wrong_tap_only_uses_her_room() -> void:
	var sol := SolutionDef.load_file("res://data/solutions/n02_something_fishy.json")
	var steps: Array = (sol.routes["slow"] as Dictionary).get("steps", [])
	var tap := Persona.wrong_tap_target(steps, _data, "n02_something_fishy")
	if tap != "":
		assert_eq(_data.hotspot_room(tap), "kitchen", "a wrong tap is a live spot in her start room")
		assert_true(_data.is_live("n02_something_fishy", tap))


func _inv_log(n: int, events: Array) -> SolverLog:
	var lg := SolverLog.new()
	lg.fill_ticks = 60
	for t in range(1, n + 1):
		lg.add_sample(t, {"hush_room": "kitchen", "b_room": "parlour", "b_state": "ROUTINE", "hush_x": 3500, "hush_state": "IDLE"})
	lg.events = events
	return lg


func test_rule13_no_command_on_a_struck_hotspot_is_accepted() -> void:
	var go := {"c": "go", "hotspot": "kitchen_table", "run": false}
	var ok := _inv_log(120, [{"e": "cmd_rejected", "t": 10, "c": "go", "why": "struck", "target": "kitchen_table"}])
	ok.cmds = [[10, go]]
	ok.struck = {"kitchen_table": true}
	assert_eq(Invariants.rule13_struck(ok), [] as Array[String])
	var silent := _inv_log(120, [])
	silent.cmds = [[10, go]]
	silent.struck = {"kitchen_table": true}
	assert_has(Invariants.rule13_struck(silent)[0], "was not refused with cmd_rejected struck")
	var accepted := _inv_log(120, [{"e": "hush_go", "t": 10, "target": "kitchen_table", "run": false},
		{"e": "hide", "t": 60, "spot": "kitchen_table", "watched": false}])
	accepted.cmds = [[10, go]]
	accepted.struck = {"kitchen_table": true}
	var bad := Invariants.rule13_struck(accepted)
	assert_eq(bad.size(), 3, str(bad))
	var pin := _inv_log(120, [{"e": "cmd_rejected", "t": 20, "c": "pin", "why": "struck", "target": "parlour_chaise_back"}])
	pin.cmds = [[20, {"c": "pin", "hotspot": "parlour_chaise_back"}]]
	pin.struck = {"parlour_chaise_back": true}
	assert_eq(Invariants.rule13_struck(pin), [] as Array[String])
	var mock := _inv_log(120, [])
	mock.cmds = [[10, go]]
	assert_eq(Invariants.rule13_struck(mock), [] as Array[String], "a world without a mask (no log.struck) is exempt")
	var all := Invariants.check(silent)
	var has13 := false
	for m in all:
		has13 = has13 or m.begins_with("rule 13")
	assert_true(has13, "check() runs rule 13: %s" % str(all))


func test_d1_lean_hides_adjacency_only_pip_beats_without_an_emote() -> void:
	# one micro-gag every 4 s for 60 s: all PiP by adjacency — the gate counts them, lean does not (no emote)
	var evs: Array = []
	for t in range(60, 3600, 240):
		evs.append({"e": "micro_gag", "t": t, "id": "mg_hum", "vis": "pip", "pip_reason": "adjacent", "emote": ""})
	var lg := _inv_log(3600, evs)
	lg.persona = "ideal"
	var gate := Metrics.dead_air(lg)
	var lean := Metrics.d1_lean(lg, Callable(), "ideal")
	assert_lt(float(gate["dead_air_ff_pct"]), 10.0, "the sim credits the PiP beats")
	assert_gt(float(lean["dead_air_ff_pct"]), 80.0, "lean: adjacency-only beats without an emote are invisible")
	assert_false(bool(lean["ok"]))
	assert_eq(int((lean["beats"] as Dictionary)["adjacent_pip"]), evs.size())
	# with an emote the edge badge plays them: visible again, as edge beats (the ⅓ cap then fails)
	for e in evs:
		e["emote"] = "hum"
	var lean2 := Metrics.d1_lean(_with(lg, evs), Callable(), "ideal")
	assert_lt(float(lean2["dead_air_ff_pct"]), 10.0)
	assert_gt(float(lean2["edge_share"]), 0.9)
	assert_has(lean2["fail"][0], "edge share")
	# heading / rigging PiP beats stay PiP under lean
	for e in evs:
		e["pip_reason"] = "heading"
		e["emote"] = ""
	var lean3 := Metrics.d1_lean(_with(lg, evs), Callable(), "ideal")
	assert_true(bool(lean3["ok"]), str(lean3))
	assert_eq(Metrics.lean_text({"persona": "scenario", "d1_lean": lean3}, false).ends_with("info"), true)


func _with(lg: SolverLog, evs: Array) -> SolverLog:
	lg.events = evs
	return lg


func test_the_retired_routes_are_absent_and_the_baseline_names_them() -> void:
	var sol := SolutionDef.load_file("res://data/solutions/n02_something_fishy.json")
	assert_eq(sol.route_names(), PackedStringArray(["ideal", "required", "slow"]))
	var solve: GDScript = load("res://tools/solve.gd")
	var base := {"runs": [{"episode": "n02_something_fishy", "route": "face_to_face", "ok": true},
		{"episode": "n02_something_fishy", "route": "ideal", "ok": true}]}
	var cmp: Dictionary = solve.compare_baseline(base, [{"episode": "n02_something_fishy", "route": "ideal", "ok": true}])
	assert_eq((cmp["new"] as Array).size(), 0, "a retired route is not a failure")
	assert_has(cmp["absent"], "n02_something_fishy/face_to_face")


func test_the_prologue_mirror_hold_is_a_player_led_wait() -> void:
	assert_eq(_data.fixup_hold_activities("p00_curtain_up"), PackedStringArray(["fixup_mirror"]),
		"the held mirror fix-up is exempt from rule 9's 60 s progress check, like an uncapped gate")
	assert_eq(_data.fixup_hold_activities("n01_throat_tea"), PackedStringArray())

