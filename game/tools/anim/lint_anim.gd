## Animation + rig lint CLI (TECH §10.5) — CI entry point (tools/scripts/lint.sh calls it):
##   godot --headless --path <sandbox> -s res://tools/anim/lint_anim.gd -- --all
##   … -- --rig=_mannequin            (that rig + its clips)
##   … -- --clip=_mannequin/rx_take   (one clip)
##   … -- --file=res://tests/rig/fixtures/bad_pop.json   (a clip file outside data/anim)
##   … -- --no-rigs                   (clips only)
##   … -- --strict                    (the pre-gate: every WARNING counts as an ERROR)
## Expected lengths (A24 / A25 / A29) come from SliceClips.build() when it exists, else from
## activities.json (the summary line says which).
## Prints one line per finding ("ERROR <rule> <file>:f<frame> <message>") and a summary;
## exit code 1 when any error-severity finding exists, else 0.
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var rig_id := ""
	var clip_id := ""
	var file := ""
	var all := false
	var rigs := true
	var strict := false
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
