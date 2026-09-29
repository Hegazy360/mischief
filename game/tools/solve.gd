## Solver CLI (TECH §8): plays every route of every `final` episode headless and checks it.
##
##   tools/scripts/solve.sh [<episode>|all] [--route=ideal|required|slow|<name>,…|all] [--auto] [--write-auto]
##                          [--report=/abs/out.json] [--strict] [--auto-gate] [--budget-ms=60000]
##                          [--max-macros=400] [--timeline=/abs/dir] [--dump-events=/abs/dir]
##                          [--dump-cmds=/abs/dir] [--baseline=/abs/report.json] [--pregate]
##   (= tools/scripts/sandbox.sh solve -s res://tools/solve.gd -- …)
## `--route=all` runs every route of the solution file (ideal, required, slow and the `scenario` routes).
## `--dump-cmds=/abs/dir` writes `<episode>_<route>.cmds.json` per run in the `sim_run.gd --cmds` format
## ({"cmds": [[tick, cmd], …]} + episode, route, persona, ticks, hash): replaying it through sim_run gives the
## same final hash (NightScene's e2e driver and ViewSandbox `--sim --cmds` replay them).
## `--baseline=/abs/report.json` compares with a saved `--report` (ruling L15): exit 1 only when a route or an
## expect key that passed in the baseline fails now (new routes / keys are checked absolutely); prints
## "new failures / still failing / fixed". `warn_<key>` expect keys are evaluated and reported but never fail;
## the summary lists every one still present. `--pregate` also fails a run on `pregate_fail` (a `warn_` key
## left, or edge beats above 1/3 of the beat credit — ruling L1).
##
## Per route: SimWorld.create(db, episode, {invariants: true}) → Executor(route, persona) → Metrics →
## `expect` checks → Invariants (+ a determinism replay of the command log, + the sim's own invariant
## counters). One summary line per run:
##   [solve] n01_throat_tea ideal OK 214.3 s ★★★ 118 applause, lines 6, catches 0, 1st laugh 7.9 s, …
## `--auto` runs the planner proofs (line alone, whole Script, ★★★, soft-lock); `--write-auto` also
## writes `data/solutions/_auto/<episode>.json` (to `--auto-dir`, which solve.sh points at the repo).
## Exit 1 on any failed expect, invariant, missing route or invalid content/solution; `--auto-gate`
## makes planner proofs gate too. Missing sim / no final episodes → a SKIP line and exit 0 (1 with
## `--strict`). `--timeline=/abs/dir` writes one SolverTimeline PNG per run. `--world=mock` (with
## `--data=res://tests/solver/fixtures/mock_data`) runs the whole pipeline on the tests' MockWorld;
## `--solutions=res://dir` reads the route files from another folder (trying routes before they land);
## `--dump-events=/abs/dir` writes each run's events and commands as JSON lines.
extends SceneTree

const ROUTES: PackedStringArray = ["ideal", "required", "slow"]


func _initialize() -> void:
	var a := _args()
	var code := run(a)
	quit(code)


func _args() -> Dictionary:
	var a := {"episode": "all", "route": "all", "auto": false, "write_auto": false, "report": "", "strict": false,
		"auto_gate": false, "data": "res://data", "auto_dir": "", "budget_ms": 50000, "max_macros": 400, "max_s": 900,
		"replay": true,
		"timeline": "", "world": "sim", "solutions": "", "dump_events": "", "dump_cmds": "", "baseline": "",
		"pregate": false}
	for s in OS.get_cmdline_user_args():
		if not s.begins_with("--"):
			a["episode"] = s
			continue
		var kv := s.trim_prefix("--").split("=", true, 1)
		var k := kv[0].replace("-", "_")
		if kv.size() == 1:
			if k == "no_replay":
				a["replay"] = false
			else:
				a[k] = true
		else:
			a[k] = int(kv[1]) if (a.get(k, null) is int) else kv[1]
	return a


