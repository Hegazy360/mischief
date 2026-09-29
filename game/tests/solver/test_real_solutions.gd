## Real-sim integration (TECH §10.1 "solution replays"): soft-skips until res://sim/world/sim_world.gd,
## a clean ContentDB and the episode + solution data exist. Then: the `ideal` routes of
## p00_curtain_up, n01_throat_tea and n02_something_fishy meet their whole `expect` with every
## invariant green; every other route of every `final` episode completes, meets its correctness
## expects (stars, lines, applause, catches, duration) and invariants — its fun-gate targets (laugh
## clock, dead air, gaps) are printed here and gated by tools/scripts/solve.sh; a short fuzz run per
## bot is fair.
extends TestBase

const SLICE: PackedStringArray = ["p00_curtain_up", "n01_throat_tea", "n02_something_fishy"]

var _db: Object = null
var _data: SolverData = null


## Why the real sim can't be used ("" when it can). Allows the errors a WIP sim logs on load.
func _ready_or_why() -> String:
	var why := SolverHooks.sim_missing_reason()
	if why != "":
		if ResourceLoader.exists(SolverHooks.SIM_WORLD):
			allow_errors()
			return "sim present but does not compile yet"
		return why
	_data = SolverData.load_dir("res://data")
	if _data.episodes.is_empty():
		return "no episodes in res://data/episodes yet"
	_db = SolverHooks.load_db("res://data")
	var errs := SolverHooks.db_errors(_db)
	if not errs.is_empty():
		allow_errors()
		return "ContentDB reports %d error(s) (first: %s)" % [errs.size(), errs[0]]
	return ""


func _route_report(ep: String, rn: String) -> Dictionary:
	var sol := SolutionDef.load_file("res://data/solutions/%s.json" % ep)
	if not sol.has_route(rn):
		return {"ok": false, "fail": ["route %s missing from solutions/%s.json" % [rn, ep]], "invariants": []}
	var r := sol.resolve(rn)
	var cfg := {"invariants": true}
	var w := SolverHooks.make_world(_db, ep, cfg)
	if w == null:
		return {"ok": false, "fail": ["SimWorld.create(%s) returned null" % ep], "invariants": []}
	var ex := Executor.new(w, r, r["persona"], Callable(), _data, {"episode": ep})
	var rep := ex.run(60 * 900)
	var fails: Array = rep["fail"]
	# Correctness keys fail the test; fun-gate targets are reported (tools/scripts/solve.sh gates them).
	var strict_keys: Dictionary = Metrics.split_expect(r["expect"], false) if rn != "ideal" else r["expect"]
	for f in Metrics.check_expect(rep, strict_keys):
		fails.append("expect: %s" % f)
	if rn != "ideal":
		for f in Metrics.check_expect(rep, Metrics.split_expect(r["expect"], true)):
			print("  FUN GATE MISS %s %s: %s" % [ep, rn, f])
	ex.log.replay_hash = Invariants.replay_hash(SolverHooks.world_factory(_db, ep, cfg), ex.log)
	var inv := Invariants.check(ex.log)
	inv.append_array(Invariants.sim_counters(w))
	rep["invariants"] = inv
	print("  %s" % Metrics.summary_line(rep))
	return rep


func test_real_slice_ideal_routes() -> void:
	var why := _ready_or_why()
	if why != "":
		skip(why)
		return
	var ran := 0
	for ep in SLICE:
		if _data.episode(ep).is_empty() or not FileAccess.file_exists("res://data/solutions/%s.json" % ep):
			continue
		ran += 1
		var rep := _route_report(ep, "ideal")
		assert_eq(rep["fail"], [], "%s ideal: %s" % [ep, rep["fail"]])
		assert_eq(rep["invariants"], [] as Array[String], "%s ideal invariants" % ep)
	if ran == 0:
		skip("no slice episode has an authored solution yet")


