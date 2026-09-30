## The REDESIGN §6.3 lint runner (`tools/scripts/lint3d.sh` runs it in a sandbox; index §6 rows 9–12 and 16).
##
##   … -s res://tools/lint3d/run_lint3d.gd -- <mode>… [--json=/abs.json] [--strict] [--verbose]
##   --set [--night=<id>,… | --all-nights] [--measure=/abs/measure.json]      counts, geometry, families, stacks (+ the
##                                                                            colour / silhouette measures when given)
##   --screen [--aspects=20x9,16x9,4x3] [--night=…]                          projected hit boxes (headless)
##   --hud --from=/abs/dir                                                   e2e reports' hud_pieces / overlays / share
##   --visibility --cmds-dir=/abs/dir [--routes=all|ideal,…] [--aspects=20x9] [--mode=sim|lean] [--no-other-mode]
##                [--max-frames=N]                                           C8 on every frame of every solver route
##   --perf <report.json>… | --perf --from=/abs/dir                           the perf3d budgets
##
## Prints `[lint3d] …` lines (errors, warnings, skips; info with --verbose) and one summary per mode; `--json` writes
## {mode: Lint3D.report(…)} (one file). Exit 1 on any error (or, with --strict, any SKIP); warnings never fail.
extends SceneTree

var _args := {}
var _positional := PackedStringArray()
var _modes := PackedStringArray()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a in ["--set", "--screen", "--hud", "--visibility", "--perf"]:
			_modes.append(a.trim_prefix("--"))
		elif a.begins_with("--"):
			var kv := a.trim_prefix("--").split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
		else:
			_positional.append(a)
	_run.call_deferred()


func _nights() -> PackedStringArray:
	var n := String(_args.get("night", ""))
	if n == "" or n == "all" or _args.has("all-nights"):
		return Lint3D.NIGHTS
	return PackedStringArray(n.split(",", false))


func _csv(key: String, fallback: String) -> PackedStringArray:
	return PackedStringArray(String(_args.get(key, fallback)).split(",", false))


func _run() -> void:
	await process_frame
	var strict := _args.has("strict")
	var verbose := _args.has("verbose")
	if _modes.is_empty():
		printerr("[lint3d] no mode: --set | --screen | --hud | --visibility | --perf")
		quit(2)
		return
	var db: ContentDB = null
	if _modes.has("set") or _modes.has("screen") or _modes.has("visibility"):
		db = ContentDB.load_dir("res://data")
	var out := {}
	var fail := false
	for mode in _modes:
		var t0 := Time.get_ticks_msec()
		var r: Dictionary = {}
		match mode:
			"set":
				var measure: Variant = Lint3D.read_json(String(_args.get("measure", "")))
				r = SetLint3D.run(db, _nights(), measure)
			"screen":
				r = ScreenRectLint3D.run(db, _nights(), _csv("aspects", "20x9,16x9,4x3"))
			"hud":
				r = _hud(String(_args.get("from", "")))
			"visibility":
				r = await _visibility(db)
			"perf":
				r = _perf()
		var issues: Array = r.get("issues", [])
		var rep := Lint3D.report(mode, issues, r.get("results", {}), strict)
		rep["ms"] = Time.get_ticks_msec() - t0
		out[mode] = rep
		Lint3D.print_issues(mode, issues, strict, verbose)
		if mode == "perf":
			print(PerfCheck3D.table((r.get("results", {}) as Dictionary).get("rows", [])))
		if not bool(rep["pass"]):
			fail = true
	if _args.has("json"):
		Lint3D.write_json(String(_args["json"]), out)
		print("[lint3d] json %s" % _args["json"])
	quit(1 if fail else 0)


## The e2e reports of a folder (or the positional files).
func _report_files(dir: String) -> PackedStringArray:
	var files := PackedStringArray()
	for p in _positional:
		if p.ends_with(".json"):
			files.append(p)
	if dir != "":
		var d := DirAccess.open(dir)
		if d != null:
			var names := d.get_files()
			names.sort()
			for f in names:
				if f.ends_with(".json"):
					files.append(dir.path_join(f))
	return files


func _hud(dir: String) -> Dictionary:
	var issues: Array = []
	var stats: Array = []
	var files := _report_files(dir)
	if files.is_empty():
		issues.append(Lint3D.skip(HudLint3D.LINT, "reports", "no e2e reports in '%s' (e2e.sh … --report=, r3d-night)" % dir,
			"r3d-night"))
	for f in files:
		var rep: Variant = Lint3D.read_json(f)
		if not (rep is Dictionary) or not ((rep as Dictionary).has("hud_pieces") or (rep as Dictionary).has("pip_on_share")):
			continue
		var r := HudLint3D.check_report(rep, f.get_file().get_basename())
		issues.append_array(r["issues"])
		stats.append(r["stats"])
	if stats.is_empty() and not files.is_empty():
		issues.append(Lint3D.skip(HudLint3D.LINT, "reports", "no 3D e2e report among %d JSON files in %s" % [files.size(), dir],
			"r3d-night"))
	return {"issues": issues, "results": {"reports": stats}}