## Returns the process exit code.
func run(a: Dictionary) -> int:
	var root: String = a["data"]
	var strict: bool = a["strict"]
	var data := SolverData.load_dir(root)
	for e in data.errors:
		print("[solve] data parse error: %s" % e)
	if not data.errors.is_empty():
		return 1
	var eps := PackedStringArray()
	if String(a["episode"]) == "all":
		eps = data.final_episode_ids()
	else:
		eps.append(String(a["episode"]))
	if eps.is_empty():
		print("[solve] SKIP: no final episodes in %s/episodes — nothing to solve" % root)
		return 1 if strict else 0
	var db: Object = null
	if String(a["world"]) != "mock":
		var why := SolverHooks.sim_missing_reason()
		if why != "":
			print("[solve] SKIP: %s — %d final episode(s) not solved: %s" % [why, eps.size(), ", ".join(eps)])
			return 1 if strict else 0
		db = SolverHooks.load_db(root)
		var dberr := SolverHooks.db_errors(db)
		if not dberr.is_empty():
			print("[solve] FAIL: ContentDB reports %d error(s):" % dberr.size())
			for e in dberr:
				print("  - %s" % e)
			return 1
	var want_routes := PackedStringArray()
	if String(a["route"]) == "all":
		want_routes = ROUTES.duplicate()
	else:
		want_routes = PackedStringArray(String(a["route"]).split(",", false))
	var reports: Array = []
	var autos := {}
	var failed := 0
	for ep in eps:
		if data.episode(ep).is_empty():
			print("[solve] FAIL %s: no such episode in %s/episodes" % [ep, root])
			failed += 1
			continue
		var sol_dir: String = a["solutions"] if String(a["solutions"]) != "" else "%s/solutions" % root
		var sol := SolutionDef.load_file("%s/%s.json" % [sol_dir, ep])
		var verr := sol.validate(data)
		if not verr.is_empty():
			print("[solve] FAIL %s: solution file has %d problem(s):" % [ep, verr.size()])
			for e in verr:
				print("  - %s" % e)
			failed += 1
		var names := want_routes.duplicate()
		if String(a["route"]) == "all":
			for n in sol.route_names():
				if not names.has(n):
					names.append(n)
		for rn in names:
			if not sol.has_route(rn):
				print("[solve] %s %s FAIL — route missing from solutions/%s.json" % [ep, rn, ep])
				reports.append({"episode": ep, "route": rn, "ok": false, "fail": ["route missing"], "stars": []})
				failed += 1
				continue
			var rep := run_route(db, data, ep, sol, rn, a)
			reports.append(rep)
			print(Metrics.summary_line(rep))
			for f in rep["fail"]:
				print("  - fail: %s" % f)
			for i in rep.get("invariants", []):
				print("  - invariant: %s" % i)
			if not bool(rep["ok"]):
				failed += 1
		if bool(a["auto"]) or bool(a["write_auto"]):
			var authored3 := false
			for rep0 in reports:
				if String(rep0.get("episode", "")) == ep and bool(rep0.get("ok", false)) and (rep0.get("stars", []) as Array).size() == 3 \
						and bool(rep0["stars"][2]):
					authored3 = true
			var au := run_auto(db, data, ep, a, authored3)
			autos[ep] = au
			if bool(a["auto_gate"]) and not bool(au["ok"]):
				failed += 1
	var rp: String = a["report"]
	if rp != "":
		_write_report(rp, reports, autos)
	var warn_left := PackedStringArray()
	for rep in reports:
		for k in rep.get("warn_keys", []):
			warn_left.append("%s/%s: %s" % [rep.get("episode", "?"), rep.get("route", "?"), k])
	if not warn_left.is_empty():
		print("[solve] warn_ expect keys still present (%d; the pre-gate requires none): %s" % [warn_left.size(), ", ".join(warn_left)])
	print("[solve] %s: %d run(s), %d failed%s" % ["OK" if failed == 0 else "FAIL", reports.size(), failed,
		"" if rp == "" else ", report %s" % rp])
	var bl: String = a["baseline"]
	if bl != "":
		var cmp := compare_baseline(SolverData.read_json(bl), reports)
		print_baseline(cmp, bl)
		return 1 if not (cmp["new"] as Array).is_empty() else 0
	return 0 if failed == 0 else 1


