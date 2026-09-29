## Rig lint CLI (TECH §10.5):
##   godot --headless --path <sandbox> -s res://tools/anim/lint_rig.gd -- [--all | --rig=<id> | --file=<rig.json>]
## Prints one line per finding and a summary; exit code 1 on any error.
extends SceneTree


func _initialize() -> void:
	var rig_id := ""
	var file := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rig="):
			rig_id = a.substr(6)
		elif a.begins_with("--file="):
			file = a.substr(7)
	var findings: Array = []
	if file != "":
		var r := RigDef.load(file)
		var poses_path := file.get_base_dir().path_join("poses.json")
		var lib: PoseLib = null
		if FileAccess.file_exists(poses_path):
			lib = PoseLib.load(r, poses_path, file.get_base_dir().path_join("faces.json"))
		findings = RigLint.lint_rig(r, lib)
	else:
		findings = RigLint.lint_all(rig_id)
	for f in findings:
		print(AnimLint.format(f))
	var errors := AnimLint.error_count(findings)
	print("lint_rig: %d error(s), %d warning(s)" % [errors, findings.size() - errors])
	quit(1 if errors > 0 else 0)
