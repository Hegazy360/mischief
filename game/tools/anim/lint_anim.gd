## Animation + rig lint CLI (TECH §10.5) — CI entry point (tools/scripts/lint.sh calls it):
##   godot --headless --path <sandbox> -s res://tools/anim/lint_anim.gd -- --all
##   … -- --rig=_mannequin            (that rig + its clips)
##   … -- --clip=_mannequin/rx_take   (one clip)
##   … -- --file=res://tests/rig/fixtures/bad_pop.json   (a clip file outside data/anim)
##   … -- --no-rigs                   (clips only)
##   … -- --strict                    (the pre-gate: every WARNING counts as an ERROR)
## Expected lengths (A24 / A25 / A29) come from SliceClips.build() when it exists, else from
## activities.json (the summary line says which).
## **3D clips (R3D, `--format=3d`)** — the rules of `lint3d_rules.gd` (AnimLint3D) on the sidecars under
## `data/anim/<rig>3d/` and their baked `.res` on the rig's skeleton:
##   … -- --format=3d [--rig=hush] [--clip=hush/loco_walk] [--file=/abs/or/res/sidecar.json]
##        [--scope=g0,p00] [--strict] [--json=/abs/report.json]
## `--scope=g0,p00` lints the ruling-R9 set (SliceClips.build3d(g0_sneeze, p00_curtain_up) + rig_high/mid/low; until
## r3d-view3d lands build3d, the 2D manifest's g0/p00 rows with the 3D swaps); clips of the scope not baked yet are
## listed as MISSING (info). Without `--scope` every sidecar of the rig(s) is linted.
## Prints one line per finding ("ERROR <rule> <file>:f<frame> <message>") and a summary;
## exit code 1 when any error-severity finding exists, else 0.
extends SceneTree

const Lint3D := preload("res://tools/anim/lint3d_rules.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var rig_id := ""
	var clip_id := ""
	var file := ""
	var all := false
	var rigs := true
	var strict := false
	var fmt := "2d"
	var scope := PackedStringArray()
	var json_out := ""
	for a in args:
		if a == "--all":
			all = true
		elif a == "--no-rigs":
			rigs = false
		elif a == "--strict":
			strict = true
		elif a.begins_with("--rig="):
			rig_id = a.substr(6)
		elif a.begins_with("--clip="):
			clip_id = a.substr(7)
		elif a.begins_with("--file="):
			file = a.substr(7)
		elif a.begins_with("--format="):
			fmt = a.substr(9)
		elif a.begins_with("--scope="):
			scope = a.substr(8).split(",", false)
		elif a.begins_with("--json="):
			json_out = a.substr(7)
	if fmt == "3d":
		quit(_lint_3d(rig_id, clip_id, file, scope, strict, json_out))
		return
	var findings: Array = []
	var clips := 0
	if file != "":
		var c := ClipLib.load_file(file)
		findings.append_array(AnimLint.lint_clip(c))
		clips = 1
	elif clip_id != "":
		var c2 := ClipLib.get_clip(clip_id)
		if c2 == null:
			printerr("lint_anim: clip '%s' not found" % clip_id)
			quit(2)
			return
		findings.append_array(AnimLint.lint_clip(c2))
		clips = 1
	else:
		if not all and rig_id == "":
			all = true
		if rigs:
			findings.append_array(RigLint.lint_all(rig_id))
		var rig_ids := PackedStringArray([rig_id]) if rig_id != "" else ClipLib.rigs_with_clips()
		for r in rig_ids:
			for cid in ClipLib.list(r):
				findings.append_array(AnimLint.lint_clip(ClipLib.get_clip(cid)))
				clips += 1
	if strict:
		AnimLint.make_strict(findings)
	for f in findings:
		print(AnimLint.format(f))
	var errors := AnimLint.error_count(findings)
	print("lint_anim: %d clip(s), %d error(s), %d warning(s)%s; expected lengths from %s" % [clips, errors,
		findings.size() - errors, " [strict]" if strict else "", AnimLint.expectations_source()])
	quit(1 if errors > 0 else 0)


## The 3D lint (see the header); returns the exit code.
func _lint_3d(rig_id: String, clip_id: String, file: String, scope: PackedStringArray, strict: bool, json_out: String) -> int:
	var t0 := Time.get_ticks_msec()
	var findings: Array = []
	var linted := PackedStringArray()
	var missing := PackedStringArray()
	if file != "":
		findings.append_array(Lint3D.lint_paths(file))
		linted.append(file)
	elif clip_id != "":
		if not FileAccess.file_exists(_sidecar_of(clip_id)):
			printerr("lint_anim: 3D clip '%s' not found (%s)" % [clip_id, _sidecar_of(clip_id)])
			return 2
		findings.append_array(Lint3D.lint_clip_id(clip_id))
		linted.append(clip_id)
	else:
		var ids := PackedStringArray()
		if not scope.is_empty():
			for s in Lint3D.scope_ids(scope, rig_id):
				if FileAccess.file_exists(_sidecar_of(s)):
					ids.append(s)
				else:
					missing.append(s)
		else:
			for r in (PackedStringArray([rig_id]) if rig_id != "" else _rigs_3d()):
				for c in _clips_3d(r):
					ids.append(c)
		for cid in ids:
			findings.append_array(Lint3D.lint_clip_id(cid))
			linted.append(cid)
	if strict:
		Lint3D.make_strict(findings)
	for f in findings:
		print(Lint3D.format(f))
	for m in missing:
		print("INFO MISSING %s (in the lint scope, not baked yet)" % m)
	var errors := Lint3D.error_count(findings)
	var warnings := 0
	for f2 in findings:
		if String(f2["severity"]) == "warning":
			warnings += 1
	var ms := Time.get_ticks_msec() - t0
	print("lint_anim 3d: %d clip(s), %d error(s), %d warning(s), %d missing%s; expected lengths from %s; %d ms" % [linted.size(),
		errors, warnings, missing.size(), " [strict]" if strict else "", Lint3D.expectations_source(), ms])
	if json_out != "":
		var fa := FileAccess.open(json_out, FileAccess.WRITE)
		if fa != null:
			fa.store_string(JSON.stringify({"clips": linted, "errors": errors, "warnings": warnings, "missing": missing,
				"findings": findings, "strict": strict, "expectations": Lint3D.expectations_source(), "ms": ms}, "  "))
	return 1 if errors > 0 else 0


func _sidecar_of(clip_id: String) -> String:
	return "res://data/anim/%s3d/%s.json" % [clip_id.get_slice("/", 0), clip_id.get_slice("/", 1)]


func _rigs_3d() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open("res://data/anim")
	if d == null:
		return out
	for sub in d.get_directories():
		if sub.ends_with("3d"):
			out.append(sub.trim_suffix("3d"))
	out.sort()
	return out


func _clips_3d(rig: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open("res://data/anim/%s3d" % rig)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json") and f != "map.json" and f != "rig_actions.json":
			out.append("%s/%s" % [rig, f.get_basename()])
	out.sort()
	return out