## Compare this run's reports with a saved `--report` JSON (`baseline`: its parsed dict). Returns
## {new: [..], still: [..], fixed: [..], checked: n}: "episode/route" entries, or "episode/route: key" for an
## expect key. A route passed in the baseline when its `ok` was true; a key when its `expect_results[key].ok` was
## true (baselines written before per-key results existed count every key of a passing route as passed, and
## none of a failing one). New routes and new keys are checked absolutely (a failure is new).
static func compare_baseline(baseline: Variant, reports: Array) -> Dictionary:
	var old := {}
	if baseline is Dictionary:
		for r in (baseline as Dictionary).get("runs", []):
			if r is Dictionary:
				old["%s/%s" % [r.get("episode", "?"), r.get("route", "?")]] = r
	var out := {"new": [], "still": [], "fixed": [], "checked": 0}
	for r in reports:
		var id := "%s/%s" % [r.get("episode", "?"), r.get("route", "?")]
		out["checked"] = int(out["checked"]) + 1
		var now_ok := bool(r.get("ok", false))
		var b: Variant = old.get(id, null)
		if b == null:
			if not now_ok:
				(out["new"] as Array).append("%s (new route)" % id)
			continue
		var was_ok := bool((b as Dictionary).get("ok", false))
		if was_ok and not now_ok:
			(out["new"] as Array).append(id)
		elif not was_ok and not now_ok:
			(out["still"] as Array).append(id)
		elif not was_ok and now_ok:
			(out["fixed"] as Array).append(id)
		var old_keys: Variant = (b as Dictionary).get("expect_results", null)
		var now_keys: Dictionary = r.get("expect_results", {})
		for k in now_keys:
			var key := String(k)
			if key.begins_with(Metrics.WARN_PREFIX):
				continue
			var k_now := bool((now_keys[k] as Dictionary).get("ok", false))
			var k_was: Variant = null
			if old_keys is Dictionary:
				if (old_keys as Dictionary).has(k):
					k_was = bool(((old_keys as Dictionary)[k] as Dictionary).get("ok", false))
			else:
				k_was = was_ok   # a baseline without per-key results: route granularity
			if k_was == null:
				if not k_now:
					(out["new"] as Array).append("%s: %s (new key)" % [id, key])
				continue
			if bool(k_was) and not k_now:
				(out["new"] as Array).append("%s: %s" % [id, key])
			elif not bool(k_was) and not k_now:
				(out["still"] as Array).append("%s: %s" % [id, key])
			elif not bool(k_was) and k_now:
				(out["fixed"] as Array).append("%s: %s" % [id, key])
	return out


## Print the baseline comparison.
static func print_baseline(cmp: Dictionary, path: String) -> void:
	var nw: Array = cmp["new"]
	var st: Array = cmp["still"]
	var fx: Array = cmp["fixed"]
	print("[solve] baseline %s: %d new failure(s), %d still failing, %d fixed (%d run(s) checked)" % [path, nw.size(), st.size(),
		fx.size(), int(cmp["checked"])])
	for x in nw:
		print("  - NEW failure: %s" % x)
	for x in st:
		print("  - still failing: %s" % x)
	for x in fx:
		print("  - fixed: %s" % x)
	print("[solve] baseline %s" % ("OK: no new failures" if nw.is_empty() else "FAIL: new failures against the baseline"))