func test_real_every_final_route() -> void:
	var why := _ready_or_why()
	if why != "":
		skip(why)
		return
	var eps := _data.final_episode_ids()
	if eps.is_empty():
		skip("no final episodes yet")
		return
	for ep in eps:
		var sol := SolutionDef.load_file("res://data/solutions/%s.json" % ep)
		assert_eq(sol.validate(_data), PackedStringArray(), "%s solution file validates" % ep)
		for rn in ["ideal", "required", "slow"]:
			assert_true(sol.has_route(rn), "%s has a %s route" % [ep, rn])
		for rn in sol.route_names():
			if rn == "ideal" and SLICE.has(ep):
				continue   # covered above
			var rep := _route_report(ep, rn)
			assert_eq(rep["fail"], [], "%s %s: %s" % [ep, rn, rep["fail"]])
			assert_eq(rep["invariants"], [] as Array[String], "%s %s invariants" % [ep, rn])


func test_real_fuzz_smoke() -> void:
	var why := _ready_or_why()
	if why != "":
		skip(why)
		return
	var eps := _data.final_episode_ids()
	if eps.is_empty():
		skip("no final episodes yet")
		return
	var ep := eps[0]
	for bot in Fuzz.BOTS:
		var r := Fuzz.run_bot(SolverHooks.world_factory(_db, ep, {"invariants": true}), _data, ep, bot, 1,
			{"ticks": 60 * 60, "probe": false, "replay": true})
		print("  %s" % Fuzz.summary_line(r))
		assert_true(bool(r["ok"]), "%s %s: %s" % [ep, bot, "\n".join(PackedStringArray(r["invariants"]))])


func test_real_probe_reads_simworld() -> void:
	var why := _ready_or_why()
	if why != "":
		skip(why)
		return
	var eps := _data.final_episode_ids()
	if eps.is_empty():
		skip("no final episodes yet")
		return
	var ep := eps[0]
	var w := SolverHooks.make_world(_db, ep, {})
	var p := SolverProbe.new(w, _data)
	var start: Dictionary = _data.episode(ep).get("hush", {}).get("start", {})
	assert_eq(p.hush_room(), String(start.get("room", p.hush_room())), "Hush's room id resolves")
	assert_true(_data.has_room(p.bellows_room()), "Bellows' room id resolves (%s)" % p.bellows_room())
	assert_true(SolverProbe.HUSH_STATES.has(p.hush_state()), "Hush state name (%s)" % p.hush_state())
	assert_true(SolverProbe.BELLOWS_STATES.has(p.bellows_state()), "Bellows state name (%s)" % p.bellows_state())
	for pid in _data.episode_pranks(ep):
		assert_true(SolverProbe.PRANK_STATES.has(p.prank_state(pid)), "prank state of %s (%s)" % [pid, p.prank_state(pid)])
	assert_eq(p.stars().size(), 3)


## Fuzz seeds that once broke CI on p00_curtain_up, replayed on the real sim and data:
## - random seed 17 (rule 9): a go issued during Hush's 3.7 s climb-in was held with no feedback and
##   replaced before she was in → the sim now emits `cmd_queued {why: "entering"}`;
## - hider seed 13 (rule 6): a lure / noise Curious ended the uncapped "until rigged:achoo_ria" warm-up,
##   he brewed the tea with nothing rigged and the Prologue could no longer land the sneeze → an
##   uncapped player-led gate now holds the loop (TECH §3.7.1). The soft-lock probe must pass.
func test_real_fuzz_regressions_p00() -> void:
	var why := _ready_or_why()
	if why != "":
		skip(why)
		return
	var ep := "p00_curtain_up"
	if _data.episode(ep).is_empty():
		skip("no %s yet" % ep)
		return
	var fac := SolverHooks.world_factory(_db, ep, {"invariants": true})
	var r17 := Fuzz.run_bot(fac, _data, ep, "random", 17, {"probe": false})
	print("  %s" % Fuzz.summary_line(r17))
	assert_true(bool(r17["ok"]), "random 17: %s" % "\n".join(PackedStringArray(r17["invariants"])))
	var lg: SolverLog = r17["log"]
	var q := lg.events_named("cmd_queued", {"why": "entering"})
	assert_false(q.is_empty(), "the climb-in go was answered with cmd_queued")
	assert_eq(int((q[0] as Dictionary).get("t", -1)), 1, "on the tick it was tapped")
	var r13 := Fuzz.run_bot(fac, _data, ep, "hider", 13, {"probe": true})
	print("  %s" % Fuzz.summary_line(r13))
	var sl: Dictionary = r13["softlock"]
	assert_false(bool(sl.get("skipped", true)), "the probe ran (the Prologue is still on at 180 s)")
	assert_true(bool(sl.get("ok", false)), "hider 13 soft-lock probe: %s" % sl.get("why", ""))
	assert_true(bool(r13["ok"]), "hider 13: %s" % "\n".join(PackedStringArray(r13["invariants"])))
	var tea_before_rig := false
	var rigged := false
	for ev in (r13["log"] as SolverLog).events:
		var e := String(ev.get("e", ""))
		if e == "rigged" and String(ev.get("prank", "")) == "achoo_ria":
			rigged = true
		elif e == "b_activity" and String(ev.get("id", "")) == "tea" and not rigged:
			tea_before_rig = true
	assert_false(tea_before_rig, "no tea before the honey is rigged: the gate waits for the player")


