## Lint runner (TECH §10.5): content, hotspot and IP lints over the project data.
##
##   tools/scripts/lint.sh                     # = sandbox … -s res://tools/lint/run_lints.gd -- --all
##   … -- [--all] [--content] [--hotspot] [--ip] [--data=res://data] [--game=res://]
##        [--gdd=/abs/docs/GDD.md] [--json=/abs/out.json] [--strict]
##
## Prints one line per lint (`[lint] content: OK …` / `FAIL n error(s)` + each error) and a summary;
## exits 1 when any lint fails. A lint whose inputs don't exist yet is SKIPPED with a clear line
## (exit 0) unless `--strict`. The content lint includes the D1 micro-gag cadence + emote rules; its clip
## coverage (every clip of `SliceClips.build()` exists under data/anim/, BeatLint) prints WARNINGs, which
## `--strict` (the pre-gate) turns into errors. `--json` also lists the coverage (`coverage {missing, source}`).
## R3D (ruling R9): the 3D coverage (`BeatLint.coverage3d`: every clip of `SliceClips.build3d(g0, p00)` + the band
## fallbacks as a v2 sidecar — WARN, errors under `--strict`; N01/N02 as info) and, inside the content lint, the
## `hides` rules and the view data (`ViewDataLint`: previews.json, rig_actions.json vs house3d.json).
extends SceneTree


func _initialize() -> void:
	var args := {"data": "res://data", "game": "res://", "gdd": "", "json": ""}
	var want := PackedStringArray()
	var strict := false
	for a in OS.get_cmdline_user_args():
		if a == "--all":
			want.append_array(["content", "hotspot", "ip"])
		elif a in ["--content", "--hotspot", "--ip"]:
			want.append(a.trim_prefix("--"))
		elif a == "--strict":
			strict = true
		elif a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			args[kv[0]] = kv[1]
	if want.is_empty():
		want.append_array(["content", "hotspot", "ip"])
	var report := {}
	var failed := 0
	var skipped := 0
	var data_root: String = args["data"]
	if "content" in want:
		var parts := ContentLint.load_parts(data_root)
		var core := ["pranks.json", "activities.json", "items.json"]
		var missing: PackedStringArray = parts["missing"]
		var present := 0
		for c in core:
			if not missing.has(c):
				present += 1
		if present == 0 and (parts["episodes"] as Dictionary).is_empty():
			print("[lint] content: SKIPPED — no content data yet (%s/{pranks,activities,items}.json and episodes/ missing)" % data_root)
			skipped += 1
			report["content"] = {"skipped": true}
		else:
			var errs := ContentLint.lint(parts)
			if not missing.is_empty():
				print("[lint] content: note — missing %s (their checks were skipped)" % ", ".join(missing))
				if strict:
					for m in missing:
						errs.append("%s/%s: missing" % [data_root, m])
			var cov := BeatLint.coverage(parts, data_root)
			var cmiss: PackedStringArray = cov["missing"]
			if strict:
				for c in cmiss:
					errs.append("anim coverage: %s is in the slice manifest (%s) but data/anim/%s.json does not exist" % [c, cov["source"], c])
			# R3D ruling R9: the 3D coverage of the Gate-0 + Prologue scope (errors under --strict), N01/N02 info
			var c3 := BeatLint.coverage3d(data_root)
			var m3: PackedStringArray = c3["missing"]
			if String(c3["source"]) == "none":
				print("[lint] content coverage 3d: SKIPPED — SliceClips.build3d not built yet (r3d-view3d)")
			elif m3.is_empty():
				print("[lint] content coverage 3d: OK (%d clips of g0 + p00 + band fallbacks as v2 sidecars)" % int(c3["rows"]))
			else:
				print("[lint] content coverage 3d: %s %d of %d g0/p00 clip(s) have no v2 sidecar under %s/anim/<rig>3d/%s" % [
					"FAIL" if strict else "WARN", m3.size(), int(c3["rows"]), data_root, "" if strict else " (errors with --strict)"])
				for c in m3:
					print("  - %s missing 3D clip %s" % ["ERROR" if strict else "WARN", c])
					if strict:
						errs.append("anim coverage 3d: %s (SliceClips.build3d g0/p00, ruling R9) has no v2 sidecar data/anim/%s" % [c, c.replace("/", "3d/") + ".json"])
			if String(c3["source"]) != "none":
				print("[lint] content coverage 3d (info): N01/N02-only clips %d of %d missing" % [(c3["info_missing"] as PackedStringArray).size(), int(c3["info_rows"])])
			failed += _print("content", errs, "%d episodes, %d pranks" % [(parts["episodes"] as Dictionary).size(),
				((parts["pranks"] as Dictionary).get("pranks", {}) as Dictionary).size()])
			if not strict:
				if cmiss.is_empty():
					print("[lint] content coverage: OK (%d clips from %s)" % [int(cov["rows"]), cov["source"]])
				else:
					print("[lint] content coverage: WARN %d of %d clip(s) from %s missing under %s/anim (errors with --strict)" % [
						cmiss.size(), int(cov["rows"]), cov["source"], data_root])
					for c in cmiss:
						print("  - WARN missing clip %s" % c)
			report["content"] = {"errors": Array(errs), "coverage": {"missing": Array(cmiss), "source": cov["source"],
				"rows": cov["rows"]}, "coverage3d": {"missing": Array(m3), "rows": c3["rows"], "source": c3["source"],
				"info_missing": Array(c3["info_missing"]), "info_rows": c3["info_rows"]}}
	if "hotspot" in want:
		var hp := "%s/house/house.json" % data_root
		if not FileAccess.file_exists(hp):
			print("[lint] hotspot: SKIPPED — %s missing" % hp)
			skipped += 1
			report["hotspot"] = {"skipped": true}
			if strict:
				failed += 1
		else:
			var herrs := HotspotLint.lint_file(hp)
			failed += _print("hotspot", herrs, hp)
			report["hotspot"] = {"errors": Array(herrs)}
	if "ip" in want:
		var gdd: String = args["gdd"]
		var res := IpLint.scan_project(String(args["game"]), gdd)
		var hits: PackedStringArray = res["hits"]
		var what := "%d files, %d GDD strings" % [int(res["files"]), int(res["strings"])]
		if gdd != "" and not bool(res["gdd"]):
			print("[lint] ip: note — GDD not found at %s (GDD strings not scanned)" % gdd)
		failed += _print("ip", hits, what)
		report["ip"] = {"errors": Array(hits)}
	print("[lint] %s: %d lint(s) failed, %d skipped" % ["FAIL" if failed > 0 else "OK", failed, skipped])
	var jp: String = args["json"]
	if jp != "":
		var f := FileAccess.open(jp, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, "  "))
	quit(1 if failed > 0 else 0)


func _print(name: String, errs: PackedStringArray, what: String) -> int:
	if errs.is_empty():
		print("[lint] %s: OK (%s)" % [name, what])
		return 0
	print("[lint] %s: FAIL %d error(s) (%s)" % [name, errs.size(), what])
	for e in errs:
		print("  - %s" % e)
	return 1