## Play one route; returns the report (Metrics fields + ok, fail, invariants, expect).
func run_route(db: Object, data: SolverData, ep: String, sol: SolutionDef, rn: String, a: Dictionary) -> Dictionary:
	var r := sol.resolve(rn)
	var cfg := {"invariants": true}
	var make := SolverHooks.factory_for(String(a["world"]), db, data, ep, cfg)
	var world: Object = make.call()
	if world == null:
		return {"episode": ep, "route": rn, "ok": false, "fail": ["SimWorld.create returned null"], "stars": []}
	var ex := Executor.new(world, r, r["persona"], Callable(), data, {"episode": ep})
	var rep := ex.run(int(a["max_s"]) * 60)
	var ex_fail := Metrics.check_expect(rep, r["expect"])
	var fails: Array = rep["fail"]
	for f in ex_fail:
		fails.append("expect: %s" % f)
	rep["warn"] = Array(Metrics.check_warn(rep, r["expect"]))
	var wk := PackedStringArray()
	for k in r["expect"]:
		if String(k).begins_with(Metrics.WARN_PREFIX):
			wk.append(String(k))
	rep["warn_keys"] = Array(wk)
	rep["expect_results"] = Metrics.expect_results(rep, r["expect"])
	rep["expect_results"]["_steps"] = {"ok": bool(rep["ok"]), "msgs": (rep["fail"] as Array).duplicate()}
	rep["pregate_fail"] = Array(Metrics.pregate_fail(rep, r["expect"]))
	if bool(a.get("pregate", false)):
		for f in rep["pregate_fail"]:
			fails.append("pre-gate: %s" % f)
	if bool(a.get("replay", true)):
		ex.log.replay_hash = Invariants.replay_hash(make, ex.log)
	var inv := Invariants.check(ex.log)
	inv.append_array(Invariants.sim_counters(world))
	rep["invariants"] = inv
	rep["expect_results"]["_invariants"] = {"ok": inv.is_empty(), "msgs": Array(inv)}
	rep["expect"] = r["expect"]
	rep["derived_from"] = r.get("derived_from", "")
	rep["ok"] = bool(rep["ok"]) and ex_fail.is_empty() and inv.is_empty() and \
		(not bool(a.get("pregate", false)) or (rep["pregate_fail"] as Array).is_empty())
	var dc: String = a.get("dump_cmds", "")
	if dc != "":
		var path := "%s/%s_%s.cmds.json" % [dc, ep, rn]
		if write_cmds(path, ex.log, ep, rn) == OK:
			rep["cmds_file"] = path
	var de: String = a.get("dump_events", "")
	if de != "":
		DirAccess.make_dir_recursive_absolute(de)
		var f := FileAccess.open("%s/%s_%s.events.jsonl" % [de, ep, rn], FileAccess.WRITE)
		if f != null:
			for ev in ex.log.events:
				f.store_line(JSON.stringify(ev))
			for c in ex.log.cmds:
				f.store_line(JSON.stringify({"cmd_tick": c[0], "cmd": c[1]}))
	var tl: String = a.get("timeline", "")
	if tl != "":
		var png := "%s/%s_%s.png" % [tl, ep, rn]
		if SolverTimeline.save(ex.log, rep, png) == OK:
			rep["timeline"] = png
	return rep


## Write a run's commands in the `sim_run.gd --cmds` format: {"cmds": [[tick, cmd], …], episode, route,
## persona, ticks (the run's last tick), hash (its final state hash)}. Returns OK or an error code.
static func write_cmds(path: String, lg: SolverLog, ep: String, rn: String) -> int:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var rows := PackedStringArray()
	for c in lg.cmds:
		rows.append("  [%d, %s]" % [int(c[0]), JSON.stringify(c[1])])
	f.store_string("{\"episode\": %s, \"route\": %s, \"persona\": %s, \"ticks\": %d, \"hash\": %d,\n \"cmds\": [\n%s\n]}\n" % [
		JSON.stringify(ep), JSON.stringify(rn), JSON.stringify(lg.persona), lg.last_tick(), lg.final_hash, ",\n".join(rows)])
	f.close()
	return OK


