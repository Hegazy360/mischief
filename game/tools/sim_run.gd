## sim_run — headless sim CLI (TECH §3.9).
##
##   tools/scripts/sandbox.sh <name> -s res://tools/sim_run.gd -- --episode=<id> [--data=res://data]
##       [--cmds=/abs/path.json] [--ticks=N] [--dump] [--relaxed] [--seed=N]
##       [--golden=check|update] [--golden-file=/abs/or/res/path.json] [--every=N]
##
## --cmds: {"cmds": [[tick, cmd], ...]} or a bare [[tick, cmd], ...] list (commands apply at that tick; SimReplay).
## A dump from `solve.sh --dump-cmds` / `fuzz.sh --dump-cmds` also carries `episode`, `ticks` and `hash`: they are
## the defaults for --episode / --ticks, and the run reports whether its final hash matches the dump's
## (exit 1 when it does not).
## --dump prints every event as a JSON line. Always prints a summary and the final state hash.
## --golden=check replays the golden file's cmds and compares its checkpoints (exit 1 on mismatch);
## --golden=update rewrites the file with checkpoints every --every ticks (default 600) + the last tick.
## Default golden file: res://tests/sim/golden/<episode>.json (inside a sandbox, pass --golden-file with the
## repo path to update the real file).
extends SceneTree


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.trim_prefix("--").split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	quit(_run(args))


func _run(args: Dictionary) -> int:
	var data := str(args.get("data", "res://data"))
	var golden_mode := str(args.get("golden", ""))
	var ep := str(args.get("episode", ""))
	var golden_file := str(args.get("golden-file", "res://tests/sim/golden/%s.json" % ep))
	var cmds: Array = []
	var ticks := int(args.get("ticks", "3600"))
	var want_hash := -1
	var checkpoints: Array = []
	if golden_mode == "check":
		var g: Variant = _read_json(golden_file)
		if typeof(g) != TYPE_DICTIONARY:
			print("[sim_run] cannot read golden %s" % golden_file)
			return 1
		ep = str(g.get("episode", ep))
		cmds = g.get("cmds", [])
		checkpoints = g.get("checkpoints", [])
		ticks = int(g.get("ticks", ticks))
		if g.has("data"):
			data = str(g["data"])
	elif args.has("cmds"):
		var c := SimReplay.load_file(str(args["cmds"]))
		if c.is_empty():
			print("[sim_run] cannot read cmds %s" % args["cmds"])
			return 1
		cmds = c["cmds"]
		if ep == "" and str(c["episode"]) != "":
			ep = str(c["episode"])
		if not args.has("ticks") and int(c["ticks"]) > 0:
			ticks = int(c["ticks"])
		want_hash = int(c["hash"])
	var db := ContentDB.load_dir(data)
	if not db.errors.is_empty():
		print("[sim_run] content errors in %s (%d):" % [data, db.errors.size()])
		for e in db.errors:
			print("  " + e)
	var config := {"relaxed": args.has("relaxed")}
	if args.has("seed"):
		config["seed"] = int(args["seed"])
	var w := SimWorld.create(db, ep, config)
	if w == null:
		print("[sim_run] unknown episode '%s'" % ep)
		return 1
	var by_tick := SimReplay.by_tick(cmds)
	var every := int(args.get("every", "600"))
	var dump := args.has("dump")
	var want := {}
	for cp in checkpoints:
		want[int(cp[0])] = int(cp[1])
	var got: Array = []
	var mismatches := 0
	var n_events := 0
	var t0 := Time.get_ticks_usec()
	for t in range(1, ticks + 1):
		w.step(by_tick.get(t, []))
		var evs := w.drain_events()
		n_events += evs.size()
		if dump:
			for ev in evs:
				print(JSON.stringify(ev))
		if golden_mode == "check" and want.has(t):
			var h := w.state_hash()
			if h != int(want[t]):
				mismatches += 1
				print("[sim_run] golden mismatch at tick %d: %d != %d" % [t, h, int(want[t])])
		elif golden_mode == "update" and (t % every == 0 or t == ticks):
			got.append([t, w.state_hash()])
		if w.ended:
			if golden_mode == "update":
				got.append([t, w.state_hash()])
			break
	var us := Time.get_ticks_usec() - t0
	print("[sim_run] %s: %d ticks, %d events, %.3f ms/tick, applause %d, stars %s, ended %s (%s)" % [ep, w.tick,
		n_events, us / 1000.0 / maxi(1, w.tick), w.applause_tenths(), str(w.stars()), str(w.ended), w.end_reason])
	var done := PackedStringArray()
	for l in w.line_states():
		done.append("%s%s" % [l["id"], "✓" if l["done"] else ""])
	print("[sim_run] lines: %s" % ", ".join(done))
	print("[sim_run] hash %d" % w.state_hash())
	if want_hash >= 0 and golden_mode == "":
		var same := w.state_hash() == want_hash
		print("[sim_run] dump hash %d: %s" % [want_hash, "MATCH" if same else "MISMATCH"])
		if not same:
			return 1
	if golden_mode == "update":
		var out := {"episode": ep, "data": data, "ticks": ticks, "cmds": cmds, "checkpoints": got}
		var f := FileAccess.open(golden_file, FileAccess.WRITE)
		if f == null:
			print("[sim_run] cannot write %s" % golden_file)
			return 1
		f.store_string(JSON.stringify(out, "  ") + "\n")
		f.close()
		print("[sim_run] golden written: %s (%d checkpoints)" % [golden_file, got.size()])
	if golden_mode == "check":
		print("[sim_run] golden %s: %d mismatches over %d checkpoints" % ["OK" if mismatches == 0 else "FAILED",
			mismatches, want.size()])
		return 0 if mismatches == 0 else 1
	return 0


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return j.data