func _perf() -> Dictionary:
	var issues: Array = []
	var rows: Array = []
	var files := _report_files(String(_args.get("from", "")))
	if files.is_empty():
		issues.append(Lint3D.skip("perf", "reports", "no e2e report given", "r3d-night"))
	for f in files:
		var rep: Variant = Lint3D.read_json(f)
		if not (rep is Dictionary):
			issues.append(Lint3D.skip("perf", "report", "%s is not a JSON object" % f, "r3d-night"))
			continue
		if not (rep as Dictionary).has("perf3d") and not (rep as Dictionary).has("scenario"):
			continue
		var r := PerfCheck3D.check(rep, f.get_file().get_basename())
		issues.append_array(r["issues"])
		rows.append(r["row"])
	return {"issues": issues, "results": {"rows": rows}}


func _visibility(db: ContentDB) -> Dictionary:
	var issues: Array = []
	var results := {"routes": []}
	var dir := String(_args.get("cmds-dir", ""))
	var shipped := String(_args.get("mode", VisibilityCheck3D.shipped_mode()))
	var modes := PackedStringArray([shipped])
	if not _args.has("no-other-mode"):
		modes.append("lean" if shipped == "sim" else "sim")
	results["shipped_mode"] = shipped
	var aspects := _csv("aspects", "20x9")
	var want_routes := _csv("routes", "all")
	var files := VisibilityCheck3D.route_files(dir, _nights())
	if files.is_empty():
		issues.append(Lint3D.skip(VisibilityCheck3D.LINT, "routes", "no <episode>_<route>.cmds.json in '%s' (solve.sh --dump-cmds)" % dir,
			"r3d-content"))
		return {"issues": issues, "results": results}
	var keys: Array = files.keys()
	keys.sort()
	var max_frames := int(_args.get("max-frames", "30000"))
	var shots: Array = []
	for key in keys:
		var ep := String(key).get_slice("|", 0)
		var route := String(key).get_slice("|", 1)
		if not want_routes.has("all") and not want_routes.has(route):
			continue
		var cmds: Variant = Lint3D.read_json(files[key])
		if not (cmds is Dictionary):
			issues.append(Lint3D.skip(VisibilityCheck3D.LINT, "cmds", "%s unreadable" % files[key], "r3d-content", ep))
			continue
		for aspect in aspects:
			for mode in modes:
				var rp := VisibilityCheck3D.replay(root, db, ep, cmds, mode, aspect, max_frames)
				await process_frame
				if String(rp.get("error", "")) != "":
					issues.append(Lint3D.skip(VisibilityCheck3D.LINT, "replay", String(rp["error"]), VisibilityCheck3D.OWNER, ep))
					continue
				var chk := VisibilityCheck3D.check_rows(rp["rows"], mode)
				var level := Lint3D.ERROR if mode == shipped else Lint3D.INFO
				var vi := VisibilityCheck3D.violation_issues(ep, route, mode, aspect, chk, level)
				issues.append_array(vi)
				var share: Dictionary = rp["share"]
				var row := {"episode": ep, "route": route, "mode": mode, "aspect": aspect, "frames": rp["frames"],
					"ended": rp["ended"], "ms": rp["ms"], "violations": (chk["violations"] as Array).size(),
					"violation_runs": vi.size(), "window_share": snappedf(float(chk["share"]), 0.0001),
					"window_longest_s": snappedf(float(chk["longest_s"]), 0.01), "badge_frames": chk["badge_frames"],
					"pip_on_share": share.get("pip_on_share", 0.0), "pip_longest_s": share.get("pip_longest_s", 0.0)}
				(results["routes"] as Array).append(row)
				print("[lint3d] visibility %s %s %s %s: %d frames, %d violation frame(s) in %d run(s), window %.1f %% (longest %.1f s), badge %d frames, %d ms" % [
					Lint3D.label(ep), route, mode, aspect, rp["frames"], row["violations"], vi.size(), 100.0 * float(chk["share"]),
					float(chk["longest_s"]), chk["badge_frames"], rp["ms"]])
				issues.append(Lint3D.issue(VisibilityCheck3D.LINT, "window_share", Lint3D.INFO, ep, "", "%s/%s/%s" % [route, mode, aspect],
					"%.1f %%" % (100.0 * float(chk["share"])), "35 % (HUD-lint warning)", VisibilityCheck3D.OWNER,
					"longest %.1f s; badge %d frames" % [float(chk["longest_s"]), chk["badge_frames"]]))
				if mode == shipped and not (chk["violations"] as Array).is_empty():
					var first: Dictionary = (chk["violations"] as Array)[0]
					shots.append({"episode": ep, "route": route, "mode": mode, "aspect": aspect, "tick": first["tick"],
						"rule": first["rule"], "cmds": files[key]})
	results["shots"] = shots
	return {"issues": issues, "results": results}