## Planner proofs (+ `_auto/` output). Returns {ok, proofs, wrote}. ★★★ counts as proven when the
## planner or an authored route (`authored3`) reached it; Nights without Curtain Calls skip it.
func run_auto(db: Object, data: SolverData, ep: String, a: Dictionary, authored3: bool = false) -> Dictionary:
	var make := SolverHooks.factory_for(String(a["world"]), db, data, ep, {})
	var pl := Planner.new(data, ep, Callable(), {"budget_ms": int(a["budget_ms"]), "max_macros": int(a["max_macros"])})
	var proofs := pl.prove(make)
	var sc: Dictionary = proofs.get("script", {})
	var alone: Dictionary = proofs.get("line_alone", {})
	var alone_ok := true
	var alone_bad := PackedStringArray()
	for l in alone:
		if not bool(alone[l]["ok"]):
			alone_ok = false
			alone_bad.append(l)
	var sl: Dictionary = proofs.get("softlock", {})
	var calls: bool = data.rules(ep).get("curtain_calls", true) != false
	var three := bool(proofs.get("three_stars", false))
	var three_txt := "n/a (no Curtain Calls)" if not calls else ("yes (planner)" if three else ("yes (authored route)" if authored3 else "no"))
	proofs["three_stars_proven"] = (not calls) or three or authored3
	proofs["three_stars_note"] = three_txt
	var ok := bool(sc.get("ok", false)) and alone_ok and bool(proofs["three_stars_proven"]) and bool(sl.get("ok", false))
	print("[solve] %s auto %s: script %s (%d lines, %.0f applause, %s), lines alone %s, ★★★ %s, soft-lock %s (%d catches%s), %.1f s, %d macros" % [
		ep, "OK" if ok else "FAIL", "OK" if bool(sc.get("ok", false)) else "FAIL", (sc.get("lines", []) as Array).size(),
		float(sc.get("applause", 0.0)), Metrics.stars_text(sc.get("stars", [])), "OK" if alone_ok else "FAIL %s" % alone_bad,
		three_txt, "OK" if bool(sl.get("ok", false)) else "FAIL", int(sl.get("catches", 0)),
		", " + String(sl["note"]) if sl.has("note") else "", int(proofs.get("elapsed_ms", 0)) / 1000.0, int(proofs.get("expanded", 0))])
	for n in proofs.get("notes", []):
		print("  - note: %s" % n)
	if not bool(sl.get("ok", true)):
		print("  - soft-lock: %s" % sl.get("why", ""))
	var wrote := ""
	if bool(a["write_auto"]):
		var dir: String = a["auto_dir"] if String(a["auto_dir"]) != "" else "res://data/solutions/_auto"
		DirAccess.make_dir_recursive_absolute(dir)
		var path := "%s/%s.json" % [dir, ep]
		var plan := {"steps": sc.get("steps", []), "stars": sc.get("stars", []), "applause": sc.get("applause", 0.0),
			"catches": sc.get("catches", 0)}
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(pl.to_solution(plan), "  ") + "\n")
			wrote = path
			print("  - wrote %s" % path)
	var slim := proofs.duplicate(true)
	if slim.has("script"):
		(slim["script"] as Dictionary).erase("steps")
		slim["script"]["steps_n"] = (sc.get("steps", []) as Array).size()
	return {"ok": ok, "proofs": slim, "wrote": wrote}


func _write_report(path: String, reports: Array, autos: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var out := {"generated_by": "tools/solve.gd", "runs": reports, "auto": autos}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
	var md := Metrics.to_markdown(reports, "Solver report")
	if not autos.is_empty():
		md += "\n## Planner proofs\n\n| episode | ok | script | lines alone | ★★★ | soft-lock |\n|---|---|---|---|---|---|\n"
		for ep in autos:
			var p: Dictionary = autos[ep]["proofs"]
			var la := PackedStringArray()
			for l in p.get("line_alone", {}):
				la.append("%s %s" % [l, "✓" if bool(p["line_alone"][l]["ok"]) else "✗"])
			md += "| %s | %s | %s | %s | %s | %s |\n" % [ep, "OK" if bool(autos[ep]["ok"]) else "**FAIL**",
				"OK" if bool(p.get("script", {}).get("ok", false)) else "FAIL", ", ".join(la),
				String(p.get("three_stars_note", "yes" if bool(p.get("three_stars", false)) else "no")),
				"OK" if bool(p.get("softlock", {}).get("ok", false)) else "FAIL: %s" % p.get("softlock", {}).get("why", "")]
	var f2 := FileAccess.open(path.get_basename() + ".md", FileAccess.WRITE)
	if f2 != null:
		f2.store_string(md)
