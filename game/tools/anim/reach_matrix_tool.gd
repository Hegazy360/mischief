## Reach matrix tool (docs/research/animation.md phase 4): every container / rig point × facing through the
## real RigPlayer, scored (ReachMatrix), written as CSV and summarised. Exit 1 when any cell pops.
##   tools/scripts/sandbox.sh <sb> -s res://tools/anim/reach_matrix_tool.gd -- --out=/abs/matrix.csv [--rig=hush] [--only=id,id]
extends SceneTree


func _initialize() -> void:
	var out := ""
	var rig_id := "hush"
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--rig="):
			rig_id = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",", false)
	var rows := ReachMatrix.run(rig_id, root, only)
	var text := ReachMatrix.csv(rows)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.store_string(text + "\n")
			f.close()
	else:
		print(text)
	var sum := ReachMatrix.summary(rows)
	print("[reach_matrix] %s: %d cells — %s%s" % [rig_id, rows.size(), JSON.stringify(sum), (" → " + out) if out != "" else ""])
	for r in rows:
		if r["status"] == "short" or r["status"] == "pop":
			print("  %-8s %-28s facing %+d  best %.1f px  hop %.0f  crouch %.2f  jump %.0f° (authored %.0f°)" % [r["status"], r["hotspot"], r["facing"], r["best_px"], r["hop_px"], r["crouch"], r["max_joint_deg"], r["base_joint_deg"]])
	quit(1 if sum.has("pop") else 0)