## More p00 seeds past CI's 20 (found by `fuzz.sh p00_curtain_up --runs=100 --seed=21`):
## - random seed 21 (rule 6): a lure 0.5 s into the tea, ACHOO-RIA! rigged, ended the tea before its
##   7 s hook; the Prologue's loop never comes back, so the sneeze was lost → in a non-repeating loop an
##   interruption restarts an activity whose rigged prank is still to come (TECH §3.7.1);
## - hider seed 53 (rule 6, a solver false alarm): the run ends mid-dive, the probe's first go was
##   pinned (not queued) and the executor never popped her out → it waits out a dive first.
func test_real_fuzz_regressions_p00_tea_and_dive() -> void:
	var why := _ready_or_why()
	if why != "":
		skip(why)
		return
	var ep := "p00_curtain_up"
	if _data.episode(ep).is_empty():
		skip("no %s yet" % ep)
		return
	var fac := SolverHooks.world_factory(_db, ep, {"invariants": true})
	var r21 := Fuzz.run_bot(fac, _data, ep, "random", 21, {"probe": true})
	print("  %s" % Fuzz.summary_line(r21))
	assert_false(bool((r21["softlock"] as Dictionary).get("skipped", true)), "random 21: the probe ran")
	assert_true(bool(r21["ok"]), "random 21: %s" % "\n".join(PackedStringArray(r21["invariants"])))
	var lg: SolverLog = r21["log"]
	assert_false(lg.events_named("rigged", {"prank": "achoo_ria"}).is_empty(), "random 21 rigs the honey")
	assert_true(lg.events_named("b_activity_end", {"id": "tea"}).is_empty(),
		"the lure mid-tea no longer ends the tea (ACHOO-RIA! still to come)")
	var r53 := Fuzz.run_bot(fac, _data, ep, "hider", 53, {"probe": true})
	print("  %s" % Fuzz.summary_line(r53))
	assert_false(bool((r53["softlock"] as Dictionary).get("skipped", true)), "hider 53: the probe ran")
	assert_true(bool(r53["ok"]), "hider 53: %s" % "\n".join(PackedStringArray(r53["invariants"])))


## The executor on the real sim: a go step issued while Hush is mid-dive waits for her to land, pops
## her out and walks (a go during DIVING is pinned for after the pop-out, not queued).
func test_real_executor_go_while_diving() -> void:
	var why := _ready_or_why()
	if why != "":
		skip(why)
		return
	var ep := "n01_throat_tea"
	if _data.episode(ep).is_empty():
		skip("no %s yet" % ep)
		return
	var w: Object = SolverHooks.make_world(_db, ep, {"invariants": true})
	var probe := SolverProbe.new(w, _data)
	w.call("step", [SimCmd.go("kitchen_pantry_curtain")])
	var n := 0
	while probe.hush_state() != "DIVING" and n < 600:
		w.call("step", [])
		n += 1
	assert_eq(probe.hush_state(), "DIVING", "set-up: she is mid-dive")
	var ex := Executor.new(w, [{"do": "go", "to": "kitchen_honey"}], "ideal", Callable(), _data, {"episode": ep})
	var r := ex.run(900)
	assert_true(bool(r["ok"]), "go from a dive: %s" % [r["fail"]])
	assert_false(ex.log.events_named("pop_out").is_empty(), "she popped out")
	assert_false(ex.log.events_named("hush_arrive", {"hotspot": "kitchen_honey"}).is_empty(), "and arrived")
