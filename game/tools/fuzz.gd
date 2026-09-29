## Fairness fuzz CLI (TECH §8.6): seeded random / reckless / hider / bait bots on every `final`
## episode; each run ends with the invariants, a soft-lock probe and (every `--replay-every` runs) a
## determinism replay.
##
##   tools/scripts/fuzz.sh [<episode>|all] [--runs=20] [--seed=1] [--bot=all|random,reckless,…]
##                         [--ticks=10800] [--report=/abs/out.json] [--verbose] [--no-probe] [--strict]
##                         [--probe-every=4] [--probe-macros=60] [--replay-every=5]
## The soft-lock probe (the planner on the run's final state) is deterministic: it is budgeted in
## macro executions, not wall time, and runs on every `--probe-every`-th run of each bot.
##
## Prints a line per failing run (every run with --verbose) and one summary per episode × bot:
##   [fuzz] n01_throat_tea random: 20/20 OK, 31 catches, 12 near misses, 0 soft-locks
## Exit 1 on any invariant violation or soft-lock. Missing sim / no final episodes → SKIP, exit 0
## (1 with --strict). `--world=mock --data=res://tests/solver/fixtures/mock_data` fuzzes the MockWorld.
extends SceneTree


func _initialize() -> void:
	quit(run(_args()))


func _args() -> Dictionary:
	var a := {"episode": "all", "runs": 20, "seed": 1, "bot": "all", "ticks": Fuzz.DEFAULT_TICKS, "report": "",
		"verbose": false, "probe": true, "strict": false, "data": "res://data", "replay_every": 5,
		"probe_budget_ms": 0, "probe_macros": 60, "probe_every": 4, "world": "sim"}
	for s in OS.get_cmdline_user_args():
		if not s.begins_with("--"):
			a["episode"] = s
			continue
		var kv := s.trim_prefix("--").split("=", true, 1)
		var k := kv[0].replace("-", "_")
		if kv.size() == 1:
			if k == "no_probe":
				a["probe"] = false
			else:
				a[k] = true
		else:
			a[k] = int(kv[1]) if (a.get(k, null) is int) else kv[1]
	return a


func run(a: Dictionary) -> int:
	var root: String = a["data"]
	var strict: bool = a["strict"]
	var data := SolverData.load_dir(root)
	var eps := PackedStringArray()
	if String(a["episode"]) == "all":
		eps = data.final_episode_ids()
	else:
		eps.append(String(a["episode"]))
	if eps.is_empty():
		print("[fuzz] SKIP: no final episodes in %s/episodes — nothing to fuzz" % root)
		return 1 if strict else 0
	var db: Object = null
	if String(a["world"]) != "mock":
		var why := SolverHooks.sim_missing_reason()
		if why != "":
			print("[fuzz] SKIP: %s — %d final episode(s) not fuzzed: %s" % [why, eps.size(), ", ".join(eps)])
			return 1 if strict else 0
		db = SolverHooks.load_db(root)
		var dberr := SolverHooks.db_errors(db)
		if not dberr.is_empty():
			print("[fuzz] FAIL: ContentDB reports %d error(s) (first: %s)" % [dberr.size(), dberr[0]])
			return 1
	var bots := Fuzz.BOTS.duplicate() if String(a["bot"]) == "all" else PackedStringArray(String(a["bot"]).split(",", false))
	var runs: int = a["runs"]
	var total := 0
	var failed := 0
	var all_runs: Array = []
	var t0 := Time.get_ticks_msec()
	for ep in eps:
		var factory := SolverHooks.factory_for(String(a["world"]), db, data, ep, {"invariants": true})
		for bot in bots:
			var ok_n := 0
			var catches := 0
			var near := 0
			var locks := 0
			for k in runs:
				var probe_now := bool(a["probe"]) and (int(a["probe_every"]) <= 1 or k % int(a["probe_every"]) == 0)
				var o := {"ticks": int(a["ticks"]), "probe": probe_now, "probe_budget_ms": int(a["probe_budget_ms"]),
					"probe_macros": int(a["probe_macros"]),
					"replay": int(a["replay_every"]) > 0 and k % int(a["replay_every"]) == 0}
				var r := Fuzz.run_bot(factory, data, ep, bot, int(a["seed"]) + k, o)
				r.erase("log")
				total += 1
				catches += int(r.get("catches", 0))
				near += int(r.get("near_misses", 0))
				if not bool((r.get("softlock", {}) as Dictionary).get("ok", true)):
					locks += 1
				if bool(r["ok"]):
					ok_n += 1
				else:
					failed += 1
				if bool(a["verbose"]) or not bool(r["ok"]):
					print(Fuzz.summary_line(r))
					for i in r.get("invariants", []):
						print("  - %s" % i)
				all_runs.append(r)
			print("[fuzz] %s %s: %d/%d OK, %d catches, %d near misses, %d soft-lock(s)" % [ep, bot, ok_n, runs, catches, near, locks])
	var rp: String = a["report"]
	if rp != "":
		DirAccess.make_dir_recursive_absolute(rp.get_base_dir())
		var f := FileAccess.open(rp, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"generated_by": "tools/fuzz.gd", "runs": all_runs}, "  "))
	print("[fuzz] %s: %d run(s), %d failed, %.1f s" % ["OK" if failed == 0 else "FAIL", total, failed,
		(Time.get_ticks_msec() - t0) / 1000.0])
	return 0 if failed == 0 else 1
